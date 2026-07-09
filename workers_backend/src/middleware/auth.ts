// src/middleware/auth.ts
// JWT 认证中间件 (withAuth 包装器)。
//
// 职责:
//   - 校验 Authorization: Bearer <access_token>
//   - 验签失败 / 缺失令牌 / 已过期 -> 返回 401 { code: 1, error: "..." }
//   - 成功则注入 X-User-Id / X-Username 请求头, 转交被包装的 handler
//
// 注: withAuth 捕获 handler 抛出的异常并统一转为 500 错误响应。

import type { Env, Handler } from '../types';
import { verifyAccessToken } from '../lib/jwt';
import { jsonError } from './error';

/**
 * 包装一个受保护 handler, 注入 JWT 校验逻辑。
 * @param handler 需要鉴权的业务 handler
 * @param _env    预留 env (实际 env 在运行时由 fetch 传入, 此处保留参数以与计划签名一致)
 */
export function withAuth(handler: Handler, _env?: Env): Handler {
  return async (req: Request, env: Env, ctx: ExecutionContext, params: Record<string, string>): Promise<Response> => {
    if (!env.JWT_SECRET) {
      return jsonError(500, '服务器密钥未配置');
    }

    const authHeader = req.headers.get('Authorization') || '';
    if (!authHeader.startsWith('Bearer ')) {
      return jsonError(401, 'Missing access token');
    }
    const token = authHeader.substring(7).trim();
    if (!token) {
      return jsonError(401, 'Missing access token');
    }

    const payload = await verifyAccessToken(token, env.JWT_SECRET);
    if (!payload) {
      return jsonError(401, 'Invalid or expired token');
    }

    // 通过请求头注入用户信息 (Workers 请求头可重写)
    const headers = new Headers(req.headers);
    headers.set('X-User-Id', String(payload.user_id));
    headers.set('X-Username', payload.username);
    const reqWithUser = new Request(req, { headers });

    try {
      return await handler(reqWithUser, env, ctx, params);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Internal Server Error';
      return jsonError(500, message);
    }
  };
}

/**
 * 从被 withAuth 包装的请求中读取注入的用户信息。
 */
export function getAuthUser(req: Request): { userId: number; username: string } | null {
  const userIdStr = req.headers.get('X-User-Id');
  const username = req.headers.get('X-Username');
  if (!userIdStr || !username) return null;
  const userId = parseInt(userIdStr, 10);
  if (!Number.isFinite(userId)) return null;
  return { userId, username };
}
