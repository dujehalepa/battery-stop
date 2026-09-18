#!/bin/sh
# Собирает DMG с оформленным окном: фон, иконка программы и ярлык Applications.
# Использование: make-dmg.sh <BatteryStop.app> <фон.png> <выходной.dmg>
set -e

APP="$1"
BACKGROUND="$2"
OUTPUT="$3"

VOLUME_NAME="BatteryStop"
APP_NAME=$(basename "$APP")
WORK_DIR=$(dirname "$OUTPUT")
STAGING="$WORK_DIR/dmgroot"
TEMP_DMG="$WORK_DIR/BatteryStop-rw.dmg"

rm -rf "$STAGING" "$TEMP_DMG" "$OUTPUT"
mkdir -p "$STAGING/.background"

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cp "$BACKGROUND" "$STAGING/.background/background.png"
# Двойное разрешение фона: 144 dpi дают 600×400 точек на экране.
sips -s dpiWidth 144 -s dpiHeight 144 "$STAGING/.background/background.png" >/dev/null

hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING" -ov \
    -format UDRW -fs HFS+ "$TEMP_DMG" >/dev/null

MOUNT_POINT=$(hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen \
    | grep '/Volumes/' | sed 's|.*\(/Volumes/.*\)|\1|')
# Если том с таким именем уже смонтирован, система добавляет суффикс («BatteryStop 1»),
# поэтому Finder'у передаём имя точки монтирования, а не имя тома.
DISK_NAME=$(basename "$MOUNT_POINT")

# Раскладку окна Finder хранит в .DS_Store тома, поэтому расставляем всё скриптом.
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$DISK_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {240, 130, 840, 530}
        set options to the icon view options of container window
        set arrangement of options to not arranged
        set icon size of options to 112
        set text size of options to 12
        set background picture of options to file ".background:background.png"
        set position of item "$APP_NAME" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# Иконку тома ставим после Finder: во время настройки окна он удаляет этот файл.
if [ -f "$WORK_DIR/AppIcon.icns" ]; then
    cp "$WORK_DIR/AppIcon.icns" "$MOUNT_POINT/.VolumeIcon.icns"
    SetFile -a C "$MOUNT_POINT"
fi

sync
hdiutil detach "$MOUNT_POINT" >/dev/null

hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT" >/dev/null
rm -f "$TEMP_DMG"
rm -rf "$STAGING"

echo "Готов образ: $OUTPUT"
