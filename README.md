# Fuji File Transfer

An iOS app for transferring photos from Fujifilm X-T5 cameras to iPhone over Wi-Fi, designed to be faster and less frustrating than Fujifilm's XApp.

## 📱 Without a Mac This Week?

**You can still contribute and make progress:**

- ✅ **Review & merge PRs** from GitHub mobile — CI validates all builds automatically
- ✅ **Watch Actions tab** for build status — green checkmarks mean code compiles
- ✅ **Read and improve docs** — README, DEVELOPMENT.md are editable from phone
- ✅ **Test real transfers** — Use camera's USB mode + Apple Photos app (see USB guide in-app)
- ✅ **Plan features** — Open issues, discuss architecture in PR comments

**When you return to Mac:**
- Open `FujiFileTransfer/FujiFileTransfer.xcodeproj` in Xcode
- Build and run on Simulator (mock mode) or device (with camera)
- See [DEVELOPMENT.md](DEVELOPMENT.md) for full setup

## Features

**Simple, focused workflow:**
1. **See photos** — Thumbnail grid loads immediately on connection
2. **Tap to select** — Toggle selection with simple tap (clear visual state)
3. **Import** — Single prominent button imports selected photos

**Core capabilities:**
- **Fast Wi-Fi Transfer**: Direct connection to Fujifilm X-T5 over Wi-Fi
- **Automatic Connection**: App connects on launch (demo mode in Simulator)
- **Smart Tracking**: Remembers which photos are already imported
- **JPEG Priority**: Optimized for JPEG transfers (RAW supported but untested)
- **Photos Integration**: Saves directly to iOS Photos library
- **Minimal Setup**: Connection help available in menu, not blocking main workflow
- **Demo Mode**: Fully functional Simulator support with 8 sample photos

## CI/CD

This project includes a **compile-only CI workflow** that builds the app for iOS Simulator on every push and pull request:

- **What it does**: Validates that the code compiles successfully without requiring signing credentials
- **What it doesn't do**: Does not create device builds, TestFlight uploads, or App Store releases
- **Requirements**: None - runs on free GitHub Actions runners with no Apple Developer Program needed
- **Xcode version**: Uses the default Xcode on `macos-latest` runners (automatically updated by GitHub)

The workflow builds for iOS Simulator using `CODE_SIGNING_ALLOWED=NO`, which means:
- ✅ Code compilation and SwiftUI syntax validation work
- ✅ Build errors are caught automatically
- ✅ Flexible simulator destination that works across runner updates
- ❌ Device installation requires a paid Apple Developer Program membership ($99/year)
- ❌ TestFlight/App Store distribution not included

See [`.github/workflows/ios-build.yml`](.github/workflows/ios-build.yml) for the full configuration.

## Requirements

- iOS 17.0 or later
- iPhone or iPad
- Fujifilm X-T5 camera (or compatible Fujifilm camera using the same protocol)
- Xcode 15.0 or later (for building)
- **For device installation**: Apple Developer Program membership (not required for Simulator builds)

## Project Architecture

### Clean Module Boundaries

The app is organized with clear separation of concerns:

```
FujiFileTransfer/
├── Transport/              # Camera communication abstraction
│   ├── CameraTransport.swift       # Protocol defining camera interface
│   ├── FujiWiFiTransport.swift     # Real Fuji Wi-Fi implementation
│   └── MockTransport.swift         # Simulator/testing mock
├── Network/                # Low-level networking
│   ├── PTPProtocol.swift           # Fujifilm PTP-over-TCP protocol
│   └── NetworkManager.swift        # TCP connection management
├── Services/               # Business logic services
│   └── PhotosImportService.swift   # Photos library integration
├── ViewModels/             # SwiftUI view models
│   ├── ConnectionViewModel.swift
│   └── ImportViewModel.swift
├── Views/                  # SwiftUI views
│   ├── ConnectionView.swift
│   ├── ThumbnailGridView.swift
│   ├── ImportProgressView.swift
│   └── USBGuideView.swift
└── Models/                 # Data models
    └── Models.swift
```

### Protocol Layer

The app implements Fujifilm's proprietary PTP-over-TCP protocol, which differs from standard PTP/IP:

- Uses PTP/IP-style REQ/ACK for initial handshake
- Switches to USB-style PTP packets over TCP for commands
- Connection to camera's access point at `192.168.0.1:55740`
- Custom initialization packet with specific GUID and protocol version

Implementation based on open-source references:
- [libfuji](https://github.com/petabyt/libfuji) (MIT License)
- [Fudge protocol writeup](https://danielc.dev/blog/fudge1/)

### Transport Abstraction

`CameraTransport` protocol allows switching between:
- **FujiWiFiTransport**: Real camera communication via Network.framework
- **MockTransport**: Simulated camera with fake images for Simulator testing

## Setup Instructions

### Opening in Xcode

1. Clone this repository
2. Open `FujiFileTransfer/FujiFileTransfer.xcodeproj` in Xcode on a Mac
3. Select your development team in Signing & Capabilities
4. Build and run on a device or simulator

### Required Entitlements

The app requires the following capabilities (already configured in `FujiFileTransfer.entitlements`):

- **Hotspot Configuration**: To join the camera's Wi-Fi network programmatically
- **Local Network**: To discover and connect to the camera
- **Photos Library**: To save imported images

### Permissions

The app requests:
- **Local Network Usage**: Required to connect to the camera's TCP server
- **Photo Library Add-Only Access**: Required to save imported photos

## Using the App

**Simplified workflow** — Photos first, setup help in menu:

### Quick Start

1. **On Camera**: Menu → Connection Setting → Wireless Settings → "Connect to Smartphone"
2. **On iPhone**: Settings → Wi-Fi → Join camera network (X-T5_XXXX)
3. **Open App**: Photos appear automatically
4. **Tap photos** to select
5. **Tap Import** button

### Interface

- **Status bar** (top): Shows connection state or "Demo Mode" in Simulator
- **Photo grid** (main): Tap any photo to toggle selection
  - Green "new" indicator for not-yet-imported photos
  - Checkmark shows selected state
- **Import button** (bottom): Active when photos selected or new photos available
  - "Import N Photos" when selection exists
  - "Import All New" when no selection but new photos present
  - Disabled with reason when nothing to import

### Setup Help

Tap **⋯ menu** (top right) for:
- Camera setup instructions
- USB import guide (fallback)
- Mock mode toggle (Simulator)

### USB Transfer Mode

For faster transfers or when Wi-Fi is unreliable:

1. **Camera Setup**:
   - Menu → Connection Setting → Connection Mode → USB Card Reader
   - Set Power Supply Off/Comm On

2. **Connect**:
   - Use USB-C cable (iPhone 15+) or Lightning Camera Adapter (older iPhones)
   - Open Apple Photos app → Import tab
   - Select and import photos

See the in-app USB guide (info button) for detailed instructions.

## Known Limitations

### Current Implementation

- **JPEG Focus**: Primary testing and optimization for JPEG files
- **RAW Support**: Protocol layer supports RAW, but full-size RAF transfers untested
- **HEIF/Video**: Limited testing on non-JPEG formats
- **Connection Reliability**: PTP handshake with newer cameras may require user confirmation on camera screen
- **Error Recovery**: Basic error handling; connection failures require manual reconnect

### Protocol Uncertainties

The implementation is based on reverse-engineering and open-source references. Some areas marked as TODOs in code:

- Complete device property negotiation for X-T5 specifically
- Event handling for camera-initiated transfers
- Remote mode / live view (out of scope for v1)

### vs. Fujifilm XApp

**Simpler:**
- Photos-first interface (no multi-screen wizard)
- One-tap selection, one Import button
- Automatic connection (no manual pairing flow)

**Faster:**
- Direct protocol control for thumbnail loading
- Import tracking avoids re-downloading
- Minimal chrome, maximum content

**Limitations:**
- No live view / remote shutter
- No camera settings control
- Focused on X-T5 (may work with other models)
- Compile-only (no App Store distribution yet)

## Building for Device

1. Open the project in Xcode
2. Select a connected iOS device (or use Simulator for testing)
3. Update the bundle identifier if needed: `com.example.FujiFileTransfer`
4. **For device builds**: Select your development team in Signing & Capabilities
   - Requires Apple Developer Program membership ($99/year)
   - Free tier allows Simulator builds only
5. Build and run (Cmd+R)

### Simulator vs. Device

- **Simulator**: Uses `MockTransport` with generated placeholder images
- **Device**: Uses real `FujiWiFiTransport` to connect to camera
- Toggle "Use Mock Mode" in debug builds to force mock mode on device

## Development

### Code Organization

- **Actor-based concurrency**: `NetworkManager` and `PhotosImportService` use Swift actors
- **Async/await**: All network and I/O operations are async
- **SwiftUI + MVVM**: Clean separation between views and view models
- **Protocol-oriented**: `CameraTransport` protocol enables testing and mock implementations

### Adding Features

To add support for new operations:

1. Add operation code to `PTPProtocol.OperationCode`
2. Implement command/response handling in `FujiWiFiTransport`
3. Add mock behavior to `MockTransport`
4. Expose via `CameraTransport` protocol if needed

### Testing

The `MockTransport` allows UI development without a camera:
- Generates placeholder thumbnails and images
- Simulates transfer progress
- Can simulate connection errors

## Protocol Details

### Initialization Sequence

1. Connect to `192.168.0.1:55740` via TCP
2. Send Fuji init packet (0x52 bytes):
   - Protocol version: `0x8F53E4F2`
   - GUID: `5D48A5AD-0B7FB287-D0DED5D3-00000000`
   - Device name: UTF-16 encoded client name
3. Receive init ACK
4. Send PTP OpenSession command
5. Begin PTP operations

### PTP Packet Format

After initialization, all packets use USB-style PTP:
- Command packets: operation code + transaction ID + parameters
- Data packets: command response data
- Response packets: status code + optional return parameters

See `PTPProtocol.swift` for full packet structures.

## License

MIT License - see [LICENSE](LICENSE) file

## Acknowledgments

This project is inspired by and references:

- **[libfuji](https://github.com/petabyt/libfuji)** by petabyt (MIT License)
  - C library for Fujifilm camera communication
  - Protocol reference and implementation concepts
  
- **[Fudge Android App](https://danielc.dev/blog/fudge1/)** by Daniel C
  - Protocol documentation and reverse engineering work
  - Wireless communication sequence details

Protocol implementation in this project is a clean-room Swift reimplementation based on publicly documented protocol behavior. No code was copied from GPL sources.

See [NOTICE](NOTICE) for detailed attribution.

## Contributing

Contributions welcome! Areas for improvement:

- Support for additional Fujifilm camera models
- RAW file handling optimization
- Better error recovery and reconnection
- Advanced features (remote mode, live view)
- Localization

Please open issues for bugs or feature requests.

## Disclaimer

This is an unofficial, independent project not affiliated with or endorsed by Fujifilm. Use at your own risk. The developer is not responsible for any data loss or camera issues.
