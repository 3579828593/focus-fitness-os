# Focus Fitness OS 发布清单

## 版本: v1.0.0
## 日期: 2026-07-08

---

## 一、代码质量门禁

- [ ] `flutter analyze --fatal-warnings` 零警告
- [ ] `dart run build_runner build --delete-conflicting-outputs` 成功
- [ ] `flutter test --coverage` 全部通过
- [ ] 代码覆盖率 >= 60%
- [ ] `npm test` (Node-RED function 测试) 全部通过
- [ ] flows.json JSON 校验通过
- [ ] 无 TODO/FIXME 标记在核心代码中

## 二、功能验收 — Flutter 端

### 首页
- [ ] 首页正确显示今日日期 (zh_CN locale)
- [ ] 今日日程数量正确显示
- [ ] 快速导航卡片可点击跳转
- [ ] 目标进度条正确渲染

### 专注计时
- [ ] FocusSessionNotifier 正确初始化 (从 DB 读取 focusMinutes/breakMinutes)
- [ ] 计时器开始/暂停/恢复功能正常
- [ ] TTS 播报"休息时间"正确触发
- [ ] 会话状态持久化到 DB (CREATED→RUNNING→COMPLETED)
- [ ] 进度条正确显示当前轮次
- [ ] 放弃会话后状态为 ABANDONED

### 健身训练
- [ ] WorkoutSessionNotifier 正确初始化 (从 DB 读取动作数据)
- [ ] 组录入 (次数/重量/RPE) 功能正常
- [ ] 休息倒计时正确, 最后3秒 TTS 倒数
- [ ] 动作切换确认 (半自动推进)
- [ ] 训练完成后片段保存到 DB
- [ ] 上报 NodeRedApi 失败时降级到 LocalFallbackRules
- [ ] 降级结果写入 OpLog
- [ ] 训练总结正确显示 (完成组数/总训练量/完成率)

### 提案确认
- [ ] 正确获取 LOCKED 状态提案列表
- [ ] 接受提案后 OpLog 记录
- [ ] 拒绝提案后 OpLog 记录
- [ ] Node-RED 不可达时显示离线视图

### 数据同步
- [ ] OpLogSyncEngine 定时扫描未同步记录
- [ ] SyncEngine 双向同步 (push + pull)
- [ ] 冲突解决 (LWW + Lamport Clock) 正确
- [ ] 离线操作时 OpLog 持续累积

## 三、功能验收 — Node-RED 后端

### Flow1: 每日提醒
- [ ] 定时触发 (cron)
- [ ] 推送通知到配置的渠道

### Flow2: 完成递增
- [ ] 接收训练完成上报
- [ ] progressive_overload 算法正确计算
- [ ] 生成 LOCKED 提案

### Flow3: 周报复盘
- [ ] 每周触发
- [ ] 汇总数据正确

### Flow4: 冲突检测
- [ ] 检测时间冲突
- [ ] 生成重排提案

### Flow5: 提案管理
- [ ] 接受/拒绝 API 正确响应
- [ ] 状态流转 LOCKED → ACCEPTED/REJECTED

### Flow6: 周报查询
- [ ] /api/v1/stats/weekly 返回正确数据

### Flow7: 健康检查
- [ ] /health 返回 200
- [ ] /ready 返回 200

### Flow8: 指标采集
- [ ] /metrics 返回 Prometheus 格式
- [ ] 计数器/直方图正确更新

### Flow9: JWT 认证
- [ ] /api/v1/auth/login 返回 JWT + Refresh Token
- [ ] /api/v1/auth/refresh 返回新 JWT
- [ ] 无效 JWT 返回 401

## 四、基础设施验收

### Docker
- [ ] `docker build` 成功
- [ ] docker-compose.prod.yml 启动成功
- [ ] 容器健康检查通过
- [ ] 资源限制生效 (512M/1CPU nodered, 1G/2CPU wger)

### TLS
- [ ] 自签名证书生成成功
- [ ] HTTPS 端口 443 可访问
- [ ] HTTP → HTTPS 重定向生效
- [ ] HSTS header 存在
- [ ] 安全 headers (X-Frame-Options, X-Content-Type-Options 等) 存在

### 可观测性
- [ ] Prometheus 抓取 /metrics 成功
- [ ] Grafana 面板渲染正常
- [ ] Loki 日志聚合正常
- [ ] Sentry 错误追踪接入 (生产环境)

### CI/CD
- [ ] flutter-test job 通过
- [ ] nodered-validate job 通过
- [ ] docker-build job 通过 (main 分支)
- [ ] 覆盖率门禁 >= 60% 生效

## 五、安全验收

- [ ] JWT 认证替代静态 token
- [ ] Refresh Token 轮换机制
- [ ] API 端点需认证 (除 /health, /metrics, /api/v1/auth/*)
- [ ] Node-RED 编辑器仅本地访问 (127.0.0.1)
- [ ] credentialSecret 通过环境变量设置
- [ ] .env 不在版本控制中
- [ ] 敏感数据 (密码/令牌) 不硬编码

## 六、发布步骤

1. [ ] 创建 release branch (release/v1.0.0)
2. [ ] 更新 pubspec.yaml version
3. [ ] 更新 package.json version
4. [ ] 运行全部门禁检查
5. [ ] 生成 changelog
6. [ ] 创建 Git tag (v1.0.0)
7. [ ] 合并到 main 分支
8. [ ] CI/CD 自动触发 Docker 镜像构建
9. [ ] 部署到生产环境
10. [ ] 验证生产环境健康检查
11. [ ] 通知用户发布完成
