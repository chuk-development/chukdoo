import React, { useState, useEffect, useRef, useCallback } from 'react';
import { store } from '../store/store';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Card, CardContent } from './ui/card';
import { Badge } from './ui/badge';
import { Tabs, TabsList, TabsTrigger } from './ui/tabs';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { cn } from '../lib/utils';
import { Play, Pause, RotateCcw, Flag, Link } from 'lucide-react';

type TimerMode = 'stopwatch' | 'timer' | 'pomodoro';

function formatTime(ms: number): string {
  const totalSec = Math.floor(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  if (h > 0) {
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function formatMs(ms: number): string {
  return String(Math.floor((ms % 1000) / 10)).padStart(2, '0');
}

export function TimerView() {
  const [mode, setMode] = useState<TimerMode>('pomodoro');
  const [running, setRunning] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [laps, setLaps] = useState<number[]>([]);
  const [timerDuration, setTimerDuration] = useState(5 * 60 * 1000);
  const [timerRemaining, setTimerRemaining] = useState(5 * 60 * 1000);
  const [pomodoroPhase, setPomodoroPhase] = useState<'work' | 'break'>('work');
  const [pomodoroSessions, setPomodoroSessions] = useState(0);
  const [pomodoroRemaining, setPomodoroRemaining] = useState(25 * 60 * 1000);
  const [linkedTodoId, setLinkedTodoId] = useState<string | null>(null);
  const [timerInputMin, setTimerInputMin] = useState('5');
  const [timerInputSec, setTimerInputSec] = useState('0');
  const [timerDone, setTimerDone] = useState(false);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const lastTickRef = useRef<number>(0);

  const WORK_DURATION = 25 * 60 * 1000;
  const BREAK_DURATION = 5 * 60 * 1000;

  const stop = useCallback(() => {
    setRunning(false);
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, []);

  useEffect(() => {
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, []);

  useEffect(() => {
    if (!running) return;

    lastTickRef.current = Date.now();
    intervalRef.current = setInterval(() => {
      const now = Date.now();
      const delta = now - lastTickRef.current;
      lastTickRef.current = now;

      if (mode === 'stopwatch') {
        setElapsed(prev => prev + delta);
      } else if (mode === 'timer') {
        setTimerRemaining(prev => {
          const next = prev - delta;
          if (next <= 0) {
            stop();
            setTimerDone(true);
            return 0;
          }
          return next;
        });
      } else if (mode === 'pomodoro') {
        setPomodoroRemaining(prev => {
          const next = prev - delta;
          if (next <= 0) {
            if (pomodoroPhase === 'work') {
              setPomodoroSessions(s => s + 1);
              setPomodoroPhase('break');
              return BREAK_DURATION;
            } else {
              setPomodoroPhase('work');
              return WORK_DURATION;
            }
          }
          return next;
        });
      }
    }, 100);

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    };
  }, [running, mode, pomodoroPhase, stop]);

  function start() {
    if (mode === 'timer' && !running && timerRemaining <= 0) {
      const dur = (parseInt(timerInputMin) || 0) * 60000 + (parseInt(timerInputSec) || 0) * 1000;
      setTimerDuration(dur);
      setTimerRemaining(dur);
      setTimerDone(false);
    }
    setRunning(true);
  }

  function reset() {
    stop();
    if (mode === 'stopwatch') {
      setElapsed(0);
      setLaps([]);
    } else if (mode === 'timer') {
      const dur = (parseInt(timerInputMin) || 0) * 60000 + (parseInt(timerInputSec) || 0) * 1000;
      setTimerDuration(dur);
      setTimerRemaining(dur);
      setTimerDone(false);
    } else {
      setPomodoroPhase('work');
      setPomodoroRemaining(WORK_DURATION);
      setPomodoroSessions(0);
    }
  }

  function lap() {
    setLaps(prev => [...prev, elapsed]);
  }

  function switchMode(m: TimerMode) {
    stop();
    setMode(m);
    setElapsed(0);
    setLaps([]);
    setTimerDone(false);
    if (m === 'timer') {
      const dur = (parseInt(timerInputMin) || 0) * 60000 + (parseInt(timerInputSec) || 0) * 1000;
      setTimerDuration(dur);
      setTimerRemaining(dur);
    }
    if (m === 'pomodoro') {
      setPomodoroPhase('work');
      setPomodoroRemaining(WORK_DURATION);
    }
  }

  function applyTimerDuration() {
    const dur = (parseInt(timerInputMin) || 0) * 60000 + (parseInt(timerInputSec) || 0) * 1000;
    setTimerDuration(dur);
    setTimerRemaining(dur);
    setTimerDone(false);
  }

  const activeTodos = store.todos.filter(t => !t.isCompleted);
  const linkedTodo = linkedTodoId ? store.todos.find(t => t.id === linkedTodoId) : null;

  let displayTime = '';
  let progress = 0;

  if (mode === 'stopwatch') {
    displayTime = formatTime(elapsed);
  } else if (mode === 'timer') {
    displayTime = formatTime(timerRemaining);
    progress = timerDuration > 0 ? (1 - timerRemaining / timerDuration) * 100 : 0;
  } else {
    displayTime = formatTime(pomodoroRemaining);
    const total = pomodoroPhase === 'work' ? WORK_DURATION : BREAK_DURATION;
    progress = (1 - pomodoroRemaining / total) * 100;
  }

  return (
    <div className="flex flex-col items-center max-w-lg mx-auto px-8 py-12">
      {/* Mode tabs */}
      <Tabs value={mode} onValueChange={(v) => switchMode(v as TimerMode)} className="mb-8">
        <TabsList>
          <TabsTrigger value="stopwatch">Stoppuhr</TabsTrigger>
          <TabsTrigger value="timer">Timer</TabsTrigger>
          <TabsTrigger value="pomodoro">Pomodoro</TabsTrigger>
        </TabsList>
      </Tabs>

      {/* Timer display */}
      <div className="relative w-52 h-52 flex items-center justify-center mb-6">
        {(mode === 'timer' || mode === 'pomodoro') && (
          <svg className="absolute inset-0 w-full h-full" viewBox="0 0 200 200">
            <circle className="timer-ring-bg" cx="100" cy="100" r="90" />
            <circle
              className="timer-ring-fg"
              cx="100" cy="100" r="90"
              style={{
                strokeDasharray: `${2 * Math.PI * 90}`,
                strokeDashoffset: `${2 * Math.PI * 90 * (1 - progress / 100)}`,
              }}
            />
          </svg>
        )}
        <div className="text-center z-10">
          <span className="text-4xl font-mono font-bold tabular-nums">{displayTime}</span>
          {mode === 'stopwatch' && <span className="text-lg font-mono text-muted-foreground">.{formatMs(elapsed)}</span>}
        </div>
      </div>

      {/* Pomodoro info */}
      {mode === 'pomodoro' && (
        <div className="flex items-center gap-3 mb-6">
          <Badge variant={pomodoroPhase === 'work' ? 'default' : 'secondary'}>
            {pomodoroPhase === 'work' ? 'Arbeiten' : 'Pause'}
          </Badge>
          <span className="text-sm text-muted-foreground">{pomodoroSessions} Sitzungen</span>
        </div>
      )}

      {/* Timer input */}
      {mode === 'timer' && !running && timerRemaining === timerDuration && (
        <div className="flex items-center gap-2 mb-6">
          <div className="flex flex-col items-center">
            <Input
              type="number"
              min="0"
              max="99"
              value={timerInputMin}
              onChange={e => setTimerInputMin(e.target.value)}
              onBlur={applyTimerDuration}
              className="w-16 text-center"
            />
            <span className="text-[10px] text-muted-foreground mt-1">Min</span>
          </div>
          <span className="text-xl font-bold text-muted-foreground">:</span>
          <div className="flex flex-col items-center">
            <Input
              type="number"
              min="0"
              max="59"
              value={timerInputSec}
              onChange={e => setTimerInputSec(e.target.value)}
              onBlur={applyTimerDuration}
              className="w-16 text-center"
            />
            <span className="text-[10px] text-muted-foreground mt-1">Sek</span>
          </div>
        </div>
      )}

      {/* Timer done alert */}
      {timerDone && mode === 'timer' && (
        <Badge variant="destructive" className="mb-4 text-sm px-4 py-1">
          Zeit abgelaufen!
        </Badge>
      )}

      {/* Controls */}
      <div className="flex items-center gap-3 mb-8">
        {!running ? (
          <Button size="lg" onClick={start} className="gap-2">
            <Play className="h-4 w-4" />
            Start
          </Button>
        ) : (
          <Button size="lg" variant="secondary" onClick={stop} className="gap-2">
            <Pause className="h-4 w-4" />
            Pause
          </Button>
        )}
        {mode === 'stopwatch' && running && (
          <Button size="lg" variant="outline" onClick={lap} className="gap-2">
            <Flag className="h-4 w-4" />
            Runde
          </Button>
        )}
        <Button size="lg" variant="outline" onClick={reset} className="gap-2">
          <RotateCcw className="h-4 w-4" />
          Reset
        </Button>
      </div>

      {/* Link to todo */}
      <Card className="w-full mb-6">
        <CardContent className="pt-4">
          <div className="flex items-center gap-2 mb-2 text-sm text-muted-foreground">
            <Link className="h-4 w-4" />
            Aufgabe verknupfen
          </div>
          <Select value={linkedTodoId ?? '__none__'} onValueChange={v => setLinkedTodoId(v === '__none__' ? null : v)}>
            <SelectTrigger className="w-full">
              <SelectValue placeholder="-- Aufgabe verknupfen --" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="__none__">Keine</SelectItem>
              {activeTodos.map(t => (
                <SelectItem key={t.id} value={t.id}>{t.title}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          {linkedTodo && (
            <div className="text-xs text-muted-foreground mt-2">
              Verknupft: <strong className="text-foreground">{linkedTodo.title}</strong>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Laps */}
      {mode === 'stopwatch' && laps.length > 0 && (
        <Card className="w-full">
          <CardContent className="pt-4">
            <h3 className="text-sm font-semibold mb-3">Runden</h3>
            <div className="space-y-1">
              {[...laps].reverse().map((l, i) => {
                const actualIdx = laps.length - 1 - i;
                return (
                  <div key={actualIdx} className="flex items-center justify-between text-sm py-1 border-b border-border/50 last:border-0">
                    <span className="text-muted-foreground">#{actualIdx + 1}</span>
                    <span className="font-mono">{formatTime(l)}.{formatMs(l)}</span>
                    {actualIdx > 0 && (
                      <span className="text-xs text-muted-foreground">+{formatTime(l - laps[actualIdx - 1]!)}</span>
                    )}
                  </div>
                );
              })}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
