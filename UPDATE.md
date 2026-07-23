# Niri Hub Update Plan

## Цель

Обновить текущий профиль Quickshell `minimal` до **Niri Hub**: единого
GNOME-like launcher и command center для Niri. Интерфейс должен объединить
запуск приложений, clipboard, Wi-Fi, Bluetooth, батарею и действия питания в
одном всплывающем окне без резервирования места на экране.

Обновление является переработкой существующего launcher, а не реализацией с
нуля. Текущий проект уже поддерживает Desktop Entries, clipboard, Networking,
Bluetooth, UPower и power actions. Основная задача состоит в разделении
монолитного `Launcher.qml`, обновлении визуального языка и синхронизации всех
точек интеграции.

## Принятые решения

- Название интерфейса: **Niri Hub**.
- Имя профиля Quickshell: `niri-hub`.
- Launcher остаётся на `Mod+D`.
- `Mod+Space` продолжает выполнять `toggle-window-floating`.
- Первая поставка включает Apps, Clipboard, Wi-Fi, Bluetooth, Battery и Power.
- Quickshell продолжает запускаться через systemd, а не через Niri
  `spawn-at-startup`.
- System monitor, shortcut overlay, keyboard layout OSD, Bluetooth agent и
  Polkit agent сохраняются.
- Целевая версия API: Quickshell 0.3.0.
- Material Symbols заменяются системными symbolic icons из Adwaita icon theme.
- Светлая тема, pinned applications, частота запуска, calculator и полноценная
  локализация остаются последующими этапами.

## Ограничения текущего плана

- `cliphist` не предоставляет надёжные timestamp и pin metadata. Закрепление и
  время добавления потребуют собственного хранилища и не входят в первую
  поставку.
- Image entries можно определить и вернуть в clipboard, но генерацию thumbnail
  следует добавлять отдельно после проверки безопасной работы с временными
  файлами.
- Полноценный GNOME Overview с окнами и workspace thumbnails не входит в scope.
  Название Niri Hub не должно создавать ожидание реализации обзора окон.
- Отдельный QML-файл для каждой простой кнопки верхней строки не нужен. Файлы
  выделяются по ответственности и повторному использованию.
- Отдельный `NavigationState` не требуется до появления реального стека
  вложенных страниц. Навигация первой версии хранится в `LauncherState`.
- Тонкие обёртки над реактивными singleton API `Networking`, `Bluetooth` и
  `UPower` не создаются без дополнительной бизнес-логики.

## Целевая структура

```text
shared/stow/quickshell/.config/quickshell/niri-hub/
├── shell.qml
├── qmldir
├── ModalWindow.qml
├── LauncherState.qml
├── ShellSettings.qml
├── Theme.qml
│
├── launcher/
│   ├── Launcher.qml
│   ├── SystemHeader.qml
│   ├── SearchField.qml
│   ├── InlineConfirmation.qml
│   ├── SectionHeader.qml
│   ├── EmptyState.qml
│   ├── pages/
│   │   ├── AppsPage.qml
│   │   ├── ClipboardPage.qml
│   │   ├── WifiPage.qml
│   │   ├── BluetoothPage.qml
│   │   └── BatteryPage.qml
│   └── delegates/
│       ├── ApplicationDelegate.qml
│       ├── ClipboardDelegate.qml
│       ├── WifiNetworkDelegate.qml
│       └── BluetoothDeviceDelegate.qml
│
├── services/
│   ├── ApplicationService.qml
│   ├── ClipboardService.qml
│   └── PowerService.qml
│
├── BluetoothAgent.qml
├── LayoutOsd.qml
├── MetricsService.qml
├── MonitorLayer.qml
├── PolkitWindow.qml
├── ShortcutOverlay.qml
├── SystemMonitorDashboard.qml
├── SystemMonitorWidget.qml
└── controls/
    ├── ShellButton.qml
    ├── ShellIcon.qml
    ├── ShellSlider.qml
    ├── ShellTextField.qml
    ├── ShellToggle.qml
    └── Keycap.qml
```

Структуру допускается упрощать во время реализации, если небольшой компонент
используется только один раз и его выделение не уменьшает сложность родителя.

## Переименование профиля

1. Переименовать каталог
   `shared/stow/quickshell/.config/quickshell/minimal` в `niri-hub`.
2. Изменить имя QML-модуля в `qmldir` с `minimal` на `niri-hub` либо выбрать
   допустимый QML URI без дефиса, например `NiriHub`, сохранив имя профиля
   `niri-hub`.
3. Заменить все вызовы `qs -c minimal` на `qs -c niri-hub`.
4. Обновить D-Bus path Polkit agent с `MinimalShell` на `NiriHub`.
5. Перенести runtime settings в `niri-hub/settings.json`.
6. Выполнить одноразовую миграцию из `minimal-shell/settings.json`, если новый
   файл ещё не существует. Сохранить accent, interface scale, reduced motion и
   настройки monitor.
7. Повысить версию схемы `ShellSettings`.

## Bootstrap и состояние

### `shell.qml`

Оставить файл точкой сборки верхнего уровня. Он должен:

- создавать singleton-сервисы и persistent agents;
- хранить текущую modal surface и focused output;
- создавать окна через `Variants` для `Quickshell.screens`;
- обрабатывать Niri event stream и keyboard layout state;
- маршрутизировать IPC;
- передавать launcher начальную страницу;
- не содержать scoring приложений, clipboard decode и power business logic.

Сохранить существующие IPC targets `monitor` и `shortcuts`. Для `launcher`
добавить методы:

```text
toggle
apps
clipboard
wifi
bluetooth
battery
```

Открытие конкретной страницы должно сначала определить focused output, затем
показать modal и передать страницу в `LauncherState`.

### `LauncherState.qml`

Добавить singleton состояния launcher:

```qml
property string page: "apps"
property string query: ""
property int selectedIndex: 0
property string pendingPowerAction: ""
property bool keyboardNavigation: false
```

Допустимые страницы первой версии:

```text
apps
clipboard
wifi
bluetooth
battery
```

При закрытии launcher необходимо сбрасывать transient state: query,
selection, pending confirmation, Wi-Fi password prompt и status messages.

## Окно launcher

Сохранить существующую полноэкранную `PanelWindow`-оболочку, поскольку она уже
обеспечивает scrim, focus, закрытие по клику снаружи и работу на focused output.

Требования:

- `exclusiveZone: 0`;
- окно не резервирует место;
- слой должен находиться поверх обычных окон;
- launcher показывается только на focused output;
- внутренняя поверхность располагается по горизонтальному центру;
- верхний отступ составляет 80–120 px;
- ширина ограничена диапазоном 640–920 px, целевое значение 800 px;
- высота ограничена доступной геометрией, целевое значение 600 px;
- клик по scrim закрывает modal;
- клик внутри launcher не должен распространяться на scrim;
- search field получает focus после открытия и смены страницы;
- открытие и закрытие используют opacity, scale и небольшой vertical offset;
- animations отключаются при `ShellSettings.reduceMotion`.

Не следует заменять оболочку на `PopupWindow` без необходимости: PopupWindow
требует anchor window, тогда как текущая per-screen PanelWindow уже решает
позиционирование и focus routing.

## Компоненты launcher

### `launcher/Launcher.qml`

Превратить текущий файл в контроллер и host страниц. В нём должны остаться:

- компоновка окна;
- `SystemHeader`;
- `SearchField`;
- loader текущей страницы;
- общая keyboard routing;
- inline power confirmation;
- Bluetooth pairing prompt routing.

Wi-Fi, Bluetooth, application filtering и clipboard process logic необходимо
вынести из этого файла.

### `launcher/SystemHeader.qml`

Структура header:

```text
[ Дата ][ Время ]    [ Wi-Fi ][ Bluetooth ][ Battery ] | [ Sleep ][ Reboot ][ Power ]
```

Требования:

- дата и время форматируются через Qt locale-aware API;
- точность `SystemClock.Minutes`;
- status buttons открывают соответствующие страницы;
- активная страница выделяется мягким accent background;
- battery button полностью скрывается без laptop battery;
- destructive color не используется постоянно;
- reboot и shutdown открывают inline confirmation;
- suspend выполняется сразу;
- все icon-only buttons имеют tooltip и `Accessible.name`.

### `launcher/SearchField.qml`

Структура:

```text
[ search icon ][ query / placeholder ][ clear ][ clipboard ]
```

Placeholder зависит от страницы:

```text
Apps       Search applications and commands…
Clipboard  Search clipboard history…
Wi-Fi      Search networks…
Bluetooth  Search devices…
Battery    Search отсутствует
```

Для сохранения существующей функции запуска команд использовать явный prefix
`>` в Apps page. Строка `> command` выполняется только после Enter и должна
показывать предупреждение о запуске через `/bin/sh`.

### `launcher/InlineConfirmation.qml`

Компонент используется для reboot и shutdown:

- не создаёт отдельное окно;
- блокирует активацию результатов;
- получает keyboard focus при открытии;
- Escape и Cancel отменяют действие;
- Enter на destructive button подтверждает действие;
- текст предупреждает о возможной потере несохранённых данных.

## Страницы

### Apps

- Использовать `DesktopEntries.applications`.
- Перенести существующий scoring в `ApplicationService`.
- Искать по name, generic name, comment, ID и keywords.
- Сортировать по score, затем по locale-aware application name.
- Выполнять `.desktop` entries через `DesktopEntry.execute()`.
- Для terminal entries сохранять запуск через Kitty с parsed command list.
- Не использовать raw `Exec` как shell command.
- Показывать icon, name и generic name или comment.
- Поддерживать Up, Down, Home, End и Enter.
- Часто используемые и pinned applications отложить до следующего этапа.

### Clipboard

- Загружать данные через `cliphist list` при открытии страницы.
- Разделять numeric cliphist ID и preview, не передавать всю строку как
  произвольную shell-команду.
- Возвращать запись через `cliphist decode` и `wl-copy`.
- После выбора закрывать launcher.
- Добавить refresh и delete.
- Показывать text preview и отдельное состояние для binary/image content.
- Не обещать timestamp и pin до появления собственного metadata storage.
- Не запускать `wl-paste --watch` из QML.

### Wi-Fi

- Использовать `Quickshell.Networking`, а не parsing `nmcli`.
- Выбирать Wi-Fi device из `Networking.devices`.
- Показывать hardware/software enabled state.
- Сортировать сети: connected, signal strength, name.
- Показывать security и signal strength.
- Поддерживать connect, disconnect и saved networks.
- Сохранить WPA/WPA2/SAE PSK prompt.
- Показывать понятную ошибку для неподдерживаемого security type.
- Включать `scannerEnabled` только пока открыта Wi-Fi page.
- `Ctrl+R` инициирует обновление списка или connectivity check.

### Bluetooth

- Использовать `Quickshell.Bluetooth`.
- Сохранить существующий `BluetoothAgent` и parser `bluetoothctl` prompts.
- Не запускать второй pairing agent.
- Сортировать устройства: connected, paired, name.
- Поддерживать pair, connect и disconnect.
- Показывать device battery, когда `batteryAvailable`.
- Включать discovery только пока открыта Bluetooth page.
- Сохранить routing pairing prompt в launcher.

### Battery

- Использовать `Quickshell.Services.UPower`.
- Не показывать кнопку и страницу на устройствах без laptop battery.
- Показывать percentage, charging/discharging state, time to empty/full и
  health/capacity, если свойства доступны в Quickshell 0.3.0.
- Добавить power profile только при наличии Power Profiles Daemon.
- Не падать и не показывать фиктивные значения, если UPower ещё не
  инициализирован.

## Keyboard navigation

Обязательные сочетания внутри launcher:

| Shortcut | Действие |
| --- | --- |
| `Escape` | Назад, очистить или закрыть |
| `Enter` | Активировать выбранный элемент |
| `Up` / `Down` | Изменить выбранный элемент |
| `Home` / `End` | Первый или последний результат |
| `Tab` | Перемещаться между header actions и content |
| `Ctrl+V` | Открыть Clipboard |
| `Ctrl+W` | Открыть Wi-Fi |
| `Ctrl+B` | Открыть Bluetooth |
| `Ctrl+L` | Вернуть focus строке поиска |
| `Ctrl+R` | Обновить текущую страницу |

Порядок обработки Escape:

1. Отменить power confirmation.
2. Отменить активный Bluetooth prompt.
3. Закрыть Wi-Fi password prompt.
4. Вернуться с системной страницы в Apps.
5. Очистить непустой query.
6. Закрыть launcher.

Для сложных областей использовать `FocusScope`, `KeyNavigation` и явный Tab
order. Все custom controls должны иметь видимый focus indicator.

## Theme и визуальный язык

### Цвета

Заменить текущую синюю palette на семантические Adwaita-like tokens:

```text
windowBackground
elevatedBackground
secondaryBackground
textPrimary
textSecondary
textDisabled
accent
accentHover
accentPressed
success
warning
destructive
border
hover
selected
scrim
```

Компоненты не должны содержать raw color literals. Первая поставка использует
тёмную тему; токены должны позволять добавить светлую тему без изменения
компонентов.

### Метрики

```text
base spacing:       4 px
window radius:     18 px
large radius:      14 px
medium radius:     10 px
small radius:       6 px
header height:     52 px
search height:     48 px
row height:     52–60 px
icon sizes:     16/20/24 px
```

Все значения масштабируются через `ShellSettings.interfaceScale`. Не смешивать
`anchors` и `Layout.*` на одном item. Элементы внутри Qt Quick Layouts должны
задавать размеры через `Layout.*`.

### Типографика

- Основной шрифт: Cantarell.
- Fallback: Noto Sans или platform sans-serif.
- Mono font: Noto Sans Mono.
- Использовать не более четырёх активных размеров на одном экране.
- Проверить интерфейс с увеличенным системным размером текста.
- Date/time formatting должно учитывать locale.

### Иконки

Добавить в `shell.qml`:

```qml
//@ pragma IconTheme Adwaita
```

Переписать `ShellIcon` на `IconImage` и `Quickshell.iconPath()`. Для каждой
иконки указывать основной symbolic name и fallback. Перевести launcher, Polkit
и остальные использующие `ShellIcon` компоненты до удаления Material Symbols.

Минимальный набор:

```text
system-search-symbolic
edit-paste-symbolic
network-wireless-symbolic
network-wireless-disabled-symbolic
bluetooth-active-symbolic
bluetooth-disabled-symbolic
battery-level-*-symbolic
system-suspend-symbolic
system-reboot-symbolic
system-shutdown-symbolic
application-x-executable-symbolic
image-missing-symbolic
```

## Motion и rendering

Использовать длительности:

```text
hover:             100 ms
selection:         120 ms
page transition:   160–180 ms
open:              180–220 ms
close:             140–180 ms
confirmation:      160 ms
```

Требования:

- анимировать преимущественно opacity и transform;
- использовать Animator types для opacity, scale, x и y, где возможно;
- не анимировать width и height сложных subtrees;
- не добавлять blur отдельных элементов;
- не применять opacity ко всему сложному content tree без необходимости;
- отключать animation при reduced motion;
- не использовать bounce, rotation и сильный zoom;
- загружать тяжёлые необязательные страницы через `Loader`;
- уничтожать неиспользуемые optional components через `Loader.active: false`.

## Accessibility и локализация

- Обернуть все пользовательские строки в `qsTr()`.
- Использовать `%1` placeholders вместо string concatenation.
- Добавить `Accessible.role` и `Accessible.name` custom controls.
- Decorative icons помечать `Accessible.ignored: true`.
- Обеспечить contrast не ниже 4.5:1 для обычного текста и 3:1 для controls.
- Не использовать только цвет для connected, warning и error states.
- Проверить полный сценарий без мыши.
- Оставить место для расширения переведённых строк на 30–40%.
- В перспективе включить `LayoutMirroring` для RTL, но не блокировать первую
  поставку отсутствием переводов.

## Niri integration

Изменить `shared/stow/niri/.config/niri/config.kdl`:

- заменить профиль `minimal` на `niri-hub` во всех IPC commands;
- оставить `Mod+D` для `launcher toggle`;
- оставить `Mod+Space` для `toggle-window-floating`;
- добавить `Mod+V` для `launcher clipboard`, если сочетание не конфликтует;
- обновить `hotkey-overlay-title`;
- сохранить monitor и shortcuts bindings;
- не добавлять `spawn-at-startup "qs"`.

Предлагаемые команды:

```text
Mod+D  -> qs -c niri-hub ipc call launcher toggle
Mod+V  -> qs -c niri-hub ipc call launcher clipboard
```

## systemd и clipboard recorder

### Arch

Обновить
`shared/stow/systemd/.config/systemd/user/quickshell.service`:

```ini
ExecStart=/usr/bin/qs -c niri-hub
```

Добавить отсутствующий declarative
`shared/stow/systemd/.config/systemd/user/cliphist.service` с запуском:

```text
wl-paste --watch cliphist store
```

Service должен быть привязан к `graphical-session.target`, перезапускаться при
ошибке и запускаться только один раз на пользовательскую сессию. Не создавать
отдельные recorder processes при каждом открытии launcher.

Обновить `arch/install.sh`, чтобы clean Arch deployment всегда находил и
включал repository-managed `cliphist.service`, а не зависел от внешнего unit.

### NixOS/Home Manager

Обновить `nixos/modules/home.nix`:

- `ExecStart` Quickshell на `qs -c niri-hub`;
- mapping с `quickshell/minimal` на `quickshell/niri-hub`;
- сохранить declarative `cliphist` user service;
- добавить новые runtime packages;
- удалить Material Symbols после полной миграции иконок.

## Пакеты

Синхронно обновить `arch/packages/niri.txt`, `arch/packages/common.txt` и
`nixos/modules/home.nix`.

Добавить или проверить:

```text
quickshell
qt6-declarative
qt6-svg
networkmanager
bluez
bluez-utils
upower
wl-clipboard
cliphist
cantarell-fonts
adwaita-icon-theme
power-profiles-daemon (optional)
```

Для NixOS использовать соответствующие атрибуты `qt6Packages.qtsvg`, Cantarell
и Power Profiles Daemon. Если battery page управляет power profile, включить
`services.power-profiles-daemon.enable = true` в desktop module.

Удалить `ttf-material-symbols-variable` и `material-symbols` только после того,
как ни один QML-компонент не использует Material Symbols font glyphs.

GTK font следует менять на Cantarell только согласованно во всех местах:

- Niri startup `gsettings`;
- Home Manager `dconf.settings`;
- GTK 3/4 settings под `shared/stow/gtk`.

## Существующие компоненты вне launcher

Следующие возможности не должны регрессировать:

- persistent system monitor widget;
- full system monitor dashboard;
- process termination confirmation;
- keyboard shortcut overlay;
- keyboard layout OSD;
- focused-output routing;
- Niri event stream restart;
- Polkit authentication agent;
- Bluetooth pairing prompt;
- monitor position and click-through persistence.

Перемещение файлов в подкаталоги не является обязательным, если оно увеличивает
объём миграции без улучшения разделения ответственности.

## Проверки

### `scripts/check.sh`

Обновить проверки:

- искать QML recursively, а не только `minimal/*.qml`;
- использовать путь `niri-hub`;
- проверять launcher IPC methods;
- сохранять проверки monitor, shortcuts, event stream, OSD и Polkit;
- заменить требование Material Symbols на проверку Adwaita icon theme и
  `IconImage`;
- проверять `Quickshell.Networking`, Bluetooth и UPower в новых файлах;
- проверять оба user services;
- проверять отсутствие Niri `spawn-at-startup "qs"`;
- проверять новые Niri bindings;
- проверять Home Manager mapping и `ExecStart`;
- проверять отсутствие оставшихся `minimal` profile references, кроме кода
  миграции старого state path и migration documentation.

`qmllint` должен получать все QML-файлы из вложенных каталогов и корректные
import paths.

### Ручная проверка

Проверить:

1. `qs -c niri-hub` запускается без QML warnings и binding loops.
2. `Mod+D` открывает и закрывает launcher на focused output.
3. Search field всегда получает focus.
4. Приложения запускаются с корректными `.desktop` arguments.
5. Prefix `>` запускает команду только после Enter.
6. Clipboard copy, delete и refresh работают для text и image entries.
7. Wi-Fi scan, connect, password prompt и disconnect работают без restart.
8. Bluetooth discovery, pairing, connect и disconnect работают без restart.
9. Battery скрыта на desktop и корректна на laptop.
10. Suspend выполняется сразу; reboot и shutdown требуют confirmation.
11. Escape соблюдает установленный порядок приоритетов.
12. Monitor, dashboard, shortcuts, OSD, Polkit и pairing prompt не сломаны.
13. Launcher появляется на правильном output после смены focus.
14. Масштабы 1×, 1.25×, 1.5× и 2× не вызывают clipping.
15. Интерфейс полностью управляется клавиатурой.
16. Отсутствие NetworkManager, BlueZ или UPower отображается как empty state, а
    не приводит к QML exception.

### Команды проверки

```sh
./scripts/check.sh
niri validate --config "$HOME/.config/niri/config.kdl"
qs -c niri-hub
qs -c niri-hub ipc call launcher toggle
qs -c niri-hub ipc call launcher clipboard
```

Для NixOS до activation:

```sh
nix flake check "path:$PWD"
sudo nixos-rebuild build --flake "path:$PWD#<host>"
sudo nixos-rebuild test --flake "path:$PWD#<host>"
```

Не повышать `system.stateVersion` и `home.stateVersion` в рамках обновления UI.

## Документация

Обновить `README.md`:

- managed path `~/.config/quickshell/niri-hub`;
- новое название и описание launcher;
- сочетания `Mod+D` и `Mod+V`;
- системные страницы;
- список systemd user services;
- команды удаления и восстановления.

Обновить `docs/migration-existing-desktop.md`:

- новый profile path;
- сценарии проверки launcher pages;
- проверку clipboard recorder;
- предупреждение о сохранении старого runtime state;
- rollback profile and services.

## Этапы реализации

### Этап 1: безопасное переименование

- Переименовать профиль и QML module.
- Обновить systemd, Niri, Home Manager, checks и documentation paths.
- Добавить migration settings.
- Убедиться, что существующая функциональность работает без визуальных
  изменений.

### Этап 2: архитектурное разделение

- Добавить `LauncherState`.
- Выделить application, clipboard и power services.
- Разделить launcher на header, search, pages и delegates.
- Сохранить существующее поведение до redesign.

### Этап 3: GNOME-like redesign

- Добавить семантическую тёмную palette.
- Перейти на Cantarell и Adwaita symbolic icons.
- Изменить размер, верхнее позиционирование, spacing, radius и focus states.
- Добавить короткие reduced-motion-aware animations.

### Этап 4: системная версия

- Завершить Apps, Clipboard, Wi-Fi, Bluetooth и Battery pages.
- Добавить inline power confirmation.
- Добавить IPC для прямого открытия страниц.
- Добавить `Mod+V` и Arch clipboard service.

### Этап 5: проверка и полировка

- Выполнить repository checks и Nix evaluation.
- Проверить keyboard-only workflow, multi-monitor и scaling.
- Проверить error и unavailable-service states.
- Обновить README и migration runbook.

### Последующие этапы

- light theme и автоматическое переключение;
- pinned и frequently used applications;
- fuzzy search;
- calculator provider;
- безопасные command providers вместо общего shell mode;
- clipboard metadata, pin и expiration;
- calendar page;
- settings UI;
- локализация и RTL;
- дополнительная accessibility validation.

## Критерии готовности

Обновление считается завершённым, когда:

- профиль называется `niri-hub` во всех runtime и deployment integrations;
- launcher открывается на focused output без заметной задержки;
- search field всегда получает focus;
- всё основное управление доступно с клавиатуры;
- окно не резервирует место;
- приложения запускаются через корректно разобранные Desktop Entries;
- clipboard recorder запускается один раз через systemd;
- Wi-Fi и Bluetooth обновляются без перезапуска shell;
- батарея скрыта на устройствах без laptop battery;
- reboot и shutdown требуют подтверждения;
- компоненты не содержат собственных hardcoded UI colors;
- все UI icons используют системную icon theme;
- reduced motion действительно отключает animations;
- monitor, shortcuts, OSD, Bluetooth agent и Polkit продолжают работать;
- Arch и NixOS configurations остаются синхронизированы;
- `./scripts/check.sh` проходит, а список skipped checks изучен;
- интерфейс проверен при scale 1×, 1.25×, 1.5× и 2×.

Итоговый визуальный язык:

```text
Adwaita-like surfaces
+ Cantarell
+ symbolic system icons
+ 18 px window radius
+ спокойный синий accent
+ минимум постоянных границ
+ мягкие hover и focus states
+ короткие animations
+ достаточно свободного пространства
```
