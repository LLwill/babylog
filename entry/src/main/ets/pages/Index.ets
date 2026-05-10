import router from '@ohos.router'
import vibrator from '@ohos.vibrator'
import promptAction from '@ohos.promptAction'
import {
  RecordType, FeedType, TempSite,
  BabyRecord, ActiveActivity,
  formatTimeAgo, formatTime, formatDuration,
  recordTypeIcon, feedTypeLabel, diaperTypeLabel, formatDate,
  tempSiteLabel, tempColor, formatTemp
} from '../model/RecordModel'
import {
  insertRecord, getRecentRecords, getLastRecord, getLastCompletedRecord,
  updateRecord, getTodaySummary, TodaySummary
} from '../database/RecordDB'

function doVibrate(duration: number): void {
  try {
    const effect: vibrator.VibrateTime = { type: 'time', duration: duration }
    const attr: vibrator.VibrateAttribute = { id: 0, usage: 'touch' }
    vibrator.startVibration(effect, attr)
  } catch {}
}

@Entry
@Component
struct Index {
  // 喂奶和睡眠分开存，互不干扰
  @StorageLink('activeFeed') @Watch('onActiveFeedChange') activeFeed: string = ''
  @StorageLink('activeSleep') @Watch('onActiveSleepChange') activeSleep: string = ''
  @StorageLink('dbReady') @Watch('onDbReady') dbReady: boolean = false

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
  @State showTempSheet: boolean = false
  @State tempValue: number = 37.0
  @State tempSite: TempSite = TempSite.AXILLA
  @State currentTime: number = Date.now()
  @State feedBannerExpanded: boolean = false
  @State sleepBannerExpanded: boolean = false

  private clockInterval: number = -1

  aboutToAppear(): void {
    this.restoreActivities()
    this.startClock()
    if (this.dbReady) {
      this.loadData()
    }
    // 否则等 @Watch('onDbReady') 触发
  }

  // 从换尿布/历史页返回时刷新数据
  onPageShow(): void {
    if (this.dbReady) {
      this.loadData()
    }
  }

  onDbReady(): void {
    if (this.dbReady) {
      this.loadData()
    }
  }

  // 外部（历史页）修改 AppStorage 时同步更新首页状态
  onActiveFeedChange(): void {
    if (!this.activeFeed) {
      this.feedActive = false
      this.feedStartTime = 0
      this.feedSubType = ''
      this.feedRecordId = 0
      this.feedSeconds = 0
      this.feedBannerExpanded = false
    } else {
      try {
        const act: ActiveActivity = JSON.parse(this.activeFeed) as ActiveActivity
        this.feedActive = true
        this.feedStartTime = act.startTime
        this.feedSubType = act.subType
        this.feedRecordId = act.recordId
      } catch {}
    }
    this.loadData()
  }

  onActiveSleepChange(): void {
    if (!this.activeSleep) {
      this.sleepActive = false
      this.sleepStartTime = 0
      this.sleepRecordId = 0
      this.sleepSeconds = 0
      this.sleepBannerExpanded = false
    } else {
      try {
        const act: ActiveActivity = JSON.parse(this.activeSleep) as ActiveActivity
        this.sleepActive = true
        this.sleepStartTime = act.startTime
        this.sleepRecordId = act.recordId
      } catch {}
    }
    this.loadData()
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
      const recent = await getRecentRecords(5)
      const lastFeed = await getLastCompletedRecord(RecordType.FEED)
      const lastDiaper = await getLastRecord(RecordType.DIAPER)
      const lastSleep = await getLastCompletedRecord(RecordType.SLEEP)
      const summary: TodaySummary = await getTodaySummary()
      this.recentRecords = recent
      // 上次时间用已结束记录的 endTime，不用进行中记录的 startTime
      this.lastFeedTime = lastFeed !== null ? lastFeed.endTime : 0
      this.lastDiaperTime = lastDiaper !== null ? lastDiaper.startTime : 0
      this.lastSleepTime = lastSleep !== null ? lastSleep.endTime : 0
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
    // 有进行中的喂奶先结束它，避免历史记录留"进行中"
    if (this.feedActive && this.feedRecordId > 0) {
      await updateRecord(this.feedRecordId, { endTime: Date.now() })
    }
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

  async saveTemperature(): Promise<void> {
    doVibrate(50)
    await insertRecord({
      type: RecordType.TEMPERATURE,
      startTime: Date.now(),
      endTime: Date.now(),
      subType: this.tempSite as string,
      note: '',
      imageUri: '',
      amount: this.tempValue
    })
    this.showTempSheet = false
    this.tempValue = 37.0
    this.tempSite = TempSite.AXILLA
    await this.loadData()
  }

  showMoreMenu(): void {
    promptAction.showActionMenu({
      title: '',
      buttons: [
        { text: '🌡️ 记录体温', color: '#333333' }
      ]
    }).then((result) => {
      if (result.index === 0) {
        this.showTempSheet = true
      }
    })
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
    }
    .width('100%')
    .padding({ left: 24, right: 24 })
  }

  @Builder
  FeedSheet() {
    Column({ space: 12 }) {
      if (this.feedActive) {
        Column({ space: 4 }) {
          Text('换边 / 换方式').fontSize(16).fontWeight(FontWeight.Medium).margin({ top: 16 })
          Text(`当前 ${feedTypeLabel(this.feedSubType)} 已喂 ${formatDuration(this.feedSeconds * 1000)}，选择后结束并开始新记录`)
            .fontSize(12).fontColor('#aaa').textAlign(TextAlign.Center)
            .padding({ left: 20, right: 20 })
        }
      } else {
        Text('选择喂奶方式').fontSize(16).fontWeight(FontWeight.Medium).margin({ top: 16 })
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
  TempSheet() {
    Column({ space: 16 }) {
      Text('🌡️ 记录体温')
        .fontSize(16).fontWeight(FontWeight.Medium).margin({ top: 16 })

      // 快捷预设按钮
      Grid() {
        ForEach([36.5, 37.0, 37.5, 38.0, 38.5, 39.0], (val: number) => {
          GridItem() {
            Button(`${val.toFixed(1)}`)
              .onClick(() => { this.tempValue = val })
              .backgroundColor(this.tempValue === val ? tempColor(val) : '#F5F5F5')
              .fontColor(this.tempValue === val ? Color.White : '#333')
              .fontSize(16).width('100%').height(48).borderRadius(12)
          }
        })
      }
      .columnsTemplate('1fr 1fr 1fr').rowsGap(10).columnsGap(10)
      .padding({ left: 20, right: 20 }).width('100%').height(116)

      // 微调区
      Row({ space: 20 }) {
        Button('-')
          .onClick(() => {
            if (this.tempValue > 35.0) {
              this.tempValue = Math.round((this.tempValue - 0.1) * 10) / 10
            }
          })
          .backgroundColor('#F5F5F5').fontColor('#333')
          .fontSize(24).width(56).height(56).borderRadius(28)

        Text(formatTemp(this.tempValue))
          .fontSize(36).fontWeight(FontWeight.Bold)
          .fontColor(tempColor(this.tempValue))
          .width(120).textAlign(TextAlign.Center)

        Button('+')
          .onClick(() => {
            if (this.tempValue < 42.0) {
              this.tempValue = Math.round((this.tempValue + 0.1) * 10) / 10
            }
          })
          .backgroundColor('#F5F5F5').fontColor('#333')
          .fontSize(24).width(56).height(56).borderRadius(28)
      }
      .justifyContent(FlexAlign.Center).width('100%')

      // 测量部位
      Row({ space: 10 }) {
        ForEach([TempSite.AXILLA, TempSite.ORAL, TempSite.EAR], (site: TempSite) => {
          Button(tempSiteLabel(site as string))
            .onClick(() => { this.tempSite = site })
            .backgroundColor(this.tempSite === site ? '#FF8C69' : '#F5F5F5')
            .fontColor(this.tempSite === site ? Color.White : '#666')
            .fontSize(14).height(36).borderRadius(18)
            .layoutWeight(1)
        })
      }
      .padding({ left: 20, right: 20 }).width('100%')

      // 保存按钮
      Button('保存记录')
        .onClick(() => { this.saveTemperature() })
        .backgroundColor('#FF8C69').fontColor(Color.White)
        .fontSize(16).fontWeight(FontWeight.Bold)
        .height(50).width('calc(100% - 40vp)').borderRadius(14)
        .margin({ bottom: 40 })
    }
    .width('100%').backgroundColor('#FFF8F0').alignItems(HorizontalAlign.Center)
  }

  @Builder
  RecentTimeline() {
    Column({ space: 0 }) {
      Row() {
        Text('最近记录').fontSize(14).fontColor('#666').fontWeight(FontWeight.Medium)
        Blank()
        Text('全部 >').fontSize(13).fontColor('#FF8C69')
          .onClick(() => { router.pushUrl({ url: 'pages/HistoryPage' }) })
      }
      .width('100%').padding({ left: 4, right: 4, bottom: 12 })

      if (this.recentRecords.length === 0) {
        Text('暂无记录，点击下方按钮开始记录 🌟')
          .fontSize(13).fontColor('#bbb').textAlign(TextAlign.Center)
          .width('100%').padding({ top: 20, bottom: 20 })
      } else {
        Column({ space: 0 }) {
          ForEach(this.recentRecords, (item: BabyRecord, index: number) => {
            Row({ space: 0 }) {
              Column() {
                Column() {
                  Text(recordTypeIcon(item.type)).fontSize(16)
                }
                .width(36).height(36)
                .backgroundColor('#FFFFFF')
                .borderRadius(18)
                .border({ width: 2, color: this.timelineColor(item.type) })
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .shadow({ radius: 4, color: '#0F000000', offsetX: 0, offsetY: 1 })

                if (index < this.recentRecords.length - 1) {
                  Column()
                    .width(2).height(24)
                    .backgroundColor('#E8E8E8')
                    .margin({ top: 2 })
                }
              }
              .width(36).alignItems(HorizontalAlign.Center)

              Column({ space: 2 }) {
                Row() {
                  Text(this.timelineTitle(item))
                    .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#333')
                  Blank()
                  if (item.endTime === 0) {
                    // 进行中：点击展开对应横幅
                    Text('去结束 >')
                      .fontSize(12).fontColor('#FF8C69')
                      .onClick(() => {
                        if (item.type === RecordType.FEED) {
                          this.feedBannerExpanded = true
                        } else if (item.type === RecordType.SLEEP) {
                          this.sleepBannerExpanded = true
                        }
                      })
                  } else {
                    Text(formatTimeAgo(item.startTime))
                      .fontSize(12).fontColor('#bbb')
                  }
                }
                .width('100%')

                if (this.timelineDetail(item)) {
                  Text(this.timelineDetail(item))
                    .fontSize(12).fontColor(item.endTime === 0 ? '#FF8C69' : '#999')
                }
              }
              .layoutWeight(1)
              .padding({ left: 12, top: 4, bottom: 8 })
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%').alignItems(VerticalAlign.Top)
          })
        }
        .padding({ left: 4 })
      }

      // 体温记录入口
      Row() {
        Text('🌡️ 记体温')
          .fontSize(13).fontColor('#FF8C69')
          .padding({ top: 12, bottom: 4 })
          .onClick(() => { this.showTempSheet = true })
      }
      .width('100%').justifyContent(FlexAlign.Center)
    }
  }

  timelineColor(type: RecordType): string {
    if (type === RecordType.FEED) return '#FF8C69'
    if (type === RecordType.SLEEP) return '#7EC8C8'
    if (type === RecordType.TEMPERATURE) return '#FF6B6B'
    return '#FFB347'
  }

  timelineTitle(item: BabyRecord): string {
    if (item.type === RecordType.FEED) {
      return `喂奶 · ${feedTypeLabel(item.subType)}`
    } else if (item.type === RecordType.DIAPER) {
      return `换尿布 · ${diaperTypeLabel(item.subType)}`
    } else if (item.type === RecordType.TEMPERATURE) {
      return `体温 · ${formatTemp(item.amount)}`
    } else {
      return '睡眠'
    }
  }

  timelineDetail(item: BabyRecord): string {
    if (item.type === RecordType.TEMPERATURE) {
      return tempSiteLabel(item.subType)
    }
    if (item.endTime === 0) return '进行中…'
    if (item.type === RecordType.FEED || item.type === RecordType.SLEEP) {
      return formatDuration(item.endTime - item.startTime)
    }
    if (item.type === RecordType.DIAPER && item.note) {
      return item.note
    }
    return ''
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
              // 更多菜单
              Text('⋯')
                .fontSize(22).fontColor('#999').padding({ left: 8 })
                .onClick(() => { this.showMoreMenu() })
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
    .bindSheet(this.showTempSheet, this.TempSheet(), {
      height: 460,
      dragBar: true,
      backgroundColor: '#FFF8F0',
      onDisappear: () => {
        this.showTempSheet = false
        this.tempValue = 37.0
        this.tempSite = TempSite.AXILLA
      }
    })
  }
}
