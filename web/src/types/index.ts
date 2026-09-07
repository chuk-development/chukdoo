export type Priority = 'p1' | 'p2' | 'p3' | 'p4';

export interface Subtask {
  id: string;
  title: string;
  isCompleted: boolean;
}

export interface Todo {
  id: string;
  projectId: string | null;
  title: string;
  description: string;
  priority: Priority;
  dueDate: string | null; // ISO date string
  dueTime: string | null; // HH:mm
  isCompleted: boolean;
  completedAt: string | null;
  labelIds: string[];
  reminderAt: string | null;
  status: 'todo' | 'in_progress' | 'done';
  subtasks: Subtask[];
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface Project {
  id: string;
  name: string;
  color: string; // hex color
  isInbox: boolean;
  sortOrder: number;
  description: string;
  createdAt: string;
  updatedAt: string;
}

export interface Label {
  id: string;
  name: string;
  color: string;
}

export interface CalendarEvent {
  id: string;
  calendarId: string | null;
  title: string;
  description: string;
  location: string;
  startTime: string;      // ISO datetime
  endTime: string;        // ISO datetime
  isAllDay: boolean;
  color: number;
  recurrenceRule: string | null;
  recurrenceId: string | null;
  originalStartTime: string | null;
  reminderMinutes: number[];
  sortOrder: number;
  version: number;
  createdAt: string;
  updatedAt: string;
}

export interface CalendarContainer {
  id: string;
  name: string;
  description: string;
  color: number;
  isDefault: boolean;
  isVisible: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export type ViewType = 'inbox' | 'today' | 'upcoming' | 'filters' | 'completed' | 'project' | 'calendar' | 'timer' | 'habits' | 'kanban';

export interface Habit {
  id: string;
  name: string;
  color: string;
  frequency: 'daily' | 'weekly';
  completions: string[]; // ISO date strings
  createdAt: string;
  streak: number;
}
