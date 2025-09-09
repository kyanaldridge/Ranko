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
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: rectangleSpacing) {
                // Left Rectangle
                RoundedRectangle(cornerRadius: rectangleCornerRadius)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFDE5C), Color(hex: 0xFFC456)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: rectangleWidth,
                           height: animateLeft ? rectangleMaxHeight * 0.65 : rectangleMaxHeight * 0.1)
                    .animation(.easeInOut(duration: animationDuration), value: animateLeft)
                
                // Middle Rectangle
                RoundedRectangle(cornerRadius: rectangleCornerRadius)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFC355), Color(hex: 0xFFAB51)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: rectangleWidth,
                           height: animateMiddle ? rectangleMaxHeight * 1 : rectangleMaxHeight * 0.1)
                    .animation(.easeInOut(duration: animationDuration), value: animateMiddle)
                
                // Right Rectangle
                RoundedRectangle(cornerRadius: rectangleCornerRadius)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFAA51), Color(hex: 0xFF914D)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: rectangleWidth,
                           height: animateRight ? rectangleMaxHeight * 0.5 : rectangleMaxHeight * 0.1)
                    .animation(.easeInOut(duration: animationDuration), value: animateRight)
            }
        }
        .frame(height: rectangleMaxHeight)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        let delay = animationDuration
        Timer.scheduledTimer(withTimeInterval: delay * 3 - 0.4, repeats: true) { _ in
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
        DispatchQueue.main.asyncAfter(deadline: .now() + delay - 0.4) {
            withAnimation { animateMiddle = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay * 2 - 0.4) {
            withAnimation { animateMiddle = false }
        }
        
        // Right animation
        DispatchQueue.main.asyncAfter(deadline: .now() + delay * 2 - 0.8) {
            withAnimation { animateRight = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay * 3 - 1) {
            withAnimation { animateRight = false }
        }
    }
}

struct ThreeRectanglesAnimation_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 50) {
                RoundedRectangle(cornerRadius: 10)
                    .frame(width: 380, height: 400)
                ThreeRectanglesAnimation(rectangleWidth: 80, rectangleMaxHeight: 250, rectangleSpacing: 10, rectangleCornerRadius: 10, animationDuration: 0.7)
                    .frame(height: 250)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .frame(width: 380, height: 260)
                    )
                ThreeRectanglesAnimation(rectangleWidth: 4, rectangleMaxHeight: 12, rectangleSpacing: 1, rectangleCornerRadius: 1, animationDuration: 0.7)
                    .frame(height: 18)
            }
        }
    }
}

