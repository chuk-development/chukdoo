import React, { useState } from 'react';
import { store } from '../store/store';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Card, CardContent } from './ui/card';
import { Badge } from './ui/badge';
import { Separator } from './ui/separator';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { cn } from '../lib/utils';
import { Plus, Check, Trash2, Flame, Repeat } from 'lucide-react';

const HABIT_COLORS = ['#00BFA5', '#FF5252', '#FFB74D', '#64B5F6', '#AB47BC', '#66BB6A', '#EC407A', '#26C6DA'];

function getLastNDays(n: number): string[] {
  const days: string[] = [];
  const d = new Date();
  for (let i = n - 1; i >= 0; i--) {
    const dd = new Date(d);
    dd.setDate(dd.getDate() - i);
    days.push(dd.toISOString().split('T')[0]!);
  }
  return days;
}

function getMonthLabel(dateStr: string): string {
  const d = new Date(dateStr);
  return ['Jan', 'Feb', 'Mar', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'][d.getMonth()]!;
}

export function HabitView() {
  const [showAdd, setShowAdd] = useState(false);
  const [newName, setNewName] = useState('');
  const [newColor, setNewColor] = useState(HABIT_COLORS[0]!);
  const [newFreq, setNewFreq] = useState<'daily' | 'weekly'>('daily');
  const [editId, setEditId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');

  const habits = store.getHabits();
  const todayStr = new Date().toISOString().split('T')[0]!;

  const gridDays = getLastNDays(84);
  const weeks: string[][] = [];
  for (let i = 0; i < gridDays.length; i += 7) {
    weeks.push(gridDays.slice(i, i + 7));
  }

  function addHabit() {
    if (!newName.trim()) return;
    store.addHabit({ name: newName.trim(), color: newColor, frequency: newFreq });
    setNewName('');
    setShowAdd(false);
  }

  function startEdit(id: string, name: string) {
    setEditId(id);
    setEditName(name);
  }

  function saveEdit() {
    if (editId && editName.trim()) {
      const habit = store.habits.find(h => h.id === editId);
      if (habit) {
        habit.name = editName.trim();
        store['save']();
        store['notify']();
      }
    }
    setEditId(null);
  }

  return (
    <div className="max-w-3xl mx-auto px-8 py-8">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-xl font-bold">Gewohnheiten</h1>
        <Button size="sm" className="gap-1" onClick={() => setShowAdd(!showAdd)}>
          <Plus className="h-4 w-4" />
          Neu
        </Button>
      </div>

      {/* Add form */}
      {showAdd && (
        <Card className="mb-6">
          <CardContent className="pt-4 space-y-3">
            <Input
              placeholder="Gewohnheit eingeben..."
              value={newName}
              onChange={e => setNewName(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && addHabit()}
              autoFocus
            />
            <div className="flex items-center justify-between gap-4">
              <div className="flex gap-1.5">
                {HABIT_COLORS.map(c => (
                  <button
                    key={c}
                    className={cn(
                      "w-6 h-6 rounded-full transition-all cursor-pointer border-2",
                      newColor === c ? "border-foreground scale-110" : "border-transparent hover:scale-105"
                    )}
                    style={{ background: c }}
                    onClick={() => setNewColor(c)}
                  />
                ))}
              </div>
              <Select value={newFreq} onValueChange={v => setNewFreq(v as 'daily' | 'weekly')}>
                <SelectTrigger className="w-32">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="daily">Taglich</SelectItem>
                  <SelectItem value="weekly">Wochentlich</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="flex justify-end gap-2">
              <Button variant="ghost" size="sm" onClick={() => setShowAdd(false)}>Abbrechen</Button>
              <Button size="sm" onClick={addHabit} disabled={!newName.trim()}>Hinzufugen</Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Empty state */}
      {habits.length === 0 && !showAdd && (
        <div className="flex flex-col items-center justify-center py-16 text-muted-foreground">
          <Repeat className="h-12 w-12 mb-3 opacity-30" />
          <div className="text-sm font-medium">Keine Gewohnheiten</div>
          <div className="text-xs mt-1">Erstelle deine erste Gewohnheit mit dem + Button</div>
        </div>
      )}

      {/* Habit list */}
      <div className="space-y-4">
        {habits.map(habit => {
          const isDoneToday = habit.completions.includes(todayStr);
          return (
            <Card key={habit.id}>
              <CardContent className="pt-4">
                {/* Header */}
                <div className="flex items-center gap-3 mb-3">
                  <button
                    className={cn(
                      "flex items-center justify-center w-6 h-6 rounded-full border-2 shrink-0 transition-all cursor-pointer",
                      isDoneToday ? "text-white" : "hover:opacity-80"
                    )}
                    style={{
                      borderColor: habit.color,
                      background: isDoneToday ? habit.color : 'transparent',
                    }}
                    onClick={() => store.toggleHabitCompletion(habit.id)}
                  >
                    {isDoneToday && <Check className="h-3 w-3" />}
                  </button>
                  <div className="flex-1 min-w-0">
                    {editId === habit.id ? (
                      <Input
                        className="h-7 text-sm"
                        value={editName}
                        onChange={e => setEditName(e.target.value)}
                        onBlur={saveEdit}
                        onKeyDown={e => e.key === 'Enter' && saveEdit()}
                        autoFocus
                      />
                    ) : (
                      <span
                        className="text-sm font-medium cursor-pointer"
                        onDoubleClick={() => startEdit(habit.id, habit.name)}
                      >
                        {habit.name}
                      </span>
                    )}
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className="text-xs text-muted-foreground">
                        {habit.frequency === 'daily' ? 'Taglich' : 'Wochentlich'}
                      </span>
                      {habit.streak > 0 && (
                        <Badge variant="secondary" className="text-[10px] px-1.5 py-0 h-4 gap-0.5">
                          <Flame className="h-2.5 w-2.5 text-p2" />
                          {habit.streak} Tage
                        </Badge>
                      )}
                    </div>
                  </div>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-7 w-7 text-muted-foreground hover:text-destructive shrink-0"
                    onClick={() => {
                      if (confirm('Gewohnheit loschen?')) store.deleteHabit(habit.id);
                    }}
                    title="Loschen"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </Button>
                </div>

                {/* Contribution grid */}
                <div className="overflow-x-auto">
                  <div className="flex gap-[3px]">
                    {weeks.map((week, wi) => (
                      <div key={wi} className="flex flex-col gap-[3px]">
                        {week.map(day => {
                          const done = habit.completions.includes(day);
                          return (
                            <div
                              key={day}
                              className={cn(
                                "w-[10px] h-[10px] rounded-[2px] cursor-pointer transition-colors",
                                done ? "" : "bg-secondary hover:bg-accent"
                              )}
                              style={done ? { background: habit.color } : {}}
                              title={`${day} ${done ? '(erledigt)' : ''}`}
                              onClick={() => store.toggleHabitCompletion(habit.id, day)}
                            />
                          );
                        })}
                      </div>
                    ))}
                  </div>
                  <div className="flex gap-[3px] mt-1">
                    {weeks.map((week, wi) => {
                      const firstDay = week[0]!;
                      const dayNum = new Date(firstDay).getDate();
                      if (dayNum <= 7) {
                        return <span key={wi} className="text-[8px] text-muted-foreground w-[10px] text-center">{getMonthLabel(firstDay)}</span>;
                      }
                      return <span key={wi} className="w-[10px]" />;
                    })}
                  </div>
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
