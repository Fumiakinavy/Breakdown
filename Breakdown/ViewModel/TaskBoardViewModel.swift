import Foundation
import Combine

final class TaskBoardViewModel: ObservableObject {
    @Published private(set) var tasks: [Task]
    @Published var capacity: TaskConflictAnalyzer.Capacity
    
    private var cancellables: Set<AnyCancellable> = []
    private let calendar: Calendar
    
    init(
        tasks: [Task] = TaskSampleData.makeSampleTasks(),
        capacity: TaskConflictAnalyzer.Capacity = .default,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.tasks = tasks
        self.capacity = capacity
        self.calendar = calendar
        recalculateConflicts()
        observeCapacityChanges()
    }
    
    var inboxTasks: [Task] {
        tasks
            .filter { $0.status == .draft }
            .sorted { ($0.dueAt ?? $0.createdAt) < ($1.dueAt ?? $1.createdAt) }
    }
    
    var activeTasks: [Task] {
        tasks
            .filter { $0.status == .refined }
            .sorted { compareActiveTasks(lhs: $0, rhs: $1) }
    }
    
    var completedTasks: [Task] {
        tasks
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? $0.dueAt ?? $0.createdAt) > ($1.completedAt ?? $1.dueAt ?? $1.createdAt) }
    }
    
    func addTask(title: String, dueDate: Date?, priority: TaskPriority, estimatedMinutes: Int = 30) {
        var newTask = Task(
            title: title,
            createdAt: Date(),
            dueAt: dueDate,
            priority: priority,
            status: .draft,
            baselineEstimateMinutes: estimatedMinutes
        )
        newTask.conflictScore = nil
        newTask.conflictCalculatedAt = nil
        
        tasks.append(newTask)
        recalculateConflicts()
    }
    
    func updateTask(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        recalculateConflicts()
    }
    
    func task(with id: UUID) -> Task? {
        tasks.first(where: { $0.id == id })
    }
    
    func updateStatus(for taskID: UUID, to status: TaskStatus) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].status = status
        if status == .completed {
            tasks[index].completedAt = Date()
        } else {
            tasks[index].completedAt = nil
        }
        recalculateConflicts()
    }
    
    func markTaskCompleted(_ taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].status = .completed
        tasks[index].completedAt = Date()
        recalculateConflicts()
    }
    
    func advanceStep(taskID: UUID, stepID: UUID) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard let stepIndex = tasks[taskIndex].steps.firstIndex(where: { $0.id == stepID }) else { return }
        
        var step = tasks[taskIndex].steps[stepIndex]
        switch step.state {
        case .pending:
            step.state = .inProgress
        case .inProgress:
            step.state = .done
        case .done:
            step.state = .pending
        }
        tasks[taskIndex].steps[stepIndex] = step
        recalculateConflicts()
    }
    
    func recalculateConflicts(referenceDate: Date = Date()) {
        let scores = TaskConflictAnalyzer.calculateScores(
            for: tasks,
            calendar: calendar,
            capacity: capacity,
            referenceDate: referenceDate
        )
        for index in tasks.indices {
            let taskID = tasks[index].id
            tasks[index].conflictScore = scores[taskID]
            tasks[index].conflictCalculatedAt = Date()
        }
    }
    
    func reorderSteps(taskID: UUID, fromOffsets: IndexSet, toOffset: Int) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[taskIndex].steps.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for index in tasks[taskIndex].steps.indices {
            tasks[taskIndex].steps[index].orderIndex = index
        }
        recalculateConflicts()
    }
    
    private func observeCapacityChanges() {
        $capacity
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recalculateConflicts()
            }
            .store(in: &cancellables)
    }
    
    private func compareActiveTasks(lhs: Task, rhs: Task) -> Bool {
        let lhsDate = nextStepDate(for: lhs) ?? lhs.dueAt ?? lhs.createdAt
        let rhsDate = nextStepDate(for: rhs) ?? rhs.dueAt ?? rhs.createdAt
        return lhsDate < rhsDate
    }
    
    private func nextStepDate(for task: Task) -> Date? {
        task.steps
            .filter { $0.state != .done }
            .compactMap { $0.scheduledAt }
            .sorted()
            .first
    }
}
