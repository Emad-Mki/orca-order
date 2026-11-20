const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function createBackend({
  files = [],
  legacyFiles = files,
  changes = [],
  batchSize,
  failJobSaveAfterWrite = false,
  scriptProperties = {},
} = {}) {
  const properties = {
    SPREADSHEET_ID: 'test-sheet',
    PRODUCT_IMAGES_FOLDER_ID: 'folder-1',
    ...scriptProperties,
  };
  if (batchSize != null) properties.IMAGE_INDEX_BATCH_SIZE = String(batchSize);
  const propertyWrites = new Map();
  const triggers = [];
  const driveApiCalls = [];
  let sheetWrites = 0;
  let expiredFilePageReturned = false;
  let uuid = 0;
  let failNextProgressSave = failJobSaveAfterWrite;

  class MockRange {
    constructor(sheet, row, column, rows, columns) {
      Object.assign(this, { sheet, row, column, rows, columns });
    }

    getValues() {
      return Array.from({ length: this.rows }, (_, rowOffset) =>
        Array.from({ length: this.columns }, (_, columnOffset) =>
          this.sheet.values[this.row + rowOffset - 1]?.[this.column + columnOffset - 1] ?? '',
        ),
      );
    }

    setValues(values) {
      sheetWrites++;
      for (let rowOffset = 0; rowOffset < values.length; rowOffset++) {
        const row = this.row + rowOffset - 1;
        this.sheet.values[row] ||= [];
        for (let columnOffset = 0; columnOffset < values[rowOffset].length; columnOffset++) {
          this.sheet.values[row][this.column + columnOffset - 1] = values[rowOffset][columnOffset];
        }
      }
      this.sheet.maxRows = Math.max(this.sheet.maxRows, this.row + values.length - 1);
    }

    copyTo() {}

    clearContent() {
      for (let row = this.row - 1; row < this.row - 1 + this.rows; row++) {
        if (!this.sheet.values[row]) continue;
        for (let column = this.column - 1; column < this.column - 1 + this.columns; column++) {
          if (this.sheet.protectedRows.has(row + 1)) {
            throw new Error('Range is protected');
          }
          this.sheet.values[row][column] = '';
        }
      }
    }
  }

  class MockSheet {
    constructor(name, headers = [], rowCount = 1000, frozenRows = 0, protectedRows = []) {
      this.name = name;
      this.maxRows = rowCount;
      this.maxColumns = 26;
      this.frozenRows = frozenRows;
      this.protectedRows = new Set(protectedRows);
      this.values = [];
      this.deleteRowsCalled = false;
      if (headers.length) this.values[0] = headers.slice();
    }

    getName() { return this.name; }
    getLastRow() {
      for (let index = this.values.length - 1; index >= 0; index--) {
        if (this.values[index]?.some(value => value !== '' && value != null)) return index + 1;
      }
      return 0;
    }
    getLastColumn() {
      return Math.max(0, ...(this.values.map(row => {
        let last = row?.length || 0;
        while (last > 0 && (row[last - 1] === '' || row[last - 1] == null)) last--;
        return last;
      })));
    }
    getMaxRows() { return this.maxRows; }
    getMaxColumns() { return this.maxColumns; }
    getFrozenRows() { return this.frozenRows; }
    getDataRange() {
      return new MockRange(
        this,
        1,
        1,
        Math.max(1, this.getLastRow()),
        Math.max(1, this.getLastColumn()),
      );
    }
    getRange(row, column, rows, columns) {
      return new MockRange(this, row, column, rows, columns);
    }
    insertRowsAfter(after, count) {
      this.maxRows += count;
      this.values.splice(after, 0, ...Array.from({ length: count }, () => []));
    }
    insertColumnsAfter(_after, count) { this.maxColumns += count; }
    deleteRows() { this.deleteRowsCalled = true; throw new Error('deleteRows must not be used'); }
  }

  const legacy = new MockSheet(
    'Product_Images',
    ['image_name', 'normalized_name', 'file_id', 'image_url', 'mime_type', 'last_checked', 'status'],
    3,
    2,
    [2, 3],
  );
  legacy.values[1] = ['old.png', 'old', 'old-id', 'old-url', 'image/png', 'old-date', 'active'];
  legacy.values[2] = ['protected.png', 'protected', 'protected-id', 'old-url', 'image/png', 'old-date', 'active'];
  const sheets = [legacy, new MockSheet('Products', ['code', 'name'], 1000)];
  const spreadsheet = {
    getSheetByName(name) { return sheets.find(sheet => sheet.name === name) || null; },
    getSheets() { return sheets; },
    insertSheet(name) {
      const sheet = new MockSheet(name);
      sheets.push(sheet);
      return sheet;
    },
  };
  const fileById = new Map(legacyFiles.map(file => [file.id, file]));

  function toDriveFile(file) {
    let id = file.id;
    let name = file.name;
    let mimeType = file.mimeType;
    if (typeof file.getId === 'function') id = file.getId();
    if (typeof file.getName === 'function') name = file.getName();
    if (typeof file.getMimeType === 'function') mimeType = file.getMimeType();
    const metadata = {
      id,
      name,
      mimeType: mimeType || 'image/png',
      modifiedTime: file.modifiedTime || '2026-01-01T00:00:00.000Z',
      parents: file.parents || ['folder-1'],
      trashed: file.trashed || false,
    };
    if (file.omitParents) delete metadata.parents;
    return metadata;
  }

  const driveFiles = files.map(toDriveFile);
  const driveChanges = changes.map(change => ({
    ...change,
    file: change.file ? toDriveFile(change.file) : change.file,
  }));
  let changesReturned = false;

  function iteratorAt(index) {
    return {
      hasNext: () => index < legacyFiles.length,
      next: () => legacyFiles[index++],
      getContinuationToken: () => `token-${index}`,
    };
  }

  const context = {
    Date,
    JSON,
    Math,
    Object,
    Array,
    String,
    Number,
    Error,
    RegExp,
    Logger: { log() {} },
    Utilities: { getUuid: () => `job-${++uuid}` },
    PropertiesService: {
      getScriptProperties: () => ({
        getProperty: key => properties[key] ?? null,
        setProperty: (key, value) => {
          if (key === 'PRODUCT_IMAGES_INDEX_JOB_V2') {
            const job = JSON.parse(value);
            if (failNextProgressSave && job.files_indexed > 0) {
              failNextProgressSave = false;
              throw new Error('temporary property write failure');
            }
          }
          properties[key] = value;
          propertyWrites.set(key, (propertyWrites.get(key) || 0) + 1);
        },
      }),
    },
    SpreadsheetApp: {
      CopyPasteType: { PASTE_FORMAT: 'PASTE_FORMAT' },
      openById: () => spreadsheet,
    },
    DriveApp: {
      getFolderById: id => {
        assert.equal(id, 'folder-1');
        return { getFiles: () => iteratorAt(0) };
      },
      continueFileIterator: token => {
        const match = /^token-(\d+)$/.exec(token);
        if (!match) throw new Error('Invalid continuation token');
        return iteratorAt(Number(match[1]));
      },
      getFileById: id => fileById.get(id) || { getId: () => id, getMimeType: () => { throw new Error('File not found'); } },
    },
    LockService: {
      getScriptLock: () => ({ tryLock: () => true, releaseLock() {} }),
    },
    ScriptApp: {
      getOAuthToken: () => 'test-oauth-token',
      getProjectTriggers: () => triggers.slice(),
      newTrigger: handlerFunction => ({
        timeBased() { return this; },
        everyMinutes() { return this; },
        everyHours() { return this; },
        create() {
          const trigger = { getHandlerFunction: () => handlerFunction };
          triggers.push(trigger);
          return trigger;
        },
      }),
      deleteTrigger: trigger => {
        const index = triggers.indexOf(trigger);
        if (index >= 0) triggers.splice(index, 1);
      },
    },
    UrlFetchApp: {
      fetch: url => {
        driveApiCalls.push(url);
        const parsed = new URL(url);
        const resource = parsed.pathname.split('/').pop();
        let payload;
        if (resource === 'startPageToken') {
          payload = { startPageToken: 'changes-token-0' };
        } else if (resource === 'files') {
          if (parsed.searchParams.get('pageToken') === '10' &&
              !expiredFilePageReturned) {
            expiredFilePageReturned = true;
            return {
              getResponseCode: () => 410,
              getContentText: () => JSON.stringify({ error: 'pageToken expired' }),
            };
          }
          const offset = Number(parsed.searchParams.get('pageToken') || 0);
          const pageSize = Number(parsed.searchParams.get('pageSize') || 1000);
          const page = driveFiles.slice(offset, offset + pageSize);
          payload = { files: page };
          if (offset + page.length < driveFiles.length) {
            payload.nextPageToken = String(offset + page.length);
          }
        } else if (resource === 'changes') {
          if (parsed.searchParams.get('pageToken') === 'expired') {
            return {
              getResponseCode: () => 410,
              getContentText: () => JSON.stringify({ error: 'pageToken expired' }),
            };
          }
          payload = {
            changes: changesReturned ? [] : driveChanges,
            newStartPageToken: changesReturned ? 'changes-token-2' : 'changes-token-1',
          };
          changesReturned = true;
        } else {
          throw new Error(`Unexpected Drive API resource: ${resource}`);
        }
        return {
          getResponseCode: () => 200,
          getContentText: () => JSON.stringify(payload),
        };
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(
    fs.readFileSync(path.join(__dirname, '..', 'Code.gs'), 'utf8'),
    context,
  );
  return { context, legacy, sheets, triggers, properties, driveApiCalls, propertyWrites,
    get sheetWrites() { return sheetWrites; } };
}

function imageFile(id, name = `${id}.png`, extra = {}) {
  return {
    id,
    name,
    ...extra,
    getId() { return this.id; },
    getName() { return this.name; },
    getMimeType() { return 'image/png'; },
  };
}

function runToCompletion(context, maxRuns = 100) {
  for (let run = 0; run < maxRuns; run++) {
    context.continueImageIndexJob();
    const status = context._imageIndexJobStatus_();
    if (['completed', 'completed_with_errors', 'failed', 'cancelled'].includes(status.status)) {
      return status;
    }
  }
  throw new Error('Image index job did not finish in the test run limit');
}

test('default update bootstraps metadata without changing frozen active rows', () => {
  const backend = createBackend({ files: [imageFile('new-1')] });
  const complete = backend.context.rebuildImageIndex();
  assert.equal(complete.status, 'completed');
  assert.equal(complete.mode, 'bootstrap');
  assert.equal(complete.files_added, 1);
  assert.equal(complete.files_indexed, 1);
  assert.equal(backend.legacy.deleteRowsCalled, false);
  assert.equal(backend.legacy.values[1][2], 'old-id');
  assert.equal(backend.legacy.values[2][2], 'protected-id');
  assert.equal(backend.properties.PRODUCT_IMAGES_CHANGES_TOKEN, 'changes-token-0');
  assert.equal(backend.triggers.length, 0);
  assert.ok(backend.driveApiCalls.every(url => !url.includes('alt=media')));
});

test('two thousand images use metadata pagination, not per-file Drive requests', () => {
  const files = Array.from({ length: 2000 }, (_, index) =>
    imageFile(`file-${index}`, index < 2 ? 'duplicate.png' : `part-${index}.png`),
  );
  const backend = createBackend({ files });
  const complete = runToCompletion(
    backend.context,
    backend.context.rebuildImageIndex().status === 'completed' ? 1 : 5,
  );
  assert.equal(complete.status, 'completed');
  assert.equal(complete.files_scanned, 2000);
  assert.equal(complete.files_indexed, 2000);
  const active = backend.context._all('Product_Images');
  assert.equal(active.length, 2000);
  assert.equal(new Set(active.map(row => row.file_id)).size, 2000);
  assert.equal(active.filter(row => row.image_name === 'duplicate.png').length, 2);
  assert.equal(complete.name_conflict_count, 1);
  assert.equal(backend.driveApiCalls.filter(url => url.includes('/files?')).length, 2);
  assert.equal(backend.driveApiCalls.some(url => url.includes('/files/')), false);
  assert.equal(backend.driveApiCalls.length, 3);
  assert.equal(complete.timings.trigger_wait_ms, 0);
  assert.equal(backend.triggers.length, 0);
});

test('incremental update upserts by file id and marks moved/deleted files inactive', () => {
  const backend = createBackend({
    files: [
      imageFile('existing', 'old.png'),
      imageFile('gone', 'gone.png'),
      imageFile('moved', 'moved.png'),
      imageFile('unconfirmed', 'unconfirmed.png'),
    ],
  });
  backend.context.rebuildImageIndex();
  const activeSheet = backend.properties.PRODUCT_IMAGES_ACTIVE_SHEET;
  const sheet = backend.sheets.find(item => item.name === activeSheet);
  const existing = imageFile('existing', 'renamed.png', {
    modifiedTime: '2026-02-01T00:00:00.000Z',
  });
  backend.properties.PRODUCT_IMAGES_CHANGES_TOKEN = 'changes-token-0';
  const changesBackend = createBackend({
    changes: [
      { fileId: 'existing', file: existing },
      { fileId: 'gone', removed: true },
      { fileId: 'moved', file: imageFile('moved', 'moved.png', { parents: ['elsewhere'] }) },
      { fileId: 'unconfirmed', file: imageFile('unconfirmed', 'unconfirmed.png', { omitParents: true }) },
      { fileId: 'new', file: imageFile('new', 'new.png') },
    ],
    scriptProperties: {
      PRODUCT_IMAGES_CHANGES_TOKEN: 'changes-token-0',
      PRODUCT_IMAGES_ACTIVE_SHEET: 'Product_Images',
    },
  });
  changesBackend.sheets[0].values = sheet.values.map(row => row && row.slice());
  changesBackend.sheets[0].maxRows = sheet.maxRows;
  changesBackend.context.rebuildImageIndex();
  const result = changesBackend.context._imageIndexJobStatus_();
  const rows = changesBackend.context._all('Product_Images');
  assert.equal(result.mode, 'update');
  assert.equal(result.files_added, 1);
  assert.equal(result.files_updated, 1);
  assert.equal(result.files_unavailable, 2);
  assert.equal(result.error_count, 1);
  assert.equal(rows.find(row => row.file_id === 'existing').image_name, 'renamed.png');
  assert.equal(rows.find(row => row.file_id === 'existing').modified_time, existing.modifiedTime);
  assert.ok(rows.find(row => row.file_id === 'existing').image_url.includes('2026-02-01'));
  assert.equal(rows.find(row => row.file_id === 'gone').status, 'inactive');
  assert.equal(rows.find(row => row.file_id === 'moved').status, 'inactive');
  assert.equal(rows.find(row => row.file_id === 'unconfirmed').status, 'active');
  assert.ok(rows.some(row => row.file_id === 'new'));
});

test('no-change update reads no index rows and performs no sheet writes', () => {
  const backend = createBackend({
    scriptProperties: {
      PRODUCT_IMAGES_CHANGES_TOKEN: 'changes-token-0',
    },
  });
  const before = backend.sheetWrites;
  const result = backend.context.rebuildImageIndex();
  assert.equal(result.status, 'completed');
  assert.equal(result.files_scanned, 0);
  assert.equal(backend.sheetWrites, before);
  assert.equal(backend.driveApiCalls.filter(url => url.includes('/changes?')).length, 1);
  assert.equal(backend.triggers.length, 0);
});

test('expired Changes API token falls back to a safe metadata bootstrap', () => {
  const backend = createBackend({
    files: [imageFile('current')],
    scriptProperties: {
      PRODUCT_IMAGES_CHANGES_TOKEN: 'expired',
    },
  });
  backend.context.rebuildImageIndex();
  const result = runToCompletion(backend.context);
  assert.equal(result.status, 'completed');
  assert.equal(result.mode, 'bootstrap');
  assert.equal(result.token_restarts, 1);
  assert.equal(backend.context._all('Product_Images').length, 1);
});

test('expired file-list page token restarts the temporary scan safely', () => {
  const files = Array.from({ length: 11 }, (_, index) =>
    imageFile(`file-${index}`),
  );
  const backend = createBackend({ files, batchSize: 10 });
  const started = backend.context.rebuildImageIndex();
  assert.equal(started.status, 'continuing');
  assert.equal(started.token_restarts, 1);
  const completed = runToCompletion(backend.context);
  assert.equal(completed.status, 'completed');
  assert.equal(completed.files_indexed, 11);
  assert.equal(backend.context._all('Product_Images').length, 11);
});

test('one invalid file is reported without replacing the active index with a partial build', () => {
  const backend = createBackend({
    files: [imageFile('good'), imageFile('', 'bad.png')],
  });
  const result = backend.context.rebuildImageIndex();
  assert.equal(result.status, 'completed_with_errors');
  assert.equal(result.files_scanned, 2);
  assert.equal(result.files_indexed, 1);
  assert.equal(result.error_count, 1);
  assert.equal(backend.properties.PRODUCT_IMAGES_ACTIVE_SHEET, undefined);
  assert.equal(backend.context._all('Product_Images').length, 2);
});

test('legacy iterator job commits good rows before retrying a broken file', () => {
  const broken = {
    id: 'broken-id',
    getId() { return this.id; },
    getName() { throw new Error('permission denied'); },
    getMimeType() { return 'image/png'; },
  };
  const backend = createBackend({
    legacyFiles: [imageFile('good-id'), broken],
    failJobSaveAfterWrite: true,
  });
  backend.context._startImageIndexJob_(false);
  const complete = runToCompletion(backend.context);
  const job = backend.context._imageIndexReadJob_();
  const stage = backend.sheets.find(sheet => sheet.name === job.stage_sheet);
  assert.equal(complete.status, 'completed_with_errors');
  assert.equal(stage.values[1][2], 'good-id');
  assert.equal(backend.legacy.values[1][2], 'old-id');
  assert.equal(backend.properties.PRODUCT_IMAGES_ACTIVE_SHEET, undefined);
});

test('duplicate-name product matching reports conflict instead of choosing arbitrarily', () => {
  const backend = createBackend();
  const image = (id, name) => ({
    file_id: id,
    normalized_name: name,
    status: 'active',
  });
  const built = backend.context._buildImageIndexMaps_([
    image('a', 'same'),
    image('b', 'same'),
  ]);
  assert.equal(backend.context._findIndexedProductImage_({ code: 'same' }, built), null);
});

test('optional scheduled update trigger is unique and removable without touching continuation triggers', () => {
  const backend = createBackend();
  const enabled = backend.context._imageIndexSetSchedule_(true);
  assert.equal(enabled.scheduled_update, true);
  assert.equal(backend.triggers.length, 1);
  backend.context._imageIndexEnsureTrigger_();
  assert.equal(backend.triggers.length, 2);
  backend.context._imageIndexSetSchedule_(false);
  assert.deepEqual(
    backend.triggers.map(trigger => trigger.getHandlerFunction()),
    ['continueImageIndexJob'],
  );
});
