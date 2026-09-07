import { createClient, type SupabaseClient } from '@supabase/supabase-js';

let supabaseClient: SupabaseClient | null = null;
let configLoaded = false;

interface SupabaseConfig {
  supabaseUrl: string;
  supabaseAnonKey: string;
}

/**
 * Fetch Supabase config from the server's /api/config endpoint.
 * Falls back to empty strings if not available (local-only mode).
 */
async function fetchConfig(): Promise<SupabaseConfig> {
  try {
    const res = await fetch('/api/config');
    if (!res.ok) throw new Error(`Config endpoint returned ${res.status}`);
    return await res.json() as SupabaseConfig;
  } catch {
    return { supabaseUrl: '', supabaseAnonKey: '' };
  }
}

/**
 * Initialize the Supabase client. Safe to call multiple times;
 * only the first call actually creates the client.
 */
export async function initSupabase(): Promise<SupabaseClient | null> {
  if (configLoaded) return supabaseClient;

  const config = await fetchConfig();
  configLoaded = true;

  if (!config.supabaseUrl || !config.supabaseAnonKey) {
    console.log('Supabase not configured - running in local-only mode');
    return null;
  }

  supabaseClient = createClient(config.supabaseUrl, config.supabaseAnonKey, {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: true,
    },
  });

  console.log('Supabase client initialized');
  return supabaseClient;
}

/**
 * Get the current Supabase client (may be null if not configured).
 */
export function getSupabase(): SupabaseClient | null {
  return supabaseClient;
}

/**
 * Whether Supabase is available and initialized.
 */
export function isSupabaseAvailable(): boolean {
  return supabaseClient !== null;
}
