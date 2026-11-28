const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '..', 'Code.gs'), 'utf8');

function createServer() {
  const tables = {
    Users: [[
      'user_id', 'username', 'password_hash', 'salt', 'full_name', 'phone',
      'role', 'status', 'must_change_password', 'updated_at', 'updated_by',
    ], [
      'user-1', 'user-one', 'hash:currentPass123', 'salt-1', 'Old Name', '',
      'customer', 'active', false, '', '',
    ]],
    Sessions: [['token', 'user_id', 'expires_at']],
    Audit_Log: [[
      'log_id', 'user_id', 'action', 'entity', 'entity_id', 'details',
      'created_at',
    ]],
    App_Settings: [['key', 'value', 'updated_at', 'updated_by']],
    Support_Tickets: [[
      'ticket_id', 'user_id', 'username', 'created_at', 'type', 'description',
      'diagnostics_json', 'attachment_base64', 'status', 'response',
      'updated_at', 'updated_by',
    ]],
    Customers: [[
      'customer_id', 'full_name', 'phone',
    ], [
      'customer-1', 'Old Name', '',
    ]],
  };
  const cacheValues = new Map();
  const revokedUsers = [];
  const context = vm.createContext({
    Date,
    JSON,
    Math,
    Object,
    Array,
    String,
    Number,
    Error,
    RegExp,
    Utilities: {
      getUuid: () => 'uuid-12345678',
      formatDate: () => '20261128',
      base64Decode: value => Array.from(Buffer.from(value, 'base64')),
    },
    CacheService: {
      getScriptCache: () => ({
        get: key => cacheValues.get(key) ?? null,
        put: (key, value) => cacheValues.set(key, value),
        remove: key => cacheValues.delete(key),
      }),
    },
    LockService: {
      getScriptLock: () => ({
        tryLock: () => true,
        releaseLock() {},
      }),
    },
  });
  vm.runInContext(source, context);

  context._ss = () => ({
    getSheetByName: name => ({
      getDataRange: () => ({ getValues: () => tables[name] || [] }),
    }),
  });
  context._all = name => {
    const [headers, ...rows] = tables[name] || [];
    if (!headers) return [];
    return rows.map(row =>
      Object.fromEntries(headers.map((header, index) => [header, row[index]])),
    );
  };
  context._updateByField = (name, field, key, updates) => {
    const [headers, ...rows] = tables[name] || [];
    if (!headers) return false;
    const keyIndex = headers.indexOf(field);
    const rowIndex = rows.findIndex(row => String(row[keyIndex]) === String(key));
    if (rowIndex < 0) return false;
    for (const [updateKey, value] of Object.entries(updates)) {
      const column = headers.indexOf(updateKey);
      if (column >= 0) tables[name][rowIndex + 1][column] = value;
    }
    return true;
  };
  context._add = (name, values) => {
    const headers = tables[name]?.[0];
    if (!headers) throw new Error(`Missing sheet ${name}`);
    tables[name].push(headers.map(header => values[header] ?? ''));
  };
  context._ensureFeatureSheets_ = () => {};
  context._apiError = (code, message) => Object.assign(new Error(message), { code });
  context._normalizeRole = role => String(role || '').toLowerCase();
  context._digest = value => String(value);
  context._now = () => '2026-11-28T00:00:00.000Z';
  context._passwordHash_ = (password, salt) => `hash:${password}:${salt}`;
  context._verifyPassword_ = (password, user) =>
    user.password_hash === `hash:${password}` ||
    user.password_hash === `hash:${password}:${user.salt}`;
  context._removeSessionsForUser_ = userId => revokedUsers.push(userId);
  context._deactivateAllUserDevices_ = userId => revokedUsers.push(userId);
  return { context, tables, revokedUsers };
}

test('ordinary accounts cannot change their full name through the API', () => {
  const { context, tables } = createServer();
  assert.throws(
    () => context._handleUpdateUser(
      { full_name: 'Forged Name' },
      { user_id: 'user-1', role: 'customer' },
    ),
    error => error.code === 'FORBIDDEN',
  );
  assert.equal(tables.Users[1][4], 'Old Name');
});

test('admin and accountant name changes are audited with old and new values', () => {
  for (const role of ['admin', 'manager', 'accountant']) {
    const { context, tables } = createServer();
    context._handleUpdateUser(
      { full_name: 'New Name' },
      { user_id: 'user-1', customer_id: 'customer-1', role },
    );
    assert.equal(tables.Users[1][4], 'New Name');
    assert.equal(tables.Customers[1][1], 'New Name');
    const audit = tables.Audit_Log[1];
    assert.equal(audit[2], 'UPDATE_USER_NAME');
    assert.match(audit[5], /Old Name/);
    assert.match(audit[5], /New Name/);
  }
});

test('successful password changes sync the account name and revoke sessions', () => {
  const { context, tables, revokedUsers } = createServer();
  const response = context._handleUpdateUser({
    full_name: 'New Name',
    old_password: 'currentPass123',
    new_password: 'newPass12345',
  }, {
    user_id: 'user-1',
    customer_id: 'customer-1',
    role: 'accountant',
  });
  assert.equal(response.session_revoked, true);
  assert.equal(tables.Users[1][4], 'New Name');
  assert.equal(tables.Customers[1][1], 'New Name');
  assert.deepEqual(revokedUsers, ['user-1', 'user-1']);
  assert.doesNotMatch(tables.Audit_Log[1][5], /currentPass123|newPass12345/);
});

test('wrong current passwords are rate limited without recording secrets', () => {
  const { context, tables } = createServer();
  const actor = { user_id: 'user-1', role: 'customer' };
  for (let attempt = 0; attempt < 5; attempt++) {
    assert.throws(
      () => context._handleUpdateUser(
        { old_password: 'wrong-password', new_password: 'newPass12345' },
        actor,
      ),
      error => error.code === 'INVALID_CREDENTIALS',
    );
  }
  assert.throws(
    () => context._handleUpdateUser(
      { old_password: 'wrong-password', new_password: 'newPass12345' },
      actor,
    ),
    error => error.code === 'PASSWORD_CHANGE_RATE_LIMITED',
  );
  assert.equal(tables.Users[1][2], 'hash:currentPass123');
  assert.equal(tables.Audit_Log.length, 1);
});

test('contact settings validate international numbers and are admin-only', () => {
  const { context, tables } = createServer();
  assert.throws(
    () => context._handleContactInfoUpdate_({
      settings: { contact_info: { phone: '963999999999' } },
    }, { user_id: 'user-1', role: 'admin' }),
    error => error.code === 'INVALID_PHONE',
  );
  assert.throws(
    () => context._handleContactInfoUpdate_({
      settings: { contact_info: { phone: '+963999999999' } },
    }, { user_id: 'user-1', role: 'accountant' }),
  );
  context._handleContactInfoUpdate_({
    settings: {
      contact_info: {
        phone: '+963999999999',
        whatsapp: '+963988888888',
        facebook: 'https://facebook.com/orca',
      },
      legal_content: { terms: 'Terms' },
      faq: [{ question: 'Q?', answer: 'A.' }],
    },
  }, { user_id: 'user-1', role: 'admin' });
  const saved = context._handleContactInfoGet_({}, { user_id: 'user-1' });
  assert.equal(saved.contact_info.phone, '+963999999999');
  assert.equal(saved.faq[0].answer, 'A.');
  assert.equal(tables.Audit_Log[1][2], 'UPDATE_PUBLIC_APP_SETTINGS');
});

test('support tickets are private to their owner and accept bounded images', () => {
  const { context, tables } = createServer();
  context._handleSupportTicketCreate_({
    type: 'bug',
    description: 'The screen does not load',
    attach_diagnostics: true,
    diagnostics: {
      app_version: '1.0.0',
      user_id: 'forged-id',
      password: 'must-not-be-saved',
    },
  }, { user_id: 'user-1', username: 'user-one', role: 'customer' });
  assert.equal(tables.Support_Tickets[1][8], 'open');
  assert.match(tables.Support_Tickets[1][6], /"user_id":"user-1"/);
  assert.doesNotMatch(tables.Support_Tickets[1][6], /password|forged-id/);
  assert.equal(
    context._handleSupportTicketList_({}, { user_id: 'someone-else' }).tickets.length,
    0,
  );
  assert.throws(
    () => context._handleSupportTicketCreate_({
      type: 'bug',
      description: 'x',
      attachment_base64: 'not-an-image',
    }, { user_id: 'user-1', username: 'user-one', role: 'customer' }),
    error => error.code === 'INVALID_ATTACHMENT',
  );
});
