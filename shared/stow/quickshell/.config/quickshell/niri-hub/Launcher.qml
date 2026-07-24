pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower
import "."

Item {
    id: root
    required property var shell
    focus: true
    property string section: LauncherState.page === "apps" || LauncherState.page === "clipboard" ? "main" : LauncherState.page
    property string mode: LauncherState.page === "clipboard" ? "clipboard" : "apps"
    property int currentIndex: LauncherState.selectedIndex
    property var clipboardEntries: []
    property string searchQuery: ""
    property var appEntries: shell.applicationResults(searchQuery)
    property var visibleEntries: mode === "apps" ? appEntries : mode === "clipboard" ? clipboardEntries.filter(entry => entry.preview.toLowerCase().includes(query.text.toLowerCase())) : []
    property var wifiDevice: Networking.devices.values.find(device => device.type === DeviceType.Wifi) || null
    property var wifiNetworks: wifiDevice ? wifiDevice.networks.values.slice().sort((left, right) => Number(right.connected) - Number(left.connected) || right.signalStrength - left.signalStrength || left.name.localeCompare(right.name)) : []
    property var connectedNetwork: wifiNetworks.find(network => network.connected) || null
    property var passwordNetwork: null
    property var bluetoothAdapter: Bluetooth.defaultAdapter
    property var bluetoothDevices: bluetoothAdapter ? bluetoothAdapter.devices.values.slice().sort((left, right) => Number(right.connected) - Number(left.connected) || Number(right.paired) - Number(left.paired) || (left.name || left.deviceName).localeCompare(right.name || right.deviceName)) : []
    property int connectedBluetoothDevices: bluetoothDevices.filter(device => device.connected).length
    property string statusMessage: ""
    property string pendingPowerAction: LauncherState.pendingPowerAction

    onVisibleEntriesChanged: currentIndex = Math.max(0, Math.min(currentIndex, visibleEntries.length - 1))
    onCurrentIndexChanged: LauncherState.selectedIndex = currentIndex
    onPendingPowerActionChanged: LauncherState.pendingPowerAction = pendingPowerAction

    function selectOffset(offset): void {
        if (visibleEntries.length === 0)
            return
        currentIndex = (currentIndex + offset + visibleEntries.length) % visibleEntries.length
        results.positionViewAtIndex(currentIndex, ListView.Contain)
    }

    function activate(): void {
        if (mode === "apps")
            shell.launch(appEntries[currentIndex]?.entry)
        else if (mode === "run" && query.text.trim())
            shell.runCommand(query.text)
        else if (mode === "clipboard")
            shell.copyHistory(visibleEntries[currentIndex])
    }

    function setMode(nextMode): void {
        section = "main"
        mode = nextMode
        LauncherState.page = nextMode === "clipboard" ? "clipboard" : "apps"
        currentIndex = 0
        query.forceActiveFocus()
        if (nextMode === "clipboard")
            clipboardProcess.running = true
    }

    function shortcutMode(nextMode): void {
        if (root.section === "main" && root.pendingPowerAction === "" && shell.bluetoothAgent.promptType === "none")
            root.setMode(nextMode)
    }

    function openSection(nextSection): void {
        section = nextSection
        LauncherState.page = nextSection
        statusMessage = ""
        passwordNetwork = null
        wifiPassword.text = ""
    }

    function closeSection(): void {
        section = "main"
        LauncherState.page = "apps"
        statusMessage = ""
        passwordNetwork = null
        wifiPassword.text = ""
        query.forceActiveFocus()
    }

    function supportsPsk(network): bool {
        return network.security === WifiSecurityType.Sae || network.security === WifiSecurityType.Wpa2Psk || network.security === WifiSecurityType.WpaPsk
    }

    function activateNetwork(network): void {
        statusMessage = ""
        if (network.connected) {
            network.disconnect()
        } else if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe) {
            network.connect()
        } else if (supportsPsk(network)) {
            passwordNetwork = network
            wifiPassword.text = ""
            wifiPassword.forceActiveFocus()
        } else {
            statusMessage = "This network security type is not supported by the launcher"
        }
    }

    function connectWithPassword(): void {
        if (!passwordNetwork || !wifiPassword.text)
            return
        passwordNetwork.connectWithPsk(wifiPassword.text)
        wifiPassword.text = ""
        passwordNetwork = null
    }

    function handleEscape(): void {
        if (pendingPowerAction !== "")
            pendingPowerAction = ""
        else if (shell.bluetoothAgent.promptType !== "none")
            shell.bluetoothAgent.cancel()
        else if (passwordNetwork !== null) {
            passwordNetwork = null
            wifiPassword.text = ""
        }
        else if (section !== "main")
            closeSection()
        else if (query.text !== "")
            query.text = ""
        else
            shell.closeModal()
    }

    function activateBluetoothDevice(device): void {
        statusMessage = ""
        if (device.connected)
            device.disconnect()
        else if (device.paired)
            device.connect()
        else
            shell.bluetoothAgent.pair(device)
    }

    function requestPowerAction(action): void {
        if (action === "suspend") {
            Quickshell.execDetached(["systemctl", "suspend"])
            shell.closeModal()
        } else {
            pendingPowerAction = action
        }
    }

    function confirmPowerAction(): void {
        const action = pendingPowerAction
        pendingPowerAction = ""
        if (action === "restart")
            Quickshell.execDetached(["systemctl", "reboot"])
        else if (action === "poweroff")
            Quickshell.execDetached(["systemctl", "poweroff"])
        shell.closeModal()
    }

    Process {
        id: clipboardProcess
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.clipboardEntries = text.trim() ? text.trim().split("\n").map(line => {
                const tab = line.indexOf("\t")
                return { id: tab >= 0 ? line.slice(0, tab) : line, preview: tab >= 0 ? line.slice(tab + 1) : line }
            }) : []
        }
    }

    Timer {
        id: searchTimer
        interval: 100
        onTriggered: root.searchQuery = query.text
    }

    Shortcut { sequence: "Ctrl+1"; context: Qt.WindowShortcut; onActivated: root.shortcutMode("apps") }
    Shortcut { sequence: "Ctrl+2"; context: Qt.WindowShortcut; onActivated: root.shortcutMode("run") }
    Shortcut { sequence: "Ctrl+3"; context: Qt.WindowShortcut; onActivated: root.shortcutMode("clipboard") }
    Shortcut { sequence: "Ctrl+W"; context: Qt.WindowShortcut; onActivated: root.openSection("wifi") }
    Shortcut { sequence: "Ctrl+B"; context: Qt.WindowShortcut; onActivated: root.openSection("bluetooth") }
    Shortcut { sequence: "Ctrl+L"; context: Qt.WindowShortcut; onActivated: query.forceActiveFocus() }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.section === "wifi" && Networking.wifiEnabled
        when: root.wifiDevice !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: root.bluetoothAdapter
        property: "discovering"
        value: root.section === "bluetooth" && root.bluetoothAdapter?.enabled
        when: root.bluetoothAdapter !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    component StatusButton: Button {
        id: control
        property string iconName: ""
        property string primaryText: ""
        property string secondaryText: ""
        property bool selected: false
        Accessible.name: `${primaryText}, ${secondaryText}`
        implicitWidth: 150 * Theme.scale
        implicitHeight: 52 * Theme.scale
        padding: Theme.unit * 2

        background: Rectangle {
            radius: Theme.radiusMedium
            color: control.down || control.selected ? Theme.accentMuted : control.hovered ? Theme.surfaceHover : Theme.pillBackground
            border.width: 1
            border.color: control.activeFocus ? Theme.accent : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }
        contentItem: RowLayout {
            spacing: Theme.unit * 2
            Item {
                Layout.preferredWidth: 28 * Theme.scale
                Layout.preferredHeight: 28 * Theme.scale
                ShellIcon {
                    anchors.centerIn: parent
                    text: control.iconName
                    color: Theme.foreground
                    iconSize: 20
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    Layout.fillWidth: true
                    text: control.primaryText
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: control.secondaryText
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    elide: Text.ElideRight
                }
            }
        }
    }

    component BatteryIndicator: Button {
        id: batteryIndicator
        readonly property real level: Math.max(0, Math.min(1, UPower.displayDevice.percentage))
        readonly property color fillColor: level <= 0.15 ? Theme.danger : UPower.onBattery ? Theme.accent : Theme.success
        readonly property string detail: UPower.onBattery ? qsTr("%1% remaining, %2").arg(Math.round(level * 100)).arg(qsTr("%n minute(s)", "battery time remaining", Math.round(UPower.displayDevice.timeToEmpty / 60))) : UPower.displayDevice.timeToFull > 0 ? qsTr("%1% charged, %2 until full").arg(Math.round(level * 100)).arg(qsTr("%n minute(s)", "battery time until full", Math.round(UPower.displayDevice.timeToFull / 60))) : qsTr("%1% charged").arg(Math.round(level * 100))

        Accessible.name: qsTr("Battery: %1").arg(detail)
        Layout.preferredWidth: 76 * Theme.scale
        Layout.preferredHeight: 52 * Theme.scale
        flat: true
        onClicked: root.openSection(root.section === "battery" ? "main" : "battery")
        ToolTip.visible: hovered || activeFocus
        ToolTip.text: batteryIndicator.detail

        background: Rectangle {
            radius: Theme.radiusMedium
            color: batteryIndicator.down ? Theme.accentMuted : batteryIndicator.hovered ? Theme.surfaceHover : "transparent"
            border.width: batteryIndicator.activeFocus ? 2 : 0
            border.color: Theme.accent
        }

        contentItem: RowLayout {
            spacing: Theme.unit * 2

            ShellIcon {
                text: UPower.displayDevice.iconName || "battery-missing-symbolic"
                fallback: "battery-missing-symbolic"
                color: batteryIndicator.fillColor
                iconSize: 28
            }

            Label {
                text: `${Math.round(batteryIndicator.level * 100)}%`
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                font.weight: Font.DemiBold
            }
        }
    }

    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(100 * Theme.scale)
        width: Math.min(Theme.launcherWidth, parent.width - Theme.unit * 8)
        height: Math.min(Theme.launcherHeight, Math.max(0, parent.height - anchors.topMargin - Theme.unit * 4))
        radius: Theme.radiusLarge
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline
        clip: true

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.unit * 6
            spacing: Theme.unit * 4

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.unit * 3

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontDisplay
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                    }
                }

                BatteryIndicator {
                    visible: UPower.displayDevice.isLaptopBattery
                }

                StatusButton {
                    iconName: Networking.wifiEnabled ? "wifi" : "wifi_off"
                    primaryText: root.connectedNetwork?.name || (Networking.wifiEnabled ? qsTr("Wi-Fi") : qsTr("Wi-Fi off"))
                    secondaryText: root.connectedNetwork ? qsTr("Connected") : qsTr("Networks")
                    selected: root.section === "wifi"
                    onClicked: root.openSection(root.section === "wifi" ? "main" : "wifi")
                }
                StatusButton {
                    iconName: root.bluetoothAdapter?.enabled ? "bluetooth" : "bluetooth_disabled"
                    primaryText: qsTr("Bluetooth")
                    secondaryText: !root.bluetoothAdapter ? qsTr("Unavailable") : root.connectedBluetoothDevices ? qsTr("%1 connected").arg(root.connectedBluetoothDevices) : root.bluetoothAdapter.enabled ? qsTr("Available") : qsTr("Off")
                    selected: root.section === "bluetooth"
                    onClicked: root.openSection(root.section === "bluetooth" ? "main" : "bluetooth")
                }
                ShellButton {
                    Layout.preferredWidth: Theme.iconButtonSize
                    symbol: "bedtime"
                    text: ""
                    accessibleName: qsTr("Suspend")
                    ToolTip.visible: hovered
                    ToolTip.text: accessibleName
                    onClicked: root.requestPowerAction("suspend")
                }
                ShellButton {
                    Layout.preferredWidth: Theme.iconButtonSize
                    symbol: "restart_alt"
                    text: ""
                    accessibleName: qsTr("Restart")
                    ToolTip.visible: hovered
                    ToolTip.text: accessibleName
                    onClicked: root.requestPowerAction("restart")
                }
                ShellButton {
                    Layout.preferredWidth: Theme.iconButtonSize
                    symbol: "power_settings_new"
                    text: ""
                    accessibleName: qsTr("Power off")
                    ToolTip.visible: hovered
                    ToolTip.text: accessibleName
                    onClicked: root.requestPowerAction("poweroff")
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.outline
            }

            ColumnLayout {
                visible: root.section === "main"
                Layout.fillWidth: true
                Layout.fillHeight: visible
                Layout.preferredHeight: visible ? implicitHeight : 0
                Layout.minimumHeight: 0
                Layout.maximumHeight: visible ? Infinity : 0
                spacing: Theme.unit * 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.unit * 2

                    Repeater {
                        model: [{ id: "apps", label: "Apps" }, { id: "run", label: "Run" }, { id: "clipboard", label: "Clipboard" }]
                        delegate: Button {
                            id: modeButton
                            required property var modelData
                            text: modelData.label
                            checkable: true
                            checked: root.mode === modelData.id
                            flat: true
                            onClicked: root.setMode(modelData.id)
                            background: Rectangle {
                                radius: Theme.radiusPill
                                color: modeButton.checked ? Theme.accentMuted : modeButton.hovered ? Theme.surfaceRaised : "transparent"
                                border.width: modeButton.activeFocus ? 2 : 0
                                border.color: Theme.accent
                            }
                            contentItem: Label {
                                text: modeButton.text
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBody
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Label { text: qsTr("Ctrl+1 Apps  Ctrl+2 Run  Ctrl+3 Clipboard"); color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                }

                ShellTextField {
                    id: query
                    accessibleName: qsTr("Search applications")
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.controlHeight
                    placeholderText: root.mode === "apps" ? "Search applications" : root.mode === "run" ? "Run command" : "Search clipboard history"
                    selectByMouse: true
                    onTextChanged: {
                        root.currentIndex = 0
                        searchTimer.restart()
                    }
                    onAccepted: root.activate()
                    Component.onCompleted: forceActiveFocus()
                    Keys.onEscapePressed: root.handleEscape()
                    Keys.onPressed: event => {
                        if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_R) {
                            if (root.mode === "clipboard")
                                clipboardProcess.running = true
                            event.accepted = true
                        } else if (event.key === Qt.Key_Delete && root.mode === "clipboard") {
                            const entry = root.visibleEntries[root.currentIndex]
                            shell.clipboardService.remove(entry?.id || "")
                            clipboardProcess.running = true
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier)) {
                            root.selectOffset(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier)) {
                            root.selectOffset(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Home) {
                            root.currentIndex = 0
                            event.accepted = true
                        } else if (event.key === Qt.Key_End) {
                            root.currentIndex = Math.max(0, root.visibleEntries.length - 1)
                            event.accepted = true
                        }
                    }
                }

                Label {
                    visible: root.mode === "run"
                    Layout.fillWidth: true
                    text: "Commands run through /bin/sh. Review the command before pressing Enter."
                    color: Theme.muted
                    wrapMode: Text.Wrap
                }

                ListView {
                    id: results
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Theme.unit
                    model: root.mode === "run" ? [] : root.visibleEntries

                    delegate: Button {
                        id: resultButton
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: Theme.rowHeight
                        highlighted: root.currentIndex === index
                        flat: true
                        Accessible.name: root.mode === "apps" ? qsTr("Open %1").arg(modelData.entry.name) : qsTr("Copy %1").arg(modelData.preview)
                        onClicked: {
                            root.currentIndex = index
                            root.activate()
                        }
                        background: Rectangle {
                            radius: Theme.radiusMedium
                            color: resultButton.highlighted ? Theme.accentMuted : resultButton.hovered ? Theme.surfaceRaised : "transparent"
                            border.width: resultButton.activeFocus ? 2 : 0
                            border.color: Theme.accent
                        }
                        contentItem: RowLayout {
                            spacing: Theme.unit * 3
                            Image {
                                source: Quickshell.iconPath(root.mode === "apps" ? modelData.entry.icon : "edit-paste", "application-x-executable")
                                sourceSize.width: Math.round(28 * Theme.scale)
                                sourceSize.height: Math.round(28 * Theme.scale)
                                Layout.preferredWidth: 28 * Theme.scale
                                Layout.preferredHeight: 28 * Theme.scale
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label {
                                    Layout.fillWidth: true
                                    text: root.mode === "apps" ? modelData.entry.name : modelData.preview
                                    textFormat: Text.PlainText
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontLabel
                                    elide: Text.ElideRight
                                }
                                Label {
                                    visible: root.mode === "apps" && modelData.entry && (modelData.entry.genericName || modelData.entry.comment)
                                    Layout.fillWidth: true
                                    text: root.mode === "apps" && modelData.entry ? modelData.entry.genericName || modelData.entry.comment : ""
                                    textFormat: Text.PlainText
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: root.mode !== "run" && root.visibleEntries.length === 0
                        text: root.mode === "clipboard" ? "Clipboard history is empty" : "No applications found"
                        color: Theme.muted
                    }
                }
            }

            ColumnLayout {
                visible: root.section === "wifi"
                Layout.fillWidth: true
                Layout.fillHeight: visible
                Layout.preferredHeight: visible ? implicitHeight : 0
                Layout.minimumHeight: 0
                Layout.maximumHeight: visible ? Infinity : 0
                spacing: Theme.unit * 3

                RowLayout {
                    Layout.fillWidth: true
                    ShellButton { compact: true; text: qsTr("Back"); symbol: "arrow_back"; onClicked: root.closeSection() }
                    Label { Layout.leftMargin: Theme.unit * 2; text: "Wi-Fi networks"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    ShellToggle {
                        text: Networking.wifiEnabled ? "On" : "Off"
                        accessibleName: qsTr("Wi-Fi")
                        checked: Networking.wifiEnabled
                        enabled: Networking.wifiHardwareEnabled
                        onToggled: Networking.wifiEnabled = checked
                    }
                }

                Label {
                    visible: !root.wifiDevice
                    Layout.fillWidth: true
                    text: "No Wi-Fi adapter available"
                    color: Theme.muted
                    horizontalAlignment: Text.AlignHCenter
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.wifiDevice && Networking.wifiEnabled
                    clip: true
                    spacing: Theme.unit
                    model: root.wifiNetworks

                    delegate: Button {
                        id: networkButton
                        required property var modelData
                        width: ListView.view.width
                        height: Theme.rowHeight
                        flat: true
                        Accessible.name: qsTr("%1, %2").arg(modelData.name).arg(modelData.connected ? qsTr("disconnect") : qsTr("connect"))
                        onClicked: root.activateNetwork(modelData)
                        background: Rectangle {
                            radius: Theme.radiusMedium
                            color: networkButton.hovered ? Theme.surfaceRaised : modelData.connected ? Theme.accentMuted : "transparent"
                            border.width: networkButton.activeFocus ? 2 : 0
                            border.color: Theme.accent
                        }
                        contentItem: RowLayout {
                            spacing: Theme.unit * 3
                            Item {
                                Layout.preferredWidth: 28 * Theme.scale
                                Layout.preferredHeight: 28 * Theme.scale
                                ShellIcon { anchors.centerIn: parent; text: modelData.connected ? "wifi" : "network_wifi"; color: Theme.foreground; iconSize: 19 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 0
                                Label { Layout.fillWidth: true; text: modelData.name; textFormat: Text.PlainText; color: Theme.foreground; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.connected ? qsTr("Connected") : modelData.stateChanging ? qsTr("Connecting...") : modelData.known ? qsTr("Saved network") : modelData.security === WifiSecurityType.Open || modelData.security === WifiSecurityType.Owe ? qsTr("Open network") : root.supportsPsk(modelData) ? qsTr("Secured network, password required") : qsTr("Unsupported security")
                                    color: modelData.connected ? Theme.success : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption
                                    elide: Text.ElideRight
                                }
                            }
                            Label { Layout.preferredWidth: 48 * Theme.scale; text: `${Math.round(modelData.signalStrength * 100)}%`; color: Theme.foreground; horizontalAlignment: Text.AlignRight }
                            Label { Layout.preferredWidth: 88 * Theme.scale; text: modelData.connected ? "Disconnect" : "Connect"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; horizontalAlignment: Text.AlignRight }
                        }
                        Connections {
                            target: modelData
                            function onConnectionFailed(reason): void { root.statusMessage = `Connection failed: ${ConnectionFailReason.toString(reason)}` }
                        }
                    }
                }

                Rectangle {
                    visible: root.passwordNetwork !== null
                    Layout.fillWidth: true
                    Layout.preferredHeight: passwordRow.implicitHeight + Theme.unit * 6
                    radius: Theme.radiusMedium
                    color: Theme.surfaceRaised

                    RowLayout {
                        id: passwordRow
                        anchors.fill: parent
                        anchors.margins: Theme.unit * 3
                        spacing: Theme.unit * 2
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: `Password for ${root.passwordNetwork?.name || "network"}`; color: Theme.foreground }
                            ShellTextField {
                                id: wifiPassword
                                accessibleName: qsTr("Network password")
                                Layout.fillWidth: true
                                echoMode: TextInput.Password
                                placeholderText: "Network password"
                                onAccepted: root.connectWithPassword()
                            }
                        }
                        ShellButton { text: qsTr("Cancel"); onClicked: { wifiPassword.text = ""; root.passwordNetwork = null } }
                        ShellButton { text: qsTr("Connect"); primary: true; enabled: wifiPassword.text.length > 0; onClicked: root.connectWithPassword() }
                    }
                }
                Label { visible: root.statusMessage !== ""; text: root.statusMessage; color: Theme.danger; Layout.fillWidth: true; wrapMode: Text.Wrap }
            }

            ColumnLayout {
                visible: root.section === "bluetooth"
                Layout.fillWidth: true
                Layout.fillHeight: visible
                Layout.preferredHeight: visible ? implicitHeight : 0
                Layout.minimumHeight: 0
                Layout.maximumHeight: visible ? Infinity : 0
                spacing: Theme.unit * 3

                RowLayout {
                    Layout.fillWidth: true
                    ShellButton { compact: true; text: qsTr("Back"); symbol: "arrow_back"; onClicked: root.closeSection() }
                    Label { Layout.leftMargin: Theme.unit * 2; text: "Bluetooth devices"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    Label { visible: root.bluetoothAdapter?.discovering ?? false; text: "Scanning..."; color: Theme.accent }
                    ShellToggle {
                        text: root.bluetoothAdapter?.enabled ? "On" : "Off"
                        accessibleName: qsTr("Bluetooth")
                        checked: root.bluetoothAdapter?.enabled ?? false
                        enabled: root.bluetoothAdapter !== null
                        onToggled: root.bluetoothAdapter.enabled = checked
                    }
                }

                Label {
                    visible: !root.bluetoothAdapter
                    Layout.fillWidth: true
                    text: "No Bluetooth adapter available"
                    color: Theme.muted
                    horizontalAlignment: Text.AlignHCenter
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.bluetoothAdapter?.enabled ?? false
                    clip: true
                    spacing: Theme.unit
                    model: root.bluetoothDevices

                    delegate: Button {
                        id: deviceButton
                        required property var modelData
                        width: ListView.view.width
                        height: Theme.rowHeight
                        flat: true
                        Accessible.name: qsTr("%1, %2").arg(modelData.name || modelData.deviceName || modelData.address).arg(modelData.connected ? qsTr("disconnect") : modelData.paired ? qsTr("connect") : qsTr("pair"))
                        enabled: !shell.bluetoothAgent.busy || modelData === shell.bluetoothAgent.pendingDevice
                        onClicked: root.activateBluetoothDevice(modelData)
                        background: Rectangle {
                            radius: Theme.radiusMedium
                            color: deviceButton.hovered ? Theme.surfaceRaised : modelData.connected ? Theme.accentMuted : "transparent"
                            border.width: deviceButton.activeFocus ? 2 : 0
                            border.color: Theme.accent
                        }
                        contentItem: RowLayout {
                            spacing: Theme.unit * 3
                            Item {
                                Layout.preferredWidth: 30 * Theme.scale
                                Layout.preferredHeight: 30 * Theme.scale
                                ShellIcon { anchors.centerIn: parent; text: modelData.connected ? "bluetooth_connected" : "bluetooth"; color: Theme.foreground; iconSize: 19 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 0
                                Label { Layout.fillWidth: true; text: modelData.name || modelData.deviceName || modelData.address; textFormat: Text.PlainText; color: Theme.foreground; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.connected ? "Connected" : modelData.pairing ? "Pairing..." : modelData.state === BluetoothDeviceState.Connecting ? "Connecting..." : modelData.paired ? "Paired" : "New device"
                                    color: modelData.connected ? Theme.success : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption
                                    elide: Text.ElideRight
                                }
                            }
                            Label {
                                visible: modelData.batteryAvailable
                                Layout.preferredWidth: 48 * Theme.scale
                                text: `${Math.round(modelData.battery * 100)}%`
                                color: Theme.foreground
                                horizontalAlignment: Text.AlignRight
                            }
                            Label { Layout.preferredWidth: 88 * Theme.scale; text: modelData.connected ? "Disconnect" : modelData.paired ? "Connect" : "Pair"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; horizontalAlignment: Text.AlignRight }
                        }
                    }
                }
                Label {
                    visible: shell.bluetoothAgent.statusMessage !== ""
                    text: shell.bluetoothAgent.statusMessage
                    color: shell.bluetoothAgent.statusKind === "error" ? Theme.danger : shell.bluetoothAgent.statusKind === "success" ? Theme.success : Theme.muted
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }

            ColumnLayout {
                visible: root.section === "battery" && UPower.displayDevice.isLaptopBattery
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: visible ? implicitHeight : 0
                Layout.minimumHeight: 0
                Layout.maximumHeight: visible ? Infinity : 0
                spacing: Theme.unit * 3

                RowLayout {
                    Layout.fillWidth: true
                    ShellButton { compact: true; text: qsTr("Back"); symbol: "arrow_back"; onClicked: root.closeSection() }
                    Label { Layout.leftMargin: Theme.unit * 2; text: qsTr("Battery"); color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("%1% charged").arg(Math.round((UPower.displayDevice.percentage || 0) * 100))
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontDisplay
                }
                Label {
                    Layout.fillWidth: true
                    text: UPower.onBattery ? qsTr("Discharging") : qsTr("Charging or fully charged")
                    color: Theme.muted
                    font.family: Theme.fontFamily
                }
                Label {
                    Layout.fillWidth: true
                    visible: UPower.displayDevice.timeToEmpty > 0 || UPower.displayDevice.timeToFull > 0
                    text: UPower.onBattery ? qsTr("%1 remaining").arg(qsTr("%n minute(s)", "battery time remaining", Math.round(UPower.displayDevice.timeToEmpty / 60))) : qsTr("%1 until full").arg(qsTr("%n minute(s)", "battery time until full", Math.round(UPower.displayDevice.timeToFull / 60)))
                    color: Theme.muted
                    font.family: Theme.fontFamily
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.pendingPowerAction !== ""
            focus: visible
            color: Theme.scrim
            z: 20

            onVisibleChanged: {
                if (visible)
                    Qt.callLater(cancelPowerButton.forceActiveFocus)
                else
                    Qt.callLater(query.forceActiveFocus)
            }

            MouseArea { anchors.fill: parent }

            ModalCard {
                anchors.centerIn: parent
                width: Math.min(440 * Theme.scale, parent.width - Theme.unit * 12)

                ColumnLayout {
                    id: powerConfirmColumn

                    Label {
                        text: root.pendingPowerAction === "restart" ? qsTr("Restart computer?") : qsTr("Power off computer?")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Unsaved work may be lost.")
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        ShellButton { id: cancelPowerButton; text: qsTr("Cancel"); KeyNavigation.tab: confirmPowerButton; onClicked: root.pendingPowerAction = "" }
                        ShellButton { id: confirmPowerButton; text: root.pendingPowerAction === "restart" ? qsTr("Restart") : qsTr("Power off"); danger: true; KeyNavigation.tab: cancelPowerButton; onClicked: root.confirmPowerAction() }
                    }
                }
            }
        }

        Rectangle {
            id: bluetoothPrompt
            anchors.fill: parent
            visible: shell.bluetoothAgent.promptType !== "none"
            focus: visible
            color: Theme.scrim
            z: 20

            onVisibleChanged: {
                if (!visible) {
                    Qt.callLater(query.forceActiveFocus)
                    return
                }
                if (bluetoothCode.visible)
                    Qt.callLater(bluetoothCode.forceActiveFocus)
                else if (continueButton.visible)
                    Qt.callLater(continueButton.forceActiveFocus)
                else
                    Qt.callLater(cancelBluetoothButton.forceActiveFocus)
            }

            MouseArea { anchors.fill: parent }

            ModalCard {
                anchors.centerIn: parent
                width: Math.min(440 * Theme.scale, parent.width - Theme.unit * 12)

                ColumnLayout {
                    id: promptColumn

                    Label { text: qsTr("Bluetooth pairing"); color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                    Label {
                        Layout.fillWidth: true
                        text: shell.bluetoothAgent.promptType === "confirm" ? `Confirm that ${shell.bluetoothAgent.promptValue} is displayed on the device.` : shell.bluetoothAgent.promptType === "display" ? `Type ${shell.bluetoothAgent.promptValue} on the Bluetooth device, then press Enter there.` : shell.bluetoothAgent.promptType === "authorize" ? `Authorize Bluetooth service ${shell.bluetoothAgent.promptValue}?` : "Enter the code shown by the Bluetooth device."
                        color: Theme.muted
                        wrapMode: Text.Wrap
                    }
                    ShellTextField {
                        id: bluetoothCode
                        accessibleName: shell.bluetoothAgent.promptType === "pin" ? qsTr("PIN code") : qsTr("Passkey")
                        visible: shell.bluetoothAgent.promptType === "pin" || shell.bluetoothAgent.promptType === "passkey"
                        Layout.fillWidth: true
                        placeholderText: shell.bluetoothAgent.promptType === "pin" ? qsTr("PIN code") : qsTr("Passkey")
                        inputMethodHints: shell.bluetoothAgent.promptType === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
                        onAccepted: {
                            shell.bluetoothAgent.answer(text)
                            text = ""
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        ShellButton { id: cancelBluetoothButton; text: qsTr("Cancel"); KeyNavigation.tab: continueButton.visible ? continueButton : bluetoothCode; onClicked: { bluetoothCode.text = ""; shell.bluetoothAgent.cancel() } }
                        ShellButton {
                            id: continueButton
                            text: qsTr("Continue")
                            primary: true
                            visible: shell.bluetoothAgent.promptType !== "display"
                            enabled: shell.bluetoothAgent.promptType === "confirm" || shell.bluetoothAgent.promptType === "authorize" || bluetoothCode.text.length > 0
                            KeyNavigation.tab: cancelBluetoothButton
                            onClicked: {
                                shell.bluetoothAgent.answer(shell.bluetoothAgent.promptType === "confirm" || shell.bluetoothAgent.promptType === "authorize" ? "yes" : bluetoothCode.text)
                                bluetoothCode.text = ""
                            }
                        }
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: root.handleEscape()
}
