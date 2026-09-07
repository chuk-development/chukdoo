import React, { useState, useEffect, useRef, useCallback } from 'react';
import { store } from '../store/store';
import { useStoreState } from '../store/hooks';
import { Button } from './ui/button';
import { cn } from '../lib/utils';
import type { Todo, CalendarEvent } from '../types';
import { ChevronLeft, ChevronRight, Plus, Calendar, List, LayoutGrid } from 'lucide-react';

const HOURS = Array.from({ length: 24 }, (_, i) => i);
const DAY_NAMES = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const MONTH_NAMES = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'];

type CalendarViewMode = 'day' | 'week' | 'month' | 'agenda';

interface CalendarDisplayItem {
  id: string;
  title: string;
  startTime: Date;
  endTime: Date;
  isAllDay: boolean;
  color: string;
  type: 'event' | 'todo';
  event?: CalendarEvent;
  todo?: Todo;
}

function getWeekStart(date: Date): Date {
  const d = new Date(date);
  const day = d.getDay();
  const diff = (day === 0 ? -6 : 1) - day;
  d.setDate(d.getDate() + diff);
  d.setHours(0, 0, 0, 0);
  return d;
}

function formatDate(d: Date): string {
  return d.toISOString().split('T')[0]!;
}

function getWeekDays(weekStart: Date): Date[] {
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(weekStart);
    d.setDate(d.getDate() + i);
    return d;
  });
}

function getPriorityColor(priority: string): string {
  switch (priority) {
    case 'p1': return 'var(--color-p1)';
    case 'p2': return 'var(--color-p2)';
    case 'p3': return 'var(--color-p3)';
    default: return 'var(--color-primary)';
  }
}

function getMonthDays(year: number, month: number): Date[] {
  const firstOfMonth = new Date(year, month, 1);
  const gridStart = new Date(firstOfMonth);
  gridStart.setDate(gridStart.getDate() - ((firstOfMonth.getDay() + 6) % 7));
  const days: Date[] = [];
  for (let i = 0; i < 42; i++) {
    const d = new Date(gridStart);
    d.setDate(d.getDate() + i);
    days.push(d);
  }
  return days;
}

function buildDisplayItems(rangeStart: Date, rangeEnd: Date): CalendarDisplayItem[] {
  const items: CalendarDisplayItem[] = [];

  // Calendar events
  const events = store.getCalendarEventsForRange(rangeStart.toISOString(), rangeEnd.toISOString());
  const visibleCalIds = new Set(store.getVisibleCalendars().map(c => c.id));

  for (const event of events) {
    if (event.calendarId && !visibleCalIds.has(event.calendarId)) continue;
    if (event.title === '__DELETED__') continue;

    const cal = event.calendarId ? store.calendars.find(c => c.id === event.calendarId) : null;
    const color = event.color ? `#${(event.color & 0xFFFFFF).toString(16).padStart(6, '0')}` : (cal ? `#${(cal.color & 0xFFFFFF).toString(16).padStart(6, '0')}` : 'var(--color-primary)');

    items.push({
      id: event.id,
      title: event.title,
      startTime: new Date(event.startTime),
      endTime: new Date(event.endTime),
      isAllDay: event.isAllDay,
      color,
      type: 'event',
      event,
    });
  }

  // Todos with due dates
  const todos = store.todos.filter(t => !t.isCompleted && t.dueDate);
  for (const todo of todos) {
    const dueDate = new Date(todo.dueDate!);
    if (dueDate < rangeStart || dueDate > rangeEnd) continue;

    let startTime = new Date(dueDate);
    let endTime = new Date(dueDate);
    let isAllDay = true;

    if (todo.dueTime) {
      const [h, m] = todo.dueTime.split(':').map(Number);
      startTime.setHours(h!, m!, 0, 0);
      endTime = new Date(startTime.getTime() + 30 * 60000);
      isAllDay = false;
    }

    items.push({
      id: todo.id,
      title: todo.title,
      startTime,
      endTime,
      isAllDay,
      color: getPriorityColor(todo.priority),
      type: 'todo',
      todo,
    });
  }

  return items.sort((a, b) => a.startTime.getTime() - b.startTime.getTime());
}

// ==================== WEEK VIEW ====================

function WeekViewGrid({ weekOffset, setWeekOffset }: { weekOffset: number; setWeekOffset: (v: number | ((v: number) => number)) => void }) {
  const [currentTime, setCurrentTime] = useState(new Date());
  const gridRef = useRef<HTMLDivElement>(null);
  const [dragOverSlot, setDragOverSlot] = useState<string | null>(null);

  useEffect(() => {
    const interval = setInterval(() => setCurrentTime(new Date()), 60000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (gridRef.current) {
      const hour = new Date().getHours();
      gridRef.current.scrollTop = Math.max(0, (hour - 2)) * 60;
    }
  }, []);

  const today = new Date();
  const todayStr = formatDate(today);
  const weekStart = getWeekStart(today);
  weekStart.setDate(weekStart.getDate() + weekOffset * 7);
  const days = getWeekDays(weekStart);

  const rangeStart = days[0]!;
  const rangeEnd = new Date(days[6]!);
  rangeEnd.setDate(rangeEnd.getDate() + 1);

  const items = buildDisplayItems(rangeStart, rangeEnd);
  const nowMinutes = currentTime.getHours() * 60 + currentTime.getMinutes();
  const isCurrentWeek = days.some(d => formatDate(d) === todayStr);
  const monthSet = new Set(days.map(d => d.getMonth()));
  const monthHeader = [...monthSet].map(m => MONTH_NAMES[m]).join(' / ') + ' ' + days[0]!.getFullYear();

  function handleSlotClick(date: Date, hour: number) {
    const dateStr = formatDate(date);
    const startTime = new Date(date);
    startTime.setHours(hour, 0, 0, 0);
    const endTime = new Date(startTime.getTime() + 60 * 60000);

    const title = prompt('Neues Event:');
    if (title) {
      store.addCalendarEvent({
        title,
        startTime: startTime.toISOString(),
        endTime: endTime.toISOString(),
      });
    }
  }

  function handleDrop(e: React.DragEvent, date: Date, hour: number) {
    e.preventDefault();
    setDragOverSlot(null);
    const eventId = e.dataTransfer.getData('text/calendar-event-id');
    if (eventId) {
      const newStart = new Date(date);
      newStart.setHours(hour, 0, 0, 0);
      store.moveCalendarEvent(eventId, newStart.toISOString());
    }
  }

  function handleDragOver(e: React.DragEvent, dateStr: string, hour: number) {
    e.preventDefault();
    setDragOverSlot(`${dateStr}-${hour}`);
  }

  // Group items by day
  const itemsByDate: Record<string, CalendarDisplayItem[]> = {};
  for (const item of items) {
    const ds = formatDate(item.startTime);
    if (!itemsByDate[ds]) itemsByDate[ds] = [];
    itemsByDate[ds]!.push(item);
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center justify-between px-6 py-3 border-b border-border">
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => setWeekOffset(w => w - 1)}>
            <ChevronLeft className="h-4 w-4" />
          </Button>
          <Button variant="outline" size="sm" className="h-8 text-xs" onClick={() => setWeekOffset(0)}>
            Heute
          </Button>
          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => setWeekOffset(w => w + 1)}>
            <ChevronRight className="h-4 w-4" />
          </Button>
        </div>
        <h2 className="text-lg font-semibold">{monthHeader}</h2>
      </div>

      <div className="grid border-b border-border" style={{ gridTemplateColumns: '60px repeat(7, 1fr)' }}>
        <div />
        {days.map((d, i) => {
          const isToday = formatDate(d) === todayStr;
          return (
            <div key={i} className={cn("flex flex-col items-center py-2 text-xs", isToday && "text-primary")}>
              <span className="text-muted-foreground">{DAY_NAMES[i]}</span>
              <span className={cn(
                "w-7 h-7 flex items-center justify-center rounded-full text-sm font-semibold mt-0.5",
                isToday && "bg-primary text-primary-foreground"
              )}>
                {d.getDate()}
              </span>
            </div>
          );
        })}
      </div>

      {/* All-day events */}
      <div className="grid border-b border-border min-h-[40px]" style={{ gridTemplateColumns: '60px repeat(7, 1fr)' }}>
        <div className="flex items-center justify-center text-[10px] text-muted-foreground">Ganzt.</div>
        {days.map((d, i) => {
          const dateStr = formatDate(d);
          const allDay = (itemsByDate[dateStr] || []).filter(item => item.isAllDay);
          return (
            <div key={i} className="px-0.5 py-0.5 border-l border-border">
              {allDay.slice(0, 3).map(item => (
                <div
                  key={item.id}
                  className="text-[10px] px-1 py-0.5 mb-0.5 rounded border-l-2 truncate cursor-pointer hover:opacity-80"
                  style={{ borderLeftColor: item.color, backgroundColor: item.color + '22' }}
                >
                  {item.title}
                  {item.type === 'todo' && <span className="text-muted-foreground ml-1">·Aufgabe</span>}
                </div>
              ))}
              {allDay.length > 3 && <div className="text-[9px] text-muted-foreground px-1">+{allDay.length - 3}</div>}
            </div>
          );
        })}
      </div>

      {/* Time grid */}
      <div className="flex-1 overflow-y-auto" ref={gridRef}>
        <div className="relative grid" style={{ gridTemplateColumns: '60px repeat(7, 1fr)' }}>
          <div>
            {HOURS.map(h => (
              <div key={h} className="h-[60px] border-b border-border/30 flex justify-end pr-2 pt-0">
                <span className="text-[10px] text-muted-foreground -translate-y-1.5">
                  {String(h).padStart(2, '0')}:00
                </span>
              </div>
            ))}
          </div>

          {days.map((d, dayIdx) => {
            const dateStr = formatDate(d);
            const dayItems = (itemsByDate[dateStr] || []).filter(item => !item.isAllDay);
            const isToday = dateStr === todayStr;

            return (
              <div key={dayIdx} className={cn("relative border-l border-border", isToday && "bg-primary/5")}>
                {HOURS.map(h => {
                  const slotKey = `${dateStr}-${h}`;
                  return (
                    <div
                      key={h}
                      className={cn(
                        "h-[60px] border-b border-border/30 cursor-pointer hover:bg-accent/30",
                        dragOverSlot === slotKey && "bg-primary/10"
                      )}
                      onClick={() => handleSlotClick(d, h)}
                      onDragOver={(e) => handleDragOver(e, dateStr, h)}
                      onDragLeave={() => setDragOverSlot(null)}
                      onDrop={(e) => handleDrop(e, d, h)}
                    />
                  );
                })}

                {dayItems.map(item => {
                  const top = item.startTime.getHours() * 60 + item.startTime.getMinutes();
                  const endMin = item.endTime.getHours() * 60 + item.endTime.getMinutes();
                  const height = Math.max(20, endMin - top);

                  return (
                    <div
                      key={item.id}
                      draggable={item.type === 'event'}
                      onDragStart={(e) => {
                        if (item.event) {
                          e.dataTransfer.setData('text/calendar-event-id', item.event.id);
                        }
                      }}
                      className="absolute left-0.5 right-0.5 rounded text-[10px] px-1 py-0.5 border-l-2 cursor-pointer hover:opacity-80 overflow-hidden"
                      style={{
                        top: `${top}px`,
                        height: `${height}px`,
                        borderLeftColor: item.color,
                        backgroundColor: item.color + '22',
                      }}
                      title={item.title}
                    >
                      <span className="text-muted-foreground">
                        {String(item.startTime.getHours()).padStart(2, '0')}:{String(item.startTime.getMinutes()).padStart(2, '0')}
                      </span>{' '}
                      <span className="font-medium">{item.title}</span>
                      {item.type === 'todo' && <span className="text-muted-foreground ml-1 italic text-[9px]">Aufgabe</span>}
                    </div>
                  );
                })}

                {isToday && isCurrentWeek && (
                  <div className="absolute left-0 right-0 pointer-events-none z-10" style={{ top: `${nowMinutes}px` }}>
                    <div className="relative flex items-center">
                      <div className="w-2 h-2 rounded-full bg-destructive -ml-1" />
                      <div className="flex-1 h-[2px] bg-destructive" />
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

// ==================== MONTH VIEW ====================

function MonthViewGrid({ monthOffset, setMonthOffset }: { monthOffset: number; setMonthOffset: (v: number | ((v: number) => number)) => void }) {
  const today = new Date();
  const todayStr = formatDate(today);
  const viewDate = new Date(today.getFullYear(), today.getMonth() + monthOffset, 1);
  const days = getMonthDays(viewDate.getFullYear(), viewDate.getMonth());

  const rangeStart = days[0]!;
  const rangeEnd = new Date(days[days.length - 1]!);
  rangeEnd.setDate(rangeEnd.getDate() + 1);
  const items = buildDisplayItems(rangeStart, rangeEnd);

  const itemsByDate: Record<string, CalendarDisplayItem[]> = {};
  for (const item of items) {
    const ds = formatDate(item.startTime);
    if (!itemsByDate[ds]) itemsByDate[ds] = [];
    itemsByDate[ds]!.push(item);
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center justify-between px-6 py-3 border-b border-border">
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => setMonthOffset(m => m - 1)}>
            <ChevronLeft className="h-4 w-4" />
          </Button>
          <Button variant="outline" size="sm" className="h-8 text-xs" onClick={() => setMonthOffset(0)}>
            Heute
          </Button>
          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => setMonthOffset(m => m + 1)}>
            <ChevronRight className="h-4 w-4" />
          </Button>
        </div>
        <h2 className="text-lg font-semibold">{MONTH_NAMES[viewDate.getMonth()]} {viewDate.getFullYear()}</h2>
      </div>

      <div className="grid grid-cols-7 border-b border-border">
        {DAY_NAMES.map(d => (
          <div key={d} className="py-2 text-center text-xs text-muted-foreground font-medium">{d}</div>
        ))}
      </div>

      <div className="grid grid-cols-7 flex-1">
        {days.map((d, i) => {
          const ds = formatDate(d);
          const isCurrentMonth = d.getMonth() === viewDate.getMonth();
          const isToday = ds === todayStr;
          const dayItems = itemsByDate[ds] || [];

          return (
            <div key={i} className={cn(
              "border-b border-r border-border p-1 min-h-[80px]",
              !isCurrentMonth && "opacity-40"
            )}>
              <div className={cn(
                "text-xs font-medium mb-1",
                isToday && "text-primary font-bold"
              )}>
                <span className={cn(
                  "w-6 h-6 inline-flex items-center justify-center rounded-full",
                  isToday && "bg-primary text-primary-foreground"
                )}>
                  {d.getDate()}
                </span>
              </div>
              {dayItems.slice(0, 3).map(item => (
                <div
                  key={item.id}
                  className="text-[9px] px-1 py-0.5 mb-0.5 rounded truncate border-l-2"
                  style={{ borderLeftColor: item.color, backgroundColor: item.color + '15' }}
                >
                  {!item.isAllDay && (
                    <span className="text-muted-foreground mr-0.5">
                      {String(item.startTime.getHours()).padStart(2, '0')}:{String(item.startTime.getMinutes()).padStart(2, '0')}
                    </span>
                  )}
                  {item.title}
                </div>
              ))}
              {dayItems.length > 3 && (
                <div className="text-[9px] text-muted-foreground px-1">+{dayItems.length - 3} mehr</div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ==================== AGENDA VIEW ====================

function AgendaViewList() {
  const today = new Date();
  const rangeEnd = new Date(today);
  rangeEnd.setDate(rangeEnd.getDate() + 30);

  const items = buildDisplayItems(today, rangeEnd);

  const grouped: Record<string, CalendarDisplayItem[]> = {};
  for (const item of items) {
    const ds = formatDate(item.startTime);
    if (!grouped[ds]) grouped[ds] = [];
    grouped[ds]!.push(item);
  }

  const sortedDays = Object.keys(grouped).sort();

  if (sortedDays.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-muted-foreground">
        <Calendar className="h-12 w-12 mb-3" />
        <p className="text-lg">Keine Termine</p>
      </div>
    );
  }

  const todayStr = formatDate(today);

  return (
    <div className="overflow-y-auto h-full">
      {sortedDays.map(ds => {
        const dayItems = grouped[ds]!;
        const date = new Date(ds);
        const isToday = ds === todayStr;
        const dayName = isToday ? 'Heute' : DAY_NAMES[(date.getDay() + 6) % 7];
        const monthDay = `${date.getDate()}. ${MONTH_NAMES[date.getMonth()]}`;

        return (
          <div key={ds}>
            <div className={cn(
              "px-6 py-2 text-sm font-semibold border-b border-border",
              isToday ? "bg-primary/10 text-primary" : "bg-card"
            )}>
              {dayName} – {monthDay}
            </div>
            {dayItems.map(item => (
              <div key={item.id} className="flex items-center gap-3 px-6 py-3 border-b border-border hover:bg-accent/30 cursor-pointer">
                <div className="w-1 h-8 rounded" style={{ backgroundColor: item.color }} />
                <div className="flex-1 min-w-0">
                  <div className="text-sm font-medium truncate">{item.title}</div>
                  <div className="text-xs text-muted-foreground">
                    {item.isAllDay ? 'Ganztägig' : (
                      `${String(item.startTime.getHours()).padStart(2, '0')}:${String(item.startTime.getMinutes()).padStart(2, '0')} – ${String(item.endTime.getHours()).padStart(2, '0')}:${String(item.endTime.getMinutes()).padStart(2, '0')}`
                    )}
                    {item.type === 'todo' && ' · Aufgabe'}
                  </div>
                </div>
              </div>
            ))}
          </div>
        );
      })}
    </div>
  );
}

// ==================== MAIN VIEW ====================

export function CalendarView() {
  useStoreState();
  const [viewMode, setViewMode] = useState<CalendarViewMode>('week');
  const [weekOffset, setWeekOffset] = useState(0);
  const [monthOffset, setMonthOffset] = useState(0);

  return (
    <div className="flex flex-col h-full">
      {/* View mode switcher */}
      <div className="flex items-center justify-center gap-1 px-4 py-2 border-b border-border">
        {([
          ['day', 'Tag', <Calendar className="h-3.5 w-3.5" />],
          ['week', 'Woche', <LayoutGrid className="h-3.5 w-3.5" />],
          ['month', 'Monat', <LayoutGrid className="h-3.5 w-3.5" />],
          ['agenda', 'Agenda', <List className="h-3.5 w-3.5" />],
        ] as const).map(([mode, label, icon]) => (
          <Button
            key={mode}
            variant={viewMode === mode ? 'secondary' : 'ghost'}
            size="sm"
            className="h-7 text-xs gap-1"
            onClick={() => setViewMode(mode as CalendarViewMode)}
          >
            {icon} {label}
          </Button>
        ))}
      </div>

      {/* View content */}
      {viewMode === 'week' && <WeekViewGrid weekOffset={weekOffset} setWeekOffset={setWeekOffset} />}
      {viewMode === 'day' && <WeekViewGrid weekOffset={weekOffset} setWeekOffset={setWeekOffset} />}
      {viewMode === 'month' && <MonthViewGrid monthOffset={monthOffset} setMonthOffset={setMonthOffset} />}
      {viewMode === 'agenda' && <AgendaViewList />}
    </div>
  );
}
