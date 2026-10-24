import SwiftUI
import UIKit
import AudioToolbox

struct RemoteView: View {
    @StateObject private var remote = SamsungRemote()
    @State private var host = UserDefaults.standard.string(forKey: "tvHost") ?? ""
    @State private var showingSettings = false
    @FocusState private var ipFieldFocused: Bool
    @AppStorage("remoteHaptics") private var hapticsEnabled = true
    @AppStorage("remoteKeySound") private var keySoundEnabled = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Samsung TV Remote").font(.title2.bold())
                        Text("AU9000 · 同一個 Wi-Fi 網路").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("設定")
                }

                HStack {
                    TextField("電視 IP 位址或主機名稱", text: $host)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($ipFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { ipFieldFocused = false }
                    Button {
                        ipFieldFocused = false
                        remote.searchForTVs()
                    } label: { Label("搜尋", systemImage: "magnifyingglass") }
                        .buttonStyle(.bordered)
                }

                HStack(spacing: 10) {
                    Circle()
                        .fill(remote.connected ? Color.green : (remote.connecting ? Color.orange : Color.gray))
                        .frame(width: 10, height: 10)
                    Text(remote.connected ? "已連線" : (remote.connecting ? "連線中" : (remote.isSearching ? "搜尋中" : "未連線")))
                        .font(.subheadline.weight(.semibold))
                    if remote.connecting || remote.isSearching { RGBLoadingView() }
                    Spacer(minLength: 4)
                    Text(remote.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 32)

                tvInfoCard

                HStack {
                    Text("搜尋到的電視").font(.headline)
                    Spacer()
                    Button(remote.isSearching ? "搜尋中…" : "重新搜尋") {
                        ipFieldFocused = false
                        remote.searchForTVs()
                    }
                    .disabled(remote.isSearching)
                }
                ForEach(remote.discoveredTVs) { tv in
                    Button {
                        host = tv.host
                        ipFieldFocused = false
                        UserDefaults.standard.set(tv.host, forKey: "tvHost")
                        UserDefaults.standard.set(tv.name, forKey: "tvName_\(tv.host)")
                        remote.connect(host: tv.host, name: tv.name)
                    } label: {
                        HStack {
                            Image(systemName: "tv")
                            VStack(alignment: .leading) {
                                Text(tv.name).font(.body.weight(.medium))
                                Text(tv.host).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
                Text(remote.discoveryStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button(remote.connected ? "中斷連線" : "連線") {
                        ipFieldFocused = false
                        UserDefaults.standard.set(host, forKey: "tvHost")
                        remote.connected ? remote.disconnect() : remote.connect(host: host)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(remote.connecting || (!remote.connected && host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

                    if !remote.connected && !remote.connecting && !host.isEmpty {
                        Button("快速重連") {
                            ipFieldFocused = false
                            remote.connect(host: host)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Button { sendKey("KEY_POWER") } label: { Label("電源", systemImage: "power") }
                    .buttonStyle(.bordered)
                    .disabled(!remote.connected)

                VStack(alignment: .leading, spacing: 10) {
                    Text("快捷按鍵").font(.headline)
                    HStack(spacing: 8) {
                        quickKey("YouTube", "KEY_YOUTUBE", icon: "play.rectangle.fill", tint: .red)
                        quickKey("Netflix", "KEY_NETFLIX", icon: "play.rectangle.fill", tint: .red)
                        quickKey("訊源", "KEY_SOURCE", icon: "rectangle.on.rectangle")
                    }
                    HStack(spacing: 8) {
                        quickKey("音量＋", "KEY_VOLUP", icon: "speaker.plus")
                        quickKey("音量－", "KEY_VOLDOWN", icon: "speaker.minus")
                        quickKey("靜音", "KEY_MUTE", icon: "speaker.slash")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("觸控板").font(.headline)
                    TouchPadView(
                        onMove: { sendKey($0) },
                        onSelect: { sendKey("KEY_ENTER") }
                    )
                    .frame(height: 145)
                    .disabled(!remote.connected)
                    .opacity(remote.connected ? 1 : 0.55)
                }

                VStack(spacing: 10) {
                    key("▲", "KEY_UP")
                    HStack(spacing: 38) {
                        key("◀", "KEY_LEFT")
                        key("確定", "KEY_ENTER", wide: true)
                        key("▶", "KEY_RIGHT")
                    }
                    key("▼", "KEY_DOWN")
                }
                HStack(spacing: 24) {
                    key("返回", "KEY_RETURN", wide: true)
                    key("首頁", "KEY_HOME", wide: true)
                    key("播放／暫停", "KEY_PLAY", wide: true)
                }
                HStack(spacing: 24) {
                    VStack {
                        key("音量＋", "KEY_VOLUP", wide: true)
                        key("音量－", "KEY_VOLDOWN", wide: true)
                    }
                    VStack {
                        key("頻道＋", "KEY_CHUP", wide: true)
                        key("頻道－", "KEY_CHDOWN", wide: true)
                    }
                    key("靜音", "KEY_MUTE", wide: true)
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { ipFieldFocused = false }
            }
        }
        .sheet(isPresented: $showingSettings) { RemoteSettingsView() }
    }

    private var tvInfoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "tv.and.hifispeaker.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 42, height: 42)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(remote.connectedTVName.isEmpty ? "尚未選擇電視" : remote.connectedTVName)
                    .font(.subheadline.weight(.semibold))
                Text(remote.currentHost.isEmpty ? "輸入 IP 或搜尋附近的電視" : remote.currentHost)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(remote.connected ? "已連線" : (remote.connecting ? "連線中" : "離線"))
                .font(.caption.weight(.medium))
                .foregroundStyle(remote.connected ? .green : (remote.connecting ? .orange : .secondary))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.06)))
    }

    private func sendKey(_ code: String) {
        if hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        if keySoundEnabled { AudioServicesPlaySystemSound(1104) }
        remote.key(code)
    }

    private func quickKey(_ title: String, _ code: String, icon: String, tint: Color = .primary) -> some View {
        Button { sendKey(code) } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3).foregroundStyle(tint)
                Text(title).font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
        }
        .buttonStyle(.bordered)
        .disabled(!remote.connected)
    }

    private func key(_ title: String, _ code: String, wide: Bool = false) -> some View {
        Button(title) { sendKey(code) }
            .buttonStyle(.bordered)
            .frame(minWidth: wide ? 78 : 52, minHeight: 44)
            .disabled(!remote.connected)
    }
}

private struct TouchPadView: View {
    let onMove: (String) -> Void
    let onSelect: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color(uiColor: .secondarySystemBackground), Color.blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.blue.opacity(0.25), lineWidth: 1))
            VStack(spacing: 8) {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("滑動移動 · 點一下確定")
                    .font(.subheadline.weight(.medium))
                Text("觸控板")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture(perform: onSelect)
        .gesture(DragGesture(minimumDistance: 20).onEnded { value in
            let dx = value.translation.width
            let dy = value.translation.height
            guard max(abs(dx), abs(dy)) >= 30 else { return }
            if abs(dx) > abs(dy) { onMove(dx > 0 ? "KEY_RIGHT" : "KEY_LEFT") }
            else { onMove(dy > 0 ? "KEY_DOWN" : "KEY_UP") }
        })
        .accessibilityElement()
        .accessibilityLabel("觸控板。滑動移動，點一下確定")
    }
}

private struct RemoteSettingsView: View {
    @AppStorage("remoteHaptics") private var hapticsEnabled = true
    @AppStorage("remoteKeySound") private var keySoundEnabled = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("按鍵回饋") {
                    Toggle("震動回饋", isOn: $hapticsEnabled)
                    Toggle("按鍵音", isOn: $keySoundEnabled)
                }
                Section {
                    Text("快捷列提供 YouTube、Netflix、訊源、音量和靜音按鍵。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("遙控器設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct RGBLoadingView: View {
    @State private var rotation = 0.0
    private let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red]

    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.92)
            .stroke(AngularGradient(colors: colors, center: .center), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(rotation))
            .frame(width: 24, height: 24)
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { rotation = 360 }
            }
            .accessibilityLabel("正在連線")
    }
}
