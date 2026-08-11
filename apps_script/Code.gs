const H = {
  Users: ['user_id','username','password_hash','salt','full_name','phone','role','customer_id','status','must_change_password','created_at','last_login'],
  Customers: ['customer_id','full_name','company_name','phone','address','province','notes','opening_usd','opening_syp','status','created_at'],
  Products: ['code','name','image_name','group','origin','unit_1','quantity','unit_2','factor_2','quantity_2','factor_3','unit_3','quantity_3','display_price','currency','notes','updated_at','updated_by'],
  Orders: ['order_id','customer_id','customer_name','status','currency','note','accounting_invoice_no','is_read','is_new','cancellation_reason','created_at','updated_at','created_by'],
  Order_Items: ['item_id','order_id','code','unit','quantity_requested','quantity_approved','display_price_snapshot','final_price','status','customer_note','accountant_note','warehouse_note'],
  Payments: ['payment_id','customer_id','order_id','amount','currency','box_type','method','payment_date','note','created_by','created_at','action_type'],
  Boxes_Balance: ['box_id','box_name','currency','balance','last_updated'],
  Sham_Cash_Balance: ['id','currency','balance','last_updated'],
  Inventory_Movements: ['movement_id','code','type','quantity','note','created_by','created_at'],
  Shipments: ['shipment_id','order_id','delivery_method','carrier','tracking_no','province','shipping_cost_internal','shipping_date','status','note'],
  Low_Stock_Requests: ['request_id','code','requested_qty','status','note','created_by','created_at'],
  Notifications: ['notification_id','user_id','title','body','type','entity_type','entity_id','read_at','created_at'],
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
        case 'getPayments':
          result = _handleGetPayments(body, user);
          break;
        case 'recordPayment':
          result = _handleRecordPayment(body, user);
          break;
        case 'updatePayment':
          result = _handleUpdatePayment(body, user);
          break;
        case 'deletePayment':
          result = _handleDeletePayment(body, user);
          break;
        case 'getBoxBalances':
          result = _handleGetBoxBalances(body, user);
          break;
        case 'sendNotification':
          result = _handleSendNotification(body, user);
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
  const orderId = body.orderId || body.order_id;
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
  const orderId = body.orderId || body.order_id;
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
  const orderId = body.orderId || body.order_id;
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
  const orderId = body.orderId || body.order_id;
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
  const orderId = body.orderId || body.order_id;
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
  const orderId = body.orderId || body.order_id;
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
    const customerNameCol = H.Orders.indexOf('customer_name') + 1;
    
    ordersSheet.getRange(rowIndex, statusCol).setValue('priced');
    ordersSheet.getRange(rowIndex, updatedCol).setValue(_now());
    
    // جلب اسم الزبون لإرسال الإشعار
    const customerName = ordersSheet.getRange(rowIndex, customerNameCol).getValue();
    
    // إرسال إشعار للزبون بأن التسعير جاهز
    try {
      const notificationData = {
        action: 'sendNotification',
        title: 'تم تسعير طلبك',
        body: `تم اعتماد أسعار طلبك رقم ${orderId}. يرجى مراجعة الفاتورة وتأكيدها.`,
        type: 'order_priced',
        orderId: orderId,
        targetRoles: ['customer'],
        customerName: customerName
      };
      
      // استدعاء دالة إرسال الإشعارات
      _sendNotificationToUser(notificationData);
    } catch (notifError) {
      Logger.log('خطأ في إرسال الإشعار: ' + notifError);
      // لا نوقف العملية إذا فشل الإشعار
    }
  }
  
  return { success: true, message: 'تم إرسال التسعير بنجاح' };
}

// دالة مساعدة لإرسال إشعار لمستخدم محدد
function _sendNotificationToUser(data) {
  try {
    const notificationsSheet = _ss().getSheetByName('Notifications');
    if (!notificationsSheet) {
      Logger.log('جدول Notifications غير موجود');
      return;
    }
    
    const headers = _getHeaders('Notifications');
    const newRow = [];
    
    // إنشاء صف جديد للإشعار
    headers.forEach(h => {
      let value = '';
      switch(h) {
        case 'notification_id': value = Utilities.getUuid(); break;
        case 'title': value = data.title || ''; break;
        case 'body': value = data.body || ''; break;
        case 'type': value = data.type || 'general'; break;
        case 'order_id': value = data.orderId || ''; break;
        case 'customer_name': value = data.customerName || ''; break;
        case 'target_role': value = data.targetRoles ? data.targetRoles.join(',') : ''; break;
        case 'is_read': value = false; break;
        case 'created_at': value = _now(); break;
        default: value = '';
      }
      newRow.push(value);
    });
    
    notificationsSheet.appendRow(newRow);
    Logger.log('تم حفظ الإشعار بنجاح');
  } catch (e) {
    Logger.log('خطأ في حفظ الإشعار: ' + e);
  }
}

// تحديث طلب من قبل الزبون (تعديل الكميات أو حذف مواد)
function _handleUpdateCustomerOrder(body, user) {
  const orderId = body.orderId || body.order_id;
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
  const orderId = body.orderId || body.order_id;
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

// ==================== دوال نظام الدفعات والصناديق ====================

// جلب أرصدة الصناديق
function _handleGetBoxBalances(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  
  const boxesBalance = _all('Boxes_Balance');
  const shamCashBalance = _all('Sham_Cash_Balance');
  
  // تهيئة الأرصدة الافتراضية إذا لم تكن موجودة
  let cashBoxSYP = boxesBalance.find(b => b.box_name === 'cash_box' && b.currency === 'SYP');
  let cashBoxUSD = boxesBalance.find(b => b.box_name === 'cash_box' && b.currency === 'USD');
  let shamCashSYP = boxesBalance.find(b => b.box_name === 'sham_cash' && b.currency === 'SYP');
  let shamCashUSD = boxesBalance.find(b => b.box_name === 'sham_cash' && b.currency === 'USD');
  
  if (!cashBoxSYP) {
    cashBoxSYP = { box_id: 'box_cash_syp', box_name: 'cash_box', currency: 'SYP', balance: 0 };
  }
  if (!cashBoxUSD) {
    cashBoxUSD = { box_id: 'box_cash_usd', box_name: 'cash_box', currency: 'USD', balance: 0 };
  }
  if (!shamCashSYP) {
    shamCashSYP = { box_id: 'box_sham_syp', box_name: 'sham_cash', currency: 'SYP', balance: 0 };
  }
  if (!shamCashUSD) {
    shamCashUSD = { box_id: 'box_sham_usd', box_name: 'sham_cash', currency: 'USD', balance: 0 };
  }
  
  return {
    balances: {
      cash_box_syp: Number(cashBoxSYP.balance || 0),
      cash_box_usd: Number(cashBoxUSD.balance || 0),
      sham_cash_syp: Number(shamCashSYP.balance || 0),
      sham_cash_usd: Number(shamCashUSD.balance || 0),
    }
  };
}

// جلب قائمة الدفعات
function _handleGetPayments(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  
  let payments = _all('Payments');
  
  // فلترة حسب الزبون إذا تم تحديده
  if (body.customer_id) {
    payments = payments.filter(p => p.customer_id === body.customer_id);
  }
  
  // فلترة حسب نوع الصندوق إذا تم تحديده
  if (body.box_type) {
    payments = payments.filter(p => p.box_type === body.box_type);
  }
  
  // فلترة حسب العملة
  if (body.currency) {
    payments = payments.filter(p => p.currency === body.currency);
  }
  
  // إضافة معلومات الزبون
  const customers = _all('Customers');
  payments = payments.map(p => {
    const customer = customers.find(c => c.customer_id === p.customer_id);
    return {
      ...p,
      customer_name: customer ? customer.full_name : 'غير معروف',
    };
  });
  
  // ترتيب حسب الأحدث أولاً
  payments.sort((a, b) => {
    const dateA = new Date(a.created_at || a.payment_date || 0);
    const dateB = new Date(b.created_at || b.payment_date || 0);
    return dateB - dateA;
  });
  
  return { payments: payments };
}

// تسجيل دفعة جديدة (استلام أو صرف)
function _handleRecordPayment(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  
  const amount = Number(body.amount || 0);
  if (amount <= 0) {
    throw new Error('المبلغ يجب أن يكون أكبر من صفر');
  }
  
  const actionType = body.action_type || 'receive'; // receive أو pay
  const boxType = body.box_type || 'cash_box'; // cash_box أو sham_cash
  const currency = body.currency || 'USD';
  const customerId = body.customer_id;
  const note = body.note || '';
  
  if (actionType === 'receive' && !customerId) {
    throw new Error('يجب اختيار الزبون للاستلام');
  }
  
  if (actionType === 'pay' && !note) {
    throw new Error('يجب كتابة ملاحظة/سبب للصرف');
  }
  
  // التحقق من الرصيد الكافي في حال الصرف
  if (actionType === 'pay') {
    const boxesBalance = _all('Boxes_Balance');
    const box = boxesBalance.find(b => b.box_name === boxType && b.currency === currency);
    const currentBalance = box ? Number(box.balance || 0) : 0;
    
    if (currentBalance < amount) {
      throw new Error('الرصيد في الصندوق غير كافي');
    }
  }
  
  // إنشاء رقم الدفعة
  const year = new Date().getFullYear();
  const existing = _all('Payments').filter(p => String(p.payment_id).includes('PAY-' + year));
  const seq = existing.length + 1;
  const paymentId = 'PAY-' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd') + '-' + String(seq).padStart(6, '0');
  
  const now = _now();
  
  // تسجيل الدفعة
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
  
  // تحديث رصيد الزبون في حال الاستلام
  if (actionType === 'receive' && customerId) {
    _updateCustomerBalance(customerId, amount, currency, 'credit');
  }
  
  // تحديث رصيد الصندوق
  _updateBoxBalance(boxType, currency, amount, actionType);
  
  // إرسال إشعار للمدير والمحاسب
  if (actionType === 'receive') {
    _sendNotificationToRoles('admin,manager,accountant', 'استلام دفعة', 'تم استلام دفعة من الزبون بقيمة ' + amount + ' ' + currency, 'payment', paymentId);
  } else {
    _sendNotificationToRoles('admin,manager', 'صرف من الصندوق', 'تم صرف مبلغ ' + amount + ' ' + currency + ' من ' + boxType, 'payment', paymentId);
  }
  
  return { success: true, payment_id: paymentId };
}

// تحديث دفعة موجودة
function _handleUpdatePayment(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  
  const paymentId = body.payment_id;
  if (!paymentId) {
    throw new Error('رقم الدفعة مطلوب');
  }
  
  const payments = _all('Payments');
  const paymentIndex = payments.findIndex(p => p.payment_id === paymentId);
  if (paymentIndex === -1) {
    throw new Error('الدفعة غير موجودة');
  }
  
  const oldPayment = payments[paymentIndex];
  const newAmount = Number(body.amount || oldPayment.amount);
  const newActionType = body.action_type || oldPayment.action_type;
  const newBoxType = body.box_type || oldPayment.box_type;
  const newCurrency = body.currency || oldPayment.currency;
  const newCustomerId = body.customer_id !== undefined ? body.customer_id : oldPayment.customer_id;
  const newNote = body.note !== undefined ? body.note : oldPayment.note;
  
  // عكس العملية القديمة
  if (oldPayment.action_type === 'receive' && oldPayment.customer_id) {
    _updateCustomerBalance(oldPayment.customer_id, Number(oldPayment.amount), oldPayment.currency, 'debit');
  }
  _updateBoxBalance(oldPayment.box_type, oldPayment.currency, Number(oldPayment.amount), oldPayment.action_type === 'receive' ? 'pay' : 'receive');
  
  // تطبيق العملية الجديدة
  if (newActionType === 'receive' && newCustomerId) {
    _updateCustomerBalance(newCustomerId, newAmount, newCurrency, 'credit');
  }
  _updateBoxBalance(newBoxType, newCurrency, newAmount, newActionType === 'receive' ? 'receive' : 'pay');
  
  // تحديث البيانات
  const sheet = _ss().getSheetByName('Payments');
  const rowIndex = paymentIndex + 2;
  
  const paymentsHeaders = H.Payments;
  const amountCol = paymentsHeaders.indexOf('amount') + 1;
  const actionTypeCol = paymentsHeaders.indexOf('action_type') + 1;
  const boxTypeCol = paymentsHeaders.indexOf('box_type') + 1;
  const currencyCol = paymentsHeaders.indexOf('currency') + 1;
  const customerIdCol = paymentsHeaders.indexOf('customer_id') + 1;
  const noteCol = paymentsHeaders.indexOf('note') + 1;
  
  sheet.getRange(rowIndex, amountCol).setValue(newAmount);
  sheet.getRange(rowIndex, actionTypeCol).setValue(newActionType);
  sheet.getRange(rowIndex, boxTypeCol).setValue(newBoxType);
  sheet.getRange(rowIndex, currencyCol).setValue(newCurrency);
  if (body.customer_id !== undefined) {
    sheet.getRange(rowIndex, customerIdCol).setValue(newCustomerId);
  }
  if (body.note !== undefined) {
    sheet.getRange(rowIndex, noteCol).setValue(newNote);
  }
  
  _add('Audit_Log', {
    log_id: Utilities.getUuid(),
    user_id: user.user_id,
    action: 'UPDATE_PAYMENT',
    entity: 'Payments',
    entity_id: paymentId,
    details: 'تعديل دفعة',
    created_at: _now(),
  });
  
  return { success: true };
}

// حذف دفعة
function _handleDeletePayment(body, user) {
  _needRole(user, ['admin', 'manager', 'accountant']);
  
  const paymentId = body.payment_id;
  if (!paymentId) {
    throw new Error('رقم الدفعة مطلوب');
  }
  
  const payments = _all('Payments');
  const paymentIndex = payments.findIndex(p => p.payment_id === paymentId);
  if (paymentIndex === -1) {
    throw new Error('الدفعة غير موجودة');
  }
  
  const payment = payments[paymentIndex];
  
  // عكس العملية
  if (payment.action_type === 'receive' && payment.customer_id) {
    _updateCustomerBalance(payment.customer_id, Number(payment.amount), payment.currency, 'debit');
  }
  _updateBoxBalance(payment.box_type, payment.currency, Number(payment.amount), payment.action_type === 'receive' ? 'pay' : 'receive');
  
  // حذف الدفعة
  const sheet = _ss().getSheetByName('Payments');
  sheet.deleteRow(paymentIndex + 2);
  
  _add('Audit_Log', {
    log_id: Utilities.getUuid(),
    user_id: user.user_id,
    action: 'DELETE_PAYMENT',
    entity: 'Payments',
    entity_id: paymentId,
    details: 'حذف دفعة',
    created_at: _now(),
  });
  
  return { success: true };
}

// تحديث رصيد الزبون
function _updateCustomerBalance(customerId, amount, currency, operation) {
  const customers = _all('Customers');
  const customerIndex = customers.findIndex(c => c.customer_id === customerId);
  if (customerIndex === -1) return;
  
  const sheet = _ss().getSheetByName('Customers');
  const rowIndex = customerIndex + 2;
  
  const balanceField = currency === 'USD' ? 'opening_usd' : 'opening_syp';
  const balanceCol = H.Customers.indexOf(balanceField) + 1;
  
  const currentBalance = Number(customers[customerIndex][balanceField] || 0);
  let newBalance;
  
  if (operation === 'credit') {
    // استلام: إنقاص الدين (خصم من الرصيد)
    newBalance = currentBalance - amount;
  } else {
    // صرف: زيادة الدين (إضافة للرصيد)
    newBalance = currentBalance + amount;
  }
  
  sheet.getRange(rowIndex, balanceCol).setValue(newBalance);
}

// تحديث رصيد الصندوق
function _updateBoxBalance(boxType, currency, amount, actionType) {
  const boxesBalance = _all('Boxes_Balance');
  let box = boxesBalance.find(b => b.box_name === boxType && b.currency === currency);
  
  const sheet = _ss().getSheetByName('Boxes_Balance');
  
  if (!box) {
    // إنشاء صندوق جديد
    const boxId = 'box_' + boxType + '_' + currency.toLowerCase();
    _add('Boxes_Balance', {
      box_id: boxId,
      box_name: boxType,
      currency: currency,
      balance: 0,
      last_updated: _now(),
    });
    box = { box_id: boxId, box_name: boxType, currency: currency, balance: 0 };
  }
  
  const boxIndex = boxesBalance.findIndex(b => b.box_id === box.box_id);
  const rowIndex = boxIndex + 2;
  
  const balanceCol = H.Boxes_Balance.indexOf('balance') + 1;
  const lastUpdatedCol = H.Boxes_Balance.indexOf('last_updated') + 1;
  
  const currentBalance = Number(box.balance || 0);
  let newBalance;
  
  if (actionType === 'receive') {
    // استلام: زيادة الرصيد
    newBalance = currentBalance + amount;
  } else {
    // صرف: إنقاص الرصيد
    newBalance = currentBalance - amount;
  }
  
  sheet.getRange(rowIndex, balanceCol).setValue(newBalance);
  sheet.getRange(rowIndex, lastUpdatedCol).setValue(_now());
}

// إرسال إشعار
function _handleSendNotification(body, user) {
  const userIds = body.user_ids || [];
  const title = body.title || '';
  const messageBody = body.body || '';
  const type = body.type || 'general';
  const entityType = body.entity_type || '';
  const entityId = body.entity_id || '';
  
  if (!title || !messageBody) {
    throw new Error('العنوان والرسالة مطلوبان');
  }
  
  const now = _now();
  const notificationId = Utilities.getUuid();
  
  // إرسال الإشعار لكل مستخدم
  userIds.forEach(userId => {
    _add('Notifications', {
      notification_id: notificationId + '_' + userId,
      user_id: userId,
      title: title,
      body: messageBody,
      type: type,
      entity_type: entityType,
      entity_id: entityId,
      read_at: '',
      created_at: now,
    });
  });
  
  return { success: true };
}

// إرسال إشعار لأدوار محددة
function _sendNotificationToRoles(rolesStr, title, messageBody, entityType, entityId) {
  const roles = rolesStr.split(',');
  const users = _all('Users').filter(u => roles.includes(u.role) && u.status === 'active');
  
  const userIds = users.map(u => u.user_id);
  if (userIds.length > 0) {
    _handleSendNotification({
      user_ids: userIds,
      title: title,
      body: messageBody,
      type: 'system',
      entity_type: entityType,
      entity_id: entityId,
    }, { user_id: 'system', role: 'system' });
  }
}

// تحديث دالة إضافة دفعة القديمة للتوافق
function _handleAddPaymentOld(body, user) {
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
    box_type: body.box_type || 'cash_box',
    method: body.method || 'cash',
    payment_date: body.payment_date || _now(),
    note: body.note || '',
    created_by: user.user_id,
    created_at: _now(),
    action_type: 'receive',
  });
  return { saved: true };
}
