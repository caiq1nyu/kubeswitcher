import AppKit
import KubeSwitcherCore
import SwiftUI
import UniformTypeIdentifiers

private enum AppTheme {
    static let accent = Color(red: 0.03, green: 0.43, blue: 0.86)
    static let accentBlue = Color(red: 0.15, green: 0.55, blue: 0.95)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(nsColor: .controlBackgroundColor).opacity(0.62)
    static let surface = Color(nsColor: .textBackgroundColor)
    static let control = Color(nsColor: .controlBackgroundColor).opacity(0.72)
    static let border = Color.primary.opacity(0.075)
    static let mutedText = Color.primary.opacity(0.52)
}

struct KubeSwitcherRootView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                titleBar
                Divider()
                HStack(spacing: 0) {
                    SidebarView(viewModel: viewModel)
                        .frame(width: 280)
                    Divider()
                    DetailView(viewModel: viewModel)
                }
            }
            if viewModel.showingEditor {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                EnvironmentEditorView(viewModel: viewModel, record: viewModel.editingRecord)
                    .frame(width: 620)
                    .frame(maxHeight: 560)
                    .shadow(color: .black.opacity(0.16), radius: 28, y: 12)
            }
            if viewModel.showingSettings {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                SettingsView(viewModel: viewModel)
                    .frame(width: 560)
                    .frame(maxHeight: 540)
                    .shadow(color: .black.opacity(0.16), radius: 28, y: 12)
            }
            if let message = viewModel.toastMessage {
                toastView(message)
            }
        }
        .tint(AppTheme.accent)
        .background(AppTheme.canvas)
        .alert("KubeSwitcher", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("OK") { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(AppTheme.accent)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(AppTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            Text("KubeSwitcher")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.88))
            Spacer()
            HStack(spacing: 8) {
                statusPill(
                    label: viewModel.l10n.text(.currentEnvironment),
                    value: viewModel.appliedEnvironment?.name ?? viewModel.l10n.text(.noEnvironmentApplied),
                    systemImage: "switch.2",
                    accent: AppTheme.accent
                )
                statusPill(
                    label: viewModel.l10n.text(.currentNamespace),
                    value: appliedNamespaceText,
                    systemImage: "scope",
                    accent: AppTheme.accentBlue
                )
            }
            Button(viewModel.settings.language == .zhHans ? "EN" : "中文") {
                viewModel.toggleLanguage()
            }
            .buttonStyle(.plain)
            .font(.callout.weight(.semibold))
            .frame(minWidth: 46, minHeight: 32)
            .background(AppTheme.control, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
            Button {
                viewModel.showingEditor = false
                viewModel.editingRecord = nil
                viewModel.showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(AppTheme.control, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
            .help(viewModel.l10n.text(.preferences))
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .background(AppTheme.surface.opacity(0.96))
    }

    private var appliedNamespaceText: String {
        guard viewModel.appliedEnvironment != nil else {
            return viewModel.l10n.text(.noEnvironmentApplied)
        }
        let namespace = viewModel.appliedNamespace?.trimmingCharacters(in: .whitespacesAndNewlines)
        return namespace?.isEmpty == false ? namespace! : "default"
    }

    private func statusPill(label: String, value: String, systemImage: String, accent: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
                .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 168, alignment: .leading)
        .background(AppTheme.control, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.14), lineWidth: 1))
    }

    private func toastView(_ message: String) -> some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 9) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(message)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.9))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.10), radius: 16, y: 6)
            }
            .padding(.top, 12)
            .padding(.trailing, 22)
            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.18), value: viewModel.toastMessage)
    }
}

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(viewModel.l10n.text(.environments), systemImage: "square.stack.3d.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.66))
                Spacer()
                Button {
                    viewModel.editingRecord = nil
                    viewModel.showingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 32, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accent)
                .background(AppTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                .help(viewModel.l10n.text(.addEnvironment))
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(viewModel.l10n.text(.searchCluster), text: $viewModel.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))

            if viewModel.groupedEnvironments.isEmpty {
                Text(viewModel.l10n.text(.empty))
                    .foregroundStyle(.secondary)
                    .padding(.top, 32)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.groupedEnvironments, id: \.0) { group, records in
                            GroupSectionView(viewModel: viewModel, group: group, records: records)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .scrollIndicators(.hidden)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
        .background(AppTheme.sidebar)
    }
}

struct GroupSectionView: View {
    @ObservedObject var viewModel: AppViewModel
    let group: String
    let records: [EnvironmentRecord]
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                expanded.toggle()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .medium))
                    Text(group)
                        .lineLimit(1)
                    Text("\(records.count)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.primary.opacity(0.58))
                .font(.callout.weight(.semibold))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    EnvironmentRowView(viewModel: viewModel, record: record)
                    if index < records.count - 1 {
                        Divider()
                            .opacity(0.55)
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
        .padding(.top, 2)
    }
}

struct EnvironmentRowView: View {
    @ObservedObject var viewModel: AppViewModel
    let record: EnvironmentRecord
    @State private var hovering = false

    private var selected: Bool {
        viewModel.activeEnvironment?.id == record.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(record.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(selected ? Color.primary.opacity(0.92) : Color.primary.opacity(0.82))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    KindBadge(kind: record.kind)
                    Spacer()
                    Menu {
                        Button {
                            viewModel.editingRecord = record
                            viewModel.showingEditor = true
                        } label: {
                            Label(viewModel.l10n.text(.edit), systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            viewModel.deleteTarget = record
                        } label: {
                            Label(viewModel.l10n.text(.delete), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 24, height: 22)
                    }
                    .menuStyle(.borderlessButton)
                    .opacity(hovering || selected ? 1 : 0)
                }
                Text(record.description.isEmpty ? record.summary.contextName : record.description)
                    .font(.callout)
                    .foregroundStyle(AppTheme.mutedText)
                    .lineLimit(1)
                Text("ns: \(record.currentNamespace ?? "default")")
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(.primary.opacity(0.46))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.select(record)
            }

            if viewModel.deleteTarget?.id == record.id {
                HStack {
                    Spacer()
                    Button(viewModel.l10n.text(.cancel)) {
                        viewModel.deleteTarget = nil
                    }
                    Button(viewModel.l10n.text(.confirm)) {
                        viewModel.delete(record)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.red.opacity(0.35)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            selected
                ? AppTheme.accent.opacity(0.065)
                : hovering ? Color.primary.opacity(0.026) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(alignment: .leading) {
            if selected {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(AppTheme.accent)
                    .frame(width: 3)
                    .padding(.vertical, 10)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? AppTheme.accent.opacity(0.20) : Color.clear))
        .onHover { hovering = $0 }
    }
}

struct DetailView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let active = viewModel.activeEnvironment {
                header(active)
                Divider()
                namespaces(active)
            } else {
                Spacer()
                Text(viewModel.l10n.text(.empty))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .background(AppTheme.canvas)
    }

    private func header(_ record: EnvironmentRecord) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(viewModel.l10n.text(.activeCluster))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedText)
                    KindBadge(kind: record.kind)
                    Text(record.group)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.control, in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(AppTheme.mutedText)
                }
                Text(record.name)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.86))
            }
            Spacer()
            Button {
                Task { await viewModel.applySelectedEnvironment() }
            } label: {
                Label(viewModel.l10n.text(.applyConfig), systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(AppTheme.accent)
            .disabled(viewModel.isBusy)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(AppTheme.surface)
    }

    private func namespaces(_ record: EnvironmentRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(viewModel.l10n.text(.namespaceSelect))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.64))
                Text("\(viewModel.namespaces.count) Total")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppTheme.mutedText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.control, in: Capsule())
                Button {
                    viewModel.refreshNamespacesForSelected()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 26)
                }
                .buttonStyle(.plain)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                .disabled(viewModel.namespaceLoadingEnvironmentID == record.id)
                .help(viewModel.l10n.text(.refreshNamespaces))
                if viewModel.namespaceLoadingEnvironmentID == record.id {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.l10n.text(.namespaceLoading))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let namespaceLoadError = viewModel.namespaceLoadError {
                    Text("\(viewModel.l10n.text(.namespaceUnavailable)): \(namespaceLoadError)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(viewModel.l10n.text(.filterNamespaces), text: $viewModel.namespaceFilter)
                        .textFieldStyle(.plain)
                }
                .frame(width: 280)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
            }

            ScrollView {
                if viewModel.filteredNamespaces.isEmpty {
                    Text(emptyNamespaceMessage(record))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                        ForEach(viewModel.filteredNamespaces) { namespace in
                            NamespaceCard(
                                namespace: namespace,
                                selected: namespace.name == (record.currentNamespace ?? "default")
                            ) {
                                viewModel.selectNamespace(namespace.name, for: record.id)
                            }
                        }
                    }
                    .padding(.trailing, 6)
                }
            }
            .frame(minHeight: 220, maxHeight: .infinity)
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func emptyNamespaceMessage(_ record: EnvironmentRecord) -> String {
        if viewModel.namespaceLoadingEnvironmentID == record.id {
            return viewModel.l10n.text(.namespaceLoading)
        }
        if let namespaceLoadError = viewModel.namespaceLoadError {
            return "\(viewModel.l10n.text(.namespaceUnavailable)): \(namespaceLoadError)"
        }
        if !viewModel.namespaceFilter.isEmpty {
            return viewModel.l10n.text(.noNamespaceResults)
        }
        return viewModel.l10n.text(.namespacesNotLoaded)
    }
}

struct KindBadge: View {
    let kind: EnvironmentKind

    var body: some View {
        Text(kind == .prod ? "PROD" : "TEST")
            .font(.caption2.weight(.bold))
            .foregroundStyle(kind == .prod ? AppTheme.accent : AppTheme.accentBlue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(kind == .prod ? AppTheme.accent.opacity(0.09) : AppTheme.accentBlue.opacity(0.09), in: Capsule())
    }
}

struct NamespaceCard: View {
    let namespace: KubeNamespace
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(namespace.name)
                            .font(.system(.callout, design: .monospaced).weight(.semibold))
                            .foregroundStyle(selected ? AppTheme.accent : Color.primary.opacity(0.82))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                            .help(namespace.status)
                    }
                    Text("AGE \(ageText)")
                        .font(.caption2.monospacedDigit().weight(.medium))
                        .foregroundStyle(.primary.opacity(0.42))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(height: 56)
            .background(
                selected
                    ? AppTheme.accent.opacity(0.05)
                    : hovering ? Color.primary.opacity(0.025) : AppTheme.surface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(alignment: .leading) {
                if selected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(AppTheme.accent.opacity(0.88))
                        .frame(width: 3)
                        .padding(.vertical, 10)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? AppTheme.accent.opacity(0.30) : AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var statusColor: Color {
        switch namespace.status.lowercased() {
        case "active":
            return .green
        case "terminating":
            return .red
        default:
            return .secondary
        }
    }

    private var ageText: String {
        guard let createdAt = namespace.createdAt else { return "-" }
        let seconds = max(0, Int(Date().timeIntervalSince(createdAt)))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 48 { return "\(hours)h" }
        let days = hours / 24
        if days < 365 { return "\(days)d" }
        let years = days / 365
        return "\(years)y"
    }
}

struct EnvironmentEditorView: View {
    private enum GroupSelectionMode: String {
        case createNew
        case useExisting
    }

    @ObservedObject var viewModel: AppViewModel
    let record: EnvironmentRecord?

    @State private var groupSelectionMode: GroupSelectionMode
    @State private var newGroup: String
    @State private var selectedExistingGroup: String
    @State private var groupFilter = ""
    @State private var showingGroupPicker = false
    @State private var name: String
    @State private var kind: EnvironmentKind
    @State private var description: String
    @State private var configText: String
    @State private var sourceType: KubeConfigSourceType = .pastedText
    @State private var importingFile = false
    @State private var importedFileName: String?

    init(viewModel: AppViewModel, record: EnvironmentRecord?) {
        self.viewModel = viewModel
        self.record = record
        _groupSelectionMode = State(initialValue: record == nil ? .createNew : .useExisting)
        _newGroup = State(initialValue: record == nil ? EnvironmentStore.defaultGroup : "")
        _selectedExistingGroup = State(initialValue: record?.group ?? "")
        _name = State(initialValue: record?.name ?? "")
        _kind = State(initialValue: record?.kind ?? .test)
        _description = State(initialValue: record?.description ?? "")
        _configText = State(initialValue: "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.l10n.text(record == nil ? .addEnvironment : .editEnvironment))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.9))
                Spacer()
                Button {
                    viewModel.showingEditor = false
                    viewModel.editingRecord = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(AppTheme.control, in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Field(label: viewModel.l10n.text(.group), required: true) {
                        groupSelector
                    }

                    Field(label: viewModel.l10n.text(.name), required: true) {
                        TextField("minikube, aliyun-prod", text: $name)
                    }

                    HStack(spacing: 16) {
                        Field(label: viewModel.l10n.text(.kind), required: false) {
                            Picker("", selection: $kind) {
                                Text("测试环境 (TEST)").tag(EnvironmentKind.test)
                                Text("正式环境 (PROD)").tag(EnvironmentKind.prod)
                            }
                            .pickerStyle(.segmented)
                        }
                        Field(label: viewModel.l10n.text(.description), required: false) {
                            TextField("本地开发、阿里云生产...", text: $description)
                        }
                    }

                    HStack {
                        Text(viewModel.l10n.text(.source))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.mutedText)
                        Spacer()
                    }

                    Picker("", selection: $sourceType) {
                        Label(viewModel.l10n.text(.paste), systemImage: "doc.text").tag(KubeConfigSourceType.pastedText)
                        Label(viewModel.l10n.text(.importFile), systemImage: "square.and.arrow.down").tag(KubeConfigSourceType.importedFile)
                    }
                    .pickerStyle(.segmented)

                    if sourceType == .importedFile {
                        fileImportPrompt
                    } else {
                        configEditor(height: 160)
                    }

                    if record != nil && configText.isEmpty {
                        Text("重新粘贴 kubeconfig 后保存；Keychain 中的原配置不会直接展示。")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(22)
            }
            .background(AppTheme.canvas)

            Divider()

            HStack {
                Spacer()
                Button(viewModel.l10n.text(.cancel)) {
                    viewModel.showingEditor = false
                    viewModel.editingRecord = nil
                }
                .keyboardShortcut(.cancelAction)
                Button(viewModel.l10n.text(.save)) {
                    let draft = EnvironmentDraft(
                        id: record?.id,
                        name: name,
                        group: selectedGroup,
                        kind: kind,
                        description: description,
                        kubeConfig: configText,
                        sourceType: sourceType
                    )
                    Task { await viewModel.saveDraft(draft) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || configText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(AppTheme.surface)
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border))
        .fileImporter(isPresented: $importingFile, allowedContentTypes: kubeConfigContentTypes, allowsMultipleSelection: false) { result in
            do {
                let urls = try result.get()
                guard let url = urls.first else { return }
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                configText = try String(contentsOf: url, encoding: .utf8)
                sourceType = .importedFile
                importedFileName = url.lastPathComponent
            } catch {
                viewModel.alertMessage = localText(
                    zh: "读取 kubeconfig 文件失败: \(error.localizedDescription)",
                    en: "Failed to read kubeconfig file: \(error.localizedDescription)"
                )
            }
        }
        .task {
            if let record, configText.isEmpty {
                configText = (try? viewModel.store.kubeConfig(id: record.id)) ?? ""
            }
        }
    }

    private var existingGroups: [String] {
        Array(Set(viewModel.environments.map(\.group).filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var filteredGroups: [String] {
        guard !groupFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return existingGroups
        }
        return existingGroups.filter { $0.localizedCaseInsensitiveContains(groupFilter) }
    }

    private var selectedGroup: String {
        groupSelectionMode == .createNew ? newGroup : selectedExistingGroup
    }

    private var groupSelector: some View {
        HStack(spacing: 8) {
            Picker("", selection: $groupSelectionMode) {
                Text(viewModel.l10n.text(.createGroup)).tag(GroupSelectionMode.createNew)
                Text(viewModel.l10n.text(.useExistingGroup)).tag(GroupSelectionMode.useExisting)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 230)
            .onChange(of: groupSelectionMode) { mode in
                guard mode == .useExisting, selectedExistingGroup.isEmpty else { return }
                selectedExistingGroup = existingGroups.first ?? ""
            }

            if groupSelectionMode == .createNew {
                TextField(EnvironmentStore.defaultGroup, text: $newGroup)
            } else {
                Button {
                    groupFilter = ""
                    showingGroupPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedExistingGroup.isEmpty ? viewModel.l10n.text(.selectGroup) : selectedExistingGroup)
                            .foregroundStyle(selectedExistingGroup.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 9)
                    .frame(maxWidth: .infinity, minHeight: 22)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingGroupPicker, arrowEdge: .bottom) {
                    existingGroupPicker
                }
            }
        }
    }

    private var existingGroupPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(viewModel.l10n.text(.filterGroups), text: $groupFilter)
                .textFieldStyle(.roundedBorder)

            if filteredGroups.isEmpty {
                Text(viewModel.l10n.text(.noMatchingGroups))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 64)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredGroups, id: \.self) { existingGroup in
                            Button {
                                selectedExistingGroup = existingGroup
                                showingGroupPicker = false
                            } label: {
                                HStack {
                                    Text(existingGroup)
                                        .lineLimit(1)
                                    Spacer()
                                    if selectedExistingGroup == existingGroup {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(12)
        .frame(width: 280)
        .background(AppTheme.surface)
    }

    private var fileImportPrompt: some View {
        Button {
            importingFile = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
                Text(localText(zh: "点击区域选择 kubeconfig 文件", en: "Click to choose a kubeconfig file"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(localText(zh: "支持 .yaml、.yml、config 文件", en: "Supports .yaml, .yml, and config files"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let importedFileName {
                    Text(localText(zh: "已载入: \(importedFileName)", en: "Loaded: \(importedFileName)"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.accent.opacity(0.24), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
            )
        }
        .buttonStyle(.plain)
    }

    private func configEditor(height: CGFloat) -> some View {
        TextEditor(text: $configText)
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(.primary)
            .scrollContentBackground(.hidden)
            .padding(10)
            .frame(height: height)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
    }

    private var kubeConfigContentTypes: [UTType] {
        [
            .yaml,
            UTType(filenameExtension: "yml"),
            UTType(filenameExtension: "config"),
            .text,
            .data
        ].compactMap { $0 }
    }

    private func localText(zh: String, en: String) -> String {
        viewModel.settings.language == .zhHans ? zh : en
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var kubeConfigPath: String
    @State private var dataDirectoryPath: String
    @State private var deletePersistenceDirectoryOnClear: Bool
    @State private var hotKeyKey: String
    @State private var hotKeyModifiers: Set<HotKeyModifier>
    @State private var confirmingClear = false

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        _kubeConfigPath = State(initialValue: viewModel.appPreferences.kubeConfigPath)
        _dataDirectoryPath = State(initialValue: viewModel.appPreferences.dataDirectoryPath)
        _deletePersistenceDirectoryOnClear = State(initialValue: viewModel.appPreferences.deletePersistenceDirectoryOnClear)
        _hotKeyKey = State(initialValue: viewModel.settings.hotKey.key)
        _hotKeyModifiers = State(initialValue: Set(viewModel.settings.hotKey.modifiers))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.l10n.text(.preferences))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.9))
                Spacer()
                Button {
                    viewModel.showingSettings = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(AppTheme.control, in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                Field(label: viewModel.l10n.text(.defaultKubeConfigPath), required: true) {
                    TextField("~/.kube/config", text: $kubeConfigPath)
                }

                Field(label: viewModel.l10n.text(.persistenceDirectory), required: true) {
                    TextField("~/Library/Application Support/KubeSwitcher", text: $dataDirectoryPath)
                }

                Field(label: viewModel.l10n.text(.globalHotKey), required: true) {
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            modifierButton(.command)
                            modifierButton(.option)
                            modifierButton(.control)
                            modifierButton(.shift)
                        }

                        Picker(viewModel.l10n.text(.key), selection: $hotKeyKey) {
                            ForEach(HotKeyPreference.availableKeys, id: \.self) { key in
                                Text(key).tag(key)
                            }
                        }
                        .frame(width: 86)
                    }
                }

                Text("\(viewModel.l10n.text(.hotKeyHint)) \(HotKeyPreference(key: hotKeyKey, modifiers: Array(hotKeyModifiers)).displayText)")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Toggle(viewModel.l10n.text(.cleanupDeletesDirectory), isOn: $deletePersistenceDirectoryOnClear)

                Text(viewModel.l10n.text(.settingsHint))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.l10n.text(.clearDataWarning))
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if confirmingClear {
                        HStack {
                            Text(viewModel.l10n.text(.clearDataQuestion))
                                .foregroundStyle(.red)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(viewModel.l10n.text(.cancel)) {
                                confirmingClear = false
                            }
                            Button(viewModel.l10n.text(.confirm)) {
                                viewModel.clearPersistenceAndQuit(deleteDirectory: deletePersistenceDirectoryOnClear)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .padding(12)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.red.opacity(0.35)))
                    } else {
                        Button(role: .destructive) {
                            confirmingClear = true
                        } label: {
                            Label(viewModel.l10n.text(.clearDataAndQuit), systemImage: "trash")
                        }
                    }
                }
            }
            .padding(22)
            .background(AppTheme.canvas)

            Divider()

            HStack {
                Button(viewModel.l10n.text(.resetDefaults)) {
                    let defaults = AppPreferences.defaults()
                    kubeConfigPath = defaults.kubeConfigPath
                    dataDirectoryPath = defaults.dataDirectoryPath
                    deletePersistenceDirectoryOnClear = defaults.deletePersistenceDirectoryOnClear
                    hotKeyKey = HotKeyPreference().key
                    hotKeyModifiers = Set(HotKeyPreference().modifiers)
                }
                Spacer()
                Button(viewModel.l10n.text(.cancel)) {
                    viewModel.showingSettings = false
                }
                Button(viewModel.l10n.text(.save)) {
                    viewModel.saveSettings(
                        preferences: AppPreferences(
                            kubeConfigPath: kubeConfigPath,
                            dataDirectoryPath: dataDirectoryPath,
                            deletePersistenceDirectoryOnClear: deletePersistenceDirectoryOnClear
                        ),
                        hotKey: HotKeyPreference(key: hotKeyKey, modifiers: Array(hotKeyModifiers))
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(kubeConfigPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || dataDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || hotKeyModifiers.isEmpty)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(AppTheme.surface)
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border))
    }

    private func modifierButton(_ modifier: HotKeyModifier) -> some View {
        Button {
            if hotKeyModifiers.contains(modifier) {
                hotKeyModifiers.remove(modifier)
            } else {
                hotKeyModifiers.insert(modifier)
            }
        } label: {
            Text(modifier.displayText)
                .font(.headline.weight(.semibold))
                .frame(width: 34, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(hotKeyModifiers.contains(modifier) ? Color.white : Color.primary.opacity(0.72))
        .background(
            hotKeyModifiers.contains(modifier) ? AppTheme.accent : AppTheme.control,
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(hotKeyModifiers.contains(modifier) ? AppTheme.accent.opacity(0.15) : AppTheme.border, lineWidth: 1)
        )
        .help(viewModel.l10n.text(.modifiers))
    }
}

struct Field<Content: View>: View {
    let label: String
    let required: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedText)
                if required { Text("*").foregroundStyle(.red) }
            }
            content
                .textFieldStyle(.roundedBorder)
        }
    }
}
