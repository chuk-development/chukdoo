#!/usr/bin/env python3
# /// script
# dependencies = ["secretstorage", "cryptography"]
# ///
"""
Chukdoo password recovery - brute-force your own password.
Tries to unwrap the Master Key using each password candidate.

The Master Key is wrapped (AES-GCM encrypted) with a key derived from
your password via PBKDF2. If unwrapping succeeds AND the result matches
the cached Master Key, we found the password.

Usage:
  1. Create passwords.txt with one password per line
  2. Run: uv run recover_password.py passwords.txt
"""

import sys
import base64
import hashlib
import json
import time
import multiprocessing
from functools import partial
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# Constants matching Flutter app
KDF_ITERATIONS = 600_000
BACKUP_KDF_ITERATIONS = 100_000
KEY_LENGTH = 32  # 256 bits


def get_cached_master_key():
    """Read the cached master key from the Linux keyring."""
    import secretstorage

    bus = secretstorage.dbus_init()
    collection = secretstorage.get_default_collection(bus)

    for item in collection.get_all_items():
        if item.get_label() == 'io.chukdoo.app/FlutterSecureStorage':
            data = json.loads(item.get_secret().decode())
            for k, v in data.items():
                if k.startswith('encryption_key_'):
                    return base64.b64decode(v)
    raise RuntimeError("Could not find master key in keyring")


def get_salt():
    """Read the salt from the Linux keyring."""
    import secretstorage

    bus = secretstorage.dbus_init()
    collection = secretstorage.get_default_collection(bus)

    for item in collection.get_all_items():
        if item.get_label() == 'io.chukdoo.app/FlutterSecureStorage':
            data = json.loads(item.get_secret().decode())
            for k, v in data.items():
                if k.startswith('encryption_salt_'):
                    return base64.b64decode(v)
    raise RuntimeError("Could not find salt in keyring")


def get_wrapped_password_key():
    """Read the password-wrapped master key from Supabase shared prefs."""
    import os
    import subprocess

    # Read env - check os.environ first, then .env.local file
    env = dict(os.environ)
    # Try multiple locations for .env.local
    script_dir = os.path.dirname(os.path.abspath(__file__))
    cwd = os.getcwd()
    for d in [script_dir, cwd, os.path.expanduser('~/git/chukdoo')]:
        p = os.path.join(d, '.env.local')
        if os.path.exists(p):
            env_path = p
            break
    else:
        env_path = os.path.join(script_dir, '.env.local')
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line.startswith('export '):
                    line = line[7:]
                if '=' in line and not line.startswith('#'):
                    k, v = line.split('=', 1)
                    env[k] = v.strip('"').strip("'")

    # Try both app IDs
    for app_id in ['io.chukdoo.app', 'com.example.chukdoo']:
        p = os.path.expanduser(f'~/.local/share/{app_id}/shared_preferences.json')
        if os.path.exists(p):
            with open(p) as f:
                data = json.load(f)
            if data:
                sp_path = p
                break
    else:
        sp_path = os.path.expanduser('~/.local/share/io.chukdoo.app/shared_preferences.json')
    with open(sp_path) as f:
        sp = json.load(f)

    refresh_token = None
    for k, v in sp.items():
        if 'auth-token' in k:
            token_data = json.loads(v)
            refresh_token = token_data.get('refresh_token')
            break

    if not refresh_token or not env.get('SUPABASE_URL'):
        raise RuntimeError("Need SUPABASE_URL in .env.local and a valid session")

    import urllib.request

    # Refresh the session first
    refresh_req = urllib.request.Request(
        f"{env['SUPABASE_URL']}/auth/v1/token?grant_type=refresh_token",
        data=json.dumps({"refresh_token": refresh_token}).encode(),
        headers={
            'apikey': env['SUPABASE_ANON_KEY'],
            'Content-Type': 'application/json',
        },
    )
    with urllib.request.urlopen(refresh_req) as resp:
        session = json.loads(resp.read())
    token = session['access_token']

    url = f"{env['SUPABASE_URL']}/rest/v1/user_keys?key_type=eq.password&select=wrapped_key"
    req = urllib.request.Request(url, headers={
        'apikey': env['SUPABASE_ANON_KEY'],
        'Authorization': f'Bearer {token}',
    })
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())

    if not data:
        raise RuntimeError("No password-wrapped key found in Supabase")

    return json.loads(data[0]['wrapped_key'])


def try_unwrap(password: str, salt: bytes, wrapped: dict, known_master_key: bytes) -> bool:
    """Try to unwrap the master key with a password candidate."""
    # Derive key from password
    derived = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, KDF_ITERATIONS, dklen=KEY_LENGTH)

    # Try AES-GCM decrypt of the wrapped key
    nonce = base64.b64decode(wrapped['nonce'])
    ciphertext = base64.b64decode(wrapped['ciphertext'])
    mac = base64.b64decode(wrapped['mac'])

    try:
        aesgcm = AESGCM(derived)
        unwrapped = aesgcm.decrypt(nonce, ciphertext + mac, None)
        # Check if unwrapped matches the known master key
        return unwrapped == known_master_key
    except Exception:
        # Decrypt failed = wrong password
        return False


def check_batch(passwords: list, salt: bytes, wrapped: dict, known_master_key: bytes):
    for pw in passwords:
        if try_unwrap(pw, salt, wrapped, known_master_key):
            return pw
    return None


def main():
    if len(sys.argv) < 2:
        print("Usage: uv run recover_password.py passwords.txt")
        sys.exit(1)

    password_file = sys.argv[1]

    print("Loading crypto data...")
    master_key = get_cached_master_key()
    salt = get_salt()
    wrapped = get_wrapped_password_key()

    print(f"  Master Key: {base64.b64encode(master_key).decode()[:20]}...")
    print(f"  Salt: {base64.b64encode(salt).decode()}")
    print(f"  Wrapped key nonce: {wrapped['nonce'][:16]}...")
    print(f"  PBKDF2 iterations: {KDF_ITERATIONS:,}")
    print()

    with open(password_file, 'r') as f:
        passwords = [line.strip() for line in f if line.strip()]

    print(f"Loaded {len(passwords)} password candidates")

    # Benchmark
    print("Benchmarking...")
    t0 = time.time()
    try_unwrap("benchmark_xyz_123", salt, wrapped, master_key)
    per = time.time() - t0
    print(f"  {per:.2f}s per attempt, ~{per * len(passwords):.0f}s total")
    print()

    num_workers = max(1, multiprocessing.cpu_count() - 1)
    batch_size = max(1, len(passwords) // (num_workers * 4))
    batches = [passwords[i:i + batch_size] for i in range(0, len(passwords), batch_size)]

    print(f"Brute-forcing with {num_workers} workers...")
    start = time.time()
    found = None

    worker = partial(check_batch, salt=salt, wrapped=wrapped, known_master_key=master_key)

    with multiprocessing.Pool(num_workers) as pool:
        for i, result in enumerate(pool.imap_unordered(worker, batches)):
            checked = min((i + 1) * batch_size, len(passwords))
            elapsed = time.time() - start
            rate = checked / elapsed if elapsed > 0 else 0
            print(f"\r  {checked}/{len(passwords)} ({rate:.1f}/s)", end="", flush=True)
            if result:
                found = result
                pool.terminate()
                break

    print()
    print()

    if found:
        print(f"PASSWORD FOUND: {found}")
    else:
        print("No match. Add more candidates to passwords.txt")


if __name__ == '__main__':
    main()
