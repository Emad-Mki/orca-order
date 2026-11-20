const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function backend(status = 200) {
  const calls = [];
  const context = {
    PropertiesService: {
      getScriptProperties: () => ({
        getProperty: key => key === 'FCM_PROJECT_ID' ? 'test-project' : null,
      }),
    },
    ScriptApp: { getOAuthToken: () => 'test-oauth-token' },
    Utilities: { getUuid: () => 'notification-1' },
    UrlFetchApp: {
      fetch: (url, options) => {
        calls.push({ url, options });
        return {
          getResponseCode: () => status,
          getContentText: () => status === 200
            ? '{"name":"projects/test-project/messages/1"}'
            : '{"error":{"status":"PERMISSION_DENIED"}}',
        };
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'Code.gs'), 'utf8'), context);
  return { context, calls };
}

test('role topic request uses Apps Script OAuth and string data', () => {
  const { context, calls } = backend();
  const result = context.sendFCMNotification(
    'role_warehouse', 'Title', 'Body', '/orders', 42,
  );
  assert.equal(result.name, 'projects/test-project/messages/1');
  assert.equal(calls[0].url, 'https://fcm.googleapis.com/v1/projects/test-project/messages:send');
  assert.equal(calls[0].options.headers.Authorization, 'Bearer test-oauth-token');
  const message = JSON.parse(calls[0].options.payload).message;
  assert.equal(message.topic, 'role_warehouse');
  assert.deepEqual(message.notification, { title: 'Title', body: 'Body' });
  assert.equal(message.data.order_id, '42');
  assert.equal(message.data.deep_link, '/orders');
  assert.equal(message.data.target_role, 'warehouse');
  assert.ok(Object.values(message.data).every(value => typeof value === 'string'));
  assert.equal(message.android.notification.channel_id, 'orders');
});

test('rejects invalid topics and routes and surfaces FCM errors', () => {
  const { context, calls } = backend(403);
  assert.throws(() => context.sendFCMNotification('role_customer', 'x', 'y', '/orders', ''), /missing order ID/);
  assert.throws(() => context.sendFCMNotification('unknown', 'x', 'y', '/notifications', ''), /Invalid FCM role topic/);
  assert.throws(() => context.sendFCMNotification('role_admin', 'x', 'y', 'https://example.com', ''), /Invalid FCM route/);
  assert.equal(calls.length, 0);
  assert.throws(() => context.sendFCMNotification('role_admin', 'x', 'y', '/notifications', ''), /FCM_PERMISSION_DENIED_HTTP_403/);
});

test('Apps Script manifest includes existing service scopes and FCM', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'appsscript.json'), 'utf8'));
  for (const scope of ['spreadsheets', 'drive', 'script.external_request', 'script.scriptapp', 'firebase.messaging']) {
    assert.ok(manifest.oauthScopes.includes(`https://www.googleapis.com/auth/${scope}`));
  }
});
