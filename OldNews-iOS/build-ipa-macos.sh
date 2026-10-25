#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "错误：生成并签名 iOS IPA 需要 macOS + Xcode。当前系统不是 macOS。" >&2
  exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "错误：未找到 xcodebuild，请先安装 Xcode 27 并完成首次启动。" >&2
  exit 1
fi
if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
  echo "错误：请先设置 APPLE_TEAM_ID。" >&2
  exit 1
fi

mkdir -p build
sed "s/__TEAM_ID__/${APPLE_TEAM_ID}/g" Docs/ExportOptions.plist.template > build/ExportOptions.plist
SIGN_ARGS=(-allowProvisioningUpdates "DEVELOPMENT_TEAM=${APPLE_TEAM_ID}")

xcodebuild \
  -project OldNews.xcodeproj \
  -scheme OldNews \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$PWD/build/OldNews.xcarchive" \
  "${SIGN_ARGS[@]}" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$PWD/build/OldNews.xcarchive" \
  -exportPath "$PWD/build/ipa" \
  -exportOptionsPlist "$PWD/build/ExportOptions.plist" \
  -allowProvisioningUpdates

echo "完成。请检查 build/ipa/ 目录中的 IPA，并先在测试设备上验证。"
