-- database_schema_v2.sql - PROFESSIONAL SCHEMA FOR SCALABILITY
-- Uses CREATE TABLE IF NOT EXISTS to preserve historical data across runs

-- Table 1: Monitoring runs (scan metadata)
CREATE TABLE IF NOT EXISTS monitoring_runs (
    run_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    total_sdps INTEGER,
    responding_sdps INTEGER,
    offline_sdps INTEGER,
    total_alarms INTEGER,
    total_trees INTEGER,
    avg_response_time REAL,
    healthy_sdps INTEGER,
    warning_sdps INTEGER,
    critical_sdps INTEGER
);

-- Table 2: SDP status per run
CREATE TABLE IF NOT EXISTS sdp_status (
    status_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER,
    sdp_name TEXT,
    is_online INTEGER,
    alarm_count INTEGER,
    health_status TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (run_id) REFERENCES monitoring_runs(run_id)
);

-- Table 3: Alarms (flexible for all alarm types)
CREATE TABLE IF NOT EXISTS alarms (
    alarm_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER,
    severity TEXT,
    alarm_type TEXT,  -- 'low_files', 'extra_category', 'missing_tree', etc.
    sdp_list TEXT,
    sdp_count INTEGER,
    tree_name TEXT,
    category_name TEXT,
    file_count INTEGER,  -- 0, 1, or more
    issue_description TEXT,
    status TEXT DEFAULT 'Active',
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (run_id) REFERENCES monitoring_runs(run_id)
);

-- Table 4: Alarm distribution
CREATE TABLE IF NOT EXISTS alarm_distribution (
    dist_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER,
    critical_count INTEGER,
    config_mismatch_count INTEGER,
    version_diff_count INTEGER,
    low_files_count INTEGER,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (run_id) REFERENCES monitoring_runs(run_id)
);

-- Table 5: Trees (metadata per tree)
CREATE TABLE IF NOT EXISTS trees (
    tree_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER,
    tree_name TEXT,
    total_categories INTEGER,
    total_alarms INTEGER,
    affected_sdps INTEGER,
    health_status TEXT,  -- 'healthy', 'warning', 'critical'
    FOREIGN KEY (run_id) REFERENCES monitoring_runs(run_id)
);

-- Table 6: Categories (category metadata per tree)
CREATE TABLE IF NOT EXISTS categories (
    category_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER,
    tree_name TEXT,
    category_name TEXT,
    total_sdps INTEGER,
    sdps_with_0_files INTEGER,
    sdps_with_1_file INTEGER,
    sdps_with_multiple_files INTEGER,
    health_status TEXT,
    FOREIGN KEY (run_id) REFERENCES monitoring_runs(run_id)
);

-- Table 7: SDP Categories (detailed file counts per SDP per category)
CREATE TABLE IF NOT EXISTS sdp_categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER,
    sdp_name TEXT,
    tree_name TEXT,
    category_name TEXT,
    file_count INTEGER,
    status TEXT,  -- 'ok', 'warning', 'critical'
    FOREIGN KEY (run_id) REFERENCES monitoring_runs(run_id)
);

-- Indexes for performance (use IF NOT EXISTS via CREATE INDEX IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_runs_timestamp ON monitoring_runs(run_timestamp);
CREATE INDEX IF NOT EXISTS idx_alarms_run ON alarms(run_id);
CREATE INDEX IF NOT EXISTS idx_alarms_tree ON alarms(tree_name);
CREATE INDEX IF NOT EXISTS idx_alarms_type ON alarms(alarm_type);
CREATE INDEX IF NOT EXISTS idx_sdp_status_run ON sdp_status(run_id);
CREATE INDEX IF NOT EXISTS idx_trees_run ON trees(run_id);
CREATE INDEX IF NOT EXISTS idx_categories_run ON categories(run_id);
CREATE INDEX IF NOT EXISTS idx_categories_tree ON categories(tree_name);
CREATE INDEX IF NOT EXISTS idx_sdp_categories_run ON sdp_categories(run_id);
CREATE INDEX IF NOT EXISTS idx_sdp_categories_tree_cat ON sdp_categories(tree_name, category_name);

-- Views for common queries
CREATE VIEW IF NOT EXISTS v_latest_run AS
SELECT * FROM monitoring_runs ORDER BY run_timestamp DESC LIMIT 1;

CREATE VIEW IF NOT EXISTS v_latest_alarms AS
SELECT a.* FROM alarms a
INNER JOIN v_latest_run r ON a.run_id = r.run_id
WHERE a.status = 'Active'
ORDER BY
    CASE a.severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
    END,
    a.timestamp DESC;

CREATE VIEW IF NOT EXISTS v_tree_summary AS
SELECT
    t.*,
    COUNT(DISTINCT c.category_name) as category_count,
    COUNT(DISTINCT a.alarm_id) as alarm_count
FROM trees t
INNER JOIN v_latest_run r ON t.run_id = r.run_id
LEFT JOIN categories c ON c.tree_name = t.tree_name AND c.run_id = t.run_id
LEFT JOIN alarms a ON a.tree_name = t.tree_name AND a.run_id = t.run_id
GROUP BY t.tree_id;
