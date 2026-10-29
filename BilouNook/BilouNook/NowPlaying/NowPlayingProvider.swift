import Foundation

enum NowPlayingCommand: Equatable {
    case togglePlayPause
    case next
    case previous
    case seek(TimeInterval)
}

protocol NowPlayingProvider: AnyObject {
    var identifier: String { get }
    var isAvailable: Bool { get }

    func start(
        onUpdate: @escaping (NowPlayingSnapshot?) -> Void,
        onFailure: @escaping () -> Void
    )
    func stop()
    func send(_ command: NowPlayingCommand)
}
