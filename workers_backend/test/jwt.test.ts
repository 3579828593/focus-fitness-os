// test/jwt.test.ts
// JWT 签发/验证单元测试 — 使用 Web Crypto API (运行于 Workers pool)。
//
// 覆盖:
//   1. signAccessToken -> verifyAccessToken 成功, payload 字段正确
//   2. 篡改 token -> verifyAccessToken 返回 null
//   3. 过期 token -> verifyAccessToken 返回 null

import { describe, it, expect } from 'vitest';
import { signAccessToken, verifyAccessToken, generateRefreshToken } from '../src/lib/jwt';

const SECRET = 'test-jwt-secret-for-vitest';

describe('JWT signAccessToken / verifyAccessToken', () => {
  it('签发后应能成功验证并返回正确 payload', async () => {
    const token = await signAccessToken(1, 'admin', SECRET, 3600);
    expect(token.split('.').length).toBe(3);

    const payload = await verifyAccessToken(token, SECRET);
    expect(payload).not.toBeNull();
    expect(payload!.user_id).toBe(1);
    expect(payload!.username).toBe('admin');
    expect(payload!.iat).toBeTypeOf('number');
    expect(payload!.exp).toBe(payload!.iat + 3600);
    expect(payload!.exp).toBeGreaterThan(payload!.iat);
  });

  it('篡改签名后应验证失败 (返回 null)', async () => {
    const token = await signAccessToken(2, 'alice', SECRET, 3600);
    const parts = token.split('.');
    // 翻转签名末尾字符
    const lastChar = parts[2][parts[2].length - 1];
    const flipped = lastChar === 'A' ? 'B' : 'A';
    const tamperedSig = parts[2].slice(0, -1) + flipped;
    const tampered = `${parts[0]}.${parts[1]}.${tamperedSig}`;

    const payload = await verifyAccessToken(tampered, SECRET);
    expect(payload).toBeNull();
  });

  it('篡改 payload 后应验证失败 (返回 null)', async () => {
    const token = await signAccessToken(3, 'bob', SECRET, 3600);
    const parts = token.split('.');
    // 将 payload 替换为另一段 base64url (伪造 user_id)
    const fakePayload = btoa(JSON.stringify({ user_id: 999, username: 'evil', iat: 0, exp: 9999999999 }))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
    const tampered = `${parts[0]}.${fakePayload}.${parts[2]}`;

    const payload = await verifyAccessToken(tampered, SECRET);
    expect(payload).toBeNull();
  });

  it('过期 token 应验证失败 (返回 null)', async () => {
    // 使用负 TTL 使 exp 落在过去
    const token = await signAccessToken(4, 'expired-user', SECRET, -10);
    const payload = await verifyAccessToken(token, SECRET);
    expect(payload).toBeNull();
  });

  it('格式错误的 token (非三段) 应返回 null', async () => {
    const payload = await verifyAccessToken('not.a.valid.jwt.extra', SECRET);
    expect(payload).toBeNull();
    const payload2 = await verifyAccessToken('onlyonepart', SECRET);
    expect(payload2).toBeNull();
  });

  it('使用错误密钥验证应返回 null', async () => {
    const token = await signAccessToken(5, 'carol', SECRET, 3600);
    const payload = await verifyAccessToken(token, 'wrong-secret');
    expect(payload).toBeNull();
  });
});

describe('generateRefreshToken', () => {
  it('应生成 128 字符的十六进制字符串', () => {
    const token = generateRefreshToken();
    expect(token).toMatch(/^[0-9a-f]{128}$/);
  });

  it('每次生成的 token 应不同', () => {
    const a = generateRefreshToken();
    const b = generateRefreshToken();
    expect(a).not.toBe(b);
  });
});
