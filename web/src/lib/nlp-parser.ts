import { format } from 'date-fns';

export type DetectedLanguage = 'german' | 'english';

export type SegmentType = 'text' | 'date' | 'time' | 'priority' | 'project' | 'label';

export interface ParsedSegment {
  text: string;
  type: SegmentType;
  value?: unknown;
}

export interface ParseResult {
  title: string;
  dueDate: string | null;   // yyyy-MM-dd
  dueTime: string | null;   // HH:mm
  priority: 'p1' | 'p2' | 'p3' | 'p4' | null;
  projectName: string | null;
  labels: string[];
  detectedLanguage: DetectedLanguage;
  segments: ParsedSegment[];
}

// ---------------------------------------------------------------------------
// Language detection
// ---------------------------------------------------------------------------

const GERMAN_INDICATORS = new Set([
  'morgen', 'heute', 'übermorgen', 'uhr', 'montag', 'dienstag',
  'mittwoch', 'donnerstag', 'freitag', 'samstag', 'sonntag',
  'nächste', 'woche', 'monat',
]);

// Short German day names that also serve as indicators, but only when they
// appear as standalone words (checked separately with word-boundary logic).
const GERMAN_SHORT_DAY_INDICATORS = new Set([
  'mo', 'di', 'mi', 'do', 'fr', 'sa', 'so',
]);

const ENGLISH_INDICATORS = new Set([
  'tomorrow', 'today', 'next', 'week', 'month', 'monday',
  'tuesday', 'wednesday', 'thursday', 'friday', 'saturday',
  'sunday', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun', 'am', 'pm',
]);

function detectLanguage(input: string): DetectedLanguage {
  const lower = input.toLowerCase();
  const words = lower.split(/\s+/);
  let germanScore = 0;
  let englishScore = 0;

  for (const word of words) {
    if (GERMAN_INDICATORS.has(word)) germanScore++;
    // For short German day names, only count if word-boundary matched
    if (GERMAN_SHORT_DAY_INDICATORS.has(word)) germanScore++;
    if (ENGLISH_INDICATORS.has(word)) englishScore++;
  }

  if (germanScore === englishScore) return 'german'; // default
  return germanScore > englishScore ? 'german' : 'english';
}

// ---------------------------------------------------------------------------
// Priority parser
// ---------------------------------------------------------------------------

interface PriorityMatch {
  priority: 1 | 2 | 3 | 4;
  matchedText: string;
  index: number;
}

function parsePriority(input: string): PriorityMatch | null {
  // !!1 through !!4 (higher precedence)
  const excl = /!!([1-4])/.exec(input);
  if (excl) {
    return {
      priority: parseInt(excl[1], 10) as 1 | 2 | 3 | 4,
      matchedText: excl[0],
      index: excl.index,
    };
  }
  // p1 through p4 with word boundaries
  const p = /\bp([1-4])\b/i.exec(input);
  if (p) {
    return {
      priority: parseInt(p[1], 10) as 1 | 2 | 3 | 4,
      matchedText: p[0],
      index: p.index,
    };
  }
  return null;
}

// ---------------------------------------------------------------------------
// Project parser (#name or #"name with spaces")
// ---------------------------------------------------------------------------

interface ProjectMatch {
  projectName: string;
  matchedText: string;
  index: number;
}

function parseProject(input: string): ProjectMatch | null {
  const m = /#(?:"([^"]+)"|(\S+))/.exec(input);
  if (!m) return null;
  const name = m[1] ?? m[2];
  if (!name) return null;
  return { projectName: name, matchedText: m[0], index: m.index };
}

// ---------------------------------------------------------------------------
// Label parser (@name, multiple allowed)
// ---------------------------------------------------------------------------

interface LabelMatch {
  label: string;
  matchedText: string;
  index: number;
}

function parseLabels(input: string): LabelMatch[] {
  const results: LabelMatch[] = [];
  const re = /@(\S+)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(input)) !== null) {
    if (m[1]) {
      results.push({ label: m[1], matchedText: m[0], index: m.index });
    }
  }
  return results;
}

// ---------------------------------------------------------------------------
// Date / time parser
// ---------------------------------------------------------------------------

// Word-boundary pattern that prevents matching inside words.
// Uses negative lookbehind/lookahead for letters including German umlauts.
const LETTER = '[a-zA-ZäöüßÄÖÜ]';

function dayBoundaryRegex(keyword: string): RegExp {
  return new RegExp(`(?<!${LETTER})${keyword}(?!${LETTER})`, 'i');
}

const GERMAN_DAY_SHORTCUTS: Record<string, number> = {
  mo: 1, di: 2, mi: 3, do: 4, fr: 5, sa: 6, so: 0,
  montag: 1, dienstag: 2, mittwoch: 3, donnerstag: 4,
  freitag: 5, samstag: 6, sonntag: 0,
};

const ENGLISH_DAY_SHORTCUTS: Record<string, number> = {
  mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6, sun: 0,
  monday: 1, tuesday: 2, wednesday: 3, thursday: 4,
  friday: 5, saturday: 6, sunday: 0,
};

// JS Date.getDay(): 0=Sunday, 1=Monday ... 6=Saturday
function nextWeekday(targetDay: number, now: Date): Date {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const currentDay = today.getDay();
  let diff = targetDay - currentDay;
  if (diff <= 0) diff += 7; // always advance to the NEXT occurrence
  const result = new Date(today);
  result.setDate(result.getDate() + diff);
  return result;
}

interface DateTimeMatch {
  date: string | null;   // yyyy-MM-dd
  time: string | null;   // HH:mm
  matchedText: string;
  index: number;
}

/**
 * Parse date + time from input. The Flutter parser returns at most one date
 * match and one time match (whichever comes first). We replicate that by
 * collecting candidates and picking the best.
 *
 * Important difference from Flutter: we separate date and time parsing so that
 * "mi 15:00" yields BOTH a date (Wednesday) AND a time (15:00).
 */
function parseDateTime(input: string, language: DetectedLanguage): { date: DateTimeMatch | null; time: DateTimeMatch | null } {
  const lower = input.toLowerCase();
  const now = new Date();

  let dateMatch: DateTimeMatch | null = null;
  let timeMatch: DateTimeMatch | null = null;

  // --- Relative keywords ---
  const relativeMap: Record<string, number> = language === 'german'
    ? { heute: 0, morgen: 1, übermorgen: 2 }
    : { today: 0, tod: 0, tomorrow: 1, tom: 1 };

  for (const [keyword, offset] of Object.entries(relativeMap)) {
    const re = new RegExp(`\\b${keyword}\\b`, 'i');
    const m = re.exec(lower);
    if (m) {
      const d = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      d.setDate(d.getDate() + offset);
      dateMatch = { date: format(d, 'yyyy-MM-dd'), time: null, matchedText: m[0], index: m.index };
      break;
    }
  }

  // --- "next week" / "nächste woche" ---
  if (!dateMatch) {
    const nwRe = language === 'german'
      ? /\bnächste\s+woche\b/i
      : /\bnext\s+week\b/i;
    const nwM = nwRe.exec(lower);
    if (nwM) {
      const d = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      d.setDate(d.getDate() + 7);
      dateMatch = { date: format(d, 'yyyy-MM-dd'), time: null, matchedText: nwM[0], index: nwM.index };
    }
  }

  // --- Day shortcuts ---
  if (!dateMatch) {
    const shortcuts = language === 'german' ? GERMAN_DAY_SHORTCUTS : ENGLISH_DAY_SHORTCUTS;
    // Sort by length descending so "montag" is tried before "mo"
    const sorted = Object.entries(shortcuts).sort((a, b) => b[0].length - a[0].length);
    for (const [keyword, targetDay] of sorted) {
      const re = dayBoundaryRegex(keyword);
      const m = re.exec(lower);
      if (m) {
        const target = nextWeekday(targetDay, now);
        dateMatch = { date: format(target, 'yyyy-MM-dd'), time: null, matchedText: m[0], index: m.index };
        break;
      }
    }
  }

  // --- Explicit date patterns ---
  if (!dateMatch) {
    // German: DD.MM or DD.MM.YYYY
    if (language === 'german') {
      const gm = /\b(\d{1,2})\.(\d{1,2})(?:\.(\d{2,4}))?\b/.exec(input);
      if (gm) {
        const day = parseInt(gm[1], 10);
        const month = parseInt(gm[2], 10);
        let year = now.getFullYear();
        if (gm[3]) {
          year = parseInt(gm[3], 10);
          if (year < 100) year += 2000;
        }
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          const d = new Date(year, month - 1, day);
          dateMatch = { date: format(d, 'yyyy-MM-dd'), time: null, matchedText: gm[0], index: gm.index };
        }
      }
    }

    // US: MM/DD or MM/DD/YYYY
    if (!dateMatch && language === 'english') {
      const um = /\b(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?\b/.exec(input);
      if (um) {
        const month = parseInt(um[1], 10);
        const day = parseInt(um[2], 10);
        let year = now.getFullYear();
        if (um[3]) {
          year = parseInt(um[3], 10);
          if (year < 100) year += 2000;
        }
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          const d = new Date(year, month - 1, day);
          dateMatch = { date: format(d, 'yyyy-MM-dd'), time: null, matchedText: um[0], index: um.index };
        }
      }
    }
  }

  // --- Time patterns: 10:00, 10 uhr, 10am, 14:30, 3pm ---
  const timeRe = /\b(\d{1,2})(?::(\d{2}))?\s*(uhr|am|pm)\b/i;
  const colonTimeRe = /\b(\d{1,2}):(\d{2})\b/;
  let tm = timeRe.exec(lower);
  if (!tm) {
    // Also match standalone HH:MM without suffix
    tm = colonTimeRe.exec(input);
  }
  if (tm) {
    let hour = parseInt(tm[1], 10);
    const minute = tm[2] ? parseInt(tm[2], 10) : 0;
    const modifier = tm[3]?.toLowerCase();

    if (modifier === 'pm' && hour < 12) hour += 12;
    else if (modifier === 'am' && hour === 12) hour = 0;

    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      const hh = String(hour).padStart(2, '0');
      const mm = String(minute).padStart(2, '0');
      timeMatch = {
        date: null,
        time: `${hh}:${mm}`,
        matchedText: tm[0],
        index: tm.index,
      };
    }
  }

  return { date: dateMatch, time: timeMatch };
}

// ---------------------------------------------------------------------------
// Remove a matched substring (case-insensitive, first occurrence)
// ---------------------------------------------------------------------------

function removeMatch(input: string, match: string): string {
  const escaped = match.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return input.replace(new RegExp(escaped, 'i'), '').trim();
}

// ---------------------------------------------------------------------------
// Main parse function
// ---------------------------------------------------------------------------

export function parseNaturalLanguage(input: string): ParseResult {
  if (!input.trim()) {
    return {
      title: '',
      dueDate: null,
      dueTime: null,
      priority: null,
      projectName: null,
      labels: [],
      detectedLanguage: 'german',
      segments: [],
    };
  }

  const language = detectLanguage(input);
  let remaining = input;
  const allMatches: Array<{ index: number; length: number; text: string; type: SegmentType; value?: unknown }> = [];

  // Priority
  const prioResult = parsePriority(remaining);
  let priority: ParseResult['priority'] = null;
  if (prioResult) {
    priority = `p${prioResult.priority}` as ParseResult['priority'];
    allMatches.push({ index: prioResult.index, length: prioResult.matchedText.length, text: prioResult.matchedText, type: 'priority', value: priority });
    remaining = removeMatch(remaining, prioResult.matchedText);
  }

  // Date & time
  const dtResult = parseDateTime(remaining, language);
  let dueDate: string | null = null;
  let dueTime: string | null = null;

  if (dtResult.date) {
    dueDate = dtResult.date.date;
    // We need to find the match position in the ORIGINAL input for highlighting
    allMatches.push({ index: dtResult.date.index, length: dtResult.date.matchedText.length, text: dtResult.date.matchedText, type: 'date' });
    remaining = removeMatch(remaining, dtResult.date.matchedText);
  }

  if (dtResult.time) {
    dueTime = dtResult.time.time;
    allMatches.push({ index: dtResult.time.index, length: dtResult.time.matchedText.length, text: dtResult.time.matchedText, type: 'time' });
    remaining = removeMatch(remaining, dtResult.time.matchedText);
  }

  // If we got a time but no date, default to today
  if (dueTime && !dueDate) {
    const now = new Date();
    dueDate = format(new Date(now.getFullYear(), now.getMonth(), now.getDate()), 'yyyy-MM-dd');
  }

  // Project
  const projResult = parseProject(remaining);
  let projectName: string | null = null;
  if (projResult) {
    projectName = projResult.projectName;
    allMatches.push({ index: projResult.index, length: projResult.matchedText.length, text: projResult.matchedText, type: 'project' });
    remaining = removeMatch(remaining, projResult.matchedText);
  }

  // Labels
  const labelResults = parseLabels(remaining);
  const labels: string[] = [];
  for (const lr of labelResults) {
    labels.push(lr.label);
    allMatches.push({ index: lr.index, length: lr.matchedText.length, text: lr.matchedText, type: 'label' });
    remaining = removeMatch(remaining, lr.matchedText);
  }

  // Clean up title
  const title = remaining.trim().replace(/\s+/g, ' ');

  // Build segments from original input for highlighting
  const segments = buildSegments(input, language);

  return {
    title,
    dueDate,
    dueTime,
    priority,
    projectName,
    labels,
    detectedLanguage: language,
    segments,
  };
}

// ---------------------------------------------------------------------------
// Build segments for real-time highlighting (operates on original input)
// ---------------------------------------------------------------------------

interface MatchInfo {
  start: number;
  end: number;
  text: string;
  type: SegmentType;
}

function buildSegments(input: string, language: DetectedLanguage): ParsedSegment[] {
  const lower = input.toLowerCase();
  const matches: MatchInfo[] = [];

  // Priority
  const excl = /!!([1-4])/.exec(input);
  if (excl) {
    matches.push({ start: excl.index, end: excl.index + excl[0].length, text: excl[0], type: 'priority' });
  } else {
    const p = /\bp([1-4])\b/i.exec(input);
    if (p) {
      matches.push({ start: p.index, end: p.index + p[0].length, text: p[0], type: 'priority' });
    }
  }

  // Date - relative
  const relativeMap: Record<string, number> = language === 'german'
    ? { heute: 0, morgen: 1, übermorgen: 2 }
    : { today: 0, tod: 0, tomorrow: 1, tom: 1 };

  let dateFound = false;
  for (const keyword of Object.keys(relativeMap)) {
    const re = new RegExp(`\\b${keyword}\\b`, 'i');
    const m = re.exec(lower);
    if (m) {
      matches.push({ start: m.index, end: m.index + m[0].length, text: input.slice(m.index, m.index + m[0].length), type: 'date' });
      dateFound = true;
      break;
    }
  }

  // "next week" / "nächste woche"
  if (!dateFound) {
    const nwRe = language === 'german' ? /\bnächste\s+woche\b/i : /\bnext\s+week\b/i;
    const nwM = nwRe.exec(lower);
    if (nwM) {
      matches.push({ start: nwM.index, end: nwM.index + nwM[0].length, text: input.slice(nwM.index, nwM.index + nwM[0].length), type: 'date' });
      dateFound = true;
    }
  }

  // Day shortcuts
  if (!dateFound) {
    const shortcuts = language === 'german' ? GERMAN_DAY_SHORTCUTS : ENGLISH_DAY_SHORTCUTS;
    const sorted = Object.keys(shortcuts).sort((a, b) => b.length - a.length);
    for (const keyword of sorted) {
      const re = dayBoundaryRegex(keyword);
      const m = re.exec(lower);
      if (m) {
        matches.push({ start: m.index, end: m.index + m[0].length, text: input.slice(m.index, m.index + m[0].length), type: 'date' });
        dateFound = true;
        break;
      }
    }
  }

  // Explicit dates
  if (!dateFound) {
    if (language === 'german') {
      const gm = /\b(\d{1,2})\.(\d{1,2})(?:\.(\d{2,4}))?\b/.exec(input);
      if (gm) {
        matches.push({ start: gm.index, end: gm.index + gm[0].length, text: gm[0], type: 'date' });
      }
    } else {
      const um = /\b(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?\b/.exec(input);
      if (um) {
        matches.push({ start: um.index, end: um.index + um[0].length, text: um[0], type: 'date' });
      }
    }
  }

  // Time
  const timeRe = /\b(\d{1,2})(?::(\d{2}))?\s*(uhr|am|pm)\b/i;
  const colonTimeRe = /\b(\d{1,2}):(\d{2})\b/;
  let tm = timeRe.exec(lower);
  if (!tm) tm = colonTimeRe.exec(input);
  if (tm) {
    // Make sure we don't overlap with a date match
    const overlaps = matches.some(
      (mx) => tm!.index >= mx.start && tm!.index < mx.end
    );
    if (!overlaps) {
      matches.push({ start: tm.index, end: tm.index + tm[0].length, text: input.slice(tm.index, tm.index + tm[0].length), type: 'time' });
    }
  }

  // Project
  const projRe = /#(?:"([^"]+)"|(\S+))/;
  const projM = projRe.exec(input);
  if (projM) {
    matches.push({ start: projM.index, end: projM.index + projM[0].length, text: projM[0], type: 'project' });
  }

  // Labels
  const labelRe = /@(\S+)/g;
  let lm: RegExpExecArray | null;
  while ((lm = labelRe.exec(input)) !== null) {
    matches.push({ start: lm.index, end: lm.index + lm[0].length, text: lm[0], type: 'label' });
  }

  // Sort by position, remove overlaps
  matches.sort((a, b) => a.start - b.start);
  const filtered: MatchInfo[] = [];
  for (const match of matches) {
    if (filtered.length === 0 || match.start >= filtered[filtered.length - 1].end) {
      filtered.push(match);
    }
  }

  // Build segment list
  const segments: ParsedSegment[] = [];
  let pos = 0;
  for (const match of filtered) {
    if (match.start > pos) {
      segments.push({ text: input.slice(pos, match.start), type: 'text' });
    }
    segments.push({ text: match.text, type: match.type });
    pos = match.end;
  }
  if (pos < input.length) {
    segments.push({ text: input.slice(pos), type: 'text' });
  }

  return segments;
}
