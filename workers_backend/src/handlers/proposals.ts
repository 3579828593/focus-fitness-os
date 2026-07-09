// src/handlers/proposals.ts
// 提案管理 — 迁移自 Node-RED Flow5 + Flow11。
//
// GET  /api/v1/proposals              ?status=LOCKED&limit=50  -> { code:0, data:{ proposals, count }, message:"ok" }
// POST /api/v1/proposals/:id/accept                            -> UPDATE proposals SET lock_state='ACCEPTED' WHERE id=?
// POST /api/v1/proposals/:id/reject                            -> UPDATE proposals SET lock_state='REJECTED'  WHERE id=?

import type { Env, Handler, ProposalRow } from '../types';
import { getAuthUser } from '../middleware/auth';
import { jsonError, jsonResponse } from '../middleware/error';

/** 允许的状态过滤值 (映射到 lock_state 列) */
const ALLOWED_STATUSES = new Set(['PENDING', 'LOCKED', 'ACCEPTED', 'REJECTED']);

function parseLimit(raw: string | null): number {
  const n = parseInt(raw ?? '', 10);
  if (!Number.isFinite(n) || n <= 0) return 50;
  return Math.min(n, 500); // 上限 500, 防止超大查询
}

/**
 * GET /api/v1/proposals?status=LOCKED&limit=50
 */
export const proposalsList: Handler = async (req, env, _ctx, _params) => {
  const user = getAuthUser(req);
  if (!user) {
    return jsonError(401, 'Unauthorized');
  }

  const url = new URL(req.url);
  const status = url.searchParams.get('status');
  const limit = parseLimit(url.searchParams.get('limit'));

  let sql: string;
  let bindings: unknown[];
  if (status && ALLOWED_STATUSES.has(status)) {
    sql = `SELECT id, type, lock_state, target_table, target_id, target_field,
                  old_value, new_value, reason, created_at
             FROM proposals
            WHERE lock_state = ?
            ORDER BY created_at DESC
            LIMIT ?`;
    bindings = [status, limit];
  } else {
    sql = `SELECT id, type, lock_state, target_table, target_id, target_field,
                  old_value, new_value, reason, created_at
             FROM proposals
            ORDER BY created_at DESC
            LIMIT ?`;
    bindings = [limit];
  }

  const result = await env.DB.prepare(sql).bind(...bindings).all<ProposalRow>();
  const proposals = result.results ?? [];

  return jsonResponse(
    {
      proposals,
      count: proposals.length,
    },
    'ok'
  );
};

/**
 * POST /api/v1/proposals/:id/accept
 * params.id = 提案 ID
 */
export const proposalAccept: Handler = async (req, env, _ctx, params) => {
  const user = getAuthUser(req);
  if (!user) {
    return jsonError(401, 'Unauthorized');
  }

  const id = parseInt(params.id, 10);
  if (!Number.isFinite(id) || id <= 0) {
    return jsonError(400, '无效的提案 ID');
  }

  const result = await env.DB.prepare(
    `UPDATE proposals SET lock_state = 'ACCEPTED' WHERE id = ?`
  )
    .bind(id)
    .run();

  const changes = (result.meta as { changes?: number } | undefined)?.changes ?? 0;
  if (changes === 0) {
    return jsonError(404, '提案不存在');
  }

  return jsonResponse({ id, lock_state: 'ACCEPTED' }, 'proposal accepted');
};

/**
 * POST /api/v1/proposals/:id/reject
 * params.id = 提案 ID
 */
export const proposalReject: Handler = async (req, env, _ctx, params) => {
  const user = getAuthUser(req);
  if (!user) {
    return jsonError(401, 'Unauthorized');
  }

  const id = parseInt(params.id, 10);
  if (!Number.isFinite(id) || id <= 0) {
    return jsonError(400, '无效的提案 ID');
  }

  const result = await env.DB.prepare(
    `UPDATE proposals SET lock_state = 'REJECTED' WHERE id = ?`
  )
    .bind(id)
    .run();

  const changes = (result.meta as { changes?: number } | undefined)?.changes ?? 0;
  if (changes === 0) {
    return jsonError(404, '提案不存在');
  }

  return jsonResponse({ id, lock_state: 'REJECTED' }, 'proposal rejected');
};
