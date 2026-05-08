// 记录类型
export enum RecordType {
  FEED = 'FEED',
  DIAPER = 'DIAPER',
  SLEEP = 'SLEEP'
}

// 喂奶方式
export enum FeedType {
  LEFT = 'LEFT',       // 左乳
  RIGHT = 'RIGHT',     // 右乳
  BOTTLE = 'BOTTLE',   // 奶瓶
  MIXED = 'MIXED'      // 混合
}

// 尿布类型
export enum DiaperType {
  PEE = 'PEE',         // 小便
  POO = 'POO',         // 大便
  MIXED = 'MIXED'      // 混合
}

// 通用记录结构
export interface BabyRecord {
  id: number
  type: RecordType
  startTime: number      // 时间戳 ms
  endTime: number        // 时间戳 ms（喂奶/睡眠结束时间，换尿布同 startTime）
  subType: string        // FeedType | DiaperType
  note: string           // 备注
  imageUri: string       // 图片 URI（换尿布拍照）
  amount: number         // 奶量 ml（喂奶时用）
}

// 进行中活动（存 AppStorage）
export interface ActiveActivity {
  type: RecordType
  startTime: number
  subType: string
  recordId: number       // 已写入 DB 的 id，结束时更新
}

// 时间格式化工具
export function formatDuration(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000)
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  if (hours > 0) {
    return `${hours}h${String(minutes).padStart(2, '0')}m`
  }
  if (minutes > 0) {
    return `${minutes}m${String(seconds).padStart(2, '0')}s`
  }
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
  if (minutes > 0) {
    return `${minutes}m前`
  }
  return '刚刚'
}

export function formatTime(timestamp: number): string {
  const d = new Date(timestamp)
  const h = String(d.getHours()).padStart(2, '0')
  const m = String(d.getMinutes()).padStart(2, '0')
  return `${h}:${m}`
}

export function formatDate(timestamp: number): string {
  const d = new Date(timestamp)
  return `${d.getMonth() + 1}月${d.getDate()}日`
}

export function recordTypeLabel(type: RecordType): string {
  switch (type) {
    case RecordType.FEED: return '喂奶'
    case RecordType.DIAPER: return '换尿布'
    case RecordType.SLEEP: return '睡眠'
    default: return ''
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

export function recordTypeIcon(type: RecordType): string {
  switch (type) {
    case RecordType.FEED: return '🍼'
    case RecordType.DIAPER: return '🧷'
    case RecordType.SLEEP: return '😴'
    default: return '📝'
  }
}
