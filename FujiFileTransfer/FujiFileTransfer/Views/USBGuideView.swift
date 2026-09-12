import SwiftUI

struct USBGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    
                    whenToUseSection
                    
                    setupStepsSection
                    
                    connectionMethodsSection
                }
                .padding()
            }
            .navigationTitle("USB Import Guide")
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
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "cable.connector")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            Text("USB Cable Import")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("For faster, more reliable transfers, you can import photos directly via USB cable using Apple Photos.")
                .foregroundColor(.secondary)
        }
    }
    
    private var whenToUseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When to Use USB")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                bulletPoint("Wi-Fi connection is unstable")
                bulletPoint("Importing many large files (RAW, videos)")
                bulletPoint("Camera battery is low")
                bulletPoint("Faster transfer speeds needed")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var setupStepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Setup")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                setupStep(
                    number: "1",
                    title: "Configure USB Mode",
                    description: "On camera: Menu → Connection Setting → Connection Mode → USB Card Reader"
                )
                
                setupStep(
                    number: "2",
                    title: "Power Settings",
                    description: "Set: Power Supply Off/Comm On (keeps camera on when connected)"
                )
                
                setupStep(
                    number: "3",
                    title: "Connect Cable",
                    description: "Use USB-C cable to connect camera to iPhone"
                )
            }
        }
    }
    
    private var connectionMethodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Methods")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                connectionMethod(
                    icon: "cable.connector",
                    title: "USB-C to USB-C",
                    description: "Direct connection for iPhone 15 and later"
                )
                
                connectionMethod(
                    icon: "cable.connector",
                    title: "Lightning Camera Adapter",
                    description: "Use Apple Lightning to USB Camera Adapter for older iPhones, then connect USB-C cable"
                )
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("After Connecting")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("1. Open the Photos app on iPhone")
                    Text("2. Tap 'Import' tab")
                    Text("3. Select photos to import")
                    Text("4. Tap 'Import Selected' or 'Import All'")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private func setupStep(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .fontWeight(.bold)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func connectionMethod(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .fontWeight(.bold)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}
