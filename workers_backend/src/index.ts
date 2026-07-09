// src/index.ts
// Worker 入口 — 注册所有路由, 处理 CORS 预检, 应用 JWT 鉴权与统一错误处理。
//
// 路由表 (与 Node-RED 端点契约一致):
//   POST /api/v1/auth/login              (无鉴权)
//   POST /api/v1/auth/refresh            (Refresh Token, 无 JWT)
//   POST /api/v1/auth/verify             (Access Token, 无 JWT 中间件)
//   POST /api/v1/sessions/complete       (JWT)
//   POST /api/v1/schedule/change         (JWT)
//   GET  /api/v1/proposals               (JWT)
//   POST /api/v1/proposals/:id/accept    (JWT)
//   POST /api/v1/proposals/:id/reject    (JWT)
//   GET  /api/v1/stats/weekly            (JWT)
//   GET  /health                         (无鉴权)
//   GET  /ready                          (无鉴权)
//   GET  /metrics                        (无鉴权)
//   OPTIONS /api/v1/*                    (CORS 预检)

import { Router } from './router';
import { corsMiddleware, getCorsHeaders } from './middleware/cors';
import { withAuth } from './middleware/auth';
import { jsonError, applyCorsHeaders } from './middleware/error';
import { authLogin, authRefresh, authVerify } from './handlers/auth';
import { sessionsComplete } from './handlers/sessions';
import { scheduleChange } from './handlers/schedule';
import { proposalsList, proposalAccept, proposalReject } from './handlers/proposals';
import { weeklyStats } from './handlers/stats';
import { healthCheck, readyCheck, metricsHandler } from './handlers/health';
import type { Env } from './types';

/** 构建路由器并注册全部路由 */
function buildRouter(): Router {
  const router = new Router();
  // 认证端点 (无 JWT 中间件, login/refresh/verify 自行处理令牌)
  router.add('POST', '/api/v1/auth/login', authLogin);
  router.add('POST', '/api/v1/auth/refresh', authRefresh);
  router.add('POST', '/api/v1/auth/verify', authVerify);
  // 受保护业务端点 (withAuth 包装)
  router.add('POST', '/api/v1/sessions/complete', withAuth(sessionsComplete));
  router.add('POST', '/api/v1/schedule/change', withAuth(scheduleChange));
  router.add('GET', '/api/v1/proposals', withAuth(proposalsList));
  router.add('POST', '/api/v1/proposals/:id/accept', withAuth(proposalAccept));
  router.add('POST', '/api/v1/proposals/:id/reject', withAuth(proposalReject));
  router.add('GET', '/api/v1/stats/weekly', withAuth(weeklyStats));
  // 基础设施端点 (无鉴权)
  router.add('GET', '/health', healthCheck);
  router.add('GET', '/ready', readyCheck);
  router.add('GET', '/metrics', metricsHandler);
  return router;
}

export default {
  /**
   * HTTP 请求入口。
   */
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // CORS 预检: 对所有 OPTIONS 请求返回 204
    if (req.method === 'OPTIONS') {
      return corsMiddleware(req, env);
    }

    const corsHeaders = getCorsHeaders(req, env);
    const router = buildRouter();
    const url = new URL(req.url);
    const matched = router.match(req.method, url.pathname);

    if (!matched) {
      const res = jsonError(404, 'Not Found');
      return applyCorsHeaders(res, corsHeaders);
    }

    try {
      const res = await matched.handler(req, env, ctx, matched.params);
      // 附加 CORS 头部到实际响应
      return applyCorsHeaders(res, corsHeaders);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Internal Server Error';
      const res = jsonError(500, message);
      return applyCorsHeaders(res, corsHeaders);
    }
  },

  /**
   * Cron Triggers 入口。
   * crons = ["0 22 * * *"]  -> 每日 22:00 UTC 提醒 (Phase E1)
   * crons = ["0 8 * * 1"]   -> 每周一 08:00 UTC 周报 (Phase E2)
   */
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    const cron = event.cron;
    const now = new Date(event.scheduledTime).toISOString();

    if (cron === '0 22 * * *') {
      // 每日提醒: 查询明天有日程的条目 (占位实现, 可接外部 webhook 推送)
      ctx.waitUntil(
        (async () => {
          try {
            await env.DB.prepare(
              `SELECT COUNT(*) AS cnt FROM schedule_entries WHERE deleted_at IS NULL`
            ).first();
            console.log(`[cron:daily_reminder] tick at ${now}`);
          } catch (err) {
            console.error('[cron:daily_reminder] error', err);
          }
        })()
      );
    } else if (cron === '0 8 * * 1') {
      // 每周周报: 聚合上周 sessions (占位实现, 实际可写缓存表或推送)
      ctx.waitUntil(
        (async () => {
          try {
            await env.DB.prepare(
              `SELECT COUNT(*) AS cnt FROM sessions WHERE deleted_at IS NULL`
            ).first();
            console.log(`[cron:weekly_report] tick at ${now}`);
          } catch (err) {
            console.error('[cron:weekly_report] error', err);
          }
        })()
      );
    } else {
      console.log(`[cron:unknown] ${cron} at ${now}`);
    }
  },
};
