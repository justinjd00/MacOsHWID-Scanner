import AppKit
import SwiftUI

@main
struct HWIDScannerApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = MainView()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "macOS HWID Scanner"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

struct MainView: View {
    @StateObject private var scanner = ScannerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            
            ScrollView {
                VStack(spacing: 20) {
                    if scanner.isScanning {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Scanning hardware information...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    } else if scanner.hardwareInfo.isEmpty {
                        WelcomeView()
                    } else {
                        HardwareInfoView(info: scanner.hardwareInfo)
                    }
                }
                .padding(20)
            }
            
            FooterView(
                isScanning: scanner.isScanning,
                hasResults: !scanner.hardwareInfo.isEmpty,
                onStart: {
                    scanner.startScan()
                },
                onClose: {
                    NSApplication.shared.terminate(nil)
                },
                onShowInFinder: {
                    scanner.showInFinder()
                }
            )
        }
        .frame(minWidth: 900, minHeight: 700)
    }
}

struct HeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 28))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("macOS HWID Scanner")
                    .font(.system(size: 22, weight: .bold))
                Text("Collect hardware information")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .opacity(0.7)
            
            Text("Ready to Scan")
                .font(.system(size: 28, weight: .semibold))
            
            Text("Click 'Start' to collect hardware information")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(60)
    }
}

struct HardwareInfoView: View {
    let info: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            InfoSection(title: "System", icon: "desktopcomputer") {
                if let model = info["model"] as? [String: String] {
                    InfoRow(label: "Model", value: model["name"] ?? "N/A")
                    InfoRow(label: "Identifier", value: model["identifier"] ?? "N/A")
                    if let modelNumber = model["model_number"] {
                        InfoRow(label: "Model Number", value: modelNumber)
                    }
                }
                if let serial = info["serial_number"] as? String {
                    InfoRow(label: "Serial Number", value: serial)
                }
                if let uuid = info["system_uuid"] as? String {
                    InfoRow(label: "System UUID", value: uuid)
                }
                if let hwid = info["hwid"] as? String {
                    InfoRow(label: "Hardware ID", value: hwid)
                        .font(.system(.body, design: .monospaced))
                }
            }
            
            InfoSection(title: "CPU", icon: "cpu") {
                if let cpu = info["cpu"] as? [String: String] {
                    InfoRow(label: "Model", value: cpu["model"] ?? "N/A")
                    if let modelNumber = cpu["model_number"] {
                        InfoRow(label: "Model Number", value: modelNumber)
                    }
                    if let family = cpu["family"] {
                        InfoRow(label: "Family", value: family)
                    }
                    InfoRow(label: "Physical Cores", value: cpu["physical_cores"] ?? "N/A")
                    InfoRow(label: "Logical Cores", value: cpu["logical_cores"] ?? "N/A")
                }
            }
            
            InfoSection(title: "Memory", icon: "memorychip") {
                if let mem = info["memory"] as? [String: String] {
                    InfoRow(label: "Total", value: "\(mem["total_gb"] ?? "N/A") GB")
                    if let type = mem["type"] {
                        InfoRow(label: "Type", value: type)
                    }
                    if let manufacturer = mem["manufacturer"] {
                        InfoRow(label: "Manufacturer", value: manufacturer)
                    }
                    if let speed = mem["speed"] {
                        InfoRow(label: "Speed", value: speed)
                    }
                }
            }
            
            InfoSection(title: "Storage", icon: "externaldrive") {
                if let disks = info["disks"] as? [[String: String]] {
                    ForEach(Array(disks.enumerated()), id: \.offset) { index, disk in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Disk \(index + 1)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.blue)
                            
                            if let device = disk["device"] {
                                InfoRow(label: "Device", value: device)
                            }
                            if let name = disk["name"], !name.isEmpty {
                                InfoRow(label: "Name", value: name)
                            }
                            if let model = disk["model"] {
                                InfoRow(label: "Model", value: model)
                            }
                            if let capacity = disk["capacity"] {
                                InfoRow(label: "Capacity", value: capacity)
                            }
                            if let serial = disk["serial"] {
                                InfoRow(label: "Serial Number", value: serial)
                            }
                            
                            if index < disks.count - 1 {
                                Divider()
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }
            
            InfoSection(title: "Network Interfaces", icon: "network") {
                if let interfaces = info["network_interfaces"] as? [[String: String]] {
                    ForEach(Array(interfaces.enumerated()), id: \.offset) { index, interface in
                        HStack {
                            if let device = interface["device"] {
                                Text(device)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if let mac = interface["mac_address"] {
                                Text(mac)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        .padding(.vertical, 6)
                        
                        if index < interfaces.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct FooterView: View {
    let isScanning: Bool
    let hasResults: Bool
    let onStart: () -> Void
    let onClose: () -> Void
    let onShowInFinder: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if hasResults {
                Button(action: onShowInFinder) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                        Text("Show in Finder")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .frame(minWidth: 140)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            Spacer()
            
            Button(action: onStart) {
                HStack(spacing: 8) {
                    if isScanning {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(isScanning ? "Scanning..." : "Start")
                        .font(.system(size: 15, weight: .medium))
                }
                .frame(minWidth: 140)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isScanning)
            
            Button(action: onClose) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Close")
                        .font(.system(size: 15, weight: .medium))
                }
                .frame(minWidth: 140)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top
        )
    }
}

class ScannerViewModel: ObservableObject {
    @Published var hardwareInfo: [String: Any] = [:]
    @Published var isScanning = false
    
    func startScan() {
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let scanner = MacOSHWIDScanner()
            let info = scanner.scanAll()
            
            scanner.saveToFile()
            
            DispatchQueue.main.async {
                self.hardwareInfo = info
                self.isScanning = false
            }
        }
    }
    
    func showInFinder() {
        let filename = "hwid_report.json"
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        let filePath = (currentDirectory as NSString).appendingPathComponent(filename)
        
        if fileManager.fileExists(atPath: filePath) {
            NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: currentDirectory)
        }
    }
}

