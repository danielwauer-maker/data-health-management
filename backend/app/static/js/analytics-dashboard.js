let currentSelectedScanId = null;

function formatNumber(value) {
  return new Intl.NumberFormat('de-DE').format(Number(value || 0));
}

function formatCurrency(value) {
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: 'EUR',
    maximumFractionDigits: 2,
  }).format(Number(value || 0));
}

function escapeHtml(value) {
  return String(value || '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function renderProfileCards(items) {
  const host = document.getElementById('profile-cards');
  host.innerHTML = '';

  if (!items.length) {
    host.innerHTML = '<div class="empty-state">Noch keine Profilwerte vorhanden.</div>';
    return;
  }

  items.forEach((item) => {
    const card = document.createElement('div');
    card.className = 'mini-card';
    card.innerHTML = `<div class="mini-card-value">${formatNumber(item.value)}</div><div class="mini-card-label">${escapeHtml(item.label)}</div>`;
    host.appendChild(card);
  });
}

function renderTrend(items) {
  const host = document.getElementById('trend-chart');
  host.innerHTML = '';

  if (!items.length) {
    host.innerHTML = '<div class="empty-state">Noch keine Trenddaten vorhanden.</div>';
    return;
  }

  const width = 560;
  const height = 220;
  const paddingX = 32;
  const paddingTop = 20;
  const paddingBottom = 42;
  const usableWidth = width - paddingX * 2;
  const usableHeight = height - paddingTop - paddingBottom;
  const maxValue = Math.max(...items.map((item) => Number(item.value || 0)), 1);
  const stepX = items.length > 1 ? usableWidth / (items.length - 1) : 0;

  const points = items.map((item, index) => {
    const x = paddingX + stepX * index;
    const ratio = Number(item.value || 0) / maxValue;
    const y = paddingTop + (usableHeight - usableHeight * ratio);
    return { ...item, x, y };
  });

  const polylinePoints = points.map((point) => `${point.x},${point.y}`).join(' ');
  const gridLines = [0, 0.5, 1].map((ratio) => {
    const y = paddingTop + usableHeight - usableHeight * ratio;
    const label = Math.round(maxValue * ratio);
    return `
      <line x1="${paddingX}" y1="${y}" x2="${width - paddingX}" y2="${y}" class="trend-grid-line"></line>
      <text x="${paddingX - 10}" y="${y + 4}" text-anchor="end" class="trend-axis-label">${formatNumber(label)}</text>
    `;
  }).join('');

  const pointCircles = points.map((point) => `
    <circle cx="${point.x}" cy="${point.y}" r="${point.is_selected ? 6 : 4}" class="trend-point${point.is_selected ? ' is-selected' : ''}"></circle>
  `).join('');

  const xLabels = points.map((point) => `
    <text x="${point.x}" y="${height - 14}" text-anchor="middle" class="trend-axis-label">${escapeHtml(point.label)}</text>
  `).join('');

  const tooltipItems = points.map((point) => `
    <div class="trend-legend-item${point.is_selected ? ' is-selected' : ''}">
      <span>${escapeHtml(point.timestamp)}</span>
      <strong>${formatNumber(point.value)}</strong>
    </div>
  `).join('');

  host.innerHTML = `
    <svg viewBox="0 0 ${width} ${height}" class="trend-svg" role="img" aria-label="Score Trend">
      ${gridLines}
      <polyline points="${polylinePoints}" class="trend-line"></polyline>
      ${pointCircles}
      ${xLabels}
    </svg>
    <div class="trend-legend">${tooltipItems}</div>
  `;
}

function renderRecentScans(items) {
  const host = document.getElementById('recent-scans-body');

  if (!items.length) {
    host.innerHTML = '<tr><td colspan="5" class="table-empty">Noch keine Scans vorhanden.</td></tr>';
    return;
  }

  host.innerHTML = items.map((item) => `
    <tr class="scan-row${item.is_selected ? ' is-selected' : ''}" data-scan-id="${escapeHtml(item.scan_id)}" tabindex="0">
      <td>${escapeHtml(item.generated_at)}</td>
      <td>${escapeHtml(item.scan_type)}</td>
      <td>${formatNumber(item.data_score)}</td>
      <td>${formatNumber(item.issues_count)}</td>
      <td>${escapeHtml(item.headline || '')}</td>
    </tr>
  `).join('');
}

function renderIssueGroups(items) {
  const host = document.getElementById('issue-groups');
  host.innerHTML = '';

  if (!items.length) {
    host.innerHTML = '<div class="empty-state">Für diesen Scan wurden keine Findings gruppiert.</div>';
    return;
  }

  const maxValue = Math.max(...items.map((item) => Number(item.count || 0)), 1);
  items.forEach((item) => {
    const width = Math.max((Number(item.count || 0) / maxValue) * 100, 2);
    const row = document.createElement('div');
    row.className = 'progress-row';
    row.innerHTML = `<div class="progress-meta"><span>${escapeHtml(item.name)}</span><span>${formatNumber(item.count)}</span></div><div class="progress-track"><div class="progress-fill" style="width:${width}%"></div></div>`;
    host.appendChild(row);
  });
}

function renderFindings(items) {
  const host = document.getElementById('findings-body');

  if (!items.length) {
    host.innerHTML = '<tr><td colspan="6" class="table-empty">Für diesen Scan gibt es keine Findings.</td></tr>';
    return;
  }

  host.innerHTML = items.map((item) => `
    <tr>
      <td>${escapeHtml(item.code)}</td>
      <td>${escapeHtml(item.title)}</td>
      <td>${escapeHtml(item.group)}</td>
      <td><span class="severity severity-${escapeHtml(item.severity)}">${escapeHtml(item.severity)}</span></td>
      <td>${formatNumber(item.count)}</td>
      <td>${formatCurrency(item.impact_eur)}</td>
    </tr>
  `).join('');
}

async function loadDashboard(scanId = null) {
  const token = document.body.dataset.token;
  const url = new URL('/analytics/embed/data', window.location.origin);
  url.searchParams.set('token', token);
  if (scanId) {
    url.searchParams.set('scan_id', scanId);
  }

  const response = await fetch(url.toString());
  if (!response.ok) {
    document.getElementById('page-subtitle').textContent = 'Dashboard konnte nicht geladen werden.';
    return;
  }

  const data = await response.json();
  currentSelectedScanId = data.selected_scan_id || null;
  document.getElementById('page-title').textContent = data.title;
  document.getElementById('page-subtitle').textContent = data.subtitle;
  document.getElementById('scan-mode-badge').textContent = data.scan_mode_label;
  document.getElementById('last-updated').textContent = `Letzte Aktualisierung: ${data.last_updated}`;
  document.getElementById('kpi-score').textContent = formatNumber(data.kpis.health_score);
  document.getElementById('kpi-records').textContent = formatNumber(data.kpis.total_records);
  document.getElementById('kpi-price').textContent = formatCurrency(data.kpis.estimated_premium_price_monthly);
  document.getElementById('kpi-loss').textContent = formatCurrency(data.kpis.estimated_loss_eur);
  document.getElementById('kpi-roi').textContent = formatCurrency(data.kpis.roi_eur);

  renderProfileCards(data.profile_cards || []);
  renderTrend(data.score_trend || []);
  renderRecentScans(data.recent_scans || []);
  renderIssueGroups(data.issue_groups || []);
  renderFindings(data.top_findings || []);
}

document.getElementById('recent-scans-body').addEventListener('click', async (event) => {
  const row = event.target.closest('.scan-row');
  if (!row) {
    return;
  }

  const scanId = row.dataset.scanId;
  if (!scanId || scanId === currentSelectedScanId) {
    return;
  }

  await loadDashboard(scanId);
});

document.getElementById('recent-scans-body').addEventListener('keydown', async (event) => {
  if (event.key !== 'Enter' && event.key !== ' ') {
    return;
  }

  const row = event.target.closest('.scan-row');
  if (!row) {
    return;
  }

  event.preventDefault();
  const scanId = row.dataset.scanId;
  if (!scanId || scanId === currentSelectedScanId) {
    return;
  }

  await loadDashboard(scanId);
});

loadDashboard();