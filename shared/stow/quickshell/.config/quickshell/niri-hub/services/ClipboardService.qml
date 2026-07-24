import QtQuick
import Quickshell

QtObject {
    function copy(id): void {
        if (id !== "")
            Quickshell.execDetached(["/bin/sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", id])
    }

    function remove(id): void {
        if (id !== "")
            Quickshell.execDetached(["/bin/sh", "-c", "cliphist delete \"$1\"; rm -f \"$2/$1.\"*", "sh", id, Quickshell.cachePath("clipboard")])
    }
}
