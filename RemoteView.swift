import SwiftUI

struct RemoteView: View {
    @StateObject private var remote = SamsungRemote()
    @State private var host = UserDefaults.standard.string(forKey: "tvHost") ?? ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Samsung TV Remote").font(.title2.bold())
            Text("AU9000 · 同一個 Wi-Fi 網路").foregroundStyle(.secondary)
            HStack {
                TextField("電視 IP 位址", text: $host)
                    .textInputAutocapitalization(.never).keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Button(remote.connected ? "中斷" : "連線") {
                    UserDefaults.standard.set(host, forKey: "tvHost")
                    remote.connected ? remote.disconnect() : remote.connect(host: host)
                }.buttonStyle(.borderedProminent)
            }
            Text(remote.status).font(.footnote).foregroundStyle(.secondary)

            Button { remote.key("KEY_POWER") } label: { Label("電源", systemImage: "power") }
                .buttonStyle(.bordered)
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
                VStack { key("音量＋", "KEY_VOLUP", wide: true); key("音量－", "KEY_VOLDOWN", wide: true) }
                VStack { key("頻道＋", "KEY_CHUP", wide: true); key("頻道－", "KEY_CHDOWN", wide: true) }
                key("靜音", "KEY_MUTE", wide: true)
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: 520)
    }

    private func key(_ title: String, _ code: String, wide: Bool = false) -> some View {
        Button(title) { remote.key(code) }
            .buttonStyle(.bordered)
            .frame(minWidth: wide ? 78 : 52, minHeight: 44)
            .disabled(!remote.connected)
    }
}
