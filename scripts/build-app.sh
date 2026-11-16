#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
app_dir="$project_root/dist/Camera RAW Studio.app"

cd "$project_root"
swift build -c release

mkdir -p "$app_dir/Contents/MacOS"
mkdir -p "$app_dir/Contents/Resources"
cp ".build/release/CameraImageWorker" "$app_dir/Contents/MacOS/CameraImageWorker"
cp "Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
rm -rf "$app_dir/Contents/Resources/"*.lproj
for localization_dir in Resources/*.lproj; do
    cp -R "$localization_dir" "$app_dir/Contents/Resources/"
done
rm -rf "$app_dir/Contents/Resources/RestormerRealDenoising.mlmodelc"
cp -R "Resources/Models/RestormerRealDenoising.mlmodelc" "$app_dir/Contents/Resources/"
cp "Resources/Restormer-LICENSE.txt" "$app_dir/Contents/Resources/"
codesign --force --sign - "$app_dir"

print -r -- "$app_dir"
