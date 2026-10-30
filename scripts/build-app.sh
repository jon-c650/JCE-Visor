#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
destination="${1:-$project_dir/outputs}"
build_dir="${VISOR_BUILD_DIR:-$project_dir/.build}"
app_dir="$destination/Visor.app"

mkdir -p "$build_dir/module-cache" "$destination"
SWIFTPM_MODULECACHE_OVERRIDE="$build_dir/module-cache" \
CLANG_MODULE_CACHE_PATH="$build_dir/module-cache" \
swift build --disable-sandbox -c release -debug-info-format none --package-path "$project_dir" --scratch-path "$build_dir"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$build_dir/release/Visor" "$app_dir/Contents/MacOS/Visor"
cp -R "$build_dir/release/Visor_Visor.bundle" "$app_dir/Contents/Resources/Visor_Visor.bundle"
cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
cp "$project_dir/Resources/Assets.car" "$app_dir/Contents/Resources/Assets.car"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
xattr -cr "$app_dir"
codesign --force --deep --sign - "$app_dir"

echo "$app_dir"
