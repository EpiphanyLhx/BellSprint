# BellSprint for Windows

Windows 10/11 x64 托盘版上下课铃声工具，与 macOS 版保持完整功能对齐。

## 功能

- Windows 系统托盘常驻，双击打开设置
- 显示下一个铃声、当前课程和今日课程
- 周一至周日独立课表和启用状态
- 自动生成课表，支持午休和晚饭休息
- 手动添加、删除、命名和调整每节课
- 修改结束时间、课程时长或课间后级联顺延
- 课程冲突检测
- 预备铃、上课铃、下课铃
- 自定义 WAV / MP3 / M4A / AIFF
- 音量和音频输出设备选择
- 同步全部、时间安排或课程安排到其他天
- 开机自启动

## 本地构建

需要 Windows 10/11 和 .NET 8 SDK：

```powershell
dotnet test BellSprint.Core.Tests/BellSprint.Core.Tests.csproj -c Release
dotnet publish BellSprint.Windows/BellSprint.Windows.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

GitHub Actions 会自动生成 `BellSprint-Windows-x64.zip`。
