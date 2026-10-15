import { Theme } from '../common/Theme';
import { InfoLine, ThreatBlock } from '../components/UiParts';
import { Catalog, GlossaryRow, SbomRow, ThreatRow } from '../model/Catalog';

@Component
export struct ArchiveView {
  @State showSheet: boolean = false;
  @State threat: ThreatRow = Catalog.residual();
  private threats: ThreatRow[] = Catalog.threats();
  private components: SbomRow[] = Catalog.sbom('金银湖安全中心');
  private words: GlossaryRow[] = Catalog.glossary();

  build() {
    Scroll() {
      Column() {
        Text('边界声明')
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.gold)
          .margin({ bottom: 8 })
        Text(Catalog.boundary)
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.text)
          .lineHeight(24)
          .padding(14)
          .borderRadius(14)
          .backgroundColor(Theme.card)
          .border({ width: 1, color: Theme.gold })
          .margin({ bottom: 16 })

        Text('威胁台账')
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.gold)
          .margin({ bottom: 8 })
        Text('待处理项还没有登记成已缓解。残余项带登记时点和依据编号，登记日是计划修订日。')
          .width('100%')
          .fontSize(13)
          .fontColor(Theme.muted)
          .margin({ bottom: 8 })
        ForEach(this.threats, (item: ThreatRow) => {
          Column() {
            Text(item.threatId + '  ·  ' + item.title)
              .width('100%')
              .fontSize(16)
              .fontColor(Theme.text)
            Text(item.status === 'residual' ? '残余 · 点开查看' : '待处理 · 点开查看')
              .width('100%')
              .fontSize(13)
              .fontColor(Theme.gold)
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .borderRadius(14)
          .backgroundColor(Theme.card)
          .margin({ bottom: 8 })
          .onClick(() => {
            this.threat = item;
            this.showSheet = true;
          })
        }, (item: ThreatRow) => item.threatId)

        Text('SBOM')
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.gold)
          .margin({ top: 8, bottom: 8 })
        ForEach(this.components, (item: SbomRow) => {
          Column() {
            Text(item.name)
              .width('100%')
              .fontSize(16)
              .fontColor(Theme.text)
            InfoLine({ label: '版本', value: item.version })
            InfoLine({ label: '许可证', value: item.license })
            InfoLine({ label: '范围', value: item.scope })
            Text(item.note)
              .width('100%')
              .fontSize(13)
              .fontColor(Theme.muted)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .borderRadius(14)
          .backgroundColor(Theme.card)
          .margin({ bottom: 8 })
        }, (item: SbomRow) => item.name)

        Text('解说备答')
          .width('100%')
          .fontSize(16)
          .fontColor(Theme.gold)
          .margin({ top: 8, bottom: 8 })
        ForEach(this.words, (item: GlossaryRow) => {
          Column() {
            Text(item.term)
              .width('100%')
              .fontSize(16)
              .fontColor(Theme.gold)
            Text(item.meaning)
              .width('100%')
              .fontSize(14)
              .fontColor(Theme.text)
              .lineHeight(20)
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .borderRadius(14)
          .backgroundColor(Theme.card)
          .margin({ bottom: 8 })
        }, (item: GlossaryRow) => item.term)
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .bindSheet(this.showSheet, this.sheetBuilder(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: true,
      backgroundColor: Theme.card,
      onDisappear: () => {
        this.showSheet = false;
      }
    })
  }

  @Builder
  sheetBuilder() {
    Scroll() {
      Column() {
        ThreatBlock({ row: this.threat })
      }
      .width('100%')
      .padding(20)
    }
    .backgroundColor(Theme.card)
  }
}
