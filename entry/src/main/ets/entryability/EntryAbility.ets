import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { LiveStore } from '../model/LiveStore';

const DOMAIN = 0x4A59;
const TAG = 'SecurityCenter';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    let name = 'com.jinyinhu.securitycenter';
    if (typeof want.bundleName === 'string') {
      name = want.bundleName;
    }
    hilog.info(DOMAIN, TAG, 'onCreate %{public}s', name + '/' + launchParam.launchReason.toString());
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'colorMode %{public}s', JSON.stringify(err));
    }
    LiveStore.bind(this.context);
    LiveStore.prepare();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    LiveStore.restore().then(() => {
      this.open(windowStage);
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'restore %{public}s', JSON.stringify(err));
      this.open(windowStage);
    });
  }

  private open(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err && err.code) {
        hilog.error(DOMAIN, TAG, 'load %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'loaded');
    });
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setWindowBackgroundColor('#FF0E2244');
      win.setWindowKeepScreenOn(true);
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'window %{public}s', JSON.stringify(err));
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground');
  }
}
