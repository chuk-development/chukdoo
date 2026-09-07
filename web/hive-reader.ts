/**
 * Reads Hive v2 box files (Flutter's local database format).
 * This allows the web app to access the same data as the Flutter app.
 */

interface HiveEntry {
  [key: string]: any;
}

export async function readHiveBox(path: string): Promise<Map<string, HiveEntry>> {
  const file = Bun.file(path);
  if (!(await file.exists())) return new Map();

  const buffer = await file.arrayBuffer();
  const data = new Uint8Array(buffer);
  const view = new DataView(buffer);
  const entries = new Map<string, HiveEntry>();

  let pos = 0;

  while (pos < data.length) {
    if (pos + 4 > data.length) break;

    const frameLenRaw = view.getUint32(pos, true);
    const deleted = (frameLenRaw >>> 31) & 1;
    const frameLen = frameLenRaw & 0x7FFFFFFF;

    if (frameLen === 0) break;

    // frameLen INCLUDES the 4-byte length field itself
    const frameEnd = pos + frameLen;
    if (frameEnd > data.length) break;

    if (!deleted) {
      try {
        const result = parseFrame(data, view, pos + 4, frameEnd);
        if (result) {
          entries.set(result.key, result.value);
        }
      } catch {}
    }

    pos = frameEnd;
  }

  return entries;
}

function parseFrame(data: Uint8Array, view: DataView, start: number, end: number): { key: string; value: HiveEntry } | null {
  let fp = start;
  const keyType = data[fp]!;
  fp++;

  if (keyType !== 0x01) return null; // only string keys

  const keyLen = data[fp]!;
  fp++;
  const key = new TextDecoder().decode(data.slice(fp, fp + keyLen));
  fp += keyLen;

  const value = readValue(data, view, fp, end);
  if (!value || typeof value.val !== 'object' || value.val === null) return null;

  return { key, value: value.val };
}

function readValue(data: Uint8Array, view: DataView, pos: number, end: number): { val: any; pos: number } | null {
  if (pos >= end) return null;

  const type = data[pos]!;
  pos++;

  switch (type) {
    case 0x00: // null
      return { val: null, pos };

    case 0x01: // int (stored as double)
      if (pos + 8 > end) return null;
      return { val: view.getFloat64(pos, true), pos: pos + 8 };

    case 0x02: // double
      if (pos + 8 > end) return null;
      return { val: view.getFloat64(pos, true), pos: pos + 8 };

    case 0x03: // bool
      if (pos >= end) return null;
      return { val: data[pos]! !== 0, pos: pos + 1 };

    case 0x04: { // string
      if (pos + 4 > end) return null;
      const len = view.getUint32(pos, true);
      pos += 4;
      if (pos + len > end) return null;
      const str = new TextDecoder().decode(data.slice(pos, pos + len));
      return { val: str, pos: pos + len };
    }

    case 0x05: { // byte list
      if (pos + 4 > end) return null;
      const len = view.getUint32(pos, true);
      pos += 4;
      return { val: Array.from(data.slice(pos, pos + len)), pos: pos + len };
    }

    case 0x09: { // string list
      if (pos + 4 > end) return null;
      const len = view.getUint32(pos, true);
      pos += 4;
      const arr: string[] = [];
      for (let i = 0; i < len; i++) {
        if (pos + 4 > end) break;
        const sLen = view.getUint32(pos, true);
        pos += 4;
        if (pos + sLen > end) break;
        arr.push(new TextDecoder().decode(data.slice(pos, pos + sLen)));
        pos += sLen;
      }
      return { val: arr, pos };
    }

    case 0x0A: { // list
      if (pos + 4 > end) return null;
      const len = view.getUint32(pos, true);
      pos += 4;
      const arr: any[] = [];
      for (let i = 0; i < len; i++) {
        const result = readValue(data, view, pos, end);
        if (!result) break;
        arr.push(result.val);
        pos = result.pos;
      }
      return { val: arr, pos };
    }

    case 0x0B: { // map
      if (pos + 4 > end) return null;
      const len = view.getUint32(pos, true);
      pos += 4;
      const obj: Record<string, any> = {};
      for (let i = 0; i < len; i++) {
        const kResult = readValue(data, view, pos, end);
        if (!kResult) break;
        pos = kResult.pos;
        const vResult = readValue(data, view, pos, end);
        if (!vResult) break;
        pos = vResult.pos;
        obj[String(kResult.val)] = vResult.val;
      }
      return { val: obj, pos };
    }

    default:
      return null;
  }
}
