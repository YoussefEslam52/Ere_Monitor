#!/bin/bash
# db_loader.sh - PRODUCTION - Loads monitoring alarms into SQLite database
# Fixes: proper alarm type classification, severity mapping, version_diff counting,
#        accurate SDP counting, and categories table population
set -e

DB_FILE="$HOME/sdp_monitor.db"
ALARM_FILE="$HOME/ere_alarms_latest.txt"
SCHEMA_FILE="$HOME/database_schema_v2.sql"

process_alarm() {
    local ALARM_TEXT="$1"
    local AFFECTED_LIST="$2"

    # Classify alarm type and severity based on alarm text patterns
    local ALARM_TYPE="unknown"
    local SEVERITY="low"

    if [[ "$ALARM_TEXT" =~ SSH\ failed ]]; then
        ALARM_TYPE="ssh_failed"
        SEVERITY="critical"
    elif [[ "$ALARM_TEXT" =~ missing\ tree ]]; then
        ALARM_TYPE="missing_tree"
        SEVERITY="critical"
    elif [[ "$ALARM_TEXT" =~ (has|have)\ extra\ category ]]; then
        ALARM_TYPE="extra_category"
        SEVERITY="high"
    elif [[ "$ALARM_TEXT" =~ missing\ reference\ category ]]; then
        ALARM_TYPE="missing_category"
        SEVERITY="high"
    elif [[ "$ALARM_TEXT" =~ version\ mismatch ]]; then
        ALARM_TYPE="version_mismatch"
        SEVERITY="medium"
    elif [[ "$ALARM_TEXT" =~ has\ 0\ files ]]; then
        ALARM_TYPE="low_files_0"
        SEVERITY="low"
    elif [[ "$ALARM_TEXT" =~ has\ only\ 1\ file ]]; then
        ALARM_TYPE="low_files_1"
        SEVERITY="low"
    fi

    # Extract tree name
    local TREE="Unknown"
    [[ "$ALARM_TEXT" =~ tree\ \[([^\]]+)\] ]] && TREE="${BASH_REMATCH[1]}"

    # Skip if no tree info and not an SSH failure (malformed alarm)
    if [[ "$TREE" == "Unknown" && "$ALARM_TYPE" != "ssh_failed" ]]; then
        return
    fi

    # Extract category
    local CATEGORY="N/A"
    if [[ "$ALARM_TEXT" =~ category\ \[([^\]]+)\] ]]; then
        CATEGORY="${BASH_REMATCH[1]}"
    fi

    # Extract file count
    local FILE_COUNT=-1
    [[ "$ALARM_TEXT" =~ has\ 0\ files ]] && FILE_COUNT=0
    [[ "$ALARM_TEXT" =~ has\ only\ 1\ file ]] && FILE_COUNT=1

    # Extract SDP prefix (text before the first " - ")
    local SDP_PREFIX=""
    [[ "$ALARM_TEXT" =~ ^([^-]+)\ -\  ]] && SDP_PREFIX=$(echo "${BASH_REMATCH[1]}" | xargs)

    # Determine SDP list and count
    local SDP_LIST="$SDP_PREFIX"
    local SDP_COUNT=1

    if [ -n "$AFFECTED_LIST" ]; then
        SDP_LIST="$AFFECTED_LIST"
        SDP_COUNT=$(echo "$SDP_LIST" | tr ',' '\n' | grep -c 'SDP')
    elif [[ "$SDP_PREFIX" =~ ^SDP[0-9]+B$ ]]; then
        SDP_LIST="$SDP_PREFIX"
        SDP_COUNT=1
    elif [[ "$SDP_PREFIX" =~ ^All ]]; then
        SDP_COUNT=44
        SDP_LIST="All SDPs"
    elif [[ "$SDP_PREFIX" =~ ([0-9]+)\ SDPs? ]]; then
        SDP_COUNT="${BASH_REMATCH[1]}"
    fi

    local ISSUE="$ALARM_TEXT"

    # Escape single quotes for SQL
    ISSUE="${ISSUE//\'/\'\'}"
    SDP_LIST="${SDP_LIST//\'/\'\'}"
    TREE="${TREE//\'/\'\'}"
    CATEGORY="${CATEGORY//\'/\'\'}"

    sqlite3 "$DB_FILE" "INSERT INTO alarms (run_id,severity,alarm_type,sdp_list,sdp_count,tree_name,category_name,file_count,issue_description,status) VALUES ($RUN_ID,'$SEVERITY','$ALARM_TYPE','$SDP_LIST',$SDP_COUNT,'$TREE','$CATEGORY',$FILE_COUNT,'$ISSUE','Active');"
    ALARM_COUNT=$((ALARM_COUNT+1))
}

[ ! -f "$SCHEMA_FILE" ] && { echo "ERROR: Schema not found"; exit 1; }
[ ! -f "$ALARM_FILE" ] && { echo "ERROR: Alarm file not found"; exit 1; }

# Initialize schema (CREATE TABLE IF NOT EXISTS - preserves history)
sqlite3 "$DB_FILE" < "$SCHEMA_FILE"

# Get total trees from latest stats file
TOTAL_TREES=18
STATS_FILE=$(ls -t "$HOME"/sdp_stats_*.txt 2>/dev/null | head -1)
if [ -z "$STATS_FILE" ] || [ ! -f "$STATS_FILE" ]; then
    STATS_FILE="$HOME/ere_stats_latest.txt"
fi
[ -f "$STATS_FILE" ] && TOTAL_TREES=$(grep "^Total Trees:" "$STATS_FILE" | awk '{print $3}' | tr -d ' \t\n\r')
TOTAL_TREES=${TOTAL_TREES:-18}

# Count alarm types from alarm file
CRITICAL_ALARMS=$(grep -c "missing tree\|SSH failed" "$ALARM_FILE" 2>/dev/null || echo 0)
CRITICAL_ALARMS=$(echo "$CRITICAL_ALARMS" | tr -d ' \t\n\r')

CONFIG_MISMATCH=$(grep -c "extra category\|missing reference category" "$ALARM_FILE" 2>/dev/null || echo 0)
CONFIG_MISMATCH=$(echo "$CONFIG_MISMATCH" | tr -d ' \t\n\r')

VERSION_DIFF=$(grep -c "version mismatch" "$ALARM_FILE" 2>/dev/null || echo 0)
VERSION_DIFF=$(echo "$VERSION_DIFF" | tr -d ' \t\n\r')

LOW_FILES=$(grep -c "has only 1 file\|has 0 files" "$ALARM_FILE" 2>/dev/null || echo 0)
LOW_FILES=$(echo "$LOW_FILES" | tr -d ' \t\n\r')

TOTAL_ALARMS=$(grep -c "^\[ALARM\]" "$ALARM_FILE" 2>/dev/null || echo 0)
TOTAL_ALARMS=$(echo "$TOTAL_ALARMS" | tr -d ' \t\n\r')

# Count SDP health using only [ALARM] lines (not Affected: lines) to avoid overcounting
OFFLINE=0; CRITICAL_SDPS=0; WARNING_SDPS=0; HEALTHY_SDPS=0
for sdp in SDP{27..70}B; do
    # Count only [ALARM] lines that mention this SDP specifically
    # Use word boundary matching to avoid SDP3 matching SDP30B etc.
    SDP_ALARMS=$(grep "^\[ALARM\]" "$ALARM_FILE" 2>/dev/null | grep -cw "$sdp" || echo 0)
    SDP_ALARMS=$(echo "$SDP_ALARMS" | tr -d ' \t\n\r')

    if grep -q "^\[ALARM\].*$sdp.*SSH failed" "$ALARM_FILE" 2>/dev/null; then
        OFFLINE=$((OFFLINE+1))
    elif [ "$SDP_ALARMS" -ge 5 ]; then
        CRITICAL_SDPS=$((CRITICAL_SDPS+1))
    elif [ "$SDP_ALARMS" -ge 1 ]; then
        WARNING_SDPS=$((WARNING_SDPS+1))
    else
        HEALTHY_SDPS=$((HEALTHY_SDPS+1))
    fi
done

TOTAL_SDPS=$((OFFLINE+CRITICAL_SDPS+WARNING_SDPS+HEALTHY_SDPS))
RESPONDING_SDPS=$((TOTAL_SDPS-OFFLINE))

# Insert monitoring run
RUN_ID=$(sqlite3 "$DB_FILE" "INSERT INTO monitoring_runs (run_timestamp,total_sdps,responding_sdps,offline_sdps,total_alarms,total_trees,avg_response_time,healthy_sdps,warning_sdps,critical_sdps) VALUES (datetime('now'),$TOTAL_SDPS,$RESPONDING_SDPS,$OFFLINE,$TOTAL_ALARMS,$TOTAL_TREES,0.0,$HEALTHY_SDPS,$WARNING_SDPS,$CRITICAL_SDPS); SELECT last_insert_rowid();")

# Insert alarm distribution with actual version_diff count
sqlite3 "$DB_FILE" "INSERT INTO alarm_distribution (run_id,critical_count,config_mismatch_count,version_diff_count,low_files_count) VALUES ($RUN_ID,$CRITICAL_ALARMS,$CONFIG_MISMATCH,$VERSION_DIFF,$LOW_FILES);"

# Process individual alarms
ALARM_COUNT=0; CURRENT_ALARM=""; CURRENT_AFFECTED=""; SKIPPED=0
while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^\[ALARM\]\ (.+)$ ]]; then
        if [ -n "$CURRENT_ALARM" ]; then
            BEFORE=$ALARM_COUNT
            process_alarm "$CURRENT_ALARM" "$CURRENT_AFFECTED"
            [ $ALARM_COUNT -eq $BEFORE ] && { SKIPPED=$((SKIPPED+1)); echo "SKIP: $CURRENT_ALARM" >&2; }
        fi
        CURRENT_ALARM="${BASH_REMATCH[1]}"
        CURRENT_AFFECTED=""
    elif [[ "$line" =~ ^[[:space:]]+Affected:[[:space:]]*(.+)$ ]]; then
        CURRENT_AFFECTED="${BASH_REMATCH[1]}"
    fi
done < "$ALARM_FILE"

# Process last alarm
if [ -n "$CURRENT_ALARM" ]; then
    BEFORE=$ALARM_COUNT
    process_alarm "$CURRENT_ALARM" "$CURRENT_AFFECTED"
    [ $ALARM_COUNT -eq $BEFORE ] && { SKIPPED=$((SKIPPED+1)); echo "SKIP: $CURRENT_ALARM" >&2; }
fi

# Populate trees table from alarms
sqlite3 "$DB_FILE" "INSERT INTO trees (run_id,tree_name,total_categories,total_alarms,affected_sdps,health_status)
SELECT run_id,tree_name,COUNT(DISTINCT category_name),COUNT(*),SUM(sdp_count),
    CASE
        WHEN SUM(CASE WHEN severity='critical' THEN 1 ELSE 0 END)>0 THEN 'critical'
        WHEN SUM(CASE WHEN severity='high' THEN 1 ELSE 0 END)>0 THEN 'warning'
        ELSE 'healthy'
    END
FROM alarms
WHERE run_id=$RUN_ID AND tree_name!='Unknown'
GROUP BY run_id,tree_name;"

# Populate categories table from alarms
sqlite3 "$DB_FILE" "INSERT INTO categories (run_id,tree_name,category_name,total_sdps,sdps_with_0_files,sdps_with_1_file,sdps_with_multiple_files,health_status)
SELECT
    run_id,
    tree_name,
    category_name,
    SUM(sdp_count),
    SUM(CASE WHEN file_count=0 THEN sdp_count ELSE 0 END),
    SUM(CASE WHEN file_count=1 THEN sdp_count ELSE 0 END),
    SUM(CASE WHEN file_count>1 THEN sdp_count ELSE 0 END),
    CASE
        WHEN SUM(CASE WHEN file_count=0 THEN 1 ELSE 0 END) > 0 THEN 'critical'
        WHEN SUM(CASE WHEN severity IN ('high','critical') THEN 1 ELSE 0 END) > 0 THEN 'warning'
        WHEN SUM(CASE WHEN file_count=1 THEN 1 ELSE 0 END) > 0 THEN 'warning'
        ELSE 'healthy'
    END
FROM alarms
WHERE run_id=$RUN_ID AND tree_name!='Unknown' AND category_name!='N/A'
GROUP BY run_id,tree_name,category_name;"

# Populate SDP status
for sdp in SDP{27..70}B; do
    IS_ONLINE=1
    SDP_ALARMS=$(grep "^\[ALARM\]" "$ALARM_FILE" 2>/dev/null | grep -cw "$sdp" || echo 0)
    SDP_ALARMS=$(echo "$SDP_ALARMS" | tr -d ' \t\n\r')
    HEALTH="healthy"

    if grep -q "^\[ALARM\].*$sdp.*SSH failed" "$ALARM_FILE" 2>/dev/null; then
        IS_ONLINE=0
        HEALTH="offline"
    elif [ "$SDP_ALARMS" -ge 5 ]; then
        HEALTH="critical"
    elif [ "$SDP_ALARMS" -ge 1 ]; then
        HEALTH="warning"
    fi

    sqlite3 "$DB_FILE" "INSERT INTO sdp_status (run_id,sdp_name,is_online,alarm_count,health_status) VALUES ($RUN_ID,'$sdp',$IS_ONLINE,$SDP_ALARMS,'$HEALTH');"
done

# Prune old data (keep last 30 days to prevent unbounded growth)
sqlite3 "$DB_FILE" "DELETE FROM alarms WHERE run_id IN (SELECT run_id FROM monitoring_runs WHERE run_timestamp < datetime('now','-30 days'));
DELETE FROM sdp_status WHERE run_id IN (SELECT run_id FROM monitoring_runs WHERE run_timestamp < datetime('now','-30 days'));
DELETE FROM alarm_distribution WHERE run_id IN (SELECT run_id FROM monitoring_runs WHERE run_timestamp < datetime('now','-30 days'));
DELETE FROM trees WHERE run_id IN (SELECT run_id FROM monitoring_runs WHERE run_timestamp < datetime('now','-30 days'));
DELETE FROM categories WHERE run_id IN (SELECT run_id FROM monitoring_runs WHERE run_timestamp < datetime('now','-30 days'));
DELETE FROM sdp_categories WHERE run_id IN (SELECT run_id FROM monitoring_runs WHERE run_timestamp < datetime('now','-30 days'));
DELETE FROM monitoring_runs WHERE run_timestamp < datetime('now','-30 days');"

echo "Database loaded: $ALARM_COUNT alarms inserted ($SKIPPED skipped), run_id=$RUN_ID"
