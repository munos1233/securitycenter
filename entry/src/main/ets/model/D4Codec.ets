import { hilog } from '@kit.PerformanceAnalysisKit';
import { BoardCard, BoardPair, BuildInfo, D4Event, ParseResult, defaultBoards, isHexTail, nowIso, validateEvent } from './D4Types';

class BundlePeek {
  schema: string = '';
  schemaVersion: string = '';
  events: D4Event[] = [];
}

class BoardPeek {
  role: string = '';
  title: string = '';
  deviceId: string = '';
  imageVersion: string = '';
  hashTail: string = '';
  appVersion: string = '';
}

class PairPeek {
  schema: string = '';
  schemaVersion: string = '';
  vanilla: BoardPeek = new BoardPeek();
  secure: BoardPeek = new BoardPeek();
}

function jsonEscape(value: string): string {
  let out = '';
  for (let i = 0; i < value.length; i++) {
    let code = value.charCodeAt(i);
    if (code === 34) {
      out += '\\"';
    } else if (code === 92) {
      out += '\\\\';
    } else if (code === 10) {
      out += '\\n';
    } else if (code === 13) {
      out += '\\r';
    } else if (code === 9) {
      out += '\\t';
    } else if (code < 32) {
      let hex = code.toString(16);
      if (hex.length < 2) {
        hex = '0' + hex;
      }
      out += '\\u00' + hex;
    } else {
      out += value.charAt(i);
    }
  }
  return out;
}

function quote(value: string): string {
  return '"' + jsonEscape(value) + '"';
}

function textOf(value: string): string {
  if (typeof value === 'string') {
    return value;
  }
  return '';
}

function copyEvent(raw: D4Event): D4Event {
  let event = new D4Event();
  event.schema = textOf(raw.schema);
  event.schemaVersion = textOf(raw.schemaVersion);
  event.eventId = textOf(raw.eventId);
  if (typeof raw.seq === 'number') {
    event.seq = raw.seq;
  }
  event.deviceId = textOf(raw.deviceId);
  event.imageRole = textOf(raw.imageRole);
  event.imageVersion = textOf(raw.imageVersion);
  event.imageHashTail = textOf(raw.imageHashTail).toUpperCase();
  event.appId = textOf(raw.appId);
  event.appVersion = textOf(raw.appVersion);
  event.scenarioId = textOf(raw.scenarioId);
  event.outcome = textOf(raw.outcome);
  event.phrase = textOf(raw.phrase);
  event.occurredAt = textOf(raw.occurredAt);
  event.ruleId = textOf(raw.ruleId);
  event.baselineClause = textOf(raw.baselineClause);
  event.threatId = textOf(raw.threatId);
  event.threatStatus = textOf(raw.threatStatus);
  event.registeredAt = textOf(raw.registeredAt);
  event.evidenceNo = textOf(raw.evidenceNo);
  event.source = textOf(raw.source);
  event.detail = textOf(raw.detail);
  return event;
}

function formatEvent(event: D4Event, pad: string): string {
  let inner = pad + '  ';
  let lines = pad + '{\n';
  lines += inner + '"schema": ' + quote(event.schema) + ',\n';
  lines += inner + '"schemaVersion": ' + quote(event.schemaVersion) + ',\n';
  lines += inner + '"eventId": ' + quote(event.eventId) + ',\n';
  lines += inner + '"seq": ' + event.seq.toString() + ',\n';
  lines += inner + '"deviceId": ' + quote(event.deviceId) + ',\n';
  lines += inner + '"imageRole": ' + quote(event.imageRole) + ',\n';
  lines += inner + '"imageVersion": ' + quote(event.imageVersion) + ',\n';
  lines += inner + '"imageHashTail": ' + quote(event.imageHashTail) + ',\n';
  lines += inner + '"appId": ' + quote(event.appId) + ',\n';
  lines += inner + '"appVersion": ' + quote(event.appVersion) + ',\n';
  lines += inner + '"scenarioId": ' + quote(event.scenarioId) + ',\n';
  lines += inner + '"outcome": ' + quote(event.outcome) + ',\n';
  lines += inner + '"phrase": ' + quote(event.phrase) + ',\n';
  lines += inner + '"occurredAt": ' + quote(event.occurredAt) + ',\n';
  lines += inner + '"ruleId": ' + quote(event.ruleId) + ',\n';
  lines += inner + '"baselineClause": ' + quote(event.baselineClause) + ',\n';
  lines += inner + '"threatId": ' + quote(event.threatId) + ',\n';
  lines += inner + '"threatStatus": ' + quote(event.threatStatus) + ',\n';
  lines += inner + '"registeredAt": ' + quote(event.registeredAt) + ',\n';
  lines += inner + '"evidenceNo": ' + quote(event.evidenceNo) + ',\n';
  lines += inner + '"source": ' + quote(event.source) + ',\n';
  lines += inner + '"detail": ' + quote(event.detail) + '\n';
  lines += pad + '}';
  return lines;
}

export function formatBundle(events: D4Event[]): string {
  let lines = '{\n';
  lines += '  "schema": ' + quote(BuildInfo.schemaBundle) + ',\n';
  lines += '  "schemaVersion": ' + quote(BuildInfo.schemaVersion) + ',\n';
  lines += '  "exportedAt": ' + quote(nowIso()) + ',\n';
  lines += '  "note": ' + quote(BuildInfo.bundleNote) + ',\n';
  lines += '  "events": [\n';
  for (let i = 0; i < events.length; i++) {
    lines += formatEvent(events[i], '    ');
    if (i + 1 < events.length) {
      lines += ',\n';
    } else {
      lines += '\n';
    }
  }
  lines += '  ]\n}\n';
  return lines;
}

function readEvents(items: D4Event[]): ParseResult {
  let result = new ParseResult();
  if (items.length > 200) {
    result.message = '一次最多交换 200 条记录';
    return result;
  }
  let seen: string[] = [];
  let messages: string[] = [];
  for (let i = 0; i < items.length; i++) {
    let event = copyEvent(items[i] as D4Event);
    let problem = validateEvent(event);
    let where = '第 ' + (i + 1).toString() + ' 条';
    if (problem !== '') {
      result.skipped++;
      messages.push(where + '已跳过：' + problem);
      continue;
    }
    let duplicated = false;
    for (let j = 0; j < seen.length; j++) {
      if (seen[j] === event.eventId) {
        duplicated = true;
      }
    }
    if (duplicated) {
      result.skipped++;
      messages.push(where + '已跳过：事件编号重复');
      continue;
    }
    seen.push(event.eventId);
    result.events.push(event);
  }
  result.ok = result.events.length > 0 || items.length === 0;
  if (items.length === 0) {
    result.message = '文件里没有记录';
    result.ok = true;
    return result;
  }
  if (result.events.length === 0) {
    result.ok = false;
    result.message = messages.length > 0 ? messages[0] : '没有可导入的记录';
    return result;
  }
  result.message = '可读 ' + result.events.length.toString() + ' 条';
  if (messages.length > 0) {
    result.message = result.message + '，' + messages[0];
  }
  return result;
}

export function parseBundle(raw: string): ParseResult {
  let result = new ParseResult();
  if (raw.length === 0) {
    result.message = '文件是空的';
    return result;
  }
  if (raw.length > 1000000) {
    result.message = '文件超过 1MB';
    return result;
  }
  let trimmed = raw.trim();
  if (trimmed.charAt(0) === '\uFEFF') {
    trimmed = trimmed.substring(1).trim();
  }
  try {
    if (trimmed.charAt(0) === '[') {
      let items = JSON.parse(trimmed) as D4Event[];
      if (!(items instanceof Array)) {
        result.message = '不是记录数组';
        return result;
      }
      return readEvents(items);
    }
    let bundle = JSON.parse(trimmed) as BundlePeek;
    if (bundle.schema !== BuildInfo.schemaBundle || bundle.schemaVersion !== BuildInfo.schemaVersion) {
      result.message = '不是本阶段的 D4 交换文件';
      return result;
    }
    if (!(bundle.events instanceof Array)) {
      result.message = '交换文件缺少 events 数组';
      return result;
    }
    return readEvents(bundle.events);
  } catch (err) {
    hilog.error(0x4A59, 'D4Codec', 'parse %{public}s', JSON.stringify(err));
    result.message = '不是合法的 JSON';
    return result;
  }
}

function formatCard(card: BoardCard, pad: string): string {
  let inner = pad + '  ';
  return pad + '{\n' +
    inner + '"role": ' + quote(card.role) + ',\n' +
    inner + '"title": ' + quote(card.title) + ',\n' +
    inner + '"deviceId": ' + quote(card.deviceId) + ',\n' +
    inner + '"imageVersion": ' + quote(card.imageVersion) + ',\n' +
    inner + '"hashTail": ' + quote(card.hashTail) + ',\n' +
    inner + '"appVersion": ' + quote(card.appVersion) + '\n' +
    pad + '}';
}

export function formatBoards(pair: BoardPair): string {
  return '{\n' +
    '  "schema": "jinyinhu.board.pair",\n' +
    '  "schemaVersion": "0.1",\n' +
    '  "vanilla": ' + formatCard(pair.vanilla, '  ') + ',\n' +
    '  "secure": ' + formatCard(pair.secure, '  ') + '\n' +
    '}\n';
}

function copyCard(raw: BoardPeek, expectedRole: string): BoardCard | undefined {
  let card = new BoardCard();
  card.role = textOf(raw.role);
  card.title = textOf(raw.title);
  card.deviceId = textOf(raw.deviceId);
  card.imageVersion = textOf(raw.imageVersion);
  card.hashTail = textOf(raw.hashTail).toUpperCase();
  card.appVersion = textOf(raw.appVersion);
  if (card.role !== expectedRole) {
    return undefined;
  }
  if (card.title.length < 1 || card.title.length > 20) {
    return undefined;
  }
  if (card.deviceId.length < 1 || card.deviceId.length > 64) {
    return undefined;
  }
  if (card.imageVersion.length < 1 || card.imageVersion.length > 32) {
    return undefined;
  }
  if (!isHexTail(card.hashTail)) {
    return undefined;
  }
  if (card.appVersion.length < 1 || card.appVersion.length > 32) {
    return undefined;
  }
  return card;
}

export function parseBoards(raw: string): BoardPair | undefined {
  try {
    let parsed = JSON.parse(raw) as PairPeek;
    if (parsed.schema !== 'jinyinhu.board.pair' || parsed.schemaVersion !== '0.1') {
      return undefined;
    }
    let vanilla = copyCard(parsed.vanilla, 'vanilla-demo');
    let secure = copyCard(parsed.secure, 'secure');
    if (vanilla === undefined || secure === undefined) {
      return undefined;
    }
    let pair = defaultBoards();
    pair.vanilla = vanilla;
    pair.secure = secure;
    return pair;
  } catch (err) {
    hilog.error(0x4A59, 'D4Codec', 'boards %{public}s', JSON.stringify(err));
    return undefined;
  }
}
