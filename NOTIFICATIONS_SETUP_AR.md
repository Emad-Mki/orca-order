# إعداد إشعارات Orca Order

## الحالة الحالية

- أضيفت مواضيع `role_admin` و`role_manager` و`role_accountant` و`role_warehouse` و`role_salesperson` و`role_customer` للإعلانات **العامة فقط**. يستطيع أي تثبيت الاشتراك في أي موضوع؛ أسماء الأدوار ليست آلية مصادقة، وإلغاء الاشتراك قد يفشل دون اتصال. لا تضع معلومات طلبات أو حسابات أو معرّفات خاصة في الرسائل أو بياناتها. تستمر أحداث الطلبات والفواتير الحالية بالإرسال الموجّه للأجهزة المسجلة بعد تحقق الخادم من المستلمين، ولا تُبث تلقائيًا على المواضيع.
- معرّف Android في Gradle و`MainActivity` هو `com.orcallc.orca_order`.
- يوجد إعداد Android محلي في `android/app/google-services.json` ويطابق معرّف الحزمة. هذا الملف إعداد عميل Firebase وليس مفتاح Service Account؛ لا تستبدله بإعداد مشروع آخر دون تحديث تطبيق Firebase.
- يستخدم Android الإعداد الأصلي عبر Google Services Gradle plugin و`Firebase.initializeApp()`؛ لا يوجد `firebase_options.dart` حاليًا. تهيئة Firebase غير حاجبة لشاشة الدخول، وفشلها لا يمنع تشغيل التطبيق.
- `Code.gs` يرسل عبر FCM HTTP v1 فقط. لا يوجد مفتاح FCM legacy أو Service Account داخل Flutter.
- تُضاف أعمدة `event_id` إلى `Notifications` و`enabled` و`fcm_target_type` إلى `User_Devices` بترحيل إضافي لا يمسح البيانات. تسجّل النسخة الحديثة FID وتستهدفه عبر HTTP v1؛ الأجهزة القديمة التي لا تحتوي نوع هدف تستمر باستعمال FCM registration token. تبقى `status` لحالة الإرسال و`is_read`/`read_at` لحالة القراءة.
- يلزم نشر نسخة `Code.gs` وتشغيل التهيئة والإعدادات أدناه قبل اعتبار الإرسال من الخادم فعالًا. لم يتم نشر شيء أو تغيير Firebase/Apps Script عن بُعد.

## إرسال إعلان إلى موضوع عبر هوية Apps Script

1. اربط مشروع Apps Script بمشروع Google Cloud قياسي، وفعّل فيه Firebase Cloud Messaging API. أضف Script Property باسم `FCM_PROJECT_ID` بقيمة **معرّف مشروع Firebase** وليس رقمه.
2. أضف هوية الحساب الذي ينفّذ Web App أو المشغّل إلى IAM في مشروع Firebase، وامنحه صلاحية `cloudmessaging.messages.create`، مثلاً عبر دور `Firebase Cloud Messaging API Admin`. `ScriptApp.getOAuthToken()` يمثل هوية منفّذ Apps Script، وليس تلقائيًا Service Account لمشروع Firebase. عند اختلاف المشروعين يجب منح الهوية الصلاحية في المشروع المستهدف.
3. انشر `appsscript.json` مع `Code.gs` وأعِد تفويض جميع النطاقات. النطاقات تشمل Sheets وDrive وUrlFetch والمشغلات وFCM حتى لا تتعطل وظائف النظام الحالية.
4. من وظيفة موثوقة على الخادم فقط، أرسل إعلانًا عامًا، مثلاً:

```javascript
sendFCMNotification(
  'role_warehouse',
  'إعلان عام',
  'يرجى فتح التطبيق للاطلاع على آخر المستجدات.',
  '/notifications',
  ''
);
```

الدالة تدعم أيضًا `/orders` مع `orderId`، لكن يُستخدم ذلك فقط إذا كان المعرّف نفسه معلومة عامة؛ تفاصيل الطلب لا تُرسل في الرسالة، ويتحقق التطبيق من الدور ثم يطلب الطلب من الخادم الذي يفحص ملكية العميل. لا تستدعِ الدالة مباشرة من بيانات مستخدم غير موثوق، ولا تضفها إلى `doPost` دون مصادقة وصلاحية صريحة. الإرسال الحالي المرتبط بتغيرات الطلب يستخدم المسار الموجّه للأجهزة، وليس هذا البث.

شكل طلب HTTP v1 هو `message: {topic, notification: {title, body}, data: {notification_id, deep_link, order_id, target_role, channel_id}, android: {...}}`، وجميع قيم `data` نصوص. يقبل FCM الطلب أو يرفضه بخطأ HTTP؛ القبول لا يضمن التسليم. رسائل `notification` تُعرض عادةً من النظام في الخلفية، أما الواجهة فتستخدم إشعارًا محليًا واحدًا. لا تُعرض رسائل الخلفية مرتين من معالج Dart.

يخزن التطبيق الموضوع المشترك فيه محليًا ويحاول إلغاءه عند الخروج أو تبديل الدور، ثم يشترك في الموضوع الجديد. عند فشل الشبكة يبقى اسم الموضوع السابق للمحاولة مجددًا؛ لذلك لا تعتمد على إلغاء الاشتراك لحماية البيانات. عند النقر، يُؤجل التوجيه حتى تكتمل شاشة الدخول وتغيير كلمة المرور إن لزم، وتُرفض الأدوار أو الحسابات غير المطابقة، وتخضع بيانات الطلب للتحقق على الخادم.

## 1. مشروع Firebase وتطبيق Android

1. أنشئ مشروع Firebase أو اختر المشروع الذي سيستخدمه Orca Order.
2. أضف تطبيق Android بمعرّف الحزمة `com.orcallc.orca_order` (الموجود في `android/app/build.gradle.kts`).
3. نزّل `google-services.json` من إعدادات التطبيق وضعه في `android/app/google-services.json`.
4. لا تضع Service Account JSON في هذا المسار أو في Flutter. ملف `google-services.json` هو إعداد عميل، أما مفتاح Service Account فهو سر خادمي.

لإعداد iOS، أضف تطبيق iOS بمعرّفه من إعدادات Runner، نزّل `GoogleService-Info.plist`، فعّل Push Notifications وBackground Modes/Remote notifications، واضبط APNs Authentication Key في Firebase. لا يحتوي المشروع حاليًا على ملف iOS هذا أو إعداد FlutterFire مولّد، لذلك لا تعتبر إشعارات iOS جاهزة.

أضف `GoogleService-Info.plist` إلى هدف Runner في Xcode، مع توقيع provisioning profile يدعم Push Notifications. `Info.plist` يتضمن `remote-notification` بالفعل؛ فعّل أيضًا Capability في Xcode. يستخدم `AppDelegate.swift` الحالي `FlutterAppDelegate` وتسجيل الإضافات في المحرك الضمني، فلا تستبدله بمثال قديم ولا تعطل Firebase method swizzling. يطلب Flutter الإذن عبر `requestPermission` بعد تسجيل الدخول. في Android يوجد `POST_NOTIFICATIONS` وأيقونة وقناة افتراضية في `AndroidManifest.xml`؛ تُنشأ القنوات عند تهيئة الخدمة قبل الاشتراك. الإذن مطلوب على Android 13 فأحدث. قد يمنع فرض إيقاف التطبيق من إعدادات النظام التسليم إلى أن يفتحه المستخدم مجددًا؛ إغلاقه العادي لا يعني ذلك.

يجب فتح التطبيق مرة واحدة على الأقل قبل استقبال الرسائل. على iOS، بعد إغلاق التطبيق بالسحب قد يلزم فتحه مجددًا لاستقبال رسائل الخلفية؛ وعلى Android يلزم فتحه مجددًا بعد فرض الإيقاف من إعدادات النظام.

## 2. FlutterFire

Android الحالي يقرأ إعداد Firebase الأصلي من `google-services.json` ولا يحتاج ملف خيارات مولّد. إذا أُضيف iOS أو منصة أخرى، شغّل FlutterFire CLI محليًا للمشروع نفسه:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure --project <FIREBASE_PROJECT_ID> --platforms android,ios
```

احتفظ بمعرّف المشروع الذي تختاره، ولا تستخدم قيمة افتراضية أو وهمية. عند إضافة `firebase_options.dart` للمنصات الأخرى، عدّل نقطة التهيئة لاستخدام `DefaultFirebaseOptions.currentPlatform` وتحقق من إعدادات كل منصة. لا ترفع أي ملف Service Account أو مفتاح خاص.

## 3. خدمات Google المطلوبة

- فعّل **Firebase Cloud Messaging API (HTTP v1)** في Google Cloud للمشروع نفسه؛ لا تفعّل أو تستخدم Legacy HTTP API.
- اسمح لـ Apps Script بإجراء طلبات `UrlFetchApp` إلى `oauth2.googleapis.com` و`fcm.googleapis.com`. راجع أذونات OAuth التي يطلبها Apps Script عند تشغيله.
- لا يلزم Firestore أو Realtime Database لهذا الربط؛ مصدر البيانات الحالي هو Google Sheets الذي يستخدمه `Code.gs`.

## 4. هوية الإرسال والصلاحيات

أنشئ Service Account مخصصًا للإرسال في مشروع Firebase، وامنحه أقل دور يتيح إرسال FCM (`Firebase Cloud Messaging API Admin`/`roles/firebasecloudmessaging.admin` عند توفره في المشروع). لا تستخدم حساب مالك المشروع أو مفتاحًا شخصيًا عامًا.

في محرر Apps Script للمشروع الذي يشغّل `Code.gs`، أضف Script Property:

| الاسم | القيمة |
|---|---|
| `FCM_SERVICE_ACCOUNT_JSON` | محتوى JSON كاملًا لمفتاح Service Account المخصص |

تأكد أن `project_id` في المفتاح يخص مشروع Firebase نفسه. Script Properties ليست مخزن أسرار مخصصًا: قصّر صلاحية محرري Apps Script، ولا تسجل القيمة أو تضعها في مصدر التحكم أو التذاكر أو المحادثات. إذا انكشف المفتاح فألغِه وأصدر بديلًا. احتفظ بـ`SPREADSHEET_ID` الحالي ولا تغيّره أثناء إعداد الإشعارات.

## 5. أوراق البيانات والنشر

1. خذ نسخة احتياطية معتادة من ملف البيانات قبل الترحيل.
2. انشر التعديلات الحالية على `Code.gs` إلى مشروع Apps Script المرتبط بمصدر البيانات نفسه.
3. شغّل `setupSystem()` يدويًا مرة واحدة من محرر Apps Script بحساب مشغّل النظام. يضيف الأعمدة الناقصة إلى `Notifications` و`User_Devices` دون حذف الأوراق أو صفوفها، وينشئ الورقة إن لم تكن موجودة.
4. شغّل `installNotificationRetryTrigger()` مرة واحدة لتثبيت إعادة المحاولة المحدودة كل خمس دقائق. راجع صفحة Triggers للتأكد من وجود مشغّل واحد لـ`retryPendingNotifications`.
5. أنشئ إصدار Web App جديدًا وانشره وفق سياسة الوصول الحالية للتطبيق، مع التنفيذ بهوية الحساب المخوّل الذي يصل إلى Sheets. لا توسّع الوصول إلى «أي شخص» لتجاوز المصادقة؛ كل عمليات الأجهزة والإشعارات تعتمد جلسة Orca الموثقة.
6. حدّث عنوان API في إعدادات التطبيق فقط إذا تغيّر عنوان النشر. لا توجد ورقة منفصلة مطلوبة؛ سجل الإرسال والقراءة يبقى في `Notifications`، وسجلات الأجهزة في `User_Devices`.

يستخرج `user_id` من الجلسة التي تحقق منها `Code.gs`، ولا يعتمد على `user_id` المرسل من Flutter. تُحدد مستلمي الأحداث من أدوار وحسابات `Users` النشطة. لا تُرسل أرقام أسعار أو أرصدة في الرسائل الظاهرة.

## 6. اختبار آمن

1. ثبّت نسخة Android على هاتف اختبار، سجّل الدخول، ووافق على الإذن. تحقق من ظهور الجهاز في `User_Devices` مع `enabled=true` و`is_active=true` و`fcm_target_type=fid` من دون نسخ المعرّف إلى سجل عام.
2. يرسل الخادم إلى FID المخزن مباشرةً، بينما Firebase Console تطلب FCM registration token ولا تقبل FID. لاختبار Console تحديدًا، استخرج مؤقتًا FCM registration token من تثبيت اختبار موثوق باستخدام `FirebaseMessaging.instance.getToken()` في جلسة تطوير محلية، ولا تطبعه في سجلات مشتركة أو تضفه إلى المستودع؛ ألصقه في **Send test message** ثم امسح الحافظة. البديل لاختبار FID دون استخراج token هو إرسال رسالة اختبار من Apps Script/HTTP v1 بعد إعداد هوية الإرسال. لا ترسل اختبارًا إلى رموز مستخدمي الإنتاج.
3. اختبر اختبارًا وظيفيًا بحسابات اختبار: إنشاء طلب عميل، تغيير حالته، تجهيز الطلب إن كان مساره مفعّلًا، فاتورة مبيع لمندوب، ودفعة لعميل مرتبط بحساب نشط.
4. كرر الاختبارات والتطبيق مفتوح، في الخلفية، وبعد إغلاقه ثم الضغط على الإشعار. تحقق من فتح مركز الإشعارات/الطلب/صفحة المبيعات المعتمدة، ثم سجّل الخروج وبدّل الحساب على الجهاز.
5. تحقق في مركز الإشعارات من `event_id` و`status` و`read_at` و`is_read`. `status=sent` يعني أن FCM قبل الإرسال فقط، ولا يثبت وصوله للهاتف أو قراءته. يتضمن التطبيق معرف الإشعار لمنع إعادة العرض المحلية؛ ولا يوجد ضمان تسليم مرة واحدة تمامًا.

## 7. تشخيص عدم الوصول

- **لا يوجد صف جهاز أو `enabled=false`:** تحقق من جلسة الدخول، إذن النظام، نجاح تسجيل الدخول، وطلبات `user_device_upsert`/`user_device_deactivate`. راجع أن تغيير الحساب أو تسجيل الخروج لم يترك الجهاز مرتبطًا بالحساب السابق، وأن `fcm_target_type` يطابق القيمة المخزنة (`fid` للتسجيل الحديث أو `token` للأجهزة القديمة).
- **`Notifications.status=pending` و`NO_ACTIVE_DEVICE`:** لم يُسجّل جهاز صالح مفعّل لهذا الحساب؛ راجع ورقة الأجهزة وإعداد FCM في التطبيق.
- **الحالة `failed` مع إعداد Service Account:** افحص سجل تنفيذ Apps Script ورسالة الخطأ المختصرة؛ تحقق من `FCM_SERVICE_ACCOUNT_JSON`، وصلاحية الدور، وتمكين FCM HTTP v1، وتطابق المشروع. لا تسجل الرمز أو المفتاح.
- **FCM قبل الرسالة (`sent`) ولم تظهر:** تحقق من إذن Android، قناة الإشعار، إعدادات البطارية/الشبكة والجهاز، ثم اختبر foreground مقابل background. قبول FCM ليس إقرار وصول.
- **تظهر ولا تفتح المحتوى:** راجع بيانات `notification_id`/`type`/`entity_type`/`entity_id`، جلسة التطبيق، وصلاحية endpoint الذي يجلب تفاصيل الكيان. المحتوى يُجلب بعد المصادقة؛ لا تضع بيانات مالية في payload.
- **التكرار:** قارن `event_id` و`notification_id` وسجل الإرسال؛ راجع المحاولات الجزئية أو إعادة المحاولة. تستخدم رسائل النظام معرفًا ثابتًا للتجميع/الاستبدال، ويمنع التطبيق إعادة العرض المحلية بالمعرّف.

## ما لم يمكن التحقق منه محليًا

لا يمكن من بيئة التطوير تأكيد صلاحية Service Account أو إصدار Apps Script المنشور أو وصول FCM/APNs لهاتف حقيقي. لذلك يظل الإرسال/الاستقبال الفعلي، سلوك إذن Android على الجهاز، اختبار حسابين، تشغيل trigger، إعداد iOS، وتنظيف رموز FCM غير الصالحة بحاجة إلى الإعداد والاختبار أعلاه.
