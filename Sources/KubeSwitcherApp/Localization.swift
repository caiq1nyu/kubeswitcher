import Foundation
import KubeSwitcherCore

struct L10n {
    let language: AppLanguage

    func text(_ key: Key) -> String {
        switch language {
        case .zhHans:
            return key.zh
        case .english:
            return key.en
        }
    }

    struct Key {
        let zh: String
        let en: String
    }

}

extension L10n.Key {
    static let environments = Self(zh: "环境列表", en: "Environments")
    static let searchCluster = Self(zh: "搜索集群...", en: "Search cluster...")
    static let activeCluster = Self(zh: "当前集群", en: "Active Cluster")
    static let apiServer = Self(zh: "API 地址", en: "API Server")
    static let namespaceSelect = Self(zh: "命名空间选择", en: "Namespace Select")
    static let filterNamespaces = Self(zh: "过滤命名空间...", en: "Filter namespaces...")
    static let namespaceLoading = Self(zh: "正在加载命名空间...", en: "Loading namespaces...")
    static let namespaceUnavailable = Self(zh: "暂时无法加载命名空间", en: "Namespaces unavailable")
    static let refreshNamespaces = Self(zh: "刷新命名空间", en: "Refresh Namespaces")
    static let namespacesNotLoaded = Self(zh: "命名空间未加载，点击刷新按钮加载。", en: "Namespaces are not loaded. Click refresh.")
    static let noNamespaceResults = Self(zh: "没有匹配的命名空间。", en: "No matching namespaces.")
    static let edit = Self(zh: "编辑", en: "Edit")
    static let delete = Self(zh: "删除", en: "Delete")
    static let kubeconfigBoard = Self(zh: "KUBECONFIG 看板", en: "Kubeconfig Info Board")
    static let copyConfig = Self(zh: "复制配置", en: "Copy Config")
    static let defaultNamespace = Self(zh: "默认命名空间", en: "Default Namespace")
    static let currentEnvironment = Self(zh: "当前环境", en: "Current Env")
    static let currentNamespace = Self(zh: "当前 NS", en: "Current NS")
    static let noEnvironmentApplied = Self(zh: "未应用", en: "Not Applied")
    static let applyConfig = Self(zh: "应用配置", en: "Apply Config")
    static let applyConfigSucceeded = Self(zh: "配置已应用", en: "Config applied")
    static let preferences = Self(zh: "设置", en: "Settings")
    static let defaultKubeConfigPath = Self(zh: "默认 KUBECONFIG 路径", en: "Default KUBECONFIG Path")
    static let persistenceDirectory = Self(zh: "环境持久化目录", en: "Persistence Directory")
    static let cleanupDeletesDirectory = Self(zh: "清理时删除持久化目录", en: "Delete persistence directory when clearing")
    static let globalHotKey = Self(zh: "唤醒快捷键", en: "Global Hotkey")
    static let hotKeyHint = Self(zh: "用于唤醒或隐藏 KubeSwitcher，默认是 ⌘K。", en: "Shows or hides KubeSwitcher. Default is ⌘K.")
    static let modifiers = Self(zh: "修饰键", en: "Modifiers")
    static let key = Self(zh: "按键", en: "Key")
    static let clearDataAndQuit = Self(zh: "清理数据并退出", en: "Clear Data and Quit")
    static let clearDataQuestion = Self(zh: "确认清理 KubeSwitcher 数据?", en: "Clear KubeSwitcher data?")
    static let resetDefaults = Self(zh: "恢复默认", en: "Reset Defaults")
    static let dataDirectoryRestartNotice = Self(zh: "环境持久化目录已保存，下次启动后生效。", en: "Persistence directory saved. It will take effect after restart.")
    static let settingsHint = Self(
        zh: "KUBECONFIG 路径会立即用于下一次应用配置；持久化目录变更需要重启后生效。",
        en: "The KUBECONFIG path applies to the next apply action; persistence directory changes take effect after restart."
    )
    static let clearDataWarning = Self(
        zh: "会删除 KubeSwitcher 已登记环境和 Keychain 中对应 kubeconfig。此操作不会删除默认 kubeconfig。",
        en: "This removes KubeSwitcher registered environments and matching Keychain kubeconfigs. It does not delete the default kubeconfig."
    )
    static let addEnvironment = Self(zh: "添加环境", en: "Add Environment")
    static let editEnvironment = Self(zh: "修改环境", en: "Edit Environment")
    static let group = Self(zh: "环境分组", en: "Group")
    static let name = Self(zh: "环境名称", en: "Environment Name")
    static let kind = Self(zh: "环境属性", en: "Environment Type")
    static let description = Self(zh: "环境备注", en: "Description")
    static let source = Self(zh: "KUBECONFIG 配置来源", en: "Kubeconfig Source")
    static let paste = Self(zh: "文本贴入配置", en: "Paste Config")
    static let importFile = Self(zh: "导入本地文件", en: "Import File")
    static let cancel = Self(zh: "取消", en: "Cancel")
    static let save = Self(zh: "确认保存", en: "Save")
    static let deleteQuestion = Self(zh: "确认移除该环境?", en: "Remove this environment?")
    static let confirm = Self(zh: "确认", en: "Confirm")
    static let empty = Self(zh: "还没有环境，点击 + 添加 kubeconfig。", en: "No environments yet. Click + to add kubeconfig.")
    static let kubectlMissing = Self(zh: "未检测到 kubectl，请先安装并确保在 PATH 中。", en: "kubectl was not found. Install it and ensure it is in PATH.")
}
