import Foundation
import SwiftUI

enum CameraConnectionState {
    case disconnected
    case connecting
    case connected
    case error(String)
}

struct CameraImage: Identifiable {
    let id: UInt32
    let filename: String
    let thumbnailData: Data?
    let fullImageData: Data?
    let fileSize: UInt64
    let createdDate: Date?
    let format: ImageFormat
    var isImported: Bool = false
    
    enum ImageFormat: String {
        case jpeg = "JPEG"
        case raw = "RAF"
        case heif = "HEIF"
        case movie = "MOV"
        case unknown = "Unknown"
        
        static func from(objectFormat: UInt16) -> ImageFormat {
            switch objectFormat {
            case 0x3801: return .jpeg
            case 0x3800, 0xB101: return .raw
            case 0x3802: return .heif
            case 0x300B, 0x300C: return .movie
            default: return .unknown
            }
        }
    }
}

struct ImportProgress: Identifiable {
    let id = UUID()
    let image: CameraImage
    var bytesTransferred: UInt64 = 0
    var totalBytes: UInt64
    var state: ImportState = .pending
    
    enum ImportState {
        case pending
        case downloading
        case saving
        case completed
        case failed(String)
    }
    
    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesTransferred) / Double(totalBytes)
    }
}

enum TransportError: LocalizedError {
    case connectionFailed(String)
    case notConnected
    case invalidResponse
    case timeout
    case protocolError(String)
    case ioError
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .notConnected:
            return "Not connected to camera"
        case .invalidResponse:
            return "Invalid response from camera"
        case .timeout:
            return "Connection timed out"
        case .protocolError(let reason):
            return "Protocol error: \(reason)"
        case .ioError:
            return "I/O error"
        case .cancelled:
            return "Operation cancelled"
        }
    }
}
