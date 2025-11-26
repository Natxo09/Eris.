//
//  DeviceUtils.swift
//  Eris.
//
//  Created by Ignacio Palacio on 19/6/25.
//

import Foundation
import UIKit
import Metal

struct DeviceUtils {
    enum DeviceType {
        case iPhone
        case iPad
        case mac
        case unknown
    }
    
    enum ChipFamily: Int {
        case unsupported = 0
        case unknown = 1
        case a13 = 2
        case a14 = 3
        case a15 = 4
        case a16 = 5
        case a17Pro = 6
        case a18 = 7
        case a18Pro = 8
        case m1 = 9
        case m2 = 10
        case m3 = 11
        case m4 = 12
    }
    
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    static var deviceType: DeviceType {
        #if os(macOS)
        return .mac
        #else
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return .iPhone
        case .pad:
            return .iPad
        default:
            return .unknown
        }
        #endif
    }
    
    static var deviceModel: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        #else
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
        #endif
    }
    
    static var chipFamily: ChipFamily {
        let model = deviceModel.lowercased()
        
        // iPhone models with incompatible chips
        // A11 - iPhone X
        if model.contains("iphone10,3") || model.contains("iphone10,6") {
            return .unsupported
        }
        // A12 - iPhone XS, XS Max, XR
        if model.contains("iphone11,2") || model.contains("iphone11,4") || 
           model.contains("iphone11,6") || model.contains("iphone11,8") {
            return .unsupported
        }
        
        // iPhone models with compatible chips
        // A13 - Only iPhone 11 Pro, 11 Pro Max, and SE 2nd gen (NOT base iPhone 11)
        // iPhone 11 (iPhone12,1) is excluded due to insufficient memory
        if model.contains("iphone12,3") || model.contains("iphone12,5") || 
           model.contains("iphone12,8") {
            return .a13
        }
        
        // iPhone 11 base model - NOT SUPPORTED
        if model.contains("iphone12,1") {
            return .unsupported
        }
        // A14 - iPhone 12 series
        if model.contains("iphone13,1") || model.contains("iphone13,2") || 
           model.contains("iphone13,3") || model.contains("iphone13,4") {
            return .a14
        }
        // A15 - iPhone 13 series and iPhone 14/14 Plus
        if model.contains("iphone14,2") || model.contains("iphone14,3") || 
           model.contains("iphone14,4") || model.contains("iphone14,5") ||
           model.contains("iphone14,7") || model.contains("iphone14,8") {
            return .a15
        }
        // A16 - iPhone 14 Pro/Pro Max and iPhone 15/15 Plus
        if model.contains("iphone15,2") || model.contains("iphone15,3") ||
           model.contains("iphone15,4") || model.contains("iphone15,5") {
            return .a16
        }
        // A17 Pro - iPhone 15 Pro/Pro Max
        if model.contains("iphone16,1") || model.contains("iphone16,2") {
            return .a17Pro
        }
        // A18 - iPhone 16/16 Plus
        if model.contains("iphone17,1") || model.contains("iphone17,2") {
            return .a18
        }
        // A18 Pro - iPhone 16 Pro/Pro Max
        if model.contains("iphone17,3") || model.contains("iphone17,4") {
            return .a18Pro
        }
        
        // iPad models with M-series chips
        if model.contains("ipad13,4") || model.contains("ipad13,5") ||
           model.contains("ipad13,6") || model.contains("ipad13,7") {
            return .m1 // iPad Pro M1
        }
        if model.contains("ipad13,8") || model.contains("ipad13,9") ||
           model.contains("ipad13,10") || model.contains("ipad13,11") {
            return .m1 // iPad Air M1
        }
        if model.contains("ipad14,3") || model.contains("ipad14,4") ||
           model.contains("ipad14,5") || model.contains("ipad14,6") {
            return .m2 // iPad Pro M2
        }
        if model.contains("ipad14,8") || model.contains("ipad14,9") {
            return .m2 // iPad Air M2
        }
        if model.contains("ipad16,3") || model.contains("ipad16,4") ||
           model.contains("ipad16,5") || model.contains("ipad16,6") {
            return .m4 // iPad Pro M4
        }
        
        // Mac detection (when running as Designed for iPad)
        #if os(iOS) && arch(arm64)
        if ProcessInfo.processInfo.isiOSAppOnMac {
            // Running on Mac with Apple Silicon
            let cpuType = getCPUType()
            if cpuType.contains("Apple M1") {
                return .m1
            } else if cpuType.contains("Apple M2") {
                return .m2
            } else if cpuType.contains("Apple M3") {
                return .m3
            } else if cpuType.contains("Apple M4") {
                return .m4
            }
            return .m1 // Default to M1 if can't detect specific version
        }
        #endif
        
        return isSimulator ? .unsupported : .unknown
    }
    
    static var canRunMLX: Bool {
        // Check if we're in the simulator
        if isSimulator {
            return false
        }
        
        // Check for Metal 3 support (same as fullmoon)
        #if os(iOS)
        if let device = MTLCreateSystemDefaultDevice() {
            return device.supportsFamily(.metal3)
        }
        #endif
        
        return false
    }
    
    static var deviceModelName: String {
        let model = deviceModel.lowercased()
        
        // iPhone models mapping
        if model.contains("iphone10,3") || model.contains("iphone10,6") {
            return "iPhone X"
        }
        if model.contains("iphone11,2") {
            return "iPhone XS"
        }
        if model.contains("iphone11,4") || model.contains("iphone11,6") {
            return "iPhone XS Max"
        }
        if model.contains("iphone11,8") {
            return "iPhone XR"
        }
        if model.contains("iphone12,1") {
            return "iPhone 11"
        }
        if model.contains("iphone12,3") {
            return "iPhone 11 Pro"
        }
        if model.contains("iphone12,5") {
            return "iPhone 11 Pro Max"
        }
        if model.contains("iphone12,8") {
            return "iPhone SE (2nd gen)"
        }
        if model.contains("iphone13,1") {
            return "iPhone 12 mini"
        }
        if model.contains("iphone13,2") {
            return "iPhone 12"
        }
        if model.contains("iphone13,3") {
            return "iPhone 12 Pro"
        }
        if model.contains("iphone13,4") {
            return "iPhone 12 Pro Max"
        }
        if model.contains("iphone14,2") {
            return "iPhone 13 Pro"
        }
        if model.contains("iphone14,3") {
            return "iPhone 13 Pro Max"
        }
        if model.contains("iphone14,4") {
            return "iPhone 13 mini"
        }
        if model.contains("iphone14,5") {
            return "iPhone 13"
        }
        if model.contains("iphone14,6") {
            return "iPhone SE (3rd gen)"
        }
        if model.contains("iphone14,7") {
            return "iPhone 14"
        }
        if model.contains("iphone14,8") {
            return "iPhone 14 Plus"
        }
        if model.contains("iphone15,2") {
            return "iPhone 14 Pro"
        }
        if model.contains("iphone15,3") {
            return "iPhone 14 Pro Max"
        }
        if model.contains("iphone15,4") {
            return "iPhone 15"
        }
        if model.contains("iphone15,5") {
            return "iPhone 15 Plus"
        }
        if model.contains("iphone16,1") {
            return "iPhone 15 Pro"
        }
        if model.contains("iphone16,2") {
            return "iPhone 15 Pro Max"
        }
        if model.contains("iphone17,1") {
            return "iPhone 16"
        }
        if model.contains("iphone17,2") {
            return "iPhone 16 Plus"
        }
        if model.contains("iphone17,3") {
            return "iPhone 16 Pro"
        }
        if model.contains("iphone17,4") {
            return "iPhone 16 Pro Max"
        }
        
        // iPad models mapping
        if model.contains("ipad13,4") || model.contains("ipad13,5") ||
           model.contains("ipad13,6") || model.contains("ipad13,7") {
            return "iPad Pro (M1)"
        }
        if model.contains("ipad13,8") || model.contains("ipad13,9") ||
           model.contains("ipad13,10") || model.contains("ipad13,11") {
            return "iPad Air (M1)"
        }
        if model.contains("ipad14,3") || model.contains("ipad14,4") ||
           model.contains("ipad14,5") || model.contains("ipad14,6") {
            return "iPad Pro (M2)"
        }
        if model.contains("ipad14,8") || model.contains("ipad14,9") {
            return "iPad Air (M2)"
        }
        if model.contains("ipad16,3") || model.contains("ipad16,4") ||
           model.contains("ipad16,5") || model.contains("ipad16,6") {
            return "iPad Pro (M4)"
        }
        
        // Simulator
        if isSimulator {
            return "Simulator"
        }
        
        // Default to generic names
        switch deviceType {
        case .iPhone:
            return "iPhone"
        case .iPad:
            return "iPad"
        case .mac:
            return "Mac"
        case .unknown:
            return deviceModel
        }
    }
    
    static var deviceDescription: String {
        return deviceModelName
    }
    
    static var chipDescription: String {
        // First check if device supports Metal 3
        #if os(iOS)
        if let device = MTLCreateSystemDefaultDevice() {
            if device.supportsFamily(.metal3) {
                // Return the detected chip name with Metal 3 support indicator
                switch chipFamily {
                case .a13:
                    return "A13 Bionic (Metal 3)"
                case .a14:
                    return "A14 Bionic (Metal 3)"
                case .a15:
                    return "A15 Bionic (Metal 3)"
                case .a16:
                    return "A16 Bionic (Metal 3)"
                case .a17Pro:
                    return "A17 Pro (Metal 3)"
                case .a18:
                    return "A18 (Metal 3)"
                case .a18Pro:
                    return "A18 Pro (Metal 3)"
                case .m1:
                    return "M1 (Metal 3)"
                case .m2:
                    return "M2 (Metal 3)"
                case .m3:
                    return "M3 (Metal 3)"
                case .m4:
                    return "M4 (Metal 3)"
                case .unsupported:
                    return "Unsupported Chip"
                case .unknown:
                    // Device supports Metal 3 but we don't know the exact chip
                    return "Unknown Chip (Metal 3)"
                }
            }
        }
        #endif
        
        // Fallback to basic chip description
        switch chipFamily {
        case .a13:
            return "A13 Bionic"
        case .a14:
            return "A14 Bionic"
        case .a15:
            return "A15 Bionic"
        case .a16:
            return "A16 Bionic"
        case .a17Pro:
            return "A17 Pro"
        case .a18:
            return "A18"
        case .a18Pro:
            return "A18 Pro"
        case .m1:
            return "M1"
        case .m2:
            return "M2"
        case .m3:
            return "M3"
        case .m4:
            return "M4"
        case .unsupported:
            return "Unsupported Chip"
        case .unknown:
            return "Unknown Chip"
        }
    }
    
    static var compatibilityMessage: String {
        if canRunMLX {
            return "Your \(deviceDescription) with \(chipDescription) chip is compatible with MLX models."
        } else if isSimulator {
            return "Simulator detected. MLX models require real Apple Silicon hardware."
        } else {
            return "Your device doesn't support MLX models. MLX requires 6GB+ RAM and Metal 3 support (iPhone 11 Pro/SE 2nd gen or newer)."
        }
    }
    
    static var iOSVersion: String {
        return UIDevice.current.systemVersion
    }
    
    
    private static func getCPUType() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var cpu = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &cpu, &size, nil, 0)
        return String(cString: cpu)
    }
}