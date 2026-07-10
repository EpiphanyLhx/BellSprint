# BellSprint

BellSprint 是一款 macOS 菜单栏常驻应用，适用于固定课表排课需求的场景。它能在预设的时间点自动播放预备铃、上课铃、下课铃，帮助你精准管理每节课的时间。

## 技术栈

<p  align="center">

  <img src="https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/SwiftUI-000000?logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/macOS-14.0+-000000?logo=apple&logoColor=white" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/AVAudioEngine-007AFF?logo=apple&logoColor=white" alt="AVAudioEngine">
  <img src="https://img.shields.io/badge/CoreAudio-007AFF?logo=apple&logoColor=white" alt="CoreAudio">
  <img src="https://img.shields.io/badge/SPM-FA7343?logo=swift&logoColor=white" alt="Swift Package Manager">
  <img src="https://img.shields.io/badge/UserDefaults-999999?logo=apple&logoColor=white" alt="UserDefaults">
  <img src="https://img.shields.io/badge/SMAppService-666666?logo=apple&logoColor=white" alt="SMAppService">
</p>

## 功能特性

- **菜单栏常驻** — 驻留在 macOS 菜单栏中，不占用 Dock 空间，实时显示启用/禁用状态
- **按天配置课表** — 周一至周日每天独立配置，支持每天启用/禁用
- **一键生成课表** — 根据开始时间、结束时间、课程时长、课间休息自动生成全天课程
- **手动排课** — 支持逐节添加/删除课程，单独调整每节课的时间
- **午休 & 晚饭休息** — 支持配置午休和晚饭时间段，自动跳过休息时间
- **级联时间调整** — 修改某节课的时间后，后续课程会自动顺延
- **时间冲突检测** — 课程时间重叠时界面会显示红色警告
- **三种铃声** — 预备铃、上课铃、下课铃分别独立配置
- **自定义铃声** — 支持用户选择自定义 .wav / .mp3 / .m4a / .aiff 音频文件
- **音量控制** — 0%–100% 自由调节
- **音频输出设备选择** — 支持选择特定的音频输出设备
- **配置同步** — 支持将某天的配置一键同步到其他天
- **开机自启动** — 通过 macOS 原生登录项实现

## 系统要求

- macOS 14.0 (Sonoma) 及以上
- Xcode 15+ 或 Xcode Command Line Tools（仅构建时需要）

## 构建与运行

### 方式一：外层构建脚本

```bash
cd /Users/LHX/Desktop/时钟
./build_and_run.sh
```

该脚本会执行 Release 编译 → 复制到 .app bundle → 启动应用。

### 方式二：项目内构建脚本

```bash
cd /Users/LHX/Desktop/时钟/ClassBell
./build.sh
```

### 方式三：SPM 命令行

```bash
cd /Users/LHX/Desktop/时钟/ClassBell
swift build -c release
# 直接运行
.build/arm64-apple-macosx/release/ClassBell
```

## 项目结构

```
ClassBell/
├── Package.swift                  # Swift Package Manager 配置
├── build.sh                       # 构建脚本
├── Sources/
│   ├── ClassBell/                 # 主应用源码
│   │   ├── ClassBellApp.swift     # @main 入口，MenuBarExtra + 设置窗口
│   │   ├── AppState.swift         # 核心状态管理（定时轮询、铃声触发）
│   │   ├── Info.plist
│   │   ├── Models/
│   │   │   └── Models.swift       # 数据模型（DayConfig, CourseConfig, BellEvent 等）
│   │   ├── Services/
│   │   │   ├── BellScheduler.swift    # 铃声事件生成器
│   │   │   └── AudioService.swift     # 音频播放服务（AVAudioEngine）
│   │   ├── Views/
│   │   │   ├── ContentView.swift      # 主设置窗口
│   │   │   ├── MenuBarView.swift      # 菜单栏弹出面板
│   │   │   ├── DayConfigView.swift    # 单天课程配置编辑器
│   │   │   ├── SoundSettingsView.swift # 声音设置面板
│   │   │   └── TimeFieldFormatter.swift # 时间输入校验
│   │   └── Resources/             # 内置铃声资源
│   │       ├── pre_bell.wav       # 预备铃
│   │       ├── start_bell.wav     # 上课铃
│   │       └── end_bell.wav       # 下课铃
│   └── ClassBell-macOS/           # macOS 特定代码
└── .build/                        # SPM 构建产物
```

## 使用说明

1. 启动应用后，菜单栏会出现铃铛图标
2. 点击铃铛图标可查看当前时间、下一个铃声事件和今日课程
3. 点击「设置」打开配置窗口，按天配置课表
4. 在声音设置中可调节音量、选择输出设备、更换铃声
5. 配置完成后点击菜单栏的「启用」开关即可开始自动打铃
