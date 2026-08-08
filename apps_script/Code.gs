const H = {
  Users: ['user_id','username','password_hash','salt','full_name','phone','role','customer_id','status','must_change_password','created_at','last_login'],
  Customers: ['customer_id','full_name','company_name','phone','address','province','notes','opening_usd','opening_syp','status','created_at'],
  Products: ['code','name','image_name','group','origin','unit_1','quantity','unit_2','factor_2','quantity_2','factor_3','unit_3','quantity_3','display_price','currency','notes','updated_at','updated_by'],
  Orders: ['order_id','customer_id','status','currency','note','accounting_invoice_no','created_at','updated_at','created_by'],
  Order_Items: ['item_id','order_id','code','unit','quantity_requested','quantity_approved','display_price_snapshot','final_price','status','customer_note','accountant_note','warehouse_note'],
  Payments: ['payment_id','customer_id','order_id','amount','currency','method','payment_date','note','created_by'],
  Inventory_Movements: ['movement_id','code','type','quantity','note','created_by','created_at'],
  Shipments: ['shipment_id','order_id','delivery_method','carrier','tracking_no','province','shipping_cost_internal','shipping_date','status','note'],
  Low_Stock_Requests: ['request_id','code','requested_qty','status','note','created_by','created_at'],
  Notifications: ['notification_id','user_id','title','body','read_at','created_at'],
  Audit_Log: ['log_id','user_id','action','entity','entity_id','details','created_at'],
  Sessions: ['token','user_id','expires_at'],
};

function _ss() {
  const id = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
  if (!id) throw new Error('SPREADSHEET_ID غير مضبوط في Script Properties');
  return SpreadsheetApp.openById(id);
}

function _now() {
  return new Date().toISOString();
}

function _digest(str) {
  return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, str)
    .map((b) => ('0' + (b & 255).toString(16)).slice(-2))
    .join('');
}

function _all(name) {
  const sheet = _ss().getSheetByName(name);
  const values = sheet.getDataRange().getValues();
  const headers = values.shift();
  return values
    .filter((r) => r.join('') !== '')
    .map((row) => Object.fromEntries(headers.map((h, i) => [h, row[i]])));
}

function _add(name, obj) {
  const sheet = _ss().getSheetByName(name);
  const headers = H[name];
  sheet.appendRow(headers.map((k) => obj[k] ?? ''));
}

function _json(o) {
  return ContentService.createTextOutput(JSON.stringify(o))
    .setMimeType(ContentService.MimeType.JSON);
}

function setupSystem() {
  const ss = _ss();
  Object.keys(H).forEach((name) => {
    let sheet = ss.getSheetByName(name);
    if (!sheet) sheet = ss.insertSheet(name);
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(H[name]);
    }
    sheet.setFrozenRows(1);
  });
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

function _auth(token) {
  const sessions = _all('Sessions');
  const s = sessions.find((x) => x.token === token && new Date(x.expires_at) > new Date());
  if (!s) throw new Error('انتهت الجلسة، يرجى تسجيل الدخول مجدداً');
  const users = _all('Users');
  const u = users.find((x) => x.user_id === s.user_id && x.status === 'active');
  if (!u) throw new Error('الحساب غير نشط');
  return u;
}

function _needRole(user, roles) {
  if (roles.indexOf(user.role) < 0) {
    throw new Error('ليست لديك الصلاحية لهذه العملية');
  }
}

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents || '{}');
    let result = {};

    if (body.action === 'login') {
      result = _handleLogin(body);
    } else {
      const user = _auth(body.token);
      switch (body.action) {
        case 'products':
          result = _handleProducts(body, user);
          break;
        case 'create_order':
          result = _handleCreateOrder(body, user);
          break;
        case 'receive_goods':
          result = _handleReceiveGoods(body, user);
          break;
        case 'add_payment':
          result = _handleAddPayment(body, user);
          break;
        case 'shipment':
          result = _handleShipment(body, user);
          break;
        default:
          throw new Error('عملية غير معروفة: ' + body.action);
      }
    }

    return _json({ ok: true, ...result });
  } catch (err) {
    return _json({ ok: false, error: err.message });
  }
}

function _handleLogin(body) {
  const users = _all('Users');
  const username = String(body.username || '').toLowerCase();
  const u = users.find((x) => String(x.username).toLowerCase() === username && x.status === 'active');
  if (!u) throw new Error('اسم المستخدم أو كلمة المرور غير صحيحة');

  const hash = _digest(String(body.password || '') + u.salt);
  if (hash !== u.password_hash) {
    throw new Error('اسم المستخدم أو كلمة المرور غير صحيحة');
  }

  const token = Utilities.getUuid() + Utilities.getUuid();
  _add('Sessions', {
    token: token,
    user_id: u.user_id,
    expires_at: new Date(Date.now() + 86400000).toISOString(), // 24h
  });

  return {
    session: {
      token: token,
      user_id: u.user_id,
      username: u.username,
      full_name: u.full_name,
      role: u.role,
    },
  };
}

function _handleProducts(body, user) {
  const q = String(body.q || '').toLowerCase();
  const products = _all('Products')
    .filter((p) =>
      !q ||
      String(p.code).toLowerCase().includes(q) ||
      String(p.name).toLowerCase().includes(q) ||
      String(p.group).toLowerCase().includes(q)
    )
    .map((p) => ({
      code: p.code,
      name: p.name,
      image_name: p.image_name,
      group: p.group,
      origin: p.origin,
      unit: p.unit_1,
      quantity: Number(p.quantity || 0),
      display_price: Number(p.display_price || 0),
      currency: p.currency || 'USD',
      notes: p.notes || '',
    }));
  return { products: products };
}

function _handleCreateOrder(body, user) {
  _needRole(user, ['customer']);
  const items = body.items;
  if (!Array.isArray(items) || !items.length) {
    throw new Error('الطلبية فارغة');
  }

  const year = new Date().getFullYear();
  const existing = _all('Orders').filter((o) => String(o.order_id).includes('OR-' + year));
  const seq = existing.length + 1;
  const orderId = 'OR-' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd') + '-' + String(seq).padStart(6, '0');

  _add('Orders', {
    order_id: orderId,
    customer_id: user.customer_id,
    status: 'submitted',
    currency: 'USD',
    note: body.note || '',
    accounting_invoice_no: '',
    created_at: _now(),
    updated_at: _now(),
    created_by: user.user_id,
  });

  const products = _all('Products');

  items.forEach((row, idx) => {
    const code = row.code;
    const p = products.find((x) => x.code === code);
    if (!p) {
      throw new Error('مادة غير موجودة: ' + code);
    }
    _add('Order_Items', {
      item_id: orderId + '-' + (idx + 1),
      order_id: orderId,
      code: code,
      unit: row.unit || p.unit_1,
      quantity_requested: Number(row.quantity || 0),
      quantity_approved: '',
      display_price_snapshot: p.display_price,
      final_price: '',
      status: 'pending',
      customer_note: row.note || '',
      accountant_note: '',
      warehouse_note: '',
    });
  });

  _add('Audit_Log', {
    log_id: Utilities.getUuid(),
    user_id: user.user_id,
    action: 'CREATE_ORDER',
    entity: 'Orders',
    entity_id: orderId,
    details: 'طلبية جديدة من الزبون',
    created_at: _now(),
  });

  return { order_id: orderId };
}

function _handleReceiveGoods(body, user) {
  _needRole(user, ['admin', 'accountant', 'warehouse']);
  const code = body.code;
  const qty = Number(body.quantity || 0);
  if (!code || qty <= 0) {
    throw new Error('بيانات استلام المواد غير صالحة');
  }
  _add('Inventory_Movements', {
    movement_id: Utilities.getUuid(),
    code: code,
    type: 'receipt',
    quantity: qty,
    note: body.note || '',
    created_by: user.user_id,
    created_at: _now(),
  });
  return { saved: true };
}

function _handleAddPayment(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const amount = Number(body.amount || 0);
  if (!body.customer_id || amount <= 0) {
    throw new Error('بيانات الدفعة غير صالحة');
  }
  _add('Payments', {
    payment_id: Utilities.getUuid(),
    customer_id: body.customer_id,
    order_id: body.order_id || '',
    amount: amount,
    currency: body.currency || 'USD',
    method: body.method || 'cash',
    payment_date: body.payment_date || _now(),
    note: body.note || '',
    created_by: user.user_id,
  });
  return { saved: true };
}

function _handleShipment(body, user) {
  _needRole(user, ['admin', 'accountant']);
  if (!body.order_id) {
    throw new Error('رقم الطلب مطلوب للشحن');
  }
  _add('Shipments', {
    shipment_id: Utilities.getUuid(),
    order_id: body.order_id,
    delivery_method: body.delivery_method || 'شحن',
    carrier: body.carrier || '',
    tracking_no: body.tracking_no || '',
    province: body.province || '',
    shipping_cost_internal: Number(body.shipping_cost_internal || 0),
    shipping_date: body.shipping_date || _now(),
    status: body.status || 'shipping',
    note: body.note || '',
  });
  return { saved: true };
}
