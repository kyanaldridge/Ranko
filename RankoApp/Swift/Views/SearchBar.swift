//
//  SearchBar.swift
//  RankoTestViewer
//
//  Created by Kyan Aldridge on 17/4/2025.
//

import SwiftUI

struct CustomSearchBar: View {
    @Binding var text: String
    var preText: String
    var isEditing: Binding<Bool>? = nil
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.black)
                .font(.caption)
                .fontWeight(.bold)

            TextField(preText, text: $text, onEditingChanged: { editing in
                isEditing?.wrappedValue = editing
            }, onCommit: {
                onSubmit?()
            })
            .submitLabel(.search)
            .foregroundColor(.black)
            .font(.callout)
            .fontWeight(.bold)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "clear.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct AlgoliaSearchBar: View {
    @Binding var text: String
    var preText: String
    var isEditing: Binding<Bool>? = nil
    var onSubmit: (() -> Void)? = nil
    @State private var textNotEmpty: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color(hex: 0x8A8A8D))

            TextField(preText, text: $text, onEditingChanged: { editing in
                isEditing?.wrappedValue = editing
            }, onCommit: {
                onSubmit?()
            })
            .submitLabel(.search)
            .font(.custom("Nunito-Black", size: 16))
            .foregroundStyle(text.isEmpty ? Color(hex: 0x8A8A8D) : .black)

            if textNotEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(hex: 0x8A8A8D))
                }
            }
        }
        .onChange(of: text) { oldValue, newValue in
            if oldValue.isEmpty && !newValue.isEmpty {
                withAnimation(.snappy(duration: 0.2, extraBounce: 0.33)) {
                    textNotEmpty = true
                }
            } else if !oldValue.isEmpty && newValue.isEmpty {
                withAnimation(.snappy(duration: 0.2, extraBounce: 0.33)) {
                    textNotEmpty = false
                }
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
        .padding(.horizontal)
    }
}

