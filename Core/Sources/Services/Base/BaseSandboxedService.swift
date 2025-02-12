import Foundation

/// Base class for services requiring sandbox compliance
open class BaseSandboxedService: BaseService {
    // MARK: - Properties

    public let securityService: SecurityServiceProtocol

    // MARK: - Initialization

    public init(logger: LoggerProtocol, securityService: SecurityServiceProtocol) {
        self.securityService = securityService
        super.init(logger: logger)
    }

    // MARK: - Public Methods

    open func startAccessing(_ url: URL) async throws -> Bool {
        do {
            return try await securityService.validateAccess(to: url)
        } catch {
            logger.error(
                "Failed to start accessing \(url.path): \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw error
        }
    }

    open func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
