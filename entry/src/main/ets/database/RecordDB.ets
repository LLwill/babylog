import relationalStore from '@ohos.data.relationalStore'
import { BabyRecord, RecordType } from '../model/RecordModel'
import common from '@ohos.app.ability.common'

const DB_NAME = 'babylog.db'
const TABLE_NAME = 'baby_records'

const SQL_CREATE_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    type        TEXT    NOT NULL,
    start_time  INTEGER NOT NULL,
    end_time    INTEGER NOT NULL DEFAULT 0,
    sub_type    TEXT    NOT NULL DEFAULT '',
    note        TEXT    NOT NULL DEFAULT '',
    image_uri   TEXT    NOT NULL DEFAULT '',
    amount      REAL    NOT NULL DEFAULT 0
  )
`

export interface NewRecord {
  type: RecordType
  startTime: number
  endTime: number
  subType: string
  note: string
  imageUri: string
  amount: number
}

export interface UpdateFields {
  endTime?: number
  note?: string
  amount?: number
  imageUri?: string
}

export interface TodaySummary {
  feedCount: number
  sleepMs: number
  diaperCount: number
}

interface CursorRow {
  type: string
  startTime: number
  endTime: number
}

interface OrphanRow {
  id: number
  type: string
  startTime: number
}

let rdbStore: relationalStore.RdbStore | null = null

export async function initDB(context: common.UIAbilityContext): Promise<void> {
  const config: relationalStore.StoreConfig = {
    name: DB_NAME,
    securityLevel: relationalStore.SecurityLevel.S1
  }
  rdbStore = await relationalStore.getRdbStore(context, config)
  await rdbStore.executeSql(SQL_CREATE_TABLE)
}

/**
 * 修复孤儿记录：
 * - 喂奶：超过 1 小时未结束，用 startTime + 1h 封底
 * - 睡眠：不强制结束，由 EntryAbility 恢复到 AppStorage
 */
export async function fixOrphanRecords(activeIds: number[]): Promise<void> {
  const store = getStore()
  const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
  predicates.equalTo('end_time', 0)
  const cursor = await store.query(predicates, ['id', 'type', 'start_time'])
  const MAX_FEED_MS = 60 * 60 * 1000

  const orphans: OrphanRow[] = []
  while (cursor.goToNextRow()) {
    const row: OrphanRow = {
      id: cursor.getLong(cursor.getColumnIndex('id')),
      type: cursor.getString(cursor.getColumnIndex('type')),
      startTime: cursor.getLong(cursor.getColumnIndex('start_time'))
    }
    orphans.push(row)
  }
  cursor.close()

  for (const row of orphans) {
    if (activeIds.includes(row.id)) continue
    if (row.type === 'FEED') {
      const fix: relationalStore.ValuesBucket = { 'end_time': row.startTime + MAX_FEED_MS }
      const p = new relationalStore.RdbPredicates(TABLE_NAME)
      p.equalTo('id', row.id)
      await store.update(fix, p)
    }
    // SLEEP 不处理，由 EntryAbility.getOrphanSleep 恢复
  }
}

/**
 * 查询进行中的睡眠记录，用于手机重启后恢复 AppStorage
 */
export async function getOrphanSleep(): Promise<BabyRecord | null> {
  const store = getStore()
  const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
  predicates.equalTo('type', 'SLEEP').equalTo('end_time', 0).orderByDesc('start_time').limitAs(1)
  const cursor = await store.query(predicates,
    ['id', 'type', 'start_time', 'end_time', 'sub_type', 'note', 'image_uri', 'amount'])
  const records = cursorToRecords(cursor)
  return records.length > 0 ? records[0] : null
}

function getStore(): relationalStore.RdbStore {
  if (!rdbStore) {
    throw new Error('DB not initialized')
  }
  return rdbStore
}

export async function insertRecord(record: NewRecord): Promise<number> {
  const store = getStore()
  const valueBucket: relationalStore.ValuesBucket = {
    'type': record.type as string,
    'start_time': record.startTime,
    'end_time': record.endTime,
    'sub_type': record.subType,
    'note': record.note,
    'image_uri': record.imageUri,
    'amount': record.amount
  }
  return await store.insert(TABLE_NAME, valueBucket)
}

export async function updateRecord(id: number, fields: UpdateFields): Promise<void> {
  const store = getStore()
  const valueBucket: relationalStore.ValuesBucket = {}
  if (fields.endTime !== undefined) valueBucket['end_time'] = fields.endTime
  if (fields.note !== undefined) valueBucket['note'] = fields.note
  if (fields.amount !== undefined) valueBucket['amount'] = fields.amount
  if (fields.imageUri !== undefined) valueBucket['image_uri'] = fields.imageUri
  const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
  predicates.equalTo('id', id)
  await store.update(valueBucket, predicates)
}

export async function deleteRecord(id: number): Promise<void> {
  const store = getStore()
  const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
  predicates.equalTo('id', id)
  await store.delete(predicates)
}

export async function getRecentRecords(limit: number): Promise<BabyRecord[]> {
  const store = getStore()
  const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
  predicates.orderByDesc('start_time').limitAs(limit)
  const cursor = await store.query(predicates,
    ['id', 'type', 'start_time', 'end_time', 'sub_type', 'note', 'image_uri', 'amount'])
  return cursorToRecords(cursor)
}

export async function getRecordsByDate(dateStr: string): Promise<BabyRecord[]> {
  const store = getStore()
  const d = new Date(dateStr)
  const startOfDay = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
  const endOfDay = startOfDay + 86400000
  const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
  predicates.greaterThanOrEqualTo('start_time', startOfDay)
    .and()
    .lessThan('start_time', endOfDay)
    .orderByDesc('start_time')
  const cursor = await store.query(predicates,
    ['id', 'type', 'start_time', 'end_time', 'sub_type', 'note', 'image_uri', 'amount'])
  return cursorToRecords(cursor)
}

export async function getLastCompletedRecord(type: RecordType): Promise<BabyRecord | null> {
  const store = getStore()
  const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
  predicates.equalTo('type', type as string)
    .greaterThan('end_time', 0)
    .orderByDesc('end_time')
    .limitAs(1)
  const cursor = await store.query(predicates,
    ['id', 'type', 'start_time', 'end_time', 'sub_type', 'note', 'image_uri', 'amount'])
  const records = cursorToRecords(cursor)
  return records.length > 0 ? records[0] : null
}


  const store = getStore()
  const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
  predicates.equalTo('type', type as string).orderByDesc('start_time').limitAs(1)
  const cursor = await store.query(predicates,
    ['id', 'type', 'start_time', 'end_time', 'sub_type', 'note', 'image_uri', 'amount'])
  const records = cursorToRecords(cursor)
  return records.length > 0 ? records[0] : null
}

export async function getTodaySummary(): Promise<TodaySummary> {
  const now = new Date()
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  const store = getStore()
  const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
  predicates.greaterThanOrEqualTo('start_time', startOfDay)
  const cursor = await store.query(predicates, ['type', 'start_time', 'end_time'])
  const rows: CursorRow[] = []
  while (cursor.goToNextRow()) {
    const row: CursorRow = {
      type: cursor.getString(cursor.getColumnIndex('type')),
      startTime: cursor.getLong(cursor.getColumnIndex('start_time')),
      endTime: cursor.getLong(cursor.getColumnIndex('end_time'))
    }
    rows.push(row)
  }
  cursor.close()
  let feedCount = 0
  let sleepMs = 0
  let diaperCount = 0
  for (const r of rows) {
    if (r.type === RecordType.FEED as string) {
      feedCount++
    } else if (r.type === RecordType.DIAPER as string) {
      diaperCount++
    } else if (r.type === RecordType.SLEEP as string) {
      if (r.endTime > 0) {
        sleepMs += (r.endTime - r.startTime)
      } else {
        // 进行中的睡眠也计入今日时长
        sleepMs += (Date.now() - r.startTime)
      }
    }
  }
  return { feedCount, sleepMs, diaperCount }
}

function cursorToRecords(cursor: relationalStore.ResultSet): BabyRecord[] {
  const records: BabyRecord[] = []
  while (cursor.goToNextRow()) {
    const record: BabyRecord = {
      id: cursor.getLong(cursor.getColumnIndex('id')),
      type: cursor.getString(cursor.getColumnIndex('type')) as RecordType,
      startTime: cursor.getLong(cursor.getColumnIndex('start_time')),
      endTime: cursor.getLong(cursor.getColumnIndex('end_time')),
      subType: cursor.getString(cursor.getColumnIndex('sub_type')),
      note: cursor.getString(cursor.getColumnIndex('note')),
      imageUri: cursor.getString(cursor.getColumnIndex('image_uri')),
      amount: cursor.getDouble(cursor.getColumnIndex('amount'))
    }
    records.push(record)
  }
  cursor.close()
  return records
}
