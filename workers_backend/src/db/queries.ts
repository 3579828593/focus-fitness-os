// src/db/queries.ts
// SQL 查询字符串 - 按业务域组织
// 迁移自 Node-RED 的 msg.topic 模式 SQL (Flow2/4/5/6/9)
//
// 在 Workers 中通过 env.DB.prepare(sql).bind(...).run()/all()/first() 执行
// 占位符统一使用 D1/SQLite 的 "?" 参数化语法

// ===== 认证域 (Flow9: JWT + Refresh Token) =====
export const authQueries = {
  // 登录时插入 refresh_token (替代原 refresh_tokens.json 文件存储)
  insertRefreshToken:
    'INSERT INTO refresh_tokens (token, user_id, username, created_at, expires_at) VALUES (?, ?, ?, ?, ?)',

  // 刷新时查询 refresh_token 记录
  selectRefreshToken:
    'SELECT token, user_id, username, created_at, expires_at FROM refresh_tokens WHERE token = ?',

  // 过期或登出时删除 refresh_token
  deleteRefreshToken:
    'DELETE FROM refresh_tokens WHERE token = ?',

  // 按用户名查询用户 (密码哈希验证)
  selectUserByUsername:
    'SELECT user_id, username, password_hash, created_at, updated_at FROM users WHERE username = ?',

  // 清理已过期的 refresh_token (可由 Cron Trigger 定期调用)
  deleteExpiredRefreshTokens:
    'DELETE FROM refresh_tokens WHERE expires_at < ?',
} as const;

// ===== 会话域 (Flow2: 训练完成上报 → 渐进超负荷) =====
export const sessionQueries = {
  // 写入渐进超负荷生成的 LOCKED 提案
  // 参数: type, lock_state, target_table, target_id, target_field,
  //       old_value, new_value, reason, created_at
  insertProposal:
    'INSERT INTO proposals (type, lock_state, target_table, target_id, target_field, old_value, new_value, reason, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',

  // 查询某会话的片段 (渐进超负荷备用, 当前片段由请求体直接传入)
  selectSegmentsBySession:
    'SELECT segment_id, session_id, seg_type, planned_seconds, actual_seconds, reps_done, weight_kg_done, created_at FROM session_segments WHERE session_id = ? AND deleted_at IS NULL ORDER BY segment_id',
} as const;

// ===== 日程域 (Flow4: 冲突检测) =====
export const scheduleQueries = {
  // 查询同日日程 (排除新条目本身, JOIN executable_units 获取 priority)
  // 迁移自 Node-RED f4_query_existing
  // 参数: date, newEntry.entry_id
  selectScheduleByDate:
    'SELECT se.entry_id, se.date, se.start_time, se.exec_mode, se.unit_id, eu.priority ' +
    'FROM schedule_entries se ' +
    'JOIN executable_units eu ON se.unit_id = eu.id ' +
    'WHERE se.date = ? AND se.entry_id != ? AND se.deleted_at IS NULL',
} as const;

// ===== 提案域 (Flow5 + Flow11: 提案列表/接受/拒绝) =====
export const proposalQueries = {
  // 按 lock_state 查询提案列表 (分页)
  // 参数: lock_state, limit
  selectProposals:
    'SELECT id, type, lock_state, target_table, target_id, target_field, old_value, new_value, reason, created_at ' +
    'FROM proposals WHERE lock_state = ? ORDER BY created_at DESC LIMIT ?',

  // 查询单个提案 (接受/拒绝前校验存在性)
  // 参数: id
  selectProposalById:
    'SELECT id, type, lock_state, target_table, target_id, target_field, old_value, new_value, reason, created_at FROM proposals WHERE id = ?',

  // 接受提案: lock_state → ACCEPTED
  // 参数: id
  updateProposalLockState:
    'UPDATE proposals SET lock_state = ? WHERE id = ?',
} as const;

// ===== 统计域 (Flow6: 周报统计) =====
export const statsQueries = {
  // 按日期范围查询会话 (JOIN schedule_entries 获取 exec_mode)
  // 迁移自 Node-RED f3_query_sessions
  // 参数: startDate (含时间), endDate (含时间)
  selectSessionsByDateRange:
    'SELECT s.session_id, s.entry_id, s.state, s.started_at, s.ended_at, ' +
    's.completion_ratio, s.outcome, s.last_segment_index, ' +
    'se.exec_mode, se.unit_id ' +
    'FROM sessions s ' +
    'JOIN schedule_entries se ON s.entry_id = se.entry_id ' +
    'WHERE s.started_at >= ? AND s.started_at <= ? AND s.deleted_at IS NULL',

  // 带训练量的会话查询 (LEFT JOIN 聚合 session_segments 得到每会话 training_volume)
  // 用于周报统计的 totalTrainingVolume 聚合
  // 参数: startDate (含时间), endDate (含时间)
  selectSessionsWithVolumeByDateRange:
    'SELECT s.session_id, s.entry_id, s.state, s.started_at, s.ended_at, ' +
    's.completion_ratio, s.outcome, s.last_segment_index, ' +
    'se.exec_mode, se.unit_id, ' +
    'COALESCE(SUM(COALESCE(ss.reps_done, 0) * COALESCE(ss.weight_kg_done, 0)), 0) AS training_volume ' +
    'FROM sessions s ' +
    'JOIN schedule_entries se ON s.entry_id = se.entry_id ' +
    'LEFT JOIN session_segments ss ON ss.session_id = s.session_id AND ss.deleted_at IS NULL ' +
    'WHERE s.started_at >= ? AND s.started_at <= ? AND s.deleted_at IS NULL ' +
    'GROUP BY s.session_id',
} as const;

// ===== 健康检查域 =====
export const healthQueries = {
  // D1 连通性检查 (GET /ready)
  selectOne: 'SELECT 1',
} as const;
