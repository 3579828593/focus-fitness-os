// src/handlers/sessions.ts
// 训练完成上报 — 迁移自 Node-RED Flow2 (sessions/complete)。
//
// POST /api/v1/sessions/complete (需 JWT)
// Body: { session_id, entry_id, completion_ratio, segments }
//   - segments: 数组, 其中 seg_type === "WORKOUT_SET" 的片段参与渐进超负荷
//
// 流程:
//   1. 校验请求体
//   2. 提取 WORKOUT_SET 片段
//   3. 若无训练数据 -> { code:0, data:{ status:"skipped" }, message:"no exercise data" }
//   4. 否则查 workout_exercises 取目标动作, 调用 progressiveOverload()
//   5. 将生成的 LOCKED 提案 INSERT 到 proposals 表
//   6. 返回 { code:0, data:{ status:"ok" }, message:"session processed" }

import type { Env, Handler, SessionSegment, WorkoutExercise, ProposalInsert } from '../types';
import { progressiveOverload } from '../lib/progressive_overload';
import { getAuthUser } from '../middleware/auth';
import { jsonError, jsonResponse } from '../middleware/error';

interface SessionsCompleteBody {
  session_id?: unknown;
  entry_id?: unknown;
  completion_ratio?: unknown;
  segments?: unknown;
  exercise?: unknown; // 可选: 直接传入动作信息
}

export const sessionsComplete: Handler = async (req, env, _ctx, _params) => {
  const user = getAuthUser(req);
  if (!user) {
    return jsonError(401, 'Unauthorized');
  }

  let body: SessionsCompleteBody;
  try {
    body = (await req.json()) as SessionsCompleteBody;
  } catch {
    return jsonError(400, '请求体不是合法 JSON');
  }

  const sessionId = typeof body.session_id === 'number' ? body.session_id : null;
  const entryId = typeof body.entry_id === 'number' ? body.entry_id : null;
  const completionRatio =
    typeof body.completion_ratio === 'number' && Number.isFinite(body.completion_ratio)
      ? body.completion_ratio
      : null;

  if (sessionId == null || entryId == null || completionRatio == null) {
    return jsonError(400, '缺少必要字段: session_id, entry_id, completion_ratio');
  }
  if (completionRatio < 0 || completionRatio > 1) {
    return jsonError(400, 'completion_ratio 必须在 [0, 1] 范围内');
  }

  const segments = Array.isArray(body.segments)
    ? (body.segments as SessionSegment[])
    : [];

  // 提取 WORKOUT_SET 片段
  const workoutSegments = segments.filter((s) => s && s.seg_type === 'WORKOUT_SET');

  // 无训练数据 -> skipped
  if (workoutSegments.length === 0) {
    return jsonResponse({ status: 'skipped' }, 'no exercise data');
  }

  // 取目标动作: 优先使用请求体传入的 exercise, 否则按 entry_id -> unit_id 查 workout_exercises
  let exercise: WorkoutExercise | null = null;
  if (body.exercise && typeof body.exercise === 'object') {
    exercise = body.exercise as WorkoutExercise;
  } else {
    // 通过 schedule_entries.unit_id 关联 workout_exercises
    exercise = await env.DB.prepare(
      `SELECT we.exercise_id, we.unit_id, we.name, we.planned_sets, we.planned_reps,
              we.planned_weight, we.rest_seconds, we.rpe
         FROM workout_exercises we
         JOIN schedule_entries se ON se.unit_id = we.unit_id
        WHERE se.entry_id = ? AND we.deleted_at IS NULL
        LIMIT 1`
    )
      .bind(entryId)
      .first<WorkoutExercise>();
  }

  if (!exercise) {
    // 无关联动作 -> skipped
    return jsonResponse({ status: 'skipped' }, 'no exercise data');
  }

  // 渐进超负荷决策
  const result = progressiveOverload(exercise, completionRatio, workoutSegments);

  // 持久化提案到 D1
  await insertProposal(env, result.proposal);

  return jsonResponse(
    {
      status: 'ok',
      session_id: sessionId,
      entry_id: entryId,
      new_weight: result.newWeight,
      reason: result.reason,
      is_pr: result.isPR,
      completion_ratio: result.completionRatio,
      avg_rpe: Number(result.avgRpe.toFixed(2)),
    },
    'session processed'
  );
};

/** 将单个提案写入 proposals 表 */
export async function insertProposal(env: Env, proposal: ProposalInsert): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO proposals (type, lock_state, target_table, target_id, target_field, old_value, new_value, reason, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(
      proposal.type,
      proposal.lock_state,
      proposal.target_table,
      proposal.target_id,
      proposal.target_field,
      proposal.old_value,
      proposal.new_value,
      proposal.reason,
      proposal.created_at
    )
    .run();
}
