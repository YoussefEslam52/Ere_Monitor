<?php
ob_start();
ini_set('display_errors', '0');
error_reporting(0);

header('Content-Type: application/json');
date_default_timezone_set('UTC');

$db_file = dirname(__FILE__) . '/../sdp_monitor.db';
if (!file_exists($db_file)) {
    $db_file = dirname(__FILE__) . '/data/sdp_monitor.db';
}

if (!function_exists('http_response_code')) {
    function http_response_code($code = NULL) {
        if ($code !== NULL) {
            if (isset($_SERVER['SERVER_PROTOCOL'])) $protocol = $_SERVER['SERVER_PROTOCOL'];
            else $protocol = 'HTTP/1.0';
            header("$protocol $code");
            $GLOBALS['http_response_code'] = $code;
        }
        return isset($GLOBALS['http_response_code']) ? $GLOBALS['http_response_code'] : 200;
    }
}

function send_json($data, $code = 200) {
    if ($code !== 200) http_response_code($code);
    ob_clean();
    echo json_encode($data);
    exit;
}

if (!file_exists($db_file)) {
    send_json(array('error' => "Database not found", 'summary' => null), 404);
}

try {
    $db = new PDO("sqlite:$db_file");
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    send_json(array('error' => "Connection failed: " . $e->getMessage()), 500);
}

$action = isset($_GET['action']) ? $_GET['action'] : 'dashboard';

switch ($action) {
    case 'dashboard': get_dashboard_summary(); break;
    case 'alarms': get_alarms(); break;
    case 'trees': get_trees(); break;
    case 'sdp_status': get_sdp_status(); break;
    case 'diagnostic': get_diagnostic(); break;
    default: send_json(array('error' => "Invalid action"), 400);
}

function get_dashboard_summary() {
    global $db;
    $stmt = $db->query("SELECT *, run_timestamp as last_run FROM monitoring_runs ORDER BY run_id DESC LIMIT 1");
    $run = $stmt->fetch();
    
    if (!$run) {
        send_json(array(
            'summary' => array('total_sdps' => 0, 'healthy_sdps' => 0, 'critical_sdps' => 0, 'offline_sdps' => 0, 'total_trees' => 0, 'last_run' => '--'),
            'recent_alarms' => array(),
            'history' => array()
        ));
    }
    
    $stmt = $db->prepare("SELECT alarm_id, timestamp, sdp_list as sdp, severity, issue_description as alarm_text FROM alarms WHERE run_id = ? ORDER BY severity = 'critical' DESC, timestamp DESC LIMIT 10");
    $stmt->execute(array($run['run_id']));
    $recent = $stmt->fetchAll();
    
    $stmt = $db->query("SELECT date(run_timestamp) as run_time, MAX(total_alarms) as alarm_count FROM monitoring_runs WHERE run_timestamp >= date('now', '-7 days') GROUP BY date(run_timestamp) ORDER BY run_time ASC");
    $history = $stmt->fetchAll();
    
    send_json(array('summary' => $run, 'recent_alarms' => $recent ? $recent : array(), 'history' => $history ? $history : array()));
}

function get_alarms() {
    global $db;
    $stmt = $db->query("SELECT MAX(run_id) FROM monitoring_runs");
    $run_id = $stmt->fetchColumn();
    if (!$run_id) send_json(array('alarms' => array()));
    
    $stmt = $db->prepare("SELECT alarm_id as id, timestamp, sdp_list as sdp, tree_name as tree, category_name as category, severity, issue_description as alarm_text FROM alarms WHERE run_id = ? ORDER BY severity = 'critical' DESC, timestamp DESC LIMIT 100");
    $stmt->execute(array($run_id));
    send_json(array('alarms' => $stmt->fetchAll()));
}

function get_trees() {
    global $db;
    $stmt = $db->query("SELECT tree_name, category_name as category, expected_files, found_files, (expected_files - found_files) as missing_files FROM categories WHERE run_id = (SELECT MAX(run_id) FROM monitoring_runs) ORDER BY alarm_count DESC");
    $trees = $stmt->fetchAll();
    send_json(array('trees' => $trees ? $trees : array()));
}

function get_sdp_status() {
    global $db;
    $stmt = $db->query("SELECT *, CASE WHEN health_status != 'offline' THEN 1 ELSE 0 END as is_online FROM sdp_status WHERE run_id = (SELECT MAX(run_id) FROM monitoring_runs) ORDER BY sdp_name ASC");
    $status = $stmt->fetchAll();
    send_json(array('sdp_status' => $status ? $status : array()));
}

function get_diagnostic() {
    global $db, $db_file;
    $stats = array('db' => realpath($db_file), 'size' => @filesize($db_file), 'php' => PHP_VERSION, 'time' => date('Y-m-d H:i:s'));
    $stmt = $db->query("SELECT * FROM monitoring_runs ORDER BY run_id DESC LIMIT 5");
    $stats['recent_runs'] = $stmt->fetchAll();
    send_json($stats);
}
