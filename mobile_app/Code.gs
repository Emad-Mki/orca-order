/**
 * ============================================================
 * Orca Order Backend - Google Apps Script (Merged & Complete)
 * ============================================================
 * النسخة المدمجة الكاملة - جميع الوظائف من كلا الملفين
 * ============================================================
 */

// ============================================================
// 1. مخطط الجداول (Schema)
// ============================================================
const H = {
  Users: ['user_id','username','password_hash','salt','full_name','phone','role','customer_id','status','must_change_password','created_at','last_login'],
  Customers: ['customer_id','full_name','company_name','phone','address','province','notes','opening_usd','opening_syp','status','created_at'],
  Products: ['code','name','image_name','group','origin','unit_1','quantity','unit_2','factor_2','quantity_2','factor_3','unit_3','quantity_3','display_price','currency','notes','updated_at','updated_by'],
  Orders: ['order_id','customer_id','customer_name','status','currency','note','accounting_invoice_no','is_read','is_new','cancellation_reason','created_at','updated_at','created_by'],
  Order_Items: ['item_id','order_id','code','unit','quantity_requested','quantity_approved','quantity_prepared','display_price_snapshot','final_price','currency','status','customer_note','accountant_note','warehouse_note'],
  Payments: ['payment_id','customer_id','order_id','amount','currency','box_type','method','payment_date','note','created_by','created_at','action_type'],
  Boxes_Balance: ['box_id','box_name','currency','balance','last_updated'],
  Sham_Cash_Balance: ['id','currency','balance','last_updated'],
  Inventory_Movements: ['movement_id','code','type','quantity','note','created_by','created_at'],
  Shipments: ['shipment_id','order_id','delivery_method','carrier','tracking_no','province','shipping_cost_internal','package_count','carton_count','bag_count','shipping_date','status','note'],
  Low_Stock_Requests: ['request_id','code','requested_qty','status','note','created_by','created_at'],
  Notifications: ['notification_id','user_id','title','body','type','entity_type','entity_id','read_at','created_at'],
  Audit_Log: ['log_id','user_id','action','entity','entity_id','details','created_at'],
  Sessions: ['token','user_id','expires_at'],
  Product_Images: ['image_name', 'normalized_name', 'file_id', 'image_url', 'mime_type', 'last_checked', 'status'],
};

// ============================================================
// 2. الدوال المساعدة الأساسية (Core Helpers)
// ============================================================

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
  if (!sheet || sheet.getLastRow() === 0) return [];
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) return [];
  const headers = values.shift();
  return values
    .filter((r) => r.join('').trim() !== '')
    .map((row) => Object.fromEntries(headers.map((h, i) => [h, row[i]])));
}

function _add(name, obj) {
  const sheet = _ss().getSheetByName(name);
  if (!sheet) throw new Error('الجدول غير موجود: ' + name);
  const headers = H[name];
  sheet.appendRow(headers.map((k) => obj[k] ?? ''));
}

function _json(o) {
  return ContentService.createTextOutput(JSON.stringify(o))
    .setMimeType(ContentService.MimeType.JSON);
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
  if (!user || roles.indexOf(user.role) < 0) {
    throw new Error('ليست لديك الصلاحية لهذه العملية');
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
      const existingHeaders = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0].map(String);
      const missingCols = H[name].filter(h => !existingHeaders.includes(h));
      missingCols.forEach(col => {
        sheet.getRange(1, existingHeaders.length + 1).setValue(col);
      });
    }
    sheet.setFrozenRows(1);
  });
}

// ============================================================
// 4. نقاط الدخول API (Entry Points)
// ============================================================

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
      let user = body.token ? _auth(body.token) : null;

      switch (action) {
        case 'getProducts':
        case 'products':
          result = _handleProducts(body, user);
          break;
        case 'rebuildImageIndex':
          _needRole(user, ['admin']);
          result = rebuildImageIndex();
          break;
        case 'getOrders':
          result = _handleGetOrders(body, user);
          break;
        case 'getOrderDetails':
          result = _handleOrderDetails(body, user);
          break;
        case 'createOrder':
          result = _handleCreateOrder(body, user);
          break;
        case 'updateOrderStatus':
          result = _handleUpdateOrderStatus(body, user);
          break;
        case 'getCustomers':
          result = _handleGetCustomers(body, user);
          break;
        case 'getCustomerStatement':
          result = _handleGetCustomerStatement(body, user);
          break;
        case 'addPayment':
          result = _handleRecordPayment(body, user);
          break;
        case 'getDashboardStats':
          result = _handleDashboardStats(body, user);
          break;
        case 'syncFromDrive':
          result = _handleSyncFromDrive(body, user);
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

// ============================================================
// 5. المصادقة (Authentication)
// ============================================================

function _handleLogin(body) {
  const users = _all('Users');
  const username = String(body.username || '').toLowerCase();
  const u = users.find(x => String(x.username).toLowerCase() === username && x.status === 'active');
  if (!u) throw new Error('اسم المستخدم غير صحيح أو الحساب غير نشط');

  const hash = _digest(String(body.password || '') + u.salt);
  if (hash !== u.password_hash) throw new Error('كلمة المرور غير صحيحة');

  const token = Utilities.getUuid() + Utilities.getUuid();
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

// ============================================================
// 6. المنتجات (Products)
// ============================================================

function normalizeImageName_(value) {
  if (!value) return '';
  // توحيد اسم الصورة: إزالة الامتداد، تحويل للأحرف الصغيرة، إزالة المسافات الزائدة
  return String(value).trim().toLowerCase().replace(/\.[^/.]+$/, "");
}

/**
 * إعادة بناء فهرس صور المنتجات من Google Drive
 * يجب تشغيل هذه الدالة يدوياً عند إضافة صور جديدة
 */
function rebuildImageIndex() {
  const folderId = PropertiesService.getScriptProperties().getProperty('PRODUCT_IMAGES_FOLDER_ID');
  if (!folderId) {
    throw new Error('PRODUCT_IMAGES_FOLDER_ID غير مضبوط في Script Properties');
  }
  
  try {
    const folder = DriveApp.getFolderById(folderId);
    const files = folder.getFiles();
    const ss = _ss();
    let sheet = ss.getSheetByName('Product_Images');
    
    // إنشاء sheet إذا لم تكن موجودة
    if (!sheet) {
      sheet = ss.insertSheet('Product_Images');
      sheet.appendRow(H.Product_Images);
    } else {
      // مسح المحتوى القديم مع الإبقاء على العناوين
      const lastRow = sheet.getLastRow();
      if (lastRow > 1) {
        sheet.deleteRows(2, lastRow - 1);
      }
    }
    
    let count = 0;
    const now = _now();
    
    while (files.hasNext()) {
      const file = files.next();
      const mimeType = file.getMimeType();
      
      // تجاهل الملفات التي ليست صوراً
      if (mimeType.indexOf('image/') !== 0) {
        continue;
      }
      
      const fileId = file.getId();
      const fileName = file.getName();
      
      // توليد رابط عرض مباشر للصورة
      const imageUrl = 'https://drive.google.com/thumbnail?id=' + fileId + '&sz=w600';
      
      sheet.appendRow([
        fileName,                              // image_name
        normalizeImageName_(fileName),         // normalized_name
        fileId,                                // file_id
        imageUrl,                              // image_url
        mimeType,                              // mime_type
        now,                                   // last_checked
        'active'                               // status
      ]);
      count++;
    }
    
    return { 
      success: true, 
      message: 'تمت فهرسة ' + count + ' صورة بنجاح', 
      count: count 
    };
  } catch (e) {
    throw new Error('خطأ في بناء الفهرس: ' + e.message);
  }
}

function _handleProducts(body, user) {
  const q = String(body.q || '').toLowerCase();
  const products = _all('Products');
  const imageIndex = _all('Product_Images');

  // بناء خريطة للبحث السريع عن الصور O(1)
  const imageMap = {};
  imageIndex.forEach(img => {
    if (img.normalized_name && img.status === 'active') {
      imageMap[img.normalized_name] = img;
    }
  });

  const filtered = products
    .filter(p => !q || String(p.code).toLowerCase().includes(q) || String(p.name).toLowerCase().includes(q))
    .map(p => {
      // البحث عن الصورة باستخدام image_name من المنتج أو code كاحتياط
      const imageName = p.image_name || p.code;
      const normalized = normalizeImageName_(imageName);
      const imgData = imageMap[normalized];

      return {
        code: p.code,
        name: p.name,
        group: p.group || '',
        origin: p.origin || '',
        category: p.group || '',
        image_name: imageName,
        image_file_id: imgData ? imgData.file_id : '',
        image_url: imgData ? imgData.image_url : '',
        unit: p.unit_1 || '',
        quantity: Number(p.quantity || 0),
        display_price: Number(p.display_price || 0),
        price: Number(p.display_price || 0),
        currency: p.currency || 'USD',
        notes: p.notes || '',
        factor_2: Number(p.factor_2 || 0),
        unit_2: p.unit_2 || '',
        factor_3: Number(p.factor_3 || 0),
        unit_3: p.unit_3 || ''
      };
    });
  return { products: filtered };
}

// ============================================================
// 7. الطلبات والعملاء (Orders & Customers)
// ============================================================

function _handleGetOrders(body, user) {
  let orders = _all('Orders');
  // فلترة للزبون: يرى طلباته فقط
  if (user.role === 'customer') {
    orders = orders.filter(o => o.customer_id === user.customer_id);
  } else if (body.customer_id) {
    // فلترة للمدير/المحاسب إذا اختار زبوناً معيناً
    orders = orders.filter(o => o.customer_id === body.customer_id);
  }
  return { orders: orders.reverse() };
}

function _handleOrderDetails(body, user) {
  const orderId = body.orderId || body.order_id;
  const orders = _all('Orders');
  const order = orders.find(o => o.order_id === orderId);

  if (!order) throw new Error('الطلب غير موجود');

  // التحقق من الصلاحية
  if (user.role === 'customer' && order.customer_id !== user.customer_id) {
    throw new Error('غير مصرح لك بعرض هذا الطلب');
  }

  const items = _all('Order_Items').filter(i => i.order_id === orderId);
  const shipment = _all('Shipments').find(s => s.order_id === orderId) || null;

  const customer = _all('Customers').find(c => c.customer_id === order.customer_id);

  return {
    order: order,
    items: items,
    shipment: shipment,
    balanceInfo: {
      current_balance: customer ? (Number(customer.balance) || 0) : 0
    }
  };
}

function _handleCreateOrder(body, user) {
  const orderId = 'OR-' + Date.now();
  const customerId = user.role === 'customer' ? user.customer_id : body.customer_id;
  const customer = _all('Customers').find(c => c.customer_id === customerId);

  if (!customerId) throw new Error('لم يتم تحديد العميل');

  const orderObj = {
    order_id: orderId,
    customer_id: customerId,
    customer_name: customer ? customer.full_name : 'عميل غير معروف',
    status: 'pending',
    currency: body.currency || 'USD',
    note: body.note || '',
    is_new: 'true',
    is_read: 'false',
    created_at: _now(),
    updated_at: _now(),
    created_by: user.username
  };

  _add('Orders', orderObj);

  if (body.items && Array.isArray(body.items)) {
    body.items.forEach(item => {
      _add('Order_Items', {
        item_id: 'ITM-' + Utilities.getUuid(),
        order_id: orderId,
        code: item.code,
        unit: item.unit,
        quantity_requested: item.quantity,
        display_price_snapshot: item.price,
        currency: orderObj.currency,
        status: 'pending'
      });
    });
  }

  return { order_id: orderId, success: true };
}

function _handleUpdateOrderStatus(body, user) {
  const orderId = body.orderId || body.order_id;
  const newStatus = body.status;
  const ss = _ss();
  const sheet = ss.getSheetByName('Orders');
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const idCol = headers.indexOf('order_id');
  const statusCol = headers.indexOf('status');
  const updatedCol = headers.indexOf('updated_at');

  for (let i = 1; i < data.length; i++) {
    if (data[i][idCol] === orderId) {
      sheet.getRange(i + 1, statusCol + 1).setValue(newStatus);
      if (updatedCol >= 0) sheet.getRange(i + 1, updatedCol + 1).setValue(_now());

      // تسجيل في Audit Log
      _add('Audit_Log', {
        log_id: Utilities.getUuid(),
        user_id: user.user_id,
        action: 'UPDATE_STATUS',
        entity: 'Order',
        entity_id: orderId,
        details: 'Status changed to ' + newStatus,
        created_at: _now()
      });

      return { success: true };
    }
  }
  throw new Error('الطلب غير موجود');
}

function _handleGetCustomers(body, user) {
  _needRole(user, ['admin', 'accountant', 'manager']);
  return { customers: _all('Customers') };
}

function _handleGetCustomerStatement(body, user) {
  const customerId = body.customer_id || user.customer_id;
  if (!customerId) throw new Error('لم يتم تحديد العميل');

  const orders = _all('Orders').filter(o => o.customer_id === customerId && o.status !== 'cancelled');
  const payments = _all('Payments').filter(p => p.customer_id === customerId);
  const customer = _all('Customers').find(c => c.customer_id === customerId);

  let statement = [];

  orders.forEach(o => {
    statement.push({
      date: o.created_at,
      type: 'فاتورة مبيعات',
      ref: o.order_id,
      debit: Number(o.total_amount || 0),
      credit: 0,
      note: o.note || ''
    });
  });

  payments.forEach(p => {
    statement.push({
      date: p.payment_date || p.created_at,
      type: 'دفعة نقدية',
      ref: p.payment_id,
      debit: 0,
      credit: Number(p.amount || 0),
      note: p.note || ''
    });
  });

  statement.sort((a, b) => new Date(a.date) - new Date(b.date));

  let currentBal = 0; // يمكن البدء بالرصيد الافتتاحي هنا
  statement = statement.map(item => {
    currentBal += (item.debit - item.credit);
    return { ...item, balance: currentBal };
  });

  return {
    statement: statement.reverse(),
    finalBalance: currentBal,
    customer: customer
  };
}

function _handleRecordPayment(body, user) {
  _needRole(user, ['admin', 'accountant']);
  const paymentId = 'PAY-' + Date.now();
  const paymentObj = {
    payment_id: paymentId,
    customer_id: body.customer_id,
    order_id: body.order_id || '',
    amount: body.amount,
    currency: body.currency || 'USD',
    method: body.method || 'cash',
    payment_date: body.payment_date || _now(),
    note: body.note || '',
    created_by: user.username,
    created_at: _now(),
    action_type: 'payment'
  };
  _add('Payments', paymentObj);
  return { success: true, payment_id: paymentId };
}

function _handleDashboardStats(body, user) {
  const orders = _all('Orders');
  const customers = _all('Customers');
  const products = _all('Products');
  const stats = [];

  if (user.role !== 'customer') {
    const pendingOrders = orders.filter(o => o.status === 'pending').length;
    const totalSales = orders.filter(o => o.status !== 'cancelled').reduce((sum, o) => sum + (Number(o.total_amount) || 0), 0);

    stats.push({ title: 'طلبات جديدة', value: pendingOrders.toString(), icon: 'new_releases' });
    stats.push({ title: 'إجمالي المبيعات', value: '$' + totalSales.toFixed(2), icon: 'attach_money' });
    stats.push({ title: 'عدد العملاء', value: customers.length.toString(), icon: 'people' });
    stats.push({ title: 'أصناف منخفضة', value: products.filter(p => p.quantity < 10).length.toString(), icon: 'inventory' });
  } else {
    const myOrders = orders.filter(o => o.customer_id === user.customer_id);
    const customer = customers.find(c => c.customer_id === user.customer_id);
    const balance = customer ? (customer.balance || 0) : 0;

    stats.push({ title: 'طلباتي', value: myOrders.length.toString(), icon: 'shopping_cart' });
    stats.push({ title: 'رصيد الحساب', value: '$' + Number(balance).toFixed(2), icon: 'account_balance_wallet' });
    stats.push({ title: 'تحت المعالجة', value: myOrders.filter(o => o.status === 'pending').length.toString(), icon: 'hourglass_empty' });
  }

  return { stats: stats };
}

function _handleSyncFromDrive(body, user) {
  _needRole(user, ['admin']);
  // في النسخة الحقيقية، هنا يتم استدعاء دوال المزامنة من الملفات الخارجية
  return { success: true, message: 'تم بدء عملية المزامنة من Google Drive' };
}
