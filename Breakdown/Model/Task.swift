import Foundation
import CoreGraphics

enum TaskStatus: String, Codable, CaseIterable {
    case draft
    case refined
    case completed
}

enum TaskStepState: String, Codable, CaseIterable {
    case pending
    case inProgress
    case done
}

enum TaskPriority: String, Codable, CaseIterable {
    case high
    case medium
    case low
    
    var localizedName: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
}

struct TaskStep: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var detail: String?
    var estimatedMinutes: Int
    var orderIndex: Int
    var state: TaskStepState
    var scheduledAt: Date?
    
    init(
        id: UUID = UUID(),
        title: String,
        detail: String? = nil,
        estimatedMinutes: Int = 30,
        orderIndex: Int,
        state: TaskStepState = .pending,
        scheduledAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.estimatedMinutes = estimatedMinutes
        self.orderIndex = orderIndex
        self.state = state
        self.scheduledAt = scheduledAt
    }
}

struct Task: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var detail: String?
    var createdAt: Date
    var dueAt: Date?
    var priority: TaskPriority
    var status: TaskStatus
    var steps: [TaskStep]
    var baselineEstimateMinutes: Int
    var conflictScore: Double?
    var conflictCalculatedAt: Date?
    var completedAt: Date?
    var graphVersion: Int
    var graphNodes: [SubtaskNode]
    var graphEdges: [SubtaskEdge]
    
    init(
        id: UUID = UUID(),
        title: String,
        detail: String? = nil,
        createdAt: Date = Date(),
        dueAt: Date? = nil,
        priority: TaskPriority = .medium,
        status: TaskStatus = .draft,
        steps: [TaskStep] = [],
        baselineEstimateMinutes: Int = 30,
        conflictScore: Double? = nil,
        conflictCalculatedAt: Date? = nil,
        completedAt: Date? = nil,
        graphVersion: Int = 1,
        graphNodes: [SubtaskNode] = [],
        graphEdges: [SubtaskEdge] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
        self.dueAt = dueAt
        self.priority = priority
        self.status = status
        self.steps = steps
        self.baselineEstimateMinutes = baselineEstimateMinutes
        self.conflictScore = conflictScore
        self.conflictCalculatedAt = conflictCalculatedAt
        self.completedAt = completedAt
        self.graphVersion = graphVersion
        self.graphNodes = graphNodes
        self.graphEdges = graphEdges
    }
    
    var totalEstimatedMinutes: Int {
        let stepsTotal = steps.reduce(0) { $0 + $1.estimatedMinutes }
        return stepsTotal > 0 ? stepsTotal : baselineEstimateMinutes
    }
    
    var nextAction: String {
        switch status {
        case .draft:
            return "詳細化が必要"
        case .refined:
            if let step = steps.first(where: { $0.state != .done }) {
                return step.title
            }
            return "作業を確認"
        case .completed:
            return "完了済み"
        }
    }
}

struct TaskConflictAnalyzer {
    struct Capacity {
        var weekdayMinutes: Int
        var weekendMinutes: Int
        
        static let `default` = Capacity(weekdayMinutes: 180, weekendMinutes: 300)
    }
    
    static func calculateScores(
        for tasks: [Task],
        calendar: Calendar = Calendar(identifier: .gregorian),
        capacity: Capacity = .default,
        referenceDate: Date = Date()
    ) -> [UUID: Double] {
        guard !tasks.isEmpty else { return [:] }
        
        var scores: [UUID: Double] = [:]
        var workloadByDay: [Date: Int] = [:]
        var taskDates: [UUID: Date] = [:]
        
        for task in tasks where task.status != .completed {
            let anchorDate = task.dueAt ?? calendar.startOfDay(for: referenceDate)
        let day = calendar.startOfDay(for: anchorDate)
        taskDates[task.id] = day
        workloadByDay[day, default: 0] += task.totalEstimatedMinutes
    }
    
        for (taskID, day) in taskDates {
            let total = workloadByDay[day, default: 0]
            let isWeekend = calendar.isDateInWeekend(day)
            let capacityMinutes = isWeekend ? capacity.weekendMinutes : capacity.weekdayMinutes
            guard capacityMinutes > 0 else {
                scores[taskID] = nil
                continue
            }
            let ratio = Double(total) / Double(capacityMinutes)
            scores[taskID] = min(max(ratio, 0), 1)
        }
        
        return scores
    }
}

enum TaskSampleData {
    static func makeSampleTasks(now: Date = Date()) -> [Task] {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
        let weekend = calendar.date(byAdding: .day, value: 2, to: today)
        
        let draftTaskId = UUID()
        let draftRoot = SubtaskNode(
            taskId: draftTaskId,
            title: "新サービス企画アイデア整理",
            aiProposedTitle: "企画アイデアの整理",
            confidence: 0.95,
            layout: CGPoint(x: 0.5, y: 0.2),
            isUserEdited: true
        )
        let draftChild1 = SubtaskNode(
            taskId: draftTaskId,
            parentNodeId: draftRoot.id,
            title: "市場調査メモを分類",
            aiProposedTitle: "市場調査分析",
            confidence: 0.72,
            layout: CGPoint(x: 0.3, y: 0.5)
        )
        let draftChild2 = SubtaskNode(
            taskId: draftTaskId,
            parentNodeId: draftRoot.id,
            title: "課題と仮説をまとめる",
            aiProposedTitle: "課題整理",
            confidence: 0.68,
            layout: CGPoint(x: 0.7, y: 0.52)
        )
        let draftEdges = [
            SubtaskEdge(taskId: draftTaskId, sourceNodeId: draftRoot.id, targetNodeId: draftChild1.id, relation: "sequence"),
            SubtaskEdge(taskId: draftTaskId, sourceNodeId: draftRoot.id, targetNodeId: draftChild2.id, relation: "sequence")
        ]
        let draftTask = Task(
            id: draftTaskId,
            title: "新サービス企画アイデア整理",
            detail: "メモしたアイデアを整理し、AI分解を依頼する。",
            createdAt: today,
            dueAt: tomorrow,
            priority: .high,
            status: .draft,
            baselineEstimateMinutes: 45,
            graphNodes: [draftRoot, draftChild1, draftChild2],
            graphEdges: draftEdges
        )
        
        let refinedTaskId = UUID()
        let refinedRoot = SubtaskNode(
            taskId: refinedTaskId,
            title: "モバイルUIデザイン修正",
            aiProposedTitle: "Inbox UI修正",
            confidence: 0.9,
            layout: CGPoint(x: 0.5, y: 0.2),
            isUserEdited: true
        )
        let refinedTablet = SubtaskNode(
            taskId: refinedTaskId,
            parentNodeId: refinedRoot.id,
            title: "競合リサーチ確認",
            aiProposedTitle: "競合比較",
            confidence: 0.65,
            layout: CGPoint(x: 0.3, y: 0.5),
            isUserEdited: true
        )
        let refinedWireframe = SubtaskNode(
            taskId: refinedTaskId,
            parentNodeId: refinedRoot.id,
            title: "ワイヤーフレーム修正",
            aiProposedTitle: "ワイヤーフレーム更新",
            confidence: 0.8,
            layout: CGPoint(x: 0.55, y: 0.55),
            isUserEdited: false
        )
        let refinedReview = SubtaskNode(
            taskId: refinedTaskId,
            parentNodeId: refinedWireframe.id,
            title: "レビュー依頼送付",
            aiProposedTitle: "レビュー依頼",
            confidence: 0.6,
            layout: CGPoint(x: 0.75, y: 0.7),
            isUserEdited: false
        )
        let refinedTask = Task(
            id: refinedTaskId,
            title: "モバイルUIデザイン修正",
            detail: "Inbox画面のワイヤーフレームを仕上げる。",
            createdAt: today,
            dueAt: tomorrow,
            priority: .medium,
            status: .refined,
            steps: [
                TaskStep(title: "競合リサーチ確認", estimatedMinutes: 30, orderIndex: 0),
                TaskStep(title: "ワイヤーフレーム修正", estimatedMinutes: 45, orderIndex: 1, state: .inProgress),
                TaskStep(title: "レビュー依頼送付", estimatedMinutes: 15, orderIndex: 2)
            ],
            baselineEstimateMinutes: 60,
            graphVersion: 2,
            graphNodes: [refinedRoot, refinedTablet, refinedWireframe, refinedReview],
            graphEdges: [
                SubtaskEdge(taskId: refinedTaskId, sourceNodeId: refinedRoot.id, targetNodeId: refinedTablet.id, relation: "sequence"),
                SubtaskEdge(taskId: refinedTaskId, sourceNodeId: refinedRoot.id, targetNodeId: refinedWireframe.id, relation: "sequence"),
                SubtaskEdge(taskId: refinedTaskId, sourceNodeId: refinedWireframe.id, targetNodeId: refinedReview.id, relation: "dependency")
            ]
        )
        
        let completedTaskId = UUID()
        let completedRoot = SubtaskNode(
            taskId: completedTaskId,
            title: "週次レビュー",
            aiProposedTitle: "週次レビュー",
            confidence: 1.0,
            layout: CGPoint(x: 0.5, y: 0.2),
            isUserEdited: true
        )
        let completedTask = Task(
            id: completedTaskId,
            title: "週次レビュー",
            detail: "完了タスクの振り返りと次週計画。",
            createdAt: calendar.date(byAdding: .day, value: -3, to: today) ?? today,
            dueAt: weekend,
            priority: .low,
            status: .completed,
            steps: [
                TaskStep(title: "完了タスク整理", estimatedMinutes: 20, orderIndex: 0, state: .done),
                TaskStep(title: "次週優先度決め", estimatedMinutes: 40, orderIndex: 1, state: .done)
            ],
            baselineEstimateMinutes: 60,
            completedAt: today,
            graphVersion: 1,
            graphNodes: [completedRoot],
            graphEdges: []
        )
        
        return [draftTask, refinedTask, completedTask]
    }
}
struct SubtaskNode: Identifiable, Hashable, Codable {
    let id: UUID
    var taskId: UUID
    var parentNodeId: UUID?
    var title: String
    var aiProposedTitle: String?
    var confidence: Double
    var metadata: [String: String]
    var layout: CGPoint
    var isUserEdited: Bool
    
    init(
        id: UUID = UUID(),
        taskId: UUID,
        parentNodeId: UUID? = nil,
        title: String,
        aiProposedTitle: String? = nil,
        confidence: Double = 0.7,
        metadata: [String: String] = [:],
        layout: CGPoint,
        isUserEdited: Bool = false
    ) {
        self.id = id
        self.taskId = taskId
        self.parentNodeId = parentNodeId
        self.title = title
        self.aiProposedTitle = aiProposedTitle
        self.confidence = confidence
        self.metadata = metadata
        self.layout = layout
        self.isUserEdited = isUserEdited
    }
    
    enum CodingKeys: String, CodingKey {
        case id, taskId, parentNodeId, title, aiProposedTitle, confidence, metadata, layoutX, layoutY, isUserEdited
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        taskId = try container.decode(UUID.self, forKey: .taskId)
        parentNodeId = try container.decodeIfPresent(UUID.self, forKey: .parentNodeId)
        title = try container.decode(String.self, forKey: .title)
        aiProposedTitle = try container.decodeIfPresent(String.self, forKey: .aiProposedTitle)
        confidence = try container.decode(Double.self, forKey: .confidence)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        let x = try container.decode(Double.self, forKey: .layoutX)
        let y = try container.decode(Double.self, forKey: .layoutY)
        layout = CGPoint(x: x, y: y)
        isUserEdited = try container.decode(Bool.self, forKey: .isUserEdited)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(taskId, forKey: .taskId)
        try container.encodeIfPresent(parentNodeId, forKey: .parentNodeId)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(aiProposedTitle, forKey: .aiProposedTitle)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(layout.x, forKey: .layoutX)
        try container.encode(layout.y, forKey: .layoutY)
        try container.encode(isUserEdited, forKey: .isUserEdited)
    }
}

struct SubtaskEdge: Identifiable, Hashable, Codable {
    let id: UUID
    var taskId: UUID
    var sourceNodeId: UUID
    var targetNodeId: UUID
    var relation: String
    
    init(
        id: UUID = UUID(),
        taskId: UUID,
        sourceNodeId: UUID,
        targetNodeId: UUID,
        relation: String = "sequence"
    ) {
        self.id = id
        self.taskId = taskId
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.relation = relation
    }
}
