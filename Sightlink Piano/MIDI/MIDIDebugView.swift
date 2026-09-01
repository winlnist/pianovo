import SwiftUI

struct MIDIDebugView: View {
    @StateObject private var midiService = MIDIInputService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MIDI status: \(midiService.isConnected ? "Connected" : "No device")")
                .font(.headline)

            Text("CoreMIDI source count: \(midiService.systemSourceCount)")
            Text("Connection state: \(midiService.isConnected ? "Connected to at least one source" : "Not connected")")

            if midiService.connectedSources.isEmpty {
                Text("Discovered sources: none")
            } else {
                Text("Discovered sources:")
                    .font(.headline)

                ForEach(Array(midiService.connectedSources.enumerated()), id: \.element.id) { index, source in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("[\(index)] \(source.name)")
                        Text("Endpoint: \(source.id)")
                        Text("Service connected: \(midiService.isConnected(to: source) ? "yes" : "no")")
                    }
                }
            }

            Divider()

            if let event = midiService.lastEvent {
                Text("Last event:")
                    .font(.headline)
                Text("\(label(for: event.kind))")
                Text("\(pitchLabel(event.pitch)) / MIDI \(event.midiNoteNumber)")
                Text("Velocity \(event.velocity)")
                Text("Channel \(event.channel)")
            } else {
                Text("Last event: none")
            }

            Divider()

            Text("Temporary diagnostics:")
                .font(.headline)

            if midiService.diagnosticMessages.isEmpty {
                Text("No diagnostics yet")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(midiService.diagnosticMessages.enumerated()), id: \.offset) { _, message in
                            Text(message)
                                .font(.caption.monospaced())
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func label(for kind: MIDIInputEventKind) -> String {
        switch kind {
        case .notePressed:
            return "Note On"
        case .noteReleased:
            return "Note Off"
        }
    }

    private func pitchLabel(_ pitch: Pitch) -> String {
        "\(pitch.letter.rawValue)\(pitch.octave)"
    }
}

#Preview("MIDI Debug") {
    MIDIDebugView()
}
