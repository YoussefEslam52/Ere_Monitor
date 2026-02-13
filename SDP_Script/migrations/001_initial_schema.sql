-- Migrations: 001_initial_schema.sql
-- Description: Initial schema for Ere Monitor v1.0
-- Author: Gemini
-- Date: 2026-02-13

-- Monitoring Runs
CREATE TABLE IF NOT EXISTS monitoring_runs (
    run_id INTEGER PRIMARY KEY AUTOINCREMENT,
    total_sdps INTEGER DEFAULT 0,
    responding_sdps INTEGER DEFAULT 0,
    total_trees INTEGER DEFAULT 0,
    total_alarms INTEGER DEFAULT 0,
    healthy_sdps INTEGER DEFAULT 0,
    warning_sdps INTEGER DEFAULT 0,
    critical_sdps INTEGER DEFAULT 0,
    offline_sdps INTEGER DEFAULT 0,
    avg_response_time DECIMAL(5,2) DEFAULT 0.00,
    run_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Alarms
CREATE TABLE IF NOT EXISTS alarms (
    alarm_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER,
    severity TEXT CHECK(severity IN ('critical', 'warning', 'low')) DEFAULT 'low',
    alarm_type TEXT,
    sdp_list TEXT,
    sdp_count INTEGER DEFAULT 0,
    tree_name TEXT,
    category_name TEXT,
    file_count INTEGER DEFAULT 0,
    issue_description TEXT,
    status TEXT CHECK(status IN ('Active', 'Resolved', 'Acknowledged')) DEFAULT 'Active',
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(run_id) REFERENCES monitoring_runs(run_id) ON DELETE CASCADE
);

-- SDP Status
CREATE TABLE IF NOT EXISTS sdp_status (
    status_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER,
    sdp_name TEXT,
    ip_address TEXT,
    health_status TEXT CHECK(health_status IN ('healthy', 'warning', 'critical', 'offline')),
    health_level INTEGER DEFAULT 100,
    alarm_count INTEGER DEFAULT 0,
    last_checked DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(run_id) REFERENCES monitoring_runs(run_id) ON DELETE CASCADE
);

-- Trees
CREATE TABLE IF NOT EXISTS trees (
    tree_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER,
    tree_name TEXT,
    alarm_count INTEGER DEFAULT 0,
    category_count INTEGER DEFAULT 0,
    affected_sdps INTEGER DEFAULT 0,
    FOREIGN KEY(run_id) REFERENCES monitoring_runs(run_id) ON DELETE CASCADE
);

-- Categories (Per Tree/Run)
CREATE TABLE IF NOT EXISTS categories (
    category_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER,
    tree_name TEXT,
    category_name TEXT,
    alarm_count INTEGER DEFAULT 0,
    FOREIGN KEY(run_id) REFERENCES monitoring_runs(run_id) ON DELETE CASCADE
);

-- Indexing for Performance
CREATE INDEX IF NOT EXISTS idx_alarms_run_id ON alarms(run_id);
CREATE INDEX IF NOT EXISTS idx_alarms_tree_name ON alarms(tree_name);
CREATE INDEX IF NOT EXISTS idx_alarms_severity ON alarms(severity);
CREATE INDEX IF NOT EXISTS idx_sdp_status_run ON sdp_status(run_id);
CREATE INDEX IF NOT EXISTS idx_monitoring_runs_ts ON monitoring_runs(run_timestamp);
