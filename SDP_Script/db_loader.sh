#!/bin/bash
# db_loader.sh - Definitive Legacy Loader (v7)
# Hardened against all known failure modes on legacy systems.

set -e
DB_FILE="$HOME/sdp_monitor.db"
ALARM_FILE="$HOME/ere_alarms_latest.txt"
STATS_FILE="$HOME/ere_stats_latest.txt"
ST_FILE="$HOME/sdp_status_latest.txt"
SCHEMA_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/migrations/001_initial_schema.sql"
TMP_SQL="$HOME/ere_db_load.sql"

# 1. Initialize/Migrate Schema
if [ ! -s "$DB_FILE" ]; then
    echo "Initializing new database..."
    sqlite3 "$DB_FILE" < "$SCHEMA_FILE"
else
    # Robust Migration for ip_address column
    echo "Checking schema integrity..."
    sqlite3 "$DB_FILE" "ALTER TABLE sdp_status ADD COLUMN ip_address TEXT;" 2>/dev/null || true
fi

# 2. Extract Stats Robustly (Handles labels with or without spaces/indentation)
get_stat() {
    if [ -f "$STATS_FILE" ]; then
        # Use grep -i and strip everything but the final number
        grep -i "$1" "$STATS_FILE" | sed 's/.*[:=] *//; s/[^0-9]//g' | head -1
    else
        echo 0
    fi
}

T_TREES=$(get_stat "Trees")
T_SDPS=$(get_stat "TotalSDPs")
[ "$T_SDPS" == "0" ] && T_SDPS=$(get_stat "Total SDPs")
R_SDPS=$(get_stat "Responding")
H_SDPS=$(get_stat "Healthy")
W_SDPS=$(get_stat "Warning")
C_SDPS=$(get_stat "Critical")
O_SDPS=$(get_stat "Offline")
T_ALARMS=$(get_stat "Alarms")
[ "$T_ALARMS" == "0" ] && T_ALARMS=$(grep -c "^\[ALARM\]" "$ALARM_FILE" || echo 0)

# 3. Build SQL with Mandatory Escaping
escape_sql() {
    echo "$1" | sed "s/'/''/g"
}

{
    echo "BEGIN TRANSACTION;"
    echo "INSERT INTO monitoring_runs (run_timestamp, total_sdps, responding_sdps, total_trees, total_alarms, healthy_sdps, warning_sdps, critical_sdps, offline_sdps) VALUES (datetime('now'), '${T_SDPS:-0}', '${R_SDPS:-0}', '${T_TREES:-0}', '${T_ALARMS:-0}', '${H_SDPS:-0}', '${W_SDPS:-0}', '${C_SDPS:-0}', '${O_SDPS:-0}');"
    echo "CREATE TEMPORARY TABLE _run_id AS SELECT last_insert_rowid() AS id;"

    # Process Alarms
    if [ -f "$ALARM_FILE" ]; then
        while read -r line; do
            if [[ "$line" =~ ^\[ALARM\]\ (.+)$ ]]; then
                RAW_TXT="${BASH_REMATCH[1]}"
                TXT=$(escape_sql "$RAW_TXT")
                SEV="low"
                [[ "$RAW_TXT" =~ missing\ tree ]] && SEV="critical"
                [[ "$RAW_TXT" =~ SSH\ failed ]] && SEV="critical"
                
                TREE=""; [[ "$RAW_TXT" =~ tree\ \[([^\]]+)\] ]] && TREE=$(escape_sql "${BASH_REMATCH[1]}")
                CAT=""; [[ "$RAW_TXT" =~ category\ \[([^\]]+)\] ]] && CAT=$(escape_sql "${BASH_REMATCH[1]}")
                SDP=""; [[ "$RAW_TXT" =~ ^([^-]+)\ - ]] && SDP=$(escape_sql "${BASH_REMATCH[1]}")
                
                echo "INSERT INTO alarms (run_id, severity, sdp_list, tree_name, category_name, issue_description) VALUES ((SELECT id FROM _run_id), '$SEV', '$SDP', '$TREE', '$CAT', '$TXT');"
            elif [[ "$line" =~ ^\ Affected:\ (.+)$ ]]; then
                HOSTS=$(escape_sql "${BASH_REMATCH[1]}")
                echo "UPDATE alarms SET sdp_list = '$HOSTS' WHERE alarm_id = last_insert_rowid();"
            fi
        done < "$ALARM_FILE"
    fi

    # Process SDP Status
    if [ -f "$ST_FILE" ]; then
        while IFS=',' read -r h ip hs || [ -n "$h" ]; do
            if [ -n "$h" ]; then
                H_ESC=$(escape_sql "$h")
                IP_ESC=$(escape_sql "$ip")
                HS_ESC=$(escape_sql "$hs")
                echo "INSERT INTO sdp_status (run_id, sdp_name, ip_address, health_status) VALUES ((SELECT id FROM _run_id), '$H_ESC', '$IP_ESC', '$HS_ESC');"
            fi
        done < "$ST_FILE"
    fi

    # Aggregations
    echo "INSERT INTO categories (run_id, tree_name, category_name, alarm_count) SELECT (SELECT id FROM _run_id), tree_name, category_name, COUNT(*) FROM alarms WHERE run_id=(SELECT id FROM _run_id) AND tree_name != '' AND category_name != '' GROUP BY tree_name, category_name;"
    echo "INSERT INTO trees (run_id, tree_name, alarm_count) SELECT (SELECT id FROM _run_id), tree_name, COUNT(*) FROM alarms WHERE run_id=(SELECT id FROM _run_id) AND tree_name != '' GROUP BY tree_name;"
    echo "COMMIT;"
} > "$TMP_SQL"

# 4. Execute
echo "Loading database..."
if sqlite3 "$DB_FILE" < "$TMP_SQL"; then
    echo "Database load complete."
    rm -f "$TMP_SQL"
else
    echo "ERROR: Data load failed. SQLite reported issues."
    echo "Check the generated SQL at $TMP_SQL for errors."
    exit 1
fi