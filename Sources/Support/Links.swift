import Foundation

/// The author's links, in one place. They appear on the splash and in About,
/// and are the kind of constant that quietly drifts apart when each screen
/// keeps its own copy.
enum Links {
    static let website = URL(string: "https://ividi.dev/")!
    static let github = URL(string: "https://github.com/VidiPT89/")!
    /// The App Store Connect privacy policy URL points here too.
    static let privacy = URL(string: "https://github.com/VidiPT89/iVidiPinball/blob/main/PRIVACY.md")!
}
