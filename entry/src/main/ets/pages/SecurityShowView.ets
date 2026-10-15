import { Theme } from '../common/Theme';
import { BoardPane, EventBlock, ThreatBlock } from '../components/UiParts';
import { Catalog } from '../model/Catalog';
import { BoardPair, D4Event, defaultBoards } from '../model/D4Types';
import { clockText, resolveShow } from '../model/ShowDeck';

@Component
export struct SecurityShowView {
  @StorageLink('liveEvents') liveEvents: D4Event[] = [];
  @StorageLink('boardPair') boards: BoardPair = defaultBoards();
  @StorageLink('pairLayout') pairLayout: string = 'solo';
  @Prop
  @Watch('onActiveChange')
  active: boolean = true;
  @State secureCard: D4Event = new D4Event();
  @State vanillaCard: D4Event = new D4Event();
  @State showSheet: boolean = false;
  @State sheetMode: string = 'event';
  @State sheetEvent: D4Event = new D4Event();
  onPrep: () => void = () => {};
  private appId: string = 'com.jinyinhu.securitycenter';

  aboutToAppear(): void {
    this.refresh();
  }

  onActiveChange(): void {
    if (this.active) {
      this.refresh();
    }
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('金银湖')
            .fontSize(13)
            .fontColor(Theme.gold)
          Text('安全版')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.text)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('准备')
          .fontSize(16)
          .fontColor(Theme.gold)
          .padding({ left: 12, right: 4, top: 8, bottom: 8 })
          .onClick(() => {
            this.onPrep();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 16, top: 12 })

      if (this.pairLayout === 'pair') {
        Row() {
          BoardPane({
            role: 'vanilla-demo',
            version: this.boards.vanilla.imageVersion,
            hashTail: this.boards.vanilla.hashTail,
            focused: true,
            face: 'both',
            phrase: this.vanillaCard.phrase,
            timeText: clockText(this.vanillaCard.occurredAt),
            outcome: this.vanillaCard.outcome,
            demoMark: this.vanillaCard.source === 'show',
            onOpen: () => {
              this.openEvent(this.vanillaCard);
            }
          })
            .layoutWeight(1)
          Column()
            .width(1)
            .height('100%')
            .backgroundColor(Theme.gold)
          BoardPane({
            role: 'secure',
            version: this.boards.secure.imageVersion,
            hashTail: this.boards.secure.hashTail,
            focused: true,
            face: 'both',
            phrase: this.secureCard.phrase,
            timeText: clockText(this.secureCard.occurredAt),
            outcome: this.secureCard.outcome,
            demoMark: this.secureCard.source === 'show',
            onOpen: () => {
              this.openEvent(this.secureCard);
            }
          })
            .layoutWeight(1)
        }
        .layoutWeight(1)
        .width('100%')
        .margin({ top: 12 })
      } else {
        BoardPane({
          role: 'secure',
          version: this.boards.secure.imageVersion,
          hashTail: this.boards.secure.hashTail,
          focused: true,
          face: 'both',
          phrase: this.secureCard.phrase,
          timeText: clockText(this.secureCard.occurredAt),
          outcome: this.secureCard.outcome,
          demoMark: this.secureCard.source === 'show',
          onOpen: () => {
            this.openEvent(this.secureCard);
          }
        })
          .layoutWeight(1)
          .width('100%')
          .margin({ top: 12 })
      }

      Row() {
        Text('残余')
          .fontSize(15)
          .fontColor(Theme.gold)
          .border({ width: 1, color: Theme.gold })
          .borderRadius(14)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .onClick(() => {
            this.sheetMode = 'threat';
            this.showSheet = true;
          })
        Blank()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10 })

      Text(Catalog.boundary)
        .width('100%')
        .fontSize(16)
        .fontColor(Theme.text)
        .lineHeight(24)
        .maxLines(4)
        .padding({ left: 20, right: 20, top: 10, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.page)
    .bindSheet(this.showSheet, this.sheetBody(), {
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
  sheetBody() {
    Scroll() {
      Column() {
        if (this.sheetMode === 'threat') {
          ThreatBlock({ row: Catalog.residual() })
        } else {
          EventBlock({ event: this.sheetEvent })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
    }
    .backgroundColor(Theme.card)
  }

  private refresh(): void {
    this.secureCard = resolveShow(this.liveEvents, 'secure', 'S3', this.boards, this.appId, this.secureCard);
    this.vanillaCard = resolveShow(this.liveEvents, 'vanilla-demo', 'S3', this.boards, this.appId, this.vanillaCard);
  }

  private openEvent(event: D4Event): void {
    if (event.phrase.length === 0) {
      return;
    }
    this.sheetMode = 'event';
    this.sheetEvent = event;
    this.showSheet = true;
  }
}
