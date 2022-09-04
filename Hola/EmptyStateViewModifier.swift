//
//  EmptyStateView.swift
//  Hola
//
//  Created by Randall Wood on 3/13/22.
//  Copyright © 2022 Randall Wood. All rights reserved.
//

import SwiftUI

struct EmptyStateViewModifier<EmptyContent>: ViewModifier where EmptyContent: View {
    var isEmpty: Bool
    let emptyContent: () -> EmptyContent

    func body(content: Content) -> some View {
        if isEmpty {
            emptyContent()
        } else {
            content
        }
    }
}

extension View {
    func emptyState<EmptyContent>(_ isEmpty: Bool, emptyContent: @escaping () -> EmptyContent) -> some View where EmptyContent: View {
        modifier(EmptyStateViewModifier(isEmpty: isEmpty, emptyContent: emptyContent))
    }
}
