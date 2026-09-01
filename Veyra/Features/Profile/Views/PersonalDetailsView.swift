import SwiftUI

struct PersonalDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        Form {
            Section("Public profile") {
                TextField("Display name", text: $viewModel.displayName)
                    .textContentType(.name)
                TextField("Username", text: $viewModel.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if let message = viewModel.validationMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.circle")
                        .foregroundStyle(VeyraColor.danger)
                }
            }

            Section {
                Button("Save changes") {
                    if viewModel.save() { dismiss() }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .background(VeyraColor.background)
        .navigationTitle("Personal details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PersonalDetailsView(viewModel: ProfileViewModel(store: InMemoryProfileStore()))
    }
    .preferredColorScheme(.dark)
}
