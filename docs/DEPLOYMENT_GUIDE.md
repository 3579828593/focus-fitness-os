# Focus Fitness OS — 云端部署指南

## 零本地安装方案

本方案让你**无需在本地安装 Flutter SDK、Docker、Node.js**，全部通过云端完成构建和部署。

---

## 一、自动构建 APK（GitHub Actions）

### 工作原理
- 推送 `v*` 格式的 tag（如 `v1.0.0`）→ 自动触发 APK 构建
- GitHub Actions 云端安装 Flutter SDK → 编译 → 生成 APK
- APK 自动上传为 GitHub Release 附件，可直接下载安装

### 触发构建
```bash
# 方式1: 推送 tag 触发自动构建
git tag v1.0.0
git push origin v1.0.0

# 方式2: 在 GitHub 仓库页面手动触发
# Actions → Build Android APK → Run workflow
```

### 下载 APK
1. 打开 https://github.com/3579828593/focus-fitness-os/releases
2. 下载最新 Release 中的 `focus-fitness-os-v1.0.0.apk`
3. 传输到 Android 手机安装

### 查看 CI 状态
- https://github.com/3579828593/focus-fitness-os/actions
- 构建日志、测试结果、覆盖率报告全部可在线查看

---

## 二、Node-RED 后端部署（Railway.app）

### 工作原理
- Railway.app 连接 GitHub 仓库，每次 push 自动部署
- 使用项目中的 Dockerfile 构建容器镜像
- 提供 HTTPS 公网访问地址，无需本地 Docker

### 部署步骤
1. 打开 https://railway.app
2. 使用 GitHub 账号登录
3. 点击 "New Project" → "Deploy from GitHub repo"
4. 选择 `focus-fitness-os` 仓库
5. Railway 自动检测 `railway.json` 配置
6. 自动构建 Docker 镜像并部署
7. 部署完成后获得公网 URL（如 `https://focus-fitness-os.up.railway.app`）

### 配置环境变量
在 Railway 项目设置中添加：
```
NODE_RED_SECRET=your-secret-key
JWT_SECRET=your-jwt-secret
ADMIN_PASSWORD_HASH=your-bcrypt-hash
API_PASSWORD_HASH=your-bcrypt-hash
TZ=Asia/Shanghai
```

### 自动更新
每次 push 到 `master` 分支 → Railway 自动重新部署，零停机更新。

---

## 三、Node-RED 测试（GitHub Actions CI）

### 工作原理
- 每次 push 自动运行 29 个 Node-RED function 测试
- 测试通过后才会触发 Docker 构建
- 无需本地安装 Node.js

### CI/CD 完整管道
```
push → Flutter Analyze & Test → Node-RED Validation & Test → Docker Build
                                                                ↓
                                                    tag v* → Build APK → GitHub Release
                                                                ↓
                                                    Railway → 自动部署后端
```

---

## 四、对比：旧方案 vs 新方案

| 操作 | 旧方案（本地） | 新方案（云端） |
|------|----------------|----------------|
| 构建 APK | 安装 Flutter SDK (~2GB) + 构建 10分钟 | 推送 tag，GitHub Actions 自动构建 |
| 运行后端 | 启动 Docker Desktop + docker-compose | Railway 自动部署，7×24 在线 |
| 运行测试 | 本地 npm install + npm test | GitHub Actions CI 自动运行 |
| 获取 APK | 在 build/ 目录找文件 | GitHub Releases 页面直接下载 |
| 后端地址 | localhost:1880 | Railway 提供公网 HTTPS URL |

---

## 五、快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/3579828593/focus-fitness-os.git
cd focus-fitness-os

# 2. 触发 APK 构建（推送 tag）
git tag v1.0.0
git push origin v1.0.0

# 3. 等待构建完成（约10-15分钟）
#    在 Actions 页面查看进度

# 4. 下载 APK
#    在 Releases 页面下载

# 5. 部署后端到 Railway
#    访问 railway.app → 连接 GitHub 仓库 → 自动部署
```

---

## 六、费用

| 服务 | 免费额度 | 说明 |
|------|----------|------|
| GitHub Actions | 2000 分钟/月 | 私有仓库免费，公开仓库无限 |
| Railway.app | $5 试用额度 | 之后 $5/月 含 500GB 流量 |
| GitHub Releases | 免费 | 每个文件最大 2GB |

**完全免费的替代方案**（后端部署）：
- Render.com：免费 Web Service（750 小时/月，会休眠）
- Fly.io：免费 3 个共享 CPU VM
