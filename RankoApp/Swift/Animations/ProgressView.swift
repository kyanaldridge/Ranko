//
//  ProgressView.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 2/8/2025.
//

import SwiftUI

struct ThreeRectanglesAnimation: View {
    @State private var animateLeft = false
    @State private var animateMiddle = false
    @State private var animateRight = false
    
    let rectangleWidth: CGFloat
    let rectangleMaxHeight: CGFloat
    let rectangleSpacing: CGFloat
    let rectangleCornerRadius: CGFloat
    let animationDuration: Double
    
    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: rectangleSpacing) {
                // Left Rectangle
                RoundedRectangle(cornerRadius: rectangleCornerRadius)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFDE5C), Color(hex: 0xFFC456)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: rectangleWidth,
                           height: animateLeft ? rectangleMaxHeight * 0.6 : rectangleMaxHeight * 0.1)
                    .animation(.easeInOut(duration: 0.7), value: animateLeft)
                
                // Middle Rectangle
                RoundedRectangle(cornerRadius: rectangleCornerRadius)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFC355), Color(hex: 0xFFAB51)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: rectangleWidth,
                           height: animateMiddle ? rectangleMaxHeight * 0.9 : rectangleMaxHeight * 0.1)
                    .animation(.easeInOut(duration: 0.7), value: animateMiddle)
                
                // Right Rectangle
                RoundedRectangle(cornerRadius: rectangleCornerRadius)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFAA51), Color(hex: 0xFF914D)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: rectangleWidth,
                           height: animateRight ? rectangleMaxHeight * 0.4 : rectangleMaxHeight * 0.1)
                    .animation(.easeInOut(duration: 0.7), value: animateRight)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        let delay = animationDuration
        Timer.scheduledTimer(withTimeInterval: delay * 3, repeats: true) { _ in
            animateSequence(delay: delay)
        }
        animateSequence(delay: delay)
    }
    
    private func animateSequence(delay: Double) {
        // Left animation
        withAnimation {
            animateLeft = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation { animateLeft = false }
        }
        
        // Middle animation
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation { animateMiddle = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay * 2) {
            withAnimation { animateMiddle = false }
        }
        
        // Right animation
        DispatchQueue.main.asyncAfter(deadline: .now() + delay * 2) {
            withAnimation { animateRight = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay * 3 - 0.1) {
            withAnimation { animateRight = false }
        }
    }
}

struct ThreeRectanglesAnimation_Previews: PreviewProvider {
    static var previews: some View {
        ThreeRectanglesAnimation(rectangleWidth: 80, rectangleMaxHeight: 200, rectangleSpacing: 10, rectangleCornerRadius: 10, animationDuration: 0.7)
            .frame(height: 250)
            .padding()
    }
}

