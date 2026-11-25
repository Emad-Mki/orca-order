const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const headers = [
  'image_name', 'normalized_name', 'file_id', 'image_url',
  'mime_type', 'last_checked', 'status', 'modified_time',
];

function createBackend({ files = [], changes = [], scriptProperties = {}, batchSize } = {}) {
  const properties = {
    SPREADSHEET_ID: 'test-sheet',
    PRODUCT_IMAGES_FOLDER_ID: 'folder-1',
    ...scriptProperties,
  };
  if (batchSize != null) properties.IMAGE_INDEX_BATCH_SIZE = String(batchSize);
  const triggers = [];
  const driveApiCalls = [];
  let sheetWrites = 0;
  const imageSheet = {
    name: 'Product_Images',
    values: [headers.slice()],
    maxRows: 1000,
    maxColumns: 26,
    getName() { return this.name; },
    getLastRow() {
      for (let i = this.values.length - 1; i >= 0; i--) {
        if (this.values[i]?.some(value => value !== '' && value != null)) return i + 1;
      }
      return 0;
    },
    getLastColumn() {
      return Math.max(0, ...this.values.map(row => {
        let last = row?.length || 0;
        while (last && (row[last - 1] === '' || row[last - 1] == null)) last--;
        return last;
      }));
    },
    getMaxRows() { return this.maxRows; },
    getMaxColumns() { return this.maxColumns; },
    setFrozenRows() {},
    insertRowsAfter(after, count) {
      this.maxRows += count;
      this.values.splice(after, 0, ...Array.from({ length: count }, () => []));
    },
    deleteColumns(start, count) {
      for (const row of this.values) row.splice(start - 1, count);
      this.maxColumns -= count;
    },
    getRange(row, column, rowCount = 1, columnCount = 1) {
      return {
        getValues: () => Array.from({ length: rowCount }, (_, r) =>
          Array.from({ length: columnCount }, (_, c) =>
            this.values[row + r - 1]?.[column + c - 1] ?? '',
          ),
        ),
        setValues: values => {
          sheetWrites++;
          values.forEach((valueRow, r) => {
            const index = row + r - 1;
            this.values[index] ||= [];
            valueRow.forEach((value, c) => {
              this.values[index][column + c - 1] = value;
            });
          });
          this.maxRows = Math.max(this.maxRows, row + values.length - 1);
        },
        clearContent: () => {
          sheetWrites++;
          for (let r = row - 1; r < row - 1 + rowCount; r++) {
            this.values[r] ||= [];
            for (let c = column - 1; c < column - 1 + columnCount; c++) this.values[r][c] = '';
          }
        },
      };
    },
  };
  const sheets = [imageSheet];
  const spreadsheet = {
    getSheetByName: name => sheets.find(sheet => sheet.name === name) || null,
    getSheets: () => sheets,
    insertSheet: name => {
      const sheet = { ...imageSheet, name, values: [], maxRows: 1000, maxColumns: 26 };
      sheets.push(sheet);
      return sheet;
    },
  };
  let currentChanges = changes;
  const context = {
    Date, JSON, Math, Object, Array, String, Number, Error, RegExp,
    Logger: { log() {} },
    Utilities: { getUuid: (() => { let id = 0; return () => `job-${++id}`; })() },
    PropertiesService: {
      getScriptProperties: () => ({
        getProperty: key => properties[key] ?? null,
        setProperty: (key, value) => { properties[key] = value; },
        deleteProperty: key => { delete properties[key]; },
      }),
    },
    SpreadsheetApp: { openById: () => spreadsheet },
    LockService: { getScriptLock: () => ({ tryLock: () => true, releaseLock() {} }) },
    ScriptApp: {
      getOAuthToken: () => 'test-token',
      getProjectTriggers: () => triggers.slice(),
      newTrigger: handler => ({
        timeBased() { return this; },
        everyMinutes() { return this; },
        everyHours() { return this; },
        create() {
          const trigger = { getHandlerFunction: () => handler };
          triggers.push(trigger);
          return trigger;
        },
      }),
      deleteTrigger: trigger => triggers.splice(triggers.indexOf(trigger), 1),
    },
    UrlFetchApp: {
      fetch: url => {
        driveApiCalls.push(url);
        const parsed = new URL(url);
        const resource = parsed.pathname.split('/').pop();
        const pageSize = Number(parsed.searchParams.get('pageSize') || 200);
        let payload;
        if (resource === 'startPageToken') {
          payload = { startPageToken: 'changes-token-start' };
        } else if (resource === 'files') {
          const offset = Number(parsed.searchParams.get('pageToken') || 0);
          const page = files.slice(offset, offset + pageSize);
          payload = { files: page };
          if (offset + page.length < files.length) payload.nextPageToken = String(offset + page.length);
        } else if (resource === 'changes') {
          const token = parsed.searchParams.get('pageToken');
          if (token === 'expired') {
            return { getResponseCode: () => 410, getContentText: () => '{"error":"pageToken expired"}' };
          }
          payload = { changes: currentChanges, newStartPageToken: 'changes-token-next' };
          currentChanges = [];
        } else {
          throw new Error(`Unexpected Drive API resource ${resource}`);
        }
        return { getResponseCode: () => 200, getContentText: () => JSON.stringify(payload) };
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'Code.gs'), 'utf8'), context);
  return {
    context, sheets, imageSheet, triggers, properties, driveApiCalls,
    setChanges(value) { currentChanges = value; },
    get sheetWrites() { return sheetWrites; },
  };
}

function file(id, name = `${id}.png`, extra = {}) {
  return {
    id, name, mimeType: 'image/png', modifiedTime: '2026-01-01T00:00:00Z',
    parents: ['folder-1'], trashed: false, ...extra,
  };
}

function finish(context, limit = 100) {
  for (let i = 0; i < limit; i++) {
    const status = context._imageIndexJobStatus_();
    if (['completed', 'completed_with_errors', 'failed', 'cancelled'].includes(status.status)) return status;
    context.continueImageIndexJob();
  }
  throw new Error('Image index did not finish in time');
}

test('default update bootstraps the index directly in Product_Images', () => {
  const backend = createBackend({ files: [file('new-1')] });
  const started = backend.context.rebuildImageIndex();
  const result = finish(backend.context);
  assert.equal(result.status, 'completed');
  assert.equal(started.mode, 'bootstrap');
  assert.equal(result.files_added, 1);
  assert.equal(backend.sheets.length, 1);
  assert.deepEqual(backend.context._all('Product_Images').map(row => row.file_id), ['new-1']);
  assert.equal(backend.properties.PRODUCT_IMAGES_CHANGES_TOKEN, 'changes-token-next');
  assert.equal(backend.properties.PRODUCT_IMAGES_INDEXED_FOLDER_ID, 'folder-1');
  assert.equal(backend.triggers.length, 0);
});

test('full rebuild requires confirmation and replaces rows without adding sheets', () => {
  const backend = createBackend({ files: [file('replacement')] });
  backend.imageSheet.values.push(['old.png', 'old', 'old-id', 'url', 'image/png', 'date', 'active', 'modified']);
  assert.throws(() => backend.context.rebuildImageIndex({ operation: 'full' }));
  backend.context.rebuildImageIndex({ operation: 'full', confirmed: true });
  const result = finish(backend.context);
  assert.equal(result.status, 'completed');
  assert.deepEqual(backend.context._all('Product_Images').map(row => row.file_id), ['replacement']);
  assert.equal(backend.sheets.length, 1);
});

test('metadata pagination indexes 2000 images in batches', () => {
  const files = Array.from({ length: 2000 }, (_, i) =>
    file(`f-${i}`, i < 2 ? 'duplicate.png' : `part-${i}.png`));
  const backend = createBackend({ files });
  backend.context.rebuildImageIndex();
  const result = finish(backend.context);
  const rows = backend.context._all('Product_Images');
  assert.equal(result.files_scanned, 2000);
  assert.equal(result.files_indexed, 2000);
  assert.equal(rows.length, 2000);
  assert.equal(new Set(rows.map(row => row.file_id)).size, 2000);
  assert.equal(backend.driveApiCalls.filter(url => url.includes('/files?')).length, 10);
  assert.equal(backend.sheets.length, 1);
});

test('replaying a full-scan page upserts by file id instead of duplicating rows', () => {
  const backend = createBackend({ files: [file('stable')] });
  backend.context.rebuildImageIndex();
  const job = backend.context._imageIndexReadJob_();
  job.phase = 'files';
  job.page_token = '';
  backend.context._imageIndexRunFilesBatch_(job);
  assert.deepEqual(backend.context._all('Product_Images').map(row => row.file_id), ['stable']);
});

test('incremental update upserts, renames and deactivates entries by file id', () => {
  const backend = createBackend({ files: [file('existing', 'old.png'), file('gone'), file('moved')] });
  backend.context.rebuildImageIndex();
  assert.equal(finish(backend.context).status, 'completed');
  backend.setChanges([
    { fileId: 'existing', file: file('existing', 'renamed.png', { modifiedTime: '2026-02-01T00:00:00Z' }) },
    { fileId: 'gone', removed: true },
    { fileId: 'moved', file: file('moved', 'moved.png', { parents: ['elsewhere'] }) },
    { fileId: 'new', file: file('new') },
  ]);
  const result = backend.context.rebuildImageIndex();
  assert.equal(result.mode, 'update');
  assert.equal(result.status, 'completed');
  const rows = backend.context._all('Product_Images');
  assert.equal(rows.find(row => row.file_id === 'existing').image_name, 'renamed.png');
  assert.equal(rows.find(row => row.file_id === 'existing').modified_time, '2026-02-01T00:00:00Z');
  assert.equal(rows.find(row => row.file_id === 'gone').status, 'inactive');
  assert.equal(rows.find(row => row.file_id === 'moved').status, 'inactive');
  assert.equal(rows.find(row => row.file_id === 'new').status, 'active');
  assert.equal(result.files_added, 1);
  assert.equal(result.files_updated, 1);
  assert.equal(result.files_unavailable, 2);
});

test('no-change update reads no full file listing and performs no sheet writes', () => {
  const backend = createBackend({
    scriptProperties: {
      PRODUCT_IMAGES_CHANGES_TOKEN: 'changes-token-old',
      PRODUCT_IMAGES_INDEXED_FOLDER_ID: 'folder-1',
    },
  });
  const before = backend.sheetWrites;
  const result = backend.context.rebuildImageIndex();
  assert.equal(result.status, 'completed');
  assert.equal(result.files_scanned, 0);
  assert.equal(backend.sheetWrites, before);
  assert.equal(backend.driveApiCalls.filter(url => url.includes('/files?')).length, 0);
});

test('schema repair uses the active legacy columns once and removes extra columns', () => {
  const backend = createBackend({ scriptProperties: { PRODUCT_IMAGES_ACTIVE_COLUMN: '9' } });
  const sheet = backend.imageSheet;
  sheet.values[0] = headers.concat(headers);
  sheet.values[1] = ['old.png', 'old', 'old-id', 'old-url', 'image/png', 'date', 'active', 'modified']
    .concat(['new.png', 'new', 'new-id', 'new-url', 'image/png', 'new-date', 'active', 'new-modified']);
  sheet.maxColumns = 26;
  const rowsBefore = backend.context._all('Product_Images');
  assert.equal(rowsBefore[0].file_id, 'old-id');
  backend.context._imageIndexEnsureSchema_(sheet);
  assert.equal(sheet.maxColumns, headers.length);
  assert.deepEqual(backend.context._all('Product_Images').map(row => row.file_id), ['new-id']);
  assert.equal(backend.properties.PRODUCT_IMAGES_ACTIVE_COLUMN, undefined);
});

test('schema repair accepts reordered headers and ordinary reads never migrate legacy sheets', () => {
  const backend = createBackend({
    scriptProperties: { PRODUCT_IMAGES_ACTIVE_SHEET: 'missing_legacy_sheet' },
  });
  const sheet = backend.imageSheet;
  sheet.values[0] = [
    'file_id', 'image_name', 'normalized_name', 'image_url',
    'mime_type', 'last_checked', 'status', 'modified_time',
  ];
  sheet.values[1] = [
    'reordered-id', 'reordered.png', 'reordered', 'url',
    'image/png', 'date', 'active', 'modified',
  ];
  const read = backend.context._all('Product_Images');
  assert.equal(read[0].file_id, 'reordered-id');
  assert.equal(backend.properties.PRODUCT_IMAGES_ACTIVE_SHEET, 'missing_legacy_sheet');
  backend.context._imageIndexEnsureSchema_(sheet);
  assert.deepEqual(sheet.values[0], headers);
  assert.deepEqual(backend.context._all('Product_Images').map(row => row.file_id), ['reordered-id']);
});

test('expired changes token safely starts a fresh full scan', () => {
  const backend = createBackend({
    files: [file('fresh')],
    scriptProperties: {
      PRODUCT_IMAGES_CHANGES_TOKEN: 'expired',
      PRODUCT_IMAGES_INDEXED_FOLDER_ID: 'folder-1',
    },
  });
  backend.context.rebuildImageIndex();
  const result = finish(backend.context);
  assert.equal(result.status, 'completed');
  assert.equal(result.mode, 'bootstrap');
  assert.equal(result.token_restarts, 1);
  assert.deepEqual(backend.context._all('Product_Images').map(row => row.file_id), ['fresh']);
});

test('scheduled trigger is unique and can be removed independently', () => {
  const backend = createBackend();
  backend.context._imageIndexSetSchedule_(true);
  backend.context._imageIndexSetSchedule_(true);
  backend.context._imageIndexEnsureTrigger_();
  assert.deepEqual(backend.triggers.map(trigger => trigger.getHandlerFunction()).sort(),
    ['continueImageIndexJob', 'scheduledImageIndexUpdate']);
  backend.context._imageIndexSetSchedule_(false);
  assert.deepEqual(backend.triggers.map(trigger => trigger.getHandlerFunction()), ['continueImageIndexJob']);
});
