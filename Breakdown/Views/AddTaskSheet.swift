import SwiftUI

struct AddTaskSheet: View {
    @ObservedObject var viewModel: TaskBoardViewModel
    @Binding var isPresented: Bool
    
    @State private var title: String = ""
    @State private var includeDueDate: Bool = true
    @State private var dueDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var preferredSlot: PreferredSlot = .anytime
    @State private var estimatedMinutes: Int = 30
    @State private var validationMessage: String?
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section("タスク概要") {
                    TextField("タイトル（必須）", text: $title)
                        .focused($isTitleFocused)
                        .textInputAutocapitalization(.sentences)
                    Picker("希望時間帯", selection: $preferredSlot) {
                        ForEach(PreferredSlot.allCases, id: \.self) { slot in
                            Text(slot.localizedName).tag(slot)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("期限と見積り") {
                    Toggle("期限を設定", isOn: $includeDueDate.animation())
                    if includeDueDate {
                        DatePicker(
                            "期限",
                            selection: $dueDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                    }
                    Stepper(value: $estimatedMinutes, in: 15...240, step: 15) {
                        Text("推定作業時間: \(estimatedMinutes)分")
                    }
                }
                
                if let message = validationMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("新規タスク")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                isTitleFocused = true
            }
        }
    }
    
    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var canSave: Bool {
        !trimmedTitle.isEmpty
    }
    
    private func save() {
        guard canSave else {
            validationMessage = "タイトルを入力してください。"
            return
        }
        validationMessage = nil
        let due = includeDueDate ? dueDate : nil
        viewModel.addTask(
            title: trimmedTitle,
            dueDate: due,
            preferredSlot: preferredSlot,
            estimatedMinutes: estimatedMinutes
        )
        dismiss()
    }
    
    private func dismiss() {
        isPresented = false
    }
}

#Preview {
    AddTaskSheet(viewModel: TaskBoardViewModel(), isPresented: .constant(true))
}
