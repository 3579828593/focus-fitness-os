// src/handlers/schedule.ts
// 日程变更通知 — 迁移自 Node-RED Flow4 (conflict_detection)。
//
// POST /api/v1/schedule/change (需 JWT)
// Body: { entry_id, date, start_time, unit_id }
//
// 流程:
//   1. 校验请求体
//   2. 查询同日日程: SELECT entry_id, unit_id, date, start_time FROM schedule_entries
//                    WHERE date = ? AND deleted_at IS NULL
//   3. detectConflicts(newEntry, existing) -> { conflicts, proposals, resolved }
//   4. 批量 INSERT 冲突提案到 proposals 表
//   5. 返回 { code:0, data:{ conflicts, proposals }, message }

import type { Env, Handler, ScheduleEntry } from '../types';
import { detectConflicts } from '../lib/conflict_detector';
import { getAuthUser } from '../middleware/auth';
import { jsonError, jsonResponse } from '../middleware/error';
import { insertProposal } from './sessions';

interface ScheduleChangeBody {
  entry_id?: unknown;
  date?: unknown;
  start_time?: unknown;
  unit_id?: unknown;
  priority?: unknown;
}

export const scheduleChange: Handler = async (req, env, _ctx, _params) => {
  const user = getAuthUser(req);
  if (!user) {
    return jsonError(401, 'Unauthorized');
  }

  let body: ScheduleChangeBody;
  try {
    body = (await req.json()) as ScheduleChangeBody;
  } catch {
    return jsonError(400, '请求体不是合法 JSON');
  }

  const entryId = typeof body.entry_id === 'number' ? body.entry_id : null;
  const date = typeof body.date === 'string' ? body.date : null;
  const startTime = typeof body.start_time === 'string' ? body.start_time : null;
  const unitId = typeof body.unit_id === 'number' ? body.unit_id : null;

  if (entryId == null || !date || !startTime) {
    return jsonError(400, '缺少必要字段: entry_id, date, start_time');
  }

  const priority = typeof body.priority === 'number' ? body.priority : 5;
  const newEntry: ScheduleEntry = {
    entry_id: entryId,
    unit_id: unitId,
    date,
    start_time: startTime,
    priority,
  };

  // 查询同日已存在的日程 (未删除)
  const existing = await env.DB.prepare(
    `SELECT entry_id, unit_id, date, start_time, exec_mode, is_baseline, lock_state
       FROM schedule_entries
      WHERE date = ? AND deleted_at IS NULL`
  )
    .bind(date)
    .all<ScheduleEntry>();

  const existingEntries = existing.results ?? [];

  // 冲突检测 + 顺延提案生成
  const detection = detectConflicts(newEntry, existingEntries);

  // 批量持久化提案
  for (const proposal of detection.proposals) {
    await insertProposal(env, proposal);
  }

  const message =
    detection.proposals.length > 0
      ? `检测到 ${detection.conflicts.length} 个冲突, 生成 ${detection.proposals.length} 个顺延提案`
      : '无冲突';

  return jsonResponse(
    {
      conflicts: detection.conflicts,
      proposals: detection.proposals,
      resolved: detection.resolved,
    },
    message
  );
};
