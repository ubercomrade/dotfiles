import QtQuick
import Quickshell

QtObject {
    function suspend(): void { Quickshell.execDetached(["systemctl", "suspend"]) }
    function reboot(): void { Quickshell.execDetached(["systemctl", "reboot"]) }
    function poweroff(): void { Quickshell.execDetached(["systemctl", "poweroff"]) }
}
