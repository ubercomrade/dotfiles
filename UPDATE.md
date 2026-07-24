# Desktop integration update plan

## Goal

Make the Niri desktop reproducible across Arch Linux and NixOS, fix the
current Quickshell UI defects, and use one coherent appearance contract for
GTK, Qt, icons, cursors, notifications, and Kitty.

The recommended baseline is an Adwaita/GNOME-oriented desktop using the GTK3
Qt platform theme, Adwaita icons, and an Adwaita cursor. Quickshell remains a
custom Qt Quick Controls Basic interface, but its semantic tokens should track
the same visual language.

## Phase 1: Fix functional QML defects

- [ ] Give the Polkit, power, Bluetooth, and process-confirmation cards an
  actual bounded `height`, not only `implicitHeight`.
- [ ] Extract their repeated scrim, card, Escape handling, initial focus, and
  focus-trap behavior into a reusable modal component where this reduces the
  duplicated logic.
- [ ] Add usable accessible names to application, clipboard, Wi-Fi, and
  Bluetooth delegate buttons.
- [ ] Keep keyboard focus inside active confirmation dialogs and restore focus
  when they close.
- [ ] Make the battery status element a real keyboard-accessible button that
  opens the battery page.
- [ ] Move launcher-wide shortcuts away from the search field so they remain
  active after focus moves to another control.
- [ ] Restore conventional Tab traversal; use explicit shortcuts for switching
  Apps, Run, and Clipboard modes.
- [ ] Increase process-row height to a usable pointer and keyboard target.
- [ ] Validate persisted interface scale values before applying them.

Primary files:

- `shared/stow/quickshell/.config/quickshell/niri-hub/Launcher.qml`
- `shared/stow/quickshell/.config/quickshell/niri-hub/PolkitWindow.qml`
- `shared/stow/quickshell/.config/quickshell/niri-hub/SystemMonitorDashboard.qml`
- `shared/stow/quickshell/.config/quickshell/niri-hub/ShellSettings.qml`

## Phase 2: Make runtime dependencies reproducible

- [ ] Declare Qt 6 5Compat because `ShellIcon.qml` imports
  `Qt5Compat.GraphicalEffects`.
- [ ] Declare the selected sans and monospace fonts instead of relying on
  packages installed outside the repository.
- [ ] Keep Arch and NixOS package declarations equivalent for every runtime
  dependency used by Quickshell, Mako, and Kitty.
- [ ] Decide whether to retain `Noto Sans Mono` or standardize on
  `Adwaita Mono`. Prefer `adwaita-fonts` for the strict Adwaita variant.
- [ ] Ensure the limited Arch Niri deployment includes Kitty configuration and
  MIME associations, since that preset installs Kitty and the associated GUI
  applications.

Primary files:

- `arch/packages/niri.txt`
- `arch/packages/common.txt`
- `arch/install.sh`
- `nixos/modules/home.nix`
- `nixos/modules/desktop.nix`

## Phase 3: Define one appearance contract

- [ ] Use dconf and the settings portal as the primary GTK appearance source;
  retain GTK 3/4 `settings.ini` files as compatible fallbacks.
- [ ] Remove the redundant Niri startup mutation of the same GTK settings once
  both deployment targets set them declaratively.
- [ ] Set `QT_QPA_PLATFORMTHEME=gtk3` in the graphical session environment so
  ordinary Qt applications inherit GTK fonts, palette, icons, and related
  desktop settings through Qt's built-in GTK3 platform theme.
- [ ] Do not adopt QGnomePlatform or adwaita-qt; both projects are unmaintained.
- [ ] Avoid a global `QT_STYLE_OVERRIDE` unless an identified application needs
  an explicit compatibility override.
- [ ] Put shared graphical-session variables in one managed environment file
  and ensure user systemd services receive the same values.
- [ ] Keep portal routing as GTK for the default and file chooser, GNOME for
  screenshots and screen casting, and GNOME Keyring for secrets.

Primary files:

- `shared/stow/gtk/.config/gtk-3.0/settings.ini`
- `shared/stow/gtk/.config/gtk-4.0/settings.ini`
- `shared/stow/niri/.config/niri/config.kdl`
- `shared/stow/portal/.config/xdg-desktop-portal/niri-portals.conf`
- `nixos/modules/home.nix`
- `nixos/modules/desktop.nix`

## Phase 4: Unify the cursor

- [ ] Select one cursor theme and size for the compositor, GTK, Qt clients,
  XWayland, and portal-launched applications.
- [ ] Prefer Adwaita at size 24 for an official-package-only, portable setup.
- [ ] If Bibata is retained, declare it explicitly for Arch and NixOS rather
  than relying on a locally installed third-party package.
- [ ] Set the cursor through Niri, GTK settings, dconf, and graphical-session
  environment variables.
- [ ] Ensure `XCURSOR_PATH` includes system and user icon directories if a
  user-installed cursor theme is supported.
- [ ] Verify cursor appearance over the compositor background, GTK windows,
  Qt windows, Quickshell surfaces, and XWayland applications.

## Phase 5: Improve icons and status surfaces

- [ ] Continue using Freedesktop icon names and a complete installed icon
  theme with `hicolor` fallback.
- [ ] Decide whether Niri Hub is permanently Adwaita or should follow the
  session icon theme; remove the hard-coded icon-theme pragma only for the
  latter behavior.
- [ ] Use native control `icon.name` and `icon.color` where practical instead
  of applying a graphical color overlay to every icon.
- [ ] Never recolor application icons; preserve their original multicolor
  artwork.
- [ ] Add semantic fallbacks instead of using `image-missing-symbolic` for all
  missing shell actions.
- [ ] Correct disabled icon colors in `ShellButton.qml`.
- [ ] Show Wi-Fi security with an icon or text in addition to color.
- [ ] Add a lazily loaded Tray or Background Apps page to Niri Hub if access to
  StatusNotifier-only applications is required; do not add a permanent panel
  solely for tray icons.

Primary files:

- `shared/stow/quickshell/.config/quickshell/niri-hub/ShellIcon.qml`
- `shared/stow/quickshell/.config/quickshell/niri-hub/ShellButton.qml`
- `shared/stow/quickshell/.config/quickshell/niri-hub/Launcher.qml`
- `shared/stow/quickshell/.config/quickshell/niri-hub/shell.qml`

## Phase 6: Normalize visual design and typography

- [ ] Keep semantic role names for surfaces, text, outline, accent, success,
  warning, and destructive colors.
- [ ] Replace the remaining duplicated or ambiguous aliases in `Theme.qml`
  with a small documented token set.
- [ ] Increase normal body text from 14 px-equivalent to an accessible desktop
  size and keep captions for metadata only.
- [ ] Separate text scale from geometric interface scale.
- [ ] Add light and high-contrast palettes only after the dark palette and
  system-theme plumbing are stable.
- [ ] Make active Wi-Fi and Bluetooth pages visibly selected.
- [ ] Reserve persistent destructive styling for confirmations instead of the
  always-visible power-off button.
- [ ] Use the same elevation treatment for equivalent modal cards.
- [ ] Add text legends and current-value summaries to monitor graphs so color
  is not the only differentiator.
- [ ] Replace animated `Canvas` graphs with a render-friendly alternative if
  profiling shows meaningful main-thread cost.

Primary files:

- `shared/stow/quickshell/.config/quickshell/niri-hub/Theme.qml`
- `shared/stow/quickshell/.config/quickshell/niri-hub/Launcher.qml`
- `shared/stow/quickshell/.config/quickshell/niri-hub/SystemMonitorWidget.qml`
- `shared/stow/quickshell/.config/quickshell/niri-hub/SystemMonitorDashboard.qml`

## Phase 7: Localization and accessibility

- [ ] Wrap all user-visible QML strings in `qsTr()`.
- [ ] Use locale-aware short date and time formats instead of fixed format
  strings.
- [ ] Use translatable plural forms for battery durations.
- [ ] Store Bluetooth result state separately from translated status text;
  never classify errors by searching English words.
- [ ] Add RTL layout mirroring and verify directional icons.
- [ ] Make hover tooltips visible on keyboard focus as well.
- [ ] Add accessible descriptions or textual alternatives for graphs and
  asynchronous status changes.
- [ ] Pair selection, connection, warning, and error colors with text, shape,
  or icons.
- [ ] Verify logical focus order and visible focus indicators for every
  interactive element.

## Phase 8: Align Mako and Kitty

- [ ] Choose one dark semantic palette for Quickshell surfaces, Mako, and the
  non-ANSI parts of Kitty.
- [ ] Keep a terminal-specific ANSI palette, but align background, foreground,
  selection, cursor, URL, and border roles with the desktop palette.
- [ ] Move Kitty colors into a separate included theme file.
- [ ] Consider `Adwaita Mono` for maximum GNOME consistency, or retain
  `Noto Sans Mono` and declare it on both platforms.
- [ ] Review `confirm_os_window_close 0` and restore protection if closing a
  terminal with foreground work must require confirmation.
- [ ] Keep Mako critical notifications persistent and ensure their danger state
  uses both text and border treatment.

Primary files:

- `shared/stow/kitty/.config/kitty/kitty.conf`
- `shared/stow/mako/.config/mako/config`
- `shared/stow/quickshell/.config/quickshell/niri-hub/Theme.qml`

## Phase 9: Remove configuration drift

- [ ] Generate shortcut help from one canonical data source, or add a check
  that compares `ShortcutOverlay.qml` with Niri bindings.
- [ ] Add the missing `Super+V` shortcut to the current overlay immediately.
- [ ] Keep Arch systemd units and Home Manager service definitions equivalent,
  including restart delays.
- [ ] Document intentional omissions such as the lack of a permanent bar,
  notification history, workspace indicator, and audio controls.
- [ ] Add repository checks for declared QML imports, configured fonts, cursor
  packages, and Arch/NixOS appearance parity where practical.

## Verification

- [ ] Run `./scripts/check.sh` and review every reported skip.
- [ ] Run `bash -n apply.sh install.sh arch/install.sh` after shell changes.
- [ ] Run `qmllint` through the repository check and resolve all diagnostics.
- [ ] Validate Niri configuration for the generic and laptop host profiles.
- [ ] Run `nix flake check "path:$PWD"` after Nix changes.
- [ ] Build the relevant NixOS host before activation.
- [ ] Test a clean Arch limited Niri deployment, not only a machine with extra
  packages already installed.
- [ ] Test at logical geometries corresponding to `2520x1680@1.5` and
  `1920x1080@1.0`.
- [ ] Test keyboard-only operation, large text, reduced motion, dark mode,
  deuteranopia simulation, and screen-reader names.
- [ ] Verify GTK 3, GTK 4/libadwaita, Qt Widgets, Qt Quick, XWayland, portal
  dialogs, cursor theme, application icons, tray items, Mako, and Kitty.

## Decisions before implementation

- [ ] Cursor: Adwaita 24 (recommended) or explicitly packaged Bibata.
- [ ] Monospace font: Adwaita Mono for strict GNOME alignment or declared Noto
  Sans Mono for continuity.
- [ ] Icons: fixed Adwaita identity for Niri Hub or runtime session icon theme.
- [ ] Terminal palette: desktop-aligned Adwaita roles or retained Catppuccin
  ANSI colors with aligned surfaces.
- [ ] Tray: intentionally unsupported or exposed as an on-demand Hub page.
