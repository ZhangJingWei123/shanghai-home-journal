# 沪居 HuJu

沪居是一款面向上海首次购房者的 iOS 看房决策日志。它不复制房源平台，
而是把预算、板块调研、现场证据、AI 复盘和购房流程放进同一个私人工作台。

## 界面

<p>
  <img src="docs/screenshots/home.png" width="30%" alt="沪居首页">
  <img src="docs/screenshots/map.png" width="30%" alt="上海看房足迹地图">
  <img src="docs/screenshots/ai.png" width="30%" alt="AI 决策助手">
</p>

## 当前原型

- 上海地图看房足迹，按候选、复看、已看和排除显示状态。
- 结构化看房日志，记录总价、面积、通勤、加分项、风险和现场判断。
- 可解释 AI 决策助手，展示匹配原因与仍待核验的证据。
- 预算压力模型，估算首付、税费预留、月供和现金缺口。
- 从资格确认到交割的购房清单。
- 本地 Codable 持久化，不上传地址、收入或个人笔记。

## 产品边界

首版 AI 是实现 `AIAdvising` 协议的本地决策引擎。它用于整理用户证据，
不提供官方估价、贷款、税务、产权或学区结论。未来接入远端或端侧模型时，
必须先增加明确授权、隐私说明、数据最小化与结果溯源。

市场和竞品分析见 [docs/market-analysis.md](docs/market-analysis.md)。

## 运行

环境要求：

- macOS
- Xcode 16+
- iOS 17+ Simulator

```bash
open HuJu.xcodeproj
```

或命令行构建：

```bash
xcodebuild \
  -project HuJu.xcodeproj \
  -scheme HuJu \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Skills

AgentBuddy 已将 `ios-swift` 1.0.1 项目级安装到 `.trae/skills/ios-swift`。
本仓库还包含 `.trae/skills/shanghai-home-journal-ios`，用于约束后续产品、
AI、SwiftUI、MapKit、隐私与验收工作。

```bash
PATH="/opt/homebrew/bin:$PATH" \
npm_config_registry="https://bnpm.byted.org" \
npx agentbuddy@latest install
```

## Roadmap

1. 相机、语音与 OCR 快速录入现场证据。
2. 通勤锚点与多时段路线对比。
3. 经用户授权的房源链接导入和价格变更追踪。
4. 当前政策快照与来源更新时间提示。
5. 产权、贷款和签约材料的隐私保险箱。
6. CloudKit 私有数据库跨设备同步。
