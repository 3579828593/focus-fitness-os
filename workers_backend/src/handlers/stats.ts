// src/handlers/stats.ts
// 周报统计 — 迁移自 Node-RED Flow6 (weekly_report)。
//
// GET /api/v1/stats/weekly?week=2026-W28 (需 JWT)
//   week 支持 "YYYY-Www" (ISO 周) 与 "YYYY-MM-DD" 两种格式, 缺省取当前周
//
// 返回: { code:0, data:{ week, start_date, end_date, total_sessions,
//                         total_focus_minutes, total_training_volume,
//                         completed_sessions, completion_rate }, message:"ok" }

import type { Env, Handler, SessionRow } from '../types';
import { parseWeekRange, aggregateWeeklyStats } from '../lib/weekly_stats';
import { getAuthUser } from '../middleware/auth';
import { jsonError, jsonResponse } from '../middleware/error';

export const weeklyStats: Handler = async (req, env, _ctx, _params) => {
  const user = getAuthUser(req);
  if (!user) {
    return jsonError(401, 'Unauthorized');
  }

  const url = new URL(req.url);
  const week = url.searchParams.get('week');

  // 解析周范围
  let range;
  try {
    range = parseWeekRange(week);
  } catch {
    return jsonError(400, 'week 参数格式无效, 支持 YYYY-Www 或 YYYY-MM-DD');
  }

  // 查询该周 sessions (created_at 为 ISO 字符串, BETWEEN 字符串比较)
  // 使用 start_date 00:00:00 ~ end_date 23:59:59 覆盖整天
  const startTs = `${range.startDate}T00:00:00`;
  const endTs = `${range.endDate}T23:59:59`;

  const result = await env.DB.prepare(
    `SELECT session_id, entry_id, state, started_at, ended_at,
            completion_ratio, outcome, last_segment_index, created_at, updated_at, deleted_at
       FROM sessions
      WHERE created_at BETWEEN ? AND ?
        AND deleted_at IS NULL`
  )
    .bind(startTs, endTs)
    .all<SessionRow>();

  const sessions = result.results ?? [];

  // 聚合
  const stats = aggregateWeeklyStats(range, sessions);

  return jsonResponse(stats, 'ok');
};
