-- FunnyNetwork schema (MariaDB 10.11+ / MySQL 8+)
-- Charset: utf8mb4
-- Apply on database: funny_global
-- Mode-local DBs: funny_surv, funny_sb, funny_ana, funny_prison, funny_farm, funny_bw, ...

CREATE DATABASE IF NOT EXISTS funny_global CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE funny_global;

-- ─── Players ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS players (
  uuid            BINARY(16) PRIMARY KEY,
  name            VARCHAR(16) NOT NULL,
  name_lower      VARCHAR(16) NOT NULL,
  first_join      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_join       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_server     VARCHAR(64) NULL,
  lang            CHAR(5) NOT NULL DEFAULT 'ru',
  prestige        INT NOT NULL DEFAULT 0,
  settings_json   JSON NULL,
  UNIQUE KEY uq_name_lower (name_lower),
  KEY idx_last_join (last_join)
) ENGINE=InnoDB;

-- ─── FunnyCoins ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS funny_coins (
  uuid            BINARY(16) PRIMARY KEY,
  balance         BIGINT NOT NULL DEFAULT 0,
  lifetime_earned BIGINT NOT NULL DEFAULT 0,
  lifetime_spent  BIGINT NOT NULL DEFAULT 0,
  updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_fc_player FOREIGN KEY (uuid) REFERENCES players(uuid)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS eco_ledger (
  id           BIGINT AUTO_INCREMENT PRIMARY KEY,
  txn_id       CHAR(36) NOT NULL,
  uuid         BINARY(16) NOT NULL,
  currency     VARCHAR(32) NOT NULL,
  delta        BIGINT NOT NULL,
  balance_after BIGINT NOT NULL,
  reason       VARCHAR(64) NOT NULL,
  actor        VARCHAR(64) NULL,
  server_id    VARCHAR(64) NOT NULL,
  meta_json    JSON NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_txn (txn_id),
  KEY idx_uuid_time (uuid, created_at),
  KEY idx_currency_time (currency, created_at)
) ENGINE=InnoDB;

-- ─── Cosmetics / Titles ────────────────────────────────────
CREATE TABLE IF NOT EXISTS cosmetics_owned (
  uuid         BINARY(16) NOT NULL,
  cosmetic_id  VARCHAR(64) NOT NULL,
  obtained_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (uuid, cosmetic_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cosmetics_selected (
  uuid         BINARY(16) PRIMARY KEY,
  hat          VARCHAR(64) NULL,
  cloak        VARCHAR(64) NULL,
  trail        VARCHAR(64) NULL,
  kill_effect  VARCHAR(64) NULL,
  join_msg     VARCHAR(64) NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS titles_owned (
  uuid       BINARY(16) NOT NULL,
  title_id   VARCHAR(64) NOT NULL,
  PRIMARY KEY (uuid, title_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS titles_active (
  uuid       BINARY(16) PRIMARY KEY,
  title_id   VARCHAR(64) NULL
) ENGINE=InnoDB;

-- ─── Achievements ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS achievements (
  uuid            BINARY(16) NOT NULL,
  achievement_id  VARCHAR(64) NOT NULL,
  progress        INT NOT NULL DEFAULT 0,
  completed_at    TIMESTAMP NULL,
  PRIMARY KEY (uuid, achievement_id)
) ENGINE=InnoDB;

-- ─── Crate keys ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS crate_keys (
  uuid       BINARY(16) NOT NULL,
  key_type   VARCHAR(32) NOT NULL,
  amount     INT NOT NULL DEFAULT 0,
  PRIMARY KEY (uuid, key_type)
) ENGINE=InnoDB;

-- ─── Clans ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS clans (
  id           BIGINT AUTO_INCREMENT PRIMARY KEY,
  tag          VARCHAR(8) NOT NULL,
  name         VARCHAR(32) NOT NULL,
  owner_uuid   BINARY(16) NOT NULL,
  bank_fc      BIGINT NOT NULL DEFAULT 0,
  level        INT NOT NULL DEFAULT 1,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_tag (tag)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS clan_members (
  clan_id     BIGINT NOT NULL,
  uuid        BINARY(16) NOT NULL,
  role        ENUM('owner','officer','member') NOT NULL DEFAULT 'member',
  joined_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (uuid),
  KEY idx_clan (clan_id),
  CONSTRAINT fk_cm_clan FOREIGN KEY (clan_id) REFERENCES clans(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ─── Quests ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS quest_progress (
  uuid        BINARY(16) NOT NULL,
  quest_id    VARCHAR(64) NOT NULL,
  period_key  CHAR(10) NOT NULL, -- e.g. 2026-07-19 or 2026-W29
  progress    INT NOT NULL DEFAULT 0,
  completed   TINYINT(1) NOT NULL DEFAULT 0,
  claimed     TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (uuid, quest_id, period_key)
) ENGINE=InnoDB;

-- ─── Reports ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reports (
  id           BIGINT AUTO_INCREMENT PRIMARY KEY,
  reporter     BINARY(16) NOT NULL,
  target       BINARY(16) NOT NULL,
  reason       VARCHAR(64) NOT NULL,
  details      VARCHAR(512) NULL,
  server_id    VARCHAR(64) NOT NULL,
  status       ENUM('open','claimed','closed') NOT NULL DEFAULT 'open',
  staff_uuid   BINARY(16) NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_status (status, created_at)
) ENGINE=InnoDB;

-- ─── Tebex idempotency ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS tebex_transactions (
  txn_id       VARCHAR(64) PRIMARY KEY,
  uuid         BINARY(16) NOT NULL,
  package_id   VARCHAR(64) NOT NULL,
  processed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ─── Minigame stats (BedWars example) ──────────────────────
CREATE TABLE IF NOT EXISTS stats_bedwars (
  uuid         BINARY(16) NOT NULL,
  season_id    INT NOT NULL,
  wins         INT NOT NULL DEFAULT 0,
  losses       INT NOT NULL DEFAULT 0,
  kills        INT NOT NULL DEFAULT 0,
  final_kills  INT NOT NULL DEFAULT 0,
  beds         INT NOT NULL DEFAULT 0,
  winstreak    INT NOT NULL DEFAULT 0,
  rating       INT NOT NULL DEFAULT 1000,
  PRIMARY KEY (uuid, season_id),
  KEY idx_rating (season_id, rating DESC)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS stats_skywars (
  uuid         BINARY(16) NOT NULL,
  season_id    INT NOT NULL,
  wins         INT NOT NULL DEFAULT 0,
  kills        INT NOT NULL DEFAULT 0,
  deaths       INT NOT NULL DEFAULT 0,
  rating       INT NOT NULL DEFAULT 1000,
  PRIMARY KEY (uuid, season_id),
  KEY idx_sw_rating (season_id, rating DESC)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS seasons (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  mode         VARCHAR(32) NOT NULL,
  name         VARCHAR(64) NOT NULL,
  starts_at    TIMESTAMP NOT NULL,
  ends_at      TIMESTAMP NOT NULL
) ENGINE=InnoDB;

-- ═══════════════════════════════════════════════════════════
-- Mode-local example: funny_surv
-- ═══════════════════════════════════════════════════════════
CREATE DATABASE IF NOT EXISTS funny_surv CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE funny_surv;

CREATE TABLE IF NOT EXISTS surv_balance (
  uuid     BINARY(16) PRIMARY KEY,
  balance  DECIMAL(20,2) NOT NULL DEFAULT 0
) ENGINE=InnoDB;

-- Inventory blobs if using FunnySync SQL backend
CREATE TABLE IF NOT EXISTS surv_inventory (
  uuid          BINARY(16) PRIMARY KEY,
  inventory_b64 MEDIUMBLOB NOT NULL,
  ender_b64     MEDIUMBLOB NULL,
  xp            INT NOT NULL DEFAULT 0,
  level         INT NOT NULL DEFAULT 0,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ═══════════════════════════════════════════════════════════
-- Mode-local example: funny_sb
-- ═══════════════════════════════════════════════════════════
CREATE DATABASE IF NOT EXISTS funny_sb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE funny_sb;

CREATE TABLE IF NOT EXISTS sb_balance (
  uuid     BINARY(16) PRIMARY KEY,
  balance  DECIMAL(20,2) NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sb_islands (
  island_id    BINARY(16) PRIMARY KEY,
  owner_uuid   BINARY(16) NOT NULL,
  level        INT NOT NULL DEFAULT 0,
  bank         DECIMAL(20,2) NOT NULL DEFAULT 0,
  schematic    VARCHAR(64) NOT NULL DEFAULT 'default',
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_owner (owner_uuid),
  KEY idx_level (level DESC)
) ENGINE=InnoDB;

-- Note: LuckPerms, LiteBans, CoreProtect create their own schemas/tables.
-- Point each plugin to dedicated DB users with least privilege.
