import Foundation

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

enum PreferredSlot: String, Codable, CaseIterable {
    case anytime
    case morning
    case afternoon
    case evening
    
    var localizedName: String {
        switch self {
        case .anytime: return "いつでも"
        case .morning: return "午前"
        case .afternoon: return "午後"
        case .evening: return "夜"
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
    var preferredSlot: PreferredSlot
    var status: TaskStatus
    var steps: [TaskStep]
    var baselineEstimateMinutes: Int
    var conflictScore: Double?
    var conflictCalculatedAt: Date?
    var completedAt: Date?
    
    init(
        id: UUID = UUID(),
        title: String,
        detail: String? = nil,
        createdAt: Date = Date(),
        dueAt: Date? = nil,
        preferredSlot: PreferredSlot = .anytime,
        status: TaskStatus = .draft,
        steps: [TaskStep] = [],
        baselineEstimateMinutes: Int = 30,
        conflictScore: Double? = nil,
        conflictCalculatedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
        self.dueAt = dueAt
        self.preferredSlot = preferredSlot
        self.status = status
        self.steps = steps
        self.baselineEstimateMinutes = baselineEstimateMinutes
        self.conflictScore = conflictScore
        self.conflictCalculatedAt = conflictCalculatedAt
        self.completedAt = completedAt
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
        
        let draftTask = Task(
            title: "新サービス企画アイデア整理",
            detail: "メモしたアイデアを整理し、AI分解を依頼する。",
            createdAt: today,
            dueAt: tomorrow,
            preferredSlot: .afternoon,
            status: .draft,
            baselineEstimateMinutes: 45
        )
        
        let refinedTask = Task(
            title: "モバイルUIデザイン修正",
            detail: "Inbox画面のワイヤーフレームを仕上げる。",
            createdAt: today,
            dueAt: tomorrow,
            preferredSlot: .morning,
            status: .refined,
            steps: [
                TaskStep(title: "競合リサーチ確認", estimatedMinutes: 30, orderIndex: 0),
                TaskStep(title: "ワイヤーフレーム修正", estimatedMinutes: 45, orderIndex: 1, state: .inProgress),
                TaskStep(title: "レビュー依頼送付", estimatedMinutes: 15, orderIndex: 2)
            ],
            baselineEstimateMinutes: 60
        )
        
        let completedTask = Task(
            title: "週次レビュー",
            detail: "完了タスクの振り返りと次週計画。",
            createdAt: calendar.date(byAdding: .day, value: -3, to: today) ?? today,
            dueAt: weekend,
            preferredSlot: .evening,
            status: .completed,
            steps: [
                TaskStep(title: "完了タスク整理", estimatedMinutes: 20, orderIndex: 0, state: .done),
                TaskStep(title: "次週優先度決め", estimatedMinutes: 40, orderIndex: 1, state: .done)
            ],
            baselineEstimateMinutes: 60,
            completedAt: today
        )
        
        return [draftTask, refinedTask, completedTask]
    }
}
