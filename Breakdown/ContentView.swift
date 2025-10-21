//
//  ContentView.swift
//  Breakdown
//
//  Created by uehara fumiaki on 2025/10/21.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TaskBoardViewModel
    
    var body: some View {
        NavigationStack {
            List {
                Section("詳細化待ちタスク") {
                    if viewModel.inboxTasks.isEmpty {
                        ContentUnavailableView("タスクなし", systemImage: "tray", description: Text("右下のボタンからタスクを追加しましょう。"))
                    } else {
                        ForEach(viewModel.inboxTasks) { task in
                            InboxTaskRow(task: task)
                        }
                    }
                }
                
                Section("作業中タスク") {
                    if viewModel.activeTasks.isEmpty {
                        Text("まだ実行中のタスクはありません。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.activeTasks) { task in
                            ActiveTaskRow(task: task)
                        }
                    }
                }
            }
            .navigationTitle("Breakdown")
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

#Preview {
    ContentView(viewModel: TaskBoardViewModel())
}
