import SwiftUI
import UIKit

/// Central theme system for Synk app
/// Uses coral/warm orange as the primary brand color
enum Theme {
    // MARK: - Primary Brand Colors

    /// Main brand color - coral/warm orange
    /// Light: #FF6B6B, Dark: #FF7F7F (slightly brighter for visibility)
    static var primary: Color {
        Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 1.0, green: 0.498, blue: 0.498, alpha: 1.0) // #FF7F7F
            } else {
                return UIColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0) // #FF6B6B
            }
        })
    }

    /// Darker primary for pressed states and emphasis
    /// Light: #E85555, Dark: #FF6B6B
    static var primaryDark: Color {
        Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0) // #FF6B6B
            } else {
                return UIColor(red: 0.91, green: 0.333, blue: 0.333, alpha: 1.0) // #E85555
            }
        })
    }

    /// Light primary for avatar backgrounds and highlights
    /// Light: #FFF0F0, Dark: #3D2828
    static var primaryLight: Color {
        Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.24, green: 0.157, blue: 0.157, alpha: 1.0) // #3D2828
            } else {
                return UIColor(red: 1.0, green: 0.941, blue: 0.941, alpha: 1.0) // #FFF0F0
            }
        })
    }

    // MARK: - Chat Background

    /// Chat message area background - warm cream
    /// Light: #FAF5F2, Dark: #1C1A19
    static var chatBackground: Color {
        Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.11, green: 0.10, blue: 0.10, alpha: 1.0) // #1C1A19
            } else {
                return UIColor(red: 0.98, green: 0.96, blue: 0.95, alpha: 1.0) // #FAF5F2
            }
        })
    }

    // MARK: - Semantic Colors (iOS Defaults)

    /// Use system green for completed tasks, checkmarks
    static var success: Color { .green }

    /// Use system orange for due soon, overdue dates
    static var warning: Color { .orange }

    /// Use system red for delete actions, errors
    static var error: Color { .red }
}
