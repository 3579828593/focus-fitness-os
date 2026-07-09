-- ===== Focus Fitness OS - D1 初始迁移 =====
-- 从 Node-RED SQLite 迁移到 Cloudflare D1
-- 13 张表 (10 客户端镜像表 + proposals + users + refresh_tokens) + 10 个索引

-- 客户端镜像表 (与 Drift schema 对齐, snake_case)
CREATE TABLE IF NOT EXISTS executable_units (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  unit_type TEXT NOT NULL,
  title TEXT NOT NULL,
  priority INTEGER DEFAULT 3,
  expected_minutes INTEGER NOT NULL,
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT '2026-01-01T00:00:00',
  updated_at TEXT,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS learning_task_exts (
  unit_id INTEGER PRIMARY KEY REFERENCES executable_units(id) ON DELETE CASCADE,
  task_kind TEXT NOT NULL,
  focus_minutes INTEGER DEFAULT 25,
  break_minutes INTEGER DEFAULT 5,
  created_at TEXT DEFAULT '2026-01-01T00:00:00',
  updated_at TEXT,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS workout_plan_exts (
  unit_id INTEGER PRIMARY KEY REFERENCES executable_units(id) ON DELETE CASCADE,
  workout_kind TEXT NOT NULL,
  target_muscle TEXT,
  created_at TEXT DEFAULT '2026-01-01T00:00:00',
  updated_at TEXT,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS workout_exercises (
  exercise_id INTEGER PRIMARY KEY AUTOINCREMENT,
  unit_id INTEGER REFERENCES executable_units(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  planned_sets INTEGER NOT NULL,
  planned_reps INTEGER NOT NULL,
  planned_weight REAL NOT NULL,
  rest_seconds INTEGER DEFAULT 90,
  rpe REAL,
  created_at TEXT DEFAULT '2026-01-01T00:00:00',
  updated_at TEXT,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS schedule_entries (
  entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
  unit_id INTEGER REFERENCES executable_units(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  start_time TEXT NOT NULL,
  exec_mode TEXT NOT NULL,
  is_baseline INTEGER DEFAULT 0,
  lock_state TEXT DEFAULT 'OPEN',
  created_at TEXT DEFAULT '2026-01-01T00:00:00',
  updated_at TEXT,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS sessions (
  session_id INTEGER PRIMARY KEY AUTOINCREMENT,
  entry_id INTEGER REFERENCES schedule_entries(entry_id) ON DELETE CASCADE,
  state TEXT DEFAULT 'CREATED',
  started_at TEXT,
  ended_at TEXT,
  completion_ratio REAL DEFAULT 0.0,
  outcome TEXT,
  last_segment_index INTEGER DEFAULT 0,
  created_at TEXT DEFAULT '2026-01-01T00:00:00',
  updated_at TEXT,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS session_segments (
  segment_id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER REFERENCES sessions(session_id) ON DELETE CASCADE,
  seg_type TEXT NOT NULL,
  planned_seconds INTEGER NOT NULL,
  actual_seconds INTEGER,
  reps_done INTEGER,
  weight_kg_done REAL,
  created_at TEXT DEFAULT '2026-01-01T00:00:00',
  updated_at TEXT,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS goals (
  goal_id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  target_value REAL NOT NULL,
  current_value REAL DEFAULT 0.0,
  unit TEXT NOT NULL,
  status TEXT DEFAULT 'ACTIVE',
  created_at TEXT DEFAULT '2026-01-01T00:00:00',
  updated_at TEXT,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS streaks (
  streak_id INTEGER PRIMARY KEY AUTOINCREMENT,
  unit_id INTEGER REFERENCES executable_units(id) ON DELETE CASCADE,
  current_count INTEGER DEFAULT 0,
  longest_count INTEGER DEFAULT 0,
  last_date TEXT,
  created_at TEXT DEFAULT '2026-01-01T00:00:00',
  updated_at TEXT,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS op_logs (
  op_id INTEGER PRIMARY KEY AUTOINCREMENT,
  tbl_name TEXT NOT NULL,
  record_id INTEGER NOT NULL,
  op_type TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT DEFAULT '2026-01-01T00:00:00',
  synced INTEGER DEFAULT 0,
  device_id TEXT,
  lamport_clock INTEGER DEFAULT 0
);

-- 服务端独有表
CREATE TABLE IF NOT EXISTS proposals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  lock_state TEXT DEFAULT 'PENDING',
  target_table TEXT NOT NULL,
  target_id INTEGER,
  target_field TEXT,
  old_value TEXT,
  new_value TEXT,
  reason TEXT,
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS users (
  user_id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TEXT DEFAULT '2026-01-01T00:00:00',
  updated_at TEXT
);

-- Refresh Token 存储 (替代文件系统)
CREATE TABLE IF NOT EXISTS refresh_tokens (
  token TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  username TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_schedule_date_time ON schedule_entries(date, start_time);
CREATE INDEX IF NOT EXISTS idx_session_entry_state ON sessions(entry_id, state);
CREATE INDEX IF NOT EXISTS idx_segment_session ON session_segments(session_id, segment_id);
CREATE INDEX IF NOT EXISTS idx_oplog_synced ON op_logs(synced, created_at);
CREATE INDEX IF NOT EXISTS idx_exercise_unit ON workout_exercises(unit_id);
CREATE INDEX IF NOT EXISTS idx_streak_unit_date ON streaks(unit_id, last_date);
CREATE INDEX IF NOT EXISTS idx_schedule_active ON schedule_entries(date, deleted_at);
CREATE INDEX IF NOT EXISTS idx_session_active ON sessions(entry_id, deleted_at);
CREATE INDEX IF NOT EXISTS idx_refresh_expires ON refresh_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_proposals_lock_state ON proposals(lock_state, created_at);

-- 初始用户 (密码需用 PBKDF2 重新哈希后插入)
-- INSERT INTO users (username, password_hash) VALUES ('admin', '[PBKDF2 hash]');
