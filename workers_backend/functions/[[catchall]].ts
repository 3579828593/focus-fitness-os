// functions/[[catchall]].ts
// Cloudflare Pages Functions 入口 — 捕获所有路由，委托给现有 Workers 路由器。
//
// 适配层: Pages Functions 的 EventContext → Workers Handler 签名
//   context.request  → req: Request
//   context.env      → env: Env (D1, secrets, vars)
//   context.waitUntil → ctx.waitUntil
//
// 路由表 (与 Workers 版本完全一致):
//   POST /api/v1/auth/login, /auth/refresh, /auth/verify
//   POST /api/v1/sessions/complete, /schedule/change
//   GET  /api/v1/proposals, /stats/weekly
//   POST /api/v1/proposals/:id/accept, /:id/reject
//   GET  /health, /ready, /metrics
//   OPTIONS * (CORS 预检)

import { Router } from '../src/router';
import { corsMiddleware, getCorsHeaders } from '../src/middleware/cors';
import { withAuth } from '../src/middleware/auth';
import { jsonError, applyCorsHeaders } from '../src/middleware/error';
import { authLogin, authRefresh, authVerify } from '../src/handlers/auth';
import { sessionsComplete } from '../src/handlers/sessions';
import { scheduleChange } from '../src/handlers/schedule';
import { proposalsList, proposalAccept, proposalReject } from '../src/handlers/proposals';
import { weeklyStats } from '../src/handlers/stats';
import { healthCheck, readyCheck, metricsHandler } from '../src/handlers/health';
import type { Env, Handler } from '../src/types';

/** 构建路由器 (与 Workers index.ts 完全一致) */
function buildRouter(): Router {
  const router = new Router();
  router.add('POST', '/api/v1/auth/login', authLogin);
  router.add('POST', '/api/v1/auth/refresh', authRefresh);
  router.add('POST', '/api/v1/auth/verify', authVerify);
  router.add('POST', '/api/v1/sessions/complete', withAuth(sessionsComplete));
  router.add('POST', '/api/v1/schedule/change', withAuth(scheduleChange));
  router.add('GET', '/api/v1/proposals', withAuth(proposalsList));
  router.add('POST', '/api/v1/proposals/:id/accept', withAuth(proposalAccept));
  router.add('POST', '/api/v1/proposals/:id/reject', withAuth(proposalReject));
  router.add('GET', '/api/v1/stats/weekly', withAuth(weeklyStats));
  router.add('GET', '/health', healthCheck);
  router.add('GET', '/ready', readyCheck);
  router.add('GET', '/metrics', metricsHandler);
  return router;
}

/** 模拟 ExecutionContext (Pages context 只有 waitUntil) */
interface MockExecutionContext {
  waitUntil(promise: Promise<unknown>): void;
  passThroughOnException(): void;
}

/** Pages Functions onRequest — 适配到 Workers Handler 签名 */
export const onRequest: PagesFunction<Env & { ASSETS: { fetch: (req: Request | string) => Promise<Response> } }> = async (context) => {
  const { request: req, env, waitUntil } = context;

  // CORS 预检
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

  // 构建 mock ExecutionContext
  const ctx: MockExecutionContext = {
    waitUntil: (promise: Promise<unknown>) => waitUntil(promise),
    passThroughOnException: () => context.passThroughOnException(),
  };

  try {
    const res = await matched.handler(req, env, ctx as unknown as ExecutionContext, matched.params);
    return applyCorsHeaders(res, corsHeaders);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Internal Server Error';
    const res = jsonError(500, message);
    return applyCorsHeaders(res, corsHeaders);
  }
};
