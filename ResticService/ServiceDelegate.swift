import Core
import Foundation

final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Configure the connection.
        // First, set the interface that the exported object implements.
        newConnection.exportedInterface = NSXPCInterface(with: ResticXPCProtocol.self)

        // Next, set the object that the connection exports. All messages sent on the connection to this service will be
        // sent to the exported object to handle. The connection retains the exported object.
        let exportedObject = ResticService()
        newConnection.exportedObject = exportedObject

        // Resuming the connection allows the system to deliver more incoming messages.
        newConnection.resume()

        // Returning true from this method tells the system that you have accepted this connection. If you want to
        // reject the connection for some reason, call invalidate() on the connection and return false.
        return true
    }
}
