import React, { useState, useEffect, useRef } from 'react';
import { store } from '../store/store';
import type { Todo } from '../types';
import { formatDueDate, getDueDateClass } from '../utils';
import { Button } from './ui/button';
import { Progress } from './ui/progress';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from './ui/dropdown-menu';
import { cn } from '../lib/utils';
import { Calendar, Pencil, Trash2, CheckSquare, Check, FolderInput, Inbox, GripVertical } from 'lucide-react';

interface Props {
  todo: Todo;
  showProjectTag?: boolean;
  onEdit: () => void;
}

function normalizePriority(p: any): string {
  if (typeof p === 'number') return `p${p}`;
  return String(p ?? 'p4');
}

function getPriorityBorderColor(priority: any): string {
  const p = normalizePriority(priority);
  switch (p) {
    case 'p1': return 'border-p1 text-p1';
    case 'p2': return 'border-p2 text-p2';
    case 'p3': return 'border-p3 text-p3';
    default: return 'border-muted-foreground text-muted-foreground';
  }
}

function getDueDateColorClass(dueDateClass: string): string {
  switch (dueDateClass) {
    case 'overdue': return 'text-destructive';
    case 'today': return 'text-primary';
    default: return 'text-muted-foreground';
  }
}

export function TodoItem({ todo, showProjectTag, onEdit }: Props) {
  const project = todo.projectId ? store.getProjectById(todo.projectId) : null;
  const subtasks = todo.subtasks ?? [];
  const completedSubtasks = subtasks.filter(s => s.isCompleted).length;
  const totalSubtasks = subtasks.length;
  const projects = store.getUserProjects();
  const hasMeta = !!(todo.dueDate || totalSubtasks > 0 || (showProjectTag && project));

  const isHighlighted = store.highlightedTodoId === todo.id;
  const rowRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (isHighlighted && rowRef.current) {
      rowRef.current.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  }, [isHighlighted]);

  return (
    <div
      ref={rowRef}
      className={cn(
        "group flex items-center gap-3 px-2 py-2.5 rounded-md hover:bg-card/60 cursor-pointer transition-all border-b border-border/50",
        isHighlighted && "bg-primary/15 ring-1 ring-primary/40 animate-[pulse-highlight_2s_ease-out]"
      )}
      onClick={onEdit}
      draggable
      onDragStart={(e) => {
        e.dataTransfer.setData('text/plain', todo.id);
        e.dataTransfer.effectAllowed = 'move';
        (e.currentTarget as HTMLElement).style.opacity = '0.4';
      }}
      onDragEnd={(e) => {
        (e.currentTarget as HTMLElement).style.opacity = '1';
      }}
    >
      {/* Drag handle - visible on hover */}
      <GripVertical className="h-3.5 w-3.5 text-muted-foreground/0 group-hover:text-muted-foreground/40 shrink-0 cursor-grab transition-colors" />

      {/* Checkbox */}
      <button
        className={cn(
          "flex items-center justify-center w-[18px] h-[18px] rounded-full border-2 shrink-0 transition-all cursor-pointer",
          todo.isCompleted
            ? "bg-primary border-primary text-primary-foreground"
            : getPriorityBorderColor(todo.priority),
          !todo.isCompleted && "hover:bg-accent"
        )}
        onClick={(e) => {
          e.stopPropagation();
          store.toggleTodo(todo.id);
        }}
      >
        {todo.isCompleted && <Check className="h-3 w-3" />}
      </button>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <div className={cn("text-sm leading-5", todo.isCompleted && "line-through text-muted-foreground")}>
          {todo.title}
        </div>
        {todo.description && (
          <div className="text-xs text-muted-foreground mt-0.5 truncate">{todo.description}</div>
        )}
        {hasMeta && (
          <div className="flex items-center gap-2 mt-1 flex-wrap">
            {todo.dueDate && (
              <span className={cn("flex items-center gap-1 text-xs", getDueDateColorClass(getDueDateClass(todo.dueDate)))}>
                <Calendar className="h-3 w-3" />
                {formatDueDate(todo.dueDate, todo.dueTime)}
              </span>
            )}
            {totalSubtasks > 0 && (
              <span className="flex items-center gap-1.5 text-xs text-muted-foreground">
                <CheckSquare className="h-3 w-3" />
                {completedSubtasks}/{totalSubtasks}
                <Progress value={(completedSubtasks / totalSubtasks) * 100} className="w-12 h-1" />
              </span>
            )}
            {showProjectTag && project && (
              <span className="flex items-center gap-1 text-xs text-muted-foreground">
                <span className="w-1.5 h-1.5 rounded-sm" style={{ background: project.color }} />
                {project.name}
              </span>
            )}
          </div>
        )}
      </div>

      {/* Actions */}
      <div className="flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
        {/* Move to project */}
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              size="icon"
              className="h-7 w-7 text-muted-foreground hover:text-foreground"
              onClick={(e) => e.stopPropagation()}
              title="Verschieben"
            >
              <FolderInput className="h-3.5 w-3.5" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-48" onClick={(e) => e.stopPropagation()}>
            <DropdownMenuItem
              className="gap-2 cursor-pointer"
              onClick={() => store.updateTodo(todo.id, { projectId: null })}
            >
              <Inbox className="h-3.5 w-3.5" />
              Eingang
              {!todo.projectId && <Check className="h-3 w-3 ml-auto" />}
            </DropdownMenuItem>
            {projects.length > 0 && <DropdownMenuSeparator />}
            {projects.map(p => (
              <DropdownMenuItem
                key={p.id}
                className="gap-2 cursor-pointer"
                onClick={() => store.updateTodo(todo.id, { projectId: p.id })}
              >
                <span className="w-3 h-3 rounded-sm shrink-0" style={{ background: p.color }} />
                {p.name}
                {todo.projectId === p.id && <Check className="h-3 w-3 ml-auto" />}
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>

        <Button
          variant="ghost"
          size="icon"
          className="h-7 w-7 text-muted-foreground hover:text-foreground"
          onClick={(e) => { e.stopPropagation(); onEdit(); }}
          title="Bearbeiten"
        >
          <Pencil className="h-3.5 w-3.5" />
        </Button>
        <Button
          variant="ghost"
          size="icon"
          className="h-7 w-7 text-muted-foreground hover:text-destructive"
          onClick={(e) => {
            e.stopPropagation();
            store.deleteTodo(todo.id);
          }}
          title="Loschen"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </Button>
      </div>
    </div>
  );
}
