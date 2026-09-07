import index from "./index.html";
import { readHiveBox } from "./hive-reader";

const SUPABASE_URL = process.env.SUPABASE_URL ?? '';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY ?? '';

// Try to read encryption key + session from Flutter's secure storage via libsecret
let bootstrapData: { encryptionKey: string; refreshToken: string; userId: string } | null = null;

async function loadBootstrapFromKeyring() {
  try {
    const proc = Bun.spawn(['python3', '-c', `
import secretstorage, json, sys
bus = secretstorage.dbus_init()
collection = secretstorage.get_default_collection(bus)
result = {}
for item in collection.get_all_items():
    label = item.get_label()
    if label == 'io.chukdoo.app/FlutterSecureStorage':
        data = json.loads(item.get_secret().decode())
        for k, v in data.items():
            if k.startswith('encryption_key_'):
                result['encryptionKey'] = v
                result['userId'] = k.replace('encryption_key_', '')
# Get refresh token from shared_preferences
import os
sp_path = os.path.expanduser('~/.local/share/io.chukdoo.app/shared_preferences.json')
if os.path.exists(sp_path):
    with open(sp_path) as f:
        sp = json.load(f)
    for k, v in sp.items():
        if 'auth-token' in k:
            token_data = json.loads(v)
            result['refreshToken'] = token_data.get('refresh_token', '')
print(json.dumps(result))
`]);
    const output = await new Response(proc.stdout).text();
    const data = JSON.parse(output.trim());
    if (data.encryptionKey && data.refreshToken) {
      bootstrapData = data;
      console.log(`Bootstrap: found encryption key for user ${data.userId}`);
    }
  } catch (e) {
    console.log('Bootstrap: could not read from keyring (optional)');
  }
}

await loadBootstrapFromKeyring();

Bun.serve({
  port: 41923,
  routes: {
    "/": index,
    "/api/config": () => Response.json({
      supabaseUrl: SUPABASE_URL,
      supabaseAnonKey: SUPABASE_ANON_KEY,
    }),
    "/api/hive-data": async () => {
      try {
        const homedir = process.env.HOME ?? '/home/user';
        const todosPath = `${homedir}/doc/todos.hive`;
        const projectsPath = `${homedir}/doc/projects.hive`;
        const calendarsPath = `${homedir}/doc/calendars.hive`;
        const calendarEventsPath = `${homedir}/doc/calendar_events.hive`;

        const [todosMap, projectsMap, calendarsMap, calendarEventsMap] = await Promise.all([
          readHiveBox(todosPath),
          readHiveBox(projectsPath),
          readHiveBox(calendarsPath).catch(() => new Map()),
          readHiveBox(calendarEventsPath).catch(() => new Map()),
        ]);

        const todos = Array.from(todosMap.values());
        const projects = Array.from(projectsMap.values());
        const calendars = Array.from(calendarsMap.values());
        const calendar_events = Array.from(calendarEventsMap.values());

        return Response.json({ todos, projects, calendars, calendar_events });
      } catch (e: any) {
        return Response.json({ error: e.message, todos: [], projects: [], calendars: [], calendar_events: [] });
      }
    },
    "/api/bootstrap": () => {
      if (!bootstrapData) {
        return Response.json({ available: false });
      }
      return Response.json({
        available: true,
        encryptionKey: bootstrapData.encryptionKey,
        refreshToken: bootstrapData.refreshToken,
        userId: bootstrapData.userId,
      });
    },
    // SPA fallback - serve index.html for all non-file routes
    "/*": index,
  },
  development: {
    hmr: true,
    console: true,
  },
});

console.log("Chukdoo web running at http://localhost:41923");
if (SUPABASE_URL) {
  console.log(`Supabase: ${SUPABASE_URL}`);
} else {
  console.log("Supabase: not configured (local-only mode)");
}
