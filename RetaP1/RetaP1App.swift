//
//  RetaP1App.swift
//  RetaP1
//
//  Created by RongzhiChen on 7/2/26.
//

import SwiftUI

@main
struct RetaP1App: App {
    var body: some Scene {
        // MenuBarExtra is a Scene that lives in the macOS menu bar (top-right)
        // instead of a normal window. "Reta" is its accessibility label/tooltip;
        // systemImage is the SF Symbol shown as the menu-bar icon.
        MenuBarExtra("Reta", systemImage: "brain.head.profile") {
            ContentView()
        }
        // .window style shows our SwiftUI view as a small free-form panel
        // (so we can put buttons + live text in it). The default .menu style
        // would render it as a plain dropdown menu instead.
        .menuBarExtraStyle(.window)
    }
}
