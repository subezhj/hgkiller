# hgkiller

红果短剧 iOS 观影布局增强插件，输出独立的 **hgkiller.dylib**。

首版以用户提供的红果短剧 **7.3.9 / 7.3.9.32** FLEX 导出为适配依据。
Bundle ID 为 com.phoenix.video，主程序为 Eggplant。源码不包含导出的截图、设备路径、账号或媒体数据。

## 功能

- 设置 → **hgkiller**：独立入口卡片位于「红果净化」上方，不修改原列表的数据源、行号或点击回调。
- 头像、收藏、评论、点赞、分享独立显示开关。
- 右侧控件大小 55%–100%，默认 80%；隐藏项自动收紧排列，保留至少 44pt 的点击目标。
- 悬浮液态玻璃底栏：使用系统公开 UIGlassEffect API；不可用时回退为系统磨砂材质。
- 保留宿主原有 Tab 控件及其点击动作，不创建平行的 Tab 控制器。
- 视频列表、Cell 与播放器容器延伸到底部；同步分页尺寸与页码，保留进度条。
- 高比例竖屏视频可裁切铺满，横屏及低比例竖屏保持比例。
- 顶部分类与搜索文字缩小，默认 85%，可调为 55%–100%。
- 总开关与恢复默认设置；所有偏好键使用 HGK.v1. 前缀。

## 构建与下载

GitHub Actions 自动运行几何测试、编译 arm64 iOS 动态库、进行 ad-hoc 签名并上传 artifact。
在仓库的 **Actions → Build hgkiller dylib → 成功的运行 → Artifacts** 下载 hgkiller-dylib 压缩包。

macOS 安装 Xcode 后运行：

    bash scripts/build.sh

输出：

    build/hgkiller.dylib
    build/SHA256SUMS.txt

最低部署版本为 iOS 14。源码通过运行时检测系统液态玻璃类，不要求本地 SDK 包含 iOS 26 头文件。
使用 Objective-C Runtime 的目标类方法拦截，无 CydiaSubstrate、Substitute 或 libhooker 依赖。
动态库仅在 com.phoenix.video 进程内启用。

注入工具需将 dylib 加载到宿主进程，并按其流程重新签名应用。构建产物的 ad-hoc 签名不等于任意设备上的安装授权。
本项目不修改宿主安装包、不提供应用 IPA。

## 当前验证范围

自动验证覆盖安全区底栏位置、视频比例、竖屏裁切、44pt 点击目标下限与扩展前后的页码对齐。
iOS 编译通过仅证明源码可编译和动态库可生成；**未完成真机注入、截图与交互验收**。

全屏扩展只作用于导出中首页的视频流，且要求使用纵向 UICollectionViewFlowLayout 或其子类。
未知布局保持宿主行为，不替换宿主的 collection view layout。
搜索详情、横屏窗口和画中画窗口不应用该布局方案。

与「红果净化」的入口和偏好设置独立；若另一插件也改同一控件的 frame、transform 或 hidden，
最终效果取决于双方 Hook 的执行顺序，仍需共同注入验收。关闭该插件中的重叠布局功能可减少争用。

## 真机验收

1. 设置页确认 hgkiller 在红果净化上方，两个入口都可打开。
2. 分别关闭右侧五个控件，确认重排、点击动作及重新开启正确。
3. 缩放拖至 55%、80%、100%，反复切换，确认无累计缩小。
4. Tab 的首页、剧场、我的切换正常，底栏不遮挡进度条的拖动。
5. 连续上下滑动视频，确认每页停靠准确；比较横屏和竖屏视频。
6. 关闭总开关和视频延伸开关，确认恢复布局。
7. 打开评论、选集、搜索，前后台切换及屏幕旋转，确认无错误铺满。

## 实现文件

- src/HGCore.m：宿主作用域、方法拦截、设置缓存与恢复。
- src/HGChrome.m：右侧控件、点击区域与顶部字体。
- src/HGLayout.m：视频几何、分页、HUD 锚点与悬浮底栏。
- src/HGSettings.m：独立设置入口和设置页。
- src/HGEntry.m：Bundle 过滤、主线程初始化和延迟类加载重试。
- src/HGGeometry.h：可独立测试的布局计算。

## 参考

架构与布局处理思路参考 [subezhj/DYKiller](https://github.com/subezhj/DYKiller)。
hgkiller 为针对红果类体系重新实现的工程，不依赖其抖音私有类。

系统材质 API：[Apple UIGlassEffect](https://developer.apple.com/documentation/uikit/uiglasseffect)。
