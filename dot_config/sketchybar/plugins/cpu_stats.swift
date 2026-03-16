import Foundation
import Darwin.Mach

let INFO_COUNT = mach_msg_type_number_t(
    MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
)

func readTicks() -> (UInt64, UInt64, UInt64, UInt64)? {
    var count = INFO_COUNT
    var info = host_cpu_load_info_data_t()
    let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
        ptr.withMemoryRebound(to: integer_t.self, capacity: Int(INFO_COUNT)) {
            host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
        }
    }
    guard kr == KERN_SUCCESS else { return nil }
    // cpu_ticks: 0=user 1=system 2=idle 3=nice
    return (UInt64(info.cpu_ticks.0), UInt64(info.cpu_ticks.1),
            UInt64(info.cpu_ticks.2), UInt64(info.cpu_ticks.3))
}

guard let (user, sys, idle, nice) = readTicks() else { print(0); exit(0) }

let cache = "/tmp/sketchybar_cpu_ticks"
var pct = 0

if let prev = try? String(contentsOfFile: cache, encoding: .utf8) {
    let v = prev.split(separator: " ").compactMap { UInt64($0) }
    if v.count == 4 {
        let du = user - v[0], ds = sys - v[1], di = idle - v[2], dn = nice - v[3]
        let total = du + ds + di + dn
        if total > 0 { pct = Int((du + ds + dn) * 100 / total) }
    }
}

try? "\(user) \(sys) \(idle) \(nice)".write(toFile: cache, atomically: true, encoding: .utf8)
print(pct)
