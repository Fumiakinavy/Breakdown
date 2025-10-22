import SwiftUI

struct TaskDetailSheet: View {
    @ObservedObject var viewModel: TaskBoardViewModel
    let taskID: UUID
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            if let task = viewModel.task(with: taskID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        TaskGraphView(viewModel: viewModel, taskID: taskID)
                            .frame(minHeight: 360)
                            .padding(.horizontal)
                            .padding(.top)
                        taskInfoSection(task)
                        stepsSection(task)
                        if task.status == .draft {
                            Button {
                                viewModel.updateStatus(for: task.id, to: .refined)
                            } label: {
                                Label("詳細化を完了", systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 32)
                }
                .background(Color(uiColor: .systemGroupedBackground))
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
    
    private func taskInfoSection(_ task: Task) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("タスク情報")
                .font(.title3.bold())
            VStack(alignment: .leading, spacing: 8) {
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
            .padding()
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal)
    }
    
    private func stepsSection(_ task: Task) -> some View {
        let steps = task.steps.sorted { $0.orderIndex < $1.orderIndex }
        return VStack(alignment: .leading, spacing: 12) {
            Text("ステップ")
                .font(.title3.bold())
            if steps.isEmpty {
                Text("まだステップが登録されていません。")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(steps) { step in
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
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
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
