import React, { useState, useEffect } from 'react';
import { store } from '../store/store';
import { TodoItem } from './TodoItem';
import { TaskInputForm } from './TaskInputForm';
import { Button } from './ui/button';
import type { Todo } from '../types';
import { Plus, CheckCircle2, ClipboardList } from 'lucide-react';

interface Props {
  todos: Todo[];
  showProjectTag?: boolean;
  defaultProjectId?: string | null;
  isCompletedView?: boolean;
}

export function TodoList({ todos, showProjectTag, defaultProjectId, isCompletedView }: Props) {
  const [showInput, setShowInput] = useState(false);
  const [editingTodo, setEditingTodo] = useState<string | null>(null);

  useEffect(() => {
    const handler = () => setShowInput(true);
    window.addEventListener('chukdoo:add-task', handler);
    return () => window.removeEventListener('chukdoo:add-task', handler);
  }, []);

  if (isCompletedView) {
    return (
      <div className="space-y-0">
        {todos.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-muted-foreground">
            <CheckCircle2 className="h-12 w-12 mb-3 opacity-30" />
            <div className="text-sm font-medium">Keine erledigten Aufgaben</div>
          </div>
        ) : (
          todos.map(todo => (
            <TodoItem
              key={todo.id}
              todo={todo}
              showProjectTag={true}
              onEdit={() => setEditingTodo(todo.id)}
            />
          ))
        )}
      </div>
    );
  }

  const sorted = [...todos].sort((a, b) => a.sortOrder - b.sortOrder);

  return (
    <div className="space-y-0">
      {sorted.map(todo => (
        editingTodo === todo.id ? (
          <TaskInputForm
            key={todo.id}
            editTodo={todo}
            defaultProjectId={defaultProjectId}
            onClose={() => setEditingTodo(null)}
            onSave={(data) => {
              store.updateTodo(todo.id, data);
              setEditingTodo(null);
            }}
          />
        ) : (
          <TodoItem
            key={todo.id}
            todo={todo}
            showProjectTag={showProjectTag}
            onEdit={() => setEditingTodo(todo.id)}
          />
        )
      ))}

      {showInput ? (
        <TaskInputForm
          defaultProjectId={defaultProjectId}
          onClose={() => setShowInput(false)}
          onSave={(data) => {
            store.addTodo(data);
            // keep input open for quick adding
          }}
        />
      ) : (
        <button
          className="flex items-center gap-2 w-full px-2 py-2.5 text-sm text-muted-foreground hover:text-primary transition-colors cursor-pointer rounded-md"
          onClick={() => setShowInput(true)}
        >
          <Plus className="h-4 w-4" />
          Aufgabe hinzufugen
        </button>
      )}

      {sorted.length === 0 && !showInput && (
        <div className="flex flex-col items-center justify-center py-16 text-muted-foreground">
          <ClipboardList className="h-12 w-12 mb-3 opacity-30" />
          <div className="text-sm font-medium">Alles erledigt!</div>
          <div className="text-xs mt-1">Fuge eine Aufgabe hinzu um loszulegen</div>
        </div>
      )}
    </div>
  );
}
