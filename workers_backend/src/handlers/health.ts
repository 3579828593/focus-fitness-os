// src/handlers/health.ts
// 健康检查 / 就绪检查 / Prometheus 指标 — 迁移自 Node-RED metrics flow。
//
// GET /health   -> { code:0, data:{ status:"healthy", timestamp }, message:"ok" }
// GET /ready    -> 检查 D1 连接 (SELECT 1), 返回 { code:0, data:{ status:"ready", checks:{ d1:"ok"|"fail" } }, message }
// GET /metrics  -> 基础 Prometheus 文本格式指标

import type { Env, Handler } from '../types';
import { jsonResponse, jsonError } from '../middleware/error';

/**
 * GET /health — 存活探针, 不依赖外部资源。
 */
export const healthCheck: Handler = async (_req, _env, _ctx, _params) => {
  return jsonResponse(
    {
      status: 'healthy',
      timestamp: new Date().toISOString(),
    },
    'ok'
  );
};

/**
 * GET /ready — 就绪探针, 通过 SELECT 1 验证 D1 可达。
 */
export const readyCheck: Handler = async (_req, env, _ctx, _params) => {
  const checks: { d1: 'ok' | 'fail' } = { d1: 'fail' };
  try {
    await env.DB.prepare('SELECT 1').first();
    checks.d1 = 'ok';
  } catch {
    checks.d1 = 'fail';
  }

  const ready = checks.d1 === 'ok';
  if (!ready) {
    return jsonError(503, 'not ready');
  }

  return jsonResponse(
    {
      status: 'ready',
      checks,
    },
    'ok'
  );
};

/**
 * GET /metrics — 基础 Prometheus 文本格式指标。
 * 当前为静态/进程级指标 (Workers 为无状态, 真实指标需配合 Analytics Engine / Durable Objects)。
 */
export const metricsHandler: Handler = async (_req, _env, _ctx, _params) => {
  const ts = Math.floor(Date.now() / 1000);
  const lines = [
    '# HELP focus_fitness_api_up API 存活状态 (1=up)',
    '# TYPE focus_fitness_api_up gauge',
    `focus_fitness_api_up 1 ${ts}000`,
    '',
    '# HELP focus_fitness_api_requests_total 请求总数 (占位, 实际需接 Analytics Engine)',
    '# TYPE focus_fitness_api_requests_total counter',
    `focus_fitness_api_requests_total 0 ${ts}000`,
    '',
    '# HELP focus_fitness_api_db_ready D1 就绪状态 (1=ready)',
    '# TYPE focus_fitness_api_db_ready gauge',
    `focus_fitness_api_db_ready 1 ${ts}000`,
    '',
  ];
  return new Response(lines.join('\n'), {
    status: 200,
    headers: { 'Content-Type': 'text/plain; version=0.0.4; charset=utf-8' },
  });
};
