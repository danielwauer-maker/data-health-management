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

function setHidden(id, hidden) {
  const el = byId(id);
  if (el) {
    el.hidden = Boolean(hidden);
  }
}

function renderProfileCards(items) {
  const host = byId('profile-cards');
  if (!host) return;
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

function renderLineChart(hostId, items, ariaLabel) {
  const host = byId(hostId);
  if (!host) return;
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
  if (!host) return;
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

function renderFindings(items, visibility) {
  const host = byId('findings-body');
  if (!host) return;
  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<tr><td colspan="6" class="table-empty">Für diesen Scan gibt es keine Findings.</td></tr>';
    return;
  }

  const isPremium = Boolean(visibility?.show_issue_details);
  host.innerHTML = items.map((item) => {
    const teaser = isPremium
      ? escapeHtml(item?.recommendation_preview || '')
      : 'Recommendation available with Premium';
    return `
      <tr>
        <td>
          <div class="issue-title-cell">${escapeHtml(item?.title)}</div>
          <div class="issue-subline">${escapeHtml(item?.code)}</div>
          <div class="issue-subline">${teaser}</div>
        </td>
        <td>${escapeHtml(item?.group)}</td>
        <td><span class="severity severity-${escapeHtml(item?.severity)}">${escapeHtml(item?.severity)}</span></td>
        <td>${formatNumber(item?.count)}</td>
        <td>${formatCurrency(item?.impact_eur)}</td>
        <td><span class="access-pill access-${escapeHtml(item?.access_state)}">${escapeHtml(item?.access_label)}</span></td>
      </tr>
    `;
  }).join('');
}

function renderLockedPanels(items, visibility) {
  const host = byId('locked-panel-stack');
  if (!host) return;
  host.innerHTML = '';
  if (visibility?.show_issue_details) {
    host.innerHTML = `
      <article class="panel unlocked-panel">
        <div class="panel-header"><h2>Premium insights</h2><span class="muted">Unlocked</span></div>
        <p class="panel-copy">Recommendations, record-level details, and BC actions are available for the active scan.</p>
        <div class="panel-note">Use the Top Findings list to prioritize the next fixes.</div>
      </article>
    `;
    return;
  }
  (items || []).forEach((item) => {
    const card = document.createElement('article');
    card.className = 'panel locked-panel';
    card.innerHTML = `
      <div class="lock-icon">🔒</div>
      <h3>${escapeHtml(item?.title)}</h3>
      <p>${escapeHtml(item?.body)}</p>
      <button type="button" class="cta-button subtle">${escapeHtml(item?.cta)}</button>
    `;
    host.appendChild(card);
  });
}

function renderBenefits(items) {
  const host = byId('premium-benefits');
  if (!host) return;
  host.innerHTML = '';
  (items || []).forEach((item) => {
    const li = document.createElement('li');
    li.innerHTML = `<span class="benefit-bullet">✓</span><span>${escapeHtml(item)}</span>`;
    host.appendChild(li);
  });
}

function applyVisibility(data) {
  const visibility = data?.visibility || {};
  const license = data?.license || {};
  const isPremium = Boolean(license?.is_premium);

  setText('license-plan-badge', isPremium ? 'Premium active' : 'Free insight');
  byId('license-plan-badge')?.classList.toggle('success-pill', isPremium);

  setText('price-card-label', isPremium ? 'Premium / Monat' : 'Premium unlock');
  setText('price-card-helper', isPremium ? 'Configured target price' : 'Unlock records, recommendations, and actions');
  setText('roi-card-label', visibility.show_roi ? 'ROI' : 'Potential Saving');
  setText('roi-card-helper', visibility.show_roi ? 'Potential minus annual cost' : 'Available in Premium');
  setText('kpi-roi', visibility.show_roi ? formatCurrency(data?.kpis?.roi_eur) : formatCurrency(data?.kpis?.potential_saving_eur));
  setHidden('upgrade-band', !visibility.show_upgrade_cta);
  byId('benefits-panel')?.classList.toggle('premium-live', isPremium);
  setText('findings-subtitle', isPremium ? 'Prioritized actions and recommendations' : 'Visible in Free, actionable in Premium');
}

function applyHero(data) {
  setText('hero-eyebrow', data?.hero?.eyebrow || '');
  setText('hero-title', data?.hero?.title || '');
  setText('hero-subtitle', data?.hero?.subtitle || '');
  setText('hero-cta-button', data?.hero?.cta_title || 'Unlock Premium');
  setText('hero-cta-title', data?.hero?.cta_price_hint || '');
  setText('hero-cta-body', data?.hero?.cta_body || '');
  setText('hero-highlight-title', data?.hero?.highlight_title || '');
  setText('hero-highlight-body', data?.hero?.highlight_body || '');
  setText('hero-price-hint', data?.hero?.cta_price_hint || '');
}

async function loadDashboard(scanId = null) {
  const token = document.body?.dataset?.token;
  if (!token) return;

  const url = new URL('/analytics/embed/data', window.location.origin);
  url.searchParams.set('token', token);
  if (scanId) url.searchParams.set('scan_id', scanId);

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
    setText('kpi-loss', formatCurrency(data?.kpis?.estimated_loss_eur));
    setText('kpi-price', formatCurrency(data?.kpis?.estimated_premium_price_monthly));
    setText('kpi-checks', formatNumber(data?.kpis?.checks_run));
    setText('kpi-issues', formatNumber(data?.kpis?.issues_count));

    applyHero(data);
    applyVisibility(data);
    renderProfileCards(data?.profile_cards || []);
    renderLineChart('trend-chart', data?.score_trend || [], 'Score Trend');
    renderLineChart('loss-trend-chart', data?.loss_trend || [], 'Loss Trend');
    renderRecentScans(data?.recent_scans || []);
    renderIssueGroups(data?.issue_groups || []);
    renderFindings(data?.top_findings || [], data?.visibility || {});
    renderLockedPanels(data?.locked_panels || [], data?.visibility || {});
    renderBenefits(data?.premium_benefits || []);
  } catch (error) {
    console.error('loadDashboard failed:', error);
    setText('page-subtitle', 'Dashboard konnte nicht geladen werden.');
  }
}

function registerEvents() {
  const scansBody = byId('recent-scans-body');
  if (!scansBody) return;

  scansBody.addEventListener('click', async (event) => {
    const row = event.target.closest('.scan-row');
    if (!row) return;
    const scanId = row.dataset.scanId;
    if (!scanId || scanId === currentSelectedScanId) return;
    await loadDashboard(scanId);
  });

  scansBody.addEventListener('keydown', async (event) => {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    const row = event.target.closest('.scan-row');
    if (!row) return;
    event.preventDefault();
    const scanId = row.dataset.scanId;
    if (!scanId || scanId === currentSelectedScanId) return;
    await loadDashboard(scanId);
  });
}

document.addEventListener('DOMContentLoaded', async () => {
  registerEvents();
  await loadDashboard();
});
