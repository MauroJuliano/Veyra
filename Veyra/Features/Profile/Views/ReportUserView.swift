import SwiftUI

private enum ReportReason: String, CaseIterable, Identifiable {
    case spam
    case harassment
    case impersonation
    case inappropriateContent = "inappropriate_content"
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam: "Spam"
        case .harassment: "Harassment or bullying"
        case .impersonation: "Pretending to be someone else"
        case .inappropriateContent: "Inappropriate content"
        case .other: "Something else"
        }
    }
}

struct ReportUserView: View {
    @Environment(\.dismiss) private var dismiss
    let user: User
    let repository: (any RemoteChatRepository)?
    let onSubmitted: () -> Void

    @State private var reason: ReportReason = .spam
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Why are you reporting this profile?") {
                    Picker("Reason", selection: $reason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.title).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    TextField(
                        "Add context (optional)",
                        text: $details,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .onChange(of: details) { _, value in
                        if value.count > 500 {
                            details = String(value.prefix(500))
                        }
                    }

                    Text("\(details.count)/500")
                        .font(VeyraTypography.caption)
                        .foregroundStyle(VeyraColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } header: {
                    Text("Details")
                } footer: {
                    Text("Reports are reviewed privately. Reporting does not automatically block this user.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .foregroundStyle(VeyraColor.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(VeyraColor.background)
            .navigationTitle("Report \(user.participantName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { Task { await submit() } }
                        .disabled(isSubmitting)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func submit() async {
        guard let repository, let userID = user.participantID else {
            errorMessage = "Reporting is unavailable right now."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await repository.reportUser(
                userID: userID,
                reason: reason.rawValue,
                details: details.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSubmitted()
            dismiss()
        } catch {
            if error.localizedDescription.lowercased().contains("already pending") {
                errorMessage = "You already have a report pending for this user."
            } else {
                errorMessage = "The report could not be submitted. Please try again."
            }
        }
    }
}

#Preview {
    ReportUserView(
        user: User(participantName: "Martha Nielsen", userName: "@martha", participantAvatarURL: nil),
        repository: nil,
        onSubmitted: {}
    )
}
