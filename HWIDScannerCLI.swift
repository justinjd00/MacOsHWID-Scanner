import Foundation

struct CLIArguments {
    var jsonOnly: Bool = false
    var outputFile: String? = nil
    var quiet: Bool = false
    var help: Bool = false
    var version: Bool = false
    var showHwid: Bool = false
    var showSerial: Bool = false
    var showUuid: Bool = false
}

func parseArguments() -> CLIArguments {
    var args = CLIArguments()
    let arguments = CommandLine.arguments
    
    var i = 1
    while i < arguments.count {
        let arg = arguments[i]
        
        switch arg {
        case "--json", "-j":
            args.jsonOnly = true
        case "--output", "-o":
            if i + 1 < arguments.count {
                args.outputFile = arguments[i + 1]
                i += 1
            }
        case "--quiet", "-q":
            args.quiet = true
        case "--help", "-h":
            args.help = true
        case "--version", "-v":
            args.version = true
        case "--hwid":
            args.showHwid = true
        case "--serial":
            args.showSerial = true
        case "--uuid":
            args.showUuid = true
        default:
            break
        }
        i += 1
    }
    
    return args
}

func printHelp() {
    print("""
    macOS HWID Scanner
    
    Usage: hwid_scanner_swift [OPTIONS]
    
    Options:
        -h, --help          Show this help message
        -v, --version       Show version information
        -j, --json          Output only JSON
        -o, --output FILE   Save output to file (default: hwid_report.json)
        -q, --quiet         Suppress all output except errors
        --hwid              Show only hardware ID
        --serial            Show only serial number
        --uuid              Show only system UUID
    
    Examples:
        hwid_scanner_swift                    # Full scan with output
        hwid_scanner_swift --json             # JSON output only
        hwid_scanner_swift --hwid             # Show only HWID
        hwid_scanner_swift -o report.json     # Save to custom file
        hwid_scanner_swift --quiet --json     # Silent JSON output
    """)
}

func printVersion() {
    print("macOS HWID Scanner v1.0.0")
}

func printFullOutput(info: [String: Any]) {
    print("macOS HWID Scanner")
    print("=" + String(repeating: "=", count: 49))
    
    print("\nSystem Information:")
    if let model = info["model"] as? [String: String] {
        print("  Model: \(model["name"] ?? "N/A")")
        print("  Identifier: \(model["identifier"] ?? "N/A")")
        print("  Model Number: \(model["model_number"] ?? "N/A")")
    }
    
    print("\nSerial Number: \(info["serial_number"] as? String ?? "N/A")")
    print("System UUID: \(info["system_uuid"] as? String ?? "N/A")")
    print("Hardware ID: \(info["hwid"] as? String ?? "N/A")")
    
    print("\nCPU:")
    if let cpu = info["cpu"] as? [String: String] {
        print("  Model: \(cpu["model"] ?? "N/A")")
        print("  Model Number: \(cpu["model_number"] ?? "N/A")")
        print("  Family: \(cpu["family"] ?? "N/A")")
        print("  Physical Cores: \(cpu["physical_cores"] ?? "N/A")")
        print("  Logical Cores: \(cpu["logical_cores"] ?? "N/A")")
    }
    
    print("\nMemory:")
    if let mem = info["memory"] as? [String: String] {
        print("  Total: \(mem["total_gb"] ?? "N/A") GB")
        if let type = mem["type"] {
            print("  Type: \(type)")
        }
        if let manufacturer = mem["manufacturer"] {
            print("  Manufacturer: \(manufacturer)")
        }
        if let speed = mem["speed"] {
            print("  Speed: \(speed)")
        }
        if let moduleSize = mem["module_size"] {
            print("  Module Size: \(moduleSize)")
        }
        if let serial = mem["serial"] {
            print("  Serial Number: \(serial)")
        }
    }
    
    print("\nStorage:")
    if let disks = info["disks"] as? [[String: String]] {
        for (index, disk) in disks.enumerated() {
            print("  Disk \(index + 1):")
            if let device = disk["device"] {
                print("    Device: \(device)")
            }
            if let name = disk["name"], !name.isEmpty {
                print("    Name: \(name)")
            }
            if let model = disk["model"] {
                print("    Model: \(model)")
            }
            if let capacity = disk["capacity"] {
                print("    Capacity: \(capacity)")
            }
            if let serial = disk["serial"] {
                print("    Serial Number: \(serial)")
            }
            if let uuid = disk["uuid"] {
                print("    UUID: \(uuid)")
            }
        }
    }
    
    print("\nNetwork Interfaces:")
    if let interfaces = info["network_interfaces"] as? [[String: String]] {
        for interface in interfaces {
            if let mac = interface["mac_address"] {
                let device = interface["device"] ?? "N/A"
                print("  \(device): \(mac)")
            }
        }
    }
    
    print("\nScan completed!")
}

@main
struct HWIDScannerCLI {
    static func main() {
        let args = parseArguments()
        
        if args.help {
            printHelp()
            return
        }
        
        if args.version {
            printVersion()
            return
        }
        
        let scanner = MacOSHWIDScanner()
        let info = scanner.scanAll()
        
        let outputFile = args.outputFile ?? "hwid_report.json"
        scanner.saveToFile(filename: outputFile)
        
        if args.quiet {
            return
        }
        
        if args.jsonOnly {
            if let json = scanner.toJSON() {
                print(json)
            }
            return
        }
        
        if args.showHwid {
            if let hwid = info["hwid"] as? String {
                print(hwid)
            }
            return
        }
        
        if args.showSerial {
            if let serial = info["serial_number"] as? String {
                print(serial)
            }
            return
        }
        
        if args.showUuid {
            if let uuid = info["system_uuid"] as? String {
                print(uuid)
            }
            return
        }
        
        printFullOutput(info: info)
    }
}
