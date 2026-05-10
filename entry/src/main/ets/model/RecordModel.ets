// 记录类型
export enum RecordType {
  FEED = 'FEED',
  DIAPER = 'DIAPER',
  SLEEP = 'SLEEP',
  TEMPERATURE = 'TEMPERATURE'
}

// 喂奶方式
export enum FeedType {
  LEFT = 'LEFT',
  RIGHT = 'RIGHT',
  BOTTLE = 'BOTTLE',
  MIXED = 'MIXED'
}

// 尿布类型
export enum DiaperType {
  PEE = 'PEE',
  POO = 'POO',
  MIXED = 'MIXED'
}

// 测量部位
export enum TempSite {
  AXILLA = 'axilla',   // 腋下
  ORAL = 'oral',       // 口腔
  EAR = 'ear'          // 耳温
}

// 通用记录结构
export interface BabyRecord {
  id: number
  type: RecordType
  startTime: number
  endTime: number
  subType: string        // FeedType | DiaperType | TempSite
  note: string
  imageUri: string
  amount: number         // 体温时存体温值（℃），喂奶时存奶量（ml）
}

// 进行中活动（存 AppStorage）
export interface ActiveActivity {
  type: RecordType
  startTime: number
  subType: string
  recordId: number
}

// ── 时间格式化 ──

export function formatDuration(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000)
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  if (hours > 0) return `${hours}h${String(minutes).padStart(2, '0')}m`
  if (minutes > 0) return `${minutes}m${String(seconds).padStart(2, '0')}s`
  return `${seconds}s`
}

export function formatTimeAgo(timestamp: number): string {
  const diff = Date.now() - timestamp
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(minutes / 60)
  if (hours > 0) {
    const remainMin = minutes % 60
    return remainMin > 0 ? `${hours}h${remainMin}m前` : `${hours}h前`
  }
  if (minutes > 0) return `${minutes}m前`
  return '刚刚'
}

export function formatTime(timestamp: number): string {
  const d = new Date(timestamp)
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}

export function formatDate(timestamp: number): string {
  const d = new Date(timestamp)
  return `${d.getMonth() + 1}月${d.getDate()}日`
}

// ── Label / Icon ──

export function recordTypeLabel(type: RecordType): string {
  switch (type) {
    case RecordType.FEED: return '喂奶'
    case RecordType.DIAPER: return '换尿布'
    case RecordType.SLEEP: return '睡眠'
    case RecordType.TEMPERATURE: return '体温'
    default: return ''
  }
}

export function recordTypeIcon(type: RecordType): string {
  switch (type) {
    case RecordType.FEED: return '🍼'
    case RecordType.DIAPER: return '🧷'
    case RecordType.SLEEP: return '😴'
    case RecordType.TEMPERATURE: return '🌡️'
    default: return '📝'
  }
}

export function feedTypeLabel(subType: string): string {
  switch (subType) {
    case FeedType.LEFT: return '左乳'
    case FeedType.RIGHT: return '右乳'
    case FeedType.BOTTLE: return '奶瓶'
    case FeedType.MIXED: return '混合'
    default: return ''
  }
}

export function diaperTypeLabel(subType: string): string {
  switch (subType) {
    case DiaperType.PEE: return '💧小便'
    case DiaperType.POO: return '💩大便'
    case DiaperType.MIXED: return '💩💧混合'
    default: return ''
  }
}

export function tempSiteLabel(subType: string): string {
  switch (subType) {
    case TempSite.AXILLA: return '腋下'
    case TempSite.ORAL: return '口腔'
    case TempSite.EAR: return '耳温'
    default: return '腋下'
  }
}

// 体温颜色：正常绿 / 低烧橙 / 发烧红
export function tempColor(value: number): string {
  if (value >= 38.5) return '#FF6B6B'
  if (value >= 37.5) return '#FFB347'
  return '#7EC8C8'
}

// 体温格式化显示
export function formatTemp(value: number): string {
  return `${value.toFixed(1)}℃`
}
