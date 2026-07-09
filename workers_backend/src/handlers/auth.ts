// src/handlers/auth.ts
// 认证端点 — 迁移自 Node-RED Flow9 (auth.json)。
//
// 三个 handler (API 契约与 Node-RED 完全一致):
//   POST /api/v1/auth/login    -> { access_token, refresh_token, token_type:"Bearer", expires_in:3600 }
//   POST /api/v1/auth/refresh  -> 同上 (refresh_token 经 Authorization: Bearer 传入)
//   POST /api/v1/auth/verify   -> { code:0, data:{ valid:true, user_id, username, exp, iat }, message:"令牌有效" }
//
// 关键差异: Refresh Token 从文件系统 (refresh_tokens.json) 迁移到 D1 refresh_tokens 表。

import type { Env, Handler, UserRow, RefreshTokenRow } from '../types';
import { signAccessToken, verifyAccessToken, generateRefreshToken, ACCESS_TOKEN_TTL, REFRESH_TOKEN_TTL } from '../lib/jwt';
import { verifyPassword } from '../lib/password';
import { jsonError, jsonResponse } from '../middleware/error';

/**
 * 构造 OAuth2 扁平响应 (不包装在 {code, data, message} 中)。
 * Flutter AuthTokens.fromJson 直接解析 response.body, 期望扁平结构。
 */
function oauthResponse(data: Record<string, unknown>): Response {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}

/**
 * POST /api/v1/auth/login
 * Body: { username, password }
 * 1. 查询 users 表
 * 2. verifyPassword (PBKDF2, timing-safe)
 * 3. signAccessToken + generateRefreshToken
 * 4. 插入 refresh_tokens 表
 * 5. 返回 OAuth2 扁平结构
 */
export const authLogin: Handler = async (req, env, _ctx, _params) => {
  if (!env.JWT_SECRET) {
    return jsonError(500, '服务器密钥未配置');
  }

  let body: { username?: unknown; password?: unknown };
  try {
    body = (await req.json()) as { username?: unknown; password?: unknown };
  } catch {
    return jsonError(400, '请求体不是合法 JSON');
  }

  const username = typeof body.username === 'string' ? body.username.trim() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  if (!username || !password) {
    return jsonError(400, '用户名和密码不能为空');
  }

  // 查询用户
  const stmt = env.DB.prepare('SELECT user_id, username, password_hash FROM users WHERE username = ? LIMIT 1');
  const result = await stmt.bind(username).first<UserRow>();
  if (!result) {
    return jsonError(401, '用户名或密码错误');
  }

  // 验证密码 (PBKDF2)
  const ok = await verifyPassword(password, result.password_hash);
  if (!ok) {
    return jsonError(401, '用户名或密码错误');
  }

  // 签发令牌
  const accessToken = await signAccessToken(result.user_id, result.username, env.JWT_SECRET, ACCESS_TOKEN_TTL);
  const refreshToken = generateRefreshToken();
  const now = Math.floor(Date.now() / 1000);

  // 持久化 refresh token 到 D1
  await env.DB.prepare(
    'INSERT INTO refresh_tokens (token, user_id, username, created_at, expires_at) VALUES (?, ?, ?, ?, ?)'
  )
    .bind(refreshToken, result.user_id, result.username, now, now + REFRESH_TOKEN_TTL)
    .run();

  return oauthResponse({
    access_token: accessToken,
    refresh_token: refreshToken,
    token_type: 'Bearer',
    expires_in: ACCESS_TOKEN_TTL,
  });
};

/** 从 Authorization 头提取 Bearer token */
function extractBearerToken(req: Request): string | null {
  const authHeader = req.headers.get('Authorization') || '';
  if (!authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.substring(7).trim();
  return token || null;
}

/**
 * POST /api/v1/auth/refresh
 * Header: Authorization: Bearer <refresh_token>
 * 1. 查询 refresh_tokens 表
 * 2. 检查过期 -> 过期则删除并返回 401
 * 3. signAccessToken
 * 4. 返回新的 access_token (refresh_token 保持不变, 与 Node-RED 一致)
 */
export const authRefresh: Handler = async (req, env, _ctx, _params) => {
  if (!env.JWT_SECRET) {
    return jsonError(500, '服务器密钥未配置');
  }

  const token = extractBearerToken(req);
  if (!token) {
    return jsonError(401, '缺少 Refresh Token');
  }

  const row = await env.DB.prepare(
    'SELECT token, user_id, username, created_at, expires_at FROM refresh_tokens WHERE token = ? LIMIT 1'
  )
    .bind(token)
    .first<RefreshTokenRow>();

  if (!row) {
    return jsonError(401, '无效的 Refresh Token');
  }

  const now = Math.floor(Date.now() / 1000);
  if (now > row.expires_at) {
    // 过期: 删除并拒绝
    await env.DB.prepare('DELETE FROM refresh_tokens WHERE token = ?').bind(token).run();
    return jsonError(401, 'Refresh Token 已过期, 请重新登录');
  }

  const accessToken = await signAccessToken(row.user_id, row.username, env.JWT_SECRET, ACCESS_TOKEN_TTL);

  return oauthResponse({
    access_token: accessToken,
    refresh_token: token,
    token_type: 'Bearer',
    expires_in: ACCESS_TOKEN_TTL,
  });
};

/**
 * POST /api/v1/auth/verify
 * Header: Authorization: Bearer <access_token>
 * 1. verifyAccessToken
 * 2. 返回 { code:0, data:{ valid:true, user_id, username, exp, iat }, message:"令牌有效" }
 */
export const authVerify: Handler = async (req, env, _ctx, _params) => {
  if (!env.JWT_SECRET) {
    return jsonError(500, '服务器密钥未配置');
  }

  const token = extractBearerToken(req);
  if (!token) {
    return jsonError(401, '缺少 Access Token');
  }

  const payload = await verifyAccessToken(token, env.JWT_SECRET);
  if (!payload) {
    return jsonError(401, '令牌无效或已过期');
  }

  return jsonResponse(
    {
      valid: true,
      user_id: payload.user_id,
      username: payload.username,
      exp: payload.exp,
      iat: payload.iat,
    },
    '令牌有效'
  );
};
