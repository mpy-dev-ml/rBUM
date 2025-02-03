import Foundation

/// Protocol defining the interface for the Restic XPC service
@objc public protocol ResticServiceProtocol {
    /// Execute a restic command
    func executeCommand(_ command: String, 
                       arguments: [String], 
                       environment: [String: String], 
                       workingDirectory: String, 
                       withReply reply: @escaping (Data?, Error?) -> Void)
    
    /// Check if restic is available
    func checkResticAvailability(withReply reply: @escaping (Bool, String?) -> Void)
    
    /// Get version information
    func getVersion(withReply reply: @escaping (String?, Error?) -> Void)
}

/// Main class implementing the Restic XPC service
class ResticService: NSObject, ResticServiceProtocol {
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.ResticService", qos: .userInitiated)
    private let fileManager = FileManager.default
    
    func executeCommand(_ command: String,
                       arguments: [String],
                       environment: [String: String],
                       workingDirectory: String,
                       withReply reply: @escaping (Data?, Error?) -> Void) {
        queue.async {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: command)
                process.arguments = arguments
                process.environment = environment
                process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus == 0 {
                    reply(outputData, nil)
                } else {
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    reply(nil, NSError(domain: "ResticServiceError",
                                     code: Int(process.terminationStatus),
                                     userInfo: [NSLocalizedDescriptionKey: errorMessage]))
                }
            } catch {
                reply(nil, error)
            }
        }
    }
    
    func checkResticAvailability(withReply reply: @escaping (Bool, String?) -> Void) {
        queue.async {
            let paths = ProcessInfo.processInfo.environment["PATH"]?.components(separatedBy: ":")
            let resticPath = paths?.first { path in
                let resticURL = URL(fileURLWithPath: path).appendingPathComponent("restic")
                return self.fileManager.fileExists(atPath: resticURL.path)
            }
            
            if let path = resticPath {
                reply(true, path)
            } else {
                reply(false, nil)
            }
        }
    }
    
    func getVersion(withReply reply: @escaping (String?, Error?) -> Void) {
        queue.async {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/local/bin/restic")
                process.arguments = ["version"]
                
                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let version = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                
                reply(version, nil)
            } catch {
                reply(nil, error)
            }
        }
    }
}

// Main entry point for the XPC service
class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: ResticServiceProtocol.self)
        let exportedObject = ResticService()
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
    }
}

// Start the XPC service
let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
