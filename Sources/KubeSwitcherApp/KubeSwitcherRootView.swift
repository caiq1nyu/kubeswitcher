import AppKit
import KubeSwitcherCore
import SwiftUI
import UniformTypeIdentifiers

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
                Color.black.opacity(0.30)
                    .ignoresSafeArea()
                EnvironmentEditorView(viewModel: viewModel, record: viewModel.editingRecord)
                    .frame(width: 560)
                    .shadow(radius: 18)
            }
            if viewModel.showingSettings {
                Color.black.opacity(0.30)
                    .ignoresSafeArea()
                SettingsView(viewModel: viewModel)
                    .frame(width: 560)
                    .shadow(radius: 18)
            }
            if let message = viewModel.toastMessage {
                toastView(message)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
        HStack {
            Image(systemName: "shippingbox.circle.fill")
                .foregroundStyle(.indigo)
                .font(.system(size: 17, weight: .semibold))
            Text("KubeSwitcher")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.9))
            Spacer()
            HStack(spacing: 8) {
                statusPill(
                    label: viewModel.l10n.text(.currentEnvironment),
                    value: viewModel.appliedEnvironment?.name ?? viewModel.l10n.text(.noEnvironmentApplied),
                    systemImage: "switch.2",
                    accent: .indigo
                )
                statusPill(
                    label: viewModel.l10n.text(.currentNamespace),
                    value: appliedNamespaceText,
                    systemImage: "scope",
                    accent: .blue
                )
            }
            Button(viewModel.settings.language == .zhHans ? "EN" : "中文") {
                viewModel.toggleLanguage()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            Button {
                viewModel.showingEditor = false
                viewModel.editingRecord = nil
                viewModel.showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help(viewModel.l10n.text(.preferences))
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
    }

    private var appliedNamespaceText: String {
        guard viewModel.appliedEnvironment != nil else {
            return viewModel.l10n.text(.noEnvironmentApplied)
        }
        let namespace = viewModel.settings.activeNamespace?.trimmingCharacters(in: .whitespacesAndNewlines)
        return namespace?.isEmpty == false ? namespace! : "default"
    }

    private func statusPill(label: String, value: String, systemImage: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 190, alignment: .leading)
        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.16), lineWidth: 1))
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
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
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
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(viewModel.l10n.text(.environments), systemImage: "square.stack.3d.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary.opacity(0.62))
                Spacer()
                Button {
                    viewModel.editingRecord = nil
                    viewModel.showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(viewModel.l10n.text(.searchCluster), text: $viewModel.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08)))

            if viewModel.groupedEnvironments.isEmpty {
                Text(viewModel.l10n.text(.empty))
                    .foregroundStyle(.secondary)
                    .padding(.top, 32)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
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
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct GroupSectionView: View {
    @ObservedObject var viewModel: AppViewModel
    let group: String
    let records: [EnvironmentRecord]
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                expanded.toggle()
            } label: {
                HStack {
                    Image(systemName: "folder")
                    Text(group.uppercased())
                    Text("\(records.count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.background, in: Capsule())
                    Spacer()
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                }
                .foregroundStyle(.primary.opacity(0.58))
                .font(.callout.weight(.bold))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    EnvironmentRowView(viewModel: viewModel, record: record)
                    if index < records.count - 1 {
                        Divider()
                            .padding(.horizontal, 10)
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
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(record.name)
                        .font(.headline.weight(.semibold))
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
                    if selected {
                        Circle()
                            .fill(.indigo)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(record.description.isEmpty ? record.summary.contextName : record.description)
                    .foregroundStyle(.primary.opacity(0.52))
                    .lineLimit(2)
                Text("ns: \(record.currentNamespace ?? "default")")
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.48))
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            selected
                ? Color.indigo.opacity(0.065)
                : hovering ? Color.primary.opacity(0.035) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.indigo.opacity(0.28) : Color.clear))
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
    }

    private func header(_ record: EnvironmentRecord) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(viewModel.l10n.text(.activeCluster))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.58))
                    Text("•")
                        .foregroundStyle(.primary.opacity(0.35))
                    KindBadge(kind: record.kind)
                    Text("•")
                        .foregroundStyle(.primary.opacity(0.35))
                    Text(record.group)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.primary.opacity(0.55))
                }
                Text(record.name)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.88))
            }
            Spacer()
            Button {
                Task { await viewModel.applySelectedEnvironment() }
            } label: {
                Label(viewModel.l10n.text(.applyConfig), systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isBusy)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 24)
    }

    private func namespaces(_ record: EnvironmentRecord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(viewModel.l10n.text(.namespaceSelect).uppercased())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary.opacity(0.62))
                Text("\(viewModel.namespaces.count) Total")
                    .font(.callout.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                Button {
                    viewModel.refreshNamespacesForSelected()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.namespaceLoadingEnvironmentID == record.id)
                .help(viewModel.l10n.text(.refreshNamespaces))
                if viewModel.namespaceLoadingEnvironmentID == record.id {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.l10n.text(.namespaceLoading))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if let namespaceLoadError = viewModel.namespaceLoadError {
                    Text("\(viewModel.l10n.text(.namespaceUnavailable)): \(namespaceLoadError)")
                        .font(.callout)
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
                .frame(width: 300)
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08)))
            }

            ScrollView {
                if viewModel.filteredNamespaces.isEmpty {
                    Text(emptyNamespaceMessage(record))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
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
            .frame(height: 340)
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 20)
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
            .font(.caption.weight(.heavy))
            .foregroundStyle(kind == .prod ? .indigo : .blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(kind == .prod ? Color.indigo.opacity(0.095) : Color.blue.opacity(0.095), in: Capsule())
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
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(namespace.name)
                            .font(.system(.callout, design: .monospaced).weight(.bold))
                            .foregroundStyle(selected ? Color.indigo.opacity(0.95) : Color.primary.opacity(0.86))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7.5, height: 7.5)
                            .help(namespace.status)
                    }
                    Text("AGE \(ageText)")
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.primary.opacity(0.44))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(height: 62)
            .background(
                selected
                    ? Color.indigo.opacity(0.045)
                    : hovering ? Color.primary.opacity(0.022) : Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(alignment: .leading) {
                if selected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.indigo.opacity(0.85))
                        .frame(width: 3)
                        .padding(.vertical, 10)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.indigo.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: selected ? 1.2 : 1)
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
    @ObservedObject var viewModel: AppViewModel
    let record: EnvironmentRecord?

    @State private var group: String
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
        _group = State(initialValue: record?.group ?? EnvironmentStore.defaultGroup)
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
                }
                .buttonStyle(.plain)
                .font(.title3)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        Field(label: viewModel.l10n.text(.group), required: true) {
                            TextField(EnvironmentStore.defaultGroup, text: $group)
                        }
                        Field(label: viewModel.l10n.text(.name), required: true) {
                            TextField("minikube, aliyun-prod", text: $name)
                        }
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
                        Text(viewModel.l10n.text(.source).uppercased())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    Picker("", selection: $sourceType) {
                        Label(viewModel.l10n.text(.paste), systemImage: "doc.text").tag(KubeConfigSourceType.pastedText)
                        Label(viewModel.l10n.text(.importFile), systemImage: "square.and.arrow.down").tag(KubeConfigSourceType.importedFile)
                    }
                    .pickerStyle(.segmented)

                    if sourceType == .importedFile {
                        fileImportPrompt
                        if !configText.isEmpty {
                            configEditor(height: 120)
                        }
                    } else {
                        configEditor(height: 180)
                    }

                    if record != nil && configText.isEmpty {
                        Text("重新粘贴 kubeconfig 后保存；Keychain 中的原配置不会直接展示。")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(22)
            }

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
                        group: group,
                        kind: kind,
                        description: description,
                        kubeConfig: configText,
                        sourceType: sourceType
                    )
                    Task { await viewModel.saveDraft(draft) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || configText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
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

    private var fileImportPrompt: some View {
        Button {
            importingFile = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                Text(localText(zh: "点击区域选择 kubeconfig 文件", en: "Click to choose a kubeconfig file"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(localText(zh: "支持 .yaml、.yml、config 文件", en: "Supports .yaml, .yml, and config files"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let importedFileName {
                    Text(localText(zh: "已载入: \(importedFileName)", en: "Loaded: \(importedFileName)"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.indigo)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.indigo.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
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
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
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
                }
                .buttonStyle(.plain)
                .font(.title3)
                .foregroundStyle(.secondary)
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
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
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
            hotKeyModifiers.contains(modifier) ? Color.accentColor : Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(hotKeyModifiers.contains(modifier) ? Color.accentColor.opacity(0.15) : Color.black.opacity(0.08), lineWidth: 1)
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
                    .foregroundStyle(.primary.opacity(0.58))
                if required { Text("*").foregroundStyle(.red) }
            }
            content
                .textFieldStyle(.roundedBorder)
        }
    }
}
