import React, { useEffect, useState } from 'react';
import { Sidebar } from './Sidebar';
import { MainContent } from './MainContent';
import { AuthView } from './AuthView';
import { useStoreState } from '../store/hooks';
import { TooltipProvider } from './ui/tooltip';
import { initSupabase, isSupabaseAvailable } from '../lib/supabase';
import { getSession, tryRestoreKey, onAuthStateChange, bootstrapFromServer } from '../lib/auth';
import { store } from '../store/store';
import type { Session } from '@supabase/supabase-js';

type AppState = 'loading' | 'auth' | 'app';

export function App() {
  useStoreState(); // subscribe to store updates
  const [appState, setAppState] = useState<AppState>('loading');
  const [session, setSession] = useState<Session | null>(null);

  useEffect(() => {
    let unsubscribe: (() => void) | null = null;

    async function init() {
      // Initialize Supabase (non-blocking - works without it)
      await initSupabase();

      if (!isSupabaseAvailable()) {
        // No Supabase config - go straight to app in local mode
        setAppState('app');
        return;
      }

      // Check existing session
      const existingSession = await getSession();
      if (existingSession) {
        setSession(existingSession);
        store.setSupabaseEnabled(true);

        // Try to restore encryption key from sessionStorage
        await tryRestoreKey();

        // Trigger initial sync
        store.syncWithSupabase();

        setAppState('app');
      } else {
        // Try bootstrap from server (picks up Flutter session from keyring)
        const bootstrapped = await bootstrapFromServer();
        if (bootstrapped) {
          const newSession = await getSession();
          setSession(newSession);
          store.setSupabaseEnabled(true);
          store.syncWithSupabase();
          setAppState('app');
        } else {
          // Show auth screen
          setAppState('auth');
        }
      }

      // Listen for auth state changes
      unsubscribe = onAuthStateChange((event, newSession) => {
        setSession(newSession);
        if (event === 'SIGNED_OUT') {
          store.setSupabaseEnabled(false);
        } else if (newSession) {
          store.setSupabaseEnabled(true);
        }
      });
    }

    init();

    return () => {
      if (unsubscribe) unsubscribe();
    };
  }, []);

  if (appState === 'loading') {
    return (
      <div className="flex items-center justify-center h-screen bg-background">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-primary text-primary-foreground flex items-center justify-center text-lg font-bold">
            C
          </div>
          <span className="text-sm text-muted-foreground">Wird geladen...</span>
        </div>
      </div>
    );
  }

  if (appState === 'auth') {
    return (
      <AuthView
        onAuthenticated={() => {
          store.setSupabaseEnabled(true);
          store.syncWithSupabase();
          // Re-fetch session
          getSession().then(s => setSession(s));
          setAppState('app');
        }}
        onSkip={() => {
          setAppState('app');
        }}
      />
    );
  }

  const userEmail = session?.user?.email ?? null;

  return (
    <TooltipProvider>
      <div className="flex h-screen w-screen overflow-hidden">
        <Sidebar
          userEmail={userEmail}
          onShowAuth={() => setAppState('auth')}
        />
        <MainContent />
      </div>
    </TooltipProvider>
  );
}
