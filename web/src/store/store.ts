import { v4 as uuid } from 'uuid';
import type { Todo, Project, Priority, ViewType, Habit, Subtask, CalendarEvent, CalendarContainer } from '../types';
import { getSupabase, isSupabaseAvailable } from '../lib/supabase';
import { getEncryptionKey, hasEncryptionKey } from '../lib/auth';
import { encrypt, decrypt } from '../lib/encryption';

type Listener = () => void;

export type SyncStatus = 'idle' | 'syncing' | 'error' | 'offline';

const PROJECT_COLORS = [
  '#00BFA5', '#FF5252', '#FFB74D', '#CDDC39',
  '#66BB6A', '#64B5F6', '#AB47BC', '#EC407A',
  '#26C6DA', '#78909C',
];

class Store {
  todos: Todo[] = [];
  projects: Project[] = [];
  habits: Habit[] = [];
  calendarEvents: CalendarEvent[] = [];
  calendars: CalendarContainer[] = [];
  currentView: ViewType = 'inbox';
  currentProjectId: string | null = null;
  showCompleted: boolean = false;
  highlightedTodoId: string | null = null;
  syncStatus: SyncStatus = 'idle';
  syncError: string | null = null;
  private listeners: Set<Listener> = new Set();
  private supabaseEnabled: boolean = false;

  constructor() {
    this.load();
    if (this.projects.length === 0) {
      // Create default inbox project
      this.projects.push({
        id: 'inbox',
        name: 'Eingang',
        color: '#00BFA5',
        isInbox: true,
        sortOrder: 0,
        description: '',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
      this.save();
    }
  }

  subscribe(listener: Listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private notify() {
    this.listeners.forEach(l => l());
  }

  private save() {
    localStorage.setItem('chukdoo_todos', JSON.stringify(this.todos));
    localStorage.setItem('chukdoo_projects', JSON.stringify(this.projects));
    localStorage.setItem('chukdoo_habits', JSON.stringify(this.habits));
    localStorage.setItem('chukdoo_calendar_events', JSON.stringify(this.calendarEvents));
    localStorage.setItem('chukdoo_calendars', JSON.stringify(this.calendars));
  }

  private load() {
    try {
      const todos = localStorage.getItem('chukdoo_todos');
      const projects = localStorage.getItem('chukdoo_projects');
      const habits = localStorage.getItem('chukdoo_habits');
      const calendarEvents = localStorage.getItem('chukdoo_calendar_events');
      const calendars = localStorage.getItem('chukdoo_calendars');
      if (todos) this.todos = JSON.parse(todos);
      if (projects) this.projects = JSON.parse(projects);
      if (habits) this.habits = JSON.parse(habits);
      if (calendarEvents) this.calendarEvents = JSON.parse(calendarEvents);
      if (calendars) this.calendars = JSON.parse(calendars);
    } catch {}
  }

  // ---------- Supabase sync ----------

  setSupabaseEnabled(enabled: boolean) {
    this.supabaseEnabled = enabled;
    this.notify();
  }

  get isSupabaseEnabled(): boolean {
    return this.supabaseEnabled && isSupabaseAvailable();
  }

  /**
   * Sync a single todo to Supabase (encrypt sensitive fields before upload).
   */
  private async syncTodoToSupabase(todo: Todo, operation: 'upsert' | 'delete') {
    if (!this.isSupabaseEnabled || !hasEncryptionKey()) return;

    const supabase = getSupabase();
    if (!supabase) return;

    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return;

    try {
      if (operation === 'delete') {
        await supabase.from('todos').delete().eq('id', todo.id);
        return;
      }

      const key = getEncryptionKey()!;

      // Encrypt the full todo as JSON (matching Flutter's schema - everything in encrypted_payload)
      const priorityInt = typeof todo.priority === 'number' ? todo.priority : (parseInt(String(todo.priority).replace('p', '')) || 4);
      const fullPayload = JSON.stringify({
        id: todo.id,
        user_id: session.user.id,
        project_id: todo.projectId || null,
        title: todo.title,
        description: todo.description || null,
        priority: priorityInt,
        due_date: todo.dueDate || null,
        due_time: todo.dueTime ? `${todo.dueTime}:00` : null,
        is_completed: todo.isCompleted,
        completed_at: todo.completedAt || null,
        recurrence_rule: null,
        sort_order: todo.sortOrder,
        created_at: todo.createdAt,
        updated_at: todo.updatedAt,
        encryption_context: null,
        label_ids: todo.labelIds ?? [],
        reminder_at: todo.reminderAt || null,
        version: 1,
      });
      const encryptedPayload = await encrypt(fullPayload, key);

      await supabase.from('todos').upsert({
        id: todo.id,
        user_id: session.user.id,
        encrypted_payload: encryptedPayload,
        updated_at: todo.updatedAt,
      });
    } catch (e) {
      console.error('Sync todo failed:', e);
    }
  }

  /**
   * Sync a single project to Supabase.
   */
  private async syncProjectToSupabase(project: Project, operation: 'upsert' | 'delete') {
    if (!this.isSupabaseEnabled || !hasEncryptionKey()) return;

    const supabase = getSupabase();
    if (!supabase) return;

    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return;

    try {
      if (operation === 'delete') {
        await supabase.from('projects').delete().eq('id', project.id);
        return;
      }

      const key = getEncryptionKey()!;
      // Flutter uses camelCase for project payload
      const projectPayload = {
        id: project.id,
        name: project.name,
        color: project.color,
        isInbox: project.isInbox,
        sortOrder: project.sortOrder,
        description: project.description || '',
        updatedAt: project.updatedAt,
      };
      const encryptedPayload = await encrypt(JSON.stringify(projectPayload), key);

      await supabase.from('projects').upsert({
        id: project.id,
        user_id: session.user.id,
        encrypted_payload: encryptedPayload,
        updated_at: project.updatedAt,
      });
    } catch (e) {
      console.error('Sync project failed:', e);
    }
  }

  /**
   * Load data directly from Flutter's Hive database (via server endpoint).
   * This is the most up-to-date source since the Flutter app may not have synced to Supabase.
   */
  async loadFromHive() {
    try {
      const resp = await fetch('/api/hive-data');
      const data = await resp.json();
      if (data.error) {
        console.warn('Hive read error:', data.error);
        return false;
      }

      const hiveTodos: Todo[] = (data.todos ?? []).map((t: any) => ({
        id: t.id ?? '',
        projectId: t.project_id || null,
        title: t.title ?? '',
        description: t.description ?? '',
        priority: typeof t.priority === 'number' ? `p${t.priority}` as Priority : (t.priority ?? 'p4'),
        dueDate: t.due_date || null,
        dueTime: t.due_time ? String(t.due_time).split(':').slice(0, 2).join(':') : null,
        isCompleted: t.is_completed === true,
        completedAt: t.completed_at || null,
        status: t.is_completed ? 'done' as const : 'todo' as const,
        subtasks: [],
        labelIds: t.label_ids ?? [],
        reminderAt: t.reminder_at || null,
        sortOrder: typeof t.sort_order === 'number' ? t.sort_order : 0,
        createdAt: t.created_at ?? '',
        updatedAt: t.updated_at ?? '',
      }));

      const hiveProjects: Project[] = (data.projects ?? []).map((p: any) => ({
        id: p.id ?? '',
        name: p.name ?? '',
        color: typeof p.color === 'string' ? p.color : '#00BFA5',
        isInbox: p.is_inbox === true || p.isInbox === true,
        sortOrder: typeof p.sort_order === 'number' ? p.sort_order : (typeof p.sortOrder === 'number' ? p.sortOrder : 0),
        description: p.description ?? '',
        createdAt: p.created_at ?? p.createdAt ?? '',
        updatedAt: p.updated_at ?? p.updatedAt ?? '',
      }));

      if (hiveTodos.length > 0) {
        this.todos = hiveTodos;
        console.log(`Loaded ${hiveTodos.length} todos from Hive (${hiveTodos.filter(t => t.isCompleted).length} completed)`);
      }
      if (hiveProjects.length > 0) {
        // Keep default inbox + add hive projects
        const inbox = this.projects.find(p => p.isInbox);
        this.projects = inbox ? [inbox, ...hiveProjects.filter(p => !p.isInbox)] : hiveProjects;
      }

      // Load calendar events from Hive
      const hiveCalendarEvents: CalendarEvent[] = (data.calendar_events ?? []).map((e: any) => ({
        id: e.id ?? '',
        calendarId: e.calendar_id || null,
        title: e.title ?? '',
        description: e.description ?? '',
        location: e.location ?? '',
        startTime: e.start_time ?? '',
        endTime: e.end_time ?? '',
        isAllDay: e.is_all_day === true,
        color: typeof e.color === 'number' ? e.color : 0,
        recurrenceRule: e.recurrence_rule || null,
        recurrenceId: e.recurrence_id || null,
        originalStartTime: e.original_start_time || null,
        reminderMinutes: e.reminder_minutes ?? [],
        sortOrder: e.sort_order ?? 0,
        version: e.version ?? 1,
        createdAt: e.created_at ?? '',
        updatedAt: e.updated_at ?? '',
      }));

      const hiveCalendars: CalendarContainer[] = (data.calendars ?? []).map((c: any) => ({
        id: c.id ?? '',
        name: c.name ?? '',
        description: c.description ?? '',
        color: typeof c.color === 'number' ? c.color : 0xFF4285F4,
        isDefault: c.is_default === true,
        isVisible: c.is_visible !== false,
        sortOrder: c.sort_order ?? 0,
        createdAt: c.created_at ?? '',
        updatedAt: c.updated_at ?? '',
      }));

      if (hiveCalendarEvents.length > 0) {
        this.calendarEvents = hiveCalendarEvents;
        console.log(`Loaded ${hiveCalendarEvents.length} calendar events from Hive`);
      }
      if (hiveCalendars.length > 0) {
        this.calendars = hiveCalendars;
        console.log(`Loaded ${hiveCalendars.length} calendars from Hive`);
      }

      this.save();
      this.notify();
      return true;
    } catch (e) {
      console.warn('Failed to load from Hive:', e);
      return false;
    }
  }

  /**
   * Full sync: try Hive first (most up-to-date), then Supabase as fallback.
   */
  async syncWithSupabase() {
    if (!this.isSupabaseEnabled || !hasEncryptionKey()) {
      this.syncStatus = 'offline';
      this.notify();
      return;
    }

    const supabase = getSupabase();
    if (!supabase) return;

    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      this.syncStatus = 'offline';
      this.notify();
      return;
    }

    this.syncStatus = 'syncing';
    this.syncError = null;
    this.notify();

    // Try Hive first (local Flutter data is always more up-to-date)
    const hiveLoaded = await this.loadFromHive();
    if (hiveLoaded) {
      this.syncStatus = 'idle';
      this.notify();
      return; // Hive data is the source of truth
    }

    try {
      const key = getEncryptionKey()!;
      const userId = session.user.id;

      // On first sync (no local data yet), skip uploading to avoid overwriting server
      const hasLocalData = this.todos.length > 0;

      if (hasLocalData) {
        // Upload all local todos
        for (const todo of this.todos) {
          await this.syncTodoToSupabase(todo, 'upsert');
        }

        // Upload all local projects (except default inbox)
        for (const project of this.projects) {
          if (!project.isInbox) {
            await this.syncProjectToSupabase(project, 'upsert');
          }
        }
      }

      // Download todos from server
      // Supabase schema: id, user_id, encrypted_payload (full todo JSON), updated_at
      // The encrypted_payload contains ALL fields (title, description, is_completed, priority, etc.)
      const { data: serverTodos, error: todosError } = await supabase
        .from('todos')
        .select('id, encrypted_payload, updated_at')
        .eq('user_id', userId);

      if (todosError) throw todosError;

      if (serverTodos) {
        for (const row of serverTodos) {
          if (!row.encrypted_payload) continue;

          let payload: any;
          try {
            const decrypted = await decrypt(row.encrypted_payload as string, key);
            payload = JSON.parse(decrypted);
          } catch {
            console.warn('Failed to decrypt todo', row.id, '- skipping');
            continue;
          }

          // Parse due_time from "HH:mm:ss" or "HH:mm" to "HH:mm"
          let dueTime: string | null = null;
          if (payload.due_time) {
            const parts = String(payload.due_time).split(':');
            dueTime = `${parts[0]}:${parts[1]}`;
          }

          // Convert priority int (1-4) to string ("p1"-"p4")
          const priorityInt = payload.priority ?? 4;
          const priority = (typeof priorityInt === 'number' ? `p${priorityInt}` : String(priorityInt)) as Priority;

          const serverTodo: Todo = {
            id: payload.id ?? row.id,
            projectId: payload.project_id || null,
            title: payload.title ?? '',
            description: payload.description ?? '',
            priority,
            dueDate: payload.due_date || null,
            dueTime,
            isCompleted: payload.is_completed === true,
            completedAt: payload.completed_at || null,
            status: payload.is_completed ? 'done' : 'todo',
            subtasks: [],
            labelIds: payload.label_ids ?? [],
            reminderAt: payload.reminder_at || null,
            sortOrder: payload.sort_order ?? 0,
            createdAt: payload.created_at ?? row.updated_at,
            updatedAt: payload.updated_at ?? row.updated_at,
          };

          const localIdx = this.todos.findIndex(t => t.id === serverTodo.id);
          if (localIdx === -1) {
            this.todos.push(serverTodo);
          } else {
            // Server always wins on download (server is source of truth)
            this.todos[localIdx] = serverTodo;
          }
        }
      }

      // Download projects from server (same schema: id, user_id, encrypted_payload, updated_at)
      const { data: serverProjects, error: projectsError } = await supabase
        .from('projects')
        .select('id, encrypted_payload, updated_at')
        .eq('user_id', userId);

      if (projectsError) throw projectsError;

      if (serverProjects) {
        for (const row of serverProjects) {
          if (!row.encrypted_payload) continue;

          let payload: any;
          try {
            const decrypted = await decrypt(row.encrypted_payload as string, key);
            payload = JSON.parse(decrypted);
          } catch {
            console.warn('Failed to decrypt project', row.id, '- skipping');
            continue;
          }

          // Project payload can be camelCase or snake_case depending on version
          const serverProject: Project = {
            id: payload.id ?? row.id,
            name: payload.name ?? '',
            color: typeof payload.color === 'string' ? payload.color : (payload.color ? `#${payload.color.toString(16).padStart(6, '0')}` : '#00BFA5'),
            isInbox: payload.isInbox ?? payload.is_inbox ?? false,
            sortOrder: payload.sortOrder ?? payload.sort_order ?? 0,
            description: payload.description ?? '',
            createdAt: payload.createdAt ?? payload.created_at ?? row.updated_at,
            updatedAt: payload.updatedAt ?? payload.updated_at ?? row.updated_at,
          };

          const localIdx = this.projects.findIndex(p => p.id === serverProject.id);
          if (localIdx === -1) {
            this.projects.push(serverProject);
          } else {
            this.projects[localIdx] = serverProject;
          }
        }
      }

      // Download calendar events from server
      try {
        const { data: serverEvents, error: eventsError } = await supabase
          .from('calendar_events')
          .select('id, encrypted_payload, updated_at')
          .eq('user_id', userId);

        if (!eventsError && serverEvents) {
          for (const row of serverEvents) {
            if (!row.encrypted_payload) continue;
            let payload: any;
            try {
              const decrypted = await decrypt(row.encrypted_payload as string, key);
              payload = JSON.parse(decrypted);
            } catch {
              console.warn('Failed to decrypt calendar event', row.id, '- skipping');
              continue;
            }

            const serverEvent: CalendarEvent = {
              id: payload.id ?? row.id,
              calendarId: payload.calendar_id || null,
              title: payload.title ?? '',
              description: payload.description ?? '',
              location: payload.location ?? '',
              startTime: payload.start_time ?? '',
              endTime: payload.end_time ?? '',
              isAllDay: payload.is_all_day === true,
              color: typeof payload.color === 'number' ? payload.color : 0,
              recurrenceRule: payload.recurrence_rule || null,
              recurrenceId: payload.recurrence_id || null,
              originalStartTime: payload.original_start_time || null,
              reminderMinutes: payload.reminder_minutes ?? [],
              sortOrder: payload.sort_order ?? 0,
              version: payload.version ?? 1,
              createdAt: payload.created_at ?? row.updated_at,
              updatedAt: payload.updated_at ?? row.updated_at,
            };

            const localIdx = this.calendarEvents.findIndex(e => e.id === serverEvent.id);
            if (localIdx === -1) {
              this.calendarEvents.push(serverEvent);
            } else {
              this.calendarEvents[localIdx] = serverEvent;
            }
          }
        }
      } catch (e) {
        console.warn('Calendar events sync failed:', e);
      }

      // Download calendars from server
      try {
        const { data: serverCalendars, error: calendarsError } = await supabase
          .from('calendars')
          .select('id, encrypted_payload, updated_at')
          .eq('user_id', userId);

        if (!calendarsError && serverCalendars) {
          for (const row of serverCalendars) {
            if (!row.encrypted_payload) continue;
            let payload: any;
            try {
              const decrypted = await decrypt(row.encrypted_payload as string, key);
              payload = JSON.parse(decrypted);
            } catch {
              console.warn('Failed to decrypt calendar', row.id, '- skipping');
              continue;
            }

            const serverCal: CalendarContainer = {
              id: payload.id ?? row.id,
              name: payload.name ?? '',
              description: payload.description ?? '',
              color: typeof payload.color === 'number' ? payload.color : 0xFF4285F4,
              isDefault: payload.is_default ?? payload.isDefault ?? false,
              isVisible: payload.is_visible ?? payload.isVisible ?? true,
              sortOrder: payload.sort_order ?? payload.sortOrder ?? 0,
              createdAt: payload.created_at ?? payload.createdAt ?? row.updated_at,
              updatedAt: payload.updated_at ?? payload.updatedAt ?? row.updated_at,
            };

            const localIdx = this.calendars.findIndex(c => c.id === serverCal.id);
            if (localIdx === -1) {
              this.calendars.push(serverCal);
            } else {
              this.calendars[localIdx] = serverCal;
            }
          }
        }
      } catch (e) {
        console.warn('Calendars sync failed:', e);
      }

      this.save();
      this.syncStatus = 'idle';
      this.syncError = null;
    } catch (e: any) {
      console.error('Sync failed:', e);
      this.syncStatus = 'error';
      this.syncError = e?.message ?? String(e);
    }

    this.notify();
  }

  // ---------- Views ----------

  setView(view: ViewType, projectId?: string) {
    this.currentView = view;
    this.currentProjectId = projectId ?? null;
    this.notify();
  }

  toggleShowCompleted() {
    this.showCompleted = !this.showCompleted;
    this.notify();
  }

  highlightTodo(todoId: string) {
    this.highlightedTodoId = todoId;
    this.notify();
    // Auto-clear after 2 seconds
    setTimeout(() => {
      if (this.highlightedTodoId === todoId) {
        this.highlightedTodoId = null;
        this.notify();
      }
    }, 2000);
  }

  // ---------- Todo operations ----------

  addTodo(data: {
    title: string;
    description?: string;
    projectId?: string | null;
    priority?: Priority;
    dueDate?: string | null;
    dueTime?: string | null;
    labelIds?: string[];
    subtasks?: Subtask[];
  }) {
    const now = new Date().toISOString();
    const todo: Todo = {
      id: uuid(),
      projectId: data.projectId ?? null,
      title: data.title,
      description: data.description ?? '',
      priority: data.priority ?? 'p4',
      dueDate: data.dueDate ?? null,
      dueTime: data.dueTime ?? null,
      isCompleted: false,
      completedAt: null,
      status: 'todo',
      subtasks: data.subtasks ?? [],
      labelIds: data.labelIds ?? [],
      reminderAt: null,
      sortOrder: this.todos.length,
      createdAt: now,
      updatedAt: now,
    };
    this.todos.push(todo);
    this.save();
    this.notify();
    this.syncTodoToSupabase(todo, 'upsert');
    return todo;
  }

  updateTodo(id: string, updates: Partial<Todo>) {
    const idx = this.todos.findIndex(t => t.id === id);
    if (idx === -1) return;
    this.todos[idx] = { ...this.todos[idx]!, ...updates, updatedAt: new Date().toISOString() };
    this.save();
    this.notify();
    this.syncTodoToSupabase(this.todos[idx]!, 'upsert');
  }

  toggleTodo(id: string) {
    const todo = this.todos.find(t => t.id === id);
    if (!todo) return;
    todo.isCompleted = !todo.isCompleted;
    todo.completedAt = todo.isCompleted ? new Date().toISOString() : null;
    todo.updatedAt = new Date().toISOString();
    this.save();
    this.notify();
    this.syncTodoToSupabase(todo, 'upsert');
  }

  deleteTodo(id: string) {
    const todo = this.todos.find(t => t.id === id);
    this.todos = this.todos.filter(t => t.id !== id);
    this.save();
    this.notify();
    if (todo) this.syncTodoToSupabase(todo, 'delete');
  }

  addSubtask(todoId: string, title: string) {
    const todo = this.todos.find(t => t.id === todoId);
    if (!todo) return;
    if (!todo.subtasks) todo.subtasks = [];
    const subtask: Subtask = {
      id: uuid(),
      title,
      isCompleted: false,
    };
    todo.subtasks.push(subtask);
    todo.updatedAt = new Date().toISOString();
    this.save();
    this.notify();
    this.syncTodoToSupabase(todo, 'upsert');
    return subtask;
  }

  toggleSubtask(todoId: string, subtaskId: string) {
    const todo = this.todos.find(t => t.id === todoId);
    if (!todo || !todo.subtasks) return;
    const subtask = todo.subtasks.find(s => s.id === subtaskId);
    if (!subtask) return;
    subtask.isCompleted = !subtask.isCompleted;
    todo.updatedAt = new Date().toISOString();
    this.save();
    this.notify();
    this.syncTodoToSupabase(todo, 'upsert');
  }

  deleteSubtask(todoId: string, subtaskId: string) {
    const todo = this.todos.find(t => t.id === todoId);
    if (!todo || !todo.subtasks) return;
    todo.subtasks = todo.subtasks.filter(s => s.id !== subtaskId);
    todo.updatedAt = new Date().toISOString();
    this.save();
    this.notify();
    this.syncTodoToSupabase(todo, 'upsert');
  }

  moveTodoStatus(id: string, status: 'todo' | 'in_progress' | 'done') {
    const todo = this.todos.find(t => t.id === id);
    if (!todo) return;
    todo.status = status;
    if (status === 'done') {
      todo.isCompleted = true;
      todo.completedAt = new Date().toISOString();
    } else {
      todo.isCompleted = false;
      todo.completedAt = null;
    }
    todo.updatedAt = new Date().toISOString();
    this.save();
    this.notify();
    this.syncTodoToSupabase(todo, 'upsert');
  }

  // ---------- Filtered getters ----------

  private sortTodos(todos: Todo[]): Todo[] {
    return todos.sort((a, b) => {
      // Due-date ascending (soonest first), no due-date goes to bottom
      if (a.dueDate && b.dueDate) {
        const cmp = a.dueDate.localeCompare(b.dueDate);
        if (cmp !== 0) return cmp;
      } else if (a.dueDate && !b.dueDate) return -1;
      else if (!a.dueDate && b.dueDate) return 1;
      // Then by sortOrder
      return a.sortOrder - b.sortOrder;
    });
  }

  getInboxTodos() {
    return this.sortTodos(
      this.todos.filter(t => !t.isCompleted && !t.projectId)
    );
  }

  getTodayTodos() {
    const today = new Date().toISOString().split('T')[0]!;
    return this.sortTodos(
      this.todos.filter(t => {
        if (t.isCompleted) return false;
        if (!t.dueDate) return false;
        return t.dueDate <= today;
      })
    );
  }

  getUpcomingTodos() {
    const today = new Date().toISOString().split('T')[0]!;
    return this.sortTodos(
      this.todos.filter(t => {
        if (t.isCompleted) return false;
        if (!t.dueDate) return false;
        return t.dueDate > today;
      })
    );
  }

  getProjectTodos(projectId: string) {
    if (projectId === 'inbox') {
      return this.getInboxTodos();
    }
    return this.sortTodos(
      this.todos.filter(t => !t.isCompleted && t.projectId === projectId)
    );
  }

  getCompletedTodos() {
    return this.todos.filter(t => t.isCompleted)
      .sort((a, b) => (b.completedAt ?? '').localeCompare(a.completedAt ?? ''));
  }

  getProjectTaskCount(projectId: string) {
    if (projectId === 'inbox') {
      return this.todos.filter(t => !t.isCompleted && !t.projectId).length;
    }
    return this.todos.filter(t => !t.isCompleted && t.projectId === projectId).length;
  }

  // ---------- Project operations ----------

  addProject(data: { name: string; color?: string; description?: string }) {
    const now = new Date().toISOString();
    const usedColors = new Set(this.projects.map(p => p.color));
    const availableColor = PROJECT_COLORS.find(c => !usedColors.has(c)) ?? PROJECT_COLORS[Math.floor(Math.random() * PROJECT_COLORS.length)]!;
    const project: Project = {
      id: uuid(),
      name: data.name,
      color: data.color ?? availableColor,
      isInbox: false,
      sortOrder: this.projects.length,
      description: data.description ?? '',
      createdAt: now,
      updatedAt: now,
    };
    this.projects.push(project);
    this.save();
    this.notify();
    this.syncProjectToSupabase(project, 'upsert');
    return project;
  }

  updateProject(id: string, updates: Partial<Project>) {
    const idx = this.projects.findIndex(p => p.id === id);
    if (idx === -1) return;
    this.projects[idx] = { ...this.projects[idx]!, ...updates, updatedAt: new Date().toISOString() };
    this.save();
    this.notify();
    this.syncProjectToSupabase(this.projects[idx]!, 'upsert');
  }

  deleteProject(id: string) {
    const project = this.projects.find(p => p.id === id);
    // Move todos to inbox
    this.todos.forEach(t => {
      if (t.projectId === id) t.projectId = null;
    });
    this.projects = this.projects.filter(p => p.id !== id);
    this.save();
    this.notify();
    if (project) this.syncProjectToSupabase(project, 'delete');
  }

  getUserProjects() {
    return this.projects.filter(p => !p.isInbox).sort((a, b) => a.sortOrder - b.sortOrder);
  }

  getProjectById(id: string) {
    return this.projects.find(p => p.id === id);
  }

  // ---------- Habit operations ----------

  addHabit(data: { name: string; color: string; frequency: 'daily' | 'weekly' }) {
    const habit: Habit = {
      id: uuid(),
      name: data.name,
      color: data.color,
      frequency: data.frequency,
      completions: [],
      createdAt: new Date().toISOString(),
      streak: 0,
    };
    this.habits.push(habit);
    this.save();
    this.notify();
    return habit;
  }

  toggleHabitCompletion(id: string, date?: string) {
    const habit = this.habits.find(h => h.id === id);
    if (!habit) return;
    const d = date ?? new Date().toISOString().split('T')[0]!;
    const idx = habit.completions.indexOf(d);
    if (idx === -1) {
      habit.completions.push(d);
    } else {
      habit.completions.splice(idx, 1);
    }
    // Recalculate streak
    habit.streak = this.calculateStreak(habit);
    this.save();
    this.notify();
  }

  deleteHabit(id: string) {
    this.habits = this.habits.filter(h => h.id !== id);
    this.save();
    this.notify();
  }

  getHabits() {
    return this.habits;
  }

  // ---------- Calendar operations ----------

  private async syncCalendarEventToSupabase(event: CalendarEvent, operation: 'upsert' | 'delete') {
    if (!this.isSupabaseEnabled || !hasEncryptionKey()) return;

    const supabase = getSupabase();
    if (!supabase) return;

    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return;

    try {
      if (operation === 'delete') {
        await supabase.from('calendar_events').delete().eq('id', event.id);
        return;
      }

      const key = getEncryptionKey()!;
      const fullPayload = JSON.stringify({
        id: event.id,
        user_id: session.user.id,
        calendar_id: event.calendarId || null,
        title: event.title,
        description: event.description || null,
        location: event.location || null,
        start_time: event.startTime,
        end_time: event.endTime,
        is_all_day: event.isAllDay,
        color: event.color,
        recurrence_rule: event.recurrenceRule || null,
        recurrence_id: event.recurrenceId || null,
        original_start_time: event.originalStartTime || null,
        reminder_minutes: event.reminderMinutes,
        sort_order: event.sortOrder,
        version: event.version,
        encryption_context: null,
        created_at: event.createdAt,
        updated_at: event.updatedAt,
      });
      const encryptedPayload = await encrypt(fullPayload, key);

      await supabase.from('calendar_events').upsert({
        id: event.id,
        user_id: session.user.id,
        encrypted_payload: encryptedPayload,
        updated_at: event.updatedAt,
      });
    } catch (e) {
      console.error('Sync calendar event failed:', e);
    }
  }

  private async syncCalendarToSupabase(cal: CalendarContainer, operation: 'upsert' | 'delete') {
    if (!this.isSupabaseEnabled || !hasEncryptionKey()) return;

    const supabase = getSupabase();
    if (!supabase) return;

    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return;

    try {
      if (operation === 'delete') {
        await supabase.from('calendars').delete().eq('id', cal.id);
        return;
      }

      const key = getEncryptionKey()!;
      const payload = {
        id: cal.id,
        user_id: session.user.id,
        name: cal.name,
        description: cal.description || '',
        color: cal.color,
        is_default: cal.isDefault,
        is_visible: cal.isVisible,
        sort_order: cal.sortOrder,
        created_at: cal.createdAt,
        updated_at: cal.updatedAt,
      };
      const encryptedPayload = await encrypt(JSON.stringify(payload), key);

      await supabase.from('calendars').upsert({
        id: cal.id,
        user_id: session.user.id,
        encrypted_payload: encryptedPayload,
        updated_at: cal.updatedAt,
      });
    } catch (e) {
      console.error('Sync calendar failed:', e);
    }
  }

  addCalendarEvent(data: {
    title: string;
    description?: string;
    location?: string;
    calendarId?: string | null;
    startTime: string;
    endTime: string;
    isAllDay?: boolean;
    color?: number;
    recurrenceRule?: string | null;
    reminderMinutes?: number[];
  }) {
    const now = new Date().toISOString();
    const event: CalendarEvent = {
      id: uuid(),
      calendarId: data.calendarId ?? null,
      title: data.title,
      description: data.description ?? '',
      location: data.location ?? '',
      startTime: data.startTime,
      endTime: data.endTime,
      isAllDay: data.isAllDay ?? false,
      color: data.color ?? 0,
      recurrenceRule: data.recurrenceRule ?? null,
      recurrenceId: null,
      originalStartTime: null,
      reminderMinutes: data.reminderMinutes ?? [15],
      sortOrder: 0,
      version: 1,
      createdAt: now,
      updatedAt: now,
    };
    this.calendarEvents.push(event);
    this.save();
    this.notify();
    this.syncCalendarEventToSupabase(event, 'upsert');
    return event;
  }

  updateCalendarEvent(id: string, updates: Partial<CalendarEvent>) {
    const idx = this.calendarEvents.findIndex(e => e.id === id);
    if (idx === -1) return;
    this.calendarEvents[idx] = {
      ...this.calendarEvents[idx]!,
      ...updates,
      updatedAt: new Date().toISOString(),
    };
    this.save();
    this.notify();
    this.syncCalendarEventToSupabase(this.calendarEvents[idx]!, 'upsert');
  }

  deleteCalendarEvent(id: string) {
    const event = this.calendarEvents.find(e => e.id === id);
    this.calendarEvents = this.calendarEvents.filter(e => e.id !== id);
    this.save();
    this.notify();
    if (event) this.syncCalendarEventToSupabase(event, 'delete');
  }

  moveCalendarEvent(id: string, newStartTime: string) {
    const event = this.calendarEvents.find(e => e.id === id);
    if (!event) return;
    const start = new Date(event.startTime);
    const end = new Date(event.endTime);
    const duration = end.getTime() - start.getTime();
    const newStart = new Date(newStartTime);
    const newEnd = new Date(newStart.getTime() + duration);
    this.updateCalendarEvent(id, {
      startTime: newStart.toISOString(),
      endTime: newEnd.toISOString(),
    });
  }

  addCalendar(data: { name: string; description?: string; color?: number; isDefault?: boolean }) {
    const now = new Date().toISOString();
    const cal: CalendarContainer = {
      id: uuid(),
      name: data.name,
      description: data.description ?? '',
      color: data.color ?? 0xFF4285F4,
      isDefault: data.isDefault ?? false,
      isVisible: true,
      sortOrder: this.calendars.length,
      createdAt: now,
      updatedAt: now,
    };
    this.calendars.push(cal);
    this.save();
    this.notify();
    this.syncCalendarToSupabase(cal, 'upsert');
    return cal;
  }

  updateCalendar(id: string, updates: Partial<CalendarContainer>) {
    const idx = this.calendars.findIndex(c => c.id === id);
    if (idx === -1) return;
    this.calendars[idx] = {
      ...this.calendars[idx]!,
      ...updates,
      updatedAt: new Date().toISOString(),
    };
    this.save();
    this.notify();
    this.syncCalendarToSupabase(this.calendars[idx]!, 'upsert');
  }

  deleteCalendar(id: string) {
    const cal = this.calendars.find(c => c.id === id);
    this.calendars = this.calendars.filter(c => c.id !== id);
    this.save();
    this.notify();
    if (cal) this.syncCalendarToSupabase(cal, 'delete');
  }

  toggleCalendarVisibility(id: string) {
    const cal = this.calendars.find(c => c.id === id);
    if (cal) {
      this.updateCalendar(id, { isVisible: !cal.isVisible });
    }
  }

  getCalendarEvents() {
    return this.calendarEvents;
  }

  getCalendarEventsForDay(date: string) {
    const dayStart = new Date(date);
    dayStart.setHours(0, 0, 0, 0);
    const dayEnd = new Date(dayStart);
    dayEnd.setDate(dayEnd.getDate() + 1);
    return this.calendarEvents.filter(e => {
      const start = new Date(e.startTime);
      const end = new Date(e.endTime);
      return start < dayEnd && end > dayStart;
    });
  }

  getCalendarEventsForRange(startDate: string, endDate: string) {
    const rangeStart = new Date(startDate);
    const rangeEnd = new Date(endDate);
    return this.calendarEvents.filter(e => {
      const start = new Date(e.startTime);
      const end = new Date(e.endTime);
      return start < rangeEnd && end > rangeStart;
    });
  }

  getVisibleCalendars() {
    return this.calendars.filter(c => c.isVisible);
  }

  private calculateStreak(habit: Habit): number {
    const sorted = [...habit.completions].sort().reverse();
    if (sorted.length === 0) return 0;
    const today = new Date().toISOString().split('T')[0]!;
    let streak = 0;
    let checkDate = new Date(today);
    // Allow today or yesterday as start
    if (sorted[0] !== today) {
      const yesterday = new Date(checkDate);
      yesterday.setDate(yesterday.getDate() - 1);
      const yesterdayStr = yesterday.toISOString().split('T')[0]!;
      if (sorted[0] !== yesterdayStr) return 0;
      checkDate = yesterday;
    }
    for (let i = 0; i < 365; i++) {
      const ds = checkDate.toISOString().split('T')[0]!;
      if (habit.completions.includes(ds)) {
        streak++;
        checkDate.setDate(checkDate.getDate() - 1);
      } else {
        break;
      }
    }
    return streak;
  }
}

export const store = new Store();
export { PROJECT_COLORS };
