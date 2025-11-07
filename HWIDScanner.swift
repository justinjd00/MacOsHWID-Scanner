import Foundation
import IOKit
import SystemConfiguration
import CryptoKit

class MacOSHWIDScanner {
    private var systemInfo: [String: Any] = [:]
    
    
    func getCPUInfo() -> [String: String] {
        var cpuInfo: [String: String] = [:]
        
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var cpuBrand = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &cpuBrand, &size, nil, 0)
            cpuInfo["model"] = String(cString: cpuBrand)
        }
        
        var physicalCores: Int32 = 0
        var size2 = MemoryLayout<Int32>.size
        if sysctlbyname("hw.physicalcpu", &physicalCores, &size2, nil, 0) == 0 {
            cpuInfo["physical_cores"] = String(physicalCores)
        }
        
        var logicalCores: Int32 = 0
        if sysctlbyname("hw.logicalcpu", &logicalCores, &size2, nil, 0) == 0 {
            cpuInfo["logical_cores"] = String(logicalCores)
        }
        
        var cpuFamily: Int32 = 0
        if sysctlbyname("machdep.cpu.family", &cpuFamily, &size2, nil, 0) == 0 {
            cpuInfo["family"] = String(cpuFamily)
        }
        
        var cpuModel: Int32 = 0
        if sysctlbyname("machdep.cpu.model", &cpuModel, &size2, nil, 0) == 0 {
            cpuInfo["model_number"] = String(cpuModel)
        }
        
        return cpuInfo
    }
    
    
    func getMemoryInfo() -> [String: String] {
        var memoryInfo: [String: String] = [:]
        
        var memSize: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &memSize, &size, nil, 0) == 0 {
            let totalGB = Double(memSize) / (1024.0 * 1024.0 * 1024.0)
            memoryInfo["total_gb"] = String(format: "%.2f", totalGB)
            memoryInfo["total_bytes"] = String(memSize)
        }
        
        let ramDetails = getRAMDetails()
        memoryInfo.merge(ramDetails) { (_, new) in new }
        
        return memoryInfo
    }
    
    private func getRAMDetails() -> [String: String] {
        var ramInfo: [String: String] = [:]
        
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPMemoryDataType", "-xml", "-detailLevel", "full"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]],
               let firstItem = plist.first,
               let items = firstItem["_items"] as? [[String: Any]] {
                
                for (index, item) in items.enumerated() {
                    if let dimmType = item["dimm_type"] as? String {
                        if index == 0 {
                            ramInfo["type"] = dimmType
                        } else {
                            ramInfo["type"] = (ramInfo["type"] ?? "") + ", " + dimmType
                        }
                    }
                    
                    if let manufacturer = item["dimm_manufacturer"] as? String {
                        if index == 0 {
                            ramInfo["manufacturer"] = manufacturer
                        } else {
                            ramInfo["manufacturer"] = (ramInfo["manufacturer"] ?? "") + ", " + manufacturer
                        }
                    }
                    
                    if let size = item["dimm_size"] as? String {
                        if index == 0 {
                            ramInfo["module_size"] = size
                        } else {
                            ramInfo["module_size"] = (ramInfo["module_size"] ?? "") + ", " + size
                        }
                    }
                    
                    if let speed = item["dimm_speed"] as? String {
                        if index == 0 {
                            ramInfo["speed"] = speed
                        } else {
                            ramInfo["speed"] = (ramInfo["speed"] ?? "") + ", " + speed
                        }
                    }
                    
                    if let serial = item["dimm_serial_number"] as? String, !serial.isEmpty {
                        if index == 0 {
                            ramInfo["serial"] = serial
                        } else {
                            ramInfo["serial"] = (ramInfo["serial"] ?? "") + ", " + serial
                        }
                    }
                }
            }
        } catch {
            return getRAMTypeFromText()
        }
        
        if ramInfo.isEmpty {
            return getRAMTypeFromText()
        }
        
        return ramInfo
    }
    
    private func getRAMTypeFromText() -> [String: String] {
        var ramInfo: [String: String] = [:]
        
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPMemoryDataType"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.contains("Type:") {
                        let parts = trimmed.components(separatedBy: ":")
                        if parts.count > 1 {
                            ramInfo["type"] = parts[1].trimmingCharacters(in: .whitespaces)
                        }
                    } else if trimmed.contains("Manufacturer:") {
                        let parts = trimmed.components(separatedBy: ":")
                        if parts.count > 1 {
                            ramInfo["manufacturer"] = parts[1].trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
        } catch {
        }
        
        return ramInfo
    }
    
    
    func getSystemUUID() -> String? {
        #if swift(>=5.0)
        let masterPort: mach_port_t = kIOMainPortDefault
        #else
        let masterPort: mach_port_t = kIOMasterPortDefault
        #endif
        let platformExpert = IOServiceGetMatchingService(masterPort,
                                                         IOServiceMatching("IOPlatformExpertDevice"))
        guard platformExpert != 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }
        
        let uuidKey = "IOPlatformUUID" as CFString
        if let uuidUnmanaged = IORegistryEntryCreateCFProperty(platformExpert, uuidKey, kCFAllocatorDefault, 0) {
            let uuid = uuidUnmanaged.takeRetainedValue()
            return uuid as? String
        }
        
        return nil
    }
    
    func getSerialNumber() -> String? {
        #if swift(>=5.0)
        let masterPort: mach_port_t = kIOMainPortDefault
        #else
        let masterPort: mach_port_t = kIOMasterPortDefault
        #endif
        let platformExpert = IOServiceGetMatchingService(masterPort,
                                                         IOServiceMatching("IOPlatformExpertDevice"))
        guard platformExpert != 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }
        
        let serialKey = "IOPlatformSerialNumber" as CFString
        if let serialUnmanaged = IORegistryEntryCreateCFProperty(platformExpert, serialKey, kCFAllocatorDefault, 0) {
            let serial = serialUnmanaged.takeRetainedValue()
            return serial as? String
        }
        
        return nil
    }
    
    
    func getModelInfo() -> [String: String] {
        var modelInfo: [String: String] = [:]
        
        var size: size_t = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        if size > 0 {
            var model = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &model, &size, nil, 0)
            modelInfo["identifier"] = String(cString: model)
        }
        
        #if swift(>=5.0)
        let masterPort: mach_port_t = kIOMainPortDefault
        #else
        let masterPort: mach_port_t = kIOMasterPortDefault
        #endif
        let platformExpert = IOServiceGetMatchingService(masterPort,
                                                         IOServiceMatching("IOPlatformExpertDevice"))
        if platformExpert != 0 {
            defer { IOObjectRelease(platformExpert) }
            
            let modelKey = "model" as CFString
            if let modelUnmanaged = IORegistryEntryCreateCFProperty(platformExpert, modelKey, kCFAllocatorDefault, 0) {
                let model = modelUnmanaged.takeRetainedValue()
                modelInfo["name"] = model as? String
            }
        }
        
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPHardwareDataType"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains("Model Number:") {
                        let parts = line.components(separatedBy: ":")
                        if parts.count > 1 {
                            modelInfo["model_number"] = parts[1].trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
        } catch {
        }
        
        return modelInfo
    }
    
    
    func getMACAddresses() -> [[String: String]] {
        var interfaces: [[String: String]] = []
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return interfaces }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            let name = String(cString: interface.ifa_name)
            
            if name.hasPrefix("en") || name.hasPrefix("bridge") {
                if let addr = interface.ifa_addr,
                   addr.pointee.sa_family == UInt8(AF_LINK) {
                    let linkAddr = UnsafeRawPointer(addr).bindMemory(to: sockaddr_dl.self, capacity: 1)
                    let macLength = Int(linkAddr.pointee.sdl_alen)
                    
                    if macLength == 6 {
                        let dl = linkAddr.pointee
                        let dataOffset = Int(dl.sdl_nlen)
                        
                        let sdlDataOffset = MemoryLayout<UInt8>.size * 2 + // sdl_len, sdl_family
                                           MemoryLayout<UInt16>.size +      // sdl_index
                                           MemoryLayout<UInt8>.size +       // sdl_type
                                           MemoryLayout<UInt8>.size +       // sdl_nlen
                                           MemoryLayout<UInt8>.size         // sdl_alen
                        
                        let macPtr = UnsafeRawPointer(linkAddr)
                            .advanced(by: sdlDataOffset)
                            .advanced(by: dataOffset)
                            .assumingMemoryBound(to: UInt8.self)
                        
                        let macBytes = Array(UnsafeBufferPointer(start: macPtr, count: macLength))
                        let macString = macBytes.map { String(format: "%02x", $0) }.joined(separator: ":")
                        
                        interfaces.append([
                            "device": name,
                            "mac_address": macString.uppercased()
                        ])
                    }
                }
            }
        }
        
        return interfaces
    }
    
    
    func getDiskInfo() -> [[String: String]] {
        var disks: [[String: String]] = []
        
        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments = ["list", "-plist"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let allDisks = plist["AllDisksAndPartitions"] as? [[String: Any]] {
                
                for disk in allDisks {
                    var diskInfo: [String: String] = [:]
                    
                    if let deviceName = disk["DeviceIdentifier"] as? String {
                        diskInfo["device"] = deviceName
                    }
                    
                    if let size = disk["Size"] as? Int64 {
                        let sizeGB = Double(size) / (1024.0 * 1024.0 * 1024.0)
                        diskInfo["capacity"] = String(format: "%.2f GB", sizeGB)
                    }
                    
                    if let device = diskInfo["device"] {
                        let infoTask = Process()
                        infoTask.launchPath = "/usr/sbin/diskutil"
                        infoTask.arguments = ["info", "-plist", device]
                        
                        let infoPipe = Pipe()
                        infoTask.standardOutput = infoPipe
                        
                        do {
                            try infoTask.run()
                            infoTask.waitUntilExit()
                            
                            let infoData = infoPipe.fileHandleForReading.readDataToEndOfFile()
                            if let infoPlist = try PropertyListSerialization.propertyList(from: infoData, options: [], format: nil) as? [String: Any] {
                                if let volumeName = infoPlist["VolumeName"] as? String, !volumeName.isEmpty {
                                    diskInfo["name"] = volumeName
                                }
                                if let mediaName = infoPlist["MediaName"] as? String, !mediaName.isEmpty {
                                    if diskInfo["name"] == nil || diskInfo["name"]?.isEmpty == true {
                                        diskInfo["name"] = mediaName
                                    } else {
                                        diskInfo["media_name"] = mediaName
                                    }
                                }
                                if let volumeUUID = infoPlist["VolumeUUID"] as? String {
                                    diskInfo["uuid"] = volumeUUID
                                }
                                if let diskSerial = infoPlist["DiskSerialNumber"] as? String {
                                    diskInfo["serial"] = diskSerial
                                }
                                if let diskModel = infoPlist["DeviceModel"] as? String {
                                    diskInfo["model"] = diskModel
                                }
                                if let deviceNode = infoPlist["DeviceNode"] as? String {
                                    diskInfo["device_node"] = deviceNode
                                }
                            }
                        } catch {
                        }
                    }
                    
                    if !diskInfo.isEmpty {
                        disks.append(diskInfo)
                    }
                }
            }
        } catch {
        }
        
        return disks
    }
    
    
    func getPlatformInfo() -> [String: String] {
        return [
            "system": "Darwin",
            "release": ProcessInfo.processInfo.operatingSystemVersionString,
            "machine": getMachineArchitecture()
        ]
    }
    
    private func getMachineArchitecture() -> String {
        var size: size_t = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        if size > 0 {
            var machine = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.machine", &machine, &size, nil, 0)
            return String(cString: machine)
        }
        return "unknown"
    }
    
    
    func generateHWID() -> String {
        var hwString = ""
        
        if let uuid = getSystemUUID() {
            hwString += "UUID:\(uuid)|"
        }
        
        if let serial = getSerialNumber() {
            hwString += "SERIAL:\(serial)|"
        }
        
        let cpuInfo = getCPUInfo()
        if let cpuModel = cpuInfo["model"] {
            hwString += "CPU:\(cpuModel)|"
        }
        
        let macAddresses = getMACAddresses()
        if let firstMAC = macAddresses.first?["mac_address"] {
            hwString += "MAC:\(firstMAC)|"
        }
        
        let disks = getDiskInfo()
        for disk in disks {
            if let uuid = disk["uuid"] {
                hwString += "DISK:\(uuid)|"
            }
        }
        
        if !hwString.isEmpty {
            let data = hwString.data(using: .utf8)!
            let digest = SHA256.hash(data: data)
            let hwid = digest.map { String(format: "%02X", $0) }.joined()
            return String(hwid.prefix(32))
        }
        
        return ""
    }
    
    
    func scanAll() -> [String: Any] {
        systemInfo = [
            "platform": getPlatformInfo(),
            "model": getModelInfo(),
            "serial_number": getSerialNumber() ?? "",
            "system_uuid": getSystemUUID() ?? "",
            "cpu": getCPUInfo(),
            "memory": getMemoryInfo(),
            "disks": getDiskInfo(),
            "network_interfaces": getMACAddresses(),
            "hwid": generateHWID()
        ]
        
        return systemInfo
    }
    
    
    func toJSON() -> String? {
        if systemInfo.isEmpty {
            _ = scanAll()
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: systemInfo, options: .prettyPrinted) else {
            return nil
        }
        
        return String(data: jsonData, encoding: .utf8)
    }
    
    func saveToFile(filename: String = "hwid_report.json") {
        if systemInfo.isEmpty {
            _ = scanAll()
        }
        
        guard let jsonString = toJSON() else {
            return
        }
        
        do {
            try jsonString.write(toFile: filename, atomically: true, encoding: .utf8)
        } catch {
        }
    }
}

