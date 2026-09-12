import SwiftUI

struct ImportProgressView: View {
    @Binding var progress: [ImportProgress]
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Importing...")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(completedCount)/\(progress.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                ForEach(progress) { item in
                    ImportRowView(item: item)
                }
            }
            .padding()
            .background(Color(.systemGray6))
        }
    }
    
    private var completedCount: Int {
        progress.filter { item in
            if case .completed = item.state {
                return true
            }
            return false
        }.count
    }
}

struct ImportRowView: View {
    let item: ImportProgress
    
    var body: some View {
        HStack(spacing: 12) {
            stateIcon
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.image.filename)
                    .font(.subheadline)
                    .lineLimit(1)
                
                if case .downloading = item.state {
                    ProgressView(value: item.progress, total: 1.0)
                        .progressViewStyle(.linear)
                    
                    Text("\(formatBytes(item.bytesTransferred)) / \(formatBytes(item.totalBytes))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(stateText)
                        .font(.caption)
                        .foregroundColor(stateColor)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var stateIcon: some View {
        Group {
            switch item.state {
            case .pending:
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
            case .downloading:
                ProgressView()
            case .saving:
                ProgressView()
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .frame(width: 20, height: 20)
    }
    
    private var stateText: String {
        switch item.state {
        case .pending:
            return "Waiting..."
        case .downloading:
            return "Downloading..."
        case .saving:
            return "Saving to Photos..."
        case .completed:
            return "Completed"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
    
    private var stateColor: Color {
        switch item.state {
        case .pending:
            return .secondary
        case .downloading, .saving:
            return .accentColor
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
