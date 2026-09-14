import Foundation
import Network

actor NetworkManager {
    private var connection: NWConnection?
    private var isConnected = false
    private var transactionID: UInt32 = 1
    
    func connect(host: String, port: UInt16) async throws {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        connection = NWConnection(to: endpoint, using: parameters)
        
        return try await withThrowingTaskGroup(of: Void.self) { group in
            var resumed = false
            
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    self.connection?.stateUpdateHandler = { [weak self] state in
                        guard !resumed else { return }
                        
                        switch state {
                        case .ready:
                            resumed = true
                            Task {
                                await self?.setConnected(true)
                                continuation.resume()
                            }
                        case .failed(let error):
                            resumed = true
                            continuation.resume(throwing: TransportError.connectionFailed(error.localizedDescription))
                        case .waiting(let error):
                            print("Connection waiting: \(error)")
                        default:
                            break
                        }
                    }
                    
                    self.connection?.start(queue: .global())
                }
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: 12_000_000_000)
                if !resumed {
                    throw TransportError.timeout
                }
            }
            
            try await group.next()
            group.cancelAll()
        }
    }
    
    func disconnect() async {
        connection?.cancel()
        connection = nil
        await setConnected(false)
    }
    
    private func setConnected(_ connected: Bool) {
        isConnected = connected
    }
    
    func send(data: Data) async throws {
        guard isConnected, let connection = connection else {
            throw TransportError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: TransportError.ioError)
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    func receive(minimumLength: Int = 1, maximumLength: Int = 65536) async throws -> Data {
        guard isConnected, let connection = connection else {
            throw TransportError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: minimumLength, maximumLength: maximumLength) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: TransportError.ioError)
                } else if let data = data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: TransportError.connectionFailed("Connection closed"))
                } else {
                    continuation.resume(throwing: TransportError.invalidResponse)
                }
            }
        }
    }
    
    func receiveExact(length: Int) async throws -> Data {
        var accumulated = Data()
        
        while accumulated.count < length {
            let chunk = try await receive(minimumLength: 1, maximumLength: length - accumulated.count)
            accumulated.append(chunk)
        }
        
        return accumulated
    }
    
    func nextTransactionID() -> UInt32 {
        defer { transactionID += 1 }
        return transactionID
    }
}
