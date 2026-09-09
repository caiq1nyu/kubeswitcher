import AppKit
import Foundation
import KubeSwitcherCore
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    @Published var environments: [EnvironmentRecord] = []
    @Published var settings = KubeSwitcherSettings()
    @Published var selectedID: UUID?
    @Published var namespaces: [KubeNamespace] = []
    @Published var namespaceLoadError: String?
    @Published var namespaceLoadingEnvironmentID: UUID?
    @Published var searchText = ""
    @Published var namespaceFilter = ""
    @Published var showingEditor = false
    @Published var showingSettings = false
    @Published var showingExport = false
    @Published var isTransferring = false
    @Published var editingRecord: EnvironmentRecord?
    @Published var deleteTarget: EnvironmentRecord?
    @Published var alertMessage: String?
    @Published var toastMessage: String?
    @Published var toastHasFailures = false
    @Published var appliedNamespace: String?
    @Published var isBusy = false
    @Published var appPreferences: AppPreferences

    let store: EnvironmentStore
    private let kubectl: KubectlClient
    private var activator: EnvironmentActivator
    private var namespacePreviewTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var kubeConfigMonitorTask: Task<Void, Never>?
    private var lastKubeConfigModificationDate: Date?
    var onHotKeyPreferenceChanged: ((HotKeyPreference) -> Void)?

    var l10n: L10n { L10n(language: settings.language) }

    var activeEnvironment: EnvironmentRecord? {
        environments.first { $0.id == selectedID }
            ?? environments.first { $0.id == settings.activeEnvironmentID }
            ?? environments.first
    }

    var appliedEnvironment: EnvironmentRecord? {
        guard let activeEnvironmentID = settings.activeEnvironmentID else { return nil }
        return environments.first { $0.id == activeEnvironmentID }
    }

    var groupedEnvironments: [(String, [EnvironmentRecord])] {
        let filtered = environments.filter { record in
            searchText.isEmpty
                || record.name.localizedCaseInsensitiveContains(searchText)
                || record.description.localizedCaseInsensitiveContains(searchText)
                || record.group.localizedCaseInsensitiveContains(searchText)
        }
        let groups = Dictionary(grouping: filtered, by: \.group)
        return groups.keys.sorted().map { ($0, groups[$0] ?? []) }
    }

    var filteredNamespaces: [KubeNamespace] {
        guard !namespaceFilter.isEmpty else { return namespaces }
        return namespaces.filter { $0.name.localizedCaseInsensitiveContains(namespaceFilter) }
    }

    static func bootstrap() -> AppViewModel {
        let preferences = AppPreferencesStore.load()
        let kubectl = KubectlClient()
        do {
            let dataDirectory = preferences.resolvedDataDirectoryURL
            try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            let store = EnvironmentStore(
                metadataURL: dataDirectory.appendingPathComponent("environments.json"),
                secretStore: KeychainKubeConfigStore(),
                kubectl: kubectl
            )
            let activator = EnvironmentActivator(
                store: store,
                kubectl: kubectl,
                kubeConfigPath: preferences.resolvedKubeConfigURL
            )
            return AppViewModel(store: store, kubectl: kubectl, activator: activator, appPreferences: preferences)
        } catch {
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent("KubeSwitcherFallback", isDirectory: true)
            let metadata = temp.appendingPathComponent("environments.json")
            let memory = VolatileKubeConfigStore()
            let store = EnvironmentStore(metadataURL: metadata, secretStore: memory, kubectl: kubectl)
            let model = AppViewModel(
                store: store,
                kubectl: kubectl,
                activator: EnvironmentActivator(store: store, kubectl: kubectl, kubeConfigPath: preferences.resolvedKubeConfigURL),
                appPreferences: preferences
            )
            model.alertMessage = error.localizedDescription
            return model
        }
    }

    init(store: EnvironmentStore, kubectl: KubectlClient, activator: EnvironmentActivator, appPreferences: AppPreferences) {
        self.store = store
        self.kubectl = kubectl
        self.activator = activator
        self.appPreferences = appPreferences
    }

    func refresh() async {
        do {
            environments = try store.loadEnvironments()
            settings = try store.loadSettings()
            selectedID = settings.activeEnvironmentID ?? environments.first?.id
            resetNamespacePreviewState()
            await refreshAppliedNamespaceFromDefaultKubeConfig(force: true)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func toggleLanguage() {
        settings.language = settings.language == .zhHans ? .english : .zhHans
        try? store.saveSettings(settings)
    }

    func saveAppPreferences(_ preferences: AppPreferences) {
        let preferences = AppPreferences(
            kubeConfigPath: preferences.kubeConfigPath.trimmingCharacters(in: .whitespacesAndNewlines),
            dataDirectoryPath: preferences.dataDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines),
            deletePersistenceDirectoryOnClear: preferences.deletePersistenceDirectoryOnClear
        )
        let oldDataDirectory = appPreferences.resolvedDataDirectoryURL.standardizedFileURL
        let newDataDirectory = preferences.resolvedDataDirectoryURL.standardizedFileURL
        AppPreferencesStore.save(preferences)
        appPreferences = preferences
        activator = EnvironmentActivator(
            store: store,
            kubectl: kubectl,
            kubeConfigPath: preferences.resolvedKubeConfigURL
        )
        showingSettings = false
        lastKubeConfigModificationDate = nil
        Task { await refreshAppliedNamespaceFromDefaultKubeConfig(force: true) }
        if oldDataDirectory != newDataDirectory {
            alertMessage = l10n.text(.dataDirectoryRestartNotice)
        }
    }

    func saveSettings(preferences: AppPreferences, hotKey: HotKeyPreference) {
        saveAppPreferences(preferences)
        settings.hotKey = hotKey
        do {
            try store.saveSettings(settings)
            onHotKeyPreferenceChanged?(hotKey)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func resetAppPreferences() {
        saveAppPreferences(AppPreferences.defaults())
    }

    func clearPersistenceAndQuit(deleteDirectory: Bool) {
        do {
            try store.clearPersistence(deleteDirectory: deleteDirectory)
            NSApp.terminate(nil)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func select(_ record: EnvironmentRecord) {
        selectedID = record.id
        resetNamespacePreviewState()
        startNamespacePreview(environmentID: record.id)
    }

    func applySelectedEnvironment() async {
        guard let id = activeEnvironment?.id else { return }
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await applyUnlocked(id, namespace: activeEnvironment?.currentNamespace)
            showToast(l10n.text(.applyConfigSucceeded))
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func startDefaultKubeConfigMonitor() {
        kubeConfigMonitorTask?.cancel()
        kubeConfigMonitorTask = Task { [weak self] in
            await self?.refreshAppliedNamespaceFromDefaultKubeConfig(force: true)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await self?.refreshAppliedNamespaceFromDefaultKubeConfig(force: false)
            }
        }
    }

    func refreshAppliedNamespaceFromDefaultKubeConfig(force: Bool = false) async {
        guard settings.activeEnvironmentID != nil else {
            appliedNamespace = nil
            return
        }

        let kubeConfigURL = appPreferences.resolvedKubeConfigURL
        let modificationDate = (try? FileManager.default.attributesOfItem(atPath: kubeConfigURL.path)[.modificationDate]) as? Date
        guard force || modificationDate != lastKubeConfigModificationDate else { return }
        lastKubeConfigModificationDate = modificationDate

        do {
            appliedNamespace = try await kubectl.currentNamespace(kubeConfigPath: kubeConfigURL) ?? "default"
        } catch {
            appliedNamespace = "default"
        }
    }

    private func showToast(_ message: String, hasFailures: Bool = false, duration: UInt64 = 2_000_000_000) {
        toastHasFailures = hasFailures
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self?.toastMessage == message {
                    self?.toastMessage = nil
                }
            }
        }
    }

    func transferText(zh: String, en: String) -> String {
        settings.language == .zhHans ? zh : en
    }

    func exportEnvironments(ids: Set<UUID>) {
        guard !isBusy, !ids.isEmpty else { return }
        let panel = NSSavePanel()
        panel.level = .floating
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "kubeswitcher-environments.json"
        panel.canCreateDirectories = true
        panel.title = transferText(zh: "导出环境", en: "Export environments")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try store.exportEnvironments(ids: ids)
            try data.write(to: url, options: .atomic)
            showingExport = false
            showToast(transferText(zh: "导出完成，成功\(ids.count)个", en: "Export complete, \(ids.count) succeeded"))
        } catch {
            showToast(transferText(zh: "导出失败：", en: "Export failed: ") + error.localizedDescription, hasFailures: true)
        }
    }

    func importEnvironments() async {
        guard !isBusy else { return }
        let panel = NSOpenPanel()
        panel.level = .floating
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = transferText(zh: "导入环境", en: "Import environments")
        let window = NSApp.keyWindow
        let response = await withCheckedContinuation { continuation in
            if let window {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
        panel.orderOut(nil)
        guard response == .OK, let url = panel.url else { return }
        window?.makeKeyAndOrderFront(nil)
        await importEnvironments(from: url)
    }

    func importEnvironments(from url: URL) async {
        guard !isBusy else { return }
        isBusy = true
        isTransferring = true
        var message: String
        var hasFailures: Bool
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let result = try await store.importEnvironments(data: Data(contentsOf: url))
            environments = try store.loadEnvironments()
            message = transferText(
                zh: "导入完成，成功\(result.succeeded)个",
                en: "Import complete, \(result.succeeded) succeeded"
            )
            if result.failed > 0 {
                message += transferText(zh: "，失败\(result.failed)个", en: ", \(result.failed) failed")
            }
            hasFailures = result.failed > 0
        } catch {
            message = transferText(zh: "导入失败：", en: "Import failed: ") + error.localizedDescription
            hasFailures = true
        }
        isBusy = false
        isTransferring = false
        showToast(message, hasFailures: hasFailures, duration: 4_000_000_000)
    }

    func saveDraft(_ draft: EnvironmentDraft) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let record = try await store.saveEnvironment(draft: draft)
            environments = try store.loadEnvironments()
            showingEditor = false
            editingRecord = nil
            selectedID = record.id
            resetNamespacePreviewState()
            startNamespacePreview(environmentID: record.id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func applyUnlocked(_ id: UUID, namespace: String?) async throws {
        let result = try await activator.activate(id, namespace: namespace)
        if !result.namespaces.isEmpty {
            namespaces = result.namespaces
        }
        environments = try store.loadEnvironments()
        settings = try store.loadSettings()
        selectedID = id
        await refreshAppliedNamespaceFromDefaultKubeConfig(force: true)
        namespaceLoadError = result.namespaceRefreshError
        namespaceLoadingEnvironmentID = nil
    }

    func refreshNamespacesForSelected() {
        guard let id = activeEnvironment?.id else { return }
        startNamespacePreview(environmentID: id)
    }

    private func resetNamespacePreviewState() {
        namespacePreviewTask?.cancel()
        namespacePreviewTask = nil
        namespaceFilter = ""
        namespaces = []
        namespaceLoadError = nil
        namespaceLoadingEnvironmentID = nil
    }

    private func clearNamespaceLoading(environmentID: UUID) {
        if namespaceLoadingEnvironmentID == environmentID {
            namespaceLoadingEnvironmentID = nil
        }
    }

    func selectNamespace(_ namespace: String, for environmentID: UUID) {
        do {
            try store.updateNamespace(environmentID: environmentID, namespace: namespace)
            environments = try store.loadEnvironments()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func startNamespacePreview(environmentID: UUID) {
        namespacePreviewTask?.cancel()
        namespaceLoadError = nil
        namespaceLoadingEnvironmentID = environmentID
        namespacePreviewTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.activator.previewNamespaces(environmentID: environmentID)
                guard !Task.isCancelled else { return }
                if self.selectedID == environmentID {
                    self.namespaces = result.namespaces
                    self.namespaceLoadError = result.namespaceRefreshError
                    self.clearNamespaceLoading(environmentID: environmentID)
                }
            } catch {
                guard !Task.isCancelled else { return }
                if self.selectedID == environmentID {
                    self.namespaces = []
                    self.namespaceLoadError = error.localizedDescription
                    self.clearNamespaceLoading(environmentID: environmentID)
                }
            }
        }
    }

    func delete(_ record: EnvironmentRecord) {
        do {
            try store.deleteEnvironment(id: record.id)
            environments = try store.loadEnvironments()
            selectedID = environments.first?.id
            deleteTarget = nil
            resetNamespacePreviewState()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func kubeConfigForClipboard() {
        guard let id = activeEnvironment?.id else { return }
        do {
            let config = try store.kubeConfig(id: id)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(config, forType: .string)
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

private final class VolatileKubeConfigStore: KubeConfigSecretStore {
    private var values: [UUID: String] = [:]

    func saveConfig(_ config: String, id: UUID) throws {
        values[id] = config
    }

    func readConfig(id: UUID) throws -> String? {
        values[id]
    }

    func deleteConfig(id: UUID) throws {
        values.removeValue(forKey: id)
    }
}
