import Foundation

// TODO: Protocol Implementation Notes
// - This is a clean-room implementation based on libfuji and public protocol docs
// - X-T5 specific behavior may differ from other Fujifilm cameras
// - Some operations may require user confirmation on camera screen (OpenSession, RemoteMode)
// - Error recovery and reconnection logic is basic - may need camera power cycle
// - Timeout handling is minimal - long operations may hang without progress

class FujiWiFiTransport: CameraTransport {
    private(set) var connectionState: CameraConnectionState = .disconnected
    var onStateChanged: ((CameraConnectionState) -> Void)?
    
    private let networkManager = NetworkManager()
    private let host: String
    private let port: UInt16
    private var sessionID: UInt32 = 0
    
    init(host: String = PTPProtocol.defaultHost, port: UInt16 = PTPProtocol.defaultPort) {
        self.host = host
        self.port = port
    }
    
    func connect() async throws {
        updateConnectionState(.connecting)
        
        do {
            try await networkManager.connect(host: host, port: port)
            try await performFujiInitWithRetry()
            try await openSession()
            
            updateConnectionState(.connected)
        } catch let error as TransportError {
            let message = error.localizedDescription ?? "Unknown connection error"
            updateConnectionState(.error(message))
            throw error
        } catch {
            updateConnectionState(.error("Connection failed: \(error.localizedDescription)"))
            throw TransportError.connectionFailed(error.localizedDescription)
        }
    }
    
    func disconnect() async {
        if sessionID != 0 {
            try? await closeSession()
        }
        await networkManager.disconnect()
        updateConnectionState(.disconnected)
    }
    
    func listImages() async throws -> [CameraImage] {
        guard case .connected = connectionState else {
            throw TransportError.notConnected
        }
        
        let storageIDs = try await getStorageIDs()
        guard !storageIDs.isEmpty else {
            throw TransportError.protocolError("No storage found on camera")
        }
        
        var allImages: [CameraImage] = []
        var failedObjectCount = 0
        
        for storageID in storageIDs {
            let objectHandles = try await getObjectHandles(storageID: storageID)
            
            for handle in objectHandles {
                do {
                    let imageInfo = try await getObjectInfo(objectHandle: handle)
                    if imageInfo.format != .unknown && imageInfo.format != .movie {
                        allImages.append(imageInfo)
                    }
                } catch {
                    failedObjectCount += 1
                }
            }
        }
        
        if allImages.isEmpty && failedObjectCount > 0 {
            throw TransportError.protocolError("Failed to retrieve image info (\(failedObjectCount) objects)")
        }
        
        return allImages
    }
    
    func downloadThumbnail(objectID: UInt32) async throws -> Data {
        guard case .connected = connectionState else {
            throw TransportError.notConnected
        }
        
        return try await getThumbnail(objectHandle: objectID)
    }
    
    func downloadImage(objectID: UInt32, progress: ((UInt64, UInt64) -> Void)?) async throws -> Data {
        guard case .connected = connectionState else {
            throw TransportError.notConnected
        }
        
        return try await getObject(objectHandle: objectID, progress: progress)
    }
    
    private func updateConnectionState(_ newState: CameraConnectionState) {
        connectionState = newState
        onStateChanged?(newState)
    }
    
    private func performFujiInitWithRetry(maxAttempts: Int = 2) async throws {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                try await performFujiInit()
                return
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: 800_000_000)
                }
            }
        }
        
        throw lastError ?? TransportError.protocolError("Init failed after \(maxAttempts) attempts")
    }
    
    private func performFujiInit() async throws {
        let initPacket = PTPProtocol.InitPacket(deviceName: "FujiFileTransfer")
        let data = initPacket.encode()
        
        try await networkManager.send(data: data)
        
        let responseHeader = try await networkManager.receiveExact(length: 4)
        let responseLength = responseHeader.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        
        guard responseLength >= 4 else {
            throw TransportError.invalidResponse
        }
        
        let remainingData = try await networkManager.receiveExact(length: Int(responseLength) - 4)
        let fullResponse = responseHeader + remainingData
        
        let typeRaw = fullResponse.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).littleEndian }
        guard typeRaw == PTPProtocol.PacketType.initCommandAck.rawValue else {
            throw TransportError.protocolError("Init failed - expected ACK, got type \(typeRaw)")
        }
    }
    
    private func openSession() async throws {
        sessionID = 1
        
        let command = PTPProtocol.CommandPacket(
            length: 0,
            operation: .openSession,
            transactionID: await networkManager.nextTransactionID(),
            parameters: [sessionID]
        )
        
        try await networkManager.send(data: command.encode())
        
        let responseData = try await networkManager.receiveExact(length: 12)
        let fullResponseData = responseData + (try await networkManager.receive(minimumLength: 1, maximumLength: 8192))
        
        let response = try PTPProtocol.ResponsePacket.decode(from: fullResponseData)
        
        guard response.responseCode == .ok || response.responseCode == .sessionAlreadyOpen else {
            throw TransportError.protocolError("OpenSession failed: \(response.responseCode)")
        }
    }
    
    private func closeSession() async throws {
        let command = PTPProtocol.CommandPacket(
            length: 0,
            operation: .closeSession,
            transactionID: await networkManager.nextTransactionID(),
            parameters: []
        )
        
        try await networkManager.send(data: command.encode())
        _ = try? await networkManager.receive(minimumLength: 1, maximumLength: 8192)
        
        sessionID = 0
    }
    
    private func getStorageIDs() async throws -> [UInt32] {
        let command = PTPProtocol.CommandPacket(
            length: 0,
            operation: .getStorageIDs,
            transactionID: await networkManager.nextTransactionID(),
            parameters: []
        )
        
        try await networkManager.send(data: command.encode())
        
        let dataHeader = try await networkManager.receiveExact(length: 12)
        let dataLength = dataHeader.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        
        guard dataLength >= 12 else {
            throw TransportError.invalidResponse
        }
        
        let remainingData = try await networkManager.receiveExact(length: Int(dataLength) - 12)
        let fullData = dataHeader + remainingData
        
        let arrayData = fullData.dropFirst(12)
        guard arrayData.count >= 4 else {
            return []
        }
        
        let count = arrayData.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        var storageIDs: [UInt32] = []
        
        var offset = 4
        for _ in 0..<count {
            if offset + 4 <= arrayData.count {
                let storageID = arrayData.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).littleEndian }
                storageIDs.append(storageID)
                offset += 4
            }
        }
        
        let responseData = try await networkManager.receiveExact(length: 12)
        _ = try PTPProtocol.ResponsePacket.decode(from: responseData + (try? await networkManager.receive(minimumLength: 0, maximumLength: 100) ?? Data()))
        
        return storageIDs
    }
    
    private func getObjectHandles(storageID: UInt32, objectFormat: UInt32 = 0xFFFFFFFF, parentObject: UInt32 = 0xFFFFFFFF) async throws -> [UInt32] {
        let command = PTPProtocol.CommandPacket(
            length: 0,
            operation: .getObjectHandles,
            transactionID: await networkManager.nextTransactionID(),
            parameters: [storageID, objectFormat, parentObject]
        )
        
        try await networkManager.send(data: command.encode())
        
        let dataHeader = try await networkManager.receiveExact(length: 12)
        let dataLength = dataHeader.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        
        guard dataLength >= 12 else {
            throw TransportError.invalidResponse
        }
        
        let remainingData = try await networkManager.receiveExact(length: Int(dataLength) - 12)
        let fullData = dataHeader + remainingData
        
        let arrayData = fullData.dropFirst(12)
        guard arrayData.count >= 4 else {
            return []
        }
        
        let count = arrayData.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        var handles: [UInt32] = []
        
        var offset = 4
        for _ in 0..<count {
            if offset + 4 <= arrayData.count {
                let handle = arrayData.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).littleEndian }
                handles.append(handle)
                offset += 4
            }
        }
        
        let responseData = try await networkManager.receiveExact(length: 12)
        _ = try PTPProtocol.ResponsePacket.decode(from: responseData + (try? await networkManager.receive(minimumLength: 0, maximumLength: 100) ?? Data()))
        
        return handles
    }
    
    private func getObjectInfo(objectHandle: UInt32) async throws -> CameraImage {
        let command = PTPProtocol.CommandPacket(
            length: 0,
            operation: .getObjectInfo,
            transactionID: await networkManager.nextTransactionID(),
            parameters: [objectHandle]
        )
        
        try await networkManager.send(data: command.encode())
        
        let dataHeader = try await networkManager.receiveExact(length: 12)
        let dataLength = dataHeader.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        
        guard dataLength >= 12 else {
            throw TransportError.invalidResponse
        }
        
        let remainingData = try await networkManager.receiveExact(length: Int(dataLength) - 12)
        let infoData = remainingData
        
        guard infoData.count >= 52 else {
            throw TransportError.invalidResponse
        }
        
        let objectFormat = infoData.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt16.self).littleEndian }
        let imageSize = infoData.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt64.self).littleEndian }
        
        var offset = 52
        let filename = readPTPString(from: infoData, at: &offset)
        
        let responseData = try await networkManager.receiveExact(length: 12)
        _ = try PTPProtocol.ResponsePacket.decode(from: responseData + (try? await networkManager.receive(minimumLength: 0, maximumLength: 100) ?? Data()))
        
        return CameraImage(
            id: objectHandle,
            filename: filename,
            thumbnailData: nil,
            fullImageData: nil,
            fileSize: imageSize,
            createdDate: nil,
            format: CameraImage.ImageFormat.from(objectFormat: objectFormat)
        )
    }
    
    private func getThumbnail(objectHandle: UInt32) async throws -> Data {
        let command = PTPProtocol.CommandPacket(
            length: 0,
            operation: .getThumb,
            transactionID: await networkManager.nextTransactionID(),
            parameters: [objectHandle]
        )
        
        try await networkManager.send(data: command.encode())
        
        let dataHeader = try await networkManager.receiveExact(length: 12)
        let dataLength = dataHeader.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        
        guard dataLength >= 12 else {
            throw TransportError.invalidResponse
        }
        
        let thumbnailData = try await networkManager.receiveExact(length: Int(dataLength) - 12)
        
        let responseData = try await networkManager.receiveExact(length: 12)
        _ = try PTPProtocol.ResponsePacket.decode(from: responseData + (try? await networkManager.receive(minimumLength: 0, maximumLength: 100) ?? Data()))
        
        return thumbnailData
    }
    
    private func getObject(objectHandle: UInt32, progress: ((UInt64, UInt64) -> Void)?) async throws -> Data {
        let command = PTPProtocol.CommandPacket(
            length: 0,
            operation: .getObject,
            transactionID: await networkManager.nextTransactionID(),
            parameters: [objectHandle]
        )
        
        try await networkManager.send(data: command.encode())
        
        let dataHeader = try await networkManager.receiveExact(length: 12)
        let dataLength = dataHeader.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        
        guard dataLength >= 12 else {
            throw TransportError.invalidResponse
        }
        
        let totalBytes = UInt64(dataLength - 12)
        var objectData = Data()
        var received: UInt64 = 0
        
        let chunkSize = 65536
        while received < totalBytes {
            let remaining = Int(totalBytes - received)
            let toRead = min(remaining, chunkSize)
            
            let chunk = try await networkManager.receiveExact(length: toRead)
            objectData.append(chunk)
            received += UInt64(chunk.count)
            
            progress?(received, totalBytes)
        }
        
        let responseData = try await networkManager.receiveExact(length: 12)
        _ = try PTPProtocol.ResponsePacket.decode(from: responseData + (try? await networkManager.receive(minimumLength: 0, maximumLength: 100) ?? Data()))
        
        return objectData
    }
    
    private func readPTPString(from data: Data, at offset: inout Int) -> String {
        guard offset < data.count else { return "" }
        
        let length = Int(data[offset])
        offset += 1
        
        guard length > 0, offset + (length - 1) * 2 <= data.count else {
            return ""
        }
        
        var utf16Chars: [UInt16] = []
        for _ in 0..<(length - 1) {
            let char = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self).littleEndian }
            utf16Chars.append(char)
            offset += 2
        }
        
        return String(utf16CodeUnits: utf16Chars, count: utf16Chars.count)
    }
}
