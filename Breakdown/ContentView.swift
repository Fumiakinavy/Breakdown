//
//  ContentView.swift
//  Breakdown
//
//  Created by uehara fumiaki on 2025/10/21.
//

import SwiftUI

enum TaskBoardTab: Hashable {
    case inbox
    case active
    case completed
    
    var title: String {
        switch self {
        case .inbox: return "Inbox"
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }
    
    var systemImage: String {
        switch self {
        case .inbox: return "tray.full"
        case .active: return "list.bullet.clipboard"
        case .completed: return "checkmark.circle"
        }
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: TaskBoardViewModel
    @State private var selectedTab: TaskBoardTab = .inbox
    @State private var isPresentingAddSheet = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            InboxPage(viewModel: viewModel)
                .tabItem {
                    Label(TaskBoardTab.inbox.title, systemImage: TaskBoardTab.inbox.systemImage)
                }
                .tag(TaskBoardTab.inbox)
                .badge(viewModel.inboxTasks.count)
            
            ActivePage(viewModel: viewModel)
                .tabItem {
                    Label(TaskBoardTab.active.title, systemImage: TaskBoardTab.active.systemImage)
                }
                .tag(TaskBoardTab.active)
                .badge(viewModel.activeTasks.count)
            
            CompletedPage(viewModel: viewModel)
                .tabItem {
                    Label(TaskBoardTab.completed.title, systemImage: TaskBoardTab.completed.systemImage)
                }
                .tag(TaskBoardTab.completed)
                .badge(viewModel.completedTasks.count)
        }
        .overlay(alignment: .bottomTrailing) {
            AddTaskButton {
                isPresentingAddSheet = true
            }
            .padding(.trailing, 24)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            AddTaskSheet(viewModel: viewModel, isPresented: $isPresentingAddSheet)
        }
    }
}

private struct InboxPage: View {
    @ObservedObject var viewModel: TaskBoardViewModel
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.inboxTasks.isEmpty {
                    ContentUnavailableView("タスクなし", systemImage: "tray", description: Text("右下のボタンからタスクを追加しましょう。"))
                } else {
                    ForEach(viewModel.inboxTasks) { task in
                        InboxTaskRow(task: task)
                    }
                }
            }
            .navigationTitle("詳細化待ち")
        }
    }
}

private struct ActivePage: View {
    @ObservedObject var viewModel: TaskBoardViewModel
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.activeTasks.isEmpty {
                    ContentUnavailableView("作業中タスクなし", systemImage: "checklist", description: Text("詳細化を完了するとここに表示されます。"))
                } else {
                    ForEach(viewModel.activeTasks) { task in
                        ActiveTaskRow(task: task)
                    }
                }
            }
            .navigationTitle("実行中")
        }
    }
}

private struct CompletedPage: View {
    @ObservedObject var viewModel: TaskBoardViewModel
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.completedTasks.isEmpty {
                    ContentUnavailableView("完了タスクなし", systemImage: "archivebox", description: Text("完了したタスクはここに保存されます。"))
                } else {
                    ForEach(viewModel.completedTasks) { task in
                        CompletedTaskRow(task: task)
                    }
                }
            }
            .navigationTitle("完了済み")
        }
    }
}

private struct InboxTaskRow: View {
    let task: Task
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                HStack(spacing: 8) {
                    if let due = task.dueAt {
                        Label {
                            Text(due, style: .date)
                        } icon: {
                            Image(systemName: "calendar")
                        }
                    }
                    Text(task.preferredSlot.localizedName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            if let score = task.conflictScore {
                ConflictBadge(score: score)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ActiveTaskRow: View {
    let task: Task
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView(value: progress)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                Text(task.nextAction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let score = task.conflictScore {
                ConflictBadge(score: score)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var progress: Double {
        guard !task.steps.isEmpty else { return 0 }
        let completed = task.steps.filter { $0.state == .done }.count
        return Double(completed) / Double(task.steps.count)
    }
}

private struct CompletedTaskRow: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.title)
                    .font(.headline)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            if let completedAt = task.completedAt {
                Label {
                    Text(completedAt, style: .date)
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if !task.steps.isEmpty {
                Text("\(task.steps.count) ステップ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ConflictBadge: View {
    let score: Double
    
    var body: some View {
        let percentage = Int(score * 100)
        Text("\(percentage)%")
            .font(.caption.monospacedDigit())
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(backgroundColor, in: Capsule())
            .foregroundStyle(foregroundColor)
            .accessibilityLabel("コンフリクト度合い \(percentage) パーセント")
    }
    
    private var backgroundColor: Color {
        switch score {
        case ..<0.4:
            return Color.green.opacity(0.15)
        case ..<0.7:
            return Color.yellow.opacity(0.2)
        default:
            return Color.red.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch score {
        case ..<0.4:
            return .green
        case ..<0.7:
            return .orange
        default:
            return .red
        }
    }
}

private struct AddTaskButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
        }
        .accessibilityLabel("タスクを追加")
    }
}

#Preview {
    ContentView(viewModel: TaskBoardViewModel())
}
