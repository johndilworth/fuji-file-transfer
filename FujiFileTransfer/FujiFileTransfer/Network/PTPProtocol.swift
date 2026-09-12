import Foundation

struct PTPProtocol {
    static let fujiProtocolVersion: UInt32 = 0x8F53E4F2
    static let defaultPort: UInt16 = 55740
    static let defaultHost = "192.168.0.1"
    
    static let fujiGUID: [UInt32] = [0x5D48A5AD, 0x0B7FB287, 0xD0DED5D3, 0x00000000]
    
    enum PacketType: UInt32 {
        case initCommandRequest = 0x00000001
        case initCommandAck = 0x00000002
        case initEventRequest = 0x00000003
        case initEventAck = 0x00000004
        case initFail = 0x00000005
        case cmdRequest = 0x00000006
        case cmdResponse = 0x00000007
        case event = 0x00000008
        case startData = 0x00000009
        case data = 0x0000000A
        case cancel = 0x0000000B
        case endData = 0x0000000C
        case probe = 0x0000000D
        case probeResponse = 0x0000000E
    }
    
    enum OperationCode: UInt16 {
        case getDeviceInfo = 0x1001
        case openSession = 0x1002
        case closeSession = 0x1003
        case getStorageIDs = 0x1004
        case getStorageInfo = 0x1005
        case getNumObjects = 0x1006
        case getObjectHandles = 0x1007
        case getObjectInfo = 0x1008
        case getObject = 0x1009
        case getThumb = 0x100A
        case deleteObject = 0x100B
        case sendObjectInfo = 0x100C
        case sendObject = 0x100D
        case initCapture = 0x101E
        case terminateCapture = 0x1020
        
        case fujiGetObjectVersion = 0x9009
        case fujiGetEvents = 0x900C
    }
    
    enum ResponseCode: UInt16 {
        case ok = 0x2001
        case generalError = 0x2002
        case sessionNotOpen = 0x2003
        case invalidTransactionID = 0x2004
        case operationNotSupported = 0x2005
        case parameterNotSupported = 0x2006
        case incompleteTransfer = 0x2007
        case invalidStorageID = 0x2008
        case invalidObjectHandle = 0x2009
        case devicePropNotSupported = 0x200A
        case invalidObjectFormatCode = 0x200B
        case storeFull = 0x200C
        case objectWriteProtected = 0x200D
        case storeReadOnly = 0x200E
        case accessDenied = 0x200F
        case noThumbnailPresent = 0x2010
        case selfTestFailed = 0x2011
        case partialDeletion = 0x2012
        case storeNotAvailable = 0x2013
        case specificationByFormatUnsupported = 0x2014
        case noValidObjectInfo = 0x2015
        case invalidCodeFormat = 0x2016
        case unknownVendorCode = 0x2017
        case captureAlreadyTerminated = 0x2018
        case deviceBusy = 0x2019
        case invalidParentObject = 0x201A
        case invalidDevicePropFormat = 0x201B
        case invalidDevicePropValue = 0x201C
        case invalidParameter = 0x201D
        case sessionAlreadyOpen = 0x201E
        case transactionCancelled = 0x201F
        case specificationOfDestinationUnsupported = 0x2020
    }
    
    struct InitPacket {
        let length: UInt32 = 0x52
        let type: PacketType = .initCommandRequest
        let version: UInt32 = fujiProtocolVersion
        let guid: [UInt32] = fujiGUID
        let deviceName: String
        
        func encode() -> Data {
            var data = Data()
            data.append(contentsOf: withUnsafeBytes(of: length.littleEndian) { Data($0) })
            data.append(contentsOf: withUnsafeBytes(of: type.rawValue.littleEndian) { Data($0) })
            data.append(contentsOf: withUnsafeBytes(of: version.littleEndian) { Data($0) })
            
            for guidPart in guid {
                data.append(contentsOf: withUnsafeBytes(of: guidPart.littleEndian) { Data($0) })
            }
            
            let utf16Name = deviceName.utf16
            for char in utf16Name {
                data.append(contentsOf: withUnsafeBytes(of: char.littleEndian) { Data($0) })
            }
            data.append(contentsOf: [0x00, 0x00])
            
            let padding = 0x52 - data.count
            if padding > 0 {
                data.append(Data(repeating: 0, count: padding))
            }
            
            return data
        }
    }
    
    struct CommandPacket {
        let length: UInt32
        let type: PacketType = .cmdRequest
        let operation: OperationCode
        let transactionID: UInt32
        let parameters: [UInt32]
        
        func encode() -> Data {
            var data = Data()
            let totalLength = UInt32(12 + 2 + 2 + 4 + parameters.count * 4)
            
            data.append(contentsOf: withUnsafeBytes(of: totalLength.littleEndian) { Data($0) })
            data.append(contentsOf: withUnsafeBytes(of: type.rawValue.littleEndian) { Data($0) })
            
            data.append(contentsOf: withUnsafeBytes(of: UInt32(10 + 2 + 2 + 4 + parameters.count * 4).littleEndian) { Data($0) })
            
            data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
            data.append(contentsOf: withUnsafeBytes(of: operation.rawValue.littleEndian) { Data($0) })
            data.append(contentsOf: withUnsafeBytes(of: transactionID.littleEndian) { Data($0) })
            
            for param in parameters {
                data.append(contentsOf: withUnsafeBytes(of: param.littleEndian) { Data($0) })
            }
            
            return data
        }
    }
    
    struct ResponsePacket {
        let length: UInt32
        let type: PacketType
        let containerLength: UInt32
        let containerType: UInt16
        let responseCode: ResponseCode
        let transactionID: UInt32
        let parameters: [UInt32]
        
        static func decode(from data: Data) throws -> ResponsePacket {
            guard data.count >= 12 else {
                throw TransportError.invalidResponse
            }
            
            let length = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self).littleEndian }
            let typeRaw = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).littleEndian }
            guard let type = PacketType(rawValue: typeRaw) else {
                throw TransportError.invalidResponse
            }
            
            let containerLength = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self).littleEndian }
            
            guard data.count >= 20 else {
                throw TransportError.invalidResponse
            }
            
            let containerType = data.withUnsafeBytes { $0.load(fromByteOffset: 12, as: UInt16.self).littleEndian }
            let responseCodeRaw = data.withUnsafeBytes { $0.load(fromByteOffset: 14, as: UInt16.self).littleEndian }
            let responseCode = ResponseCode(rawValue: responseCodeRaw) ?? .generalError
            let transactionID = data.withUnsafeBytes { $0.load(fromByteOffset: 16, as: UInt32.self).littleEndian }
            
            var parameters: [UInt32] = []
            var offset = 20
            while offset + 4 <= data.count {
                let param = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).littleEndian }
                parameters.append(param)
                offset += 4
            }
            
            return ResponsePacket(
                length: length,
                type: type,
                containerLength: containerLength,
                containerType: containerType,
                responseCode: responseCode,
                transactionID: transactionID,
                parameters: parameters
            )
        }
    }
}
