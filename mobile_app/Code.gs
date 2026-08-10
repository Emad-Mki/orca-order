/**
 * Orca Order Backend - Google Apps Script
 */

const H = {
  Users: ['user_id','username','password_hash','salt','full_name','phone','role','customer_id','status','must_change_password','created_at','last_login'],
  Customers: ['customer_id','full_name','company_name','phone','address','province','notes','opening_usd','opening_syp','status','created_at'],
  Products: ['code','name','image_name','group','origin','unit_1','quantity','unit_2','factor_2','quantity_2','factor_3','unit_3','quantity_3','display_price','currency','notes','updated_at','updated_by'],
  Orders: ['order_id','customer_id','status','currency','note','accounting_invoice_no','created_at','updated_at','created_by'],
  Order_Items: ['item_id','order_id','code','unit','quantity_requested','quantity_approved','quantity_prepared','display_price_snapshot','final_price','currency','status','customer_note','accountant_note','warehouse_note'],
  Payments: ['payment_id','customer_id','order_id','amount','currency','method','payment_date','note','created_by'],
  Inventory_Movements: ['movement_id','code','type','quantity','note','created_by','created_at'],
  Shipments: ['shipment_id','order_id','delivery_method','carrier','tracking_no','province','shipping_cost_internal','package_count','carton_count','bag_count','shipping_date','status','note'],
  Low_Stock_Requests: ['request_id','code','requested_qty','status','note','created_by','created_at'],
  Notifications: ['notification_id','user_id','title','body','read_at','created_at'],
  Audit_Log: ['log_id','user_id','action','entity','entity_id','details','created_at'],
  Sessions: ['token','user_id','expires_at'],
};

// --- الدوال المساعدة (Helpers) ---
function _ss() {
  const id = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
  if (!id) throw new Error('SPREADSHEET_ID غير مضبوط في Script Properties');
  return SpreadsheetApp.openById(id);
}

function _now() { return new Date().toISOString(); }

function _digest(str) {
  return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, str)
    .map((b) => ('0' + (b & 255).toString(16)).slice(-2)).join('');
}

function _all(name) {
  const sheet = _ss().getSheetByName(name);
  if (!sheet) return [];
  const values = sheet.getDataRange().getValues();
  const headers = values.shift();
  return values
    .filter((r) => r.join('').trim() !== '')
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

function _auth(token) {
  const s = _all('Sessions').find((x) => x.token === token && new Date(x.expires_at) > new Date());
  if (!s) throw new Error('انتهت الجلسة، يرجى تسجيل الدخول مجدداً');
  const u = _all('Users').find((x) => x.user_id === s.user_id && x.status === 'active');
  if (!u) throw new Error('الحساب غير نشط');
  return u;
}

function _needRole(user, roles) {
  if (!user || roles.indexOf(user.role) < 0) {
    throw new Error('ليست لديك الصلاحية لهذه العملية');
  }
}

// --- معالجة الطلبات ---
function doGet(e) {
  return _json({ ok: true, success: true, message: "Orca API is running" });
}

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents || '{}');
    let result = {};
    const action = body.action;

    if (action === 'login') {
      result = _handleLogin(body);
    } else {
      // محاولة التعرف على المستخدم عبر التوكن أو اسم المستخدم
      let user = null;
      if (body.token) {
        user = _auth(body.token);
      } else if (body.username || body.user) {
        const username = String(body.username || body.user).toLowerCase();
        user = _all('Users').find(u => String(u.username).toLowerCase() === username);
      }

      switch (action) {
        case 'getProducts':
        case 'products':
          result = _handleProducts(body, user);
          break;
        case 'getOrders':
          result = _handleGetOrders(body, user);
          break;
        case 'getOrderDetails':
          result = _handleOrderDetails(body, user);
          break;
        case 'updateOrderPricing':
          result = _handleUpdateOrderPricing(body, user);
          break;
        case 'updateCustomerOrder':
          result = _handleUpdateCustomerOrder(body, user);
          break;
        case 'confirmWarehousePrep':
          result = _handleWarehousePrep(body, user);
          break;
        case 'createOrder':
        case 'create_order':
          result = _handleCreateOrder(body, user);
          break;
        case 'updateOrderStatus':
          result = _handleUpdateStatus(body, user);
          break;
        case 'getCustomers':
          result = _handleGetCustomers(body, user);
          break;
        case 'getPayments':
          result = _handleGetPayments(body, user);
          break;
        case 'getInventoryMovements':
          result = _handleGetInventoryMovements(body, user);
          break;
        case 'syncFromDrive':
          result = _handleSyncFromDrive(body, user);
          break;
        case 'updateConfig':
          result = _handleUpdateConfig(body, user);
          break;
        case 'getReports':
          result = _handleReports(body, user);
          break;
        case 'getCustomerStatement':
          result = _handleGetCustomerStatement(body, user);
          break;
        case 'exportStatement':
          return _handleExportStatement(body, user);
        case 'getDashboardStats':
          result = _handleDashboardStats(body, user);
          break;
        case 'updateUser':
          result = _handleUpdateUser(body, user);
          break;
        case 'getNotifications':
          result = _handleGetNotifications(body, user);
          break;
        case 'markNotificationAsRead':
          result = _handleMarkNotificationAsRead(body, user);
          break;
        case 'createCustomer':
          result = _handleCreateCustomer(body, user);
          break;
        case 'addPayment':
          result = _handleAddPayment(body, user);
          break;
        case 'updateProductQuantity':
        case 'adjust_inventory':
          result = _handleUpdateProductQuantity(body, user);
          break;
        case 'createLowStockRequest':
          result = _handleCreateLowStockRequest(body, user);
          break;
        case 'getLowStockRequests':
          result = _handleGetLowStockRequests(body, user);
          break;
        case 'getShipments':
          result = _handleGetShipments(body, user);
          break;
        case 'shipment':
          result = _handleShipment(body, user);
          break;
        case 'updateShipmentStatus':
          result = _handleUpdateShipmentStatus(body, user);
          break;
        default:
          throw new Error('عملية غير معروفة: ' + action);
      }
    }

    return _json({ ok: true, success: true, ...result });
  } catch (err) {
    return _json({ ok: false, success: false, error: err.message });
  }
}

// --- العمليات (Handlers) ---

function _handleLogin(body) {
  const users = _all('Users');
  const username = String(body.username || body.user || '').toLowerCase();
  const u = users.find(x => String(x.username).toLowerCase() === username && x.status === 'active');

  if (!u) throw new Error('اسم المستخدم غير صحيح أو الحساب غير نشط');

  const hash = _digest(String(body.password || '') + u.salt);
  if (hash !== u.password_hash) throw new Error('كلمة المرور غير صحيحة');

  const token = Utilities.getUuid();
  _add('Sessions', {
    token: token,
    user_id: u.user_id,
    expires_at: new Date(Date.now() + 86400000).toISOString()
  });

  return {
    session: {
      token: token,
      user_id: u.user_id,
      username: u.username,
      full_name: u.full_name,
      role: u.role,
      customer_id: u.customer_id
    }
  };
}

function _handleProducts(body, user) {
  const q = String(body.q || '').toLowerCase();
  const products = _all('Products')
    .filter(p => !q || String(p.code).toLowerCase().includes(q) || String(p.name).toLowerCase().includes(q) || String(p.group).toLowerCase().includes(q))
    .map(p => ({
      code: p.code,
      name: p.name,
      category: p.group,
      origin: p.origin,
      unit: p.unit_1,
      quantity: Number(p.quantity || 0),
      price: Number(p.display_price || 0),
      image_url: p.image_name,
      notes: p.notes
    }));
  return { products: products };
}

function _handleGetOrders(body, user) {
  let orders = _all('Orders');
  if (user && user.role === 'customer' && user.customer_id) {
    orders = orders.filter(o => o.customer_id === user.customer_id);
  }
  return {
    orders: orders.map(o => ({
      id: o.order_id,
      status: o.status,
      date: o.created_at,
      note: o.note
    })).reverse()
  };
}

function _handleOrderDetails(body, user) {
  const orderId = body.orderId || body.order_id;
  const items = _all('Order_Items').filter(i => i.order_id === orderId);
  const products = _all('Products');

  const detailedItems = items.map(i => {
    const p = products.find(prod => prod.code === i.code);
    return {
      code: i.code,
      name: p ? p.name : 'منتج غير موجود',
      quantity: Number(i.quantity_requested || 0),
      unit: i.unit,
      price: Number(i.display_price_snapshot || 0),
      note: i.customer_note
    };
  });

  return { items: detailedItems };
}

function _handleCreateOrder(body, user) {
  if (!user) throw new Error('المستخدم غير معروف');
  const items = body.items;
  if (!Array.isArray(items) || !items.length) throw new Error('الطلبية فارغة');

  const orderId = 'OR-' + Utilities.formatDate(new Date(), "GMT+3", 'yyyyMMdd-HHmmss');

  _add('Orders', {
    order_id: orderId,
    customer_id: user.customer_id || 'GUEST',
    status: 'submitted',
    currency: 'USD',
    note: body.note || '',
    created_at: _now(),
    updated_at: _now(),
    created_by: user.user_id
  });

  const products = _all('Products');

  items.forEach((item, idx) => {
    const p = products.find(x => x.code === item.code);
    _add('Order_Items', {
      item_id: orderId + '-' + (idx + 1),
      order_id: orderId,
      code: item.code,
      unit: item.unit || (p ? p.unit_1 : ''),
      quantity_requested: item.quantity,
      display_price_snapshot: item.price || (p ? p.display_price : 0),
      status: 'pending',
      customer_note: item.note || ''
    });
  });

  _add('Audit_Log', {
    log_id: Utilities.getUuid(),
    user_id: user.user_id,
    action: 'CREATE_ORDER',
    entity: 'Orders',
    entity_id: orderId,
    details: 'إنشاء طلب جديد',
    created_at: _now(),
  });

  // إشعار المسؤولين بطلب جديد
  _notifyRole('admin', 'طلب جديد', `تم استلام طلب جديد برقم ${orderId} من العميل ${user.full_name}`);
  _notifyRole('accountant', 'طلب جديد للمراجعة', `الطلب ${orderId} بانتظار المراجعة المالية.`);

  return { order_id: orderId, message: "تم إنشاء الطلب بنجاح" };
}

function _handleGetNotifications(body, user) {
  if (!user) throw new Error('المستخدم غير معروف');
  const notifications = _all('Notifications').filter(n => n.user_id === user.user_id);
  return { notifications: notifications.reverse() };
}

function _handleMarkNotificationAsRead(body, user) {
  if (!user) throw new Error('المستخدم غير معروف');
  const notificationId = body.notificationId;
  const ss = _ss();
  const sheet = ss.getSheetByName('Notifications');
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const idIdx = headers.indexOf('notification_id');
  const readAtIdx = headers.indexOf('read_at');

  for (let i = 1; i < data.length; i++) {
    if (data[i][idIdx] === notificationId) {
      sheet.getRange(i + 1, readAtIdx + 1).setValue(_now());
      return { success: true };
    }
  }
  throw new Error('الإشعار غير موجود');
}

function _sendNotification(userId, title, body, metadata = {}) {
  _add('Notifications', {
    notification_id: Utilities.getUuid(),
    user_id: userId,
    title: title,
    body: body,
    read_at: '',
    created_at: _now(),
    // We can store metadata as a JSON string in a note or dedicated column if we expand the schema
    // For now, let's assume 'body' can contain context or we use the 'note' if we add it.
    // Let's stick to the current schema for simplicity but ensure it's functional.
  });
}

function _getStatusTextAr(status) {
  switch (status.toLowerCase()) {
    case 'submitted': return 'قيد المراجعة';
    case 'priced': return 'بانتظار تأكيدك (مسعرة)';
    case 'customer_changed': return 'تم تعديل الزبون (تحتاج مراجعة)';
    case 'customer_confirmed': return 'مؤكدة من الزبون';
    case 'approved': return 'معتمدة (قيد التجهيز)';
    case 'prepared': return 'جاهزة للشحن';
    case 'shipping': return 'قيد الشحن';
    case 'delivered': return 'تم التسليم';
    case 'returned': return 'مرتجع';
    default: return status;
  }
}

function _handleOrderDetails(body, user) {
  const orderId = body.orderId || body.order_id;
  const items = _all('Order_Items').filter(i => i.order_id === orderId);
  const products = _all('Products');
  const order = _all('Orders').find(o => o.order_id === orderId);
  const shipment = _all('Shipments').find(s => s.order_id === orderId);

  const detailedItems = items.map(i => {
    const p = products.find(prod => prod.code === i.code);
    return {
      item_id: i.item_id,
      code: i.code,
      name: p ? p.name : 'منتج غير موجود',
      quantity_requested: Number(i.quantity_requested || 0),
      quantity_approved: Number(i.quantity_approved || 0),
      quantity_prepared: Number(i.quantity_prepared || 0),
      unit: i.unit,
      price_offer: Number(i.display_price_snapshot || 0),
      final_price: Number(i.final_price || 0),
      currency: i.currency || 'USD',
      customer_note: i.customer_note,
      accountant_note: i.accountant_note,
      warehouse_note: i.warehouse_note,
      stock_available: p ? Number(p.quantity || 0) : 0
    };
  });

  return {
    items: detailedItems,
    order: order,
    shipment: shipment
  };
}

function _handleUpdateOrderPricing(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const orderId = body.orderId;
  const itemsUpdates = body.items; // Array of {item_id, quantity_approved, final_price, currency, accountant_note}

  const ss = _ss();
  const itemsSheet = ss.getSheetByName('Order_Items');
  const itemsData = itemsSheet.getDataRange().getValues();
  const itemsHeaders = itemsData[0];
  const itemIdIdx = itemsHeaders.indexOf('item_id');

  itemsUpdates.forEach(upd => {
    for (let i = 1; i < itemsData.length; i++) {
      if (itemsData[i][itemIdIdx] === upd.item_id) {
        itemsSheet.getRange(i + 1, itemsHeaders.indexOf('quantity_approved') + 1).setValue(upd.quantity_approved);
        itemsSheet.getRange(i + 1, itemsHeaders.indexOf('final_price') + 1).setValue(upd.final_price);
        itemsSheet.getRange(i + 1, itemsHeaders.indexOf('currency') + 1).setValue(upd.currency);
        itemsSheet.getRange(i + 1, itemsHeaders.indexOf('accountant_note') + 1).setValue(upd.accountant_note || '');
        break;
      }
    }
  });

  // تحديث حالة الطلب
  _updateStatusInternal(orderId, 'priced');

  // إشعار الزبون
  const order = _all('Orders').find(o => o.order_id === orderId);
  if (order) {
    const customerUser = _all('Users').find(u => u.customer_id === order.customer_id);
    if (customerUser) {
      _sendNotification(customerUser.user_id, 'تم تسعير الطلب', `طلبك رقم ${orderId} جاهز للمراجعة والتأكيد.`);
    }
  }

  return { success: true };
}

function _handleWarehousePrep(body, user) {
  _needRole(user, ['admin', 'warehouse']);
  const orderId = body.orderId;
  const itemsUpdates = body.items; // {item_id, quantity_prepared, warehouse_note}

  const ss = _ss();
  const itemsSheet = ss.getSheetByName('Order_Items');
  const itemsData = itemsSheet.getDataRange().getValues();
  const itemsHeaders = itemsData[0];

  itemsUpdates.forEach(upd => {
    for (let i = 1; i < itemsData.length; i++) {
      if (itemsData[i][itemsHeaders.indexOf('item_id')] === upd.item_id) {
        itemsSheet.getRange(i + 1, itemsHeaders.indexOf('quantity_prepared') + 1).setValue(upd.quantity_prepared);
        itemsSheet.getRange(i + 1, itemsHeaders.indexOf('warehouse_note') + 1).setValue(upd.warehouse_note || '');
        break;
      }
    }
  });

  // تسجيل الطرود في جدول الشحن
  _add('Shipments', {
    shipment_id: 'SHP-' + Utilities.getUuid().substring(0,8),
    order_id: orderId,
    package_count: body.package_count,
    carton_count: body.carton_count,
    bag_count: body.bag_count,
    status: 'prepared',
    shipping_date: _now()
  });

  _updateStatusInternal(orderId, 'prepared');

  // إشعار المحاسبين والمدراء
  _notifyRole('accountant', 'طلب مجهز', `تم تجهيز الطلب ${orderId} في المستودع.`);
  _notifyRole('admin', 'طلب مجهز', `الطلب ${orderId} جاهز للشحن.`);

  return { success: true };
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

function _handleUpdateStatus(body, user) {
  const orderId = body.orderId || body.order_id;
  const newStatus = body.status;

  if (newStatus === 'customer_confirmed') {
    _needRole(user, ['customer']);
  } else if (newStatus === 'approved') {
    _needRole(user, ['admin', 'accountant']);
    _reserveStock(orderId, user.user_id);
  } else {
    _needRole(user, ['admin', 'accountant', 'warehouse']);
  }

  const ss = _ss();
  const sheet = ss.getSheetByName('Orders');
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const orderIdIdx = headers.indexOf('order_id');
  const customerIdIdx = headers.indexOf('customer_id');
  const statusIdx = headers.indexOf('status');
  const updatedAtIdx = headers.indexOf('updated_at');

  for (let i = 1; i < data.length; i++) {
    if (data[i][orderIdIdx] === orderId) {
      const oldStatus = data[i][statusIdx];
      sheet.getRange(i + 1, statusIdx + 1).setValue(newStatus);
      sheet.getRange(i + 1, updatedAtIdx + 1).setValue(_now());

      // نظام الإشعارات الموسع
      if (newStatus === 'customer_confirmed') {
        _notifyRole('accountant', 'تأكيد زبون', `الزبون أكد الطلب ${orderId}.`);
      } else if (newStatus === 'approved') {
        _notifyRole('warehouse', 'طلب جديد للتجهيز', `تم اعتماد الطلب ${orderId}، يرجى البدء بالتجهيز.`);
        const customerUser = _all('Users').find(u => u.customer_id === data[i][customerIdIdx]);
        if (customerUser) _sendNotification(customerUser.user_id, 'تم اعتماد طلبك', `الطلب ${orderId} قيد التجهيز الآن.`);
      } else if (newStatus === 'shipping') {
        const customerUser = _all('Users').find(u => u.customer_id === data[i][customerIdIdx]);
        if (customerUser) _sendNotification(customerUser.user_id, 'بدأ الشحن', `طلبك رقم ${orderId} في الطريق إليك.`);
      } else if (newStatus === 'delivered') {
        const customerUser = _all('Users').find(u => u.customer_id === data[i][customerIdIdx]);
        if (customerUser) _sendNotification(customerUser.user_id, 'تم التسليم', `تم تأكيد استلام الطلب ${orderId}. شكراً لتعاملك معنا.`);
      }

      return { success: true };
    }
  }
  throw new Error('الطلب غير موجود');
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

function _handleUpdateCustomerOrder(body, user) {
  _needRole(user, ['customer']);
  const orderId = body.orderId;
  const items = body.items; // Array of {item_id, quantity, action: 'update' | 'delete'}

  const ss = _ss();
  const itemsSheet = ss.getSheetByName('Order_Items');
  const itemsData = itemsSheet.getDataRange().getValues();
  const headers = itemsData[0];
  const itemIdIdx = headers.indexOf('item_id');
  const qtyReqIdx = headers.indexOf('quantity_requested');
  const qtyAppIdx = headers.indexOf('quantity_approved');
  const codeIdx = headers.indexOf('code');

  // Identify all actions and their target rows
  let actions = [];
  items.forEach(upd => {
    for (let i = 1; i < itemsData.length; i++) {
      if (itemsData[i][itemIdIdx] === upd.item_id) {
        actions.push({ row: i + 1, data: itemsData[i], update: upd });
        break;
      }
    }
  });

  // Process updates first to avoid row-shift issues during updates
  const updates = actions.filter(a => a.update.action === 'update');
  updates.forEach(a => {
    const approved = Number(a.data[qtyAppIdx] || 0);
    const requested = Number(a.update.quantity || 0);

    // Strict enforcement: requested cannot be less than approved
    if (requested < approved) {
      throw new Error(`غير مسموح بتخفيض الكمية المصادق عليها للصنف (${a.data[codeIdx]}). المعتمد: ${approved}`);
    }

    itemsSheet.getRange(a.row, qtyReqIdx + 1).setValue(requested);
  });

  // Process deletions in reverse order of row numbers to maintain row integrity
  const deletes = actions.filter(a => a.update.action === 'delete').sort((a, b) => b.row - a.row);
  deletes.forEach(a => {
    itemsSheet.deleteRow(a.row);
  });

  _updateStatusInternal(orderId, 'customer_changed');

  // Log the change
  _add('Audit_Log', {
    log_id: Utilities.getUuid(),
    user_id: user.user_id,
    action: 'CUSTOMER_UPDATE_ORDER',
    entity: 'Orders',
    entity_id: orderId,
    details: `الزبون قام بتعديل الطلبية. بنود محدثة: ${updates.length}, بنود محذوفة: ${deletes.length}`,
    created_at: _now(),
  });

  return { success: true };
}

function _getStatusTextAr(status) {
  switch (status.toLowerCase()) {
    case 'submitted': return 'قيد المراجعة';
    case 'priced': return 'بانتظار تأكيدك (مسعرة)';
    case 'customer_changed': return 'تم تعديل الزبون (تحتاج مراجعة)';
    case 'customer_confirmed': return 'مؤكدة من الزبون';
    case 'approved': return 'معتمدة (قيد التجهيز)';
    case 'prepared': return 'جاهزة للشحن';
    case 'shipping': return 'قيد الشحن';
    case 'delivered': return 'تم التسليم';
    case 'returned': return 'مرتجع';
    default: return status;
  }
}

function _handleGetCustomers(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const customers = _all('Customers');
  const payments = _all('Payments');
  const orders = _all('Orders');
  const orderItems = _all('Order_Items');

  return {
    customers: customers.map(c => {
      // حساب إجمالي المدفوعات
      const totalPaid = payments
        .filter(p => p.customer_id === c.customer_id)
        .reduce((sum, p) => sum + Number(p.amount || 0), 0);

      // حساب إجمالي الطلبات (المعتمدة أو التي تم تسليمها فقط لضمان دقة المحاسبة)
      const customerOrders = orders.filter(o => o.customer_id === c.customer_id && ['approved', 'prepared', 'shipping', 'delivered'].includes(o.status));

      let totalOrdersValue = 0;
      customerOrders.forEach(o => {
        const items = orderItems.filter(oi => oi.order_id === o.order_id);
        items.forEach(item => {
          totalOrdersValue += Number(item.final_price || item.display_price_snapshot || 0) * Number(item.quantity_requested || 0);
        });
      });

      return {
        ...c,
        balance: Number((totalOrdersValue - totalPaid).toFixed(2))
      };
    })
  };
}

function _handleGetPayments(body, user) {
  _needRole(user, ['admin', 'accountant']);
  return { payments: _all('Payments') };
}

function _handleGetInventoryMovements(body, user) {
  _needRole(user, ['admin', 'warehouse']);
  const movements = _all('Inventory_Movements');
  const code = body.code;
  if (code) {
    return { movements: movements.filter(m => m.code === code).reverse() };
  }
  return { movements: movements.reverse() };
}

function _updateProductQuantity(code, delta) {
  const ss = _ss();
  const sheet = ss.getSheetByName('Products');
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const codeIdx = headers.indexOf('code');
  const qtyIdx = headers.indexOf('quantity');

  for (let i = 1; i < data.length; i++) {
    if (data[i][codeIdx] == code) {
      const currentQty = Number(data[i][qtyIdx] || 0);
      sheet.getRange(i + 1, qtyIdx + 1).setValue(currentQty + delta);
      return true;
    }
  }
  return false;
}

function _handleReceiveGoods(body, user) {
  _needRole(user, ['admin', 'warehouse']);
  const code = body.code;
  const qty = Number(body.quantity || 0);
  if (!code || qty <= 0) throw new Error('بيانات غير صالحة');

  if (_updateProductQuantity(code, qty)) {
    _add('Inventory_Movements', {
      movement_id: Utilities.getUuid(),
      code: code,
      type: 'receipt',
      quantity: qty,
      note: body.note || '',
      created_by: user.user_id,
      created_at: _now(),
    });
    return { success: true };
  }
  throw new Error('المنتج غير موجود');
}

function _handleAdjustInventory(body, user) {
  _needRole(user, ['admin', 'warehouse']);
  const code = body.code;
  const qty = Number(body.quantity || 0);
  if (!code || qty === 0) throw new Error('بيانات غير صالحة');

  if (_updateProductQuantity(code, qty)) {
    _add('Inventory_Movements', {
      movement_id: Utilities.getUuid(),
      code: code,
      type: body.type || 'adjustment',
      quantity: qty,
      note: body.note || '',
      created_by: user.user_id,
      created_at: _now(),
    });
    return { success: true };
  }
  throw new Error('المنتج غير موجود');
}

function _handleAddPayment(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const amount = Number(body.amount || 0);
  if (!body.customer_id || amount <= 0) throw new Error('بيانات غير صالحة');
  const paymentId = Utilities.getUuid();
  _add('Payments', {
    payment_id: paymentId,
    customer_id: body.customer_id,
    order_id: body.order_id || '',
    amount: amount,
    currency: body.currency || 'USD',
    method: body.method || 'cash',
    payment_date: body.payment_date || _now(),
    note: body.note || '',
    created_by: user.user_id,
  });

  // إشعار الزبون باستلام الدفعة
  const customerUser = _all('Users').find(u => u.customer_id === body.customer_id);
  if (customerUser) {
    _sendNotification(customerUser.user_id, 'تم استلام دفعة', `تم تقييد مبلغ ${amount} ${body.currency || 'USD'} في حسابكم.`);
  }

  return { success: true };
}

function _handleGetShipments(body, user) {
  _needRole(user, ['admin', 'accountant', 'warehouse']);
  return { shipments: _all('Shipments').reverse() };
}

function _handleShipment(body, user) {
  _needRole(user, ['admin', 'accountant', 'warehouse']);
  if (!body.order_id) throw new Error('رقم الطلب مطلوب');
  const shipmentId = 'SHP-' + Utilities.getUuid().substring(0, 8).toUpperCase();
  _add('Shipments', {
    shipment_id: shipmentId,
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
  return { success: true, shipment_id: shipmentId };
}

function _handleUpdateShipmentStatus(body, user) {
  _needRole(user, ['admin', 'warehouse']);
  const shipmentId = body.shipmentId || body.shipment_id;
  const newStatus = body.status;

  const ss = _ss();
  const sheet = ss.getSheetByName('Shipments');
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const idIdx = headers.indexOf('shipment_id');
  const statusIdx = headers.indexOf('status');

  for (let i = 1; i < data.length; i++) {
    if (data[i][idIdx] === shipmentId) {
      sheet.getRange(i + 1, statusIdx + 1).setValue(newStatus);
      return { success: true };
    }
  }
  throw new Error('الشحنة غير موجودة');
}

function _handleUpdateConfig(body, user) {
  _needRole(user, ['admin']);
  if (body.csv_file_id) {
    PropertiesService.getScriptProperties().setProperty('CSV_FILE_ID', body.csv_file_id);
  }
  if (body.spreadsheet_id) {
    PropertiesService.getScriptProperties().setProperty('SPREADSHEET_ID', body.spreadsheet_id);
  }
  return { success: true, message: 'تم تحديث الإعدادات بنجاح' };
}

function _handleSyncFromDrive(body, user) {
  _needRole(user, ['admin', 'accountant']);

  // استخدام المعرف الممرر في الطلب أو المخزن في الإعدادات أو الافتراضي
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

        // تحسين معالجة الحقول الرقمية
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
      message: `تمت المزامنة بنجاح: تحديث ${updated}، إضافة ${created}`,
      details: { updated, created }
    };
  } catch (e) {
    throw new Error('خطأ في مزامنة Drive: ' + e.message);
  }
}

function _handleImportProducts(body, user) {
  _needRole(user, ['admin']);
  const products = body.products;
  if (!Array.isArray(products)) throw new Error('بيانات غير صالحة');

  const ss = _ss();
  const sheet = ss.getSheetByName('Products');
  const existingProducts = _all('Products');

  let count = 0;
  products.forEach(p => {
    const existing = existingProducts.find(x => String(x.code) === String(p.code));
    if (existing) {
      const data = sheet.getDataRange().getValues();
      const headers = data[0];
      const codeIdx = headers.indexOf('code');
      for (let i = 1; i < data.length; i++) {
        if (data[i][codeIdx] == p.code) {
          headers.forEach((h, j) => {
             if (p[h] !== undefined && h !== 'code') {
               sheet.getRange(i + 1, j + 1).setValue(p[h]);
             }
          });
          break;
        }
      }
    } else {
      _add('Products', {
        code: p.code,
        name: p.name,
        group: p.group || p.category || '',
        origin: p.origin || '',
        unit_1: p.unit || p.unit_1 || 'قطعة',
        quantity: Number(p.quantity || 0),
        display_price: Number(p.price || p.display_price || 0),
        currency: p.currency || 'USD',
        updated_at: _now(),
        updated_by: user.user_id
      });
    }
    count++;
  });
  return { success: true, count: count };
}

// --- تهيئة النظام (Setup) ---

function setupSystem() {
  const ss = _ss();
  Object.keys(H).forEach(name => {
    let sheet = ss.getSheetByName(name) || ss.insertSheet(name);
    if (sheet.getLastRow() === 0) sheet.appendRow(H[name]);
    sheet.setFrozenRows(1);
  });
}

// --- وظائف إضافية للميزات الجديدة ---

function _handleDashboardStats(body, user) {
  const products = _all('Products');
  const orders = _all('Orders');
  const customers = _all('Customers');
  const payments = _all('Payments');

  if (user.role === 'customer') {
    const myOrders = orders.filter(o => o.customer_id === user.customer_id);
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

  // للمسؤولين والمحاسبين والمستودع
  const stats = [];
  if (['admin', 'accountant'].includes(user.role)) {
    stats.push({ title: 'إجمالي العملاء', value: customers.length.toString(), icon: 'people' });
    const totalRevenue = payments.reduce((sum, p) => sum + Number(p.amount), 0);
    stats.push({ title: 'إجمالي التحصيلات', value: totalRevenue.toFixed(2) + ' $', icon: 'attach_money' });
  }

  if (['admin', 'warehouse'].includes(user.role)) {
    const lowStock = products.filter(p => Number(p.quantity) < 10).length;
    stats.push({ title: 'منتجات منخفضة المخزون', value: lowStock.toString(), icon: 'inventory' });
  }

  stats.push({ title: 'الطلبات الجديدة', value: orders.filter(o => o.status === 'submitted').length.toString(), icon: 'new_releases' });

  return { stats };
}

function _handleUpdateUser(body, user) {
  const ss = _ss();
  const sheet = ss.getSheetByName('Users');
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const userIdIdx = headers.indexOf('user_id');
  const fullNameIdx = headers.indexOf('full_name');
  const phoneIdx = headers.indexOf('phone');
  const passHashIdx = headers.indexOf('password_hash');
  const saltIdx = headers.indexOf('salt');

  for (let i = 1; i < data.length; i++) {
    if (data[i][userIdIdx] === user.user_id) {
      if (body.full_name) sheet.getRange(i + 1, fullNameIdx + 1).setValue(body.full_name);
      if (body.phone) sheet.getRange(i + 1, phoneIdx + 1).setValue(body.phone);

      if (body.new_password) {
        const newSalt = Utilities.getUuid();
        const newHash = _digest(body.new_password + newSalt);
        sheet.getRange(i + 1, passHashIdx + 1).setValue(newHash);
        sheet.getRange(i + 1, saltIdx + 1).setValue(newSalt);
      }
      return { success: true, message: 'تم تحديث البيانات بنجاح' };
    }
  }
  throw new Error('المستخدم غير موجود');
}

function _handleCreateCustomer(body, user) {
  _needRole(user, ['admin', 'accountant']);

  const customerId = 'CUS-' + Utilities.getUuid().substring(0, 5).toUpperCase();
  const username = body.username.toLowerCase();

  // التحقق من تكرار اسم المستخدم
  const existing = _all('Users').find(u => u.username === username);
  if (existing) throw new Error('اسم المستخدم موجود مسبقاً');

  // إضافة العميل
  _add('Customers', {
    customer_id: customerId,
    full_name: body.full_name,
    company_name: body.company_name || '',
    phone: body.phone || '',
    address: body.address || '',
    status: 'active',
    created_at: _now()
  });

  // إنشاء حساب مستخدم للعميل بكلمة مرور افتراضية (نفس اسم المستخدم)
  const salt = Utilities.getUuid();
  _add('Users', {
    user_id: 'USR-' + Utilities.getUuid().substring(0, 5),
    username: username,
    password_hash: _digest(username + salt), // الباسورد الافتراضية هي اليوزرنيم
    salt: salt,
    full_name: body.full_name,
    role: 'customer',
    customer_id: customerId,
    status: 'active',
    created_at: _now()
  });

  return { success: true, customer_id: customerId, message: 'تم إنشاء حساب العميل بنجاح' };
}

function _handleUpdateProductQuantity(body, user) {
  _needRole(user, ['admin', 'warehouse']);
  const code = body.code;
  const delta = Number(body.quantity || 0);

  if (_updateProductQuantity(code, delta)) {
    _add('Inventory_Movements', {
      movement_id: Utilities.getUuid(),
      code: code,
      type: delta > 0 ? 'receipt' : 'adjustment',
      quantity: Math.abs(delta),
      note: body.note || 'تحديث مخزون يدوي',
      created_by: user.user_id,
      created_at: _now(),
    });
    return { success: true, message: 'تم تحديث المخزون' };
  }
  throw new Error('المنتج غير موجود');
}

function _handleReports(body, user) {
  _needRole(user, ['admin']);

  const orders = _all('Orders');
  const items = _all('Order_Items');
  const products = _all('Products');

  // إحصائيات الطلبات حسب الحالة
  const statusStats = {};
  orders.forEach(o => {
    statusStats[o.status] = (statusStats[o.status] || 0) + 1;
  });

  // المبيعات حسب التصنيف
  const categorySales = {};
  items.forEach(item => {
    const p = products.find(prod => prod.code === item.code);
    const cat = p ? p.group : 'غير مصنف';
    const total = Number(item.final_price || item.display_price_snapshot || 0) * Number(item.quantity_requested || 0);
    categorySales[cat] = (categorySales[cat] || 0) + total;
  });

  return {
    statusStats: Object.entries(statusStats).map(([name, value]) => ({ name, value })),
    categorySales: Object.entries(categorySales).map(([name, value]) => ({ name, value: Number(value.toFixed(2)) }))
  };
}

function _handleCreateLowStockRequest(body, user) {
  _needRole(user, ['admin', 'warehouse']);
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

  // إشعار المسؤولين بطلب نواقص جديد
  _notifyRole('admin', 'طلب نواقص جديد', `قام المستودع بطلب نواقص للمنتج ${body.code} بكمية ${body.requested_qty}`);
  _notifyRole('accountant', 'تنبيه مخزون', `تم تسجيل طلب نقص مواد للمنتج ${body.code}.`);

  return { success: true, request_id: requestId };
}

function _handleGetLowStockRequests(body, user) {
  _needRole(user, ['admin', 'warehouse']);
  return { requests: _all('Low_Stock_Requests').reverse() };
}

function _handleGetCustomerStatement(body, user) {
  _needRole(user, ['admin', 'accountant', 'customer']);

  const customerId = body.customer_id || (user.role === 'customer' ? user.customer_id : null);
  if (!customerId) throw new Error('رقم العميل مطلوب');

  if (user.role === 'customer' && user.customer_id !== customerId) {
    throw new Error('غير مصرح لك بعرض بيانات عميل آخر');
  }

  const customer = _all('Customers').find(c => c.customer_id === customerId);
  if (!customer) throw new Error('العميل غير موجود');

  const payments = _all('Payments').filter(p => p.customer_id === customerId);
  const orders = _all('Orders').filter(o => o.customer_id === customerId && ['approved', 'prepared', 'shipping', 'delivered'].includes(o.status));
  const orderItems = _all('Order_Items');

  let statement = [];

  const openingUsd = Number(customer.opening_usd || 0);
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
    items.forEach(item => {
      total += Number(item.final_price || item.display_price_snapshot || 0) * Number(item.quantity_requested || 0);
    });

    statement.push({
      date: o.created_at,
      type: 'طلب بضاعة',
      ref: o.order_id,
      debit: total,
      credit: 0,
      note: o.note || ''
    });
  });

  payments.forEach(p => {
    statement.push({
      date: p.payment_date,
      type: 'دفعة نقدية',
      ref: p.payment_id,
      debit: 0,
      credit: Number(p.amount),
      note: p.note || p.method || ''
    });
  });

  statement.sort((a, b) => new Date(a.date) - new Date(b.date));

  let runningBalance = 0;
  statement = statement.map(s => {
    runningBalance += (s.debit - s.credit);
    return { ...s, balance: Number(runningBalance.toFixed(2)) };
  });

  return {
    customer: {
      full_name: customer.full_name,
      company_name: customer.company_name,
      customer_id: customer.customer_id
    },
    statement: statement.reverse(),
    finalBalance: Number(runningBalance.toFixed(2))
  };
}

function _handleExportStatement(body, user) {
  _needRole(user, ['admin', 'accountant', 'customer']);
  const res = _handleGetCustomerStatement(body, user);
  const customer = res.customer;
  const statement = res.statement;

  let html = `
    <div dir="rtl" style="font-family: Arial, sans-serif; padding: 20px;">
      <h1 style="color: #00658f; text-align: center;">كشف حساب عميل</h1>
      <hr/>
      <table style="width: 100%; margin-bottom: 20px;">
        <tr>
          <td><strong>العميل:</strong> ${customer.full_name}</td>
          <td style="text-align: left;"><strong>التاريخ:</strong> ${new Date().toLocaleDateString('ar-EG')}</td>
        </tr>
        <tr>
          <td><strong>الشركة:</strong> ${customer.company_name || '-'}</td>
          <td style="text-align: left;"><strong>رقم العميل:</strong> ${customer.customer_id}</td>
        </tr>
      </table>

      <table border="1" style="width: 100%; border-collapse: collapse; text-align: center;">
        <thead style="background-color: #f2f2f2;">
          <tr>
            <th>التاريخ</th>
            <th>البيان</th>
            <th>المرجع</th>
            <th>مدين ($)</th>
            <th>دائن ($)</th>
            <th>الرصيد ($)</th>
          </tr>
        </thead>
        <tbody>
          ${statement.map(s => `
            <tr>
              <td>${s.date.split('T')[0]}</td>
              <td>${s.type}</td>
              <td>${s.ref}</td>
              <td style="color: ${s.debit > 0 ? 'red' : 'black'}">${s.debit || '-'}</td>
              <td style="color: ${s.credit > 0 ? 'green' : 'black'}">${s.credit || '-'}</td>
              <td style="font-weight: bold;">${s.balance}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>

      <div style="margin-top: 30px; text-align: left;">
        <h3>الرصيد الإجمالي: ${res.finalBalance} $</h3>
      </div>

      <div style="margin-top: 50px; text-align: center; color: #888; font-size: 10px;">
        تم الإنشاء بواسطة نظام أوركا أوردر - ${new Date().toLocaleString('ar-EG')}
      </div>
    </div>
  `;

  const blob = HtmlService.createHtmlOutput(html).getAs('application/pdf');
  blob.setName(`Statement_${customer.full_name}_${new Date().getTime()}.pdf`);

  // لتبسيط الأمر في GAS بدون إعدادات معقدة لـ Drive API، سنقوم بإرجاع الـ PDF كـ Base64
  // أو يمكننا استخدام URL إذا كان لدينا مجلد عام
  return _json({
    ok: true,
    success: true,
    pdfBase64: Utilities.base64Encode(blob.getBytes()),
    fileName: blob.getName()
  });
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
  const readAtIdx = headers.indexOf('read_at');

  for (let i = 1; i < data.length; i++) {
    if (data[i][idIdx] === notificationId) {
      sheet.getRange(i + 1, readAtIdx + 1).setValue(_now());
      return { success: true };
    }
  }
  throw new Error('الإشعار غير موجود');
}
