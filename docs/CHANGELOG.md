# Changelog

## [1.0.0] - 2026-07-08

### Added
- Flutter 端: Drift ORM (V2 Schema, 9 业务表 + OpLogs)
- Flutter 端: Riverpod NotifierProvider 状态管理
- Flutter 端: Repository 层 (SessionRepository + WorkoutRepository)
- Flutter 端: 双执行器 (FocusRunner + WorkoutRunner) 状态机
- Flutter 端: TTS 集成 (TtsQueue + FlutterTts)
- Flutter 端: HTTP 重试机制 (指数退避)
- Flutter 端: OpLogSyncEngine (单向上行同步)
- Flutter 端: SyncEngine (双向同步 + LWW 冲突解决)
- Flutter 端: JWT 认证 (AuthService + Refresh Token)
- Flutter 端: ErrorTrackingService (Sentry 骨架)
- Flutter 端: MetricsCollector (Prometheus 格式指标)
- Node-RED: 9 个 Flow (提醒/超负荷/冲突/周报/提案/查询/健康/指标/认证)
- Node-RED: 4 个 function 模块 (超负荷/完成率/冲突/报告)
- 基础设施: Docker + docker-compose (prod/monitoring/tls)
- 基础设施: Nginx TLS 反向代理
- 基础设施: Prometheus + Grafana + Loki 可观测性栈
- CI/CD: GitHub Actions 3-job pipeline (test/validate/build)
- CI/CD: 覆盖率门禁 >= 60%
- 测试: 14+ 测试文件 (单元/Widget/E2E/Golden/Repository/Notifier)

### Fixed
- API 路径 404 (/sessions/$id/complete → /sessions/complete)
- TTS 未集成到 Runner 回调
- 会话状态未持久化到 DB
- HTTP 无重试机制
- Node-RED Flow JSON 分散未合并
- 路由不一致 (main.dart vs test_helpers)
- Notifier 绕过 Repository 层
- 降级结果丢弃未写 OpLog
- todayScheduleProvider 类型不安全

### Security
- JWT + Refresh Token 认证替代静态 token
- TLS 加密 (Nginx 反向代理)
- 安全 headers (HSTS, X-Frame-Options, etc.)
- Node-RED 编辑器仅本地访问
- credentialSecret 环境变量化
