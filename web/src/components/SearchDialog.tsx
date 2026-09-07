import React, { useState, useRef, useEffect, useMemo } from 'react';
import { store } from '../store/store';
import { useStoreState } from '../store/hooks';
import { cn } from '../lib/utils';
import { Search, Calendar, Check, X, Inbox, FolderOpen } from 'lucide-react';
import { formatDueDate, getDueDateClass } from '../utils';
import * as DialogPrimitive from '@radix-ui/react-dialog';

interface Props {
  open: boolean;
  onClose: () => void;
}

export function SearchDialog({ open, onClose }: Props) {
  useStoreState();
  const [query, setQuery] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (open) {
      setQuery('');
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [open]);

  // Keyboard shortcut: Escape closes
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        if (!open) {
          // Can't open from here, but prevent default
        }
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [open]);

  const results = useMemo(() => {
    if (!query.trim()) return [];
    const q = query.toLowerCase();
    return store.todos
      .filter(t => {
        const title = (t.title ?? '').toLowerCase();
        const desc = (t.description ?? '').toLowerCase();
        return title.includes(q) || desc.includes(q);
      })
      .sort((a, b) => {
        if (a.isCompleted !== b.isCompleted) return a.isCompleted ? 1 : -1;
        return (b.createdAt ?? '').localeCompare(a.createdAt ?? '');
      })
      .slice(0, 30);
  }, [query]);

  const handleSelect = (todoId: string) => {
    const todo = store.todos.find(t => t.id === todoId);
    if (!todo) return;
    // Navigate to the right view
    if (todo.projectId) {
      store.setView('project', todo.projectId);
    } else {
      store.setView('inbox');
    }
    onClose();
    // Highlight + scroll after a tick (view needs to render first)
    setTimeout(() => store.highlightTodo(todoId), 100);
  };

  return (
    <DialogPrimitive.Root open={open} onOpenChange={(o) => { if (!o) onClose(); }}>
      <DialogPrimitive.Portal>
        <DialogPrimitive.Overlay className="fixed inset-0 z-50 bg-black/60" />
        <DialogPrimitive.Content className="fixed left-1/2 top-[15%] z-50 w-full max-w-xl -translate-x-1/2 border border-border bg-card shadow-2xl rounded-xl overflow-hidden">
          <DialogPrimitive.Title className="sr-only">Suchen</DialogPrimitive.Title>
          <DialogPrimitive.Description className="sr-only">Aufgaben durchsuchen</DialogPrimitive.Description>

          {/* Search input bar */}
          <div className="flex items-center gap-3 px-4 h-12 border-b border-border">
            <Search className="h-4 w-4 text-muted-foreground shrink-0" />
            <input
              ref={inputRef}
              className="flex-1 bg-transparent border-none outline-none text-sm text-foreground placeholder:text-muted-foreground"
              placeholder="Aufgaben durchsuchen..."
              value={query}
              onChange={e => setQuery(e.target.value)}
              onKeyDown={e => {
                if (e.key === 'Escape') onClose();
              }}
            />
            {query && (
              <>
                <span className="text-xs text-muted-foreground whitespace-nowrap">
                  {results.length} Ergebnis{results.length !== 1 ? 'se' : ''}
                </span>
                <button
                  className="text-muted-foreground hover:text-foreground transition-colors cursor-pointer"
                  onClick={() => setQuery('')}
                >
                  <X className="h-3.5 w-3.5" />
                </button>
              </>
            )}
          </div>

          {/* Results */}
          <div className="max-h-[380px] overflow-y-auto">
            {query.trim() && results.length === 0 && (
              <div className="px-4 py-10 text-center text-sm text-muted-foreground">
                Keine Ergebnisse für "<span className="text-foreground">{query}</span>"
              </div>
            )}

            {results.map(todo => {
              const project = todo.projectId ? store.getProjectById(todo.projectId) : null;
              const p = typeof todo.priority === 'number' ? `p${todo.priority}` : String(todo.priority ?? 'p4');

              return (
                <button
                  key={todo.id}
                  className="w-full flex items-center gap-3 px-4 py-2 hover:bg-accent/50 transition-colors text-left cursor-pointer border-b border-border/30 last:border-b-0"
                  onClick={() => handleSelect(todo.id)}
                >
                  {/* Checkbox */}
                  <div className={cn(
                    "w-4 h-4 rounded-full border-2 shrink-0 flex items-center justify-center",
                    todo.isCompleted
                      ? "bg-primary border-primary"
                      : p === 'p1' ? "border-p1" : p === 'p2' ? "border-p2" : p === 'p3' ? "border-p3" : "border-muted-foreground"
                  )}>
                    {todo.isCompleted && <Check className="h-2.5 w-2.5 text-primary-foreground" />}
                  </div>

                  {/* Content */}
                  <div className="flex-1 min-w-0">
                    <div className={cn("text-sm leading-tight", todo.isCompleted && "line-through text-muted-foreground")}>
                      {highlightMatch(todo.title, query)}
                    </div>
                    {todo.description && (
                      <div className="text-xs text-muted-foreground mt-0.5 truncate">
                        {highlightMatch(todo.description, query)}
                      </div>
                    )}
                  </div>

                  {/* Meta (right side) */}
                  <div className="flex items-center gap-2 shrink-0">
                    {todo.dueDate && (
                      <span className={cn("text-xs flex items-center gap-1",
                        getDueDateClass(todo.dueDate) === 'overdue' ? 'text-destructive' :
                        getDueDateClass(todo.dueDate) === 'today' ? 'text-primary' : 'text-muted-foreground'
                      )}>
                        <Calendar className="h-3 w-3" />
                        {formatDueDate(todo.dueDate, todo.dueTime)}
                      </span>
                    )}
                    {project ? (
                      <span className="text-xs text-muted-foreground flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-sm" style={{ background: project.color }} />
                        {project.name}
                      </span>
                    ) : (
                      <Inbox className="h-3 w-3 text-muted-foreground/50" />
                    )}
                  </div>
                </button>
              );
            })}
          </div>

          {/* Empty state */}
          {!query.trim() && (
            <div className="px-4 py-8 text-center">
              <Search className="h-8 w-8 text-muted-foreground/30 mx-auto mb-2" />
              <div className="text-sm text-muted-foreground">Tippe um Aufgaben zu suchen</div>
              <div className="text-xs text-muted-foreground/60 mt-1">Durchsucht Titel und Beschreibungen</div>
            </div>
          )}

          {/* Footer */}
          <div className="flex items-center justify-between px-4 py-2 border-t border-border text-xs text-muted-foreground/60">
            <span>ESC zum Schließen</span>
            <span>↵ zum Öffnen</span>
          </div>
        </DialogPrimitive.Content>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  );
}

function highlightMatch(text: string, query: string): React.ReactNode {
  if (!query.trim()) return text;
  const idx = text.toLowerCase().indexOf(query.toLowerCase());
  if (idx === -1) return text;
  return (
    <>
      {text.slice(0, idx)}
      <mark className="bg-primary/25 text-primary rounded-[2px] px-[1px]">{text.slice(idx, idx + query.length)}</mark>
      {text.slice(idx + query.length)}
    </>
  );
}
