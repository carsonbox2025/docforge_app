#!/usr/bin/env bash
set -euo pipefail

FLAVORS=(official xiaomi huawei vivo oppo honor)
APK_OUT="build/app/outputs/flutter-apk"
DL_DIR="$(cd "$(dirname "$0")/../.." && pwd)/AIStudio/apps/service/data/docforge/downloads"

echo "=== DocForge Release Builder ==="
echo "Flavors: ${FLAVORS[*]}"
echo ""

success=()
failed=()

for flavor in "${FLAVORS[@]}"; do
  echo ">>> Building $flavor ..."
  if flutter build apk --release --flavor "$flavor" --dart-define=CHANNEL="$flavor"; then
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
