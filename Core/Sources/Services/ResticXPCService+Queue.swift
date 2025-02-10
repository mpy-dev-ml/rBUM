import Foundation

@available(macOS 13.0, *)
extension ResticXPCService {
    // MARK: - Queue Processing

    /// Process the next message in the queue
    func processNextMessage() async {
        guard let message = await messageQueue.nextPendingMessage() else {
            return
        }

        do {
            let result = try await executeCommand(message.command)
            await messageQueue.completeMessage(message.id)

            // Notify success
            NotificationCenter.default.post(
                name: .xpcCommandCompleted,
                object: nil,
                userInfo: [
                    "messageId": message.id,
                    "result": result,
                ]
            )
        } catch {
            await messageQueue.completeMessage(message.id, error: error)

            // Notify failure
            NotificationCenter.default.post(
                name: .xpcCommandFailed,
                object: nil,
                userInfo: [
                    "messageId": message.id,
                    "error": error,
                ]
            )
        }
    }

    /// Start the queue processor
    func startQueueProcessor() {
        guard queueProcessor == nil else { return }

        queueProcessor = Task {
            while !Task.isCancelled {
                await processNextMessage()
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            }
        }
    }

    /// Stop the queue processor
    func stopQueueProcessor() {
        queueProcessor?.cancel()
        queueProcessor = nil
    }

    // MARK: - Queue Management

    /// Enqueue a command for execution
    /// - Parameter command: The command to execute
    /// - Returns: The ID of the queued message
    func enqueueCommand(_ command: XPCCommandConfig) async -> UUID {
        let messageId = await messageQueue.enqueue(command)
        startQueueProcessor()
        return messageId
    }

    /// Get the current status of the message queue
    /// - Returns: The current queue status
    func getQueueStatus() async -> XPCMessageQueue.QueueStatus {
        await messageQueue.queueStatus()
    }

    /// Clean up completed and failed messages
    func cleanupQueue() async {
        await messageQueue.cleanup()
    }
}
