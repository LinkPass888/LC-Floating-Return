# LCFloatingReturn 0.1.1

这是一个面向 LiveContainer / SideStore Guest 的精简悬浮返回按钮插件。

- iOS 16+，arm64。
- 点击悬浮按钮：返回 LiveContainer 首页。
- 长按约 0.55 秒：打开按钮外观设置。
- 拖动按钮：沿屏幕移动，松手后吸附到左右边缘。
- 仅在已打开并启用插件的 Guest App 中显示，可逐 App 关闭；新安装的 Guest App 默认显示。LC 主界面显示开关单独控制，默认关闭。
- 「恢复默认设置」恢复当前外观默认值、默认 Guest App 显示范围并关闭 LC 主界面显示，同时清理废弃参数。

## 构建

在 macOS + Xcode 环境通过 GitHub Actions 的 **Build LCFloatingReturn dylib** 工作流构建并验证 `LCFloatingReturn.dylib`。下载 Actions artifact 后，在 LC+SS Tweaks 管理器中导入、重新签名，再分配给目标 Guest。

本仓库只保留该插件与其 Orbit 运行时构建所需文件，不再包含 LiveContainer 主应用源码。

## 使用

1. 将 `LCFloatingReturn.dylib` 导入 LC+SS 的 `LCFloatingReturn` tweak 文件夹并签名。
2. 在目标 Guest 设置中选择该 tweak 文件夹。
3. 启动 Guest 后，点击悬浮按钮返回 LC；长按打开外观设置。

设备端行为请在实际 LiveContainer / SideStore 环境验证。
