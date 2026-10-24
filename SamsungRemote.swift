import Foundation
import Combine

@MainActor
final class SamsungRemote: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    @Published private(set) var connected = false
    @Published private(set) var connecting = false
    @Published private(set) var status = "輸入電視 IP 後連線，首次連線請在電視上選擇允許。"
    private var session: URLSession!
    private var socket: URLSessionWebSocketTask?
    private var host = ""
    private var token: String? { UserDefaults.standard.string(forKey: "tvToken_\(host)") }

    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    func connect(host: String) {
        let clean = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { status = "請輸入電視 IP 位址。"; return }
        socket?.cancel(with: .goingAway, reason: nil)
        self.host = clean
        var components = URLComponents()
        components.scheme = "wss"
        components.host = clean
        components.port = 8002
        components.path = "/api/v2/channels/samsung.remote.control"
        var query = [URLQueryItem(name: "name", value: Data("AU9000 iPhone Remote".utf8).base64EncodedString())]
        if let token { query.append(URLQueryItem(name: "token", value: token)) }
        components.queryItems = query
        guard let url = components.url else { status = "IP 位址格式不正確。"; return }
        connecting = true
        connected = false
        status = "正在連線…"
        let task = session.webSocketTask(with: url)
        socket = task
        task.resume()
        receiveNext()

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard let self, self.host == clean, self.connecting else { return }
            self.socket?.cancel(with: .goingAway, reason: nil)
            self.socket = nil
            self.connecting = false
            self.status = "連線逾時，請確認 IP 與 Wi-Fi 後重試。"
        }
    }

    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        connected = false
        connecting = false
        status = "已中斷連線。"
    }

    func key(_ code: String) {
        guard connected, let socket else { return }
        let message: [String: Any] = ["method": "ms.remote.control", "params": [
            "Cmd": "Click", "DataOfCmd": code, "Option": "false", "TypeOfRemote": "SendRemoteKey"
        ]]
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let text = String(data: data, encoding: .utf8) else { return }
        socket.send(.string(text)) { [weak self] error in
            if let error { Task { @MainActor in self?.status = "傳送失敗：\(error.localizedDescription)" } }
        }
    }

    private func receiveNext() {
        socket?.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case .failure(let error):
                    self.connected = false
                    self.connecting = false
                    self.status = "連線中斷：\(error.localizedDescription)"
                case .success(let message):
                    if case .string(let text) = message { self.handle(text) }
                    self.receiveNext()
                }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        if root["event"] as? String == "ms.channel.connect" {
            if let payload = root["data"] as? [String: Any], let newToken = payload["token"] as? String {
                UserDefaults.standard.set(newToken, forKey: "tvToken_\(host)")
            }
            connected = true
            connecting = false
            status = "已連線。可以開始操作電視。"
        } else if root["event"] as? String == "ms.channel.unauthorized" {
            connected = false
            connecting = false
            status = "電視尚未允許連線，請在電視畫面選擇允許後重試。"
        }
    }

    // Samsung TVs commonly use a self-signed certificate for their local secure WebSocket.
    // Trust is scoped to the TV connection; this app sends only remote key commands.
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        Task { @MainActor in self.status = "等待電視確認連線…" }
    }
}
