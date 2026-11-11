import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var enabled: Bool?
    @State private var videoEnabled: Bool?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: enabled == true ? "checkmark.shield.fill" : "shield.slash")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(enabled == true ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))

            if enabled == true {
                Text("Ads are blocked").font(.title.bold())
                Text("That's it. Cardea works inside Safari on its own —\nyou can close this window.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else if enabled == false {
                Text("Turn on Cardea in Safari").font(.title.bold())
                instructions
            }
            Spacer()
            if enabled != nil { videoRow }
        }
        .padding(32)
        .frame(maxWidth: 480)
        .animation(.default, value: enabled)
        .animation(.default, value: videoEnabled)
        .task { await refresh() }
        // Re-check whenever the user comes back from Settings.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refresh() }
        }
        #endif
    }

    @ViewBuilder private var instructions: some View {
        #if os(macOS)
        Text("Check the box next to Cardea in Safari's Extensions settings.")
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
        Button("Open Safari Settings") { Blocker.openSafariSettings() }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        #else
        VStack(alignment: .leading, spacing: 10) {
            Label("Open the **Settings** app", systemImage: "1.circle.fill")
            Label("Go to **Safari › Extensions**", systemImage: "2.circle.fill")
            Label("Tap **Cardea** and turn it on", systemImage: "3.circle.fill")
        }
        .font(.body)
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        #endif
    }

    /// Optional second switch: ads inside YouTube videos.
    private var videoRow: some View {
        HStack(spacing: 12) {
            Image(systemName: videoEnabled == true ? "play.circle.fill" : "play.circle")
                .font(.title)
                .foregroundStyle(videoEnabled == true ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("YouTube video ads").font(.headline)
                #if os(macOS)
                Text(videoEnabled == true ? "Blocked by Cardea Video." : "Optional: turn on Cardea Video and allow it on youtube.com.")
                    .font(.callout).foregroundStyle(.secondary)
                #else
                Text("Optional: in **Safari › Extensions**, turn on **Cardea Video** and allow it on youtube.com.")
                    .font(.callout).foregroundStyle(.secondary)
                #endif
            }
            Spacer(minLength: 0)
            #if os(macOS)
            if videoEnabled != true {
                Button("Turn On") { Blocker.openSafariSettings(for: Blocker.video) }
            }
            #endif
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    private func refresh() async {
        enabled = await Blocker.adsEnabled()
        videoEnabled = await Blocker.videoEnabled()
    }
}
