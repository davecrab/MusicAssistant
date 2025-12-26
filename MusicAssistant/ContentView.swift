//
//  ContentView.swift
//  MusicAssistant
//
//  Created by Dave Crabtree on 2025-12-25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        RootView()
            .environmentObject(appModel)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
