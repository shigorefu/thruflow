//
//  ContentView.swift
//  ThruFlow
//
//  Created by エドワード on 2026/07/08.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        DirectionListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Direction.self, inMemory: true)
}
