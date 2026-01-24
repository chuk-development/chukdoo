# Backup-Codes für E2EE Recovery

## Problem

User verliert Passwort → Alle Daten verloren (weil E2EE mit Passwort-Key)

## Lösung

Bei Account-Erstellung: 8 Backup-Codes generieren. Jeder Code kann den Master-Key entschlüsseln.

---

## Architektur

```
                         ┌─────────────────┐
                         │   Master Key    │
                         │  (random 256b)  │
                         └────────┬────────┘
                                  │
                                  │ verschlüsselt alle Daten
                                  │
      ┌───────────────────────────┼───────────────────────────┐
      │                           │                           │
      ▼                           ▼                           ▼
┌───────────┐             ┌───────────┐             ┌───────────┐
│ Wrapped   │             │ Wrapped   │             │ Wrapped   │
│ mit       │             │ mit       │             │ mit       │
│ Passwort  │             │ Code 1    │             │ Code 2    │   ... (8 Codes)
└───────────┘             └───────────┘             └───────────┘
      │                           │                           │
      └───────────────────────────┴───────────────────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │    Supabase     │
                         │   user_keys     │
                         └─────────────────┘
```

Der **Master-Key** ist der eigentliche Verschlüsselungs-Key. Er wird zufällig generiert (einmalig) und dann mehrfach "wrapped":
- Einmal mit dem Passwort
- Einmal mit jedem Backup-Code

---

## Datenbank

```sql
CREATE TABLE user_keys (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users,
  key_type TEXT,           -- 'password' | 'backup_1' | 'backup_2' | ...
  wrapped_key TEXT,        -- Master-Key verschlüsselt mit diesem Key
  code_hash TEXT,          -- SHA-256 Hash des Backup-Codes (nur für backup_*)
  used_at TIMESTAMP,       -- NULL = noch nicht benutzt
  created_at TIMESTAMP
);
```

---

## Flows

### 1. Account erstellen

```dart
Future<List<String>> setupEncryption(String password) async {
  // 1. Master-Key generieren (einmalig, random)
  final masterKey = generateSecureRandom(32); // 256 bit

  // 2. Salt generieren
  final salt = generateSecureRandom(16);

  // 3. Mit Passwort wrappen
  final passwordKey = pbkdf2(password, salt, iterations: 600000);
  final wrappedWithPassword = aesGcmEncrypt(masterKey, passwordKey);

  await supabase.from('user_keys').insert({
    'user_id': userId,
    'key_type': 'password',
    'wrapped_key': base64Encode(wrappedWithPassword),
  });

  // 4. Backup-Codes generieren
  final backupCodes = <String>[];

  for (var i = 0; i < 8; i++) {
    // Format: XXXX-XXXX-XXXX (12 Zeichen)
    final code = generateBackupCode(); // z.B. "A7K2-M9P4-X3B8"
    backupCodes.add(code);

    // Code → Key → Wrap Master-Key
    final codeKey = pbkdf2(code, salt, iterations: 100000);
    final wrappedWithCode = aesGcmEncrypt(masterKey, codeKey);
    final codeHash = sha256(code); // Zum späteren Verifizieren

    await supabase.from('user_keys').insert({
      'user_id': userId,
      'key_type': 'backup_$i',
      'wrapped_key': base64Encode(wrappedWithCode),
      'code_hash': codeHash,
    });
  }

  // 5. Codes dem User zeigen (NUR EINMAL!)
  return backupCodes;
}

String generateBackupCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Keine 0/O/1/I
  final random = Random.secure();
  final code = List.generate(12, (_) => chars[random.nextInt(chars.length)]);
  return '${code.sublist(0, 4).join()}-${code.sublist(4, 8).join()}-${code.sublist(8, 12).join()}';
}
```

### 2. Passwort vergessen - Recovery

```dart
Future<bool> recoverWithBackupCode(String code, String newPassword) async {
  // 1. Code-Hash berechnen
  final codeHash = sha256(code);

  // 2. In DB suchen
  final result = await supabase
    .from('user_keys')
    .select()
    .eq('user_id', userId)
    .eq('code_hash', codeHash)
    .isFilter('used_at', null) // Noch nicht benutzt
    .maybeSingle();

  if (result == null) {
    return false; // Ungültiger oder bereits benutzter Code
  }

  // 3. Master-Key mit Backup-Code entschlüsseln
  final salt = await getSalt(userId);
  final codeKey = pbkdf2(code, salt, iterations: 100000);
  final wrappedKey = base64Decode(result['wrapped_key']);
  final masterKey = aesGcmDecrypt(wrappedKey, codeKey);

  // 4. Master-Key mit neuem Passwort wrappen
  final newPasswordKey = pbkdf2(newPassword, salt, iterations: 600000);
  final newWrappedKey = aesGcmEncrypt(masterKey, newPasswordKey);

  // 5. Password-Key aktualisieren
  await supabase
    .from('user_keys')
    .update({'wrapped_key': base64Encode(newWrappedKey)})
    .eq('user_id', userId)
    .eq('key_type', 'password');

  // 6. Backup-Code als benutzt markieren
  await supabase
    .from('user_keys')
    .update({'used_at': DateTime.now().toIso8601String()})
    .eq('id', result['id']);

  return true;
}
```

### 3. Neue Backup-Codes generieren (Settings)

```dart
Future<List<String>> regenerateBackupCodes(String currentPassword) async {
  // 1. Master-Key mit aktuellem Passwort entschlüsseln
  final masterKey = await decryptMasterKey(currentPassword);

  // 2. Alte Backup-Codes löschen
  await supabase
    .from('user_keys')
    .delete()
    .eq('user_id', userId)
    .like('key_type', 'backup_%');

  // 3. Neue Codes generieren
  final salt = await getSalt(userId);
  final newCodes = <String>[];

  for (var i = 0; i < 8; i++) {
    final code = generateBackupCode();
    newCodes.add(code);

    final codeKey = pbkdf2(code, salt, iterations: 100000);
    final wrappedKey = aesGcmEncrypt(masterKey, codeKey);
    final codeHash = sha256(code);

    await supabase.from('user_keys').insert({
      'user_id': userId,
      'key_type': 'backup_$i',
      'wrapped_key': base64Encode(wrappedKey),
      'code_hash': codeHash,
    });
  }

  return newCodes;
}
```

---

## UI

### Backup-Codes anzeigen (bei Erstellung)

```
╔═══════════════════════════════════════════════╗
║         CHUKDOO BACKUP-CODES                  ║
║                                               ║
║  Bewahre diese Codes sicher auf!              ║
║  Jeder Code kann nur EINMAL verwendet werden. ║
║                                               ║
║  ┌───────────────────────────────────────┐    ║
║  │  1. A7K2-M9P4-X3B8                   │    ║
║  │  2. B3N5-Q8R2-Y6C1                   │    ║
║  │  3. D9F4-K7L3-Z2M8                   │    ║
║  │  4. G1H6-P5S9-W4T7                   │    ║
║  │  5. J8V2-N3X6-E9A4                   │    ║
║  │  6. L5Y7-R1U8-I2O3                   │    ║
║  │  7. M4C9-T6B1-H7K5                   │    ║
║  │  8. P2W8-F3J6-S9D4                   │    ║
║  └───────────────────────────────────────┘    ║
║                                               ║
║  [In Zwischenablage] [Als PDF speichern]      ║
║                                               ║
║                              [Ich habe sie]   ║
╚═══════════════════════════════════════════════╝
```

### Settings - Sicherheit

```
┌─────────────────────────────────────────┐
│ Einstellungen                           │
├─────────────────────────────────────────┤
│                                         │
│ 🔐 SICHERHEIT                           │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 🔑 Backup-Codes                     │ │
│ │                                     │ │
│ │ 5 von 8 Codes verfügbar             │ │
│ │                                     │ │
│ │ [Neue generieren]                   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 🔒 Passwort ändern              ›   │ │
│ └─────────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### Recovery-Flow

```
┌─────────────────────────────────────────┐
│ Passwort zurücksetzen                   │
├─────────────────────────────────────────┤
│                                         │
│ Gib einen deiner Backup-Codes ein:      │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │  [____]-[____]-[____]               │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Neues Passwort:                         │
│ ┌─────────────────────────────────────┐ │
│ │  ••••••••••••                       │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Passwort bestätigen:                    │
│ ┌─────────────────────────────────────┐ │
│ │  ••••••••••••                       │ │
│ └─────────────────────────────────────┘ │
│                                         │
│              [Abbrechen] [Zurücksetzen] │
└─────────────────────────────────────────┘
```

---

## Sicherheits-Hinweise

- **Codes nie speichern**: Nur die SHA-256 Hashes werden in der DB gespeichert
- **Einmal-Verwendung**: Jeder Code funktioniert nur einmal
- **Rate-Limiting**: Max 5 fehlgeschlagene Versuche, dann 15 Min Sperre
- **Keine 0/O/1/I**: Verhindert Verwechslungen beim Abtippen
- **Alle Codes weg = Daten weg**: Wenn 8 Codes benutzt und Passwort vergessen → kein Recovery

---

## Migration (bestehende User)

Für User die schon existieren (ohne Master-Key):

```dart
Future<void> migrateToMasterKey(String currentPassword) async {
  // 1. Aktuellen Key (aus Passwort) als Master-Key verwenden
  final salt = await getSalt(userId);
  final masterKey = pbkdf2(currentPassword, salt, iterations: 600000);

  // 2. Neuen zufälligen Master-Key generieren
  final newMasterKey = generateSecureRandom(32);

  // 3. Alle Daten re-encrypten (im Hintergrund)
  await reencryptAllData(masterKey, newMasterKey);

  // 4. Neuen Master-Key mit Passwort wrappen
  final wrappedKey = aesGcmEncrypt(newMasterKey, masterKey);

  await supabase.from('user_keys').insert({
    'user_id': userId,
    'key_type': 'password',
    'wrapped_key': base64Encode(wrappedKey),
  });

  // 5. Backup-Codes generieren
  final codes = await generateBackupCodes(newMasterKey);
  showBackupCodesDialog(codes);
}
```
