//
//  ShakeEffect.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 17/4/2025.
//

import SwiftUI

/// A custom geometry effect for creating a shake animation.
struct ShakeEffect: GeometryEffect {
    var travelDistance: CGFloat = 10
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = travelDistance * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
