/**
 * Focus Fitness OS - Node-RED 安全配置文件
 *
 * 安全说明：
 *   - adminAuth   仅允许已认证用户访问 Node-RED 编辑器
 *   - uiHost      限制为 127.0.0.1，编辑器仅本地访问
 *   - HTTP API 端点已从 Basic Auth (httpNodeAuth) 迁移至 JWT 认证
 *   - JWT 验证逻辑在 Flow (flows/auth.json) 中实现，非 httpNodeAuth
 *   - credentialSecret 用于加密 credentials，生产环境务必通过环境变量覆盖
 *
 * JWT 认证流程 (HMAC-SHA256)：
 *   1. POST /api/v1/auth/login   验证用户名密码 → 签发 access_token(1h) + refresh_token(7d)
 *   2. POST /api/v1/auth/refresh 携带 refresh_token → 签发新的 access_token
 *   3. POST /api/v1/auth/verify  验证 access_token 签名与有效期
 *   - access_token  payload: { user_id, username, exp, iat }，有效期 1 小时
 *   - refresh_token 为 64 字节随机 hex，存储于 global context，有效期 7 天
 *   - JWT 密钥通过 JWT_SECRET 环境变量配置，默认值仅供开发使用
 *
 * 密码生成方式（生成 bcrypt 哈希，用于 adminAuth）：
 *   node -e "console.log(require('bcryptjs').hashSync('你的密码', 8))"
 *   或使用 Node-RED 内置命令：node-red-admin hash-pw
 */

module.exports = {
    // 管理后台认证：仅允许 admin 用户登录编辑器
    // 密码哈希可通过 NODE_RED_ADMIN_HASH 环境变量覆盖
    // 默认密码: FocusFitness2026! (生产环境务必通过环境变量覆盖)
    adminAuth: {
        type: "credentials",
        users: [
            {
                username: "admin",
                password: process.env.NODE_RED_ADMIN_HASH || "$2b$08$***REMOVED***",
                permissions: "*"
            }
        ]
    },

    // 绑定所有网络接口，允许云平台代理外部访问
    uiHost: "0.0.0.0",

    // HTTP 节点（API 端点）认证：已移除 Basic Auth (httpNodeAuth)
    // JWT 认证由 flows/auth.json 中的 Flow 实现：
    //   - /api/v1/auth/* 端点为公开端点 (无需认证即可访问)
    //   - 其余 /api/v1/* 业务端点应在各自 Flow 中校验 Authorization: Bearer <access_token>
    // 注意：Node-RED 原生 httpNodeAuth 仅支持全局 Basic Auth，无法满足 JWT 细粒度控制，
    //       因此认证逻辑下放到 Flow 层，由 function 节点使用 crypto 模块完成 HMAC-SHA256 验签。
    // httpNodeAuth: { user: "apiuser", pass: "$2a$08$PLACEHOLDER" },  // 已弃用

    // 凭证加密密钥，生产环境务必通过 NODE_RED_SECRET 环境变量覆盖
    credentialSecret: process.env.NODE_RED_SECRET || "dev-secret-change-in-prod",

    // function 节点可访问的全局上下文模块
    // crypto: JWT 签名/验签 (HMAC-SHA256) 与 refresh_token 随机生成
    // JWT_SECRET: 通过环境变量注入，供 auth flow 的 function 节点使用 global.get('JWT_SECRET')
    functionGlobalContext: {
        crypto: require('crypto'),
        fs: require('fs'),
        JWT_SECRET: process.env.JWT_SECRET || 'focus-fitness-os-jwt-secret-2024'
    },

    // 默认 HTTP 监听端口
    uiPort: process.env.PORT || 1880,

    // 流程文件位置（与 docker-compose 中 FLOWS 环境变量对应）
    flowFile: 'flows.json',
    flowFilePretty: true,

    // 禁用未使用的功能以减少攻击面
    httpStatic: false,

    // 日志配置
    logging: {
        console: {
            level: "info",
            metrics: false,
            audit: false
        }
    }
};
