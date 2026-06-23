import UIKit
import MLX
import MLXRandom
import MLXNN

class MemoryManager {
    static let shared = MemoryManager()
    
    private var memoryWarningObserver: NSObjectProtocol?
    private var observers: [MemoryPressureObserver] = []
    
    // Cache references
    private weak var modelManager: ModelManager?
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Setup
    
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    // MARK: - Memory Warning Handling
    
    private func handleMemoryWarning() {
        print("⚠️ Memory Warning Received - Starting cleanup")
        
        // 1. Reduce MLX GPU cache limit more aggressively for low-memory devices
        let chipFamily = DeviceUtils.chipFamily
        let reducedLimit: Int
        
        switch chipFamily {
        case .a13, .a14:
            // Aggressive reduction for 4GB RAM devices
            reducedLimit = 32 * 1024 * 1024 // 32MB
        case .a15:
            // Moderate reduction for 6GB RAM devices
            reducedLimit = 64 * 1024 * 1024 // 64MB
        default:
            // Standard reduction for newer devices
            reducedLimit = 128 * 1024 * 1024 // 128MB
        }
        
        MLX.Memory.cacheLimit = reducedLimit
        print("✓ Reduced GPU cache limit to \(reducedLimit/1024/1024)MB for \(DeviceUtils.chipDescription)")
        
        // 2. Clear any image caches
        URLCache.shared.removeAllCachedResponses()
        print("✓ Cleared URL cache")
        
        // 3. Notify observers to clear their caches
        notifyObservers()
        
        // 4. Force garbage collection
        autoreleasepool {
            // This helps release any autoreleased objects
        }
        
        // 5. Log memory usage
        logMemoryUsage()
    }
    
    // MARK: - Observer Pattern
    
    func addObserver(_ observer: MemoryPressureObserver) {
        observers.append(observer)
    }
    
    func removeObserver(_ observer: MemoryPressureObserver) {
        observers.removeAll { $0 === observer }
    }
    
    private func notifyObservers() {
        observers.forEach { observer in
            observer.didReceiveMemoryWarning()
        }
    }
    
    // MARK: - Memory Usage Monitoring
    
    func logMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            print("📊 Current Memory Usage: \(String(format: "%.1f", usedMemoryMB)) MB")
        }
    }
    
    // MARK: - Manual Memory Management
    
    func performLowMemoryCleanup() {
        handleMemoryWarning()
    }
    
    func resetGPUCacheLimit() {
        // Reset to appropriate limit based on device
        let chipFamily = DeviceUtils.chipFamily
        let defaultLimit: Int
        
        switch chipFamily {
        case .a13, .a14:
            defaultLimit = 64 * 1024 * 1024 // 64MB for 4GB RAM devices
        case .a15:
            defaultLimit = 128 * 1024 * 1024 // 128MB for 6GB RAM devices
        case .a16, .a17Pro, .a18, .a18Pro, .a19, .a19Pro:
            defaultLimit = 256 * 1024 * 1024 // 256MB for newer devices
        case .m1, .m2, .m3, .m4, .m5:
            defaultLimit = 512 * 1024 * 1024 // 512MB for iPad M-series
        default:
            defaultLimit = 32 * 1024 * 1024 // Conservative default
        }
        
        MLX.Memory.cacheLimit = defaultLimit
        print("✓ Reset GPU cache limit to \(defaultLimit/1024/1024)MB for \(DeviceUtils.chipDescription)")
    }
}

// MARK: - Memory Pressure Observer Protocol

protocol MemoryPressureObserver: AnyObject {
    func didReceiveMemoryWarning()
}