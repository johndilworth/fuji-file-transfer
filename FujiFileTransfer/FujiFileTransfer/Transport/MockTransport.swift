import Foundation
import SwiftUI

class MockTransport: CameraTransport {
    private(set) var connectionState: CameraConnectionState = .disconnected
    var onStateChanged: ((CameraConnectionState) -> Void)?
    
    private let mockImages: [CameraImage]
    private let shouldSimulateError: Bool
    private let connectionDelay: TimeInterval
    
    init(shouldSimulateError: Bool = false, connectionDelay: TimeInterval = 0.8) {
        self.shouldSimulateError = shouldSimulateError
        self.connectionDelay = connectionDelay
        
        self.mockImages = [
            CameraImage(
                id: 1,
                filename: "DSCF0001.JPG",
                thumbnailData: Self.generatePlaceholderThumbnail(text: "🏔️\nLandscape"),
                fullImageData: Self.generatePlaceholderImage(text: "DSCF0001"),
                fileSize: 4_500_000,
                createdDate: Date().addingTimeInterval(-7200),
                format: .jpeg
            ),
            CameraImage(
                id: 2,
                filename: "DSCF0002.JPG",
                thumbnailData: Self.generatePlaceholderThumbnail(text: "📷\nPortrait"),
                fullImageData: Self.generatePlaceholderImage(text: "DSCF0002"),
                fileSize: 5_200_000,
                createdDate: Date().addingTimeInterval(-6000),
                format: .jpeg
            ),
            CameraImage(
                id: 3,
                filename: "DSCF0003.JPG",
                thumbnailData: Self.generatePlaceholderThumbnail(text: "🌆\nSunset"),
                fullImageData: Self.generatePlaceholderImage(text: "DSCF0003"),
                fileSize: 3_800_000,
                createdDate: Date().addingTimeInterval(-4800),
                format: .jpeg
            ),
            CameraImage(
                id: 4,
                filename: "DSCF0004.RAF",
                thumbnailData: Self.generatePlaceholderThumbnail(text: "📸\nRAW"),
                fullImageData: Self.generatePlaceholderImage(text: "DSCF0004\nRAW FILE"),
                fileSize: 52_000_000,
                createdDate: Date().addingTimeInterval(-3600),
                format: .raw
            ),
            CameraImage(
                id: 5,
                filename: "DSCF0005.JPG",
                thumbnailData: Self.generatePlaceholderThumbnail(text: "🌸\nMacro"),
                fullImageData: Self.generatePlaceholderImage(text: "DSCF0005"),
                fileSize: 4_100_000,
                createdDate: Date().addingTimeInterval(-2400),
                format: .jpeg
            ),
            CameraImage(
                id: 6,
                filename: "DSCF0006.JPG",
                thumbnailData: Self.generatePlaceholderThumbnail(text: "🏙️\nStreet"),
                fullImageData: Self.generatePlaceholderImage(text: "DSCF0006"),
                fileSize: 4_700_000,
                createdDate: Date().addingTimeInterval(-1200),
                format: .jpeg
            ),
            CameraImage(
                id: 7,
                filename: "DSCF0007.JPG",
                thumbnailData: Self.generatePlaceholderThumbnail(text: "🐦\nWildlife"),
                fullImageData: Self.generatePlaceholderImage(text: "DSCF0007"),
                fileSize: 6_200_000,
                createdDate: Date().addingTimeInterval(-600),
                format: .jpeg
            ),
            CameraImage(
                id: 8,
                filename: "DSCF0008.JPG",
                thumbnailData: Self.generatePlaceholderThumbnail(text: "🎭\nArt"),
                fullImageData: Self.generatePlaceholderImage(text: "DSCF0008"),
                fileSize: 4_900_000,
                createdDate: Date().addingTimeInterval(-300),
                format: .jpeg
            )
        ]
    }
    
    func connect() async throws {
        updateConnectionState(.connecting)
        
        try await Task.sleep(nanoseconds: UInt64(connectionDelay * 1_000_000_000))
        
        if shouldSimulateError {
            updateConnectionState(.error("Mock connection error"))
            throw TransportError.connectionFailed("Simulated error for testing")
        }
        
        updateConnectionState(.connected)
    }
    
    func disconnect() async {
        updateConnectionState(.disconnected)
    }
    
    func listImages() async throws -> [CameraImage] {
        guard case .connected = connectionState else {
            throw TransportError.notConnected
        }
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        return mockImages
    }
    
    func downloadThumbnail(objectID: UInt32) async throws -> Data {
        guard case .connected = connectionState else {
            throw TransportError.notConnected
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        guard let image = mockImages.first(where: { $0.id == objectID }),
              let thumbnailData = image.thumbnailData else {
            throw TransportError.protocolError("Object not found")
        }
        
        return thumbnailData
    }
    
    func downloadImage(objectID: UInt32, progress: ((UInt64, UInt64) -> Void)?) async throws -> Data {
        guard case .connected = connectionState else {
            throw TransportError.notConnected
        }
        
        guard let image = mockImages.first(where: { $0.id == objectID }),
              let imageData = image.fullImageData else {
            throw TransportError.protocolError("Object not found")
        }
        
        let totalSize = image.fileSize
        let chunkSize: UInt64 = 524288
        var transferred: UInt64 = 0
        
        while transferred < totalSize {
            let sleepTime: UInt64 = image.format == .raw ? 100_000_000 : 40_000_000
            try await Task.sleep(nanoseconds: sleepTime)
            
            transferred = min(transferred + chunkSize, totalSize)
            progress?(transferred, totalSize)
        }
        
        return imageData
    }
    
    private func updateConnectionState(_ newState: CameraConnectionState) {
        connectionState = newState
        onStateChanged?(newState)
    }
    
    private static func generatePlaceholderThumbnail(text: String) -> Data {
        let size = CGSize(width: 200, height: 150)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            UIColor.systemGray5.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            
            let string = NSAttributedString(string: text, attributes: attrs)
            let stringSize = string.size()
            let rect = CGRect(
                x: (size.width - stringSize.width) / 2,
                y: (size.height - stringSize.height) / 2,
                width: stringSize.width,
                height: stringSize.height
            )
            string.draw(in: rect)
        }
        
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
    
    private static func generatePlaceholderImage(text: String) -> Data {
        let size = CGSize(width: 1600, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            UIColor.systemGray4.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 120, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            
            let string = NSAttributedString(string: text, attributes: attrs)
            let stringSize = string.size()
            let rect = CGRect(
                x: (size.width - stringSize.width) / 2,
                y: (size.height - stringSize.height) / 2,
                width: stringSize.width,
                height: stringSize.height
            )
            string.draw(in: rect)
        }
        
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}
