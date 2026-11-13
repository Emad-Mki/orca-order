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
      newBlob: value => ({
        getBytes: () => Array.from(Buffer.from(String(value), 'utf8')),
      }),
      computeHmacSha256Signature: () => {
        throw new Error('PBKDF2 must not call Utilities once per round');
      },
    },
    PropertiesService: { getScriptProperties: () => scriptProperties },
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
  assert.equal(config.cash_box_configured, true);
  assert.equal('settings' in config, false);
  assert.equal('SALES_INVOICE_CURRENCY' in config, false);

  const missingCurrency = loadBackend();
  missingCurrency._all = () => [];
  const missingConfig = missingCurrency._handleSalesConfiguration({}, {
    user_id: 'user-1',
    role: 'salesperson',
  });
  assert.equal(missingConfig.invoice_currency, '');
});

test('sales settings update Script Properties only after full validation', () => {
  const backend = loadBackend();
  const changes = [];
  backend._add = (sheet, record) => changes.push({ sheet, record });
  const result = backend._handleUpdateSalesSettings(
    {
      invoice_currency: ' syp ',
      sham_cash_currency: 'usd',
      default_product_currency: 'USD',
      rate_syp_per_usd: '14500',
      usd_decimals: 2,
      syp_decimals: 0,
    },
    { role: 'admin', user_id: 'admin-1' },
  );
  assert.equal(result.settings.invoice_currency, 'SYP');
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

test('branch manager cannot read the newly added seller financial summaries', () => {
  const backend = loadBackend();
  assert.throws(
    () => backend._handleSalesSummary({}, { role: 'manager' }),
    error => error.message.includes('ليست لديك الصلاحية'),
  );
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

test('product serialization preserves group, subgroup, origin, and OEM fields', () => {
  const backend = loadBackend();
  const product = backend._serializeProductForRole(
    {
      code: 'A1',
      name: 'Item',
      group: 'Engines',
      sub_group: 'Pistons',
      origin: 'Japan',
      oem: 'OEM-101',
    },
    'customer',
    '',
  );
  assert.equal(product.group, 'Engines');
  assert.equal(product.sub_group, 'Pistons');
  assert.equal(product.origin, 'Japan');
  assert.equal(product.oem, 'OEM-101');
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
