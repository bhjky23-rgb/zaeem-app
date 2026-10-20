#!/usr/bin/env bash
# Builds an installable APK for the Zaeem Trading Android wrapper.
# Works locally and in CI (Gradle wrapper is optional).
set -euo pipefail

cd "$(dirname "$0")"

if [[ -z "${JAVA_HOME:-}" ]]; then
  echo "JAVA_HOME غير مضبوط. ثبّت JDK 17 واضبطه، مثال:"
  echo "  export JAVA_HOME=\"\$HOME/.jdks/temurin-17\""
  exit 1
fi

if [[ ! -f local.properties ]]; then
  if [[ -z "${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}" ]]; then
    echo "لم أجد Android SDK. اضبط ANDROID_SDK_ROOT أو أنشئ local.properties:"
    echo "  sdk.dir=/path/to/Android/Sdk"
    exit 1
  fi
  echo "sdk.dir=${ANDROID_SDK_ROOT:-$ANDROID_HOME}" > local.properties
fi

GRADLE_CMD="gradle"
if [[ -x ./gradlew ]]; then GRADLE_CMD="./gradlew"; fi

echo "==> بناء APK (${GRADLE_CMD} assembleDebug)"
$GRADLE_CMD --no-daemon assembleDebug

APK=$(find app/build/outputs/apk/debug -name '*.apk' | head -1)
if [[ -z "$APK" ]]; then
  echo "لم يتم إنتاج أي ملف APK. راجع مخرجات البناء أعلاه."
  exit 1
fi

echo
echo "تم إنشاء الملف: $APK"
echo "الحجم: $(du -h "$APK" | cut -f1)"
echo "للتثبيت على جهاز موصول: adb install -r \"$APK\""
