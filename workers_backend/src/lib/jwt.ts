// src/lib/jwt.ts
// JWT 签发/验证 — 使用 Web Crypto API (SubtleCrypto) 实现 HMAC-SHA256。
// 替代 Node-RED 中基于 Node.js crypto + Buffer 的实现, Workers 原生支持, 零依赖。
//
// 契约 (与 Node-RED 保持一致):
// - Header: { alg: "HS256", typ: "JWT" }
// - Payload: { user_id, username, iat, exp }
// - 签名: HMAC-SHA256(secret, headerB64.payloadB64), base64url 编码
// - Access Token TTL: 3600s (1h)

const encoder = new TextEncoder();
const decoder = new TextDecoder();

/** Token 有效期 (秒): Access Token 1 小时; Refresh Token 7 天 (与 Node-RED Flow9 契约一致) */
export const ACCESS_TOKEN_TTL = 3600;
export const REFRESH_TOKEN_TTL = 7 * 24 * 3600;

/** ArrayBuffer | Uint8Array -> base64url 字符串 (无 padding) */
function base64urlEncode(data: ArrayBuffer | Uint8Array): string {
  const bytes = data instanceof Uint8Array ? data : new Uint8Array(data);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** base64url 字符串 -> Uint8Array */
function base64urlDecode(str: string): Uint8Array {
  let s = str.replace(/-/g, '+').replace(/_/g, '/');
  while (s.length % 4) s += '=';
  const binary = atob(s);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/** 导入 HMAC 密钥 */
async function importKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign', 'verify']
  );
}

/** verifyAccessToken 成功时返回的 payload 类型 (含 iat) */
export interface VerifiedPayload {
  user_id: number;
  username: string;
  iat: number;
  exp: number;
}

/**
 * 签发 Access Token (JWT)。
 * @param userId   用户 ID
 * @param username 用户名
 * @param secret   HMAC-SHA256 密钥 (env.JWT_SECRET)
 * @param ttlSeconds 过期秒数, 默认 3600 (1 小时)
 */
export async function signAccessToken(
  userId: number,
  username: string,
  secret: string,
  ttlSeconds = 3600
): Promise<string> {
  const header = { alg: 'HS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const payload = { user_id: userId, username, iat: now, exp: now + ttlSeconds };

  const headerB64 = base64urlEncode(encoder.encode(JSON.stringify(header)));
  const payloadB64 = base64urlEncode(encoder.encode(JSON.stringify(payload)));
  const data = `${headerB64}.${payloadB64}`;

  const key = await importKey(secret);
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(data));
  return `${data}.${base64urlEncode(sig)}`;
}

/**
 * 验证 Access Token。
 * 验签失败或已过期返回 null, 成功返回 payload (含 iat/exp)。
 */
export async function verifyAccessToken(
  token: string,
  secret: string
): Promise<VerifiedPayload | null> {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [headerB64, payloadB64, signatureB64] = parts;
  const data = `${headerB64}.${payloadB64}`;

  const key = await importKey(secret);
  const sigBytes = base64urlDecode(signatureB64);
  const valid = await crypto.subtle.verify('HMAC', key, sigBytes, encoder.encode(data));
  if (!valid) return null;

  let payload: VerifiedPayload;
  try {
    payload = JSON.parse(decoder.decode(base64urlDecode(payloadB64)));
  } catch {
    return null;
  }

  const now = Math.floor(Date.now() / 1000);
  if (payload.exp && now > payload.exp) return null;
  return payload;
}

/**
 * 生成 64 字节随机 Refresh Token (十六进制字符串, 128 字符)。
 * 使用 crypto.getRandomValues, Workers 原生支持。
 */
export function generateRefreshToken(): string {
  const bytes = new Uint8Array(64);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}
