import Foundation
import ShowdownKit

/// The raw websocket to a Showdown server. Reconnection policy lives in `AppModel`.
@MainActor
final class ShowdownConnection {
    enum State: Equatable {
        case disconnected, connecting, connected
    }

    var onFrame: ((ServerFrame) -> Void)?
    var onStateChange: ((State) -> Void)?

    private(set) var state: State = .disconnected {
        didSet { if oldValue != state { onStateChange?(state) } }
    }

    private let session = URLSession(configuration: .default)
    private var task: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var generation = 0

    func connect(to url: URL) {
        disconnect()
        generation += 1
        let current = generation
        state = .connecting
        let task = session.webSocketTask(with: url)
        // The formats list and battle logs on rejoin can be large.
        task.maximumMessageSize = 32 * 1024 * 1024
        self.task = task
        task.resume()
        receive(current)
        pingTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.ping(current) }
        }
    }

    func disconnect() {
        generation += 1
        pingTimer?.invalidate()
        pingTimer = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .disconnected
    }

    func send(_ text: String) {
        task?.send(.string(text)) { _ in }
    }

    private func receive(_ current: Int) {
        task?.receive { [weak self] result in
            Task { @MainActor in
                guard let self, current == self.generation else { return }
                switch result {
                case .success(let message):
                    self.state = .connected
                    switch message {
                    case .string(let text):
                        self.onFrame?(ServerFrame(raw: text))
                    case .data(let data):
                        self.onFrame?(ServerFrame(raw: String(decoding: data, as: UTF8.self)))
                    @unknown default:
                        break
                    }
                    self.receive(current)
                case .failure:
                    self.dropped(current)
                }
            }
        }
    }

    private func ping(_ current: Int) {
        guard current == generation else { return }
        task?.sendPing { [weak self] error in
            guard error != nil else { return }
            Task { @MainActor in self?.dropped(current) }
        }
    }

    private func dropped(_ current: Int) {
        guard current == generation else { return }
        disconnect()
    }
}
