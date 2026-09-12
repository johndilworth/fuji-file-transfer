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
                compactProgressView
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
            
            ZStack(alignment: .bottom) {
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
                    .padding(.bottom, 80)
                }
                
                importButton
            }
        }
    }
    
    private var importButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if viewModel.hasSelection {
                    viewModel.importSelected()
                } else {
                    viewModel.importAllNew()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                    .symbolEffect(.bounce, value: viewModel.selectedImageIDs.count)
                
                Group {
                    if viewModel.hasSelection {
                        Text("Import \(viewModel.selectedImageIDs.count)")
                    } else if viewModel.newImagesCount > 0 {
                        Text("Import All New")
                    } else {
                        Text("Select Photos")
                    }
                }
                .contentTransition(.numericText())
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.hasSelection && viewModel.newImagesCount == 0)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background)
        .animation(.easeInOut(duration: 0.25), value: viewModel.hasSelection)
        .animation(.easeInOut(duration: 0.25), value: viewModel.newImagesCount)
    }
    
    private var toolbarView: some View {
        HStack {
            Text("\(viewModel.images.count) photos")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .contentTransition(.numericText())
            
            if viewModel.newImagesCount > 0 {
                Text("• \(viewModel.newImagesCount) new")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .contentTransition(.numericText())
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            
            Spacer()
            
            if viewModel.hasSelection {
                Button("Clear") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.deselectAll()
                    }
                }
                .font(.subheadline)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else if viewModel.newImagesCount > 0 {
                Button("Select All New") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectAllNew()
                    }
                }
                .font(.subheadline)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background.secondary)
        .animation(.easeInOut(duration: 0.25), value: viewModel.hasSelection)
        .animation(.easeInOut(duration: 0.25), value: viewModel.newImagesCount)
    }
}

    private var compactProgressView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Importing \(completedCount) of \(viewModel.importProgress.count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())
                
                if let current = currentImport {
                    Text(current.image.filename)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            
            Spacer()
            
            Button("Cancel") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.cancelImport()
                }
            }
            .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background.secondary)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: completedCount)
    }
    
    private var completedCount: Int {
        viewModel.importProgress.filter { item in
            if case .completed = item.state {
                return true
            }
            return false
        }.count
    }
    
    private var currentImport: ImportProgress? {
        viewModel.importProgress.first { item in
            if case .downloading = item.state {
                return true
            }
            return false
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
                        .opacity(isSelected ? 1.0 : (image.isImported ? 0.6 : 1.0))
                } else {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                        }
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .tint)
                        .shadow(radius: 2)
                        .padding(8)
                        .transition(.scale.combined(with: .opacity))
                }
                
                if !isSelected && !image.isImported {
                    VStack {
                        Spacer()
                        HStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                                .shadow(radius: 1)
                            Spacer()
                        }
                        .padding(8)
                    }
                    .transition(.opacity)
                }
                
                if image.format == .raw {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("RAW")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .padding(8)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
