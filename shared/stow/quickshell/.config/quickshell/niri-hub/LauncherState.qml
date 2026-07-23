pragma Singleton
import QtQuick

QtObject {
    property string page: "apps"
    property string query: ""
    property int selectedIndex: 0
    property string pendingPowerAction: ""
    property bool keyboardNavigation: false
    property var wifiPasswordNetwork: null
    property string statusMessage: ""

    function reset(): void {
        query = ""
        selectedIndex = 0
        pendingPowerAction = ""
        wifiPasswordNetwork = null
        statusMessage = ""
        keyboardNavigation = false
    }
}
