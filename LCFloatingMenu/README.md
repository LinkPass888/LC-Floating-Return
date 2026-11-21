# LCFloatingReturn

当前版本 **0.1.0**，是精简返回按钮版。点击悬浮按钮返回 LiveContainer 首页，长按约 0.55 秒打开设置，拖动可重新定位并吸附屏幕边缘。默认只在运行中的 Guest App 显示；设置页的「在 LC 主界面显示」开关默认关闭，可按需开启。

设置页可逐个选择允许显示按钮的 Guest App。未设置时默认对所有已安装 Guest App 显示。点击「恢复默认设置」恢复外观、位置及显示范围默认值，并清除已废弃的历史参数。

不包含历史版本的抽屉、Guest 应用切换、多任务管理、插件中心、更新器或诊断日志界面。

## 安装

从 GitHub Actions 的 `Build LCFloatingReturn dylib` 工作流下载 `LCFloatingReturn-dylib` artifact。发行文件名为 `LCFloatingReturn.dylib`。在 LC+SS Tweaks 管理器中导入该 dylib、重新签名，然后将该 tweak 文件夹分配给目标 Guest。

## 构建

需要 macOS 与 Xcode：

```sh
LCOrbit/Build/build.sh dist/LCFloatingReturn.dylib
LCOrbit/Tests/verify.sh dist/LCFloatingReturn.dylib
```

实际设备上的返回行为、设置窗口和签名加载需要在 LiveContainer / SideStore 环境验证。
