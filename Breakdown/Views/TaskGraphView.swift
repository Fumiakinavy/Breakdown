import SwiftUI

struct TaskGraphView: View {
    @ObservedObject var viewModel: TaskBoardViewModel
    let taskID: UUID
    
    @State private var editingNodeID: UUID?
    @State private var canvasSize: CGSize = .zero
    
    private var task: Task? {
        viewModel.task(with: taskID)
    }
    
    private var nodes: [SubtaskNode] {
        task?.graphNodes ?? []
    }
    
    private var edges: [SubtaskEdge] {
        task?.graphEdges ?? []
    }
    
    private var canUndo: Bool {
        viewModel.canUndoGraph(taskID: taskID)
    }
    
    private var canRedo: Bool {
        viewModel.canRedoGraph(taskID: taskID)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                graphCanvas(size: geometry.size)
                ForEach(nodes) { node in
                    GraphNodeView(
                        node: node,
                        isEditing: editingNodeID == node.id,
                        onCommit: { text in
                            viewModel.renameNode(taskID: taskID, nodeID: node.id, title: text)
                            editingNodeID = nil
                        }
                    )
                    .position(position(for: node, in: geometry.size))
                    .gesture(dragGesture(for: node, canvasSize: geometry.size))
                    .simultaneousGesture(longPressGesture(for: node, canvasSize: geometry.size))
                    .simultaneousGesture(doubleTapGesture(for: node))
                }
            }
            .background(Color(uiColor: .systemBackground))
            .onAppear {
                canvasSize = geometry.size
                viewModel.ensureGraphHistory(for: taskID)
            }
            .onChange(of: geometry.size) { newValue in
                canvasSize = newValue
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.undoGraphChange(taskID: taskID) }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!canUndo)
                    Button(action: { viewModel.redoGraphChange(taskID: taskID) }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!canRedo)
                }
            }
        }
    }
    
    private func graphCanvas(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            for edge in edges {
                guard let source = nodes.first(where: { $0.id == edge.sourceNodeId }),
                      let target = nodes.first(where: { $0.id == edge.targetNodeId }) else { continue }
                let start = position(for: source, in: canvasSize)
                let end = position(for: target, in: canvasSize)
                var path = Path()
                path.move(to: start)
                let midX = (start.x + end.x) / 2
                path.addCurve(to: end,
                              control1: CGPoint(x: midX, y: start.y + 40),
                              control2: CGPoint(x: midX, y: end.y - 40))
                context.stroke(path, with: .color(Color.accentColor.opacity(0.4)), lineWidth: 3)
            }
        }
    }
    
    private func position(for node: SubtaskNode, in size: CGSize) -> CGPoint {
        CGPoint(x: node.layout.x * size.width, y: node.layout.y * size.height)
    }
    
    private func normalizedPoint(for absolute: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: absolute.x / size.width, y: absolute.y / size.height)
    }
    
    private func dragGesture(for node: SubtaskNode, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let location = CGPoint(x: value.location.x, y: value.location.y)
                let normalized = normalizedPoint(for: location, in: canvasSize)
                viewModel.updateNodePosition(taskID: taskID, nodeID: node.id, normalizedPoint: normalized)
            }
            .onEnded { value in
                let location = CGPoint(x: value.location.x, y: value.location.y)
                let normalized = normalizedPoint(for: location, in: canvasSize)
                viewModel.updateNodePosition(taskID: taskID, nodeID: node.id, normalizedPoint: normalized)
                viewModel.finalizeNodePosition(taskID: taskID)
            }
    }
    
    private func longPressGesture(for node: SubtaskNode, canvasSize: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                let offset = CGPoint(x: node.layout.x + 0.1, y: node.layout.y + 0.1)
                viewModel.addSubtaskNodes(for: taskID, around: offset)
            }
    }
    
    private func doubleTapGesture(for node: SubtaskNode) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                editingNodeID = node.id
            }
    }
}

private struct GraphNodeView: View {
    let node: SubtaskNode
    let isEditing: Bool
    var onCommit: (String) -> Void
    
    @State private var draftTitle: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("信頼度 \(Int(node.confidence * 100))%")
                    .font(.caption2)
                    .padding(4)
                    .background(confidenceColor.opacity(0.2), in: Capsule())
                Spacer()
            }
            if isEditing {
                TextField("タイトル", text: $draftTitle)
                    .textFieldStyle(.roundedBorder)
                    .onAppear { draftTitle = node.title }
                HStack {
                    Spacer()
                    Button {
                        onCommit(draftTitle)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            } else {
                Text(node.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .padding(12)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(node.isUserEdited ? Color.green : Color.gray.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .frame(width: 180)
        .onAppear {
            draftTitle = node.title
        }
    }
    
    private var confidenceColor: Color {
        switch node.confidence {
        case 0.75...: return .green
        case 0.5...: return .orange
        default: return .red
        }
    }
    
    private var backgroundStyle: Color {
        node.isUserEdited ? Color.blue.opacity(0.1) : Color(uiColor: .secondarySystemBackground)
    }
}

#Preview {
    TaskGraphView(viewModel: TaskBoardViewModel(), taskID: TaskSampleData.makeSampleTasks().first!.id)
}
