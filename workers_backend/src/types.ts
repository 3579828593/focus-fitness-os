// src/types.ts
// TypeScript 类型定义 (Cloudflare Workers + D1)
// 类型来源: D1 schema (migrations/0001_init.sql) + Node-RED 业务流 (Flow2/4/6/9)

/**
 * Worker 环境变量绑定。
 * - DB: D1 数据库绑定 (wrangler.toml 中的 [[d1_databases]] binding = "DB")
 * - CORS_ALLOWED_ORIGINS: 逗号分隔的允许跨域来源列表
 * - JWT_SECRET: HMAC-SHA256 签名密钥 (作为 Secret 配置)
 * - API_PASSWORD_HASH: 可选, 初始管理员密码哈希 (pbkdf2:100000:saltHex:hashHex)
 */
export interface Env {
  DB: D1Database;
  CORS_ALLOWED_ORIGINS: string;
  JWT_SECRET: string;
  API_PASSWORD_HASH?: string;
}

/** 路由处理器签名: 所有 handler 都遵循 (req, env, ctx, params) => Promise<Response> */
export type Handler = (
  req: Request,
  env: Env,
  ctx: ExecutionContext,
  params: Record<string, string>
) => Promise<Response>;

/** 用户表行 */
export interface UserRow {
  user_id: number;
  username: string;
  password_hash: string;
  created_at: string;
  updated_at: string | null;
}

/** refresh_tokens 表行 */
export interface RefreshTokenRow {
  token: string;
  user_id: number;
  username: string;
  created_at: number;
  expires_at: number;
}

/** proposals 表行 */
export interface ProposalRow {
  id: number;
  type: string;
  lock_state: string;
  target_table: string;
  target_id: number | null;
  target_field: string | null;
  old_value: string | null;
  new_value: string | null;
  reason: string | null;
  created_at: string | null;
}

/** schedule_entries 表行 (冲突检测用) */
export interface ScheduleEntry {
  entry_id: number;
  unit_id: number | null;
  date: string;
  start_time: string;
  exec_mode?: string;
  is_baseline?: number;
  lock_state?: string;
  priority?: number;
  created_at?: string;
  updated_at?: string | null;
  deleted_at?: string | null;
}

/** workout_exercises 表行 (渐进超负荷用) */
export interface WorkoutExercise {
  exercise_id: number;
  unit_id: number | null;
  name: string;
  planned_sets: number;
  planned_reps: number;
  planned_weight: number;
  rest_seconds?: number;
  rpe?: number | null;
  max_weight?: number;
  created_at?: string;
  updated_at?: string | null;
  deleted_at?: string | null;
}

/** session_segments 表行 */
export interface SessionSegment {
  segment_id?: number;
  session_id?: number;
  seg_type: string;
  planned_seconds?: number;
  actual_seconds?: number | null;
  reps_done?: number | null;
  weight_kg_done?: number | null;
  rpe?: number | null;
  exercise_id?: number;
  planned_reps?: number;
  created_at?: string;
  updated_at?: string | null;
  deleted_at?: string | null;
}

/** sessions 表行 */
export interface SessionRow {
  session_id: number;
  entry_id: number | null;
  state: string;
  started_at: string | null;
  ended_at: string | null;
  completion_ratio: number;
  outcome: string | null;
  last_segment_index: number;
  created_at: string;
  updated_at: string | null;
  deleted_at: string | null;
}

/** JWT payload 结构 (与 Node-RED 契约一致) */
export interface JwtPayload {
  user_id: number;
  username: string;
  iat: number;
  exp: number;
}

/** OAuth2 扁平登录/刷新响应 */
export interface TokenResponse {
  access_token: string;
  refresh_token: string;
  token_type: 'Bearer';
  expires_in: number;
}

/** 统一业务响应: { code: 0, data, message } */
export interface ApiOkResponse<T = unknown> {
  code: 0;
  data: T;
  message: string;
}

/** 统一错误响应: { code: 1, error } */
export interface ApiErrorResponse {
  code: 1;
  error: string;
}

/** 渐进超负荷结果 */
export interface ProgressiveOverloadResult {
  newWeight: number;
  reason: string;
  isPR: boolean;
  completionRatio: number;
  avgRpe: number;
  proposal: ProposalInsert;
}

/** proposals 表 INSERT 用的结构 */
export interface ProposalInsert {
  type: string;
  lock_state: string;
  target_table: string;
  target_id: number | null;
  target_field: string | null;
  old_value: string | null;
  new_value: string | null;
  reason: string;
  created_at: string;
}

/** 冲突检测结果 */
export interface ConflictDetectionResult {
  conflicts: ScheduleEntry[];
  proposals: ProposalInsert[];
  resolved: boolean;
}
