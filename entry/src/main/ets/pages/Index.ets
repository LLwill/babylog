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

type ActivityState = '' | 'FEED' | 'SLEEP'

@Entry
@Component
struct Index {
  @StorageLink('activeActivity') activeActivity: string = ''

  @State activityState: ActivityState = ''
  @State activityStartTime: number = 0
  @State activitySubType: string = ''
  @State activityRecordId: number = 0

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
  // 控制活动卡片是否展开结束按钮
  @State activityCardExpanded: boolean = false

  private clockInterval: number = -1

  aboutToAppear(): void {
    this.restoreActivity()
    this.loadData()
    this.startClock()
  }

  aboutToDisappear(): void {
    if (this.clockInterval !== -1) {
      clearInterval(this.clockInterval)
    }
  }

  restoreActivity(): void {
    if (!this.activeActivity) {
      this.activityState = ''
      return
    }
    try {
      const act: ActiveActivity = JSON.parse(this.activeActivity) as ActiveActivity
      if (act.type === RecordType.FEED) {
        this.activityState = 'FEED'
      } else if (act.type === RecordType.SLEEP) {
        this.activityState = 'SLEEP'
      } else {
        this.activityState = ''
      }
      this.activityStartTime = act.startTime
      this.activitySubType = act.subType
      this.activityRecordId = act.recordId
      this.timerSeconds = Math.floor((Date.now() - act.startTime) / 1000)
    } catch {
      this.activityState = ''
    }
  }

  startClock(): void {
    this.clockInterval = setInterval(() => {
      this.currentTime = Date.now()
      if (this.activityState !== '') {
        this.timerSeconds = Math.floor((Date.now() - this.activityStartTime) / 1000)
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

  saveActivity(type: RecordType, startTime: number, subType: string, recordId: number): void {
    const act: ActiveActivity = { type, startTime, subType, recordId }
    this.activeActivity = JSON.stringify(act)
    this.activityState = type === RecordType.FEED ? 'FEED' : 'SLEEP'
    this.activityStartTime = startTime
    this.activitySubType = subType
    this.activityRecordId = recordId
    this.activityCardExpanded = false
  }

  clearActivity(): void {
    this.activeActivity = ''
    this.activityState = ''
    this.activityStartTime = 0
    this.activitySubType = ''
    this.activityRecordId = 0
    this.timerSeconds = 0
    this.activityCardExpanded = false
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
    this.saveActivity(RecordType.FEED, now, subType as string, id)
    this.showFeedSheet = false
  }

  async endFeed(): Promise<void> {
    if (this.activityState !== 'FEED') return
    doVibrate(100)
    await updateRecord(this.activityRecordId, { endTime: Date.now() })
    this.clearActivity()
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
    this.saveActivity(RecordType.SLEEP, now, '', id)
  }

  async endSleep(): Promise<void> {
    if (this.activityState !== 'SLEEP') return
    doVibrate(100)
    await updateRecord(this.activityRecordId, { endTime: Date.now() })
    this.clearActivity()
    await this.loadData()
  }

  // ── 进行中活动横幅（悬浮在顶部，随时可见） ──
  @Builder
  ActivityBanner() {
    if (this.activityState !== '') {
      Column() {
        // 点击展开/收起结束按钮
        Row({ space: 12 }) {
          Text(this.activityState === 'FEED' ? '🍼' : '😴').fontSize(20)
          Column({ space: 2 }) {
            Text(this.activityState === 'FEED' ? `喂奶中 · ${feedTypeLabel(this.activitySubType)}` : '睡眠中')
              .fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor(this.activityState === 'FEED' ? '#FF8C69' : '#7EC8C8')
            Text(`开始于 ${formatTime(this.activityStartTime)}`)
              .fontSize(12).fontColor('#999')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text(formatDuration(this.timerSeconds * 1000))
            .fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(this.activityState === 'FEED' ? '#FF8C69' : '#7EC8C8')
          Text(this.activityCardExpanded ? '∧' : '∨')
            .fontSize(14).fontColor('#aaa').margin({ left: 4 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: this.activityCardExpanded ? 8 : 14 })
        .onClick(() => { this.activityCardExpanded = !this.activityCardExpanded })

        // 展开后显示结束按钮
        if (this.activityCardExpanded) {
          Button(this.activityState === 'FEED' ? '✅ 结束喂奶' : '☀️ 宝宝醒了')
            .onClick(() => {
              if (this.activityState === 'FEED') {
                this.endFeed()
              } else {
                this.endSleep()
              }
            })
            .backgroundColor(this.activityState === 'FEED' ? '#FF8C69' : '#7EC8C8')
            .fontColor(Color.White)
            .fontSize(16).fontWeight(FontWeight.Bold)
            .height(48).width('100%')
            .borderRadius(12)
            .margin({ left: 16, right: 16, bottom: 14 })
            .width('calc(100% - 32vp)')
        }
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius({ bottomLeft: 16, bottomRight: 16 })
      .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 3 })
      .animation({ duration: 200 })
    }
  }

  // ── 上次记录状态卡 ──
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

  // ── 底部操作按钮（始终显示三个，不锁定） ──
  @Builder
  ActionButtons() {
    Row({ space: 10 }) {
      // 喂奶按钮：有活动中时变为带指示点的状态
      Column({ space: 4 }) {
        Button('🍼')
          .onClick(() => { this.showFeedSheet = true })
          .backgroundColor(this.activityState === 'FEED' ? '#FF8C69' : '#FFF0E8')
          .fontColor(this.activityState === 'FEED' ? Color.White : '#FF8C69')
          .fontSize(24).width(64).height(64).borderRadius(32)
        Text(this.activityState === 'FEED' ? '喂奶中' : '喂奶')
          .fontSize(12)
          .fontColor(this.activityState === 'FEED' ? '#FF8C69' : '#666')
          .fontWeight(this.activityState === 'FEED' ? FontWeight.Bold : FontWeight.Normal)
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)

      // 换尿布按钮（始终可用）
      Column({ space: 4 }) {
        Button('🧷')
          .onClick(() => { router.pushUrl({ url: 'pages/DiaperPage' }) })
          .backgroundColor('#FFF3E0')
          .fontColor('#FFB347')
          .fontSize(24).width(64).height(64).borderRadius(32)
        Text('换尿布').fontSize(12).fontColor('#666')
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)

      // 睡眠按钮
      Column({ space: 4 }) {
        Button('😴')
          .onClick(() => {
            if (this.activityState === 'SLEEP') {
              this.activityCardExpanded = true
            } else {
              this.startSleep()
            }
          })
          .backgroundColor(this.activityState === 'SLEEP' ? '#7EC8C8' : '#E8F6F6')
          .fontColor(this.activityState === 'SLEEP' ? Color.White : '#7EC8C8')
          .fontSize(24).width(64).height(64).borderRadius(32)
        Text(this.activityState === 'SLEEP' ? '睡眠中' : '睡着了')
          .fontSize(12)
          .fontColor(this.activityState === 'SLEEP' ? '#7EC8C8' : '#666')
          .fontWeight(this.activityState === 'SLEEP' ? FontWeight.Bold : FontWeight.Normal)
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)

      // 历史记录入口
      Column({ space: 4 }) {
        Button('📋')
          .onClick(() => { router.pushUrl({ url: 'pages/HistoryPage' }) })
          .backgroundColor('#F0F0F0')
          .fontColor('#999')
          .fontSize(24).width(64).height(64).borderRadius(32)
        Text('历史').fontSize(12).fontColor('#666')
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
  }

  // ── 喂奶类型 Sheet ──
  @Builder
  FeedSheet() {
    Column({ space: 12 }) {
      Text(this.activityState === 'FEED' ? '喂奶进行中，重新开始？' : '选择喂奶方式')
        .fontSize(16).fontWeight(FontWeight.Medium).margin({ top: 16 })
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

  // ── 最近记录时间线 ──
  @Builder
  RecentTimeline() {
    Column({ space: 8 }) {
      Text('最近记录')
        .fontSize(14).fontColor('#666').fontWeight(FontWeight.Medium)
        .padding({ left: 4 })

      if (this.recentRecords.length === 0) {
        Text('暂无记录，点击下方按钮开始记录 🌟')
          .fontSize(13).fontColor('#bbb')
          .textAlign(TextAlign.Center)
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
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off).width('100%')
      }
    }
  }

  build() {
    Column() {
      // 顶部活动横幅（有活动时显示）
      this.ActivityBanner()

      // 主滚动区
      Scroll() {
        Column({ space: 16 }) {
          // 顶部：宝宝信息 + 今日摘要
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

          // 上次记录卡
          this.LastRecordCard()

          // 最近时间线
          this.RecentTimeline()

          // 底部留白
          Blank().height(100)
        }
        .padding({ top: 16, left: 20, right: 20, bottom: 20 })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')

      // 固定底部操作栏
      Column() {
        Divider().color('#F0F0F0').strokeWidth(1)
        this.ActionButtons()
        Blank().height(28)
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: -2 })
    }
    .width('100%').height('100%')
    .backgroundColor('#FFF8F0')
    .bindSheet(this.showFeedSheet, this.FeedSheet(), {
      height: 300,
      dragBar: true,
      backgroundColor: '#FFF8F0',
      onDisappear: () => { this.showFeedSheet = false }
    })
  }
}
