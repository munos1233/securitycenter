import { Theme } from '../common/Theme';
import { ChoiceRow, EventBlock, EventCard, GoldButton } from '../components/UiParts';
import { Choice, D4Event, filterEvents } from '../model/D4Types';
import { LiveStore } from '../model/LiveStore';

@Component
export struct StreamView {
  @StorageLink('liveEvents') liveEvents: D4Event[] = [];
  @State role: string = '';
  @State showSheet: boolean = false;
  @State detail: D4Event = new D4Event();
  @State confirmDelete: boolean = false;
  private roles: Choice[] = [
    new Choice('', '全部板子'),
    new Choice('vanilla-demo', '普通版'),
    new Choice('secure', '安全版')
  ];

  build() {
    Scroll() {
      Column() {
        ChoiceRow({
          title: '哪一块板',
          options: this.roles,
          value: this.role,
          onPick: (value: string) => {
            this.role = value;
          }
        })
        if (filterEvents(this.liveEvents, this.role, '').length === 0) {
          Text('事件流是空的。对照台记下观察，或在证据页导入文件之后，会出现在这里。')
            .width('100%')
            .fontSize(14)
            .fontColor(Theme.muted)
            .padding(16)
            .borderRadius(12)
            .backgroundColor(Theme.card)
        }
        ForEach(filterEvents(this.liveEvents, this.role, ''), (item: D4Event) => {
          EventCard({
            event: item,
            onOpen: (eventId: string) => {
              this.openEvent(eventId);
            }
          })
        }, (item: D4Event) => item.eventId)
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
        EventBlock({ event: this.detail })
        GoldButton({
          label: this.confirmDelete ? '确认删除这条' : '删除这条',
          onTap: () => {
            this.deleteCurrent();
          }
        })
      }
      .width('100%')
      .padding(20)
    }
    .backgroundColor(Theme.card)
  }

  private openEvent(eventId: string): void {
    for (let i = 0; i < this.liveEvents.length; i++) {
      if (this.liveEvents[i].eventId === eventId) {
        this.detail = this.liveEvents[i];
        this.confirmDelete = false;
        this.showSheet = true;
        return;
      }
    }
  }

  private deleteCurrent(): void {
    if (!this.confirmDelete) {
      this.confirmDelete = true;
      return;
    }
    this.showSheet = false;
    this.confirmDelete = false;
    LiveStore.deleteEvent(this.detail.eventId);
  }
}
