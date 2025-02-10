import Foundation

/// Represents a queued XPC message with retry information
public struct XPCQueuedMessage: Identifiable {
    public let id: UUID
    let command: XPCCommandConfig
    let createdAt: Date
    var retryCount: Int
    var lastAttempt: Date?
    var status: MessageStatus

    public enum MessageStatus {
        case pending
        case inProgress
        case completed
        case failed(Error)
    }

    init(command: XPCCommandConfig) {
        id = UUID()
        self.command = command
        createdAt = Date()
        retryCount = 0
        status = .pending
    }
}

/// Manages the queue of XPC messages with retry logic
@available(macOS 13.0, *)
public actor XPCMessageQueue {
    // MARK: - Properties

    private var messages: [XPCQueuedMessage]
    private let maxRetries: Int
    private let retryDelay: TimeInterval
    private let logger: LoggerProtocol

    /// Current health status
    private(set) var currentStatus: XPCHealthStatus

    // MARK: - Initialization

    /// Initializes a new XPC message queue
    /// - Parameters:
    ///   - maxRetries: Maximum number of retries for failed messages
    ///   - retryDelay: Delay between retry attempts in seconds
    ///   - logger: Logger instance for tracking queue operations
    public init(
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        logger: LoggerProtocol
    ) {
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.logger = logger
        currentStatus = .unknown
        messages = []
    }

    // MARK: - Queue Management

    /// Enqueue a new command for execution
    /// - Parameter command: The command configuration to queue
    /// - Returns: The ID of the queued message
    public func enqueue(_ command: XPCCommandConfig) -> UUID {
        let message = XPCQueuedMessage(command: command)
        messages.append(message)
        logger.debug("Enqueued message \(message.id)", privacy: .public)
        return message.id
    }

    /// Get the next pending message for processing
    /// - Returns: The next message to process, if any
    public func nextPendingMessage() -> XPCQueuedMessage? {
        guard let index = messages.firstIndex(where: { $0.status == .pending }) else {
            return nil
        }

        // Check if message is in progress
        if case .inProgress = messages[index].status {
            let msgId = messages[index].id
            logger.warning(
                "Message \(msgId) is already in progress",
                privacy: .public
            )
            return nil
        }

        // Check if message is completed
        if case .completed = messages[index].status {
            let msgId = messages[index].id
            logger.warning(
                "Message \(msgId) is already completed",
                privacy: .public
            )
            return nil
        }

        messages[index].status = .inProgress
        messages[index].lastAttempt = Date()
        return messages[index]
    }

    /// Handle completion of a message
    /// - Parameters:
    ///   - id: The message ID
    ///   - error: Optional error if the message failed
    public func completeMessage(_ id: UUID, error: Error? = nil) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else {
            logger.error("Message \(id) not found for completion", privacy: .public)
            return
        }

        if let error {
            handleMessageFailure(at: index, error: error)
        } else {
            messages[index].status = .completed
            logger.debug("Message \(id) completed successfully", privacy: .public)
        }
    }

    // MARK: - Private Methods

    private func handleMessageFailure(at index: Int, error: Error) {
        messages[index].retryCount += 1
        let msgId = messages[index].id

        if messages[index].retryCount >= maxRetries {
            messages[index].status = .failed(error)
            logger.error(
                "Message \(msgId) failed after \(maxRetries) retries: \(error.localizedDescription)",
                privacy: .public
            )
        } else {
            messages[index].status = .pending
            logger.warning(
                "Message \(msgId) failed, scheduling retry \(messages[index].retryCount)/\(maxRetries)",
                privacy: .public
            )
        }
    }

    /// Clean up completed and failed messages
    public func cleanup() {
        messages.removeAll { message in
            switch message.status {
            case .completed,
                 .failed:
                true
            default:
                false
            }
        }
    }

    // MARK: - Queue Status

    /// Represents the current status of the message queue
    public struct QueueStatus {
        /// Number of pending messages
        public let pending: Int
        /// Number of in-progress messages
        public let inProgress: Int
        /// Number of completed messages
        public let completed: Int
        /// Number of failed messages
        public let failed: Int
    }

    /// Get the current queue status
    /// - Returns: Current status of the message queue
    public func queueStatus() async -> QueueStatus {
        var pending = 0
        var inProgress = 0
        var completed = 0
        var failed = 0

        for message in messages {
            switch message.status {
            case .pending:
                pending += 1
            case .inProgress:
                inProgress += 1
            case .completed:
                completed += 1
            case .failed:
                failed += 1
            }
        }

        return QueueStatus(
            pending: pending,
            inProgress: inProgress,
            completed: completed,
            failed: failed
        )
    }
}
