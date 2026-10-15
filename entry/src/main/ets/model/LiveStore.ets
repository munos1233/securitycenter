import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { formatBoards, formatBundle, parseBoards, parseBundle } from './D4Codec';
import {
  BoardPair,
  D4Event,
  copyEvents,
  defaultBoards,
  hasEventId,
  nowIso,
  removeEvent
} from './D4Types';
import {
  acceptProbeRun,
  acceptSidecarReport,
  applyAppendRun,
  applyImportFailure,
  applyKeepSidecar,
  applyRunFault,
  formatProbeShelf,
  parseProbeShelf
} from '../probe/ProbeCodec';
import {
  ProbeId,
  ProbeLimits,
  ProbeRun,
  ProbeShelf,
  SidecarReport,
  copyShelf,
  emptyProbeShelf
} from '../probe/ProbeTypes';

const DOMAIN = 0x4A59;
const TAG = 'LiveStore';
const PREF_NAME = 'jinyinhu';

export class LiveStore {
  private static ctx: common.UIAbilityContext | undefined = undefined;
  private static pref: preferences.Preferences | undefined = undefined;
  private static shelfBlocked: boolean = false;

  static bind(ctx: common.UIAbilityContext): void {
    LiveStore.ctx = ctx;
  }

  static prepare(): void {
    if (!AppStorage.has('liveEvents')) {
      let emptyEvents: D4Event[] = [];
      AppStorage.setOrCreate('liveEvents', emptyEvents);
    }
    if (!AppStorage.has('boardPair')) {
      AppStorage.setOrCreate('boardPair', defaultBoards());
    }
    if (!AppStorage.has('statusLine')) {
      AppStorage.setOrCreate('statusLine', '');
    }
    if (!AppStorage.has('pairLayout')) {
      AppStorage.setOrCreate('pairLayout', 'solo');
    }
    if (!AppStorage.has('probeShelf')) {
      AppStorage.setOrCreate('probeShelf', emptyProbeShelf());
    }
  }

  static async restore(): Promise<void> {
    if (LiveStore.ctx === undefined) {
      return;
    }
    try {
      LiveStore.pref = await preferences.getPreferences(LiveStore.ctx, PREF_NAME);
      let eventRaw = await LiveStore.pref.get('events', '');
      if (typeof eventRaw === 'string' && eventRaw.length > 0) {
        let parsed = parseBundle(eventRaw);
        if (parsed.ok) {
          AppStorage.setOrCreate('liveEvents', parsed.events);
        } else {
          LiveStore.setStatus(parsed.message);
        }
      }
      let boardRaw = await LiveStore.pref.get('boards', '');
      if (typeof boardRaw === 'string' && boardRaw.length > 0) {
        let boards = parseBoards(boardRaw);
        if (boards !== undefined) {
          AppStorage.setOrCreate('boardPair', boards);
        } else {
          LiveStore.setStatus('亮相信息已损坏，已恢复默认标识');
        }
      }
      let layoutRaw = await LiveStore.pref.get('pairLayout', 'solo');
      if (layoutRaw === 'pair') {
        AppStorage.setOrCreate('pairLayout', 'pair');
      } else {
        AppStorage.setOrCreate('pairLayout', 'solo');
      }
      await LiveStore.restoreShelf();
    } catch (err) {
      LiveStore.setStatus('本地记录读取失败，已从空白现场开始');
      hilog.error(DOMAIN, TAG, 'restore %{public}s', JSON.stringify(err));
    }
  }

  static events(): D4Event[] {
    let current = AppStorage.get<D4Event[]>('liveEvents');
    if (current === undefined) {
      return [];
    }
    return current;
  }

  static boards(): BoardPair {
    let current = AppStorage.get<BoardPair>('boardPair');
    if (current === undefined) {
      return defaultBoards();
    }
    return current;
  }

  static setStatus(message: string): void {
    AppStorage.setOrCreate('statusLine', message);
  }

  static async replaceEvents(events: D4Event[]): Promise<void> {
    AppStorage.setOrCreate('liveEvents', events);
    await LiveStore.persistEvents(events);
  }

  static async clearEvents(): Promise<void> {
    let empty: D4Event[] = [];
    await LiveStore.replaceEvents(empty);
    LiveStore.setStatus('现场记录和版式样例已清空');
  }

  static async deleteEvent(eventId: string): Promise<void> {
    let next = removeEvent(LiveStore.events(), eventId);
    await LiveStore.replaceEvents(next);
    LiveStore.setStatus('已删除一条记录');
  }

  static async importText(text: string, replace: boolean): Promise<string> {
    let parsed = parseBundle(text);
    if (!parsed.ok) {
      LiveStore.setStatus(parsed.message);
      return parsed.message;
    }
    if (replace) {
      await LiveStore.replaceEvents(parsed.events);
      let loaded = '已载入 ' + parsed.events.length.toString() + ' 条版式样例，演示前请清空';
      LiveStore.setStatus(loaded);
      return loaded;
    }
    if (parsed.events.length === 0) {
      LiveStore.setStatus(parsed.message);
      return parsed.message;
    }
    let merged = copyEvents(LiveStore.events());
    let added = 0;
    let skipped = parsed.skipped;
    for (let i = 0; i < parsed.events.length; i++) {
      if (hasEventId(merged, parsed.events[i].eventId) || merged.length >= 200) {
        skipped++;
        continue;
      }
      merged.push(parsed.events[i]);
      added++;
    }
    await LiveStore.replaceEvents(merged);
    let message = '导入 ' + added.toString() + ' 条';
    if (skipped > 0) {
      message = message + '，跳过 ' + skipped.toString() + ' 条';
    }
    LiveStore.setStatus(message);
    return message;
  }

  static async saveBoards(pair: BoardPair): Promise<void> {
    AppStorage.setOrCreate('boardPair', pair);
    if (LiveStore.pref === undefined) {
      LiveStore.setStatus('亮相信息只保存在本次运行');
      return;
    }
    try {
      await LiveStore.pref.put('boards', formatBoards(pair));
      await LiveStore.pref.flush();
      LiveStore.setStatus('亮相信息已保存');
    } catch (err) {
      LiveStore.setStatus('亮相信息保存失败');
      hilog.error(DOMAIN, TAG, 'boards %{public}s', JSON.stringify(err));
    }
  }

  static async saveLayout(mode: string): Promise<void> {
    let next = 'solo';
    if (mode === 'pair') {
      next = 'pair';
    }
    AppStorage.setOrCreate('pairLayout', next);
    if (LiveStore.pref === undefined) {
      return;
    }
    try {
      await LiveStore.pref.put('pairLayout', next);
      await LiveStore.pref.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'layout %{public}s', JSON.stringify(err));
    }
  }

  static shelf(): ProbeShelf {
    let current = AppStorage.get<ProbeShelf>('probeShelf');
    if (current === undefined) {
      let created = emptyProbeShelf();
      AppStorage.setOrCreate('probeShelf', created);
      return created;
    }
    return current;
  }

  static boardUdid(): string {
    return LiveStore.shelf().boardUdid;
  }

  static setBoardUdid(value: string): void {
    let trimmed = '';
    if (typeof value === 'string') {
      trimmed = value.trim();
    }
    if (trimmed.length > ProbeLimits.udidMax || trimmed.indexOf('\n') >= 0 || trimmed.indexOf('\r') >= 0) {
      LiveStore.setStatus('UDID 无法登记');
      return;
    }
    let next = copyShelf(LiveStore.shelf());
    next.boardUdid = trimmed;
    try {
      LiveStore.commitShelf(next);
    } catch (err) {
      LiveStore.setStatus('探针记录写入失败');
      hilog.error(DOMAIN, TAG, 'udid %{public}s', JSON.stringify(err));
      return;
    }
    if (trimmed.length === 0) {
      LiveStore.setStatus('UDID 登记已清空');
    } else {
      LiveStore.setStatus('UDID 已登记');
    }
  }

  static appendProbeRun(run: ProbeRun): void {
    let accepted = acceptProbeRun(run.probeId, run);
    if (!accepted.ok) {
      throw new Error(accepted.reason);
    }
    LiveStore.commitShelf(applyAppendRun(LiveStore.shelf(), accepted.run));
  }

  static keepSidecar(report: SidecarReport): void {
    let accepted = acceptSidecarReport(report, LiveStore.boardUdid());
    if (!accepted.ok) {
      throw new Error(accepted.reason);
    }
    LiveStore.commitShelf(applyKeepSidecar(LiveStore.shelf(), accepted.report, nowIso()));
    LiveStore.setStatus('侧车报告已导入');
  }

  static noteImportFailure(reason: string): void {
    let next = applyImportFailure(LiveStore.shelf(), reason, nowIso());
    LiveStore.commitShelf(next);
    LiveStore.setStatus(next.failureReason);
  }

  static noteRunFault(probeId: ProbeId, reason: string): void {
    let id = probeId;
    if (id !== 'P1' && id !== 'P2' && id !== 'P3') {
      throw new Error('探针编号不一致');
    }
    LiveStore.commitShelf(applyRunFault(LiveStore.shelf(), id, reason, nowIso()));
  }

  private static async restoreShelf(): Promise<void> {
    if (LiveStore.pref === undefined) {
      return;
    }
    try {
      let raw = await LiveStore.pref.get('probeShelf', '');
      if (typeof raw !== 'string' || raw.length === 0) {
        LiveStore.shelfBlocked = false;
        return;
      }
      let parsed = parseProbeShelf(raw);
      if (parsed === undefined) {
        LiveStore.shelfBlocked = true;
        LiveStore.setStatus('探针记录有损坏条目，未载入');
        hilog.error(DOMAIN, TAG, 'probe shelf kept on disk');
        return;
      }
      LiveStore.shelfBlocked = false;
      AppStorage.setOrCreate('probeShelf', parsed);
    } catch (err) {
      LiveStore.shelfBlocked = true;
      LiveStore.setStatus('探针记录有损坏条目，未载入');
      hilog.error(DOMAIN, TAG, 'probe shelf %{public}s', JSON.stringify(err));
    }
  }

  private static commitShelf(next: ProbeShelf): void {
    if (LiveStore.shelfBlocked) {
      throw new Error('探针记录有损坏条目，未写入');
    }
    if (LiveStore.pref === undefined) {
      throw new Error('探针记录尚未打开');
    }
    let text = formatProbeShelf(next);
    if (text.length === 0 || text.length > ProbeLimits.shelfTextMax) {
      throw new Error('探针记录过长，未写入');
    }
    let previous = '';
    let hadPrevious = false;
    try {
      let raw = LiveStore.pref.getSync('probeShelf', '');
      if (typeof raw === 'string') {
        previous = raw;
        hadPrevious = raw.length > 0;
      }
      LiveStore.pref.putSync('probeShelf', text);
      LiveStore.pref.flushSync();
    } catch (err) {
      LiveStore.restoreShelfText(hadPrevious, previous);
      hilog.error(DOMAIN, TAG, 'shelf %{public}s', JSON.stringify(err));
      throw new Error('探针记录写入失败');
    }
    AppStorage.setOrCreate('probeShelf', next);
  }

  private static restoreShelfText(hadPrevious: boolean, previous: string): void {
    if (LiveStore.pref === undefined) {
      return;
    }
    try {
      if (hadPrevious) {
        LiveStore.pref.putSync('probeShelf', previous);
      } else {
        LiveStore.pref.deleteSync('probeShelf');
      }
      LiveStore.pref.flushSync();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'shelf rollback %{public}s', JSON.stringify(err));
    }
  }

  private static async persistEvents(events: D4Event[]): Promise<void> {
    if (LiveStore.pref === undefined) {
      return;
    }
    try {
      await LiveStore.pref.put('events', formatBundle(events));
      await LiveStore.pref.flush();
    } catch (err) {
      LiveStore.setStatus('记录写入失败');
      hilog.error(DOMAIN, TAG, 'events %{public}s', JSON.stringify(err));
    }
  }
}
