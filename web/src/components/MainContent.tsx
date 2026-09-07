import React from 'react';
import { store } from '../store/store';
import { useStoreState } from '../store/hooks';
import { TodoList } from './TodoList';
import { CalendarView } from './CalendarView';
import { TimerView } from './TimerView';
import { HabitView } from './HabitView';
import { KanbanView } from './KanbanView';
import { Button } from './ui/button';
import { CheckCircle2 } from 'lucide-react';

export function MainContent() {
  useStoreState(); // subscribe to store changes
  const view = store.currentView;
  const projectId = store.currentProjectId;

  // Special views
  if (view === 'calendar') {
    return (
      <main className="flex-1 overflow-y-auto bg-background">
        <CalendarView />
      </main>
    );
  }

  if (view === 'timer') {
    return (
      <main className="flex-1 overflow-y-auto bg-background">
        <TimerView />
      </main>
    );
  }

  if (view === 'habits') {
    return (
      <main className="flex-1 overflow-y-auto bg-background">
        <HabitView />
      </main>
    );
  }

  if (view === 'kanban') {
    return (
      <main className="flex-1 overflow-y-auto bg-background">
        <KanbanView />
      </main>
    );
  }

  const showCompleted = store.showCompleted;

  let title = '';
  let todos: ReturnType<typeof store.getInboxTodos> = [];
  let projectColor: string | undefined;
  let projectDescription: string | undefined;
  let showProjectTag = false;
  let completedTodos: ReturnType<typeof store.getCompletedTodos> = [];

  switch (view) {
    case 'inbox':
      title = 'Eingang';
      todos = store.getInboxTodos();
      if (showCompleted) completedTodos = store.todos.filter(t => t.isCompleted && !t.projectId);
      break;
    case 'today':
      title = 'Heute';
      todos = store.getTodayTodos();
      showProjectTag = true;
      if (showCompleted) {
        const today = new Date().toISOString().split('T')[0]!;
        completedTodos = store.todos.filter(t => t.isCompleted && t.dueDate && t.dueDate <= today);
      }
      break;
    case 'upcoming':
      title = 'Demnachst';
      todos = store.getUpcomingTodos();
      showProjectTag = true;
      break;
    case 'completed':
      title = 'Erledigt';
      todos = store.getCompletedTodos();
      break;
    case 'filters':
      title = 'Filter und Etiketten';
      todos = [];
      break;
    case 'project': {
      const project = projectId ? store.getProjectById(projectId) : null;
      if (project) {
        title = project.name;
        projectColor = project.color;
        projectDescription = project.description;
        todos = store.getProjectTodos(projectId!);
        if (showCompleted) completedTodos = store.todos.filter(t => t.isCompleted && t.projectId === projectId);
      }
      break;
    }
  }

  const isCompletedView = view === 'completed';

  return (
    <main className="flex-1 overflow-y-auto bg-background">
      <div className="max-w-3xl mx-auto px-8 py-8">
        <div className="flex items-center justify-between mb-1">
          <div className="flex items-center gap-2">
            {projectColor && (
              <div className="w-3 h-3 rounded-sm" style={{ background: projectColor }} />
            )}
            <h1 className="text-xl font-bold">{title}</h1>
          </div>
          {!isCompletedView && (
            <div className="flex items-center gap-1">
              <Button
                variant={showCompleted ? "secondary" : "ghost"}
                size="sm"
                className="text-muted-foreground gap-1.5"
                onClick={() => store.toggleShowCompleted()}
                title={showCompleted ? 'Erledigte ausblenden' : 'Erledigte anzeigen'}
              >
                <CheckCircle2 className="h-4 w-4" />
                {showCompleted ? 'Erledigte ausblenden' : 'Erledigte anzeigen'}
              </Button>
            </div>
          )}
        </div>
        {projectDescription && (
          <p className="text-sm text-muted-foreground mb-4">{projectDescription}</p>
        )}
        <TodoList
          todos={todos}
          showProjectTag={showProjectTag}
          defaultProjectId={view === 'project' ? projectId : null}
          isCompletedView={isCompletedView}
        />
        {showCompleted && completedTodos.length > 0 && !isCompletedView && (
          <div className="mt-6">
            <div className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2 px-2">
              Erledigt ({completedTodos.length})
            </div>
            <TodoList
              todos={completedTodos}
              showProjectTag={showProjectTag}
              isCompletedView={true}
            />
          </div>
        )}
      </div>
    </main>
  );
}
