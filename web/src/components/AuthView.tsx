import React, { useState } from 'react';
import { signIn, signUp } from '../lib/auth';
import { isSupabaseAvailable } from '../lib/supabase';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';

interface AuthViewProps {
  onAuthenticated: () => void;
  onSkip: () => void;
}

export function AuthView({ onAuthenticated, onSkip }: AuthViewProps) {
  const [mode, setMode] = useState<'login' | 'signup'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const available = isSupabaseAvailable();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    if (!email || !password) {
      setError('Bitte E-Mail und Passwort eingeben.');
      return;
    }

    if (mode === 'signup' && password !== confirmPassword) {
      setError('Passwoerter stimmen nicht ueberein.');
      return;
    }

    if (mode === 'signup' && password.length < 8) {
      setError('Passwort muss mindestens 8 Zeichen lang sein.');
      return;
    }

    setLoading(true);

    try {
      if (mode === 'login') {
        const result = await signIn(email, password);
        if (result.error) {
          setError(result.error);
        } else {
          onAuthenticated();
        }
      } else {
        const result = await signUp(email, password);
        if (result.error) {
          setError(result.error);
        } else {
          setSuccess('Konto erstellt! Bitte bestaetigen Sie Ihre E-Mail, dann melden Sie sich an.');
          setMode('login');
        }
      }
    } catch (e: any) {
      setError(e?.message ?? 'Ein Fehler ist aufgetreten.');
    } finally {
      setLoading(false);
    }
  }

  if (!available) {
    return (
      <div className="flex items-center justify-center h-screen bg-background">
        <Card className="w-full max-w-md mx-4">
          <CardHeader className="text-center">
            <div className="w-12 h-12 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-xl font-bold mx-auto mb-2">
              C
            </div>
            <CardTitle className="text-xl">Chukdoo</CardTitle>
            <CardDescription>
              Cloud-Sync ist nicht konfiguriert. Die App laeuft im lokalen Modus.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button className="w-full" onClick={onSkip}>
              Lokal verwenden
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center h-screen bg-background">
      <Card className="w-full max-w-md mx-4">
        <CardHeader className="text-center">
          <div className="w-12 h-12 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-xl font-bold mx-auto mb-2">
            C
          </div>
          <CardTitle className="text-xl">
            {mode === 'login' ? 'Anmelden' : 'Registrieren'}
          </CardTitle>
          <CardDescription>
            {mode === 'login'
              ? 'Melden Sie sich an, um Ihre Aufgaben geraeteuebergreifend zu synchronisieren.'
              : 'Erstellen Sie ein Konto fuer die Cloud-Synchronisation mit Ende-zu-Ende-Verschluesselung.'}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            {error && (
              <div className="text-sm text-destructive bg-destructive/10 rounded-md p-3">
                {error}
              </div>
            )}
            {success && (
              <div className="text-sm text-green-600 bg-green-50 dark:bg-green-950/30 rounded-md p-3">
                {success}
              </div>
            )}

            <div className="space-y-2">
              <label htmlFor="email" className="text-sm font-medium text-foreground">
                E-Mail
              </label>
              <Input
                id="email"
                type="email"
                placeholder="name@beispiel.de"
                value={email}
                onChange={e => setEmail(e.target.value)}
                autoComplete="email"
                disabled={loading}
              />
            </div>

            <div className="space-y-2">
              <label htmlFor="password" className="text-sm font-medium text-foreground">
                Passwort
              </label>
              <Input
                id="password"
                type="password"
                placeholder="Passwort"
                value={password}
                onChange={e => setPassword(e.target.value)}
                autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
                disabled={loading}
              />
            </div>

            {mode === 'signup' && (
              <div className="space-y-2">
                <label htmlFor="confirm-password" className="text-sm font-medium text-foreground">
                  Passwort bestaetigen
                </label>
                <Input
                  id="confirm-password"
                  type="password"
                  placeholder="Passwort wiederholen"
                  value={confirmPassword}
                  onChange={e => setConfirmPassword(e.target.value)}
                  autoComplete="new-password"
                  disabled={loading}
                />
              </div>
            )}

            <Button type="submit" className="w-full" disabled={loading}>
              {loading
                ? 'Wird geladen...'
                : mode === 'login'
                  ? 'Anmelden'
                  : 'Registrieren'}
            </Button>

            <div className="text-center text-sm text-muted-foreground">
              {mode === 'login' ? (
                <>
                  Noch kein Konto?{' '}
                  <button
                    type="button"
                    className="text-primary hover:underline"
                    onClick={() => { setMode('signup'); setError(null); setSuccess(null); }}
                  >
                    Registrieren
                  </button>
                </>
              ) : (
                <>
                  Bereits registriert?{' '}
                  <button
                    type="button"
                    className="text-primary hover:underline"
                    onClick={() => { setMode('login'); setError(null); setSuccess(null); }}
                  >
                    Anmelden
                  </button>
                </>
              )}
            </div>

            <div className="relative">
              <div className="absolute inset-0 flex items-center">
                <span className="w-full border-t border-border" />
              </div>
              <div className="relative flex justify-center text-xs uppercase">
                <span className="bg-card px-2 text-muted-foreground">oder</span>
              </div>
            </div>

            <Button type="button" variant="outline" className="w-full" onClick={onSkip} disabled={loading}>
              Lokal verwenden
            </Button>
            <p className="text-xs text-muted-foreground text-center">
              Alle Daten bleiben lokal auf diesem Geraet.
            </p>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
