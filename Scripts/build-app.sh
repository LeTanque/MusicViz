#!/bin/zsh
set -euo pipefail

task_root="${0:A:h:h}"
cd "$task_root"
task_cache="${TMPDIR:-/private/tmp}/musicviz-swift-cache"
mkdir -p "$task_cache/clang" "$task_cache/swift"
CLANG_MODULE_CACHE_PATH="$task_cache/clang" SWIFT_MODULECACHE_PATH="$task_cache/swift" swift build -c release

app_path="$task_root/build/MusicViz.app"
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$task_root/Resources/Info.plist" "$app_path/Contents/Info.plist"
cp "$task_root/.build/release/MusicViz" "$app_path/Contents/MacOS/MusicViz"
codesign --force --sign - --timestamp=none "$app_path"
echo "$app_path"
