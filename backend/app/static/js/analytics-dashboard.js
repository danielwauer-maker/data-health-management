let currentSelectedScanId = null;

function byId(id) {
  return document.getElementById(id);
}

function formatNumber(value) {
  return new Intl.NumberFormat('en-US').format(Number(value || 0));
}

function formatCurrency(value) {
  return new Intl.NumberFormat('en-US', {
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

function getRating(score) {
  const value = Number(score || 0);
  if (value <= 60) {
    return { key: 'critical', label: 'Critical', color: '#ef4444' };
  }
  if (value <= 75) {
    return { key: 'warning', label: 'Warning', color: '#f97316' };
  }
  if (value <= 85) {
    return { key: 'moderate', label: 'Moderate', color: '#eab308' };
  }
  if (value <= 95) {
    return { key: 'good', label: 'Good', color: '#3b82f6' };
  }
  return { key: 'excellent', label: 'Excellent', color: '#22c55e' };
}

function renderGauge(score) {
  const host = byId('gauge-host');
  if (!host) {
    return;
  }

  const safeScore = Math.max(0, Math.min(100, Number(score || 0)));
  const rating = getRating(safeScore);
  const radius = 78;
  const circumference = Math.PI * radius;
  const dash = (safeScore / 100) * circumference;

  host.innerHTML = `
    <svg class="gauge-svg" viewBox="0 0 220 140" aria-label="Data Health Score gauge">
      <path d="M 32 108 A 78 78 0 0 1 188 108" class="gauge-track"></path>
      <path d="M 32 108 A 78 78 0 0 1 188 108" class="gauge-progress" style="stroke:${rating.color}; stroke-dasharray:${dash} ${circumference};"></path>
      <text x="110" y="86" text-anchor="middle" class="gauge-value">${formatNumber(safeScore)}</text>
      <text x="110" y="106" text-anchor="middle" class="gauge-label">Data Health Score</text>
    </svg>
  `;
}

function renderHero(hero, planLabel) {
  const headline = byId('hero-headline');
  const bullets = byId('hero-bullets');
  const intro = byId('hero-intro');
  const planBadge = byId('plan-badge');
  const subscriptionPlan = byId('subscription-plan');

  if (intro) {
    intro.textContent = hero?.intro || 'Insight is free. Action is Premium.';
  }

  if (headline) {
    const text = hero?.headline || 'Your data health is critical';
    const color = hero?.rating_color || '#ef4444';
    const ratingLabel = hero?.rating_label || 'Critical';
    const colorRegex = new RegExp(ratingLabel, 'i');
    if (colorRegex.test(text)) {
      headline.innerHTML = escapeHtml(text).replace(colorRegex, `<span style="color:${color};">${escapeHtml(ratingLabel)}</span>`);
    } else {
      headline.innerHTML = `${escapeHtml(text)} <span style="color:${color};">${escapeHtml(ratingLabel)}</span>`;
    }
  }

  if (bullets) {
    const items = Array.isArray(hero?.bullets) ? hero.bullets : [];
    bullets.innerHTML = items.map((item) => `<li>${escapeHtml(item)}</li>`).join('');
  }

  if (planBadge) {
    planBadge.textContent = planLabel || 'Free';
    planBadge.className = `plan-badge ${String(planLabel || '').toLowerCase() === 'premium' ? 'premium' : 'free'}`;
  }

  if (subscriptionPlan) {
    subscriptionPlan.textContent = planLabel || 'Free';
  }
}

function renderProfileCards(items) {
  const host = byId('profile-cards');
  if (!host) return;
  host.innerHTML = '';

  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<div class="empty-state">No profile data available yet.</div>';
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

function renderTrend(hostId, items, ariaLabel) {
  const host = byId(hostId);
  if (!host) return;
  host.innerHTML = '';

  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<div class="empty-state">No trend data available yet.</div>';
    return;
  }

  const safeItems = items.map((item) => ({
    label: item?.label || '',
    value: Number(item?.value || 0),
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

  host.innerHTML = `
    <svg viewBox="0 0 ${width} ${height}" class="trend-svg" role="img" aria-label="${escapeHtml(ariaLabel)}">
      ${gridLines}
      <polyline points="${polylinePoints}" class="trend-line"></polyline>
      ${pointCircles}
      ${xLabels}
    </svg>
  `;
}

function renderRecentScans(items) {
  const host = byId('recent-scans-body');
  if (!host) return;

  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<tr><td colspan="5" class="table-empty">No scans available yet.</td></tr>';
    return;
  }

  host.innerHTML = items.map((item) => `
    <tr class="scan-row${item?.is_selected ? ' is-selected' : ''}" data-scan-id="${escapeHtml(item?.scan_id)}" tabindex="0">
      <td>${escapeHtml(item?.generated_at)}</td>
      <td>${escapeHtml(item?.scan_type)}</td>
      <td>${formatNumber(item?.score)}</td>
      <td>${formatNumber(item?.issues_count)}</td>
      <td>${escapeHtml(item?.headline || '')}</td>
    </tr>
  `).join('');
}

function renderIssueGroups(items) {
  const host = byId('issue-groups');
  if (!host) return;

  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<div class="empty-state">No issue groups available.</div>';
    return;
  }

  const max = Math.max(...items.map((item) => Number(item?.count || 0)), 1);
  host.innerHTML = items.map((item) => {
    const count = Number(item?.count || 0);
    const percent = Math.max(4, Math.round((count / max) * 100));
    return `
      <div class="progress-row">
        <div class="progress-topline">
          <span>${escapeHtml(item?.name)}</span>
          <span>${formatNumber(count)}</span>
        </div>
        <div class="progress-track"><div class="progress-bar" style="width:${percent}%"></div></div>
      </div>
    `;
  }).join('');
}

function renderFindings(items) {
  const host = byId('findings-body');
  if (!host) return;

  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<tr><td colspan="5" class="table-empty">No findings available.</td></tr>';
    return;
  }

  host.innerHTML = items.map((item) => `
    <tr>
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
      setText('page-subtitle', 'Dashboard could not be loaded.');
      return;
    }

    const data = await response.json();
    currentSelectedScanId = data?.selected_scan_id || null;

    setText('page-title', data?.title || 'BCSentinel Analytics');
    setText('page-subtitle', data?.subtitle || '');
    setText('last-updated', `Last updated: ${data?.last_updated || '—'}`);
    renderHero(data?.hero || {}, data?.current_plan_label || 'Free');
    renderGauge(data?.kpis?.health_score);
    setText('kpi-score', formatNumber(data?.kpis?.health_score));
    setText('kpi-records', formatNumber(data?.kpis?.total_records));
    setText('kpi-affected', formatNumber(data?.kpis?.affected_records));
    setText('kpi-price', formatCurrency(data?.kpis?.estimated_premium_price_monthly));
    setText('kpi-loss', formatCurrency(data?.kpis?.estimated_loss_eur));
    setText('kpi-roi', formatCurrency(data?.kpis?.roi_eur));
    setText('kpi-checks', formatNumber(data?.kpis?.checks_run));
    setText('kpi-issues', formatNumber(data?.kpis?.issues_count));
    setText('subscription-price', formatCurrency(data?.kpis?.estimated_premium_price_monthly));

    renderProfileCards(data?.profile_cards || []);
    renderTrend('trend-chart', data?.score_trend || [], 'Score Trend');
    renderTrend('loss-chart', data?.loss_trend || [], 'Loss Trend');
    renderRecentScans(data?.recent_scans || []);
    renderIssueGroups(data?.issue_groups || []);
    renderFindings(data?.top_findings || []);
  } catch (error) {
    console.error('loadDashboard failed:', error);
    setText('page-subtitle', 'Dashboard could not be loaded.');
  }
}

function registerEvents() {
  const scansBody = byId('recent-scans-body');
  if (!scansBody) return;

  async function handleSelect(row) {
    const scanId = row?.dataset?.scanId;
    if (!scanId || scanId === currentSelectedScanId) return;
    await loadDashboard(scanId);
  }

  scansBody.addEventListener('click', async (event) => {
    const row = event.target.closest('.scan-row');
    if (!row) return;
    await handleSelect(row);
  });

  scansBody.addEventListener('keydown', async (event) => {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    const row = event.target.closest('.scan-row');
    if (!row) return;
    event.preventDefault();
    await handleSelect(row);
  });
}

document.addEventListener('DOMContentLoaded', () => {
  registerEvents();
  loadDashboard();
});
