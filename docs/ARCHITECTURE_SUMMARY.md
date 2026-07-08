# Focus Fitness OS 架构总结

## 项目概览
备考 × 健身 × 规则编排全栈应用, Flutter + Node-RED + Docker 架构

## 技术栈
- 前端: Flutter 3.5+ / Dart / Riverpod 2.5 / Drift ORM / GoRouter
- 后端: Node-RED 4.0 / Node.js 18
- 数据: SQLite (本地) / PowerSync (双向同步)
- 基础设施: Docker / Nginx (TLS) / Prometheus / Grafana / Loki / Sentry
- CI/CD: GitHub Actions

## 架构层次 (Flutter)
1. UI Layer (screens/) — HookConsumerWidget, 纯展示
2. State Layer (providers/) — NotifierProvider, 状态管理
3. Repository Layer (repositories/) — 数据仓库, 整合 DAO + API + OpLog
4. Service Layer (services/) — API/同步/TTS/认证/错误追踪/指标
5. Data Layer (data/) — Drift ORM, 9 业务表 + OpLogs, V2 Schema
6. Runner Layer (runners/) — FocusRunner + WorkoutRunner 状态机

## 架构层次 (Node-RED)
9 个 Flow: 每日提醒/渐进超负荷/冲突检测/周报/提案管理/周报查询/健康检查/指标采集/JWT认证

## 数据流
训练完成 → WorkoutSessionNotifier → SessionRepository → NodeRedApi → Flow2 → 渐进超负荷 → 提案
         → (失败) → LocalFallbackRules + OpLog → SyncEngine → 后续同步

## SOLO-OS PRAR 开发历程
9 个周期, 从架构设计到安全收尾的完整闭环
