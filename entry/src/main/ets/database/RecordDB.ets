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

let rdbStore: relationalStore.RdbStore | null = null

export async function initDB(context: common.UIAbilityContext): Promise<void> {
  const config: relationalStore.StoreConfig = {
    name: DB_NAME,
    securityLevel: relationalStore.SecurityLevel.S1
  }
  rdbStore = await relationalStore.getRdbStore(context, config)
  await rdbStore.executeSql(SQL_CREATE_TABLE)
}

function getStore(): relationalStore.RdbStore {
  if (!rdbStore) {
    throw new Error('DB not initialized')
  }
  return rdbStore
}

export async function insertRecord(record: Omit<BabyRecord, 'id'>): Promise<number> {
  const store = getStore()
  const valueBucket: relationalStore.ValuesBucket = {
    type: record.type,
    start_time: record.startTime,
    end_time: record.endTime,
    sub_type: record.subType,
    note: record.note,
    image_uri: record.imageUri,
    amount: record.amount
  }
  const rowId = await store.insert(TABLE_NAME, valueBucket)
  return rowId
}

export async function updateRecord(id: number, fields: Partial<BabyRecord>): Promise<void> {
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
  const cursor = await store.query(predicates, ['id', 'type', 'start_time', 'end_time', 'sub_type', 'note', 'image_uri', 'amount'])
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
  const cursor = await store.query(predicates, ['id', 'type', 'start_time', 'end_time', 'sub_type', 'note', 'image_uri', 'amount'])
  return cursorToRecords(cursor)
}

export async function getLastRecord(type: RecordType): Promise<BabyRecord | null> {
  const store = getStore()
  const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
  predicates.equalTo('type', type).orderByDesc('start_time').limitAs(1)
  const cursor = await store.query(predicates, ['id', 'type', 'start_time', 'end_time', 'sub_type', 'note', 'image_uri', 'amount'])
  const records = cursorToRecords(cursor)
  return records.length > 0 ? records[0] : null
}

export async function getTodaySummary(): Promise<{ feedCount: number, sleepMs: number, diaperCount: number }> {
  const now = new Date()
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  const store = getStore()
  const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
  predicates.greaterThanOrEqualTo('start_time', startOfDay)
  const cursor = await store.query(predicates, ['type', 'start_time', 'end_time'])
  const records: Array<{ type: string, startTime: number, endTime: number }> = []
  while (cursor.goToNextRow()) {
    records.push({
      type: cursor.getString(cursor.getColumnIndex('type')),
      startTime: cursor.getLong(cursor.getColumnIndex('start_time')),
      endTime: cursor.getLong(cursor.getColumnIndex('end_time'))
    })
  }
  cursor.close()
  let feedCount = 0
  let sleepMs = 0
  let diaperCount = 0
  for (const r of records) {
    if (r.type === RecordType.FEED) feedCount++
    else if (r.type === RecordType.DIAPER) diaperCount++
    else if (r.type === RecordType.SLEEP && r.endTime > 0) sleepMs += (r.endTime - r.startTime)
  }
  return { feedCount, sleepMs, diaperCount }
}

function cursorToRecords(cursor: relationalStore.ResultSet): BabyRecord[] {
  const records: BabyRecord[] = []
  while (cursor.goToNextRow()) {
    records.push({
      id: cursor.getLong(cursor.getColumnIndex('id')),
      type: cursor.getString(cursor.getColumnIndex('type')) as RecordType,
      startTime: cursor.getLong(cursor.getColumnIndex('start_time')),
      endTime: cursor.getLong(cursor.getColumnIndex('end_time')),
      subType: cursor.getString(cursor.getColumnIndex('sub_type')),
      note: cursor.getString(cursor.getColumnIndex('note')),
      imageUri: cursor.getString(cursor.getColumnIndex('image_uri')),
      amount: cursor.getDouble(cursor.getColumnIndex('amount'))
    })
  }
  cursor.close()
  return records
}
