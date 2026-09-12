import Foundation
import SwiftUI

@MainActor
class ImportViewModel: ObservableObject {
    @Published var images: [CameraImage] = []
    @Published var selectedImageIDs: Set<UInt32> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var importProgress: [ImportProgress] = []
    @Published var isImporting = false
    
    private let photosService = PhotosImportService()
    private var transport: CameraTransport?
    private var importTask: Task<Void, Never>?
    
    var hasSelection: Bool {
        !selectedImageIDs.isEmpty
    }
    
    var newImagesCount: Int {
        images.filter { !$0.isImported }.count
    }
    
    func loadImages(from transport: CameraTransport) async {
        self.transport = transport
        isLoading = true
        errorMessage = nil
        
        do {
            var loadedImages = try await transport.listImages()
            
            let importedIDs = await photosService.getImportedIDs()
            for index in loadedImages.indices {
                loadedImages[index].isImported = importedIDs.contains(loadedImages[index].id)
            }
            
            images = loadedImages
            
            await loadThumbnails(for: loadedImages)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func toggleSelection(_ imageID: UInt32) {
        if selectedImageIDs.contains(imageID) {
            selectedImageIDs.remove(imageID)
        } else {
            selectedImageIDs.insert(imageID)
        }
    }
    
    func selectAll() {
        selectedImageIDs = Set(images.map { $0.id })
    }
    
    func deselectAll() {
        selectedImageIDs.removeAll()
    }
    
    func selectAllNew() {
        selectedImageIDs = Set(images.filter { !$0.isImported }.map { $0.id })
    }
    
    func importSelected() {
        let imagesToImport = images.filter { selectedImageIDs.contains($0.id) }
        startImport(images: imagesToImport)
    }
    
    func importAllNew() {
        let imagesToImport = images.filter { !$0.isImported }
        startImport(images: imagesToImport)
    }
    
    func cancelImport() {
        importTask?.cancel()
        importTask = nil
        isImporting = false
        importProgress.removeAll()
    }
    
    private func startImport(images: [CameraImage]) {
        guard let transport = transport, !images.isEmpty else { return }
        
        isImporting = true
        errorMessage = nil
        importProgress = images.map { image in
            ImportProgress(image: image, totalBytes: image.fileSize, state: .pending)
        }
        
        importTask = Task {
            for (index, image) in images.enumerated() {
                guard !Task.isCancelled else { break }
                
                importProgress[index].state = .downloading
                
                do {
                    let imageData = try await transport.downloadImage(objectID: image.id) { transferred, total in
                        Task { @MainActor in
                            self.importProgress[index].bytesTransferred = transferred
                            self.importProgress[index].totalBytes = total
                        }
                    }
                    
                    importProgress[index].state = .saving
                    
                    try await photosService.saveImage(imageData, filename: image.filename)
                    await photosService.markAsImported(image.id)
                    
                    if let imageIndex = self.images.firstIndex(where: { $0.id == image.id }) {
                        self.images[imageIndex].isImported = true
                    }
                    
                    importProgress[index].state = .completed
                    
                } catch {
                    importProgress[index].state = .failed(error.localizedDescription)
                }
            }
            
            isImporting = false
            selectedImageIDs.removeAll()
        }
    }
    
    private func loadThumbnails(for images: [CameraImage]) async {
        guard let transport = transport else { return }
        
        for (index, image) in images.enumerated() {
            guard image.thumbnailData == nil else { continue }
            
            if let thumbnailData = try? await transport.downloadThumbnail(objectID: image.id) {
                self.images[index] = CameraImage(
                    id: image.id,
                    filename: image.filename,
                    thumbnailData: thumbnailData,
                    fullImageData: image.fullImageData,
                    fileSize: image.fileSize,
                    createdDate: image.createdDate,
                    format: image.format,
                    isImported: image.isImported
                )
            }
        }
    }
}
