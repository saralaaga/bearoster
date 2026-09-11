# App 隐私问卷答案（App Privacy）

App Store Connect → App 隐私 → 按下面的答案逐项填写。

## 结论

**不收集数据（Data Not Collected）。**

填完后的最终状态：`Data Not Collected`。所有数据类型都应保持「未收集」。

## 依据（为什么可以这样填）

| 检查项 | 结果 |
|---|---|
| 网络请求代码（`URLSession` / `Network` framework） | 无 |
| 第三方 SDK | 无（`Package.swift` 只依赖 Apple 系统框架） |
| 分析 / 埋点 / 崩溃上报 | 无 |
| 账号或登录 | 无 |
| 数据传出设备 | 无，全部 on-device 处理 |
| 与第三方共享 | 无 |
| 追踪（tracking） | 无 |

命令复核：

```bash
grep -rn "URLSession\|import Network" Sources/
```

预期无输出。

## 逐项填写

| 问卷项 | 答案 |
|---|---|
| 是否收集数据？ | 否 |
| 是否用于追踪？ | 否 |
| 数据类型（联系方式、用户内容、标识符、使用数据、诊断…） | 全部不勾选 |
| 数据是否加密传输？ | 不适用（不收集） |
| 是否允许用户请求删除数据？ | 不适用（不收集）；App 内删除标签/记录即可 |

## 隐私清单文件

`Packaging/PrivacyInfo.xcprivacy` 已随包分发：

- `NSPrivacyTracking` = `false`
- `NSPrivacyCollectedDataTypes` = 空数组
- `NSPrivacyAccessedAPITypes` 只声明 `UserDefaults`，原因码 `CA92.1`

## 权限用途说明（Info.plist）

| 权限 | 用途字符串 |
|---|---|
| 通讯录 | `NSContactsUsageDescription` |
| 麦克风 | `NSMicrophoneUsageDescription` |
| 语音识别 | `NSSpeechRecognitionUsageDescription` |

三处都是英文文案，和商店描述一致。
