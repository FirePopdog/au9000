import Foundation
import Combine

struct DiscoveredTV: Identifiable {
    let name: String
    let host: String
    var id: String { host }
}

@MainActor
final class SamsungRemote: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    @Published private(set) var connected = false
    @Published private(set) var connecting = false
    @Published private(set) var status = "搜尋電視，或輸入 IP 位址連線。"
    @Published private(set) var discoveredTVs: [DiscoveredTV] = []
    @Published private(set) var isSearching = false
    @Published private(set) var discoveryStatus = "尚未搜尋。"
    private var session: URLSession!
    private var socket: URLSessionWebSocketTask?
    private var host = ""
    private var token: String? { UserDefaults.standard.string(forKey: "tvToken_\(host)") }
    private var browser: NetServiceBrowser?
    private var services: [NetService] = []
    private var searchTimeout: Task<Void, Never>?

    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    func searchForTVs() {
        searchTimeout?.cancel()
        browser?.stop()
        browser = nil
        services.removeAll()
        discoveredTVs.removeAll()
        isSearching = true
        discoveryStatus = "正在搜尋同一個 Wi-Fi 網路上的 Samsung 電視…"

        let serviceBrowser = NetServiceBrowser()
        serviceBrowser.delegate = self
        browser = serviceBrowser
        serviceBrowser.searchForServices(ofType: "_samsungmsf._tcp.", inDomain: "local.")

        searchTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.browser?.stop()
            self.browser = nil
            self.isSearching = false
            self.discoveryStatus = self.discoveredTVs.isEmpty
                ? "找不到電視。請確認同一個 Wi-Fi，或手動輸入 IP。"
                : "找到 \(self.discoveredTVs.count) 台電視。"
        }
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

extension SamsungRemote: NetServiceBrowserDelegate, NetServiceDelegate {
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService,
                                       moreComing: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.browser === browser else { return }
            self.services.append(service)
            service.delegate = self
            service.resolve(withTimeout: 5)
        }
    }

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        let serviceName = sender.name
        guard let resolvedHost = sender.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              !resolvedHost.isEmpty else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let tv = DiscoveredTV(name: serviceName, host: resolvedHost)
            guard !self.discoveredTVs.contains(where: { $0.host == tv.host }) else { return }
            self.discoveredTVs.append(tv)
            self.discoveredTVs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.discoveryStatus = "找到 \(self.discoveredTVs.count) 台電視。"
        }
    }

    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        let error = String(describing: errorDict)
        Task { @MainActor [weak self] in
            guard let self, self.browser === browser else { return }
            self.isSearching = false
            self.browser = nil
            self.discoveryStatus = "搜尋失敗：\(error)"
        }
    }
}
