// src/middleware/error.ts
// 统一错误/响应辅助函数。
//
// API 契约 (与 Node-RED 保持一致):
//   成功业务响应: { code: 0, data: {...}, message: "ok" }
//   错误响应:     { code: 1, error: "message" }

/** 默认 CORS 头部键名, 供实际响应附加 */
const CORS_HEADER_KEYS = [
  'Access-Control-Allow-Origin',
  'Access-Control-Allow-Headers',
  'Access-Control-Allow-Methods',
  'Access-Control-Max-Age',
] as const;

/**
 * 构造错误响应: { code: 1, error: message }, HTTP statusCode。
 */
export function jsonError(
  statusCode: number,
  message: string,
  extraHeaders: Record<string, string> = {}
): Response {
  const body = JSON.stringify({ code: 1, error: message });
  return new Response(body, {
    status: statusCode,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...extraHeaders,
    },
  });
}

/**
 * 构造成功业务响应: { code: 0, data, message }, HTTP 200。
 */
export function jsonResponse<T>(
  data: T,
  message = 'ok',
  extraHeaders: Record<string, string> = {}
): Response {
  const body = JSON.stringify({ code: 0, data, message });
  return new Response(body, {
    status: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...extraHeaders,
    },
  });
}

/**
 * 给已有 Response 附加 CORS 头部 (用于 OPTIONS 之外的实际响应)。
 * 返回一个新的 Response, 不污染原 body。
 */
export function applyCorsHeaders(
  res: Response,
  corsHeaders: Record<string, string>
): Response {
  const newHeaders = new Headers(res.headers);
  for (const key of CORS_HEADER_KEYS) {
    if (corsHeaders[key]) newHeaders.set(key, corsHeaders[key]);
  }
  return new Response(res.body, {
    status: res.status,
    statusText: res.statusText,
    headers: newHeaders,
  });
}

/** 兼容: 返回 JSON 字符串的 Body (部分场景需要直接拼接) */
export function jsonBody(data: unknown): string {
  return JSON.stringify(data);
}
