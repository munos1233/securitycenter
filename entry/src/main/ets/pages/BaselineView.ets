import { Theme } from '../common/Theme';
import { BaselineItem, Catalog } from '../model/Catalog';

@Component
export struct BaselineView {
  private items: BaselineItem[] = Catalog.baseline();

  build() {
    Scroll() {
      Column() {
        Text('这里是核查位，不是已经发布的条款号。W4 随加固清单终冻之后，才把真正的条款号填进来。裁剪任何依赖项之前，要同时换场景或走变更。')
          .width('100%')
          .fontSize(14)
          .fontColor(Theme.muted)
          .lineHeight(20)
          .margin({ bottom: 12 })
        ForEach(this.items, (item: BaselineItem) => {
          Column() {
            Text(item.slot + '  ·  ' + item.state)
              .width('100%')
              .fontSize(13)
              .fontColor(Theme.gold)
            Text(item.title)
              .width('100%')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.text)
              .margin({ top: 4 })
            Text(item.scenarioId)
              .width('100%')
              .fontSize(13)
              .fontColor(Theme.muted)
              .margin({ top: 4 })
            Text(item.note)
              .width('100%')
              .fontSize(14)
              .fontColor(Theme.text)
              .lineHeight(20)
              .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .borderRadius(14)
          .backgroundColor(Theme.card)
          .margin({ bottom: 10 })
        }, (item: BaselineItem) => item.slot)
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
  }
}
