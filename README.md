# KubeSwitcher

[中文](README-CN.md) | English

KubeSwitcher is a small macOS menu-bar app for people who manage many Kubernetes environments locally and switch between them all day.

It is built for operators and developers who already use terminal tools like `kubectl`, `kubens`, `kubectx`, and `k9s`, but want a faster way to pick the kubeconfig and namespace before returning to the terminal.

![KubeSwitcher main window](docs/images/kubeswitcher-main.png)

## What It Does

- Register Kubernetes environments from pasted or imported kubeconfig files.
- Organize environments with simple freeform groups.
- Mark environments as `TEST` or `PROD`.
- Preview and pick namespaces before applying an environment.
- Apply the selected kubeconfig and namespace to your configured kubeconfig path.
- Back up the existing kubeconfig before overwriting it.
- Show or hide the app with a configurable global hotkey. The default is `Command + K`.
- Switch UI language between Chinese and English.

## How It Works

KubeSwitcher keeps environment metadata under your configured persistence directory. Kubeconfig contents are stored in macOS Keychain.

When you click **Apply Config**, KubeSwitcher writes the selected environment to the configured kubeconfig path. The default path is:

```text
~/.kube/config
```

Before writing, it creates a timestamped backup next to that file.

`kubectl` is required. KubeSwitcher uses your local `kubectl` to validate kubeconfigs and list namespaces.

## Settings

Open Settings from the top-right gear button. You can configure:

- Default kubeconfig path.
- Environment persistence directory.
- Whether clearing app data also removes the persistence directory.
- Global show/hide hotkey.

## GitHub Description

Fast macOS menu-bar switcher for local Kubernetes kubeconfigs and namespaces.

## Note

On first install via dmg, you need to manually grant trust in System Settings > Privacy & Security > Security.
