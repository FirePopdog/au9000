import SwiftUI

struct RemoteView: View {
    @StateObject private var remote = SamsungRemote()
    @State private var host = UserDefaults.standard.string(forKey: "tvHost") ?? ""
    @FocusState private var ipFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Samsung TV Remote").font(.title2.bold())
                Text("AU9000 · 同一個 Wi-Fi 網路").foregroundStyle(.secondary)

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
                    } label: {
                        Label("搜尋", systemImage: "magnifyingglass")
                    }
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

                HStack {
                    Text("搜尋到的電視").font(.headline)
                    Spacer()
                    Text(remote.discoveryStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                ForEach(remote.discoveredTVs) { tv in
                    Button {
                        host = tv.host
                        ipFieldFocused = false
                        UserDefaults.standard.set(tv.host, forKey: "tvHost")
                        remote.connect(host: tv.host)
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

                Button { remote.key("KEY_POWER") } label: { Label("電源", systemImage: "power") }
                    .buttonStyle(.bordered)
                    .disabled(!remote.connected)

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
    }

    private func key(_ title: String, _ code: String, wide: Bool = false) -> some View {
        Button(title) { remote.key(code) }
            .buttonStyle(.bordered)
            .frame(minWidth: wide ? 78 : 52, minHeight: 44)
            .disabled(!remote.connected)
    }
}

private struct RGBLoadingView: View {
    @State private var rotation = 0.0
    private let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red]

    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.92)
            .stroke(
                AngularGradient(colors: colors, center: .center),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .rotationEffect(.degrees(rotation))
            .frame(width: 24, height: 24)
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .accessibilityLabel("正在連線")
    }
}
