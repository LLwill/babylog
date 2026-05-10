import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { initDB, fixOrphanRecords } from '../database/RecordDB';
import { ActiveActivity } from '../model/RecordModel';

const DOMAIN = 0x0000;

function getActiveIds(): number[] {
  const ids: number[] = []
  const feedStr = AppStorage.get<string>('activeFeed')
  const sleepStr = AppStorage.get<string>('activeSleep')
  if (feedStr) {
    try {
      const act = JSON.parse(feedStr) as ActiveActivity
      if (act.recordId > 0) ids.push(act.recordId)
    } catch {}
  }
  if (sleepStr) {
    try {
      const act = JSON.parse(sleepStr) as ActiveActivity
      if (act.recordId > 0) ids.push(act.recordId)
    } catch {}
  }
  return ids
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    // 先初始化 DB，完成后再加载页面，保证首页拿到数据
    AppStorage.setOrCreate<boolean>('dbReady', false)
    initDB(this.context).then(async () => {
      // 修复孤儿记录（App 被杀/重启后遗留的 endTime=0 记录）
      const activeIds = getActiveIds()
      await fixOrphanRecords(activeIds)
      AppStorage.setOrCreate<boolean>('dbReady', true)
      hilog.info(DOMAIN, 'testTag', 'DB initialized successfully')
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Failed to init DB: %{public}s', JSON.stringify(err))
      AppStorage.setOrCreate<boolean>('dbReady', true)
    })

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
