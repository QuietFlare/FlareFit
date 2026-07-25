//
//  Theme.swift
//  FlareFit
//

import SwiftUI

extension LinearGradient {
    /// The FlareFit ember gradient — same palette as the app icon.
    static var ember: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.45, blue: 0.10),
                Color(red: 0.85, green: 0.16, blue: 0.05),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Deeper variant used for full-screen backgrounds.
    static var emberDeep: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.45, blue: 0.10),
                Color(red: 0.85, green: 0.16, blue: 0.05),
                Color(red: 0.45, green: 0.05, blue: 0.10),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
