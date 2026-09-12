import Foundation
import SwiftUI

@MainActor
class ConnectionViewModel: ObservableObject {
    @Published var connectionState: CameraConnectionState = .disconnected
    @Published var errorMessage: String?
    @Published var useMockMode: Bool = true
    
    private var transport: CameraTransport?
    
    var isConnected: Bool {
        if case .connected = connectionState {
            return true
        }
        return false
    }
    
    var isConnecting: Bool {
        if case .connecting = connectionState {
            return true
        }
        return false
    }
    
    init() {
        #if targetEnvironment(simulator)
        useMockMode = true
        #else
        useMockMode = false
        #endif
    }
    
    func connect() async {
        errorMessage = nil
        
        if useMockMode {
            transport = MockTransport()
        } else {
            transport = FujiWiFiTransport()
        }
        
        transport?.onStateChanged = { [weak self] newState in
            Task { @MainActor in
                self?.connectionState = newState
                if case .error(let message) = newState {
                    self?.errorMessage = message
                }
            }
        }
        
        do {
            try await transport?.connect()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func disconnect() async {
        await transport?.disconnect()
        transport = nil
    }
    
    func getTransport() -> CameraTransport? {
        return transport
    }
}
