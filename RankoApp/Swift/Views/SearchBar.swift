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
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

