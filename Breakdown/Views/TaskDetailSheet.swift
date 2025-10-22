import SwiftUI

struct TaskDetailSheet: View {
    @ObservedObject var viewModel: TaskBoardViewModel
    let taskID: UUID
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            if let task = viewModel.task(with: taskID) {
                List {
                    Section("タスク情報") {
                        Text(task.title)
                            .font(.headline)
                        if let due = task.dueAt {
                            Label {
                                Text(due, style: .date)
                            } icon: {
                                Image(systemName: "calendar")
                            }
                        }
                        Label("優先度: \(task.priority.localizedName)", systemImage: "flag")
                            .foregroundStyle(priorityColor(for: task.priority))
                        Label("推定時間: \(task.totalEstimatedMinutes)分", systemImage: "clock")
                            .foregroundStyle(.secondary)
                        if let score = task.conflictScore {
                            Label("コンフリクト: \(Int(score * 100))%", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(conflictColor(for: score))
                        }
                    }
                    
                    Section("ステップ") {
                        if task.steps.isEmpty {
                            Text("まだステップが登録されていません。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(task.steps) { step in
                                Button {
                                    viewModel.advanceStep(taskID: task.id, stepID: step.id)
                                } label: {
                                    HStack {
                                        Image(systemName: icon(for: step.state))
                                            .foregroundStyle(color(for: step.state))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(step.title)
                                            if let detail = step.detail, !detail.isEmpty {
                                                Text(detail)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text("\(step.estimatedMinutes)分")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    if task.status == .draft {
                        Section {
                            Button {
                                viewModel.updateStatus(for: task.id, to: .refined)
                            } label: {
                                Label("詳細化を完了", systemImage: "sparkles")
                            }
                        }
                    }
                }
                .navigationTitle("タスク詳細")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("タスクが見つかりません")
                        .font(.headline)
                    Button("閉じる") {
                        dismiss()
                    }
                }
                .padding()
            }
        }
    }
    
    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
    
    private func conflictColor(for score: Double) -> Color {
        switch score {
        case ..<0.4: return .green
        case ..<0.7: return .orange
        default: return .red
        }
    }
    
    private func icon(for state: TaskStepState) -> String {
        switch state {
        case .pending: return "circle"
        case .inProgress: return "clock.fill"
        case .done: return "checkmark.circle.fill"
        }
    }
    
    private func color(for state: TaskStepState) -> Color {
        switch state {
        case .pending: return .secondary
        case .inProgress: return .blue
        case .done: return .green
        }
    }
}

#Preview {
    TaskDetailSheet(viewModel: TaskBoardViewModel(), taskID: TaskSampleData.makeSampleTasks().first!.id)
}
