# BatteryStop

Программа для macOS, которая ограничивает максимальный заряд батареи MacBook.
Живёт в строке меню, без окна и без иконки в Dock.

## Что умеет

- текущее состояние батареи и лимита;
- **Ограничивать заряд (80%)** — включить/выключить лимит;

Режима два: заряжать не выше 80% или заряжать без ограничения.

## Сборка

Нужны Command Line Tools (Xcode не требуется):

```sh
make dmg          # dist/BatteryStop.dmg
make app          # только dist/BatteryStop.app
make install-local # собрать, положить в /Applications и запустить
```

## Установка

Открыть `dist/BatteryStop.dmg` и перетащить `BatteryStop.app` в `Applications`.

Приложение подписано ad-hoc (без сертификата разработчика), поэтому при первом
запуске macOS может попросить подтверждение в «Конфиденциальность и безопасность».

Автозапуск включается в настройках программы.

## Удаление

```sh
make uninstall
```

или просто перетащить `BatteryStop.app` в корзину. Лимит заряда при этом останется
таким, каким его выставили: снять его можно в самой программе или в системных
настройках аккумулятора.

## Ограничения

- Только Apple Silicon с macOS, где есть встроенный лимит заряда (проверено на
  MacBook Air M4, macOS 27.0).
- Используется приватный системный фреймворк — Apple может изменить его в будущих
  версиях macOS, и такую программу нельзя опубликовать в Mac App Store.
- Пороги ниже 80% недоступны: это ограничение macOS, а не программы.

## Структура

```
Sources/BatteryStopCore/   Battery.swift      — чтение заряда через IOKit
                           ChargeLimit.swift  — обёртка над PowerUI (лимит заряда)
                           BatteryGlyph.swift — рисунок «батарея + знак запрета»
Sources/BatteryStopApp/    main.swift, AppDelegate.swift (строка меню),
                           AppModel.swift, SettingsWindowController.swift
scripts/make-icon/         генератор AppIcon.icns из того же рисунка
Makefile                   сборка .app и .dmg
```
