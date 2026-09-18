APP_NAME  := BatteryStop
BUNDLE    := dist/$(APP_NAME).app
CONFIG    := release
BUILD_DIR := .build/$(CONFIG)
DMG       := dist/$(APP_NAME).dmg
ICON      := dist/AppIcon.icns
DMG_BG    := dist/dmg-background.png

.PHONY: all build app dmg clean install-local uninstall run

all: dmg

build:
	swift build -c $(CONFIG)

$(ICON): scripts/make-icon/main.swift Sources/BatteryStopCore/BatteryGlyph.swift
	@mkdir -p dist .build
	swiftc -O scripts/make-icon/main.swift Sources/BatteryStopCore/BatteryGlyph.swift -o .build/make-icon
	.build/make-icon $(ICON)

app: build $(ICON)
	@rm -rf $(BUNDLE)
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/BatteryStopApp $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp $(ICON) $(BUNDLE)/Contents/Resources/AppIcon.icns
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" $(BUNDLE)/Contents/Info.plist >/dev/null
	printf 'APPL????' > $(BUNDLE)/Contents/PkgInfo
	codesign --force --deep --sign - --options runtime $(BUNDLE)
	@echo "Собрано: $(BUNDLE)"

$(DMG_BG): scripts/make-dmg-background/main.swift
	@mkdir -p dist .build
	swiftc -O scripts/make-dmg-background/main.swift -o .build/make-dmg-background
	.build/make-dmg-background $(DMG_BG)

dmg: app $(DMG_BG)
	/bin/sh scripts/make-dmg.sh $(BUNDLE) $(DMG_BG) $(DMG)

# Локальная установка без DMG: копирует .app в /Applications и запускает его.
install-local: app
	@rm -rf /Applications/$(APP_NAME).app
	cp -R $(BUNDLE) /Applications/
	open /Applications/$(APP_NAME).app

uninstall:
	-osascript -e 'quit app "$(APP_NAME)"' 2>/dev/null || true
	rm -rf /Applications/$(APP_NAME).app

run: app
	open $(BUNDLE)

clean:
	swift package clean
	rm -rf .build dist
