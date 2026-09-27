import SwiftUI

struct GrandStaffDebugView: View {
    private let pitches = [
        Pitch(.c, octave: 2),
        Pitch(.e, octave: 2),
        Pitch(.g, octave: 2),
        Pitch(.c, octave: 3),
        Pitch(.b, octave: 3),
        Pitch(.c, octave: 4),
        Pitch(.e, octave: 4),
        Pitch(.g, octave: 4),
        Pitch(.c, octave: 5),
        Pitch(.a, octave: 5),
        Pitch(.c, octave: 6)
    ]

    @State private var selectedPitch = Pitch(.c, octave: 4)

    var body: some View {
        VStack(spacing: 20) {
            GrandStaffView(pitch: selectedPitch)
                .frame(maxWidth: 680)

            Picker("Pitch", selection: $selectedPitch) {
                ForEach(pitches, id: \.self) { pitch in
                    Text(Self.label(for: pitch)).tag(pitch)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private static func label(for pitch: Pitch) -> String {
        "\(pitch.letter.rawValue)\(pitch.octave)"
    }
}
