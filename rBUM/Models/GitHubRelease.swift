import Foundation

/// Model representing a GitHub release
struct GitHubRelease: Codable {
    /// The tag name of the release
    let tagName: String
    
    /// The name of the release
    let name: String
    
    /// The release description/body
    let body: String
    
    /// The HTML URL of the release
    let htmlUrl: String
    
    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
    }
}
