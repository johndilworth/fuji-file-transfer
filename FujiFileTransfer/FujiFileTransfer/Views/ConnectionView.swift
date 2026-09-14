import SwiftUI

struct ConnectionView: View {
    @StateObject private var viewModel = ConnectionViewModel()
    @State private var showingSetupHelp = false
    @State private var showingUSBGuide = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusBar
                
                if viewModel.isConnected {
                    if let transport = viewModel.getTransport() {
                        ThumbnailGridView(transport: transport)
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle("Fuji File Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingSetupHelp = true
                        } label: {
                            Label("Camera Setup", systemImage: "camera")
                        }
                        
                        Button {
                            showingUSBGuide = true
                        } label: {
                            Label("USB Import Guide", systemImage: "cable.connector")
                        }
                        
                        #if targetEnvironment(simulator)
                        Divider()
                        Toggle("Mock Mode", isOn: $viewModel.useMockMode)
                        #endif
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSetupHelp) {
                SetupHelpView()
            }
            .sheet(isPresented: $showingUSBGuide) {
                USBGuideView()
            }
            .task {
                await viewModel.connect()
            }
        }
    }
    
    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .symbolEffect(.pulse, isActive: viewModel.isConnecting)
                .contentTransition(.symbolEffect(.replace))
            
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(statusColor)
                .contentTransition(.numericText())
            
            Spacer()
            
            if viewModel.isConnecting {
                ProgressView()
                    .controlSize(.small)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background.secondary)
        .animation(.easeInOut(duration: 0.3), value: viewModel.connectionState)
    }
    
    private var statusIcon: String {
        switch viewModel.connectionState {
        case .connected:
            return viewModel.useMockMode ? "wand.and.stars.inverse" : "wifi"
        case .connecting:
            return "antenna.radiowaves.left.and.right"
        case .error:
            return "exclamationmark.triangle"
        case .disconnected:
            return "camera"
        }
    }
    
    private var statusColor: Color {
        switch viewModel.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .error:
            return .red
        case .disconnected:
            return .secondary
        }
    }
    
    private var statusText: String {
        switch viewModel.connectionState {
        case .connected:
            return viewModel.useMockMode ? "Demo Mode — Sample Photos" : "Connected"
        case .connecting:
            return "Connecting..."
        case .error(let message):
            return "Error: \(message)"
        case .disconnected:
            return "Not Connected"
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 12) {
                Text(emptyStateTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                if case .error = viewModel.connectionState {
                    Button {
                        Task {
                            await viewModel.retry()
                        }
                    } label: {
                        Label("Retry Connection", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button {
                    showingSetupHelp = true
                } label: {
                    Text(case .error = viewModel.connectionState ? "Setup Help" : "Camera Setup")
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private var emptyStateTitle: String {
        switch viewModel.connectionState {
        case .error:
            return "Connection Failed"
        case .disconnected, .connecting:
            return "No Photos"
        case .connected:
            return "No Photos"
        }
    }
    
    private var emptyStateMessage: String {
        switch viewModel.connectionState {
        case .error(let message):
            return message
        case .disconnected, .connecting:
            return "Camera not connected"
        case .connected:
            return "No photos available"
        }
    }
}

struct SetupHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Camera Setup")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("On your Fujifilm X-T5:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. Menu → Connection Setting → Wireless Settings")
                        Text("2. Select \"Connect to Smartphone\" → OK")
                        Text("3. Camera creates Wi-Fi network")
                    }
                    .font(.subheadline)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    Text("On your iPhone:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. Settings → Wi-Fi")
                        Text("2. Join camera's network (X-T5_XXXX)")
                        Text("3. Return to this app")
                    }
                    .font(.subheadline)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    Text("App will connect automatically and show photos.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Setup Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
