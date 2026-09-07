/**
 * Client-side E2EE encryption service using Web Crypto API.
 * Compatible with the Flutter app's encryption (PBKDF2 600k + AES-256-GCM).
 *
 * Payload format (JSON string):
 *   { "v": "1", "nonce": "<base64>", "ciphertext": "<base64>", "mac": "<base64>" }
 *
 * Flutter's `cryptography` package produces a SecretBox where mac = GCM auth tag.
 * Web Crypto's AES-GCM appends the auth tag to the ciphertext, so we split/join
 * on encrypt/decrypt to match Flutter's separate fields.
 */

const PAYLOAD_VERSION = '1';
const KDF_ITERATIONS = 600_000;
const SALT_LENGTH = 16; // bytes
const NONCE_LENGTH = 12; // bytes, standard for AES-GCM
const KEY_LENGTH = 256; // bits
const TAG_LENGTH = 128; // bits (16 bytes), standard GCM tag

// ---------- helpers ----------

function toBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]!);
  }
  return btoa(binary);
}

function fromBase64(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// ---------- public API ----------

/**
 * Generate a cryptographically secure random salt.
 */
export function generateSalt(): Uint8Array {
  return crypto.getRandomValues(new Uint8Array(SALT_LENGTH));
}

/**
 * Derive an AES-256-GCM CryptoKey from a password and salt using PBKDF2.
 * Parameters match the Flutter app: HMAC-SHA256, 600 000 iterations, 256-bit key.
 */
export async function deriveKey(password: string, salt: Uint8Array): Promise<CryptoKey> {
  const encoder = new TextEncoder();
  const passwordBytes = encoder.encode(password);

  // Import password as raw key material for PBKDF2
  const baseKey = await crypto.subtle.importKey(
    'raw',
    passwordBytes,
    'PBKDF2',
    false,
    ['deriveKey'],
  );

  // Derive AES-GCM key
  return crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt: salt as BufferSource,
      iterations: KDF_ITERATIONS,
      hash: 'SHA-256',
    },
    baseKey,
    { name: 'AES-GCM', length: KEY_LENGTH },
    true, // extractable so we can export for sessionStorage
    ['encrypt', 'decrypt'],
  );
}

/**
 * Encrypt plaintext with the given AES-256-GCM key.
 * Returns a JSON string matching the Flutter payload format:
 *   { v, nonce, ciphertext, mac }
 */
export async function encrypt(plaintext: string, key: CryptoKey): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(plaintext);

  const nonce = crypto.getRandomValues(new Uint8Array(NONCE_LENGTH));

  // Web Crypto AES-GCM returns ciphertext + tag concatenated
  const encrypted = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: nonce, tagLength: TAG_LENGTH },
    key,
    data,
  );

  const encryptedBytes = new Uint8Array(encrypted);

  // Split into ciphertext and auth tag (last 16 bytes)
  const tagBytes = TAG_LENGTH / 8;
  const ciphertext = encryptedBytes.slice(0, encryptedBytes.length - tagBytes);
  const mac = encryptedBytes.slice(encryptedBytes.length - tagBytes);

  const payload = {
    v: PAYLOAD_VERSION,
    nonce: toBase64(nonce),
    ciphertext: toBase64(ciphertext),
    mac: toBase64(mac),
  };

  return JSON.stringify(payload);
}

/**
 * Decrypt a payload string produced by encrypt() (or the Flutter app).
 */
export async function decrypt(encryptedPayload: string, key: CryptoKey): Promise<string> {
  const payload = JSON.parse(encryptedPayload) as {
    v: string;
    nonce: string;
    ciphertext: string;
    mac: string;
  };

  if (payload.v !== PAYLOAD_VERSION) {
    throw new Error(`Unsupported ciphertext version: ${payload.v}`);
  }

  const nonce = fromBase64(payload.nonce);
  const ciphertext = fromBase64(payload.ciphertext);
  const mac = fromBase64(payload.mac);

  // Web Crypto expects ciphertext + tag concatenated
  const combined = new Uint8Array(ciphertext.length + mac.length);
  combined.set(ciphertext, 0);
  combined.set(mac, ciphertext.length);

  const decrypted = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: nonce as BufferSource, tagLength: TAG_LENGTH },
    key,
    combined as BufferSource,
  );

  const decoder = new TextDecoder();
  return decoder.decode(decrypted);
}

/**
 * Export a CryptoKey to raw bytes (for storing in sessionStorage).
 */
export async function exportKey(key: CryptoKey): Promise<string> {
  const raw = await crypto.subtle.exportKey('raw', key);
  return toBase64(new Uint8Array(raw));
}

/**
 * Import a CryptoKey from a base64-encoded raw key (from sessionStorage).
 */
export async function importKey(base64Key: string): Promise<CryptoKey> {
  const raw = fromBase64(base64Key);
  return crypto.subtle.importKey(
    'raw',
    raw as BufferSource,
    { name: 'AES-GCM', length: KEY_LENGTH },
    true,
    ['encrypt', 'decrypt'],
  );
}
