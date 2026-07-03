# KubeSwitcher

中文 | [English](README.md)

KubeSwitcher 是一个 macOS 菜单栏小工具，适合日常在本地管理大量 Kubernetes 环境、频繁切换 kubeconfig 和 namespace 的开发者或运维同学。

它不是用来替代 `kubectl`、`kubens`、`kubectx`、`k9s` 的。它更像是一个轻量的本地环境选择器：先在界面里选好环境和命名空间，再继续用你熟悉的终端工具工作。

![KubeSwitcher main window](docs/images/kubeswitcher-main.png)

## 功能

- 通过粘贴或导入 kubeconfig 文件登记 Kubernetes 环境。
- 用简单的自由分组管理环境。
- 区分 `TEST` 和 `PROD` 环境。
- 预览并选择 namespace。
- 点击 **应用配置** 后，把选中的 kubeconfig 和 namespace 写入配置里的 kubeconfig 路径。
- 覆盖前自动备份原来的 kubeconfig。
- 支持可配置的全局唤醒/隐藏快捷键，默认是 `Command + K`。
- 支持中文 / English 切换。

## 工作方式

KubeSwitcher 会把环境元数据保存在你配置的持久化目录里，kubeconfig 内容会保存到 macOS Keychain。

点击 **应用配置** 时，它会把当前选中的环境写入配置里的 kubeconfig 路径。默认路径是：

```text
~/.kube/config
```

写入前会在同目录下创建带时间戳的备份文件。

KubeSwitcher 依赖本机 `kubectl`，会用它来校验 kubeconfig 和读取 namespace。

## 设置项

右上角齿轮按钮可以打开设置，目前支持：

- 默认 kubeconfig 路径。
- 环境持久化目录。
- 清理应用数据时是否同时删除持久化目录。
- 全局唤醒/隐藏快捷键。

## 说明

dmg首次安装时，需要在 系统设置-隐私与安全性-安全性 中手动授信一下
