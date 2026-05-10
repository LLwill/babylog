import router from '@ohos.router'
import vibrator from '@ohos.vibrator'
import {
  RecordType, FeedType,
  BabyRecord, ActiveActivity,
  formatTimeAgo, formatTime, formatDuration,
  recordTypeIcon, feedTypeLabel, diaperTypeLabel, formatDate
} from '../model/RecordModel'
import {
  insertRecord, getRecentRecords, getLastRecord,
  updateRecord, getTodaySummary
} from '../database/RecordDB'
import { TodaySummary } from '../database/RecordDB'

function doVibrate(duration: number): void {
  try {
    const effect: vibrator.VibrateTime = { type: 'time', duration: duration }
    const attr: vibrator.VibrateAttribute = { id: 0, usage: 'touch' }
    vibrator.startVibration(effect, attr)
  } catch (_e) {}
}

@Entry
@Component
struct Index {
  @StorageLink('activeActivity') activeActivity: string = ''
  @State recentRecords: BabyRecord[] = []
  @State lastFeedTime: number = 0
  @State lastDiaperTime: number = 0
  @State lastSleepTime: number = 0
  @State feedCount: number = 0
  @State sleepHours: string = '0'
  @State diaperCount: number = 0
  @State timerSeconds: number = 0
  @State showFeedSheet: boolean = false
  @State currentTime: number = Date.now()

  private clockInterval: number = -1

  aboutToAppear(): void {
    this.loadData()
    this.startClock()
  }

  aboutToDisappear(): void {
    if (this.clockInterval !== -1) {
      clearInterval(this.clockInterval)
    }
  }

  startClock(): void {
    this.clockInterval = setInterval(() => {
      this.currentTime = Date.now()
      if (this.activeActivity) {
        const act: ActiveActivity = JSON.parse(this.activeActivity) as ActiveActivity
        this.timerSeconds = Math.floor((Date.now() - act.startTime) / 1000)
      }
    }, 1000)
  }

  async loadData(): Promise<void> {
    try {
      const recent = await getRecentRecords(10)
      const lastFeed = await getLastRecord(RecordType.FEED)
      const lastDiaper = await getLastRecord(RecordType.DIAPER)
      const lastSleep = await getLastRecord(RecordType.SLEEP)
      const summary: TodaySummary = await getTodaySummary()
      this.recentRecords = recent
      this.lastFeedTime = lastFeed !== null ? lastFeed.startTime : 0
      this.lastDiaperTime = lastDiaper !== null ? lastDiaper.startTime : 0
      this.lastSleepTime = lastSleep !== null ? lastSleep.startTime : 0
      this.feedCount = summary.feedCount
      this.diaperCount = summary.diaperCount
      const sleepH = summary.sleepMs / 3600000
      this.sleepHours = sleepH >= 1 ? sleepH.toFixed(1) : `${Math.floor(summary.sleepMs / 60000)}m`
    } catch (e) {
      console.error('loadData error', JSON.stringify(e))
    }
  }

  getActiveActivity(): ActiveActivity | null {
    if (!this.activeActivity) {
      return null
    }
    try {
      return JSON.parse(this.activeActivity) as ActiveActivity
    } catch {
      return null
    }
  }

  async startFeed(subType: FeedType): Promise<void> {
    doVibrate(50)
    const now = Date.now()
    const id = await insertRecord({
      type: RecordType.FEED,
      startTime: now,
      endTime: 0,
      subType: subType as string,
      note: '',
      imageUri: '',
      amount: 0
    })
    const act: ActiveActivity = { type: RecordType.FEED, startTime: now, subType: subType as string, recordId: id }
    this.activeActivity = JSON.stringify(act)
    this.showFeedSheet = false
  }

  async endFeed(): Promise<void> {
    const act = this.getActiveActivity()
    if (act === null || act.type !== RecordType.FEED) {
      return
    }
    doVibrate(100)
    await updateRecord(act.recordId, { endTime: Date.now() })
    this.activeActivity = ''
    this.timerSeconds = 0
    await this.loadData()
  }

  async startSleep(): Promise<void> {
    doVibrate(50)
    const now = Date.now()
    const id = await insertRecord({
      type: RecordType.SLEEP,
      startTime: now,
      endTime: 0,
      subType: '',
      note: '',
      imageUri: '',
      amount: 0
    })
    const act: ActiveActivity = { type: RecordType.SLEEP, startTime: now, subType: '', recordId: id }
    this.activeActivity = JSON.stringify(act)
  }

  async endSleep(): Promise<void> {
    const act = this.getActiveActivity()
    if (act === null || act.type !== RecordType.SLEEP) {
      return
    }
    doVibrate(100)
    await updateRecord(act.recordId, { endTime: Date.now() })
    this.activeActivity = ''
    this.timerSeconds = 0
    await this.loadData()
  }

  @Builder
  StatusCard() {
    const act = this.getActiveActivity()
    Column() {
      if (act === null) {
        Column({ space: 16 }) {
          Text('宝宝状态')
            .fontSize(14)
            .fontColor('#999')
          Row({ space: 24 }) {
            Column({ space: 4 }) {
              Text('🍼').fontSize(24)
              Text(this.lastFeedTime > 0 ? formatTimeAgo(this.lastFeedTime) : '未记录')
                .fontSize(13).fontColor('#666')
              Text('上次喂奶').fontSize(11).fontColor('#aaa')
            }
            Column({ space: 4 }) {
              Text('🧷').fontSize(24)
              Text(this.lastDiaperTime > 0 ? formatTimeAgo(this.lastDiaperTime) : '未记录')
                .fontSize(13).fontColor('#666')
              Text('上次换尿布').fontSize(11).fontColor('#aaa')
            }
            Column({ space: 4 }) {
              Text('😴').fontSize(24)
              Text(this.lastSleepTime > 0 ? formatTimeAgo(this.lastSleepTime) : '未记录')
                .fontSize(13).fontColor('#666')
              Text('上次入睡').fontSize(11).fontColor('#aaa')
            }
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      } else if (act.type === RecordType.FEED) {
        Column({ space: 12 }) {
          Text('🍼 喂奶中').fontSize(16).fontColor('#FF8C69').fontWeight(FontWeight.Medium)
          Text(feedTypeLabel(act.subType)).fontSize(13).fontColor('#999')
          Text(formatDuration(this.timerSeconds * 1000))
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF8C69')
          Text(`开始于 ${formatTime(act.startTime)}`).fontSize(12).fontColor('#aaa')
        }
        .alignItems(HorizontalAlign.Center)
      } else if (act.type === RecordType.SLEEP) {
        Column({ space: 12 }) {
          Text('😴 睡眠中').fontSize(16).fontColor('#7EC8C8').fontWeight(FontWeight.Medium)
          Text(formatDuration(this.timerSeconds * 1000))
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor('#7EC8C8')
          Text(`入睡于 ${formatTime(act.startTime)}`).fontSize(12).fontColor('#aaa')
        }
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: 24, bottom: 24, left: 20, right: 20 })
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 2 })
    .justifyContent(FlexAlign.Center)
    .height(180)
  }

  @Builder
  ActionButtons() {
    const act = this.getActiveActivity()
    Row({ space: 12 }) {
      if (act === null) {
        Button('🍼 喂奶')
          .onClick(() => { this.showFeedSheet = true })
          .backgroundColor('#FF8C69')
          .fontColor(Color.White)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .height(56)
          .layoutWeight(1)
          .borderRadius(16)
        Button('🧷 换尿布')
          .onClick(() => { router.pushUrl({ url: 'pages/DiaperPage' }) })
          .backgroundColor('#FFB347')
          .fontColor(Color.White)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .height(56)
          .layoutWeight(1)
          .borderRadius(16)
        Button('😴 睡着了')
          .onClick(() => { this.startSleep() })
          .backgroundColor('#7EC8C8')
          .fontColor(Color.White)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .height(56)
          .layoutWeight(1)
          .borderRadius(16)
      } else if (act.type === RecordType.FEED) {
        Button('✅ 结束喂奶')
          .onClick(() => { this.endFeed() })
          .backgroundColor('#FF8C69')
          .fontColor(Color.White)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .height(60)
          .width('100%')
          .borderRadius(16)
      } else if (act.type === RecordType.SLEEP) {
        Button('☀️ 宝宝醒了')
          .onClick(() => { this.endSleep() })
          .backgroundColor('#7EC8C8')
          .fontColor(Color.White)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .height(60)
          .width('100%')
          .borderRadius(16)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  FeedSheet() {
    Column({ space: 16 }) {
      Text('选择喂奶方式')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 12 })
      Grid() {
        GridItem() {
          Button('左乳')
            .onClick(() => { this.startFeed(FeedType.LEFT) })
            .backgroundColor('#FFF0E8')
            .fontColor('#FF8C69')
            .fontSize(18)
            .width('100%')
            .height(70)
            .borderRadius(14)
        }
        GridItem() {
          Button('右乳')
            .onClick(() => { this.startFeed(FeedType.RIGHT) })
            .backgroundColor('#FFF0E8')
            .fontColor('#FF8C69')
            .fontSize(18)
            .width('100%')
            .height(70)
            .borderRadius(14)
        }
        GridItem() {
          Button('🍼 奶瓶')
            .onClick(() => { this.startFeed(FeedType.BOTTLE) })
            .backgroundColor('#FFF0E8')
            .fontColor('#FF8C69')
            .fontSize(18)
            .width('100%')
            .height(70)
            .borderRadius(14)
        }
        GridItem() {
          Button('混合')
            .onClick(() => { this.startFeed(FeedType.MIXED) })
            .backgroundColor('#FFF0E8')
            .fontColor('#FF8C69')
            .fontSize(18)
            .width('100%')
            .height(70)
            .borderRadius(14)
        }
      }
      .columnsTemplate('1fr 1fr')
      .rowsGap(12)
      .columnsGap(12)
      .padding({ left: 20, right: 20 })
      .width('100%')
      .height(160)
      .margin({ bottom: 32 })
    }
    .width('100%')
    .backgroundColor('#FFF8F0')
  }

  @Builder
  RecentTimeline() {
    Column({ space: 8 }) {
      Row() {
        Text('最近记录').fontSize(14).fontColor('#666').fontWeight(FontWeight.Medium)
        Blank()
        Text('查看全部 >')
          .fontSize(13)
          .fontColor('#FF8C69')
          .onClick(() => { router.pushUrl({ url: 'pages/HistoryPage' }) })
      }
      .width('100%')
      .padding({ left: 4, right: 4 })

      if (this.recentRecords.length === 0) {
        Text('暂无记录，开始记录宝宝的第一次吧 🌟')
          .fontSize(13)
          .fontColor('#aaa')
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 12, bottom: 12 })
      } else {
        Scroll() {
          Row({ space: 10 }) {
            ForEach(this.recentRecords.slice(0, 8), (item: BabyRecord) => {
              Column({ space: 4 }) {
                Text(recordTypeIcon(item.type)).fontSize(22)
                Text(formatTime(item.startTime)).fontSize(11).fontColor('#666')
                if (item.type === RecordType.FEED && item.endTime > 0) {
                  Text(formatDuration(item.endTime - item.startTime)).fontSize(10).fontColor('#aaa')
                } else if (item.type === RecordType.DIAPER) {
                  Text(diaperTypeLabel(item.subType)).fontSize(10).fontColor('#aaa')
                } else if (item.type === RecordType.SLEEP && item.endTime > 0) {
                  Text(formatDuration(item.endTime - item.startTime)).fontSize(10).fontColor('#aaa')
                }
              }
              .padding({ top: 10, bottom: 10, left: 14, right: 14 })
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 1 })
              .alignItems(HorizontalAlign.Center)
            })
          }
          .padding({ bottom: 4 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }
    }
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 16 }) {
          Row() {
            Column({ space: 2 }) {
              Text('宝宝').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333')
              Text(formatDate(this.currentTime)).fontSize(13).fontColor('#999')
            }
            Blank()
            Row({ space: 16 }) {
              Column({ space: 2 }) {
                Text(`${this.feedCount}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FF8C69')
                Text('喂奶').fontSize(11).fontColor('#aaa')
              }
              Column({ space: 2 }) {
                Text(this.sleepHours).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#7EC8C8')
                Text('睡眠').fontSize(11).fontColor('#aaa')
              }
              Column({ space: 2 }) {
                Text(`${this.diaperCount}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFB347')
                Text('尿布').fontSize(11).fontColor('#aaa')
              }
            }
          }
          .width('100%')
          .padding({ left: 4, right: 4 })

          this.StatusCard()
          this.RecentTimeline()
          Blank().height(88)
        }
        .padding({ top: 16, left: 20, right: 20, bottom: 20 })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      Column() {
        Blank()
        Column() {
          this.ActionButtons()
        }
        .padding({ top: 12, bottom: 28 })
        .backgroundColor('#FFF8F0')
        .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: -2 })
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF8F0')
    .bindSheet($showFeedSheet, this.FeedSheet(), {
      height: 280,
      dragBar: true,
      backgroundColor: '#FFF8F0'
    })
  }
}
