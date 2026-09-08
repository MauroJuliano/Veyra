import SwiftUI

struct ContactListView: View {
    let repository: (any RemoteChatRepository)?
    let callRepository: (any CallRepository)?
    let localRepository: any ContactRepository
    let messageCache: any MessageCacheRepository
    @State private var contacts: [Contact]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedConversation: Conversation?
    @State private var selectedContact: Contact?
    @State private var openingContactID: UUID?

    var groupedUsers: [String: [Contact]] {
        Dictionary(grouping: filteredContacts) { contact in
            String(contact.name.prefix(1)).uppercased()
        }
    }

    var sortedKeys: [String] {
        groupedUsers.keys.sorted()
    }

    init(repository: (any RemoteChatRepository)?, callRepository: (any CallRepository)? = nil, localRepository: any ContactRepository, messageCache: any MessageCacheRepository) {
        self.repository = repository
        self.callRepository = callRepository
        self.localRepository = localRepository
        self.messageCache = messageCache
        _contacts = State(initialValue: localRepository.fetchContacts())
    }

    private var filteredContacts: [Contact] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return contacts }
        return contacts.filter { $0.name.localizedStandardContains(query) }
    }

    var body: some View {
        Group {
            if isLoading && contacts.isEmpty {
                ProgressView("Loading contacts…")
            } else if contacts.isEmpty {
                ContentUnavailableView(
                    "No contacts yet",
                    systemImage: "person.2",
                    description: Text(errorMessage ?? String(localized: "People you start conversations with will appear here."))
                )
            } else {
                List {
                    ForEach(sortedKeys, id: \.self) { key in
                        Section(header: Text(key)) {
                            ForEach(groupedUsers[key]!.sorted(by: { $0.name < $1.name })) { contact in
                                Button {
                                    selectedContact = contact
                                } label: {
                                    HStack {
                                        contactRow(contact)
                                        Spacer()
                                        if openingContactID == contact.id {
                                            ProgressView()
                                        } else {
                                            Image(systemName: "chevron.right")
                                                .font(.caption.bold())
                                                .foregroundStyle(VeyraColor.textSecondary)
                                        }
                                    }
                                    .padding(.horizontal, VeyraSpacing.md)
                                    .padding(.vertical, VeyraSpacing.xs)
                                    .frame(maxWidth: .infinity)
                                    .background {
                                        GlassBackground()
                                    }
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 18,
                                            style: .continuous
                                        )
                                    )

                                    if groupedUsers[key, default: []].count > 1 &&
                                        contact.id != groupedUsers[key, default: []].last?.id {

                                        Divider()
                                            .padding(.leading, 72)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(openingContactID != nil)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(
                                    EdgeInsets(
                                        top: 4,
                                        leading: 0,
                                        bottom: 4,
                                        trailing: 0
                                    )
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, VeyraSpacing.md)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnTap()

            }
        }
        .navigationTitle("Connections")
        .searchable(text: $searchText, prompt: "Search contacts")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [VeyraColor.background, VeyraColor.accentMuted.opacity(0.5), VeyraColor.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(item: $selectedConversation) { conversation in
            MessageTimelineView(conversation: conversation, repository: repository, callRepository: callRepository, cache: messageCache, messages: [])
        }
        .navigationDestination(item: $selectedContact) { contact in
            PublicProfileView(
                user: User(
                    id: contact.id,
                    participantID: contact.id,
                    participantName: contact.name,
                    userName: "",
                    bio: contact.bio,
                    participantAvatarURL: contact.avatarURL
                ),
                repository: repository,
                callRepository: callRepository,
                conversationID: contact.conversationID
            ) { _ in
                await openConversation(with: contact)
            }
        }
    }

    private func contactRow(_ contact: Contact) -> some View {
        HStack(spacing: VeyraSpacing.md) {
            VeyraAvatar(name: contact.name, imageURL: contact.avatarURL, showsOnlineIndicator: contact.isOnline)
            VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                Text(contact.name)
                    .font(VeyraTypography.bodyEmphasized)
                    .foregroundStyle(VeyraColor.textPrimary)

                Text(contact.bio.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "No bio yet"))
                    .font(VeyraTypography.body)
                    .foregroundStyle(VeyraColor.textSecondary)
                    .lineLimit(1)
            }

        }
        .padding(.vertical, VeyraSpacing.xs)

    }

    @MainActor
    private func load() async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let remoteContacts = try await repository.fetchContacts()
            localRepository.saveContacts(remoteContacts)
            contacts = remoteContacts
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func openConversation(with contact: Contact) async {
        guard let repository else { return }
        openingContactID = contact.id
        defer { openingContactID = nil }
        do {
            selectedConversation = try await repository.startConversation(with: contact)
            selectedContact = nil
            errorMessage = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
