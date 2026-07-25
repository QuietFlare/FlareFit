//
//  MusicManager.swift
//  FlareFit
//

import MediaPlayer
import SwiftUI

/// Controls workout music via the system music player (Apple Music / local library).
/// Playback continues in the Music app, so lock screen and Control Center work too.
@MainActor
final class MusicManager: ObservableObject {
    static let shared = MusicManager()

    let player = MPMusicPlayerController.systemMusicPlayer

    @Published private(set) var isPlaying = false
    @Published private(set) var nowPlayingTitle: String?
    @Published private(set) var hasWorkoutQueue = false

    private init() {
        player.beginGeneratingPlaybackNotifications()
        let center = NotificationCenter.default
        center.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        center.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func refresh() {
        isPlaying = player.playbackState == .playing
        nowPlayingTitle = player.nowPlayingItem?.title
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        refresh()
    }

    func pauseMusic() {
        player.pause()
        refresh()
    }

    /// Queue the picked songs without starting playback — the workout starts them.
    func queueWorkoutMusic(_ collection: MPMediaItemCollection) {
        player.setQueue(with: collection)
        player.prepareToPlay()
        hasWorkoutQueue = true
        refresh()
    }

    /// Called when a workout session begins. Resumes the chosen queue (or
    /// whatever was last playing) — does nothing if no music was ever chosen.
    func startWorkoutMusic() {
        guard hasWorkoutQueue || player.nowPlayingItem != nil else { return }
        player.play()
        refresh()
    }
}

/// Wraps the system media picker so the user can queue up songs or playlists.
struct MusicPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = true
        picker.prompt = "Choose your workout music"
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let dismiss: () -> Void

        init(dismiss: @escaping () -> Void) {
            self.dismiss = dismiss
        }

        func mediaPicker(_ mediaPicker: MPMediaPickerController,
                         didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            Task { @MainActor in
                MusicManager.shared.queueWorkoutMusic(mediaItemCollection)
            }
            dismiss()
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            dismiss()
        }
    }
}
