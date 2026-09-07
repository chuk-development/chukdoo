import React, { useState } from 'react';
import { store } from '../store/store';
import { useStoreState } from '../store/hooks';
import { TaskInputForm } from './TaskInputForm';
import { formatDueDate, getDueDateClass } from '../utils';
import { Button } from './ui/button';
import { Card, CardContent } from './ui/card';
import { Badge } from './ui/badge';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { cn } from '../lib/utils';
import type { Todo } from '../types';
import {
  ClipboardList,
  Hammer,
  CheckCircle2,
  Calendar,
  CheckSquare,
  ArrowRight,
} from 'lucide-react';

const COLUMNS = [
  { key: 'todo' as const, label: 'Zu erledigen', icon: ClipboardList },
  { key: 'in_progress' as const, label: 'In Arbeit', icon: Hammer },
  { key: 'done' as const, label: 'Erledigt', icon: CheckCircle2 },
];

export function KanbanView() {
  useStoreState();
  const [filterProjectId, setFilterProjectId] = useState<string | null>(null);
  const [editingTodoId, setEditingTodoId] = useState<string | null>(null);

  const projects = store.getUserProjects();

  const allTodos = store.todos.filter(t => {
    if (filterProjectId) {
      if (filterProjectId === 'inbox') return !t.projectId;
      return t.projectId === filterProjectId;
    }
    return true;
  });

  const getColumnTodos = (status: 'todo' | 'in_progress' | 'done') => {
    return allTodos.filter(t => {
      const todoStatus = t.status ?? (t.isCompleted ? 'done' : 'todo');
      if (status === 'done') return todoStatus === 'done' || t.isCompleted;
      if (status === 'todo') return todoStatus === 'todo' && !t.isCompleted;
      return todoStatus === status && !t.isCompleted;
    }).sort((a, b) => (b.createdAt ?? '').localeCompare(a.createdAt ?? ''));
  };

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 border-b border-border">
        <h1 className="text-xl font-bold">Kanban Board</h1>
        <Select value={filterProjectId ?? '__all__'} onValueChange={v => setFilterProjectId(v === '__all__' ? null : v)}>
          <SelectTrigger className="w-48">
            <SelectValue placeholder="Alle Projekte" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="__all__">Alle Projekte</SelectItem>
            <SelectItem value="inbox">Eingang</SelectItem>
            {projects.map(p => (
              <SelectItem key={p.id} value={p.id}>{p.name}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* Board */}
      <div className="flex-1 flex gap-4 p-6 overflow-x-auto">
        {COLUMNS.map(col => {
          const todos = getColumnTodos(col.key);
          const Icon = col.icon;
          return (
            <div key={col.key} className="flex flex-col w-80 min-w-[320px] shrink-0">
              {/* Column header */}
              <div className="flex items-center gap-2 px-2 py-2 mb-3">
                <Icon className="h-4 w-4 text-muted-foreground" />
                <span className="text-sm font-semibold">{col.label}</span>
                <Badge variant="secondary" className="text-[10px] px-1.5 h-5 ml-auto">
                  {todos.length}
                </Badge>
              </div>

              {/* Column body - drop target */}
              <KanbanDropZone status={col.key}>
                {todos.map(todo => (
                    <KanbanCard
                      key={todo.id}
                      todo={todo}
                      onEdit={() => setEditingTodoId(todo.id)}
                      currentStatus={todo.status ?? (todo.isCompleted ? 'done' : 'todo')}
                    />
                ))}
              </KanbanDropZone>
            </div>
          );
        })}
      </div>

      {/* Edit dialog - renders as overlay instead of inline */}
      {editingTodoId && (() => {
        const editTodo = store.todos.find(t => t.id === editingTodoId);
        if (!editTodo) return null;
        return (
          <div
            className="fixed inset-0 z-50 bg-black/50 flex items-start justify-center pt-[10vh]"
            onClick={() => setEditingTodoId(null)}
          >
            <div className="w-full max-w-lg" onClick={e => e.stopPropagation()}>
              <TaskInputForm
                editTodo={editTodo}
                onClose={() => setEditingTodoId(null)}
                onSave={(data) => {
                  store.updateTodo(editingTodoId, data);
                  setEditingTodoId(null);
                }}
              />
            </div>
          </div>
        );
      })()}
    </div>
  );
}

function KanbanDropZone({ status, children }: { status: string; children: React.ReactNode }) {
  const [dragOver, setDragOver] = React.useState(false);
  return (
    <div
      className={cn(
        "flex-1 space-y-2 overflow-y-auto rounded-lg p-1 transition-colors min-h-[100px]",
        dragOver && "bg-primary/10 ring-2 ring-primary/40"
      )}
      onDragOver={(e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        setDragOver(true);
      }}
      onDragLeave={() => setDragOver(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDragOver(false);
        const todoId = e.dataTransfer.getData('text/plain');
        if (todoId) {
          store.moveTodoStatus(todoId, status as 'todo' | 'in_progress' | 'done');
        }
      }}
    >
      {children}
    </div>
  );
}

function KanbanCard({ todo, onEdit, currentStatus }: {
  todo: Todo;
  onEdit: () => void;
  currentStatus: 'todo' | 'in_progress' | 'done';
}) {
  const project = todo.projectId ? store.getProjectById(todo.projectId) : null;
  const subtasks = todo.subtasks ?? [];
  const completedSubtasks = subtasks.filter(s => s.isCompleted).length;
  const totalSubtasks = subtasks.length;

  const moveOptions = COLUMNS.filter(c => c.key !== currentStatus);

  const priorityBorder = () => {
    const p = typeof todo.priority === 'number' ? `p${todo.priority}` : String(todo.priority ?? 'p4');
    switch (p) {
      case 'p1': return 'border-l-p1';
      case 'p2': return 'border-l-p2';
      case 'p3': return 'border-l-p3';
      default: return 'border-l-transparent';
    }
  };

  const dueDateColor = () => {
    if (!todo.dueDate) return '';
    const cls = getDueDateClass(todo.dueDate);
    switch (cls) {
      case 'overdue': return 'text-destructive';
      case 'today': return 'text-primary';
      default: return 'text-muted-foreground';
    }
  };

  return (
    <Card
      className={cn("border-l-[3px] cursor-pointer hover:bg-accent/30 transition-colors", priorityBorder())}
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
      <CardContent className="p-3">
        <div className="text-sm font-medium mb-1">{todo.title}</div>
        {todo.description && (
          <div className="text-xs text-muted-foreground mb-2 line-clamp-2">{todo.description}</div>
        )}
        <div className="flex items-center gap-2 flex-wrap text-xs">
          {todo.dueDate && (
            <span className={cn("flex items-center gap-1", dueDateColor())}>
              <Calendar className="h-3 w-3" />
              {formatDueDate(todo.dueDate, todo.dueTime)}
            </span>
          )}
          {totalSubtasks > 0 && (
            <span className="flex items-center gap-1 text-muted-foreground">
              <CheckSquare className="h-3 w-3" />
              {completedSubtasks}/{totalSubtasks}
            </span>
          )}
          {project && (
            <span className="flex items-center gap-1 text-muted-foreground">
              <span className="w-1.5 h-1.5 rounded-sm" style={{ background: project.color }} />
              {project.name}
            </span>
          )}
        </div>

        {/* Move actions */}
        <div className="flex gap-1 mt-2 pt-2 border-t border-border/50" onClick={e => e.stopPropagation()}>
          {moveOptions.map(opt => {
            const Icon = opt.icon;
            return (
              <Button
                key={opt.key}
                variant="ghost"
                size="sm"
                className="h-6 text-[10px] gap-1 text-muted-foreground flex-1"
                title={`Nach "${opt.label}" verschieben`}
                onClick={() => store.moveTodoStatus(todo.id, opt.key)}
              >
                <Icon className="h-3 w-3" />
                {opt.label}
              </Button>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}
