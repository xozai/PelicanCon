import SwiftUI

struct InviteListView: View {
    @State private var config: InviteGateConfig?
    @State private var isLoading    = true
    @State private var isSaving     = false
    @State private var newEmails    = ""   // paste multiple, comma/newline separated
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var emailToRemove: String?
    @State private var showRemoveConfirm = false

    private let service = InviteGateService.shared

    var body: some View {
        ZStack {
            Theme.offWhite.ignoresSafeArea()
            if isLoading {
                ProgressView("Loading…").tint(Theme.red)
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        gateToggleCard
                        addEmailsCard
                        emailListCard
                        Spacer(minLength: 32)
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Invite List")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let msg = successMessage {
                successToast(msg).transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { successMessage = nil } }
            }
        }
        .animation(.spring(response: 0.4), value: successMessage)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .confirmationDialog("Remove \(emailToRemove ?? "email")?",
                            isPresented: $showRemoveConfirm,
                            titleVisibility: .visible) {
            Button("Remove from List", role: .destructive) {
                guard let email = emailToRemove else { return }
                Task { await removeEmail(email) }
            }
            Button("Cancel", role: .cancel) { emailToRemove = nil }
        }
        .task { await loadConfig() }
    }

    // MARK: - Cards

    private var gateToggleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Registration Gate", systemImage: "lock.shield.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.darkGray)
            Toggle("Restrict registration to approved emails only", isOn: Binding(
                get:  { config?.enabled ?? false },
                set: { newVal in
                    config?.enabled = newVal
                    Task { await saveEnabled(newVal) }
                }
            ))
            .tint(Theme.red)
            Text(config?.enabled == true
                 ? "Only emails on this list can create an account."
                 : "Anyone can register. Enable this to restrict access to approved emails.")
                .font(.caption)
                .foregroundColor(Theme.midGray)
        }
        .padding(16).cardStyle()
    }

    private var addEmailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Add Approved Emails", systemImage: "person.badge.plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.darkGray)
            TextEditor(text: $newEmails)
                .font(.system(size: 14, design: .monospaced))
                .frame(minHeight: 100, maxHeight: 160)
                .padding(10)
                .background(Theme.lightGray)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("Paste one email per line, or comma-separated. Bulk import supported.")
                .font(.caption2).foregroundColor(Theme.midGray)
            Button {
                Task { await addEmails() }
            } label: {
                if isSaving {
                    HStack(spacing: 8) { ProgressView().tint(.white); Text("Adding…") }
                } else {
                    Label("Add to List", systemImage: "plus.circle.fill")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(newEmails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
        }
        .padding(16).cardStyle()
    }

    private var emailListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Approved Emails (\(config?.allowedEmails.count ?? 0))",
                      systemImage: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.darkGray)
                Spacer()
            }
            if config?.allowedEmails.isEmpty != false {
                Text("No emails added yet.")
                    .font(.subheadline).foregroundColor(Theme.midGray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(config?.allowedEmails.sorted() ?? [], id: \.self) { email in
                    HStack {
                        Image(systemName: "envelope.fill")
                            .font(.caption).foregroundColor(Theme.midGray)
                        Text(email)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Theme.darkGray)
                        Spacer()
                        Button {
                            emailToRemove      = email
                            showRemoveConfirm  = true
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(Theme.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    if email != config?.allowedEmails.sorted().last {
                        Divider()
                    }
                }
            }
        }
        .padding(16).cardStyle()
    }

    // MARK: - Actions

    private func loadConfig() async {
        isLoading = true
        let fetched = await service.fetchConfig()
        config    = fetched ?? InviteGateConfig(enabled: false, allowedEmails: [])
        isLoading = false
    }

    private func saveEnabled(_ enabled: Bool) async {
        guard var c = config else { return }
        c.enabled = enabled
        try? await service.saveConfig(c)
    }

    private func addEmails() async {
        let raw = newEmails
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.contains("@") }
        guard !raw.isEmpty else { errorMessage = "No valid email addresses found."; return }
        isSaving = true
        do {
            try await service.addEmails(raw)
            config?.allowedEmails.append(contentsOf: raw)
            newEmails      = ""
            successMessage = "Added \(raw.count) email\(raw.count == 1 ? "" : "s")."
        } catch { errorMessage = error.localizedDescription }
        isSaving = false
    }

    private func removeEmail(_ email: String) async {
        do {
            try await service.removeEmail(email)
            config?.allowedEmails.removeAll { $0 == email }
            successMessage = "Removed \(email)."
        } catch { errorMessage = error.localizedDescription }
        emailToRemove = nil
    }

    private func successToast(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
            Text(msg).font(.subheadline).fontWeight(.medium).foregroundColor(.white)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Theme.success)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8)
        .padding(.top, 12)
    }
}
