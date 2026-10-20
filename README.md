# زعيم التداول · تطبيق أندرويد (WebView + AndroidBridge)

مشروع Android أصلي (Kotlin) يلفّ موقع **زعيم التداول** داخل WebView، ويحقن جسر
`window.AndroidBridge` يتيح قراءة كوكي جلسة Pocket Option (`ssid`) عبر
`CookieManager` وإرسالها تلقائيًا إلى `POST /api/connect-session` على نفس نطاق الموقع.

> هذا المجلد مصدر جاهز للبناء. لا يوجد ملف APK مرفق، ولم يُبنَ داخل بيئة المعاينة
> (لا تتوفر فيها أدوات Android SDK/Gradle).

## المسار الكامل للربط

1. يفتح التطبيق عنوان الموقع المُعدّ داخل `WebView` (كوكيز WebView مشتركة على مستوى
   العملية، مع تفعيل كوكيز الطرف الثالث).
2. المستخدم يسجّل الدخول إلى الموقع نفسه (كوكي `zaeem_session` مطلوب لتوثيق الـ API).
3. المستخدم يضغط **«ربط حساب Pocket Option»** في لوحة التحكم.
4. الصفحة تنادي `window.AndroidBridge.connectSession()`.
5. الجسر يتأكد أن الصفحة الحالية على نطاق الموقع، يقرأ `ssid` من
   `CookieManager.getCookie("https://pocketoption.com")`، ويقرأ كوكي توثيق الموقع من
   نفس المدير.
6. الجسر يرسل الطلب في Thread خلفي إلى `https://<موقعك>/api/connect-session` مع
   `session_cookie: "ssid value"`، ثم يعيد النتيجة إلى الصفحة عبر
   `window.AndroidBridgeCallback({success, code, message})`.
7. الخادم يشفّر الجلسة بـ AES-256-GCM ويحوّل الحالة إلى **متصل**.

إذا لم توجد جلسة Pocket Option بعد، يفتح الجسر شاشة تسجيل الدخول داخل التطبيق
(`SessionLoginActivity`)؛ بعد نجاح الدخول تُطلق الصفحة حدث
`zaeem:session-ready` فيُستكمل الربط تلقائيًا.

## البناء

المتطلبات: JDK 17، Android SDK 35، Gradle 8.7+ (أو Android Studio Ladybug أو أحدث).

```bash
cd android-app
# إن لم يكن Gradle مثبتًا: افتح المجلد في Android Studio وسيُنشئ الـ wrapper.
gradle wrapper --gradle-version 8.7
./gradlew assembleDebug          # app/build/outputs/apk/debug/app-debug.apk
./gradlew assembleRelease        # يتطلب signingConfig (انظر أدناه)
```

## تصدير ملف APK

لا يوجد ملف APK جاهز مرفق بالمشروع، ولم يُبنَ داخل بيئة المعاينة (أدوات أندرويد الأصلية
تحتاج glibc غير متوفر هناك). الطرق الثلاث التالية تُنتج ملفًا قابلًا للتثبيت:

### ١) Android Studio (الأسهل)

1. افتح مجلد `android-app` في Android Studio (Ladybug أو أحدث) وانتظر انتهاء Sync.
2. عدّل `zaeem.siteUrl` في `gradle.properties`، أو اتركه فارغًا وأدخل عنوان الموقع من شاشة الإعداد عند أول تشغيل.
3. `Build ▸ Build Bundle(s) / APK(s) ▸ Build APK(s)`.
4. الملف الناتج: `app/build/outputs/apk/debug/app-debug.apk` (افتح `locate` من الرسالة المنبثقة).
5. للتثبيت المباشر على هاتف موصول بكابل USB مع تفعيل تصحيح USB: اضغط ▶ Run.

للنسخة الموقّعة القابلة للتوزيع: `Build ▸ Generate Signed App Bundle / APK ▸ APK` ثم أنشئ
keystore (احتفظ به وبكلماته، فبدونه لا يمكن تحديث التطبيق لاحقًا).

### ٢) سطر الأوامر (Linux / macOS)

```bash
export JAVA_HOME="$HOME/.jdks/temurin-17"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
cd android-app
./build-apk.sh                       # يبني ويطبع مسار APK وحجمه
# أو يدويًا:
gradle wrapper --gradle-version 8.7
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

### ٣) GitHub Actions (رابط تنزيل مباشر)

الملف `.github/workflows/android-apk.yml` يبني الـ APK على GitHub دون أي إعداد محلي:

1. ارفع المشروع إلى مستودع GitHub؛ سيعمل الـ workflow تلقائيًا عند أي تعديل داخل `android-app/`
   (أو شغّله يدويًا من `Actions ▸ Android APK ▸ Run workflow`).
2. بعد نجاح التشغيل نزّل الملف من أسفل صفحة التشغيل: قسم **Artifacts** ←
   `zaeem-trading-debug-apk.zip` (بداخله `app-debug.apk`).
3. للحصول على **رابط تحميل مباشر ودائم**: أنشئ Release
   (`Releases ▸ Draft a new release ▸ Publish`)، وسيُرفق الـ workflow ملف الـ APK كأصل تنزيل
   برابط مباشر من نوع
   `https://github.com/<user>/<repo>/releases/download/<tag>/app-debug.apk`.

> إن أردت أن يفتح التطبيق عنوانك مباشرة من البداية، ضع `zaeem.siteUrl=https://نطاقك`
> في `android-app/gradle.properties` قبل الرفع؛ سيُبنى داخل الـ APK.

### تثبيت الملف على الهاتف

- فعّل «تثبيت من مصادر غير معروفة» للمتصفح أو مدير الملفات الذي تفتح منه الملف.
- حزمة نسخة التصحيح هي `com.zaeemtrading.app.debug`؛ لتثبيت نسخة موقّعة لاحقًا أزل نسخة
  التصحيح أولًا لأن التوقيع مختلف.
- كل نشر جديد على Google Play يحتاج `versionCode` أكبر.

### عنوان الموقع

إمّا في `gradle.properties` قبل البناء:

```properties
zaeem.siteUrl=https://your-domain.com
```

أو اتركه فارغًا فيعرض التطبيق شاشة إعداد عند أول تشغيل (ويمكن الوصول إليها لاحقًا من
زر الترس أسفل الشاشة). يُطبَّع العنوان إلى `https://host` ويُحفظ في
`SharedPreferences` على الجهاز فقط.

### توقيع نسخة الإصدار

أنشئ keystore ولا ترفعه إلى المستودع، ثم أضف في `app/build.gradle.kts`:

```kotlin
android {
    signingConfigs {
        create("release") {
            storeFile = file("../keystore/zaeem.jks")
            storePassword = System.getenv("ZAeEM_STORE_PASSWORD")
            keyAlias = "zaeem"
            keyPassword = System.getenv("ZAeEM_KEY_PASSWORD")
        }
    }
    buildTypes {
        release { signingConfig = signingConfigs.getByName("release") }
    }
}
```

كل رفع جديد إلى Google Play يحتاج `versionCode` أكبر.

## عقد الجسر

| الدالة | النوع | الوصف |
| --- | --- | --- |
| `isAndroidApp()` | sync | `"true"` للكشف عن التطبيق |
| `appVersion()` | sync | اسم إصدار التطبيق |
| `siteUrl()` | sync | أصل الموقع المُعدّ |
| `getPocketOptionCookie()` | sync | قيمة `ssid` الخام أو `null` |
| `getPocketOptionSession()` | sync | تشخيص JSON: `found`, `cookieNames`, `capturedAt` (بدون قيم) |
| `openPocketOptionLogin()` | void | يفتح شاشة تسجيل الدخول داخل التطبيق |
| `connectSession()` | async | يرسل الجلسة إلى `/api/connect-session` ثم ينادي `window.AndroidBridgeCallback` |

`getPocketOptionCookie()` يبقى متوافقًا مع المعالج الأصلي في
`src/components/account-client.tsx` (اختبار `tests/bridge-smoke.mjs`).

## ضوابط الأمان المطبَّقة

- **النطاق الموثوق فقط:** كل دالة في الجسر تعيد التحقق من أن الصفحة الحالية على نطاق
  الموقع (`isTrustedPage`)؛ لا يُحقن الجسر في صفحات أخرى.
- **لا خروج من النطاق:** الروابط الخارجية تُفتح في المتصفح، ويُمنع تحميل أي نطاق آخر
  داخل الـ WebView (باستثناء `pocketoption.com` لشاشة الدخول).
- **HTTPS فقط:** `usesCleartextTraffic=false` مع استثناء `localhost`/`10.0.2.2` للتطوير.
- **لا تخزين للكوكيز على الجهاز:** لا تُكتب الجلسة في ملفات التطبيق ولا في السجلات؛
  تُقرأ لحظة الضغط وتُرسل عبر HTTPS ثم تبقى في WebView كما يشترط تسجيل الدخول.
- **لا وصول لملفات الجهاز:** `allowFileAccess=false`, `allowContentAccess=false`,
  وتعطيل نوافذ JavaScript المتعددة.
- **الكوكيز من Pocket Option فقط:** لا تُقرأ كوكيز أي نطاق آخر.

## حدود معروفة

- لم يُختبر تسجيل الدخول إلى Pocket Option داخل WebView على جهاز حقيقي في هذه البيئة؛
  قد يحجب مزوّد الدخول (Google/Facebook OAuth) العمل داخل WebView، وعندها يكمل
  المستخدم الدخول بالبريد وكلمة المرور.
- الربط يحفظ الجلسة فقط: لا يوجد محرّك تنفيذ صفقات في هذا المشروع، ولا تُفتح أي صفقة.
- أتمتة الجلسة على منصة طرف ثالث تخضع لشروط استخدام المنصة؛ راجعها قبل التوزيع العام،
  والتزم بأن المستخدم يربط حسابه الشخصي بموافقته.
