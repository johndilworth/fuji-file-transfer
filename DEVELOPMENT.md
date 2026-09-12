# Development Guide

Quick reference for developing Fuji File Transfer on your Mac.

## Opening the Project

1. Open `FujiFileTransfer/FujiFileTransfer.xcodeproj` in Xcode
2. Select target device:
   - **iOS Simulator**: No setup required, uses mock mode automatically
   - **Physical iPhone/iPad**: Requires Apple Developer Program for signing

## Building & Running

### Simulator (Recommended for Development)

```bash
# Builds and runs in Simulator with mock camera data
# No camera required, no signing needed
```

1. Select any iOS Simulator from device menu
2. Press ⌘R to build and run
3. App automatically uses mock mode with 8 sample photos
4. Test UI, import flow, and selection without camera

### Device (Requires Camera)

1. Connect iPhone via USB
2. Select your device from menu
3. **Signing**: Xcode will prompt for development team
   - Free tier: 7-day certificates, must rebuild weekly
   - Paid ($99/year): 1-year certificates
4. Press ⌘R to build and run
5. **First launch**: iOS will show "Untrusted Developer" alert
   - Settings → General → VPN & Device Management → Trust developer
6. Connect to camera's Wi-Fi before using app

## Project Structure

```
FujiFileTransfer/
├── Transport/              # Camera communication
│   ├── CameraTransport.swift       # Protocol
│   ├── FujiWiFiTransport.swift     # Real camera (PTP/TCP)
│   └── MockTransport.swift         # Simulator testing
├── Network/                # Low-level PTP protocol
│   ├── PTPProtocol.swift           # Packet structures
│   └── NetworkManager.swift        # TCP connection
├── Services/               # Business logic
│   └── PhotosImportService.swift   # Save to Photos
├── ViewModels/             # SwiftUI state
│   ├── ConnectionViewModel.swift
│   └── ImportViewModel.swift
├── Views/                  # UI
│   ├── ConnectionView.swift        # Main screen
│   ├── ThumbnailGridView.swift     # Photo grid
│   └── ImportProgressView.swift    # Transfer status
└── Models/                 # Data types
    └── Models.swift
```

## Architecture

**Protocol-based design** allows switching between real camera and mock:

```swift
protocol CameraTransport {
    func connect() async throws
    func listImages() async throws -> [CameraImage]
    func downloadImage(objectID: UInt32, ...) async throws -> Data
}
```

**Implementations:**
- `FujiWiFiTransport`: Network.framework TCP to 192.168.0.1:55740
- `MockTransport`: Generated placeholder images for Simulator

## Common Development Tasks

### Adding a New PTP Command

1. Add operation code to `PTPProtocol.OperationCode`
2. Implement in `FujiWiFiTransport` private method
3. Add mock behavior to `MockTransport`
4. Expose via `CameraTransport` protocol if needed

### Modifying UI

All views use SwiftUI:
- `ConnectionView`: Main screen with photo grid
- `ThumbnailGridView`: Grid layout and import button
- Changes are live-preview compatible in Xcode

### Testing Without Camera

The `MockTransport` simulates:
- Connection delay (~0.8s)
- 8 sample photos (JPEGs + 1 RAW)
- Transfer progress with realistic speeds
- Already-imported state tracking

### Protocol Debugging

To see PTP traffic:
- Add `print()` statements in `NetworkManager.send()` and `receive()`
- Check response codes in `PTPProtocol.ResponseCode`
- Consult libfuji source for command sequences

## Known Issues & TODOs

See `FujiWiFiTransport.swift` for protocol TODOs:
- Connection timeouts not implemented
- Some operations may require camera screen confirmation
- Error recovery is basic (may need camera power cycle)
- RemoteMode handshake not fully implemented for X-T5

## Troubleshooting

### "Untrusted Developer" on Device
Settings → General → VPN & Device Management → Trust your Apple ID

### Build Fails with Signing Error
- Update `PRODUCT_BUNDLE_IDENTIFIER` to unique name
- Select your development team in Signing & Capabilities

### Camera Won't Connect
1. Check iPhone is joined to camera's Wi-Fi network (Settings → Wi-Fi)
2. Camera must be in "Connect to Smartphone" mode
3. Try toggling camera Wi-Fi off/on
4. Check you can ping 192.168.0.1 from Terminal (on Mac)

### Simulator Shows No Photos
- Ensure "Mock Mode" toggle is ON in connection view
- Check console for MockTransport errors

## Contributing

When submitting PRs:
1. Ensure CI builds pass (iOS Simulator, no signing)
2. Test in Simulator if no camera available
3. Document protocol uncertainties as TODOs, don't fake working code
4. Update README if changing user-facing behavior

## Testing Checklist

**Simulator:**
- [ ] App launches and shows demo mode
- [ ] 8 sample photos load
- [ ] Can select/deselect photos
- [ ] Import button enables/disables correctly
- [ ] Import progress shows for each photo

**Device with Camera:**
- [ ] Connects to camera Wi-Fi
- [ ] Shows real photos from camera
- [ ] Downloads thumbnails
- [ ] Imports JPEG to Photos library
- [ ] Remembers imported photos
- [ ] Progress tracking works
- [ ] Can cancel import

## Resources

- **Protocol**: https://danielc.dev/blog/fudge1/
- **Reference Implementation**: https://github.com/petabyt/libfuji (MIT)
- **PTP Spec**: ISO 15740 (USB-style packets over TCP for Fuji)
