nonisolated enum MIDIInputEventKind: Hashable {
    case notePressed
    case noteReleased
}

nonisolated struct MIDIInputEvent: Hashable {
    let kind: MIDIInputEventKind
    let pitch: Pitch
    let midiNoteNumber: Int
    let velocity: Int
    let channel: Int

    var practiceInput: PracticeInput? {
        switch kind {
        case .notePressed:
            .notePressed(pitch)
        case .noteReleased:
            nil
        }
    }
}

nonisolated struct MIDISource: Identifiable, Hashable {
    let id: Int
    let name: String
}
