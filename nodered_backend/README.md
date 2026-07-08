# Focus Fitness OS — Node-RED 后端

Focus Fitness OS 的 Node-RED 编排后端，负责番茄钟会话管理、健身训练记录、日程冲突调度、周报生成与多渠道通知推送。

---

## 目录结构

```
nodered_backend/
├── docker-compose.yml        # Docker Compose 编排（nodered + wger）
├── settings.js               # Node-RED 安全配置
├── package.json              # 项目依赖与启动脚本
├── flows/
│   └── flows.json            # Flow 入口文件（空数组，待导入）
├── functions/
│   ├── progressive_overload.js   # 渐进超负荷算法
│   ├── completion_rate.js        # 完成率与训练量统计
│   ├── conflict_resolver.js      # 日程冲突检测与顺延
│   └── report_template.js        # 周报模板填充
├── data/                     # Node-RED 运行数据（自动生成）
└── README.md                 # 本文档
```

---

## 快速开始

### 前置要求

- Docker Engine >= 20.10
- Docker Compose v2

### 安装步骤

```bash
# 1. 进入后端目录
cd focus_fitness_os/nodered_backend

# 2. （可选）安装本地依赖（仅在不使用 Docker 时需要）
npm install

# 3. 通过 Docker Compose 启动全部服务
docker-compose up -d

# 4. 查看运行状态
docker-compose ps

# 5. 查看日志
docker-compose logs -f nodered
```

### 停止与清理

```bash
# 停止服务（保留数据）
docker-compose down

# 停止并删除数据卷（谨慎操作）
docker-compose down -v
```

---

## 默认端口

| 服务      | 端口  | 说明                          |
| --------- | ----- | ----------------------------- |
| Node-RED  | 1880  | 流程编辑器与 HTTP API 端点    |
| wger      | 8000  | wger 健身管理 API（可选服务） |

Node-RED 编辑器访问地址：`http://127.0.0.1:1880`

> 注意：`settings.js` 中 `uiHost` 设为 `127.0.0.1`，编辑器仅允许本地访问。如需远程访问，请通过反向代理（如 Nginx）并配置 TLS。

---

## 安全配置说明

`settings.js` 包含以下安全机制，**生产部署前必须修改**：

### 1. 管理后台认证（adminAuth）

- 类型：`credentials`
- 默认用户：`admin`
- 密码：bcrypt 哈希占位符 `$2a$08$PLACEHOLDER_REPLACE_ME`

生成真实密码哈希：

```bash
# 方式一：使用 node-red-admin
npx node-red-admin hash-pw

# 方式二：使用 bcryptjs
node -e "console.log(require('bcryptjs').hashSync('你的密码', 8))"
```

将输出的哈希字符串替换 `settings.js` 中的 `password` 字段。

### 2. HTTP 节点认证（httpNodeAuth）

- 用户名：`apiuser`
- 密码：bcrypt 哈希占位符 `$2a$08$PLACEHOLDER`

所有 HTTP In/Out 节点暴露的 API 端点均需 Basic Auth 认证。

### 3. 凭证加密密钥（credentialSecret）

- 默认值：`dev-secret-change-in-prod`（仅开发环境）
- 生产环境通过环境变量覆盖：

```bash
export NODE_RED_SECRET="你的强随机密钥"
```

### 4. 编辑器绑定（uiHost）

设为 `127.0.0.1`，确保编辑器不对外网直接暴露。

---

## Flow 简介

本后端规划以下 4 条核心 Flow（需导入 `flows/flows.json`）：

### Flow 1：番茄钟会话 Flow

- **触发**：cron-plus 定时 / Telegram 命令
- **功能**：管理专注会话生命周期（START → PAUSE → RESUME → COMPLETE），记录实际专注时长，会话结束后写入数据库并推送通知。
- **关键节点**：cron-plus、function、sqlite、pushover

### Flow 2：健身训练记录 Flow

- **触发**：HTTP API / wger 同步
- **功能**：接收训练片段（segments），调用 `progressive_overload.js` 计算下次训练建议重量，调用 `completion_rate.js` 统计完成率与训练量，生成 PROPOSAL 锁定提案。
- **关键节点**：HTTP In、function、sqlite、wger

### Flow 3：日程冲突调度 Flow

- **触发**：Google Calendar 事件变更 / HTTP API
- **功能**：检测新日程与已有日程的时段冲突，按优先级排序，低优先级项自动顺延，生成冲突解决方案提案。
- **关键节点**：google-calendar、function（conflict_resolver）、HTTP Out

### Flow 4：周报复盘 Flow

- **触发**：cron-plus 每周日定时
- **功能**：汇总本周专注与训练数据，调用 `report_template.js` 生成格式化周报文本，通过 Telegram / Email / Pushover 多渠道推送。
- **关键节点**：cron-plus、function、telegrambot、email、pushover

---

## 函数节点说明

| 文件                       | 输入                                          | 输出                                   | 用途                         |
| -------------------------- | --------------------------------------------- | -------------------------------------- | ---------------------------- |
| `progressive_overload.js`  | session, exercise, segments                   | newWeight, reason, isPR, proposal      | 渐进超负荷重量调整与 PR 检测 |
| `completion_rate.js`       | segments, planned_sets                        | completion_rate, total_volume          | 完成率与训练量统计           |
| `conflict_resolver.js`     | new_entry, existing_entries                   | conflicts, proposals, resolved         | 日程冲突检测与自动顺延       |
| `report_template.js`       | weekly_sessions, goals                        | report（格式化文本）                   | 周报内容生成                 |

所有函数节点代码位于 `functions/` 目录，可复制到 Node-RED function 节点中使用。

---

## 社区节点列表

`package.json` 中声明的 Node-RED 社区节点：

| 节点                                  | 用途                                        |
| ------------------------------------- | ------------------------------------------- |
| `node-red-contrib-cron-plus`          | 高级定时调度，支持 cron 表达式与动态触发    |
| `node-red-contrib-telegrambot`        | Telegram Bot 收发消息，命令交互与通知推送   |
| `node-red-contrib-wger`               | wger 健身管理平台 API 集成                  |
| `node-red-node-sqlite`                | SQLite 数据库读写，本地持久化               |
| `node-red-node-email`                 | 邮件发送，周报与告警通知                    |
| `node-red-node-pushover`              | Pushover 推送通知                           |
| `@marek-knappe/node-red-google-calendar` | Google Calendar 日历事件读取与同步         |

---

## 本地开发（非 Docker）

```bash
# 安装依赖
npm install

# 全局安装 Node-RED（若未安装）
npm install -g node-red

# 启动 Node-RED（使用当前目录与自定义 settings）
npm start
# 等价于：node-red -u . -s settings.js
```

---

## 常见问题

### Q: 编辑器无法远程访问？

`settings.js` 中 `uiHost` 默认为 `127.0.0.1`。如需远程访问，建议配置 Nginx 反向代理：

```nginx
server {
    listen 443 ssl;
    server_name nodered.example.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:1880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

### Q: 忘记 admin 密码？

编辑 `settings.js`，将 `adminAuth.users[0].password` 替换为新密码的 bcrypt 哈希，重启服务。

### Q: wger 服务如何启用？

`docker-compose.yml` 中 wger 服务为可选，默认随 `docker-compose up` 启动。如不需要，可注释 wger 服务段落或使用 profile 控制。

### Q: 如何导入预置 Flow？

将 `flows/flows.json` 内容通过 Node-RED 编辑器菜单 → Import → 剪贴板粘贴导入，或直接将文件挂载到容器 `/flows/flows.json`。

---

## 许可证

MIT
