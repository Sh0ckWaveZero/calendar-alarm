import AVFoundation
import SwiftUI

/// Full-screen sound list: system default, bundled sounds, then the sounds
/// that ship with iOS. Tapping a row selects it and plays a preview.
struct SoundPickerView: View {
    @Binding var selection: String?

    @State private var systemSounds: [AlarmSound] = []
    @State private var isScanning = true
    @State private var player: AVAudioPlayer?

    var body: some View {
        List {
            Section {
                row(id: nil, label: Text("Default"))
            }
            section(Text("App Sounds"), sounds: SoundCatalog.bundled)
            section(Text("iOS Ringtones"), sounds: systemSounds.filter { $0.source == .ringtone })
            section(Text("iOS Sounds"), sounds: systemSounds.filter { $0.source == .systemSound })
            if isScanning {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(Text("Sound"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            systemSounds = await Task.detached { SoundCatalog.system }.value
            isScanning = false
        }
        .onDisappear { player?.stop() }
    }

    @ViewBuilder
    private func section(_ title: Text, sounds: [AlarmSound]) -> some View {
        if !sounds.isEmpty {
            Section {
                ForEach(sounds) { sound in
                    row(id: sound.id, label: Text(verbatim: sound.label), previewURL: sound.url)
                }
            } header: {
                title
            }
        }
    }

    private func row(id: String?, label: Text, previewURL: URL? = nil) -> some View {
        Button {
            selection = id
            preview(previewURL)
        } label: {
            HStack {
                label
                    .foregroundStyle(Theme.text)
                Spacer()
                if selection == id {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func preview(_ url: URL?) {
        player?.stop()
        guard let url else { return }
        // .playback so the preview is audible with the silent switch on.
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}

/// Card row showing the current sound; pushes the full sound list.
struct SoundPickerRow: View {
    let title: Text
    @Binding var selection: String?

    var body: some View {
        NavigationLink {
            SoundPickerView(selection: $selection)
        } label: {
            HStack {
                title
                    .foregroundStyle(Theme.text)
                Spacer()
                (selection.map { Text(verbatim: SoundCatalog.label(for: $0)) } ?? Text("Default"))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.subtext)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
