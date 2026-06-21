//
//  Created by Jerel Walters on 6/21/26.
//  Copyright © 2026 Jerel Walters. All rights reserved.
//

import SwiftUI
import UIKit

enum HMColor {
    static let canvas = adaptive(light: 0xEEF2F5, dark: 0x071525)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x0B2A45)
    static let surfaceMuted = adaptive(light: 0xF3F6F7, dark: 0x102F49)
    static let textPrimary = adaptive(light: 0x071525, dark: 0xFFFFFF)
    static let textSecondary = adaptive(light: 0x607080, dark: 0xA9BAC8)
    static let border = adaptive(light: 0xC5CFD5, dark: 0x426077)
    static let brandNavy = adaptive(light: 0x061D33, dark: 0x02172B)
    static let accent = adaptive(light: 0xFFAB1A, dark: 0xFFB423)
    static let success = adaptive(light: 0x159866, dark: 0x64E69E)
    static let successSurface = adaptive(light: 0xE8F7EF, dark: 0x174C39)
    static let warning = adaptive(light: 0xD68100, dark: 0xFFB423)
    static let warningSurface = adaptive(light: 0xFFF8E8, dark: 0x3D3014)
    static let danger = adaptive(light: 0xD84B24, dark: 0xFF8B6B)
    static let dangerSurface = adaptive(light: 0xFFF0EB, dark: 0x43251F)
    static let link = adaptive(light: 0x146AC2, dark: 0x72B7FF)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(
            uiColor: UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

enum HMSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum HMRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 18
}

enum HMFont {
    static let screenTitle = Font.system(.largeTitle, design: .default, weight: .bold)
    static let sectionTitle = Font.system(.title3, design: .default, weight: .bold)
    static let cardTitle = Font.system(.headline, design: .default, weight: .bold)
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let caption = Font.system(.caption, design: .default, weight: .medium)
    static let eyebrow = Font.system(.caption, design: .default, weight: .bold)
}

enum HMButtonKind {
    case accent
    case navy
}

struct HMPrimaryButtonStyle: ButtonStyle {
    let kind: HMButtonKind

    init(kind: HMButtonKind = .navy) {
        self.kind = kind
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: HMRadius.medium))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        kind == .accent ? HMColor.accent : HMColor.brandNavy
    }

    private var foregroundColor: Color {
        kind == .accent ? HMColor.brandNavy : .white
    }
}

private struct HMCardModifier: ViewModifier {
    let backgroundColor: Color

    func body(content: Content) -> some View {
        content
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: HMRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: HMRadius.large)
                    .stroke(HMColor.border, lineWidth: 1)
            }
    }
}

private struct HMAppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(HMColor.canvas.ignoresSafeArea())
    }
}

extension View {
    func hmCard(backgroundColor: Color = HMColor.surface) -> some View {
        modifier(HMCardModifier(backgroundColor: backgroundColor))
    }

    func hmAppBackground() -> some View {
        modifier(HMAppBackgroundModifier())
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

#if DEBUG
#Preview("Design System") {
    DesignSystemPreview()
}

private struct DesignSystemPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: HMSpacing.lg) {
            Text(AppStrings.appName.localized)
                .font(HMFont.screenTitle)
                .foregroundStyle(HMColor.textPrimary)

            Text(DesignSystemStrings.previewSubtitle.localized)
                .font(HMFont.body)
                .foregroundStyle(HMColor.textSecondary)

            Button(DesignSystemStrings.primaryAction.localized) {}
                .buttonStyle(HMPrimaryButtonStyle(kind: .accent))

            Button(DesignSystemStrings.secondaryAction.localized) {}
                .buttonStyle(HMPrimaryButtonStyle())
        }
        .padding(HMSpacing.xl)
        .hmAppBackground()
    }
}
#endif
