import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../common/Theme';
import { GoldButton, ProbeBadge } from '../components/UiParts';
import { LiveStore } from '../model/LiveStore';
import { acceptProbeRun } from '../probe/ProbeCodec';
import { Registry } from '../probe/Registry';
import { ProbeEvidence, ProbeRun, ProbeRunFault, ProbeShelf, emptyProbeShelf, isStamp } from '../probe/ProbeTypes';

const DOMAIN = 0x4A59;
const TAG = 'ScanView';

@Component
export struct ScanView {
  @StorageLink('probeShelf') probeShelf: ProbeShelf = emptyProbeShelf();
  @State busy: boolean = false;
  @State activeId: string = '';
  @State tick: number = 0;

  aboutToAppear(): void {
    Registry.registerAll();
  }

  build() {
    Scroll() {
      Column() {
        Text('扫描')
          .width('100%')
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.text)
          .margin({ bottom: 12 })

        GoldButton({
          label: this.busy ? '正在扫描' : '一键自动扫描',
          canTap: !this.busy,
          onTap: () => {
            this.startScan();
          }
        })

        if (this.activeId.length > 0) {
          Text('正在扫描 ' + this.activeId)
            .width('100%')
            .fontSize(14)
            .fontColor(Theme.muted)
            .margin({ top: 8 })
        }

        ForEach(this.probeIds(), (id: string) => {
          this.probeCard(id)
        }, (id: string) => id + this.tick.toString())
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.page)
    .scrollBar(BarState.Off)
  }

  @Builder
  probeCard(id: string) {
    Column() {
      Row() {
        Text(this.probeTitle(id))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.text)
          .layoutWeight(1)
        if (!this.scanningThis(id)) {
          ProbeBadge({ run: this.badgeRun(id) })
        }
      }
      .width('100%')

      Text(this.phraseText(id))
        .width('100%')
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.phraseColor(id))
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 12 })

      if (id === 'P2' && this.showingRun(id)) {
        Text('五条尝试')
          .width('100%')
          .fontSize(13)
          .fontColor(Theme.gold)
          .margin({ top: 12, bottom: 6 })
        ForEach(this.runEvidences(id), (item: ProbeEvidence, index: number) => {
          Column() {
            Text(item.text)
              .width('100%')
              .fontSize(14)
              .fontColor(Theme.text)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(item.raw)
              .width('100%')
              .fontSize(12)
              .fontColor(Theme.muted)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
            Text(isStamp(item.at) ? item.at : '')
              .width('100%')
              .fontSize(12)
              .fontColor(Theme.muted)
              .maxLines(1)
              .margin({ top: 2 })
              .visibility(isStamp(item.at) ? Visibility.Visible : Visibility.None)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 6, bottom: 6 })
        }, (item: ProbeEvidence, index: number) => index.toString() + item.at)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .borderRadius(14)
    .backgroundColor(Theme.card)
    .borderWidth({ left: 6, top: 1, right: 1, bottom: 1 })
    .borderColor(this.cardColor(id))
    .margin({ top: 12 })
  }

  private startScan(): void {
    if (this.busy) {
      return;
    }
    let ctx = this.host();
    if (ctx === undefined) {
      LiveStore.setStatus('无法扫描');
      return;
    }
    Registry.registerAll();
    let probes = Registry.all();
    if (probes.length === 0) {
      LiveStore.setStatus('没有已登记的探针');
      return;
    }
    this.busy = true;
    this.activeId = '';
    Registry.runAll(ctx, (result) => {
      if (result.probeId.length > 0) {
        this.tick = this.tick + 1;
      }
    }, (id: string) => {
      this.activeId = id;
    }).then(() => {
      this.finishScan();
    }).catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'scan %{public}s', JSON.stringify(err));
      LiveStore.setStatus('扫描中断');
      this.finishScan();
    });
  }

  private finishScan(): void {
    this.busy = false;
    this.activeId = '';
    this.tick = this.tick + 1;
  }

  private host(): common.UIAbilityContext | undefined {
    let value = this.getUIContext().getHostContext();
    if (value === undefined) {
      return undefined;
    }
    return value as common.UIAbilityContext;
  }

  private probeIds(): string[] {
    let ids: string[] = [];
    ids.push('P1');
    ids.push('P2');
    ids.push('P3');
    return ids;
  }

  private probeTitle(id: string): string {
    let probes = Registry.all();
    for (let i = 0; i < probes.length; i++) {
      if (probes[i].id === id && probes[i].title.length > 0) {
        return probes[i].title;
      }
    }
    if (id === 'P1') {
      return '安装完整性';
    }
    if (id === 'P2') {
      return '沙箱隔离';
    }
    if (id === 'P3') {
      return '安全组件姿态';
    }
    return id;
  }

  private badgeRun(id: string): ProbeRun {
    if (this.scanningThis(id)) {
      return new ProbeRun();
    }
    let run = this.visibleRun(id);
    if (run === undefined) {
      return new ProbeRun();
    }
    return run;
  }

  private showingRun(id: string): boolean {
    return this.visibleRun(id) !== undefined && !this.scanningThis(id);
  }

  private phraseText(id: string): string {
    if (this.scanningThis(id)) {
      return '正在扫描';
    }
    let run = this.visibleRun(id);
    if (run !== undefined) {
      return run.phrase;
    }
    let fault = this.visibleFault(id);
    if (fault !== undefined) {
      return fault.reason;
    }
    return '尚未扫描';
  }

  private phraseColor(id: string): string {
    if (this.scanningThis(id)) {
      return Theme.muted;
    }
    let run = this.visibleRun(id);
    if (run === undefined) {
      if (this.visibleFault(id) !== undefined) {
        return Theme.warn;
      }
      return Theme.muted;
    }
    if (run.verdict === 'hit') {
      return Theme.danger;
    }
    if (run.verdict === 'blocked') {
      return Theme.ok;
    }
    return Theme.gold;
  }

  private cardColor(id: string): string {
    if (this.scanningThis(id)) {
      return Theme.line;
    }
    let run = this.visibleRun(id);
    if (run === undefined) {
      if (this.visibleFault(id) !== undefined) {
        return Theme.warn;
      }
      return Theme.line;
    }
    if (run.verdict === 'hit') {
      return Theme.danger;
    }
    if (run.verdict === 'blocked') {
      return Theme.ok;
    }
    return Theme.line;
  }

  private runEvidences(id: string): ProbeEvidence[] {
    let run = this.visibleRun(id);
    if (run === undefined) {
      let empty: ProbeEvidence[] = [];
      return empty;
    }
    return run.evidences;
  }

  private scanningThis(id: string): boolean {
    return this.busy && this.activeId === id;
  }

  private visibleRun(id: string): ProbeRun | undefined {
    let run = this.newestRun(id);
    if (run === undefined) {
      return undefined;
    }
    let fault = this.newestFault(id);
    if (fault !== undefined && fault.at >= run.createdAt) {
      return undefined;
    }
    return run;
  }

  private visibleFault(id: string): ProbeRunFault | undefined {
    let fault = this.newestFault(id);
    if (fault === undefined) {
      return undefined;
    }
    let run = this.newestRun(id);
    if (run !== undefined && run.createdAt > fault.at) {
      return undefined;
    }
    return fault;
  }

  private newestRun(id: string): ProbeRun | undefined {
    let runs = this.probeShelf.runs;
    for (let i = runs.length - 1; i >= 0; i--) {
      if (runs[i].probeId !== id) {
        continue;
      }
      if (acceptProbeRun(id, runs[i]).ok) {
        return runs[i];
      }
    }
    return undefined;
  }

  private newestFault(id: string): ProbeRunFault | undefined {
    let faults = this.probeShelf.runFaults;
    for (let i = 0; i < faults.length; i++) {
      if (faults[i].probeId === id && isStamp(faults[i].at) && faults[i].reason.length > 0) {
        return faults[i];
      }
    }
    return undefined;
  }
}
