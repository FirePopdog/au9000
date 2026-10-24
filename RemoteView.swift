import SwiftUI
import UIKit
import AudioToolbox

private struct SavedTV: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var host: String
}

private struct RemoteShortcut: Identifiable {
    let id: String
    let title: String
    let key: String
    let icon: String
    var tint: Color = .primary

    static let catalog: [RemoteShortcut] = [
        .init(id: "youtube", title: "YouTube", key: "KEY_YOUTUBE", icon: "play.rectangle.fill", tint: .red),
        .init(id: "netflix", title: "Netflix", key: "KEY_NETFLIX", icon: "play.rectangle.fill", tint: .red),
        .init(id: "source", title: "訊源", key: "KEY_SOURCE", icon: "rectangle.on.rectangle"),
        .init(id: "volumeUp", title: "音量＋", key: "KEY_VOLUP", icon: "speaker.plus"),
        .init(id: "volumeDown", title: "音量－", key: "KEY_VOLDOWN", icon: "speaker.minus"),
        .init(id: "mute", title: "靜音", key: "KEY_MUTE", icon: "speaker.slash"),
        .init(id: "home", title: "首頁", key: "KEY_HOME", icon: "house"),
        .init(id: "back", title: "返回", key: "KEY_RETURN", icon: "arrow.uturn.backward"),
        .init(id: "play", title: "播放／暫停", key: "KEY_PLAY", icon: "playpause")
    ]
}

struct RemoteView: View {
    @StateObject private var remote = SamsungRemote()
    @State private var host = UserDefaults.standard.string(forKey: "tvHost") ?? ""
    @State private var showingSettings = false
    @State private var showingTVManager = false
    @State private var savedTVs: [SavedTV] = Self.loadSavedTVs()
    @FocusState private var ipFieldFocused: Bool
    @AppStorage("remoteHaptics") private var hapticsEnabled = true
    @AppStorage("remoteKeySound") private var keySoundEnabled = false
    @AppStorage("remoteQuickShortcutIDs") private var shortcutIDs = "youtube,netflix,source,volumeUp,volumeDown,mute"

    private var selectedShortcuts: [RemoteShortcut] {
        let selected = Set(shortcutIDs.split(separator: ",").map(String.init))
        return RemoteShortcut.catalog.filter { selected.contains($0.id) }
    }

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
                    Text("我的電視").font(.headline)
                    Spacer()
                    Button("管理") { showingTVManager = true }
                        .font(.subheadline)
                }
                if savedTVs.isEmpty {
                    Text("搜尋到電視後會自動收藏，也可以在「管理」中手動新增。")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(savedTVs) { tv in
                        Button {
                            host = tv.host
                            ipFieldFocused = false
                            UserDefaults.standard.set(tv.host, forKey: "tvHost")
                            remote.connect(host: tv.host, name: tv.name)
                        } label: {
                            HStack {
                                Image(systemName: "tv")
                                VStack(alignment: .leading) {
                                    Text(tv.name).font(.body.weight(.medium))
                                    Text(tv.host).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if remote.currentHost.caseInsensitiveCompare(tv.host) == .orderedSame && remote.connected {
                                    Label("使用中", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                                } else {
                                    Image(systemName: "arrow.right.circle")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                }

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
                        rememberTV(name: tv.name, host: tv.host)
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
                    if selectedShortcuts.isEmpty {
                        Text("前往設定選擇要顯示的快捷按鍵。")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(selectedShortcuts) { shortcut in
                                quickKey(shortcut.title, shortcut.key, icon: shortcut.icon, tint: shortcut.tint)
                            }
                        }
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
        .sheet(isPresented: $showingTVManager) {
            SavedTVManagerView(tvs: $savedTVs)
        }
        .onChange(of: savedTVs) { newValue in Self.saveTVs(newValue) }
    }

    private func rememberTV(name: String, host: String) {
        if let index = savedTVs.firstIndex(where: { $0.host.caseInsensitiveCompare(host) == .orderedSame }) {
            savedTVs[index].name = name
        } else {
            savedTVs.append(SavedTV(name: name, host: host))
        }
    }

    private static func loadSavedTVs() -> [SavedTV] {
        if let data = UserDefaults.standard.data(forKey: "savedTVProfiles"),
           let values = try? JSONDecoder().decode([SavedTV].self, from: data) { return values }
        if let host = UserDefaults.standard.string(forKey: "tvHost"), !host.isEmpty {
            return [SavedTV(name: UserDefaults.standard.string(forKey: "tvName_\(host)") ?? "Samsung TV", host: host)]
        }
        return []
    }

    private static func saveTVs(_ tvs: [SavedTV]) {
        guard let data = try? JSONEncoder().encode(tvs) else { return }
        UserDefaults.standard.set(data, forKey: "savedTVProfiles")
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
    @AppStorage("remoteQuickShortcutIDs") private var shortcutIDs = "youtube,netflix,source,volumeUp,volumeDown,mute"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("按鍵回饋") {
                    Toggle("震動回饋", isOn: $hapticsEnabled)
                    Toggle("按鍵音", isOn: $keySoundEnabled)
                }
                Section("首頁快捷列") {
                    ForEach(RemoteShortcut.catalog) { shortcut in
                        Toggle(isOn: shortcutBinding(shortcut)) {
                            Label(shortcut.title, systemImage: shortcut.icon)
                        }
                    }
                    Text("勾選要放在首頁的 App、訊源或常用按鍵。")
                        .font(.footnote).foregroundStyle(.secondary)
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

    private func shortcutBinding(_ shortcut: RemoteShortcut) -> Binding<Bool> {
        Binding(
            get: { Set(shortcutIDs.split(separator: ",").map(String.init)).contains(shortcut.id) },
            set: { enabled in
                var ids = Set(shortcutIDs.split(separator: ",").map(String.init))
                if enabled { ids.insert(shortcut.id) } else { ids.remove(shortcut.id) }
                shortcutIDs = RemoteShortcut.catalog.map(\.id).filter { ids.contains($0) }.joined(separator: ",")
            }
        )
    }
}

private struct SavedTVManagerView: View {
    @Binding var tvs: [SavedTV]
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var host = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("已收藏的電視") {
                    if tvs.isEmpty { Text("尚無收藏電視").foregroundStyle(.secondary) }
                    ForEach($tvs) { $tv in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("電視名稱", text: $tv.name)
                            TextField("IP 位址或主機名稱", text: $tv.host)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                        }
                    }
                    .onDelete { tvs.remove(atOffsets: $0) }
                }
                Section("新增電視") {
                    TextField("名稱，例如客廳電視", text: $name)
                    TextField("IP 位址或主機名稱", text: $host)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Button { addTV() } label: { Label("新增收藏", systemImage: "plus.circle.fill") }
                        .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("我的電視")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addTV() {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = tvs.firstIndex(where: { $0.host.caseInsensitiveCompare(cleanHost) == .orderedSame }) {
            tvs[index].name = cleanName.isEmpty ? tvs[index].name : cleanName
        } else {
            tvs.append(SavedTV(name: cleanName.isEmpty ? "Samsung TV" : cleanName, host: cleanHost))
        }
        name = ""
        host = ""
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
