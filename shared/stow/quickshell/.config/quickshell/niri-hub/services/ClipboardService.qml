import QtQuick
import Quickshell

QtObject {
    function copy(id): void {
        if (id !== "")
            Quickshell.execDetached(["/bin/sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", id])
    }

    function remove(id): void {
        if (id !== "")
            Quickshell.execDetached(["cliphist", "delete", id])
    }
}
