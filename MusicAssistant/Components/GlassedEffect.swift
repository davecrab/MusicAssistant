//
//  GlassedEffect.swift
//  Ai Assist
//
//  Created by Dave Crabtree on 2025-06-27.
//

import SwiftUI

extension View {
    @ViewBuilder
    public func glassedEffect(in shape: some Shape, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self.background {
                shape.glassed()
            }
        }
    }
}

extension Shape {
    public func glassed() -> some View {
        self
            .fill(.ultraThinMaterial)
            //            .fill(
            //                .linearGradient(
            //                    colors: [
            //                        .primary.opacity(0.08),
            //                        .primary.opacity(0.05),
            //                        .primary.opacity(0.01),
            //                        .clear,
            //                        .clear,
            //                        .clear
            //                    ],
            //                    startPoint: .topLeading,
            //                    endPoint: .bottomTrailing
            //                )
            //            )
            .stroke(.primary.opacity(0.2), lineWidth: 0.7)
    }
}

// MARK: - Glass Effect Container
struct GlassedEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 12.0, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - Glass Effect ID Extension
extension View {
    public func glassEffectID(_ id: String, in namespace: Namespace.ID) -> some View {
        self.id(id)
    }
}
