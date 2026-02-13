<?php
/**
 * SDP Monitor API - PHP 5.4 COMPATIBLE VERSION
 * Endpoints: dashboard, alarms, sdp_status, trees, tree_detail, diagnostic, sdp_alarms
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Cache-Control: no-cache, must-revalidate');

$db_file = dirname(__FILE__) . '/data/sdp_monitor.db';

if (!file_exists($db_file)) {
    http_response_code(500);
    die(json_encode(array('error' => 'Database not found', 'path' => $db_file)));
}

try {
    $db = new PDO('sqlite:' . $db_file);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    http_response_code(500);
    die(json_encode(array('error' => 'Database connection failed', 'message' => $e->getMessage())));
}

$action = 'dashboard';
if (isset($_GET['action'])) {
    $action = $_GET['action'];
}

if ($action === 'dashboard') {
    $result = getDashboardData($db);
    echo json_encode($result);
} elseif ($action === 'alarms') {
    $limit = 20;
    if (isset($_GET['limit'])) {
        $limit = (int)$_GET['limit'];
    }
    $result = getRecentAlarms($db, $limit);
    echo json_encode($result);
} elseif ($action === 'sdp_status') {
    $result = getSDPStatus($db);
    echo json_encode($result);
} elseif ($action === 'trees') {
    $result = getTreeList($db);
    echo json_encode($result);
} elseif ($action === 'tree_detail') {
    $tree = isset($_GET['tree']) ? $_GET['tree'] : '';
    $result = getTreeDetail($db, $tree);
    echo json_encode($result);
} elseif ($action === 'diagnostic') {
    $result = getDiagnosticData($db);
    echo json_encode($result);
} elseif ($action === 'sdp_alarms') {
    $sdp = isset($_GET['sdp']) ? $_GET['sdp'] : '';
    $result = getSDPAlarms($db, $sdp);
    echo json_encode($result);
} else {
    http_response_code(400);
    echo json_encode(array('error' => 'Invalid action'));
}


/**
 * Get dashboard data
 */
function getDashboardData($db) {
    try {
        $stmt = $db->query("SELECT * FROM monitoring_runs ORDER BY run_timestamp DESC LIMIT 1");
        $latest_run = $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        return array('error' => 'Query failed', 'message' => $e->getMessage());
    }

    if (!$latest_run) {
        return array('error' => 'No monitoring data available');
    }

    $run_id = $latest_run['run_id'];

    // Get alarm distribution
    $alarm_dist = null;
    try {
        $stmt = $db->prepare("SELECT * FROM alarm_distribution WHERE run_id = ?");
        $stmt->execute(array($run_id));
        $alarm_dist = $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        // Continue without alarm distribution
    }

    // Get recent alarms
    $recent_alarms = array();
    try {
        $stmt = $db->prepare("SELECT * FROM alarms WHERE run_id = ? AND status = 'Active' ORDER BY
            CASE severity
                WHEN 'critical' THEN 1
                WHEN 'high' THEN 2
                WHEN 'medium' THEN 3
                WHEN 'low' THEN 4
            END,
            alarm_id DESC LIMIT 10");
        $stmt->execute(array($run_id));
        $recent_alarms = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        // Continue without alarms
    }

    // Get 7-day trend
    $trend_detail = array();
    try {
        $stmt = $db->query("
            SELECT DATE(mr.run_timestamp) as date,
                MAX(COALESCE(ad.config_mismatch_count, 0)) as config_mismatch,
                MAX(COALESCE(ad.low_files_count, 0)) as low_files
            FROM monitoring_runs mr
            LEFT JOIN alarm_distribution ad ON mr.run_id = ad.run_id
            WHERE mr.run_timestamp >= datetime('now', '-7 days')
            GROUP BY DATE(mr.run_timestamp)
            ORDER BY date
        ");
        $trend_detail = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        // Continue without trend
    }

    // Format dates for chart
    $dates = array();
    $config_mismatches = array();
    $low_files_array = array();
    if (count($trend_detail) > 0) {
        foreach ($trend_detail as $row) {
            $dates[] = date('M j', strtotime($row['date']));
            $config_mismatches[] = (int)$row['config_mismatch'];
            $low_files_array[] = (int)$row['low_files'];
        }
    }

    // Fill to 7 days
    while (count($dates) < 7) {
        $days_ago = 7 - count($dates);
        array_unshift($dates, date('M j', strtotime('-' . $days_ago . ' days')));
        array_unshift($config_mismatches, 0);
        array_unshift($low_files_array, 0);
    }

    // Format alarms
    $formatted_alarms = array();
    foreach ($recent_alarms as $alarm) {
        $sdp_display = $alarm['sdp_list'];
        if ($alarm['sdp_count'] > 1 && strpos($alarm['sdp_list'], ',') !== false) {
            $sdp_display = $alarm['sdp_count'] . ' SDPs';
        }

        $formatted_alarms[] = array(
            'time' => date('H:i', strtotime($alarm['timestamp'])),
            'severity' => $alarm['severity'],
            'alarm_type' => $alarm['alarm_type'],
            'sdp' => $sdp_display,
            'sdp_count' => (int)$alarm['sdp_count'],
            'sdp_list' => $alarm['sdp_list'],
            'tree' => $alarm['tree_name'],
            'category' => $alarm['category_name'],
            'file_count' => (int)$alarm['file_count'],
            'issue' => $alarm['issue_description'],
            'status' => $alarm['status']
        );
    }

    // Extract alarm distribution counts
    $critical_count = 0;
    $config_mismatch_count = 0;
    $version_diff_count = 0;
    $low_files_count = 0;

    if ($alarm_dist !== null && is_array($alarm_dist)) {
        if (isset($alarm_dist['critical_count'])) {
            $critical_count = (int)$alarm_dist['critical_count'];
        }
        if (isset($alarm_dist['config_mismatch_count'])) {
            $config_mismatch_count = (int)$alarm_dist['config_mismatch_count'];
        }
        if (isset($alarm_dist['version_diff_count'])) {
            $version_diff_count = (int)$alarm_dist['version_diff_count'];
        }
        if (isset($alarm_dist['low_files_count'])) {
            $low_files_count = (int)$alarm_dist['low_files_count'];
        }
    }

    $total_trees = (int)$latest_run['total_trees'];

    return array(
        'timestamp' => $latest_run['run_timestamp'],
        'stats' => array(
            'total_sdps' => (int)$latest_run['total_sdps'],
            'responding_sdps' => (int)$latest_run['responding_sdps'],
            'total_trees' => $total_trees,
            'total_alarms' => (int)$latest_run['total_alarms'],
            'avg_response_time' => (float)$latest_run['avg_response_time']
        ),
        'health' => array(
            'healthy' => (int)$latest_run['healthy_sdps'],
            'warning' => (int)$latest_run['warning_sdps'],
            'critical' => (int)$latest_run['critical_sdps'],
            'offline' => (int)$latest_run['offline_sdps']
        ),
        'alarm_distribution' => array(
            'critical' => $critical_count,
            'config_mismatch' => $config_mismatch_count,
            'version_diff' => $version_diff_count,
            'low_files' => $low_files_count
        ),
        'recent_alarms' => $formatted_alarms,
        'trend_data' => array(
            'dates' => $dates,
            'config_mismatches' => $config_mismatches,
            'low_files' => $low_files_array
        )
    );
}


/**
 * Get recent alarms
 */
function getRecentAlarms($db, $limit) {
    try {
        $stmt = $db->prepare("
            SELECT a.*, mr.run_timestamp
            FROM alarms a
            INNER JOIN monitoring_runs mr ON a.run_id = mr.run_id
            WHERE a.run_id = (SELECT MAX(run_id) FROM monitoring_runs)
            AND a.status = 'Active'
            ORDER BY
                CASE a.severity
                    WHEN 'critical' THEN 1
                    WHEN 'high' THEN 2
                    WHEN 'medium' THEN 3
                    WHEN 'low' THEN 4
                END,
                a.alarm_id DESC
            LIMIT ?
        ");
        $stmt->execute(array($limit));
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        return array('error' => 'Query failed', 'message' => $e->getMessage());
    }
}


/**
 * Get SDP status details
 */
function getSDPStatus($db) {
    try {
        $stmt = $db->query("SELECT run_id FROM monitoring_runs ORDER BY run_timestamp DESC LIMIT 1");
        $run = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$run) {
            return array('error' => 'No monitoring data');
        }

        $run_id = $run['run_id'];

        $stmt = $db->prepare("
            SELECT sdp_name, is_online, alarm_count, health_status
            FROM sdp_status
            WHERE run_id = ?
            ORDER BY
                CASE health_status
                    WHEN 'critical' THEN 1
                    WHEN 'warning' THEN 2
                    WHEN 'healthy' THEN 3
                    WHEN 'offline' THEN 4
                END, sdp_name
        ");
        $stmt->execute(array($run_id));
        $sdps = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $grouped = array(
            'healthy' => array(),
            'warning' => array(),
            'critical' => array(),
            'offline' => array()
        );

        foreach ($sdps as $sdp) {
            $status = $sdp['health_status'];
            if (isset($grouped[$status])) {
                $grouped[$status][] = $sdp;
            }
        }

        return array(
            'sdps' => $sdps,
            'grouped' => $grouped,
            'counts' => array(
                'healthy' => count($grouped['healthy']),
                'warning' => count($grouped['warning']),
                'critical' => count($grouped['critical']),
                'offline' => count($grouped['offline'])
            )
        );
    } catch (Exception $e) {
        return array('error' => 'Query failed', 'message' => $e->getMessage());
    }
}


/**
 * Get tree list with statistics
 */
function getTreeList($db) {
    try {
        $stmt = $db->query("SELECT run_id FROM monitoring_runs ORDER BY run_timestamp DESC LIMIT 1");
        $run = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$run) {
            return array('error' => 'No monitoring data');
        }

        $run_id = $run['run_id'];

        $stmt = $db->prepare("
            SELECT tree_name,
                   total_alarms as alarm_count,
                   total_categories as category_count,
                   affected_sdps,
                   health_status
            FROM trees
            WHERE run_id = ?
            ORDER BY total_alarms DESC
        ");
        $stmt->execute(array($run_id));
        $trees = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return array(
            'trees' => $trees,
            'total' => count($trees)
        );
    } catch (Exception $e) {
        return array('error' => 'Query failed', 'message' => $e->getMessage());
    }
}


/**
 * Get detailed data for a specific tree - categories, alarms, SDP impact
 */
function getTreeDetail($db, $tree_name) {
    if (empty($tree_name)) {
        return array('error' => 'Tree name required');
    }

    try {
        $stmt = $db->query("SELECT run_id FROM monitoring_runs ORDER BY run_timestamp DESC LIMIT 1");
        $run = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$run) {
            return array('error' => 'No monitoring data');
        }

        $run_id = $run['run_id'];

        // Get tree summary
        $stmt = $db->prepare("SELECT * FROM trees WHERE run_id = ? AND tree_name = ?");
        $stmt->execute(array($run_id, $tree_name));
        $tree = $stmt->fetch(PDO::FETCH_ASSOC);

        // Get categories for this tree
        $categories = array();
        $stmt = $db->prepare("
            SELECT category_name, total_sdps, sdps_with_0_files, sdps_with_1_file,
                   sdps_with_multiple_files, health_status
            FROM categories
            WHERE run_id = ? AND tree_name = ?
            ORDER BY
                CASE health_status
                    WHEN 'critical' THEN 1
                    WHEN 'warning' THEN 2
                    WHEN 'healthy' THEN 3
                END,
                category_name
        ");
        $stmt->execute(array($run_id, $tree_name));
        $categories = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Get alarms for this tree
        $stmt = $db->prepare("
            SELECT alarm_id, severity, alarm_type, sdp_list, sdp_count,
                   category_name, file_count, issue_description
            FROM alarms
            WHERE run_id = ? AND tree_name = ? AND status = 'Active'
            ORDER BY
                CASE severity
                    WHEN 'critical' THEN 1
                    WHEN 'high' THEN 2
                    WHEN 'medium' THEN 3
                    WHEN 'low' THEN 4
                END,
                alarm_id
        ");
        $stmt->execute(array($run_id, $tree_name));
        $alarms = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Calculate severity breakdown
        $severity_counts = array('critical' => 0, 'high' => 0, 'medium' => 0, 'low' => 0);
        $alarm_type_counts = array();
        $affected_sdps = array();

        foreach ($alarms as $alarm) {
            $sev = $alarm['severity'];
            if (isset($severity_counts[$sev])) {
                $severity_counts[$sev]++;
            }

            $atype = $alarm['alarm_type'];
            if (!isset($alarm_type_counts[$atype])) {
                $alarm_type_counts[$atype] = 0;
            }
            $alarm_type_counts[$atype]++;

            // Parse SDP list for impact analysis
            if (preg_match_all('/SDP\d+B/', $alarm['sdp_list'], $matches)) {
                foreach ($matches[0] as $sdp) {
                    if (!isset($affected_sdps[$sdp])) {
                        $affected_sdps[$sdp] = 0;
                    }
                    $affected_sdps[$sdp]++;
                }
            }
        }

        // Sort SDPs by alarm count descending
        arsort($affected_sdps);

        // Format SDP impact as array
        $sdp_impact = array();
        foreach ($affected_sdps as $sdp => $count) {
            $sdp_impact[] = array('sdp' => $sdp, 'alarm_count' => $count);
        }

        // Calculate file status from categories
        $file_status = array('zero' => 0, 'one' => 0, 'multiple' => 0);
        foreach ($categories as $cat) {
            if ((int)$cat['sdps_with_0_files'] > 0) {
                $file_status['zero']++;
            }
            if ((int)$cat['sdps_with_1_file'] > 0) {
                $file_status['one']++;
            }
            if ((int)$cat['sdps_with_multiple_files'] > 0) {
                $file_status['multiple']++;
            }
        }

        return array(
            'tree' => $tree,
            'categories' => $categories,
            'alarms' => $alarms,
            'severity_counts' => $severity_counts,
            'alarm_type_counts' => $alarm_type_counts,
            'sdp_impact' => array_slice($sdp_impact, 0, 15),
            'file_status' => $file_status,
            'total_alarms' => count($alarms),
            'total_categories' => count($categories),
            'total_affected_sdps' => count($affected_sdps)
        );
    } catch (Exception $e) {
        return array('error' => 'Query failed', 'message' => $e->getMessage());
    }
}


/**
 * Get diagnostic data
 */
function getDiagnosticData($db) {
    try {
        $stmt = $db->query("
            SELECT alarm_id, severity, alarm_type, tree_name, category_name,
                   sdp_list, sdp_count, file_count, issue_description, timestamp
            FROM alarms
            WHERE status = 'Active'
            ORDER BY alarm_id DESC
            LIMIT 5
        ");
        $alarms = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return array(
            'sample_alarms' => $alarms,
            'note' => 'This shows the exact format of alarm data in your database'
        );
    } catch (Exception $e) {
        return array('error' => 'Query failed', 'message' => $e->getMessage());
    }
}


/**
 * Get alarms for a specific SDP
 */
function getSDPAlarms($db, $sdp_name) {
    if (empty($sdp_name) || !preg_match('/^SDP\d+B$/', $sdp_name)) {
        return array('error' => 'Valid SDP name required (e.g., SDP27B)');
    }

    try {
        $stmt = $db->query("SELECT run_id FROM monitoring_runs ORDER BY run_timestamp DESC LIMIT 1");
        $run = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$run) {
            return array('error' => 'No monitoring data');
        }

        $run_id = $run['run_id'];

        // Match SDP name as a whole word in the sdp_list
        $stmt = $db->prepare("
            SELECT alarm_id, severity, alarm_type, tree_name, category_name,
                   issue_description, timestamp
            FROM alarms
            WHERE run_id = ?
            AND status = 'Active'
            AND (
                sdp_list LIKE ?
                OR sdp_list LIKE ?
                OR sdp_list LIKE ?
                OR sdp_list = ?
                OR sdp_list = 'All SDPs'
            )
            ORDER BY
                CASE severity
                    WHEN 'critical' THEN 1
                    WHEN 'high' THEN 2
                    WHEN 'medium' THEN 3
                    WHEN 'low' THEN 4
                END,
                timestamp DESC
        ");
        // Match: starts with, ends with, contains with comma boundaries, or exact match
        $stmt->execute(array(
            $run_id,
            $sdp_name . ',%',
            '%,' . $sdp_name . ',%',
            '%,' . $sdp_name,
            $sdp_name
        ));
        $alarms = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return array(
            'sdp' => $sdp_name,
            'alarm_count' => count($alarms),
            'alarms' => $alarms
        );
    } catch (Exception $e) {
        return array('error' => 'Query failed', 'message' => $e->getMessage());
    }
}
