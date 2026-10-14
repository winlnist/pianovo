import SwiftUI

/// Guidance only: choosing a destination never starts a programme or writes practice records.
struct GettingStartedScreen: View {
    let onFinish: (AppDestination?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Practise at your own pace")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Use Pianovo without an account. Your plans, exercises and saved records are stored locally; Pianovo does not upload them or provide cloud sync yet.")
                }

                Section("Connect a MIDI piano") {
                    Text("Turn on your piano and connect its USB MIDI port to your iPad or iPhone with a compatible data cable or adapter. The tested iPad Pro and Yamaha P-45 setup uses a USB-B to USB-C cable.")
                    Text("Open Practice, choose Treble Reading or Bass Reading, and check the MIDI status. Play the displayed note in the correct octave: a correct note advances the exercise; an incorrect note keeps the current note highlighted.")
                    Text("If you see No MIDI Piano, check the piano's power, cable and adapter, then reconnect. A detected MIDI source alone does not prove notes are arriving; try playing a displayed note.")
                        .foregroundStyle(.secondary)
                    Text("Tap the score to reveal the controls. Changing mode or range, or choosing Reset Session, restarts standalone Practice and clears its temporary statistics.")
                    destinationButton("Open Practice", destination: .practice)
                }

                Section("Choose your programme") {
                    Text("In Today, Start Programme begins the original twelve-week programme at Week 1, Day 1. Your position is saved and does not advance with the calendar. Reference documents cannot be opened in Pianovo yet.")
                    Text("For your own plan, create written exercises in Library, arrange them in a Programme template, then choose Use as my programme. Today → Programmes lets you switch back while keeping each saved position.")
                    Text("Your authored exercises are written guidance; they do not launch generated MIDI Practice. The original programme's generated sight-reading assignments can start an assigned session.")
                        .foregroundStyle(.secondary)
                    destinationButton("Open Today", destination: .today)
                    destinationButton("Open Library", destination: .library)
                }

                Section("Know what is saved") {
                    Text("Completion is your own report, separate from mastery. Ending an assigned session saves its context and times, but does not complete the assignment or advance your programme.")
                    Text("Standalone Practice statistics and the assigned-session summary are temporary. History shows saved records and private notes; it does not store numeric accuracy or tempo statistics.")
                    Text("Unsaved assigned sessions may be lost if the app closes. You can reopen this guide with Getting started in the main toolbar.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Getting started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onFinish(nil) }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func destinationButton(_ title: String, destination: AppDestination) -> some View {
        Button(title) { onFinish(destination) }
            .frame(minHeight: 44)
            .accessibilityHint("Closes this guide and opens \(destination.title). Does not start or save a session.")
    }
}

#Preview {
    GettingStartedScreen { _ in }
}
