import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../common/Theme';
import { StatusLine } from '../components/UiParts';
import { LiveStore, ScanProgress } from '../model/LiveStore';
import {
  HomeSummary,
  PROBE_IDS,
  ProbeTone,
  homeSummary,
  probeName,
  probeTone,
  shortStamp,
  toneLabel
} from '../model/ProbeStatus';
import { ScanTask } from '../model/ScanTask';
import { DoppelUninstall } from './DoppelUninstall';
import { ProbeShelf, emptyProbeShelf } from '../probe/ProbeTypes';
import { Finding, Findings } from '../report/Findings';

const DOMAIN = 0x4A59;
const TAG = 'HomeView';
const HERO_SIZE: number = 168;

@Component
export struct HomeView {
  @StorageLink('probeShelf') probeShelf: ProbeShelf = emptyProbeShelf();
  @StorageLink('findings') findings: Finding[] = [];
  @StorageLink('scanProgress') scanProgress: ScanProgress = new ScanProgress();
  @StorageLink('statusLine') statusLine: string = '';
  @State starting: boolean = false;
  onOpen: (route: string) => void = (route: string) => {
    hilog.info(DOMAIN, TAG, 'open %{public}s', route);
  };

  build() {
    Scroll() {
      Column() {
        Text('安全中心')
          .width('100%')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.text)
          .padding({ left: 24, right: 24, top: 24 })

        this.hero()

        DoppelUninstall()

        this.groupTitle('安全检测')
        Row() {
          ForEach(PROBE_IDS, (id: string) => {
            this.checkTile(id)
          }, (id: string) => id + probeTone(this.probeShelf, id))
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .borderRadius(16)
        .backgroundColor(Theme.card)

        this.groupTitle('安全管理')
        Column() {
          this.listRow($r('sys.symbol.doc_text_badge_clock_fill'), '#E84026', '风险记录', this.recordHint(), 'ledger', true)
          this.listRow($r('sys.symbol.doc_text_badge_checkmark_fill'), '#0A59F7', '安全报告', '检测概览与系统镜像', 'report', true)
          this.listRow($r('sys.symbol.folder_fill'), '#F7931E', '记录导入导出', '导出检测记录，或导入已有报告', 'archive', true)
          this.listRow($r('sys.symbol.phone_fill'), '#5E6E82', '设备信息', this.deviceHint(), 'device', true)
          this.listRow($r('sys.symbol.info_circle_fill'), '#22A45D', '安全说明', '检测范围、威胁与组件清单', 'about', false)
        }
        .width('100%')
        .borderRadius(16)
        .backgroundColor(Theme.card)

        StatusLine({ text: this.statusLine })
          .margin({ top: 8 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 32 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .backgroundColor(Theme.page)
  }

  @Builder
  hero() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(HERO_SIZE)
          .height(HERO_SIZE)
          .borderRadius(HERO_SIZE / 2)
          .backgroundColor(this.heroSoft())
        if (this.scanning()) {
          Progress({ value: this.progressValue(), total: 300, type: ProgressType.Ring })
            .width(HERO_SIZE)
            .height(HERO_SIZE)
            .style({ strokeWidth: 8 })
            .color(Theme.accent)
            .backgroundColor(Theme.line)
          LoadingProgress()
            .width(72)
            .height(72)
            .color(Theme.accent)
        } else if (this.summary().tone === 'risk' || this.summary().tone === 'note') {
          SymbolGlyph($r('sys.symbol.exclamationmark_shield_fill'))
            .fontSize(80)
            .fontColor([this.heroColor()])
        } else {
          SymbolGlyph($r('sys.symbol.checkmark_shield_fill'))
            .fontSize(80)
            .fontColor([this.heroColor()])
        }
      }
      .width(HERO_SIZE)
      .height(HERO_SIZE)

      Text(this.headline())
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.scanning() ? Theme.text : this.heroColor())
        .margin({ top: 20 })
      Text(this.subline())
        .fontSize(14)
        .fontColor(Theme.muted)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6 })

      Button(this.buttonLabel())
        .type(ButtonType.Capsule)
        .width(200)
        .height(40)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.onAccent)
        .backgroundColor(Theme.accent)
        .enabled(!this.scanning())
        .opacity(this.scanning() ? 0.4 : 1)
        .margin({ top: 24 })
        .onClick(() => {
          this.checkAll();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 24, bottom: 16 })
  }

  @Builder
  groupTitle(title: string) {
    Text(title)
      .width('100%')
      .fontSize(14)
      .fontColor(Theme.muted)
      .padding({ left: 12, top: 16, bottom: 8 })
  }

  @Builder
  checkTile(id: string) {
    Column() {
      Stack() {
        if (id === 'P1') {
          SymbolGlyph($r('sys.symbol.arrow_down_shield'))
            .fontSize(26)
            .fontColor([Theme.onAccent])
        } else if (id === 'P2') {
          SymbolGlyph($r('sys.symbol.lock_shield_fill'))
            .fontSize(26)
            .fontColor([Theme.onAccent])
        } else {
          SymbolGlyph($r('sys.symbol.hand_tap_fill'))
            .fontSize(26)
            .fontColor([Theme.onAccent])
        }
      }
      .width(48)
      .height(48)
      .borderRadius(14)
      .backgroundColor(tileColor(id))

      Text(probeName(id))
        .fontSize(14)
        .fontColor(Theme.text)
        .maxLines(1)
        .margin({ top: 10 })
      Text(this.tileText(id))
        .fontSize(12)
        .fontColor(this.tileTone(id))
        .maxLines(1)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onOpen(id);
    })
  }

  @Builder
  listRow(icon: Resource, color: string, title: string, hint: string, route: string, divided: boolean) {
    Column() {
      Row() {
        Stack() {
          SymbolGlyph(icon)
            .fontSize(20)
            .fontColor([Theme.onAccent])
        }
        .width(36)
        .height(36)
        .borderRadius(10)
        .backgroundColor(color)

        Column() {
          Text(title)
            .fontSize(16)
            .fontColor(Theme.text)
          Text(hint)
            .fontSize(12)
            .fontColor(Theme.muted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([Theme.line])
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      if (divided) {
        Divider()
          .color(Theme.line)
          .strokeWidth(0.5)
          .margin({ left: 64, right: 16 })
      }
    }
    .width('100%')
    .onClick(() => {
      this.onOpen(route);
    })
  }

  private summary(): HomeSummary {
    return homeSummary(this.probeShelf);
  }

  private scanning(): boolean {
    return this.starting || this.scanProgress.running;
  }

  private headline(): string {
    if (this.scanning()) {
      return '正在体检';
    }
    let summary = this.summary();
    if (summary.tone === 'risk') {
      return '发现 ' + summary.risks.toString() + ' 项风险';
    }
    if (summary.tone === 'note') {
      return '有 ' + summary.notes.toString() + ' 项需要留意';
    }
    if (summary.tone === 'safe') {
      return '未发现风险';
    }
    return '尚未体检';
  }

  private subline(): string {
    if (this.scanning()) {
      if (this.scanProgress.title.length === 0) {
        return '准备检测';
      }
      if (this.scanProgress.total > 0 && this.scanProgress.step > 0) {
        return this.scanProgress.title + '  ' + this.scanProgress.step.toString() + '/' + this.scanProgress.total.toString();
      }
      return this.scanProgress.title;
    }
    let at = shortStamp(this.summary().lastAt);
    if (at.length > 0) {
      return '上次体检 ' + at;
    }
    return '检查安装包、应用隔离和安全控件';
  }

  private buttonLabel(): string {
    if (this.scanning()) {
      return '体检中…';
    }
    return this.summary().tone === 'none' ? '立即体检' : '重新体检';
  }

  private heroColor(): string {
    return toneColor(this.summary().tone);
  }

  private heroSoft(): string {
    if (this.scanning()) {
      return Theme.accentSoft;
    }
    let tone = this.summary().tone;
    if (tone === 'risk') {
      return Theme.dangerSoft;
    }
    if (tone === 'note') {
      return Theme.warnSoft;
    }
    if (tone === 'safe') {
      return Theme.okSoft;
    }
    return Theme.accentSoft;
  }

  private progressValue(): number {
    let index = PROBE_IDS.indexOf(this.scanProgress.probeId);
    if (index < 0) {
      return 0;
    }
    let part = 50;
    if (this.scanProgress.total > 0 && this.scanProgress.step > 0) {
      part = Math.round(this.scanProgress.step * 100 / this.scanProgress.total);
    }
    return index * 100 + part;
  }

  private tileText(id: string): string {
    if (this.scanProgress.running && this.scanProgress.probeId === id) {
      return '检测中';
    }
    return toneLabel(probeTone(this.probeShelf, id));
  }

  private tileTone(id: string): string {
    if (this.scanProgress.running && this.scanProgress.probeId === id) {
      return Theme.accent;
    }
    let tone = probeTone(this.probeShelf, id);
    if (tone === 'none') {
      return Theme.muted;
    }
    return toneColor(tone);
  }

  private recordHint(): string {
    let count = this.findings.length >= 0 ? Findings.list().length : 0;
    if (count === 0) {
      return '暂无记录';
    }
    return count.toString() + ' 条检测记录';
  }

  private deviceHint(): string {
    return this.probeShelf.boardUdid.length > 0 ? '设备已登记' : '设备未登记';
  }

  private checkAll(): void {
    if (this.scanning() || ScanTask.running()) {
      return;
    }
    let ctx = this.host();
    if (ctx === undefined) {
      LiveStore.setStatus('无法开始体检');
      return;
    }
    this.starting = true;
    ScanTask.run(ctx, []).then(() => {
      this.starting = false;
    }).catch((err: Object) => {
      hilog.error(DOMAIN, TAG, 'check %{public}s', JSON.stringify(err));
      LiveStore.setStatus('体检中断');
      this.starting = false;
    });
  }

  private host(): common.UIAbilityContext | undefined {
    let value = this.getUIContext().getHostContext();
    if (value === undefined) {
      return undefined;
    }
    return value as common.UIAbilityContext;
  }
}

function toneColor(tone: ProbeTone): string {
  if (tone === 'risk') {
    return Theme.danger;
  }
  if (tone === 'note' || tone === 'fault') {
    return Theme.warn;
  }
  if (tone === 'safe') {
    return Theme.ok;
  }
  return Theme.accent;
}

function tileColor(id: string): string {
  if (id === 'P1') {
    return '#0A59F7';
  }
  if (id === 'P2') {
    return '#00A6A6';
  }
  return '#F7931E';
}
