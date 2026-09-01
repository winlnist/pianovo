enum MIDIMessageDecoder {
    static func decodeUMPWord(_ word: UInt32) -> MIDIInputEvent? {
        let messageType = UInt8((word >> 28) & 0xF)

        switch messageType {
        case 0x2:
            return decodeMIDI1ChannelVoiceUMP(word)
        default:
            return nil
        }
    }

    static func decodeMIDI1ChannelVoice(status: UInt8, data1: UInt8, data2: UInt8) -> MIDIInputEvent? {
        let statusType = status & 0xF0
        let channel = Int(status & 0x0F) + 1
        let midiNoteNumber = Int(data1)
        let velocity = Int(data2)

        guard let pitch = Pitch(midiNoteNumber: midiNoteNumber) else {
            return nil
        }

        switch statusType {
        case 0x80:
            return MIDIInputEvent(
                kind: .noteReleased,
                pitch: pitch,
                midiNoteNumber: midiNoteNumber,
                velocity: velocity,
                channel: channel
            )
        case 0x90:
            return MIDIInputEvent(
                kind: velocity == 0 ? .noteReleased : .notePressed,
                pitch: pitch,
                midiNoteNumber: midiNoteNumber,
                velocity: velocity,
                channel: channel
            )
        default:
            return nil
        }
    }

    private static func decodeMIDI1ChannelVoiceUMP(_ word: UInt32) -> MIDIInputEvent? {
        let status = UInt8((word >> 16) & 0xFF)
        let data1 = UInt8((word >> 8) & 0xFF)
        let data2 = UInt8(word & 0xFF)

        return decodeMIDI1ChannelVoice(status: status, data1: data1, data2: data2)
    }
}
