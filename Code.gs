/**
* ============================================================
* Orca Order Backend - Google Apps Script
* ============================================================
*/

// ============================================================
// 1. مخطط الجداول (Schema)
// ============================================================
const H = {
  Users: ['user_id','username','password_hash','salt','full_name','phone','role','customer_id','status','must_change_password','created_at','last_login','city','address','email','customer_type','internal_notes','sales_stock_id','cash_box_id','updated_at','updated_by'],
  Customers: ['customer_id','full_name','company_name','phone','address','province','notes','opening_usd','opening_syp','status','created_at','is_system_record','creation_request_id'],
  Products: ['code','name','image_name','group','origin','unit_1','quantity','minimum_stock','unit_2','factor_2','quantity_2','unit_3','factor_3','quantity_3','display_price','price_2','price_3','currency','notes','updated_at','updated_by','image_file_id','sub_group','oem','availability_status'],
  Offers: ['offer_id','product_code','title','unit','old_price','offer_price','currency','min_quantity','starts_at','ends_at','note','enabled','sort_order','revision','created_at','created_by','updated_at','updated_by','archived_at','archived_by','bundle_items'],
  Orders: ['order_id', 'order_number', 'customer_id', 'customer_name', 'status', 'currency', 'note', 'accounting_invoice_no', 'accounting_invoice_no_updated_by', 'accounting_invoice_no_updated_at', 'discount_type', 'discount_input', 'discount', 'discount_reason', 'is_read', 'is_new', 'cancellation_reason', 'cancelled_at', 'cancelled_by', 'created_at', 'updated_at', 'created_by', 'subtotal', 'total', 'priced_by', 'priced_at', 'accountant_notes', 'posting_id', 'posted_at', 'matching_status', 'revision_no', 'client_request_id'],
  Order_Items: ['item_id', 'order_id', 'order_number', 'code', 'name_snapshot', 'unit', 'unit_factor', 'base_price_snapshot', 'unit_price_snapshot', 'unit_1', 'unit_2', 'factor_2', 'unit_3', 'factor_3', 'quantity_requested', 'quantity_approved', 'quantity_prepared', 'display_price_snapshot', 'final_price', 'currency', 'status', 'customer_note', 'accountant_note', 'warehouse_note', 'warehouse_package_numbers', 'warehouse_package_type', 'warehouse_custom_package_type', 'total_price', 'offer_id', 'offer_revision', 'offer_old_price', 'offer_min_quantity', 'offer_starts_at', 'offer_ends_at'],
  Payments: ['payment_id','customer_id','order_id','amount','currency','box_type','method','payment_date','note','created_by','created_at','action_type','payment_method','invoice_currency','invoice_equivalent','exchange_rate','reference','client_request_id','change_amount','change_currency','receipt_id','reversal_of'],
  Boxes_Balance: ['box_id','box_name','currency','balance','last_updated'],
  Sham_Cash_Balance: ['id','currency','balance','last_updated'],
  Inventory_Movements: ['movement_id','code','type','quantity','note','created_by','created_at', 'reference_id', 'posting_id', 'is_correction'],
  Shipments: ['shipment_id','order_id','delivery_method','carrier','tracking_no','province','shipping_cost_internal','package_count','carton_count','bag_count','shipping_date','status','note','warehouse_note','invoice_id','package_types_json','weight_kg','dimensions','client_request_id'],
  Low_Stock_Requests: ['request_id','code','requested_qty','status','note','created_by','created_at'],
  Notifications: ['notification_id','event_id','event_type','title','body','target_role','target_user_id','customer_id','order_id','invoice_id','product_id','deep_link','created_at','sent_at','read_at','is_read','status','created_by','retry_count','last_error','last_attempt_at','delivered_device_ids','user_id','type','entity_type','entity_id'],
  User_Devices: ['device_id','user_id','fcm_token','fcm_target_type','platform','app_version','last_active_at','is_active','enabled','created_at','updated_at'],
  Audit_Log: ['log_id','user_id','action','entity','entity_id','details','created_at'],
  Sessions: ['token','user_id','expires_at'],
  Product_Images: ['image_name', 'normalized_name', 'file_id', 'image_url', 'mime_type', 'last_checked', 'status', 'modified_time'],
  New_Products: ['code','name','description','unit','price','image_url','show_in_new','created_at'],
  Sales_Stock: ['user_id','code','quantity','updated_at','updated_by'],
  Sales_Invoices: ['invoice_id','invoice_number','created_by','created_by_role','customer_id','customer_name','buyer_name','buyer_phone','seller_id','invoice_date','created_at','updated_at','modified_by','revision','status','stock_source','currency','subtotal','discount','net_total','amount_received','payment_currency','payment_method','rate_syp_per_usd','equivalent_received','change_amount','net_received','notes','payment_reference','cash_box_id','client_request_id','total_received_usd','total_refunded_usd','net_paid_usd','balance_due_usd','financial_status','payment_detail_version','void_request_id','void_reason'],
  Sales_Invoice_Items: ['item_id','invoice_id','code','name_snapshot','unit','quantity','unit_price','line_total','note','stock_source'],
  Sales_Invoice_Audit: ['audit_id','invoice_id','user_id','created_at','action','reason','before_json','after_json'],
  Sales_Invoice_Allocations: ['allocation_id','receipt_id','invoice_id','customer_id','amount_usd','created_by','created_at','client_request_id'],
};
const _PASSWORD_HASH_ITERATIONS_ = 120000;
const _SHA256_CONSTANTS_ = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

// ============================================================
// 2. الدوال المساعدة الأساسية (Core Helpers)
// ============================================================
function _ss() {
  const id = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
  if (!id) throw new Error('SPREADSHEET_ID غير مضبوط في Script Properties');
  return SpreadsheetApp.openById(id);
}

function _isActiveStatus_(status) {
  const value = String(status || '').trim().toLowerCase();
  return value === '' || value === 'active';
}

function _now() {
  return new Date().toISOString();
}

function _digest(str) {
  return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, str)
    .map((b) => ('0' + (b & 255).toString(16)).slice(-2))
    .join('');
}

/**
 * قراءة جميع الصفوف من ورقة مع تحويلها إلى كائنات باستخدام العناوين الفعلية
 */
function _all(name) {
  const ss = _ss();
  const sheet = ss.getSheetByName(name);
  if (!sheet) return [];
  const values = name === 'Product_Images'
    ? sheet.getLastRow()
      ? sheet.getRange(
        1,
        1,
        sheet.getLastRow(),
        Math.min(sheet.getLastColumn(), H.Product_Images.length)
      ).getValues()
      : []
    : sheet.getDataRange().getValues();
  if (values.length === 0) return [];
  const headers = values.shift();
  return values
    .filter((r) => r.join('').trim() !== '')
    .map((row) => Object.fromEntries(headers.map((h, i) => [String(h).trim(), row[i]])));
}

/**
 * الحصول على رؤوس الأعمدة الفعلية من ورقة
 */
function _getHeaders(sheetName) {
  const sheet = _ss().getSheetByName(sheetName);
  if (!sheet) return [];
  const lastCol = sheet.getLastColumn();
  if (lastCol === 0) return [];
  return sheet.getRange(1, 1, 1, lastCol).getValues()[0].map(h => String(h).trim());
}

function _requireColumns_(sheetName, requiredColumns) {
  const headers = _getHeaders(sheetName);
  const missing = requiredColumns.filter(column => headers.indexOf(column) < 0);
  if (missing.length) {
    throw _apiError(
      'SCHEMA_NOT_READY',
      'مخطط ورقة ' + sheetName + ' غير مهيأ (' + missing.join(', ') + ')؛ شغّل setupSystem أولاً',
      false
    );
  }
}

/**
 * كتابة كائن إلى ورقة باستخدام العناوين الفعلية (وليس الترتيب الثابت)
 * هذه الدالة تقرأ العناوين الفعلية من الورقة ثم تكتب القيم في الأعمدة الصحيحة
 */
function _add(name, obj) {
  const sheet = _ss().getSheetByName(name);
  if (!sheet) throw new Error('الجدول غير موجود: ' + name);
  
  // قراءة العناوين الفعلية من الورقة
  const actualHeaders = _getHeaders(name);
  
  if (actualHeaders.length === 0) {
    // إذا لم تكن هناك عناوين، نستخدم المخطط H ونضيفه أولاً
    const schemaHeaders = H[name] || [];
    if (schemaHeaders.length > 0) {
      sheet.appendRow(schemaHeaders);
      sheet.appendRow(schemaHeaders.map((k) => obj[k] ?? ''));
    }
    return;
  }
  
  // كتابة القيم حسب العناوين الفعلية الموجودة في الورقة
  const row = actualHeaders.map((header) => {
    // البحث عن قيمة مطابقة في الكائن المدخل
    // ندعم عدة صيغ لاسم الحقل
    const possibleKeys = [
      header,
      header.toLowerCase(),
      header.replace(/_/g, '').toLowerCase(),
      header.replace(/-/g, '_').toLowerCase()
    ];
    
    for (const key of possibleKeys) {
      if (obj[key] !== undefined && obj[key] !== null) {
        return obj[key];
      }
    }
    
    // محاولة البحث بمطابقة جزئية
    for (const objKey of Object.keys(obj)) {
      if (String(objKey).toLowerCase().replace(/_/g, '') === header.toLowerCase().replace(/_/g, '')) {
        return obj[objKey];
      }
    }
    
    return '';
  });
  
  sheet.appendRow(row);
}

/**
 * تحديث صف موجود بناءً على مفتاح
 */
function _updateByField(sheetName, keyField, keyValue, updates) {
  const sheet = _ss().getSheetByName(sheetName);
  if (!sheet) throw new Error('الجدول غير موجود: ' + sheetName);
  
  const data = sheet.getDataRange().getValues();
  if (data.length < 2) return false;
  
  const headers = data[0].map(h => String(h).trim());
  const keyIndex = headers.indexOf(keyField);
  
  if (keyIndex === -1) throw new Error('حقل المفتاح غير موجود: ' + keyField);
  
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][keyIndex]).trim() === String(keyValue).trim()) {
      // تحديث الخلايا
      const updateHeaders = Object.keys(updates);
      for (const field of updateHeaders) {
        const colIndex = headers.indexOf(field);
        if (colIndex !== -1) {
          sheet.getRange(i + 1, colIndex + 1).setValue(updates[field]);
        }
      }
      return true;
    }
  }
  
  return false;
}

/**
 * البحث عن صفوف بناءً على حقل وقيمة
 */
function _findByField(sheetName, fieldName, value) {
  const allData = _all(sheetName);
  return allData.filter(row => String(row[fieldName] ?? '').trim() === String(value).trim());
}

function _json(o) {
  // تأكد من عدم وجود تعارض بين ok و success
  if (o.success !== undefined && o.ok === undefined) o.ok = o.success;
  return ContentService.createTextOutput(JSON.stringify(o))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * نموذج استجابة موحد للـ API
 */
function _apiResponse(data, error = null, requestId = null) {
  const ok = error === null;
  const res = {
    ok: ok,
    success: ok,
    api_version: "1.3.0",
    request_id: requestId || Utilities.getUuid(),
  };

  if (error) {
    res.data = null;
    const message = typeof error === 'string'
      ? error
      : (error.message || 'خطأ غير معروف في الخادم');
    res.error = {
      code: error.code || 'SERVER_ERROR',
      message: message,
      retryable: error.retryable === true
    };
    res.message = message;
  } else {
    res.data = data;
    res.error = null;
    if (data && typeof data === 'object' && !Array.isArray(data)) {
      Object.keys(data).forEach((key) => {
        if (!['ok', 'success', 'error', 'request_id', 'api_version'].includes(key)) {
          res[key] = data[key];
        }
      });
    }
  }

  return ContentService.createTextOutput(JSON.stringify(res))
    .setMimeType(ContentService.MimeType.JSON);
}

function _apiError(code, message, retryable) {
  const error = new Error(message);
  error.code = code;
  error.retryable = retryable === true;
  return error;
}

function _normalizeRole(role) {
  const value = String(role || '').trim().toLowerCase();
  const aliases = {
    admin: ['admin', 'مدير', 'المدير العام'],
    manager: ['manager', 'مدير فرع'],
    accountant: ['accountant', 'محاسب', 'المحاسب'],
    warehouse: ['warehouse', 'مستودع', 'أمين المستودع'],
    salesperson: ['salesperson', 'sales', 'user', 'مندوب مبيعات', 'مندوب', 'موظف مبيعات'],
    customer: ['customer', 'عميل', 'زبون'],
  };
  for (const canonical in aliases) {
    if (aliases[canonical].includes(value)) return canonical;
  }
  return '';
}

function _isTrue_(value) {
  return value === true || ['1', 'true', 'yes', 'active']
    .includes(String(value || '').trim().toLowerCase());
}

function _sha256Bytes_(input) {
  const bytes = input.map(value => value & 255);
  const bitLength = bytes.length * 8;
  bytes.push(0x80);
  while (bytes.length % 64 !== 56) bytes.push(0);
  bytes.push(
    0, 0, 0, 0,
    (bitLength >>> 24) & 255,
    (bitLength >>> 16) & 255,
    (bitLength >>> 8) & 255,
    bitLength & 255
  );

  const state = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];
  const words = new Array(64);
  const rotateRight = (value, count) =>
    (value >>> count) | (value << (32 - count));
  for (let offset = 0; offset < bytes.length; offset += 64) {
    for (let i = 0; i < 16; i++) {
      const position = offset + i * 4;
      words[i] = (
        (bytes[position] << 24) |
        (bytes[position + 1] << 16) |
        (bytes[position + 2] << 8) |
        bytes[position + 3]
      ) >>> 0;
    }
    for (let i = 16; i < 64; i++) {
      const x = words[i - 15];
      const y = words[i - 2];
      const s0 = rotateRight(x, 7) ^ rotateRight(x, 18) ^ (x >>> 3);
      const s1 = rotateRight(y, 17) ^ rotateRight(y, 19) ^ (y >>> 10);
      words[i] = (words[i - 16] + s0 + words[i - 7] + s1) >>> 0;
    }

    let a = state[0];
    let b = state[1];
    let c = state[2];
    let d = state[3];
    let e = state[4];
    let f = state[5];
    let g = state[6];
    let h = state[7];
    for (let i = 0; i < 64; i++) {
      const sum1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25);
      const choose = (e & f) ^ (~e & g);
      const temp1 = (h + sum1 + choose + _SHA256_CONSTANTS_[i] + words[i]) >>> 0;
      const sum0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22);
      const majority = (a & b) ^ (a & c) ^ (b & c);
      const temp2 = (sum0 + majority) >>> 0;
      h = g;
      g = f;
      f = e;
      e = (d + temp1) >>> 0;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) >>> 0;
    }
    state[0] = (state[0] + a) >>> 0;
    state[1] = (state[1] + b) >>> 0;
    state[2] = (state[2] + c) >>> 0;
    state[3] = (state[3] + d) >>> 0;
    state[4] = (state[4] + e) >>> 0;
    state[5] = (state[5] + f) >>> 0;
    state[6] = (state[6] + g) >>> 0;
    state[7] = (state[7] + h) >>> 0;
  }
  const output = [];
  state.forEach(word => output.push(
    (word >>> 24) & 255,
    (word >>> 16) & 255,
    (word >>> 8) & 255,
    word & 255
  ));
  return output;
}

function _hmacSha256Bytes_(message, key) {
  let normalizedKey = key.map(value => value & 255);
  if (normalizedKey.length > 64) normalizedKey = _sha256Bytes_(normalizedKey);
  while (normalizedKey.length < 64) normalizedKey.push(0);
  const inner = [];
  const outer = [];
  for (let i = 0; i < 64; i++) {
    inner.push(normalizedKey[i] ^ 0x36);
    outer.push(normalizedKey[i] ^ 0x5c);
  }
  return _sha256Bytes_(outer.concat(_sha256Bytes_(inner.concat(message))));
}

function _passwordHash_(password, salt, iterations) {
  const rounds = iterations || _PASSWORD_HASH_ITERATIONS_;
  const passwordBytes = Utilities.newBlob(String(password)).getBytes();
  const saltBytes = Utilities.newBlob(String(salt)).getBytes();
  const firstBlockInput = saltBytes.concat([0, 0, 0, 1]);
  let block = _hmacSha256Bytes_(firstBlockInput, passwordBytes);
  const result = block.slice();
  for (let i = 1; i < rounds; i++) {
    block = _hmacSha256Bytes_(block, passwordBytes);
    for (let j = 0; j < result.length; j++) result[j] ^= block[j];
  }
  const hex = result.map(b => ('0' + (b & 255).toString(16)).slice(-2)).join('');
  return 'pbkdf2-sha256$' + rounds + '$' + hex;
}

function _verifyPassword_(password, user) {
  const stored = String(user.password_hash || '');
  if (stored.indexOf('pbkdf2-sha256$') === 0) {
    const parts = stored.split('$');
    const rounds = Number(parts[1]);
    if (!Number.isInteger(rounds) || rounds < 10000 || rounds > 250000 ||
        !parts[2]) return false;
    return _passwordHash_(password, user.salt, rounds) === stored;
  }
  return _digest(String(password) + String(user.salt || '')) === stored;
}

function _checkLoginRateLimit_(username) {
  const cache = CacheService.getScriptCache();
  const key = 'login-attempts:' + _digest(String(username).toLowerCase()).slice(0, 32);
  const attempts = Number(cache.get(key) || 0);
  if (attempts >= 8) {
    throw _apiError(
      'LOGIN_RATE_LIMITED',
      'محاولات دخول كثيرة. حاول بعد 15 دقيقة',
      false
    );
  }
  return key;
}

function _recordLoginAttempt_(key, failed) {
  const cache = CacheService.getScriptCache();
  if (!failed) {
    cache.remove(key);
    return;
  }
  const attempts = Number(cache.get(key) || 0) + 1;
  cache.put(key, String(attempts), 900);
}

function _removeSessionsForUser_(userId) {
  const sheet = _ss().getSheetByName('Sessions');
  if (!sheet) return;
  const rows = _all('Sessions');
  for (let i = rows.length - 1; i >= 0; i--) {
    if (String(rows[i].user_id) === String(userId)) sheet.deleteRow(i + 2);
  }
}

function _auth(token) {
  const normalizedToken = String(token || '').trim();
  if (!normalizedToken) {
    throw _apiError('AUTH_REQUIRED', 'يجب تسجيل الدخول أولاً', false);
  }
  const sessions = _all('Sessions');
  const now = Date.now();
  const s = sessions.find((x) => String(x.token || '') === normalizedToken);
  if (!s || !Number.isFinite(Date.parse(s.expires_at)) ||
      Date.parse(s.expires_at) <= now) {
    if (s && s.user_id) _deactivateAllUserDevices_(s.user_id);
    throw _apiError('SESSION_EXPIRED', 'انتهت الجلسة، يرجى تسجيل الدخول مجدداً', false);
  }
  const users = _all('Users');
  const u = users.find((x) =>
    String(x.user_id) === String(s.user_id) &&
    _isActiveStatus_(x.status)
  );
  if (!u) {
    _deactivateAllUserDevices_(s.user_id);
    throw _apiError('ACCOUNT_INACTIVE', 'الحساب غير نشط', false);
  }
  const role = _normalizeRole(u.role);
  if (!role) {
    throw _apiError('ROLE_NOT_ALLOWED', 'الدور غير معروف أو غير مفعل', false);
  }
  return Object.assign({}, u, { role: role, original_role: u.role });
}

function _handleLogout(token, deviceId, user) {
  if (deviceId && user) {
    _handleDeactivateUserDevice({ device_id: deviceId }, user);
  }
  const sessions = _all('Sessions');
  const index = sessions.findIndex(s => s.token === token);
  if (index >= 0) {
    // إزالة الجلسة من التخزين (حذف الصف في جدول Sessions)
    const sheet = SpreadsheetApp.openById(PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID')).getSheetByName('Sessions');
    sheet.deleteRow(index + 2); // +2 لأن الـ headers في صف 1 و findIndex تبدأ بـ 0
  }
  return { success: true, message: 'تم تسجيل الخروج بنجاح' };
}

function canPriceOrder_(role) {
  const normalized = _normalizeRole(role);
  return ['admin', 'manager', 'accountant'].includes(normalized);
}

function _isAdmin(role) {
  return _normalizeRole(role) === 'admin';
}

/**
 * التحقق من ملكية البيانات أو الصلاحيات الإدارية
 */
function _checkOwnership(user, ownerId) {
  if (!user) throw new Error('غير مصرح');
  const role = _normalizeRole(user.role);
  if (['admin', 'manager', 'accountant'].includes(role)) return true;
  const sessionOwnerId = role === 'customer' ? user.customer_id : user.user_id;
  if (sessionOwnerId && String(sessionOwnerId) === String(ownerId)) return true;
  throw new Error('ليس لديك صلاحية الوصول لهذه البيانات');
}

function _needRole(user, roles) {
  if (!user) {
    throw new Error('يجب تسجيل الدخول أولاً (رمز الجلسة مفقود أو غير صالح)');
  }

  const userRole = _normalizeRole(user.role);
  const normalizedRequiredRoles = roles.map(_normalizeRole);
  if (!userRole || !normalizedRequiredRoles.includes(userRole)) {
    throw new Error('ليست لديك الصلاحية لهذه العملية (الدور: ' + user.role + ')');
  }
}

function _requireOrderOwnership(user, order) {
  if (!user || !order) throw new Error('الطلب غير موجود');
  if (_normalizeRole(user.role) === 'customer' &&
      (!user.customer_id ||
       String(order.customer_id) !== String(user.customer_id))) {
    throw _apiError('FORBIDDEN', 'ليس لديك صلاحية الوصول لهذا الطلب', false);
  }
}

function _withoutFinancialFields(record, role) {
  if (role === 'admin' || role === 'manager' || role === 'accountant') return record;

  const financialFields = [
    'price', 'display_price', 'display_price_snapshot', 'price_offer', 'offer_old_price',
    'price_2', 'price_3',
    'unit_price_snapshot', 'base_price_snapshot',
    'final_price', 'default_price', 'total_price', 'subtotal', 'total',
    'total_amount', 'grand_total', 'invoice_total', 'balance',
    'discount', 'discount_type', 'discount_input', 'discount_reason',
    'accounting_invoice_no_updated_by', 'accounting_invoice_no_updated_at',
    'previous_balance', 'current_balance', 'opening_usd', 'opening_syp',
    'accountant_notes', 'priced_by', 'priced_at', 'accounting_invoice_no',
    'posting_id', 'posted_at', 'matching_status', 'shipping_cost_internal'
  ];
  const safe = Object.assign({}, record);
  financialFields.forEach((field) => delete safe[field]);
  return safe;
}

function _withoutInternalOrderFields(record) {
  const safe = Object.assign({}, record);
  [
    'accountant_notes',
    'accounting_invoice_no',
    'accounting_invoice_no_updated_by',
    'accounting_invoice_no_updated_at',
    'discount',
    'discount_type',
    'discount_input',
    'discount_reason',
    'posting_id',
    'posted_at',
    'matching_status'
  ].forEach(field => delete safe[field]);
  return safe;
}

function _serializeProductForRole(product, role, imageUrl, defaultProductCurrency) {
  const userRole = _normalizeRole(role);
  const item = {
    code: product.code,
    name: product.name,
    category: product.group || product.category || 'عام',
    group: product.group || product.category || '',
    sub_group: product.sub_group || product.subGroup || '',
    origin: product.origin || '',
    oem: product.oem || product.OEM || '',
    availability_status: product.availability_status || '',
    image_url: imageUrl || product.image_url || '',
    unit: product.unit_1 || product.unit || '',
    unit_1: product.unit_1 || product.unit || '',
    unit_2: product.unit_2 || '',
    factor_2: product.factor_2 === '' ? null : product.factor_2,
    unit_3: product.unit_3 || '',
    factor_3: product.factor_3 === '' ? null : product.factor_3,
    currency: product.currency ||
      (userRole === 'salesperson'
        ? (defaultProductCurrency === undefined
          ? _salesProperty_('DEFAULT_PRODUCT_CURRENCY')
          : defaultProductCurrency)
        : 'USD'),
    notes: product.notes || product.description || '',
    is_new: product.show_in_new === 'true' ||
      product.show_in_new === true,
    created_at: product.created_at || ''
  };
  if (['admin', 'manager', 'accountant', 'salesperson'].includes(userRole)) {
    item.price = product.display_price === '' || product.display_price == null
      ? (product.price === '' || product.price == null ? null : Number(product.price))
      : Number(product.display_price);
    item.price_2 = product.price_2 === '' || product.price_2 == null ? null : Number(product.price_2);
    item.price_3 = product.price_3 === '' || product.price_3 == null ? null : Number(product.price_3);
  }
  if (['admin', 'manager', 'accountant', 'warehouse', 'salesperson'].includes(userRole)) {
    item.quantity = Number(product.quantity === '' || product.quantity == null
      ? (product.stock === '' || product.stock == null ? 0 : product.stock)
      : product.quantity);
    item.stock = item.quantity;
  } else if (userRole === 'customer') {
    item.price = product.display_price === '' || product.display_price == null
      ? (product.price === '' || product.price == null ? null : Number(product.price))
      : Number(product.display_price);
    item.price_2 = product.price_2 === '' || product.price_2 == null ? null : Number(product.price_2);
    item.price_3 = product.price_3 === '' || product.price_3 == null ? null : Number(product.price_3);
  }
  return item;
}

function _getSalesStockQuantity_(user, code) {
  const stockId = String(user && user.sales_stock_id || '');
  if (!stockId) return 0;
  const row = _all('Sales_Stock').find(item =>
    String(item.user_id) === stockId && String(item.code) === String(code)
  );
  const quantity = Number(row && row.quantity || 0);
  return Number.isFinite(quantity) && quantity > 0 ? quantity : 0;
}

function _getSalesStockMap_(user) {
  const stockId = String(user && user.sales_stock_id || '');
  const map = {};
  if (!stockId) return map;
  _all('Sales_Stock').forEach(item => {
    if (String(item.user_id) === stockId) {
      const quantity = Number(item.quantity || 0);
      map[String(item.code)] = Number.isFinite(quantity) && quantity > 0 ? quantity : 0;
    }
  });
  return map;
}

function _getStatusTextAr(status) {
  if (!status) return '';
  switch (String(status).toLowerCase()) {
    case 'pending': return 'قيد الانتظار';
    case 'submitted': return 'قيد المراجعة';
    case 'priced': return 'بانتظار تأكيدك (مسعرة)';
    case 'customer_changed': return 'تم تعديل الزبون (تحتاج مراجعة)';
    case 'customer_confirmed': return 'مؤكدة من الزبون';
    case 'approved': return 'معتمدة (قيد التجهيز)';
    case 'prepared': return 'جاهزة للشحن';
    case 'shipping': return 'قيد الشحن';
    case 'delivered': return 'تم التسليم';
    case 'returned': return 'مرتجع';
    case 'cancelled': return 'ملغاة';
    case 'deleted': return 'محذوفة';
    default: return status;
  }
}

// ============================================================
// 3. تهيئة النظام (Setup)
// ============================================================
function setupSystem() {
  const ss = _ss();

  // ضبط Folder ID للصور إذا لم يكن موجوداً
  const props = PropertiesService.getScriptProperties();
  if (!props.getProperty('PRODUCT_IMAGES_FOLDER_ID')) {
    props.setProperty('PRODUCT_IMAGES_FOLDER_ID', '1H9KGBPTnZYE8bQHOWUih39zUwB0Hk9ds');
  }

  Object.keys(H).forEach((name) => {
    let sheet = ss.getSheetByName(name);
    if (!sheet) sheet = ss.insertSheet(name);
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(H[name]);
    } else {
      // تحديث الأعمدة الناقصة
      const existingHeaders = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0].map(String);
      const missingCols = H[name].filter(h => !existingHeaders.includes(h));
      missingCols.forEach(col => {
        sheet.getRange(1, existingHeaders.length + missingCols.indexOf(col) + 1).setValue(col);
      });
    }
    sheet.setFrozenRows(1);
  });

  _ensureShopCustomer_();
}

function _ensureShopCustomer_() {
  const existing = _all('Customers').find(c =>
    String(c.customer_id || '') === 'CUS-SHOP'
  );
  if (existing) return existing.customer_id;
  _add('Customers', {
    customer_id: 'CUS-SHOP',
    full_name: 'زبائن محل',
    company_name: 'سجل داخلي للمبيعات النقدية',
    status: 'active',
    is_system_record: true,
    created_at: _now(),
  });
  return 'CUS-SHOP';
}

function seedAdmin(password) {
  const salt = Utilities.getUuid();
  _add('Users', {
    user_id: 'USR-00001',
    username: 'Nsr.adm',
    password_hash: _digest(password + salt),
    salt: salt,
    full_name: 'نصر نصر وطفة',
    phone: '0947766076',
    role: 'admin',
    status: 'active',
    must_change_password: 'yes',
    created_at: _now(),
  });
}

// ============================================================
// 4. نقاط الدخول API (Entry Points)
// ============================================================
function doGet(e) {
  return _apiResponse({ message: 'Orca API is running' });
}

function doPost(e) {
  const requestId = Utilities.getUuid();
  try {
    // يُقرأ JSON من جسم POST حتى عند إرساله بنوع text/plain من الويب.
    const rawBody = (e && e.postData && e.postData.contents) || '{}';
    const body = JSON.parse(rawBody);
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      throw _apiError('INVALID_REQUEST', 'محتوى الطلب غير صالح', false);
    }
    let result = {};
    const action = _canonicalizeApiAction_(body.action);

    if (!action) {
      throw _apiError('INVALID_REQUEST', 'حقل action مطلوب', false);
    }

    if (action === 'login') {
      result = _handleLogin(body);
      return _apiResponse(result, null, requestId);
    }

    const token = String(body.token || body.sessionToken || '').trim();
    if (!token) {
      throw _apiError('AUTH_REQUIRED', 'يجب تسجيل الدخول أولاً', false);
    }

    const user = _auth(token);
    if (_isTrue_(user.must_change_password) &&
        !['logout', 'user_update'].includes(action)) {
      throw _apiError(
        'PASSWORD_CHANGE_REQUIRED',
        'يجب تغيير كلمة المرور المؤقتة قبل استخدام التطبيق',
        false
      );
    }
    if (action === 'invoice_template_update') _invoiceTemplateRejectDuplicateJsonKeys_(rawBody);

    // تسجيل النشاط (Audit Log)
    Logger.log('Action: ' + action + ' by User: ' + user.username);

    switch (action) {
      case 'logout':
        result = _handleLogout(token, body.device_id, user);
        break;
      case 'validate_session':
        result = { valid: true, user: { username: user.username, role: user.role } };
        break;
      case 'offer_list':
        result = _handleOfferList_(body, user);
        break;
      case 'offer_save':
        result = _handleOfferSave_(body, user);
        break;
      case 'offer_archive':
        result = _handleOfferArchive_(body, user);
        break;
      // --- المنتجات ---
      case 'product_list':
      case 'getProducts':
      case 'products':
        result = _handleProducts(body, user);
        break;
      case 'product_search':
      case 'searchProducts':
      case 'search_products':
        result = _handleSearchProducts(body, user);
        break;
      case 'product_categories':
      case 'getProductCategories':
      case 'get_product_categories':
        result = _handleGetProductCategories(body, user);
        break;
      case 'rebuildImageIndex':
        _needRole(user, ['admin']);
        result = rebuildImageIndex(body);
        break;
      case 'image_index_status':
        _needRole(user, ['admin']);
        result = _imageIndexJobStatus_();
        break;
      case 'image_index_resume':
        _needRole(user, ['admin']);
        result = resumeImageIndexJob();
        break;
      case 'image_index_cancel':
        _needRole(user, ['admin']);
        result = cancelImageIndexJob();
        break;
      case 'image_index_restart':
        _needRole(user, ['admin']);
        result = rebuildImageIndex({
          operation: 'restart',
          confirmed: body.confirmed,
        });
        break;
      case 'image_index_schedule':
        _needRole(user, ['admin']);
        result = _imageIndexSetSchedule_(
          body.enabled === true || String(body.enabled) === 'true'
        );
        break;
      case 'product_update_qty':
      case 'updateProductQuantity':
      case 'adjust_inventory':
        result = _handleUpdateProductQuantity(body, user);
        break;
      case 'product_receive':
      case 'receive_goods':
        result = _handleReceiveGoods(body, user);
        break;
      case 'product_create':
        result = _handleCreateProduct(body, user);
        break;
      case 'product_price_update':
        result = _handleUpdateProductPrice(body, user);
        break;
      // --- الطلبات ---
      case 'order_list':
      case 'getOrders':
        result = _handleGetOrders(body, user);
        break;
      case 'order_details':
      case 'getOrderDetails':
        result = _handleOrderDetails(body, user);
        break;
      case 'order_price':
      case 'price_order':
      case 'updateOrderPricing':
        result = _handleUpdateOrderPricing(body, user);
        break;
      case 'order_accounting_invoice_update':
        result = _handleUpdateAccountingInvoiceNumber(body, user);
        break;
      case 'order_create':
      case 'createOrder':
      case 'create_order':
        result = _handleCreateOrder(body, user);
        break;
      case 'updateCustomerOrder':
        result = _handleUpdateCustomerOrder(body, user);
        break;
      case 'edit_order':
        result = _handleEditOrder(body, user);
        break;
      case 'order_status_update':
      case 'update_order_status':
      case 'updateOrderStatus':
        result = _handleUpdateOrderStatus(body, user);
        break;
      case 'confirmWarehousePrep':
        result = _handleConfirmWarehousePrep(body, user);
        break;
      case 'markOrderAsRead':
        result = _handleMarkOrderAsRead(body, user);
        break;
      case 'order_cancel':
      case 'cancelOrder':
      case 'cancel_order':
        result = _handleCancelOrder(body, user);
        break;
      case 'order_delete':
      case 'deleteOrder':
      case 'delete_order':
        result = _handleDeleteOrder(body, user);
        break;
      // --- العملاء ---
      case 'customer_list':
      case 'getCustomers':
        result = _handleGetCustomers(body, user);
        break;
      case 'sales_customer_list':
        result = _handleSalesCustomerList(body, user);
        break;
      case 'sales_customer_create':
        result = _handleCreateSalesCustomer(body, user);
        break;
      case 'customer_create':
      case 'createCustomer':
      case 'add_customer':
        result = _handleCreateCustomer(body, user);
        break;
      case 'customer_update':
      case 'updateCustomer':
      case 'update_customer':
        result = _handleUpdateCustomer(body, user);
        break;
      case 'customer_statement':
      case 'getCustomerStatement':
      case 'get_customer_statement':
        result = _handleGetCustomerStatement(body, user);
        break;
      case 'exportStatement':
        result = _handleExportStatement(body, user);
        break;
      // --- الدفعات والصناديق ---
      case 'payment_list':
      case 'getPayments':
        result = _handleGetPayments(body, user);
        break;
      case 'payment_add':
      case 'addPayment':
      case 'add_payment':
      case 'record_payment':
      case 'recordPayment':
        result = _handleRecordPayment(body, user);
        break;
      case 'payment_update':
      case 'updatePayment':
        result = _handleUpdatePayment(body, user);
        break;
      case 'payment_delete':
      case 'deletePayment':
        result = _handleDeletePayment(body, user);
        break;
      case 'payment_reverse':
        result = _handleReversePayment(body, user);
        break;
      case 'box_balances':
      case 'getBoxBalances':
        result = _handleGetBoxBalances(body, user);
        break;
      case 'cash_box_statement':
        result = _handleCashBoxStatement(body, user);
        break;
      case 'cash_box_opening_balance':
        result = _handleCashBoxOpeningBalance(body, user);
        break;
      case 'customer_receipt_create':
        result = _handleCreateCustomerReceipt(body, user);
        break;
      case 'sales_invoice_collect':
        result = _handleCollectSalesInvoice(body, user);
        break;
      case 'sales_invoice_allocate':
        result = _handleAllocateCustomerReceipt(body, user);
        break;
      // --- المخزون ---
      case 'inventory_movements':
      case 'getInventoryMovements':
        result = _handleGetInventoryMovements(body, user);
        break;
      // --- الشحن ---
      case 'shipment_list':
      case 'getShipments':
        result = _handleGetShipments(body, user);
        break;
      case 'shipment_save':
      case 'shipment':
        result = _handleShipment(body, user);
        break;
      case 'shipment_status_update':
      case 'updateShipmentStatus':
        result = _handleUpdateShipmentStatus(body, user);
        break;
      // --- النواقص ---
      case 'low_stock_create':
      case 'createLowStockRequest':
        result = _handleCreateLowStockRequest(body, user);
        break;
      case 'low_stock_list':
      case 'getLowStockRequests':
        result = _handleGetLowStockRequests(body, user);
        break;
      // --- الإشعارات ---
      case 'notification_list':
      case 'getNotifications':
        result = _handleGetNotifications(body, user);
        break;
      case 'notification_read':
      case 'markNotificationRead':
      case 'markNotificationAsRead':
        result = _handleMarkNotificationAsRead(body, user);
        break;
      case 'notification_send':
      case 'sendNotification':
        result = _handleSendNotification(body, user);
        break;
      case 'notification_mark_all_read':
        result = _handleMarkAllNotificationsAsRead(user);
        break;
      case 'notification_retry':
        result = _handleRetryNotification(body, user);
        break;
      case 'user_device_upsert':
        result = _handleRegisterUserDevice(body, user);
        break;
      case 'user_device_deactivate':
        result = _handleDeactivateUserDevice(body, user);
        break;
      // --- المزامنة والإعدادات ---
      case 'sync_drive':
      case 'syncFromDrive':
        result = _handleSyncFromDrive(body, user);
        break;
      case 'config_update':
      case 'updateConfig':
        result = _handleUpdateConfig(body, user);
        break;
      // --- التقارير والإحصائيات ---
      case 'reports':
      case 'getReports':
        result = _handleReports(body, user);
        break;
      case 'dashboard_stats':
      case 'getDashboardStats':
        result = _handleDashboardStats(body, user);
        break;
      case 'best_sellers':
      case 'getBestSellers':
        result = _handleBestSellers(body, user);
        break;
      case 'new_products':
      case 'getNewProducts':
        result = _handleNewProducts(body, user);
        break;
      // --- المستخدم ---
      case 'user_update':
      case 'change_password':
        result = _handleUpdateUser(body, user);
        break;
      case 'users_list':
        result = _handleListUsers(body, user);
        break;
      case 'user_create':
        result = _handleCreateManagedUser(body, user);
        break;
      case 'user_update_admin':
        result = _handleUpdateManagedUser(body, user);
        break;
      case 'user_status':
        result = _handleSetUserStatus(body, user);
        break;
      case 'user_reset_password':
        result = _handleResetManagedPassword(body, user);
        break;
      case 'sales_stock_transfer':
        result = _handleSalesStockTransfer(body, user);
        break;
      case 'salespeople_list':
        result = _handleSalespeopleList(body, user);
        break;
      case 'sales_configuration':
        result = _handleSalesConfiguration(body, user);
        break;
      case 'sales_settings_get':
        result = _handleGetSalesSettings(body, user);
        break;
      case 'sales_settings_update':
        result = _handleUpdateSalesSettings(body, user);
        break;
      case 'invoice_template_get':
        result = _handleInvoiceTemplateGet_(body, user);
        break;
      case 'invoice_template_update':
        result = _handleInvoiceTemplateUpdate_(body, user);
        break;
      case 'sales_invoice_create':
        result = _handleCreateSalesInvoiceV2(body, user);
        break;
      case 'sales_invoice_list':
        result = _handleListSalesInvoicesV2(body, user);
        break;
      case 'sales_invoice_void':
        result = _handleVoidSalesInvoice(body, user);
        break;
      case 'sales_summary':
        result = _handleSalesSummary(body, user);
        break;
      default:
        const err = new Error('عملية غير معروفة: ' + action);
        err.code = 'UNKNOWN_ACTION';
        throw err;
    }

    return _apiResponse(result, null, requestId);
  } catch (err) {
    const error = err instanceof Error
      ? err
      : _apiError('SERVER_ERROR', String(err), false);
    if (error instanceof SyntaxError) {
      error.code = 'INVALID_JSON';
      error.retryable = false;
      error.message = 'تعذر قراءة JSON الخاص بالطلب';
    }
    return _apiResponse(null, error, requestId);
  }
}

function _canonicalizeApiAction_(action) {
  const value = String(action || '').trim();
  const aliases = {
    record_payment: 'recordPayment',
    markNotificationRead: 'markNotificationAsRead',
  };
  return aliases[value] || value;
}

// ============================================================
// 5. المصادقة (Authentication)
// ============================================================
function _handleLogin(body) {
  const loginStartedAt = Date.now();
  const users = _all('Users');
  const username = String(body.username || '').trim().toLowerCase();
  const password = typeof body.password === 'string' ? body.password : '';
  if (!username || !password) {
    throw _apiError('AUTH_INVALID_CREDENTIALS', 'اسم المستخدم وكلمة المرور مطلوبان', false);
  }
  const attemptKey = _checkLoginRateLimit_(username);
  const u = users.find(x =>
    String(x.username || '').trim().toLowerCase() === username
  );
  if (!u || !u.salt || !u.password_hash) {
    _recordLoginAttempt_(attemptKey, true);
    throw _apiError('AUTH_INVALID_CREDENTIALS', 'بيانات تسجيل الدخول غير صحيحة', false);
  }

  const verificationStartedAt = Date.now();
  const passwordValid = _verifyPassword_(password, u);
  Logger.log('login_password_verify_ms=' + (Date.now() - verificationStartedAt));
  if (!passwordValid) {
    _recordLoginAttempt_(attemptKey, true);
    throw _apiError('AUTH_INVALID_CREDENTIALS', 'بيانات تسجيل الدخول غير صحيحة', false);
  }
  if (!_isActiveStatus_(u.status)) {
    _recordLoginAttempt_(attemptKey, true);
    throw _apiError('ACCOUNT_INACTIVE', 'الحساب غير مفعل', false);
  }

  const loginUpdates = { last_login: _now() };
  const storedPasswordHash = String(u.password_hash);
  const storedRounds = storedPasswordHash.indexOf('pbkdf2-sha256$') === 0
    ? Number(storedPasswordHash.split('$')[1])
    : 0;
  if (storedRounds !== _PASSWORD_HASH_ITERATIONS_) {
    loginUpdates.password_hash = _passwordHash_(password, u.salt);
    loginUpdates.status = 'active';
    loginUpdates.updated_at = _now();
    loginUpdates.updated_by = 'password_migration';
  }
  _updateByField('Users', 'user_id', u.user_id, loginUpdates);
  _recordLoginAttempt_(attemptKey, false);

  const role = _normalizeRole(u.role);
  if (!role) {
    throw _apiError('ROLE_NOT_ALLOWED', 'الدور غير معروف أو غير مفعل', false);
  }

  const token = Utilities.getUuid() + Utilities.getUuid();
  const sessionStartedAt = Date.now();
  _add('Sessions', {
    token: token,
    user_id: u.user_id,
    expires_at: new Date(Date.now() + 86400000).toISOString()
  });
  Logger.log('login_session_write_ms=' + (Date.now() - sessionStartedAt));
  Logger.log('login_total_server_ms=' + (Date.now() - loginStartedAt));

  return {
    session: {
      token: token,
      user_id: u.user_id,
      username: u.username,
      full_name: u.full_name,
      role: role,
      customer_id: u.customer_id,
      must_change_password: _isTrue_(u.must_change_password),
      id: u.user_id,
      name: u.full_name,
    },
    user: {
      user_id: u.user_id,
      id: u.user_id,
      username: u.username,
      full_name: u.full_name,
      name: u.full_name,
      role: role,
      customer_id: u.customer_id,
      must_change_password: _isTrue_(u.must_change_password),
    },
  };
}

function _handleUpdateUser(body, user) {
  if (body.role !== undefined ||
      body.user_id !== undefined ||
      body.target_username !== undefined ||
      body.is_active !== undefined ||
      body.status !== undefined) {
    throw _apiError('FORBIDDEN', 'لا يمكن تعديل الدور أو حالة الحساب من هذه العملية', false);
  }
  const ss = _ss();
  const sheet = ss.getSheetByName('Users');
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const userIdIdx = headers.indexOf('user_id');
  const passHashIdx = headers.indexOf('password_hash');
  const saltIdx = headers.indexOf('salt');

  for (let i = 1; i < data.length; i++) {
    if (data[i][userIdIdx] === user.user_id) {
      if (_isTrue_(user.must_change_password) && !body.new_password) {
        throw _apiError(
          'PASSWORD_CHANGE_REQUIRED',
          'يجب تغيير كلمة المرور المؤقتة قبل استخدام التطبيق',
          false
        );
      }
      const updates = { updated_at: _now(), updated_by: user.user_id };
      if (body.full_name !== undefined) updates.full_name = String(body.full_name).trim();
      if (body.phone !== undefined) updates.phone = String(body.phone).trim();
      if (body.new_password) {
        if (!body.old_password) {
          throw _apiError('OLD_PASSWORD_REQUIRED', 'أدخل كلمة المرور الحالية أولاً', false);
        }
        const password = String(body.new_password);
        if (password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
          throw _apiError(
            'WEAK_PASSWORD',
            'يجب أن تتكون كلمة المرور من 8 محارف على الأقل وتضم حرفًا ورقمًا',
            false
          );
        }
        if (!_verifyPassword_(String(body.old_password), {
          password_hash: data[i][passHashIdx],
          salt: data[i][saltIdx]
        })) {
          throw _apiError('INVALID_CREDENTIALS', 'كلمة المرور الحالية غير صحيحة', false);
        }
        const newSalt = Utilities.getUuid();
        updates.password_hash = _passwordHash_(password, newSalt);
        updates.salt = newSalt;
        updates.must_change_password = false;
        const previousValues = {};
        Object.keys(updates).forEach(key => {
          const index = headers.indexOf(key);
          if (index >= 0) previousValues[key] = data[i][index];
        });
        const updated = _updateByField('Users', 'user_id', user.user_id, updates);
        if (!updated) throw new Error('فشل تحديث كلمة المرور');
        try {
          _add('Audit_Log', {
            log_id: Utilities.getUuid(),
            user_id: user.user_id,
            action: 'CHANGE_PASSWORD',
            entity: 'Users',
            entity_id: user.user_id,
            details: 'تغيير كلمة المرور',
            created_at: _now(),
          });
        } catch (error) {
          _updateByField('Users', 'user_id', user.user_id, previousValues);
          throw error;
        }
        _removeSessionsForUser_(user.user_id);
        return {
          success: true,
          message: 'تم تغيير كلمة المرور، سجّل الدخول من جديد',
          session_revoked: true
        };
      }
      _updateByField('Users', 'user_id', user.user_id, updates);
      return { success: true, message: 'تم تحديث البيانات بنجاح' };
    }
  }
  throw new Error('المستخدم غير موجود');
}

const _CUSTOMER_TYPES_ = ['زبون جملة', 'زبون نصف جملة', 'زبون مفرق', 'زبون موزع'];
const _MANAGED_ROLES_ = ['admin', 'manager', 'accountant', 'warehouse', 'salesperson', 'customer'];

function _managedUserView_(user) {
  return {
    user_id: user.user_id,
    username: user.username,
    full_name: user.full_name,
    phone: user.phone || '',
    city: user.city || '',
    address: user.address || '',
    email: user.email || '',
    role: _normalizeRole(user.role),
    customer_id: user.customer_id || '',
    customer_type: user.customer_type || '',
    internal_notes: user.internal_notes || '',
    status: _isActiveStatus_(user.status) ? 'active' : 'inactive',
    must_change_password: _isTrue_(user.must_change_password),
    sales_stock_id: user.sales_stock_id || '',
    cash_box_id: user.cash_box_id || '',
    created_at: user.created_at || '',
    updated_at: user.updated_at || '',
    updated_by: user.updated_by || '',
  };
}

function _managedUserSnapshot_(user) {
  const view = _managedUserView_(user);
  delete view.internal_notes;
  return view;
}

function _assertUniqueUsername_(username, exceptUserId) {
  const normalized = String(username || '').trim().toLowerCase();
  if (!/^[a-z0-9._-]{3,32}$/.test(normalized)) {
    throw _apiError(
      'INVALID_USERNAME',
      'اسم الدخول يجب أن يتكون من 3 إلى 32 حرفًا إنجليزيًا أو رقمًا أو . _ -',
      false
    );
  }
  const duplicate = _all('Users').some(u =>
    String(u.username || '').trim().toLowerCase() === normalized &&
    String(u.user_id) !== String(exceptUserId || '')
  );
  if (duplicate) throw _apiError('USERNAME_EXISTS', 'اسم الدخول مستخدم مسبقًا', false);
  return normalized;
}

function _validateManagedUser_(body, existing) {
  const fullName = String(body.full_name ?? (existing ? existing.full_name : '') ?? '').trim();
  if (!fullName) throw _apiError('INVALID_USER', 'الاسم الكامل مطلوب', false);
  const role = _normalizeRole(body.role ?? (existing ? existing.role : undefined));
  if (!_MANAGED_ROLES_.includes(role)) {
    throw _apiError('INVALID_ROLE', 'الدور المحدد غير صالح', false);
  }
  const customerType = String(body.customer_type ?? (existing ? existing.customer_type : '') ?? '').trim();
  const legacyUnclassifiedCustomer = !!existing &&
    _normalizeRole(existing.role) === 'customer' &&
    !String(existing.customer_type || '').trim() &&
    !String(body.customer_type || '').trim();
  if (role === 'customer' &&
      !_CUSTOMER_TYPES_.includes(customerType) &&
      !legacyUnclassifiedCustomer) {
    throw _apiError('CUSTOMER_TYPE_REQUIRED', 'نوع الزبون مطلوب وصالح للحسابات الجديدة', false);
  }
  const phone = String(body.phone ?? (existing ? existing.phone : '') ?? '').trim();
  const email = String(body.email ?? (existing ? existing.email : '') ?? '').trim();
  if (phone.length > 32 || (email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email))) {
    throw _apiError('INVALID_CONTACT', 'رقم الهاتف أو البريد الإلكتروني غير صالح', false);
  }
  return { full_name: fullName, role, customer_type: role === 'customer' ? customerType : '' };
}

function _assertAdminRemains_(target, nextRole, nextStatus) {
  const wasActiveAdmin = _normalizeRole(target.role) === 'admin' &&
    _isActiveStatus_(target.status);
  const remainsActiveAdmin = nextRole === 'admin' && nextStatus === 'active';
  if (!wasActiveAdmin || remainsActiveAdmin) return;
  const activeAdmins = _all('Users').filter(u =>
    _normalizeRole(u.role) === 'admin' &&
    _isActiveStatus_(u.status)
  ).length;
  if (activeAdmins <= 1) {
    throw _apiError('LAST_ACTIVE_ADMIN', 'لا يمكن تعطيل أو تغيير دور آخر مدير مفعل', false);
  }
}

function _managedUserAudit_(user, action, targetId, before, after, details) {
  _add('Audit_Log', {
    log_id: Utilities.getUuid(),
    user_id: user.user_id,
    action: action,
    entity: 'Users',
    entity_id: targetId,
    details: JSON.stringify({ message: details, before: before, after: after }),
    created_at: _now(),
  });
}

function _handleListUsers(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const query = String(body.query || '').trim().toLowerCase();
  const roleFilter = String(body.role || '').trim();
  const statusFilter = String(body.status || '').trim().toLowerCase();
  const users = _all('Users')
    .map(_managedUserView_)
    .filter(u =>
      (!query || [u.full_name, u.username, u.phone, u.city, u.customer_type]
        .join(' ').toLowerCase().includes(query)) &&
      (!roleFilter || roleFilter === 'all' || u.role === _normalizeRole(roleFilter)) &&
      (!statusFilter || statusFilter === 'all' || u.status === statusFilter)
    );
  return { users: users };
}

function _handleCreateManagedUser(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) throw _apiError('BUSY', 'تعذر قفل إدارة الحسابات، حاول مجددًا', true);
  let createdCustomerId = '';
  let createdUserId = '';
  try {
    const username = _assertUniqueUsername_(body.username);
    const validated = _validateManagedUser_(body);
    const userId = 'USR-' + Utilities.getUuid().replace(/-/g, '').slice(0, 16).toUpperCase();
    const customerId = validated.role === 'customer'
      ? 'CUS-' + Utilities.getUuid().replace(/-/g, '').slice(0, 12).toUpperCase()
      : '';
    const salt = Utilities.getUuid();
    const status = body.status === 'inactive' || body.is_active === false ||
      String(body.is_active || '') === '0' ? 'inactive' : 'active';
    const now = _now();
    const cashBoxId = validated.role === 'salesperson'
      ? String(body.cash_box_id || '').trim() || ('sales_' + userId)
      : '';
    const record = {
      user_id: userId,
      username: username,
      password_hash: _passwordHash_('654321', salt),
      salt: salt,
      full_name: validated.full_name,
      phone: String(body.phone || '').trim(),
      role: validated.role,
      customer_id: customerId,
      status: status,
      must_change_password: true,
      created_at: now,
      last_login: '',
      city: String(body.city || '').trim(),
      address: String(body.address || '').trim(),
      email: String(body.email || '').trim(),
      customer_type: validated.customer_type,
      internal_notes: String(body.internal_notes || '').trim(),
      sales_stock_id: '',
      cash_box_id: cashBoxId,
      updated_at: now,
      updated_by: user.user_id,
    };
    if (customerId) {
      createdCustomerId = customerId;
      _add('Customers', {
        customer_id: customerId,
        full_name: record.full_name,
        phone: record.phone,
        address: record.address,
        province: record.city,
        status: status,
        created_at: now,
        is_system_record: false,
      });
    }
    createdUserId = userId;
    _add('Users', record);
    _managedUserAudit_(user, 'CREATE_USER', userId, null, _managedUserSnapshot_(record), 'إنشاء حساب');
    return { success: true, user: _managedUserView_(record) };
  } catch (error) {
    if (createdUserId) _deleteRowsByField_('Users', 'user_id', createdUserId);
    if (createdCustomerId) _deleteRowsByField_('Customers', 'customer_id', createdCustomerId);
    throw error;
  } finally {
    lock.releaseLock();
  }
}

function _handleUpdateManagedUser(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const targetId = String(body.user_id || '').trim();
  if (!targetId) throw _apiError('USER_ID_REQUIRED', 'معرف الحساب مطلوب', false);
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) throw _apiError('BUSY', 'تعذر قفل إدارة الحسابات، حاول مجددًا', true);
  try {
    const target = _all('Users').find(u => String(u.user_id) === targetId);
    if (!target) throw _apiError('USER_NOT_FOUND', 'الحساب غير موجود', false);
    const validated = _validateManagedUser_(body, target);
    const username = _assertUniqueUsername_(body.username ?? target.username, targetId);
    const status = body.status === undefined && body.is_active === undefined
      ? (_isActiveStatus_(target.status) ? 'active' : 'inactive')
      : (body.status === 'active' || body.is_active === true ||
          String(body.is_active || '') === '1' ? 'active' : 'inactive');
    if (targetId === String(user.user_id) &&
        (status !== (_isActiveStatus_(target.status) ? 'active' : 'inactive') ||
         validated.role !== _normalizeRole(target.role))) {
      throw _apiError(
        'SELF_ROLE_OR_STATUS_CHANGE',
        'لا يمكن تغيير دور حسابك أو حالته من هذه الجلسة',
        false
      );
    }
    _assertAdminRemains_(target, validated.role, status);
    const before = _managedUserSnapshot_(target);
    const now = _now();
    const updates = {
      username: username,
      full_name: validated.full_name,
      phone: String(body.phone ?? target.phone ?? '').trim(),
      role: validated.role,
      status: status,
      city: String(body.city ?? target.city ?? '').trim(),
      address: String(body.address ?? target.address ?? '').trim(),
      email: String(body.email ?? target.email ?? '').trim(),
      customer_type: validated.customer_type,
      internal_notes: String(body.internal_notes ?? target.internal_notes ?? '').trim(),
      updated_at: now,
      updated_by: user.user_id,
    };
    if (validated.role === 'salesperson') {
      updates.cash_box_id = String(body.cash_box_id ?? target.cash_box_id ?? '').trim() ||
        ('sales_' + target.user_id);
    }
    const customer = target.customer_id
      ? _all('Customers').find(row => String(row.customer_id) === String(target.customer_id))
      : null;
    let userUpdated = false;
    let customerUpdated = false;
    try {
      userUpdated = _updateByField('Users', 'user_id', targetId, updates);
      if (!userUpdated) throw new Error('فشل تحديث سجل الحساب');
      const updated = Object.assign({}, target, updates);
      if (target.customer_id && customer) {
        customerUpdated = _updateByField('Customers', 'customer_id', target.customer_id, {
          full_name: updates.full_name,
          phone: updates.phone,
          address: updates.address,
          province: updates.city,
          status: status,
        });
        if (!customerUpdated) throw new Error('فشل تحديث سجل الزبون المرتبط');
      }
      if (String(target.role) !== String(validated.role) ||
          (_isActiveStatus_(target.status) ? 'active' : 'inactive') !== status) {
        _removeSessionsForUser_(targetId);
        if (typeof _deactivateAllUserDevices_ === 'function') {
          _deactivateAllUserDevices_(targetId);
        }
      }
      _managedUserAudit_(user, 'UPDATE_USER', targetId, before, _managedUserSnapshot_(updated), 'تعديل بيانات الحساب');
      return { success: true, user: _managedUserView_(updated) };
    } catch (error) {
      const rollbackErrors = [];
      if (userUpdated) {
        try {
          const restore = {};
          Object.keys(updates).forEach(key => {
            if (Object.prototype.hasOwnProperty.call(target, key)) {
              restore[key] = target[key];
            } else {
              restore[key] = '';
            }
          });
          _updateByField('Users', 'user_id', targetId, restore);
        } catch (rollbackError) {
          rollbackErrors.push(String(rollbackError));
        }
      }
      if (customerUpdated && customer) {
        try {
          _updateByField('Customers', 'customer_id', target.customer_id, {
            full_name: customer.full_name,
            phone: customer.phone,
            address: customer.address,
            province: customer.province,
            status: customer.status,
          });
        } catch (rollbackError) {
          rollbackErrors.push(String(rollbackError));
        }
      }
      if (rollbackErrors.length) {
        throw _apiError(
          'ACCOUNT_UPDATE_ROLLBACK_FAILED',
          'فشل تحديث الحساب وتعذر إكمال التراجع. تحقق من سجل العمليات',
          false
        );
      }
      throw error;
    }
  } finally {
    lock.releaseLock();
  }
}

function _handleSetUserStatus(body, user) {
  const updateBody = {
    user_id: body.user_id,
    status: body.status === 'active' || body.is_active === true ||
      String(body.is_active || '') === '1' ? 'active' : 'inactive',
  };
  return _handleUpdateManagedUser(updateBody, user);
}

function _handleResetManagedPassword(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const targetId = String(body.user_id || '').trim();
  if (!targetId) throw _apiError('USER_ID_REQUIRED', 'معرف الحساب مطلوب', false);
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) throw _apiError('BUSY', 'تعذر قفل إدارة الحسابات، حاول مجددًا', true);
  try {
    const target = _all('Users').find(u => String(u.user_id) === targetId);
    if (!target) throw _apiError('USER_NOT_FOUND', 'الحساب غير موجود', false);
    const salt = Utilities.getUuid();
    const updates = {
      password_hash: _passwordHash_('654321', salt),
      salt: salt,
      must_change_password: true,
      updated_at: _now(),
      updated_by: user.user_id,
    };
    const updated = _updateByField('Users', 'user_id', targetId, updates);
    if (!updated) throw new Error('فشل إعادة تعيين كلمة المرور');
    try {
      _managedUserAudit_(
        user,
        'RESET_USER_PASSWORD',
        targetId,
        _managedUserSnapshot_(target),
        Object.assign({}, _managedUserSnapshot_(target), { must_change_password: true }),
        'إعادة تعيين كلمة المرور وإبطال الجلسات'
      );
    } catch (error) {
      const restore = {};
      ['password_hash', 'salt', 'must_change_password', 'updated_at', 'updated_by']
        .forEach(key => { restore[key] = target[key] || ''; });
      _updateByField('Users', 'user_id', targetId, restore);
      throw error;
    }
    _removeSessionsForUser_(targetId);
    if (typeof _deactivateAllUserDevices_ === 'function') {
      _deactivateAllUserDevices_(targetId);
    }
    return { success: true, must_change_password: true };
  } finally {
    lock.releaseLock();
  }
}

// ============================================================
// 6. المنتجات (Products)
// ============================================================
// Offers are separate from product prices and share the order-creation script lock.
function _offerError_(code, message) {
  throw _apiError(code, message, false);
}

function _offerBoolean_(value) {
  if (value === true || value === 1 || value === '1') return true;
  if (value === false || value === 0 || value === '0') return false;
  if (typeof value === 'string') {
    const text = value.trim().toLowerCase();
    if (text === 'true' || text === 'yes') return true;
    if (text === 'false' || text === 'no') return false;
  }
  _offerError_('INVALID_OFFER', 'قيمة منطقية غير صالحة');
}

function _offerTime_(value) {
  if (value instanceof Date) {
    if (Number.isFinite(value.getTime())) return value.toISOString();
    _offerError_('INVALID_OFFER', 'تاريخ العرض غير صالح');
  }
  if (typeof value !== 'string') _offerError_('INVALID_OFFER', 'التاريخ يتطلب توقيت UTC أو إزاحة');
  const m = value.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?(Z|[+-]\d{2}:\d{2})$/);
  if (!m) _offerError_('INVALID_OFFER', 'التاريخ يتطلب توقيت UTC أو إزاحة');
  const year = Number(m[1]), month = Number(m[2]), day = Number(m[3]);
  const hour = Number(m[4]), minute = Number(m[5]), second = Number(m[6]);
  const calendar = new Date(0);
  calendar.setUTCFullYear(year, month - 1, day);
  calendar.setUTCHours(hour, minute, second, 0);
  if (month < 1 || month > 12 || day < 1 || hour > 23 || minute > 59 || second > 59 ||
      calendar.getUTCFullYear() !== year || calendar.getUTCMonth() !== month - 1 || calendar.getUTCDate() !== day) {
    _offerError_('INVALID_OFFER', 'تاريخ العرض غير صالح');
  }
  if (m[8] !== 'Z') {
    const offsetHour = Number(m[8].slice(1, 3)), offsetMinute = Number(m[8].slice(4, 6));
    if (offsetHour > 14 || offsetMinute > 59 || (offsetHour === 14 && offsetMinute !== 0)) {
      _offerError_('INVALID_OFFER', 'إزاحة التوقيت غير صالحة');
    }
  }
  const ms = Date.parse(value);
  if (!Number.isFinite(ms)) _offerError_('INVALID_OFFER', 'تاريخ العرض غير صالح');
  return new Date(ms).toISOString();
}

function _offerStatus_(offer, now) {
  if (offer.archived_at) return 'archived';
  if (!_offerBoolean_(offer.enabled)) return 'disabled';
  const start = Date.parse(_offerTime_(offer.starts_at));
  const end = Date.parse(_offerTime_(offer.ends_at));
  if (now < start) return 'scheduled';
  return now < end ? 'active' : 'expired';
}

function _offerPublic_(offer, role, now) {
  const result = {};
  H.Offers.forEach(key => { result[key] = offer[key] === undefined ? '' : offer[key]; });
  let bundleItems = [];
  if (Array.isArray(offer.bundle_items)) {
    bundleItems = offer.bundle_items;
  } else if (String(offer.bundle_items || '').trim()) {
    try {
      bundleItems = JSON.parse(offer.bundle_items);
    } catch (error) {
      _offerError_('INVALID_OFFER', 'بيانات مكونات الحزمة غير صالحة');
    }
  }
  if (!Array.isArray(bundleItems)) {
    _offerError_('INVALID_OFFER', 'بيانات مكونات الحزمة غير صالحة');
  }
  result.bundle_items = bundleItems;
  result.enabled = _offerBoolean_(offer.enabled);
  ['old_price', 'offer_price', 'min_quantity', 'sort_order', 'revision'].forEach(key => {
    result[key] = Number(offer[key]);
  });
  ['starts_at', 'ends_at', 'created_at', 'updated_at', 'archived_at'].forEach(key => {
    if (result[key]) result[key] = _offerTime_(result[key]);
  });
  result.status = _offerStatus_(offer, now);
  if (_normalizeRole(role) === 'warehouse') {
    delete result.old_price;
    delete result.offer_price;
    result.bundle_items = bundleItems.map(item => {
      const safeItem = Object.assign({}, item);
      delete safeItem.old_price;
      delete safeItem.offer_price;
      return safeItem;
    });
  }
  return result;
}

function _offerManager_(user) {
  if (!canPriceOrder_(user.role)) _offerError_('FORBIDDEN', 'ليست لديك صلاحية إدارة العروض');
}

function _offerNumber_(value, positive) {
  if ((typeof value !== 'number' && typeof value !== 'string') ||
      String(value).trim() === '' || !Number.isFinite(Number(value)) ||
      (positive && Number(value) <= 0)) {
    _offerError_('INVALID_OFFER', 'قيمة رقمية غير صالحة');
  }
  return Number(value);
}

function _offerText_(value, required) {
  if (typeof value !== 'string' || (required && !value.trim()) || value.length > 2000) {
    _offerError_('INVALID_OFFER', 'نص العرض غير صالح');
  }
  return value.trim();
}

function _offerProductPrice_(product, unit) {
  if (!product) return null;
  const definitions = [
    [product.unit_1, product.display_price, 1],
    [product.unit_2, product.price_2, product.factor_2],
    [product.unit_3, product.price_3, product.factor_3]
  ];
  const matching = definitions.filter(entry => String(entry[0] || '').trim() === unit);
  if (matching.length !== 1) return null;
  const price = matching[0][1], factor = Number(matching[0][2]);
  if (price == null || String(price).trim() === '' || !Number.isFinite(Number(price)) ||
      Number(price) <= 0 || !Number.isFinite(factor) || factor <= 0) return null;
  return Number(price);
}

function _offerMatchesProduct_(offer, product) {
  const bundleItems = _offerBundleItems_(offer);
  if (bundleItems.length > 1) {
    return bundleItems.every(item => {
      const componentProduct = product && String(product.code).trim() ===
        String(item.product_code).trim()
        ? product
        : _all('Products').find(candidate =>
          String(candidate.code).trim() === String(item.product_code).trim());
      const normalPrice = _offerProductPrice_(componentProduct, String(item.unit).trim());
      return normalPrice !== null &&
        Number.isFinite(Number(item.old_price)) &&
        Number.isFinite(Number(item.offer_price)) &&
        Number(item.offer_price) > 0 &&
        Number(item.offer_price) < Number(item.old_price) &&
        Number(item.old_price) <= normalPrice &&
        String(componentProduct.currency || 'USD').trim().toUpperCase() ===
          String(offer.currency || '').trim().toUpperCase();
    });
  }
  const price = _offerProductPrice_(product, String(offer.unit || '').trim());
  const oldPrice = Number(offer.old_price), offerPrice = Number(offer.offer_price);
  return price !== null && Number.isFinite(oldPrice) && Number.isFinite(offerPrice) &&
    offerPrice > 0 && offerPrice < oldPrice && oldPrice <= price &&
    String(product.currency || 'USD').trim().toUpperCase() === String(offer.currency || '').trim().toUpperCase();
}

function _offerBundleItems_(offer) {
  if (Array.isArray(offer.bundle_items)) return offer.bundle_items;
  const raw = String(offer.bundle_items || '').trim();
  if (!raw) return [];
  try {
    const items = JSON.parse(raw);
    if (!Array.isArray(items)) _offerError_('INVALID_OFFER', 'بيانات مكونات الحزمة غير صالحة');
    return items;
  } catch (error) {
    _offerError_('INVALID_OFFER', 'بيانات مكونات الحزمة غير صالحة');
  }
}

function _offerInputBundleItems_(input) {
  const value = input.bundle_items;
  if (value == null || value === '') return [];
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    return _offerBundleItems_({ bundle_items: value });
  }
  _offerError_('INVALID_OFFER', 'بيانات مكونات الحزمة غير صالحة');
}

function _offerOverlapKeys_(offer) {
  const bundleItems = _offerBundleItems_(offer);
  if (bundleItems.length > 1) {
    return bundleItems.map(item =>
      String(item.product_code).trim() + '\u001f' + String(item.unit).trim());
  }
  return [String(offer.product_code).trim() + '\u001f' +
    String(offer.unit).trim()];
}

function _offerComponentFor_(offer, code, unit) {
  const component = _offerBundleItems_(offer).find(item =>
    String(item.product_code).trim() === String(code || '').trim() &&
    String(item.unit).trim() === String(unit || '').trim());
  return component || null;
}

function _offerComponent_(input, products, currency) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    _offerError_('INVALID_OFFER', 'مكوّن الحزمة غير صالح');
  }
  const productCode = _offerText_(input.product_code, true);
  const product = products.find(candidate =>
    String(candidate.code).trim() === productCode);
  if (!product) _offerError_('PRODUCT_NOT_FOUND', 'منتج في الحزمة غير موجود');
  const unit = _offerText_(input.unit, true);
  if (![product.unit_1, product.unit_2, product.unit_3]
      .map(value => String(value || '').trim()).filter(Boolean).includes(unit)) {
    _offerError_('INVALID_PRODUCT_UNIT', 'وحدة منتج في الحزمة غير معرفة');
  }
  if (String(product.currency || 'USD').trim().toUpperCase() !== currency) {
    _offerError_('INVALID_OFFER', 'يجب توحيد عملة جميع منتجات الحزمة');
  }
  const quantity = _offerNumber_(input.quantity, true);
  if (!Number.isSafeInteger(quantity)) {
    _offerError_('INVALID_OFFER', 'كمية كل منتج في الحزمة يجب أن تكون عدداً صحيحاً');
  }
  const oldPrice = _offerNumber_(input.old_price, true);
  const offerPrice = _offerNumber_(input.offer_price, true);
  const regularPrice = _offerProductPrice_(product, unit);
  if (offerPrice >= oldPrice || regularPrice === null || oldPrice > regularPrice) {
    _offerError_('INVALID_OFFER', 'سعر مكوّن الحزمة لا يطابق سعر المنتج أو لا يتضمن تخفيضاً');
  }
  return {
    product_code: productCode,
    product_name: String(product.name || ''),
    unit: unit,
    quantity: quantity,
    old_price: oldPrice,
    offer_price: offerPrice,
  };
}

function _offerValidate_(input, product) {
  const offer = {};
  offer.title = _offerText_(input.title == null ? '' : input.title, false);
  offer.note = _offerText_(input.note == null ? '' : input.note, false);
  offer.currency = _offerText_(input.currency, true).toUpperCase();
  const products = _all('Products');
  const suppliedBundle = _offerInputBundleItems_(input);
  if (suppliedBundle.length > 1) {
    const bundleItems = suppliedBundle.map(item =>
      _offerComponent_(item, products, offer.currency));
    const keys = new Set();
    bundleItems.forEach(item => {
      const key = item.product_code + '\u001f' + item.unit;
      if (keys.has(key)) _offerError_('INVALID_OFFER', 'لا تكرر المنتج والوحدة ضمن الحزمة');
      keys.add(key);
    });
    offer.bundle_items = JSON.stringify(bundleItems);
    offer.product_code = bundleItems[0].product_code;
    offer.unit = 'حزمة';
    offer.old_price = bundleItems.reduce(
      (sum, item) => sum + item.quantity * item.old_price, 0);
    offer.offer_price = bundleItems.reduce(
      (sum, item) => sum + item.quantity * item.offer_price, 0);
    offer.min_quantity = 1;
    const totalOld = bundleItems.reduce(
      (sum, item) => sum + item.quantity * item.old_price, 0);
    if (!(offer.offer_price > 0 && offer.offer_price < totalOld)) {
      _offerError_('INVALID_OFFER', 'سعر الحزمة يجب أن يكون أقل من مجموع أسعارها السابقة');
    }
  } else {
    offer.bundle_items = '';
    offer.product_code = _offerText_(input.product_code, true);
    offer.unit = _offerText_(input.unit, true);
    if (!product) _offerError_('PRODUCT_NOT_FOUND', 'المنتج غير موجود');
    if (![product.unit_1, product.unit_2, product.unit_3].map(v => String(v || '').trim()).filter(Boolean).includes(offer.unit)) {
      _offerError_('INVALID_PRODUCT_UNIT', 'الوحدة غير معرفة للمنتج');
    }
    const productCurrency = String(product.currency || 'USD').trim().toUpperCase();
    if (!['USD', 'SYP'].includes(offer.currency) || offer.currency !== productCurrency) {
      _offerError_('INVALID_OFFER', 'عملة العرض غير مدعومة أو لا تطابق المنتج');
    }
    offer.old_price = _offerNumber_(input.old_price, true);
    offer.offer_price = _offerNumber_(input.offer_price, true);
    if (offer.offer_price >= offer.old_price) _offerError_('INVALID_OFFER', 'سعر العرض يجب أن يكون أقل من السعر القديم');
    if (!_offerMatchesProduct_(offer, product)) {
      _offerError_('INVALID_OFFER', 'أسعار العرض تتجاوز سعر وحدة المنتج المهيأ أو سعر الوحدة غير صالح');
    }
    offer.min_quantity = _offerNumber_(input.min_quantity, true);
  }
  if (!['USD', 'SYP'].includes(offer.currency)) {
    _offerError_('INVALID_OFFER', 'عملة العرض غير مدعومة');
  }
  if (!product) _offerError_('PRODUCT_NOT_FOUND', 'المنتج غير موجود');
  offer.sort_order = _offerNumber_(input.sort_order == null ? 0 : input.sort_order, false);
  offer.enabled = _offerBoolean_(input.enabled == null ? true : input.enabled);
  // API timestamps must be strings with an explicit zone, never local sheet dates.
  if (typeof input.starts_at !== 'string' || typeof input.ends_at !== 'string') {
    _offerError_('INVALID_OFFER', 'تاريخ العرض يتطلب توقيت UTC أو إزاحة');
  }
  offer.starts_at = _offerTime_(input.starts_at);
  offer.ends_at = _offerTime_(input.ends_at);
  if (Date.parse(offer.ends_at) <= Date.parse(offer.starts_at)) _offerError_('INVALID_OFFER', 'نهاية العرض يجب أن تلي بدايته');
  return offer;
}

function _offerWrite_(offer, existing) {
  const sheet = _ss().getSheetByName('Offers');
  const data = sheet.getDataRange().getValues();
  const headers = data[0].map(h => String(h).trim());
  const safe = value => typeof value === 'string' && /^[=+\-@]/.test(value) ? "'" + value : value;
  if (!existing) {
    sheet.appendRow(headers.map(key => safe(offer[key] == null ? '' : offer[key])));
    return;
  }
  const idIndex = headers.indexOf('offer_id');
  const rowIndex = data.findIndex((row, i) => i > 0 && String(row[idIndex]) === String(existing.offer_id));
  if (rowIndex < 1) _offerError_('OFFER_NOT_FOUND', 'العرض غير موجود');
  const row = headers.map((key, index) =>
    Object.prototype.hasOwnProperty.call(offer, key) ? safe(offer[key]) : data[rowIndex][index]);
  sheet.getRange(rowIndex + 1, 1, 1, headers.length).setValues([row]);
}

function _offerAudit_(user, action, before, after, now) {
  const timestamp = new Date(now).toISOString();
  _add('Audit_Log', {
    log_id: Utilities.getUuid(),
    user_id: user.user_id,
    action: action,
    entity: 'Offers',
    entity_id: after.offer_id,
    details: JSON.stringify({
      before: before ? _offerPublic_(before, 'admin', now) : null,
      after: _offerPublic_(after, 'admin', now)
    }),
    created_at: timestamp
  });
}

function _handleOfferList_(body, user) {
  const manage = body.manage == null ? false : _offerBoolean_(body.manage);
  if (manage) _offerManager_(user);
  _requireColumns_('Offers', H.Offers);
  const now = Date.now();
  const products = new Map((manage ? [] : _all('Products'))
    .map(product => [String(product.code).trim(), product]));
  const offers = _all('Offers').filter(offer => manage ||
    (_offerStatus_(offer, now) === 'active' && _offerMatchesProduct_(offer,
      products.get(String(offer.product_code).trim()))))
    .map(offer => _offerPublic_(offer, user.role, now))
    .sort((a, b) => a.sort_order - b.sort_order || String(a.offer_id).localeCompare(String(b.offer_id)));
  return { offers: offers, server_time: new Date(now).toISOString() };
}

function _handleOfferSave_(body, user) {
  _offerManager_(user);
  if (!body.offer || typeof body.offer !== 'object' || Array.isArray(body.offer)) _offerError_('INVALID_OFFER', 'بيانات العرض مطلوبة');
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) throw _apiError('BUSY', 'العروض قيد التحديث، حاول مجدداً', true);
  try {
    _requireColumns_('Offers', H.Offers);
    _requireColumns_('Audit_Log', H.Audit_Log);
    const input = body.offer;
    const id = String(input.offer_id || '').trim();
    const offers = _all('Offers');
    const previous = id ? offers.find(o => String(o.offer_id) === id) : null;
    if (id && !previous) _offerError_('OFFER_NOT_FOUND', 'العرض غير موجود');
    if (previous && previous.archived_at) _offerError_('OFFER_ARCHIVED', 'لا يمكن تعديل عرض مؤرشف');
    if (previous && (!Number.isSafeInteger(Number(input.revision)) || Number(input.revision) !== Number(previous.revision))) {
      _offerError_('OFFER_CHANGED', 'تغير العرض، يرجى إعادة تحميله');
    }
    const merged = Object.assign({}, previous || {}, input);
    if (previous) {
      if (!Object.prototype.hasOwnProperty.call(input, 'starts_at')) merged.starts_at = _offerTime_(previous.starts_at);
      if (!Object.prototype.hasOwnProperty.call(input, 'ends_at')) merged.ends_at = _offerTime_(previous.ends_at);
    }
    const code = typeof merged.product_code === 'string' ? merged.product_code.trim() : '';
    const product = _all('Products').find(p => String(p.code).trim() === code);
    const offer = _offerValidate_(merged, product);
    if (offer.enabled) {
      const offerKeys = new Set(_offerOverlapKeys_(offer));
      const overlap = offers.some(other => {
        if (String(other.offer_id) === id || other.archived_at ||
            !_offerBoolean_(other.enabled) ||
            !_offerOverlapKeys_(other).some(key => offerKeys.has(key))) return false;
        return Date.parse(_offerTime_(other.starts_at)) < Date.parse(offer.ends_at) &&
          Date.parse(offer.starts_at) < Date.parse(_offerTime_(other.ends_at));
      });
      if (overlap) _offerError_('OFFER_OVERLAP', 'يوجد عرض مفعل متداخل للمنتج والوحدة');
    }
    const nowMs = Date.now();
    const now = new Date(nowMs).toISOString();
    Object.assign(offer, {
      offer_id: previous ? previous.offer_id : 'OFR-' + Utilities.getUuid(),
      revision: previous ? Number(previous.revision) + 1 : 1,
      created_at: previous ? previous.created_at : now,
      created_by: previous ? previous.created_by : user.user_id,
      updated_at: now, updated_by: user.user_id,
      archived_at: '', archived_by: ''
    });
    const action = !previous ? 'OFFER_CREATE' :
      _offerBoolean_(previous.enabled) !== offer.enabled
        ? (offer.enabled ? 'OFFER_ENABLE' : 'OFFER_DISABLE') : 'OFFER_UPDATE';
    _offerAudit_(user, action, previous, offer, nowMs);
    SpreadsheetApp.flush();
    _offerWrite_(offer, previous);
    SpreadsheetApp.flush();
    return { offer: _offerPublic_(offer, user.role, Date.now()) };
  } finally {
    lock.releaseLock();
  }
}

function _handleOfferArchive_(body, user) {
  _offerManager_(user);
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) throw _apiError('BUSY', 'العروض قيد التحديث، حاول مجدداً', true);
  try {
    _requireColumns_('Offers', H.Offers);
    _requireColumns_('Audit_Log', H.Audit_Log);
    const id = String(body.offer_id || '').trim();
    const offer = _all('Offers').find(o => String(o.offer_id) === id);
    if (!offer) _offerError_('OFFER_NOT_FOUND', 'العرض غير موجود');
    if (!Number.isSafeInteger(Number(body.revision)) || Number(body.revision) !== Number(offer.revision)) {
      _offerError_('OFFER_CHANGED', 'تغير العرض، يرجى إعادة تحميله');
    }
    if (offer.archived_at) _offerError_('OFFER_ARCHIVED', 'العرض مؤرشف');
    const before = Object.assign({}, offer);
    const nowMs = Date.now();
    const now = new Date(nowMs).toISOString();
    Object.assign(offer, { enabled: false, revision: Number(offer.revision) + 1,
      updated_at: now, updated_by: user.user_id, archived_at: now, archived_by: user.user_id });
    _offerAudit_(user, 'OFFER_ARCHIVE', before, offer, nowMs);
    SpreadsheetApp.flush();
    _offerWrite_(offer, offer);
    SpreadsheetApp.flush();
    return { offer: _offerPublic_(offer, user.role, Date.now()) };
  } finally {
    lock.releaseLock();
  }
}

function _orderOfferClaim_(item, offers, currency, now) {
  const keys = ['offer_id', 'offer_revision', 'offer_price'];
  const claimed = keys.some(key => Object.prototype.hasOwnProperty.call(item, key));
  if (!claimed) return null;
  const changed = () => _offerError_('OFFER_CHANGED', 'العرض تغير أو لم يعد مؤهلاً، يرجى تحديث الطلب');
  if (!keys.every(key => Object.prototype.hasOwnProperty.call(item, key)) ||
      typeof item.offer_id !== 'string' || !item.offer_id.trim() ||
      !['number', 'string'].includes(typeof item.offer_revision) ||
      String(item.offer_revision).trim() === '' ||
      !Number.isSafeInteger(Number(item.offer_revision)) || Number(item.offer_revision) <= 0 ||
      !['number', 'string'].includes(typeof item.offer_price) || String(item.offer_price).trim() === '' ||
      !Number.isFinite(Number(item.offer_price))) changed();
  const offer = offers.find(o => String(o.offer_id) === item.offer_id.trim());
  if (!offer) changed();
  try {
    const quantity = Number(item.quantity ?? item.quantity_requested);
    const bundleItems = _offerBundleItems_(offer);
    if (bundleItems.length > 1) {
      const component = bundleItems.find(entry =>
        String(entry.product_code).trim() === String(item.code || '').trim() &&
        String(entry.unit).trim() === String(item.unit || '').trim());
      const bundleCount = component
        ? quantity / Number(component.quantity)
        : NaN;
      if (_offerStatus_(offer, now) !== 'active' ||
          String(offer.currency).trim().toUpperCase() !== currency ||
          !component ||
          !Number.isFinite(quantity) || quantity <= 0 ||
          !Number.isSafeInteger(bundleCount) || bundleCount < 1 ||
          Number(item.offer_revision) !== Number(offer.revision) ||
          Number(item.offer_price) !== Number(component.offer_price) ||
          !Number.isFinite(Number(component.old_price)) ||
          Number(component.old_price) <= Number(component.offer_price) ||
          Date.parse(_offerTime_(offer.ends_at)) <= Date.parse(_offerTime_(offer.starts_at))) {
        changed();
      }
      return offer;
    }
    if (_offerStatus_(offer, now) !== 'active' ||
        String(offer.product_code).trim() !== String(item.code || '').trim() ||
        String(offer.unit).trim() !== String(item.unit || '').trim() ||
        String(offer.currency).trim().toUpperCase() !== currency ||
        !Number.isFinite(quantity) || quantity <= 0 ||
        !Number.isFinite(Number(offer.min_quantity)) || Number(offer.min_quantity) <= 0 ||
        quantity < Number(offer.min_quantity) ||
        Number(item.offer_revision) !== Number(offer.revision) ||
        Number(item.offer_price) !== Number(offer.offer_price) ||
        !Number.isFinite(Number(offer.offer_price)) || Number(offer.offer_price) <= 0 ||
        !Number.isFinite(Number(offer.old_price)) || Number(offer.old_price) <= Number(offer.offer_price) ||
        Date.parse(_offerTime_(offer.ends_at)) <= Date.parse(_offerTime_(offer.starts_at))) changed();
  } catch (error) {
    changed();
  }
  return offer;
}

function _validateOfferBundles_(validatedItems) {
  const grouped = new Map();
  validatedItems.forEach(validated => {
    if (!validated.offer) return;
    const components = _offerBundleItems_(validated.offer);
    if (components.length < 2) return;
    const group = grouped.get(validated.offer.offer_id) || [];
    group.push(validated);
    grouped.set(validated.offer.offer_id, group);
  });
  grouped.forEach((lines, offerId) => {
    const offer = lines[0].offer;
    const components = _offerBundleItems_(offer);
    const changed = () => _offerError_('OFFER_CHANGED', 'يجب طلب مكونات الحزمة كاملة وبالكميات المحددة');
    if (lines.length !== components.length) changed();
    const bundleCounts = [];
    const seen = new Set();
    lines.forEach(line => {
      const key = line.code + '\u001f' + line.unit;
      if (seen.has(key)) changed();
      seen.add(key);
      const component = components.find(entry =>
        String(entry.product_code).trim() === line.code &&
        String(entry.unit).trim() === line.unit);
      if (!component) changed();
      const count = line.quantity / Number(component.quantity);
      if (!Number.isSafeInteger(count) || count < 1) changed();
      bundleCounts.push(count);
    });
    if (bundleCounts.some(count => count !== bundleCounts[0])) changed();
    if (components.some(component =>
      !seen.has(String(component.product_code).trim() + '\u001f' +
        String(component.unit).trim()))) changed();
    if (String(offer.offer_id) !== offerId) changed();
  });
}

function _validateUnchangedOfferItem_(input, previous, partial) {
  const reject = () => _offerError_('OFFER_REQUOTE_REQUIRED', 'تغيير بند العرض يتطلب إعادة اقتباس');
  if (input.action === 'delete') reject();
  const sameNumber = (a, b) => a != null && b != null &&
    String(a).trim() !== '' && String(b).trim() !== '' &&
    Number.isFinite(Number(a)) && Number.isFinite(Number(b)) && Number(a) === Number(b);
  if (!sameNumber(input.quantity, previous.quantity_requested)) reject();
  if ((!partial || input.unit !== undefined) &&
      String(input.unit || '').trim() !== String(previous.unit || '').trim()) reject();
  if (input.code !== undefined && String(input.code).trim() !== String(previous.code).trim()) reject();
  const snapshotFields = [
    'offer_id', 'offer_revision', 'offer_old_price', 'offer_min_quantity',
    'offer_starts_at', 'offer_ends_at', 'unit_price_snapshot', 'display_price_snapshot',
    'base_price_snapshot', 'unit_factor', 'unit_1', 'unit_2', 'unit_3', 'factor_2', 'factor_3',
    'quantity_requested', 'quantity_approved', 'final_price', 'total_price', 'currency', 'status'
  ];
  const numericFields = ['offer_revision', 'offer_old_price', 'offer_min_quantity',
    'unit_price_snapshot', 'display_price_snapshot', 'base_price_snapshot', 'unit_factor', 'factor_2', 'factor_3',
    'quantity_requested', 'quantity_approved', 'final_price', 'total_price'];
  snapshotFields.forEach(field => {
    if (!Object.prototype.hasOwnProperty.call(input, field)) return;
    const a = input[field], b = previous[field];
    if ((a == null || a === '') && (b == null || b === '')) return;
    if (field === 'offer_starts_at' || field === 'offer_ends_at') {
      try {
        if (_offerTime_(a) !== _offerTime_(b)) reject();
      } catch (error) {
        reject();
      }
    } else if (numericFields.includes(field) ? !sameNumber(a, b) : String(a) !== String(b)) reject();
  });
  if (input.offer_price !== undefined && !sameNumber(input.offer_price, previous.unit_price_snapshot)) reject();
  if (input.price !== undefined && input.price !== null && input.price !== '') {
    const price = previous.final_price !== '' && previous.final_price != null
      ? previous.final_price : previous.unit_price_snapshot;
    if (!sameNumber(input.price, price)) reject();
  }
}

function _handleProducts(body, user) {
  const q = String(body.q || '').toLowerCase();
  const defaultProductCurrency = _normalizeRole(user.role) === 'salesperson'
    ? _salesProperty_('DEFAULT_PRODUCT_CURRENCY')
    : '';
  const products = _all('Products');
  const newProducts = _all('New_Products');
  const imageIndex = _all('Product_Images');
  const newProductMap = {};
  newProducts.forEach(product => {
    newProductMap[String(product.code)] = product;
  });

  // بناء خريطة للبحث السريع عن الصور O(1)
  const imageMaps = _buildImageIndexMaps_(imageIndex);

  // دمج المنتجات من Sheet الأساسية والجديدة
  let allList = [...products];
  const knownProductCodes = new Set(products.map(product => product.code));
  newProducts.forEach(np => {
    if (!knownProductCodes.has(np.code)) {
      knownProductCodes.add(np.code);
      allList.push(np);
    }
  });

  return {
    products: allList
      .filter(p =>
        !q ||
        String(p.code).toLowerCase().includes(q) ||
        String(p.name).toLowerCase().includes(q) ||
        String(p.group || '').toLowerCase().includes(q) ||
        String(p.oem || p.OEM || '').toLowerCase().includes(q)
      )
      .map(p => {
        const imgData = _findIndexedProductImage_(p, imageMaps);

        const item = _serializeProductForRole(
          p,
          user.role,
          imgData ? imgData.image_url : '',
          defaultProductCurrency
        );
        const newProduct = newProductMap[String(p.code)];
        item.is_new = p.show_in_new === 'true' ||
          p.show_in_new === true ||
          !!newProduct;
        if (!item.created_at && newProduct && newProduct.created_at) {
          item.created_at = newProduct.created_at;
        }
        return item;
      })
  };
}

function _handleNewProducts(body, user) {
  const defaultProductCurrency = _normalizeRole(user.role) === 'salesperson'
    ? _salesProperty_('DEFAULT_PRODUCT_CURRENCY')
    : '';
  const catalogProducts = {};
  _all('Products').forEach(product => {
    catalogProducts[String(product.code)] = product;
  });
  const imageMaps = _buildImageIndexMaps_(_all('Product_Images'));
  const newProducts = _all('New_Products')
    .filter(p =>
      (p.show_in_new === 'true' || p.show_in_new === true) &&
      p.created_at &&
      !isNaN(Date.parse(p.created_at))
    )
    .sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at));
  return {
    products: newProducts.map(p => {
      const baseProduct = catalogProducts[String(p.code)] || {};
      const mergedProduct = Object.assign({}, baseProduct, p);
      const indexedImage = _findIndexedProductImage_(mergedProduct, imageMaps);
      const imageUrl = p.image_url ||
        (indexedImage && indexedImage.image_url) ||
        baseProduct.image_url ||
        '';
      const product = _serializeProductForRole(
        mergedProduct,
        user.role,
        imageUrl,
        defaultProductCurrency
      );
      product.is_new = true;
      return product;
    })
  };
}

function _handleBestSellers(body, user) {
  const orderItems = _all('Order_Items');
  const products = [..._all('Products'), ..._all('New_Products')];
  const productsByCode = new Map();
  products.forEach(product => {
    const code = String(product.code);
    if (!productsByCode.has(code)) productsByCode.set(code, product);
  });
  const orders = _all('Orders');
  const imageIndex = _all('Product_Images');
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const approvedOrderIds = {};
  orders.forEach(order => {
    const status = String(order.status || '').toLowerCase();
    const createdAt = Date.parse(order.created_at || '');
    if (
      ['approved', 'prepared'].includes(status) &&
      !isNaN(createdAt) &&
      createdAt >= thirtyDaysAgo.getTime()
    ) {
      approvedOrderIds[String(order.order_id)] = true;
    }
  });

  const salesMap = {};
  orderItems.forEach(item => {
    const code = String(item.code || '');
    const quantity = Number(item.quantity_approved || 0);
    if (
      code &&
      approvedOrderIds[String(item.order_id)] &&
      isFinite(quantity) &&
      quantity > 0
    ) {
      salesMap[code] = (salesMap[code] || 0) + quantity;
    }
  });

  const userRole = _normalizeRole(user.role);
  if (!['admin', 'manager', 'accountant', 'warehouse', 'customer', 'salesperson'].includes(userRole)) {
    throw new Error('غير مصرح لك بعرض المنتجات');
  }
  const defaultProductCurrency = userRole === 'salesperson'
    ? _salesProperty_('DEFAULT_PRODUCT_CURRENCY')
    : '';

  const imageMaps = _buildImageIndexMaps_(imageIndex);

  const bestSellers = Object.keys(salesMap)
    .map(code => {
      const product = productsByCode.get(code);
      if (!product) return null;
      const image = _findIndexedProductImage_(product, imageMaps);
      const safeProduct = _serializeProductForRole(
        product,
        userRole,
        image ? image.image_url : product.image_url || '',
        defaultProductCurrency
      );
      safeProduct.order_units = salesMap[code];
      return safeProduct;
    })
    .filter(Boolean)
    .sort((a, b) =>
      b.order_units - a.order_units || String(a.code).localeCompare(String(b.code))
    )
    .slice(0, 10);

  return { products: bestSellers };
}

function _handleSearchProducts(body, user) {
  const query = String(body.q || body.query || '').toLowerCase();
  const category = body.category || body.group || '';
  const defaultProductCurrency = _normalizeRole(user.role) === 'salesperson'
    ? _salesProperty_('DEFAULT_PRODUCT_CURRENCY')
    : '';
  const products = _all('Products');
  const imageIndex = _all('Product_Images');
  const imageMaps = _buildImageIndexMaps_(imageIndex);

  let filtered = products;
  
  // تصفية حسب البحث النصي
  if (query) {
    filtered = filtered.filter(p =>
      String(p.code).toLowerCase().includes(query) ||
      String(p.name).toLowerCase().includes(query) ||
      String(p.group).toLowerCase().includes(query) ||
      String(p.oem || p.OEM || '').toLowerCase().includes(query)
    );
  }
  
  // تصفية حسب الفئة
  if (category) {
    filtered = filtered.filter(p => String(p.group).toLowerCase() === String(category).toLowerCase());
  }

  return {
    products: filtered.map(p => {
      const imgData = _findIndexedProductImage_(p, imageMaps);
      const product = _serializeProductForRole(
        p,
        user.role,
        imgData ? imgData.image_url : '',
        defaultProductCurrency
      );
      product.image_name = p.image_name || p.code;
      product.image_id = imgData ? imgData.file_id : (p.image_id || '');
      product.origin = p.origin;
      return product;
    })
  };
}

function _handleGetProductCategories(body, user) {
  const products = _all('Products');
  const categories = [...new Set(products.map(p => String(p.group || '').trim()).filter(g => g))];
  return { categories: categories.sort() };
}

function _handleUpdateProductQuantity(body, user) {
  _needRole(user, ['admin']);
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) {
    throw _apiError('BUSY', 'المخزون قيد التحديث، حاول مجددًا', true);
  }
  try {
    const code = body.code;
    const delta = Number(body.quantity || 0);
    if (!code) throw new Error('كود المنتج مطلوب');

    if (_updateProductQuantity(code, delta)) {
      const product = _all('Products').find(p => String(p.code) === String(code));
      const productName = product ? product.name : code;
      _add('Inventory_Movements', {
        movement_id: Utilities.getUuid(),
        code: code,
        type: delta > 0 ? 'receipt' : 'adjustment',
        quantity: Math.abs(delta),
        note: body.note || 'تحديث مخزون يدوي',
        created_by: user.user_id,
        created_at: _now(),
      });
      _sendNotificationToRoles(
        'admin,accountant,warehouse',
        'تم تحديث المخزون',
        'تم تحديث كمية المنتج ' + productName + '.',
        'inventory.quantity_updated',
        code,
        { product_id: code, high_priority: false }
      );
      const minimum = Number(product && (
        product.minimum_stock || product.min_stock || product.minimum_quantity
      ) || 0);
      const updatedQuantity = Number(product && product.quantity || 0);
      if (minimum > 0 && updatedQuantity < minimum) {
        _sendNotificationToRoles(
          'admin,accountant',
          'تنبيه انخفاض المخزون',
          'انخفض مخزون المنتج ' + productName + ' عن الحد الأدنى.',
          'alert.low_stock',
          code,
          { product_id: code, high_priority: true }
        );
      }
      return { success: true, message: 'تم تحديث المخزون' };
    }
    throw new Error('المنتج غير موجود');
  } finally {
    lock.releaseLock();
  }
}

function _handleReceiveGoods(body, user) {
  _needRole(user, ['admin', 'accountant', 'warehouse']);
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) {
    throw _apiError('BUSY', 'المخزون قيد التحديث، حاول مجددًا', true);
  }
  try {
    const code = body.code;
    const qty = Number(body.quantity || 0);
    if (!code || qty <= 0) throw new Error('بيانات استلام المواد غير صالحة');

    if (_updateProductQuantity(code, qty)) {
      const product = _all('Products').find(p => String(p.code) === String(code));
      const productName = product ? product.name : code;
      _add('Inventory_Movements', {
        movement_id: Utilities.getUuid(),
        code: code,
        type: 'receipt',
        quantity: qty,
        note: body.note || '',
        created_by: user.user_id,
        created_at: _now(),
      });
      _sendNotificationToRoles(
        'admin,accountant,warehouse',
        'تم استلام مواد جديدة',
        'تم تسجيل مواد مستلمة للمنتج ' + productName + '.',
        'inventory.received',
        code,
        { product_id: code }
      );
      return { success: true, saved: true };
    }
    throw new Error('المنتج غير موجود');
  } finally {
    lock.releaseLock();
  }
}

function _handleCreateProduct(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const code = String(body.code || '').trim();
  const name = String(body.name || '').trim();
  const price = Number(body.display_price ?? body.price ?? 0);
  const quantity = Number(body.quantity || 0);
  if (!code || !name || !Number.isFinite(price) || price < 0 ||
      !Number.isFinite(quantity) || quantity < 0) {
    throw _apiError('INVALID_PRODUCT', 'بيانات المنتج غير صالحة', false);
  }
  if (_all('Products').some(product => String(product.code) === code)) {
    throw _apiError('PRODUCT_EXISTS', 'رمز المنتج مستخدم مسبقاً', false);
  }
  _add('Products', {
    code: code,
    name: name,
    image_name: body.image_name || '',
    group: body.group || body.category || '',
    origin: body.origin || '',
    unit_1: body.unit || body.unit_1 || '',
    quantity: quantity,
    minimum_stock: Number(body.minimum_stock || 0),
    display_price: price,
    currency: body.currency || 'USD',
    notes: body.notes || '',
    updated_at: _now(),
    updated_by: user.user_id,
    sub_group: body.sub_group || '',
    oem: body.oem || ''
  });
  _sendNotificationToRoles(
    'admin,accountant',
    'تمت إضافة منتج جديد',
    'تمت إضافة المنتج ' + name + ' إلى الكتالوج.',
    'inventory.product_created',
    code,
    { product_id: code, created_by: user.user_id }
  );
  if (quantity > 0) {
    _sendNotificationToRoles(
      'admin,accountant,warehouse',
      'تم تحديث المخزون',
      'تم تسجيل كمية ابتدائية للمنتج ' + name + '.',
      'inventory.quantity_updated',
      code,
      { product_id: code, created_by: user.user_id }
    );
  }
  return { success: true, code: code };
}

function _handleUpdateProductPrice(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const code = String(body.code || '').trim();
  const price = Number(body.display_price ?? body.price);
  if (!code || !Number.isFinite(price) || price < 0) {
    throw _apiError('INVALID_PRODUCT_PRICE', 'رمز المنتج والسعر الجديد مطلوبان', false);
  }
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) throw _apiError('BUSY', 'الأسعار قيد التحديث، حاول مجدداً', true);
  let product;
  try {
    product = _all('Products').find(item => String(item.code) === code);
    if (!product) throw _apiError('PRODUCT_NOT_FOUND', 'المنتج غير موجود', false);
    _updateByField('Products', 'code', code, {
      display_price: price,
      currency: body.currency || product.currency || 'USD',
      updated_at: _now(),
      updated_by: user.user_id
    });
    SpreadsheetApp.flush();
  } finally {
    lock.releaseLock();
  }
  _sendNotificationToRoles(
    'admin,accountant',
    'تم تحديث سعر منتج',
    'تم تحديث بيانات السعر للمنتج ' + product.name + '.',
    'inventory.price_updated',
    code,
    { product_id: code, created_by: user.user_id }
  );
  return { success: true, code: code };
}

function _updateProductQuantity(code, delta) {
  const ss = _ss();
  const sheet = ss.getSheetByName('Products');
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const codeIdx = headers.indexOf('code');
  const qtyIdx = headers.indexOf('quantity');

  for (let i = 1; i < data.length; i++) {
    if (String(data[i][codeIdx]) === String(code)) {
      const currentQty = Number(data[i][qtyIdx] || 0);
      sheet.getRange(i + 1, qtyIdx + 1).setValue(currentQty + delta);
      return true;
    }
  }
  return false;
}

function _setProductStockQuantity_(code, quantity) {
  const sheet = _ss().getSheetByName('Products');
  if (!sheet) throw new Error('ورقة المنتجات غير موجودة');
  const values = sheet.getDataRange().getValues();
  if (!values.length) throw new Error('ورقة المنتجات لا تحتوي على عناوين');
  const headers = values[0].map(header => String(header).trim());
  const codeIndex = headers.indexOf('code');
  const quantityIndex = headers.indexOf('quantity');
  if (codeIndex < 0 || quantityIndex < 0) {
    throw new Error('مخطط ورقة المنتجات لا يحتوي حقول الرمز والكمية');
  }
  const matchingRows = values
    .map((row, index) => ({ row: row, index: index }))
    .filter(entry =>
      entry.index > 0 && String(entry.row[codeIndex]) === String(code)
    );
  if (matchingRows.length !== 1) {
    throw _apiError(
      'PRODUCT_STOCK_ROW_INVALID',
      'يجب وجود سجل مخزون واحد فقط للمادة ' + code,
      false
    );
  }
  const rowIndex = matchingRows[0].index;
  sheet.getRange(rowIndex + 1, quantityIndex + 1).setValue(quantity);
}

// ============================================================
// 7. صور المنتجات (Product Images - Indexing)
// ============================================================
function normalizeImageName_(value) {
  if (!value) return '';
  // توحيد اسم الصورة: إزالة الامتداد، تحويل للأحرف الصغيرة، إزالة المسافات الزائدة
  return String(value).trim().toLowerCase().replace(/\.[^/.]+$/, "");
}

function _buildImageIndexMaps_(imageIndex) {
  const byId = Object.create(null);
  const byName = Object.create(null);
  const conflicts = Object.create(null);
  imageIndex.forEach(image => {
    if (image.status !== 'active') return;
    const fileId = String(image.file_id || '').trim();
    const normalizedName = String(image.normalized_name || '').trim();
    if (fileId) byId[fileId] = image;
    if (normalizedName) {
      if (conflicts[normalizedName]) return;
      const current = byName[normalizedName];
      if (current && String(current.file_id || '') !== fileId) {
        delete byName[normalizedName];
        conflicts[normalizedName] = true;
        Logger.log('Image index name conflict: ' + normalizedName);
      } else {
        byName[normalizedName] = image;
      }
    }
  });
  return { byId: byId, byName: byName };
}

function _findIndexedProductImage_(product, imageMaps) {
  const fileId = String(product.image_file_id || '').trim();
  if (fileId && imageMaps.byId[fileId]) return imageMaps.byId[fileId];
  return imageMaps.byName[normalizeImageName_(product.image_name || product.code)] || null;
}

/**
 * The index is stored in one canonical table and keyed by stable Drive file id.
 */
const IMAGE_INDEX_JOB_PROPERTY_ = 'PRODUCT_IMAGES_INDEX_JOB_V3';
const IMAGE_INDEX_CHANGES_TOKEN_PROPERTY_ = 'PRODUCT_IMAGES_CHANGES_TOKEN';
const IMAGE_INDEX_FOLDER_PROPERTY_ = 'PRODUCT_IMAGES_INDEXED_FOLDER_ID';
const IMAGE_INDEX_SCHEDULED_PROPERTY_ = 'PRODUCT_IMAGES_SCHEDULED';
const IMAGE_INDEX_TRIGGER_FUNCTION_ = 'continueImageIndexJob';
const IMAGE_INDEX_SCHEDULE_TRIGGER_FUNCTION_ = 'scheduledImageIndexUpdate';
const IMAGE_INDEX_BATCH_SIZE_ = 200;
const IMAGE_INDEX_MAX_BATCH_SIZE_ = 500;
const IMAGE_INDEX_MAX_ERRORS_ = 20;

function rebuildImageIndex(options) {
  const opts = options || {};
  const operation = String(opts.operation || 'update').trim().toLowerCase();
  if (operation === 'status') return _imageIndexJobStatus_();
  if (operation === 'resume') return resumeImageIndexJob();
  if (operation === 'cancel') return cancelImageIndexJob();
  const full = operation === 'full' || operation === 'restart';
  if (full && opts.confirmed !== true && String(opts.confirmed) !== 'true') {
    throw _apiError('CONFIRMATION_REQUIRED', 'إعادة بناء الفهرس الكامل تتطلب confirmed=true', false);
  }
  return _startImageIndexJob_(full);
}

function _imageIndexReadJob_() {
  const raw = PropertiesService.getScriptProperties().getProperty(IMAGE_INDEX_JOB_PROPERTY_);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch (error) {
    Logger.log('Image index state is invalid: ' + _imageIndexSafeError_(error));
    throw _apiError('IMAGE_INDEX_STATE_INVALID', 'تعذر قراءة حالة فهرسة الصور', false);
  }
}

function _imageIndexSaveJob_(job) {
  job.last_progress_at = _now();
  PropertiesService.getScriptProperties().setProperty(IMAGE_INDEX_JOB_PROPERTY_, JSON.stringify(job));
}

function _imageIndexConfig_() {
  const raw = PropertiesService.getScriptProperties().getProperty('IMAGE_INDEX_BATCH_SIZE');
  const configured = raw == null || String(raw).trim() === '' ? NaN : Number(raw);
  return { batchSize: Number.isInteger(configured) ? Math.max(10, Math.min(IMAGE_INDEX_MAX_BATCH_SIZE_, configured)) : IMAGE_INDEX_BATCH_SIZE_ };
}

function _imageIndexPublicStatus_(job) {
  if (!job) return {
    success: true, status: 'idle', scheduled_update: _imageIndexScheduleStatus_(),
    message: 'لا توجد مهمة فهرسة صور حالية',
  };
  return {
    success: true,
    jobId: job.job_id,
    status: job.status,
    mode: job.mode,
    phase: job.phase || '',
    files_scanned: job.files_scanned || 0,
    files_indexed: job.files_indexed || 0,
    files_added: job.files_added || 0,
    files_updated: job.files_updated || 0,
    files_unavailable: job.files_unavailable || 0,
    files_skipped: job.files_skipped || 0,
    error_count: job.error_count || 0,
    errors: job.errors || [],
    token_restarts: job.token_restarts || 0,
    started_at: job.started_at,
    completed_at: job.completed_at || null,
    last_progress_at: job.last_progress_at,
    last_error: job.last_error || null,
    duration_ms: Math.max(0, (job.completed_at ? Date.parse(job.completed_at) : Date.now()) - Date.parse(job.started_at)),
    scheduled_update: _imageIndexScheduleStatus_(),
    message: _imageIndexStatusMessage_(job),
  };
}

function _imageIndexStatusMessage_(job) {
  const labels = {
    pending: 'بانتظار البدء', running: 'قيد الفهرسة', continuing: 'قيد الاستكمال',
    completed: 'اكتملت الفهرسة', completed_with_errors: 'اكتملت الفهرسة مع أخطاء',
    failed: 'فشلت المهمة؛ أعد المحاولة أو استأنفها', cancelled: 'أُلغيت المهمة',
  };
  return (labels[job.status] || job.status) +
    ' — فُحص ' + (job.files_scanned || 0) +
    '، أُضيف ' + (job.files_added || 0) +
    '، عُدّل ' + (job.files_updated || 0) +
    '، غير متاح ' + (job.files_unavailable || 0) +
    '، أخطاء ' + (job.error_count || 0);
}

function _imageIndexSafeError_(error) {
  return String(error && error.message ? error.message : error || 'Unknown error')
    .replace(/https?:\/\/\S+/gi, '[URL removed]')
    .replace(/(?:ya29\.[\w.-]+|AIza[\w-]{20,})/g, '[credential removed]')
    .replace(/[\r\n\t]+/g, ' ')
    .slice(0, 240);
}

function _imageIndexSheet_() {
  const sheet = _ss().getSheetByName('Product_Images');
  if (!sheet) throw _apiError('IMAGE_INDEX_SHEET_MISSING', 'ورقة Product_Images غير موجودة؛ شغّل setupSystem أولاً', false);
  return sheet;
}

function _imageIndexEnsureSchema_(sheet) {
  const headers = H.Product_Images;
  const lastColumn = Math.max(sheet.getLastColumn(), headers.length);
  const allHeaders = sheet.getRange(1, 1, 1, lastColumn).getValues()[0].map(value => String(value || '').trim());
  const properties = PropertiesService.getScriptProperties();
  const activeColumn = Number(properties.getProperty('PRODUCT_IMAGES_ACTIVE_COLUMN') || 1);
  let sourceColumn = 1;
  let sourceHeaders = allHeaders.slice(0, headers.length);
  if (Number.isInteger(activeColumn) && activeColumn > 1 && activeColumn + headers.length - 1 <= lastColumn) {
    const activeHeaders = sheet.getRange(1, activeColumn, 1, headers.length).getValues()[0].map(value => String(value || '').trim());
    if (headers.every(header => activeHeaders.indexOf(header) >= 0)) {
      sourceColumn = activeColumn;
      sourceHeaders = activeHeaders;
    }
  }
  const positions = Object.create(null);
  sourceHeaders.forEach((header, index) => {
    if (header && positions[header] === undefined) positions[header] = index;
  });
  if (!headers.some(header => positions[header] !== undefined)) {
    throw _apiError('IMAGE_INDEX_SCHEMA', 'تعذر تحديد أعمدة بيانات Product_Images', false);
  }
  const lastRow = sheet.getLastRow();
  const sourceRows = lastRow > 1 ? sheet.getRange(2, sourceColumn, lastRow - 1, headers.length).getValues() : [];
  const rows = sourceRows.filter(row => row.some(value => value !== '' && value != null))
    .map(row => headers.map(header => positions[header] === undefined ? '' : row[positions[header]]));
  const currentHeaders = sheet.getRange(1, 1, 1, headers.length).getValues()[0].map(value => String(value || '').trim());
  if (sourceColumn !== 1 || currentHeaders.join('\u001f') !== headers.join('\u001f')) {
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    if (lastRow > 1) sheet.getRange(2, 1, lastRow - 1, headers.length).clearContent();
    _imageIndexEnsureRows_(sheet, rows.length + 1);
    if (rows.length) sheet.getRange(2, 1, rows.length, headers.length).setValues(rows);
  }
  const extraColumns = sheet.getMaxColumns() - headers.length;
  if (extraColumns > 0) sheet.deleteColumns(headers.length + 1, extraColumns);
  properties.deleteProperty('PRODUCT_IMAGES_ACTIVE_COLUMN');
  properties.deleteProperty('PRODUCT_IMAGES_ACTIVE_SHEET');
}

function _imageIndexEnsureRows_(sheet, requiredLastRow) {
  const current = sheet.getMaxRows();
  if (requiredLastRow > current) sheet.insertRowsAfter(current, requiredLastRow - current);
}

function _imageIndexDriveApi_(resource, params) {
  const query = Object.keys(params || {}).map(key => encodeURIComponent(key) + '=' + encodeURIComponent(params[key])).join('&');
  const response = UrlFetchApp.fetch('https://www.googleapis.com/drive/v3/' + resource + (query ? '?' + query : ''), {
    method: 'get',
    headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() },
    muteHttpExceptions: true,
  });
  const code = response.getResponseCode();
  const body = response.getContentText();
  if (code < 200 || code >= 300) throw new Error('Drive API ' + code + ': ' + body.slice(0, 300));
  return JSON.parse(body);
}

function _imageIndexStartToken_() {
  const response = _imageIndexDriveApi_('changes/startPageToken', { supportsAllDrives: true });
  const token = String(response.startPageToken || '');
  if (!token) throw new Error('Drive API did not return a changes token');
  return token;
}

function _imageIndexMetadataRow_(file, folderId) {
  if (!file || !file.id || !file.name || !file.mimeType || !Array.isArray(file.parents)) {
    throw new Error('بيانات ملف Drive غير مكتملة');
  }
  if (file.trashed || file.parents.indexOf(folderId) < 0 || String(file.mimeType).indexOf('image/') !== 0) return null;
  const fileId = String(file.id).trim();
  const fileName = String(file.name).trim();
  if (!fileId || !fileName) throw new Error('معرف أو اسم ملف Drive فارغ');
  const modifiedTime = String(file.modifiedTime || '');
  return [
    fileName, normalizeImageName_(fileName), fileId,
    'https://drive.google.com/thumbnail?id=' + fileId + '&sz=w600&v=' + encodeURIComponent(modifiedTime),
    String(file.mimeType), _now(), 'active', modifiedTime,
  ];
}

function _imageIndexNewJob_(mode, folderId, startToken) {
  return {
    job_id: Utilities.getUuid(),
    mode: mode,
    phase: mode === 'update' ? 'changes' : 'files',
    status: 'pending',
    folder_id: folderId,
    start_token: startToken || '',
    page_token: mode === 'update' ? startToken : '',
    files_scanned: 0, files_indexed: 0, files_added: 0, files_updated: 0,
    files_unavailable: 0, files_skipped: 0, error_count: 0, errors: [],
    token_restarts: 0, batch_failures: 0, started_at: _now(),
    last_progress_at: _now(), completed_at: null, last_error: null,
  };
}

function _imageIndexClearRows_(sheet) {
  const lastRow = sheet.getLastRow();
  if (lastRow > 1) sheet.getRange(2, 1, lastRow - 1, H.Product_Images.length).clearContent();
}

function _startImageIndexJob_(full) {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) throw _apiError('IMAGE_INDEX_BUSY', 'يتم تحديث فهرس الصور؛ حاول مجدداً', true);
  try {
    const current = _imageIndexReadJob_();
    if (current && ['pending', 'running', 'continuing'].indexOf(current.status) >= 0) {
      if (!full) return _imageIndexPublicStatus_(current);
      current.status = 'cancelled';
      current.completed_at = _now();
      _imageIndexSaveJob_(current);
    }
    if (!full && current && current.status === 'failed' &&
        ['full', 'bootstrap'].indexOf(current.mode) >= 0) {
      return _imageIndexPublicStatus_(current);
    }
    const properties = PropertiesService.getScriptProperties();
    const folderId = String(properties.getProperty('PRODUCT_IMAGES_FOLDER_ID') || '1H9KGBPTnZYE8bQHOWUih39zUwB0Hk9ds').trim();
    const indexedFolder = properties.getProperty(IMAGE_INDEX_FOLDER_PROPERTY_);
    const storedToken = properties.getProperty(IMAGE_INDEX_CHANGES_TOKEN_PROPERTY_) || '';
    const bootstrap = full || !storedToken || indexedFolder !== folderId;
    const mode = full ? 'full' : (bootstrap ? 'bootstrap' : 'update');
    const startToken = bootstrap ? _imageIndexStartToken_() : storedToken;
    const sheet = _imageIndexSheet_();
    _imageIndexEnsureSchema_(sheet);
    if (bootstrap) _imageIndexClearRows_(sheet);
    _imageIndexSaveJob_(_imageIndexNewJob_(mode, folderId, startToken));
  } finally {
    lock.releaseLock();
  }
  continueImageIndexJob();
  let status = _imageIndexJobStatus_();
  if (['pending', 'running', 'continuing'].indexOf(status.status) >= 0) {
    try {
      _imageIndexEnsureTrigger_();
    } catch (error) {
      const job = _imageIndexReadJob_();
      if (job) {
        job.status = 'failed';
        job.last_error = 'تعذر إنشاء مشغّل الاستكمال؛ تحقق من أذونات Apps Script';
        _imageIndexSaveJob_(job);
      }
      throw _apiError('IMAGE_INDEX_TRIGGER_FAILED', 'تعذر إنشاء مشغّل استكمال فهرسة الصور', false);
    }
    status = _imageIndexJobStatus_();
  }
  return status;
}

function _imageIndexAppendError_(job, error) {
  const message = _imageIndexSafeError_(error);
  job.error_count++;
  job.last_error = message;
  if (job.errors.length < IMAGE_INDEX_MAX_ERRORS_) job.errors.push({ message: message, at: _now() });
  Logger.log('Image index error: ' + message);
}

function _imageIndexApplyChanges_(job, changes) {
  const sheet = _imageIndexSheet_();
  const lastRow = sheet.getLastRow();
  const existingRows = lastRow > 1 ? sheet.getRange(2, 1, lastRow - 1, H.Product_Images.length).getValues() : [];
  const byId = Object.create(null);
  existingRows.forEach((row, index) => {
    const id = String(row[2] || '').trim();
    if (id) byId[id] = { row: index + 2, values: row };
  });
  const latest = Object.create(null);
  changes.forEach(change => {
    const id = String(change.fileId || change.file && change.file.id || '').trim();
    if (id) latest[id] = change;
  });
  const updates = [];
  const additions = [];
  Object.keys(latest).forEach(id => {
    const change = latest[id];
    const old = byId[id];
    let row = null;
    if (!change.removed && !change.file) {
      _imageIndexAppendError_(job, new Error('Drive لم يُرجع بيانات الملف المتغير؛ بقيت حالته كما هي'));
      return;
    }
    if (!change.removed) {
      try {
        row = _imageIndexMetadataRow_(change.file, job.folder_id);
      } catch (error) {
        _imageIndexAppendError_(job, error);
        return;
      }
    }
    job.files_scanned++;
    if (!row) {
      if (old && String(old.values[6]).toLowerCase() === 'active') {
        const inactive = old.values.slice();
        inactive[5] = _now();
        inactive[6] = 'inactive';
        updates.push({ row: old.row, values: inactive });
        job.files_unavailable++;
      } else {
        job.files_skipped++;
      }
    } else if (!old) {
      additions.push(row);
      job.files_added++;
    } else if (String(old.values[0]) !== row[0] || String(old.values[4]) !== row[4] ||
        String(old.values[6]) !== 'active' || String(old.values[7] || '') !== row[7]) {
      updates.push({ row: old.row, values: row });
      job.files_updated++;
    } else {
      job.files_skipped++;
    }
  });
  updates.sort((a, b) => a.row - b.row);
  let group = [];
  const flush = () => {
    if (!group.length) return;
    sheet.getRange(group[0].row, 1, group.length, H.Product_Images.length).setValues(group.map(item => item.values));
    group = [];
  };
  updates.forEach(item => {
    if (group.length && item.row !== group[group.length - 1].row + 1) flush();
    group.push(item);
  });
  flush();
  if (additions.length) {
    const startRow = Math.max(2, lastRow + 1);
    _imageIndexEnsureRows_(sheet, startRow + additions.length - 1);
    sheet.getRange(startRow, 1, additions.length, H.Product_Images.length).setValues(additions);
  }
  job.files_indexed += additions.length + updates.length;
}

function _imageIndexRunFilesBatch_(job) {
  const params = {
    q: "'" + job.folder_id.replace(/'/g, "\\'") + "' in parents and trashed = false",
    pageSize: _imageIndexConfig_().batchSize,
    fields: 'nextPageToken,files(id,name,mimeType,modifiedTime,parents,trashed)',
    supportsAllDrives: true,
    includeItemsFromAllDrives: true,
  };
  if (job.page_token) params.pageToken = job.page_token;
  const response = _imageIndexDriveApi_('files', params);
  const rows = [];
  (response.files || []).forEach(file => {
    job.files_scanned++;
    try {
      const row = _imageIndexMetadataRow_(file, job.folder_id);
      if (row) rows.push(row);
      else job.files_skipped++;
    } catch (error) {
      _imageIndexAppendError_(job, error);
    }
  });
  if (rows.length) {
    const sheet = _imageIndexSheet_();
    const lastRow = sheet.getLastRow();
    const existingRows = lastRow > 1
      ? sheet.getRange(2, 1, lastRow - 1, H.Product_Images.length).getValues()
      : [];
    const rowById = Object.create(null);
    existingRows.forEach((old, index) => {
      const id = String(old[2] || '').trim();
      if (id) rowById[id] = { row: index + 2, values: old };
    });
    const updates = [];
    const additions = [];
    rows.forEach(row => {
      const existing = rowById[String(row[2])];
      if (!existing) {
        additions.push(row);
        job.files_added++;
      } else {
        if (existing.values.some((value, index) => String(value || '') !== String(row[index] || ''))) {
          updates.push({ row: existing.row, values: row });
          job.files_updated++;
        } else {
          job.files_skipped++;
        }
      }
    });
    updates.forEach(update => {
      sheet.getRange(update.row, 1, 1, H.Product_Images.length).setValues([update.values]);
    });
    if (additions.length) {
      const firstRow = Math.max(2, lastRow + 1);
      _imageIndexEnsureRows_(sheet, firstRow + additions.length - 1);
      sheet.getRange(firstRow, 1, additions.length, H.Product_Images.length).setValues(additions);
    }
    job.files_indexed += additions.length + updates.length;
  }
  if (response.nextPageToken) {
    job.page_token = response.nextPageToken;
  } else {
    job.phase = 'changes';
    job.page_token = job.start_token;
  }
  job.status = 'continuing';
}

function _imageIndexRunChangesBatch_(job) {
  const response = _imageIndexDriveApi_('changes', {
    pageToken: job.page_token,
    pageSize: _imageIndexConfig_().batchSize,
    includeRemoved: true,
    supportsAllDrives: true,
    includeItemsFromAllDrives: true,
    fields: 'nextPageToken,newStartPageToken,changes(fileId,removed,file(id,name,mimeType,modifiedTime,parents,trashed))',
  });
  const changes = response.changes || [];
  if (changes.length) _imageIndexApplyChanges_(job, changes);
  if (response.nextPageToken) {
    job.page_token = response.nextPageToken;
    job.status = 'continuing';
    return;
  }
  if (!response.newStartPageToken) throw new Error('Drive API did not return the next changes token');
  const properties = PropertiesService.getScriptProperties();
  properties.setProperty(IMAGE_INDEX_CHANGES_TOKEN_PROPERTY_, response.newStartPageToken);
  properties.setProperty(IMAGE_INDEX_FOLDER_PROPERTY_, job.folder_id);
  job.page_token = '';
  job.status = job.error_count ? 'completed_with_errors' : 'completed';
  job.completed_at = _now();
}

function _imageIndexRestartAsFull_(job) {
  const token = _imageIndexStartToken_();
  const sheet = _imageIndexSheet_();
  _imageIndexEnsureSchema_(sheet);
  _imageIndexClearRows_(sheet);
  job.mode = 'bootstrap';
  job.phase = 'files';
  job.start_token = token;
  job.page_token = '';
  job.files_scanned = 0;
  job.files_indexed = 0;
  job.files_added = 0;
  job.files_updated = 0;
  job.files_unavailable = 0;
  job.files_skipped = 0;
  job.error_count = 0;
  job.errors = [];
  job.batch_failures = 0;
  job.token_restarts = Number(job.token_restarts || 0) + 1;
  job.last_error = 'انتهت صلاحية رمز Drive؛ بدأ فحص كامل جديد';
  job.status = 'continuing';
}

function _imageIndexEnsureTrigger_() {
  const exists = ScriptApp.getProjectTriggers().some(trigger =>
    trigger.getHandlerFunction() === IMAGE_INDEX_TRIGGER_FUNCTION_);
  if (!exists) ScriptApp.newTrigger(IMAGE_INDEX_TRIGGER_FUNCTION_).timeBased().everyMinutes(1).create();
}

function _imageIndexDeleteTriggers_() {
  ScriptApp.getProjectTriggers().forEach(trigger => {
    if (trigger.getHandlerFunction() === IMAGE_INDEX_TRIGGER_FUNCTION_) ScriptApp.deleteTrigger(trigger);
  });
}

function continueImageIndexJob() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(1000)) return;
  try {
    const job = _imageIndexReadJob_();
    if (!job || !['pending', 'running', 'continuing'].includes(job.status)) {
      _imageIndexDeleteTriggers_();
      return;
    }
    job.status = 'running';
    job.last_error = null;
    try {
      if (job.phase === 'files') _imageIndexRunFilesBatch_(job);
      else _imageIndexRunChangesBatch_(job);
      job.batch_failures = 0;
    } catch (error) {
      const message = _imageIndexSafeError_(error);
      if (/Drive API 410|page.?token|start.?page.?token/i.test(message) &&
          Number(job.token_restarts || 0) < 2) {
        _imageIndexRestartAsFull_(job);
      } else {
        job.batch_failures = Number(job.batch_failures || 0) + 1;
        job.last_error = message;
        if (job.batch_failures >= 3) {
          job.status = 'failed';
          job.completed_at = _now();
        } else {
          job.status = 'continuing';
        }
        _imageIndexAppendError_(job, error);
      }
    }
    _imageIndexSaveJob_(job);
    if (['completed', 'completed_with_errors', 'failed', 'cancelled'].includes(job.status)) {
      _imageIndexDeleteTriggers_();
    }
  } finally {
    lock.releaseLock();
  }
}

function _imageIndexJobStatus_() {
  return _imageIndexPublicStatus_(_imageIndexReadJob_());
}

function resumeImageIndexJob() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) throw _apiError('IMAGE_INDEX_BUSY', 'يتم تحديث حالة فهرس الصور؛ حاول مجدداً', true);
  try {
    const job = _imageIndexReadJob_();
    if (!job || !['failed', 'pending', 'running', 'continuing'].includes(job.status)) {
      throw _apiError('IMAGE_INDEX_NOT_RESUMABLE', 'لا توجد مهمة قابلة للاستكمال', false);
    }
    job.status = 'continuing';
    job.batch_failures = 0;
    job.last_error = null;
    _imageIndexSaveJob_(job);
    _imageIndexEnsureTrigger_();
    return _imageIndexPublicStatus_(job);
  } finally {
    lock.releaseLock();
  }
}

function cancelImageIndexJob() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) throw _apiError('IMAGE_INDEX_BUSY', 'يتم تحديث حالة فهرس الصور؛ حاول مجدداً', true);
  try {
    const job = _imageIndexReadJob_();
    if (!job || !['pending', 'running', 'continuing'].includes(job.status)) return _imageIndexPublicStatus_(job);
    job.status = 'cancelled';
    job.completed_at = _now();
    _imageIndexSaveJob_(job);
    _imageIndexDeleteTriggers_();
    return _imageIndexPublicStatus_(job);
  } finally {
    lock.releaseLock();
  }
}

function _imageIndexScheduleStatus_() {
  return PropertiesService.getScriptProperties().getProperty(IMAGE_INDEX_SCHEDULED_PROPERTY_) === 'true';
}

function _imageIndexSetSchedule_(enabled) {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) throw _apiError('IMAGE_INDEX_BUSY', 'يتم تحديث حالة فهرس الصور؛ حاول مجدداً', true);
  try {
    const matching = ScriptApp.getProjectTriggers().filter(trigger =>
      trigger.getHandlerFunction() === IMAGE_INDEX_SCHEDULE_TRIGGER_FUNCTION_);
    if (enabled && !matching.length) {
      ScriptApp.newTrigger(IMAGE_INDEX_SCHEDULE_TRIGGER_FUNCTION_).timeBased().everyHours(6).create();
    } else if (!enabled) {
      matching.forEach(trigger => ScriptApp.deleteTrigger(trigger));
    }
    PropertiesService.getScriptProperties().setProperty(IMAGE_INDEX_SCHEDULED_PROPERTY_, enabled ? 'true' : 'false');
    return { success: true, scheduled_update: enabled };
  } finally {
    lock.releaseLock();
  }
}

function scheduledImageIndexUpdate() {
  return rebuildImageIndex({ operation: 'update' });
}

// ============================================================
// 8. الطلبات (Orders)
// ============================================================
function _handleGetOrders(body, user) {
  const startedAt = Date.now();
  const userRole = _normalizeRole(user.role);
  let orders = _all('Orders');

  if (userRole === 'customer') {
    const customerId = user.customer_id;
    if (!customerId) {
      throw _apiError('ACCOUNT_NOT_LINKED', 'حساب العميل غير مرتبط بملف عميل', false);
    }
    orders = orders.filter(o => String(o.customer_id) === String(customerId));
  } else if (['admin', 'manager', 'accountant', 'warehouse'].includes(userRole)) {
    // الإدارة ترى الكل أو حسب الفلتر
    if (body.customer_id) {
      orders = orders.filter(o => String(o.customer_id) === String(body.customer_id));
    }
  } else {
    throw new Error('غير مصرح لك بعرض الطلبات');
  }

  orders = orders.filter(o => o.status !== 'deleted');
  if (body.status) {
    orders = orders.filter(o => String(o.status) === String(body.status));
  }
  const customersById = {};
  _all('Customers').forEach(customer => {
    customersById[String(customer.customer_id)] = customer;
  });
  orders = orders.map(o => {
    const customer = customersById[String(o.customer_id)];
    return {
      ...(userRole === 'admin' || userRole === 'manager' || userRole === 'accountant'
          ? o
          : _withoutInternalOrderFields(_withoutFinancialFields(o, userRole))),
      // إضافة id كمرادف لـ order_id للتوافق مع Flutter
      id: o.order_id || '',
      order_number: o.order_number || o.order_id || '',
      customer_name: o.customer_name || (customer ? customer.full_name : 'غير معروف'),
      status_text: _getStatusTextAr(o.status),
      is_new: o.is_new === 'true' || o.is_new === true || o.is_read === 'false' || o.is_read === false || o.is_read === '0',
    };
  });

  orders.sort((a, b) => {
    const dateA = new Date(a.created_at || 0);
    const dateB = new Date(b.created_at || 0);
    return dateB - dateA;
  });

  Logger.log(
    'orders_list_ms=' + (Date.now() - startedAt) +
    ' order_count=' + orders.length +
    ' role=' + userRole
  );
  return { orders: orders };
}

/**
 * معالجة جلب تفاصيل الطلب
 * تدعم البحث بـ order_id أو order_number
 */
function _handleOrderDetails(body, user) {
  const identifier = resolveOrderIdentifier_(body);
  
  if (!identifier) {
    throw _apiError('ORDER_IDENTIFIER_REQUIRED', 'رقم أو معرف الطلب مطلوب.', false);
  }

  // 1. البحث عن المعرف المرجعي الحقيقي (order_id)
  const orders = _all('Orders');
  const order = orders.find(o =>
    String(o.order_id) === String(identifier) ||
    String(o.order_number || o.order_no) === String(identifier)
  );
  
  if (!order) {
    throw _apiError('ORDER_NOT_FOUND', 'الطلب غير موجود.', false);
  }

  const realOrderId = String(order.order_id);
  _requireOrderOwnership(user, order);

  // 2. استخدام المعرف المرجعي الحقيقي لجلب جميع البيانات المرتبطة
  return _handleOrderDetailsWithRealId(order, realOrderId, user);
}

function _handleOrderDetailsWithRealId(order, orderId, user) {
  const startedAt = Date.now();
  const userRole = _normalizeRole(user.role);
  const allOrderItems = _all('Order_Items');
  const items = allOrderItems.filter(i => String(i.order_id) === orderId);
  const products = _all('Products');
  const productsByCode = {};
  products.forEach(product => {
    productsByCode[String(product.code)] = product;
  });
  const imageIndex = _all('Product_Images');
  const allOrderShipments = _all('Shipments')
    .filter(s => String(s.order_id) === orderId);
  const shipment = allOrderShipments.length
    ? allOrderShipments[allOrderShipments.length - 1]
    : null;
  const customer = _all('Customers').find(c => c.customer_id === order.customer_id);

  // بناء خريطة للبحث السريع عن الصور O(1)
  const imageMaps = _buildImageIndexMaps_(imageIndex);

  const detailedItems = items.map(i => {
    const p = productsByCode[String(i.code)];
    let imageUrl = '';

    if (p) {
      const imgData = _findIndexedProductImage_(p, imageMaps);

      if (imgData) {
        imageUrl = imgData.image_url;
      } else if (p.image_file_id) {
        imageUrl = 'https://drive.google.com/thumbnail?id=' + p.image_file_id + '&sz=w400';
      }
    }

    const item = {
      item_id: i.item_id || '',
      code: i.code || '',
      name: i.name_snapshot || (p ? p.name : (i.name || 'منتج غير معروف')),
      unit: i.unit || (p ? p.unit : ''),
      unit_factor: i.unit_factor !== undefined && i.unit_factor !== '' ? Number(i.unit_factor) : null,
      base_price_snapshot: i.base_price_snapshot !== undefined && i.base_price_snapshot !== '' ? Number(i.base_price_snapshot) : null,
      unit_price_snapshot: i.unit_price_snapshot !== undefined && i.unit_price_snapshot !== ''
        ? Number(i.unit_price_snapshot)
        : (i.display_price_snapshot !== undefined && i.display_price_snapshot !== ''
            ? Number(i.display_price_snapshot)
            : null),
      unit_1: i.unit_1 || (p ? p.unit_1 || '' : ''),
      unit_2: i.unit_2 || (p ? p.unit_2 || '' : ''),
      factor_2: i.factor_2 !== undefined && i.factor_2 !== '' ? Number(i.factor_2) : (p && p.factor_2 !== '' ? Number(p.factor_2) : null),
      unit_3: i.unit_3 || (p ? p.unit_3 || '' : ''),
      factor_3: i.factor_3 !== undefined && i.factor_3 !== '' ? Number(i.factor_3) : (p && p.factor_3 !== '' ? Number(p.factor_3) : null),
      image_url: imageUrl,

      // الكميات الصريحة
      quantity_requested: i.quantity_requested !== undefined && i.quantity_requested !== '' ? Number(i.quantity_requested) : null,
      quantity_approved: i.quantity_approved !== undefined && i.quantity_approved !== '' ? Number(i.quantity_approved) : null,
      quantity_prepared: i.quantity_prepared !== undefined && i.quantity_prepared !== '' ? Number(i.quantity_prepared) : null,

      // الأسعار (سيتم حذفها للأدوار غير المصرح لها)
      price_offer: i.display_price_snapshot !== undefined && i.display_price_snapshot !== '' ? Number(i.display_price_snapshot) : null,
      final_price: i.final_price !== undefined && i.final_price !== '' ? Number(i.final_price) : null,
      default_price: i.unit_price_snapshot !== undefined && i.unit_price_snapshot !== ''
        ? Number(i.unit_price_snapshot)
        : (i.display_price_snapshot !== undefined && i.display_price_snapshot !== ''
            ? Number(i.display_price_snapshot)
            : null),
      total_price: i.total_price !== undefined && i.total_price !== '' ? Number(i.total_price) : null,

      status: i.status || 'pending',
      stock_available: p ? Number(p.quantity || 0) : 0,
      accountant_note: i.accountant_note || '',
      warehouse_note: i.warehouse_note || '',
      warehouse_package_numbers: i.warehouse_package_numbers || '',
      warehouse_package_type: i.warehouse_package_type || '',
      warehouse_custom_package_type: i.warehouse_custom_package_type || '',
      note: i.customer_note || i.note || ''
    };

    if (i.offer_id) {
      item.offer_id = i.offer_id;
      item.offer_revision = Number(i.offer_revision);
      item.offer_old_price = Number(i.offer_old_price);
      item.offer_min_quantity = Number(i.offer_min_quantity);
      item.offer_starts_at = _offerTime_(i.offer_starts_at);
      item.offer_ends_at = _offerTime_(i.offer_ends_at);
    }

    // تطبيق أمان الحقول على مستوى العناصر
    if (userRole === 'warehouse') {
      delete item.base_price_snapshot;
      delete item.unit_price_snapshot;
      delete item.offer_old_price;
      delete item.price_offer;
      delete item.final_price;
      delete item.default_price;
      delete item.total_price;
      delete item.accountant_note;
    } else if (userRole === 'customer') {
      delete item.stock_available;
      delete item.accountant_note;
      delete item.warehouse_note;
      delete item.warehouse_package_numbers;
      delete item.warehouse_package_type;
      delete item.warehouse_custom_package_type;
    }
    return item;
  });

  // تطبيق أمان الحقول على مستوى الطلب الرئيسي
  let safeOrder = Object.assign({}, order);
  if (userRole === 'warehouse') {
    safeOrder = _withoutFinancialFields(safeOrder, userRole);
    safeOrder = _withoutInternalOrderFields(safeOrder);
  } else if (userRole === 'customer') {
    safeOrder = _withoutInternalOrderFields(safeOrder);
  }

  // حساب معلومات الرصيد بشكل منفصل وصحيح
  let balanceInfo = null;
  let currentOrderTotal = 0;
  if (customer && userRole !== 'warehouse') {
    const allPayments = _all('Payments');
    const allOrders = _all('Orders');
    const itemsByOrderId = {};
    allOrderItems.forEach(item => {
      const itemOrderId = String(item.order_id || '').trim();
      if (!itemsByOrderId[itemOrderId]) itemsByOrderId[itemOrderId] = [];
      itemsByOrderId[itemOrderId].push(item);
    });
    
    // تصفية الدفعات والطلبات للعميل الحالي
    const customerPayments = allPayments.filter(p => p.customer_id === order.customer_id);
    const customerOrders = allOrders.filter(o =>
      o.customer_id === order.customer_id &&
      !['cancelled', 'deleted'].includes(String(o.status || '').toLowerCase())
    );
    
    // حساب إجمالي الدفعات
    const totalPaid = customerPayments.reduce((sum, p) => sum + Number(p.amount || 0), 0);
    
    // حساب الرصيد السابق (الفواتير السابقة فقط، باستثناء الطلب الحالي)
    let previousOrdersTotal = 0;
    const currentOrderId = String(order.order_id || '').trim();
    
    customerOrders.forEach(o => {
      const orderItems = itemsByOrderId[String(o.order_id || '').trim()] || [];
      
      let orderSum = 0;
      orderItems.forEach(item => {
        // حساب فقط البنود المتوفرة والمسعرة
        const isUnavailable = String(item.status || '').toLowerCase() === 'unavailable';
        if (!isUnavailable) {
          const price = Number(item.final_price || item.display_price_snapshot || 0);
          const qty = Number(item.quantity_approved || item.quantity_requested || 0);
          orderSum += price * qty;
        }
      });

      const isFinancialStatus = ['approved', 'prepared', 'shipping', 'delivered'].includes(String(o.status || '').toLowerCase());

      // إذا كان هذا هو الطلب الحالي، لا تدخله في الرصيد السابق
      if (String(o.order_id || '').trim() === currentOrderId) {
        currentOrderTotal = orderSum;
      } else if (isFinancialStatus) {
        // تضاف فقط الطلبات "المرحلة" للرصيد السابق
        const savedTotal = Number(o.total);
        const savedDiscount = Number(o.discount || 0);
        previousOrdersTotal += o.total !== '' && o.total != null && Number.isFinite(savedTotal)
          ? savedTotal
          : _roundOrderAmount_(orderSum - (Number.isFinite(savedDiscount) ? savedDiscount : 0));
      }
    });
    const savedCurrentTotal = Number(order.total);
    if (order.total !== '' && order.total != null && Number.isFinite(savedCurrentTotal)) {
      currentOrderTotal = savedCurrentTotal;
    } else {
      currentOrderTotal = _roundOrderAmount_(currentOrderTotal - Number(order.discount || 0));
    }
    
    // الرصيد السابق = مجموع الفواتير السابقة - مجموع الدفعات السابقة + الرصيد الافتتاحي
    const openingBalance = Number(customer.opening_usd || 0);
    const previousBalance = previousOrdersTotal - totalPaid + openingBalance;
    
    // الرصيد الجديد = الرصيد السابق + صافي الفاتورة الحالية
    const newBalance = previousBalance + currentOrderTotal;
    
    balanceInfo = {
      previous_balance: previousBalance,
      current_invoice_total: currentOrderTotal,
      total_paid: totalPaid,
      opening_balance: openingBalance,
      new_balance: newBalance,
      currency: order.currency || 'USD'
    };
  }

  const orderResponse = {
    order_id: orderId,
    order_number: order.order_number || order.order_no || orderId,
    customer_id: order.customer_id || '',
    customer_name: order.customer_name || (customer ? customer.full_name : '') || 'غير معروف',
    status: order.status || '',
    normalized_status: _getStatusTextAr(order.status),
    currency: order.currency || 'USD',
    note: order.note || '',
    accountant_notes: order.accountant_notes || '',
    accounting_invoice_no: order.accounting_invoice_no || '',
    accounting_invoice_no_updated_by: order.accounting_invoice_no_updated_by || '',
    accounting_invoice_no_updated_at: order.accounting_invoice_no_updated_at || '',
    created_at: order.created_at || '',
    updated_at: order.updated_at || '',
    created_by: order.created_by || '',
    items: detailedItems
  };
  if (userRole !== 'warehouse') {
    orderResponse.total_amount = currentOrderTotal;
    if (['admin', 'manager', 'accountant'].includes(userRole)) {
      orderResponse.subtotal = Number(order.subtotal || 0);
    }
    orderResponse.total_requested = detailedItems.reduce(
      (sum, item) => sum + ((item.price_offer || item.default_price || 0) * (item.quantity_requested || 0)),
      0
    );
    orderResponse.total_final = currentOrderTotal;
    if (['admin', 'manager', 'accountant'].includes(userRole)) {
      orderResponse.discount = Number(order.discount || 0);
      orderResponse.discount_type = order.discount_type || '';
      orderResponse.discount_input = order.discount_input || '';
      orderResponse.discount_reason = order.discount_reason || '';
    }
  } else {
    delete orderResponse.accountant_notes;
    delete orderResponse.accounting_invoice_no;
    delete orderResponse.accounting_invoice_no_updated_by;
    delete orderResponse.accounting_invoice_no_updated_at;
  }
  if (userRole === 'customer') {
    delete orderResponse.accountant_notes;
    delete orderResponse.accounting_invoice_no;
    delete orderResponse.accounting_invoice_no_updated_by;
    delete orderResponse.accounting_invoice_no_updated_at;
    delete orderResponse.discount;
    delete orderResponse.discount_type;
    delete orderResponse.discount_input;
    delete orderResponse.discount_reason;
  }
  if (!['admin', 'manager', 'accountant'].includes(userRole)) {
    delete orderResponse.accounting_invoice_no;
    delete orderResponse.accounting_invoice_no_updated_by;
    delete orderResponse.accounting_invoice_no_updated_at;
    delete orderResponse.discount;
    delete orderResponse.discount_type;
    delete orderResponse.discount_input;
    delete orderResponse.discount_reason;
  }

  const orderMap = {};
  orderMap[orderId] = order;
  const invoiceMap = {};
  const safeShipments = allOrderShipments.map(item => {
    const enriched = _shipmentWithSummary_(item, orderMap, invoiceMap);
    return userRole === 'warehouse'
      ? _withoutFinancialFields(enriched, userRole)
      : enriched;
  });
  const safeShipment = safeShipments.length
    ? Object.assign({}, safeShipments[safeShipments.length - 1], {
        all_shipments: safeShipments
      })
    : null;

  Logger.log(
    'order_details_ms=' + (Date.now() - startedAt) +
    ' item_count=' + detailedItems.length +
    ' role=' + userRole
  );
  return {
    order: orderResponse,
    shipment: safeShipment,
    balanceInfo: userRole === 'warehouse' ? null : balanceInfo
  };
}


/**
 * دالة موحدة لاستخراج معرف الطلب من body
 * تدعم عدة صيغ لاسم الحقل
 */
function resolveOrderIdentifier_(body) {
  if (!body || typeof body !== 'object') return '';
  
  const possibleKeys = [
    'order_id', 'orderId', 'orderid',
    'order_number', 'orderNumber', 'ordernumber',
    'order_no', 'orderNo',
    'id'
  ];
  
  for (const key of possibleKeys) {
    const val = body[key];
    if (val !== undefined && val !== null && String(val).trim() !== '') {
      return String(val).trim();
    }
  }
  
  return '';
}

/**
 * Generates ORD-YYMMDD-NNNNN with an annual sequence while the caller holds ScriptLock.
 */
function _generateOrderNumber(existingOrders, now) {
  const createdAt = now || new Date();
  const timeZone = Session.getScriptTimeZone();
  const datePrefix = Utilities.formatDate(createdAt, timeZone, 'yyMMdd');
  const yearPrefix = 'ORD-' + datePrefix.substring(0, 2);
  const props = PropertiesService.getScriptProperties();
  const propKey = 'SEQ_ORD_' + datePrefix.substring(0, 2);
  const savedSequence = props.getProperty(propKey);
  let current = savedSequence == null ? 0 : Number(savedSequence);
  if (!Number.isSafeInteger(current) || current < 0) {
    throw _apiError('ORDER_SEQUENCE_INVALID', 'عداد أرقام الطلبات غير صالح', false);
  }

  // Recover from a missing/reset annual property. This full scan is one-time per
  // annual sequence; subsequent allocations use the centrally locked property.
  if (savedSequence == null) {
    (existingOrders || []).forEach(order => {
      const number = String(order.order_number || '');
      const match = number.match(/^ORD-(\d{6})-(\d{5})$/);
      if (match && number.startsWith(yearPrefix)) {
        current = Math.max(current, Number(match[2]));
      }
    });
  }
  if (current >= 99999) {
    throw _apiError('ORDER_SEQUENCE_EXHAUSTED', 'اكتمل تسلسل الطلبات لهذه السنة', false);
  }

  const next = current + 1;
  props.setProperty(propKey, String(next));
  return 'ORD-' + datePrefix + '-' + String(next).padStart(5, '0');
}

/**
 * Generates a globally shared SAL number while the caller holds ScriptLock.
 */
function _generateSalesInvoiceNumber_(existingInvoices, createdAt) {
  const date = createdAt || new Date();
  const datePrefix = Utilities.formatDate(
    date,
    Session.getScriptTimeZone(),
    'yyMMdd'
  );
  const year = datePrefix.substring(0, 2);
  const propertyKey = 'SEQ_SAL_' + year;
  const properties = PropertiesService.getScriptProperties();
  const savedValue = properties.getProperty(propertyKey);
  let current = savedValue == null ? 500000 : Number(savedValue);
  if (!Number.isSafeInteger(current) || current < 500000) {
    throw _apiError(
      'SALES_INVOICE_SEQUENCE_INVALID',
      'عداد فواتير المبيعات لهذه السنة غير صالح',
      false
    );
  }

  (existingInvoices || []).forEach(invoice => {
    const match = String(invoice.invoice_number || '')
      .match(/^SAL-(\d{6})-(\d{6})$/);
    if (match && match[1].substring(0, 2) === year) {
      current = Math.max(current, Number(match[2]));
    }
  });
  if (current >= 999999) {
    throw _apiError(
      'SALES_INVOICE_SEQUENCE_EXHAUSTED',
      'اكتمل نطاق أرقام فواتير المبيعات لهذه السنة؛ لم يُعد العداد إلى البداية',
      false
    );
  }

  const next = current + 1;
  properties.setProperty(propertyKey, String(next));
  return 'SAL-' + datePrefix + '-' + String(next).padStart(6, '0');
}

/**
 * معالجة إنشاء طلب جديد
 * ينشئ order_id فريد ويربط البنود به
 */
function _handleCreateOrder(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'customer']);
  // استخدام LockService لمنع التكرار
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) {
    throw _apiError('BUSY', 'جاري معالجة طلب آخر، يرجى الانتظار قليلاً', true);
  }
  
  try {
    // التحقق من هوية العميل
    let customerId = '';
    if (user && user.role === 'customer') {
      customerId = user.customer_id;
    } else {
      customerId = body.customer_id || body.customerId;
    }

    if (!customerId) {
      throw _apiError('CUSTOMER_REQUIRED', 'لم يتم تحديد العميل', false);
    }

    // التحقق من وجود بنود
    const items = body.items || body.orderItems;
    if (!items || !Array.isArray(items) || items.length === 0) {
      throw _apiError('EMPTY_ORDER', 'لا يمكن إرسال طلب فارغ', false);
    }
    
    const clientRequestId = String(
      body.client_request_id || body.request_id || body.requestId || ''
    ).trim();
    if (!clientRequestId) {
      throw _apiError('CLIENT_REQUEST_ID_REQUIRED', 'معرف العملية مطلوب لإرسال الطلب بأمان', false);
    }

    const existingOrders = _all('Orders');
    const existing = existingOrders.find(o =>
      String(o.client_request_id || '').trim() === clientRequestId
    );
    if (existing) {
      _requireOrderOwnership(user, existing);
      if (String(existing.customer_id) !== String(customerId)) {
        throw _apiError('REQUEST_ID_CONFLICT', 'معرف العملية مستخدم لطلب آخر', false);
      }
      const savedItems = _all('Order_Items').filter(
        item => String(item.order_id) === String(existing.order_id)
      );
      if (savedItems.length !== items.length) {
        throw _apiError('ORDER_RETRY_INCOMPLETE', 'تعذر التحقق من اكتمال الطلب السابق؛ يرجى مراجعة الدعم قبل إعادة الإرسال', false);
      }
      return {
        success: true,
        message: 'تم استلام الطلب مسبقاً',
        order_id: existing.order_id,
        order_number: existing.order_number || existing.order_id,
        is_duplicate: true
      };
    }
    
    const customer = _all('Customers').find(c => c.customer_id === customerId);
    if (!customer && user.role === 'customer') {
      throw _apiError('CUSTOMER_NOT_FOUND', 'ملف العميل المرتبط بالحساب غير موجود', false);
    }

    // Validate every line before writing the order header or any item.
    const productsByCode = {};
    _all('Products').forEach(product => {
      productsByCode[String(product.code)] = product;
    });
    const requestedCurrency = String(body.currency || 'USD').trim().toUpperCase();
    const hasOfferClaims = items.some(item => item && typeof item === 'object' &&
      ['offer_id', 'offer_revision', 'offer_price'].some(key => Object.prototype.hasOwnProperty.call(item, key)));
    if (hasOfferClaims) _requireColumns_('Offers', H.Offers);
    const offers = hasOfferClaims ? _all('Offers') : [];
    const offerCheckTime = Date.now();
    const validatedItems = items.map(item => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) {
        throw _apiError('INVALID_ORDER_ITEM', 'بند الطلب غير صالح', false);
      }
      const offer = _orderOfferClaim_(item, offers, requestedCurrency, offerCheckTime);
      const qty = Number(item.quantity ?? item.quantity_requested);
      const code = String(item.code || '').trim();
      if (!code || !Number.isFinite(qty) || qty <= 0) {
        throw _apiError('INVALID_ORDER_ITEM', 'يوجد بند بكمية أو كود غير صالح', false);
      }
      const product = productsByCode[code];
      if (!product) {
        if (offer) _offerError_('OFFER_CHANGED', 'المنتج المرتبط بالعرض غير موجود');
        throw _apiError('PRODUCT_NOT_FOUND', 'المنتج غير موجود: ' + code, false);
      }
      const productCurrency =
        String(product.currency || 'USD').trim().toUpperCase();
      if (productCurrency !== requestedCurrency) {
        if (offer) _offerError_('OFFER_CHANGED', 'عملة المنتج المرتبط بالعرض تغيرت');
        throw _apiError('PRODUCT_CURRENCY_MISMATCH', 'عملة المنتج ' + code + ' لا تطابق عملة الطلب', false);
      }
      if (offer && !_offerMatchesProduct_(offer, product)) {
        _offerError_('OFFER_CHANGED', 'سعر وحدة المنتج المرتبط بالعرض تغير');
      }
      const unit1 = String(product.unit_1 || '').trim();
      const unit2 = String(product.unit_2 || '').trim();
      const unit3 = String(product.unit_3 || '').trim();
      const duplicateUnits = {};
      [
        [unit1, '1', product.display_price],
        [unit2, product.factor_2, product.price_2],
        [unit3, product.factor_3, product.price_3]
      ].forEach(definition => {
        const label = definition[0];
        if (!label) return;
        const data = String(definition[1]) + '|' + String(definition[2]);
        if (duplicateUnits[label] && duplicateUnits[label] !== data) {
          throw _apiError('CONFLICTING_PRODUCT_UNITS', 'تعريف وحدات المنتج متعارض: ' + code, false);
        }
        duplicateUnits[label] = data;
      });
      const unit = String(item.unit || unit1).trim();
      if (!unit || ![unit1, unit2, unit3].filter(Boolean).includes(unit)) {
        if (offer) _offerError_('OFFER_CHANGED', 'وحدة المنتج المرتبط بالعرض تغيرت');
        throw _apiError('INVALID_PRODUCT_UNIT', 'الوحدة المحددة غير معرفة للمنتج ' + code, false);
      }
      let factor = 1;
      let unitPrice;
      if (unit === unit1) {
        unitPrice = product.display_price;
      } else if (unit === unit2) {
        factor = Number(String(product.factor_2 || '').trim());
        unitPrice = product.price_2;
      } else {
        factor = Number(String(product.factor_3 || '').trim());
        unitPrice = product.price_3;
      }
      if (unit !== unit1 && (!Number.isFinite(factor) || factor <= 0)) {
        throw _apiError('UNIT_CONVERSION_REQUIRED', 'معامل تحويل الوحدة غير مضبوط للمنتج ' + code, false);
      }
      if (unitPrice == null || String(unitPrice).trim() === '' || !Number.isFinite(Number(unitPrice))) {
        if (Object.prototype.hasOwnProperty.call(item, 'expected_unit_price')) {
          _offerError_('PRICE_CHANGED', 'سعر الوحدة تغير، يرجى تحديث الطلب');
        }
        throw _apiError('UNIT_PRICE_REQUIRED', 'سعر الوحدة غير مضبوط للمنتج ' + code, false);
      }
      const offerComponent = offer ? _offerComponentFor_(offer, code, unit) : null;
      const authoritativePrice = offer
        ? Number(offerComponent ? offerComponent.offer_price : offer.offer_price)
        : Number(unitPrice);
      if (Object.prototype.hasOwnProperty.call(item, 'expected_unit_price') &&
          (!['number', 'string'].includes(typeof item.expected_unit_price) ||
           String(item.expected_unit_price).trim() === '' ||
           !Number.isFinite(Number(item.expected_unit_price)) ||
           Number(item.expected_unit_price) !== authoritativePrice)) {
        _offerError_('PRICE_CHANGED', 'سعر الوحدة تغير، يرجى تحديث الطلب');
      }
      return { item: item, product: product, code: code, unit: unit, quantity: qty, factor: factor,
        unitPrice: authoritativePrice, offer: offer };
    });
    _validateOfferBundles_(validatedItems);

    _requireColumns_('Orders', [
      'order_id', 'order_number', 'customer_id', 'status', 'created_at',
      'updated_at', 'client_request_id'
    ]);
    _requireColumns_('Order_Items', [
      'item_id', 'order_id', 'order_number', 'code', 'name_snapshot',
      'unit', 'unit_factor', 'base_price_snapshot', 'unit_price_snapshot',
      'quantity_requested', 'display_price_snapshot'
    ]);
    if (hasOfferClaims) _requireColumns_('Order_Items', [
      'offer_id', 'offer_revision', 'offer_old_price', 'offer_min_quantity',
      'offer_starts_at', 'offer_ends_at'
    ]);

    // The global script lock protects both the annual sequence and this write.
    const orderNumber = _generateOrderNumber(existingOrders);
    const orderId = 'ORD-' + Utilities.getUuid();
    
    const orderObj = {
      order_id: orderId,
      order_number: orderNumber,
      customer_id: customerId,
      customer_name: body.customer_name || (customer ? (customer.full_name || customer.company_name) : 'عميل غير معروف'),
      status: 'pending',
      currency: requestedCurrency,
      note: body.note || body.notes || '',
      is_new: 'true',
      is_read: 'false',
      created_at: _now(),
      updated_at: _now(),
      created_by: user ? (user.username || user.user_id) : 'unknown',
      created_by_role: user ? user.role : '',
      client_request_id: clientRequestId
    };
    
    // حفظ الطلب الرئيسي
    _add('Orders', orderObj);

    // حفظ البنود
    let itemsSaved = 0;
    for (const validated of validatedItems) {
      const item = validated.item;
      const product = validated.product;
      _add('Order_Items', {
        item_id: 'ITM-' + Utilities.getUuid(),
        order_id: orderId,
        order_number: orderNumber,
        code: validated.code,
        name_snapshot: product.name || '',
        unit: validated.unit,
        unit_factor: validated.factor,
        base_price_snapshot: product.display_price === '' || product.display_price == null ? '' : Number(product.display_price),
        unit_price_snapshot: validated.unitPrice,
        unit_1: product.unit_1 || '',
        unit_2: product.unit_2 || '',
        factor_2: product.factor_2 || '',
        unit_3: product.unit_3 || '',
        factor_3: product.factor_3 || '',
        quantity_requested: validated.quantity,
        display_price_snapshot: validated.unitPrice,
        offer_id: validated.offer ? validated.offer.offer_id : '',
        offer_revision: validated.offer ? Number(validated.offer.revision) : '',
        offer_old_price: validated.offer
          ? Number((_offerComponentFor_(validated.offer, validated.code, validated.unit) || validated.offer).old_price)
          : '',
        offer_min_quantity: validated.offer
          ? Number((_offerComponentFor_(validated.offer, validated.code, validated.unit) || validated.offer).quantity ??
            validated.offer.min_quantity)
          : '',
        offer_starts_at: validated.offer ? _offerTime_(validated.offer.starts_at) : '',
        offer_ends_at: validated.offer ? _offerTime_(validated.offer.ends_at) : '',
        currency: orderObj.currency,
        status: 'pending',
        customer_note: item.note || item.customer_note || ''
      });
      itemsSaved++;
    }

    if (itemsSaved === 0) {
      throw new Error('لم يتم حفظ أي بنود في الطلب');
    }
    if (hasOfferClaims) SpreadsheetApp.flush();

    _sendNotificationToRoles(
      'admin,manager,accountant',
      'طلب جديد',
      'تم استلام طلب جديد رقم #' + orderNumber + ' من ' + orderObj.customer_name,
      'order.created',
      orderId,
      {
        order_id: orderId,
        customer_id: customerId,
        event_id: 'order.created:' + clientRequestId
      }
    );

    return { 
      success: true, 
      message: 'تم إرسال الطلبية بنجاح',
      order_id: orderId,
      order_number: orderNumber
    };
  } catch (e) {
    Logger.log('خطأ في إنشاء الطلب: ' + e.message);
    throw e;
  } finally {
    lock.releaseLock();
  }
}

/**
 * معالجة تحديث حالة الطلب مع ضوابط مالية صارمة
 */
function _handleUpdateOrderStatus(body, user) {
  const orderId = body.orderId || body.order_id;
  const newStatus = body.status;
  const requestId = body.request_id || Utilities.getUuid();
  const proxyForCustomer = body.proxy_for_customer === true ||
    String(body.proxy_for_customer || '').toLowerCase() === 'true';
  const proxyReason = String(body.reason || '').trim();

  if (!orderId || !newStatus) throw new Error('بيانات غير صالحة');
  if (proxyForCustomer) {
    if (!['admin', 'manager', 'accountant'].includes(_normalizeRole(user.role))) {
      throw _apiError('FORBIDDEN', 'لا يملك هذا الحساب تفويض تأكيد الزبون', false);
    }
    if (String(newStatus).trim().toLowerCase() !== 'customer_confirmed') {
      throw _apiError('INVALID_PROXY_ACTION', 'التفويض مسموح لتأكيد عرض السعر فقط', false);
    }
    if (proxyReason.length < 3) {
      throw _apiError('PROXY_REASON_REQUIRED', 'سبب مختصر مطلوب للتأكيد نيابةً عن الزبون', false);
    }
  }
  if (String(newStatus).trim().toLowerCase() === 'cancelled') {
    return _handleCancelOrder({
      order_id: orderId,
      cancellation_reason: body.cancellation_reason || body.reason || ''
    }, user);
  }

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) throw new Error('النظام مشغول بعملية ترحيل أخرى، يرجى المحاولة بعد قليل');

  try {
    const orders = _all('Orders');
    const orderIndex = orders.findIndex(o => String(o.order_id) === String(orderId));
    if (orderIndex === -1) throw new Error('الطلب غير موجود');
    const order = orders[orderIndex];
    _requireOrderOwnership(user, order);
    if (String(newStatus).trim().toLowerCase() === 'approved') {
      const accountingInvoiceNo = String(order.accounting_invoice_no || '')
        .replace(/\s+/g, ' ').trim().toLowerCase();
      if (accountingInvoiceNo && orders.some(item =>
        String(item.order_id) !== String(orderId) &&
        String(item.accounting_invoice_no || '').replace(/\s+/g, ' ').trim().toLowerCase() === accountingInvoiceNo
      )) {
        throw _apiError(
          'DUPLICATE_ACCOUNTING_INVOICE',
          'رقم الفاتورة المحاسبي مكرر؛ صححه قبل الاعتماد النهائي',
          false
        );
      }
    }

    // التحقق من صلاحية الانتقال
    _validateStateTransition(order.status, newStatus, user.role, {
      proxyForCustomer: proxyForCustomer,
    });

    // إذا كانت الحالة هي "الاعتماد النهائي" (approved) نقوم بالترحيل المالي والمخزني
    if (newStatus === 'approved') {
      if (order.status === 'approved' || order.posting_id) {
        return { success: true, message: 'الطلب معتمد ومرحّل مسبقاً', already_posted: true };
      }
      _executeFinalPosting(order, user, requestId);
    }

    const updates = {
      'status': newStatus,
      'updated_at': _now()
    };

    if (newStatus === 'approved') {
      updates['posting_id'] = 'POST-' + requestId.substring(0,8).toUpperCase();
      updates['posted_at'] = _now();
      updates['revision_no'] = (Number(order.revision_no || 0) + 1);
    }

    _updateByField('Orders', 'order_id', orderId, updates);

    // إرسال الإشعارات بناءً على الحالة الجديدة
    _dispatchStatusNotifications(order, newStatus, requestId);

    // إرسال إشعار للشحن إذا تم شحن الطلب
    if (newStatus === 'shipped') {
       _sendNotificationToRoles(
        'admin,manager',
        'تم شحن الطلب',
        'تم شحن الطلب رقم #' + (order.order_number || order.order_id),
        'shipping.shipped',
        order.order_id,
        { order_id: order.order_id, customer_id: order.customer_id }
      );
    }

    _add('Audit_Log', {
      log_id: Utilities.getUuid(),
      user_id: user.user_id,
      action: 'UPDATE_ORDER_STATUS',
      entity: 'Orders',
      entity_id: orderId,
      details: proxyForCustomer
        ? 'تأكيد عرض السعر نيابةً عن الزبون بواسطة ' + _normalizeRole(user.role) +
          ' | السبب: ' + proxyReason + ' | الحالة السابقة: ' + order.status +
          ' | الحالة الجديدة: ' + newStatus
        : 'تحديث الحالة إلى: ' + newStatus + (updates.posting_id ? ' | Posting: ' + updates.posting_id : ''),
      created_at: _now(),
    });

    return {
      success: true,
      status: newStatus,
      posting_id: updates.posting_id
    };

  } finally {
    lock.releaseLock();
  }
}

/**
 * التحقق من قواعد انتقال الحالات (RBAC + Workflow)
 */
function _validateStateTransition(oldStatus, newStatus, role, options) {
  const r = _normalizeRole(role);
  const proxyForCustomer = !!(options && options.proxyForCustomer);
  const from = String(oldStatus || '').trim().toLowerCase();
  const to = String(newStatus || '').trim().toLowerCase();
  const canApproveFinancially = ['admin', 'manager', 'accountant'].includes(r);
  const canManageWarehouse = ['admin', 'manager', 'warehouse'].includes(r);
  const isCustomer = r === 'customer';

  // منع تعديل طلب ملغى أو محذوف
  if (['cancelled', 'deleted'].includes(from)) {
    throw new Error('لا يمكن تعديل طلب ملغى أو محذوف');
  }

  // قواعد الانتقال
  if (to === 'customer_confirmed') {
    if (!isCustomer && !proxyForCustomer) {
      throw new Error('فقط الزبون أو مفوض مخول يمكنه تأكيد الطلبية');
    }
    if (proxyForCustomer && !['admin', 'manager', 'accountant'].includes(r)) {
      throw new Error('هذا الدور ليس مخولاً للتأكيد نيابةً عن الزبون');
    }
    if (from !== 'priced') {
      throw new Error('يجب تسعير الطلب أولاً قبل تأكيد السعر');
    }
  } else if (to === 'approved') {
    if (!canApproveFinancially) throw new Error('ليس لديك صلاحية الاعتماد المالي والترحيل');
    if (from !== 'customer_confirmed' && from !== 'approved') {
      throw new Error('يجب تأكيد السعر من الزبون أولاً قبل الاعتماد النهائي');
    }
  } else if (to === 'preparing') {
    if (!canManageWarehouse) {
      throw new Error('ليس لديك صلاحية تحديث حالة التجهيز/الشحن');
    }
    if (from !== 'approved') {
      throw new Error('يجب اعتماد الطلب مالياً قبل بدء التجهيز');
    }
  } else if (to === 'shipping') {
    if (!canManageWarehouse) {
      throw new Error('ليس لديك صلاحية تحديث حالة التجهيز/الشحن');
    }
    if (from !== 'prepared') {
      throw new Error('يجب تجهيز الطلب قبل شحنه');
    }
  } else if (to === 'delivered') {
    if (!canManageWarehouse) {
      throw new Error('ليس لديك صلاحية تحديث حالة التجهيز/الشحن');
    }
    if (from !== 'shipping') {
      throw new Error('يجب شحن الطلب قبل تأكيد التسليم');
    }
  } else {
    throw new Error('حالة الطلب المطلوبة لا تدعم التحديث المباشر');
  }

  // منع التراجع عن الترحيل (approved) إلى حالات سابقة مباشرة دون تصحيح
  if (from === 'approved' && ['pending', 'priced', 'customer_confirmed'].includes(to)) {
    throw new Error('لا يمكن إعادة الطلب لحالة المسودة بعد الترحيل المالي. استخدم طلب تصحيح.');
  }
}

/**
 * الترحيل النهائي: خصم المخزون وتسجيل القيود
 */
function _executeFinalPosting(order, user, requestId) {
  const items = _all('Order_Items').filter(i => String(i.order_id) === String(order.order_id));
  const productsSheet = _ss().getSheetByName('Products');
  const prodData = productsSheet.getDataRange().getValues();
  const prodHeaders = prodData[0];
  const codeIdx = prodHeaders.indexOf('code');
  const qtyIdx = prodHeaders.indexOf('quantity');

  const postingId = 'POST-' + requestId.substring(0,8).toUpperCase();

  // تجميع الكميات المطلوب خصمها لكل منتج (في حال تكرر نفس المنتج في الطلب)
  const deductions = {};
  const productMinStocks = {};
  const productNames = {};

  // قراءة الحد الأدنى لكل منتج
  const minStockIdx = prodHeaders.indexOf('minimum_stock');
  const nameIdx = prodHeaders.indexOf('name');

  items.forEach(item => {
    const qtyToDeduct = Number(item.quantity_approved || item.quantity_requested || 0);
    const isUnavailable = String(item.status).toLowerCase() === 'unavailable';
    if (qtyToDeduct > 0 && !isUnavailable) {
      const code = String(item.code);
      deductions[code] = (deductions[code] || 0) + qtyToDeduct;
    }
  });

  // تحديث البيانات في الذاكرة والتحقق من الحد الأدنى
  let modified = false;
  const lowStockAlerts = [];

  for (let j = 1; j < prodData.length; j++) {
    const code = String(prodData[j][codeIdx]);
    if (deductions[code]) {
      const currentQty = Number(prodData[j][qtyIdx] || 0);
      const newQty = currentQty - deductions[code];
      prodData[j][qtyIdx] = newQty;
      modified = true;

      const minStock = Number(prodData[j][minStockIdx] || 0);
      if (minStock > 0 && newQty < minStock) {
        lowStockAlerts.push({
          code: code,
          name: String(prodData[j][nameIdx] || code),
          quantity: newQty
        });
      }
    }
  }

  // حفظ التغييرات دفعة واحدة إذا حدث تعديل
  if (modified) {
    productsSheet.getDataRange().setValues(prodData);

    // إرسال تنبيهات نقص المخزون
    lowStockAlerts.forEach(alert => {
      _sendNotificationToRoles(
        'admin,accountant,warehouse',
        'تنبيه انخفاض المخزون',
        'انخفض مخزون المنتج ' + alert.name + ' عن الحد الأدنى بعد ترحيل الطلب.',
        'alert.low_stock',
        alert.code,
        { product_id: alert.code, high_priority: true }
      );
    });
  }

  // تسجيل حركات المخزون
  items.forEach(item => {
    const qtyToDeduct = Number(item.quantity_approved || item.quantity_requested || 0);
    const isUnavailable = String(item.status).toLowerCase() === 'unavailable';

    if (qtyToDeduct > 0 && !isUnavailable) {
      _add('Inventory_Movements', {
        movement_id: 'MV-' + Utilities.getUuid().substring(0,8),
        code: item.code,
        type: 'sale',
        quantity: qtyToDeduct,
        note: 'ترحيل نهائي للطلب: ' + (order.order_id),
        created_by: user.user_id,
        created_at: _now(),
        reference_id: order.order_id,
        posting_id: postingId,
        is_correction: 'false'
      });
    }
  });
}

/**
 * إرسال الإشعارات بناءً على الحالة
 */
function _dispatchStatusNotifications(order, newStatus, requestId) {
  const eventId = 'order.status:' + order.order_id + ':' + newStatus + ':' +
    String(requestId || order.updated_at || '');
  if (newStatus === 'customer_confirmed') {
    _sendNotificationToRoles(
      'accountant,admin',
      'تمت الموافقة على الطلب',
      'وافق العميل على الطلب #' + (order.order_number || order.order_id) + '.',
      'order.customer_confirmed',
      order.order_id,
      {
        order_id: order.order_id,
        customer_id: order.customer_id,
        event_id: eventId
      }
    );
  } else if (newStatus === 'approved') {
    _sendNotificationToRoles(
      'warehouse',
      'طلب جاهز للتجهيز',
      'تم اعتماد الطلب #' + (order.order_number || order.order_id) + '، يرجى البدء بالتجهيز.',
      'order.ready_for_preparation',
      order.order_id,
      {
        order_id: order.order_id,
        customer_id: order.customer_id,
        high_priority: true,
        event_id: eventId
      }
    );
    const customerUser = _all('Users').find(u => u.customer_id === order.customer_id);
    if (customerUser) {
      _sendNotification(customerUser.user_id, 'تم اعتماد طلبك', 'طلبك #' + (order.order_number || order.order_id) + ' قيد التجهيز الآن.', {
        event_type: 'order.approved',
        event_id: eventId,
        order_id: order.order_id,
        customer_id: order.customer_id
      });
      _sendNotification(customerUser.user_id, 'تم إصدار فاتورة', 'تم إنشاء فاتورة للطلب #' + (order.order_number || order.order_id) + '.', {
        event_type: 'invoice.created',
        event_id: eventId,
        order_id: order.order_id,
        invoice_id: order.accounting_invoice_no || order.order_id,
        customer_id: order.customer_id
      });
    }
    _sendNotificationToRoles(
      'admin',
      'تم إصدار فاتورة',
      'تم إنشاء فاتورة للطلب #' + (order.order_number || order.order_id) + '.',
      'invoice.created',
      order.order_id,
      {
        order_id: order.order_id,
        invoice_id: order.accounting_invoice_no || order.order_id,
        customer_id: order.customer_id
      }
    );
  } else if (newStatus === 'shipping') {
    const customerUser = _all('Users').find(u => u.customer_id === order.customer_id);
    const orderShipments = _all('Shipments')
      .filter(s => String(s.order_id) === String(order.order_id));
    const shipment = orderShipments.length
      ? orderShipments[orderShipments.length - 1]
      : {};
    const shippingBody = 'تم شحن الطلب #' + (order.order_number || order.order_id) +
      (shipment.carrier ? ' عبر ' + shipment.carrier : '') +
      (shipment.package_count ? '، ' + _shipmentPackageSummary_(shipment) : '') +
      (shipment.province ? '، الوجهة: ' + shipment.province : '') +
      (shipment.tracking_no ? '، التتبع: ' + shipment.tracking_no : '') + '.';
    const metadata = {
      event_type: 'shipping.shipped',
      order_id: order.order_id,
      customer_id: order.customer_id,
      high_priority: true
    };
    if (customerUser) {
      _sendNotification(customerUser.user_id, 'تم شحن طلبك', shippingBody, metadata);
    }
    _sendNotificationToRoles('accountant,admin', 'تم شحن الطلب', shippingBody, 'shipping.shipped', order.order_id, metadata);
  } else if (newStatus === 'delivered') {
    const customerUser = _all('Users').find(u => u.customer_id === order.customer_id);
    const metadata = {
      event_type: 'shipping.delivered',
      order_id: order.order_id,
      customer_id: order.customer_id
    };
    const body = 'تم تسليم الطلب #' + (order.order_number || order.order_id) + ' بنجاح.';
    if (customerUser) {
      _sendNotification(customerUser.user_id, 'تم تسليم طلبك', body, metadata);
    }
    _sendNotificationToRoles('accountant,admin', 'تم تسليم الطلب', body, 'shipping.delivered', order.order_id, metadata);
  }
}

/**
 * إجراء تصحيح لفاتورة مرحلة (Reversal/Correction)
 */
function _handleOrderCorrection(body, user) {
  _needRole(user, ['admin', 'manager']);
  const orderId = body.orderId || body.order_id;
  const reason = body.reason || 'تصحيح إداري';

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) throw new Error('النظام مشغول، يرجى المحاولة لاحقاً');

  try {
    const orders = _all('Orders');
    const order = orders.find(o => String(o.order_id) === String(orderId));

    if (!order || order.status !== 'approved') {
      throw new Error('يمكن تصحيح الطلبات المعتمدة فقط');
    }

    // 1. عكس حركات المخزون المرتبطة بالترحيل الحالي
    const movements = _all('Inventory_Movements').filter(m => String(m.reference_id) === String(orderId) && m.is_correction !== 'true');

    movements.forEach(m => {
      // إعادة الكمية للمخزون
      const productsSheet = _ss().getSheetByName('Products');
      const prodData = productsSheet.getDataRange().getValues();
      const codeIdx = prodData[0].indexOf('code');
      const qtyIdx = prodData[0].indexOf('quantity');

      for (let j = 1; j < prodData.length; j++) {
        if (String(prodData[j][codeIdx]) === String(m.code)) {
          const currentQty = Number(prodData[j][qtyIdx] || 0);
          productsSheet.getRange(j + 1, qtyIdx + 1).setValue(currentQty + Number(m.quantity));
          break;
        }
      }

      _add('Inventory_Movements', {
        movement_id: 'REV-' + Utilities.getUuid().substring(0,8),
        code: m.code,
        type: 'correction',
        quantity: m.quantity,
        note: 'عكس ترحيل للطلب: ' + orderId + ' - السبب: ' + reason,
        created_by: user.user_id,
        created_at: _now(),
        reference_id: orderId,
        is_correction: 'true'
      });
    });

    // 2. تحديث حالة الطلب لإعادته للمسودة أو المراجعة
    _updateByField('Orders', 'order_id', orderId, {
      status: 'customer_confirmed',
      posting_id: '',
      cancellation_reason: 'تصحيح مالي: ' + reason,
      updated_at: _now(),
      revision_no: (Number(order.revision_no || 0) + 1)
    });

    return { success: true, message: 'تم عكس الترحيل بنجاح، الطلب متاح للتعديل الآن' };
  } finally {
    lock.releaseLock();
  }
}

function _handleMarkOrderAsRead(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const orderId = body.orderId || body.order_id;
  if (!orderId) throw new Error('رقم الطلب مطلوب');

  const orders = _all('Orders');
  const orderIndex = orders.findIndex(o => o.order_id === orderId);
  if (orderIndex === -1) throw new Error('الطلب غير موجود');

  const sheet = _ss().getSheetByName('Orders');
  const rowIndex = orderIndex + 2;
  const headers = _getHeaders('Orders');
  const isReadCol = headers.indexOf('is_read') + 1;
  const isNewCol = headers.indexOf('is_new') + 1;

  sheet.getRange(rowIndex, isReadCol).setValue('true');
  sheet.getRange(rowIndex, isNewCol).setValue('false');

  return { success: true };
}

function _handleCancelOrder(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'customer']);
  const orderId = String(body.orderId || body.order_id || '');
  const reason = String(body.cancellation_reason || body.reason || '').trim();
  if (!orderId) throw new Error('رقم الطلب مطلوب');

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) throw new Error('النظام مشغول، يرجى المحاولة لاحقاً');
  try {
    const orders = _all('Orders');
    const orderIndex = orders.findIndex(o => String(o.order_id) === orderId);
    if (orderIndex === -1) throw new Error('الطلب غير موجود');
    const order = orders[orderIndex];
    const role = _normalizeRole(user.role);
    const status = String(order.status || '').trim().toLowerCase();
    _requireOrderOwnership(user, order);

    if (['cancelled', 'deleted'].includes(status)) {
      if (status === 'cancelled') {
        return { success: true, status: 'cancelled', is_duplicate: true };
      }
      throw _apiError('INVALID_STATE', 'لا يمكن إلغاء طلب محذوف', false);
    }
    if (role === 'customer' &&
        !['pending', 'submitted', 'processing', 'customer_changed', 'priced'].includes(status)) {
      throw _apiError('INVALID_STATE', 'يمكن للزبون إلغاء الطلب في مرحلتي المعالجة والتسعير فقط', false);
    }

    const sheet = _ss().getSheetByName('Orders');
    const rowIndex = orderIndex + 2;
    const headers = _getHeaders('Orders');
    const requiredColumns = [
      'status',
      'cancellation_reason',
      'cancelled_at',
      'cancelled_by',
      'updated_at'
    ];
    const missingColumn = requiredColumns.find(field => headers.indexOf(field) < 0);
    if (missingColumn) {
      throw new Error('عمود الطلب غير مهيأ: ' + missingColumn + '؛ شغّل setupSystem أولاً');
    }
    _reverseOrderInventoryForCancellation_(order, user, reason || 'إلغاء الفاتورة');

    const setOrderValue = (field, value) => {
      const column = headers.indexOf(field) + 1;
      sheet.getRange(rowIndex, column).setValue(value);
    };
    setOrderValue('status', 'cancelled');
    setOrderValue('cancellation_reason', reason);
    setOrderValue('cancelled_at', _now());
    setOrderValue('cancelled_by', user.user_id || '');
    setOrderValue('updated_at', _now());

    _add('Audit_Log', {
      log_id: Utilities.getUuid(),
      user_id: user.user_id,
      action: 'CANCEL_ORDER',
      entity: 'Orders',
      entity_id: orderId,
      details: 'إلغاء الفاتورة وعكس حركات المخزون المرحلة. السبب: ' + (reason || 'غير محدد'),
      created_at: _now(),
    });

    _sendNotificationToRoles(
      'admin,accountant,warehouse',
      'تم إلغاء الطلب',
      'تم إلغاء الطلب #' + (order.order_number || orderId) +
        (reason ? '. ' + _safeCancellationReason_(reason) : '.'),
      'order.cancelled',
      orderId,
      { order_id: orderId, customer_id: order.customer_id }
    );
    const customerUser = _all('Users').find(u => u.customer_id === order.customer_id);
    if (customerUser) {
      _sendNotification(
        customerUser.user_id,
        'تم إلغاء الطلب',
        'تم إلغاء الطلب #' + (order.order_number || orderId) +
          (reason ? '. ' + _safeCancellationReason_(reason) : '.'),
        { event_type: 'order.cancelled', order_id: orderId, customer_id: order.customer_id }
      );
    }

    return { success: true, status: 'cancelled' };
  } finally {
    lock.releaseLock();
  }
}

function _reverseOrderInventoryForCancellation_(order, user, reason) {
  const orderId = String(order.order_id);
  const movements = _all('Inventory_Movements').filter(
    movement => String(movement.reference_id || '') === orderId
  );
  if (!movements.length) return;

  const netConsumedByCode = {};
  movements.forEach(movement => {
    const quantity = Number(movement.quantity || 0);
    if (!Number.isFinite(quantity) || quantity <= 0) return;
    const type = String(movement.type || '').toLowerCase();
    const sign = type === 'sale' ? 1 : type === 'correction' ? -1 : 0;
    if (sign) {
      const code = String(movement.code || '');
      netConsumedByCode[code] = (netConsumedByCode[code] || 0) + sign * quantity;
    }
  });

  const productsSheet = _ss().getSheetByName('Products');
  const productData = productsSheet.getDataRange().getValues();
  const headers = productData[0].map(String);
  const codeIdx = headers.indexOf('code');
  const quantityIdx = headers.indexOf('quantity');
  if (codeIdx < 0 || quantityIdx < 0) throw new Error('تعذر عكس المخزون: أعمدة المنتج غير موجودة');

  const changes = [];
  Object.keys(netConsumedByCode).forEach(code => {
    const netQuantity = netConsumedByCode[code];
    if (Math.abs(netQuantity) < 0.000001) return;
    const rowIndex = productData.findIndex((row, index) =>
      index > 0 && String(row[codeIdx]) === code
    );
    if (rowIndex < 0) throw new Error('تعذر عكس المخزون للصنف غير الموجود: ' + code);
    changes.push({ code: code, rowIndex: rowIndex, quantity: netQuantity });
  });

  changes.forEach(change => {
    const currentQuantity = Number(productData[change.rowIndex][quantityIdx] || 0);
    const updatedQuantity = currentQuantity + change.quantity;
    if (updatedQuantity < 0) {
      throw new Error('تعذر إلغاء الفاتورة لأن مخزون الصنف ' + change.code + ' غير كافٍ لعكس الحركات السابقة');
    }
  });

  changes.forEach(change => {
    const currentQuantity = Number(productData[change.rowIndex][quantityIdx] || 0);
    productsSheet.getRange(change.rowIndex + 1, quantityIdx + 1)
      .setValue(currentQuantity + change.quantity);
    _add('Inventory_Movements', {
      movement_id: 'REV-' + Utilities.getUuid().substring(0, 8),
      code: change.code,
      type: change.quantity > 0 ? 'correction' : 'sale',
      quantity: Math.abs(change.quantity),
      note: 'عكس إلغاء الفاتورة ' + orderId + ' - السبب: ' + reason,
      created_by: user.user_id,
      created_at: _now(),
      reference_id: orderId,
      posting_id: order.posting_id || '',
      is_correction: 'true'
    });
  });
}

function _handleDeleteOrder(body, user) {
  _needRole(user, ['admin', 'manager']);
  const orderId = body.orderId || body.order_id;
  const reason = body.cancellation_reason || '';
  if (!orderId) throw new Error('رقم الطلب مطلوب');

  const orders = _all('Orders');
  const orderIndex = orders.findIndex(o => o.order_id === orderId);
  if (orderIndex === -1) throw new Error('الطلب غير موجود');

  const sheet = _ss().getSheetByName('Orders');
  const rowIndex = orderIndex + 2;
  const headers = _getHeaders('Orders');
  const statusCol = headers.indexOf('status') + 1;
  const reasonCol = headers.indexOf('cancellation_reason') + 1;
  const updatedCol = headers.indexOf('updated_at') + 1;

  sheet.getRange(rowIndex, statusCol).setValue('deleted');
  sheet.getRange(rowIndex, reasonCol).setValue(reason);
  sheet.getRange(rowIndex, updatedCol).setValue(_now());

  _add('Audit_Log', {
    log_id: Utilities.getUuid(),
    user_id: user.user_id,
    action: 'DELETE_ORDER',
    entity: 'Orders',
    entity_id: orderId,
    details: 'حذف نهائي للطلب. السبب: ' + reason,
    created_at: _now(),
  });

  return { success: true };
}

function _roundOrderAmount_(amount) {
  return Math.round((Number(amount) + Number.EPSILON) * 100) / 100;
}

function _parseOrderDiscount_(input, subtotal) {
  const raw = String(input == null ? '' : input).trim();
  if (!raw) {
    return { type: 'none', input: '', amount: 0, netTotal: _roundOrderAmount_(subtotal) };
  }
  const digits = {
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9'
  };
  let normalized = raw.replace(/[٠-٩۰-۹]/g, digit => digits[digit]);
  normalized = normalized.replace(/٫/g, '.');
  if (/\d\s+\d/.test(normalized)) {
    throw _apiError('INVALID_DISCOUNT', 'المسافات داخل الرقم تجعل قيمة الحسم غامضة', false);
  }
  normalized = normalized.replace(/\s/g, '');
  const percentMarks = (normalized.match(/[%٪]/g) || []).length;
  const type = percentMarks ? 'percent' : 'amount';
  if (percentMarks) {
    if (percentMarks !== 1 || !/[%٪]$/.test(normalized)) {
      throw _apiError('INVALID_DISCOUNT', 'صيغة الحسم غير واضحة؛ ضع % بعد النسبة', false);
    }
    normalized = normalized.slice(0, -1);
  }
  if (!/^\d+(?:[.,]\d{1,2})?$/.test(normalized) ||
      (normalized.includes('.') && normalized.includes(','))) {
    throw _apiError('INVALID_DISCOUNT', 'أدخل مبلغاً أو نسبة صحيحة؛ لا تستخدم فواصل آلاف أو قيمة سالبة', false);
  }
  const numeric = Number(normalized.replace(',', '.'));
  if (!Number.isFinite(numeric) || numeric < 0) {
    throw _apiError('INVALID_DISCOUNT', 'قيمة الحسم يجب أن تكون رقماً غير سالب', false);
  }
  let amount;
  if (type === 'percent') {
    if (numeric > 100) {
      throw _apiError('INVALID_DISCOUNT', 'نسبة الحسم يجب ألا تتجاوز 100%', false);
    }
    amount = _roundOrderAmount_(subtotal * numeric / 100);
  } else {
    amount = _roundOrderAmount_(numeric);
    if (amount > _roundOrderAmount_(subtotal)) {
      throw _apiError('INVALID_DISCOUNT', 'مبلغ الحسم لا يجوز أن يتجاوز إجمالي الفاتورة', false);
    }
  }
  return {
    type: type,
    input: raw.replace(/\s+/g, ' ').trim(),
    amount: amount,
    netTotal: _roundOrderAmount_(subtotal - amount)
  };
}

function _handleUpdateAccountingInvoiceNumber(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const orderId = resolveOrderIdentifier_(body);
  if (!orderId) throw _apiError('ORDER_IDENTIFIER_REQUIRED', 'رقم الطلب مطلوب', false);
  const input = String(body.accounting_invoice_no == null ? '' : body.accounting_invoice_no)
    .replace(/\s+/g, ' ').trim();
  if (input.length > 64) {
    throw _apiError('ACCOUNTING_INVOICE_TOO_LONG', 'رقم الفاتورة المحاسبي يجب ألا يتجاوز 64 حرفاً', false);
  }

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(15000)) {
    throw _apiError('BUSY', 'النظام مشغول، يرجى المحاولة لاحقاً', true);
  }
  try {
    _requireColumns_('Orders', [
      'order_id', 'accounting_invoice_no', 'accounting_invoice_no_updated_by',
      'accounting_invoice_no_updated_at', 'updated_at'
    ]);
    const orders = _all('Orders');
    const order = orders.find(item => String(item.order_id) === String(orderId));
    if (!order) throw _apiError('ORDER_NOT_FOUND', 'الطلب غير موجود', false);
    const previous = String(order.accounting_invoice_no || '').replace(/\s+/g, ' ').trim();
    const duplicate = input && orders.some(item =>
      String(item.order_id) !== String(orderId) &&
      String(item.accounting_invoice_no || '').replace(/\s+/g, ' ').trim().toLowerCase() === input.toLowerCase()
    );
    if (duplicate) {
      throw _apiError('DUPLICATE_ACCOUNTING_INVOICE', 'رقم الفاتورة المحاسبي مستخدم في طلب آخر', false);
    }
    if (previous === input) return { success: true, accounting_invoice_no: input };

    _requireColumns_('Audit_Log', ['log_id', 'user_id', 'action', 'entity', 'entity_id', 'details', 'created_at']);
    const now = _now();
    _updateByField('Orders', 'order_id', orderId, {
      accounting_invoice_no: input,
      accounting_invoice_no_updated_by: user.user_id || user.username || '',
      accounting_invoice_no_updated_at: now,
      updated_at: now
    });
    _add('Audit_Log', {
      log_id: Utilities.getUuid(),
      user_id: user.user_id,
      action: 'ORDER_ACCOUNTING_INVOICE_UPDATED',
      entity: 'Orders',
      entity_id: orderId,
      details: JSON.stringify({ previous: previous, new: input }),
      created_at: now
    });
    return {
      success: true,
      accounting_invoice_no: input,
      accounting_invoice_no_updated_by: user.user_id || user.username || '',
      accounting_invoice_no_updated_at: now
    };
  } finally {
    lock.releaseLock();
  }
}

function _handleUpdateOrderPricing(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);

  const orderId = resolveOrderIdentifier_(body);
  if (!orderId) {
    throw new Error('رقم الطلب مطلوب');
  }

  const itemsUpdates = body.items || [];
  if (!Array.isArray(itemsUpdates)) {
    throw new Error('بيانات البنود غير صالحة');
  }

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(15000)) {
    throw new Error('جاري معالجة الطلب، يرجى الانتظار قليلاً');
  }
  
  try {
    const ss = _ss();
    const ordersSheet = ss.getSheetByName('Orders');
    const ordersData = ordersSheet.getDataRange().getValues();
    const ordersHeaders = ordersData[0].map(h => String(h).trim());
    const oIdColIdx = ordersHeaders.indexOf('order_id');
    let currentOrderData = null;
    for (let i = 1; i < ordersData.length; i++) {
      if (String(ordersData[i][oIdColIdx]).trim() === orderId) {
        currentOrderData = Object.fromEntries(ordersHeaders.map((h, j) => [h, ordersData[i][j]]));
        break;
      }
    }
    if (!currentOrderData) throw new Error('الطلب غير موجود');
    _requireColumns_('Orders', [
      'order_id', 'subtotal', 'total', 'discount', 'discount_type',
      'discount_input', 'discount_reason', 'updated_at'
    ]);
    const previousDiscount = Number(currentOrderData.discount || 0);
    if (!Number.isFinite(previousDiscount) || previousDiscount < 0) {
      throw _apiError('INVALID_STORED_DISCOUNT', 'بيانات الحسم المحفوظة غير صالحة', false);
    }
    if (body.last_updated_at && currentOrderData.updated_at) {
      const clientTs = new Date(body.last_updated_at).getTime();
      const serverTs = new Date(currentOrderData.updated_at).getTime();
      if (Math.abs(serverTs - clientTs) > 2000 && serverTs > clientTs) {
        throw new Error('فشل الحفظ: قام مستخدم آخر بتعديل الطلب بالفعل. يرجى تحديث البيانات والمحاولة مرة أخرى.');
      }
    }

    // 1. تحديث بنود الطلب في ورقة Order_Items
    const itemsSheet = ss.getSheetByName('Order_Items');
    const itemsData = itemsSheet.getDataRange().getValues();
    const itemsHeaders = itemsData[0].map(h => String(h).trim());
    
    const idIdx = itemsHeaders.indexOf('item_id');
    const oIdIdx = itemsHeaders.indexOf('order_id');
    const codeIdx = itemsHeaders.indexOf('code');
    const qtyAppIdx = itemsHeaders.indexOf('quantity_approved');
    const finalPriceIdx = itemsHeaders.indexOf('final_price');
    const statusIdx = itemsHeaders.indexOf('status');
    const accNoteIdx = itemsHeaders.indexOf('accountant_note');
    const totalIdx = itemsHeaders.indexOf('total_price');
    const unitIdx = itemsHeaders.indexOf('unit');
    const offerIdIdx = itemsHeaders.indexOf('offer_id');
    const offerMinIdx = itemsHeaders.indexOf('offer_min_quantity');
    const offerPriceIdx = itemsHeaders.indexOf('unit_price_snapshot');

    // تجميع الأكواد الموجودة حالياً لهذا الطلب
    const existingItems = {};
    const offerItems = new Map();
    const duplicateCodes = new Set();
    for (let i = 1; i < itemsData.length; i++) {
      if (String(itemsData[i][oIdIdx]).trim() === orderId) {
        const code = String(itemsData[i][codeIdx]).trim();
        if (Object.prototype.hasOwnProperty.call(existingItems, code)) duplicateCodes.add(code);
        existingItems[code] = i + 1;
        if (offerIdIdx >= 0 && String(itemsData[i][offerIdIdx] || '').trim()) {
          offerItems.set(code, itemsData[i]);
        }
      }
    }
    if (offerItems.size) {
      const rejectOfferPricing = () => _offerError_('OFFER_REQUOTE_REQUIRED',
        'تعذر تسعير العرض بشروط مختلفة عن لقطة الطلب؛ يلزم إعادة اقتباس');
      const overrides = [];
      if (offerMinIdx < 0 || offerPriceIdx < 0 || unitIdx < 0 ||
          qtyAppIdx < 0 || finalPriceIdx < 0 || statusIdx < 0 || totalIdx < 0) {
        rejectOfferPricing();
      }
      const submitted = new Map();
      itemsUpdates.forEach(item => {
        if (!item || typeof item !== 'object' || Array.isArray(item)) rejectOfferPricing();
        const code = String(item.productId || item.code || '').trim();
        if (!code || submitted.has(code)) rejectOfferPricing();
        submitted.set(code, item);
      });
      offerItems.forEach((row, code) => {
        const item = submitted.get(code);
        if (duplicateCodes.has(code) || !item) rejectOfferPricing();
        const unit = String(row[unitIdx] || '').trim();
        const min = row[offerMinIdx], price = row[offerPriceIdx];
        if (!unit || min == null || String(min).trim() === '' ||
            !Number.isFinite(Number(min)) || Number(min) <= 0 ||
            price == null || String(price).trim() === '' ||
            !Number.isFinite(Number(price)) || Number(price) <= 0 ||
            (item.unit != null && String(item.unit).trim() !== '' &&
             String(item.unit).trim() !== unit)) rejectOfferPricing();
        if (item.status !== 'unavailable') {
          const qty = item.quantity_approved !== undefined ? item.quantity_approved : item.quantity;
          const finalPrice = item.final_price !== undefined ? item.final_price :
            (item.price !== undefined ? item.price : item.unitPrice);
          if (!['number', 'string'].includes(typeof qty) || String(qty).trim() === '' || !Number.isFinite(Number(qty)) ||
              Number(qty) < Number(min) || !['number', 'string'].includes(typeof finalPrice) || String(finalPrice).trim() === '' ||
              !Number.isFinite(Number(finalPrice)) || Number(finalPrice) < 0 ||
              (Number(finalPrice) !== Number(price) && body.confirm_offer_price_override !== true)) {
            rejectOfferPricing();
          }
          if (Number(finalPrice) !== Number(price)) {
            overrides.push({
              item_id: idIdx >= 0 ? row[idIdx] : '', code: code, unit: unit,
              offer_id: row[offerIdIdx], offer_price: Number(price),
              previous_final_price: finalPriceIdx >= 0 && row[finalPriceIdx] !== '' ? Number(row[finalPriceIdx]) : null,
              final_price: Number(finalPrice), quantity_approved: Number(qty)
            });
          }
        }
      });
      if (overrides.length) {
        _requireColumns_('Audit_Log', H.Audit_Log);
        _add('Audit_Log', {
          log_id: Utilities.getUuid(), user_id: user.user_id,
          action: 'OFFER_PRICE_OVERRIDE', entity: 'Orders', entity_id: orderId,
          details: JSON.stringify({ overrides: overrides }), created_at: _now()
        });
        SpreadsheetApp.flush();
      }
    }

    let calculatedSubtotal = 0;
    const submittedCodesForTotals = new Set();
    itemsUpdates.forEach(item => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) {
        throw _apiError('INVALID_PRICING_ITEM', 'بيانات أحد البنود غير صالحة', false);
      }
      const code = String(item.productId || item.code || '').trim();
      if (!code || submittedCodesForTotals.has(code)) {
        throw _apiError('INVALID_PRICING_ITEM', 'رمز المنتج مطلوب ولا يجوز تكرار البند', false);
      }
      submittedCodesForTotals.add(code);
      if (item.status === 'unavailable') return;
      const rawQuantity = item.quantity_approved !== undefined ? item.quantity_approved : (item.quantity || 0);
      const rawPrice = item.final_price !== undefined ? item.final_price : (item.price !== undefined ? item.price : (item.unitPrice || 0));
      const quantity = Number(rawQuantity);
      const price = Number(rawPrice);
      if (!Number.isFinite(quantity) || quantity < 0 ||
          !Number.isFinite(price) || price < 0) {
        throw _apiError('INVALID_PRICING_ITEM', 'الكمية والسعر يجب أن يكونا رقمين غير سالبين', false);
      }
      calculatedSubtotal += _roundOrderAmount_(quantity * price);
    });
    calculatedSubtotal = _roundOrderAmount_(calculatedSubtotal);

    const hasDiscountInput = Object.prototype.hasOwnProperty.call(body, 'discount_input');
    const previousType = String(currentOrderData.discount_type || (previousDiscount > 0 ? 'amount' : 'none'));
    const storedPreviousInput = String(currentOrderData.discount_input || '');
    const previousInput = storedPreviousInput || (previousDiscount > 0 ? String(previousDiscount) : '');
    let parsedDiscount;
    if (hasDiscountInput) {
      parsedDiscount = _parseOrderDiscount_(body.discount_input, calculatedSubtotal);
    } else if (previousType === 'percent' && previousInput) {
      parsedDiscount = _parseOrderDiscount_(previousInput, calculatedSubtotal);
    } else {
      parsedDiscount = {
        type: previousDiscount > 0 ? 'amount' : 'none',
        input: previousInput,
        amount: _roundOrderAmount_(previousDiscount),
        netTotal: _roundOrderAmount_(calculatedSubtotal - previousDiscount)
      };
      if (parsedDiscount.amount > calculatedSubtotal) {
        throw _apiError('INVALID_DISCOUNT', 'مبلغ الحسم المحفوظ يتجاوز إجمالي الفاتورة', false);
      }
    }
    const discountChanged =
      Math.abs(previousDiscount - parsedDiscount.amount) >= 0.005 ||
      previousType !== parsedDiscount.type ||
      (storedPreviousInput !== '' && previousInput !== parsedDiscount.input);
    if (discountChanged && String(body.discount_reason || '').trim().length < 3) {
      throw _apiError('DISCOUNT_REASON_REQUIRED', 'أدخل سبباً مختصراً للحسم', false);
    }
    if (discountChanged &&
        (currentOrderData.posting_id ||
        ['approved', 'prepared', 'shipping', 'shipped', 'delivered', 'returned'].includes(
          String(currentOrderData.status || '').toLowerCase()
        ))) {
      throw _apiError('DISCOUNT_LOCKED', 'لا يمكن تعديل الحسم بعد الاعتماد النهائي؛ يلزم إجراء تصحيح مالي مخوّل', false);
    }
    if (discountChanged) {
      _requireColumns_('Audit_Log', ['log_id', 'user_id', 'action', 'entity', 'entity_id', 'details', 'created_at']);
    }

    // معالجة التحديثات والإضافات وحساب الإجمالي من البنود المحفوظة
    itemsUpdates.forEach(item => {
      const code = String(item.productId || item.code || '').trim();
      const isOfferItem = offerItems.has(code);
      const available = item.status !== 'unavailable';
      const status = available ? 'available' : 'unavailable';
      const rawQuantity = item.quantity_approved !== undefined ? item.quantity_approved : (item.quantity || 0);
      const rawPrice = item.final_price !== undefined ? item.final_price : (item.price !== undefined ? item.price : (item.unitPrice || 0));
      const qty = !available ? 0 : Number(rawQuantity);
      const price = !available ? 0 : Number(rawPrice);
      if (!Number.isFinite(qty) || qty < 0 || !Number.isFinite(price) || price < 0) {
        throw _apiError('INVALID_PRICING_ITEM', 'الكمية والسعر يجب أن يكونا رقمين غير سالبين', false);
      }
      const note = item.accountant_note || item.note || '';
      const lineTotal = available ? _roundOrderAmount_(qty * price) : 0;
      const unit = item.unit || '';

      // Additional tracking fields
      const unitFactor = item.unit_factor;
      const basePriceSnapshot = item.base_price_snapshot;
      const unit1 = item.unit_1;
      const unit2 = item.unit_2;
      const factor2 = item.factor_2;
      const unit3 = item.unit_3;
      const factor3 = item.factor_3;

      if (existingItems[code]) {
        // تحديث بند موجود
        const row = existingItems[code];
        if (qtyAppIdx !== -1) itemsSheet.getRange(row, qtyAppIdx + 1).setValue(qty);
        if (finalPriceIdx !== -1) itemsSheet.getRange(row, finalPriceIdx + 1).setValue(price);
        if (statusIdx !== -1) itemsSheet.getRange(row, statusIdx + 1).setValue(status);
        if (accNoteIdx !== -1) itemsSheet.getRange(row, accNoteIdx + 1).setValue(note);
        if (totalIdx !== -1) itemsSheet.getRange(row, totalIdx + 1).setValue(lineTotal);
        if (!isOfferItem && unitIdx !== -1 && unit) itemsSheet.getRange(row, unitIdx + 1).setValue(unit);

        // Update new tracking fields if present
        if (!isOfferItem) {
          const ufIdx = itemsHeaders.indexOf('unit_factor');
          if (ufIdx !== -1 && unitFactor !== undefined) itemsSheet.getRange(row, ufIdx + 1).setValue(unitFactor);

          const bpsIdx = itemsHeaders.indexOf('base_price_snapshot');
          if (bpsIdx !== -1 && basePriceSnapshot !== undefined) itemsSheet.getRange(row, bpsIdx + 1).setValue(basePriceSnapshot);

          const u1Idx = itemsHeaders.indexOf('unit_1');
          if (u1Idx !== -1 && unit1 !== undefined) itemsSheet.getRange(row, u1Idx + 1).setValue(unit1);

          const u2Idx = itemsHeaders.indexOf('unit_2');
          if (u2Idx !== -1 && unit2 !== undefined) itemsSheet.getRange(row, u2Idx + 1).setValue(unit2);

          const f2Idx = itemsHeaders.indexOf('factor_2');
          if (f2Idx !== -1 && factor2 !== undefined) itemsSheet.getRange(row, f2Idx + 1).setValue(factor2);

          const u3Idx = itemsHeaders.indexOf('unit_3');
          if (u3Idx !== -1 && unit3 !== undefined) itemsSheet.getRange(row, u3Idx + 1).setValue(unit3);

          const f3Idx = itemsHeaders.indexOf('factor_3');
          if (f3Idx !== -1 && factor3 !== undefined) itemsSheet.getRange(row, f3Idx + 1).setValue(factor3);
        }
      } else {
        // إضافة بند جديد
        _add('Order_Items', {
          item_id: 'ITM-' + Utilities.getUuid().substring(0, 8),
          order_id: orderId,
          order_number: currentOrderData.order_number || '',
          code: code,
          unit: unit,
          unit_factor: unitFactor,
          base_price_snapshot: basePriceSnapshot,
          unit_1: unit1,
          unit_2: unit2,
          factor_2: factor2,
          unit_3: unit3,
          factor_3: factor3,
          quantity_requested: qty,
          quantity_approved: qty,
          final_price: price,
          status: status,
          accountant_note: note,
          total_price: lineTotal,
          currency: body.currency || 'USD'
        });
      }
    });
    // حذف البنود التي لم تعد موجودة في القائمة المرسلة (الحذف من الأسفل للأعلى لتجنب إزاحة الفهرس)
    const newCodes = itemsUpdates.map(item => String(item.productId || item.code || '').trim());
    const rowsToDelete = [];
    Object.keys(existingItems).forEach(oldCode => {
      if (!newCodes.includes(oldCode)) {
        rowsToDelete.push(existingItems[oldCode]);
      }
    });

    rowsToDelete.sort((a, b) => b - a).forEach(row => {
      itemsSheet.deleteRow(row);
    });

    // 2. تحديث الطلب الرئيسي في ورقة Orders
    const updates = {
      'updated_at': _now(),
      'subtotal': calculatedSubtotal,
      'total': parsedDiscount.netTotal,
      'discount_type': parsedDiscount.type,
      'discount_input': parsedDiscount.input,
      'discount': parsedDiscount.amount,
      'discount_reason': discountChanged ? String(body.discount_reason || '').trim() : (currentOrderData.discount_reason || ''),
      'accountant_notes': body.notes || '',
      'priced_by': body.pricedBy || user.user_id,
      'priced_at': _now()
    };

      if (body.submitForCustomer === true) {
        updates['status'] = 'priced';
      }

      _updateByField('Orders', 'order_id', orderId, updates);
      if (discountChanged) {
        _add('Audit_Log', {
          log_id: Utilities.getUuid(),
          user_id: user.user_id,
          action: 'ORDER_DISCOUNT_UPDATED',
          entity: 'Orders',
          entity_id: orderId,
          details: JSON.stringify({
            previous: {
              type: previousType,
              input: previousInput,
              amount: previousDiscount,
              subtotal: Number(currentOrderData.subtotal || 0),
              total: Number(currentOrderData.total || currentOrderData.subtotal || 0)
            },
            new: {
              type: parsedDiscount.type,
              input: parsedDiscount.input,
              amount: parsedDiscount.amount,
              subtotal: calculatedSubtotal,
              total: parsedDiscount.netTotal
            },
            reason: String(body.discount_reason || '').trim()
          }),
          created_at: _now()
        });
      }

      // إشعار للزبون والإدارة بعد إرسال التسعير للمراجعة
      if (body.submitForCustomer === true) {
        const order = _all('Orders').find(o => String(o.order_id).trim() === orderId);
        if (order) {
          const customerUser = _all('Users').find(u => u.customer_id === order.customer_id);
          if (customerUser) {
            _sendNotification(customerUser.user_id, 'تم تسعير طلبك', 'الطلب #' + (order.order_number || orderId) + ' جاهز للمراجعة.', {
              event_type: 'order.priced',
              order_id: orderId,
              customer_id: order.customer_id
            });
          }
          _sendNotificationToRoles('admin', 'تم تسعير الطلب', 'تم تسعير الطلب #' + (order.order_number || orderId) + ' وإرساله للعميل للمراجعة.', 'order.priced', orderId, {
            order_id: orderId,
            customer_id: order.customer_id
          });
        }
      }

      return {
        success: true,
        message: body.submitForCustomer ? 'تم اعتماد التسعير وإرساله للزبون' : 'تم حفظ المسودة بنجاح',
        orderId: orderId,
        status: body.submitForCustomer ? 'priced' : undefined
      };

    } catch (e) {
    Logger.log('Error in price_order: ' + e.message);
    throw e;
  } finally {
    lock.releaseLock();
  }
}

function _handleEditOrder(body, user) {
  const role = _normalizeRole(user && user.role);
  const orderId = String(body.orderId || body.order_id || '').trim();
  const submittedItems = body.items;
  if (!orderId || !Array.isArray(submittedItems) || !submittedItems.length) {
    throw _apiError('INVALID_ORDER', 'بيانات الطلب أو الأصناف غير صالحة', false);
  }

  const customerCanEdit = role === 'customer';
  const financialCanEdit = ['admin', 'manager', 'accountant'].includes(role);
  if (!customerCanEdit && !financialCanEdit) {
    throw _apiError('FORBIDDEN', 'ليس لديك صلاحية تعديل الطلب', false);
  }

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) {
    throw _apiError('BUSY', 'النظام مشغول، يرجى المحاولة لاحقاً', true);
  }

  try {
    const orders = _all('Orders');
    const order = orders.find(item => String(item.order_id) === orderId);
    if (!order) throw _apiError('ORDER_NOT_FOUND', 'الطلب غير موجود', false);
    _requireOrderOwnership(user, order);

    const status = String(order.status || '').trim().toLowerCase();
    const customerStatuses = ['pending', 'submitted', 'processing', 'customer_changed', 'priced'];
    const financialStatuses = [
      'pending', 'submitted', 'processing', 'customer_changed', 'priced',
      'customer_confirmed', 'approved'
    ];
    if (!(customerCanEdit ? customerStatuses : financialStatuses).includes(status)) {
      throw _apiError('INVALID_STATE', 'لا يمكن تعديل الطلب في مرحلته الحالية', false);
    }
    if (!customerCanEdit && ['priced', 'customer_confirmed', 'approved'].includes(status)) {
      _requireColumns_('Orders', [
        'subtotal', 'total', 'discount', 'discount_type', 'discount_input',
        'discount_reason'
      ]);
    }
    const ss = _ss();
    const itemsSheet = ss.getSheetByName('Order_Items');
    const itemsData = itemsSheet.getDataRange().getValues();
    if (itemsData.length === 0) throw new Error('جدول أصناف الطلبات غير مهيأ');
    const headers = itemsData[0].map(header => String(header).trim());
    const col = name => headers.indexOf(name);
    const requiredColumns = ['item_id', 'order_id', 'code', 'unit', 'quantity_requested'];
    if (requiredColumns.some(name => col(name) < 0)) {
      throw new Error('أعمدة أصناف الطلب غير مهيأة. شغّل setupSystem أولاً');
    }

    const existingRows = new Map();
    const orderIdCol = col('order_id');
    const itemIdCol = col('item_id');
    for (let rowIndex = 1; rowIndex < itemsData.length; rowIndex++) {
      if (String(itemsData[rowIndex][orderIdCol]).trim() === orderId) {
        existingRows.set(String(itemsData[rowIndex][itemIdCol]), {
          rowNumber: rowIndex + 1,
          values: itemsData[rowIndex]
        });
      }
    }
    const existingOffers = new Map();
    existingRows.forEach((row, id) => {
      const previous = Object.fromEntries(headers.map((header, index) => [header, row.values[index]]));
      if (String(previous.offer_id || '').trim()) existingOffers.set(id, previous);
    });
    const offerIds = new Set();
    submittedItems.forEach(item => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) {
        throw _apiError('INVALID_ORDER_ITEM', 'بند الطلب غير صالح', false);
      }
      const id = String(item.item_id || '').trim();
      const previous = existingOffers.get(id);
      if (previous) {
        if (offerIds.has(id)) _offerError_('OFFER_REQUOTE_REQUIRED', 'تكرار بند العرض يتطلب إعادة اقتباس');
        offerIds.add(id);
        _validateUnchangedOfferItem_(item, previous, false);
      } else if (item.offer_id || item.offer_revision || item.offer_price) {
        _offerError_('OFFER_REQUOTE_REQUIRED', 'إضافة عرض تتطلب إعادة اقتباس');
      }
    });
    if (offerIds.size !== existingOffers.size) {
      _offerError_('OFFER_REQUOTE_REQUIRED', 'حذف بند العرض يتطلب إعادة اقتباس');
    }

    const products = _all('Products');
    const productsByCode = new Map(
      products.map(product => [String(product.code).trim(), product])
    );
    const submittedIds = new Set();
    const codes = new Set();
    const normalizedItems = submittedItems.map(item => {
      const code = String(item.code || '').trim();
      const quantity = Number(item.quantity);
      const unit = String(item.unit || '').trim();
      const itemId = String(item.item_id || '').trim();
      if (!code || !Number.isFinite(quantity) || quantity <= 0 || !unit) {
        throw _apiError('INVALID_ORDER_ITEM', 'تحقق من رمز الصنف والكمية والوحدة', false);
      }
      if (codes.has(code)) {
        throw _apiError('DUPLICATE_ORDER_ITEM', 'لا يمكن تكرار الصنف نفسه في الطلب', false);
      }
      codes.add(code);

      let existing = null;
      if (itemId) {
        if (submittedIds.has(itemId) || !existingRows.has(itemId)) {
          throw _apiError('INVALID_ORDER_ITEM', 'أحد أصناف الطلب غير صالح', false);
        }
        submittedIds.add(itemId);
        existing = existingRows.get(itemId);
        if (String(existing.values[col('code')]).trim() !== code) {
          throw _apiError('INVALID_ORDER_ITEM', 'لا يمكن تغيير رمز الصنف الحالي', false);
        }
      }

      const previousOffer = existingOffers.get(itemId);
      if (previousOffer) {
        const approvedQuantity = previousOffer.quantity_approved !== '' && previousOffer.quantity_approved != null
          ? Number(previousOffer.quantity_approved) : Number(previousOffer.quantity_requested);
        const savedTotal = previousOffer.total_price !== '' && previousOffer.total_price != null
          ? Number(previousOffer.total_price) : 0;
        if (!Number.isFinite(approvedQuantity) || !Number.isFinite(savedTotal)) {
          _offerError_('OFFER_REQUOTE_REQUIRED', 'لقطة العرض غير صالحة');
        }
        return {
          itemId: itemId, existing: existing, previous: previousOffer, isOffer: true,
          code: code, quantity: quantity, approvedQuantity: approvedQuantity,
          unit: unit, status: String(previousOffer.status || '').trim().toLowerCase(),
          lineTotal: savedTotal, note: item.note === undefined ? null : String(item.note || '').trim()
        };
      }
      const product = productsByCode.get(code);
      if (!product) {
        throw _apiError('PRODUCT_NOT_FOUND', 'الصنف غير موجود: ' + code, false);
      }

      // Calculate unit factor based on selected unit
      let unitFactor = 1.0;
      if (unit === String(product.unit_2 || '').trim()) unitFactor = Number(product.factor_2) || 1.0;
      else if (unit === String(product.unit_3 || '').trim()) unitFactor = Number(product.factor_3) || 1.0;

      const allowedUnits = [
        product.unit_1, product.unit_2, product.unit_3,
        existing ? existing.values[col('unit')] : ''
      ].map(value => String(value || '').trim()).filter(Boolean);
      if (allowedUnits.length && !allowedUnits.includes(unit)) {
        throw _apiError('INVALID_UNIT', 'وحدة القياس غير صالحة للصنف ' + code, false);
      }

      const previous = existing
        ? Object.fromEntries(headers.map((header, index) => [header, existing.values[index]]))
        : {};
      let lineStatus = String(previous.status || '').trim().toLowerCase();
      if (customerCanEdit || !lineStatus) {
        lineStatus = ['approved', 'priced', 'customer_confirmed'].includes(status)
          ? 'available'
          : 'pending';
      }
      if (customerCanEdit) lineStatus = 'pending';

      let price = null;
      if (!customerCanEdit) {
        const candidate = item.price !== undefined && item.price !== null && item.price !== ''
          ? Number(item.price)
          : Number(previous.final_price || previous.display_price_snapshot || product.display_price || 0);
        if (!Number.isFinite(candidate) || candidate < 0) {
          throw _apiError('INVALID_PRICE', 'سعر الصنف غير صالح: ' + code, false);
        }
        price = candidate;
      }

      const snapshotPrice = Number(previous.display_price_snapshot ||
          product.display_price || 0);
      if (!Number.isFinite(snapshotPrice) || snapshotPrice < 0) {
        throw _apiError('INVALID_PRICE', 'سعر الصنف غير صالح: ' + code, false);
      }
      const approvedStage = ['priced', 'customer_confirmed', 'approved'].includes(status);
      const lineTotal = !customerCanEdit && approvedStage && lineStatus !== 'unavailable'
        ? _roundOrderAmount_(quantity * price)
        : 0;
      return {
        itemId: itemId,
        existing: existing,
        previous: previous,
        code: code,
        product: product,
        quantity: quantity,
        unit: unit,
        unitFactor: unitFactor,
        basePriceSnapshot: Number(product.display_price || 0),
        note: String(item.note || '').trim(),
        status: lineStatus,
        price: price,
        snapshotPrice: snapshotPrice,
        lineTotal: lineTotal
      };
    });

    const previousConsumption = {};
    if (status === 'approved') {
      existingRows.forEach(existing => {
        const values = existing.values;
        if (String(values[col('status')] || '').toLowerCase() === 'unavailable') return;
        const code = String(values[col('code')]).trim();
        const approved = col('quantity_approved') >= 0 ? values[col('quantity_approved')] : '';
        const quantity = Number(approved !== '' && approved != null ? approved : values[col('quantity_requested')] || 0);
        previousConsumption[code] = (previousConsumption[code] || 0) + quantity;
      });
    }

    const nextConsumption = {};
    if (status === 'approved') {
      normalizedItems.forEach(item => {
        if (item.status === 'unavailable') return;
        nextConsumption[item.code] = (nextConsumption[item.code] || 0) +
          (item.isOffer ? item.approvedQuantity : item.quantity);
      });

      const productsSheet = ss.getSheetByName('Products');
      const productData = productsSheet.getDataRange().getValues();
      const productHeaders = productData[0].map(header => String(header).trim());
      const productCodeCol = productHeaders.indexOf('code');
      const productQuantityCol = productHeaders.indexOf('quantity');
      if (productCodeCol < 0 || productQuantityCol < 0) {
        throw new Error('أعمدة مخزون المنتجات غير مهيأة');
      }
      const stockChanges = [];
      Object.keys(Object.assign({}, previousConsumption, nextConsumption)).forEach(code => {
        const delta = (previousConsumption[code] || 0) - (nextConsumption[code] || 0);
        if (Math.abs(delta) < 0.000001) return;
        const productRow = productData.findIndex((row, index) =>
          index > 0 && String(row[productCodeCol]).trim() === code
        );
        if (productRow < 0) throw new Error('المنتج غير موجود في المخزون: ' + code);
        const currentStock = Number(productData[productRow][productQuantityCol] || 0);
        if (currentStock + delta < 0) {
          throw _apiError('INSUFFICIENT_STOCK', 'المخزون غير كافٍ للصنف ' + code, false);
        }
        stockChanges.push({
          code: code,
          row: productRow + 1,
          newStock: currentStock + delta,
          delta: delta
        });
      });
      stockChanges.forEach(change => {
        productsSheet.getRange(change.row, productQuantityCol + 1).setValue(change.newStock);
        _add('Inventory_Movements', {
          movement_id: 'MV-' + Utilities.getUuid().substring(0, 8),
          code: change.code,
          type: change.delta > 0 ? 'correction' : 'sale',
          quantity: Math.abs(change.delta),
          note: 'تعديل أصناف الطلب المعتمد: ' + orderId,
          created_by: user.user_id,
          created_at: _now(),
          reference_id: orderId,
          posting_id: order.posting_id || '',
          is_correction: change.delta > 0 ? 'true' : 'false'
        });
      });
    }

    const fieldCol = name => col(name);
    const hasPricing = ['priced', 'customer_confirmed', 'approved'].includes(status);
    const setItemFields = (rowNumber, fields) => {
      Object.keys(fields).forEach(name => {
        const index = fieldCol(name);
        if (index >= 0) itemsSheet.getRange(rowNumber, index + 1).setValue(fields[name]);
      });
    };
    let subtotal = 0;
    normalizedItems.forEach(item => {
      if (item.isOffer) {
        if (item.note !== null) {
          const noteFields = {};
          noteFields[customerCanEdit ? 'customer_note' : 'accountant_note'] = item.note;
          setItemFields(item.existing.rowNumber, noteFields);
        }
        if (!customerCanEdit && hasPricing && item.status !== 'unavailable') subtotal += item.lineTotal;
        return;
      }
      const fields = {
        code: item.code,
        unit: item.unit,
        unit_factor: item.unitFactor,
        base_price_snapshot: item.basePriceSnapshot,
        unit_1: item.product.unit_1 || '',
        unit_2: item.product.unit_2 || '',
        factor_2: item.product.factor_2 || '',
        unit_3: item.product.unit_3 || '',
        factor_3: item.product.factor_3 || '',
        quantity_requested: item.quantity,
        status: item.status,
        display_price_snapshot: item.snapshotPrice
      };
      if (customerCanEdit) {
        fields.quantity_approved = '';
        fields.final_price = '';
        fields.total_price = '';
        fields.accountant_note = '';
        fields.customer_note = item.note;
      } else {
        if (['priced', 'customer_confirmed', 'approved'].includes(status)) {
          fields.quantity_approved = item.quantity;
          fields.final_price = item.price;
          fields.total_price = item.lineTotal;
          fields.accountant_note = item.note;
          subtotal += item.lineTotal;
        } else if (item.note) {
          fields.accountant_note = item.note;
        }
      }

      if (item.existing) {
        setItemFields(item.existing.rowNumber, fields);
      } else {
        _add('Order_Items', Object.assign({
          item_id: 'ITM-' + Utilities.getUuid(),
          order_id: orderId,
          order_number: order.order_number || '',
          code: item.code,
          unit: item.unit,
          unit_factor: item.unitFactor,
          base_price_snapshot: item.basePriceSnapshot,
          unit_1: item.product.unit_1 || '',
          unit_2: item.product.unit_2 || '',
          factor_2: item.product.factor_2 || '',
          unit_3: item.product.unit_3 || '',
          factor_3: item.product.factor_3 || '',
          quantity_requested: item.quantity,
          display_price_snapshot: item.snapshotPrice,
          currency: order.currency || 'USD',
          status: item.status,
          customer_note: customerCanEdit ? item.note : '',
          accountant_note: customerCanEdit ? '' : item.note,
          final_price: hasPricing ? item.price : '',
          quantity_approved: hasPricing ? item.quantity : '',
          total_price: item.lineTotal
        }, fields));
      }
    });

    const deletedRows = [];
    existingRows.forEach((existing, itemId) => {
      if (!submittedIds.has(itemId)) deletedRows.push(existing.rowNumber);
    });
    deletedRows.sort((a, b) => b - a).forEach(rowNumber => itemsSheet.deleteRow(rowNumber));

    const nextStatus = customerCanEdit ? 'customer_changed' : status;
    const orderUpdates = {
      note: String(body.note || '').trim(),
      status: nextStatus,
      updated_at: _now()
    };
    if (customerCanEdit) {
      orderUpdates.subtotal = 0;
      orderUpdates.total = 0;
      orderUpdates.discount = 0;
      orderUpdates.discount_type = 'none';
      orderUpdates.discount_input = '';
      orderUpdates.discount_reason = '';
      orderUpdates.accountant_notes = '';
      orderUpdates.priced_by = '';
      orderUpdates.priced_at = '';
    } else if (['priced', 'customer_confirmed', 'approved'].includes(status)) {
      subtotal = _roundOrderAmount_(subtotal);
      const previousDiscount = Number(order.discount || 0);
      const discountType = String(order.discount_type || (previousDiscount > 0 ? 'amount' : 'none'));
      const discountInput = String(order.discount_input || (previousDiscount > 0 ? previousDiscount : ''));
      const recalculatedDiscount = discountType === 'percent' && discountInput
        ? _parseOrderDiscount_(discountInput, subtotal)
        : _parseOrderDiscount_(discountType === 'none' ? '' : (discountInput || previousDiscount), subtotal);
      orderUpdates.subtotal = subtotal;
      orderUpdates.total = recalculatedDiscount.netTotal;
      orderUpdates.discount = recalculatedDiscount.amount;
      orderUpdates.discount_type = recalculatedDiscount.type;
      orderUpdates.discount_input = recalculatedDiscount.input;
      orderUpdates.discount_reason = order.discount_reason || '';
      if (Math.abs(previousDiscount - recalculatedDiscount.amount) >= 0.005) {
        _add('Audit_Log', {
          log_id: Utilities.getUuid(),
          user_id: user.user_id,
          action: 'ORDER_DISCOUNT_RECALCULATED',
          entity: 'Orders',
          entity_id: orderId,
          details: JSON.stringify({
            previous: { type: discountType, input: discountInput, amount: previousDiscount },
            new: {
              type: recalculatedDiscount.type,
              input: recalculatedDiscount.input,
              amount: recalculatedDiscount.amount
            },
            reason: 'إعادة احتساب حسم الفاتورة بعد تعديل أصناف الطلب صراحةً'
          }),
          created_at: _now()
        });
      }
    }
    _updateByField('Orders', 'order_id', orderId, orderUpdates);

    _add('Audit_Log', {
      log_id: Utilities.getUuid(),
      user_id: user.user_id,
      action: customerCanEdit ? 'CUSTOMER_EDIT_ORDER' : 'STAFF_EDIT_ORDER',
      entity: 'Orders',
      entity_id: orderId,
      details: customerCanEdit
        ? 'تعديل الزبون للطلب؛ أعيدت الطلبية إلى مراجعة المحاسب لإعادة التسعير'
        : 'تعديل أصناف الطلب مع الإبقاء على المرحلة: ' + status,
      created_at: _now()
    });
    if (customerCanEdit) {
      _sendNotificationToRoles(
        'admin,accountant',
        'تم تعديل الطلب',
        'قام العميل بتعديل الطلب #' + (order.order_number || orderId) + ' ويحتاج إلى مراجعة.',
        'order.customer_updated',
        orderId,
        { order_id: orderId, customer_id: order.customer_id }
      );
    }

    return { success: true, status: nextStatus };
  } finally {
    lock.releaseLock();
  }
}

function _handleUpdateCustomerOrder(body, user) {
  _needRole(user, ['customer']);
  const orderId = body.orderId || body.order_id;
  const items = body.items;
  if (!orderId || !Array.isArray(items)) throw new Error('بيانات غير صالحة');

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) throw _apiError('BUSY', 'النظام مشغول، يرجى المحاولة لاحقاً', true);
  try {
    const order = _all('Orders').find(o => String(o.order_id) === String(orderId));
    if (!order) throw _apiError('ORDER_NOT_FOUND', 'الطلب غير موجود', false);
    _requireOrderOwnership(user, order);
    if (!['pending', 'submitted', 'priced', 'customer_changed'].includes(String(order.status))) {
      throw _apiError('INVALID_STATE', 'لا يمكن تعديل الطلب في حالته الحالية', false);
    }
    const ss = _ss();
    const itemsSheet = ss.getSheetByName('Order_Items');
    const itemsData = itemsSheet.getDataRange().getValues();
    const headers = itemsData[0];
    const itemIdIdx = headers.indexOf('item_id');
    const qtyReqIdx = headers.indexOf('quantity_requested');
    const qtyAppIdx = headers.indexOf('quantity_approved');
    const codeIdx = headers.indexOf('code');

    let actions = [];
    items.forEach(upd => {
      const index = itemsData.findIndex((row, i) =>
        i > 0 &&
        String(row[itemIdIdx]) === String(upd.item_id) &&
        String(row[headers.indexOf('order_id')]) === String(orderId)
      );
      if (index < 1) {
        throw _apiError('ORDER_ITEM_NOT_FOUND', 'أحد بنود الطلب غير موجود', false);
      }
      if (!['update', 'delete'].includes(upd.action)) {
        throw _apiError('INVALID_ORDER_ITEM_ACTION', 'إجراء تعديل البند غير صالح', false);
      }
      const previous = Object.fromEntries(headers.map((header, j) => [String(header).trim(), itemsData[index][j]]));
      if (String(previous.offer_id || '').trim()) {
        _validateUnchangedOfferItem_(upd, previous, true);
      }
      actions.push({ row: index + 1, data: itemsData[index], update: upd });
    });

    const updates = actions.filter(a => a.update.action === 'update');
    updates.forEach(a => {
      const approved = Number(a.data[qtyAppIdx] || 0);
      const requested = Number(a.update.quantity);
      if (!Number.isFinite(requested) || requested <= 0) {
        throw _apiError('INVALID_QUANTITY', 'الكمية المطلوبة يجب أن تكون أكبر من صفر', false);
      }
      if (requested < approved) {
        throw new Error('غير مسموح بتخفيض الكمية المصادق عليها للصنف (' + a.data[codeIdx] + '). المعتمد: ' + approved);
      }
    });
    updates.forEach(a => {
      if (!String(a.data[headers.indexOf('offer_id')] || '').trim()) {
        itemsSheet.getRange(a.row, qtyReqIdx + 1).setValue(Number(a.update.quantity));
      }
    });

    const deletes = actions.filter(a => a.update.action === 'delete').sort((a, b) => b.row - a.row);
    deletes.forEach(a => {
      itemsSheet.deleteRow(a.row);
    });

    _updateStatusInternal(orderId, 'customer_changed');

    _add('Audit_Log', {
      log_id: Utilities.getUuid(),
      user_id: user.user_id,
      action: 'CUSTOMER_UPDATE_ORDER',
      entity: 'Orders',
      entity_id: orderId,
      details: 'الزبون قام بتعديل الطلبية. بنود محدثة: ' + updates.length + ', بنود محذوفة: ' + deletes.length,
      created_at: _now(),
    });

    _sendNotificationToRoles(
      'admin,accountant',
      'تم تعديل الطلب',
      'قام العميل بتعديل الطلب #' + (order.order_number || orderId) + ' ويحتاج إلى مراجعة.',
      'order.customer_updated',
      orderId,
      { order_id: orderId, customer_id: order.customer_id }
    );

    return { success: true };
  } finally {
    lock.releaseLock();
  }
}

function _handleConfirmWarehousePrep(body, user) {
  _needRole(user, ['admin', 'manager', 'warehouse']);
  const orderId = body.orderId || body.order_id;
  const itemsUpdates = body.items;
  if (!orderId || !Array.isArray(itemsUpdates)) throw new Error('بيانات غير صالحة');

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) throw new Error('النظام مشغول، يرجى المحاولة لاحقاً');
  try {
    const orders = _all('Orders');
    const order = orders.find(o => String(o.order_id) === String(orderId));
    if (!order) throw new Error('الطلب غير موجود');
    _requireOrderOwnership(user, order);
    if (String(order.status || '').trim().toLowerCase() !== 'preparing') {
      throw new Error('يجب بدء تجهيز الطلب قبل تأكيد التعبئة');
    }

    const ss = _ss();
    const itemsSheet = ss.getSheetByName('Order_Items');
    const itemsData = itemsSheet.getDataRange().getValues();
    const itemHeaders = itemsData[0].map(String);
    const itemIdIdx = itemHeaders.indexOf('item_id');
    const orderIdIdx = itemHeaders.indexOf('order_id');
    const approvedIdx = itemHeaders.indexOf('quantity_approved');
    const requestedIdx = itemHeaders.indexOf('quantity_requested');
    const preparedIdx = itemHeaders.indexOf('quantity_prepared');
    const priceIdx = itemHeaders.indexOf('final_price');
    const snapshotIdx = itemHeaders.indexOf('display_price_snapshot');
    const statusIdx = itemHeaders.indexOf('status');
    const codeIdx = itemHeaders.indexOf('code');
    const packageNumbersIdx = itemHeaders.indexOf('warehouse_package_numbers');
    const packageTypeIdx = itemHeaders.indexOf('warehouse_package_type');
    const customPackageTypeIdx = itemHeaders.indexOf('warehouse_custom_package_type');
    const warehouseNoteIdx = itemHeaders.indexOf('warehouse_note');
    const totalPriceIdx = itemHeaders.indexOf('total_price');
    const requiredItemColumns = [
      itemIdIdx, orderIdIdx, approvedIdx, requestedIdx, preparedIdx, priceIdx,
      snapshotIdx, statusIdx, codeIdx, packageNumbersIdx, packageTypeIdx,
      customPackageTypeIdx, warehouseNoteIdx, totalPriceIdx
    ];
    if (requiredItemColumns.some(index => index < 0)) {
      throw new Error('أعمدة التعبئة غير مهيأة. شغّل setupSystem أولاً');
    }

    const orderItems = _all('Order_Items').filter(
      item => String(item.order_id) === String(orderId)
    );
    if (!orderItems.length) throw new Error('لا توجد بنود لتجهيزها في هذه الفاتورة');
    if (itemsUpdates.length !== orderItems.length) {
      throw new Error('يجب إرسال بيانات التعبئة لجميع بنود الفاتورة');
    }

    const updatesById = {};
    itemsUpdates.forEach(update => {
      const itemId = String(update.item_id || '');
      if (!itemId || updatesById[itemId]) throw new Error('بيانات بند التعبئة غير صالحة');
      updatesById[itemId] = update;
    });

    const stockDeltaByCode = {};
    const packageNumbersSet = {};
    const packageTypeByNumber = {};
    const validatedUpdates = orderItems.map(item => {
      const itemId = String(item.item_id || '');
      const update = updatesById[itemId];
      if (!update) throw new Error('بيانات التعبئة مفقودة لأحد بنود الفاتورة');

      const preparedQuantity = Number(update.quantity_prepared);
      if (!Number.isFinite(preparedQuantity) || preparedQuantity < 0) {
        throw new Error('الكمية المجهزة يجب أن تكون رقماً غير سالب');
      }
      const packageNumbers = String(update.warehouse_package_numbers || '').trim();
      const packageType = String(update.warehouse_package_type || '').trim();
      const customPackageType = String(update.warehouse_custom_package_type || '').trim();
      if (preparedQuantity > 0 &&
          !/^\d+(?:-\d+)?(?:,\s*\d+(?:-\d+)?)*$/.test(packageNumbers)) {
        throw new Error('أدخل أرقام الطرود بهذا الشكل: 1 أو 1-2 أو 1,2');
      }
      if (preparedQuantity > 0 && !['carton', 'bag', 'other'].includes(packageType)) {
        throw new Error('اختر نوع الطرد لكل بند مجهز');
      }
      if (preparedQuantity > 0 &&
          packageType === 'other' && !customPackageType) {
        throw new Error('اكتب نوع الطرد عند اختيار أخرى');
      }
      if (preparedQuantity > 0) {
        packageNumbers.split(',').forEach(part => {
          const range = part.trim().split('-').map(Number);
          const first = range[0];
          const last = range.length > 1 ? range[1] : first;
          if (!Number.isSafeInteger(first) || !Number.isSafeInteger(last) ||
              first < 1 || last < first || last - first > 1000) {
            throw new Error('رقم الطرد أو النطاق غير صالح');
          }
          for (let packageNumber = first; packageNumber <= last; packageNumber++) {
            const key = String(packageNumber);
            const packageTypeKey = packageType === 'other'
              ? packageType + ':' + customPackageType
              : packageType;
            const existingType = packageTypeByNumber[key];
            if (existingType && existingType !== packageTypeKey) {
              throw new Error('يجب أن يكون نوع الطرد موحداً لكل رقم طرد');
            }
            packageTypeByNumber[key] = packageTypeKey;
            packageNumbersSet[key] = true;
          }
        });
      }

      const isUnavailable = String(item.status || '').toLowerCase() === 'unavailable';
      if (isUnavailable && preparedQuantity > 0) {
        throw new Error('لا يمكن تجهيز كمية لبند غير متوفر: ' + item.code);
      }
      const oldQuantityValue = item.quantity_approved;
      const oldQuantity = oldQuantityValue !== undefined && oldQuantityValue !== ''
        ? Number(oldQuantityValue)
        : Number(item.quantity_requested || 0);
      const delta = isUnavailable ? 0 : preparedQuantity - oldQuantity;
      const code = String(item.code || '');
      if (delta !== 0) {
        stockDeltaByCode[code] = (stockDeltaByCode[code] || 0) + delta;
      }
      return {
        item: item,
        update: update,
        preparedQuantity: isUnavailable ? 0 : preparedQuantity,
        packageNumbers: packageNumbers,
        packageType: packageType,
        customPackageType: customPackageType,
        rowIndex: itemsData.findIndex((row, index) =>
          index > 0 && String(row[itemIdIdx]) === itemId &&
          String(row[orderIdIdx]) === String(orderId)
        )
      };
    });

    if (Object.keys(updatesById).length !== orderItems.length) {
      throw new Error('تحتوي بيانات التعبئة على بنود لا تتبع هذه الفاتورة');
    }
    if (validatedUpdates.some(update => update.rowIndex < 1)) {
      throw new Error('تعذر العثور على أحد بنود الفاتورة في التخزين');
    }

    const productsSheet = ss.getSheetByName('Products');
    const productData = productsSheet.getDataRange().getValues();
    const productHeaders = productData[0].map(String);
    const productCodeIdx = productHeaders.indexOf('code');
    const productQuantityIdx = productHeaders.indexOf('quantity');
    if (productCodeIdx < 0 || productQuantityIdx < 0) {
      throw new Error('تعذر تحديث المخزون: أعمدة المنتج غير موجودة');
    }
    const stockChanges = Object.keys(stockDeltaByCode).map(code => {
      const rowIndex = productData.findIndex((row, index) =>
        index > 0 && String(row[productCodeIdx]) === code
      );
      if (rowIndex < 0) throw new Error('الصنف غير موجود في المخزون: ' + code);
      const delta = stockDeltaByCode[code];
      const currentQuantity = Number(productData[rowIndex][productQuantityIdx] || 0);
      if (delta > currentQuantity) {
        throw new Error('المخزون غير كافٍ للكمية الإضافية للصنف: ' + code);
      }
      return { code: code, rowIndex: rowIndex, delta: delta };
    });

    let orderSubtotal = 0;
    validatedUpdates.forEach(update => {
      const row = update.rowIndex;
      const item = update.item;
      const quantity = update.preparedQuantity;
      const price = Number(item.final_price || item.display_price_snapshot || 0);
      const lineTotal = String(item.status || '').toLowerCase() === 'unavailable'
        ? 0
        : price * quantity;
      orderSubtotal += lineTotal;
      itemsSheet.getRange(row + 1, preparedIdx + 1).setValue(quantity);
      itemsSheet.getRange(row + 1, approvedIdx + 1).setValue(quantity);
      itemsSheet.getRange(row + 1, packageNumbersIdx + 1).setValue(update.packageNumbers);
      itemsSheet.getRange(row + 1, packageTypeIdx + 1).setValue(update.packageType);
      itemsSheet.getRange(row + 1, customPackageTypeIdx + 1).setValue(update.customPackageType);
      itemsSheet.getRange(row + 1, warehouseNoteIdx + 1)
        .setValue(String(update.update.warehouse_note || '').trim());
      itemsSheet.getRange(row + 1, totalPriceIdx + 1).setValue(lineTotal);
    });

    stockChanges.forEach(change => {
      const currentQuantity = Number(productData[change.rowIndex][productQuantityIdx] || 0);
      productsSheet.getRange(change.rowIndex + 1, productQuantityIdx + 1)
        .setValue(currentQuantity - change.delta);
      _add('Inventory_Movements', {
        movement_id: (change.delta > 0 ? 'MV-' : 'REV-') + Utilities.getUuid().substring(0, 8),
        code: change.code,
        type: change.delta > 0 ? 'sale' : 'correction',
        quantity: Math.abs(change.delta),
        note: 'تعديل كمية التجهيز للطلب: ' + orderId,
        created_by: user.user_id,
        created_at: _now(),
        reference_id: orderId,
        posting_id: order.posting_id || '',
        is_correction: change.delta > 0 ? 'false' : 'true'
      });
    });

    const packageTypeCounts = {};
    Object.keys(packageTypeByNumber).forEach(packageNumber => {
      const typeKey = packageTypeByNumber[packageNumber];
      packageTypeCounts[typeKey] = (packageTypeCounts[typeKey] || 0) + 1;
    });
    const packageTypes = Object.keys(packageTypeCounts).map(typeKey => {
      if (typeKey === 'carton') {
        return { type: 'carton', label: 'كرتونة', count: packageTypeCounts[typeKey] };
      }
      if (typeKey === 'bag') {
        return { type: 'bag', label: 'كيس', count: packageTypeCounts[typeKey] };
      }
      return {
        type: 'custom',
        label: typeKey.substring('other:'.length),
        count: packageTypeCounts[typeKey]
      };
    });
    const packageSummary = _shipmentPackageSummary_({
      package_count: Object.keys(packageNumbersSet).length,
      package_types: packageTypes
    });
    _add('Shipments', {
      shipment_id: 'SHP-' + Utilities.getUuid().substring(0, 8).toUpperCase(),
      order_id: orderId,
      package_count: Object.keys(packageNumbersSet).length,
      carton_count: packageTypeCounts.carton || 0,
      bag_count: packageTypeCounts.bag || 0,
      package_types_json: JSON.stringify(packageTypes),
      status: 'prepared',
      shipping_date: _now(),
      warehouse_note: String(body.warehouse_note || '').trim(),
      note: String(body.warehouse_note || '').trim()
    });

    _updateByField('Orders', 'order_id', orderId, {
      status: 'prepared',
      subtotal: orderSubtotal,
      total: orderSubtotal,
      updated_at: _now()
    });
    const readyOrder = _all('Orders').find(o => String(o.order_id) === String(orderId));
    const preparedBody = 'تم تجهيز الطلب #' + (readyOrder ? (readyOrder.order_number || orderId) : orderId) +
      '؛ ' + packageSummary + '.';
    const preparedMetadata = {
      event_type: 'warehouse.prepared',
      order_id: orderId,
      customer_id: order.customer_id
    };
    _sendNotificationToRoles(
      'accountant,admin',
      'تم تجهيز الطلب',
      preparedBody,
      'warehouse.prepared',
      orderId,
      preparedMetadata
    );
    const preparedCustomer = _all('Users').find(u => u.customer_id === order.customer_id);
    if (preparedCustomer) {
      _sendNotification(preparedCustomer.user_id, 'تم تجهيز طلبك', preparedBody, preparedMetadata);
    }
    _add('Audit_Log', {
      log_id: Utilities.getUuid(),
      user_id: user.user_id,
      action: 'CONFIRM_WAREHOUSE_PREP',
      entity: 'Orders',
      entity_id: orderId,
      details: 'تم اعتماد التعبئة واكتمال تجهيز الفاتورة.',
      created_at: _now()
    });

    return { success: true, status: 'prepared' };
  } finally {
    lock.releaseLock();
  }
}

function _updateStatusInternal(orderId, newStatus) {
  const ss = _ss();
  const sheet = ss.getSheetByName('Orders');
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const idIdx = headers.indexOf('order_id');
  const statusIdx = headers.indexOf('status');

  for (let i = 1; i < data.length; i++) {
    if (data[i][idIdx] === orderId) {
      sheet.getRange(i + 1, statusIdx + 1).setValue(newStatus);
      sheet.getRange(i + 1, headers.indexOf('updated_at') + 1).setValue(_now());
      break;
    }
  }
}

function _reserveStock(orderId, userId) {
  const items = _all('Order_Items').filter(i => i.order_id === orderId);
  items.forEach(item => {
    const qty = Number(item.quantity_approved || 0);
    if (qty > 0) {
      const success = _updateProductQuantity(item.code, -qty);
      if (success) {
        _add('Inventory_Movements', {
          movement_id: Utilities.getUuid(),
          code: item.code,
          type: 'adjustment',
          quantity: qty,
          note: 'حجز للطلب ' + orderId,
          created_by: userId,
          created_at: _now(),
        });
      }
    }
  });
}

// ============================================================
// 9. العملاء (Customers)
// ============================================================
function _handleGetCustomers(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  // preserve inactive records for audit/history; hide only deleted records
  let customers = _all('Customers').filter(c =>
    String(c.status || '').toLowerCase() !== 'deleted'
  );
  const paginated = body.limit !== undefined;
  let nextOffset = null;
  if (paginated) {
    const limit = Number(body.limit);
    const offset = Number(body.offset || 0);
    if (!Number.isInteger(limit) || limit < 1 || limit > 100 ||
        !Number.isInteger(offset) || offset < 0) {
      throw _apiError('INVALID_PAGINATION', 'معلمات صفحات العملاء غير صالحة', false);
    }
    const query = String(body.query || '').trim().toLowerCase();
    const status = String(body.status || 'all').trim().toLowerCase();
    if (!['all', 'active', 'inactive'].includes(status)) {
      throw _apiError('INVALID_STATUS', 'حالة العميل غير صالحة', false);
    }
    customers = customers.filter(c => {
      const customerStatus = String(c.status || 'active').toLowerCase();
      return (status === 'all' || status === customerStatus) &&
        (!query || [c.full_name, c.company_name, c.phone].join(' ').toLowerCase().includes(query));
    }).sort((a, b) => String(a.customer_id).localeCompare(String(b.customer_id)));
    nextOffset = offset + limit < customers.length ? offset + limit : null;
    customers = customers.slice(offset, offset + limit);
  }
  const payments = _all('Payments');
  const orders = _all('Orders');
  const orderItems = _all('Order_Items');
  const salesInvoices = _all('Sales_Invoices');
  const customerTypes = new Map();
  _all('Users').forEach(account => {
    if (_normalizeRole(account.role) !== 'customer') return;
    const id = String(account.customer_id || '');
    const type = String(account.customer_type || '').trim();
    if (!id || !type) return;
    if (!customerTypes.has(id)) customerTypes.set(id, new Set());
    customerTypes.get(id).add(type);
  });

  return {
    ...(paginated ? { next_offset: nextOffset } : {}),
    customers: customers.map(c => {
      const customerPayments = payments.filter(p =>
        String(p.customer_id) === String(c.customer_id)
      );
      let totalPaid = 0;
      let needsFinancialReview = Number(c.opening_syp || 0) !== 0;
      customerPayments.forEach(payment => {
        const equivalent = _paymentEquivalentUsd_(payment);
        if (equivalent === null) {
          needsFinancialReview = true;
          return;
        }
        totalPaid += String(payment.action_type || 'receive') === 'pay'
          ? -equivalent : equivalent;
      });

      const customerOrders = orders.filter(o =>
        o.customer_id === c.customer_id &&
        ['approved', 'prepared', 'shipping', 'delivered'].includes(o.status)
      );

      let totalOrdersValue = 0;
      customerOrders.forEach(o => {
        const items = orderItems.filter(oi => oi.order_id === o.order_id);
        const currency = String(o.currency || 'USD').toUpperCase();
        const rate = Number(o.exchange_rate || o.rate_syp_per_usd || 0);
        let orderValue = 0;
        items.forEach(item => {
          const price = item.final_price === '' || item.final_price == null
            ? item.display_price_snapshot : item.final_price;
          const quantity = item.quantity_approved === '' || item.quantity_approved == null
            ? item.quantity_requested : item.quantity_approved;
          orderValue += Number(price || 0) * Number(quantity || 0);
        });
        const savedTotal = Number(o.total);
        if (o.total !== '' && o.total != null && Number.isFinite(savedTotal)) {
          orderValue = savedTotal;
        } else {
          orderValue = _roundOrderAmount_(orderValue - Number(o.discount || 0));
        }
        if (currency === 'USD') totalOrdersValue += orderValue;
        else if (currency === 'SYP' && rate > 0) totalOrdersValue += orderValue / rate;
        else needsFinancialReview = true;
      });
      let salesInvoiceValue = 0;
      salesInvoices.filter(invoice =>
        String(invoice.customer_id) === String(c.customer_id) &&
        String(invoice.status) === 'posted'
      ).forEach(invoice => {
        if (String(invoice.currency || 'USD').toUpperCase() === 'USD') {
          salesInvoiceValue += Number(invoice.net_total || 0);
        } else {
          needsFinancialReview = true;
        }
      });

      return {
        customer_id: c.customer_id,
        full_name: c.full_name,
        company_name: c.company_name,
        phone: c.phone,
        address: c.address,
        province: c.province,
        notes: c.notes,
        opening_usd: c.opening_usd,
        opening_syp: c.opening_syp,
        status: c.status,
        login_customer_types: Array.from(customerTypes.get(String(c.customer_id)) || []),
        balance: Number((
          totalOrdersValue + salesInvoiceValue - totalPaid +
          Number(c.opening_usd || 0)
        ).toFixed(2)),
        needs_financial_review: needsFinancialReview,
      };
    })
  };
}

function _handleSalesCustomerList(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'salesperson']);
  const query = String(body.query || '').trim().toLowerCase();
  return {
    customers: _all('Customers')
      .filter(customer =>
        !['deleted', 'inactive'].includes(String(customer.status || '').toLowerCase()) &&
        String(customer.customer_id || '') !== 'CUS-SHOP' &&
        (!query || [
          customer.customer_id,
          customer.full_name,
          customer.company_name,
          customer.phone,
        ].join(' ').toLowerCase().includes(query))
      )
      .map(customer => ({
        customer_id: String(customer.customer_id),
        full_name: String(customer.full_name || ''),
        company_name: String(customer.company_name || ''),
        phone: String(customer.phone || ''),
      })),
  };
}

function _handleCreateSalesCustomer(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'salesperson']);
  const fullName = String(body.full_name || '').trim();
  const phone = String(body.phone || '').trim();
  if (fullName.length < 2 || fullName.length > 120 || phone.length > 32) {
    throw _apiError('INVALID_CUSTOMER', 'اسم الزبون مطلوب ورقم الهاتف غير صالح', false);
  }
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) {
    throw _apiError('BUSY', 'إدارة الزبائن مشغولة، حاول مجددًا', true);
  }
  try {
    const requestId = String(body.client_request_id || '').trim();
    if (requestId.length >= 12) {
      const prior = _all('Customers').find(row =>
        String(row.creation_request_id || '') === requestId
      );
      if (prior) return { success: true, customer: prior, duplicate: true };
    }
    const customerId = 'CUS-' + Utilities.getUuid().replace(/-/g, '').slice(0, 12).toUpperCase();
    const customer = {
      customer_id: customerId,
      full_name: fullName,
      company_name: String(body.company_name || '').trim(),
      phone: phone,
      address: '',
      province: '',
      notes: String(body.notes || '').trim(),
      opening_usd: 0,
      opening_syp: '',
      status: 'active',
      created_at: _now(),
      is_system_record: false,
      creation_request_id: requestId,
    };
    _add('Customers', customer);
    _add('Audit_Log', {
      log_id: Utilities.getUuid(),
      user_id: user.user_id,
      action: 'CREATE_SALES_CUSTOMER_RECORD',
      entity: 'Customers',
      entity_id: customerId,
      details: JSON.stringify({
        full_name: fullName,
        phone: phone,
        role: _normalizeRole(user.role),
      }),
      created_at: _now(),
    });
    return { success: true, customer: customer };
  } finally {
    lock.releaseLock();
  }
}

function _handleCreateCustomer(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) throw _apiError('BUSY', 'إدارة الحسابات مشغولة، حاول مجددًا', true);
  let customerId = '';
  let customerAdded = false;
  let userId = '';
  let userAdded = false;
  try {
    const username = _assertUniqueUsername_(body.username);
    const fullName = String(body.full_name || '').trim();
    const customerType = String(body.customer_type || '').trim();
    if (!fullName) throw _apiError('INVALID_USER', 'اسم الزبون مطلوب', false);
    if (!_CUSTOMER_TYPES_.includes(customerType)) {
      throw _apiError('CUSTOMER_TYPE_REQUIRED', 'نوع الزبون مطلوب', false);
    }
    customerId = 'CUS-' + Utilities.getUuid().replace(/-/g, '').slice(0, 12).toUpperCase();
    userId = 'USR-' + Utilities.getUuid().replace(/-/g, '').slice(0, 16).toUpperCase();
    const salt = Utilities.getUuid();
    const now = _now();
    _add('Customers', {
      customer_id: customerId,
      full_name: fullName,
      company_name: body.company_name || '',
      phone: body.phone || '',
      address: body.address || '',
      province: body.province || '',
      notes: body.notes || '',
      opening_usd: Number(body.opening_usd || 0),
      opening_syp: Number(body.opening_syp || 0),
      status: 'active',
      is_system_record: false,
      created_at: now
    });
    customerAdded = true;
    const newUser = {
      user_id: userId,
      username: username,
      password_hash: _passwordHash_('654321', salt),
      salt: salt,
      full_name: fullName,
      phone: body.phone || '',
      role: 'customer',
      customer_id: customerId,
      status: 'active',
      must_change_password: true,
      created_at: now,
      city: body.province || '',
      address: body.address || '',
      email: body.email || '',
      customer_type: customerType,
      internal_notes: '',
      updated_at: now,
      updated_by: user.user_id,
    };
    _add('Users', newUser);
    userAdded = true;
    _managedUserAudit_(user, 'CREATE_USER', userId, null, _managedUserSnapshot_(newUser), 'إنشاء حساب زبون');
    return {
      success: true,
      customer_id: customerId,
      message: 'تم إنشاء حساب الزبون. كلمة المرور المؤقتة 654321',
    };
  } catch (error) {
    if (userAdded) _deleteRowsByField_('Users', 'user_id', userId);
    if (customerAdded) _deleteRowsByField_('Customers', 'customer_id', customerId);
    throw error;
  } finally {
    lock.releaseLock();
  }
}

function _handleUpdateCustomer(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const customerId = body.customer_id;
  if (!customerId) throw new Error('معرف العميل مطلوب');

  const customers = _all('Customers');
  const customer = customers.find(c => String(c.customer_id) === String(customerId));
  if (!customer) throw new Error('العميل غير موجود');
  if (String(customer.customer_id) === 'CUS-SHOP' ||
      _isTrue_(customer.is_system_record)) {
    throw _apiError('SYSTEM_CUSTOMER_READ_ONLY', 'سجل زبائن محل داخلي ولا يمكن تعديله', false);
  }

  const updates = {};
  if (body.full_name !== undefined) updates.full_name = body.full_name;
  if (body.company_name !== undefined) updates.company_name = body.company_name;
  if (body.phone !== undefined) updates.phone = body.phone;
  if (body.address !== undefined) updates.address = body.address;
  if (body.province !== undefined) updates.province = body.province;
  if (body.notes !== undefined) updates.notes = body.notes;
  if (body.opening_usd !== undefined) updates.opening_usd = body.opening_usd;
  if (body.opening_syp !== undefined) updates.opening_syp = body.opening_syp;
  if (body.status !== undefined) updates.status = body.status;

  const updated = _updateByField('Customers', 'customer_id', customerId, updates);
  
  if (!updated) throw new Error('فشل تحديث بيانات العميل');

  // تحديث اسم المستخدم إذا تم تقديمه
  if (body.username) {
    const username = String(body.username).toLowerCase();
    const users = _all('Users');
    const existingUser = users.find(u => String(u.customer_id) === String(customerId));
    
    if (existingUser) {
      const userUpdates = {
        username: username,
        full_name: body.full_name || existingUser.full_name,
        phone: body.phone || existingUser.phone
      };
      _updateByField('Users', 'user_id', existingUser.user_id, userUpdates);
    }
  }

  return { success: true, message: 'تم تحديث بيانات العميل بنجاح' };
}

// ============================================================
// 10. الدفعات والصناديق (Payments & Boxes)
// ============================================================
function _handleGetPayments(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  let payments = _all('Payments');
  if (body.customer_id) {
    payments = payments.filter(p => p.customer_id === body.customer_id);
  }
  if (body.box_type) {
    payments = payments.filter(p => p.box_type === body.box_type);
  }
  if (body.currency) {
    payments = payments.filter(p => p.currency === body.currency);
  }

  const customers = _all('Customers');
  payments = payments.map(p => {
    const customer = customers.find(c => c.customer_id === p.customer_id);
    return {
      ...p,
      customer_name: customer ? customer.full_name : 'غير معروف',
    };
  });

  payments.sort((a, b) => {
    const dateA = new Date(a.created_at || a.payment_date || 0);
    const dateB = new Date(b.created_at || b.payment_date || 0);
    return dateB - dateA;
  });

  return { payments: payments };
}

function _handleAddPayment(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const amount = Number(body.amount || 0);
  if (!body.customer_id || amount <= 0) throw new Error('بيانات الدفعة غير صالحة');

  const paymentId = Utilities.getUuid();
  _add('Payments', {
    payment_id: paymentId,
    customer_id: body.customer_id,
    order_id: body.order_id || '',
    amount: amount,
    currency: body.currency || 'USD',
    box_type: body.box_type || 'cash_box',
    method: body.method || 'cash',
    payment_date: body.payment_date || _now(),
    note: body.note || '',
    created_by: user.user_id,
    created_at: _now(),
    action_type: 'receive',
  });

  _updateBoxBalance(body.box_type || 'cash_box', body.currency || 'USD', amount, 'receive');

  const customerUser = _all('Users').find(u => u.customer_id === body.customer_id);
  if (customerUser) {
    _sendNotification(customerUser.user_id, 'تم تسجيل دفعة', 'تم تسجيل دفعة جديدة على حسابكم.', {
      event_type: 'payment.recorded',
      event_id: 'payment.recorded:' + paymentId,
      customer_id: body.customer_id,
      invoice_id: body.order_id || ''
    });
  }

  return { success: true, payment_id: paymentId };
}

function _handleRecordPayment(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const amount = Number(body.amount || 0);
  if (amount <= 0) throw new Error('المبلغ يجب أن يكون أكبر من صفر');

  const actionType = body.action_type || 'receive';
  const boxType = body.box_type || 'cash_box';
  const currency = body.currency || 'USD';
  const customerId = body.customer_id;
  const note = body.note || '';

  if (actionType === 'receive' && !customerId) {
    throw new Error('يجب اختيار الزبون للاستلام');
  }
  if (actionType === 'pay' && !note) {
    throw new Error('يجب كتابة ملاحظة/سبب للصرف');
  }

  if (actionType === 'pay') {
    const boxesBalance = _all('Boxes_Balance');
    const box = boxesBalance.find(b => b.box_name === boxType && b.currency === currency);
    const currentBalance = box ? Number(box.balance || 0) : 0;
    if (currentBalance < amount) {
      throw new Error('الرصيد في الصندوق غير كافي');
    }
  }

  const year = new Date().getFullYear();
  const existing = _all('Payments').filter(p => String(p.payment_id).includes('PAY-' + year));
  const seq = existing.length + 1;
  const paymentId = 'PAY-' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd') + '-' + String(seq).padStart(6, '0');
  const now = _now();

  _add('Payments', {
    payment_id: paymentId,
    customer_id: customerId || '',
    order_id: body.order_id || '',
    amount: amount,
    currency: currency,
    box_type: boxType,
    method: body.method || 'cash',
    payment_date: body.payment_date || now,
    note: note,
    created_by: user.user_id,
    created_at: now,
    action_type: actionType,
  });

  _updateBoxBalance(boxType, currency, amount, actionType === 'receive' ? 'receive' : 'pay');

  if (actionType === 'receive') {
    _sendNotificationToRoles(
      'admin,manager,accountant',
      'تم تسجيل دفعة',
      'تم تسجيل دفعة جديدة للعميل.',
      'payment.recorded',
      paymentId,
      { invoice_id: body.order_id || '', customer_id: customerId }
    );
    const customerUser = _all('Users').find(u => u.customer_id === customerId);
    if (customerUser) {
      _sendNotification(customerUser.user_id, 'تم تسجيل دفعة', 'تم تسجيل دفعة جديدة على حسابكم.', {
        event_type: 'payment.recorded',
        event_id: 'payment.recorded:' + paymentId,
        customer_id: customerId,
        invoice_id: body.order_id || ''
      });
    }
  } else {
    _sendNotificationToRoles(
      'admin,manager',
      'تم تسجيل حركة مالية',
      'تم تسجيل حركة جديدة في الصندوق.',
      'payment.updated',
      paymentId
    );
  }

  return { success: true, payment_id: paymentId };
}

function _handleUpdatePayment(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  throw _apiError(
    'PAYMENTS_IMMUTABLE',
    'الحركات المالية لا تعدل أو تحذف؛ استخدم إجراء العكس الموثق ثم سجل الحركة الصحيحة.',
    false
  );
}

function _handleDeletePayment(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  throw _apiError(
    'PAYMENTS_IMMUTABLE',
    'الحركات المالية لا تحذف؛ استخدم إجراء العكس الموثق للمحافظة على سجل التدقيق.',
    false
  );
}

function _handleReversePayment(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const paymentId = body.payment_id;
  const reason = String(body.reason || '').trim();
  const requestId = String(body.client_request_id || '').trim();
  if (!paymentId || reason.length < 3 || requestId.length < 12) {
    throw _apiError(
      'INVALID_PAYMENT_REVERSAL',
      'رقم الحركة وسبب العكس ومعرف العملية مطلوبة',
      false
    );
  }
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) {
    throw _apiError('BUSY', 'جارٍ ترحيل عملية أخرى، حاول مجددًا', true);
  }
  let boxSnapshot = null;
  let boxTouched = false;
  let reversalAdded = false;
  let original = null;
  try {
    const duplicate = _all('Payments').find(payment =>
      String(payment.client_request_id || '') === requestId
    );
    if (duplicate) {
      return {
        success: true,
        payment_id: duplicate.payment_id,
        duplicate: true,
      };
    }
    original = _all('Payments').find(payment =>
      String(payment.payment_id) === String(paymentId)
    );
    if (!original) {
      throw _apiError('PAYMENT_NOT_FOUND', 'الحركة المالية غير موجودة', false);
    }
    if (String(original.reversal_of || '').trim()) {
      throw _apiError('PAYMENT_ALREADY_REVERSED', 'لا يمكن عكس حركة عكسية', false);
    }
    if (_all('Payments').some(payment =>
      String(payment.reversal_of || '') === String(paymentId)
    )) {
      throw _apiError('PAYMENT_ALREADY_REVERSED', 'سبق عكس هذه الحركة', false);
    }
    const amount = Number(original.amount);
    const currency = String(original.currency || '').toUpperCase();
    const oldAction = String(original.action_type || 'receive');
    if (!Number.isFinite(amount) || amount <= 0 ||
        !['USD', 'SYP'].includes(currency) ||
        !['receive', 'pay'].includes(oldAction) ||
        !String(original.box_type || '').trim()) {
      throw _apiError('INVALID_PAYMENT', 'بيانات الحركة الأصلية غير صالحة للعكس', false);
    }
    const equivalent = _paymentEquivalentUsd_(original);
    if (currency === 'SYP' && equivalent === null) {
      throw _apiError(
        'PAYMENT_REQUIRES_MANUAL_REVIEW',
        'الحركة السورية القديمة بلا سعر صرف تاريخي؛ لا يمكن ربطها برصيد دولار. راجعها يدويًا قبل العكس.',
        false
      );
    }
    _requireColumns_('Payments', ['reversal_of', 'invoice_equivalent']);
    boxSnapshot = _cashBoxSnapshot_(original.box_type, currency);
    const reverseAction = oldAction === 'receive' ? 'pay' : 'receive';
    const reversal = {
      payment_id: 'PR-' + Utilities.getUuid().replace(/-/g, '').toUpperCase(),
      customer_id: original.customer_id || '',
      order_id: original.order_id || '',
      receipt_id: original.receipt_id || '',
      amount: amount,
      currency: currency,
      box_type: original.box_type,
      method: 'payment_reversal',
      payment_method: 'payment_reversal',
      payment_date: _now(),
      note: reason,
      created_by: user.user_id,
      created_at: _now(),
      action_type: reverseAction,
      invoice_currency: 'USD',
      invoice_equivalent: equivalent,
      exchange_rate: original.exchange_rate || '',
      reference: original.reference || '',
      client_request_id: requestId,
      reversal_of: paymentId,
    };
    _add('Payments', reversal);
    reversalAdded = true;
    boxTouched = true;
    _updateBoxBalance(
      original.box_type,
      currency,
      amount,
      reverseAction
    );
    const auditId = Utilities.getUuid();
    _add('Audit_Log', {
      log_id: auditId,
      user_id: user.user_id,
      action: 'REVERSE_PAYMENT',
      entity: 'Payments',
      entity_id: paymentId,
      details: JSON.stringify({
        reversal_payment_id: reversal.payment_id,
        reason: reason,
        before: original,
        after: reversal,
      }),
      created_at: reversal.created_at,
    });
    return {
      success: true,
      payment_id: reversal.payment_id,
      reversal_of: paymentId,
    };
  } catch (error) {
    const rollbackErrors = [];
    if (boxTouched && boxSnapshot) {
      try {
        _restoreBoxBalance_(
          original ? original.box_type : '',
          original ? original.currency : '',
          boxSnapshot
        );
      } catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (reversalAdded) {
      try {
        const reversal = _all('Payments').find(row =>
          String(row.client_request_id || '') === requestId
        );
        if (reversal) {
          _deleteRowsByField_('Payments', 'payment_id', reversal.payment_id);
        }
      } catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (rollbackErrors.length) {
      Logger.log('Payment reversal rollback failed: ' + rollbackErrors.join('; '));
      throw _apiError('PAYMENT_REVERSAL_ROLLBACK_FAILED', 'تعذر التراجع عن عكس الحركة المالية؛ راجع سجل النظام', false);
    }
    throw error;
  } finally {
    lock.releaseLock();
  }
}

function _handleGetBoxBalances(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const boxesBalance = _all('Boxes_Balance');
  const getBalance = (name, currency) => {
    const matches = boxesBalance.filter(box =>
      String(box.box_name) === name && String(box.currency).toUpperCase() === currency
    );
    if (matches.length > 1) {
      throw _apiError(
        'DUPLICATE_CASH_BOX',
        'يوجد أكثر من سجل للصندوق ' + name + ' بعملة ' + currency +
          '. يلزم توحيد السجلات يدويًا قبل استخدامه.',
        false
      );
    }
    return Number(matches.length ? matches[0].balance || 0 : 0);
  };

  return {
    balances: {
      cash_box_syp: getBalance('cash_box', 'SYP'),
      cash_box_usd: getBalance('cash_box', 'USD'),
      sham_cash_syp: getBalance('sham_cash', 'SYP'),
      sham_cash_usd: getBalance('sham_cash', 'USD'),
    }
  };
}

function _updateBoxBalance(boxType, currency, amount, actionType) {
  const boxesBalance = _all('Boxes_Balance');
  const normalizedCurrency = String(currency || '').toUpperCase();
  const matches = boxesBalance.filter(b =>
    String(b.box_name) === String(boxType) &&
    String(b.currency).toUpperCase() === normalizedCurrency
  );
  if (matches.length > 1) {
    throw _apiError(
      'DUPLICATE_CASH_BOX',
      'يوجد أكثر من سجل للصندوق ' + boxType + ' بعملة ' + normalizedCurrency +
        '. يلزم توحيد السجلات يدويًا قبل الترحيل.',
      false
    );
  }
  if (!Number.isFinite(Number(amount)) || Number(amount) <= 0 ||
      !['receive', 'pay'].includes(actionType) ||
      !['USD', 'SYP'].includes(normalizedCurrency)) {
    throw _apiError('INVALID_CASH_MOVEMENT', 'حركة الصندوق غير صالحة', false);
  }
  let box = matches.length ? matches[0] : null;
  const sheet = _ss().getSheetByName('Boxes_Balance');

  if (!box) {
    const boxId = 'box_' + boxType + '_' + currency.toLowerCase();
    _add('Boxes_Balance', {
      box_id: boxId,
      box_name: boxType,
      currency: normalizedCurrency,
      balance: 0,
      last_updated: _now(),
    });
    box = { box_id: boxId, box_name: boxType, currency: normalizedCurrency, balance: 0 };
  }

  const boxesBalanceUpdated = _all('Boxes_Balance');
  const boxIndex = boxesBalanceUpdated.findIndex(b => b.box_id === box.box_id);
  if (boxIndex === -1) return;

  const headers = _getHeaders('Boxes_Balance');
  const balanceCol = headers.indexOf('balance') + 1;
  const lastUpdatedCol = headers.indexOf('last_updated') + 1;
  if (balanceCol < 1 || lastUpdatedCol < 1) {
    throw new Error('أعمدة رصيد الصندوق غير مهيأة؛ شغّل setupSystem أولاً');
  }
  const rowIndex = boxIndex + 2;
  const currentBalance = Number(boxesBalanceUpdated[boxIndex].balance || 0);
  if (!Number.isFinite(currentBalance)) {
    throw _apiError('INVALID_CASH_BALANCE', 'رصيد الصندوق الحالي غير صالح', false);
  }
  if (actionType === 'pay' && currentBalance < Number(amount)) {
    throw _apiError(
      'INSUFFICIENT_CASH_BOX_BALANCE',
      'رصيد الصندوق ' + boxType + ' بعملة ' + normalizedCurrency + ' لا يكفي للصرف',
      false
    );
  }

  let newBalance;
  if (actionType === 'receive') {
    newBalance = currentBalance + amount;
  } else {
    newBalance = currentBalance - amount;
  }

  sheet.getRange(rowIndex, balanceCol).setValue(newBalance);
  sheet.getRange(rowIndex, lastUpdatedCol).setValue(_now());
}

function _restoreBoxBalance_(boxType, currency, snapshot) {
  const boxId = snapshot && snapshot.box_id ||
    ('box_' + boxType + '_' + currency.toLowerCase());
  if (!snapshot) {
    _deleteRowsByField_('Boxes_Balance', 'box_id', boxId);
    return;
  }
  _updateByField('Boxes_Balance', 'box_id', boxId, {
    balance: snapshot.balance,
    last_updated: snapshot.last_updated || _now(),
  });
}

function _deleteRowsByField_(sheetName, keyField, value) {
  const sheet = _ss().getSheetByName(sheetName);
  if (!sheet || sheet.getLastRow() < 2) return;
  const data = sheet.getDataRange().getValues();
  const headers = data[0].map(h => String(h).trim());
  const keyIndex = headers.indexOf(keyField);
  if (keyIndex < 0) throw new Error('حقل المفتاح غير موجود: ' + keyField);
  for (let row = data.length - 1; row >= 1; row--) {
    if (String(data[row][keyIndex]) === String(value)) sheet.deleteRow(row + 1);
  }
}

function _deleteSalesStockRow_(userId, code) {
  const sheet = _ss().getSheetByName('Sales_Stock');
  if (!sheet || sheet.getLastRow() < 2) return;
  const data = sheet.getDataRange().getValues();
  const headers = data[0].map(h => String(h).trim());
  const userIndex = headers.indexOf('user_id');
  const codeIndex = headers.indexOf('code');
  for (let row = data.length - 1; row >= 1; row--) {
    if (String(data[row][userIndex]) === String(userId) &&
        String(data[row][codeIndex]) === String(code)) {
      sheet.deleteRow(row + 1);
    }
  }
}

function _setSalesStockQuantity_(userId, code, quantity) {
  const sheet = _ss().getSheetByName('Sales_Stock');
  if (!sheet) throw new Error('ورقة مخزون المندوبين القديمة غير موجودة');
  const values = sheet.getDataRange().getValues();
  if (!values.length) throw new Error('ورقة مخزون المندوبين القديمة فارغة');
  const headers = values[0].map(header => String(header).trim());
  const userIndex = headers.indexOf('user_id');
  const codeIndex = headers.indexOf('code');
  const quantityIndex = headers.indexOf('quantity');
  if ([userIndex, codeIndex, quantityIndex].some(index => index < 0)) {
    throw new Error('مخطط مخزون المندوبين التاريخي غير صالح');
  }
  const matchingRows = values
    .map((row, index) => ({ row: row, index: index }))
    .filter(entry =>
      entry.index > 0 &&
      String(entry.row[userIndex]) === String(userId) &&
      String(entry.row[codeIndex]) === String(code)
    );
  if (matchingRows.length !== 1) {
    throw _apiError(
      'LEGACY_SELLER_STOCK_ROW_INVALID',
      'تعذر تحديد رصيد تاريخي وحيد للمادة ' + code,
      false
    );
  }
  sheet.getRange(matchingRows[0].index + 1, quantityIndex + 1).setValue(quantity);
}

const _INVOICE_TEMPLATE_COLUMNS_ = [
  'index', 'image', 'name', 'quantity', 'unit', 'price', 'total', 'note',
];

function _invoiceTemplateRejectDuplicateJsonKeys_(source) {
  const stack = [];
  for (let i = 0; i < source.length; i++) {
    const ch = source[i];
    if (ch === '"') {
      const start = i++;
      while (i < source.length) {
        if (source[i] === '\\') {
          i += 2;
        } else if (source[i] === '"') {
          break;
        } else {
          i++;
        }
      }
      let next = i + 1;
      while (/\s/.test(source[next] || '') && next < source.length) next++;
      if (source[next] === ':' && stack.length && stack[stack.length - 1]) {
        const key = JSON.parse(source.slice(start, i + 1));
        const keys = stack[stack.length - 1];
        if (keys.has(key)) throw _invoiceTemplateInvalid_('مفتاح JSON مكرر');
        keys.add(key);
      }
    } else if (ch === '{') {
      stack.push(new Set());
    } else if (ch === '[') {
      stack.push(null);
    } else if (ch === '}' || ch === ']') {
      stack.pop();
    }
  }
}
const _INVOICE_TEMPLATE_KEYS_ = [
  'version', 'company_name', 'company_details', 'footer', 'primary_color',
  'font_size', 'margin', 'columns', 'column_widths', 'show_images', 'show_notes',
];

function _invoiceTemplateInvalid_(detail) {
  return _apiError('INVALID_INVOICE_TEMPLATE', 'قالب الفاتورة غير صالح: ' + detail, false);
}

function _invoiceTemplateSheet_() {
  const sheet = _ss().getSheetByName('Invoice_Template');
  if (!sheet) {
    throw _apiError('INVOICE_TEMPLATE_SHEET_MISSING', 'ورقة Invoice_Template غير موجودة', false);
  }
  const rows = sheet.getDataRange().getValues();
  if (!rows.length || rows[0][0] !== 'key' || rows[0][1] !== 'value' ||
      rows[0].slice(2).some(value => value !== '')) {
    throw _invoiceTemplateInvalid_('العناوين يجب أن تكون key و value');
  }
  const settings = Object.create(null);
  const positions = Object.create(null);
  rows.slice(1).forEach((row, index) => {
    if (row.every(value => value === '')) return;
    const key = row[0];
    if (typeof key !== 'string' ||
        !_INVOICE_TEMPLATE_KEYS_.concat(['logo_file_id']).includes(key) ||
        Object.prototype.hasOwnProperty.call(settings, key) ||
        row.slice(2).some(value => value !== '')) {
      throw _invoiceTemplateInvalid_('مفتاح مكرر أو غير معروف أو عمود إضافي');
    }
    settings[key] = row[1];
    positions[key] = index;
  });
  if (_INVOICE_TEMPLATE_KEYS_.some(key => !Object.prototype.hasOwnProperty.call(settings, key))) {
    throw _invoiceTemplateInvalid_('بعض المفاتيح المطلوبة مفقودة');
  }
  return { sheet: sheet, rows: rows.slice(1), settings: settings, positions: positions };
}

function _invoiceTemplateValidate_(input, fromSheet) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw _invoiceTemplateInvalid_('template يجب أن يكون كائناً');
  }
  const allowed = _INVOICE_TEMPLATE_KEYS_.concat(['logo_file_id']);
  if (Object.keys(input).some(key => !allowed.includes(key)) ||
      _INVOICE_TEMPLATE_KEYS_.some(key => !Object.prototype.hasOwnProperty.call(input, key))) {
    throw _invoiceTemplateInvalid_('المفاتيح المطلوبة أو الإضافية');
  }
  function text(key, max, singleLine) {
    const value = input[key];
    if (typeof value !== 'string' || value.length > max ||
        /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(value) ||
        (singleLine && /[\r\n\t\u2028\u2029]/.test(value))) {
      throw _invoiceTemplateInvalid_(key);
    }
    return value;
  }
  function number(key, min, max) {
    let value = input[key];
    if (fromSheet && typeof value === 'string' &&
        /^-?(?:\d+\.?\d*|\.\d+)$/.test(value)) value = Number(value);
    if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) {
      throw _invoiceTemplateInvalid_(key);
    }
    return value;
  }
  function bool(key) {
    const value = input[key];
    if (value === true || (fromSheet && value === 'true')) return true;
    if (value === false || (fromSheet && value === 'false')) return false;
    throw _invoiceTemplateInvalid_(key);
  }
  function json(key) {
    if (!fromSheet) return input[key];
    if (typeof input[key] !== 'string' || input[key].length > 4096) {
      throw _invoiceTemplateInvalid_(key);
    }
    try {
      return JSON.parse(input[key]);
    } catch (error) {
      throw _invoiceTemplateInvalid_(key);
    }
  }
  const version = text('version', 40);
  const color = text('primary_color', 7);
  const logoId = Object.prototype.hasOwnProperty.call(input, 'logo_file_id')
    ? text('logo_file_id', 200) : '';
  if (!/^[A-Za-z0-9._-]{1,40}$/.test(version) ||
      !/^#[0-9a-fA-F]{6}$/.test(color) ||
      (logoId && !/^[A-Za-z0-9_-]+$/.test(logoId))) {
    throw _invoiceTemplateInvalid_('version أو primary_color أو logo_file_id');
  }
  const columns = json('columns');
  if (!Array.isArray(columns) || columns.length !== _INVOICE_TEMPLATE_COLUMNS_.length ||
      columns.some(key => !_INVOICE_TEMPLATE_COLUMNS_.includes(key)) ||
      new Set(columns).size !== columns.length) {
    throw _invoiceTemplateInvalid_('columns');
  }
  const widths = json('column_widths');
  if (!widths || typeof widths !== 'object' || Array.isArray(widths) ||
      Object.keys(widths).length !== _INVOICE_TEMPLATE_COLUMNS_.length ||
      _INVOICE_TEMPLATE_COLUMNS_.some(key =>
        !Object.prototype.hasOwnProperty.call(widths, key) ||
        typeof widths[key] !== 'number' || !Number.isFinite(widths[key]) ||
        widths[key] < 0.4 || widths[key] > 4)) {
    throw _invoiceTemplateInvalid_('column_widths');
  }
  if (fromSheet) {
    _invoiceTemplateRejectDuplicateJsonKeys_(input.column_widths);
  }
  const margin = number('margin', 20, 50);
  const showImages = bool('show_images');
  const showNotes = bool('show_notes');
  const visible = columns.filter(key =>
    (key !== 'image' || showImages) && (key !== 'note' || showNotes)
  );
  const totalWidth = visible.reduce((sum, key) => sum + widths[key], 0);
  const availableWidth = 595.2756 - 2 * margin;
  if (visible.some(key => availableWidth * widths[key] / totalWidth < 28 - 1e-9)) {
    throw _invoiceTemplateInvalid_('عرض العمود الظاهر أقل من 28 نقطة');
  }
  return {
    version: version,
    company_name: text('company_name', 200, true),
    company_details: text('company_details', 2000),
    footer: text('footer', 120, true),
    primary_color: color,
    font_size: number('font_size', 8, 14),
    margin: margin,
    columns: columns,
    column_widths: widths,
    show_images: showImages,
    show_notes: showNotes,
    logo_file_id: logoId,
  };
}

function _invoiceTemplateResponse_(settings) {
  const template = Object.assign({}, settings);
  delete template.logo_file_id;
  if (settings.logo_file_id) {
    let bytes;
    try {
      const file = DriveApp.getFileById(settings.logo_file_id);
      if (file.getSize() > 1024 * 1024) throw new Error('size');
      const blob = file.getBlob();
      const mime = blob.getContentType();
      bytes = blob.getBytes();
      const png = bytes.length >= 8 && [137, 80, 78, 71, 13, 10, 26, 10]
        .every((value, index) => (bytes[index] & 255) === value);
      const jpeg = bytes.length >= 3 && (bytes[0] & 255) === 255 &&
        (bytes[1] & 255) === 216 && (bytes[2] & 255) === 255;
      if (bytes.length > 1024 * 1024 ||
          !((mime === 'image/png' && png) || (mime === 'image/jpeg' && jpeg))) {
        throw new Error('format');
      }
    } catch (error) {
      throw _apiError('INVALID_INVOICE_TEMPLATE_LOGO', 'تعذر قراءة شعار PNG/JPEG خاص بحجم لا يتجاوز 1MB', false);
    }
    template.logo_base64 = Utilities.base64Encode(bytes);
  }
  return { template: template };
}

function _handleInvoiceTemplateGet_(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'salesperson']);
  const data = _invoiceTemplateSheet_();
  return _invoiceTemplateResponse_(_invoiceTemplateValidate_(data.settings, true));
}

function _handleInvoiceTemplateUpdate_(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const settings = _invoiceTemplateValidate_(body.template, false);
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) {
    throw _apiError('BUSY', 'قالب الفاتورة قيد التحديث، حاول مجدداً', true);
  }
  try {
    const data = _invoiceTemplateSheet_();
    const response = _invoiceTemplateResponse_(settings);
    if (!Object.prototype.hasOwnProperty.call(data.positions, 'logo_file_id') && settings.logo_file_id) {
      data.positions.logo_file_id = data.rows.length;
      data.rows.push(['logo_file_id', '']);
    }
    Object.keys(data.positions).forEach(key => {
      const value = settings[key];
      const serialized = typeof value === 'object' ? JSON.stringify(value) : String(value);
      data.rows[data.positions[key]] = [key, "'" + serialized];
    });
    if (data.rows.length) data.sheet.getRange(2, 1, data.rows.length, 2).setValues(
      data.rows.map(row => [row[0], row[1]])
    );
    return response;
  } finally {
    lock.releaseLock();
  }
}

function _salesProperty_(key) {
  return String(PropertiesService.getScriptProperties().getProperty(key) || '').trim();
}

function _getSalesSettings_() {
  const invoiceCurrency = _salesProperty_('SALES_INVOICE_CURRENCY').toUpperCase();
  const shamCurrency = _salesProperty_('SHAM_CASH_CURRENCY').toUpperCase();
  const productCurrency = _salesProperty_('DEFAULT_PRODUCT_CURRENCY').toUpperCase();
  const rate = _salesProperty_('SALES_RATE_SYP_PER_USD');
  const usdDecimals = _salesProperty_('SALES_USD_DECIMALS');
  const sypDecimals = _salesProperty_('SALES_SYP_DECIMALS');
  return {
    invoice_currency: ['USD', 'SYP'].includes(invoiceCurrency) ? invoiceCurrency : '',
    sham_cash_currency: ['USD', 'SYP'].includes(shamCurrency) ? shamCurrency : '',
    default_product_currency: ['USD', 'SYP'].includes(productCurrency)
      ? productCurrency : '',
    rate_syp_per_usd: rate && Number(rate) > 0 ? Number(rate) : null,
    usd_decimals: usdDecimals ? Number(usdDecimals) : null,
    syp_decimals: sypDecimals ? Number(sypDecimals) : null,
  };
}

function _handleGetSalesSettings(body, user) {
  _needRole(user, ['admin', 'accountant']);
  return { settings: _getSalesSettings_() };
}

function _handleUpdateSalesSettings(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const invoiceCurrency = String(body.invoice_currency || '').trim().toUpperCase();
  const shamCurrency = String(body.sham_cash_currency || '').trim().toUpperCase();
  const productCurrency = String(body.default_product_currency || '').trim().toUpperCase();
  const rateText = String(body.rate_syp_per_usd ?? '').trim();
  const usdDecimals = Number(body.usd_decimals);
  const sypDecimals = Number(body.syp_decimals);
  if (invoiceCurrency !== 'USD' ||
      !['USD', 'SYP'].includes(shamCurrency) ||
      !['USD', 'SYP'].includes(productCurrency) ||
      !Number.isInteger(usdDecimals) || usdDecimals < 0 || usdDecimals > 4 ||
      !Number.isInteger(sypDecimals) || sypDecimals < 0 || sypDecimals > 4 ||
      (rateText && (!Number.isFinite(Number(rateText)) || Number(rateText) <= 0))) {
    throw _apiError(
      'INVALID_SALES_SETTINGS',
      'عملة الفواتير USD؛ تحقق من عملة شام كاش ودقة العملات وسعر الصرف',
      false
    );
  }

  const updates = {
    SALES_INVOICE_CURRENCY: invoiceCurrency,
    SHAM_CASH_CURRENCY: shamCurrency,
    DEFAULT_PRODUCT_CURRENCY: productCurrency,
    SALES_RATE_SYP_PER_USD: rateText ? String(Number(rateText)) : '',
    SALES_USD_DECIMALS: String(usdDecimals),
    SALES_SYP_DECIMALS: String(sypDecimals),
  };
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) {
    throw _apiError('BUSY', 'إعدادات البيع قيد التحديث، حاول مجددًا', true);
  }
  const properties = PropertiesService.getScriptProperties();
  const before = {};
  const changed = [];
  try {
    if (body.expected_settings !== undefined) {
      const expected = body.expected_settings;
      const current = _getSalesSettings_();
      if (!expected || typeof expected !== 'object' ||
          Object.keys(current).some(key => expected[key] !== current[key])) {
        throw _apiError(
          'SALES_SETTINGS_CONFLICT',
          'تغيرت إعدادات البيع لدى مستخدم آخر؛ أعد تحميلها قبل الحفظ',
          false
        );
      }
    }
    Object.keys(updates).forEach(key => {
      before[key] = properties.getProperty(key);
    });
    Object.keys(updates).forEach(key => {
      properties.setProperty(key, updates[key]);
      changed.push(key);
    });
    _add('Audit_Log', {
      log_id: Utilities.getUuid(),
      user_id: user.user_id,
      action: 'UPDATE_SALES_SETTINGS',
      entity: 'ScriptProperties',
      entity_id: 'sales',
      details: JSON.stringify({ before: before, after: updates }),
      created_at: _now(),
    });
    return { success: true, settings: _getSalesSettings_() };
  } catch (error) {
    const rollbackErrors = [];
    changed.forEach(key => {
      try {
        if (before[key] === null || before[key] === undefined) {
          properties.deleteProperty(key);
        } else {
          properties.setProperty(key, before[key]);
        }
      } catch (rollbackError) {
        rollbackErrors.push(String(rollbackError));
      }
    });
    if (rollbackErrors.length) {
      Logger.log('Sales settings rollback failed: ' + rollbackErrors.join('; '));
      throw _apiError(
        'SALES_SETTINGS_ROLLBACK_FAILED',
        'تعذر حفظ الإعدادات وإكمال التراجع عنها؛ راجع سجل النظام',
        false
      );
    }
    throw error;
  } finally {
    lock.releaseLock();
  }
}

function _salesCurrencyDecimals_(currency) {
  const key = currency === 'USD' ? 'SALES_USD_DECIMALS' : 'SALES_SYP_DECIMALS';
  const raw = _salesProperty_(key);
  const decimals = Number(raw);
  if (!raw || !Number.isInteger(decimals) || decimals < 0 || decimals > 4) {
    throw _apiError(
      'SALES_CURRENCY_NOT_CONFIGURED',
      'إعداد منازل العملة ' + currency + ' غير مضبوط. يجب ضبط ' + key,
      false
    );
  }
  return decimals;
}

function _roundSalesAmount_(amount, currency) {
  const factor = Math.pow(10, _salesCurrencyDecimals_(currency));
  return Math.round((Number(amount) + Number.EPSILON) * factor) / factor;
}

function _salesPaymentCurrency_(method) {
  if (method === 'cash_syp') return 'SYP';
  if (method === 'cash_usd') return 'USD';
  if (method === 'sham_cash_syp') return 'SYP';
  if (method === 'sham_cash_usd') return 'USD';
  if (method !== 'sham_cash') {
    throw _apiError('INVALID_PAYMENT_METHOD', 'طريقة القبض مطلوبة وصالحة', false);
  }
  const currency = _salesProperty_('SHAM_CASH_CURRENCY').toUpperCase();
  if (!['USD', 'SYP'].includes(currency)) {
    throw _apiError(
      'SHAM_CASH_CURRENCY_NOT_CONFIGURED',
      'يجب ضبط عملة شام كاش في Script Properties قبل استخدامها',
      false
    );
  }
  return currency;
}

function _handleSalesConfiguration(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'salesperson']);
  const settings = _getSalesSettings_();
  return {
    invoice_currency: settings.invoice_currency || 'USD',
    sham_cash_currency: settings.sham_cash_currency,
    default_product_currency: settings.default_product_currency,
    rate_syp_per_usd: settings.rate_syp_per_usd,
    usd_decimals: settings.usd_decimals,
    syp_decimals: settings.syp_decimals,
  };
}

function _salesMethodInfo_(method) {
  const methods = {
    cash_usd: { currency: 'USD', box: 'cash_box' },
    cash_syp: { currency: 'SYP', box: 'cash_box' },
    sham_cash_usd: { currency: 'USD', box: 'sham_cash' },
    sham_cash_syp: { currency: 'SYP', box: 'sham_cash' },
  };
  const info = methods[String(method || '').trim()];
  if (!info) {
    throw _apiError('INVALID_PAYMENT_METHOD', 'اختر وسيلة دفع وصندوقًا صالحًا', false);
  }
  return info;
}

function _salesPositiveNumber_(value, fieldName) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) {
    throw _apiError('INVALID_FINANCIAL_AMOUNT', fieldName + ' يجب أن يكون موجبًا', false);
  }
  return number;
}

function _normalizeSalesPaymentLines_(rawLines, options) {
  const label = options.label || 'الحركة';
  if (rawLines === undefined || rawLines === null) return [];
  if (!Array.isArray(rawLines)) {
    throw _apiError('INVALID_PAYMENT_LINES', 'صيغة أسطر ' + label + ' غير صالحة', false);
  }
  return rawLines.map((raw, index) => {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
      throw _apiError('INVALID_PAYMENT_LINE', 'سطر ' + label + ' رقم ' + (index + 1) + ' غير صالح', false);
    }
    const method = String(raw.method || '').trim();
    const methodInfo = _salesMethodInfo_(method);
    const currency = methodInfo.currency;
    const amount = _roundSalesAmount_(
      _salesPositiveNumber_(raw.amount, 'مبلغ ' + label),
      currency
    );
    if (amount <= 0) {
      throw _apiError('INVALID_FINANCIAL_AMOUNT', 'مبلغ ' + label + ' أقل من دقة العملة', false);
    }
    if (currency === 'USD') {
      return {
        method: method,
        box: methodInfo.box,
        currency: currency,
        amount: amount,
        equivalent_usd: _roundSalesAmount_(amount, 'USD'),
        exchange_rate: '',
        reference: String(raw.reference || '').trim(),
        note: String(raw.note || '').trim(),
      };
    }

    const equivalentInput = raw.equivalent_usd === '' ||
      raw.equivalent_usd === undefined || raw.equivalent_usd === null
      ? null : Number(raw.equivalent_usd);
    const rateInput = raw.exchange_rate === '' ||
      raw.exchange_rate === undefined || raw.exchange_rate === null
      ? null : Number(raw.exchange_rate);
    if (equivalentInput !== null &&
        (!Number.isFinite(equivalentInput) || equivalentInput <= 0)) {
      throw _apiError('INVALID_EXCHANGE_RATE', 'المقابل الدولاري يجب أن يكون موجبًا', false);
    }
    if (rateInput !== null && (!Number.isFinite(rateInput) || rateInput <= 0)) {
      throw _apiError('INVALID_EXCHANGE_RATE', 'سعر الصرف يجب أن يكون ليرات موجبة لكل دولار', false);
    }
    if (equivalentInput !== null && rateInput !== null) {
      const implied = amount / rateInput;
      if (Math.abs(implied - equivalentInput) > 0.011) {
        throw _apiError(
          'EXCHANGE_VALUES_MISMATCH',
          'المبلغ السوري وسعر الصرف لا يطابقان المقابل الدولاري',
          false
        );
      }
    }
    let equivalentUsd = equivalentInput === null
      ? rateInput === null ? null : _roundSalesAmount_(amount / rateInput, 'USD')
      : _roundSalesAmount_(equivalentInput, 'USD');
    let rate = equivalentUsd === null
      ? null : amount / equivalentUsd;
    if (equivalentUsd !== null && equivalentUsd <= 0) {
      throw _apiError('INVALID_EXCHANGE_RATE', 'المقابل الدولاري بعد التقريب يساوي صفرًا', false);
    }
    return {
      method: method,
      box: methodInfo.box,
      currency: currency,
      amount: amount,
      equivalent_usd: equivalentUsd,
      exchange_rate: rate,
      reference: String(raw.reference || '').trim(),
      note: String(raw.note || '').trim(),
    };
  });
}

function _completeSalesPaymentRates_(received, refunded, options) {
  const missing = received.concat(refunded).filter(line =>
    line.currency === 'SYP' && line.equivalent_usd === null
  );
  const usdReceived = received.reduce((sum, line) =>
    sum + Number(line.equivalent_usd || 0), 0);
  const usdRefunded = refunded.reduce((sum, line) =>
    sum + Number(line.equivalent_usd || 0), 0);
  if (missing.length) {
    if (!options.settle_full) {
      throw _apiError(
        'EXCHANGE_RATE_REQUIRED',
        'أدخل المقابل الدولاري أو سعر الصرف لكل حركة سورية، أو اختر تسوية الفاتورة بالكامل',
        false
      );
    }
    const netSyp = missing
      .filter(line => received.includes(line))
      .reduce((sum, line) => sum + line.amount, 0) -
      missing
        .filter(line => refunded.includes(line))
        .reduce((sum, line) => sum + line.amount, 0);
    const knownNetUsd = usdReceived - usdRefunded;
    const targetNetUsd = Number(options.net_total) - knownNetUsd;
    if (Math.abs(netSyp) < 0.000001 ||
        Math.abs(targetNetUsd) < 0.005 ||
        netSyp * targetNetUsd <= 0) {
      throw _apiError(
        'EXCHANGE_RATE_UNDETERMINED',
        'لا يمكن استنتاج سعر صرف وحيد من هذه الحركات؛ أدخل المقابل الدولاري أو سعر الصرف لكل سطر',
        false
      );
    }
    const inferredRate = netSyp / targetNetUsd;
    if (!Number.isFinite(inferredRate) || inferredRate <= 0) {
      throw _apiError('INVALID_EXCHANGE_RATE', 'تعذر استنتاج سعر صرف موجب', false);
    }
    missing.forEach(line => {
      line.exchange_rate = inferredRate;
      line.equivalent_usd = _roundSalesAmount_(line.amount / inferredRate, 'USD');
    });
  }

  received.forEach(line => {
    if (line.currency === 'SYP') {
      line.exchange_rate = line.amount / line.equivalent_usd;
    }
  });
  refunded.forEach(line => {
    if (line.currency === 'SYP') {
      line.exchange_rate = line.amount / line.equivalent_usd;
    }
  });
  const totalReceivedUsd = _roundSalesAmount_(
    received.reduce((sum, line) => sum + line.equivalent_usd, 0),
    'USD'
  );
  const totalRefundedUsd = _roundSalesAmount_(
    refunded.reduce((sum, line) => sum + line.equivalent_usd, 0),
    'USD'
  );
  return {
    total_received_usd: totalReceivedUsd,
    total_refunded_usd: totalRefundedUsd,
    net_paid_usd: _roundSalesAmount_(totalReceivedUsd - totalRefundedUsd, 'USD'),
  };
}

function _cashBoxSnapshot_(boxName, currency) {
  const boxes = _all('Boxes_Balance').filter(box =>
    String(box.box_name) === String(boxName) &&
    String(box.currency).toUpperCase() === String(currency).toUpperCase()
  );
  if (boxes.length > 1) {
    throw _apiError(
      'DUPLICATE_CASH_BOX',
      'يوجد أكثر من سجل للصندوق ' + boxName + ' بعملة ' + currency +
        '. يلزم توحيدها يدويًا قبل الترحيل.',
      false
    );
  }
  return boxes.length ? Object.assign({}, boxes[0]) : null;
}

function _writeSalesPayment_(line, input) {
  const paymentId = 'SP-' + Utilities.getUuid().replace(/-/g, '').toUpperCase();
  const record = {
    payment_id: paymentId,
    customer_id: input.customer_id,
    order_id: input.invoice_id || '',
    receipt_id: input.receipt_id || '',
    amount: line.amount,
    currency: line.currency,
    box_type: line.box,
    method: line.method,
    payment_method: line.method,
    payment_date: input.payment_date,
    note: line.note || input.note || '',
    created_by: input.user_id,
    created_at: input.created_at,
    action_type: input.action_type,
    invoice_currency: 'USD',
    invoice_equivalent: line.equivalent_usd,
    exchange_rate: line.currency === 'SYP' ? line.exchange_rate : '',
    reference: line.reference || '',
    client_request_id: input.client_request_id,
  };
  _add('Payments', record);
  try {
    _updateBoxBalance(line.box, line.currency, line.amount, input.action_type);
  } catch (error) {
    try {
      _deleteRowsByField_('Payments', 'payment_id', paymentId);
    } catch (rollbackError) {
      Logger.log('Unable to remove unposted payment ' + paymentId + ': ' + rollbackError);
    }
    throw error;
  }
  return record;
}

function _handleSalespeopleList(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'warehouse']);
  return {
    salespeople: _all('Users')
      .filter(account =>
        _normalizeRole(account.role) === 'salesperson' &&
        _isActiveStatus_(account.status)
      )
      .map(account => ({
        user_id: account.user_id,
        full_name: account.full_name,
        username: account.username,
      })),
  };
}

function _handleSalesStockTransfer(body, user) {
  _needRole(user, ['admin', 'manager', 'warehouse']);
  throw _apiError(
    'SALESPERSON_STOCK_REMOVED',
    'تخصيص مخزون مستقل للمندوب متوقف؛ جميع المبيعات تخصم من المخزون العام',
    false
  );
}

function _handleCreateSalesInvoice(body, user) {
  _needRole(user, ['salesperson']);
  const requestId = String(body.client_request_id || '').trim();
  if (requestId.length < 12 || requestId.length > 100) {
    throw _apiError('IDEMPOTENCY_KEY_REQUIRED', 'معرف عملية فريد مطلوب لمنع تكرار الفاتورة', false);
  }
  const method = String(body.payment_method || '').trim();
  const paymentCurrency = _salesPaymentCurrency_(method);
  const invoiceCurrency = _salesProperty_('SALES_INVOICE_CURRENCY').toUpperCase();
  if (!['USD', 'SYP'].includes(invoiceCurrency)) {
    throw _apiError(
      'SALES_CURRENCY_NOT_CONFIGURED',
      'يجب ضبط SALES_INVOICE_CURRENCY على USD أو SYP قبل تسجيل البيع',
      false
    );
  }
  const invoiceDecimals = _salesCurrencyDecimals_(invoiceCurrency);
  const paymentDecimals = _salesCurrencyDecimals_(paymentCurrency);
  const amountReceived = Number(body.amount_received);
  const discount = Number(body.discount || 0);
  const items = body.items;
  if (!Array.isArray(items) || items.length === 0 ||
      !Number.isFinite(amountReceived) || amountReceived <= 0 ||
      !Number.isFinite(discount) || discount < 0) {
    throw _apiError('INVALID_SALES_INVOICE', 'بيانات الفاتورة أو القبض غير صالحة', false);
  }
  const rateText = _salesProperty_('SALES_RATE_SYP_PER_USD');
  const rate = rateText ? Number(rateText) : 0;
  if (paymentCurrency !== invoiceCurrency &&
      (!Number.isFinite(rate) || rate <= 0)) {
    throw _apiError(
      'EXCHANGE_RATE_NOT_CONFIGURED',
      'سعر الصرف SYP لكل USD غير مضبوط؛ لا يمكن تحويل عملة الدفع',
      false
    );
  }
  const exchangeRate = paymentCurrency === invoiceCurrency ? 1 : rate;
  const paymentAmount = Math.round(
    (amountReceived + Number.EPSILON) * Math.pow(10, paymentDecimals)
  ) / Math.pow(10, paymentDecimals);
  const equivalentRaw = paymentCurrency === invoiceCurrency
    ? paymentAmount
    : invoiceCurrency === 'USD'
      ? paymentAmount / exchangeRate
      : paymentAmount * exchangeRate;
  const equivalentReceived = Math.round(
    (equivalentRaw + Number.EPSILON) * Math.pow(10, invoiceDecimals)
  ) / Math.pow(10, invoiceDecimals);
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) throw _apiError('BUSY', 'جارٍ ترحيل عملية أخرى، حاول مجددًا', true);

  const invoiceId = 'SI-' + Utilities.getUuid().replace(/-/g, '').toUpperCase();
  const paymentId = 'SP-' + Utilities.getUuid().replace(/-/g, '').toUpperCase();
  const changePaymentId = 'SC-' + Utilities.getUuid().replace(/-/g, '').toUpperCase();
  const stockChanges = [];
  let boxId = '';
  let boxBefore = null;
  let boxUpdateAttempted = false;
  try {
    const prior = _all('Sales_Invoices').find(row =>
      String(row.client_request_id) === requestId &&
      String(row.seller_id) === String(user.user_id)
    );
    if (prior) return { success: true, invoice_id: prior.invoice_id, duplicate: true };
    if (_all('Sales_Invoices').some(row =>
      String(row.client_request_id) === requestId
    )) {
      throw _apiError('IDEMPOTENCY_KEY_CONFLICT', 'معرف العملية مستخدم لفاتورة أخرى', false);
    }

    const account = _all('Users').find(row =>
      String(row.user_id) === String(user.user_id) &&
      _normalizeRole(row.role) === 'salesperson' &&
      _isActiveStatus_(row.status)
    );
    if (!account || !String(account.cash_box_id || '').trim()) {
      throw _apiError(
        'SELLER_SETUP_REQUIRED',
        'يجب ربط حساب المندوب بصندوق تحصيل قبل تسجيل الفواتير',
        false
      );
    }
    boxId = String(account.cash_box_id).trim();
    const existingBox = _all('Boxes_Balance').find(row =>
      String(row.box_name) === boxId && String(row.currency) === paymentCurrency
    );
    boxBefore = existingBox ? Object.assign({}, existingBox) : null;
    const productRows = _all('Products');
    const productMap = {};
    productRows.forEach(row => productMap[String(row.code)] = row);
    const seen = {};
    let subtotal = 0;
    const preparedItems = [];
    items.forEach(item => {
      const code = String(item.code || '').trim();
      const quantity = Number(item.quantity);
      const unitPrice = Number(item.unit_price);
      if (!code || seen[code] || !Number.isFinite(quantity) ||
          !Number.isInteger(quantity) || quantity <= 0 ||
          !Number.isFinite(unitPrice) || unitPrice < 0) {
        throw _apiError(
          'INVALID_SALES_ITEM',
          'كل مادة يجب أن تكون فريدة وبكمية صحيحة موجبة وسعر غير سالب',
          false
        );
      }
      seen[code] = true;
      const product = productMap[code];
      if (!product) throw _apiError('PRODUCT_NOT_FOUND', 'المادة غير موجودة: ' + code, false);
      const productCurrency = String(
        product.currency || _salesProperty_('DEFAULT_PRODUCT_CURRENCY') || ''
      ).toUpperCase();
      if (productCurrency !== invoiceCurrency) {
        throw _apiError(
          'PRODUCT_CURRENCY_MISMATCH',
          'عملة سعر المادة ' + (product.name || code) +
            ' لا تطابق عملة الفاتورة. يلزم تصحيح إعداد العملة قبل البيع',
          false
        );
      }
      const available = Number(product.quantity || 0);
      if (!Number.isFinite(available)) {
        throw _apiError(
          'INVALID_CENTRAL_STOCK',
          'رصيد المخزون العام للمادة ' + (product.name || code) + ' غير صالح',
          false
        );
      }
      const lineTotal = Math.round(
        (quantity * unitPrice + Number.EPSILON) * Math.pow(10, invoiceDecimals)
      ) / Math.pow(10, invoiceDecimals);
      subtotal += lineTotal;
      preparedItems.push({
        code: code,
        name: String(product.name || code),
        unit: String(item.unit || product.unit_1 || ''),
        quantity: quantity,
        unit_price: unitPrice,
        line_total: lineTotal,
        note: String(item.note || ''),
        available: available,
      });
    });
    subtotal = Math.round((subtotal + Number.EPSILON) * Math.pow(10, invoiceDecimals)) /
      Math.pow(10, invoiceDecimals);
    const roundedDiscount = Math.round(
      (discount + Number.EPSILON) * Math.pow(10, invoiceDecimals)
    ) / Math.pow(10, invoiceDecimals);
    if (roundedDiscount > subtotal) {
      throw _apiError('INVALID_DISCOUNT', 'الحسم لا يجوز أن يتجاوز مجموع الفاتورة', false);
    }
    const netTotal = Math.round(
      (subtotal - roundedDiscount + Number.EPSILON) * Math.pow(10, invoiceDecimals)
    ) / Math.pow(10, invoiceDecimals);
    if (equivalentReceived < netTotal) {
      throw _apiError('PAYMENT_SHORTFALL', 'الفاتورة نقدية ويجب استلام كامل الصافي', false);
    }
    const changeAmount = Math.round(
      ((equivalentReceived - netTotal) *
        (paymentCurrency === invoiceCurrency ? 1 :
          invoiceCurrency === 'USD' ? exchangeRate : 1 / exchangeRate) +
        Number.EPSILON) * Math.pow(10, paymentDecimals)
    ) / Math.pow(10, paymentDecimals);
    _requireColumns_('Products', ['code', 'quantity']);
    _requireColumns_('Sales_Invoices', ['stock_source']);
    const customerId = _ensureShopCustomer_();
    const now = _now();
    const invoice = {
      invoice_id: invoiceId,
      customer_id: customerId,
      customer_name: 'زبائن محل',
      buyer_name: String(body.buyer_name || '').trim(),
      buyer_phone: String(body.buyer_phone || '').trim(),
      seller_id: user.user_id,
      invoice_date: now,
      created_at: now,
      updated_at: '',
      modified_by: '',
      revision: 1,
      status: 'posted',
      stock_source: 'central',
      currency: invoiceCurrency,
      subtotal: subtotal,
      discount: roundedDiscount,
      net_total: netTotal,
      amount_received: paymentAmount,
      payment_currency: paymentCurrency,
      payment_method: method,
      rate_syp_per_usd: paymentCurrency === invoiceCurrency ? '' : exchangeRate,
      equivalent_received: equivalentReceived,
      change_amount: changeAmount,
      net_received: paymentAmount - changeAmount,
      notes: String(body.notes || '').trim(),
      payment_reference: method === 'sham_cash' ? String(body.payment_reference || '').trim() : '',
      cash_box_id: boxId,
      client_request_id: requestId,
    };
    preparedItems.forEach(item => {
      const previous = item.available;
      const next = previous - item.quantity;
      stockChanges.push({ code: item.code, before: previous });
      _setProductStockQuantity_(item.code, next);
    });
    _add('Sales_Invoices', invoice);
    preparedItems.forEach(item => {
      _add('Sales_Invoice_Items', {
        item_id: 'SII-' + Utilities.getUuid().replace(/-/g, '').slice(0, 16),
        invoice_id: invoiceId,
        code: item.code,
        name_snapshot: item.name,
        unit: item.unit,
        quantity: item.quantity,
        unit_price: item.unit_price,
        line_total: item.line_total,
        note: item.note,
        stock_source: 'central',
      });
      _add('Inventory_Movements', {
        movement_id: 'MV-' + Utilities.getUuid().replace(/-/g, '').slice(0, 12),
        code: item.code,
        type: 'sale',
        quantity: item.quantity,
        note: 'فاتورة نقدية ' + invoiceId,
        created_by: user.user_id,
        created_at: now,
        reference_id: invoiceId,
        is_correction: 'false',
      });
    });
    _add('Payments', {
      payment_id: paymentId,
      customer_id: customerId,
      order_id: invoiceId,
      amount: paymentAmount,
      currency: paymentCurrency,
      box_type: boxId,
      method: method,
      payment_date: now,
      note: 'قبض فاتورة نقدية ' + invoiceId,
      created_by: user.user_id,
      created_at: now,
      action_type: 'receive',
      payment_method: method,
      invoice_currency: invoiceCurrency,
      invoice_equivalent: equivalentReceived,
      exchange_rate: paymentCurrency === invoiceCurrency ? '' : exchangeRate,
      reference: invoice.payment_reference,
      client_request_id: requestId,
    });
    boxUpdateAttempted = true;
    _updateBoxBalance(boxId, paymentCurrency, paymentAmount, 'receive');
    if (changeAmount > 0) {
      _add('Payments', {
        payment_id: changePaymentId,
        customer_id: customerId,
        order_id: invoiceId,
        amount: changeAmount,
        currency: paymentCurrency,
        box_type: boxId,
        method: 'cash_change',
        payment_date: now,
        note: 'باقي مرتجع لفاتورة ' + invoiceId,
        created_by: user.user_id,
        created_at: now,
        action_type: 'pay',
        payment_method: 'cash_change',
        invoice_currency: invoiceCurrency,
        invoice_equivalent: '',
        exchange_rate: paymentCurrency === invoiceCurrency ? '' : exchangeRate,
        reference: invoice.payment_reference,
        client_request_id: requestId + ':change',
      });
      _updateBoxBalance(boxId, paymentCurrency, changeAmount, 'pay');
    }
    _add('Sales_Invoice_Audit', {
      audit_id: Utilities.getUuid(),
      invoice_id: invoiceId,
      user_id: user.user_id,
      created_at: now,
      action: 'CREATE_POSTED_CASH_SALE',
      reason: '',
      before_json: '',
      after_json: JSON.stringify(invoice),
    });
    return {
      success: true,
      invoice_id: invoiceId,
      invoice: invoice,
      items: preparedItems.map(item => ({
        code: item.code,
        name_snapshot: item.name,
        unit: item.unit,
        quantity: item.quantity,
        unit_price: item.unit_price,
        line_total: item.line_total,
      })),
    };
  } catch (error) {
    const rollbackErrors = [];
    stockChanges.forEach(change => {
      try {
        _setProductStockQuantity_(change.code, change.before);
      } catch (rollbackError) {
        rollbackErrors.push(String(rollbackError));
      }
    });
    const rollbackSteps = [
      () => {
        if (boxUpdateAttempted) _restoreBoxBalance_(boxId, paymentCurrency, boxBefore);
      },
      () => _deleteRowsByField_('Sales_Invoices', 'invoice_id', invoiceId),
      () => _deleteRowsByField_('Sales_Invoice_Items', 'invoice_id', invoiceId),
      () => _deleteRowsByField_('Sales_Invoice_Audit', 'invoice_id', invoiceId),
      () => _deleteRowsByField_('Inventory_Movements', 'reference_id', invoiceId),
      () => _deleteRowsByField_('Payments', 'payment_id', paymentId),
      () => _deleteRowsByField_('Payments', 'payment_id', changePaymentId),
    ];
    rollbackSteps.forEach(step => {
      try {
        step();
      } catch (rollbackError) {
        rollbackErrors.push(String(rollbackError));
      }
    });
    if (rollbackErrors.length) {
      Logger.log('Sales invoice rollback failed for ' + invoiceId + ': ' + rollbackErrors.join('; '));
      throw _apiError(
        'SALES_ROLLBACK_FAILED',
        'فشل جزء من حفظ الفاتورة وتعذر إكمال التراجع تلقائيًا. رقم العملية: ' + invoiceId,
        false
      );
    }
    throw error;
  } finally {
    lock.releaseLock();
  }
}

function _handleCreateSalesInvoiceV2(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'salesperson']);
  const creatorRole = _normalizeRole(user.role);
  const creatorId = String(user.user_id || '');
  const requestId = String(body.client_request_id || '').trim();
  if (requestId.length < 12 || requestId.length > 100) {
    throw _apiError('IDEMPOTENCY_KEY_REQUIRED', 'معرف عملية فريد مطلوب لمنع تكرار الفاتورة', false);
  }
  const invoiceCurrency = String(_salesProperty_('SALES_INVOICE_CURRENCY') || 'USD').toUpperCase();
  if (invoiceCurrency !== 'USD') {
    throw _apiError(
      'SALES_CURRENCY_NOT_CONFIGURED',
      'عملة الفواتير بالدولار فقط؛ اضبط SALES_INVOICE_CURRENCY على USD',
      false
    );
  }
  const usdDecimals = _salesCurrencyDecimals_('USD');
  const sypDecimals = _salesCurrencyDecimals_('SYP');
  const discountInput = Number(body.discount || 0);
  const items = body.items;
  if (!Array.isArray(items) || items.length === 0 ||
      !Number.isFinite(discountInput) || discountInput < 0) {
    throw _apiError('INVALID_SALES_INVOICE', 'بيانات الفاتورة أو الحسم غير صالحة', false);
  }
  const received = _normalizeSalesPaymentLines_(body.received_lines, {
    label: 'الاستلام',
  });
  const refunded = _normalizeSalesPaymentLines_(body.refunded_lines, {
    label: 'الباقي المعاد',
  });
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) {
    throw _apiError('BUSY', 'جارٍ ترحيل عملية أخرى، حاول مجددًا', true);
  }

  const invoiceId = 'SI-' + Utilities.getUuid().replace(/-/g, '').toUpperCase();
  const requestPrefix = requestId;
  const stockChanges = [];
  const boxSnapshots = {};
  const paymentIds = [];
  let invoiceAdded = false;
  let auditAdded = false;
  let itemsAdded = false;
  let movementsAdded = false;
  let boxKeysChanged = [];
  try {
    const prior = _all('Sales_Invoices').find(row =>
      String(row.client_request_id) === requestId &&
      String(row.created_by || row.seller_id) === creatorId
    );
    if (prior) {
      return {
        success: true,
        invoice_id: prior.invoice_id,
        invoice_number: prior.invoice_number || '',
        balance_due_usd: prior.balance_due_usd || 0,
        financial_status: prior.financial_status || '',
        duplicate: true,
      };
    }
    if (_all('Sales_Invoices').some(row =>
      String(row.client_request_id) === requestId
    )) {
      throw _apiError('IDEMPOTENCY_KEY_CONFLICT', 'معرف العملية مستخدم لفاتورة أخرى', false);
    }

    const users = _all('Users');
    const creator = users.find(row =>
      String(row.user_id) === creatorId &&
      _normalizeRole(row.role) === creatorRole &&
      _isActiveStatus_(row.status)
    );
    if (!creator) {
      throw _apiError('CREATOR_SETUP_REQUIRED', 'حساب منشئ الفاتورة غير فعال', false);
    }
    const productRows = _all('Products');
    const productMap = {};
    productRows.forEach(row => productMap[String(row.code)] = row);
    const seen = {};
    let subtotal = 0;
    const preparedItems = [];
    items.forEach(item => {
      const code = String(item.code || '').trim();
      const quantity = Number(item.quantity);
      const unitPrice = Number(item.unit_price);
      if (!code || seen[code] || !Number.isInteger(quantity) || quantity <= 0 ||
          !Number.isFinite(unitPrice) || unitPrice < 0) {
        throw _apiError(
          'INVALID_SALES_ITEM',
          'كل مادة يجب أن تكون فريدة وبكمية موجبة وسعر غير سالب',
          false
        );
      }
      seen[code] = true;
      const product = productMap[code];
      if (!product) throw _apiError('PRODUCT_NOT_FOUND', 'المادة غير موجودة: ' + code, false);
      const productCurrency = String(
        product.currency || _salesProperty_('DEFAULT_PRODUCT_CURRENCY') || ''
      ).toUpperCase();
      if (productCurrency !== 'USD') {
        throw _apiError(
          'PRODUCT_CURRENCY_MISMATCH',
          'عملة سعر المادة ' + (product.name || code) + ' ليست USD',
          false
        );
      }
      const available = Number(product.quantity || 0);
      if (!Number.isFinite(available)) {
        throw _apiError('INVALID_CENTRAL_STOCK', 'رصيد المخزون العام غير صالح للمادة ' + code, false);
      }
      const lineTotal = _roundSalesAmount_(quantity * unitPrice, 'USD');
      subtotal += lineTotal;
      preparedItems.push({
        code: code,
        name: String(product.name || code),
        unit: String(item.unit || product.unit_1 || ''),
        quantity: quantity,
        unit_price: _roundSalesAmount_(unitPrice, 'USD'),
        line_total: lineTotal,
        note: String(item.note || ''),
        available: available,
      });
    });
    subtotal = _roundSalesAmount_(subtotal, 'USD');
    const discount = _roundSalesAmount_(discountInput, 'USD');
    if (discount > subtotal) {
      throw _apiError('INVALID_DISCOUNT', 'الحسم لا يجوز أن يتجاوز مجموع الفاتورة', false);
    }
    const netTotal = _roundSalesAmount_(subtotal - discount, 'USD');
    const settlement = _completeSalesPaymentRates_(received, refunded, {
      settle_full: body.settle_full === true || String(body.settle_full) === 'true',
      net_total: netTotal,
    });
    const balanceDue = _roundSalesAmount_(netTotal - settlement.net_paid_usd, 'USD');
    const selectedCustomerId = String(body.customer_id || '').trim();
    const isWalkIn = !selectedCustomerId || selectedCustomerId === 'CUS-SHOP';
    const customerId = isWalkIn ? _ensureShopCustomer_() : selectedCustomerId;
    const customer = _all('Customers').find(row =>
      String(row.customer_id) === customerId &&
      !['inactive', 'deleted'].includes(String(row.status || '').toLowerCase())
    );
    if (!customer) {
      throw _apiError('CUSTOMER_NOT_FOUND', 'الزبون المحدد غير موجود أو غير فعال', false);
    }
    if (balanceDue > 0.005 && isWalkIn) {
      throw _apiError(
        'CUSTOMER_REQUIRED_FOR_DEBT',
        'يوجد مبلغ متبقٍ؛ اختر زبونًا محددًا لتسجيل الدين بدل «زبائن محل»',
        false
      );
    }
    if (balanceDue < -0.005 &&
        (isWalkIn || body.confirm_customer_credit !== true)) {
      throw _apiError(
        'CUSTOMER_CREDIT_CONFIRMATION_REQUIRED',
        'المقبوض الصافي يتجاوز الفاتورة؛ سجّل الباقي المعاد أو أكد الزيادة كرصيد دائن لزبون محدد',
        false
      );
    }

    _requireColumns_('Products', ['code', 'quantity']);
    _requireColumns_('Sales_Invoices', [
      'invoice_number', 'created_by', 'created_by_role', 'stock_source',
      'financial_status', 'balance_due_usd',
    ]);
    _requireColumns_('Payments', ['receipt_id', 'invoice_equivalent']);
    const createdAt = new Date();
    const now = createdAt.toISOString();
    const invoiceNumber = _generateSalesInvoiceNumber_(
      _all('Sales_Invoices'),
      createdAt
    );
    const financialStatus = balanceDue <= 0.005
      ? 'paid' : settlement.net_paid_usd > 0 ? 'partial' : 'unpaid';
    const invoice = {
      invoice_id: invoiceId,
      invoice_number: invoiceNumber,
      created_by: creatorId,
      created_by_role: creatorRole,
      customer_id: customerId,
      customer_name: String(customer.full_name || 'زبائن محل'),
      buyer_name: String(body.buyer_name || '').trim(),
      buyer_phone: String(body.buyer_phone || '').trim(),
      seller_id: creatorRole === 'salesperson' ? creatorId : '',
      invoice_date: now,
      created_at: now,
      updated_at: '',
      modified_by: '',
      revision: 1,
      status: 'posted',
      stock_source: 'central',
      currency: 'USD',
      subtotal: subtotal,
      discount: discount,
      net_total: netTotal,
      amount_received: settlement.total_received_usd,
      payment_currency: 'USD',
      payment_method: 'mixed',
      rate_syp_per_usd: '',
      equivalent_received: settlement.total_received_usd,
      change_amount: settlement.total_refunded_usd,
      net_received: settlement.net_paid_usd,
      total_received_usd: settlement.total_received_usd,
      total_refunded_usd: settlement.total_refunded_usd,
      net_paid_usd: settlement.net_paid_usd,
      balance_due_usd: balanceDue,
      financial_status: financialStatus,
      payment_detail_version: 2,
      notes: String(body.notes || '').trim(),
      payment_reference: '',
      cash_box_id: '',
      client_request_id: requestId,
    };

    preparedItems.forEach(item => {
      stockChanges.push({ code: item.code, before: item.available });
      _setProductStockQuantity_(item.code, item.available - item.quantity);
    });
    _add('Sales_Invoices', invoice);
    invoiceAdded = true;
    itemsAdded = true;
    preparedItems.forEach(item => {
      _add('Sales_Invoice_Items', {
        item_id: 'SII-' + Utilities.getUuid().replace(/-/g, '').slice(0, 16),
        invoice_id: invoiceId,
        code: item.code,
        name_snapshot: item.name,
        unit: item.unit,
        quantity: item.quantity,
        unit_price: item.unit_price,
        line_total: item.line_total,
        note: item.note,
        stock_source: 'central',
      });
    });
    movementsAdded = true;
    preparedItems.forEach(item => {
      _add('Inventory_Movements', {
        movement_id: 'MV-' + Utilities.getUuid().replace(/-/g, '').slice(0, 12),
        code: item.code,
        type: 'sale',
        quantity: item.quantity,
        note: 'فاتورة مبيع ' + invoiceId,
        created_by: user.user_id,
        created_at: now,
        reference_id: invoiceId,
        is_correction: 'false',
      });
    });
    const paymentInput = {
      customer_id: customerId,
      invoice_id: invoiceId,
      receipt_id: '',
      payment_date: invoice.invoice_date,
      created_at: now,
      user_id: user.user_id,
      client_request_id: requestPrefix,
    };
    received.forEach((line, index) => {
      const beforeKey = line.box + ':' + line.currency;
      if (!Object.prototype.hasOwnProperty.call(boxSnapshots, beforeKey)) {
        boxSnapshots[beforeKey] = _cashBoxSnapshot_(line.box, line.currency);
      }
      boxKeysChanged.push(beforeKey);
      const payment = _writeSalesPayment_(line, Object.assign({}, paymentInput, {
        action_type: 'receive',
        client_request_id: requestPrefix + ':receive:' + index,
      }));
      paymentIds.push(payment.payment_id);
    });
    refunded.forEach((line, index) => {
      const beforeKey = line.box + ':' + line.currency;
      if (!Object.prototype.hasOwnProperty.call(boxSnapshots, beforeKey)) {
        boxSnapshots[beforeKey] = _cashBoxSnapshot_(line.box, line.currency);
      }
      boxKeysChanged.push(beforeKey);
      const payment = _writeSalesPayment_(line, Object.assign({}, paymentInput, {
        action_type: 'pay',
        client_request_id: requestPrefix + ':refund:' + index,
      }));
      paymentIds.push(payment.payment_id);
    });
    _add('Sales_Invoice_Audit', {
      audit_id: Utilities.getUuid(),
      invoice_id: invoiceId,
      user_id: user.user_id,
      created_at: now,
      action: 'CREATE_POSTED_SALES_INVOICE',
      reason: '',
      before_json: '',
      after_json: JSON.stringify({
        invoice: invoice,
        received_lines: received,
        refunded_lines: refunded,
      }),
    });
    auditAdded = true;
    if (creatorRole === 'salesperson') {
      _sendNotificationToRoles(
        'admin,accountant',
        'فاتورة مبيع جديدة',
        'أنشأ مندوب المبيعات فاتورة جديدة رقم #' + invoiceNumber + '.',
        'invoice.sales_created',
        invoiceId,
        {
          invoice_id: invoiceId,
          customer_id: customerId,
          event_id: 'sales_invoice.created:' + requestId
        }
      );
    }
    return {
      success: true,
      invoice_id: invoiceId,
      invoice_number: invoiceNumber,
      invoice: invoice,
      received_lines: received,
      refunded_lines: refunded,
      total_received_usd: settlement.total_received_usd,
      total_refunded_usd: settlement.total_refunded_usd,
      net_paid_usd: settlement.net_paid_usd,
      balance_due_usd: balanceDue,
      financial_status: financialStatus,
    };
  } catch (error) {
    const rollbackErrors = [];
    stockChanges.forEach(change => {
      try {
        _setProductStockQuantity_(change.code, change.before);
      } catch (rollbackError) {
        rollbackErrors.push(String(rollbackError));
      }
    });
    Array.from(new Set(boxKeysChanged)).reverse().forEach(key => {
      const parts = key.split(':');
      try {
        _restoreBoxBalance_(parts[0], parts[1], boxSnapshots[key]);
      } catch (rollbackError) {
        rollbackErrors.push(String(rollbackError));
      }
    });
    paymentIds.forEach(paymentId => {
      try {
        _deleteRowsByField_('Payments', 'payment_id', paymentId);
      } catch (rollbackError) {
        rollbackErrors.push(String(rollbackError));
      }
    });
    if (invoiceAdded) {
      try { _deleteRowsByField_('Sales_Invoices', 'invoice_id', invoiceId); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (itemsAdded) {
      try { _deleteRowsByField_('Sales_Invoice_Items', 'invoice_id', invoiceId); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (movementsAdded) {
      try { _deleteRowsByField_('Inventory_Movements', 'reference_id', invoiceId); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (auditAdded) {
      try { _deleteRowsByField_('Sales_Invoice_Audit', 'invoice_id', invoiceId); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (rollbackErrors.length) {
      Logger.log('Sales invoice v2 rollback failed for ' + invoiceId + ': ' + rollbackErrors.join('; '));
      throw _apiError(
        'SALES_ROLLBACK_FAILED',
        'تعذر التراجع الكامل عن الفاتورة؛ رقم العملية: ' + invoiceId + '، راجع سجل النظام',
        false
      );
    }
    throw error;
  } finally {
    lock.releaseLock();
  }
}

function _handleListSalesInvoices(body, user) {
  _needRole(user, ['admin', 'accountant', 'salesperson']);
  const role = _normalizeRole(user.role);
  const query = String(body.query || '').trim().toLowerCase();
  const from = body.from_date ? Date.parse(body.from_date) : -Infinity;
  const to = body.to_date ? Date.parse(body.to_date) : Infinity;
  if (isNaN(from) || isNaN(to) || from > to) {
    throw _apiError('INVALID_DATE_RANGE', 'نطاق التاريخ غير صالح', false);
  }
  const invoices = _all('Sales_Invoices').filter(invoice =>
    role !== 'salesperson' || String(invoice.seller_id) === String(user.user_id)
  ).filter(invoice =>
    (!body.status || String(invoice.status) === String(body.status)) &&
    (!body.payment_method ||
      String(invoice.payment_method) === String(body.payment_method)) &&
    (() => {
      const date = Date.parse(invoice.invoice_date || invoice.created_at || '');
      return Number.isFinite(date) && date >= from && date <= to;
    })() &&
    (!query || [
      invoice.invoice_id,
      invoice.buyer_name,
      invoice.buyer_phone,
      invoice.payment_method,
      invoice.status,
    ].join(' ').toLowerCase().includes(query))
  ).sort((a, b) => Date.parse(b.invoice_date || b.created_at) -
    Date.parse(a.invoice_date || a.created_at));
  return {
    invoices: invoices.map(invoice => ({
      ...invoice,
      items: _all('Sales_Invoice_Items').filter(item =>
        String(item.invoice_id) === String(invoice.invoice_id)
      ),
    })),
  };
}

function _handleVoidSalesInvoice(body, user) {
  const requestedInvoice = _all('Sales_Invoices').find(row =>
    String(row.invoice_id) === String(body.invoice_id || '').trim()
  );
  if (requestedInvoice && Number(requestedInvoice.payment_detail_version) >= 2) {
    return _handleVoidSalesInvoiceV2(body, user);
  }
  return _handleVoidSalesInvoiceLegacy(body, user);
}

function _handleVoidSalesInvoiceV2(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const invoiceId = String(body.invoice_id || '').trim();
  const reason = String(body.reason || '').trim();
  const requestId = String(body.client_request_id || '').trim();
  if (!invoiceId || reason.length < 3 || requestId.length < 12) {
    throw _apiError(
      'INVALID_VOID_REQUEST',
      'رقم الفاتورة وسبب الإلغاء ومعرف العملية مطلوبة',
      false
    );
  }
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) {
    throw _apiError('BUSY', 'جارٍ ترحيل عملية أخرى، حاول مجددًا', true);
  }
  const restoredStock = [];
  const movementIds = [];
  const releasedAllocationIds = [];
  let invoiceBefore = null;
  let invoiceUpdated = false;
  let auditAdded = false;
  let allocationAdded = false;
  try {
    const invoice = _all('Sales_Invoices').find(row =>
      String(row.invoice_id) === invoiceId
    );
    if (!invoice) {
      throw _apiError('INVOICE_NOT_FOUND', 'الفاتورة غير موجودة', false);
    }
    if (String(invoice.status) !== 'posted') {
      if (String(invoice.status) === 'voided' &&
          String(invoice.void_request_id || '') === requestId) {
        return { success: true, invoice_id: invoiceId, duplicate: true };
      }
      throw _apiError('INVOICE_NOT_POSTED', 'لا يمكن إلغاء فاتورة غير مرحلة', false);
    }
    const items = _all('Sales_Invoice_Items').filter(row =>
      String(row.invoice_id) === invoiceId
    );
    if (!items.length) {
      throw _apiError('INVOICE_ITEMS_MISSING', 'تفاصيل الفاتورة غير موجودة', false);
    }
    if (String(invoice.stock_source || '') !== 'central') {
      throw _apiError(
        'LEGACY_INVOICE_REVIEW_REQUIRED',
        'هذه فاتورة تاريخية بمصدر مخزون قديم؛ راجعها يدويًا قبل الإلغاء',
        false
      );
    }
    const allocations = _all('Sales_Invoice_Allocations').filter(row =>
      String(row.invoice_id) === invoiceId && Number(row.amount_usd) > 0
    );
    if (allocations.length) {
      _requireColumns_('Sales_Invoice_Allocations', [
        'receipt_id', 'invoice_id', 'customer_id', 'amount_usd',
      ]);
    }
    const now = _now();
    items.forEach(item => {
      const product = _all('Products').find(row =>
        String(row.code) === String(item.code)
      );
      if (!product) {
        throw _apiError('PRODUCT_NOT_FOUND', 'المادة غير موجودة: ' + item.code, false);
      }
      const before = Number(product.quantity || 0);
      const quantity = Number(item.quantity);
      if (!Number.isFinite(before) || !Number.isInteger(quantity) || quantity <= 0) {
        throw _apiError('INVALID_CENTRAL_STOCK', 'بيانات مخزون الفاتورة غير صالحة', false);
      }
      restoredStock.push({ code: item.code, before: before });
      _setProductStockQuantity_(item.code, before + quantity);
      const movementId = 'MV-' + Utilities.getUuid().replace(/-/g, '').slice(0, 12);
      _add('Inventory_Movements', {
        movement_id: movementId,
        code: item.code,
        type: 'sale_void',
        quantity: quantity,
        note: 'عكس فاتورة ' + invoiceId + ': ' + reason,
        created_by: user.user_id,
        created_at: now,
        reference_id: invoiceId,
        is_correction: 'true',
      });
      movementIds.push(movementId);
    });
    allocations.forEach(allocation => {
      const release = {
        allocation_id: 'AL-' + Utilities.getUuid().replace(/-/g, '').slice(0, 16),
        receipt_id: allocation.receipt_id,
        invoice_id: invoiceId,
        customer_id: invoice.customer_id,
        amount_usd: -Math.abs(Number(allocation.amount_usd)),
        created_by: user.user_id,
        created_at: now,
        client_request_id: requestId + ':release:' + allocation.allocation_id,
      };
      _add('Sales_Invoice_Allocations', release);
      releasedAllocationIds.push(release.allocation_id);
    });
    allocationAdded = allocations.length > 0;
    invoiceBefore = Object.assign({}, invoice);
    invoiceUpdated = _updateByField('Sales_Invoices', 'invoice_id', invoiceId, {
      status: 'voided',
      financial_status: 'voided',
      updated_at: now,
      modified_by: user.user_id,
      revision: Number(invoice.revision || 0) + 1,
      void_request_id: requestId,
      void_reason: reason,
    });
    if (!invoiceUpdated) throw new Error('تعذر تحديث حالة الفاتورة');
    _add('Sales_Invoice_Audit', {
      audit_id: Utilities.getUuid(),
      invoice_id: invoiceId,
      user_id: user.user_id,
      created_at: now,
      action: 'VOID_SALES_INVOICE_KEEP_RECEIPTS_AS_CUSTOMER_CREDIT',
      reason: reason,
      before_json: JSON.stringify(invoiceBefore),
      after_json: JSON.stringify({
        status: 'voided',
        cash_refunded: false,
        stock_restored: true,
        released_allocations: allocations.length,
      }),
    });
    auditAdded = true;
    return {
      success: true,
      invoice_id: invoiceId,
      status: 'voided',
      cash_refunded: false,
      message: 'عُكس المخزون وأُلغيت تخصيصات السداد؛ بقيت المقبوضات رصيدًا دائنًا للزبون ولم يُسجل رد نقدي.',
    };
  } catch (error) {
    const rollbackErrors = [];
    restoredStock.reverse().forEach(change => {
      try { _setProductStockQuantity_(change.code, change.before); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    });
    if (movementIds.length) {
      try {
        movementIds.forEach(id =>
          _deleteRowsByField_('Inventory_Movements', 'movement_id', id)
        );
      } catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (allocationAdded) {
      releasedAllocationIds.forEach(id => {
        try {
          _deleteRowsByField_('Sales_Invoice_Allocations', 'allocation_id', id);
        } catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
      });
    }
    if (invoiceUpdated && invoiceBefore) {
      try {
        _updateByField('Sales_Invoices', 'invoice_id', invoiceId, invoiceBefore);
      } catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (auditAdded) {
      try {
        const audits = _all('Sales_Invoice_Audit').filter(row =>
          String(row.invoice_id) === invoiceId &&
          String(row.action) === 'VOID_SALES_INVOICE_KEEP_RECEIPTS_AS_CUSTOMER_CREDIT'
        );
        audits.forEach(row =>
          _deleteRowsByField_('Sales_Invoice_Audit', 'audit_id', row.audit_id)
        );
      } catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (rollbackErrors.length) {
      Logger.log('Sales invoice void v2 rollback failed for ' + invoiceId + ': ' + rollbackErrors.join('; '));
      throw _apiError(
        'INVOICE_VOID_ROLLBACK_FAILED',
        'تعذر التراجع الكامل عن إلغاء الفاتورة؛ رقم العملية: ' + invoiceId,
        false
      );
    }
    throw error;
  } finally {
    lock.releaseLock();
  }
}

function _handleVoidSalesInvoiceLegacy(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const invoiceId = String(body.invoice_id || '').trim();
  const reason = String(body.reason || '').trim();
  if (!invoiceId || reason.length < 3) {
    throw _apiError('INVALID_VOID_REQUEST', 'رقم الفاتورة وسبب الإلغاء مطلوبان', false);
  }
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) {
    throw _apiError('BUSY', 'جارٍ ترحيل عملية أخرى، حاول مجددًا', true);
  }
  const restoredStock = [];
  const addedMovementIds = [];
  let invoiceBefore = null;
  let invoiceUpdated = false;
  let boxBefore = null;
  let boxUpdated = false;
  let refundPaymentId = '';
  let auditId = '';
  let boxId = '';
  let paymentCurrency = '';
  try {
    const invoice = _all('Sales_Invoices').find(row =>
      String(row.invoice_id) === invoiceId
    );
    if (!invoice) throw _apiError('INVOICE_NOT_FOUND', 'الفاتورة غير موجودة', false);
    if (String(invoice.status) !== 'posted') {
      throw _apiError('INVOICE_NOT_POSTED', 'لا يمكن إلغاء فاتورة غير مرحلة أو ملغاة', false);
    }
    const items = _all('Sales_Invoice_Items').filter(row =>
      String(row.invoice_id) === invoiceId
    );
    if (!items.length) throw _apiError('INVOICE_ITEMS_MISSING', 'تفاصيل الفاتورة غير موجودة', false);
    paymentCurrency = String(invoice.payment_currency || '');
    boxId = String(invoice.cash_box_id || '');
    const refundAmount = Number(invoice.net_received);
    if (!['USD', 'SYP'].includes(paymentCurrency) || !boxId ||
        !Number.isFinite(refundAmount) || refundAmount < 0) {
      throw _apiError('INVALID_INVOICE_PAYMENT', 'بيانات قبض الفاتورة غير صالحة', false);
    }
    const currentBox = _all('Boxes_Balance').find(row =>
      String(row.box_name) === boxId && String(row.currency) === paymentCurrency
    );
    boxBefore = currentBox ? Object.assign({}, currentBox) : null;
    if (refundAmount > 0 &&
        (!currentBox || Number(currentBox.balance || 0) < refundAmount)) {
      throw _apiError(
        'INSUFFICIENT_BOX_BALANCE',
        'رصيد صندوق التحصيل لا يكفي لعكس المقبوضات. يلزم تسوية الصندوق أولاً',
        false
      );
    }
    const account = _all('Users').find(row =>
      String(row.user_id) === String(invoice.seller_id)
    );
    const stockId = String(account && account.sales_stock_id || invoice.seller_id);
    const now = _now();
    items.forEach(item => {
      if (String(invoice.stock_source || '') === 'central') {
        const product = _all('Products').find(row =>
          String(row.code) === String(item.code)
        );
        if (!product) {
          throw _apiError('PRODUCT_NOT_FOUND', 'المادة غير موجودة: ' + item.code, false);
        }
        const before = Number(product.quantity || 0);
        const quantity = Number(item.quantity);
        if (!Number.isFinite(before) || !Number.isFinite(quantity) || quantity <= 0) {
          throw _apiError('INVALID_CENTRAL_STOCK', 'بيانات مخزون المادة غير صالحة', false);
        }
        restoredStock.push({
          source: 'central',
          code: item.code,
          before: before,
        });
        _setProductStockQuantity_(item.code, before + quantity);
      } else {
        const current = _all('Sales_Stock').find(row =>
          String(row.user_id) === stockId && String(row.code) === String(item.code)
        );
        if (!current) {
          throw _apiError(
            'SELLER_STOCK_ROW_MISSING',
            'تعذر عكس مخزون المندوب التاريخي للمادة ' + item.code,
            false
          );
        }
        const before = Number(current.quantity || 0);
        const quantity = Number(item.quantity);
        if (!Number.isFinite(before) || !Number.isFinite(quantity) || quantity <= 0) {
          throw _apiError('INVALID_SELLER_STOCK', 'رصيد المندوب التاريخي غير صالح', false);
        }
        restoredStock.push({
          source: 'legacy_seller',
          stockId: stockId,
          code: item.code,
          before: before,
        });
        _setSalesStockQuantity_(stockId, item.code, before + quantity);
      }
      const movementId = 'MV-' + Utilities.getUuid().replace(/-/g, '').slice(0, 12);
      _add('Inventory_Movements', {
        movement_id: movementId,
        code: item.code,
        type: 'sale_void',
        quantity: Number(item.quantity),
        note: 'عكس فاتورة ' + invoiceId + ': ' + reason,
        created_by: user.user_id,
        created_at: now,
        reference_id: invoiceId,
        is_correction: 'true',
      });
      addedMovementIds.push(movementId);
    });
    if (refundAmount > 0) {
      refundPaymentId = 'SV-' + Utilities.getUuid().replace(/-/g, '').toUpperCase();
      _add('Payments', {
        payment_id: refundPaymentId,
        customer_id: invoice.customer_id,
        order_id: invoiceId,
        amount: refundAmount,
        currency: paymentCurrency,
        box_type: boxId,
        method: 'invoice_void_refund',
        payment_date: now,
        note: 'عكس قبض فاتورة ' + invoiceId + ': ' + reason,
        created_by: user.user_id,
        created_at: now,
        action_type: 'pay',
        payment_method: 'invoice_void_refund',
        invoice_currency: invoice.currency,
        invoice_equivalent: invoice.net_total,
        exchange_rate: invoice.rate_syp_per_usd,
        reference: invoice.payment_reference || '',
        client_request_id: invoice.client_request_id + ':void',
      });
      boxUpdated = true;
      _updateBoxBalance(boxId, paymentCurrency, refundAmount, 'pay');
    }
    invoiceBefore = Object.assign({}, invoice);
    invoiceUpdated = _updateByField('Sales_Invoices', 'invoice_id', invoiceId, {
      status: 'voided',
      updated_at: now,
      modified_by: user.user_id,
      revision: Number(invoice.revision || 0) + 1,
    });
    if (!invoiceUpdated) throw new Error('تعذر تحديث حالة الفاتورة');
    auditId = Utilities.getUuid();
    _add('Sales_Invoice_Audit', {
      audit_id: auditId,
      invoice_id: invoiceId,
      user_id: user.user_id,
      created_at: now,
      action: 'VOID_POSTED_CASH_SALE',
      reason: reason,
      before_json: JSON.stringify(invoice),
      after_json: JSON.stringify({
        invoice_id: invoiceId,
        status: 'voided',
        refund_payment_id: refundPaymentId,
      }),
    });
    return { success: true, invoice_id: invoiceId, status: 'voided' };
  } catch (error) {
    const rollbackErrors = [];
    [...restoredStock].reverse().forEach(change => {
      try {
        if (change.source === 'central') {
          _setProductStockQuantity_(change.code, change.before);
        } else {
          _setSalesStockQuantity_(change.stockId, change.code, change.before);
        }
      } catch (rollbackError) {
        rollbackErrors.push(String(rollbackError));
      }
    });
    const rollbackSteps = [
      () => {
        if (boxUpdated) _restoreBoxBalance_(boxId, paymentCurrency, boxBefore);
      },
      () => {
        if (invoiceUpdated && invoiceBefore) {
          _updateByField('Sales_Invoices', 'invoice_id', invoiceId, invoiceBefore);
        }
      },
      () => {
        if (refundPaymentId) {
          _deleteRowsByField_('Payments', 'payment_id', refundPaymentId);
        }
      },
      () => {
        addedMovementIds.forEach(id =>
          _deleteRowsByField_('Inventory_Movements', 'movement_id', id)
        );
      },
      () => {
        if (auditId) _deleteRowsByField_('Sales_Invoice_Audit', 'audit_id', auditId);
      },
    ];
    rollbackSteps.forEach(step => {
      try {
        step();
      } catch (rollbackError) {
        rollbackErrors.push(String(rollbackError));
      }
    });
    if (rollbackErrors.length) {
      Logger.log('Sales invoice void rollback failed for ' + invoiceId + ': ' + rollbackErrors.join('; '));
      throw _apiError(
        'SALES_VOID_ROLLBACK_FAILED',
        'تعذر إكمال التراجع عن إلغاء الفاتورة. رقم العملية: ' + invoiceId,
        false
      );
    }
    throw error;
  } finally {
    lock.releaseLock();
  }
}

function _handleSalesSummary(body, user) {
  _needRole(user, ['admin', 'accountant', 'manager', 'salesperson']);
  const role = _normalizeRole(user.role);
  const from = body.from_date ? Date.parse(body.from_date) : -Infinity;
  const to = body.to_date ? Date.parse(body.to_date) : Infinity;
  if (isNaN(from) || isNaN(to) || from > to) {
    throw _apiError('INVALID_DATE_RANGE', 'نطاق التاريخ غير صالح', false);
  }
  const invoices = _all('Sales_Invoices').filter(invoice => {
    const date = Date.parse(invoice.invoice_date || invoice.created_at || '');
    return invoice.status === 'posted' &&
      (role !== 'salesperson' || String(invoice.seller_id) === String(user.user_id)) &&
      (!body.seller_id || String(invoice.seller_id) === String(body.seller_id)) &&
      (!body.customer_id || String(invoice.customer_id) === String(body.customer_id)) &&
      Number.isFinite(date) && date >= from && date <= to;
  });
  const totals = {};
  const receipts = {};
  const financial = { paid_usd: 0, outstanding_usd: 0, partial_count: 0, unpaid_count: 0 };
  invoices.forEach(invoice => {
    const currency = String(invoice.currency || 'USD');
    totals[currency] = (totals[currency] || 0) + Number(invoice.net_total || 0);
    const paymentCurrency = String(invoice.payment_currency || currency);
    const key = paymentCurrency + ':' + String(invoice.payment_method || 'unknown');
    receipts[key] = (receipts[key] || 0) + Number(
      invoice.net_received ?? invoice.amount_received ?? 0
    );
    const paymentSummary = _salesInvoicePaymentSummary_(invoice);
    financial.paid_usd += paymentSummary.total_paid_usd;
    financial.outstanding_usd += Math.max(0, paymentSummary.balance_due_usd);
    if (paymentSummary.financial_status === 'partial') financial.partial_count++;
    if (paymentSummary.financial_status === 'unpaid') financial.unpaid_count++;
  });
  return {
    invoices_count: invoices.length,
    sales_by_invoice_currency: totals,
    receipts_by_payment_currency_and_method: receipts,
    financial_summary_usd: financial,
  };
}

function _paymentEquivalentUsd_(payment) {
  if (String(payment.invoice_currency || '').toUpperCase() === 'USD' &&
      payment.invoice_equivalent !== '' &&
      payment.invoice_equivalent !== null &&
      payment.invoice_equivalent !== undefined) {
    const saved = Number(payment.invoice_equivalent);
    if (Number.isFinite(saved)) return saved;
  }
  const amount = Number(payment.amount);
  if (!Number.isFinite(amount)) return null;
  const currency = String(payment.currency || '').toUpperCase();
  if (currency === 'USD') return amount;
  const rate = Number(payment.exchange_rate);
  if (currency === 'SYP' && Number.isFinite(rate) && rate > 0) {
    return _roundSalesAmount_(amount / rate, 'USD');
  }
  return null;
}

function _salesInvoicePaymentSummary_(invoice) {
  const payments = _all('Payments').filter(payment =>
    String(payment.order_id || '') === String(invoice.invoice_id)
  );
  const allocations = _all('Sales_Invoice_Allocations').filter(allocation =>
    String(allocation.invoice_id) === String(invoice.invoice_id)
  );
  let netPaid = 0;
  let needsReview = false;
  payments.forEach(payment => {
    const equivalent = _paymentEquivalentUsd_(payment);
    if (equivalent === null) {
      needsReview = true;
      return;
    }
    netPaid += String(payment.action_type || 'receive') === 'pay'
      ? -equivalent : equivalent;
  });
  allocations.forEach(allocation => {
    const amount = Number(allocation.amount_usd);
    if (Number.isFinite(amount)) netPaid += amount;
    else needsReview = true;
  });
  if (!payments.length && Number.isFinite(Number(invoice.net_received))) {
    netPaid = Number(invoice.net_received);
  }
  const netTotal = Number(invoice.net_total || 0);
  const balance = _roundSalesAmount_(netTotal - netPaid, 'USD');
  let financialStatus = balance <= 0.005 ? 'paid' : netPaid > 0 ? 'partial' : 'unpaid';
  if (String(invoice.status) === 'voided') financialStatus = 'voided';
  return {
    total_paid_usd: _roundSalesAmount_(netPaid, 'USD'),
    balance_due_usd: balance,
    financial_status: financialStatus,
    needs_financial_review: needsReview,
  };
}

function _handleListSalesInvoicesV2(body, user) {
  _needRole(user, ['admin', 'accountant', 'manager', 'salesperson']);
  const role = _normalizeRole(user.role);
  const query = String(body.query || '').trim().toLowerCase();
  const from = body.from_date ? Date.parse(body.from_date) : -Infinity;
  const to = body.to_date ? Date.parse(body.to_date) : Infinity;
  if (isNaN(from) || isNaN(to) || from > to) {
    throw _apiError('INVALID_DATE_RANGE', 'نطاق التاريخ غير صالح', false);
  }
  const customers = _all('Customers');
  const users = _all('Users');
  const invoiceShipments = _all('Shipments');
  const shipmentSummaryByInvoice = {};
  invoiceShipments.forEach(shipment => {
    const invoiceId = String(shipment.invoice_id || '');
    if (!invoiceId) return;
    const summary = _shipmentPackageSummary_(shipment);
    if (summary === 'لا توجد طرود مسجلة') return;
    if (!shipmentSummaryByInvoice[invoiceId]) {
      shipmentSummaryByInvoice[invoiceId] = [];
    }
    shipmentSummaryByInvoice[invoiceId].push(summary);
  });
  let invoices = _all('Sales_Invoices').filter(invoice =>
    role !== 'salesperson' || String(invoice.seller_id) === String(user.user_id)
  );
  invoices = invoices.filter(invoice => {
    const date = Date.parse(invoice.invoice_date || invoice.created_at || '');
    const customer = customers.find(row =>
      String(row.customer_id) === String(invoice.customer_id)
    );
    const seller = users.find(row =>
      String(row.user_id) === String(invoice.seller_id)
    );
    const summary = _salesInvoicePaymentSummary_(invoice);
    invoice._calculated_financial = summary;
    const paymentMatches = !body.payment_method ||
      _all('Payments').some(payment =>
        String(payment.order_id || '') === String(invoice.invoice_id) &&
        String(payment.payment_method || payment.method || '') === String(body.payment_method)
      );
    return (!body.status || String(invoice.status) === String(body.status)) &&
      (!body.financial_status ||
        summary.financial_status === String(body.financial_status)) &&
      (!body.customer_id ||
        String(invoice.customer_id) === String(body.customer_id)) &&
      (!body.seller_id || String(invoice.seller_id) === String(body.seller_id)) &&
      paymentMatches &&
      Number.isFinite(date) && date >= from && date <= to &&
      (!query || [
        invoice.invoice_number,
        invoice.invoice_id,
        invoice.customer_name,
        customer && customer.full_name,
        invoice.buyer_name,
        invoice.buyer_phone,
        invoice.payment_method,
        invoice.status,
        seller && seller.full_name,
      ].join(' ').toLowerCase().includes(query));
  }).sort((a, b) =>
    Date.parse(b.invoice_date || b.created_at) -
    Date.parse(a.invoice_date || a.created_at)
  );
  return {
    invoices: invoices.map(invoice => {
      const summary = invoice._calculated_financial ||
        _salesInvoicePaymentSummary_(invoice);
      delete invoice._calculated_financial;
      const customer = customers.find(row =>
        String(row.customer_id) === String(invoice.customer_id)
      );
      const seller = users.find(row =>
        String(row.user_id) === String(invoice.seller_id)
      );
      const creator = users.find(row =>
        String(row.user_id) === String(invoice.created_by || invoice.seller_id)
      );
      const shipmentSummary =
        (shipmentSummaryByInvoice[String(invoice.invoice_id)] || []).join('؛ ');
      return Object.assign({}, invoice, summary, {
        customer_name: customer ? customer.full_name : invoice.customer_name,
        seller_name: seller ? seller.full_name : String(invoice.seller_id || ''),
        creator_name: creator
          ? creator.full_name
          : String(invoice.created_by || invoice.seller_id || ''),
        creator_role: _normalizeRole(
          invoice.created_by_role || (creator && creator.role) || ''
        ),
        shipment_summary: shipmentSummary,
        items: _all('Sales_Invoice_Items').filter(item =>
          String(item.invoice_id) === String(invoice.invoice_id)
        ),
        payments: _all('Payments').filter(payment =>
          String(payment.order_id || '') === String(invoice.invoice_id)
        ),
      });
    }),
  };
}

function _handleCreateCustomerReceipt(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const requestId = String(body.client_request_id || '').trim();
  const customerId = String(body.customer_id || '').trim();
  if (requestId.length < 12 || requestId.length > 100 || !customerId) {
    throw _apiError('INVALID_RECEIPT', 'معرف العملية والزبون مطلوبان', false);
  }
  const lines = _normalizeSalesPaymentLines_(body.received_lines, {
    label: 'القبض',
  });
  if (!lines.length) {
    throw _apiError('INVALID_RECEIPT', 'أضف مبلغًا واحدًا على الأقل إلى سند القبض', false);
  }
  const totalUsd = _roundSalesAmount_(
    lines.reduce((sum, line) => sum + line.equivalent_usd, 0),
    'USD'
  );
  const allocations = Array.isArray(body.allocations) ? body.allocations : [];
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) {
    throw _apiError('BUSY', 'جارٍ ترحيل عملية أخرى، حاول مجددًا', true);
  }
  const receiptId = 'RC-' + Utilities.getUuid().replace(/-/g, '').toUpperCase();
  const paymentIds = [];
  const boxSnapshots = {};
  const changedBoxes = [];
  let allocationRowsAdded = false;
  let auditAdded = false;
  try {
    const existingReceipt = _all('Payments').find(payment =>
      String(payment.receipt_id || '') === requestId ||
      String(payment.client_request_id || '').startsWith(requestId + ':')
    );
    if (existingReceipt) {
      if (String(existingReceipt.customer_id) !== customerId) {
        throw _apiError('IDEMPOTENCY_KEY_CONFLICT', 'معرف سند القبض مستخدم لزبون آخر', false);
      }
      return {
        success: true,
        receipt_id: existingReceipt.receipt_id || existingReceipt.payment_id,
        duplicate: true,
      };
    }
    const customer = _all('Customers').find(row =>
      String(row.customer_id) === customerId &&
      !['inactive', 'deleted'].includes(String(row.status || '').toLowerCase())
    );
    if (!customer || customerId === 'CUS-SHOP') {
      throw _apiError(
        'CUSTOMER_REQUIRED',
        'سند القبض المستقل يتطلب سجل زبون محددًا، ولا يسجل على «زبائن محل»',
        false
      );
    }
    _requireColumns_('Payments', ['receipt_id', 'invoice_equivalent']);
    _requireColumns_('Sales_Invoice_Allocations', [
      'receipt_id', 'invoice_id', 'customer_id', 'amount_usd',
    ]);
    let allocationTotal = 0;
    const seenInvoices = {};
    const validAllocations = allocations.map(row => {
      const invoiceId = String(row.invoice_id || '').trim();
      const amountUsd = _roundSalesAmount_(
        _salesPositiveNumber_(row.amount_usd, 'مبلغ التخصيص بالدولار'),
        'USD'
      );
      if (!invoiceId || seenInvoices[invoiceId]) {
        throw _apiError('INVALID_ALLOCATION', 'الفاتورة مفقودة أو مكررة في التخصيص', false);
      }
      seenInvoices[invoiceId] = true;
      const invoice = _all('Sales_Invoices').find(entry =>
        String(entry.invoice_id) === invoiceId &&
        String(entry.customer_id) === customerId &&
        String(entry.status) === 'posted' &&
        String(entry.currency || '').toUpperCase() === 'USD'
      );
      if (!invoice) {
        throw _apiError('INVALID_ALLOCATION', 'الفاتورة المحددة لا تخص هذا الزبون أو ليست قابلة للتخصيص', false);
      }
      const summary = _salesInvoicePaymentSummary_(invoice);
      if (summary.needs_financial_review ||
          amountUsd - summary.balance_due_usd > 0.005) {
        throw _apiError('ALLOCATION_EXCEEDS_BALANCE', 'التخصيص يتجاوز الرصيد المستحق على الفاتورة', false);
      }
      allocationTotal += amountUsd;
      return { invoice_id: invoiceId, amount_usd: amountUsd };
    });
    if (allocationTotal - totalUsd > 0.005) {
      throw _apiError('ALLOCATION_EXCEEDS_RECEIPT', 'مجموع التخصيص يتجاوز قيمة سند القبض', false);
    }
    const unapplied = _roundSalesAmount_(totalUsd - allocationTotal, 'USD');
    if (unapplied > 0.005 && body.confirm_customer_credit !== true) {
      throw _apiError(
        'CUSTOMER_CREDIT_CONFIRMATION_REQUIRED',
        'يوجد مبلغ غير مخصص؛ أكد تسجيله رصيدًا دائنًا للزبون',
        false
      );
    }
    const now = _now();
    const paymentRecords = [];
    lines.forEach((line, index) => {
      const key = line.box + ':' + line.currency;
      if (!Object.prototype.hasOwnProperty.call(boxSnapshots, key)) {
        boxSnapshots[key] = _cashBoxSnapshot_(line.box, line.currency);
      }
      changedBoxes.push(key);
      const payment = _writeSalesPayment_(line, {
        customer_id: customerId,
        invoice_id: '',
        receipt_id: receiptId,
        payment_date: String(body.payment_date || now),
        created_at: now,
        user_id: user.user_id,
        action_type: 'receive',
        note: String(body.note || '').trim(),
        client_request_id: requestId + ':' + index,
      });
      paymentIds.push(payment.payment_id);
      paymentRecords.push(payment);
    });
    let lineIndex = 0;
    let remainingOnLine = Number(paymentRecords[0]?.invoice_equivalent || 0);
    validAllocations.forEach(allocation => {
      let allocationRemaining = allocation.amount_usd;
      while (allocationRemaining > 0.005) {
        const payment = paymentRecords[lineIndex];
        if (!payment) {
          throw _apiError('ALLOCATION_EXCEEDS_RECEIPT', 'تعذر ربط التخصيص بحركات السند', false);
        }
        const part = Math.min(allocationRemaining, remainingOnLine);
        _add('Sales_Invoice_Allocations', {
          allocation_id: 'AL-' + Utilities.getUuid().replace(/-/g, '').slice(0, 16),
          receipt_id: receiptId,
          invoice_id: allocation.invoice_id,
          customer_id: customerId,
          amount_usd: _roundSalesAmount_(part, 'USD'),
          created_by: user.user_id,
          created_at: now,
          client_request_id: requestId,
        });
        allocationRowsAdded = true;
        allocationRemaining = _roundSalesAmount_(allocationRemaining - part, 'USD');
        remainingOnLine = _roundSalesAmount_(remainingOnLine - part, 'USD');
        if (remainingOnLine <= 0.005) {
          lineIndex++;
          remainingOnLine = lineIndex < paymentRecords.length
            ? Number(paymentRecords[lineIndex].invoice_equivalent || 0) : 0;
        }
      }
    });
    _add('Audit_Log', {
      log_id: Utilities.getUuid(),
      user_id: user.user_id,
      action: 'CREATE_CUSTOMER_RECEIPT',
      entity: 'Payments',
      entity_id: receiptId,
      details: JSON.stringify({
        customer_id: customerId,
        total_usd: totalUsd,
        unapplied_credit_usd: unapplied,
        request_id: requestId,
      }),
      created_at: now,
    });
    auditAdded = true;
    return {
      success: true,
      receipt_id: receiptId,
      payment_ids: paymentIds,
      total_usd: totalUsd,
      unapplied_credit_usd: unapplied,
    };
  } catch (error) {
    const rollbackErrors = [];
    Array.from(new Set(changedBoxes)).reverse().forEach(key => {
      const parts = key.split(':');
      try { _restoreBoxBalance_(parts[0], parts[1], boxSnapshots[key]); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    });
    paymentIds.forEach(paymentId => {
      try { _deleteRowsByField_('Payments', 'payment_id', paymentId); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    });
    if (allocationRowsAdded) {
      try { _deleteRowsByField_('Sales_Invoice_Allocations', 'receipt_id', receiptId); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (auditAdded) {
      try { _deleteRowsByField_('Audit_Log', 'entity_id', receiptId); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (rollbackErrors.length) {
      Logger.log('Customer receipt rollback failed for ' + receiptId + ': ' + rollbackErrors.join('; '));
      throw _apiError('RECEIPT_ROLLBACK_FAILED', 'تعذر التراجع الكامل عن سند القبض؛ رقم السند: ' + receiptId, false);
    }
    throw error;
  } finally {
    lock.releaseLock();
  }
}

function _handleCollectSalesInvoice(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'salesperson']);
  const invoiceId = String(body.invoice_id || '').trim();
  const requestId = String(body.client_request_id || '').trim();
  if (!invoiceId || requestId.length < 12 || requestId.length > 100) {
    throw _apiError(
      'INVALID_INVOICE_COLLECTION',
      'رقم الفاتورة ومعرف عملية التحصيل مطلوبان',
      false
    );
  }
  const lines = _normalizeSalesPaymentLines_(body.received_lines, {
    label: 'التحصيل',
  });
  if (!lines.length) {
    throw _apiError('INVALID_INVOICE_COLLECTION', 'أضف مبلغًا واحدًا على الأقل', false);
  }

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) {
    throw _apiError('BUSY', 'جارٍ ترحيل عملية أخرى، حاول مجددًا', true);
  }
  const paymentIds = [];
  const boxSnapshots = {};
  const changedBoxes = [];
  let invoiceBefore = null;
  let invoiceUpdated = false;
  let auditAdded = false;
  let auditId = '';
  try {
    const duplicate = _all('Payments').find(payment =>
      String(payment.client_request_id || '').startsWith(requestId + ':collect:')
    );
    if (duplicate) {
      if (String(duplicate.order_id || '') !== invoiceId) {
        throw _apiError(
          'IDEMPOTENCY_KEY_CONFLICT',
          'معرف العملية مستخدم لتحصيل فاتورة أخرى',
          false
        );
      }
      const current = _all('Sales_Invoices').find(row =>
        String(row.invoice_id) === invoiceId
      );
      return {
        success: true,
        invoice_id: invoiceId,
        duplicate: true,
        ...(current ? _salesInvoicePaymentSummary_(current) : {}),
      };
    }

    const invoice = _all('Sales_Invoices').find(row =>
      String(row.invoice_id) === invoiceId
    );
    if (!invoice || String(invoice.status) !== 'posted' ||
        String(invoice.currency || '').toUpperCase() !== 'USD') {
      throw _apiError(
        'INVOICE_NOT_COLLECTIBLE',
        'الفاتورة غير موجودة أو غير مرحلة أو عملتها تحتاج مراجعة',
        false
      );
    }
    if (_normalizeRole(user.role) === 'salesperson' &&
        String(invoice.seller_id) !== String(user.user_id)) {
      throw _apiError(
        'ROLE_NOT_ALLOWED',
        'يمكن للمندوب تسجيل التحصيل على فواتيره فقط',
        false
      );
    }
    const customer = _all('Customers').find(row =>
      String(row.customer_id) === String(invoice.customer_id) &&
      !['inactive', 'deleted'].includes(String(row.status || '').toLowerCase())
    );
    if (!customer) {
      throw _apiError('CUSTOMER_NOT_FOUND', 'سجل زبون الفاتورة غير موجود أو غير فعال', false);
    }
    const beforeSummary = _salesInvoicePaymentSummary_(invoice);
    if (beforeSummary.needs_financial_review) {
      throw _apiError(
        'FINANCIAL_REVIEW_REQUIRED',
        'تحتوي الفاتورة على حركات تاريخية تحتاج مراجعة قبل تسجيل تحصيل جديد',
        false
      );
    }
    const collectedUsd = _roundSalesAmount_(
      lines.reduce((sum, line) => sum + line.equivalent_usd, 0),
      'USD'
    );
    const newBalance = _roundSalesAmount_(
      beforeSummary.balance_due_usd - collectedUsd,
      'USD'
    );
    if (newBalance < -0.005 &&
        (String(invoice.customer_id) === 'CUS-SHOP' ||
         body.confirm_customer_credit !== true)) {
      throw _apiError(
        'CUSTOMER_CREDIT_CONFIRMATION_REQUIRED',
        'يتجاوز التحصيل المتبقي؛ أكد رصيدًا دائنًا لزبون محدد أو عدل المبلغ',
        false
      );
    }
    _requireColumns_('Payments', ['receipt_id', 'invoice_equivalent']);
    _requireColumns_('Sales_Invoices', [
      'financial_status', 'balance_due_usd', 'total_received_usd',
      'total_refunded_usd', 'net_paid_usd',
    ]);

    const now = _now();
    lines.forEach((line, index) => {
      const key = line.box + ':' + line.currency;
      if (!Object.prototype.hasOwnProperty.call(boxSnapshots, key)) {
        boxSnapshots[key] = _cashBoxSnapshot_(line.box, line.currency);
      }
      changedBoxes.push(key);
      const payment = _writeSalesPayment_(line, {
        customer_id: invoice.customer_id,
        invoice_id: invoiceId,
        receipt_id: '',
        payment_date: String(body.payment_date || now),
        created_at: now,
        user_id: user.user_id,
        action_type: 'receive',
        note: String(body.note || '').trim(),
        client_request_id: requestId + ':collect:' + index,
      });
      paymentIds.push(payment.payment_id);
    });

    const afterSummary = _salesInvoicePaymentSummary_(invoice);
    invoiceBefore = Object.assign({}, invoice);
    invoiceUpdated = _updateByField('Sales_Invoices', 'invoice_id', invoiceId, {
      total_received_usd: Number(invoice.total_received_usd || 0) + collectedUsd,
      net_paid_usd: afterSummary.total_paid_usd,
      balance_due_usd: afterSummary.balance_due_usd,
      financial_status: afterSummary.financial_status,
      updated_at: now,
      modified_by: user.user_id,
      revision: Number(invoice.revision || 0) + 1,
    });
    if (!invoiceUpdated) throw new Error('تعذر تحديث حالة السداد');
    auditId = Utilities.getUuid();
    _add('Sales_Invoice_Audit', {
      audit_id: auditId,
      invoice_id: invoiceId,
      user_id: user.user_id,
      created_at: now,
      action: 'COLLECT_SALES_INVOICE',
      reason: String(body.note || '').trim(),
      before_json: JSON.stringify(beforeSummary),
      after_json: JSON.stringify({
        summary: afterSummary,
        payment_ids: paymentIds,
      }),
    });
    auditAdded = true;
    return {
      success: true,
      invoice_id: invoiceId,
      payment_ids: paymentIds,
      total_collected_usd: collectedUsd,
      ...afterSummary,
    };
  } catch (error) {
    const rollbackErrors = [];
    Array.from(new Set(changedBoxes)).reverse().forEach(key => {
      const parts = key.split(':');
      try {
        _restoreBoxBalance_(parts[0], parts[1], boxSnapshots[key]);
      } catch (rollbackError) {
        rollbackErrors.push(String(rollbackError));
      }
    });
    paymentIds.forEach(paymentId => {
      try { _deleteRowsByField_('Payments', 'payment_id', paymentId); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    });
    if (invoiceUpdated && invoiceBefore) {
      try {
        _updateByField('Sales_Invoices', 'invoice_id', invoiceId, invoiceBefore);
      } catch (rollbackError) {
        rollbackErrors.push(String(rollbackError));
      }
    }
    if (auditAdded) {
      try {
        _deleteRowsByField_('Sales_Invoice_Audit', 'audit_id', auditId);
      } catch (rollbackError) {
        rollbackErrors.push(String(rollbackError));
      }
    }
    if (rollbackErrors.length) {
      Logger.log(
        'Invoice collection rollback failed for ' + invoiceId + ': ' +
          rollbackErrors.join('; ')
      );
      throw _apiError(
        'COLLECTION_ROLLBACK_FAILED',
        'تعذر التراجع الكامل عن التحصيل؛ رقم الفاتورة: ' + invoiceId,
        false
      );
    }
    throw error;
  } finally {
    lock.releaseLock();
  }
}

function _handleAllocateCustomerReceipt(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const receiptId = String(body.receipt_id || '').trim();
  const invoiceId = String(body.invoice_id || '').trim();
  const requestId = String(body.client_request_id || '').trim();
  const amountUsd = _roundSalesAmount_(
    _salesPositiveNumber_(body.amount_usd, 'مبلغ التخصيص بالدولار'),
    'USD'
  );
  if (!receiptId || !invoiceId || requestId.length < 12) {
    throw _apiError('INVALID_ALLOCATION', 'رقم السند والفاتورة ومعرف العملية مطلوبة', false);
  }
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) {
    throw _apiError('BUSY', 'جارٍ ترحيل عملية أخرى، حاول مجددًا', true);
  }
  try {
    const duplicate = _all('Sales_Invoice_Allocations').find(row =>
      String(row.client_request_id) === requestId
    );
    if (duplicate) {
      return { success: true, allocation_id: duplicate.allocation_id, duplicate: true };
    }
    const payments = _all('Payments').filter(row =>
      String(row.receipt_id || '') === receiptId &&
      String(row.action_type || '') === 'receive'
    );
    if (!payments.length) {
      throw _apiError('RECEIPT_NOT_FOUND', 'سند القبض غير موجود أو غير قابل للتخصيص', false);
    }
    const customerId = String(payments[0].customer_id || '');
    if (!customerId || payments.some(row =>
      String(row.customer_id) !== customerId
    )) {
      throw _apiError('INVALID_RECEIPT', 'حركات السند لا تتبع زبونًا واحدًا', false);
    }
    const invoice = _all('Sales_Invoices').find(row =>
      String(row.invoice_id) === invoiceId &&
      String(row.customer_id) === customerId &&
      String(row.status) === 'posted' &&
      String(row.currency || '').toUpperCase() === 'USD'
    );
    if (!invoice) {
      throw _apiError('INVALID_ALLOCATION', 'الفاتورة لا تخص زبون سند القبض أو ليست بالدولار', false);
    }
    const alreadyAllocated = _all('Sales_Invoice_Allocations')
      .filter(row => String(row.receipt_id) === receiptId)
      .reduce((sum, row) => sum + Number(row.amount_usd || 0), 0);
    const receiptTotal = payments.reduce((sum, row) =>
      sum + Number(_paymentEquivalentUsd_(row) || 0), 0);
    const summary = _salesInvoicePaymentSummary_(invoice);
    if (summary.needs_financial_review ||
        amountUsd - summary.balance_due_usd > 0.005 ||
        amountUsd + alreadyAllocated - receiptTotal > 0.005) {
      throw _apiError('ALLOCATION_EXCEEDS_BALANCE', 'التخصيص يتجاوز رصيد الفاتورة أو المتبقي من السند', false);
    }
    const allocation = {
      allocation_id: 'AL-' + Utilities.getUuid().replace(/-/g, '').slice(0, 16),
      receipt_id: receiptId,
      invoice_id: invoiceId,
      customer_id: customerId,
      amount_usd: amountUsd,
      created_by: user.user_id,
      created_at: _now(),
      client_request_id: requestId,
    };
    _add('Sales_Invoice_Allocations', allocation);
    _add('Audit_Log', {
      log_id: Utilities.getUuid(),
      user_id: user.user_id,
      action: 'ALLOCATE_EXISTING_CUSTOMER_RECEIPT',
      entity: 'Sales_Invoice_Allocations',
      entity_id: allocation.allocation_id,
      details: JSON.stringify(allocation),
      created_at: allocation.created_at,
    });
    return { success: true, allocation_id: allocation.allocation_id };
  } finally {
    lock.releaseLock();
  }
}

function _handleCashBoxStatement(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const boxName = String(body.box_name || '').trim();
  const currency = String(body.currency || '').trim().toUpperCase();
  if (!['cash_box', 'sham_cash'].includes(boxName) ||
      !['USD', 'SYP'].includes(currency)) {
    throw _apiError('INVALID_CASH_BOX', 'حدد صندوقًا وعملة صالحين', false);
  }
  const box = _cashBoxSnapshot_(boxName, currency);
  const rows = _all('Payments').filter(payment =>
    String(payment.box_type) === boxName &&
    String(payment.currency).toUpperCase() === currency
  ).map(payment => ({
    payment_id: payment.payment_id,
    customer_id: payment.customer_id || '',
    invoice_id: payment.order_id || '',
    receipt_id: payment.receipt_id || '',
    date: payment.payment_date || payment.created_at,
    action_type: payment.action_type || 'receive',
    method: payment.payment_method || payment.method || '',
    amount: Number(payment.amount || 0),
    currency: currency,
    equivalent_usd: _paymentEquivalentUsd_(payment),
    exchange_rate: payment.exchange_rate || '',
    reference: payment.reference || '',
    note: payment.note || '',
  })).sort((a, b) => Date.parse(a.date || 0) - Date.parse(b.date || 0));
  return {
    box_name: boxName,
    currency: currency,
    balance: Number(box ? box.balance || 0 : 0),
    movements: rows,
    needs_manual_review: rows.some(row =>
      row.currency === 'SYP' && row.equivalent_usd === null
    ),
  };
}

function _handleCashBoxOpeningBalance(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const boxName = String(body.box_name || '').trim();
  const currency = String(body.currency || '').trim().toUpperCase();
  const amount = Number(body.amount);
  const reason = String(body.reason || '').trim();
  const requestId = String(body.client_request_id || '').trim();
  const rate = body.exchange_rate === '' || body.exchange_rate === undefined ||
    body.exchange_rate === null ? null : Number(body.exchange_rate);
  if (!['cash_box', 'sham_cash'].includes(boxName) ||
      !['USD', 'SYP'].includes(currency) ||
      !Number.isFinite(amount) || amount < 0 ||
      reason.length < 3 || requestId.length < 12 ||
      (currency === 'SYP' && amount > 0 &&
        rate !== null && (!Number.isFinite(rate) || rate <= 0))) {
    throw _apiError(
      'INVALID_OPENING_BALANCE',
      'الصندوق والعملة والرصيد الافتتاحي والسبب ومعرف العملية مطلوبة',
      false
    );
  }
  const rounded = _roundSalesAmount_(amount, currency);
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) {
    throw _apiError('BUSY', 'جارٍ تحديث الصناديق، حاول مجددًا', true);
  }
  let boxAdded = false;
  let paymentId = '';
  let auditId = '';
  try {
    const priorPayment = _all('Payments').find(payment =>
      String(payment.client_request_id || '') === requestId
    );
    if (priorPayment) {
      return { success: true, duplicate: true, payment_id: priorPayment.payment_id };
    }
    const auditExists = _all('Audit_Log').some(row =>
      String(row.action) === 'OPEN_CASH_BOX' &&
      String(row.entity_id) === boxName + ':' + currency &&
      String(row.details || '').includes(requestId)
    );
    if (auditExists) return { success: true, duplicate: true };
    if (_cashBoxSnapshot_(boxName, currency)) {
      throw _apiError(
        'CASH_BOX_ALREADY_INITIALIZED',
        'للصندوق رصيد أو سجل سابق؛ لا يجوز استبداله برصيد افتتاحي. استخدم حركة تسوية موثقة.',
        false
      );
    }
    _requireColumns_('Boxes_Balance', [
      'box_id', 'box_name', 'currency', 'balance', 'last_updated',
    ]);
    _requireColumns_('Payments', [
      'payment_id', 'amount', 'currency', 'box_type', 'action_type',
      'invoice_equivalent', 'exchange_rate', 'client_request_id',
    ]);
    const boxId = 'box_' + boxName + '_' + currency.toLowerCase();
    paymentId = 'OB-' + Utilities.getUuid().replace(/-/g, '').toUpperCase();
    const equivalentUsd = currency === 'USD'
      ? rounded
      : rate === null ? '' : _roundSalesAmount_(rounded / rate, 'USD');
    _add('Boxes_Balance', {
      box_id: boxId,
      box_name: boxName,
      currency: currency,
      balance: 0,
      last_updated: _now(),
    });
    boxAdded = true;
    if (rounded > 0) {
      _add('Payments', {
        payment_id: paymentId,
        customer_id: '',
        order_id: '',
        receipt_id: paymentId,
        amount: rounded,
        currency: currency,
        box_type: boxName,
        method: 'opening_balance',
        payment_method: 'opening_balance',
        payment_date: _now(),
        note: reason,
        created_by: user.user_id,
        created_at: _now(),
        action_type: 'receive',
        invoice_currency: 'USD',
        invoice_equivalent: equivalentUsd,
        exchange_rate: currency === 'SYP' ? rate || '' : '',
        reference: '',
        client_request_id: requestId,
      });
      _updateBoxBalance(boxName, currency, rounded, 'receive');
    }
    auditId = Utilities.getUuid();
    _add('Audit_Log', {
      log_id: auditId,
      user_id: user.user_id,
      action: 'OPEN_CASH_BOX',
      entity: 'Boxes_Balance',
      entity_id: boxName + ':' + currency,
      details: JSON.stringify({
        amount: rounded,
        currency: currency,
        reason: reason,
        exchange_rate: rate,
        client_request_id: requestId,
      }),
      created_at: _now(),
    });
    return {
      success: true,
      box_id: boxId,
      payment_id: paymentId,
      balance: rounded,
      manual_review_required: currency === 'SYP' && rounded > 0 && rate === null,
    };
  } catch (error) {
    const rollbackErrors = [];
    if (paymentId) {
      try { _deleteRowsByField_('Payments', 'payment_id', paymentId); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (auditId) {
      try { _deleteRowsByField_('Audit_Log', 'log_id', auditId); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (boxAdded) {
      try {
        const snapshot = _cashBoxSnapshot_(boxName, currency);
        if (snapshot) _deleteRowsByField_('Boxes_Balance', 'box_id', snapshot.box_id);
      } catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    if (rollbackErrors.length) {
      Logger.log('Cash opening balance rollback failed: ' + rollbackErrors.join('; '));
      throw _apiError(
        'CASH_OPENING_ROLLBACK_FAILED',
        'تعذر التراجع الكامل عن الرصيد الافتتاحي؛ راجع سجل النظام',
        false
      );
    }
    throw error;
  } finally {
    lock.releaseLock();
  }
}

// ============================================================
// 11. المخزون (Inventory)
// ============================================================
function _handleGetInventoryMovements(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'warehouse']);
  const movements = _all('Inventory_Movements');
  const code = body.code;
  if (code) {
    return { movements: movements.filter(m => m.code === code).reverse() };
  }
  return { movements: movements.reverse() };
}

// ============================================================
// 12. الشحن (Shipments)
// ============================================================
function _shipmentInteger_(value, fieldName) {
  const text = String(value === undefined || value === null ? '' : value).trim();
  if (text === '') return 0;
  const number = Number(text);
  if (!Number.isSafeInteger(number) || number < 0) {
    throw new Error('عدد الطرود في ' + fieldName + ' يجب أن يكون عددًا صحيحًا غير سالب');
  }
  return number;
}

function _shipmentPackageTypes_(shipment) {
  let raw = shipment.package_types;
  if (raw === undefined || raw === null || raw === '') {
    raw = shipment.package_types_json;
  }
  if (typeof raw === 'string' && raw.trim()) {
    try {
      raw = JSON.parse(raw);
    } catch (error) {
      throw new Error('بيانات أنواع الطرود المخزنة غير صالحة');
    }
  }
  if (Array.isArray(raw)) {
    if (raw.length > 20) throw new Error('عدد أنواع الطرود أكبر من الحد المسموح');
    const parsedTypes = raw.map(item => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) {
        throw new Error('بيانات أنواع الطرود غير صالحة');
      }
      const count = _shipmentInteger_(item.count, 'نوع الطرد');
      const type = String(item.type || '').trim().toLowerCase();
      if (!['carton', 'bag', 'custom', 'other'].includes(type)) {
        throw new Error('نوع الطرد غير مدعوم');
      }
      const customType = type === 'custom' || type === 'other'
        ? String(item.label || item.custom_type || '').trim()
        : '';
      if (count > 0 && (type === 'custom' || type === 'other') && !customType) {
        throw new Error('اكتب اسم نوع الطرد المخصص');
      }
      if (customType.length > 40) throw new Error('اسم نوع الطرد طويل جدًا');
      return {
        type: type === 'other' ? 'custom' : type,
        label: type === 'carton' ? 'كرتونة'
          : type === 'bag' ? 'كيس' : customType,
        count: count
      };
    }).filter(item => item.count > 0);
    if (parsedTypes.length) return parsedTypes;
  }

  const cartonCount = _shipmentInteger_(shipment.carton_count, 'الكرتون');
  const bagCount = _shipmentInteger_(shipment.bag_count, 'الأكياس');
  const customCount = _shipmentInteger_(shipment.custom_count, 'النوع الآخر');
  const customType = String(shipment.custom_type || '').trim();
  if (customCount > 0 && !customType) throw new Error('اكتب اسم نوع الطرد المخصص');
  const legacyTypes = [];
  if (cartonCount > 0) legacyTypes.push({ type: 'carton', label: 'كرتونة', count: cartonCount });
  if (bagCount > 0) legacyTypes.push({ type: 'bag', label: 'كيس', count: bagCount });
  if (customCount > 0) legacyTypes.push({ type: 'custom', label: customType, count: customCount });
  return legacyTypes;
}

function _shipmentPackageSummary_(shipment) {
  const types = _shipmentPackageTypes_(shipment);
  const typedTotal = types.reduce((sum, item) => sum + item.count, 0);
  const legacyTotal = _shipmentInteger_(shipment.package_count, 'الإجمالي');
  const total = typedTotal > 0 ? typedTotal : legacyTotal;
  if (!total) return 'لا توجد طرود مسجلة';
  const totalNoun = total === 1 ? 'طرد واحد'
    : total === 2 ? 'طردان'
      : total <= 10 ? 'طرود' : 'طردًا';
  const detail = types.map(item => {
    const count = item.count;
    if (item.type === 'carton') {
      return count + ' ' + (count === 1 ? 'كرتونة'
        : count === 2 ? 'كرتونتان' : count <= 10 ? 'كراتين' : 'كرتونة');
    }
    if (item.type === 'bag') {
      return count + ' ' + (count === 1 ? 'كيس'
        : count === 2 ? 'كيسان' : count <= 10 ? 'أكياس' : 'كيس');
    }
    return item.label ? count + ' ' + item.label : '';
  }).filter(Boolean);
  return total + ' ' + totalNoun +
    (detail.length ? ' (' + detail.join('، ') + ')' : '');
}

function _shipmentWithSummary_(shipment, orderById, invoiceById) {
  const copy = Object.assign({}, shipment);
  const types = _shipmentPackageTypes_(copy);
  const typedTotal = types.reduce((sum, item) => sum + item.count, 0);
  if (types.length) {
    copy.package_types = types;
    copy.package_count = typedTotal;
  } else {
    copy.package_types = [];
  }
  copy.package_summary = _shipmentPackageSummary_(copy);
  const order = orderById[String(copy.order_id || '')];
  const invoice = invoiceById[String(copy.invoice_id || '')];
  if (order) {
    copy.order_number = order.order_number || order.order_id || '';
    copy.customer_name = order.customer_name || '';
    copy.accounting_invoice_no = order.accounting_invoice_no || '';
  } else if (invoice) {
    copy.order_number = '';
    copy.customer_name = invoice.customer_name || invoice.buyer_name || '';
    copy.accounting_invoice_no = invoice.invoice_number || invoice.invoice_id || '';
    copy.invoice_no = invoice.invoice_number || '';
  }
  return copy;
}

function _handleGetShipments(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'warehouse']);
  const orders = {};
  _all('Orders').forEach(order => {
    orders[String(order.order_id || '')] = order;
  });
  const invoices = {};
  _all('Sales_Invoices').forEach(invoice => {
    invoices[String(invoice.invoice_id || '')] = invoice;
  });
  const shipments = _all('Shipments').reverse();
  const userRole = _normalizeRole(user.role);
  return {
    shipments: shipments.map(s =>
      _withoutFinancialFields(_shipmentWithSummary_(s, orders, invoices), userRole)
    )
  };
}

function _handleShipment(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'warehouse']);
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) throw new Error('تعذر بدء حفظ الشحنة؛ حاول مجددًا');
  try {
    const shipmentId = String(body.shipment_id || body.shipmentId || '').trim();
    const requestId = String(body.client_request_id || '').trim();
    if (requestId) {
      const previous = _all('Shipments').find(s =>
        String(s.client_request_id || '') === requestId
      );
      if (previous && !shipmentId) {
        return { success: true, shipment_id: previous.shipment_id, duplicate: true };
      }
    }

    const identifier = String(body.order_id || body.orderId || body.invoice_id || '').trim();
    if (!identifier) throw new Error('رقم الطلب أو الفاتورة مطلوب');
    const existing = shipmentId
      ? _all('Shipments').find(item => String(item.shipment_id) === shipmentId)
      : null;
    if (shipmentId && !existing) throw new Error('الشحنة غير موجودة');
    const orders = _all('Orders');
    const order = orders.find(item =>
      [item.order_id, item.order_number, item.accounting_invoice_no]
        .some(value => String(value || '').trim() === identifier)
    ) || null;
    const invoices = _all('Sales_Invoices');
    const invoice = invoices.find(item =>
      [item.invoice_id, item.invoice_number]
        .some(value => String(value || '').trim() === identifier)
    ) || null;
    const retainedReference = existing &&
      [existing.order_id, existing.invoice_id]
        .some(value => String(value || '').trim() === identifier);
    if (!order && !invoice && !retainedReference) {
      throw new Error('الطلب أو الفاتورة غير موجودة');
    }
    if (existing) {
      const status = String(existing.status || '').toLowerCase();
      if (['delivered', 'closed', 'locked'].includes(status) &&
          _normalizeRole(user.role) !== 'admin') {
        throw new Error('لا يمكن تعديل شحنة مسلّمة أو مقفلة إلا للمدير العام');
      }
    }

    const packageTypes = _shipmentPackageTypes_(body);
    const packageCount = packageTypes.reduce((sum, item) => sum + item.count, 0) ||
      _shipmentInteger_(body.package_count, 'الإجمالي');
    if (!Number.isSafeInteger(packageCount)) throw new Error('إجمالي الطرود أكبر من الحد المسموح');
    const weight = String(body.weight_kg === undefined ? '' : body.weight_kg).trim();
    if (weight && (!Number.isFinite(Number(weight)) || Number(weight) <= 0)) {
      throw new Error('الوزن يجب أن يكون رقمًا موجبًا');
    }
    const allowedStatuses = ['prepared', 'shipping', 'in_transit', 'delivered', 'returned', 'closed'];
    const requestedStatus = String(body.status || (existing && existing.status) || 'shipping')
      .trim().toLowerCase();
    if (!allowedStatuses.includes(requestedStatus)) throw new Error('حالة الشحنة غير صالحة');
    if (requestedStatus === 'closed' && _normalizeRole(user.role) !== 'admin') {
      throw new Error('إقفال الشحنة متاح للمدير العام فقط');
    }
    const values = {
      order_id: order ? order.order_id : (existing ? existing.order_id : ''),
      invoice_id: invoice ? invoice.invoice_id : (existing ? existing.invoice_id || '' : ''),
      delivery_method: String(body.delivery_method || (existing && existing.delivery_method) || 'شحن').trim(),
      carrier: String(body.carrier || '').trim(),
      tracking_no: String(body.tracking_no || '').trim(),
      province: String(body.province || '').trim(),
      package_count: packageCount,
      carton_count: packageTypes.filter(item => item.type === 'carton')
        .reduce((sum, item) => sum + item.count, 0),
      bag_count: packageTypes.filter(item => item.type === 'bag')
        .reduce((sum, item) => sum + item.count, 0),
      package_types_json: JSON.stringify(packageTypes),
      weight_kg: weight,
      dimensions: String(body.dimensions || '').trim(),
      shipping_date: String(body.shipping_date || (existing && existing.shipping_date) || _now()).trim(),
      status: requestedStatus,
      note: String(body.note || '').trim(),
      warehouse_note: String(body.warehouse_note || (existing && existing.warehouse_note) || '').trim()
    };
    const shippingCost = Number(body.shipping_cost_internal || 0);
    if (!Number.isFinite(shippingCost) || shippingCost < 0) {
      throw new Error('تكلفة الشحن يجب أن تكون رقمًا غير سالب');
    }
    if (!Number.isFinite(Date.parse(values.shipping_date))) {
      throw new Error('تاريخ الشحن غير صالح');
    }
    const maxLengths = {
      delivery_method: 80, carrier: 120, tracking_no: 120, province: 120,
      dimensions: 80, note: 1000, warehouse_note: 1000
    };
    Object.keys(maxLengths).forEach(field => {
      if (values[field].length > maxLengths[field]) throw new Error('قيمة الحقل ' + field + ' طويلة جدًا');
    });

    let savedId = shipmentId;
    if (existing) {
      if (!_updateByField('Shipments', 'shipment_id', shipmentId, values)) {
        throw new Error('تعذر تحديث الشحنة');
      }
    } else {
      savedId = 'SHP-' + Utilities.getUuid().substring(0, 8).toUpperCase();
      values.shipment_id = savedId;
      values.client_request_id = requestId;
      values.shipping_cost_internal = shippingCost;
      _add('Shipments', values);
    }

    if (order && requestedStatus === 'shipping' &&
        (!existing || String(existing.status || '').toLowerCase() !== 'shipping')) {
      _dispatchStatusNotifications(order, 'shipping');
    }
    return { success: true, shipment_id: savedId };
  } finally {
    lock.releaseLock();
  }
}

function _handleUpdateShipmentStatus(body, user) {
  _needRole(user, ['admin', 'manager', 'warehouse']);
  const shipmentId = body.shipmentId || body.shipment_id;
  const newStatus = String(body.status || '').trim().toLowerCase();
  const allowedStatuses = ['prepared', 'shipping', 'in_transit', 'delivered', 'returned', 'closed'];
  if (!shipmentId || !allowedStatuses.includes(newStatus)) throw new Error('بيانات غير صالحة');
  if (newStatus === 'closed' && _normalizeRole(user.role) !== 'admin') {
    throw new Error('إقفال الشحنة متاح للمدير العام فقط');
  }

  const ss = _ss();
  const sheet = ss.getSheetByName('Shipments');
  if (!sheet) throw new Error('جدول الشحنات غير موجود');
  const data = sheet.getDataRange().getValues();
  if (!data.length) throw new Error('جدول الشحنات غير مهيأ');
  const headers = data[0];
  const idIdx = headers.indexOf('shipment_id');
  const statusIdx = headers.indexOf('status');
  if (idIdx < 0 || statusIdx < 0) throw new Error('أعمدة الشحنات غير مهيأة');

  for (let i = 1; i < data.length; i++) {
    if (String(data[i][idIdx]) === String(shipmentId)) {
      const oldStatus = String(data[i][statusIdx] || '').toLowerCase();
      if (['delivered', 'closed', 'locked'].includes(oldStatus) &&
          _normalizeRole(user.role) !== 'admin' && oldStatus !== newStatus) {
        throw new Error('لا يمكن تعديل شحنة مسلّمة أو مقفلة إلا للمدير العام');
      }
      sheet.getRange(i + 1, statusIdx + 1).setValue(newStatus);
      const shipment = Object.fromEntries(headers.map((header, index) => [header, data[i][index]]));
      const order = _all('Orders').find(o => String(o.order_id) === String(shipment.order_id));
      if (order && ['shipping', 'delivered'].includes(String(newStatus).toLowerCase())) {
        _dispatchStatusNotifications(order, String(newStatus).toLowerCase());
      }
      return { success: true };
    }
  }
  throw new Error('الشحنة غير موجودة');
}

// ============================================================
// 13. طلبات النواقص (Low Stock Requests)
// ============================================================
function _handleCreateLowStockRequest(body, user) {
  _needRole(user, ['admin', 'manager', 'warehouse']);
  if (!body.code || !body.requested_qty) throw new Error('بيانات الطلب غير مكتملة');

  const requestId = 'LSR-' + Utilities.getUuid().substring(0, 8).toUpperCase();
  _add('Low_Stock_Requests', {
    request_id: requestId,
    code: body.code,
    requested_qty: Number(body.requested_qty),
    status: 'pending',
    note: body.note || '',
    created_by: user.user_id,
    created_at: _now()
  });

  _sendNotificationToRoles(
    'admin,accountant',
    'طلب نواقص جديد',
    'قام المستودع بطلب مواد للمنتج ' + body.code + '.',
    'alert.low_stock_request',
    body.code,
    { product_id: body.code }
  );

  return { success: true, request_id: requestId };
}

function _handleGetLowStockRequests(body, user) {
  _needRole(user, ['admin', 'manager', 'warehouse']);
  return { requests: _all('Low_Stock_Requests').reverse() };
}

// ============================================================
// 14. الإشعارات (Notifications)
// ============================================================
function _handleGetNotifications(body, user) {
  if (!user) throw new Error('المستخدم غير معروف');
  const isAdmin = _normalizeRole(user.role) === 'admin';
  const since = body.since_time ? Date.parse(body.since_time) : 0;
  const notifications = _all('Notifications')
    .filter(notification => {
      const ownerId = notification.target_user_id || notification.user_id;
      const isOwned = String(ownerId) === String(user.user_id);
      return isOwned ||
        (isAdmin && ['failed', 'pending'].includes(String(notification.status || '')));
    })
    .filter(notification => {
      if (!Number.isFinite(since) || !since) return true;
      return [
        notification.created_at,
        notification.sent_at,
        notification.read_at,
        notification.last_attempt_at
      ].some(timestamp => Date.parse(timestamp || 0) >= since);
    })
    .sort((a, b) => Date.parse(b.created_at || 0) - Date.parse(a.created_at || 0))
    .map(notification => {
      const result = Object.assign({}, notification);
      result.is_read = result.is_read === true ||
        String(result.is_read).toLowerCase() === 'true' ||
        String(result.is_read) === '1' ||
        !!result.read_at;
      if (!isAdmin) {
        delete result.last_error;
        delete result.retry_count;
      }
      return result;
    });
  return { notifications: notifications };
}

function _handleMarkNotificationAsRead(body, user) {
  if (!user) throw new Error('المستخدم غير معروف');
  const notificationId = body.notificationId || body.notification_id;
  if (!notificationId) throw new Error('رقم الإشعار مطلوب');

  const ss = _ss();
  const sheet = ss.getSheetByName('Notifications');
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const idIdx = headers.indexOf('notification_id');
  const targetOwnerIdx = headers.indexOf('target_user_id');
  const legacyOwnerIdx = headers.indexOf('user_id');

  for (let i = 1; i < data.length; i++) {
    if (String(data[i][idIdx]) === String(notificationId)) {
      const ownerId = targetOwnerIdx >= 0 && data[i][targetOwnerIdx]
        ? data[i][targetOwnerIdx]
        : legacyOwnerIdx >= 0 ? data[i][legacyOwnerIdx] : '';
      if (String(ownerId) !== String(user.user_id)) {
        throw _apiError('FORBIDDEN', 'ليس لديك صلاحية تعديل هذا الإشعار', false);
      }
      const updates = {
        read_at: _now(),
        is_read: true
      };
      Object.keys(updates).forEach(field => {
        const index = headers.indexOf(field);
        if (index >= 0) sheet.getRange(i + 1, index + 1).setValue(updates[field]);
      });
      return { success: true };
    }
  }
  throw new Error('الإشعار غير موجود');
}

function _handleMarkAllNotificationsAsRead(user) {
  const sheet = _ss().getSheetByName('Notifications');
  if (!sheet) return { success: true, updated: 0 };
  const data = sheet.getDataRange().getValues();
  if (data.length < 2) return { success: true, updated: 0 };
  const headers = data[0].map(String);
  const targetOwnerIdx = headers.indexOf('target_user_id');
  const legacyOwnerIdx = headers.indexOf('user_id');
  const readAtIdx = headers.indexOf('read_at');
  const readIdx = headers.indexOf('is_read');
  let updated = 0;
  for (let i = 1; i < data.length; i++) {
    const ownerId = targetOwnerIdx >= 0 && data[i][targetOwnerIdx]
      ? data[i][targetOwnerIdx]
      : legacyOwnerIdx >= 0 ? data[i][legacyOwnerIdx] : '';
    if (String(ownerId) !== String(user.user_id)) continue;
    if (readAtIdx >= 0) sheet.getRange(i + 1, readAtIdx + 1).setValue(_now());
    if (readIdx >= 0) sheet.getRange(i + 1, readIdx + 1).setValue(true);
    updated++;
  }
  return { success: true, updated: updated };
}

function _handleSendNotification(body, user) {
  if (_normalizeRole(user && user.role) !== 'admin') {
    throw _apiError('FORBIDDEN', 'ليس لديك صلاحية إرسال إشعارات إدارية', false);
  }
  const allowedRoles = ['admin', 'manager', 'accountant', 'warehouse', 'salesperson', 'customer'];
  const requestedRoles = Array.isArray(body.roles)
    ? body.roles.map(_normalizeRole).filter(role => allowedRoles.includes(role))
    : [];
  if (!requestedRoles.length) {
    throw _apiError('RECIPIENT_ROLE_REQUIRED', 'يجب تحديد دور مستلم صالح', false);
  }
  const title = String(body.title || '').trim().substring(0, 100);
  const messageBody = String(body.body || '').trim().substring(0, 240);
  if (!title || !messageBody) throw new Error('العنوان والرسالة مطلوبان');
  const activeUsers = _all('Users').filter(account =>
    requestedRoles.includes(_normalizeRole(account.role)) &&
    String(account.status || '').toLowerCase() === 'active'
  );
  activeUsers.forEach(account => _sendNotification(
    account.user_id,
    title,
    messageBody,
    {
      event_type: 'general.announcement',
      created_by: user.user_id,
      target_role: _normalizeRole(account.role)
    }
  ));
  return { success: true, queued: activeUsers.length };
}

function _sendNotification(userId, title, body, metadata) {
  try {
    return _createNotificationRecord_(userId, title, body, metadata);
  } catch (error) {
    Logger.log(
      'Notification queue failed for recipient ' + String(userId) + ': ' +
      String(error.message || error).substring(0, 300)
    );
    return null;
  }
}

function _createNotificationRecord_(userId, title, body, metadata) {
  const recipient = _all('Users').find(account =>
    String(account.user_id) === String(userId) &&
    String(account.status || '').toLowerCase() === 'active'
  );
  if (!recipient) return null;

  const meta = metadata || {};
  const eventType = String(meta.event_type || meta.entity_type || 'general.notice');
  const orderId = String(meta.order_id || (meta.entity_type === 'order' ? meta.entity_id : '') || '');
  const invoiceId = String(meta.invoice_id || (meta.entity_type === 'invoice' ? meta.entity_id : '') || '');
  const productId = String(meta.product_id || (meta.entity_type === 'product' ? meta.entity_id : '') || '');
  const customerId = String(meta.customer_id || recipient.customer_id || '');
  const entityId = orderId || invoiceId || productId || String(meta.entity_id || '');
  const eventId = String(
    meta.event_id || eventType + ':' + (entityId || Utilities.getUuid())
  );
  const deepLink = meta.deep_link || (orderId
    ? '/orders/' + encodeURIComponent(orderId)
    : invoiceId
      ? '/invoices/' + encodeURIComponent(invoiceId)
      : productId
        ? '/products/' + encodeURIComponent(productId)
        : /^(payment|account)/.test(eventType)
          ? '/statement'
        : '/notifications');
  const now = _now();
  const duplicate = _all('Notifications').find(item =>
    String(item.event_id || '') === eventId &&
    String(item.target_user_id || item.user_id || '') === String(userId)
  );
  if (duplicate) return duplicate.notification_id;

  const record = {
    notification_id: Utilities.getUuid(),
    event_id: eventId,
    event_type: eventType,
    title: String(title || '').substring(0, 100),
    body: String(body || '').substring(0, 240),
    target_role: _normalizeRole(meta.target_role || recipient.role),
    target_user_id: userId,
    customer_id: customerId,
    order_id: orderId,
    invoice_id: invoiceId,
    product_id: productId,
    deep_link: deepLink,
    created_at: now,
    sent_at: '',
    read_at: '',
    is_read: false,
    status: 'pending',
    created_by: meta.created_by || 'system',
    retry_count: 0,
    last_error: '',
    last_attempt_at: '',
    delivered_device_ids: '[]',
    user_id: userId,
    type: eventType.split('.')[0],
    entity_type: eventType.split('.')[0],
    entity_id: orderId || invoiceId || productId || ''
  };
  _add('Notifications', record);
  try {
    _attemptNotificationSend_(record.notification_id);
  } catch (error) {
    Logger.log('FCM notification send failed for ' + record.notification_id + ': ' + error.message);
    _updateByField('Notifications', 'notification_id', record.notification_id, {
      status: 'failed',
      last_error: String(error.message || error).substring(0, 500)
    });
  }
  return record.notification_id;
}

function _notifyRole(role, title, body, metadata) {
  const normalizedRole = _normalizeRole(role);
  const users = _all('Users').filter(u =>
    _normalizeRole(u.role) === normalizedRole &&
    String(u.status || '').toLowerCase() === 'active'
  );
  users.forEach(u => {
    _sendNotification(u.user_id, title, body, metadata);
  });
}

function _sendNotificationToRoles(rolesStr, title, messageBody, eventType, entityId, metadata) {
  try {
    const roles = String(rolesStr || '').split(',').map(_normalizeRole);
    const users = _all('Users').filter(u =>
      roles.includes(_normalizeRole(u.role)) &&
      String(u.status || '').toLowerCase() === 'active'
    );
    const resolvedEventType = eventType ||
      (metadata && metadata.event_type) || 'general.notice';
    const resolvedEntityId = entityId || (metadata && metadata.entity_id) || '';
    const meta = Object.assign({}, metadata || {}, {
      event_type: resolvedEventType,
      entity_id: resolvedEntityId,
      event_id: (metadata && metadata.event_id) ||
        resolvedEventType + ':' + (resolvedEntityId || Utilities.getUuid())
    });
    users.forEach(user => {
      _sendNotification(user.user_id, title, messageBody, Object.assign({}, meta, {
        target_role: _normalizeRole(user.role)
      }));
    });
  } catch (error) {
    Logger.log(
      'Role notification queue failed: ' +
      String(error.message || error).substring(0, 300)
    );
  }
}

function _handleRegisterUserDevice(body, user) {
  const deviceId = String(body.device_id || '').trim();
  const fcmToken = String(body.fcm_token || '').trim();
  const fcmTargetType = String(body.fcm_target_type || 'token').trim().toLowerCase();
  if (!deviceId || deviceId.length > 120 || fcmToken.length < 20 || fcmToken.length > 4096) {
    throw _apiError('INVALID_DEVICE', 'بيانات الجهاز أو رمز الإشعارات غير صالحة', false);
  }
  if (fcmTargetType !== 'token' && fcmTargetType !== 'fid') {
    throw _apiError('INVALID_DEVICE_TARGET', 'نوع تسجيل الإشعارات غير صالح', false);
  }
  const platform = String(body.platform || '').toLowerCase();
  if (platform !== 'android' && platform !== 'ios') {
    throw _apiError('UNSUPPORTED_PLATFORM', 'نظام التشغيل هذا غير مدعوم حالياً للإشعارات', false);
  }

  const sheet = _ss().getSheetByName('User_Devices');
  if (!sheet) throw new Error('جدول الأجهزة غير مهيأ. شغّل setupSystem أولاً');
  const data = sheet.getDataRange().getValues();
  const headers = data[0].map(String);
  const deviceIdx = headers.indexOf('device_id');
  const userIdx = headers.indexOf('user_id');
  const tokenIdx = headers.indexOf('fcm_token');
  const activeIdx = headers.indexOf('is_active');
  const enabledIdx = headers.indexOf('enabled');
  const platformIdx = headers.indexOf('platform');
  const previousToken = String(body.previous_fcm_token || '').trim();

  for (let i = 1; i < data.length; i++) {
    const sameDevice = String(data[i][deviceIdx]) === deviceId;
    const sameToken = String(data[i][tokenIdx]) === fcmToken;
    const oldToken = previousToken && String(data[i][tokenIdx]) === previousToken &&
      String(data[i][userIdx]) === String(user.user_id);
    if (oldToken ||
        (sameToken && !sameDevice) ||
        ((sameDevice || sameToken) &&
          String(data[i][userIdx]) !== String(user.user_id))) {
      if (activeIdx >= 0) sheet.getRange(i + 1, activeIdx + 1).setValue(false);
      if (enabledIdx >= 0) sheet.getRange(i + 1, enabledIdx + 1).setValue(false);
    }
  }

  const now = _now();
  const existingRow = data.findIndex((row, index) =>
    index > 0 && String(row[deviceIdx]) === deviceId
  );
  const record = {
    device_id: deviceId,
    user_id: user.user_id,
    fcm_token: fcmToken,
    fcm_target_type: fcmTargetType,
    platform: platform,
    app_version: String(body.app_version || 'unknown').substring(0, 40),
    last_active_at: now,
    is_active: true,
    enabled: true,
    created_at: existingRow > 0
      ? data[existingRow][headers.indexOf('created_at')]
      : now,
    updated_at: now
  };
  if (existingRow > 0) {
    const rowNumber = existingRow + 1;
    headers.forEach((header, index) => {
      if (record[header] !== undefined) {
        sheet.getRange(rowNumber, index + 1).setValue(record[header]);
      }
    });
  } else {
    _add('User_Devices', record);
  }

  _all('Notifications')
    .filter(notification =>
      String(notification.target_user_id || notification.user_id) ===
        String(user.user_id) &&
      ['pending', 'failed'].includes(String(notification.status || ''))
    )
    .forEach(notification => {
      _updateByField('Notifications', 'notification_id', notification.notification_id, {
        status: 'pending',
        retry_count: 0,
        last_error: ''
      });
    });
  _retryPendingNotificationsForUser_(user.user_id);
  return { success: true, device_id: deviceId, is_active: true };
}

function _handleDeactivateUserDevice(body, user) {
  const deviceId = String(body.device_id || '').trim();
  if (!deviceId) throw _apiError('DEVICE_REQUIRED', 'معرف الجهاز مطلوب', false);
  const sheet = _ss().getSheetByName('User_Devices');
  const data = sheet.getDataRange().getValues();
  const headers = data[0].map(String);
  const deviceIdx = headers.indexOf('device_id');
  const userIdx = headers.indexOf('user_id');
  const activeIdx = headers.indexOf('is_active');
  const enabledIdx = headers.indexOf('enabled');
  const updatedIdx = headers.indexOf('updated_at');
  let deactivated = false;
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][deviceIdx]) !== deviceId) continue;
    if (String(data[i][userIdx]) !== String(user.user_id)) {
      throw _apiError('FORBIDDEN', 'لا يمكن إلغاء تسجيل جهاز مستخدم آخر', false);
    }
    if (activeIdx >= 0) sheet.getRange(i + 1, activeIdx + 1).setValue(false);
    if (enabledIdx >= 0) sheet.getRange(i + 1, enabledIdx + 1).setValue(false);
    if (updatedIdx >= 0) sheet.getRange(i + 1, updatedIdx + 1).setValue(_now());
    deactivated = true;
  }
  return { success: true, deactivated: deactivated };
}

function _handleRetryNotification(body, user) {
  _needRole(user, ['admin']);
  const notificationId = String(body.notification_id || '').trim();
  if (!notificationId) throw _apiError('NOTIFICATION_REQUIRED', 'معرف الإشعار مطلوب', false);
  const notification = _all('Notifications').find(item =>
    String(item.notification_id) === notificationId
  );
  if (!notification) throw _apiError('NOTIFICATION_NOT_FOUND', 'الإشعار غير موجود', false);
  if (!['failed', 'pending'].includes(String(notification.status || ''))) {
    throw _apiError('INVALID_NOTIFICATION_STATUS', 'لا يمكن إعادة إرسال هذا الإشعار', false);
  }
  _attemptNotificationSend_(notificationId);
  return { success: true };
}

function _notificationChannel_(eventType) {
  const type = String(eventType || '').toLowerCase();
  if (type.indexOf('order') === 0) return 'orders';
  if (/^(invoice|payment|account)/.test(type)) return 'invoices';
  if (type.indexOf('warehouse') === 0) return 'warehouse';
  if (type.indexOf('shipping') === 0) return 'shipping';
  if (/^(inventory|alert)/.test(type)) return 'alerts';
  return 'general';
}

function _attemptNotificationSend_(notificationId) {
  const notification = _all('Notifications').find(item =>
    String(item.notification_id) === String(notificationId)
  );
  if (!notification) throw new Error('الإشعار غير موجود');
  if (String(notification.status || '') === 'sent') return true;
  const ownerId = notification.target_user_id || notification.user_id;
  const recipient = _all('Users').find(account =>
    String(account.user_id) === String(ownerId) &&
    String(account.status || '').toLowerCase() === 'active'
  );
  if (!recipient ||
      (notification.target_role &&
       _normalizeRole(notification.target_role) !== _normalizeRole(recipient.role))) {
    _deactivateAllUserDevices_(ownerId);
    _updateByField('Notifications', 'notification_id', notificationId, {
      status: 'failed',
      last_error: 'RECIPIENT_NOT_ACTIVE_OR_ROLE_CHANGED',
      last_attempt_at: _now()
    });
    return false;
  }
  const devices = _all('User_Devices').filter(device =>
    String(device.user_id) === String(ownerId) &&
    (device.enabled === undefined || device.enabled === null || device.enabled === ''
      ? (device.is_active === true ||
          String(device.is_active).toLowerCase() === 'true' ||
          String(device.is_active) === '1')
      : (device.enabled === true ||
          String(device.enabled).toLowerCase() === 'true' ||
          String(device.enabled) === '1')) &&
    String(device.fcm_token || '').length > 20
  );
  if (!devices.length) {
    const retryCount = Number(notification.retry_count || 0) + 1;
    _updateByField('Notifications', 'notification_id', notificationId, {
      status: 'pending',
      last_error: 'NO_ACTIVE_DEVICE',
      retry_count: retryCount,
      last_attempt_at: _now()
    });
    return false;
  }

  let deliveredDeviceIds = [];
  try {
    const priorIds = JSON.parse(notification.delivered_device_ids || '[]');
    if (Array.isArray(priorIds)) deliveredDeviceIds = priorIds.map(String);
  } catch (error) {
    Logger.log(
      'Invalid delivery ledger for notification ' + notificationId + ': ' +
      String(error.message || error).substring(0, 120)
    );
  }
  const delivered = new Set(deliveredDeviceIds);
  const now = _now();
  const attempt = Number(notification.retry_count || 0) + 1;
  _updateByField('Notifications', 'notification_id', notificationId, {
    retry_count: attempt,
    last_attempt_at: now,
    last_error: ''
  });
  const channelId = _notificationChannel_(notification.event_type);
  const payload = {
    type: String(notification.event_type || 'general.notice'),
    order_id: String(notification.order_id || ''),
    invoice_id: String(notification.invoice_id || ''),
    product_id: String(notification.product_id || ''),
    notification_id: String(notification.notification_id),
    event_id: String(notification.event_id || ''),
    event_time: String(notification.created_at || now),
    channel_id: channelId,
    deep_link: String(notification.deep_link || '/notifications'),
    title: String(notification.title || '').substring(0, 100),
    body: String(notification.body || '').substring(0, 240),
    entity_type: String(notification.entity_type || ''),
    entity_id: String(notification.entity_id || '')
  };
  const highPriority = [
    'order.created',
    'order.ready_for_preparation',
    'shipping.shipped',
    'alert.low_stock'
  ].includes(payload.type);
  let allDelivered = true;
  const errors = [];
  devices.forEach(device => {
    if (delivered.has(String(device.device_id))) return;
    try {
      _sendFcmMessage_(
        device.fcm_token,
        payload,
        highPriority,
        String(device.fcm_target_type || 'token').toLowerCase()
      );
      delivered.add(String(device.device_id));
      _updateByField('Notifications', 'notification_id', notificationId, {
        delivered_device_ids: JSON.stringify(Array.from(delivered))
      });
    } catch (error) {
      allDelivered = false;
      const errorCode = String(error.message || error);
      errors.push(errorCode.substring(0, 120));
      if (errorCode.indexOf('UNREGISTERED') >= 0 ||
          errorCode.indexOf('SENDER_ID_MISMATCH') >= 0) {
        _updateByField('User_Devices', 'device_id', device.device_id, {
          is_active: false,
          enabled: false,
          updated_at: _now()
        });
      }
    }
  });
  allDelivered = allDelivered && devices.every(device =>
    delivered.has(String(device.device_id))
  );
  _updateByField('Notifications', 'notification_id', notificationId, allDelivered
    ? { status: 'sent', sent_at: _now(), last_error: '' }
    : { status: 'failed', last_error: errors.join(' | ').substring(0, 500) });
  Logger.log(
    'FCM notification ' + notificationId +
    ' accepted_devices=' + delivered.size +
    ' active_devices=' + devices.length +
    ' result=' + (allDelivered ? 'accepted' : 'partial_or_failed')
  );
  return allDelivered;
}

// Role topics are public broadcasts, not an authorization boundary.
function sendFCMNotification(topic, title, body, screenRoute, orderId) {
  const allowedTopics = ['role_admin', 'role_manager', 'role_accountant',
    'role_warehouse', 'role_salesperson', 'role_customer'];
  const target = String(topic || '').trim();
  const route = String(screenRoute || '/notifications').trim();
  const id = String(orderId || '').trim();
  if (!allowedTopics.includes(target)) throw new Error('Invalid FCM role topic');
  if (!String(title || '').trim() || !String(body || '').trim()) {
    throw new Error('FCM title and body are required');
  }
  if (!['/notifications', '/orders'].includes(route) ||
      (route === '/orders' && !id)) {
    throw new Error('Invalid FCM route or missing order ID');
  }
  const projectId = String(
    PropertiesService.getScriptProperties().getProperty('FCM_PROJECT_ID') || ''
  ).trim();
  if (!projectId) throw new Error('FCM_PROJECT_ID is not configured');
  const notificationId = Utilities.getUuid();
  const payload = {
    message: {
      topic: target,
      notification: { title: String(title), body: String(body) },
      data: {
        notification_id: notificationId,
        deep_link: route,
        order_id: id,
        target_role: target.substring('role_'.length),
        channel_id: route === '/orders' ? 'orders' : 'general'
      },
      android: {
        priority: 'HIGH',
        notification: { channel_id: route === '/orders' ? 'orders' : 'general' }
      }
    }
  };
  const response = UrlFetchApp.fetch(
    'https://fcm.googleapis.com/v1/projects/' +
      encodeURIComponent(projectId) + '/messages:send',
    {
      method: 'post',
      contentType: 'application/json',
      headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true
    }
  );
  const status = response.getResponseCode();
  if (status < 200 || status >= 300) {
    let errorStatus = 'SEND_FAILED';
    try {
      const error = JSON.parse(response.getContentText()).error;
      if (error && error.status) errorStatus = String(error.status);
    } catch (error) {
      errorStatus = 'UNPARSEABLE_RESPONSE';
    }
    throw new Error('FCM_' + errorStatus + '_HTTP_' + status);
  }
  return JSON.parse(response.getContentText());
}

function _sendFcmMessage_(fcmToken, payload, highPriority, targetType) {
  const properties = PropertiesService.getScriptProperties();
  const serviceAccountText = properties.getProperty('FCM_SERVICE_ACCOUNT_JSON');
  if (!serviceAccountText) throw new Error('FCM_SERVICE_ACCOUNT_JSON is not configured');
  const serviceAccount = JSON.parse(serviceAccountText);
  const accessToken = _getFcmAccessToken_(serviceAccount);
  const targetField = String(targetType || 'token').toLowerCase() === 'fid'
    ? 'fid'
    : 'token';
  const messageTarget = {};
  messageTarget[targetField] = fcmToken;
  const message = {
    message: Object.assign({
      notification: { title: payload.title, body: payload.body },
      data: Object.fromEntries(
        Object.keys(payload)
          .filter(key => key !== 'title' && key !== 'body')
          .map(key => [key, String(payload[key])])
      ),
      android: {
        priority: highPriority ? 'HIGH' : 'NORMAL',
        notification: {
          channel_id: payload.channel_id,
          tag: String(payload.notification_id),
          sound: 'default'
        }
      },
      apns: {
        headers: {
          'apns-collapse-id': String(payload.notification_id)
        }
      }
    }, messageTarget)
  };
  const response = UrlFetchApp.fetch(
    'https://fcm.googleapis.com/v1/projects/' +
      encodeURIComponent(serviceAccount.project_id) + '/messages:send',
    {
      method: 'post',
      contentType: 'application/json',
      headers: { Authorization: 'Bearer ' + accessToken },
      payload: JSON.stringify(message),
      muteHttpExceptions: true
    }
  );
  const code = response.getResponseCode();
  const content = response.getContentText();
  if (code < 200 || code >= 300) {
    let status = '';
    let errorCode = '';
    try {
      const parsed = JSON.parse(content || '{}');
      const details = parsed.error && Array.isArray(parsed.error.details)
        ? parsed.error.details : [];
      status = String(parsed.error && parsed.error.status || '');
      const fcmDetail = details.find(detail =>
        String(detail['@type'] || '').indexOf('FcmError') >= 0
      );
      errorCode = String(fcmDetail && fcmDetail.errorCode || status || '');
    } catch (error) {
      errorCode = 'UNPARSEABLE_RESPONSE';
    }
    throw new Error(
      'FCM_' + (errorCode || 'SEND_FAILED') + '_HTTP_' + code
    );
  }
}

function _getFcmAccessToken_(serviceAccount) {
  const cache = CacheService.getScriptCache();
  const cached = cache.get('orca_fcm_access_token');
  if (cached) return cached;
  if (!serviceAccount.client_email || !serviceAccount.private_key ||
      !serviceAccount.project_id) {
    throw new Error('FCM service account JSON is incomplete');
  }
  const now = Math.floor(Date.now() / 1000);
  const base64Url = value => Utilities.base64EncodeWebSafe(value).replace(/=+$/g, '');
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600
  }));
  const unsignedJwt = header + '.' + claims;
  const signature = base64Url(
    Utilities.computeRsaSha256Signature(unsignedJwt, serviceAccount.private_key)
  );
  const response = UrlFetchApp.fetch('https://oauth2.googleapis.com/token', {
    method: 'post',
    contentType: 'application/x-www-form-urlencoded',
    payload: {
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: unsignedJwt + '.' + signature
    },
    muteHttpExceptions: true
  });
  const code = response.getResponseCode();
  const result = JSON.parse(response.getContentText() || '{}');
  if (code < 200 || code >= 300 || !result.access_token) {
    throw new Error('FCM_OAUTH_HTTP_' + code + ': ' +
      String(result.error_description || result.error || 'OAuth token request failed'));
  }
  cache.put('orca_fcm_access_token', result.access_token, 3300);
  return result.access_token;
}

function _retryPendingNotificationsForUser_(userId) {
  _all('Notifications')
    .filter(notification =>
      String(notification.target_user_id || notification.user_id) === String(userId) &&
      ['pending', 'failed'].includes(String(notification.status || '')) &&
      Number(notification.retry_count || 0) < 5
    )
    .forEach(notification => {
      try {
        _attemptNotificationSend_(notification.notification_id);
      } catch (error) {
        Logger.log('Retry failed for ' + notification.notification_id + ': ' + error.message);
      }
    });
}

function retryPendingNotifications() {
  const retryDelaysMinutes = [1, 5, 15, 60, 240];
  const now = Date.now();
  _all('Notifications')
    .filter(notification => {
      const status = String(notification.status || '');
      const attempts = Number(notification.retry_count || 0);
      if (!['pending', 'failed'].includes(status) || attempts >= 5) return false;
      const lastAttempt = Date.parse(notification.last_attempt_at ||
        notification.created_at || 0);
      return !Number.isFinite(lastAttempt) ||
        now - lastAttempt >= retryDelaysMinutes[Math.min(attempts, 4)] * 60000;
    })
    .forEach(notification => {
      try {
        _attemptNotificationSend_(notification.notification_id);
      } catch (error) {
        Logger.log('Scheduled notification retry failed for ' +
          notification.notification_id + ': ' + error.message);
      }
    });
}

function installNotificationRetryTrigger() {
  ScriptApp.getProjectTriggers().forEach(trigger => {
    if (trigger.getHandlerFunction() === 'retryPendingNotifications') {
      ScriptApp.deleteTrigger(trigger);
    }
  });
  ScriptApp.newTrigger('retryPendingNotifications').timeBased().everyMinutes(5).create();
}

function _deactivateAllUserDevices_(userId) {
  const sheet = _ss().getSheetByName('User_Devices');
  if (!sheet) return;
  const data = sheet.getDataRange().getValues();
  if (data.length < 2) return;
  const headers = data[0].map(String);
  const userIdx = headers.indexOf('user_id');
  const activeIdx = headers.indexOf('is_active');
  const enabledIdx = headers.indexOf('enabled');
  const updatedIdx = headers.indexOf('updated_at');
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][userIdx]) !== String(userId)) continue;
    if (activeIdx >= 0) sheet.getRange(i + 1, activeIdx + 1).setValue(false);
    if (enabledIdx >= 0) sheet.getRange(i + 1, enabledIdx + 1).setValue(false);
    if (updatedIdx >= 0) sheet.getRange(i + 1, updatedIdx + 1).setValue(_now());
  }
}

function _hasRecentNotification_(eventType, entityId, since) {
  return _all('Notifications').some(notification =>
    String(notification.event_type || '') === eventType &&
    String(notification.order_id || '') === String(entityId) &&
    Date.parse(notification.created_at || 0) >= since
  );
}

function _safeCancellationReason_(reason) {
  const value = String(reason || '').trim().substring(0, 100);
  if (/[0-9$€£]/.test(value) ||
      /(usd|syp|دولار|ليرة|سعر|مبلغ|رصيد|هاتف|جوال|رقم هاتف)/i.test(value)) {
    return 'السبب محفوظ في تفاصيل الطلب';
  }
  return 'السبب: ' + value;
}

function runNotificationReminders() {
  const now = Date.now();
  const orders = _all('Orders');
  orders.forEach(order => {
    const status = String(order.status || '').toLowerCase();
    const updatedAt = Date.parse(order.updated_at || order.created_at || 0);
    const pricedAt = Date.parse(order.priced_at || order.updated_at || order.created_at || 0);
    if (!Number.isFinite(updatedAt)) return;
    if (['pending', 'submitted', 'customer_changed'].includes(status) &&
        now - updatedAt >= 30 * 60000 &&
        !_hasRecentNotification_('order.unpriced_reminder', order.order_id, now - 6 * 3600000)) {
      _sendNotificationToRoles(
        'admin,accountant',
        'طلب بانتظار التسعير',
        'الطلب #' + (order.order_number || order.order_id) + ' بانتظار المراجعة والتسعير.',
        'order.unpriced_reminder',
        order.order_id,
        { order_id: order.order_id, customer_id: order.customer_id }
      );
    }
    if (status === 'priced' && now - pricedAt >= 24 * 3600000 &&
        !_hasRecentNotification_('order.customer_approval_reminder', order.order_id, now - 24 * 3600000)) {
      const customerUser = _all('Users').find(account =>
        String(account.customer_id) === String(order.customer_id) &&
        String(account.status || '').toLowerCase() === 'active'
      );
      if (customerUser) {
        _sendNotification(
          customerUser.user_id,
          'طلب بانتظار موافقتك',
          'الطلب #' + (order.order_number || order.order_id) + ' بانتظار مراجعتك.',
          {
            event_type: 'order.customer_approval_reminder',
            order_id: order.order_id,
            customer_id: order.customer_id
          }
        );
      }
    }
  });
}

function installNotificationRemindersTrigger() {
  ScriptApp.getProjectTriggers().forEach(trigger => {
    if (trigger.getHandlerFunction() === 'runNotificationReminders') {
      ScriptApp.deleteTrigger(trigger);
    }
  });
  ScriptApp.newTrigger('runNotificationReminders').timeBased().everyHours(1).create();
}

// ============================================================
// 15. التقارير والإحصائيات (Reports & Dashboard)
// ============================================================
function _handleReports(body, user) {
  _needRole(user, ['admin', 'manager']);
  const orders = _all('Orders');
  const items = _all('Order_Items');
  const products = _all('Products');

  const statusStats = {};
  orders.forEach(o => {
    statusStats[o.status] = (statusStats[o.status] || 0) + 1;
  });

  const categorySales = {};
  items.forEach(item => {
    const p = products.find(prod => prod.code === item.code);
    const cat = p ? p.group : 'غير مصنف';
    const total = Number(item.final_price || item.display_price_snapshot || 0) * Number(item.quantity_approved || item.quantity_requested || 0);
    categorySales[cat] = (categorySales[cat] || 0) + total;
  });

  return {
    statusStats: Object.entries(statusStats).map(([name, value]) => ({ name, value })),
    categorySales: Object.entries(categorySales).map(([name, value]) => ({ name, value: Number(value.toFixed(2)) }))
  };
}

function _handleDashboardStats(body, user) {
  const products = _all('Products');
  const orders = _all('Orders');
  const customers = _all('Customers');
  const payments = _all('Payments');

  if (user.role === 'customer') {
    const myOrders = orders.filter(o => o.customer_id === user.customer_id && o.status !== 'deleted');
    const myPayments = payments.filter(p => p.customer_id === user.customer_id);
    const totalSpent = myPayments.reduce((sum, p) => sum + Number(p.amount), 0);
    return {
      stats: [
        { title: 'طلباتي', value: myOrders.length.toString(), icon: 'shopping_cart' },
        { title: 'إجمالي المدفوعات', value: totalSpent.toFixed(2) + ' $', icon: 'account_balance_wallet' },
        { title: 'حالة الحساب', value: user.status === 'active' ? 'نشط' : 'متوقف', icon: 'person' }
      ]
    };
  }

  const stats = [];
  if (['admin', 'manager', 'accountant'].includes(user.role)) {
    stats.push({ title: 'إجمالي العملاء', value: customers.length.toString(), icon: 'people' });
    const totalRevenue = payments.reduce((sum, p) => sum + Number(p.amount), 0);
    stats.push({ title: 'إجمالي التحصيلات', value: totalRevenue.toFixed(2) + ' $', icon: 'attach_money' });
  }

  if (['admin', 'manager', 'accountant'].includes(user.role)) {
    const lowStock = products.filter(p => Number(p.quantity) < 10).length;
    stats.push({ title: 'منتجات منخفضة المخزون', value: lowStock.toString(), icon: 'inventory' });
  }

  stats.push({ title: 'الطلبات الجديدة', value: orders.filter(o => ['pending', 'submitted'].includes(o.status)).length.toString(), icon: 'new_releases' });

  return { stats };
}

// ============================================================
// 16. كشف الحساب (Customer Statement)
// ============================================================
function _handleGetCustomerStatement(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'customer']);
  const userRole = _normalizeRole(user.role);

  const customerId = userRole === 'customer' ? user.customer_id : body.customer_id;

  if (!customerId) throw new Error('رقم العميل مطلوب');

  const customer = _all('Customers').find(c => String(c.customer_id) === String(customerId));
  if (!customer) throw new Error('العميل غير موجود');

  const payments = _all('Payments').filter(p =>
    String(p.customer_id) === String(customerId)
  );
  const orders = _all('Orders').filter(o =>
    String(o.customer_id) === String(customerId) &&
    ['approved', 'prepared', 'shipping', 'delivered'].includes(o.status)
  );
  const orderItems = _all('Order_Items');
  const salesInvoices = _all('Sales_Invoices').filter(invoice =>
    String(invoice.customer_id) === String(customerId)
  );

  let statement = [];
  const openingUsd = Number(customer.opening_usd || 0);
  let needsManualReview = Number(customer.opening_syp || 0) !== 0;

  if (needsManualReview) {
    statement.push({
      date: customer.created_at || _now(),
      type: 'رصيد افتتاحي بعملة تحتاج مراجعة',
      ref: '-',
      debit: 0,
      credit: 0,
      note: 'يوجد رصيد افتتاحي بالليرة دون سعر صرف تاريخي محفوظ.',
      needs_manual_review: true,
    });
  }

  if (openingUsd !== 0) {
    statement.push({
      date: customer.created_at || _now(),
      type: 'رصيد افتتاحي',
      ref: '-',
      debit: openingUsd > 0 ? openingUsd : 0,
      credit: openingUsd < 0 ? Math.abs(openingUsd) : 0,
      note: 'رصيد مدور'
    });
  }

  orders.forEach(o => {
    const items = orderItems.filter(oi => oi.order_id === o.order_id);
    let total = 0;
    const currency = String(o.currency || 'USD').toUpperCase();
    const rate = Number(o.exchange_rate || o.rate_syp_per_usd || 0);
    items.forEach(item => {
      const price = item.final_price === '' || item.final_price == null
        ? item.display_price_snapshot : item.final_price;
      const quantity = item.quantity_approved === '' || item.quantity_approved == null
        ? item.quantity_requested : item.quantity_approved;
      total += Number(price || 0) * Number(quantity || 0);
    });
    const savedTotal = Number(o.total);
    if (o.total !== '' && o.total != null && Number.isFinite(savedTotal)) {
      total = savedTotal;
    } else {
      total = _roundOrderAmount_(total - Number(o.discount || 0));
    }
    if (currency === 'SYP') {
      if (Number.isFinite(rate) && rate > 0) total /= rate;
      else {
        needsManualReview = true;
        statement.push({
          date: o.created_at,
          type: 'طلب بعملة تاريخية تحتاج مراجعة',
          ref: o.order_id,
          debit: 0,
          credit: 0,
          note: 'لا يوجد سعر صرف تاريخي محفوظ؛ لم يُعد تقييم الطلب.',
          needs_manual_review: true,
        });
        return;
      }
    } else if (currency !== 'USD') {
      needsManualReview = true;
      statement.push({
        date: o.created_at,
        type: 'طلب بعملة تاريخية تحتاج مراجعة',
        ref: o.order_id,
        debit: 0,
        credit: 0,
        note: 'عملة الطلب غير مدعومة في كشف الدولار.',
        needs_manual_review: true,
      });
      return;
    }
    statement.push({
      date: o.created_at,
      type: 'طلب بضاعة',
      ref: o.order_id,
      debit: total,
      credit: 0,
      note: [
        o.note || '',
        Number(o.discount || 0) > 0
          ? 'حسم الفاتورة: ' + Number(o.discount) + ' ' + (o.currency || 'USD')
          : ''
      ].filter(Boolean).join(' | ')
    });
  });

  salesInvoices.forEach(invoice => {
    if (String(invoice.currency || 'USD').toUpperCase() !== 'USD') {
      needsManualReview = true;
      statement.push({
        date: invoice.invoice_date || invoice.created_at,
        type: 'فاتورة بعملة تحتاج مراجعة',
        ref: invoice.invoice_id,
        debit: 0,
        credit: 0,
        note: 'عملة الفاتورة غير مدعومة في كشف الدولار؛ لم يُعد تقييمها.',
        needs_manual_review: true,
      });
      return;
    }
    if (String(invoice.status) === 'posted') {
      statement.push({
        date: invoice.invoice_date || invoice.created_at,
        type: 'فاتورة مبيع',
        ref: invoice.invoice_id,
        debit: Number(invoice.net_total || 0),
        credit: 0,
        note: 'المجموع بعد الحسم؛ حالة السداد: ' +
          String(invoice.financial_status || 'تُحسب من الحركات'),
        invoice_id: invoice.invoice_id,
      });
    } else if (String(invoice.status) === 'voided') {
      statement.push({
        date: invoice.invoice_date || invoice.created_at,
        type: 'فاتورة مبيع ملغاة',
        ref: invoice.invoice_id,
        debit: Number(invoice.net_total || 0),
        credit: 0,
        note: 'أصل الفاتورة قبل الإلغاء.',
        invoice_id: invoice.invoice_id,
      });
      statement.push({
        date: invoice.updated_at || invoice.invoice_date || invoice.created_at,
        type: 'إلغاء فاتورة مبيع',
        ref: invoice.invoice_id,
        debit: 0,
        credit: Number(invoice.net_total || 0),
        note: 'إلغاء المديونية. أي قبض باقٍ يظهر كرصيد دائن حتى ردّه فعليًا.',
        invoice_id: invoice.invoice_id,
      });
    }
  });

  payments.forEach(p => {
    const equivalent = _paymentEquivalentUsd_(p);
    if (equivalent === null) {
      needsManualReview = true;
      statement.push({
        date: p.payment_date || p.created_at,
        type: String(p.action_type) === 'pay'
          ? 'صرف بعملة تاريخية غير مصنفة'
          : 'قبض بعملة تاريخية غير مصنفة',
        ref: p.payment_id,
        debit: 0,
        credit: 0,
        note: 'لم تُسجل قيمة دولارية أو سعر صرف تاريخي؛ لا يعاد التخمين.',
        needs_manual_review: true,
      });
      return;
    }
    const isPayout = String(p.action_type || '') === 'pay';
    statement.push({
      date: p.payment_date || p.created_at,
      type: isPayout ? 'مبلغ معاد للزبون' : 'دفعة زبون',
      ref: p.payment_id,
      debit: isPayout ? equivalent : 0,
      credit: isPayout ? 0 : equivalent,
      note: (p.note || p.method || '') +
        ' · ' + Number(p.amount || 0) + ' ' + String(p.currency || '') +
        (String(p.currency).toUpperCase() === 'SYP' && p.exchange_rate
          ? ' · سعر ' + p.exchange_rate + ' ل.س/USD'
          : ''),
      source_currency: p.currency || '',
      source_amount: Number(p.amount || 0),
      equivalent_usd: equivalent,
      invoice_id: p.order_id || '',
      receipt_id: p.receipt_id || '',
    });
  });

  statement.sort((a, b) =>
    Date.parse(a.date || 0) - Date.parse(b.date || 0) ||
    String(a.ref || '').localeCompare(String(b.ref || ''))
  );

  let runningBalance = 0;
  statement = statement.map(s => {
    runningBalance += Number(s.debit || 0) - Number(s.credit || 0);
    return { ...s, balance: Number(runningBalance.toFixed(2)) };
  });

  return {
    customer: {
      full_name: customer.full_name,
      company_name: customer.company_name,
      customer_id: customer.customer_id
    },
    statement: statement.reverse(),
    finalBalance: Number(runningBalance.toFixed(2)),
    currency: 'USD',
    needs_manual_review: needsManualReview,
  };
}

function _handleExportStatement(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant', 'customer']);
  const res = _handleGetCustomerStatement(body, user);
  const customer = res.customer;
  const statement = res.statement;

  let html = '<div dir="rtl" style="font-family: Arial, sans-serif; padding: 20px;">';
  html += '<h1 style="color: #00658f; text-align: center;">كشف حساب عميل</h1><hr/>';
  html += '<table style="width: 100%; margin-bottom: 20px;">';
  html += '<tr><td><strong>العميل:</strong> ' + customer.full_name + '</td>';
  html += '<td style="text-align: left;"><strong>التاريخ:</strong> ' + new Date().toLocaleDateString('ar-EG') + '</td></tr>';
  html += '<tr><td><strong>الشركة:</strong> ' + (customer.company_name || '-') + '</td>';
  html += '<td style="text-align: left;"><strong>رقم العميل:</strong> ' + customer.customer_id + '</td></tr>';
  html += '</table>';
  html += '<table border="1" style="width: 100%; border-collapse: collapse; text-align: center;">';
  html += '<thead style="background-color: #f2f2f2;"><tr>';
  html += '<th>التاريخ</th><th>البيان</th><th>المرجع</th><th>مدين ($)</th><th>دائن ($)</th><th>الرصيد ($)</th>';
  html += '</tr></thead><tbody>';

  statement.forEach(s => {
    html += '<tr>';
    html += '<td>' + String(s.date).split('T')[0] + '</td>';
    html += '<td>' + s.type + '</td>';
    html += '<td>' + s.ref + '</td>';
    html += '<td style="color: ' + (s.debit > 0 ? 'red' : 'black') + '">' + (s.debit || '-') + '</td>';
    html += '<td style="color: ' + (s.credit > 0 ? 'green' : 'black') + '">' + (s.credit || '-') + '</td>';
    html += '<td style="font-weight: bold;">' + s.balance + '</td>';
    html += '</tr>';
  });

  html += '</tbody></table>';
  html += res.needs_manual_review
    ? '<div style="margin-top: 30px;"><h3>الرصيد يحتاج إلى مراجعة؛ الأرصدة المعروضة جزئية.</h3></div>'
    : '<div style="margin-top: 30px; text-align: left;"><h3>الرصيد الإجمالي: ' + res.finalBalance + ' $</h3></div>';
  html += '<div style="margin-top: 50px; text-align: center; color: #888; font-size: 10px;">';
  html += 'تم الإنشاء بواسطة نظام أوركا أوردر - ' + new Date().toLocaleString('ar-EG');
  html += '</div></div>';

  const blob = HtmlService.createHtmlOutput(html).getAs('application/pdf');
  blob.setName('Statement_' + customer.full_name + '_' + new Date().getTime() + '.pdf');

  return {
    pdfBase64: Utilities.base64Encode(blob.getBytes()),
    fileName: blob.getName()
  };
}

// ============================================================
// 17. المزامنة والإعدادات (Sync & Config)
// ============================================================
function _handleSyncFromDrive(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const csvFileId = body.csv_file_id ||
    PropertiesService.getScriptProperties().getProperty('CSV_FILE_ID') ||
    "1Gq27DR3gKt78mMZdRzqxJusRVdtm6t-l";

  try {
    const file = DriveApp.getFileById(csvFileId);
    const csvContent = file.getBlob().getDataAsString('UTF-8');
    const csvData = Utilities.parseCsv(csvContent);

    if (csvData.length < 2) throw new Error('ملف CSV فارغ أو غير صالح');

    const csvHeaders = csvData.shift().map(h => h.trim().toLowerCase());
    const productsSheet = _ss().getSheetByName('Products');
    const sheetData = productsSheet.getDataRange().getValues();
    const sheetHeaders = sheetData[0];
    const codeIdx = sheetHeaders.indexOf('code');

    let updated = 0;
    let created = 0;

    csvData.forEach(row => {
      const rowData = {};
      csvHeaders.forEach((h, i) => { rowData[h] = row[i]; });
      const code = rowData['code'];
      if (!code) return;

      let rowIndex = -1;
      for (let i = 1; i < sheetData.length; i++) {
        if (String(sheetData[i][codeIdx]) === String(code)) {
          rowIndex = i + 1;
          break;
        }
      }

      const newRow = sheetHeaders.map(h => {
        let val = rowData[h.toLowerCase()];
        if (['quantity', 'display_price', 'factor_2', 'factor_3'].indexOf(h.toLowerCase()) > -1) {
          return val ? Number(String(val).replace(/[^0-9.]/g, '')) : 0;
        }
        if (val !== undefined) return val;
        if (h === 'updated_at') return _now();
        if (h === 'updated_by') return user ? user.user_id : 'SYSTEM';
        if (rowIndex > 0) return sheetData[rowIndex - 1][sheetHeaders.indexOf(h)];
        return '';
      });

      if (rowIndex > 0) {
        productsSheet.getRange(rowIndex, 1, 1, sheetHeaders.length).setValues([newRow]);
        updated++;
      } else {
        productsSheet.appendRow(newRow);
        created++;
      }
    });

    return {
      success: true,
      message: 'تمت المزامنة بنجاح: تحديث ' + updated + '، إضافة ' + created,
      details: { updated, created }
    };
  } catch (e) {
    throw new Error('خطأ في مزامنة Drive: ' + e.message);
  }
}

function _handleUpdateConfig(body, user) {
  _needRole(user, ['admin']);
  if (body.csv_file_id) {
    PropertiesService.getScriptProperties().setProperty('CSV_FILE_ID', body.csv_file_id);
  }
  if (body.spreadsheet_id) {
    PropertiesService.getScriptProperties().setProperty('SPREADSHEET_ID', body.spreadsheet_id);
  }
  if (body.product_images_folder_id) {
    PropertiesService.getScriptProperties().setProperty('PRODUCT_IMAGES_FOLDER_ID', body.product_images_folder_id);
  }
  return { success: true, message: 'تم تحديث الإعدادات بنجاح' };
}
