import router from '@ohos.router'
import vibrator from '@ohos.vibrator'
import {
  RecordType, FeedType, DiaperType, TempSite,
  BabyRecord,
  formatTime, formatDuration, formatDate,
  recordTypeLabel, recordTypeIcon,
  feedTypeLabel, diaperTypeLabel, tempSiteLabel, tempColor, formatTemp
} from '../model/RecordModel'
import {
  getRecordById, updateFullRecord, deleteRecord, insertRecord
} from '../database/RecordDB'

function doVibrate(duration: number): void {
  try {
    const effect: vibrator.VibrateTime = { type: 'time', duration: duration }
    const attr: vibrator.VibrateAttribute = { id: 0, usage: 'touch' }
    vibrator.startVibration(effect, attr)
  } catch {}
}

interface RouteParams {
  recordId: number
  isNew: boolean
  defaultType: string
}

@Entry
@Component
struct RecordDetailPage {
  @State record: BabyRecord = {
    id: 0,
    type: RecordType.FEED,
    startTime: Date.now(),
    endTime: Date.now(),
    subType: FeedType.LEFT as string,
    note: '',
    imageUri: '',
    amount: 0
  }
  @State isEditing: boolean = false
  @State isNew: boolean = false
  @State loading: boolean = true
  @State saving: boolean = false

  // 编辑中的临时值
  @State editStartDate: string = ''
  @State editStartTime: string = ''
  @State editEndDate: string = ''
  @State editEndTime: string = ''
  @State editNote: string = ''
  @State editAmount: string = ''
  @State editSubType: string = ''
  @State editTempValue: number = 37.0

  aboutToAppear(): void {
    const params = router.getParams() as RouteParams
    if (params) {
      this.isNew = params.isNew === true
      if (this.isNew) {
        // 新建模式
        const defaultType = (params.defaultType || 'FEED') as RecordType
        this.record = {
          id: 0,
          type: defaultType,
          startTime: Date.now(),
          endTime: Date.now(),
          subType: this.defaultSubType(defaultType),
          note: '',
          imageUri: '',
          amount: defaultType === RecordType.TEMPERATURE ? 37.0 : 0
        }
        this.isEditing = true
        this.loading = false
        this.initEditFields()
      } else {
        this.loadRecord(params.recordId)
      }
    }
  }

  defaultSubType(type: RecordType): string {
    if (type === RecordType.FEED) return FeedType.LEFT as string
    if (type === RecordType.DIAPER) return DiaperType.PEE as string
    if (type === RecordType.TEMPERATURE) return TempSite.AXILLA as string
    return ''
  }

  async loadRecord(id: number): Promise<void> {
    try {
      const r = await getRecordById(id)
      if (r !== null) {
        this.record = r
        this.initEditFields()
      }
    } catch {}
    this.loading = false
  }

  initEditFields(): void {
    const sd = new Date(this.record.startTime)
    this.editStartDate = `${sd.getFullYear()}-${String(sd.getMonth()+1).padStart(2,'0')}-${String(sd.getDate()).padStart(2,'0')}`
    this.editStartTime = `${String(sd.getHours()).padStart(2,'0')}:${String(sd.getMinutes()).padStart(2,'0')}`
    if (this.record.endTime > 0 && this.record.endTime !== this.record.startTime) {
      const ed = new Date(this.record.endTime)
      this.editEndDate = `${ed.getFullYear()}-${String(ed.getMonth()+1).padStart(2,'0')}-${String(ed.getDate()).padStart(2,'0')}`
      this.editEndTime = `${String(ed.getHours()).padStart(2,'0')}:${String(ed.getMinutes()).padStart(2,'0')}`
    } else {
      this.editEndDate = this.editStartDate
      this.editEndTime = this.editStartTime
    }
    this.editNote = this.record.note
    this.editAmount = this.record.amount > 0 ? this.record.amount.toString() : ''
    this.editSubType = this.record.subType
    this.editTempValue = this.record.type === RecordType.TEMPERATURE && this.record.amount > 0
      ? this.record.amount : 37.0
  }

  parseDateTime(date: string, time: string): number {
    try {
      return new Date(`${date}T${time}:00`).getTime()
    } catch {
      return Date.now()
    }
  }

  async saveRecord(): Promise<void> {
    this.saving = true
    doVibrate(50)
    try {
      const startTime = this.parseDateTime(this.editStartDate, this.editStartTime)
      const endTime = this.parseDateTime(this.editEndDate, this.editEndTime)
      const amount = this.record.type === RecordType.TEMPERATURE
        ? this.editTempValue
        : (parseFloat(this.editAmount) || 0)

      if (this.isNew) {
        await insertRecord({
          type: this.record.type,
          startTime,
          endTime,
          subType: this.editSubType,
          note: this.editNote,
          imageUri: this.record.imageUri,
          amount
        })
      } else {
        const updated: BabyRecord = {
          id: this.record.id,
          type: this.record.type,
          startTime,
          endTime,
          subType: this.editSubType,
          note: this.editNote,
          imageUri: this.record.imageUri,
          amount
        }
        await updateFullRecord(updated)
      }
      router.back()
    } catch {}
    this.saving = false
  }

  async confirmDelete(): Promise<void> {
    doVibrate(100)
    try {
      await deleteRecord(this.record.id)
      router.back()
    } catch {}
  }

  // ── 详情展示行 ──
  @Builder
  DetailRow(label: string, value: string, valueColor: string) {
    Row() {
      Text(label).fontSize(14).fontColor('#999').width(80)
      Text(value).fontSize(14).fontColor(valueColor).layoutWeight(1)
    }
    .width('100%').padding({ top: 12, bottom: 12 })
    Divider().color('#F5F5F5').strokeWidth(1)
  }

  // ── 编辑输入行 ──
  @Builder
  EditRow(label: string, value: string, placeholder: string, onChange: (v: string) => void) {
    Row() {
      Text(label).fontSize(14).fontColor('#999').width(80)
      TextInput({ text: value, placeholder: placeholder })
        .fontSize(14).fontColor('#333')
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .onChange(onChange)
    }
    .width('100%').padding({ top: 8, bottom: 8 })
    Divider().color('#F5F5F5').strokeWidth(1)
  }

  // ── 子类型选择 ──
  @Builder
  SubTypeSelector() {
    Column({ space: 8 }) {
      Text('类型').fontSize(14).fontColor('#999').width('100%')
      if (this.record.type === RecordType.FEED) {
        Row({ space: 8 }) {
          ForEach([FeedType.LEFT, FeedType.RIGHT, FeedType.BOTTLE, FeedType.MIXED], (t: FeedType) => {
            Button(feedTypeLabel(t as string))
              .onClick(() => { this.editSubType = t as string })
              .backgroundColor(this.editSubType === (t as string) ? '#FF8C69' : '#F5F5F5')
              .fontColor(this.editSubType === (t as string) ? Color.White : '#666')
              .fontSize(13).height(34).borderRadius(17).layoutWeight(1)
          })
        }
      } else if (this.record.type === RecordType.DIAPER) {
        Row({ space: 8 }) {
          ForEach([DiaperType.PEE, DiaperType.POO, DiaperType.MIXED], (t: DiaperType) => {
            Button(diaperTypeLabel(t as string))
              .onClick(() => { this.editSubType = t as string })
              .backgroundColor(this.editSubType === (t as string) ? '#FFB347' : '#F5F5F5')
              .fontColor(this.editSubType === (t as string) ? Color.White : '#666')
              .fontSize(13).height(34).borderRadius(17).layoutWeight(1)
          })
        }
      } else if (this.record.type === RecordType.TEMPERATURE) {
        Row({ space: 8 }) {
          ForEach([TempSite.AXILLA, TempSite.ORAL, TempSite.EAR], (t: TempSite) => {
            Button(tempSiteLabel(t as string))
              .onClick(() => { this.editSubType = t as string })
              .backgroundColor(this.editSubType === (t as string) ? '#FF8C69' : '#F5F5F5')
              .fontColor(this.editSubType === (t as string) ? Color.White : '#666')
              .fontSize(13).height(34).borderRadius(17).layoutWeight(1)
          })
        }
      }
    }
    .width('100%').padding({ top: 12, bottom: 12 })
    Divider().color('#F5F5F5').strokeWidth(1)
  }

  // ── 体温微调 ──
  @Builder
  TempEditor() {
    Column({ space: 12 }) {
      Text('体温').fontSize(14).fontColor('#999').width('100%')
      Row({ space: 16 }) {
        Button('-')
          .onClick(() => {
            if (this.editTempValue > 35.0) {
              this.editTempValue = Math.round((this.editTempValue - 0.1) * 10) / 10
            }
          })
          .backgroundColor('#F5F5F5').fontColor('#333')
          .fontSize(20).width(48).height(48).borderRadius(24)
        Text(formatTemp(this.editTempValue))
          .fontSize(32).fontWeight(FontWeight.Bold)
          .fontColor(tempColor(this.editTempValue))
          .width(100).textAlign(TextAlign.Center)
        Button('+')
          .onClick(() => {
            if (this.editTempValue < 42.0) {
              this.editTempValue = Math.round((this.editTempValue + 0.1) * 10) / 10
            }
          })
          .backgroundColor('#F5F5F5').fontColor('#333')
          .fontSize(20).width(48).height(48).borderRadius(24)
      }
      .justifyContent(FlexAlign.Center).width('100%')
    }
    .width('100%').padding({ top: 12, bottom: 12 })
    Divider().color('#F5F5F5').strokeWidth(1)
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('←')
          .fontSize(24).fontColor('#333').padding(12)
          .onClick(() => { router.back() })
        Blank()
        Text(this.isNew ? '手动添加' : (this.isEditing ? '编辑记录' : '记录详情'))
          .fontSize(17).fontWeight(FontWeight.Medium).fontColor('#333')
        Blank()
        if (!this.isNew && !this.isEditing) {
          Text('编辑')
            .fontSize(16).fontColor('#FF8C69').padding(12)
            .onClick(() => { this.isEditing = true })
        } else {
          Text(this.saving ? '保存中' : '保存')
            .fontSize(16).fontColor('#FF8C69').padding(12)
            .onClick(() => { if (!this.saving) this.saveRecord() })
        }
      }
      .width('100%').padding({ left: 4, right: 4, top: 8 })
      Divider().color('#F0F0F0').strokeWidth(1)

      if (this.loading) {
        Column() {
          LoadingProgress().width(40).color('#FF8C69')
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            // 类型标题
            Row({ space: 12 }) {
              Text(recordTypeIcon(this.record.type)).fontSize(32)
              Column({ space: 4 }) {
                Text(recordTypeLabel(this.record.type))
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333')
                Text(formatDate(this.record.startTime))
                  .fontSize(13).fontColor('#999')
              }
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%').padding({ top: 20, bottom: 20, left: 4 })

            Divider().color('#F0F0F0').strokeWidth(8).margin({ bottom: 8 })

            if (this.isEditing) {
              // ── 编辑模式 ──
              Column({ space: 0 }) {
                // 子类型
                if (this.record.type !== RecordType.SLEEP) {
                  this.SubTypeSelector()
                }

                // 体温专属
                if (this.record.type === RecordType.TEMPERATURE) {
                  this.TempEditor()
                }

                // 开始时间
                this.EditRow('开始日期', this.editStartDate, 'YYYY-MM-DD', (v) => { this.editStartDate = v })
                this.EditRow('开始时间', this.editStartTime, 'HH:MM', (v) => { this.editStartTime = v })

                // 结束时间（喂奶/睡眠才有）
                if (this.record.type === RecordType.FEED || this.record.type === RecordType.SLEEP) {
                  this.EditRow('结束日期', this.editEndDate, 'YYYY-MM-DD', (v) => { this.editEndDate = v })
                  this.EditRow('结束时间', this.editEndTime, 'HH:MM', (v) => { this.editEndTime = v })
                }

                // 备注
                this.EditRow('备注', this.editNote, '添加备注...', (v) => { this.editNote = v })

                // 奶量（喂奶专属）
                if (this.record.type === RecordType.FEED) {
                  this.EditRow('奶量(ml)', this.editAmount, '可不填', (v) => { this.editAmount = v })
                }
              }
              .width('100%').padding({ left: 20, right: 20 })
            } else {
              // ── 查看模式 ──
              Column({ space: 0 }) {
                this.DetailRow('开始时间', formatTime(this.record.startTime), '#333')
                if (this.record.type === RecordType.FEED || this.record.type === RecordType.SLEEP) {
                  if (this.record.endTime > 0 && this.record.endTime !== this.record.startTime) {
                    this.DetailRow('结束时间', formatTime(this.record.endTime), '#333')
                    this.DetailRow('时长', formatDuration(this.record.endTime - this.record.startTime), '#FF8C69')
                  } else {
                    this.DetailRow('状态', '进行中', '#FF8C69')
                  }
                }
                if (this.record.type === RecordType.FEED) {
                  this.DetailRow('方式', feedTypeLabel(this.record.subType), '#333')
                  if (this.record.amount > 0) {
                    this.DetailRow('奶量', `${this.record.amount}ml`, '#333')
                  }
                } else if (this.record.type === RecordType.DIAPER) {
                  this.DetailRow('类型', diaperTypeLabel(this.record.subType), '#333')
                } else if (this.record.type === RecordType.TEMPERATURE) {
                  this.DetailRow('体温', formatTemp(this.record.amount), tempColor(this.record.amount))
                  this.DetailRow('部位', tempSiteLabel(this.record.subType), '#333')
                }
                if (this.record.note) {
                  this.DetailRow('备注', this.record.note, '#666')
                }
              }
              .width('100%').padding({ left: 20, right: 20 })
            }

            Blank().height(40)

            // 删除按钮（非新建模式）
            if (!this.isNew) {
              Button('删除这条记录')
                .onClick(() => { this.confirmDelete() })
                .backgroundColor('#FFF0F0').fontColor('#FF4444')
                .fontSize(15).height(48)
                .width('calc(100% - 40vp)')
                .borderRadius(12)
                .margin({ bottom: 40 })
            }
          }
          .width('100%')
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor('#FFF8F0')
  }
}
