// vitest.config.ts
// Vitest 配置 — 使用 @cloudflare/vitest-pool-workers 在 Workers 运行时 (Miniflare) 中执行测试。
// 这样 Web Crypto API (crypto.subtle / btoa / atob / getRandomValues) 原生可用。

import { defineWorkersConfig } from '@cloudflare/vitest-pool-workers/config';

export default defineWorkersConfig({
  test: {
    // 测试文件匹配
    include: ['test/**/*.test.ts'],
    // 使用 Workers pool
    poolOptions: {
      workers: {
        // 指向 wrangler.toml 以加载 D1 绑定等环境配置
        wrangler: { configPath: './wrangler.toml' },
        // 单次运行不 watch
        miniflare: {
          // 提供测试所需的环境变量 (与 Env 接口对齐)
          bindings: {
            JWT_SECRET: 'test-jwt-secret',
            CORS_ALLOWED_ORIGINS: 'https://example.com,https://3579828593.github.io',
          },
        },
      },
    },
    // 输出报告
    reporters: ['default'],
  },
});
