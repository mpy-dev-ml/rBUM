import Foundation

public enum RepositoryCreationError: LocalizedError {
    case invalidPath(String)
    case pathAlreadyExists
    case creationFailed(String)
    case importFailed(String)
    case repositoryAlreadyExists
    case invalidRepository
    case credentialsNotFound
    case invalidCredentials
    case bookmarkError(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPath(let reason):
            return "Invalid repository path: \(reason)"
        case .pathAlreadyExists:
            return "A repository already exists at this path"
        case .creationFailed(let reason):
            return "Failed to create repository: \(reason)"
        case .importFailed(let reason):
            return "Failed to import repository: \(reason)"
        case .repositoryAlreadyExists:
            return "A repository with this name already exists"
        case .invalidRepository:
            return "Invalid repository format"
        case .credentialsNotFound:
            return "Repository credentials not found"
        case .invalidCredentials:
            return "Invalid repository credentials"
        case .bookmarkError(let reason):
            return "Bookmark error: \(reason)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}
