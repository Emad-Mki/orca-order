const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function fixture() {
  const sheets = {};
  let uuid = 0;
  let locked = false;
  let lockBusy = false;
  let lockCalls = 0;
  const props = {
    SPREADSHEET_ID: 'test',
    getProperty(k) { return this[k] || null; },
    setProperty(k, v) { this[k] = v; },
  };
  class Sheet {
    constructor(rows = []) { this.rows = rows.map(row => [...row]); }
    getLastRow() { return this.rows.length; }
    getLastColumn() { return this.rows[0] ? this.rows[0].length : 0; }
    setFrozenRows() {}
    appendRow(row) { this.rows.push([...row]); }
    deleteRow(row) { this.rows.splice(row - 1, 1); }
    getDataRange() { return { getValues: () => this.rows.map(row => [...row]) }; }
    getRange(r, c, height = 1, width = 1) {
      return {
        getValues: () => Array.from({ length: height }, (_, i) =>
          Array.from({ length: width }, (_, j) => (this.rows[r - 1 + i] || [])[c - 1 + j] ?? '')),
        setValue: value => {
          while (this.rows.length < r) this.rows.push([]);
          this.rows[r - 1][c - 1] = value;
        },
        setValues: values => {
          for (let i = 0; i < height; i++) {
            while (this.rows.length < r + i) this.rows.push([]);
            for (let j = 0; j < width; j++) {
              const value = values[i][j];
              this.rows[r - 1 + i][c - 1 + j] =
                typeof value === 'string' && value.startsWith("'") ? value.slice(1) : value;
            }
          }
        },
      };
    }
  }
  const ss = {
    getSheetByName: name => sheets[name] || null,
    insertSheet: name => (sheets[name] = new Sheet()),
  };
  const context = {
    Date, JSON, Math, Object, Array, String, Number, Error, SyntaxError,
    Logger: { log() {} },
    Utilities: {
      getUuid: () => String(++uuid),
      formatDate: d => d.toISOString().slice(2, 10).replace(/-/g, ''),
    },
    Session: { getScriptTimeZone: () => 'UTC' },
    PropertiesService: { getScriptProperties: () => props },
    SpreadsheetApp: { openById: () => ss, flush() {} },
    LockService: { getScriptLock: () => ({
      tryLock() { lockCalls++; if (lockBusy || locked) return false; locked = true; return true; },
      releaseLock() { assert.equal(locked, true); locked = false; },
    }) },
    ContentService: {
      MimeType: { JSON: 'json' },
      createTextOutput: content => ({ content, setMimeType() { return this; } }),
    },
  };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'Code.gs'), 'utf8'), context);
  context.setupSystem();
  context._sendNotificationToRoles = () => {};
  context._sendNotification = () => {};
  const insert = (name, obj) => context._add(name, obj);
  insert('Products', { code: 'P1', name: 'Test', unit_1: 'piece', unit_2: 'box',
    factor_2: 10, display_price: 100, price_2: 900, currency: 'USD', quantity: 42 });
  insert('Customers', { customer_id: 'C1', full_name: 'Customer' });
  for (const role of ['admin', 'manager', 'accountant', 'customer', 'warehouse', 'salesperson']) {
    insert('Users', { user_id: role, username: role, role, status: 'active', customer_id: 'C1' });
    insert('Sessions', { token: role, user_id: role, expires_at: new Date(Date.now() + 3600000).toISOString() });
  }
  const call = (action, data = {}, role = 'admin') => JSON.parse(context.doPost({
    postData: { contents: JSON.stringify({ action, token: role, ...data }) },
  }).content);
  const offer = (overrides = {}) => ({
    product_code: 'P1', title: 'Sale', unit: 'piece', currency: 'USD',
    old_price: 100, offer_price: 75, min_quantity: 2,
    starts_at: new Date(Date.now() - 60000).toISOString(),
    ends_at: new Date(Date.now() + 3600000).toISOString(),
    enabled: true, sort_order: 0, ...overrides,
  });
  return { context, sheets, call, offer, props,
    setBusy: value => { lockBusy = value; }, get lockCalls() { return lockCalls; } };
}

test('setup migration, authentication, role visibility and archive semantics', () => {
  const f = fixture();
  assert.ok(f.sheets.Offers.rows[0].includes('archived_at'));
  assert.ok(f.sheets.Order_Items.rows[0].includes('offer_revision'));
  assert.equal(f.call('offer_list', {}, '').error.code, 'AUTH_REQUIRED');
  for (const role of ['customer', 'warehouse', 'salesperson']) {
    assert.equal(f.call('offer_list', { manage: true }, role).error.code, 'FORBIDDEN');
    assert.equal(f.call('offer_save', { offer: f.offer() }, role).error.code, 'FORBIDDEN');
    assert.equal(f.call('offer_archive', { offer_id: 'x', revision: 1 }, role).error.code, 'FORBIDDEN');
  }
  for (const role of ['manager', 'accountant']) {
    assert.equal(f.call('offer_list', { manage: 'true' }, role).ok, true);
  }
  const created = f.call('offer_save', { offer: f.offer({ enabled: 'false' }) }).offer;
  assert.equal(created.enabled, false);
  assert.equal(created.status, 'disabled');
  assert.equal(f.call('offer_list', {}, 'customer').offers.length, 0);
  const updated = f.call('offer_save', { offer: {
    offer_id: created.offer_id, revision: 1, enabled: 'true',
  } }, 'manager').offer;
  assert.equal(updated.revision, 2);
  assert.equal(updated.created_by, 'admin');
  assert.equal(updated.updated_by, 'manager');
  const customer = f.call('offer_list', {}, 'customer');
  assert.equal(customer.offers[0].offer_price, 75);
  assert.ok(customer.server_time.endsWith('Z'));
  const warehouseOffer = f.call('offer_list', {}, 'warehouse').offers[0];
  assert.equal('offer_price' in warehouseOffer, false);
  assert.equal('old_price' in warehouseOffer, false);
  assert.equal('quantity' in warehouseOffer, false);
  assert.equal(f.call('offer_archive', { offer_id: created.offer_id, revision: 1 }).error.code, 'OFFER_CHANGED');
  const archived = f.call('offer_archive', { offer_id: created.offer_id, revision: 2 }, 'accountant').offer;
  assert.equal(archived.status, 'archived');
  assert.equal(archived.revision, 3);
  assert.equal(archived.archived_by, 'accountant');
  assert.equal(f.call('offer_list', {}, 'customer').offers.length, 0);
  assert.equal(f.call('offer_list', { manage: true }).offers[0].status, 'archived');
  assert.equal(f.call('offer_save', { offer: { offer_id: created.offer_id, revision: 3 } }).error.code, 'OFFER_ARCHIVED');
  const audits = f.context._all('Audit_Log').filter(row => row.entity === 'Offers');
  assert.deepEqual(Array.from(audits, row => row.action), ['OFFER_CREATE', 'OFFER_ENABLE', 'OFFER_ARCHIVE']);
  const enabledAudit = JSON.parse(audits[1].details);
  assert.equal(enabledAudit.before.enabled, false);
  assert.equal(enabledAudit.after.enabled, true);
  assert.equal(audits[1].user_id, 'manager');
  assert.ok(audits[1].created_at.endsWith('Z'));
  const archivedAudit = JSON.parse(audits[2].details);
  assert.equal(archivedAudit.before.revision, 2);
  assert.equal(archivedAudit.after.status, 'archived');
});

test('audit schema is required before any management write', () => {
  const f = fixture();
  const headers = f.sheets.Audit_Log.rows[0];
  headers.splice(headers.indexOf('details'), 1);
  const result = f.call('offer_save', { offer: f.offer() });
  assert.equal(result.error.code, 'SCHEMA_NOT_READY');
  assert.equal(f.sheets.Offers.rows.length, 1);
});

test('audit write failure prevents offer creation or mutation', () => {
  const f = fixture();
  const created = f.call('offer_save', { offer: f.offer() }).offer;
  const before = JSON.stringify(f.sheets.Offers.rows);
  f.sheets.Audit_Log.appendRow = () => { throw new Error('audit unavailable'); };
  assert.equal(f.call('offer_archive', { offer_id: created.offer_id, revision: 1 }).ok, false);
  assert.equal(JSON.stringify(f.sheets.Offers.rows), before);
  assert.equal(f.call('offer_save', { offer: { offer_id: created.offer_id, revision: 1, title: 'X' } }).ok, false);
  assert.equal(JSON.stringify(f.sheets.Offers.rows), before);
});

test('ordinary edits and deactivation retain full before and after audit snapshots', () => {
  const f = fixture();
  const created = f.call('offer_save', { offer: f.offer() }).offer;
  assert.equal(f.call('offer_save', { offer: {
    offer_id: created.offer_id, revision: 1, title: 'Revised',
  } }).ok, true);
  assert.equal(f.call('offer_save', { offer: {
    offer_id: created.offer_id, revision: 2, enabled: false,
  } }).ok, true);
  const events = f.context._all('Audit_Log');
  assert.equal(events[1].action, 'OFFER_UPDATE');
  assert.equal(JSON.parse(events[1].details).before.title, 'Sale');
  assert.equal(JSON.parse(events[1].details).after.title, 'Revised');
  assert.equal(events[2].action, 'OFFER_DISABLE');
  assert.equal(JSON.parse(events[2].details).after.enabled, false);
});

test('offer validation, strict dates, overlap, lock and product preservation', () => {
  const f = fixture();
  const products = JSON.stringify(f.sheets.Products.rows);
  const invalid = [
    { product_code: 'missing' }, { unit: 'unknown' }, { currency: 'EUR' },
    { currency: 'SYP' }, { old_price: 0 }, { old_price: 101 }, { offer_price: 100 },
    { min_quantity: 0 }, { enabled: 'nonsense' }, { starts_at: '2025-01-01T10:00:00' },
    { starts_at: '2025-02-30T10:00:00Z' }, { starts_at: '2025-01-01T10:00:00+14:30' },
    { starts_at: '2025-01-01T10:00:00Z', ends_at: '2025-01-01T10:00:00Z' },
  ];
  for (const overrides of invalid) {
    assert.equal(f.call('offer_save', { offer: f.offer(overrides) }).ok, false, JSON.stringify(overrides));
  }
  assert.equal(f.sheets.Offers.rows.length, 1);
  f.setBusy(true);
  assert.equal(f.call('offer_save', { offer: f.offer() }).error.code, 'BUSY');
  f.setBusy(false);
  const first = f.call('offer_save', { offer: f.offer({
    starts_at: '2030-01-01T12:00:00+03:00', ends_at: '2030-01-01T13:00:00+03:00',
  }) }).offer;
  assert.equal(first.starts_at, '2030-01-01T09:00:00.000Z');
  assert.equal(first.status, 'scheduled');
  assert.equal(f.call('offer_save', { offer: f.offer({
    starts_at: '2030-01-01T09:59:59Z', ends_at: '2030-01-01T11:00:00Z',
  }) }).error.code, 'OFFER_OVERLAP');
  assert.equal(f.call('offer_save', { offer: f.offer({
    starts_at: '2030-01-01T10:00:00Z', ends_at: '2030-01-01T11:00:00Z',
  }) }).ok, true);
  assert.equal(f.call('offer_save', { offer: f.offer({
    starts_at: '2030-01-01T09:30:00Z', ends_at: '2030-01-01T09:45:00Z', enabled: false,
  }) }).ok, true);
  const disabled = f.call('offer_list', { manage: true }).offers.find(o => !o.enabled);
  assert.equal(f.call('offer_save', { offer: {
    offer_id: disabled.offer_id, revision: disabled.revision, enabled: true,
  } }).error.code, 'OFFER_OVERLAP');
  assert.equal(JSON.stringify(f.sheets.Products.rows), products);
  assert.ok(f.lockCalls > 0);
});

test('time boundaries are start-inclusive and end-exclusive', () => {
  const f = fixture();
  const offer = f.offer({ starts_at: '2030-01-01T00:00:00Z', ends_at: '2030-01-01T01:00:00Z' });
  assert.equal(f.context._offerStatus_(offer, Date.parse('2029-12-31T23:59:59Z')), 'scheduled');
  assert.equal(f.context._offerStatus_(offer, Date.parse('2030-01-01T00:00:00Z')), 'active');
  assert.equal(f.context._offerStatus_(offer, Date.parse('2030-01-01T01:00:00Z')), 'expired');
});

test('changed product prices hide misleading offers and invalidate new claims', () => {
  const f = fixture();
  const saved = f.call('offer_save', { offer: f.offer() }).offer;
  assert.equal(f.call('offer_list', {}, 'customer').offers.length, 1);
  f.setBusy(true);
  assert.equal(f.call('product_price_update', { code: 'P1', display_price: 90 }).error.code, 'BUSY');
  f.setBusy(false);
  assert.equal(f.call('product_price_update', { code: 'P1', display_price: 90 }).ok, true);
  assert.equal(f.call('offer_list', {}, 'customer').offers.length, 0);
  assert.equal(f.call('offer_list', { manage: true }).offers.length, 1);
  const res = f.call('order_create', {
    client_request_id: 'changed-price',
    items: [{ code: 'P1', unit: 'piece', quantity: 2,
      offer_id: saved.offer_id, offer_revision: 1, offer_price: 75 }],
  }, 'customer');
  assert.equal(res.error.code, 'OFFER_CHANGED');
  assert.equal(f.sheets.Orders.rows.length, 1);
  assert.equal(f.call('offer_save', { offer: {
    offer_id: saved.offer_id, revision: 1, title: 'still stale',
  } }).error.code, 'INVALID_OFFER');
});

test('claimed offers validate before any writes, snapshot authoritative data, and retry idempotently', () => {
  const f = fixture();
  const saved = f.call('offer_save', { offer: f.offer() }).offer;
  const line = { code: 'P1', unit: 'piece', quantity: 2,
    offer_id: saved.offer_id, offer_revision: saved.revision, offer_price: 75 };
  const order = (item, request = 'req1') => ({
    client_request_id: request, currency: 'USD', items: [item],
  });
  const checks = [
    { ...line, offer_id: 'not-found' }, { ...line, offer_revision: 2 },
    { ...line, offer_price: 74 }, { ...line, quantity: 1 },
    { ...line, unit: 'box' }, { ...line, code: 'missing' },
    { ...line, offer_price: null }, { ...line, offer_revision: undefined },
  ];
  const before = JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows, f.props.SEQ_ORD_26]);
  for (const item of checks) {
    assert.equal(f.call('order_create', order(item), 'customer').error.code, 'OFFER_CHANGED');
    assert.equal(JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows, f.props.SEQ_ORD_26]), before);
  }
  assert.equal(f.call('order_create', { ...order(line), currency: 'SYP' }, 'customer').error.code, 'OFFER_CHANGED');
  const response = f.call('order_create', order(line), 'customer');
  assert.equal(response.ok, true);
  const items = f.context._all('Order_Items');
  assert.equal(items[0].unit_price_snapshot, 75);
  assert.equal(items[0].display_price_snapshot, 75);
  assert.equal(items[0].offer_old_price, 100);
  assert.equal(items[0].offer_min_quantity, 2);
  assert.equal(items[0].offer_revision, 1);
  assert.equal(items[0].offer_starts_at, saved.starts_at);
  assert.equal(items[0].offer_ends_at, saved.ends_at);
  const details = f.call('order_details', { order_id: response.order_id }, 'customer').order.items[0];
  assert.equal(details.offer_id, saved.offer_id);
  assert.equal(details.offer_old_price, 100);
  assert.equal(details.unit_price_snapshot, 75);
  assert.equal('stock_available' in details, false);
  const warehouse = f.call('order_details', { order_id: response.order_id }, 'warehouse').order.items[0];
  for (const field of ['offer_old_price', 'unit_price_snapshot', 'base_price_snapshot',
    'price_offer', 'default_price', 'final_price', 'total_price']) {
    assert.equal(field in warehouse, false, field);
  }
  assert.equal(warehouse.offer_id, saved.offer_id);
  const original = JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows]);
  const itemId = items[0].item_id;
  assert.equal(f.call('edit_order', {
    order_id: response.order_id, items: [{ item_id: itemId, code: 'P1', unit: 'piece', quantity: 1 }],
  }, 'customer').error.code, 'OFFER_REQUOTE_REQUIRED');
  assert.equal(f.call('updateCustomerOrder', {
    order_id: response.order_id, items: [{ item_id: itemId, action: 'update', quantity: 1 }],
  }, 'customer').error.code, 'OFFER_REQUOTE_REQUIRED');
  assert.equal(f.call('order_price', {
    order_id: response.order_id, items: [{ code: 'P1', unit: 'piece', quantity: 1, price: 75 }],
  }).error.code, 'OFFER_REQUOTE_REQUIRED');
  assert.equal(JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows]), original);
  assert.equal(f.call('offer_archive', { offer_id: saved.offer_id, revision: 1 }).ok, true);
  assert.equal(f.call('order_create', order(line), 'customer').is_duplicate, true);
  assert.equal(f.call('order_create', order(line, 'req2'), 'customer').error.code, 'OFFER_CHANGED');
  assert.equal(f.call('order_create', order({ code: 'P1', unit: 'piece', quantity: 1 }, 'req3'), 'customer').ok, true);
  assert.equal(f.context._all('Order_Items')[1].unit_price_snapshot, 100);
});

test('offer columns are required only for claimed orders and missing schema never writes', () => {
  const f = fixture();
  const saved = f.call('offer_save', { offer: f.offer() }).offer;
  const headers = f.sheets.Order_Items.rows[0];
  headers.splice(headers.indexOf('offer_revision'), 1);
  const line = { code: 'P1', unit: 'piece', quantity: 2,
    offer_id: saved.offer_id, offer_revision: 1, offer_price: 75 };
  const body = { client_request_id: 'a', items: [line] };
  assert.equal(f.call('order_create', body, 'customer').error.code, 'SCHEMA_NOT_READY');
  assert.equal(f.sheets.Orders.rows.length, 1);
  assert.equal(f.call('order_create', {
    client_request_id: 'b', items: [{ code: 'P1', unit: 'piece', quantity: 1 }],
  }, 'customer').ok, true);
  f.context.setupSystem();
  assert.ok(f.sheets.Order_Items.rows[0].includes('offer_revision'));
  assert.equal(f.sheets.Orders.rows.length, 2);
});

test('pricing offer orders preserves historical terms and submits the approval workflow', () => {
  const f = fixture();
  const offer = f.call('offer_save', { offer: f.offer() }).offer;
  const order = f.call('order_create', { client_request_id: 'price-1', items: [{
    code: 'P1', unit: 'piece', quantity: 3, offer_id: offer.offer_id,
    offer_revision: 1, offer_price: 75,
  }] }, 'customer');
  assert.equal(order.ok, true);
  const before = f.context._all('Order_Items')[0];
  assert.equal(f.call('offer_archive', { offer_id: offer.offer_id, revision: 1 }).ok, true);
  assert.equal(f.call('product_price_update', { code: 'P1', display_price: 50 }).ok, true);
  const result = f.call('order_price', {
    order_id: order.order_id, submitForCustomer: true, subtotal: 150, total: 150,
    items: [{ code: 'P1', unit: 'piece', quantity_approved: 2, final_price: 75,
      unit_factor: 999, base_price_snapshot: 999, unit_1: 'bad', factor_2: 999 }],
  });
  assert.equal(result.ok, true);
  assert.equal(result.status, 'priced');
  const after = f.context._all('Order_Items')[0];
  for (const key of ['offer_id', 'offer_revision', 'offer_old_price', 'offer_min_quantity',
    'offer_starts_at', 'offer_ends_at', 'unit_price_snapshot', 'display_price_snapshot',
    'unit', 'unit_factor', 'base_price_snapshot', 'unit_1', 'factor_2']) {
    assert.equal(after[key], before[key], key);
  }
  assert.equal(after.quantity_approved, 2);
  assert.equal(after.final_price, 75);
  assert.equal(after.total_price, 150);
  assert.equal(f.context._all('Orders')[0].status, 'priced');
});

test('offer pricing rejects all mismatches before any order or item write', () => {
  const f = fixture();
  const offer = f.call('offer_save', { offer: f.offer() }).offer;
  const order = f.call('order_create', { client_request_id: 'price-reject', items: [{
    code: 'P1', unit: 'piece', quantity: 2, offer_id: offer.offer_id,
    offer_revision: 1, offer_price: 75,
  }] }, 'customer');
  const before = JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows]);
  const line = { code: 'P1', unit: 'piece', quantity_approved: 2, final_price: 75 };
  for (const items of [
    [{ ...line, unit: 'box' }], [{ ...line, quantity_approved: 1 }],
    [{ ...line, final_price: 74 }], [{ ...line, final_price: null }],
    [{ ...line, quantity_approved: true }], [], [line, line],
    [{ code: 'other', quantity: 1, price: 5 }, { ...line, final_price: 74 }],
  ]) {
    const result = f.call('order_price', { order_id: order.order_id, items });
    assert.equal(result.error.code, 'OFFER_REQUOTE_REQUIRED', JSON.stringify(items));
    assert.equal(JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows]), before);
  }
});

test('unavailable offer line is zeroed without changing its historical snapshot', () => {
  const f = fixture();
  const offer = f.call('offer_save', { offer: f.offer() }).offer;
  const order = f.call('order_create', { client_request_id: 'unavailable', items: [{
    code: 'P1', unit: 'piece', quantity: 2, offer_id: offer.offer_id,
    offer_revision: 1, offer_price: 75,
  }] }, 'customer');
  const before = f.context._all('Order_Items')[0];
  const result = f.call('order_price', { order_id: order.order_id, items: [{
    code: 'P1', status: 'unavailable', quantity: 9, price: 900, unit_factor: 9,
  }] });
  assert.equal(result.ok, true);
  const after = f.context._all('Order_Items')[0];
  assert.equal(after.status, 'unavailable');
  assert.equal(after.quantity_approved, 0);
  assert.equal(after.final_price, 0);
  assert.equal(after.total_price, 0);
  for (const key of ['unit', 'unit_factor', 'offer_id', 'offer_old_price',
    'offer_revision', 'offer_min_quantity', 'offer_starts_at', 'offer_ends_at',
    'unit_price_snapshot', 'display_price_snapshot']) {
    assert.equal(after[key], before[key], key);
  }
});

test('optional expected unit price is authoritative and retries remain idempotent', () => {
  const f = fixture();
  const line = { code: 'P1', unit: 'piece', quantity: 1 };
  const call = (item, id) => f.call('order_create', {
    client_request_id: id, items: [item],
  }, 'customer');
  const before = JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows, f.props.SEQ_ORD_26]);
  for (const expected of [99, null, '', true, 'Infinity']) {
    assert.equal(call({ ...line, expected_unit_price: expected }, 'bad').error.code, 'PRICE_CHANGED');
    assert.equal(JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows, f.props.SEQ_ORD_26]), before);
  }
  assert.equal(call({ ...line, expected_unit_price: '100' }, 'accepted').ok, true);
  assert.equal(f.call('product_price_update', { code: 'P1', display_price: 120 }).ok, true);
  assert.equal(call({ ...line, expected_unit_price: 100 }, 'accepted').is_duplicate, true);
  assert.equal(call({ ...line, expected_unit_price: 100 }, 'new').error.code, 'PRICE_CHANGED');
  assert.equal(call(line, 'legacy').ok, true);
  assert.equal(f.context._all('Order_Items')[1].unit_price_snapshot, 120);
});

test('expected price compares to the offered unit price rather than catalog price', () => {
  const f = fixture();
  const offer = f.call('offer_save', { offer: f.offer() }).offer;
  const item = { code: 'P1', unit: 'piece', quantity: 2, offer_id: offer.offer_id,
    offer_revision: 1, offer_price: 75 };
  const request = expected => ({ client_request_id: 'offer-comparison',
    items: [{ ...item, expected_unit_price: expected }] });
  assert.equal(f.call('order_create', request(100), 'customer').error.code, 'PRICE_CHANGED');
  assert.equal(f.sheets.Orders.rows.length, 1);
  assert.equal(f.call('order_create', request('75'), 'customer').ok, true);
});

function mixedOfferOrder(f) {
  f.context._add('Products', { code: 'P2', name: 'Other', unit_1: 'piece',
    display_price: 30, currency: 'USD', quantity: 50 });
  const offer = f.call('offer_save', { offer: f.offer() }).offer;
  const order = f.call('order_create', { client_request_id: 'mixed', items: [
    { code: 'P1', unit: 'piece', quantity: 2, offer_id: offer.offer_id,
      offer_revision: 1, offer_price: 75 },
    { code: 'P2', unit: 'piece', quantity: 1 },
  ] }, 'customer');
  assert.equal(order.ok, true);
  const items = f.context._all('Order_Items');
  return { order, offerItem: items[0], ordinary: items[1] };
}

test('edit_order permits unrelated edits while preserving historical offer snapshot', () => {
  const f = fixture();
  const { order, offerItem, ordinary } = mixedOfferOrder(f);
  const result = f.call('edit_order', { order_id: order.order_id, note: 'Order note', items: [
    { item_id: offerItem.item_id, code: 'P1', unit: 'piece', quantity: 2, note: 'Offer note' },
    { item_id: ordinary.item_id, code: 'P2', unit: 'piece', quantity: 3 },
  ] }, 'customer');
  assert.equal(result.ok, true);
  const after = f.context._all('Order_Items');
  for (const key of Object.keys(offerItem).filter(key => key !== 'customer_note')) {
    assert.equal(after[0][key], offerItem[key], key);
  }
  assert.equal(after[0].customer_note, 'Offer note');
  assert.equal(after[1].quantity_requested, 3);
  assert.equal(f.context._all('Orders')[0].note, 'Order note');
});

test('edit_order rejects promotion changes and deletion before unrelated item writes', () => {
  const f = fixture();
  const { order, offerItem, ordinary } = mixedOfferOrder(f);
  const valid = { item_id: offerItem.item_id, code: 'P1', unit: 'piece', quantity: 2 };
  const other = { item_id: ordinary.item_id, code: 'P2', unit: 'piece', quantity: 3 };
  const before = JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows, f.sheets.Products.rows]);
  for (const items of [
    [other], [other, { ...valid, quantity: 3 }], [other, { ...valid, unit: 'box' }],
    [other, { ...valid, offer_old_price: 999 }], [other, { ...valid, price: 99 }],
    [other, { ...valid, offer_price: 99 }],
    [other, valid, valid],
  ]) {
    const result = f.call('edit_order', { order_id: order.order_id, items }, 'customer');
    assert.equal(result.error.code, 'OFFER_REQUOTE_REQUIRED', JSON.stringify(items));
    assert.equal(JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows, f.sheets.Products.rows]), before);
  }
});

test('legacy customer update edits ordinary items but blocks offer changes before writes', () => {
  const f = fixture();
  const { order, offerItem, ordinary } = mixedOfferOrder(f);
  const ordinaryUpdate = { item_id: ordinary.item_id, action: 'update', quantity: 3 };
  const before = JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows]);
  for (const item of [
    { item_id: offerItem.item_id, action: 'delete' },
    { item_id: offerItem.item_id, action: 'update', quantity: 1 },
    { item_id: offerItem.item_id, action: 'update', quantity: 2, unit: 'box' },
  ]) {
    assert.equal(f.call('updateCustomerOrder', {
      order_id: order.order_id, items: [ordinaryUpdate, item],
    }, 'customer').error.code, 'OFFER_REQUOTE_REQUIRED');
    assert.equal(JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows]), before);
  }
  assert.equal(f.call('updateCustomerOrder', {
    order_id: order.order_id, items: [ordinaryUpdate,
      { item_id: offerItem.item_id, action: 'update', quantity: 2 }],
  }, 'customer').ok, true);
  const after = f.context._all('Order_Items');
  for (const key of Object.keys(offerItem)) assert.equal(after[0][key], offerItem[key], key);
  assert.equal(after[1].quantity_requested, 3);
});

test('staff edit preserves approved offer consumption and saved amounts', () => {
  const f = fixture();
  const { order, offerItem, ordinary } = mixedOfferOrder(f);
  assert.equal(f.call('order_price', { order_id: order.order_id, subtotal: 180, total: 180,
    submitForCustomer: true, items: [
      { code: 'P1', unit: 'piece', quantity: 2, price: 75 },
      { code: 'P2', unit: 'piece', quantity: 1, price: 30 },
    ] }).ok, true);
  f.context._updateByField('Orders', 'order_id', order.order_id, { status: 'approved' });
  const beforeOffer = f.context._all('Order_Items')[0];
  const result = f.call('edit_order', { order_id: order.order_id, items: [
    { item_id: offerItem.item_id, code: 'P1', unit: 'piece', quantity: 2, price: 75 },
    { item_id: ordinary.item_id, code: 'P2', unit: 'piece', quantity: 2, price: 30 },
  ] }, 'admin');
  assert.equal(result.ok, true);
  const after = f.context._all('Order_Items')[0];
  for (const key of Object.keys(beforeOffer)) assert.equal(after[key], beforeOffer[key], key);
  const products = f.context._all('Products');
  assert.equal(products[0].quantity, 42);
  assert.equal(products[1].quantity, 49);
  assert.equal(f.context._all('Orders')[0].subtotal, 210);
});

test('manual offer price override requires explicit confirmation, role and audit', () => {
  const f = fixture();
  const { order } = mixedOfferOrder(f);
  const items = [
    { code: 'P1', unit: 'piece', quantity: 2, price: 60 },
    { code: 'P2', unit: 'piece', quantity: 1, price: 30 },
  ];
  const before = f.context._all('Order_Items')[0];
  const beforeRows = JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows]);
  assert.equal(f.call('order_price', { order_id: order.order_id, items }).error.code, 'OFFER_REQUOTE_REQUIRED');
  assert.equal(f.call('order_price', { order_id: order.order_id, items, confirm_offer_price_override: 'true' }).error.code, 'OFFER_REQUOTE_REQUIRED');
  assert.equal(f.call('order_price', { order_id: order.order_id, items, confirm_offer_price_override: true }, 'customer').ok, false);
  assert.equal(f.call('order_price', { order_id: order.order_id, items: [
    { ...items[0], quantity: 1 }, items[1],
  ], confirm_offer_price_override: true }).error.code, 'OFFER_REQUOTE_REQUIRED');
  assert.equal(JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows]), beforeRows);
  const result = f.call('order_price', { order_id: order.order_id, items,
    confirm_offer_price_override: true, subtotal: 150, total: 150, submitForCustomer: true }, 'accountant');
  assert.equal(result.ok, true);
  const after = f.context._all('Order_Items')[0];
  for (const key of ['offer_id', 'offer_revision', 'offer_old_price', 'offer_min_quantity',
    'offer_starts_at', 'offer_ends_at', 'unit_price_snapshot', 'display_price_snapshot']) {
    assert.equal(after[key], before[key], key);
  }
  assert.equal(after.final_price, 60);
  assert.equal(after.total_price, 120);
  const audit = f.context._all('Audit_Log').find(row => row.action === 'OFFER_PRICE_OVERRIDE');
  assert.equal(audit.user_id, 'accountant');
  assert.equal(JSON.parse(audit.details).overrides[0].offer_price, 75);
  assert.equal(JSON.parse(audit.details).overrides[0].final_price, 60);
});

test('override audit schema and writes are required before order mutations', () => {
  const f = fixture();
  const { order } = mixedOfferOrder(f);
  const items = [{ code: 'P1', unit: 'piece', quantity: 2, price: 60 },
    { code: 'P2', unit: 'piece', quantity: 1, price: 30 }];
  const before = JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows]);
  f.sheets.Audit_Log.appendRow = () => { throw new Error('audit unavailable'); };
  assert.equal(f.call('order_price', { order_id: order.order_id, items,
    confirm_offer_price_override: true }).ok, false);
  assert.equal(JSON.stringify([f.sheets.Orders.rows, f.sheets.Order_Items.rows]), before);
});

