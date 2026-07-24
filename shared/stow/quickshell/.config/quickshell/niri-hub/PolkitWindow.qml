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

    ModalCard {
        anchors.centerIn: parent
        width: Math.min(440 * Theme.scale, parent.width - Theme.unit * 8)

        ColumnLayout {
            id: authContent
            Rectangle {
                Layout.preferredWidth: 52 * Theme.scale; Layout.preferredHeight: 52 * Theme.scale
                Layout.alignment: Qt.AlignHCenter; radius: Theme.radiusLarge; color: Theme.accentMuted
                ShellIcon { anchors.centerIn: parent; text: "shield_lock"; color: Theme.accent; iconSize: 28 }
            }
            Label { Layout.fillWidth: true; text: qsTr("Authentication required"); color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
            Label { Layout.fillWidth: true; text: flow?.message || qsTr("A system action requires permission."); color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
            Label { visible: (flow?.supplementaryMessage || "") !== ""; Layout.fillWidth: true; text: flow?.supplementaryMessage || ""; color: flow?.supplementaryIsError ? Theme.danger : Theme.muted; font.family: Theme.fontFamily; wrapMode: Text.Wrap }
            ShellTextField {
                id: response
                visible: flow?.isResponseRequired ?? false
                Layout.fillWidth: true
                implicitHeight: Theme.controlHeight
                placeholderText: flow?.inputPrompt || qsTr("Password")
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
                ShellButton { id: cancelButton; text: qsTr("Cancel"); KeyNavigation.tab: authenticateButton; onClicked: { response.text = ""; flow.cancelAuthenticationRequest() } }
                ShellButton { id: authenticateButton; text: qsTr("Authenticate"); symbol: "lock_open"; primary: true; enabled: !(flow?.isResponseRequired ?? true) || response.text.length > 0; KeyNavigation.tab: response.visible ? response : cancelButton; onClicked: response.submit() }
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
