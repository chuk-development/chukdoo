import React, { useState } from 'react';
import { PROJECT_COLORS } from '../store/store';
import type { Project } from '../types';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogDescription,
} from './ui/dialog';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Textarea } from './ui/textarea';
import { cn } from '../lib/utils';

interface Props {
  project?: Project;
  onClose: () => void;
  onSave: (data: { name: string; color: string; description: string }) => void;
  onDelete?: () => void;
}

export function ProjectDialog({ project, onClose, onSave, onDelete }: Props) {
  const [name, setName] = useState(project?.name ?? '');
  const [color, setColor] = useState(project?.color ?? PROJECT_COLORS[0]!);
  const [description, setDescription] = useState(project?.description ?? '');

  const handleSubmit = () => {
    if (!name.trim()) return;
    onSave({ name: name.trim(), color, description: description.trim() });
  };

  return (
    <Dialog open onOpenChange={(open) => { if (!open) onClose(); }}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{project ? 'Projekt bearbeiten' : 'Projekt hinzufugen'}</DialogTitle>
          <DialogDescription className="sr-only">
            {project ? 'Projekt bearbeiten' : 'Ein neues Projekt erstellen'}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium">Name</label>
            <Input
              autoFocus
              value={name}
              onChange={e => setName(e.target.value)}
              placeholder="Projektname"
              onKeyDown={e => { if (e.key === 'Enter') handleSubmit(); }}
            />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium">Beschreibung</label>
            <Textarea
              value={description}
              onChange={e => setDescription(e.target.value)}
              placeholder="Optionale Beschreibung..."
              rows={3}
            />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium">Farbe</label>
            <div className="flex flex-wrap gap-2">
              {PROJECT_COLORS.map(c => (
                <button
                  key={c}
                  className={cn(
                    "w-7 h-7 rounded-full transition-all cursor-pointer border-2",
                    color === c ? "border-foreground scale-110" : "border-transparent hover:scale-105"
                  )}
                  style={{ background: c }}
                  onClick={() => setColor(c)}
                />
              ))}
            </div>
          </div>
        </div>

        <DialogFooter className="flex-row gap-2">
          {onDelete && (
            <Button variant="destructive" size="sm" onClick={onDelete} className="mr-auto">
              Loschen
            </Button>
          )}
          <Button variant="ghost" size="sm" onClick={onClose}>
            Abbrechen
          </Button>
          <Button size="sm" onClick={handleSubmit} disabled={!name.trim()}>
            {project ? 'Speichern' : 'Hinzufugen'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
