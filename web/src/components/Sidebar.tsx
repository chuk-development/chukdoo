import React, { useState } from 'react';
import { store } from '../store/store';
import { useStoreState } from '../store/hooks';
import { ProjectDialog } from './ProjectDialog';
import { SearchDialog } from './SearchDialog';
import { Button } from './ui/button';
import { Separator } from './ui/separator';
import { cn } from '../lib/utils';
import {
  Inbox,
  CalendarDays,
  CalendarRange,
  Tag,
  CheckCircle2,
  Calendar,
  Timer,
  Repeat,
  LayoutGrid,
  Plus,
  Search,
  Bell,
  Pencil,
  HelpCircle,
  LogOut,
  RefreshCw,
  Cloud,
  CloudOff,
  Loader2,
  AlertCircle,
  Shield,
} from 'lucide-react';
import { signOut, hasEncryptionKey } from '../lib/auth';
import { isSupabaseAvailable } from '../lib/supabase';
import type { SyncStatus } from '../store/store';

interface SidebarProps {
  userEmail?: string | null;
  onShowAuth?: () => void;
}

export function Sidebar({ userEmail, onShowAuth }: SidebarProps) {
  useStoreState(); // subscribe to store changes
  const [showAddProject, setShowAddProject] = useState(false);
  const [editProject, setEditProject] = useState<string | null>(null);
  const [showSearch, setShowSearch] = useState(false);

  const projects = store.getUserProjects();
  const inboxCount = store.getProjectTaskCount('inbox');
  const todayCount = store.getTodayTodos().length;
  const syncStatus = store.syncStatus;
  const supabaseEnabled = store.isSupabaseEnabled;

  async function handleSignOut() {
    await signOut();
    store.setSupabaseEnabled(false);
    window.location.reload();
  }

  async function handleSync() {
    await store.syncWithSupabase();
  }

  return (
    <aside className="flex flex-col w-[280px] min-w-[280px] h-screen bg-card border-r border-border">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-xs font-bold">
            C
          </div>
          <span className="text-sm font-medium">chuk</span>
        </div>
        <div className="flex items-center gap-1">
          {supabaseEnabled && (
            <SyncIndicator status={syncStatus} onSync={handleSync} />
          )}
          <Button variant="ghost" size="icon" className="h-7 w-7" title="Benachrichtigungen">
            <Bell className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* Actions */}
      <div className="px-3 pb-2 space-y-1">
        <Button
          variant="default"
          size="sm"
          className="w-full justify-start gap-2"
          onClick={() => {
            store.setView(store.currentView);
            window.dispatchEvent(new CustomEvent('chukdoo:add-task'));
          }}
        >
          <Plus className="h-4 w-4" />
          Aufgabe hinzufugen
        </Button>
        <Button variant="ghost" size="sm" className="w-full justify-start gap-2 text-muted-foreground" onClick={() => setShowSearch(true)}>
          <Search className="h-4 w-4" />
          Suchen
        </Button>
      </div>

      <Separator />

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto px-2 py-2 space-y-0.5">
        <NavItem
          icon={<Inbox className="h-4 w-4" />}
          label="Eingang"
          count={inboxCount}
          active={store.currentView === 'inbox'}
          onClick={() => store.setView('inbox')}
          dropTargetId={null}
        />
        <NavItem
          icon={<CalendarDays className="h-4 w-4" />}
          label="Heute"
          count={todayCount}
          active={store.currentView === 'today'}
          onClick={() => store.setView('today')}
          iconClassName="text-success"
        />
        <NavItem
          icon={<CalendarRange className="h-4 w-4" />}
          label="Demnachst"
          active={store.currentView === 'upcoming'}
          onClick={() => store.setView('upcoming')}
          iconClassName="text-p3"
        />
        <NavItem
          icon={<Tag className="h-4 w-4" />}
          label="Filter und Etiketten"
          active={store.currentView === 'filters'}
          onClick={() => store.setView('filters')}
          iconClassName="text-p2"
        />
        <NavItem
          icon={<CheckCircle2 className="h-4 w-4" />}
          label="Erledigt"
          active={store.currentView === 'completed'}
          onClick={() => store.setView('completed')}
        />

        <Separator className="my-2" />

        <NavItem
          icon={<Calendar className="h-4 w-4" />}
          label="Kalender"
          active={store.currentView === 'calendar'}
          onClick={() => store.setView('calendar')}
          iconClassName="text-p3"
        />
        <NavItem
          icon={<Timer className="h-4 w-4" />}
          label="Timer"
          active={store.currentView === 'timer'}
          onClick={() => store.setView('timer')}
          iconClassName="text-primary"
        />
        <NavItem
          icon={<Repeat className="h-4 w-4" />}
          label="Gewohnheiten"
          active={store.currentView === 'habits'}
          onClick={() => store.setView('habits')}
          iconClassName="text-p2"
        />
        <NavItem
          icon={<LayoutGrid className="h-4 w-4" />}
          label="Kanban Board"
          active={store.currentView === 'kanban'}
          onClick={() => store.setView('kanban')}
        />

        <Separator className="my-2" />

        {/* Projects */}
        <div className="pt-1">
          <div className="flex items-center justify-between px-2 mb-1">
            <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Meine Projekte
            </span>
            <Button
              variant="ghost"
              size="icon"
              className="h-5 w-5"
              onClick={() => setShowAddProject(true)}
              title="Projekt hinzufugen"
            >
              <Plus className="h-3 w-3" />
            </Button>
          </div>

          {projects.map(p => (
            <ProjectDropTarget key={p.id} projectId={p.id}>
              <div
                className={cn(
                  "group flex items-center gap-2 px-2 py-1.5 rounded-md text-sm cursor-pointer transition-colors",
                  store.currentView === 'project' && store.currentProjectId === p.id
                    ? "bg-accent text-accent-foreground"
                    : "text-muted-foreground hover:bg-accent/50 hover:text-foreground"
                )}
                onClick={() => store.setView('project', p.id)}
              >
                <div className="w-2 h-2 rounded-sm shrink-0" style={{ background: p.color }} />
                <span className="flex-1 truncate">{p.name}</span>
                <span className="text-xs text-muted-foreground">{store.getProjectTaskCount(p.id)}</span>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-5 w-5 opacity-0 group-hover:opacity-100 transition-opacity"
                  onClick={(e) => { e.stopPropagation(); setEditProject(p.id); }}
                  title="Bearbeiten"
                >
                  <Pencil className="h-3 w-3" />
                </Button>
              </div>
            </ProjectDropTarget>
          ))}
        </div>
      </nav>

      {/* Footer - Auth & Help */}
      <Separator />
      <div className="px-3 py-2 space-y-1">
        {userEmail ? (
          <div className="space-y-1">
            <div className="flex items-center gap-2 px-2 py-1">
              <div className="flex items-center gap-1.5 flex-1 min-w-0">
                <Shield className="h-3.5 w-3.5 text-green-500 shrink-0" />
                <span className="text-xs text-muted-foreground truncate" title={userEmail}>
                  {userEmail}
                </span>
              </div>
              {hasEncryptionKey() && (
                <span className="text-[10px] text-green-600 dark:text-green-400 shrink-0">E2EE</span>
              )}
            </div>
            <Button
              variant="ghost"
              size="sm"
              className="w-full justify-start gap-2 text-muted-foreground text-xs"
              onClick={handleSignOut}
            >
              <LogOut className="h-4 w-4" />
              Abmelden
            </Button>
          </div>
        ) : (
          isSupabaseAvailable() && onShowAuth && (
            <Button
              variant="ghost"
              size="sm"
              className="w-full justify-start gap-2 text-muted-foreground text-xs"
              onClick={onShowAuth}
            >
              <Cloud className="h-4 w-4" />
              Anmelden
            </Button>
          )
        )}
        <Button variant="ghost" size="sm" className="w-full justify-start gap-2 text-muted-foreground text-xs">
          <HelpCircle className="h-4 w-4" />
          Hilfe & Ressourcen
        </Button>
      </div>

      {showAddProject && (
        <ProjectDialog
          onClose={() => setShowAddProject(false)}
          onSave={(data) => {
            store.addProject(data);
            setShowAddProject(false);
          }}
        />
      )}

      {editProject && (
        <ProjectDialog
          project={store.getProjectById(editProject)}
          onClose={() => setEditProject(null)}
          onSave={(data) => {
            store.updateProject(editProject, data);
            setEditProject(null);
          }}
          onDelete={() => {
            store.deleteProject(editProject);
            store.setView('inbox');
            setEditProject(null);
          }}
        />
      )}

      <SearchDialog open={showSearch} onClose={() => setShowSearch(false)} />
    </aside>
  );
}

function SyncIndicator({ status, onSync }: { status: SyncStatus; onSync: () => void }) {
  const iconClass = "h-4 w-4";

  switch (status) {
    case 'syncing':
      return (
        <Button variant="ghost" size="icon" className="h-7 w-7" disabled title="Wird synchronisiert...">
          <Loader2 className={cn(iconClass, "animate-spin text-primary")} />
        </Button>
      );
    case 'error':
      return (
        <Button variant="ghost" size="icon" className="h-7 w-7" onClick={onSync} title="Sync-Fehler - Erneut versuchen">
          <AlertCircle className={cn(iconClass, "text-destructive")} />
        </Button>
      );
    case 'offline':
      return (
        <Button variant="ghost" size="icon" className="h-7 w-7" onClick={onSync} title="Offline - Klicken zum Synchronisieren">
          <CloudOff className={cn(iconClass, "text-muted-foreground")} />
        </Button>
      );
    default:
      return (
        <Button variant="ghost" size="icon" className="h-7 w-7" onClick={onSync} title="Synchronisieren">
          <RefreshCw className={cn(iconClass, "text-muted-foreground")} />
        </Button>
      );
  }
}

function NavItem({ icon, label, count, active, onClick, iconClassName, dropTargetId }: {
  icon: React.ReactNode;
  label: string;
  count?: number;
  active: boolean;
  onClick: () => void;
  iconClassName?: string;
  dropTargetId?: string | null; // null = inbox, undefined = no drop target
}) {
  const [dragOver, setDragOver] = useState(false);

  const handleDragOver = dropTargetId !== undefined ? (e: React.DragEvent) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    setDragOver(true);
  } : undefined;

  const handleDragLeave = dropTargetId !== undefined ? () => setDragOver(false) : undefined;

  const handleDrop = dropTargetId !== undefined ? (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const todoId = e.dataTransfer.getData('text/plain');
    if (todoId) {
      store.updateTodo(todoId, { projectId: dropTargetId });
    }
  } : undefined;

  return (
    <div
      className={cn(
        "flex items-center gap-2 px-2 py-1.5 rounded-md text-sm cursor-pointer transition-colors",
        active
          ? "bg-accent text-accent-foreground"
          : "text-muted-foreground hover:bg-accent/50 hover:text-foreground",
        dragOver && "ring-2 ring-primary bg-primary/10"
      )}
      onClick={onClick}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      <span className={cn("shrink-0", iconClassName)}>{icon}</span>
      <span className="flex-1">{label}</span>
      {count !== undefined && count > 0 && (
        <span className="text-xs text-muted-foreground">{count}</span>
      )}
    </div>
  );
}

function ProjectDropTarget({ projectId, children }: { projectId: string; children: React.ReactNode }) {
  const [dragOver, setDragOver] = useState(false);

  return (
    <div
      className={cn(dragOver && "ring-2 ring-primary rounded-md bg-primary/10")}
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
          store.updateTodo(todoId, { projectId });
        }
      }}
    >
      {children}
    </div>
  );
}
