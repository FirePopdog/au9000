import SwiftUI
import UIKit

@main
struct AU9000RemoteApp: App {
    var body: some Scene {
        WindowGroup { LaunchGateView() }
    }
}

private struct LaunchGateView: View {
    @State private var ready = false

    var body: some View {
        ZStack {
            if ready {
                RemoteView()
                    .transition(.opacity)
            } else {
                LaunchSplashView()
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            withAnimation(.easeInOut(duration: 0.35)) { ready = true }
        }
    }
}

private struct LaunchSplashView: View {
    @State private var rotation = 0.0
    private let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red]

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 7)
                    .frame(width: 94, height: 94)
                Circle()
                    .trim(from: 0.08, to: 0.92)
                    .stroke(AngularGradient(colors: colors, center: .center), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(rotation))
                    .frame(width: 94, height: 94)
                Image(systemName: "tv")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.blue)
            }
            VStack(spacing: 6) {
                Text("AU9000 Remote")
                    .font(.title2.bold())
                Text("正在準備遙控器…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { rotation = 360 }
        }
        .accessibilityElement(children: .combine)
    }
}
