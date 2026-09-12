import Foundation

protocol CameraTransport: AnyObject {
    var connectionState: CameraConnectionState { get }
    var onStateChanged: ((CameraConnectionState) -> Void)? { get set }
    
    func connect() async throws
    func disconnect() async
    func listImages() async throws -> [CameraImage]
    func downloadThumbnail(objectID: UInt32) async throws -> Data
    func downloadImage(objectID: UInt32, progress: ((UInt64, UInt64) -> Void)?) async throws -> Data
}

extension CameraTransport {
    func updateState(_ newState: CameraConnectionState) {
        onStateChanged?(newState)
    }
}
