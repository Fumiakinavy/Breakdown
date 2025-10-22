import Foundation
import Combine
import CoreGraphics
import SwiftUI

final class TaskBoardViewModel: ObservableObject {
    @Published private(set) var tasks: [Task]
    @Published var capacity: TaskConflictAnalyzer.Capacity
    @Published private var graphHistories: [UUID: GraphHistory] = [:]
    
    private var cancellables: Set<AnyCancellable> = []
    private let calendar: Calendar
    
    private struct GraphHistory {
        var past: [TaskGraphSnapshot] = []
        var future: [TaskGraphSnapshot] = []
    }
    
    private struct TaskGraphSnapshot {
        let nodes: [SubtaskNode]
        let edges: [SubtaskEdge]
    }
    
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

    // MARK: - Graph Editing

    func addSubtaskNodes(for taskID: UUID, around point: CGPoint) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        var task = tasks[taskIndex]
        saveGraphSnapshot(for: task)

        let normalizedPoint = CGPoint(x: min(max(point.x, 0.05), 0.95), y: min(max(point.y, 0.05), 0.95))
        let newNode = SubtaskNode(
            taskId: taskID,
            parentNodeId: task.graphNodes.first?.id,
            title: "サブタスク \(task.graphNodes.count + 1)",
            aiProposedTitle: "候補 \(task.graphNodes.count + 1)",
            confidence: 0.5,
            layout: normalizedPoint,
            isUserEdited: true
        )
        task.graphNodes.append(newNode)
        if let rootId = task.graphNodes.first?.id {
            let edge = SubtaskEdge(taskId: taskID, sourceNodeId: rootId, targetNodeId: newNode.id, relation: "sequence")
            task.graphEdges.append(edge)
        }
        task.graphVersion += 1
        tasks[taskIndex] = task
    }

    func updateNodePosition(taskID: UUID, nodeID: UUID, normalizedPoint: CGPoint) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard let nodeIndex = tasks[taskIndex].graphNodes.firstIndex(where: { $0.id == nodeID }) else { return }
        let clamped = CGPoint(x: min(max(normalizedPoint.x, 0.02), 0.98), y: min(max(normalizedPoint.y, 0.02), 0.98))
        tasks[taskIndex].graphNodes[nodeIndex].layout = clamped
    }

    func finalizeNodePosition(taskID: UUID) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[taskIndex].graphVersion += 1
    }

    func renameNode(taskID: UUID, nodeID: UUID, title: String) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard let nodeIndex = tasks[taskIndex].graphNodes.firstIndex(where: { $0.id == nodeID }) else { return }
        saveGraphSnapshot(for: tasks[taskIndex])
        tasks[taskIndex].graphNodes[nodeIndex].title = title
        tasks[taskIndex].graphNodes[nodeIndex].isUserEdited = true
        tasks[taskIndex].graphVersion += 1
    }

    func reorderGraphNodes(taskID: UUID, fromOffsets: IndexSet, toOffset: Int) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        saveGraphSnapshot(for: tasks[taskIndex])
        moveItems(in: &tasks[taskIndex].graphNodes, from: fromOffsets, to: toOffset)
        tasks[taskIndex].graphVersion += 1
    }

    func undoGraphChange(taskID: UUID) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard var history = graphHistories[taskID], let snapshot = history.past.popLast() else { return }
        let current = TaskGraphSnapshot(nodes: tasks[taskIndex].graphNodes, edges: tasks[taskIndex].graphEdges)
        history.future.append(current)
        tasks[taskIndex].graphNodes = snapshot.nodes
        tasks[taskIndex].graphEdges = snapshot.edges
        tasks[taskIndex].graphVersion = max(tasks[taskIndex].graphVersion - 1, 1)
        graphHistories[taskID] = history
    }

    func redoGraphChange(taskID: UUID) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard var history = graphHistories[taskID], let snapshot = history.future.popLast() else { return }
        let current = TaskGraphSnapshot(nodes: tasks[taskIndex].graphNodes, edges: tasks[taskIndex].graphEdges)
        history.past.append(current)
        tasks[taskIndex].graphNodes = snapshot.nodes
        tasks[taskIndex].graphEdges = snapshot.edges
        tasks[taskIndex].graphVersion += 1
        graphHistories[taskID] = history
    }

    private func saveGraphSnapshot(for task: Task) {
        let snapshot = TaskGraphSnapshot(nodes: task.graphNodes, edges: task.graphEdges)
        if graphHistories[task.id] == nil {
            graphHistories[task.id] = GraphHistory()
        }
        graphHistories[task.id]?.past.append(snapshot)
        graphHistories[task.id]?.future.removeAll()
    }

    func canUndoGraph(taskID: UUID) -> Bool {
        guard let history = graphHistories[taskID] else { return false }
        return !history.past.isEmpty
    }
    
    func canRedoGraph(taskID: UUID) -> Bool {
        guard let history = graphHistories[taskID] else { return false }
        return !history.future.isEmpty
    }
    
    func ensureGraphHistory(for taskID: UUID) {
        if graphHistories[taskID] == nil {
            graphHistories[taskID] = GraphHistory()
        }
    }
    
    private func moveItems<T>(in array: inout [T], from offsets: IndexSet, to destination: Int) {
        let sortedOffsets = offsets.sorted()
        let movingItems = sortedOffsets.map { array[$0] }
        for index in sortedOffsets.reversed() {
            array.remove(at: index)
        }
        var insertIndex = destination
        if insertIndex > array.count { insertIndex = array.count }
        for (offset, element) in movingItems.enumerated() {
            array.insert(element, at: insertIndex + offset)
        }
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
        moveItems(in: &tasks[taskIndex].steps, from: fromOffsets, to: toOffset)
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
