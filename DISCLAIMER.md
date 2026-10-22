# 声明 / Disclaimer

## AI 参与开发

这个插件由 ATOM 构思需求、测试和验收，代码由 AI 编程助手（Claude Code）协助编写，包括 QML 组件、shell 脚本和像素头像生成脚本。所有代码都经过实际运行验证，但不是人工逐行手写的。

如果你在审查或使用本仓库的代码，请把这一点考虑进去。

## 仅供个人使用

- 这是按作者自己的环境（Arch + niri + kitty + DankMaterialShell）写的自用插件，**不是通用方案**。
- 没有发布到 DMS 插件注册表，也没有针对其他合成器、终端或桌面环境做适配。
- 不承诺维护、不承诺兼容未来版本的 DankMaterialShell 或 Claude Code。插件 API 在 DMS 中仍标记为 experimental，小版本升级可能直接失效。
- 使用本插件造成的任何问题（通知丢失、窗口跳错、脚本行为异常等），作者不承担责任。

## 没有许可证

本仓库未附开源许可证，保留所有权利。想使用或修改，请自行 fork；有具体问题可以开 issue，但不保证回复。

## 第三方依赖

插件调用 `kitty`（远程控制）、`niri`（窗口管理）、`notify-send`（libnotify）、`python3` 和 DankMaterialShell 自带的 `qs` IPC。这些工具各自的许可与行为与本仓库无关。
