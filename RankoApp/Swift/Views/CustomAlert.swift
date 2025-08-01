//
//  CustomAlert.swift
//  RankoApp
//
//  Created by Kyan Aldridge on 1/8/2025.
//

import SwiftUI

extension View {
    @ViewBuilder
    func alert<Content: View, Background: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder background: @escaping () -> Background
    ) -> some View {
        self
            .modifier(CustomAlertModifier(isPresented: isPresented, alertContent: content, background: background))
    }
}

/// Helper Modifier
fileprivate struct CustomAlertModifier<AlertContent: View, Background: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder var alertContent: AlertContent
    @ViewBuilder var background: Background
    /// View Properties
    @State private var showFullScreenCover: Bool = false
    @State private var animatedValue: Bool = false
    @State private var allowsInteraction: Bool = false
    
    func body(content: Content) -> some View {
        content
            /// Using Full Screen Cover to show alert content on top of the current context
            .fullScreenCover(isPresented: $showFullScreenCover) {
                ZStack {
                    if animatedValue {
                        alertContent
                            .allowsHitTesting(allowsInteraction)
                    }
                }
                .presentationBackground {
                    background
                        .allowsHitTesting(allowsInteraction)
                        .opacity(animatedValue ? 1 : 0)
                }
                .task {
                    try? await Task.sleep(for: .seconds(0.05))
                    withAnimation(.easeInOut(duration: 0.3)) {
                        animatedValue = true
                    }
                    
                    try? await Task.sleep(for: .seconds(0.3))
                    allowsInteraction = true
                }
            }
            .onChange(of: isPresented) { oldValue, newValue in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                
                if newValue {
                    withTransaction(transaction) {
                        showFullScreenCover = true
                    }
                } else {
                    allowsInteraction = false
                    withAnimation(.easeInOut(duration: 0.3), completionCriteria: .removed) {
                        animatedValue = false
                    } completion: {
                        /// Removing full-screen-cover without animation
                        withTransaction(transaction) {
                            showFullScreenCover = false
                        }
                    }
                }
            }
    }
}

struct CustomAlertDemo: View {
    @State private var showAlert = false
    @State private var showAlert1 = false
    @State private var showAlert2 = false
    var body: some View {
        NavigationStack {
            List {
                Section("Usage") {
                    Text(
                        """
                        **.alert(isPresented) {**
                            /// Content
                        **} background: {**
                            /// Background
                        **}**
                        """
                    )
                    .monospaced()
                    .lineSpacing(8)
                }
                
                Button("TextField Alert") {
                    showAlert.toggle()
                }
                .alert(isPresented: $showAlert) {
                    CustomDialog(
                        title: "Folder Name",
                        content: "Enter a file Name",
                        image: .init(content: "folder.fill.badge.plus", background: .blue, foreground: .white),
                        button1: .init(content: "Save Folder", background: .blue, foreground: .white, action: { folder in
                            print(folder)
                            showAlert = false
                        }),
                        button2: .init(content: "Cancel", background: .red, foreground: .white, action: { _ in
                            showAlert = false
                        }),
                        addsTextField: true,
                        textFieldHint: "Personal Documents"
                    )
                    .transition(.blurReplace.combined(with: .scale(0.8)))
                } background: {
                    Rectangle()
                        .fill(.primary.opacity(0.35))
                }
                
                Button("Dialog Alert") {
                    showAlert1.toggle()
                }
                .alert(isPresented: $showAlert1) {
                    CustomDialog(
                        title: "Replace Existing File?",
                        content: "This will rewrite the existing file with the new file content.",
                        image: .init(
                            content: "questionmark.folder.fill",
                            background: .blue,
                            foreground: .white
                        ),
                        button1: .init(
                            content: "Replace",
                            background: .blue,
                            foreground: .white,
                            action: { _ in
                                showAlert1 = false
                            }
                        ),
                        button2: .init(
                            content: "Cancel",
                            background: Color.primary.opacity(0.08),
                            foreground: Color.primary,
                            action: { _ in
                                showAlert1 = false
                            }
                        )
                    )
                    .transition(.blurReplace.combined(with: .push(from: .bottom)))
                } background: {
                    Rectangle()
                        .fill(.primary.opacity(0.35))
                }
                
                Button("Alert") {
                    showAlert2.toggle()
                }
                .alert(isPresented: $showAlert2) {
                    CustomDialog(
                        title: "Application Error",
                        content: "There was an error while saving your file.\nPlease try again later.",
                        image: .init(
                            content: "externaldrive.fill.trianglebadge.exclamationmark",
                            background: .blue,
                            foreground: .white
                        ),
                        button1: .init(
                            content: "Done",
                            background: .red,
                            foreground: .white,
                            action: { _ in
                            showAlert2 = false
                        })
                    )
                    .transition(.blurReplace)
                } background: {
                    Rectangle()
                        .fill(.primary.opacity(0.35))
                }
            }
            .navigationTitle("Custom Alert")
        }
    }
}

struct CustomDialog: View {
    var title: String
    var content: String?
    var image: Config
    var button1: Config
    var button2: Config?
    var addsTextField: Bool = false
    var textFieldHint: String = ""
    /// State Properties
    @State private var text: String = ""
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: image.content)
                .font(.title)
                .foregroundStyle(image.foreground)
                .frame(width: 65, height: 65)
                .background(image.background.gradient, in: .circle)
                .background {
                    Circle()
                        .stroke(.background, lineWidth: 8)
                }
            
            Text(title)
                .font(.title3.bold())
            
            if let content {
                Text(content)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .foregroundStyle(.gray)
                    .padding(.vertical, 4)
            }
            
            if addsTextField {
                TextField(textFieldHint, text: $text)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.gray.opacity(0.1))
                    }
                    .padding(.bottom, 5)
            }
            
            ButtonView(button1)
            
            if let button2 {
                ButtonView(button2)
                    .padding(.top, -5)
            }
        }
        .padding([.horizontal, .bottom], 15)
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(.background)
                .padding(.top, 30)
        }
        .frame(maxWidth: 310)
        .compositingGroup()
    }
    
    /// Button View
    @ViewBuilder
    private func ButtonView(_ config: Config) -> some View {
        Button {
            config.action(addsTextField ? text : "")
        } label: {
            Text(config.content)
                .fontWeight(.bold)
                .foregroundStyle(config.foreground)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
        }
        .tint(config.background)
        .buttonStyle(.glassProminent)
    }
    
    struct Config {
        var content: String
        var background: Color
        var foreground: Color
        var action: (String) -> () = { _ in  }
    }
}

struct CustomAlertDemo_Previews: PreviewProvider {
    static var previews: some View {
        CustomAlertDemo()
    }
}
