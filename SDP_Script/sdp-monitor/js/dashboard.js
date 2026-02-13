// dashboard.js - Ere Monitor Dashboard Logic
// Zero-Dependency, ES5 Compatible

var SimpleChart = {
    doughnut: function (canvasId, data, colors) {
        var canvas = document.getElementById(canvasId);
        if (!canvas) return;
        var ctx = canvas.getContext('2d');
        var width = canvas.width = canvas.offsetWidth;
        var height = canvas.height = canvas.offsetHeight;
        var centerX = width / 2;
        var centerY = height / 2;
        var radius = Math.min(centerX, centerY) * 0.8;

        var total = 0;
        for (var i = 0; i < data.length; i++) total += Number(data[i] || 0);

        ctx.clearRect(0, 0, width, height);

        if (total === 0) {
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
            ctx.strokeStyle = '#334155';
            ctx.lineWidth = 15;
            ctx.stroke();

            ctx.fillStyle = '#94a3b8';
            ctx.font = '14px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('No Data', centerX, centerY);
            return;
        }

        var startAngle = -0.5 * Math.PI;
        for (var i = 0; i < data.length; i++) {
            var val = Number(data[i] || 0);
            if (val === 0) continue;
            var slice = (val / total) * 2 * Math.PI;
            ctx.beginPath();
            ctx.moveTo(centerX, centerY);
            ctx.arc(centerX, centerY, radius, startAngle, startAngle + slice);
            ctx.fillStyle = colors[i];
            ctx.fill();
            startAngle += slice;
        }

        // Hole
        ctx.beginPath();
        ctx.arc(centerX, centerY, radius * 0.65, 0, 2 * Math.PI);
        ctx.fillStyle = '#1e293b';
        ctx.fill();

        // Center Text
        ctx.fillStyle = '#fff';
        ctx.font = 'bold 24px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(total, centerX, centerY);
    },
    line: function (canvasId, labels, data, color) {
        var canvas = document.getElementById(canvasId);
        if (!canvas) return;
        var ctx = canvas.getContext('2d');
        var width = canvas.width = canvas.offsetWidth;
        var height = canvas.height = canvas.offsetHeight;
        var padding = 35;

        ctx.clearRect(0, 0, width, height);

        if (!data || data.length < 1) {
            ctx.fillStyle = '#94a3b8';
            ctx.font = '14px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('No Trend Data', width / 2, height / 2);
            return;
        }

        var max = 1;
        for (var i = 0; i < data.length; i++) if (Number(data[i]) > max) max = Number(data[i]);

        var gW = width - padding * 2;
        var gH = height - padding * 2;

        // Axes
        ctx.beginPath();
        ctx.strokeStyle = '#334155';
        ctx.moveTo(padding, padding);
        ctx.lineTo(padding, height - padding);
        ctx.lineTo(width - padding, height - padding);
        ctx.stroke();

        if (data.length < 2) {
            var x = padding + gW / 2;
            var y = (height - padding) - (Number(data[0] || 0) / max * gH);
            ctx.beginPath(); ctx.arc(x, y, 4, 0, 2 * Math.PI); ctx.fillStyle = color; ctx.fill();
            return;
        }

        // Area
        ctx.beginPath();
        ctx.fillStyle = color.replace(')', ', 0.1)').replace('rgb', 'rgba');
        ctx.moveTo(padding, height - padding);
        for (var i = 0; i < data.length; i++) {
            var x = padding + (i * (gW / (data.length - 1)));
            var y = (height - padding) - (Number(data[i] || 0) / max * gH);
            ctx.lineTo(x, y);
        }
        ctx.lineTo(width - padding, height - padding);
        ctx.fill();

        // Line
        ctx.beginPath();
        ctx.strokeStyle = color;
        ctx.lineWidth = 2;
        for (var i = 0; i < data.length; i++) {
            var x = padding + (i * (gW / (data.length - 1)));
            var y = (height - padding) - (Number(data[i] || 0) / max * gH);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.stroke();
    }
};

function showJson(data) {
    var modal = document.getElementById('jsonModal');
    var modalJson = document.getElementById('modalJson');
    if (modal && modalJson) {
        modalJson.textContent = JSON.stringify(data, null, 2);
        modal.style.display = 'block';
    }
}

document.addEventListener('DOMContentLoaded', function () {
    loadDashboard();

    var closeBtn = document.getElementById('closeModal');
    if (closeBtn) closeBtn.onclick = function () { document.getElementById('jsonModal').style.display = 'none'; };

    window.onclick = function (e) {
        if (e.target == document.getElementById('jsonModal')) document.getElementById('jsonModal').style.display = 'none';
    };

    var navs = document.querySelectorAll('.nav-item');
    for (var i = 0; i < navs.length; i++) {
        navs[i].onclick = function (e) {
            e.preventDefault();
            for (var j = 0; j < navs.length; j++) navs[j].className = 'nav-item';
            this.className = 'nav-item active';
            switchView(this.getAttribute('data-view'));
        };
    }

    var refBtn = document.getElementById('refresh-btn');
    if (refBtn) refBtn.onclick = function () { loadDashboard(); };
});

function fetchJSON(url, success) {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if (xhr.status === 200) {
                try { success(JSON.parse(xhr.responseText)); } catch (e) { console.error("JSON Parse Error", e); }
            } else {
                console.error("API Error", xhr.status);
            }
        }
    };
    xhr.open('GET', url, true);
    xhr.send();
}

function loadDashboard() {
    fetchJSON('api.php?action=dashboard', function (data) {
        if (!data) return;
        var s = data.summary || {};
        document.getElementById('val-total-sdps').textContent = s.total_sdps || 0;
        document.getElementById('val-healthy-sdps').textContent = s.healthy_sdps || 0;
        document.getElementById('val-critical-sdps').textContent = (Number(s.critical_sdps || 0) + Number(s.offline_sdps || 0));
        document.getElementById('val-total-trees').textContent = s.total_trees || 0;
        document.getElementById('last-updated').textContent = "Updated: " + (s.last_run || '--');

        SimpleChart.doughnut('healthChart',
            [Number(s.healthy_sdps || 0), Number(s.critical_sdps || 0), Number(s.offline_sdps || 0)],
            ['#10b981', '#ef4444', '#94a3b8']
        );

        var lbls = [], vals = [];
        if (data.history && data.history.length > 0) {
            for (var i = 0; i < data.history.length; i++) {
                lbls.push(data.history[i].run_time);
                vals.push(Number(data.history[i].alarm_count || 0));
            }
        }
        SimpleChart.line('trendChart', lbls, vals, '#3b82f6');

        var tb = document.getElementById('dashboard-alarms-body');
        if (tb && data.recent_alarms) {
            tb.innerHTML = '';
            if (data.recent_alarms.length === 0) {
                tb.innerHTML = '<tr><td colspan="5" style="text-align:center">No recent alarms</td></tr>';
            }
            for (var i = 0; i < data.recent_alarms.length; i++) {
                (function (a) {
                    var tr = document.createElement('tr');
                    var sev = a.severity ? a.severity.toLowerCase() : 'low';
                    tr.innerHTML = '<td>' + a.timestamp + '</td><td>' + a.sdp + '</td><td><span class="badge ' + sev + '">' + (a.severity || 'Low') + '</span></td><td class="text-truncate" style="max-width:300px">' + a.alarm_text + '</td>';
                    var td = document.createElement('td');
                    var btn = document.createElement('button');
                    btn.className = 'btn btn-secondary btn-sm'; btn.textContent = 'View';
                    btn.onclick = function () { showJson(a); };
                    td.appendChild(btn); tr.appendChild(td);
                    tb.appendChild(tr);
                })(data.recent_alarms[i]);
            }
        }
    });
}

function loadAlarms() {
    fetchJSON('api.php?action=alarms', function (data) {
        var tb = document.getElementById('all-alarms-body');
        if (!tb || !data.alarms) return;
        tb.innerHTML = '';
        if (data.alarms.length === 0) {
            tb.innerHTML = '<tr><td colspan="6" style="text-align:center">No alarms found</td></tr>';
        }
        for (var i = 0; i < data.alarms.length; i++) {
            (function (a) {
                var tr = document.createElement('tr');
                var sev = a.severity ? a.severity.toLowerCase() : 'low';
                var treeInfo = (a.tree && a.category) ? (a.tree + ' / ' + a.category) : 'System';
                tr.innerHTML = '<td>' + a.timestamp + '</td><td>' + a.sdp + '</td><td>' + treeInfo + '</td><td><span class="badge ' + sev + '">' + (a.severity || 'Low') + '</span></td><td>' + a.alarm_text + '</td>';
                var td = document.createElement('td');
                var btn = document.createElement('button');
                btn.className = 'btn btn-secondary btn-sm'; btn.textContent = 'View';
                btn.onclick = function () { showJson(a); };
                td.appendChild(btn); tr.appendChild(td);
                tb.appendChild(tr);
            })(data.alarms[i]);
        }
    });
}

function loadTrees() {
    fetchJSON('api.php?action=trees', function (data) {
        var tb = document.getElementById('trees-body');
        if (!tb || !data.trees) return;
        tb.innerHTML = '';
        if (data.trees.length === 0) {
            tb.innerHTML = '<tr><td colspan="5" style="text-align:center">No tree analytics available</td></tr>';
        }
        for (var i = 0; i < data.trees.length; i++) {
            var t = data.trees[i];
            var cls = t.missing_files > 0 ? 'badge warning' : 'badge healthy';
            tb.innerHTML += '<tr><td>' + t.tree_name + '</td><td>' + (t.category || 'N/A') + '</td><td>' + (t.expected_files || '--') + '</td><td>' + (t.found_files || '--') + '</td><td><span class="' + cls + '">' + (t.missing_files > 0 ? 'Missing ' + t.missing_files : 'OK') + '</span></td></tr>';
        }
    });
}

function loadSDPStatus() {
    fetchJSON('api.php?action=sdp_status', function (data) {
        var tb = document.getElementById('sdp-status-body');
        if (!tb || !data.sdp_status) return;
        tb.innerHTML = '';
        if (data.sdp_status.length === 0) {
            tb.innerHTML = '<tr><td colspan="4" style="text-align:center">No SDP status data</td></tr>';
        }
        for (var i = 0; i < data.sdp_status.length; i++) {
            var s = data.sdp_status[i];
            var cls = s.is_online ? 'badge healthy' : 'badge offline';
            tb.innerHTML += '<tr><td>' + s.sdp_name + '</td><td>' + (s.ip_address || '--') + '</td><td><span class="' + cls + '">' + (s.is_online ? 'Online' : 'Offline') + '</span></td><td>' + s.last_checked + '</td></tr>';
        }
    });
}

function loadDiagnostic() {
    fetchJSON('api.php?action=diagnostic', function (data) {
        var pre = document.getElementById('diagnostic-data');
        if (pre) pre.textContent = JSON.stringify(data, null, 2);
    });
}

function switchView(v) {
    var vs = document.querySelectorAll('.view-section');
    for (var i = 0; i < vs.length; i++) vs[i].style.display = 'none';
    var t = document.getElementById('view-' + v);
    if (t) t.style.display = 'block';

    if (v === 'dashboard') loadDashboard();
    else if (v === 'alarms') loadAlarms();
    else if (v === 'trees') loadTrees();
    else if (v === 'sdp_status') loadSDPStatus();
    else if (v === 'diagnostic') loadDiagnostic();
}
