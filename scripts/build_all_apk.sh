#!/usr/bin/env bash
set -euo pipefail

FLAVORS=(official xiaomi huawei vivo oppo honor)
APK_OUT="build/app/outputs/flutter-apk"
DL_DIR="$(cd "$(dirname "$0")/../.." && pwd)/AIStudio/apps/service/data/docforge/downloads"

echo "=== DocForge Release Builder ==="
echo "Flavors: ${FLAVORS[*]}"
echo ""

# ─── 签名准备 ───
KEYSTORE_FILE="android/app/build/docforge-release.jks"
if [ -f "$KEYSTORE_FILE" ]; then
  echo "[签名] release keystore 已就绪，将使用正式签名"
  if [ -z "${ANDROID_KEYSTORE_PASSWORD:-}" ]; then
    echo "[签名] 警告: ANDROID_KEYSTORE_PASSWORD 未设置"
  fi
else
  echo "[签名] 未找到 $KEYSTORE_FILE，将降级 debug 签名（华为走沙箱）"
fi

# 生产 API 地址（可通过 export API_HOST=... 覆盖）
API_HOST="${API_HOST:-http://61.132.52.22:8084}"
echo "[API] $API_HOST"
echo ""

success=()
failed=()

for flavor in "${FLAVORS[@]}"; do
  echo ">>> Building $flavor ..."
  if flutter build apk --release --flavor "$flavor" --dart-define=CHANNEL="$flavor" --dart-define=API_HOST="$API_HOST"; then
    success+=("$flavor")
    echo ">>> $flavor OK"
  else
    failed+=("$flavor")
    echo ">>> $flavor FAILED"
  fi
  echo ""
done

echo "=== Results ==="
echo "Success: ${success[*]:-none}"
echo "Failed:  ${failed[*]:-none}"

if [ ${#failed[@]} -gt 0 ]; then
  exit 1
fi

# 复制 APK 到下载目录
echo ""
echo "=== Copying APKs to download dir ==="
mkdir -p "$DL_DIR"
cp -v "$APK_OUT"/*.apk "$DL_DIR/"
echo "Done. Files in $DL_DIR:"
ls -lh "$DL_DIR"/*.apk
