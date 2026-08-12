/**
* ============================================================
* Orca Order Backend - Google Apps Script
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
if (!sheet) return [];
const values = sheet.getDataRange().getValues();
if (values.length === 0) return [];
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

function _getHeaders(sheetName) {
const sheet = _ss().getSheetByName(sheetName);
if (!sheet) return [];
const lastCol = sheet.getLastColumn();
if (lastCol === 0) return [];
return sheet.getRange(1, 1, 1, lastCol).getValues()[0].map(String);
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
// --- المنتجات ---
case 'getProducts':
case 'products':
result = _handleProducts(body, user);
break;
case 'rebuildImageIndex':
_needRole(user, ['admin']);
result = rebuildImageIndex();
break;
case 'updateProductQuantity':
case 'adjust_inventory':
result = _handleUpdateProductQuantity(body, user);
break;
case 'receive_goods':
result = _handleReceiveGoods(body, user);
break;
// --- الطلبات ---
case 'getOrders':
result = _handleGetOrders(body, user);
break;
case 'getOrderDetails':
result = _handleOrderDetails(body, user);
break;
case 'createOrder':
case 'create_order':
result = _handleCreateOrder(body, user);
break;
case 'updateOrderStatus':
result = _handleUpdateOrderStatus(body, user);
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
case 'markOrderAsRead':
result = _handleMarkOrderAsRead(body, user);
break;
case 'cancelOrder':
result = _handleCancelOrder(body, user);
break;
case 'deleteOrder':
result = _handleDeleteOrder(body, user);
break;
// --- العملاء ---
case 'getCustomers':
result = _handleGetCustomers(body, user);
break;
case 'createCustomer':
result = _handleCreateCustomer(body, user);
break;
case 'getCustomerStatement':
result = _handleGetCustomerStatement(body, user);
break;
case 'exportStatement':
return _handleExportStatement(body, user);
// --- الدفعات والصناديق ---
case 'getPayments':
result = _handleGetPayments(body, user);
break;
case 'addPayment':
case 'add_payment':
result = _handleAddPayment(body, user);
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
// --- المخزون ---
case 'getInventoryMovements':
result = _handleGetInventoryMovements(body, user);
break;
// --- الشحن ---
case 'getShipments':
result = _handleGetShipments(body, user);
break;
case 'shipment':
result = _handleShipment(body, user);
break;
case 'updateShipmentStatus':
result = _handleUpdateShipmentStatus(body, user);
break;
// --- النواقص ---
case 'createLowStockRequest':
result = _handleCreateLowStockRequest(body, user);
break;
case 'getLowStockRequests':
result = _handleGetLowStockRequests(body, user);
break;
// --- الإشعارات ---
case 'getNotifications':
result = _handleGetNotifications(body, user);
break;
case 'markNotificationAsRead':
result = _handleMarkNotificationAsRead(body, user);
break;
case 'sendNotification':
result = _handleSendNotification(body, user);
break;
// --- المزامنة والإعدادات ---
case 'syncFromDrive':
result = _handleSyncFromDrive(body, user);
break;
case 'updateConfig':
result = _handleUpdateConfig(body, user);
break;
// --- التقارير والإحصائيات ---
case 'getReports':
result = _handleReports(body, user);
break;
case 'getDashboardStats':
result = _handleDashboardStats(body, user);
break;
// --- المستخدم ---
case 'updateUser':
result = _handleUpdateUser(body, user);
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
const username = String(body.username || body.user || '').toLowerCase();
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

// ============================================================
// 6. المنتجات (Products)
// ============================================================
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

return {
products: products
.filter(p =>
!q ||
String(p.code).toLowerCase().includes(q) ||
String(p.name).toLowerCase().includes(q) ||
String(p.group).toLowerCase().includes(q)
)
.map(p => {
const imageName = p.image_name || p.code;
const normalized = normalizeImageName_(imageName);
const imgData = imageMap[normalized];

return {
code: p.code,
name: p.name,
category: p.group,
image_name: imageName,
image_url: imgData ? imgData.image_url : '', // إرجاع الرابط الفعلي من الفهرس
image_id: imgData ? imgData.file_id : (p.image_id || ''),
origin: p.origin,
unit: p.unit_1,
quantity: Number(p.quantity || 0),
price: Number(p.display_price || 0),
display_price: Number(p.display_price || 0),
currency: p.currency || 'USD',
notes: p.notes || ''
};
})
};
}

function _handleUpdateProductQuantity(body, user) {
_needRole(user, ['admin', 'warehouse']);
const code = body.code;
const delta = Number(body.quantity || 0);
if (!code) throw new Error('كود المنتج مطلوب');

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

function _handleReceiveGoods(body, user) {
_needRole(user, ['admin', 'accountant', 'warehouse']);
const code = body.code;
const qty = Number(body.quantity || 0);
if (!code || qty <= 0) throw new Error('بيانات استلام المواد غير صالحة');

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
return { success: true, saved: true };
}
throw new Error('المنتج غير موجود');
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

// ============================================================
// 7. صور المنتجات (Product Images - Indexing)
// ============================================================
function normalizeImageName_(value) {
if (!value) return '';
// توحيد اسم الصورة: إزالة الامتداد، تحويل للأحرف الصغيرة، إزالة المسافات الزائدة
return String(value).trim().toLowerCase().replace(/\.[^/.]+$/, "");
}

/**
* إعادة بناء فهرس صور المنتجات من Google Drive
* يجب تشغيل هذه الدالة يدوياً أو عبر API عند إضافة صور جديدة
*/
function rebuildImageIndex() {
const folderId = PropertiesService.getScriptProperties().getProperty('PRODUCT_IMAGES_FOLDER_ID') || '1H9KGBPTnZYE8bQHOWUih39zUwB0Hk9ds';
try {
const folder = DriveApp.getFolderById(folderId);
const files = folder.getFiles();
const ss = _ss();
let sheet = ss.getSheetByName('Product_Images');

if (!sheet) {
sheet = ss.insertSheet('Product_Images');
sheet.appendRow(H.Product_Images);
} else {
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

if (mimeType.indexOf('image/') !== 0) {
continue;
}

const fileId = file.getId();
const fileName = file.getName();
const imageUrl = 'https://drive.google.com/thumbnail?id=' + fileId + '&sz=w600';

sheet.appendRow([
fileName,
normalizeImageName_(fileName),
fileId,
imageUrl,
mimeType,
now,
'active'
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

// ============================================================
// 8. الطلبات (Orders)
// ============================================================
function _handleGetOrders(body, user) {
const role = user ? user.role : 'guest';
let orders = _all('Orders');

if (body.customer_id && ['admin', 'manager', 'accountant'].includes(role)) {
orders = orders.filter(o => o.customer_id === body.customer_id);
} else if (role === 'customer' && user.customer_id) {
orders = orders.filter(o => o.customer_id === user.customer_id);
}

orders = orders.filter(o => o.status !== 'deleted');
const customers = _all('Customers');
orders = orders.map(o => {
const customer = customers.find(c => c.customer_id === o.customer_id);
return {
...o,
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

return { orders: orders };
}

function _handleOrderDetails(body, user) {
const orderId = body.orderId || body.order_id;
if (!orderId) throw new Error('رقم الطلب مطلوب');

const orders = _all('Orders').filter(o => o.order_id === orderId);
if (orders.length === 0) throw new Error('الطلب غير موجود');
const order = orders[0];

if (user && user.role === 'customer' && order.customer_id !== user.customer_id) {
throw new Error('ليس لديك صلاحية عرض هذا الطلب');
}

const items = _all('Order_Items').filter(i => i.order_id === orderId);
const products = _all('Products');
const shipment = _all('Shipments').find(s => s.order_id === orderId);
const customers = _all('Customers');
const customer = customers.find(c => c.customer_id === order.customer_id);

const detailedItems = items.map(i => {
const p = products.find(prod => prod.code === i.code);
return {
item_id: i.item_id,
code: i.code,
name: p ? p.name : 'منتج غير موجود',
unit: i.unit,
quantity_requested: Number(i.quantity_requested || 0),
quantity_approved: Number(i.quantity_approved || 0),
quantity_prepared: Number(i.quantity_prepared || 0),
price_offer: Number(i.display_price_snapshot || 0),
final_price: Number(i.final_price || 0),
currency: i.currency || 'USD',
status: i.status,
customer_note: i.customer_note || '',
accountant_note: i.accountant_note || '',
warehouse_note: i.warehouse_note || '',
stock_available: p ? Number(p.quantity || 0) : 0
};
});

let balanceInfo = null;
if (customer) {
const payments = _all('Payments').filter(p => p.customer_id === order.customer_id);
const totalPaid = payments.reduce((sum, p) => sum + Number(p.amount || 0), 0);
const allCustomerOrders = _all('Orders').filter(o =>
o.customer_id === order.customer_id &&
!['cancelled', 'deleted'].includes(o.status)
);
const allOrderItems = _all('Order_Items');
let totalOrders = 0;
allCustomerOrders.forEach(o => {
const orderItems = allOrderItems.filter(i => i.order_id === o.order_id);
orderItems.forEach(item => {
totalOrders += Number(item.final_price || item.display_price_snapshot || 0) * Number(item.quantity_approved || item.quantity_requested || 0);
});
});
const currentBalance = totalOrders - totalPaid + Number(customer.opening_usd || 0);
balanceInfo = { current_balance: currentBalance, total_paid: totalPaid };
}

return {
order: order,
items: detailedItems,
shipment: shipment || null,
balanceInfo: balanceInfo
};
}

function _handleCreateOrder(body, user) {
  // استخدام LockService لمنع التكرار
  const lock = LockService.getUserLock();
  if (!lock.tryLock(5000)) {
    throw new Error('جاري معالجة طلب آخر، يرجى الانتظار قليلاً');
  }
  
  try {
    // التحقق من عدم وجود طلب مكرر خلال آخر 30 ثانية
    const orders = _all('Orders');
    const customerId = user.role === 'customer' ? user.customer_id : body.customer_id;
    const thirtySecondsAgo = new Date(Date.now() - 30000).toISOString();
    
    // التحقق من تكرار محتمل: نفس الزبون ونفس العناصر خلال وقت قصير
    const duplicateCheck = orders.filter(o => 
      o.customer_id === customerId && 
      o.created_at > thirtySecondsAgo &&
      (o.status === 'pending' || o.status === 'draft')
    );
    
    if (duplicateCheck.length > 0) {
      // يوجد طلب حديث جداً، نعتبره تكراراً محتملاً
      return { 
        success: false, 
        message: 'تم إرسال طلب حديثاً، يرجى انتظار المعالجة أو مراجعة الطلبات الحالية',
        existing_order_id: duplicateCheck[0].order_id
      };
    }
    
    const customer = _all('Customers').find(c => c.customer_id === customerId);
\n    if (!customerId) throw new Error('لم يتم تحديد العميل');\n\n    const orderObj = {\n      order_id: 'OR-' + Date.now(),\n      customer_id: customerId,\n      customer_name: customer ? customer.full_name : 'عميل غير معروف',\n      status: 'pending',\n      currency: body.currency || 'USD',\n      note: body.note || '',\n      is_new: 'true',\n      is_read: 'false',\n      created_at: _now(),\n      updated_at: _now(),\n      created_by: user.username\n    };\n\n    _add('Orders', orderObj);\n\n    if (body.items && Array.isArray(body.items)) {\n      body.items.forEach(item => {\n        _add('Order_Items', {\n          item_id: 'ITM-' + Utilities.getUuid(),\n          order_id: orderObj.order_id,\n          code: item.code,\n          unit: item.unit,\n          quantity_requested: item.quantity,\n          display_price_snapshot: item.price,\n          currency: orderObj.currency,\n          status: 'pending'\n        });\n      });\n    }\n\n    return { order_id: orderObj.order_id, success: true };\n  } finally {\n    lock.releaseLock();\n  }
}

function _handleUpdateOrderStatus(body, user) {
const orderId = body.orderId || body.order_id;
const newStatus = body.status;
if (!orderId || !newStatus) throw new Error('بيانات غير صالحة');

if (newStatus === 'customer_confirmed') {
_needRole(user, ['customer']);
} else if (newStatus === 'approved') {
_needRole(user, ['admin', 'manager', 'accountant']);
_reserveStock(orderId, user.user_id);
} else {
_needRole(user, ['admin', 'manager', 'accountant', 'warehouse']);
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
sheet.getRange(i + 1, statusIdx + 1).setValue(newStatus);
sheet.getRange(i + 1, updatedAtIdx + 1).setValue(_now());

if (newStatus === 'customer_confirmed') {
_notifyRole('accountant', 'تأكيد زبون', 'الزبون أكد الطلب ' + orderId + '.');
} else if (newStatus === 'approved') {
_notifyRole('warehouse', 'طلب جديد للتجهيز', 'تم اعتماد الطلب ' + orderId + '، يرجى البدء بالتجهيز.');
const customerUser = _all('Users').find(u => u.customer_id === data[i][customerIdIdx]);
if (customerUser) _sendNotification(customerUser.user_id, 'تم اعتماد طلبك', 'الطلب ' + orderId + ' قيد التجهيز الآن.');
} else if (newStatus === 'shipping') {
const customerUser = _all('Users').find(u => u.customer_id === data[i][customerIdIdx]);
if (customerUser) _sendNotification(customerUser.user_id, 'بدأ الشحن', 'طلبك رقم ' + orderId + ' في الطريق إليك.');
} else if (newStatus === 'delivered') {
const customerUser = _all('Users').find(u => u.customer_id === data[i][customerIdIdx]);
if (customerUser) _sendNotification(customerUser.user_id, 'تم التسليم', 'تم تأكيد استلام الطلب ' + orderId + '. شكراً لتعاملك معنا.');
}

_add('Audit_Log', {
log_id: Utilities.getUuid(),
user_id: user.user_id,
action: 'UPDATE_ORDER_STATUS',
entity: 'Orders',
entity_id: orderId,
details: 'تحديث الحالة إلى: ' + newStatus,
created_at: _now(),
});
return { success: true };
}
}
throw new Error('الطلب غير موجود');
}

function _handleMarkOrderAsRead(body, user) {
const orderId = body.orderId || body.order_id;
if (!orderId) throw new Error('رقم الطلب مطلوب');

const orders = _all('Orders');
const orderIndex = orders.findIndex(o => o.order_id === orderId);
if (orderIndex === -1) throw new Error('الطلب غير موجود');

const sheet = _ss().getSheetByName('Orders');
const rowIndex = orderIndex + 2;
const isReadCol = H.Orders.indexOf('is_read') + 1;
const isNewCol = H.Orders.indexOf('is_new') + 1;

sheet.getRange(rowIndex, isReadCol).setValue('true');
sheet.getRange(rowIndex, isNewCol).setValue('false');

return { success: true };
}

function _handleCancelOrder(body, user) {
const orderId = body.orderId || body.order_id;
const reason = body.cancellation_reason || '';
if (!orderId) throw new Error('رقم الطلب مطلوب');

const orders = _all('Orders');
const orderIndex = orders.findIndex(o => o.order_id === orderId);
if (orderIndex === -1) throw new Error('الطلب غير موجود');

const sheet = _ss().getSheetByName('Orders');
const rowIndex = orderIndex + 2;
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
details: 'إلغاء الطلب. السبب: ' + reason,
created_at: _now(),
});

return { success: true };
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
const statusCol = H.Orders.indexOf('status') + 1;
const reasonCol = H.Orders.indexOf('cancellation_reason') + 1;
const updatedCol = H.Orders.indexOf('updated_at') + 1;

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

function _handleUpdateOrderPricing(body, user) {
_needRole(user, ['admin', 'manager', 'accountant']);
const orderId = body.orderId || body.order_id;
const itemsUpdates = body.items;
if (!orderId || !Array.isArray(itemsUpdates)) throw new Error('بيانات غير صالحة');

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
if (upd.currency) itemsSheet.getRange(i + 1, itemsHeaders.indexOf('currency') + 1).setValue(upd.currency);
itemsSheet.getRange(i + 1, itemsHeaders.indexOf('accountant_note') + 1).setValue(upd.accountant_note || '');
break;
}
}
});

_updateStatusInternal(orderId, 'priced');

const order = _all('Orders').find(o => o.order_id === orderId);
if (order) {
const customerUser = _all('Users').find(u => u.customer_id === order.customer_id);
if (customerUser) {
_sendNotification(customerUser.user_id, 'تم تسعير الطلب', 'طلبك رقم ' + orderId + ' جاهز للمراجعة والتأكيد.');
}
}

return { success: true, message: 'تم إرسال التسعير بنجاح' };
}

function _handleUpdateCustomerOrder(body, user) {
_needRole(user, ['customer']);
const orderId = body.orderId || body.order_id;
const items = body.items;
if (!orderId || !Array.isArray(items)) throw new Error('بيانات غير صالحة');

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
for (let i = 1; i < itemsData.length; i++) {
if (itemsData[i][itemIdIdx] === upd.item_id) {
actions.push({ row: i + 1, data: itemsData[i], update: upd });
break;
}
}
});

const updates = actions.filter(a => a.update.action === 'update');
updates.forEach(a => {
const approved = Number(a.data[qtyAppIdx] || 0);
const requested = Number(a.update.quantity || 0);
if (requested < approved) {
throw new Error('غير مسموح بتخفيض الكمية المصادق عليها للصنف (' + a.data[codeIdx] + '). المعتمد: ' + approved);
}
itemsSheet.getRange(a.row, qtyReqIdx + 1).setValue(requested);
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

return { success: true };
}

function _handleConfirmWarehousePrep(body, user) {
_needRole(user, ['admin', 'manager', 'warehouse']);
const orderId = body.orderId || body.order_id;
const itemsUpdates = body.items;
if (!orderId || !Array.isArray(itemsUpdates)) throw new Error('بيانات غير صالحة');

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

_add('Shipments', {
shipment_id: 'SHP-' + Utilities.getUuid().substring(0, 8).toUpperCase(),
order_id: orderId,
package_count: body.package_count || '',
carton_count: body.carton_count || '',
bag_count: body.bag_count || '',
status: 'prepared',
shipping_date: _now()
});

_updateStatusInternal(orderId, 'prepared');
_notifyRole('accountant', 'طلب مجهز', 'تم تجهيز الطلب ' + orderId + ' في المستودع.');
_notifyRole('admin', 'طلب مجهز', 'الطلب ' + orderId + ' جاهز للشحن.');

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
const customers = _all('Customers').filter(c => c.status !== 'deleted' && c.status !== 'inactive');
const payments = _all('Payments');
const orders = _all('Orders');
const orderItems = _all('Order_Items');

return {
customers: customers.map(c => {
const totalPaid = payments
.filter(p => p.customer_id === c.customer_id)
.reduce((sum, p) => sum + Number(p.amount || 0), 0);

const customerOrders = orders.filter(o =>
o.customer_id === c.customer_id &&
['approved', 'prepared', 'shipping', 'delivered'].includes(o.status)
);

let totalOrdersValue = 0;
customerOrders.forEach(o => {
const items = orderItems.filter(oi => oi.order_id === o.order_id);
items.forEach(item => {
totalOrdersValue += Number(item.final_price || item.display_price_snapshot || 0) * Number(item.quantity_approved || item.quantity_requested || 0);
});
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
balance: Number((totalOrdersValue - totalPaid + Number(c.opening_usd || 0)).toFixed(2))
};
})
};
}

function _handleCreateCustomer(body, user) {
_needRole(user, ['admin', 'manager', 'accountant']);
const customerId = 'CUS-' + Utilities.getUuid().substring(0, 5).toUpperCase();
const username = String(body.username || '').toLowerCase();
if (!username) throw new Error('اسم المستخدم مطلوب');

const existing = _all('Users').find(u => String(u.username).toLowerCase() === username);
if (existing) throw new Error('اسم المستخدم موجود مسبقاً');

_add('Customers', {
customer_id: customerId,
full_name: body.full_name,
company_name: body.company_name || '',
phone: body.phone || '',
address: body.address || '',
province: body.province || '',
notes: body.notes || '',
opening_usd: body.opening_usd || 0,
opening_syp: body.opening_syp || 0,
status: 'active',
created_at: _now()
});

const salt = Utilities.getUuid();
_add('Users', {
user_id: 'USR-' + Utilities.getUuid().substring(0, 5),
username: username,
password_hash: _digest(username + salt),
salt: salt,
full_name: body.full_name,
phone: body.phone || '',
role: 'customer',
customer_id: customerId,
status: 'active',
must_change_password: 'yes',
created_at: _now()
});

return { success: true, customer_id: customerId, message: 'تم إنشاء حساب العميل بنجاح' };
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
_sendNotification(customerUser.user_id, 'تم استلام دفعة', 'تم تقييد مبلغ ' + amount + ' ' + (body.currency || 'USD') + ' في حسابكم.');
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
_sendNotificationToRoles('admin,manager,accountant', 'استلام دفعة', 'تم استلام دفعة من الزبون بقيمة ' + amount + ' ' + currency, 'payment', paymentId);
} else {
_sendNotificationToRoles('admin,manager', 'صرف من الصندوق', 'تم صرف مبلغ ' + amount + ' ' + currency + ' من ' + boxType, 'payment', paymentId);
}

return { success: true, payment_id: paymentId };
}

function _handleUpdatePayment(body, user) {
_needRole(user, ['admin', 'manager', 'accountant']);
const paymentId = body.payment_id;
if (!paymentId) throw new Error('رقم الدفعة مطلوب');

const payments = _all('Payments');
const paymentIndex = payments.findIndex(p => p.payment_id === paymentId);
if (paymentIndex === -1) throw new Error('الدفعة غير موجودة');

const oldPayment = payments[paymentIndex];
const newAmount = Number(body.amount || oldPayment.amount);
const newActionType = body.action_type || oldPayment.action_type;
const newBoxType = body.box_type || oldPayment.box_type;
const newCurrency = body.currency || oldPayment.currency;
const newCustomerId = body.customer_id !== undefined ? body.customer_id : oldPayment.customer_id;
const newNote = body.note !== undefined ? body.note : oldPayment.note;

_updateBoxBalance(oldPayment.box_type, oldPayment.currency, Number(oldPayment.amount), oldPayment.action_type === 'receive' ? 'pay' : 'receive');
_updateBoxBalance(newBoxType, newCurrency, newAmount, newActionType === 'receive' ? 'receive' : 'pay');

const sheet = _ss().getSheetByName('Payments');
const rowIndex = paymentIndex + 2;
const paymentsHeaders = H.Payments;

sheet.getRange(rowIndex, paymentsHeaders.indexOf('amount') + 1).setValue(newAmount);
sheet.getRange(rowIndex, paymentsHeaders.indexOf('action_type') + 1).setValue(newActionType);
sheet.getRange(rowIndex, paymentsHeaders.indexOf('box_type') + 1).setValue(newBoxType);
sheet.getRange(rowIndex, paymentsHeaders.indexOf('currency') + 1).setValue(newCurrency);

if (body.customer_id !== undefined) {
sheet.getRange(rowIndex, paymentsHeaders.indexOf('customer_id') + 1).setValue(newCustomerId);
}
if (body.note !== undefined) {
sheet.getRange(rowIndex, paymentsHeaders.indexOf('note') + 1).setValue(newNote);
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

function _handleDeletePayment(body, user) {
_needRole(user, ['admin', 'manager', 'accountant']);
const paymentId = body.payment_id;
if (!paymentId) throw new Error('رقم الدفعة مطلوب');

const payments = _all('Payments');
const paymentIndex = payments.findIndex(p => p.payment_id === paymentId);
if (paymentIndex === -1) throw new Error('الدفعة غير موجودة');

const payment = payments[paymentIndex];
_updateBoxBalance(payment.box_type, payment.currency, Number(payment.amount), payment.action_type === 'receive' ? 'pay' : 'receive');

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

function _handleGetBoxBalances(body, user) {
_needRole(user, ['admin', 'manager', 'accountant']);
const boxesBalance = _all('Boxes_Balance');
let cashBoxSYP = boxesBalance.find(b => b.box_name === 'cash_box' && b.currency === 'SYP');
let cashBoxUSD = boxesBalance.find(b => b.box_name === 'cash_box' && b.currency === 'USD');
let shamCashSYP = boxesBalance.find(b => b.box_name === 'sham_cash' && b.currency === 'SYP');
let shamCashUSD = boxesBalance.find(b => b.box_name === 'sham_cash' && b.currency === 'USD');

return {
balances: {
cash_box_syp: Number((cashBoxSYP ? cashBoxSYP.balance : 0) || 0),
cash_box_usd: Number((cashBoxUSD ? cashBoxUSD.balance : 0) || 0),
sham_cash_syp: Number((shamCashSYP ? shamCashSYP.balance : 0) || 0),
sham_cash_usd: Number((shamCashUSD ? shamCashUSD.balance : 0) || 0),
}
};
}

function _updateBoxBalance(boxType, currency, amount, actionType) {
const boxesBalance = _all('Boxes_Balance');
let box = boxesBalance.find(b => b.box_name === boxType && b.currency === currency);
const sheet = _ss().getSheetByName('Boxes_Balance');

if (!box) {
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

const boxesBalanceUpdated = _all('Boxes_Balance');
const boxIndex = boxesBalanceUpdated.findIndex(b => b.box_id === box.box_id);
if (boxIndex === -1) return;

const rowIndex = boxIndex + 2;
const balanceCol = H.Boxes_Balance.indexOf('balance') + 1;
const lastUpdatedCol = H.Boxes_Balance.indexOf('last_updated') + 1;
const currentBalance = Number(boxesBalanceUpdated[boxIndex].balance || 0);

let newBalance;
if (actionType === 'receive') {
newBalance = currentBalance + amount;
} else {
newBalance = currentBalance - amount;
}

sheet.getRange(rowIndex, balanceCol).setValue(newBalance);
sheet.getRange(rowIndex, lastUpdatedCol).setValue(_now());
}

// ============================================================
// 11. المخزون (Inventory)
// ============================================================
function _handleGetInventoryMovements(body, user) {
_needRole(user, ['admin', 'manager', 'warehouse']);
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
function _handleGetShipments(body, user) {
_needRole(user, ['admin', 'manager', 'accountant', 'warehouse']);
return { shipments: _all('Shipments').reverse() };
}

function _handleShipment(body, user) {
_needRole(user, ['admin', 'manager', 'accountant', 'warehouse']);
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
package_count: body.package_count || '',
carton_count: body.carton_count || '',
bag_count: body.bag_count || '',
shipping_date: body.shipping_date || _now(),
status: body.status || 'shipping',
note: body.note || '',
});

return { success: true, shipment_id: shipmentId };
}

function _handleUpdateShipmentStatus(body, user) {
_needRole(user, ['admin', 'manager', 'warehouse']);
const shipmentId = body.shipmentId || body.shipment_id;
const newStatus = body.status;
if (!shipmentId || !newStatus) throw new Error('بيانات غير صالحة');

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

_notifyRole('admin', 'طلب نواقص جديد', 'قام المستودع بطلب نواقص للمنتج ' + body.code + ' بكمية ' + body.requested_qty);
_notifyRole('accountant', 'تنبيه مخزون', 'تم تسجيل طلب نقص مواد للمنتج ' + body.code + '.');

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
const notifications = _all('Notifications').filter(n => n.user_id === user.user_id);
return { notifications: notifications.reverse() };
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

function _handleSendNotification(body, user) {
const userIds = body.user_ids || [];
const title = body.title || '';
const messageBody = body.body || '';
const type = body.type || 'general';
const entityType = body.entity_type || '';
const entityId = body.entity_id || '';

if (!title || !messageBody) throw new Error('العنوان والرسالة مطلوبان');

const now = _now();
const notificationId = Utilities.getUuid();

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

function _sendNotification(userId, title, body, metadata) {
_add('Notifications', {
notification_id: Utilities.getUuid(),
user_id: userId,
title: title,
body: body,
type: (metadata && metadata.type) || 'general',
entity_type: (metadata && metadata.entity_type) || '',
entity_id: (metadata && metadata.entity_id) || '',
read_at: '',
created_at: _now(),
});
}

function _notifyRole(role, title, body) {
const users = _all('Users').filter(u => u.role === role && u.status === 'active');
users.forEach(u => {
_sendNotification(u.user_id, title, body);
});
}

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

if (['admin', 'manager', 'warehouse'].includes(user.role)) {
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
const customerId = body.customer_id || (user.role === 'customer' ? user.customer_id : null);
if (!customerId) throw new Error('رقم العميل مطلوب');

if (user.role === 'customer' && user.customer_id !== customerId) {
throw new Error('غير مصرح لك بعرض بيانات عميل آخر');
}

const customer = _all('Customers').find(c => c.customer_id === customerId);
if (!customer) throw new Error('العميل غير موجود');

const payments = _all('Payments').filter(p => p.customer_id === customerId);
const orders = _all('Orders').filter(o =>
o.customer_id === customerId &&
['approved', 'prepared', 'shipping', 'delivered'].includes(o.status)
);
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
total += Number(item.final_price || item.display_price_snapshot || 0) * Number(item.quantity_approved || item.quantity_requested || 0);
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
date: p.payment_date || p.created_at,
type: p.action_type === 'pay' ? 'صرف' : 'دفعة نقدية',
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
html += '<div style="margin-top: 30px; text-align: left;"><h3>الرصيد الإجمالي: ' + res.finalBalance + ' $</h3></div>';
html += '<div style="margin-top: 50px; text-align: center; color: #888; font-size: 10px;">';
html += 'تم الإنشاء بواسطة نظام أوركا أوردر - ' + new Date().toLocaleString('ar-EG');
html += '</div></div>';

const blob = HtmlService.createHtmlOutput(html).getAs('application/pdf');
blob.setName('Statement_' + customer.full_name + '_' + new Date().getTime() + '.pdf');

return _json({
ok: true,
success: true,
pdfBase64: Utilities.base64Encode(blob.getBytes()),
fileName: blob.getName()
});
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