import type { User, Session, AuthChangeEvent } from '@supabase/supabase-js';
import { getSupabase, isSupabaseAvailable } from './supabase';
import { deriveKey, exportKey, importKey, generateSalt } from './encryption';

type AuthListener = (event: AuthChangeEvent, session: Session | null) => void;

const SESSION_KEY_STORAGE = 'chukdoo_encryption_key';
const METADATA_SALT_KEY = 'chukdoo_kdf_salt';

// ---------- state ----------

let cachedKey: CryptoKey | null = null;

// ---------- auth operations ----------

/**
 * Sign in with email and password.
 * On success, derives the encryption key from the password and caches it.
 */
export async function signIn(email: string, password: string): Promise<{ user: User | null; error: string | null }> {
  const supabase = getSupabase();
  if (!supabase) return { user: null, error: 'Supabase ist nicht konfiguriert.' };

  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) return { user: null, error: error.message };

  const user = data.user;
  if (!user) return { user: null, error: 'Kein Benutzer zurueckgegeben.' };

  // Derive encryption key from password + salt in user metadata
  try {
    await initEncryptionKey(user, password);
  } catch (e: any) {
    console.error('Failed to derive encryption key:', e);
    // Non-fatal: user is logged in but encryption won't work until key is set
  }

  return { user, error: null };
}

/**
 * Sign up with email and password.
 * Creates a new salt, stores it in user metadata, derives the encryption key.
 */
export async function signUp(email: string, password: string): Promise<{ user: User | null; error: string | null }> {
  const supabase = getSupabase();
  if (!supabase) return { user: null, error: 'Supabase ist nicht konfiguriert.' };

  // Generate a fresh salt for this user
  const salt = generateSalt();
  const saltBase64 = btoa(String.fromCharCode(...salt));

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        [METADATA_SALT_KEY]: saltBase64,
        chukdoo_key_version: '1',
      },
    },
  });
  if (error) return { user: null, error: error.message };

  const user = data.user;
  if (!user) return { user: null, error: 'Kein Benutzer zurueckgegeben.' };

  // Derive key with the new salt
  try {
    const key = await deriveKey(password, salt);
    cachedKey = key;
    sessionStorage.setItem(SESSION_KEY_STORAGE, await exportKey(key));
  } catch (e: any) {
    console.error('Failed to derive encryption key on signup:', e);
  }

  return { user, error: null };
}

/**
 * Sign out the current user and clear the encryption key.
 */
export async function signOut(): Promise<void> {
  const supabase = getSupabase();
  if (supabase) {
    await supabase.auth.signOut();
  }
  cachedKey = null;
  sessionStorage.removeItem(SESSION_KEY_STORAGE);
}

/**
 * Get the current session (may be null).
 */
export async function getSession(): Promise<Session | null> {
  const supabase = getSupabase();
  if (!supabase) return null;
  const { data } = await supabase.auth.getSession();
  return data.session;
}

/**
 * Get the current user synchronously from the cached session (may be null).
 */
export async function getCurrentUser(): Promise<User | null> {
  const session = await getSession();
  return session?.user ?? null;
}

/**
 * Listen for auth state changes.
 */
export function onAuthStateChange(listener: AuthListener): (() => void) | null {
  const supabase = getSupabase();
  if (!supabase) return null;
  const { data } = supabase.auth.onAuthStateChange(listener);
  return () => data.subscription.unsubscribe();
}

// ---------- bootstrap from server (Flutter keyring) ----------

/**
 * Try to bootstrap auth from the server's /api/bootstrap endpoint.
 * This uses the encryption key + refresh token from the Flutter app's keyring.
 * Returns true if successful.
 */
export async function bootstrapFromServer(): Promise<boolean> {
  try {
    const resp = await fetch('/api/bootstrap');
    const data = await resp.json();
    if (!data.available) return false;

    const supabase = getSupabase();
    if (!supabase) return false;

    // Use the refresh token to get a new session
    const { data: sessionData, error } = await supabase.auth.refreshSession({
      refresh_token: data.refreshToken,
    });
    if (error || !sessionData.session) {
      console.error('Bootstrap: failed to refresh session:', error?.message);
      return false;
    }

    // Import the encryption key directly (it's already the derived key, base64-encoded)
    const key = await importKey(data.encryptionKey);
    cachedKey = key;
    sessionStorage.setItem(SESSION_KEY_STORAGE, data.encryptionKey);

    console.log('Bootstrap: successfully authenticated as', sessionData.session.user.email);
    return true;
  } catch (e) {
    console.error('Bootstrap: failed', e);
    return false;
  }
}

// ---------- encryption key management ----------

/**
 * Derive and cache the encryption key from the user's password.
 * The salt is fetched from user metadata.
 */
async function initEncryptionKey(user: User, password: string): Promise<void> {
  const saltBase64 = user.user_metadata?.[METADATA_SALT_KEY] as string | undefined;
  if (!saltBase64) {
    // User has no salt yet (legacy or first login) - generate one
    const salt = generateSalt();
    const saltB64 = btoa(String.fromCharCode(...salt));

    const supabase = getSupabase();
    if (supabase) {
      await supabase.auth.updateUser({
        data: {
          [METADATA_SALT_KEY]: saltB64,
          chukdoo_key_version: '1',
        },
      });
    }

    const key = await deriveKey(password, salt);
    cachedKey = key;
    sessionStorage.setItem(SESSION_KEY_STORAGE, await exportKey(key));
    return;
  }

  // Decode the stored salt
  const binary = atob(saltBase64);
  const salt = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    salt[i] = binary.charCodeAt(i);
  }

  const key = await deriveKey(password, salt);
  cachedKey = key;
  sessionStorage.setItem(SESSION_KEY_STORAGE, await exportKey(key));
}

/**
 * Try to restore the encryption key from sessionStorage.
 * Returns true if successful.
 */
export async function tryRestoreKey(): Promise<boolean> {
  const stored = sessionStorage.getItem(SESSION_KEY_STORAGE);
  if (!stored) return false;
  try {
    cachedKey = await importKey(stored);
    return true;
  } catch {
    sessionStorage.removeItem(SESSION_KEY_STORAGE);
    return false;
  }
}

/**
 * Get the current encryption key (may be null).
 */
export function getEncryptionKey(): CryptoKey | null {
  return cachedKey;
}

/**
 * Whether we have an encryption key available.
 */
export function hasEncryptionKey(): boolean {
  return cachedKey !== null;
}
