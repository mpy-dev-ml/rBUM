import Testing
@testable import Core

struct XPCMessageQueueTests {
    // MARK: - Properties

    let mockLogger = MockLogger()

    // MARK: - Setup

    func setup() async {
        mockLogger.reset()
    }

    // MARK: - Tests

    @Test("Message enqueuing works correctly")
    func testMessageEnqueuing() async throws {
        // Arrange
        let queue = XPCMessageQueue(logger: mockLogger)
        let command = XPCCommandConfig(
            command: "test",
            arguments: ["--arg1", "value1"],
            workingDirectory: nil
        )

        // Act
        let messageId = await queue.enqueue(command)
        let status = await queue.queueStatus()

        // Assert
        #expect(status.pending == 1)
        #expect(status.inProgress == 0)
        #expect(status.completed == 0)
        #expect(status.failed == 0)
        #expect(!messageId.uuidString.isEmpty)
    }

    @Test("Message processing transitions states correctly")
    func testMessageProcessing() async throws {
        // Arrange
        let queue = XPCMessageQueue(logger: mockLogger)
        let command = XPCCommandConfig(
            command: "test",
            arguments: [],
            workingDirectory: nil
        )

        // Act
        let messageId = await queue.enqueue(command)
        let message = await queue.nextPendingMessage()

        // Assert
        #expect(message != nil)
        #expect(message?.id == messageId)
        #expect(message?.status == .inProgress)

        let status = await queue.queueStatus()
        #expect(status.pending == 0)
        #expect(status.inProgress == 1)
    }

    @Test("Message completion updates status correctly")
    func testMessageCompletion() async throws {
        // Arrange
        let queue = XPCMessageQueue(logger: mockLogger)
        let command = XPCCommandConfig(
            command: "test",
            arguments: [],
            workingDirectory: nil
        )

        // Act
        let messageId = await queue.enqueue(command)
        _ = await queue.nextPendingMessage()
        await queue.completeMessage(messageId)

        // Assert
        let status = await queue.queueStatus()
        #expect(status.pending == 0)
        #expect(status.inProgress == 0)
        #expect(status.completed == 1)
        #expect(status.failed == 0)
    }

    @Test("Message failure handles retries correctly")
    func testMessageFailureAndRetry() async throws {
        // Arrange
        let queue = XPCMessageQueue(maxRetries: 2, retryDelay: 0.1, logger: mockLogger)
        let command = XPCCommandConfig(
            command: "test",
            arguments: [],
            workingDirectory: nil
        )

        // Act
        let messageId = await queue.enqueue(command)

        // First attempt
        let message1 = await queue.nextPendingMessage()
        let error = ResticXPCError.connectionNotEstablished
        await queue.completeMessage(messageId, error: error)

        // Should be pending again for retry
        let status1 = await queue.queueStatus()
        #expect(status1.pending == 1)

        // Second attempt
        let message2 = await queue.nextPendingMessage()
        await queue.completeMessage(messageId, error: error)

        // Should be pending for final retry
        let status2 = await queue.queueStatus()
        #expect(status2.pending == 1)

        // Final attempt
        let message3 = await queue.nextPendingMessage()
        await queue.completeMessage(messageId, error: error)

        // Should be marked as failed
        let status3 = await queue.queueStatus()
        #expect(status3.failed == 1)
        #expect(status3.pending == 0)
    }

    @Test("Queue cleanup removes completed and failed messages")
    func testQueueCleanup() async throws {
        // Arrange
        let queue = XPCMessageQueue(logger: mockLogger)

        // Add completed message
        let completedCommand = XPCCommandConfig(command: "completed", arguments: [], workingDirectory: nil)
        let completedId = await queue.enqueue(completedCommand)
        _ = await queue.nextPendingMessage()
        await queue.completeMessage(completedId)

        // Add failed message
        let failedCommand = XPCCommandConfig(command: "failed", arguments: [], workingDirectory: nil)
        let failedId = await queue.enqueue(failedCommand)
        _ = await queue.nextPendingMessage()
        await queue.completeMessage(failedId, error: ResticXPCError.connectionNotEstablished)

        // Add pending message
        let pendingId = await queue.enqueue(XPCCommandConfig(command: "pending", arguments: [], workingDirectory: nil))

        // Act
        await queue.cleanup()

        // Assert
        let status = await queue.queueStatus()
        #expect(status.completed == 0)
        #expect(status.failed == 0)
        #expect(status.pending == 1)
    }
}
