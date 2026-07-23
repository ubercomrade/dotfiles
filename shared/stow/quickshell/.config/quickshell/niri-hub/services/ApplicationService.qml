import QtQuick
import Quickshell

QtObject {
    function results(query): var {
        const terms = query.toLowerCase().trim().split(/\s+/).filter(term => term.length)
        return DesktopEntries.applications.values.map(entry => {
            const haystack = [entry.name, entry.genericName, entry.comment, entry.id, entry.keywords.join(" ")].join(" ").toLowerCase()
            let score = 0
            let offset = 0
            for (const term of terms) {
                const index = haystack.indexOf(term, offset)
                if (index < 0)
                    return null
                score += index === 0 || haystack[index - 1] === " " ? 100 : 10
                score -= index
                offset = index + term.length
            }
            return { entry, score }
        }).filter(result => result !== null).sort((left, right) => right.score - left.score || left.entry.name.localeCompare(right.entry.name))
    }

    function launch(entry): void {
        if (!entry)
            return
        if (entry.runInTerminal)
            Quickshell.execDetached({ command: ["kitty", "--"].concat(entry.command), workingDirectory: entry.workingDirectory })
        else
            entry.execute()
    }

    function runCommand(command): void {
        Quickshell.execDetached(["/bin/sh", "-c", command])
    }
}
