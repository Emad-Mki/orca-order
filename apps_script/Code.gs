const H = {
  Users: ['user_id','username','password_hash','salt','full_name','phone','role','customer_id','status','must_change_password','created_at','last_login'],
  Customers: ['customer_id','full_name','company_name','phone','address','province','notes','opening_usd','opening_syp','status','created_at'],
  Products: ['code','name','image_name','group','origin','unit_1','quantity','unit_2','factor_2','quantity_2','factor_3','unit_3','quantity_3','display_price','currency','notes','updated_at','updated_by'],
  Orders: ['order_id','customer_id','customer_name','status','currency','note','accounting_invoice_no','is_read','is_new','cancellation_reason','created_at','updated_at','created_by'],
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
        case 'getProducts':
          result = _handleProducts(body, user);
          break;
        case 'getOrders':
          result = _handleGetOrders(body, user);
          break;
        case 'getOrderDetails':
          result = _handleGetOrderDetails(body, user);
          break;
        case 'createOrder':
          result = _handleCreateOrder(body, user);
          break;
        case 'updateOrderStatus':
          result = _handleUpdateOrderStatus(body, user);
          break;
        case 'markOrderAsRead':
          result = _handleMarkOrderAsRead(body, user);
          break;
        case 'cancelOrder':
          result = _handleCancelOrder(body, user);
          break;
        case 'deleteOrder':
          result = _handleDeleteOrder(body, user);
          break;
        case 'updateOrderPricing':
          result = _handleUpdateOrderPricing(body, user);
          break;
        case 'updateCustomerOrder':
          result = _handleUpdateCustomerOrder(body, user);
          break;
        case 'confirmWarehousePrep':
          result = _handleConfirmWarehousePrep(body, user);
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
        case 'getCustomers':
          result = _handleGetCustomers(body, user);
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

// جلب قائمة الزبائن
function _handleGetCustomers(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const customers = _all('Customers')
    .filter(c => c.status !== 'deleted' && c.status !== 'inactive')
    .map(c => ({
      customer_id: c.customer_id,
      full_name: c.full_name,
      company_name: c.company_name,
      phone: c.phone,
    }));
  return { customers: customers };
}

// جلب الطلبات مع دعم الفلترة حسب الزبون
function _handleGetOrders(body, user) {
  const role = user.role;
  let orders = _all('Orders');
  
  // فلترة حسب الزبون إذا تم تحديده (للمدير والمحاسب فقط)
  if (body.customer_id && (role === 'admin' || role === 'manager' || role === 'accountant')) {
    orders = orders.filter(o => o.customer_id === body.customer_id);
  } else if (role === 'customer' && user.customer_id) {
    // الزبون يرى طلباته فقط
    orders = orders.filter(o => o.customer_id === user.customer_id);
  }
  
  // إضافة اسم الزبون لكل طلب
  const customers = _all('Customers');
  orders = orders.map(o => {
    const customer = customers.find(c => c.customer_id === o.customer_id);
    return {
      ...o,
      customer_name: customer ? customer.full_name : 'غير معروف',
      is_new: o.is_new === 'true' || o.is_new === true || o.is_read === 'false' || o.is_read === false || o.is_read === '0',
    };
  });
  
  // ترتيب حسب الأحدث أولاً
  orders.sort((a, b) => {
    const dateA = new Date(a.created_at || a.date || 0);
    const dateB = new Date(b.created_at || b.date || 0);
    return dateB - dateA;
  });
  
  return { orders: orders };
}

// جلب تفاصيل طلب معين
function _handleGetOrderDetails(body, user) {
  const orderId = body.orderId;
  if (!orderId) throw new Error('رقم الطلب مطلوب');
  
  const orders = _all('Orders').filter(o => o.order_id === orderId);
  if (orders.length === 0) throw new Error('الطلب غير موجود');
  
  const order = orders[0];
  
  // التحقق من الصلاحية
  if (user.role === 'customer' && order.customer_id !== user.customer_id) {
    throw new Error('ليس لديك صلاحية عرض هذا الطلب');
  }
  
  const items = _all('Order_Items')
    .filter(i => i.order_id === orderId)
    .map(i => {
      const product = _all('Products').find(p => p.code === i.code);
      return {
        ...i,
        name: product ? product.name : i.code,
        price_offer: product ? product.display_price : 0,
        stock_available: product ? product.quantity : 0,
      };
    });
  
  const customers = _all('Customers');
  const customer = customers.find(c => c.customer_id === order.customer_id);
  
  // حساب رصيد الزبون
  const payments = _all('Payments').filter(p => p.customer_id === order.customer_id);
  const totalPaid = payments.reduce((sum, p) => sum + Number(p.amount || 0), 0);
  
  const allOrders = _all('Orders').filter(o => o.customer_id === order.customer_id && o.status !== 'cancelled' && o.status !== 'deleted');
  const totalOrders = allOrders.reduce((sum, o) => {
    const orderItems = _all('Order_Items').filter(i => i.order_id === o.order_id);
    const orderTotal = orderItems.reduce((s, i) => s + (Number(i.final_price || i.display_price_snapshot || 0) * Number(i.quantity_approved || i.quantity_requested || 0)), 0);
    return sum + orderTotal;
  }, 0);
  
  const currentBalance = totalOrders - totalPaid + (Number(customer?.opening_usd || 0));
  
  return {
    order: order,
    items: items,
    balanceInfo: { current_balance: currentBalance, total_paid: totalPaid },
  };
}

// إنشاء طلب جديد
function _handleCreateOrder(body, user) {
  const items = body.items;
  if (!Array.isArray(items) || !items.length) {
    throw new Error('الطلبية فارغة');
  }
  
  // السماح للمدير/المحاسب بإنشاء طلب باسم زبون آخر
  let customerId = user.customer_id;
  if ((user.role === 'admin' || user.role === 'manager' || user.role === 'accountant') && body.customer_id) {
    customerId = body.customer_id;
  }
  
  const year = new Date().getFullYear();
  const existing = _all('Orders').filter(o => String(o.order_id).includes('OR-' + year));
  const seq = existing.length + 1;
  const orderId = 'OR-' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd') + '-' + String(seq).padStart(6, '0');
  
  const customers = _all('Customers');
  const customer = customers.find(c => c.customer_id === customerId);
  
  _add('Orders', {
    order_id: orderId,
    customer_id: customerId,
    customer_name: customer ? customer.full_name : '',
    status: 'pending',
    currency: 'USD',
    note: body.note || '',
    accounting_invoice_no: '',
    is_read: 'false',
    is_new: 'true',
    cancellation_reason: '',
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

// تحديث حالة الطلب
function _handleUpdateOrderStatus(body, user) {
  const orderId = body.orderId;
  const newStatus = body.status;
  if (!orderId || !newStatus) throw new Error('بيانات غير صالحة');
  
  const orders = _all('Orders');
  const orderIndex = orders.findIndex(o => o.order_id === orderId);
  if (orderIndex === -1) throw new Error('الطلب غير موجود');
  
  const sheet = _ss().getSheetByName('Orders');
  const rowIndex = orderIndex + 2; // +2 لأن الصف الأول للعناوين
  
  // تحديث الحالة
  const statusCol = H.Orders.indexOf('status') + 1;
  sheet.getRange(rowIndex, statusCol).setValue(newStatus);
  
  // تحديث وقت التحديث
  const updatedCol = H.Orders.indexOf('updated_at') + 1;
  sheet.getRange(rowIndex, updatedCol).setValue(_now());
  
  _add('Audit_Log', {
    log_id: Utilities.getUuid(),
    user_id: user.user_id,
    action: 'UPDATE_ORDER_STATUS',
    entity: 'Orders',
    entity_id: orderId,
    details: `تحديث الحالة إلى: ${newStatus}`,
    created_at: _now(),
  });
  
  return { success: true };
}

// تعليم الطلب كمقروء
function _handleMarkOrderAsRead(body, user) {
  const orderId = body.order_id;
  if (!orderId) throw new Error('رقم الطلب مطلوب');
  
  const orders = _all('Orders');
  const orderIndex = orders.findIndex(o => o.order_id === orderId);
  if (orderIndex === -1) throw new Error('الطلب غير موجود');
  
  const sheet = _ss().getSheetByName('Orders');
  const rowIndex = orderIndex + 2;
  
  // تحديث is_read و is_new
  const isReadCol = H.Orders.indexOf('is_read') + 1;
  const isNewCol = H.Orders.indexOf('is_new') + 1;
  sheet.getRange(rowIndex, isReadCol).setValue('true');
  sheet.getRange(rowIndex, isNewCol).setValue('false');
  
  return { success: true };
}

// إلغاء طلب
function _handleCancelOrder(body, user) {
  const orderId = body.orderId;
  const reason = body.cancellation_reason || '';
  if (!orderId) throw new Error('رقم الطلب مطلوب');
  
  const orders = _all('Orders');
  const orderIndex = orders.findIndex(o => o.order_id === orderId);
  if (orderIndex === -1) throw new Error('الطلب غير موجود');
  
  const sheet = _ss().getSheetByName('Orders');
  const rowIndex = orderIndex + 2;
  
  // تحديث الحالة وسبب الإلغاء
  const statusCol = H.Orders.indexOf('status') + 1;
  const reasonCol = H.Orders.indexOf('cancellation_reason') + 1;
  const updatedCol = H.Orders.indexOf('updated_at') + 1;
  
  sheet.getRange(rowIndex, statusCol).setValue('cancelled');
  sheet.getRange(rowIndex, reasonCol).setValue(reason);
  sheet.getRange(rowIndex, updatedCol).setValue(_now());
  
  _add('Audit_Log', {
    log_id: Utilities.getUuid(),
    user_id: user.user_id,
    action: 'CANCEL_ORDER',
    entity: 'Orders',
    entity_id: orderId,
    details: `إلغاء الطلب. السبب: ${reason}`,
    created_at: _now(),
  });
  
  return { success: true };
}

// حذف طلب نهائي
function _handleDeleteOrder(body, user) {
  const orderId = body.orderId;
  const reason = body.cancellation_reason || '';
  if (!orderId) throw new Error('رقم الطلب مطلوب');
  
  const orders = _all('Orders');
  const orderIndex = orders.findIndex(o => o.order_id === orderId);
  if (orderIndex === -1) throw new Error('الطلب غير موجود');
  
  const sheet = _ss().getSheetByName('Orders');
  const rowIndex = orderIndex + 2;
  
  // تحديث الحالة والحقل deleted
  const statusCol = H.Orders.indexOf('status') + 1;
  const reasonCol = H.Orders.indexOf('cancellation_reason') + 1;
  const updatedCol = H.Orders.indexOf('updated_at') + 1;
  
  sheet.getRange(rowIndex, statusCol).setValue('deleted');
  sheet.getRange(rowIndex, reasonCol).setValue(reason);
  sheet.getRange(rowIndex, updatedCol).setValue(_now());
  
  // حذف بنود الطلب أيضاً
  const orderItems = _all('Order_Items').filter(i => i.order_id === orderId);
  const itemsSheet = _ss().getSheetByName('Order_Items');
  orderItems.forEach(item => {
    const itemRowIndex = orderItems.indexOf(item) + 2;
    itemsSheet.deleteRow(itemRowIndex);
  });
  
  _add('Audit_Log', {
    log_id: Utilities.getUuid(),
    user_id: user.user_id,
    action: 'DELETE_ORDER',
    entity: 'Orders',
    entity_id: orderId,
    details: `حذف نهائي للطلب. السبب: ${reason}`,
    created_at: _now(),
  });
  
  return { success: true };
}

// تحديث تسعير الطلب (للمحاسب)
function _handleUpdateOrderPricing(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  const orderId = body.orderId;
  const items = body.items;
  if (!orderId || !Array.isArray(items)) throw new Error('بيانات غير صالحة');
  
  const itemsSheet = _ss().getSheetByName('Order_Items');
  const allItems = _all('Order_Items');
  
  items.forEach(updateItem => {
    const itemIndex = allItems.findIndex(i => i.item_id === updateItem.item_id);
    if (itemIndex !== -1) {
      const rowIndex = itemIndex + 2;
      const qtyApprovedCol = H.Order_Items.indexOf('quantity_approved') + 1;
      const finalPriceCol = H.Order_Items.indexOf('final_price') + 1;
      const accountantNoteCol = H.Order_Items.indexOf('accountant_note') + 1;
      
      itemsSheet.getRange(rowIndex, qtyApprovedCol).setValue(Number(updateItem.quantity_approved || 0));
      itemsSheet.getRange(rowIndex, finalPriceCol).setValue(Number(updateItem.final_price || 0));
      itemsSheet.getRange(rowIndex, accountantNoteCol).setValue(updateItem.accountant_note || '');
    }
  });
  
  // تحديث حالة الطلب إلى priced
  const orders = _all('Orders');
  const orderIndex = orders.findIndex(o => o.order_id === orderId);
  if (orderIndex !== -1) {
    const ordersSheet = _ss().getSheetByName('Orders');
    const rowIndex = orderIndex + 2;
    const statusCol = H.Orders.indexOf('status') + 1;
    const updatedCol = H.Orders.indexOf('updated_at') + 1;
    ordersSheet.getRange(rowIndex, statusCol).setValue('priced');
    ordersSheet.getRange(rowIndex, updatedCol).setValue(_now());
  }
  
  return { success: true };
}

// تحديث طلب من قبل الزبون (تعديل الكميات أو حذف مواد)
function _handleUpdateCustomerOrder(body, user) {
  const orderId = body.orderId;
  const items = body.items;
  if (!orderId || !Array.isArray(items)) throw new Error('بيانات غير صالحة');
  
  const itemsSheet = _ss().getSheetByName('Order_Items');
  const allItems = _all('Order_Items');
  
  items.forEach(updateItem => {
    if (updateItem.action === 'delete') {
      // حذف بند
      const itemIndex = allItems.findIndex(i => i.item_id === updateItem.item_id);
      if (itemIndex !== -1) {
        itemsSheet.deleteRow(itemIndex + 2);
      }
    } else if (updateItem.action === 'update') {
      // تحديث كمية
      const itemIndex = allItems.findIndex(i => i.item_id === updateItem.item_id);
      if (itemIndex !== -1) {
        const rowIndex = itemIndex + 2;
        const qtyRequestedCol = H.Order_Items.indexOf('quantity_requested') + 1;
        itemsSheet.getRange(rowIndex, qtyRequestedCol).setValue(Number(updateItem.quantity || 0));
      }
    }
  });
  
  // تحديث حالة الطلب إلى customer_changed
  const orders = _all('Orders');
  const orderIndex = orders.findIndex(o => o.order_id === orderId);
  if (orderIndex !== -1) {
    const ordersSheet = _ss().getSheetByName('Orders');
    const rowIndex = orderIndex + 2;
    const statusCol = H.Orders.indexOf('status') + 1;
    const updatedCol = H.Orders.indexOf('updated_at') + 1;
    ordersSheet.getRange(rowIndex, statusCol).setValue('customer_changed');
    ordersSheet.getRange(rowIndex, updatedCol).setValue(_now());
  }
  
  return { success: true };
}

// تأكيد تجهيز المستودع
function _handleConfirmWarehousePrep(body, user) {
  _needRole(user, ['admin', 'manager', 'warehouse']);
  const orderId = body.orderId;
  const items = body.items;
  if (!orderId || !Array.isArray(items)) throw new Error('بيانات غير صالحة');
  
  const itemsSheet = _ss().getSheetByName('Order_Items');
  const allItems = _all('Order_Items');
  
  items.forEach(prepItem => {
    const itemIndex = allItems.findIndex(i => i.item_id === prepItem.item_id);
    if (itemIndex !== -1) {
      const rowIndex = itemIndex + 2;
      const qtyPreparedCol = H.Order_Items.indexOf('quantity_prepared') + 1;
      const warehouseNoteCol = H.Order_Items.indexOf('warehouse_note') + 1;
      
      itemsSheet.getRange(rowIndex, qtyPreparedCol).setValue(Number(prepItem.quantity_prepared || 0));
      itemsSheet.getRange(rowIndex, warehouseNoteCol).setValue(prepItem.warehouse_note || '');
    }
  });
  
  // تحديث حالة الطلب إلى prepared
  const orders = _all('Orders');
  const orderIndex = orders.findIndex(o => o.order_id === orderId);
  if (orderIndex !== -1) {
    const ordersSheet = _ss().getSheetByName('Orders');
    const rowIndex = orderIndex + 2;
    const statusCol = H.Orders.indexOf('status') + 1;
    const updatedCol = H.Orders.indexOf('updated_at') + 1;
    ordersSheet.getRange(rowIndex, statusCol).setValue('prepared');
    ordersSheet.getRange(rowIndex, updatedCol).setValue(_now());
  }
  
  return { success: true };
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

// إنشاء طلب جديد (للزبون فقط) - دالة إضافية للتوافق مع الإصدارات القديمة
function _handleCreateOrderOld(body, user) {
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
    customer_name: '',
    status: 'pending',
    currency: 'USD',
    note: body.note || '',
    accounting_invoice_no: '',
    is_read: 'false',
    is_new: 'true',
    cancellation_reason: '',
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
