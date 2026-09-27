import Testing
@testable import Pianovo

struct MIDIMessageDecoderTests {
    @Test func decodesNoteOn() throws {
        let event = try #require(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0x90, data1: 60, data2: 93))

        #expect(event.kind == .notePressed)
        #expect(event.pitch == Pitch(.c, octave: 4))
        #expect(event.midiNoteNumber == 60)
        #expect(event.velocity == 93)
        #expect(event.channel == 1)
    }

    @Test func decodesNoteOff() throws {
        let event = try #require(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0x80, data1: 60, data2: 64))

        #expect(event.kind == .noteReleased)
        #expect(event.pitch == Pitch(.c, octave: 4))
        #expect(event.midiNoteNumber == 60)
        #expect(event.velocity == 64)
        #expect(event.channel == 1)
    }

    @Test func noteOnVelocityZeroBecomesNoteOff() throws {
        let event = try #require(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0x90, data1: 60, data2: 0))

        #expect(event.kind == .noteReleased)
        #expect(event.pitch == Pitch(.c, octave: 4))
        #expect(event.velocity == 0)
    }

    @Test func unsupportedMessagesAreIgnored() {
        #expect(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0xB0, data1: 64, data2: 127) == nil)
        #expect(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0xE0, data1: 0, data2: 64) == nil)
    }

    @Test func midiReferenceNotesUseMusicDomainConversion() throws {
        #expect(try #require(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0x90, data1: 36, data2: 80)).pitch == Pitch(.c, octave: 2))
        #expect(try #require(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0x90, data1: 48, data2: 80)).pitch == Pitch(.c, octave: 3))
        #expect(try #require(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0x90, data1: 60, data2: 80)).pitch == Pitch(.c, octave: 4))
        #expect(try #require(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0x90, data1: 72, data2: 80)).pitch == Pitch(.c, octave: 5))
        #expect(try #require(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0x90, data1: 84, data2: 80)).pitch == Pitch(.c, octave: 6))
    }

    @Test func decodesDifferentChannelsWithoutRestrictingToChannelOne() throws {
        let event = try #require(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0x9F, data1: 60, data2: 100))

        #expect(event.kind == .notePressed)
        #expect(event.channel == 16)
    }

    @Test func decodesMIDI1UniversalMIDIPacketWord() throws {
        let noteOnC4Channel1 = UInt32(0x20903C5D)
        let event = try #require(MIDIMessageDecoder.decodeUMPWord(noteOnC4Channel1))

        #expect(event.kind == .notePressed)
        #expect(event.pitch == Pitch(.c, octave: 4))
        #expect(event.midiNoteNumber == 60)
        #expect(event.velocity == 93)
    }

    @Test func ignoresUnsupportedUMPMessageTypes() {
        let utilityMessage = UInt32(0x00903C5D)

        #expect(MIDIMessageDecoder.decodeUMPWord(utilityMessage) == nil)
    }

    @Test func practiceEngineFacingConversionContainsNoCoreMIDITypes() throws {
        let noteOn = try #require(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0x90, data1: 60, data2: 93))
        let noteOff = try #require(MIDIMessageDecoder.decodeMIDI1ChannelVoice(status: 0x80, data1: 60, data2: 64))

        #expect(noteOn.practiceInput == .notePressed(Pitch(.c, octave: 4)))
        #expect(noteOff.practiceInput == nil)
    }
}
