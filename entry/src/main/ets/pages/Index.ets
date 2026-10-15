import { Theme } from '../common/Theme';
import { StatusLine, TabBar } from '../components/UiParts';
import { ArchiveView } from './ArchiveView';
import { BaselineView } from './BaselineView';
import { EvidenceView } from './EvidenceView';
import { OverviewView } from './OverviewView';
import { SecurityShowView } from './SecurityShowView';
import { StreamView } from './StreamView';

@Entry
@Component
struct Index {
  @StorageLink('statusLine') statusLine: string = '';
  @State showMode: boolean = true;
  @State tab: number = 0;
  private tabs: string[] = ['闭环', '记录', '清单', '事件', '台账'];

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      SecurityShowView({
        active: this.showMode,
        onPrep: () => {
          this.showMode = false;
        }
      })
        .width('100%')
        .height('100%')
        .visibility(this.showMode ? Visibility.Visible : Visibility.None)

      Column() {
        Row() {
          Text('返回正片')
            .fontSize(16)
            .fontColor(Theme.gold)
            .onClick(() => {
              this.showMode = true;
            })
          Blank()
          Text('准备')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.text)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 4 })

        StatusLine({ text: this.statusLine })
        TabBar({
          tabs: this.tabs,
          index: this.tab,
          onPick: (index: number) => {
            this.tab = index;
          }
        })
        Stack({ alignContent: Alignment.TopStart }) {
          OverviewView({
            onOpenTab: (index: number) => {
              this.tab = index;
            }
          })
            .width('100%')
            .height('100%')
            .visibility(this.tab === 0 ? Visibility.Visible : Visibility.None)
          EvidenceView()
            .width('100%')
            .height('100%')
            .visibility(this.tab === 1 ? Visibility.Visible : Visibility.None)
          BaselineView()
            .width('100%')
            .height('100%')
            .visibility(this.tab === 2 ? Visibility.Visible : Visibility.None)
          StreamView()
            .width('100%')
            .height('100%')
            .visibility(this.tab === 3 ? Visibility.Visible : Visibility.None)
          ArchiveView()
            .width('100%')
            .height('100%')
            .visibility(this.tab === 4 ? Visibility.Visible : Visibility.None)
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.page)
      .visibility(this.showMode ? Visibility.None : Visibility.Visible)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.page)
  }
}
