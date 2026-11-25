# نشر أوركا أوردر على Firebase Hosting

## المتطلبات

- Flutter وDart بإصدارات متوافقة مع المشروع.
- Node.js وnpm.
- حساب Google ومشروع Firebase. يمكن استخدام خطة Spark المجانية للاستضافة.
- قبل النشر، يجب أن ينجح بناء نسخة الويب:

  ```powershell
  flutter build web --release
  ```

  يستخدم اتصال قاعدة البيانات على الويب إصدار Drift WebAssembly، بينما تبقى
  قاعدة البيانات الأصلية كما هي على Android والمنصات الأصلية. يتضمن البناء
  `sqlite3.wasm` و`drift_worker.js` تلقائيًا؛ تأكد من نشرهما مع بقية
  `build/web` ومن أن الخادم يقدّم ملفات `.wasm` بنوع المحتوى
  `application/wasm`. لا ترفع مجلد `build/web` قديمًا على أنه إصدار جديد.

## الإعداد والنشر من Windows

افتح PowerShell في مجلد المشروع:

```powershell
cd C:\Users\eMAD\AndroidStudioProjects\orca-order-main\mobile_app
flutter config --enable-web
```

إذا لم يظهر Chrome أو Web Server في `flutter devices`، أنشئ ملفات منصة الويب
فقط. هذا الخيار لا يعيد إنشاء ملفات Android أو iOS:

```powershell
flutter create --platforms=web .
```

الأمر العام المطلوب `flutter create .` يعيد تهيئة ملفات المنصات للمشروع
القائم؛ استخدمه فقط إذا أردت إنشاء كل المنصات الناقصة، وراجع تغييرات الملفات
المخصصة بعده. لا حاجة إليه إذا أنشأت الويب بالأمر المحدد أعلاه.

```powershell
flutter create .
```

ثبّت أدوات Firebase وسجّل الدخول:

```powershell
npm install -g firebase-tools
firebase login
firebase projects:list
```

شغّل إعداد Hosting **قبل** بناء الويب لأول مرة، واختر مشروع Firebase الصحيح.
عند الأسئلة اختر:

- Public directory: `build/web`
- Configure as a single-page app (rewrite all URLs to `/index.html`): `Yes`
- Set up automatic builds and deploys with GitHub: حسب رغبتك (`No` للنشر اليدوي)

```powershell
firebase init hosting
```

احتفظ بملف `firebase.json` الموجود في جذر المشروع؛ إذا عرض Firebase استبداله
اختر عدم الاستبدال. بعد نجاح إعداد دعم الويب وقاعدة البيانات للمتصفح:

```powershell
flutter clean
flutter pub get
flutter build web --release
firebase deploy --only hosting
```

يمكن تحديد مشروع Firebase صراحةً لتجنب النشر إلى مشروع خاطئ:

```powershell
firebase deploy --only hosting --project YOUR_FIREBASE_PROJECT_ID
```

## API وCORS

يستقبل Google Apps Script جسم JSON من `doPost(e)` عبر `e.postData.contents`
بغض النظر عن نوع المحتوى. لذلك يرسل تطبيق الويب الطلب بـ
`Content-Type: text/plain; charset=utf-8` لتجنّب طلب `OPTIONS` التمهيدي الذي
لا يعالجه Apps Script؛ ويبقى Android على `application/json`. بيانات الدخول
وكلمة المرور تُرسل في جسم POST فقط، ولا تستخدم GET.

بعد أي تعديل على هذا السلوك، انشر نسخة الويب:

```powershell
flutter build web --release
firebase deploy --only hosting
```

ثم افتح الموقع المنشور، نفّذ إعادة تحميل قوية بـ `Ctrl+F5`، وافحص F12 →
Network. يجب أن يظهر طلب `POST` إلى رابط `/exec` دون طلب `OPTIONS` قبله، ثم
استجابة JSON وبها `Access-Control-Allow-Origin`. لا يستطيع `firebase.json`
إضافة رؤوس CORS إلى API خارجي؛ يعتمد هذا الحل على الطلب البسيط واستجابة
Google Apps Script القابلة للقراءة من المتصفح.

**إذا ظهر `401 Unauthorized` أو استمر CORS:** هذا يعني أن Google يرفض الطلب
قبل تشغيل `doPost`، لذلك لا يستطيع كود Apps Script إضافة ترويسة CORS للرد.
عدّل صلاحية النشر يدويًا:

1. افتح مشروع Apps Script المرتبط بهذا الـAPI، ثم Deploy → Manage deployments.
2. اضغط Edit (رمز القلم) على نشر Web app المستخدم. اختر **New version** إذا
   طلبت الواجهة ذلك.
3. اضبط **Execute as** على حساب مالك الخدمة، و**Who has access** على **Anyone**
   (وليس Anyone with Google account أو مستخدمي المؤسسة فقط).
4. اضغط Deploy، وأكمل تفويض الصلاحيات إن طُلب. لا تنشئ نشرًا جديدًا منفصلًا إلا
   عند الحاجة؛ تعديل النشر الحالي يحافظ عادةً على رابط `/exec`.
5. إذا تغيّر رابط `/exec`، حدّث `AppConfig.apiUrl` في `lib/app_config.dart`
   بالرابط الجديد، ثم ابنِ وانشر الموقع مجددًا حسب الخطوات أعلاه.
6. أرسل طلب POST تجريبيًا دون بيانات اعتماد إلى `/exec`. استجابة JSON من الـAPI
   مثل `AUTH_REQUIRED` تثبت أن الطلب وصل إلى `doPost`؛ ثم اختبر تسجيل الدخول من
   الموقع. ظهور 401 أو صفحة دخول Google يعني أن إعداد الوصول لم يُطبّق بعد.

نشر **Anyone** يجعل عنوان Web App قابلًا للوصول العام؛ يجب أن تظل العمليات
باستثناء `login` محمية برمز الجلسة كما في `doPost`. إذا لم يظهر خيار Anyone،
فقد تمنع سياسة Google Workspace ذلك، ويلزم من مسؤول المؤسسة السماح بنشر Web
App عام. إعدادات Firebase لا تستطيع تجاوز هذا المنع.

لا تضع أسرارًا أو رموز خدمة في تطبيق الويب؛ كود المتصفح عام. ولا يلزم تعديل
Android أو إعادة بناء APK لمعالجة CORS في الويب.

## الطباعة والصور في الويب

تطبيق الويب لا يملك مجلدات `path_provider` المحلية الخاصة بـ Android؛ لذلك
يتجاوز حفظ تفاصيل الطلب وصور المنتجات ونسخ PDF المؤرشفة على الويب بدل إظهار
أخطاء تخزين. تبقى معاينة/طباعة PDF متاحة أثناء فتح الصفحة، وتبقى هذه الكاشات
والأرشفة المحلية مفعّلة في Android. صور Drive تُعرض عبر عنصر صورة HTML احتياطي
في الويب عند منع قراءة الصورة بسبب CORS؛ Android يحتفظ بعارض الصور المخزّن
لديه.

بعد تحديث نسخة الويب:

```powershell
flutter build web --release
firebase deploy --only hosting --project orca-order
```

أعد تحميل الموقع بـ `Ctrl+F5`. لا حاجة لإعادة نشر Apps Script أو بناء APK
Android لهذه التعديلات.

## حل الأخطاء الشائعة

- **صفحة بيضاء:** افتح F12 → Console. تأكد أن `flutter build web --release`
  نجح، وأن `build/web/index.html` و`flutter_bootstrap.js` وملفي
  `sqlite3.wasm` و`drift_worker.js` نُشرت. أصلح أخطاء JavaScript أو CORS
  الظاهرة، وتأكد أن نوع محتوى ملف `.wasm` هو `application/wasm`.
- **404 عند فتح رابط داخلي أو تحديث الصفحة:** تحقق أن `firebase.json` في
  جذر المشروع وأن `rewrites` يعيد كل المسارات إلى `/index.html`. أعد الإعداد
  عبر `firebase init hosting` مع اختيار SPA = Yes، ثم انشر مجددًا.
- **نسخة قديمة بعد التحديث:** إعداد Cache-Control يمنع التخزين الطويل لملفات
  الصفحة وFlutter bootstrap/service worker وملف التطبيق. نفّذ بناءً جديدًا ثم
  `firebase deploy --only hosting`، وبعدها أعد تحميلًا قسريًا بـ `Ctrl+F5`
  أو امسح بيانات الموقع وService Worker من أدوات المطور.
- **فشل deploy أو `Not in a Firebase app directory`:** نفّذ الأوامر من مجلد
  المشروع الذي يحتوي `firebase.json`، ثم `firebase login` و
  `firebase projects:list`. أعد `firebase init hosting` واختر المشروع
  الصحيح، أو مرّر `--project YOUR_FIREBASE_PROJECT_ID`.
- **رفض CORS:** تحقق أن طلب الويب يستخدم `text/plain; charset=utf-8` وأنه لا
  يرسل `OPTIONS`. تحقق أيضًا من نشر نسخة Hosting الجديدة ومن صلاحية نشر Web
  App في Apps Script. قواعد rewrite في Firebase Hosting لا تصلح CORS لواجهة
  API خارجية.
