import router from '@ohos.router'
import {
  BabyRecord, RecordType, ActiveActivity,
  formatTime, formatDuration,
  recordTypeIcon, recordTypeLabel, feedTypeLabel, diaperTypeLabel
} from '../model/RecordModel'
import { getRecordsByDate, deleteRecord, updateRecord } from '../database/RecordDB'

interface DateGroup {
  date: string
  records: BabyRecord[]
}

@Entry
@Component
struct HistoryPage {
  @State groups: DateGroup[] = []
  @State loading: boolean = false
  @State deleteTargetId: number = -1

  aboutToAppear(): void {
    this.loadRecords()
  }

  todayStr(): string {
    const d = new Date()
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  }

  async loadRecords(): Promise<void> {
    this.loading = true
    try {
      const result: DateGroup[] = []
      for (let i = 0; i < 7; i++) {
        const d = new Date()
        d.setDate(d.getDate() - i)
        const dateStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
        const records = await getRecordsByDate(dateStr)
        if (records.length > 0 || i === 0) {
          result.push({ date: dateStr, records })
        }
      }
      this.groups = result
    } catch (e) {
      console.error('loadRecords error', JSON.stringify(e))
    } finally {
      this.loading = false
    }
  }

  formatGroupDate(dateStr: string): string {
    const today = this.todayStr()
    if (dateStr === today) return '今天'
    const d = new Date(dateStr)
    return `${d.getMonth() + 1}月${d.getDate()}日`
  }

  recordSummary(record: BabyRecord): string {
    if (record.type === RecordType.FEED) {
      const dur = record.endTime > 0 ? formatDuration(record.endTime - record.startTime) : '进行中'
      return `${feedTypeLabel(record.subType)} · ${dur}`
    } else if (record.type === RecordType.DIAPER) {
      const color = record.note ? ` · ${record.note}` : ''
      return `${diaperTypeLabel(record.subType)}${color}`
    } else if (record.type === RecordType.SLEEP) {
      return record.endTime > 0 ? formatDuration(record.endTime - record.startTime) : '进行中'
    }
    return ''
  }

  async handleDelete(id: number): Promise<void> {
    try {
      await deleteRecord(id)
      await this.loadRecords()
    } catch (e) {
      console.error('delete error', JSON.stringify(e))
    }
  }

  async handleFinish(id: number): Promise<void> {
    try {
      await updateRecord(id, { endTime: Date.now() })
      // 清掉 AppStorage，@Watch 会触发首页横幅消失
      const feedStr = AppStorage.get<string>('activeFeed')
      const sleepStr = AppStorage.get<string>('activeSleep')
      if (feedStr) {
        try {
          const act = JSON.parse(feedStr) as ActiveActivity
          if (act.recordId === id) {
            AppStorage.setOrCreate<string>('activeFeed', '')
          }
        } catch {}
      }
      if (sleepStr) {
        try {
          const act = JSON.parse(sleepStr) as ActiveActivity
          if (act.recordId === id) {
            AppStorage.setOrCreate<string>('activeSleep', '')
          }
        } catch {}
      }
      await this.loadRecords()
    } catch (e) {
      console.error('finish error', JSON.stringify(e))
    }
  }

  // swipeAction builder 必须是 @Builder 方法，不能用内联箭头函数
  @Builder
  DeleteButton(id: number) {
    Button('删除')
      .backgroundColor('#FF4444')
      .fontColor(Color.White)
      .fontSize(14)
      .height('100%')
      .width(80)
      .onClick(() => { this.handleDelete(id) })
  }

  @Builder
  RecordItem(record: BabyRecord) {
    Row({ space: 12 }) {
      Column() {
        Text(recordTypeIcon(record.type)).fontSize(24)
      }
      .width(44).height(44)
      .backgroundColor('#FFF0E8').borderRadius(22)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

      Column({ space: 2 }) {
        Text(recordTypeLabel(record.type))
          .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#333')
        Text(this.recordSummary(record))
          .fontSize(13).fontColor(record.endTime === 0 ? '#FF8C69' : '#888')
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)

      if (record.endTime === 0) {
        // 进行中的记录显示手动结束按钮
        Button('结束')
          .fontSize(12).fontColor('#FF8C69')
          .backgroundColor('#FFF0E8')
          .height(32).padding({ left: 12, right: 12 })
          .borderRadius(8)
          .onClick(() => { this.handleFinish(record.id) })
      } else {
        Text(formatTime(record.startTime))
          .fontSize(13).fontColor('#aaa')
      }
    }
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .width('100%').backgroundColor('#FFFFFF')
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(24).fontColor('#333').padding(12)
          .onClick(() => { router.back() })
        Blank()
        Text('历史记录')
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor('#333')
        Blank()
        Text('  ').padding(12)
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 8 })

      if (this.loading) {
        Column() {
          LoadingProgress().width(40).color('#FF8C69')
          Text('加载中...').fontSize(13).fontColor('#999').margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.groups, (group: DateGroup) => {
            ListItem() {
              Text(this.formatGroupDate(group.date))
                .fontSize(13).fontColor('#999').fontWeight(FontWeight.Medium)
                .padding({ left: 20, top: 16, bottom: 8 })
                .width('100%')
                .backgroundColor('#FFF8F0')
            }

            ForEach(group.records, (record: BabyRecord) => {
              ListItem() {
                this.RecordItem(record)
              }
              .swipeAction({
                end: {
                  builder: () => { this.DeleteButton(record.id) }
                }
              })
            }, (record: BabyRecord) => record.id.toString())

            ListItem() {
              Divider().color('#F0F0F0').strokeWidth(8)
            }
          }, (group: DateGroup) => group.date)
        }
        .layoutWeight(1)
        .backgroundColor('#FFF8F0')
        .divider({ strokeWidth: 1, color: '#F5F5F5', startMargin: 76, endMargin: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF8F0')
  }
}
