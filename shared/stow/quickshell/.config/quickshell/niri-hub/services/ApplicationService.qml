import QtQuick
import Quickshell

QtObject {
    function searchableEntries(): var {
        return DesktopEntries.applications.values
            .filter(entry => entry && entry.name && !entry.noDisplay && entry.command && entry.command.length)
            .map(entry => ({
                entry,
                haystack: [entry.name, entry.genericName, entry.comment, entry.id, (entry.keywords || []).join(" ")].join(" ").toLowerCase()
            }))
    }

    function results(query): var {
        const terms = query.toLowerCase().trim().split(/\s+/).filter(term => term.length)
        return searchableEntries().map(record => {
            const haystack = record.haystack
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
            return { entry: record.entry, score }
        }).filter(result => result !== null).sort((left, right) => right.score - left.score || left.entry.name.localeCompare(right.entry.name))
    }

    function launch(entry): void {
        if (!entry)
            return
        const command = []
        for (let index = 0; index < entry.command.length; index++)
            command.push(entry.command[index])
        if (entry.runInTerminal)
            Quickshell.execDetached({ command: ["kitty", "--"].concat(command), workingDirectory: entry.workingDirectory })
        else
            Quickshell.execDetached({ command, workingDirectory: entry.workingDirectory })
    }

    function runCommand(command): void {
        Quickshell.execDetached(["/bin/sh", "-c", command])
    }
}
