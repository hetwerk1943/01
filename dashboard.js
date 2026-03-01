// ---- helpers ----
function $(id) { return document.getElementById(id); }

function escHtml(s) {
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

function updateTime() {
  $('last-update').textContent = 'Odświeżono: ' + new Date().toLocaleTimeString('pl-PL');
}
updateTime();

// ---- Minimal bar chart (SVG, no external dependencies) ----
function drawBarChart(canvasId, data, labels) {
  const canvas = $(canvasId);
  const W = canvas.offsetWidth || 560, H = 180;
  canvas.setAttribute('width', W);
  canvas.setAttribute('height', H);
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, W, H);
  const max = Math.max(...data, 1);
  const barW = Math.floor(W / data.length) - 2;
  data.forEach((val, i) => {
    const x = i * (barW + 2) + 1;
    const barH = Math.round((val / max) * (H - 24));
    const y = H - barH - 20;
    ctx.fillStyle = 'rgba(248,81,73,0.7)';
    ctx.fillRect(x, y, barW, barH);
    if (i % 4 === 0) {
      ctx.fillStyle = '#8b949e';
      ctx.font = '9px sans-serif';
      ctx.fillText(labels[i], x, H - 4);
    }
  });
}

// ---- Minimal doughnut chart (SVG, no external dependencies) ----
function drawDoughnut(canvasId, data, labels, colors) {
  const canvas = $(canvasId);
  const W = canvas.offsetWidth || 300, H = 180;
  canvas.setAttribute('width', W);
  canvas.setAttribute('height', H);
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, W, H);
  const cx = W / 2 - 40, cy = H / 2, r = 70, inner = 40;
  const total = data.reduce((a, b) => a + b, 0) || 1;
  let start = -Math.PI / 2;
  data.forEach((val, i) => {
    const angle = (val / total) * 2 * Math.PI;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, r, start, start + angle);
    ctx.closePath();
    ctx.fillStyle = colors[i];
    ctx.fill();
    start += angle;
  });
  // inner white circle (doughnut hole)
  ctx.beginPath();
  ctx.arc(cx, cy, inner, 0, 2 * Math.PI);
  ctx.fillStyle = '#161b22';
  ctx.fill();
  // legend
  labels.forEach((lbl, i) => {
    const lx = W - 80, ly = 30 + i * 22;
    ctx.fillStyle = colors[i];
    ctx.fillRect(lx, ly, 12, 12);
    ctx.fillStyle = '#e6edf3';
    ctx.font = '11px sans-serif';
    ctx.fillText(lbl + ': ' + data[i], lx + 16, ly + 10);
  });
}

const hours = Array.from({length: 24}, (_, i) => i + ':00');
let hourBuckets = new Array(24).fill(0);
let sevData = [0, 0, 0];
let _totalEvents = 0;
let _uniqueEventTypes = new Set();
let _highSeverityCount = 0;

const MATURITY_LEVEL2_MIN_EVENTS = 10;
const MATURITY_LEVEL2_MIN_TYPES  = 2;
const MATURITY_LEVEL3_MIN_EVENTS = 50;
const MATURITY_LEVEL3_HIGH_SEV   = 5;
const MATURITY_LEVEL4_MIN_EVENTS = 200;

function repoMaturityLevel() {
  if (_totalEvents === 0) return '—';
  if (_totalEvents < MATURITY_LEVEL2_MIN_EVENTS || _uniqueEventTypes.size < MATURITY_LEVEL2_MIN_TYPES)
    return '🌱 Level 1 – Basic';
  if (_totalEvents < MATURITY_LEVEL3_MIN_EVENTS && _highSeverityCount < MATURITY_LEVEL3_HIGH_SEV)
    return '🔵 Level 2 – Developing';
  if (_totalEvents < MATURITY_LEVEL4_MIN_EVENTS)
    return '🔶 Level 3 – Established';
  return '🔴 Level 4 – Advanced';
}

function redrawCharts() {
  drawBarChart('chart-alerts', hourBuckets, hours);
  drawDoughnut('chart-severity', sevData, ['High','Medium','Low'], ['#f85149','#d29922','#3fb950']);
}
redrawCharts();
let _resizeTimer;
window.addEventListener('resize', function () {
  clearTimeout(_resizeTimer);
  _resizeTimer = setTimeout(redrawCharts, 150);
});

// ---- SIEM JSON loader ----
$('load-siem').addEventListener('change', function (e) {
  const file = e.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = function (ev) {
    const lines = ev.target.result.split('\n').filter(Boolean);
    const events = lines.map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);

    const todayStr = new Date().toISOString().slice(0, 10);
    let alertsToday = 0, susProcs = 0, fileChanges = 0;
    hourBuckets = new Array(24).fill(0);
    sevData = [0, 0, 0];
    _totalEvents = 0;
    _uniqueEventTypes = new Set();
    _highSeverityCount = 0;
    const alertList = [];

    events.forEach(ev => {
      const ts = new Date(ev.timestamp);
      if (ev.timestamp && ev.timestamp.startsWith(todayStr)) alertsToday++;
      if (ev.event_type === 'SuspiciousProcess') susProcs++;
      if (ev.event_type === 'FileChange') fileChanges++;
      if (!isNaN(ts)) hourBuckets[ts.getHours()]++;
      if (ev.severity === 'High')        { sevData[0]++; _highSeverityCount++; }
      else if (ev.severity === 'Medium') sevData[1]++;
      else                               sevData[2]++;
      if (ev.event_type) _uniqueEventTypes.add(ev.event_type);
      _totalEvents++;
      if (alertList.length < 30) alertList.push(ev);
    });

    $('kpi-alerts').textContent = alertsToday;
    $('kpi-procs').textContent  = susProcs;
    $('kpi-files').textContent  = fileChanges;
    $('kpi-siem').textContent   = events.length;
    $('kpi-maturity').textContent = repoMaturityLevel();

    redrawCharts();

    const al = $('alert-list');
    al.innerHTML = '';
    alertList.slice().reverse().forEach(ev => {
      const row = document.createElement('div');
      row.className = 'alert-row';
      const cls = ev.severity === 'High' ? 'high' : ev.severity === 'Medium' ? 'medium' : 'low';
      const tsStr = new Date(ev.timestamp).toLocaleTimeString('pl-PL');
      const detail = ev.data && ev.data.name ? ev.data.name : (ev.data && ev.data.path ? ev.data.path : '');
      row.innerHTML = '<span class="dot ' + cls + '"></span><b>[' + escHtml(tsStr) + ']</b>&nbsp;' +
                      escHtml(ev.event_type) + '&nbsp;—&nbsp;' + escHtml(detail);
      al.appendChild(row);
    });
    updateTime();
  };
  reader.readAsText(file);
});

// ---- Log file loader ----
$('load-log').addEventListener('change', function (e) {
  const file = e.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = function (ev) {
    const lines = ev.target.result.split('\n').filter(Boolean).slice(-200);
    const box = $('log-box');
    box.innerHTML = '';
    lines.slice().reverse().forEach(line => {
      const lower = line.toLowerCase();
      const parts = line.split('\t');
      const entry = document.createElement('div');
      entry.className = 'entry';
      const isSuspect = lower.includes('suspect') || lower.includes('error');
      const isWarn    = lower.includes('warning') || lower.includes('rotated');
      const cls = isSuspect ? 'text-danger' : isWarn ? 'text-warning' : '';
      const ts   = escHtml(parts[0] || '');
      const body = escHtml(parts.slice(1).join('\t') || line);
      entry.innerHTML = '<span class="ts">' + ts + '</span><span class="' + cls + '">' + body + '</span>';
      box.appendChild(entry);
    });
    updateTime();
  };
  reader.readAsText(file);
});
