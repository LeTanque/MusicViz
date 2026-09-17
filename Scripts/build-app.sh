#!/bin/zsh
set -euo pipefail

task_root="${0:A:h:h}"
cd "$task_root"
task_cache="${TMPDIR:-/private/tmp}/musicviz-swift-cache"
mkdir -p "$task_cache/clang" "$task_cache/swift"
git submodule update --init --recursive
cmake -S Vendor/projectm -B .projectm-build \
  -DBUILD_SHARED_LIBS=ON \
  -DENABLE_PLAYLIST=OFF \
  -DENABLE_SDL_UI=OFF \
  -DENABLE_INSTALL=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.2 \
  -DCMAKE_INSTALL_PREFIX="$task_root/.projectm-install"
cmake --build .projectm-build --parallel 4
cmake --install .projectm-build
ditto "$task_root/.projectm-install/include/projectM-4" "$task_root/Sources/CProjectM/include/projectM-4"
CLANG_MODULE_CACHE_PATH="$task_cache/clang" SWIFT_MODULECACHE_PATH="$task_cache/swift" swift build -c release

app_path="$task_root/build/MusicViz.app"
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$app_path/Contents/Frameworks"
cp "$task_root/Resources/Info.plist" "$app_path/Contents/Info.plist"
cp "$task_root/Resources/AppIcon.icns" "$app_path/Contents/Resources/AppIcon.icns"
cp "$task_root/.build/release/MusicViz" "$app_path/Contents/MacOS/MusicViz"
cp -R "$task_root/.projectm-install/lib/"libprojectM-4*.dylib "$app_path/Contents/Frameworks/"
mkdir -p "$app_path/Contents/Resources/MilkDrop/Presets" "$app_path/Contents/Resources/MilkDrop/Textures"
cp -R "$task_root/Vendor/presets-milkdrop-original/Milkdrop-Original/." "$app_path/Contents/Resources/MilkDrop/Presets/"
cp -R "$task_root/Vendor/presets-milkdrop-textures/textures/." "$app_path/Contents/Resources/MilkDrop/Textures/"
# Upstream asset checkouts can carry Finder metadata, which codesign rejects.
xattr -cr "$app_path"
xattr -dr com.apple.provenance "$app_path" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$app_path" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$app_path" 2>/dev/null || true
codesign --force --sign - --timestamp=none "$app_path"
codesign --verify --deep --strict "$app_path"
echo "$app_path"
