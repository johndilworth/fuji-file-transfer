import SwiftUI

struct ConnectionView: View {
    @StateObject private var viewModel = ConnectionViewModel()
    @State private var showingUSBGuide = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if viewModel.isConnected {
                    connectedContent
                } else {
                    disconnectedContent
                }
            }
            .padding()
            .navigationTitle("Fuji File Transfer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingUSBGuide = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingUSBGuide) {
                USBGuideView()
            }
        }
    }
    
    private var disconnectedContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("Connect to Fujifilm X-T5")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Camera Setup:")
                    .font(.headline)
                
                setupStep(number: "1", text: "On camera, go to: Menu → Connection Setting → Wireless Settings → Wireless Communication")
                setupStep(number: "2", text: "Select \"Connect to Smartphone\" and tap OK")
                setupStep(number: "3", text: "Join the camera's Wi-Fi network on your iPhone")
                setupStep(number: "4", text: "Return to this app and tap Connect")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            #if targetEnvironment(simulator)
            Toggle("Use Mock Mode (Simulator)", isOn: $viewModel.useMockMode)
                .padding(.horizontal)
            #endif
            
            Button {
                Task {
                    await viewModel.connect()
                }
            } label: {
                if viewModel.isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Connect to Camera")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isConnecting)
            
            Spacer()
        }
    }
    
    private var connectedContent: some View {
        VStack {
            if let transport = viewModel.getTransport() {
                ThumbnailGridView(transport: transport)
            }
        }
    }
    
    private func setupStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .fontWeight(.bold)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}
