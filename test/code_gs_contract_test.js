const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function loadBackend(options = {}) {
  const scriptProperties = {
    ...(options.scriptProperties || {}),
    getProperty(name) {
      return Object.prototype.hasOwnProperty.call(this, name)
        ? this[name]
        : name === 'SPREADSHEET_ID'
          ? 'test-sheet'
          : null;
    },
    setProperty(name, value) {
      this[name] = value;
      return this;
    },
    deleteProperty(name) {
      delete this[name];
      return this;
    },
  };
  const tables = {
    Sessions: [
      ['token', 'user_id', 'expires_at'],
      ['valid-token', 'user-1', new Date(Date.now() + 60_000).toISOString()],
    ],
    Users: [
      [
        'user_id',
        'username',
        'role',
        'status',
        'customer_id',
        'must_change_password',
      ],
      [
        'user-1',
        'customer-one',
        options.role || 'customer',
        'active',
        'customer-1',
        options.mustChangePassword || '',
      ],
    ],
  };
  const context = {
    Date,
    JSON,
    Math,
    Object,
    Array,
    String,
    Number,
    Error,
    SyntaxError,
    Logger: { log() {} },
    Utilities: {
      getUuid: () => 'request-id',
      formatDate: (date, timeZone, pattern) => {
        assert.equal(timeZone, 'UTC');
        assert.equal(pattern, 'yyMMdd');
        const year = String(date.getUTCFullYear()).slice(-2);
        const month = String(date.getUTCMonth() + 1).padStart(2, '0');
        const day = String(date.getUTCDate()).padStart(2, '0');
        return `${year}${month}${day}`;
      },
      newBlob: value => ({
        getBytes: () => Array.from(Buffer.from(String(value), 'utf8')),
      }),
      computeHmacSha256Signature: () => {
        throw new Error('PBKDF2 must not call Utilities once per round');
      },
    },
    PropertiesService: { getScriptProperties: () => scriptProperties },
    Session: { getScriptTimeZone: () => 'UTC' },
    LockService: {
      getScriptLock: () => ({
        tryLock: () => true,
        releaseLock() {},
      }),
    },
    SpreadsheetApp: {
      openById: () => ({
        getSheetByName: name => ({
          getDataRange: () => ({
            getValues: () => tables[name] || [],
          }),
        }),
      }),
    },
    ContentService: {
      MimeType: { JSON: 'application/json' },
      createTextOutput: content => ({
        content,
        setMimeType() {
          return this;
        },
      }),
    },
  };
  vm.createContext(context);
  vm.runInContext(
    fs.readFileSync(path.join(__dirname, '..', 'Code.gs'), 'utf8'),
    context,
  );
  return context;
}

function invoiceTemplateFixture(role = 'admin') {
  const backend = loadBackend({ role });
  const columns = ['index', 'image', 'name', 'quantity', 'unit', 'price', 'total', 'note'];
  const template = {
    version: '1.0',
    company_name: 'شركة',
    company_details: 'العنوان',
    footer: 'شكراً',
    primary_color: '#123abc',
    font_size: 10,
    margin: 30,
    columns,
    column_widths: Object.fromEntries(columns.map(key => [key, 1])),
    show_images: true,
    show_notes: false,
    logo_file_id: '',
  };
  let rows = [
    ['key', 'value'],
    ...Object.entries(template).map(([key, value]) => [
      key, typeof value === 'object' ? JSON.stringify(value) : value,
    ]),
  ];
  let writes = 0;
  let locks = 0;
  let releases = 0;
  let busy = false;
  const originalOpen = backend.SpreadsheetApp.openById;
  const sheet = {
    getDataRange: () => ({ getValues: () => rows.map(row => [...row]) }),
    getRange: (r, c, count, width) => ({
      setValues(values) {
        assert.deepEqual([r, c, count, width], [2, 1, values.length, 2]);
        writes++;
        rows = [rows[0], ...values.map(row => [
          row[0], typeof row[1] === 'string' && row[1].startsWith("'")
            ? row[1].slice(1) : row[1],
        ])];
      },
    }),
  };
  backend.SpreadsheetApp.openById = () => {
    const original = originalOpen();
    return {
      getSheetByName: name => {
        if (name === 'Invoice_Template') return sheet;
        const source = original.getSheetByName(name);
        return { getDataRange: () => ({
          getValues: () => source.getDataRange().getValues().map(row => [...row]),
        }) };
      },
    };
  };
  backend.LockService = { getScriptLock: () => ({
    tryLock() { locks++; return !busy; },
    releaseLock() { releases++; },
  }) };
  backend.Utilities.base64Encode = bytes => Buffer.from(bytes).toString('base64');
  const call = (action, data = {}, token = 'valid-token') => JSON.parse(backend.doPost({
    postData: { contents: JSON.stringify({ action, token, ...data }) },
  }).content);
  return {
    backend, template, call,
    get rows() { return rows; },
    set rows(value) { rows = value; },
    get writes() { return writes; },
    get locks() { return locks; },
    get releases() { return releases; },
    set busy(value) { busy = value; },
  };
}

test('invoice template actions enforce authentication and reader/writer roles', () => {
  for (const role of ['admin', 'manager', 'accountant', 'salesperson', 'customer', 'warehouse']) {
    const f = invoiceTemplateFixture(role);
    assert.equal(f.call('invoice_template_get', {}, '').error.code, 'AUTH_REQUIRED');
    const read = f.call('invoice_template_get');
    assert.equal(read.ok, !['customer', 'warehouse'].includes(role), role);
    if (read.ok) {
      assert.equal(read.data.template.version, '1.0');
      assert.equal('logo_base64' in read.data.template, false);
      assert.equal('logo_file_id' in read.data.template, false);
    }
    const update = f.call('invoice_template_update', { template: f.template });
    assert.equal(update.ok, ['admin', 'manager', 'accountant'].includes(role), `${role}: ${JSON.stringify(update.error)}`);
    assert.equal(f.writes, update.ok ? 1 : 0);
    if (update.ok) assert.deepEqual([f.locks, f.releases], [1, 1]);
  }
});

test('invoice template validates all fields before writing and locks successful replacements', () => {
  const f = invoiceTemplateFixture();
  const invalid = [
    { version: '' }, { version: 'x'.repeat(41) }, { version: 'bad space' },
    { company_name: 'x'.repeat(201) }, { company_details: 'x'.repeat(2001) },
    { footer: '\u0000' }, { footer: 'x'.repeat(121) },
    { footer: 'line\nnext' }, { footer: 'line\rnext' }, { footer: 'a\tb' },
    { footer: 'a\u2028b' }, { footer: 'a\u2029b' },
    { company_name: 'line\nnext' }, { company_name: 'line\rnext' }, { company_name: 'a\tb' },
    { primary_color: '#123' }, { font_size: 7.99 },
    { font_size: '10' }, { margin: 50.1 }, { show_images: 'true' },
    { show_notes: 0 }, { columns: [...f.template.columns.slice(0, 7), 'total'] },
    { columns: [...f.template.columns.slice(0, 7), 'unknown'] },
    { column_widths: { ...f.template.column_widths, note: 0.39 } },
    { column_widths: { ...f.template.column_widths, note: 4.01 } },
    { column_widths: { ...f.template.column_widths, extra: 1 } },
    { logo_file_id: 'https://example.com' }, { unknown: 1 },
  ];
  for (const change of invalid) {
    const result = f.call('invoice_template_update', { template: { ...f.template, ...change } });
    assert.equal(result.error.code, 'INVALID_INVOICE_TEMPLATE', JSON.stringify(change));
    assert.equal(f.writes, 0);
  }
  const missing = { ...f.template };
  delete missing.footer;
  assert.equal(f.call('invoice_template_update', { template: missing }).error.code, 'INVALID_INVOICE_TEMPLATE');
  const before = JSON.stringify(f.rows);
  f.busy = true;
  assert.equal(f.call('invoice_template_update', { template: f.template }).error.code, 'BUSY');
  assert.equal(f.writes, 0);
  assert.equal(JSON.stringify(f.rows), before);
  f.busy = false;
  const replacement = {
    ...f.template, company_name: '=1+1', company_details: 'Address\nPhone\t123',
    footer: 'x'.repeat(120), font_size: 8, margin: 50,
  };
  assert.equal(f.call('invoice_template_update', { template: replacement }).ok, true);
  const saved = f.call('invoice_template_get').data.template;
  assert.equal(saved.company_name, '=1+1');
  assert.equal(saved.company_details, 'Address\nPhone\t123');
  assert.equal(saved.footer.length, 120);
  assert.equal(f.writes, 1);
  assert.equal(f.releases, 1);
});

test('invoice template enforces visible A4 column widths on get and update', () => {
  const f = invoiceTemplateFixture();
  const widths = { index: 0.42, image: 4, name: 1.416, quantity: 1.416,
    unit: 1.416, price: 1.416, total: 1.416, note: 4 };
  const boundary = { ...f.template, margin: 47.6378, column_widths: widths,
    show_images: false, show_notes: false };
  assert.equal(f.call('invoice_template_update', { template: boundary }).ok, true);
  assert.equal(f.call('invoice_template_get').ok, true);
  const original = JSON.stringify(f.rows);
  for (const change of [
    { column_widths: { ...widths, index: 0.4199 } },
    { margin: 47.6478 },
    { show_images: true },
    { show_notes: true },
  ]) {
    const result = f.call('invoice_template_update', { template: { ...boundary, ...change } });
    assert.equal(result.error.code, 'INVALID_INVOICE_TEMPLATE', JSON.stringify(change));
    assert.equal(JSON.stringify(f.rows), original);
    assert.equal(f.writes, 1);
  }
  f.rows.find(row => row[0] === 'show_notes')[1] = 'true';
  assert.equal(f.call('invoice_template_get').error.code, 'INVALID_INVOICE_TEMPLATE');
  f.rows.find(row => row[0] === 'show_notes')[1] = 'false';
  f.rows.find(row => row[0] === 'column_widths')[1] = JSON.stringify({ ...widths, index: 0.4199 });
  assert.equal(f.call('invoice_template_get').error.code, 'INVALID_INVOICE_TEMPLATE');
});

test('invoice template rejects missing sheets, corrupt rows and duplicate JSON keys', () => {
  const f = invoiceTemplateFixture();
  f.backend.SpreadsheetApp.openById = () => ({ getSheetByName: () => null });
  assert.throws(() => f.backend._handleInvoiceTemplateGet_({}, { role: 'admin' }),
    error => error.code === 'INVOICE_TEMPLATE_SHEET_MISSING');
  assert.throws(() => f.backend._handleInvoiceTemplateUpdate_({ template: f.template }, { role: 'admin' }),
    error => error.code === 'INVOICE_TEMPLATE_SHEET_MISSING');
  assert.equal(f.releases, 1);
  const cases = [
    rows => { rows[0][0] = 'bad'; },
    rows => { rows.push(['version', '2']); },
    rows => { rows.push(['unknown', 'x']); },
    rows => { rows.splice(1, 1); },
    rows => { rows.find(row => row[0] === 'show_images')[1] = 'yes'; },
    rows => { rows.find(row => row[0] === 'columns')[1] = '['; },
    rows => { rows.find(row => row[0] === 'font_size')[1] = 15; },
    rows => { rows.find(row => row[0] === 'margin')[1] = ''; },
    rows => { rows.find(row => row[0] === 'company_name')[1] = 'x'.repeat(201); },
    rows => { rows.find(row => row[0] === 'company_name')[1] = 'first\nsecond'; },
    rows => { rows.find(row => row[0] === 'company_name')[1] = 'first\tsecond'; },
    rows => { rows.find(row => row[0] === 'footer')[1] = 'x'.repeat(121); },
    rows => { rows.find(row => row[0] === 'footer')[1] = 'first\nsecond'; },
    rows => { rows.find(row => row[0] === 'footer')[1] = 'first\tsecond'; },
    rows => { rows.find(row => row[0] === 'column_widths')[1] =
      '{"index":1,"index":1,"image":1,"name":1,"quantity":1,"unit":1,"price":1,"total":1,"note":1}'; },
  ];
  for (const corrupt of cases) {
    const fixture = invoiceTemplateFixture();
    corrupt(fixture.rows);
    assert.equal(fixture.call('invoice_template_get').error.code, 'INVALID_INVOICE_TEMPLATE');
  }
  const g = invoiceTemplateFixture();
  const raw = JSON.stringify({ action: 'invoice_template_update', token: 'valid-token', template: g.template })
    .replace('"version":"1.0"', '"version":"1.0","version":"2"');
  const result = JSON.parse(g.backend.doPost({ postData: { contents: raw } }).content);
  assert.equal(result.error.code, 'INVALID_INVOICE_TEMPLATE');
  assert.equal(g.writes, 0);
  g.rows.push(['unknown', '']);
  const before = JSON.stringify(g.rows);
  assert.equal(g.call('invoice_template_update', { template: g.template }).error.code, 'INVALID_INVOICE_TEMPLATE');
  assert.equal(JSON.stringify(g.rows), before);
  assert.equal(g.releases, 1);
});

test('invoice template reads only private bounded PNG/JPEG logos before update', () => {
  const f = invoiceTemplateFixture();
  let bytes = [137, 80, 78, 71, 13, 10, 26, 10];
  let mime = 'image/png';
  let size = bytes.length;
  f.backend.DriveApp = { getFileById(id) {
    assert.equal(id, 'private_id');
    return { getSize: () => size, getBlob: () => ({
      getContentType: () => mime, getBytes: () => bytes,
    }) };
  } };
  const input = { ...f.template, logo_file_id: 'private_id' };
  const result = f.call('invoice_template_update', { template: input });
  assert.equal(result.data.template.logo_base64, Buffer.from(bytes).toString('base64'));
  assert.equal(f.call('invoice_template_get').data.template.logo_base64, result.data.template.logo_base64);
  size = 1024 * 1024 + 1;
  assert.equal(f.call('invoice_template_update', { template: input }).error.code, 'INVALID_INVOICE_TEMPLATE_LOGO');
  assert.equal(f.writes, 1);
  assert.equal(f.call('invoice_template_get').error.code, 'INVALID_INVOICE_TEMPLATE_LOGO');
  size = 3; bytes = [255, 216, 255]; mime = 'image/jpeg';
  assert.equal(f.call('invoice_template_get').ok, true);
  mime = 'image/png';
  assert.equal(f.call('invoice_template_get').error.code, 'INVALID_INVOICE_TEMPLATE_LOGO');
  f.backend.DriveApp.getFileById = () => { throw new Error('private'); };
  assert.equal(f.call('invoice_template_get').error.code, 'INVALID_INVOICE_TEMPLATE_LOGO');
  assert.equal(f.releases, 2);
});

test('invoice template creates an optional logo row and omission clears it', () => {
  const f = invoiceTemplateFixture();
  f.rows = f.rows.filter(row => row[0] !== 'logo_file_id');
  f.backend.DriveApp = { getFileById: () => ({
    getSize: () => 3,
    getBlob: () => ({ getContentType: () => 'image/jpeg', getBytes: () => [255, 216, 255] }),
  }) };
  assert.equal(f.call('invoice_template_update', {
    template: { ...f.template, logo_file_id: 'id' },
  }).ok, true);
  assert.equal(f.rows.find(row => row[0] === 'logo_file_id')[1], 'id');
  const withoutLogo = { ...f.template };
  delete withoutLogo.logo_file_id;
  assert.equal(f.call('invoice_template_update', { template: withoutLogo }).ok, true);
  assert.equal(f.rows.find(row => row[0] === 'logo_file_id')[1], '');
  assert.equal('logo_base64' in f.call('invoice_template_get').data.template, false);
});

test('password hashing matches PBKDF2-SHA256 for ASCII and Unicode inputs', () => {
  const backend = loadBackend();
  const hash = backend._passwordHash_('Temporary123', 'test-salt', 10000);
  assert.match(hash, /^pbkdf2-sha256\$10000\$[a-f0-9]{64}$/);
  const expected = crypto
    .pbkdf2Sync('Temporary123', 'test-salt', 10000, 32, 'sha256')
    .toString('hex');
  assert.equal(hash, `pbkdf2-sha256$10000$${expected}`);
  const defaultHash = backend._passwordHash_('Temporary123', 'test-salt');
  assert.match(defaultHash, /^pbkdf2-sha256\$120000\$[a-f0-9]{64}$/);
  assert.equal(
    defaultHash,
    `pbkdf2-sha256$120000$${crypto
      .pbkdf2Sync('Temporary123', 'test-salt', 120000, 32, 'sha256')
      .toString('hex')}`,
  );
  assert.equal(
    backend._verifyPassword_('Temporary123', {
      password_hash: hash,
      salt: 'test-salt',
    }),
    true,
  );
  assert.equal(
    backend._verifyPassword_('WrongPassword123', {
      password_hash: hash,
      salt: 'test-salt',
    }),
    false,
  );
  const unicodeHash = backend._passwordHash_('كلمة السر🔒', 'ملح', 10000);
  assert.equal(
    unicodeHash,
    `pbkdf2-sha256$10000$${crypto
      .pbkdf2Sync('كلمة السر🔒', 'ملح', 10000, 32, 'sha256')
      .toString('hex')}`,
  );
});

test('sales settings normalize configured currency codes and reject managers', () => {
  const backend = loadBackend({
    scriptProperties: {
      SALES_INVOICE_CURRENCY: ' syp ',
      SHAM_CASH_CURRENCY: 'Usd',
      DEFAULT_PRODUCT_CURRENCY: 'usd',
      SALES_RATE_SYP_PER_USD: '14500',
      SALES_USD_DECIMALS: '2',
      SALES_SYP_DECIMALS: '0',
    },
  });
  const settings = backend._handleGetSalesSettings({}, { role: 'accountant' });
  assert.equal(settings.settings.invoice_currency, 'SYP');
  assert.equal(settings.settings.sham_cash_currency, 'USD');
  assert.equal(settings.settings.default_product_currency, 'USD');
  assert.equal(settings.settings.rate_syp_per_usd, 14500);
  assert.throws(
    () => backend._handleGetSalesSettings({}, { role: 'manager' }),
    error => error.message.includes('ليست لديك الصلاحية'),
  );
});

test('salesperson configuration exposes normalized values without admin access', () => {
  const backend = loadBackend({
    role: 'salesperson',
    scriptProperties: {
      SALES_INVOICE_CURRENCY: ' syp ',
      SHAM_CASH_CURRENCY: 'usd',
      DEFAULT_PRODUCT_CURRENCY: 'SYP',
      SALES_USD_DECIMALS: '2',
      SALES_SYP_DECIMALS: '0',
    },
  });
  backend._all = name =>
    name === 'Users'
      ? [{ user_id: 'user-1', cash_box_id: 'cash-box-1' }]
      : [];
  const config = backend._handleSalesConfiguration({}, {
    user_id: 'user-1',
    role: 'salesperson',
  });
  assert.equal(config.invoice_currency, 'SYP');
  assert.equal(config.sham_cash_currency, 'USD');
  assert.equal(config.default_product_currency, 'SYP');
  assert.equal('cash_box_configured' in config, false);
  assert.equal('settings' in config, false);
  assert.equal('SALES_INVOICE_CURRENCY' in config, false);
});

test('all invoice creators can load the shared sales invoice configuration', () => {
  const backend = loadBackend({
    scriptProperties: {
      SALES_INVOICE_CURRENCY: 'USD',
      SHAM_CASH_CURRENCY: 'USD',
      DEFAULT_PRODUCT_CURRENCY: 'USD',
      SALES_RATE_SYP_PER_USD: '15000',
      SALES_USD_DECIMALS: '2',
      SALES_SYP_DECIMALS: '0',
    },
  });
  for (const role of ['admin', 'manager', 'accountant', 'salesperson']) {
    const config = backend._handleSalesConfiguration({}, {
      user_id: `${role}-1`,
      role,
    });
    assert.equal(config.invoice_currency, 'USD');
    assert.equal(config.rate_syp_per_usd, 15000);
  }
  assert.throws(
    () => backend._handleSalesConfiguration({}, {
      user_id: 'customer-1',
      role: 'customer',
    }),
    error => error.message.includes('ليست لديك الصلاحية'),
  );
});

test('salespeople see central stock instead of legacy allocated balances', () => {
  const backend = loadBackend({ role: 'salesperson' });
  backend._all = name => {
    if (name === 'Products') {
      return [{
        code: 'P-1',
        name: 'Part',
        quantity: 12,
        display_price: 5,
        currency: 'USD',
        unit_1: 'piece',
      }];
    }
    if (name === 'New_Products' || name === 'Product_Images') return [];
    if (name === 'Sales_Stock') {
      throw new Error('Legacy allocated stock must not be read for new sales');
    }
    return [];
  };

  const result = backend._handleProducts({}, { role: 'salesperson' });
  assert.equal(result.products[0].quantity, 12);
  assert.equal(result.products[0].stock, 12);
});

test('cash sale deducts central stock and records its source without seller stock', () => {
  const lockState = { allowed: true, attempts: 0 };
  const backend = loadBackend({
    role: 'salesperson',
    scriptProperties: {
      SALES_INVOICE_CURRENCY: 'USD',
      SHAM_CASH_CURRENCY: 'USD',
      DEFAULT_PRODUCT_CURRENCY: 'USD',
      SALES_USD_DECIMALS: '2',
      SALES_SYP_DECIMALS: '0',
      DEFAULT_PRODUCT_CURRENCY: 'USD',
    },
  });
  let uuidSequence = 0;
  backend.Utilities.getUuid = () => `request-id-${++uuidSequence}`;
  const tables = {
    Users: [{
      user_id: 'user-1',
      role: 'salesperson',
      status: 'active',
      cash_box_id: 'cash-1',
    }, {
      user_id: 'user-2',
      role: 'salesperson',
      status: 'active',
      cash_box_id: 'cash-1',
    }],
    Products: [{
      code: 'P-1',
      name: 'Part',
      quantity: 5,
      currency: 'USD',
      unit_1: 'piece',
    }],
    Sales_Invoices: [],
    Sales_Invoice_Items: [],
    Sales_Invoice_Audit: [],
    Inventory_Movements: [],
    Payments: [],
    Sales_Stock: [],
    Boxes_Balance: [{
      box_name: 'cash-1',
      currency: 'USD',
      balance: 10000,
    }],
  };
  backend.LockService = {
    getScriptLock: () => ({
      tryLock: () => {
        lockState.attempts++;
        return lockState.allowed;
      },
      releaseLock() {},
    }),
  };
  backend._all = name => {
    return tables[name] || [];
  };
  backend._requireColumns_ = () => {};
  backend._ensureShopCustomer_ = () => 'CUS-SHOP';
  backend._setProductStockQuantity_ = (code, quantity) => {
    const product = tables.Products.find(row => row.code === code);
    if (!product) throw new Error('product missing');
    product.quantity = quantity;
  };
  backend._setSalesStockQuantity_ = (userId, code, quantity) => {
    const stock = tables.Sales_Stock.find(
      row => row.user_id === userId && row.code === code,
    );
    if (!stock) throw new Error('legacy stock missing');
    stock.quantity = quantity;
  };
  backend._add = (name, value) => {
    tables[name].push(value);
  };
  backend._updateBoxBalance = () => {};
  backend._restoreBoxBalance_ = () => {};
  backend._updateByField = (name, field, value, updates) => {
    const row = tables[name].find(item => String(item[field]) === String(value));
    if (!row) return false;
    Object.assign(row, updates);
    return true;
  };
  backend._deleteRowsByField_ = (name, field, value) => {
    tables[name] = tables[name].filter(
      row => String(row[field]) !== String(value),
    );
  };
  const firstSale = backend._handleCreateSalesInvoice({
    client_request_id: 'request-central-stock-001',
    payment_method: 'cash_usd',
    amount_received: 20,
    items: [{ code: 'P-1', quantity: 3, unit_price: 5 }],
  }, { user_id: 'user-1', role: 'salesperson' });
  assert.equal(firstSale.success, true);
  assert.equal(tables.Products[0].quantity, 2);
  assert.equal(tables.Sales_Invoices[0].stock_source, 'central');
  assert.equal(tables.Sales_Invoice_Items[0].stock_source, 'central');
  assert.deepEqual(tables.Sales_Stock, []);

  assert.throws(
    () => backend._handleCreateSalesInvoice({
      client_request_id: 'request-central-stock-negative-quantity',
      payment_method: 'cash_usd',
      amount_received: 5,
      items: [{ code: 'P-1', quantity: -1, unit_price: 5 }],
    }, { user_id: 'user-1', role: 'salesperson' }),
    error => error.code === 'INVALID_SALES_ITEM',
  );
  assert.equal(tables.Products[0].quantity, 2);

  const soldToZero = backend._handleCreateSalesInvoice({
      client_request_id: 'request-central-stock-002',
      payment_method: 'cash_usd',
      amount_received: 20,
      items: [{ code: 'P-1', quantity: 2, unit_price: 5 }],
    }, { user_id: 'user-1', role: 'salesperson' });
  assert.equal(soldToZero.success, true);
  assert.equal(tables.Products[0].quantity, 0);

  const soldBelowZero = backend._handleCreateSalesInvoice({
      client_request_id: 'request-central-stock-003',
      payment_method: 'cash_usd',
      amount_received: 10,
      items: [{ code: 'P-1', quantity: 1, unit_price: 5 }],
    }, { user_id: 'user-2', role: 'salesperson' });
  assert.equal(soldBelowZero.success, true);
  assert.equal(tables.Products[0].quantity, -1);
  assert.equal(tables.Sales_Stock.length, 0);

  const soldFromNegative = backend._handleCreateSalesInvoice({
      client_request_id: 'request-central-stock-004',
      payment_method: 'cash_usd',
      amount_received: 15,
      items: [{ code: 'P-1', quantity: 2, unit_price: 5 }],
    }, { user_id: 'user-1', role: 'salesperson' });
  assert.equal(soldFromNegative.success, true);
  assert.equal(tables.Products[0].quantity, -3);

  const duplicate = backend._handleCreateSalesInvoice({
    client_request_id: 'request-central-stock-004',
    payment_method: 'cash_usd',
    amount_received: 15,
    items: [{ code: 'P-1', quantity: 2, unit_price: 5 }],
  }, { user_id: 'user-1', role: 'salesperson' });
  assert.equal(duplicate.duplicate, true);
  assert.equal(tables.Products[0].quantity, -3);

  const voided = backend._handleVoidSalesInvoice({
    invoice_id: soldFromNegative.invoice_id,
    reason: 'اختبار عكس البيع',
  }, { user_id: 'admin-1', role: 'admin' });
  assert.equal(voided.status, 'voided');
  assert.equal(tables.Products[0].quantity, -1);
  assert.equal(tables.Sales_Stock.length, 0);

  assert.throws(
    () => backend._handleVoidSalesInvoice({
      invoice_id: soldFromNegative.invoice_id,
      reason: 'محاولة ثانية',
    }, { user_id: 'admin-1', role: 'admin' }),
    error => error.code === 'INVOICE_NOT_POSTED',
  );
  assert.equal(tables.Products[0].quantity, -1);

  tables.Users.push({
    user_id: 'legacy-seller',
    role: 'salesperson',
    status: 'active',
    cash_box_id: 'cash-1',
    sales_stock_id: 'legacy-stock',
  });
  tables.Sales_Stock.push({
    user_id: 'legacy-stock',
    code: 'P-1',
    quantity: 4,
  });
  tables.Sales_Invoices.push({
    invoice_id: 'SI-LEGACY',
    seller_id: 'legacy-seller',
    status: 'posted',
    stock_source: '',
    payment_currency: 'USD',
    cash_box_id: 'cash-1',
    net_received: 0,
    currency: 'USD',
    net_total: 0,
    revision: 1,
  });
  tables.Sales_Invoice_Items.push({
    item_id: 'SII-LEGACY',
    invoice_id: 'SI-LEGACY',
    code: 'P-1',
    quantity: 3,
  });
  backend._handleVoidSalesInvoice(
    { invoice_id: 'SI-LEGACY', reason: 'عكس فاتورة تاريخية' },
    { user_id: 'admin-1', role: 'admin' },
  );
  assert.equal(tables.Sales_Stock[0].quantity, 7);
  assert.equal(tables.Products[0].quantity, -1);

  lockState.allowed = false;
  assert.throws(
    () => backend._handleCreateSalesInvoice({
      client_request_id: 'request-central-stock-005',
      payment_method: 'cash_usd',
      amount_received: 5,
      items: [{ code: 'P-1', quantity: 1, unit_price: 5 }],
    }, { user_id: 'user-2', role: 'salesperson' }),
    error => error.message.includes('جارٍ ترحيل عملية أخرى'),
  );
  assert.equal(tables.Products[0].quantity, -1);
  assert.equal(lockState.attempts, 10);

  const missingCurrency = loadBackend();
  missingCurrency._all = () => [];
  const missingConfig = missingCurrency._handleSalesConfiguration({}, {
    user_id: 'user-1',
    role: 'salesperson',
  });

  assert.equal(missingConfig.invoice_currency, 'USD');
});

test('sales invoice schema includes the stock source migration column', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'Code.gs'), 'utf8');
  assert.match(source, /Sales_Invoices:\s*\[[^\]]*'stock_source'/);
  assert.match(source, /Sales_Invoices:\s*\[[^\]]*'invoice_number'/);
  assert.match(source, /Sales_Invoices:\s*\[[^\]]*'created_by_role'/);
});

test('sales settings update Script Properties only after full validation', () => {
  const backend = loadBackend();
  const changes = [];
  backend._add = (sheet, record) => changes.push({ sheet, record });
  assert.throws(
    () => backend._handleUpdateSalesSettings(
      {
        invoice_currency: 'SYP',
        sham_cash_currency: 'USD',
        default_product_currency: 'USD',
        rate_syp_per_usd: '14500',
        usd_decimals: 2,
        syp_decimals: 0,
      },
      { role: 'admin', user_id: 'admin-1' },
    ),
    error => error.code === 'INVALID_SALES_SETTINGS',
  );
  const result = backend._handleUpdateSalesSettings(
    {
      invoice_currency: ' usd ',
      sham_cash_currency: 'usd',
      default_product_currency: 'USD',
      rate_syp_per_usd: '14500',
      usd_decimals: 2,
      syp_decimals: 0,
    },
    { role: 'admin', user_id: 'admin-1' },
  );
  assert.equal(result.settings.invoice_currency, 'USD');
  assert.equal(result.settings.rate_syp_per_usd, 14500);
  assert.equal(changes[0].sheet, 'Audit_Log');
  assert.throws(
    () => backend._handleUpdateSalesSettings(
      { invoice_currency: 'EUR' },
      { role: 'admin', user_id: 'admin-1' },
    ),
    error => error.code === 'INVALID_SALES_SETTINGS',
  );
});

test('sales settings reject stale changes and unauthorized roles', () => {
  const backend = loadBackend({ scriptProperties: {
    SALES_INVOICE_CURRENCY: 'USD',
    SHAM_CASH_CURRENCY: 'USD',
    DEFAULT_PRODUCT_CURRENCY: 'USD',
    SALES_RATE_SYP_PER_USD: '14500',
    SALES_USD_DECIMALS: '2',
    SALES_SYP_DECIMALS: '0',
  } });
  backend._add = () => {};
  const snapshot = backend._handleGetSalesSettings({}, { role: 'admin' }).settings;
  const values = {
    invoice_currency: 'USD',
    sham_cash_currency: 'USD',
    default_product_currency: 'USD',
    rate_syp_per_usd: '15000',
    usd_decimals: 2,
    syp_decimals: 0,
    expected_settings: snapshot,
  };
  backend._handleUpdateSalesSettings(values, { role: 'accountant', user_id: 'a' });
  assert.throws(
    () => backend._handleUpdateSalesSettings(values, { role: 'admin', user_id: 'b' }),
    error => error.code === 'SALES_SETTINGS_CONFLICT',
  );
  assert.equal(backend._getSalesSettings_().rate_syp_per_usd, 15000);
  assert.throws(
    () => backend._handleUpdateSalesSettings(values, { role: 'customer' }),
    error => error.message.includes('ليست لديك الصلاحية'),
  );
});

test('legacy sales role names normalize to the salesperson permission role', () => {
  const backend = loadBackend();
  assert.equal(backend._normalizeRole('user'), 'salesperson');
  assert.equal(backend._normalizeRole('مندوب مبيعات'), 'salesperson');
  assert.equal(backend._normalizeRole('unknown'), '');
});

test('branch manager cannot manage accounts; admin and accountant can', () => {
  const backend = loadBackend();
  assert.throws(
    () => backend._handleListUsers({}, { role: 'manager' }),
    error => error.message.includes('ليست لديك الصلاحية'),
  );
  assert.doesNotThrow(() =>
    backend._handleListUsers({}, { role: 'accountant' }),
  );
  assert.doesNotThrow(() => backend._handleListUsers({}, { role: 'admin' }));
});

test('only admin and accountant can void a posted sales invoice', () => {
  const backend = loadBackend();
  for (const role of ['manager', 'warehouse', 'salesperson', 'customer']) {
    assert.throws(
      () => backend._handleVoidSalesInvoice(
        { invoice_id: 'SI-1', reason: 'duplicate' },
        { role },
      ),
      error => error.message.includes('ليست لديك الصلاحية'),
    );
  }
});

test('branch manager can read sales invoice financial summaries', () => {
  const backend = loadBackend();
  const summary = backend._handleSalesSummary({}, { role: 'manager' });
  assert.equal(summary.invoices_count, 0);
});

test('full invoice settlement infers one valid historical SYP rate', () => {
  const backend = loadBackend({
    scriptProperties: {
      SALES_USD_DECIMALS: '2',
      SALES_SYP_DECIMALS: '0',
    },
  });
  const received = backend._normalizeSalesPaymentLines_([
    { method: 'cash_usd', amount: 40 },
    { method: 'cash_syp', amount: 900000 },
  ], { label: 'الاستلام' });
  const settlement = backend._completeSalesPaymentRates_(received, [], {
    settle_full: true,
    net_total: 100,
  });
  assert.equal(received[1].exchange_rate, 15000);
  assert.equal(received[1].equivalent_usd, 60);
  assert.equal(settlement.net_paid_usd, 100);
});

test('full settlement infers SYP refund from the remaining dollar difference', () => {
  const backend = loadBackend({
    scriptProperties: {
      SALES_USD_DECIMALS: '2',
      SALES_SYP_DECIMALS: '0',
    },
  });
  const received = backend._normalizeSalesPaymentLines_([
    { method: 'cash_usd', amount: 100 },
  ], { label: 'الاستلام' });
  const refunded = backend._normalizeSalesPaymentLines_([
    { method: 'sham_cash_usd', amount: 10 },
    { method: 'cash_syp', amount: 300000 },
  ], { label: 'الباقي المعاد' });
  const settlement = backend._completeSalesPaymentRates_(received, refunded, {
    settle_full: true,
    net_total: 70,
  });
  assert.equal(refunded[1].exchange_rate, 15000);
  assert.equal(refunded[1].equivalent_usd, 20);
  assert.equal(settlement.net_paid_usd, 70);
});

test('invoice collection is idempotent and restricted to the salesperson owner', () => {
  const backend = loadBackend({
    scriptProperties: {
      SALES_USD_DECIMALS: '2',
      SALES_SYP_DECIMALS: '0',
    },
  });
  const tables = {
    Sales_Invoices: [{
      invoice_id: 'SI-1',
      customer_id: 'customer-1',
      seller_id: 'seller-1',
      status: 'posted',
      currency: 'USD',
      net_total: 100,
      revision: 1,
      total_received_usd: 0,
      total_refunded_usd: 0,
    }],
    Sales_Invoice_Allocations: [],
    Payments: [],
    Customers: [{
      customer_id: 'customer-1',
      full_name: 'Customer One',
      status: 'active',
    }],
    Boxes_Balance: [
      { box_id: 'box_cash_usd', box_name: 'cash_box', currency: 'USD', balance: 0 },
      { box_id: 'box_sham_syp', box_name: 'sham_cash', currency: 'SYP', balance: 0 },
    ],
    Sales_Invoice_Audit: [],
  };
  backend._all = name => tables[name] || [];
  backend._requireColumns_ = () => {};
  backend._add = (name, row) => tables[name].push(row);
  backend._updateBoxBalance = (boxName, currency, amount, action) => {
    const box = tables.Boxes_Balance.find(
      row => row.box_name === boxName && row.currency === currency,
    );
    if (!box) throw new Error('box not found');
    box.balance += action === 'receive' ? amount : -amount;
  };
  backend._restoreBoxBalance_ = (boxName, currency, snapshot) => {
    const index = tables.Boxes_Balance.findIndex(
      row => row.box_name === boxName && row.currency === currency,
    );
    if (snapshot === null) {
      if (index >= 0) tables.Boxes_Balance.splice(index, 1);
    } else {
      Object.assign(tables.Boxes_Balance[index], snapshot);
    }
  };
  backend._updateByField = (name, field, value, updates) => {
    const row = tables[name].find(item => String(item[field]) === String(value));
    if (!row) return false;
    Object.assign(row, updates);
    return true;
  };
  backend._deleteRowsByField_ = (name, field, value) => {
    tables[name] = tables[name].filter(
      row => String(row[field]) !== String(value),
    );
  };

  const payload = {
    invoice_id: 'SI-1',
    client_request_id: 'collection-operation-0001',
    received_lines: [
      { method: 'cash_usd', amount: 40 },
      {
        method: 'sham_cash_syp',
        amount: 900000,
        equivalent_usd: 60,
        exchange_rate: 15000,
      },
    ],
  };
  assert.throws(
    () => backend._handleCollectSalesInvoice(payload, {
      user_id: 'seller-2',
      role: 'salesperson',
    }),
    error => error.code === 'ROLE_NOT_ALLOWED',
  );
  const result = backend._handleCollectSalesInvoice(payload, {
    user_id: 'seller-1',
    role: 'salesperson',
  });
  assert.equal(result.financial_status, 'paid');
  assert.equal(result.balance_due_usd, 0);
  assert.equal(tables.Boxes_Balance[0].balance, 40);
  assert.equal(tables.Boxes_Balance[1].balance, 900000);
  const duplicate = backend._handleCollectSalesInvoice(payload, {
    user_id: 'seller-1',
    role: 'salesperson',
  });
  assert.equal(duplicate.duplicate, true);
  assert.equal(tables.Payments.length, 2);
  assert.equal(tables.Sales_Invoice_Audit.length, 1);
});

test('new customer accounts require a supported customer type', () => {
  const backend = loadBackend();
  assert.throws(
    () => backend._validateManagedUser_({ full_name: 'Customer', role: 'customer' }),
    error => error.code === 'CUSTOMER_TYPE_REQUIRED',
  );
  assert.equal(
    backend._validateManagedUser_({
      full_name: 'Customer',
      role: 'customer',
      customer_type: 'زبون مفرق',
    }).customer_type,
    'زبون مفرق',
  );
});

test('ordinary audit snapshots omit internal account notes', () => {
  const backend = loadBackend();
  const snapshot = backend._managedUserSnapshot_({
    user_id: 'user-1',
    username: 'customer-one',
    role: 'customer',
    customer_type: 'زبون مفرق',
    internal_notes: 'private',
  });
  assert.equal(snapshot.customer_type, 'زبون مفرق');
  assert.equal('internal_notes' in snapshot, false);
});

test('temporary passwords restrict protected API actions until changed', () => {
  const backend = loadBackend({ mustChangePassword: 'yes' });
  const response = backend.doPost({
    postData: {
      contents: JSON.stringify({ action: 'getProducts', token: 'valid-token' }),
    },
  });
  const result = JSON.parse(response.content);
  assert.equal(result.ok, false);
  assert.equal(result.error.code, 'PASSWORD_CHANGE_REQUIRED');
});

test('protected API actions require a session token', () => {
  const backend = loadBackend();
  const response = backend.doPost({
    postData: { contents: JSON.stringify({ action: 'getOrders', username: 'customer-one' }) },
  });
  const result = JSON.parse(response.content);
  assert.equal(result.ok, false);
  assert.equal(result.error.code, 'AUTH_REQUIRED');
});

test('user administration action is not routed to self-profile update', () => {
  const backend = loadBackend();
  const response = backend.doPost({
    postData: {
      contents: JSON.stringify({ action: 'updateUser', token: 'valid-token' }),
    },
  });
  const result = JSON.parse(response.content);
  assert.equal(result.ok, false);
  assert.equal(result.error.code, 'UNKNOWN_ACTION');
});

test('warehouse product responses include stock quantities but exclude prices', () => {
  const backend = loadBackend();
  const product = backend._serializeProductForRole(
    { code: 'A1', name: 'Item', display_price: 12, quantity: 7 },
    'warehouse',
    '',
  );
  assert.equal('price' in product, false);
  assert.equal(product.quantity, 7);
  assert.equal(product.stock, 7);
});

test('global product stock preserves zero and negative quantities', () => {
  const backend = loadBackend();
  for (const quantity of [0, -4]) {
    const product = backend._serializeProductForRole(
      { code: 'A1', quantity, stock: 19, price: 99 },
      'warehouse',
      '',
    );
    assert.equal(product.quantity, quantity);
    assert.equal(product.stock, quantity);
    assert.equal('price' in product, false);
  }
});

test('customer balance honors explicitly zero approved price and quantity', () => {
  const backend = loadBackend();
  const tables = {
    Customers: [{ customer_id: 'C1', status: 'active', opening_usd: 0 }],
    Payments: [],
    Orders: [{ order_id: 'O1', customer_id: 'C1', status: 'approved', currency: 'USD' }],
    Order_Items: [
      { order_id: 'O1', final_price: 0, display_price_snapshot: 20,
        quantity_approved: 2, quantity_requested: 2 },
      { order_id: 'O1', final_price: 10, display_price_snapshot: 10,
        quantity_approved: 0, quantity_requested: 3 },
    ],
    Sales_Invoices: [],
  };
  backend._all = name => tables[name] || [];
  assert.equal(backend._handleGetCustomers({}, { role: 'manager' }).customers[0].balance, 0);
  const statement = backend._handleGetCustomerStatement({customer_id: 'C1'}, {role: 'manager'});
  assert.equal(statement.finalBalance, 0);
});

test('customer pages filter before pagination and keep the legacy full response', () => {
  const backend = loadBackend();
  const customers = Array.from({length: 105}, (_, i) => ({
    customer_id: `C${String(i).padStart(3, '0')}`,
    full_name: i % 2 ? 'Alpha' : 'Beta',
    phone: String(i),
    status: i === 3 ? 'inactive' : 'active',
  }));
  customers.push({customer_id: 'DELETED', full_name: 'Alpha', status: 'deleted'});
  backend._all = name => name === 'Customers' ? customers : [];
  const user = {role: 'manager'};
  assert.equal(backend._handleGetCustomers({}, user).customers.length, 105);
  const first = backend._handleGetCustomers(
    {limit: 20, query: 'alpha', status: 'active'}, user);
  assert.equal(first.customers.length, 20);
  assert.equal(first.next_offset, 20);
  const second = backend._handleGetCustomers(
    {limit: 20, offset: first.next_offset, query: 'alpha', status: 'active'}, user);
  assert.equal(new Set([...first.customers, ...second.customers]
    .map(c => c.customer_id)).size, 40);
  assert.equal(backend._handleGetCustomers(
    {limit: 100, query: 'alpha', status: 'inactive'}, user).customers.length, 1);
  assert.throws(() => backend._handleGetCustomers({limit: 101}, user));
  assert.throws(() => backend._handleGetCustomers({limit: 10}, {role: 'customer'}));
});

test('commercial customer types come only from linked login accounts and are role restricted', () => {
  const backend = loadBackend();
  const tables = {
    Customers: [{customer_id: 'C1', full_name: 'Customer'}],
    Users: [
      {customer_id: 'C1', role: 'customer', customer_type: 'زبون جملة'},
      {customer_id: 'C1', role: 'customer', customer_type: 'زبون جملة'},
      {customer_id: 'C1', role: 'salesperson', customer_type: 'other'},
    ],
  };
  backend._all = name => tables[name] || [];
  for (const role of ['admin', 'manager', 'accountant']) {
    const result = backend._handleGetCustomers({}, {role});
    assert.deepEqual(Array.from(result.customers[0].login_customer_types), ['زبون جملة']);
  }
  for (const role of ['customer', 'salesperson', 'warehouse']) {
    assert.throws(() => backend._handleGetCustomers({}, {role}));
  }
  const sales = backend._handleSalesCustomerList({}, {role: 'salesperson'});
  assert.equal(sales.customers[0].login_customer_types, undefined);
});

test('historical currencies do not masquerade as complete USD balances', () => {
  const backend = loadBackend({scriptProperties: {
    SALES_USD_DECIMALS: '2', SALES_SYP_DECIMALS: '0',
  }});
  const tables = {
    Customers: [{customer_id: 'C1', status: 'active', opening_usd: 10, opening_syp: 100}],
    Payments: [{customer_id: 'C1', currency: 'SYP', amount: 5000,
      invoice_currency: 'SYP', invoice_equivalent: 5000, exchange_rate: 1000}],
    Orders: [{order_id: 'O1', customer_id: 'C1', status: 'approved', currency: 'EUR'}],
    Order_Items: [{order_id: 'O1', final_price: 7, quantity_approved: 1}],
    Sales_Invoices: [],
  };
  backend._all = name => tables[name] || [];
  assert.equal(backend._paymentEquivalentUsd_(tables.Payments[0]), 5);
  const customer = backend._handleGetCustomers({}, {role: 'manager'}).customers[0];
  assert.equal(customer.balance, 5);
  assert.equal(customer.needs_financial_review, true);
  const statement = backend._handleGetCustomerStatement({customer_id: 'C1'}, {role: 'manager'});
  assert.equal(statement.finalBalance, 5);
  assert.equal(statement.needs_manual_review, true);
  assert.equal(statement.statement.filter(row => row.needs_manual_review).length, 2);
});

test('proxy confirmation is restricted to priced orders and authorized staff', () => {
  const backend = loadBackend();
  for (const role of ['admin', 'manager', 'accountant']) {
    assert.doesNotThrow(() => backend._validateStateTransition(
      'priced', 'customer_confirmed', role, { proxyForCustomer: true },
    ));
    assert.throws(() => backend._validateStateTransition(
      'approved', 'customer_confirmed', role, { proxyForCustomer: true },
    ));
  }
  for (const role of ['warehouse', 'salesperson']) {
    assert.throws(() => backend._validateStateTransition(
      'priced', 'customer_confirmed', role, { proxyForCustomer: true },
    ));
  }
});

test('proxy confirmation audits the actor and rejects a repeated transition', () => {
  const backend = loadBackend();
  const order = {
    order_id: 'ORDER-1',
    customer_id: 'CUSTOMER-1',
    status: 'priced',
  };
  const audit = [];
  backend._all = name => name === 'Orders' ? [{ ...order }] : [];
  backend._updateByField = (table, key, id, updates) => {
    assert.equal(table, 'Orders');
    Object.assign(order, updates);
  };
  backend._dispatchStatusNotifications = () => {};
  backend._add = (table, entry) => {
    if (table === 'Audit_Log') audit.push(entry);
  };
  const request = {
    order_id: 'ORDER-1',
    status: 'customer_confirmed',
    proxy_for_customer: true,
    reason: 'طلب الزبون',
  };
  const user = { user_id: 'MANAGER-1', role: 'manager' };
  const result = backend._handleUpdateOrderStatus(request, user);
  assert.equal(result.status, 'customer_confirmed');
  assert.equal(audit.length, 1);
  assert.equal(audit[0].user_id, 'MANAGER-1');
  assert.match(audit[0].details, /manager/);
  assert.match(audit[0].details, /priced/);
  assert.match(audit[0].details, /customer_confirmed/);
  assert.match(audit[0].details, /طلب الزبون/);
  assert.throws(() => backend._handleUpdateOrderStatus(request, user));
  assert.equal(audit.length, 1);
});

test('proxy endpoint refuses unauthorized roles and missing reasons before mutation', () => {
  const backend = loadBackend();
  const request = {
    order_id: 'ORDER-1',
    status: 'customer_confirmed',
    proxy_for_customer: true,
    reason: 'طلب الزبون',
  };
  for (const role of ['warehouse', 'salesperson', 'customer']) {
    assert.throws(() => backend._handleUpdateOrderStatus(
      request, { user_id: 'U1', role },
    ));
  }
  assert.throws(() => backend._handleUpdateOrderStatus(
    { ...request, reason: '  ' }, { user_id: 'U1', role: 'accountant' },
  ));
  assert.throws(() => backend._handleUpdateOrderStatus(
    { ...request, status: 'approved' }, { user_id: 'U1', role: 'manager' },
  ));
});

test('product serialization preserves catalog details and optional availability status', () => {
  const backend = loadBackend();
  const product = backend._serializeProductForRole(
    {
      code: 'A1',
      name: 'Item',
      group: 'Engines',
      sub_group: 'Pistons',
      origin: 'Japan',
      oem: 'OEM-101',
      availability_status: 'preorder',
    },
    'customer',
    '',
  );
  assert.equal(product.group, 'Engines');
  assert.equal(product.sub_group, 'Pistons');
  assert.equal(product.origin, 'Japan');
  assert.equal(product.oem, 'OEM-101');
  assert.equal(product.availability_status, 'preorder');
});

test('product search matches OEM numbers', () => {
  const backend = loadBackend();
  backend._all = name => {
    if (name === 'Products') {
      return [
        {
          code: 'A1',
          name: 'Item',
          group: 'Engines',
          sub_group: 'Pistons',
          oem: 'OEM-101',
        },
      ];
    }
    return [];
  };

  const result = backend._handleSearchProducts(
    { q: 'OEM-101' },
    { role: 'customer' },
  );
  assert.deepEqual(
    JSON.parse(JSON.stringify(result.products.map(product => product.code))),
    ['A1'],
  );
});

test('warehouse dashboard does not reveal stock availability', () => {
  const backend = loadBackend();
  const result = backend._handleDashboardStats({}, { role: 'warehouse' });
  assert.equal(
    result.stats.some(stat => stat.title === 'منتجات منخفضة المخزون'),
    false,
  );
});

test('new products are ordered by their recorded creation date only', () => {
  const backend = loadBackend();
  backend._all = name => {
    if (name === 'Products') {
      return [{ code: 'NEW', image_name: 'newer.png' }];
    }
    if (name === 'Product_Images') {
      return [
        {
          normalized_name: 'newer',
          image_url: 'https://images.example/newer.png',
          status: 'active',
        },
      ];
    }
    if (name === 'New_Products') {
      return [
        {
          code: 'OLD',
          name: 'Older',
          show_in_new: true,
          created_at: '2026-10-01T10:00:00.000Z',
        },
        {
          code: 'UNDATED',
          name: 'Undated',
          show_in_new: true,
        },
        {
          code: 'NEW',
          name: 'Newer',
          show_in_new: true,
          created_at: '2026-11-01T10:00:00.000Z',
        },
      ];
    }
    return [];
  };

  const result = backend._handleNewProducts({}, { role: 'customer' });
  assert.deepEqual(
    JSON.parse(JSON.stringify(result.products.map(product => product.code))),
    ['NEW', 'OLD'],
  );
  assert.equal(result.products[0].created_at, '2026-11-01T10:00:00.000Z');
  assert.equal(
    result.products[0].image_url,
    'https://images.example/newer.png',
  );
});

test('product catalog carries the recorded date for products in both sheets', () => {
  const backend = loadBackend();
  backend._all = name => {
    if (name === 'Products') {
      return [{ code: 'A', name: 'Catalog product' }];
    }
    if (name === 'New_Products') {
      return [
        {
          code: 'A',
          name: 'Catalog product',
          created_at: '2026-11-01T10:00:00.000Z',
        },
      ];
    }
    return [];
  };

  const result = backend._handleProducts({}, { role: 'customer' });
  assert.equal(result.products[0].created_at, '2026-11-01T10:00:00.000Z');
});

test('best sellers count approved units from recent orders, never cancelled orders', () => {
  const backend = loadBackend();
  const now = new Date();
  const recent = now.toISOString();
  const old = new Date(now.getTime() - 31 * 24 * 60 * 60 * 1000).toISOString();
  backend._all = name => {
    if (name === 'Orders') {
      return [
        { order_id: 'approved', status: 'approved', created_at: recent },
        { order_id: 'prepared', status: 'prepared', created_at: recent },
        { order_id: 'cancelled', status: 'cancelled', created_at: recent },
        { order_id: 'pending', status: 'pending', created_at: recent },
        { order_id: 'old', status: 'approved', created_at: old },
      ];
    }
    if (name === 'Order_Items') {
      return [
        { order_id: 'approved', code: 'A', quantity_approved: 2 },
        { order_id: 'prepared', code: 'A', quantity_approved: 3 },
        { order_id: 'cancelled', code: 'B', quantity_approved: 100 },
        { order_id: 'pending', code: 'C', quantity_approved: 200 },
        { order_id: 'old', code: 'D', quantity_approved: 300 },
      ];
    }
    if (name === 'Products') {
      return [
        { code: 'A', name: 'Product A', display_price: 10 },
        { code: 'B', name: 'Product B' },
        { code: 'C', name: 'Product C' },
        { code: 'D', name: 'Product D' },
      ];
    }
    return [];
  };

  const result = backend._handleBestSellers({}, { role: 'customer' });
  assert.deepEqual(
    JSON.parse(JSON.stringify(result.products.map(product => product.code))),
    ['A'],
  );
  assert.equal(result.products[0].order_units, 5);
  assert.equal('customer_name' in result.products[0], false);
});

test('order retry never reports success for a partially saved order', () => {
  const backend = loadBackend();
  const order = {order_id: 'O1', order_number: 'N1',
    customer_id: 'customer-1', client_request_id: 'REQ-1'};
  const saved = [{order_id: 'O1'}];
  backend._all = table => table === 'Orders' ? [order] :
    table === 'Order_Items' ? saved : [];
  const request = {customer_id: 'customer-1', client_request_id: 'REQ-1',
    items: [{code: 'A'}, {code: 'B'}]};
  const user = {role: 'customer', customer_id: 'customer-1'};
  assert.throws(() => backend._handleCreateOrder(request, user),
    error => error.code === 'ORDER_RETRY_INCOMPLETE');
  saved.push({order_id: 'O1'});
  const result = backend._handleCreateOrder(request, user);
  assert.equal(result.is_duplicate, true);
  assert.equal(result.order_id, 'O1');
});

test('customer cannot access another customer order', () => {
  const backend = loadBackend();
  assert.throws(
    () => backend._requireOrderOwnership(
      { role: 'customer', customer_id: 'customer-1' },
      { order_id: 'order-2', customer_id: 'customer-2' },
    ),
    error => error.code === 'FORBIDDEN',
  );
});

test('notification role targeting includes only active intended roles', () => {
  const backend = loadBackend();
  const sent = [];
  backend._all = name => {
    if (name !== 'Users') return [];
    return [
      { user_id: 'admin-1', role: 'admin', status: 'active' },
      { user_id: 'acct-1', role: 'accountant', status: 'active' },
      { user_id: 'warehouse-1', role: 'warehouse', status: 'active' },
      { user_id: 'inactive-acct', role: 'accountant', status: 'inactive' },
    ];
  };
  backend._sendNotification = (userId, title, body, metadata) => {
    sent.push({ userId, metadata });
  };

  backend._sendNotificationToRoles(
    'admin,accountant',
    'طلب جديد',
    'إشعار آمن',
    'order.created',
    'order-1',
    { order_id: 'order-1' },
  );
  assert.deepEqual(
    JSON.parse(JSON.stringify(sent.map(item => item.userId))),
    ['admin-1', 'acct-1'],
  );
  assert.equal(sent[0].metadata.target_role, 'admin');
  assert.equal(sent[1].metadata.target_role, 'accountant');
});

test('non-admin users cannot send arbitrary notifications', () => {
  const backend = loadBackend();
  assert.throws(
    () => backend._handleSendNotification(
      { user_ids: ['user-1'], title: 'test', body: 'test' },
      { user_id: 'user-1', role: 'customer' },
    ),
    error => error.code === 'FORBIDDEN',
  );
});

test('notification channel mapping follows event category', () => {
  const backend = loadBackend();
  assert.equal(backend._notificationChannel_('order.created'), 'orders');
  assert.equal(backend._notificationChannel_('invoice.created'), 'invoices');
  assert.equal(
    backend._notificationChannel_('warehouse.prepared'),
    'warehouse',
  );
  assert.equal(backend._notificationChannel_('shipping.shipped'), 'shipping');
  assert.equal(backend._notificationChannel_('alert.low_stock'), 'alerts');
  assert.equal(backend._notificationChannel_('general.notice'), 'general');
});

test('FCM HTTP v1 sends display text and keeps routing data separate', () => {
  const backend = loadBackend({
    scriptProperties: {
      FCM_SERVICE_ACCOUNT_JSON: JSON.stringify({
        project_id: 'orca-order',
        client_email: 'sender@example.test',
        private_key: 'not-used-by-this-test',
      }),
    },
  });
  backend._getFcmAccessToken_ = () => 'test-access-token';
  let requestUrl;
  let request;
  backend.UrlFetchApp = {
    fetch(url, options) {
      requestUrl = url;
      request = options;
      return {
        getResponseCode: () => 200,
        getContentText: () => '{"name":"projects/orca-order/messages/1"}',
      };
    },
  };

  backend._sendFcmMessage_(
    'test-installation-id',
    {
      title: 'طلب جديد',
      body: 'تم استلام طلب جديد.',
      notification_id: 'notification-1',
      event_id: 'order.created:request-1',
      type: 'order.created',
      entity_type: 'order',
      entity_id: 'order-1',
      channel_id: 'orders',
    },
    true,
    'fid',
  );

  assert.match(requestUrl, /projects\/orca-order\/messages:send$/);
  const message = JSON.parse(request.payload).message;
  assert.equal(message.fid, 'test-installation-id');
  assert.equal('token' in message, false);
  assert.deepEqual(
    JSON.parse(JSON.stringify(message.notification)),
    { title: 'طلب جديد', body: 'تم استلام طلب جديد.' },
  );
  assert.equal(message.data.notification_id, 'notification-1');
  assert.equal(message.data.event_id, 'order.created:request-1');
  assert.equal(message.data.entity_id, 'order-1');
  assert.equal('title' in message.data, false);
  assert.equal('body' in message.data, false);
  assert.equal(message.android.notification.channel_id, 'orders');
});

test('FCM HTTP v1 preserves legacy registration-token targeting', () => {
  const backend = loadBackend({
    scriptProperties: {
      FCM_SERVICE_ACCOUNT_JSON: JSON.stringify({
        project_id: 'orca-order',
        client_email: 'sender@example.test',
        private_key: 'not-used-by-this-test',
      }),
    },
  });
  backend._getFcmAccessToken_ = () => 'test-access-token';
  let request;
  backend.UrlFetchApp = {
    fetch(_url, options) {
      request = options;
      return {
        getResponseCode: () => 200,
        getContentText: () => '{"name":"projects/orca-order/messages/1"}',
      };
    },
  };

  backend._sendFcmMessage_('legacy-registration-token', {
    title: 'Notice',
    body: 'A new notice.',
    notification_id: 'notification-legacy',
    channel_id: 'general',
  }, false);

  const message = JSON.parse(request.payload).message;
  assert.equal(message.token, 'legacy-registration-token');
  assert.equal('fid' in message, false);
});

test('FCM errors are categorized without retaining response payloads', () => {
  const backend = loadBackend({
    scriptProperties: {
      FCM_SERVICE_ACCOUNT_JSON: JSON.stringify({
        project_id: 'orca-order',
        client_email: 'sender@example.test',
        private_key: 'not-used-by-this-test',
      }),
    },
  });
  backend._getFcmAccessToken_ = () => 'test-access-token';
  backend.UrlFetchApp = {
    fetch() {
      return {
        getResponseCode: () => 404,
        getContentText: () => JSON.stringify({
          error: {
            status: 'NOT_FOUND',
            details: [{
              '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
              errorCode: 'UNREGISTERED',
            }],
          },
        }),
      };
    },
  };

  assert.throws(
    () => backend._sendFcmMessage_(
      'do-not-log-this-target',
      { title: 'Test', body: 'Test' },
      false,
    ),
    /FCM_UNREGISTERED_HTTP_404/,
  );
});

test('response envelope carries canonical status, data, error, and version', () => {
  const backend = loadBackend();
  const response = JSON.parse(
    backend._apiResponse({ result: 1 }, null, 'request-1').content,
  );
  assert.equal(response.ok, true);
  assert.equal(response.success, true);
  assert.deepEqual(JSON.parse(JSON.stringify(response.data)), { result: 1 });
  assert.equal(response.error, null);
  assert.equal(response.request_id, 'request-1');
  assert.equal(response.api_version, '1.3.0');
});

test('error envelope carries null data and a structured error', () => {
  const backend = loadBackend();
  const response = JSON.parse(
    backend._apiResponse(
      null,
      backend._apiError('AUTH_REQUIRED', 'Sign in required', false),
      'request-2',
    ).content,
  );
  assert.equal(response.ok, false);
  assert.equal(response.success, false);
  assert.equal(response.data, null);
  assert.deepEqual(
    JSON.parse(JSON.stringify(response.error)),
    { code: 'AUTH_REQUIRED', message: 'Sign in required', retryable: false },
  );
});

test('annual order sequence persists across days and resets only by year', () => {
  const backend = loadBackend();
  const existingOrders = [{ order_number: 'ORD-260101-00007' }];

  assert.equal(
    backend._generateOrderNumber(
      existingOrders,
      new Date('2026-01-02T10:00:00.000Z'),
    ),
    'ORD-260102-00008',
  );
  assert.equal(
    backend._generateOrderNumber(
      existingOrders,
      new Date('2026-01-03T10:00:00.000Z'),
    ),
    'ORD-260103-00009',
  );
  assert.equal(
    backend._generateOrderNumber(
      [],
      new Date('2027-01-01T10:00:00.000Z'),
    ),
    'ORD-270101-00001',
  );
});

test('annual order sequence rejects overflow instead of changing its format', () => {
  const backend = loadBackend({
    scriptProperties: { SEQ_ORD_26: '99999' },
  });
  assert.throws(
    () => backend._generateOrderNumber([], new Date('2026-12-31T23:59:00Z')),
    error => error.code === 'ORDER_SEQUENCE_EXHAUSTED',
  );
});

test('annual SAL sequence is shared across days, recovers safely, and resets by year', () => {
  const backend = loadBackend({
    scriptProperties: { SEQ_SAL_26: '500001', SEQ_ORD_26: '7' },
  });
  const existingInvoices = [{ invoice_number: 'SAL-261115-500009' }];

  assert.equal(
    backend._generateSalesInvoiceNumber_(
      existingInvoices,
      new Date('2026-11-15T10:00:00.000Z'),
    ),
    'SAL-261115-500010',
  );
  assert.equal(
    backend._generateSalesInvoiceNumber_(
      existingInvoices,
      new Date('2026-11-16T10:00:00.000Z'),
    ),
    'SAL-261116-500011',
  );
  assert.equal(
    backend._generateSalesInvoiceNumber_(
      [],
      new Date('2027-01-01T10:00:00.000Z'),
    ),
    'SAL-270101-500001',
  );
  assert.equal(backend.PropertiesService.getScriptProperties()
    .getProperty('SEQ_ORD_26'), '7');
});

test('annual SAL sequence refuses overflow and invalid counters', () => {
  const exhausted = loadBackend({
    scriptProperties: { SEQ_SAL_26: '999999' },
  });
  assert.throws(
    () => exhausted._generateSalesInvoiceNumber_(
      [],
      new Date('2026-12-31T23:59:00Z'),
    ),
    error => error.code === 'SALES_INVOICE_SEQUENCE_EXHAUSTED',
  );

  const invalid = loadBackend({
    scriptProperties: { SEQ_SAL_26: '500000x' },
  });
  assert.throws(
    () => invalid._generateSalesInvoiceNumber_(
      [],
      new Date('2026-12-31T23:59:00Z'),
    ),
    error => error.code === 'SALES_INVOICE_SEQUENCE_INVALID',
  );
});

test('sales invoice create is role-checked, globally numbered and idempotent', () => {
  const backend = loadBackend({
    scriptProperties: {
      SALES_INVOICE_CURRENCY: 'USD',
      SALES_USD_DECIMALS: '2',
      SALES_SYP_DECIMALS: '0',
    },
  });
  let uuid = 0;
  backend.Utilities.getUuid = () => `uuid-${++uuid}`;
  const tables = {
    Users: [
      { user_id: 'sales-1', role: 'salesperson', status: 'active' },
      { user_id: 'manager-1', role: 'manager', status: 'active' },
      { user_id: 'accountant-1', role: 'accountant', status: 'active' },
      { user_id: 'admin-1', role: 'admin', status: 'active' },
    ],
    Customers: [
      { customer_id: 'customer-1', full_name: 'Customer', status: 'active' },
    ],
    Products: [
      { code: 'P-1', name: 'Part', unit_1: 'piece', currency: 'USD', quantity: 50 },
    ],
    Sales_Invoices: [],
    Sales_Invoice_Items: [],
    Sales_Invoice_Audit: [],
    Sales_Invoice_Allocations: [],
    Inventory_Movements: [],
    Payments: [],
  };
  backend._all = name => tables[name] || [];
  backend._add = (name, row) => tables[name].push(row);
  backend._requireColumns_ = () => {};
  backend._setProductStockQuantity_ = (code, quantity) => {
    tables.Products.find(product => product.code === code).quantity = quantity;
  };
  backend._cashBoxSnapshot_ = () => ({});
  backend._restoreBoxBalance_ = () => {};
  backend._writeSalesPayment_ = (line, input) => {
    const payment = {
      payment_id: `payment-${tables.Payments.length + 1}`,
      order_id: input.invoice_id,
      action_type: input.action_type,
      ...line,
    };
    tables.Payments.push(payment);
    return payment;
  };
  backend._updateByField = (name, field, value, updates) => {
    const row = tables[name].find(item => String(item[field]) === String(value));
    if (!row) return false;
    Object.assign(row, updates);
    return true;
  };
  backend._deleteRowsByField_ = (name, field, value) => {
    tables[name] = tables[name].filter(
      row => String(row[field]) !== String(value),
    );
  };
  const receivedLines = [
    { method: 'cash_usd', amount: 5 },
    { method: 'sham_cash_usd', amount: 5 },
    { method: 'cash_syp', amount: 75000, exchange_rate: 15000 },
    { method: 'sham_cash_syp', amount: 75000, exchange_rate: 15000 },
  ];
  const invoiceBody = {
    client_request_id: 'same-request-id-12345',
    customer_id: 'customer-1',
    items: [{ code: 'P-1', quantity: 1, unit_price: 20 }],
    discount: 1,
    received_lines: receivedLines,
    refunded_lines: [{ method: 'cash_usd', amount: 1 }],
  };

  const salespersonInvoice = backend._handleCreateSalesInvoiceV2(
    invoiceBody,
    { user_id: 'sales-1', role: 'salesperson' },
  );
  assert.match(salespersonInvoice.invoice_number, /^SAL-\d{6}-500001$/);
  assert.equal(salespersonInvoice.invoice.created_by_role, 'salesperson');
  assert.equal(salespersonInvoice.invoice.seller_id, 'sales-1');
  assert.equal(salespersonInvoice.financial_status, 'paid');
  assert.equal(salespersonInvoice.total_received_usd, 20);
  assert.equal(salespersonInvoice.total_refunded_usd, 1);
  assert.equal(salespersonInvoice.net_paid_usd, 19);
  assert.equal(tables.Payments.length, 5);
  assert.equal(tables.Products[0].quantity, 49);

  const duplicate = backend._handleCreateSalesInvoiceV2(
    invoiceBody,
    { user_id: 'sales-1', role: 'salesperson' },
  );
  assert.equal(duplicate.duplicate, true);
  assert.equal(duplicate.invoice_number, salespersonInvoice.invoice_number);
  assert.equal(tables.Sales_Invoices.length, 1);
  assert.equal(tables.Payments.length, 5);
  assert.equal(tables.Inventory_Movements.length, 1);
  assert.equal(tables.Products[0].quantity, 49);
  const searchResults = backend._handleListSalesInvoicesV2(
    { query: salespersonInvoice.invoice_number.slice(0, 10) },
    { user_id: 'admin-1', role: 'admin' },
  );
  assert.equal(searchResults.invoices.length, 1);
  assert.equal(
    searchResults.invoices[0].invoice_number,
    salespersonInvoice.invoice_number,
  );

  for (const [userId, role] of [
    ['manager-1', 'manager'],
    ['accountant-1', 'accountant'],
    ['admin-1', 'admin'],
  ]) {
    const result = backend._handleCreateSalesInvoiceV2(
      {
        ...invoiceBody,
        client_request_id: `${role}-request-123456`,
        received_lines: [],
        refunded_lines: [],
        discount: 0,
      },
      { user_id: userId, role },
    );
    assert.match(result.invoice_number, /^SAL-\d{6}-50000[234]$/);
    assert.equal(result.invoice.created_by, userId);
    assert.equal(result.invoice.created_by_role, role);
    assert.equal(result.invoice.seller_id, '');
  }
  assert.equal(tables.Products[0].quantity, 46);

  const numberBeforeVoid = salespersonInvoice.invoice_number;
  backend._handleVoidSalesInvoice(
    {
      invoice_id: salespersonInvoice.invoice_id,
      reason: 'duplicate sale',
      client_request_id: 'void-request-123456',
    },
    { user_id: 'admin-1', role: 'admin' },
  );
  assert.equal(tables.Products[0].quantity, 47);
  assert.equal(
    tables.Sales_Invoices[0].invoice_number,
    numberBeforeVoid,
  );
  assert.equal(tables.Payments.length, 5);

  assert.throws(
    () => backend._handleCreateSalesInvoiceV2(
      {
        ...invoiceBody,
        client_request_id: 'rejected-role-request-123',
      },
      { user_id: 'customer-1', role: 'customer' },
    ),
    error => error.message.includes('ليست لديك الصلاحية'),
  );
  assert.equal(tables.Products[0].quantity, 47);
});

test('order cancellation writes by actual sheet headers and is idempotent', () => {
  const backend = loadBackend({ role: 'admin' });
  const headers = [
    'order_id',
    'customer_id',
    'customer_name',
    'status',
    'cancellation_reason',
    'created_at',
    'updated_at',
    'cancelled_at',
    'cancelled_by',
  ];
  const row = ['order-1', 'customer-1', 'Customer', 'pending', '', '', '', '', ''];
  const writes = [];
  backend._all = name => {
    if (name === 'Orders') {
      return [{
        order_id: row[0],
        customer_id: row[1],
        status: row[3],
        order_number: 'ORD-260101-00001',
      }];
    }
    return [];
  };
  backend._ss = () => ({
    getSheetByName: () => ({
      getRange: (rowNumber, columnNumber) => ({
        setValue(value) {
          writes.push({ rowNumber, columnNumber, value });
          row[columnNumber - 1] = value;
        },
      }),
    }),
  });
  backend._getHeaders = () => headers;
  let reversals = 0;
  backend._reverseOrderInventoryForCancellation_ = () => reversals++;
  backend._add = () => {};
  backend._sendNotificationToRoles = () => {};
  backend._sendNotification = () => {};

  const user = { user_id: 'admin-1', role: 'admin' };
  const first = backend._handleCancelOrder(
    { order_id: 'order-1', reason: 'duplicate' },
    user,
  );
  const second = backend._handleCancelOrder(
    { order_id: 'order-1', reason: 'duplicate' },
    user,
  );

  assert.equal(first.status, 'cancelled');
  assert.equal(second.is_duplicate, true);
  assert.equal(row[1], 'customer-1');
  assert.equal(row[3], 'cancelled');
  assert.equal(row[4], 'duplicate');
  assert.equal(reversals, 1);
  assert.ok(writes.every(write => write.rowNumber === 2));
});
