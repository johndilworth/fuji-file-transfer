import Foundation
import Photos
import UIKit

actor PhotosImportService {
    private var importedObjectIDs: Set<UInt32> = []
    private let userDefaultsKey = "com.fujifile.imported_object_ids"
    
    init() {
        loadImportedIDs()
    }
    
    func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }
    
    func saveImage(_ imageData: Data, filename: String) async throws {
        guard await requestPhotoLibraryPermission() else {
            throw TransportError.protocolError("Photo library permission denied")
        }
        
        guard let image = UIImage(data: imageData) else {
            throw TransportError.protocolError("Invalid image data")
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: nil)
        }
    }
    
    func markAsImported(_ objectID: UInt32) {
        importedObjectIDs.insert(objectID)
        saveImportedIDs()
    }
    
    func isImported(_ objectID: UInt32) -> Bool {
        return importedObjectIDs.contains(objectID)
    }
    
    func getImportedIDs() -> Set<UInt32> {
        return importedObjectIDs
    }
    
    func clearImportedIDs() {
        importedObjectIDs.removeAll()
        saveImportedIDs()
    }
    
    private func loadImportedIDs() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let ids = try? JSONDecoder().decode(Set<UInt32>.self, from: data) {
            importedObjectIDs = ids
        }
    }
    
    private func saveImportedIDs() {
        if let data = try? JSONEncoder().encode(importedObjectIDs) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
