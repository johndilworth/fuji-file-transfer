import SwiftUI

struct ThumbnailGridView: View {
    @StateObject private var viewModel = ImportViewModel()
    let transport: CameraTransport
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 4)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.images.isEmpty {
                emptyView
            } else {
                imageGridView
            }
            
            if viewModel.isImporting {
                ImportProgressView(progress: $viewModel.importProgress)
                    .transition(.move(edge: .bottom))
            }
        }
        .task {
            await viewModel.loadImages(from: transport)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading images...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No images found")
                .font(.title3)
                .foregroundColor(.secondary)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var imageGridView: some View {
        VStack(spacing: 0) {
            toolbarView
                .padding()
                .background(Color(.systemBackground))
            
            Divider()
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(viewModel.images) { image in
                        ThumbnailCell(
                            image: image,
                            isSelected: viewModel.selectedImageIDs.contains(image.id)
                        )
                        .onTapGesture {
                            viewModel.toggleSelection(image.id)
                        }
                    }
                }
                .padding(4)
            }
        }
    }
    
    private var toolbarView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(viewModel.images.count) images")
                    .font(.headline)
                
                if viewModel.newImagesCount > 0 {
                    Text("• \(viewModel.newImagesCount) new")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if viewModel.hasSelection {
                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }
                    .font(.subheadline)
                } else {
                    Menu {
                        Button("Select All") {
                            viewModel.selectAll()
                        }
                        Button("Select All New") {
                            viewModel.selectAllNew()
                        }
                    } label: {
                        Text("Select")
                            .font(.subheadline)
                    }
                }
            }
            
            if viewModel.hasSelection {
                HStack(spacing: 12) {
                    Text("\(viewModel.selectedImageIDs.count) selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Import Selected") {
                        viewModel.importSelected()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else if viewModel.newImagesCount > 0 {
                HStack {
                    Spacer()
                    
                    Button("Import All New (\(viewModel.newImagesCount))") {
                        viewModel.importAllNew()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }
}

struct ThumbnailCell: View {
    let image: CameraImage
    let isSelected: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                if let thumbnailData = image.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .background(Circle().fill(Color.white))
                        .padding(4)
                }
                
                if image.isImported {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .background(Circle().fill(Color.white.opacity(0.9)))
                                .font(.caption)
                            Spacer()
                        }
                        .padding(4)
                    }
                }
                
                if image.format == .raw {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("RAW")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        .padding(4)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .cornerRadius(2)
    }
}
