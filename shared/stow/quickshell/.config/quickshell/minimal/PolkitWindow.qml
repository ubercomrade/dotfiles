import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import "."

PanelWindow {
    id: window
    required property var shell
    required property var screenData
    required property var flow
    screen: screenData
    visible: flow !== null && !flow.isCompleted && screenData.name === shell.focusedOutput
    focusable: visible
    exclusiveZone: 0
    color: Theme.scrim
    anchors { top: true; bottom: true; left: true; right: true }

    onVisibleChanged: {
        if (visible) {
            if (flow?.isResponseRequired)
                Qt.callLater(response.forceActiveFocus)
            else
                Qt.callLater(authenticateButton.forceActiveFocus)
        }
        else
            response.text = ""
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(440 * Theme.scale, parent.width - Theme.unit * 8)
        implicitHeight: authContent.implicitHeight + Theme.unit * 10
        radius: Theme.radiusLarge
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline

        ColumnLayout {
            id: authContent
            anchors.fill: parent
            anchors.margins: Theme.unit * 5
            spacing: Theme.unit * 3
            Rectangle {
                Layout.preferredWidth: 52 * Theme.scale; Layout.preferredHeight: 52 * Theme.scale
                Layout.alignment: Qt.AlignHCenter; radius: Theme.radiusLarge; color: Theme.accentMuted
                ShellIcon { anchors.centerIn: parent; text: "shield_lock"; color: Theme.accent; iconSize: 28 }
            }
            Label { Layout.fillWidth: true; text: "Authentication required"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
            Label { Layout.fillWidth: true; text: flow?.message || "A system action requires permission."; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
            Label { visible: (flow?.supplementaryMessage || "") !== ""; Layout.fillWidth: true; text: flow?.supplementaryMessage || ""; color: flow?.supplementaryIsError ? Theme.danger : Theme.muted; font.family: Theme.fontFamily; wrapMode: Text.Wrap }
            ShellTextField {
                id: response
                visible: flow?.isResponseRequired ?? false
                Layout.fillWidth: true
                implicitHeight: Theme.controlHeight
                placeholderText: flow?.inputPrompt || "Password"
                echoMode: flow?.responseVisible ? TextInput.Normal : TextInput.Password
                selectByMouse: true
                onAccepted: submit()
                function submit(): void {
                    if (!flow || (flow.isResponseRequired && !text.length)) return
                    flow.submit(text)
                    text = ""
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                ShellButton { text: qsTr("Cancel"); onClicked: { response.text = ""; flow.cancelAuthenticationRequest() } }
                ShellButton { id: authenticateButton; text: qsTr("Authenticate"); symbol: "lock_open"; primary: true; enabled: !(flow?.isResponseRequired ?? true) || response.text.length > 0; onClicked: response.submit() }
            }
        }
    }

    Shortcut {
        enabled: window.visible
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: flow.cancelAuthenticationRequest()
    }
}
