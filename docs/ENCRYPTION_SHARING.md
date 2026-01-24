# Projekt-Sharing mit E2EE

## Übersicht

Projekte können mit anderen Usern geteilt werden, ohne die Ende-zu-Ende-Verschlüsselung zu brechen.

---

## Architektur

```
┌─────────────────────────────────────────────────────────┐
│                    PROJEKT "Arbeit"                     │
│                                                         │
│   Projekt-Key: random 256-bit                           │
│   (verschlüsselt alle Todos im Projekt)                 │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   User A (Owner)              User B (Member)           │
│   ┌─────────────┐             ┌─────────────┐           │
│   │ Public Key  │             │ Public Key  │           │
│   │ (in Supa)   │             │ (in Supa)   │           │
│   └──────┬──────┘             └──────┬──────┘           │
│          │                           │                  │
│          ▼                           ▼                  │
│   ┌─────────────┐             ┌─────────────┐           │
│   │ Wrapped     │             │ Wrapped     │           │
│   │ Projekt-Key │             │ Projekt-Key │           │
│   │ (für A)     │             │ (für B)     │           │
│   └─────────────┘             └─────────────┘           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

Jeder User hat ein asymmetrisches Keypair (X25519):
- **Public Key**: In Supabase gespeichert (öffentlich)
- **Private Key**: Lokal verschlüsselt mit User-Passwort

Der Projekt-Key wird für jeden Member individuell mit dessen Public Key verschlüsselt ("wrapped").

---

## Datenbank

```sql
-- User bekommen ein Keypair
ALTER TABLE auth.users ADD COLUMN public_key TEXT;

-- Projekt-Mitgliedschaften
CREATE TABLE project_members (
  id UUID PRIMARY KEY,
  project_id UUID REFERENCES projects,
  user_id UUID REFERENCES auth.users,
  wrapped_key TEXT,        -- Projekt-Key verschlüsselt mit User's Public Key
  role TEXT,               -- 'owner' | 'editor' | 'viewer'
  invited_by UUID,
  invited_at TIMESTAMP,
  accepted_at TIMESTAMP    -- NULL = noch nicht akzeptiert
);

-- Einladungen (für nicht-registrierte User)
CREATE TABLE project_invitations (
  id UUID PRIMARY KEY,
  project_id UUID REFERENCES projects,
  email TEXT,
  role TEXT,
  token TEXT UNIQUE,       -- Einladungs-Link Token
  expires_at TIMESTAMP,
  created_at TIMESTAMP
);
```

---

## Flows

### 1. Keypair erstellen (bei Account-Erstellung)

```dart
// X25519 Keypair generieren
final keyPair = generateX25519KeyPair();

// Public Key → Supabase (öffentlich)
await supabase.auth.updateUser({
  'data': {'public_key': base64Encode(keyPair.publicKey)}
});

// Private Key → Mit User-Key verschlüsseln → Lokal speichern
final encryptedPrivateKey = aesGcmEncrypt(keyPair.privateKey, userKey);
await secureStorage.write('private_key', encryptedPrivateKey);
```

### 2. Projekt teilen

```dart
Future<void> shareProject(String projectId, String memberEmail, String role) async {
  // 1. Projekt-Key holen (als Owner habe ich ihn)
  final projectKey = await getProjectKey(projectId);

  // 2. Member's Public Key aus Supabase holen
  final member = await supabase
    .from('profiles')
    .select('id, public_key')
    .eq('email', memberEmail)
    .single();

  if (member == null) {
    // User existiert nicht → Email-Einladung
    await sendEmailInvitation(projectId, memberEmail, role);
    return;
  }

  // 3. Projekt-Key mit Member's Public Key verschlüsseln
  final memberPublicKey = base64Decode(member['public_key']);
  final wrappedKey = x25519Encrypt(projectKey, memberPublicKey);

  // 4. In project_members speichern
  await supabase.from('project_members').insert({
    'project_id': projectId,
    'user_id': member['id'],
    'wrapped_key': base64Encode(wrappedKey),
    'role': role,
    'invited_by': currentUserId,
  });
}
```

### 3. Einladung annehmen

```dart
Future<void> acceptInvitation(String projectId) async {
  // 1. Wrapped Key aus project_members holen
  final membership = await supabase
    .from('project_members')
    .select('wrapped_key')
    .eq('project_id', projectId)
    .eq('user_id', currentUserId)
    .single();

  // 2. Mit eigenem Private Key entschlüsseln
  final wrappedKey = base64Decode(membership['wrapped_key']);
  final privateKey = await getPrivateKey();
  final projectKey = x25519Decrypt(wrappedKey, privateKey);

  // 3. Projekt-Key lokal cachen
  await cacheProjectKey(projectId, projectKey);

  // 4. Accepted markieren
  await supabase
    .from('project_members')
    .update({'accepted_at': DateTime.now().toIso8601String()})
    .eq('project_id', projectId)
    .eq('user_id', currentUserId);
}
```

### 4. Geteilte Todos lesen/schreiben

```dart
// Lesen
Future<Todo> getTodo(String todoId) async {
  final row = await supabase.from('todos').select().eq('id', todoId).single();

  if (row['project_id'] != null) {
    // Geteiltes Todo → Projekt-Key verwenden
    final projectKey = await getProjectKey(row['project_id']);
    return Todo(
      title: aesGcmDecrypt(row['encrypted_title'], projectKey),
    );
  } else {
    // Persönliches Todo → User-Key verwenden (wie bisher)
    return decryptWithUserKey(row);
  }
}

// Schreiben
Future<void> saveTodo(Todo todo) async {
  final key = todo.projectId != null
    ? await getProjectKey(todo.projectId!)
    : await getUserKey();

  await supabase.from('todos').upsert({
    'id': todo.id,
    'project_id': todo.projectId,
    'encrypted_title': aesGcmEncrypt(todo.title, key),
  });
}
```

---

## UI Mockups

### Projekt teilen

```
┌─────────────────────────────────────────┐
│ Projekt "Arbeit" teilen                 │
├─────────────────────────────────────────┤
│                                         │
│ Email: [________________________]       │
│                                         │
│ Rolle:                                  │
│ ○ Kann bearbeiten (Editor)              │
│ ○ Kann nur lesen (Viewer)               │
│                                         │
│              [Abbrechen] [Einladen]     │
└─────────────────────────────────────────┘
```

### Mitglieder verwalten

```
┌─────────────────────────────────────────┐
│ Projekt "Arbeit" - Mitglieder           │
├─────────────────────────────────────────┤
│                                         │
│ 👤 Du (Owner)                           │
│    max@example.com                      │
│                                         │
│ 👤 Anna Schmidt (Editor)            [×] │
│    anna@example.com                     │
│                                         │
│ 👤 Tom Müller (Viewer)              [×] │
│    tom@example.com                      │
│                                         │
│ ⏳ lisa@example.com (eingeladen)    [×] │
│                                         │
│ [+ Person einladen]                     │
│                                         │
└─────────────────────────────────────────┘
```

---

## Sicherheits-Hinweise

- **Key Rotation**: Wenn ein Member entfernt wird, sollte der Projekt-Key idealerweise rotiert werden (neuer Key, neu wrappen für alle verbleibenden Member)
- **Private Key Backup**: Der Private Key ist mit dem User-Passwort verschlüsselt. Passwort vergessen = kein Zugriff auf geteilte Projekte
- **Realtime**: Für Live-Updates → Supabase Realtime Subscriptions auf `project_members` und `todos`

---

## Crypto-Library

```yaml
dependencies:
  cryptography: ^2.5.0  # X25519, AES-GCM
```
