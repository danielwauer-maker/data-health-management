let currentSelectedScanId = null;

function byId(id) {
  return document.getElementById(id);
}

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

function setText(id, value) {
  const el = byId(id);
  if (el) {
    el.textContent = value;
  }
}

function renderProfileCards(items) {
  const host = byId('profile-cards');
  if (!host) {
    return;
  }

  host.innerHTML = '';

  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<div class="empty-state">Noch keine Profilwerte vorhanden.</div>';
    return;
  }

  items.forEach((item) => {
    const card = document.createElement('div');
    card.className = 'mini-card';
    card.innerHTML = `
      <div class="mini-card-value">${formatNumber(item?.value)}</div>
      <div class="mini-card-label">${escapeHtml(item?.label)}</div>
    `;
    host.appendChild(card);
  });
}

function renderTrend(items) {
  const host = byId('trend-chart');
  if (!host) {
    console.warn('trend-chart container not found.');
    return;
  }

  host.innerHTML = '';

  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<div class="empty-state">Noch keine Trenddaten vorhanden.</div>';
    return;
  }

  const safeItems = items.map((item) => ({
    scan_id: item?.scan_id || '',
    label: item?.label || '',
    timestamp: item?.timestamp || '',
    value: Number(item?.value || 0),
    scan_type: item?.scan_type || '',
    is_selected: Boolean(item?.is_selected),
  }));

  const width = 560;
  const height = 220;
  const paddingX = 32;
  const paddingTop = 20;
  const paddingBottom = 42;
  const usableWidth = width - paddingX * 2;
  const usableHeight = height - paddingTop - paddingBottom;
  const maxValue = Math.max(...safeItems.map((item) => item.value), 1);
  const stepX = safeItems.length > 1 ? usableWidth / (safeItems.length - 1) : 0;

  const points = safeItems.map((item, index) => {
    const x = paddingX + stepX * index;
    const ratio = item.value / maxValue;
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

  const legendItems = points.map((point) => `
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
    <div class="trend-legend">${legendItems}</div>
  `;
}

function renderRecentScans(items) {
  const host = byId('recent-scans-body');
  if (!host) {
    return;
  }

  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<tr><td colspan="5" class="table-empty">Noch keine Scans vorhanden.</td></tr>';
    return;
  }

  host.innerHTML = items.map((item) => `
    <tr class="scan-row${item?.is_selected ? ' is-selected' : ''}" data-scan-id="${escapeHtml(item?.scan_id)}" tabindex="0">
      <td>${escapeHtml(item?.generated_at)}</td>
      <td>${escapeHtml(item?.scan_type)}</td>
      <td>${formatNumber(item?.data_score)}</td>
      <td>${formatNumber(item?.issues_count)}</td>
      <td>${escapeHtml(item?.headline || '')}</td>
    </tr>
  `).join('');
}

function renderIssueGroups(items) {
  const host = byId('issue-groups');
  if (!host) {
    return;
  }

  host.innerHTML = '';

  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<div class="empty-state">Für diesen Scan wurden keine Findings gruppiert.</div>';
    return;
  }

  const maxValue = Math.max(...items.map((item) => Number(item?.count || 0)), 1);

  items.forEach((item) => {
    const width = Math.max((Number(item?.count || 0) / maxValue) * 100, 2);
    const row = document.createElement('div');
    row.className = 'progress-row';
    row.innerHTML = `
      <div class="progress-meta">
        <span>${escapeHtml(item?.name)}</span>
        <span>${formatNumber(item?.count)}</span>
      </div>
      <div class="progress-track">
        <div class="progress-fill" style="width:${width}%"></div>
      </div>
    `;
    host.appendChild(row);
  });
}

function renderFindings(items) {
  const host = byId('findings-body');
  if (!host) {
    return;
  }

  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<tr><td colspan="6" class="table-empty">Für diesen Scan gibt es keine Findings.</td></tr>';
    return;
  }

  host.innerHTML = items.map((item) => `
    <tr>
      <td>${escapeHtml(item?.code)}</td>
      <td>${escapeHtml(item?.title)}</td>
      <td>${escapeHtml(item?.group)}</td>
      <td><span class="severity severity-${escapeHtml(item?.severity)}">${escapeHtml(item?.severity)}</span></td>
      <td>${formatNumber(item?.count)}</td>
      <td>${formatCurrency(item?.impact_eur)}</td>
    </tr>
  `).join('');
}

async function loadDashboard(scanId = null) {
  const token = document.body?.dataset?.token;
  if (!token) {
    console.error('Missing analytics token on body[data-token].');
    return;
  }

  const url = new URL('/analytics/embed/data', window.location.origin);
  url.searchParams.set('token', token);
  if (scanId) {
    url.searchParams.set('scan_id', scanId);
  }

  try {
    const response = await fetch(url.toString());
    if (!response.ok) {
      setText('page-subtitle', 'Dashboard konnte nicht geladen werden.');
      return;
    }

    const data = await response.json();
    currentSelectedScanId = data?.selected_scan_id || null;

    setText('page-title', data?.title || 'BCSentinel Analytics');
    setText('page-subtitle', data?.subtitle || '');
    setText('scan-mode-badge', data?.scan_mode_label || '');
    setText('last-updated', `Letzte Aktualisierung: ${data?.last_updated || '—'}`);
    setText('kpi-score', formatNumber(data?.kpis?.health_score));
    setText('kpi-records', formatNumber(data?.kpis?.total_records));
    setText('kpi-price', formatCurrency(data?.kpis?.estimated_premium_price_monthly));
    setText('kpi-loss', formatCurrency(data?.kpis?.estimated_loss_eur));
    setText('kpi-roi', formatCurrency(data?.kpis?.roi_eur));

    renderProfileCards(data?.profile_cards || []);

    try {
      renderTrend(data?.score_trend || []);
    } catch (error) {
      console.error('renderTrend failed:', error);
      const trendHost = byId('trend-chart');
      if (trendHost) {
        trendHost.innerHTML = '<div class="empty-state">Trend konnte nicht geladen werden.</div>';
      }
    }

    try {
      renderRecentScans(data?.recent_scans || []);
    } catch (error) {
      console.error('renderRecentScans failed:', error);
    }

    try {
      renderIssueGroups(data?.issue_groups || []);
    } catch (error) {
      console.error('renderIssueGroups failed:', error);
    }

    try {
      renderFindings(data?.top_findings || []);
    } catch (error) {
      console.error('renderFindings failed:', error);
    }
  } catch (error) {
    console.error('loadDashboard failed:', error);
    setText('page-subtitle', 'Dashboard konnte nicht geladen werden.');
  }
}

function registerEvents() {
  const scansBody = byId('recent-scans-body');
  if (!scansBody) {
    return;
  }

  scansBody.addEventListener('click', async (event) => {
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

  scansBody.addEventListener('keydown', async (event) => {
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
}

document.addEventListener('DOMContentLoaded', () => {
  registerEvents();
  loadDashboard();
});