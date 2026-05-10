import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { initDB, fixOrphanRecords, getOrphanSleep } from '../database/RecordDB';
import { ActiveActivity, RecordType } from '../model/RecordModel';

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

    AppStorage.setOrCreate<boolean>('dbReady', false)
    initDB(this.context).then(async () => {
      // 1. 修复孤儿喂奶记录（超过1小时自动封底）
      const activeIds = getActiveIds()
      await fixOrphanRecords(activeIds)

      // 2. 手机重启后 AppStorage 丢失：恢复进行中的睡眠记录
      const sleepStr = AppStorage.get<string>('activeSleep')
      if (!sleepStr) {
        const orphanSleep = await getOrphanSleep()
        if (orphanSleep !== null) {
          const act: ActiveActivity = {
            type: RecordType.SLEEP,
            startTime: orphanSleep.startTime,
            subType: '',
            recordId: orphanSleep.id
          }
          AppStorage.setOrCreate<string>('activeSleep', JSON.stringify(act))
          hilog.info(DOMAIN, 'testTag', 'Restored orphan sleep: id=%{public}d', orphanSleep.id)
        }
      }

      AppStorage.setOrCreate<boolean>('dbReady', true)
      hilog.info(DOMAIN, 'testTag', 'DB initialized')
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Failed to init DB: %{public}s', JSON.stringify(err))
      AppStorage.setOrCreate<boolean>('dbReady', true)
    })

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
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
