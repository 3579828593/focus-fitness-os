// src/middleware/cors.ts
// CORS 中间件 — 收紧跨域来源控制 (替代 Node-RED 的 "*")。
//
// 职责:
//   - getCorsHeaders(req, env): 依据请求 Origin 与 env.CORS_ALLOWED_ORIGINS 计算应返回的 CORS 头部
//   - corsMiddleware(req, env):  处理 OPTIONS 预检, 返回 204 No Content
//   - 非 OPTIONS 请求的实际响应由 index.ts 调用 applyCorsHeaders 附加头部

import type { Env } from '../types';

const DEFAULT_ALLOWED_HEADERS = 'Origin, X-Requested-With, Content-Type, Accept, Authorization';
const DEFAULT_ALLOWED_METHODS = 'GET, POST, PUT, DELETE, OPTIONS';
const DEFAULT_MAX_AGE = '86400';

/**
 * 计算 CORS 响应头部。
 * 策略: 若请求 Origin 在白名单中, 则回显该 Origin; 否则回落到白名单第一项 (或空)。
 */
export function getCorsHeaders(req: Request, env: Env): Record<string, string> {
  const allowedOrigins = (env.CORS_ALLOWED_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const origin = req.headers.get('Origin') || '';
  const allowedOrigin = allowedOrigins.includes(origin)
    ? origin
    : allowedOrigins[0] || '';

  const headers: Record<string, string> = {
    'Access-Control-Allow-Headers': DEFAULT_ALLOWED_HEADERS,
    'Access-Control-Allow-Methods': DEFAULT_ALLOWED_METHODS,
    'Access-Control-Max-Age': DEFAULT_MAX_AGE,
  };
  if (allowedOrigin) {
    headers['Access-Control-Allow-Origin'] = allowedOrigin;
    headers['Vary'] = 'Origin';
  }
  return headers;
}

/**
 * CORS 预检中间件: 对 OPTIONS 请求返回 204 No Content + CORS 头部。
 */
export function corsMiddleware(req: Request, env: Env): Response {
  const corsHeaders = getCorsHeaders(req, env);
  return new Response(null, {
    status: 204,
    headers: corsHeaders,
  });
}
