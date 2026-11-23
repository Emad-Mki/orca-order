# نشر أوركا أوردر على Firebase Hosting

## المتطلبات

- Flutter وDart بإصدارات متوافقة مع المشروع.
- Node.js وnpm.
- حساب Google ومشروع Firebase. يمكن استخدام خطة Spark المجانية للاستضافة.
- قبل النشر، يجب أن ينجح بناء نسخة الويب:

  ```powershell
  flutter build web --release
  ```

  **تنبيه خاص بهذا المشروع:** إعداد الويب موجود في `web/`، لكن بناء الويب
  الحالي لا يكتمل لأن قاعدة البيانات المحلية تستخدم Drift/SQLite عبر
  `dart:ffi`، وهي غير متاحة في المتصفح. لم يتم تغيير قاعدة البيانات أو منطق
  التطبيق لهذا الإعداد؛ لذلك لا يمكن نشر التطبيق العامل على الويب حتى تضاف
  تهيئة تخزين متوافقة مع المتصفح. لا ترفع مجلد `build/web` قديمًا على أنه
  إصدار جديد.

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

عنوان API الإنتاجي في إعداد التطبيق يبدأ بـ `https://` ويشير إلى Google Apps
Script. اتصال الويب به يعتمد على سماح endpoint بطلبات المتصفح من نطاق Hosting
الذي سيظهر مثل `https://YOUR_FIREBASE_PROJECT_ID.web.app` (وأي نطاق مخصص).
إعداد `firebase.json` يتحكم في رؤوس ملفات الاستضافة فقط، ولا يستطيع إضافة
رؤوس CORS إلى رد API خارجي.

تحقق بعد نشر API من أدوات المطور في المتصفح (F12 → Network/Console) عند تسجيل
الدخول وطلب البيانات. إذا ظهر `CORS` أو فشل طلب `OPTIONS`، يجب ضبط دعم CORS في
خدمة API نفسها أو استخدام وسيط HTTPS موثوق يعيد توجيه الطلبات. لا تضع أسرارًا
أو رموز خدمة في تطبيق الويب؛ كود المتصفح عام. لا يمكن تأكيد نجاح CORS من
إعداد Hosting وحده.

## حل الأخطاء الشائعة

- **صفحة بيضاء:** افتح F12 → Console. تأكد أن `flutter build web --release`
  نجح، وأن `build/web/index.html` و`flutter_bootstrap.js` نُشرا. أصلح أخطاء
  JavaScript أو CORS الظاهرة؛ دعم Web يحتاج أيضًا إلى معالجة اعتماد SQLite
  على `dart:ffi` المذكور أعلاه.
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
- **رفض CORS:** هذا من API وليس Firebase Hosting؛ تحقق من سماح الـAPI لنطاق
  `web.app` وHTTPS. إن كان المصدر Apps Script ولا يدعم طلب المتصفح المطلوب،
  يلزم وسيط API ملائم؛ لا يمكن إصلاحه بإضافة rewrite للصفحات.
