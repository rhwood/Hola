//
//  ExampleView.swift
//  Hola
//
//  Created by Randall Wood on 2022-01-15.
//  Copyright © 2022 Alexandria Software. All rights reserved.
//

import SwiftUI
import SafariServices

struct ExampleView: View {
    @State private var showSafari = false
    
    var body: some View {
        VStack {
            if showSafari {
                Text("My Safari View").font(.largeTitle)
                
                SafariView2(url: URL(string: "https://www.wikipedia.org")!,
                           showing: $showSafari)
            } else {
                Button("Show Safari View") {
                    self.showSafari = true
                }
            }
        }
    }
}

struct SafariView2: UIViewControllerRepresentable {
    let url: URL
    @Binding var showing: Bool
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView2>) -> SFSafariViewController {
        let sc = SFSafariViewController(url: url)
        sc.delegate = context.coordinator
        sc.preferredBarTintColor = .systemYellow
        return sc
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView2>) {
        
    }
    
    func makeCoordinator() -> SafariView2.Coordinator {
        return Coordinator(showing: $showing)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        @Binding var showing: Bool
        
        init(showing: Binding<Bool>) {
            self._showing = showing
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            self.showing = false
        }
    }
}

struct ExampleView_Preview: PreviewProvider {
    static var previews: some View {
        ExampleView()
    }
}
