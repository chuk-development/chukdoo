import { format, isToday, isTomorrow, isYesterday, isPast, differenceInDays, parseISO } from 'date-fns';
import { de } from 'date-fns/locale';

export function formatDueDate(dateStr: string, timeStr?: string | null): string {
  const date = parseISO(dateStr);
  let result: string;

  if (isToday(date)) {
    result = 'Heute';
  } else if (isTomorrow(date)) {
    result = 'Morgen';
  } else if (isYesterday(date)) {
    result = 'Gestern';
  } else {
    const diff = differenceInDays(date, new Date());
    if (diff > 0 && diff <= 6) {
      result = format(date, 'EEEE', { locale: de });
    } else {
      result = format(date, 'd. MMM', { locale: de });
    }
  }

  if (timeStr) {
    result += ` ${timeStr}`;
  }

  return result;
}

export function getDueDateClass(dateStr: string): string {
  const date = parseISO(dateStr);
  if (isToday(date)) return 'today';
  if (isPast(date)) return 'overdue';
  return 'upcoming';
}

export function getTodayStr(): string {
  return format(new Date(), 'yyyy-MM-dd');
}

export function getTomorrowStr(): string {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return format(d, 'yyyy-MM-dd');
}

export function getNextWeekStr(): string {
  const d = new Date();
  // next monday
  const day = d.getDay();
  const diff = day === 0 ? 1 : 8 - day;
  d.setDate(d.getDate() + diff);
  return format(d, 'yyyy-MM-dd');
}
