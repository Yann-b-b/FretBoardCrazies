struct DrillPrompt: Equatable {
    let direction: DrillDirection
    let targetNote: Note
    let string: Int

    var itemKey: DrillItemKey {
        DrillItemKey(noteName: targetNote.name, string: string)
    }
}
