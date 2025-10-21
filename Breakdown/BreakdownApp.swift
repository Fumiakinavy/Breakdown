//
//  BreakdownApp.swift
//  Breakdown
//
//  Created by uehara fumiaki on 2025/10/21.
//

import SwiftUI

@main
struct BreakdownApp: App {
    @StateObject private var viewModel = TaskBoardViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
