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
  updateRecord, getTodaySummary, TodaySummary
} from '../database/RecordDB'

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
  // 喂奶和睡眠分开存，互不干扰
  @StorageLink('activeFeed') activeFeed: string = ''
  @StorageLink('activeSleep') activeSleep: string = ''

  // 喂奶状态
  @State feedActive: boolean = false
  @State feedStartTime: number = 0
  @State feedSubType: string = ''
  @State feedRecordId: number = 0
  @State feedSeconds: number = 0

  // 睡眠状态
  @State sleepActive: boolean = false
  @State sleepStartTime: number = 0
  @State sleepRecordId: number = 0
  @State sleepSeconds: number = 0

  @State recentRecords: BabyRecord[] = []
  @State lastFeedTime: number = 0
  @State lastDiaperTime: number = 0
  @State lastSleepTime: number = 0
  @State feedCount: number = 0
  @State sleepHours: string = '0'
  @State diaperCount: number = 0
  @State showFeedSheet: boolean = false
  @State currentTime: number = Date.now()
  @State feedBannerExpanded: boolean = false
  @State sleepBannerExpanded: boolean = false

  private clockInterval: number = -1

  aboutToAppear(): void {
    this.restoreActivities()
    this.loadData()
    this.startClock()
  }

  aboutToDisappear(): void {
    if (this.clockInterval !== -1) {
      clearInterval(this.clockInterval)
    }
  }

  restoreActivities(): void {
    if (this.activeFeed) {
      try {
        const act: ActiveActivity = JSON.parse(this.activeFeed) as ActiveActivity
        this.feedActive = true
        this.feedStartTime = act.startTime
        this.feedSubType = act.subType
        this.feedRecordId = act.recordId
        this.feedSeconds = Math.floor((Date.now() - act.startTime) / 1000)
      } catch {
        this.activeFeed = ''
      }
    }
    if (this.activeSleep) {
      try {
        const act: ActiveActivity = JSON.parse(this.activeSleep) as ActiveActivity
        this.sleepActive = true
        this.sleepStartTime = act.startTime
        this.sleepRecordId = act.recordId
        this.sleepSeconds = Math.floor((Date.now() - act.startTime) / 1000)
      } catch {
        this.activeSleep = ''
      }
    }
  }

  startClock(): void {
    this.clockInterval = setInterval(() => {
      this.currentTime = Date.now()
      if (this.feedActive) {
        this.feedSeconds = Math.floor((Date.now() - this.feedStartTime) / 1000)
      }
      if (this.sleepActive) {
        this.sleepSeconds = Math.floor((Date.now() - this.sleepStartTime) / 1000)
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

  async startFeed(subType: FeedType): Promise<void> {
    doVibrate(50)
    const now = Date.now()
    const id = await insertRecord({
      type: RecordType.FEED, startTime: now, endTime: 0,
      subType: subType as string, note: '', imageUri: '', amount: 0
    })
    const act: ActiveActivity = { type: RecordType.FEED, startTime: now, subType: subType as string, recordId: id }
    this.activeFeed = JSON.stringify(act)
    this.feedActive = true
    this.feedStartTime = now
    this.feedSubType = subType as string
    this.feedRecordId = id
    this.feedSeconds = 0
    this.feedBannerExpanded = false
    this.showFeedSheet = false
  }

  async endFeed(): Promise<void> {
    if (!this.feedActive) return
    doVibrate(100)
    await updateRecord(this.feedRecordId, { endTime: Date.now() })
    this.activeFeed = ''
    this.feedActive = false
    this.feedStartTime = 0
    this.feedSubType = ''
    this.feedRecordId = 0
    this.feedSeconds = 0
    this.feedBannerExpanded = false
    await this.loadData()
  }

  async startSleep(): Promise<void> {
    doVibrate(50)
    const now = Date.now()
    const id = await insertRecord({
      type: RecordType.SLEEP, startTime: now, endTime: 0,
      subType: '', note: '', imageUri: '', amount: 0
    })
    const act: ActiveActivity = { type: RecordType.SLEEP, startTime: now, subType: '', recordId: id }
    this.activeSleep = JSON.stringify(act)
    this.sleepActive = true
    this.sleepStartTime = now
    this.sleepRecordId = id
    this.sleepSeconds = 0
    this.sleepBannerExpanded = false
  }

  async endSleep(): Promise<void> {
    if (!this.sleepActive) return
    doVibrate(100)
    await updateRecord(this.sleepRecordId, { endTime: Date.now() })
    this.activeSleep = ''
    this.sleepActive = false
    this.sleepStartTime = 0
    this.sleepRecordId = 0
    this.sleepSeconds = 0
    this.sleepBannerExpanded = false
    await this.loadData()
  }

  // 喂奶横幅
  @Builder
  FeedBanner() {
    if (this.feedActive) {
      Column() {
        Row({ space: 12 }) {
          Text('🍼').fontSize(20)
          Column({ space: 2 }) {
            Text(`喂奶中 · ${feedTypeLabel(this.feedSubType)}`)
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#FF8C69')
            Text(`开始于 ${formatTime(this.feedStartTime)}`)
              .fontSize(12).fontColor('#999')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text(formatDuration(this.feedSeconds * 1000))
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FF8C69')
          Text(this.feedBannerExpanded ? ' ∧' : ' ∨').fontSize(14).fontColor('#aaa')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: this.feedBannerExpanded ? 8 : 12 })
        .onClick(() => { this.feedBannerExpanded = !this.feedBannerExpanded })

        if (this.feedBannerExpanded) {
          Button('✅ 结束喂奶')
            .onClick(() => { this.endFeed() })
            .backgroundColor('#FF8C69').fontColor(Color.White)
            .fontSize(15).fontWeight(FontWeight.Bold)
            .height(44).borderRadius(10)
            .margin({ left: 16, right: 16, bottom: 12 })
            .width('calc(100% - 32vp)')
        }
      }
      .width('100%')
      .backgroundColor('#FFF5F0')
      .border({ width: { bottom: 1 }, color: '#FFE0D0' })
      .animation({ duration: 200 })
    }
  }

  // 睡眠横幅
  @Builder
  SleepBanner() {
    if (this.sleepActive) {
      Column() {
        Row({ space: 12 }) {
          Text('😴').fontSize(20)
          Column({ space: 2 }) {
            Text('睡眠中')
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#7EC8C8')
            Text(`入睡于 ${formatTime(this.sleepStartTime)}`)
              .fontSize(12).fontColor('#999')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text(formatDuration(this.sleepSeconds * 1000))
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#7EC8C8')
          Text(this.sleepBannerExpanded ? ' ∧' : ' ∨').fontSize(14).fontColor('#aaa')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: this.sleepBannerExpanded ? 8 : 12 })
        .onClick(() => { this.sleepBannerExpanded = !this.sleepBannerExpanded })

        if (this.sleepBannerExpanded) {
          Button('☀️ 宝宝醒了')
            .onClick(() => { this.endSleep() })
            .backgroundColor('#7EC8C8').fontColor(Color.White)
            .fontSize(15).fontWeight(FontWeight.Bold)
            .height(44).borderRadius(10)
            .margin({ left: 16, right: 16, bottom: 12 })
            .width('calc(100% - 32vp)')
        }
      }
      .width('100%')
      .backgroundColor('#F0F9F9')
      .border({ width: { bottom: 1 }, color: '#C8EEEE' })
      .animation({ duration: 200 })
    }
  }

  @Builder
  LastRecordCard() {
    Row({ space: 0 }) {
      Column({ space: 4 }) {
        Text('🍼').fontSize(22)
        Text(this.lastFeedTime > 0 ? formatTimeAgo(this.lastFeedTime) : '未记录')
          .fontSize(12).fontColor('#666')
        Text('上次喂奶').fontSize(11).fontColor('#aaa')
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)

      Divider().vertical(true).height(40).color('#F0F0F0')

      Column({ space: 4 }) {
        Text('🧷').fontSize(22)
        Text(this.lastDiaperTime > 0 ? formatTimeAgo(this.lastDiaperTime) : '未记录')
          .fontSize(12).fontColor('#666')
        Text('上次换尿布').fontSize(11).fontColor('#aaa')
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)

      Divider().vertical(true).height(40).color('#F0F0F0')

      Column({ space: 4 }) {
        Text('😴').fontSize(22)
        Text(this.lastSleepTime > 0 ? formatTimeAgo(this.lastSleepTime) : '未记录')
          .fontSize(12).fontColor('#666')
        Text('上次入睡').fontSize(11).fontColor('#aaa')
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 6, color: '#0F000000', offsetX: 0, offsetY: 2 })
  }

  @Builder
  ActionButtons() {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Button('🍼')
          .onClick(() => { this.showFeedSheet = true })
          .backgroundColor(this.feedActive ? '#FF8C69' : '#FFF0E8')
          .fontColor(this.feedActive ? Color.White : '#FF8C69')
          .fontSize(24).width(64).height(64).borderRadius(32)
        Text(this.feedActive ? '喂奶中' : '喂奶')
          .fontSize(12)
          .fontColor(this.feedActive ? '#FF8C69' : '#666')
          .fontWeight(this.feedActive ? FontWeight.Bold : FontWeight.Normal)
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Button('🧷')
          .onClick(() => { router.pushUrl({ url: 'pages/DiaperPage' }) })
          .backgroundColor('#FFF3E0').fontColor('#FFB347')
          .fontSize(24).width(64).height(64).borderRadius(32)
        Text('换尿布').fontSize(12).fontColor('#666')
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Button('😴')
          .onClick(() => {
            if (this.sleepActive) {
              this.sleepBannerExpanded = true
            } else {
              this.startSleep()
            }
          })
          .backgroundColor(this.sleepActive ? '#7EC8C8' : '#E8F6F6')
          .fontColor(this.sleepActive ? Color.White : '#7EC8C8')
          .fontSize(24).width(64).height(64).borderRadius(32)
        Text(this.sleepActive ? '睡眠中' : '睡着了')
          .fontSize(12)
          .fontColor(this.sleepActive ? '#7EC8C8' : '#666')
          .fontWeight(this.sleepActive ? FontWeight.Bold : FontWeight.Normal)
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Button('📋')
          .onClick(() => { router.pushUrl({ url: 'pages/HistoryPage' }) })
          .backgroundColor('#F0F0F0').fontColor('#999')
          .fontSize(24).width(64).height(64).borderRadius(32)
        Text('历史').fontSize(12).fontColor('#666')
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
  }

  @Builder
  FeedSheet() {
    Column({ space: 12 }) {
      Text(this.feedActive ? '重新开始喂奶' : '选择喂奶方式')
        .fontSize(16).fontWeight(FontWeight.Medium).margin({ top: 16 })
      if (this.feedActive) {
        Text('当前喂奶记录将结束并开始新的').fontSize(13).fontColor('#aaa')
      }
      Grid() {
        GridItem() {
          Button('左乳')
            .onClick(() => { this.startFeed(FeedType.LEFT) })
            .backgroundColor('#FFF0E8').fontColor('#FF8C69')
            .fontSize(18).width('100%').height(70).borderRadius(14)
        }
        GridItem() {
          Button('右乳')
            .onClick(() => { this.startFeed(FeedType.RIGHT) })
            .backgroundColor('#FFF0E8').fontColor('#FF8C69')
            .fontSize(18).width('100%').height(70).borderRadius(14)
        }
        GridItem() {
          Button('🍼 奶瓶')
            .onClick(() => { this.startFeed(FeedType.BOTTLE) })
            .backgroundColor('#FFF0E8').fontColor('#FF8C69')
            .fontSize(18).width('100%').height(70).borderRadius(14)
        }
        GridItem() {
          Button('混合')
            .onClick(() => { this.startFeed(FeedType.MIXED) })
            .backgroundColor('#FFF0E8').fontColor('#FF8C69')
            .fontSize(18).width('100%').height(70).borderRadius(14)
        }
      }
      .columnsTemplate('1fr 1fr').rowsGap(12).columnsGap(12)
      .padding({ left: 20, right: 20 })
      .width('100%').height(160).margin({ bottom: 40 })
    }
    .width('100%').backgroundColor('#FFF8F0')
  }

  @Builder
  RecentTimeline() {
    Column({ space: 8 }) {
      Text('最近记录').fontSize(14).fontColor('#666').fontWeight(FontWeight.Medium).padding({ left: 4 })
      if (this.recentRecords.length === 0) {
        Text('暂无记录，点击下方按钮开始记录 🌟')
          .fontSize(13).fontColor('#bbb').textAlign(TextAlign.Center)
          .width('100%').padding({ top: 20, bottom: 20 })
      } else {
        Scroll() {
          Row({ space: 10 }) {
            ForEach(this.recentRecords.slice(0, 10), (item: BabyRecord) => {
              Column({ space: 4 }) {
                Text(recordTypeIcon(item.type)).fontSize(22)
                Text(formatTime(item.startTime)).fontSize(11).fontColor('#666')
                if (item.type === RecordType.FEED && item.endTime > 0) {
                  Text(formatDuration(item.endTime - item.startTime)).fontSize(10).fontColor('#aaa')
                } else if (item.type === RecordType.DIAPER) {
                  Text(diaperTypeLabel(item.subType)).fontSize(10).fontColor('#aaa')
                } else if (item.type === RecordType.SLEEP && item.endTime > 0) {
                  Text(formatDuration(item.endTime - item.startTime)).fontSize(10).fontColor('#aaa')
                } else if (item.endTime === 0) {
                  Text('进行中').fontSize(10).fontColor('#FF8C69')
                }
              }
              .padding({ top: 10, bottom: 10, left: 14, right: 14 })
              .backgroundColor('#FFFFFF').borderRadius(12)
              .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 1 })
              .alignItems(HorizontalAlign.Center)
            })
          }
          .padding({ bottom: 4 })
        }
        .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
      }
    }
  }

  build() {
    Column() {
      // 喂奶横幅
      this.FeedBanner()
      // 睡眠横幅
      this.SleepBanner()

      // 主滚动区
      Scroll() {
        Column({ space: 16 }) {
          Row() {
            Column({ space: 2 }) {
              Text('宝宝').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333')
              Text(formatDate(this.currentTime)).fontSize(13).fontColor('#999')
            }
            Blank()
            Row({ space: 20 }) {
              Column({ space: 2 }) {
                Text(`${this.feedCount}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FF8C69')
                Text('喂奶').fontSize(11).fontColor('#aaa')
              }
              Column({ space: 2 }) {
                Text(this.sleepHours).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#7EC8C8')
                Text('睡眠').fontSize(11).fontColor('#aaa')
              }
              Column({ space: 2 }) {
                Text(`${this.diaperCount}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFB347')
                Text('尿布').fontSize(11).fontColor('#aaa')
              }
            }
          }
          .width('100%').padding({ left: 4, right: 4 })

          this.LastRecordCard()
          this.RecentTimeline()
          Blank().height(100)
        }
        .padding({ top: 16, left: 20, right: 20, bottom: 20 })
      }
      .scrollable(ScrollDirection.Vertical).scrollBar(BarState.Off)
      .layoutWeight(1).width('100%')

      // 固定底部操作栏
      Column() {
        Divider().color('#F0F0F0').strokeWidth(1)
        this.ActionButtons()
        Blank().height(28)
      }
      .width('100%').backgroundColor('#FFFFFF')
      .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: -2 })
    }
    .width('100%').height('100%').backgroundColor('#FFF8F0')
    .bindSheet(this.showFeedSheet, this.FeedSheet(), {
      height: 320,
      dragBar: true,
      backgroundColor: '#FFF8F0',
      onDisappear: () => { this.showFeedSheet = false }
    })
  }
}
