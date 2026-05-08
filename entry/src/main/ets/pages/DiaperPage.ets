import router from '@ohos.router'
import vibrator from '@ohos.vibrator'
import picker from '@ohos.file.picker'
import { RecordType, DiaperType } from '../model/RecordModel'
import { insertRecord } from '../database/RecordDB'

@Entry
@Component
struct DiaperPage {
  @State selectedType: DiaperType | null = null
  @State selectedColor: string = ''
  @State imageUri: string = ''
  @State saving: boolean = false

  private colorOptions: string[] = ['黄色', '绿色', '黑色', '其他']

  async vibrate(duration: number): Promise<void> {
    try {
      vibrator.startVibration({ type: 'time', duration: duration }, { id: 0, usage: 'touch' })
    } catch (_) {}
  }

  async pickPhoto(): Promise<void> {
    try {
      const photoPicker = new picker.PhotoViewPicker()
      const result = await photoPicker.select({
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      })
      if (result.photoUris.length > 0) {
        this.imageUri = result.photoUris[0]
      }
    } catch (e) {
      console.error('pickPhoto error', JSON.stringify(e))
    }
  }

  async saveAndBack(): Promise<void> {
    if (!this.selectedType || this.saving) return
    this.saving = true
    try {
      await this.vibrate(80)
      const now = Date.now()
      await insertRecord({
        type: RecordType.DIAPER,
        startTime: now,
        endTime: now,
        subType: this.selectedType,
        note: this.selectedColor,
        imageUri: this.imageUri,
        amount: 0
      })
      router.back()
    } catch (e) {
      console.error('saveAndBack error', JSON.stringify(e))
      this.saving = false
    }
  }

  @Builder
  TypeButton(emoji: string, label: string, type: DiaperType, color: string) {
    Column({ space: 8 }) {
      Text(emoji).fontSize(40)
      Text(label).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#333')
    }
    .width('100%')
    .height(110)
    .backgroundColor(this.selectedType === type ? color : '#FFFFFF')
    .borderRadius(20)
    .justifyContent(FlexAlign.Center)
    .shadow({ radius: 8, color: '#0F000000', offsetX: 0, offsetY: 2 })
    .border(this.selectedType === type ? { width: 2, color: color } : { width: 0, color: Color.Transparent })
    .onClick(async () => {
      await this.vibrate(50)
      this.selectedType = type
    })
    .animation({ duration: 200 })
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor('#333')
          .padding(12)
          .onClick(() => { router.back() })
        Blank()
        Text('换尿布')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333')
        Blank()
        Text('  ').padding(12)
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 8 })

      Scroll() {
        Column({ space: 20 }) {
          // 说明文字
          Text('选择类型')
            .fontSize(15)
            .fontColor('#999')
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })

          // 三大类型按钮
          Grid() {
            GridItem() {
              this.TypeButton('💧', '小便', DiaperType.PEE, '#E8F4FD')
            }
            GridItem() {
              this.TypeButton('💩', '大便', DiaperType.POO, '#FFF3E0')
            }
            GridItem() {
              Column({ space: 8 }) {
                Text('💩💧').fontSize(40)
                Text('混合').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#333')
              }
              .width('100%')
              .height(110)
              .backgroundColor(this.selectedType === DiaperType.MIXED ? '#F3E5F5' : '#FFFFFF')
              .borderRadius(20)
              .justifyContent(FlexAlign.Center)
              .shadow({ radius: 8, color: '#0F000000', offsetX: 0, offsetY: 2 })
              .border(this.selectedType === DiaperType.MIXED ? { width: 2, color: '#CE93D8' } : { width: 0, color: Color.Transparent })
              .onClick(async () => {
                await this.vibrate(50)
                this.selectedType = DiaperType.MIXED
              })
              .animation({ duration: 200 })
            }
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(12)
          .width('100%')
          .height(110)

          // 颜色快选（选完类型后显示）
          if (this.selectedType !== null) {
            Column({ space: 10 }) {
              Text('颜色备注（可跳过）')
                .fontSize(13)
                .fontColor('#999')
                .width('100%')
              Row({ space: 10 }) {
                ForEach(this.colorOptions, (color: string) => {
                  Text(color)
                    .fontSize(14)
                    .fontColor(this.selectedColor === color ? Color.White : '#666')
                    .backgroundColor(this.selectedColor === color ? '#FF8C69' : '#F0F0F0')
                    .borderRadius(20)
                    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                    .onClick(() => {
                      this.selectedColor = this.selectedColor === color ? '' : color
                    })
                    .animation({ duration: 150 })
                })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)

            // 拍照区域
            Column({ space: 10 }) {
              if (this.imageUri) {
                Stack() {
                  Image(this.imageUri)
                    .width('100%')
                    .height(140)
                    .borderRadius(12)
                    .objectFit(ImageFit.Cover)
                  Text('重新拍照')
                    .fontSize(13)
                    .fontColor(Color.White)
                    .backgroundColor('#80000000')
                    .borderRadius(8)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .position({ x: '50%', y: '50%' })
                    .translate({ x: '-50%', y: '-50%' })
                }
                .onClick(() => { this.pickPhoto() })
              } else {
                Row({ space: 8 }) {
                  Text('📷').fontSize(20)
                  Text('拍照记录（可跳过）').fontSize(14).fontColor('#999')
                }
                .width('100%')
                .height(80)
                .backgroundColor('#F5F5F5')
                .borderRadius(12)
                .justifyContent(FlexAlign.Center)
                .onClick(() => { this.pickPhoto() })
              }
            }
            .width('100%')

            // 保存按钮
            Button(this.saving ? '保存中...' : '✅ 保存记录')
              .onClick(() => { this.saveAndBack() })
              .enabled(!this.saving)
              .backgroundColor('#FF8C69')
              .fontColor(Color.White)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .height(56)
              .width('100%')
              .borderRadius(16)
              .margin({ bottom: 40 })
          }
        }
        .padding({ left: 20, right: 20, bottom: 20 })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF8F0')
  }
}
