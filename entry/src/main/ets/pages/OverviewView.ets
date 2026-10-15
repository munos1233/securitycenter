import { Theme } from '../common/Theme';
import { GoldButton } from '../components/UiParts';
import { ScoreRing } from '../components/UiParts';
import { Catalog, ReadinessRow } from '../model/Catalog';
import { D4Event, countSource, filterEvents, readinessDone, roleLabel } from '../model/D4Types';
import { LiveStore } from '../model/LiveStore';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Component
export struct OverviewView {
  @StorageLink('liveEvents') liveEvents: D4Event[] = [];
  @StorageLink('pairLayout') pairLayout: string = 'solo';
  onOpenTab: (index: number) => void = (index: number) => {
    hilog.info(0x4A59, 'overview', '%{public}d', index);
  };

  build() {
    Scroll() {
      Column() {
        Row() {
          ScoreRing({ done: readinessDone(this.liveEvents), total: 6 })
          Column() {
            Text('对照闭环')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text)
            Text('现场记录写入之后，正片改播这一侧的真实结果。前五项是这个应用已经做成的能力，第六项等现场观察。这不是系统安全评分。')
              .fontSize(13)
              .fontColor(Theme.muted)
              .margin({ top: 6 })
              .lineHeight(18)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 16 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding(16)
        .borderRadius(16)
        .backgroundColor(Theme.card)
        .margin({ bottom: 12 })

        this.blockTitle('正片画面')
        Row() {
          Button('只看安全版')
            .type(ButtonType.Normal)
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .borderRadius(12)
            .fontColor(this.pairLayout === 'solo' ? Theme.ink : Theme.text)
            .backgroundColor(this.pairLayout === 'solo' ? Theme.gold : Theme.cardAlt)
            .margin({ right: 8 })
            .onClick(() => {
              LiveStore.saveLayout('solo');
            })
          Button('并排')
            .type(ButtonType.Normal)
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .borderRadius(12)
            .fontColor(this.pairLayout === 'pair' ? Theme.ink : Theme.text)
            .backgroundColor(this.pairLayout === 'pair' ? Theme.gold : Theme.cardAlt)
            .onClick(() => {
              LiveStore.saveLayout('pair');
            })
        }
        .width('100%')
        .margin({ bottom: 12 })

        GridRow({ columns: { sm: 2, md: 4, lg: 4 }, breakpoints: { value: ['320vp', '600vp', '840vp'] } }) {
          GridCol({ span: { sm: 1, md: 1, lg: 1 } }) {
            this.stat(this.liveEvents.length.toString(), '全部记录')
          }
          GridCol({ span: { sm: 1, md: 1, lg: 1 } }) {
            this.stat(countSource(this.liveEvents, 'onsite').toString(), '现场')
          }
          GridCol({ span: { sm: 1, md: 1, lg: 1 } }) {
            this.stat(countSource(this.liveEvents, 'rehearsal').toString(), '版式样例')
          }
          GridCol({ span: { sm: 1, md: 1, lg: 1 } }) {
            this.stat('1', '残余条目')
          }
        }
        .width('100%')
        .margin({ bottom: 12 })

        this.blockTitle('现场记录里的镜像尾号')
        this.hashLine('vanilla-demo')
        this.hashLine('secure')

        this.blockTitle('六项准备')
        ForEach(Catalog.readiness(countSource(this.liveEvents, 'onsite')), (item: ReadinessRow) => {
          Row() {
            Text(item.done ? '已具备' : '未完成')
              .fontSize(12)
              .fontColor(item.done ? '#06281A' : Theme.ink)
              .backgroundColor(item.done ? Theme.ok : Theme.gold)
              .borderRadius(10)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            Column() {
              Text(item.title)
                .fontSize(16)
                .fontColor(Theme.text)
              Text(item.note)
                .fontSize(13)
                .fontColor(Theme.muted)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 10 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding(12)
          .borderRadius(12)
          .backgroundColor(Theme.card)
          .margin({ bottom: 8 })
        }, (item: ReadinessRow) => item.title)

        GoldButton({
          label: '打开现场记录',
          onTap: () => {
            this.onOpenTab(1);
          }
        })
        .margin({ top: 8 })
        Text('配套镜像标识按计划锁定为 7.0.0.40。真实哈希尾号以现场烧录为准，不在这里编造。')
          .width('100%')
          .fontSize(13)
          .fontColor(Theme.muted)
          .margin({ top: 12 })
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
  }

  @Builder
  stat(value: string, label: string) {
    Column() {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.gold)
      Text(label)
        .fontSize(12)
        .fontColor(Theme.muted)
        .margin({ top: 2 })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor(Theme.card)
    .margin({ bottom: 8 })
  }

  @Builder
  hashLine(role: string) {
    Text(roleLabel(role) + '  ·  ' + this.latestHash(role))
      .width('100%')
      .fontSize(16)
      .fontColor(Theme.text)
      .padding(14)
      .borderRadius(12)
      .backgroundColor(Theme.card)
      .margin({ bottom: 8 })
  }

  @Builder
  blockTitle(title: string) {
    Text(title)
      .width('100%')
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(Theme.gold)
      .margin({ top: 8, bottom: 8 })
  }

  private latestHash(role: string): string {
    let list = filterEvents(this.liveEvents, role, '');
    if (list.length === 0) {
      return '还没有记录';
    }
    if (list[0].imageHashTail.length === 0) {
      return '最新一条没有尾号';
    }
    return list[0].imageHashTail;
  }
}
