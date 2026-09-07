import React, { useState, useRef, useEffect, useMemo } from 'react';
import { store } from '../store/store';
import type { Priority, Todo, Subtask } from '../types';
import { getTodayStr, getTomorrowStr, getNextWeekStr } from '../utils';
import { v4 as uuid } from 'uuid';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Textarea } from './ui/textarea';
import { Card } from './ui/card';
import { Separator } from './ui/separator';
import { Badge } from './ui/badge';
import { Popover, PopoverContent, PopoverTrigger } from './ui/popover';
import { cn } from '../lib/utils';
import { parseNaturalLanguage, type ParseResult, type ParsedSegment } from '../lib/nlp-parser';
import {
  Calendar,
  Sun,
  CalendarRange,
  Flag,
  Bell,
  MoreHorizontal,
  Inbox,
  ChevronDown,
  Plus,
  X,
  Check,
  CheckSquare,
  Sparkles,
  Clock,
  Hash,
  Tag,
} from 'lucide-react';

interface Props {
  defaultProjectId?: string | null;
  editTodo?: Todo;
  onClose: () => void;
  onSave: (data: {
    title: string;
    description?: string;
    projectId?: string | null;
    priority?: Priority;
    dueDate?: string | null;
    dueTime?: string | null;
    subtasks?: Subtask[];
  }) => void;
}

function normalizePriority(p: any): Priority {
  if (typeof p === 'number') return `p${p}` as Priority;
  if (typeof p === 'string' && /^p[1-4]$/.test(p)) return p as Priority;
  return 'p4';
}

export function TaskInputForm({ defaultProjectId, editTodo, onClose, onSave }: Props) {
  const [rawInput, setRawInput] = useState(editTodo?.title ?? '');
  const [description, setDescription] = useState(editTodo?.description ?? '');
  const [priority, setPriority] = useState<Priority>(normalizePriority(editTodo?.priority));
  const [dueDate, setDueDate] = useState<string | null>(editTodo?.dueDate ?? null);
  const [dueTime, setDueTime] = useState<string | null>(editTodo?.dueTime ?? null);
  const [projectId, setProjectId] = useState<string | null>(editTodo?.projectId ?? defaultProjectId ?? null);

  // Track which fields the user has manually set (override NLP)
  const [manualOverrides, setManualOverrides] = useState<Set<string>>(
    () => new Set(editTodo ? ['priority', 'dueDate', 'dueTime', 'project'] : [])
  );

  const [subtasks, setSubtasks] = useState<Subtask[]>(editTodo?.subtasks ?? []);
  const [newSubtaskTitle, setNewSubtaskTitle] = useState('');
  const [showSubtasks, setShowSubtasks] = useState((editTodo?.subtasks ?? []).length > 0);

  const titleRef = useRef<HTMLInputElement>(null);

  // Parse input on every keystroke
  const parseResult = useMemo(() => parseNaturalLanguage(rawInput), [rawInput]);

  // Apply NLP results to form fields (only for non-overridden fields)
  useEffect(() => {
    if (editTodo) return; // Don't auto-parse when editing

    if (!manualOverrides.has('priority') && parseResult.priority) {
      setPriority(parseResult.priority);
    }
    if (!manualOverrides.has('dueDate') && parseResult.dueDate) {
      setDueDate(parseResult.dueDate);
    }
    if (!manualOverrides.has('dueTime') && parseResult.dueTime) {
      setDueTime(parseResult.dueTime);
    }
    if (!manualOverrides.has('project') && parseResult.projectName) {
      // Try to match project name to existing project
      const projects = store.getUserProjects();
      const match = projects.find(
        (p) => p.name.toLowerCase() === parseResult.projectName!.toLowerCase()
      );
      if (match) {
        setProjectId(match.id);
      }
    }
  }, [parseResult, manualOverrides, editTodo]);

  // When NLP tokens are cleared from input, reset the corresponding fields
  useEffect(() => {
    if (editTodo) return;
    if (!manualOverrides.has('priority') && !parseResult.priority) {
      setPriority('p4');
    }
    if (!manualOverrides.has('dueDate') && !parseResult.dueDate) {
      setDueDate(null);
    }
    if (!manualOverrides.has('dueTime') && !parseResult.dueTime) {
      setDueTime(null);
    }
    if (!manualOverrides.has('project') && !parseResult.projectName) {
      setProjectId(defaultProjectId ?? null);
    }
  }, [parseResult, manualOverrides, editTodo, defaultProjectId]);

  useEffect(() => {
    titleRef.current?.focus();
  }, []);

  // Use parsed title (tokens stripped) for submission, raw input for display
  const title = editTodo ? rawInput : (parseResult.title || rawInput);

  const handleSubmit = () => {
    if (!title.trim()) return;
    onSave({
      title: title.trim(),
      description: description.trim() || undefined,
      projectId,
      priority,
      dueDate,
      dueTime,
      subtasks,
    });
    if (!editTodo) {
      setRawInput('');
      setDescription('');
      setDueDate(null);
      setDueTime(null);
      setPriority('p4');
      setProjectId(defaultProjectId ?? null);
      setSubtasks([]);
      setNewSubtaskTitle('');
      setShowSubtasks(false);
      setManualOverrides(new Set());
      titleRef.current?.focus();
    }
  };

  // Manual override helpers
  const handleManualPriority = (p: Priority) => {
    setPriority(p);
    setManualOverrides((prev) => new Set(prev).add('priority'));
  };
  const handleManualDueDate = (d: string | null) => {
    setDueDate(d);
    setManualOverrides((prev) => new Set(prev).add('dueDate'));
  };
  const handleManualDueTime = (t: string | null) => {
    setDueTime(t);
    setManualOverrides((prev) => new Set(prev).add('dueTime'));
  };
  const handleManualProject = (id: string | null) => {
    setProjectId(id);
    setManualOverrides((prev) => new Set(prev).add('project'));
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
    if (e.key === 'Escape') {
      onClose();
    }
  };

  const selectedProject = projectId ? store.getProjectById(projectId) : null;
  const projectName = selectedProject ? selectedProject.name : 'Eingang';

  const priorityColor = (p: Priority) => {
    switch (p) {
      case 'p1': return 'text-p1';
      case 'p2': return 'text-p2';
      case 'p3': return 'text-p3';
      default: return 'text-muted-foreground';
    }
  };

  return (
    <Card className="my-2 overflow-hidden">
      <div className="p-3 space-y-2">
        {/* Title */}
        <Input
          ref={titleRef}
          className="border-0 px-0 h-auto text-sm font-medium focus-visible:ring-0 shadow-none"
          placeholder={editTodo ? 'Aufgabe bearbeiten' : 'Aufgabename (z.B. "Milch kaufen mi 15:00 !!2 #einkauf")'}
          value={rawInput}
          onChange={e => setRawInput(e.target.value)}
          onKeyDown={handleKeyDown}
        />

        {/* NLP detected tokens badges */}
        {!editTodo && parseResult.segments.some((s) => s.type !== 'text') && (
          <div className="flex items-center gap-1 flex-wrap">
            <Sparkles className="h-3 w-3 text-muted-foreground" />
            {parseResult.segments.filter((s) => s.type !== 'text').map((seg, i) => (
              <Badge
                key={i}
                variant="secondary"
                className={cn(
                  "text-[10px] h-5 gap-0.5",
                  seg.type === 'date' && "bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300",
                  seg.type === 'time' && "bg-cyan-100 text-cyan-700 dark:bg-cyan-900 dark:text-cyan-300",
                  seg.type === 'priority' && "bg-orange-100 text-orange-700 dark:bg-orange-900 dark:text-orange-300",
                  seg.type === 'project' && "bg-purple-100 text-purple-700 dark:bg-purple-900 dark:text-purple-300",
                  seg.type === 'label' && "bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300",
                )}
              >
                {seg.type === 'date' && <Calendar className="h-2.5 w-2.5" />}
                {seg.type === 'time' && <Clock className="h-2.5 w-2.5" />}
                {seg.type === 'priority' && <Flag className="h-2.5 w-2.5" />}
                {seg.type === 'project' && <Hash className="h-2.5 w-2.5" />}
                {seg.type === 'label' && <Tag className="h-2.5 w-2.5" />}
                {seg.text}
              </Badge>
            ))}
          </div>
        )}
        {/* Description */}
        <Textarea
          className="border-0 px-0 min-h-0 text-xs focus-visible:ring-0 shadow-none resize-none"
          placeholder="Beschreibung"
          value={description}
          onChange={e => setDescription(e.target.value)}
          rows={1}
        />

        {/* Subtask toggle */}
        <Button
          variant="ghost"
          size="sm"
          className="h-7 text-xs text-muted-foreground gap-1"
          onClick={() => setShowSubtasks(!showSubtasks)}
        >
          <CheckSquare className="h-3 w-3" />
          Teilaufgaben {subtasks.length > 0 ? `(${subtasks.filter(s => s.isCompleted).length}/${subtasks.length})` : ''}
        </Button>

        {/* Subtasks */}
        {showSubtasks && (
          <div className="space-y-1 pl-1">
            {subtasks.map(st => (
              <div key={st.id} className="flex items-center gap-2 group">
                <button
                  className={cn(
                    "flex items-center justify-center w-4 h-4 rounded border border-muted-foreground shrink-0 cursor-pointer transition-colors",
                    st.isCompleted && "bg-primary border-primary text-primary-foreground"
                  )}
                  onClick={() => {
                    setSubtasks(prev => prev.map(s => s.id === st.id ? { ...s, isCompleted: !s.isCompleted } : s));
                  }}
                >
                  {st.isCompleted && <Check className="h-2.5 w-2.5" />}
                </button>
                <span className={cn("text-xs flex-1", st.isCompleted && "line-through text-muted-foreground")}>
                  {st.title}
                </span>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-5 w-5 opacity-0 group-hover:opacity-100"
                  onClick={() => setSubtasks(prev => prev.filter(s => s.id !== st.id))}
                >
                  <X className="h-3 w-3" />
                </Button>
              </div>
            ))}
            <div className="flex items-center gap-2">
              <Input
                className="h-7 text-xs flex-1"
                placeholder="Teilaufgabe hinzufugen..."
                value={newSubtaskTitle}
                onChange={e => setNewSubtaskTitle(e.target.value)}
                onKeyDown={e => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    e.stopPropagation();
                    if (newSubtaskTitle.trim()) {
                      setSubtasks(prev => [...prev, { id: uuid(), title: newSubtaskTitle.trim(), isCompleted: false }]);
                      setNewSubtaskTitle('');
                    }
                  }
                }}
              />
              <Button
                variant="ghost"
                size="icon"
                className="h-7 w-7"
                onClick={() => {
                  if (newSubtaskTitle.trim()) {
                    setSubtasks(prev => [...prev, { id: uuid(), title: newSubtaskTitle.trim(), isCompleted: false }]);
                    setNewSubtaskTitle('');
                  }
                }}
              >
                <Plus className="h-3.5 w-3.5" />
              </Button>
            </div>
          </div>
        )}
      </div>

      {/* Chips row */}
      <div className="flex items-center gap-1 px-3 pb-2 flex-wrap">
        {/* Date picker */}
        <Popover>
          <PopoverTrigger asChild>
            <Button
              variant="outline"
              size="sm"
              className={cn("h-7 text-xs gap-1", dueDate && "border-primary text-primary")}
            >
              <Calendar className="h-3 w-3" />
              {dueDate ? formatChipDate(dueDate) : 'Datum'}
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-56 p-1" align="start">
            <button className="flex items-center gap-2 w-full px-3 py-2 text-sm rounded-md hover:bg-accent cursor-pointer" onClick={() => handleManualDueDate(getTodayStr())}>
              <Calendar className="h-4 w-4 text-primary" /> Heute
            </button>
            <button className="flex items-center gap-2 w-full px-3 py-2 text-sm rounded-md hover:bg-accent cursor-pointer" onClick={() => handleManualDueDate(getTomorrowStr())}>
              <Sun className="h-4 w-4 text-p2" /> Morgen
            </button>
            <button className="flex items-center gap-2 w-full px-3 py-2 text-sm rounded-md hover:bg-accent cursor-pointer" onClick={() => handleManualDueDate(getNextWeekStr())}>
              <CalendarRange className="h-4 w-4 text-p3" /> Nachste Woche
            </button>
            <Separator className="my-1" />
            <div className="px-3 py-2">
              <input
                type="date"
                value={dueDate ?? ''}
                onChange={e => handleManualDueDate(e.target.value || null)}
                className="w-full bg-transparent border border-input rounded-md text-sm px-2 py-1 text-foreground"
              />
            </div>
            {dueDate && (
              <>
                <Separator className="my-1" />
                <button className="flex items-center gap-2 w-full px-3 py-2 text-sm text-destructive rounded-md hover:bg-accent cursor-pointer" onClick={() => { handleManualDueDate(null); handleManualDueTime(null); }}>
                  <X className="h-4 w-4" /> Datum entfernen
                </button>
              </>
            )}
          </PopoverContent>
        </Popover>

        {/* Priority picker */}
        <Popover>
          <PopoverTrigger asChild>
            <Button
              variant="outline"
              size="sm"
              className={cn("h-7 text-xs gap-1", priority !== 'p4' && priorityColor(priority))}
              style={priority !== 'p4' ? { borderColor: `var(--color-${priority})` } : undefined}
            >
              <Flag className="h-3 w-3" />
              {priority !== 'p4' ? `P${priority.slice(1)}` : 'Prioritat'}
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-48 p-1" align="start">
            {(['p1', 'p2', 'p3', 'p4'] as Priority[]).map(p => (
              <button
                key={p}
                className="flex items-center gap-2 w-full px-3 py-2 text-sm rounded-md hover:bg-accent cursor-pointer"
                onClick={() => handleManualPriority(p)}
              >
                <Flag className={cn("h-4 w-4", priorityColor(p))} />
                Prioritat {p.slice(1)}
                {p === priority && <Check className="h-4 w-4 ml-auto" />}
              </button>
            ))}
          </PopoverContent>
        </Popover>

        {/* Reminders (placeholder) */}
        <Button variant="outline" size="sm" className="h-7 text-xs gap-1 text-muted-foreground">
          <Bell className="h-3 w-3" /> Erinnerungen
        </Button>

        {/* More */}
        <Button variant="outline" size="sm" className="h-7 text-xs text-muted-foreground">
          <MoreHorizontal className="h-3 w-3" />
        </Button>
      </div>

      <Separator />

      {/* Bottom bar */}
      <div className="flex items-center justify-between px-3 py-2">
        {/* Project selector */}
        <Popover>
          <PopoverTrigger asChild>
            <Button variant="ghost" size="sm" className="h-7 text-xs gap-1 text-muted-foreground">
              {selectedProject && !selectedProject.isInbox ? (
                <span className="w-2 h-2 rounded-sm" style={{ background: selectedProject.color }} />
              ) : (
                <Inbox className="h-3 w-3" />
              )}
              {projectName}
              <ChevronDown className="h-3 w-3" />
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-48 p-1" align="start" side="top">
            <button
              className="flex items-center gap-2 w-full px-3 py-2 text-sm rounded-md hover:bg-accent cursor-pointer"
              onClick={() => handleManualProject(null)}
            >
              <Inbox className="h-4 w-4" /> Eingang
              {!projectId && <Check className="h-4 w-4 ml-auto" />}
            </button>
            <Separator className="my-1" />
            {store.getUserProjects().map(p => (
              <button
                key={p.id}
                className="flex items-center gap-2 w-full px-3 py-2 text-sm rounded-md hover:bg-accent cursor-pointer"
                onClick={() => handleManualProject(p.id)}
              >
                <span className="w-2.5 h-2.5 rounded-sm" style={{ background: p.color }} />
                {p.name}
                {projectId === p.id && <Check className="h-4 w-4 ml-auto" />}
              </button>
            ))}
          </PopoverContent>
        </Popover>

        <div className="flex items-center gap-2">
          <Button variant="ghost" size="sm" className="h-7 text-xs" onClick={onClose}>
            Abbrechen
          </Button>
          <Button
            size="sm"
            className="h-7 text-xs"
            onClick={handleSubmit}
            disabled={!title.trim()}
          >
            {editTodo ? 'Speichern' : 'Aufgabe hinzufugen'}
          </Button>
        </div>
      </div>
    </Card>
  );
}

function formatChipDate(dateStr: string): string {
  const d = new Date(dateStr + 'T00:00:00');
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const diff = Math.round((d.getTime() - today.getTime()) / 86400000);
  if (diff === 0) return 'Heute';
  if (diff === 1) return 'Morgen';
  if (diff === -1) return 'Gestern';
  const days = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];
  return `${d.getDate()}. ${['Jan', 'Feb', 'Mar', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'][d.getMonth()]} (${days[d.getDay()]})`;
}
