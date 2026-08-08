# أوركا أوردر

حزمة مصدر تطبيق Android + Google Apps Script تعمل دون استضافة مدفوعة.

## الخطوات المختصرة
1. أنشئ ملف Google Sheets جديداً داخل حساب Orca.emp1@gmail.com.
2. من Extensions > Apps Script، أنشئ مشروعاً جديداً وانسخ محتوى `apps_script/Code.gs`.
3. من Project Settings > Script properties أضف:
   - `SPREADSHEET_ID`: معرّف ملف Google Sheet.
   - `APP_SECRET`: قيمة عشوائية طويلة (مفتاح سري).
4. شغّل الدالة `setupSystem()` مرة واحدة لإنشاء الجداول.
5. شغّل الدالة `seedAdmin('PASSWORD')` مع كلمة مرور قوية من محرر Apps Script فقط.
6. انشر Apps Script كـ **Web app** واحتفظ بالرابط.
7. عدّل ملف `mobile_app/lib/app_config.dart` وضع رابط الـ Web app في `apiUrl`.
8. داخل مجلد `mobile_app` نفّذ:
   ```bash
   flutter pub get
   flutter run
   ```

> تحذير: اختبر كل شيء ببيانات تجريبية قبل وضع بيانات العملاء الحقيقية أو إصدار APK.
