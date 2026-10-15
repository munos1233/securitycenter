import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LiveStore } from '../model/LiveStore';
import { acceptProbeRun, acceptSidecar, copySidecar } from './ProbeCodec';
import { SandboxIsolationProbe } from './SandboxIsolationProbe';
import {
  Probe,
  ProbeId,
  ProbeResult,
  ProbeSource,
  SidecarReport,
  copyProbeRun
} from './ProbeTypes';

const DOMAIN = 0x4A59;
const TAG = 'ProbeRegistry';

/**
 * 探针注册表。没有对应类文件时 all() 不放占位探针，也不写 hit / blocked。
 * 探针模块以后调用 install；EntryAbility 调用 registerAll 后才会出现在 all() 里。
 */
export class Registry {
  private static slotP1: ProbeSource | undefined = undefined;
  private static slotP2: ProbeSource | undefined = undefined;
  private static slotP3: ProbeSource | undefined = undefined;
  private static probes: Probe[] = [];
  private static armed: boolean = false;

  static install(id: ProbeId, source: ProbeSource): void {
    if (!source) {
      return;
    }
    if (id === 'P1') {
      Registry.slotP1 = source;
    } else if (id === 'P2') {
      Registry.slotP2 = source;
    } else if (id === 'P3') {
      Registry.slotP3 = source;
    }
    if (Registry.armed) {
      Registry.materialize();
    }
  }

  static registerAll(): void {
    Registry.install('P2', new SandboxSource());
    Registry.armed = true;
    Registry.materialize();
  }

  static all(): Probe[] {
    let copy: Probe[] = [];
    for (let i = 0; i < Registry.probes.length; i++) {
      copy.push(Registry.probes[i]);
    }
    return copy;
  }

  static async runOne(probe: Probe, ctx: common.UIAbilityContext): Promise<ProbeResult> {
    let raw = await probe.run(ctx);
    let accepted = acceptProbeRun(probe.id, raw);
    if (!accepted.ok) {
      throw new Error(accepted.reason);
    }
    LiveStore.appendProbeRun(accepted.run);
    return copyProbeRun(accepted.run);
  }

  static async runAll(ctx: common.UIAbilityContext,
    onEach: (result: ProbeResult) => void,
    onStart: (id: ProbeId) => void): Promise<ProbeResult[]> {
    let probes = Registry.all();
    let done: ProbeResult[] = [];
    for (let i = 0; i < probes.length; i++) {
      let probe = probes[i];
      onStart(probe.id);
      let result: ProbeResult;
      try {
        result = await Registry.runOne(probe, ctx);
      } catch (err) {
        let reason = errorText(err);
        hilog.error(DOMAIN, TAG, 'run %{public}s failed: %{public}s', probe.id, reason);
        try {
          LiveStore.noteRunFault(probe.id, reason);
        } catch (writeErr) {
          hilog.error(DOMAIN, TAG, 'fault %{public}s not stored: %{public}s', probe.id, errorText(writeErr));
        }
        continue;
      }
      done.push(result);
      try {
        onEach(result);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'callback %{public}s failed: %{public}s', probe.id, errorText(err));
        throw err;
      }
    }
    return done;
  }

  static ingestSidecar(text: string): SidecarReport | undefined {
    let accepted = acceptSidecar(text, LiveStore.boardUdid());
    if (!accepted.ok) {
      try {
        LiveStore.noteImportFailure(accepted.reason);
      } catch (err) {
        LiveStore.setStatus('探针记录写入失败');
        hilog.error(DOMAIN, TAG, 'import note %{public}s', errorText(err));
      }
      return undefined;
    }
    try {
      LiveStore.keepSidecar(accepted.report);
    } catch (err) {
      LiveStore.setStatus('探针记录写入失败');
      hilog.error(DOMAIN, TAG, 'import %{public}s', errorText(err));
      return undefined;
    }
    return copySidecar(accepted.report);
  }

  private static materialize(): void {
    let next: Probe[] = [];
    Registry.take('P1', Registry.slotP1, next);
    Registry.take('P2', Registry.slotP2, next);
    Registry.take('P3', Registry.slotP3, next);
    Registry.probes = next;
  }

  private static take(id: ProbeId, source: ProbeSource | undefined, into: Probe[]): void {
    if (source === undefined) {
      return;
    }
    try {
      let probe = source.create();
      if (!probe || probe.id !== id) {
        hilog.error(DOMAIN, TAG, 'skip %{public}s', id);
        return;
      }
      into.push(probe);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'create %{public}s failed: %{public}s', id, errorText(err));
    }
  }
}

function errorText(err: Object): string {
  let text = '';
  if (err instanceof Error) {
    text = err.message;
  } else {
    text = JSON.stringify(err);
  }
  if (typeof text !== 'string' || text.length === 0) {
    return '探针没有落盘';
  }
  if (text.length > 200) {
    return text.substring(0, 200);
  }
  return text;
}

class SandboxSource implements ProbeSource {
  create(): Probe {
    return new SandboxIsolationProbe();
  }
}
