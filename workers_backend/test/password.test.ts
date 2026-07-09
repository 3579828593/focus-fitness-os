// test/password.test.ts
// PBKDF2 密码哈希/验证单元测试 — 使用 Web Crypto API (运行于 Workers pool)。
//
// 覆盖:
//   1. hashPassword -> verifyPassword 成功
//   2. 错误密码 -> verifyPassword 返回 false
//   3. 不同密码 -> 生成不同哈希

import { describe, it, expect } from 'vitest';
import { hashPassword, verifyPassword } from '../src/lib/password';

describe('PBKDF2 hashPassword / verifyPassword', () => {
  it('哈希后应能用原密码成功验证', async () => {
    const password = 'my-secret-p@ssw0rd';
    const hash = await hashPassword(password);
    // 存储格式: pbkdf2:100000:saltHex:hashHex
    expect(hash.startsWith('pbkdf2:100000:')).toBe(true);
    const parts = hash.split(':');
    expect(parts.length).toBe(4);
    expect(parts[2].length).toBe(32); // 16 字节 salt -> 32 hex
    expect(parts[3].length).toBe(64); // 32 字节 hash -> 64 hex

    const ok = await verifyPassword(password, hash);
    expect(ok).toBe(true);
  });

  it('错误密码应验证失败 (返回 false)', async () => {
    const password = 'correct-password';
    const wrong = 'wrong-password';
    const hash = await hashPassword(password);
    const ok = await verifyPassword(wrong, hash);
    expect(ok).toBe(false);
  });

  it('不同密码应生成不同哈希', async () => {
    const hash1 = await hashPassword('password-one');
    const hash2 = await hashPassword('password-two');
    expect(hash1).not.toBe(hash2);
    // salt 部分也应不同 (随机)
    expect(hash1.split(':')[2]).not.toBe(hash2.split(':')[2]);
  });

  it('相同密码两次哈希的 salt 应不同 (随机 salt)', async () => {
    const password = 'same-password';
    const hash1 = await hashPassword(password);
    const hash2 = await hashPassword(password);
    expect(hash1).not.toBe(hash2);
    // 但两者都能验证通过
    expect(await verifyPassword(password, hash1)).toBe(true);
    expect(await verifyPassword(password, hash2)).toBe(true);
  });

  it('格式非法的存储哈希应返回 false', async () => {
    expect(await verifyPassword('any', 'not-a-valid-hash')).toBe(false);
    expect(await verifyPassword('any', 'pbkdf2:100000:badhash')).toBe(false);
    expect(await verifyPassword('any', 'scrypt:100000:abcd:efgh')).toBe(false);
  });

  it('空字符串密码应能正常哈希与验证', async () => {
    const hash = await hashPassword('');
    expect(await verifyPassword('', hash)).toBe(true);
    expect(await verifyPassword(' ', hash)).toBe(false);
  });
});
