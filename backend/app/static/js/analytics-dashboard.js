let currentSelectedScanId = null;
let recentScansPage = 1;
const RECENT_SCANS_PAGE_SIZE = 12;
let currentDashboardState = null;
let currentModuleVolumeView = 'issues';

function byId(id) {
  return document.getElementById(id);
}

function formatNumber(value) {
  return new Intl.NumberFormat('en-US').format(Number(value || 0));
}

function formatCurrency(value) {
  const number = Number(value || 0);
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "EUR",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(number);
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
  const el = document.getElementById(id);
  if (el) el.textContent = value ?? "";
}

function setHtml(id, value) {
  const el = byId(id);
  if (el) el.innerHTML = value;
}

function scoreBand(score) {
  const safeScore = Math.max(0, Math.min(100, Number(score || 0)));
  if (safeScore <= 60) return 'critical';
  if (safeScore <= 75) return 'warning';
  if (safeScore <= 85) return 'moderate';
  if (safeScore <= 95) return 'good';
  return 'excellent';
}

function scoreBandMeta(score) {
  const band = scoreBand(score);
  const meta = {
    critical: { gaugeLabel: 'Poor', badgeClass: 'critical', colorHex: '#f44336' },
    warning: { gaugeLabel: 'Fair', badgeClass: 'warning', colorHex: '#fb8c00' },
    moderate: { gaugeLabel: 'Normal', badgeClass: 'moderate', colorHex: '#facc15' },
    good: { gaugeLabel: 'Good', badgeClass: 'good', colorHex: '#84cc16' },
    excellent: { gaugeLabel: 'Super', badgeClass: 'excellent', colorHex: '#16a34a' },
  };
  return { band, ...(meta[band] || meta.critical) };
}

function renderPricingBreakdown(data) {
  const breakdown = data?.pricing_breakdown || {};
  const subscription = data?.subscription || {};
  const subscriptionBreakdown = subscription?.pricing_breakdown || breakdown;
  const billingOptions = subscription?.billing_options || {};

  setText("preview-base-price", formatCurrency(breakdown.base_price_monthly));
  setText("preview-variable-price", formatCurrency(breakdown.variable_price_monthly));
  setText("preview-final-price", formatCurrency(breakdown.final_price_monthly));
  setText("preview-annual-fixed", formatCurrency(breakdown.annual_fixed_price));
  setText("preview-monthly-note", breakdown.monthly_note || "");
  setText("preview-annual-note", breakdown.annual_note || "");

  setText("subscription-base-price", formatCurrency(subscriptionBreakdown.base_price_monthly));
  setText("subscription-variable-price", formatCurrency(subscriptionBreakdown.variable_price_monthly));
  setText("subscription-final-price", formatCurrency(subscriptionBreakdown.final_price_monthly));
  setText("subscription-annual-fixed", formatCurrency(subscriptionBreakdown.annual_fixed_price));

  setText("subscription-monthly-label", billingOptions.monthly_label || "Monthly billing");
  setText("subscription-monthly-note", billingOptions.monthly_note || "");
  setText("subscription-annual-label", billingOptions.annual_label || "Annual fixed plan");
  setText("subscription-annual-note", billingOptions.annual_note || "");
}


function renderGauge(score) {
  const host = byId('gauge-meter');
  if (!host) return;

  const safeScore = Math.max(0, Math.min(100, Number(score || 0)));
  const meta = scoreBandMeta(safeScore);

  const centerX = 160;
  const centerY = 174;
  const outerRadius = 124;
  const innerRadius = 88;
  const labelRadius = 103;

  const segments = [
    { label: 'Poor', start: 180, end: 108, className: 'critical' },
    { label: 'Fair', start: 108, end: 72, className: 'warning' },
    { label: 'Moderate', start: 72, end: 45, className: 'moderate' },
    { label: 'Good', start: 45, end: 18, className: 'info' },
    { label: 'Excellent', start: 18, end: 0, className: 'excellent' },
  ];

  function polarToCartesian(cx, cy, radius, angleDeg) {
    const radians = (angleDeg - 90) * (Math.PI / 180);
    return {
      x: cx + radius * Math.cos(radians),
      y: cy + radius * Math.sin(radians),
    };
  }

  function arcPath(cx, cy, radius, startAngle, endAngle) {
    const start = polarToCartesian(cx, cy, radius, startAngle);
    const end = polarToCartesian(cx, cy, radius, endAngle);
    const largeArcFlag = Math.abs(endAngle - startAngle) > 180 ? 1 : 0;
    const sweepFlag = startAngle > endAngle ? 1 : 0;
    return `M ${start.x} ${start.y} A ${radius} ${radius} 0 ${largeArcFlag} ${sweepFlag} ${end.x} ${end.y}`;
  }

  function ringSlicePath(cx, cy, outerR, innerR, startAngle, endAngle) {
    const outerStart = polarToCartesian(cx, cy, outerR, startAngle);
    const outerEnd = polarToCartesian(cx, cy, outerR, endAngle);
    const innerEnd = polarToCartesian(cx, cy, innerR, endAngle);
    const innerStart = polarToCartesian(cx, cy, innerR, startAngle);
    const largeArcFlag = Math.abs(endAngle - startAngle) > 180 ? 1 : 0;
    const sweepFlagOuter = startAngle > endAngle ? 1 : 0;
    const sweepFlagInner = sweepFlagOuter ? 0 : 1;

    return [
      `M ${outerStart.x} ${outerStart.y}`,
      `A ${outerR} ${outerR} 0 ${largeArcFlag} ${sweepFlagOuter} ${outerEnd.x} ${outerEnd.y}`,
      `L ${innerEnd.x} ${innerEnd.y}`,
      `A ${innerR} ${innerR} 0 ${largeArcFlag} ${sweepFlagInner} ${innerStart.x} ${innerStart.y}`,
      'Z',
    ].join(' ');
  }

  function labelPosition(angleDeg) {
    return polarToCartesian(centerX, centerY, labelRadius, angleDeg);
  }

  const segmentMarkup = segments.map((segment) => {
    const textPos = labelPosition((segment.start + segment.end) / 2);
    const rotation = ((segment.start + segment.end) / 2) - 90;

    return `
      <g class="gauge-segment-group">
        <path d="${ringSlicePath(centerX, centerY, outerRadius, innerRadius, segment.start, segment.end)}"
              class="gauge-segment ${segment.className}"></path>
        <path d="${arcPath(centerX, centerY, innerRadius - 5, segment.start - 1.5, segment.end + 1.5)}"
              class="gauge-segment-inner-outline"></path>
        <text x="${textPos.x}" y="${textPos.y}" text-anchor="middle"
              class="gauge-band-label"
              transform="rotate(${rotation} ${textPos.x} ${textPos.y})">${segment.label}</text>
      </g>
    `;
  }).join('');

  const pointerAngle = 180 - (safeScore * 1.8);
  const radians = (pointerAngle - 90) * (Math.PI / 180);
  const needleLength = 88;
  const needleBaseHalf = 9;
  const tipX = centerX + needleLength * Math.cos(radians);
  const tipY = centerY + needleLength * Math.sin(radians);
  const baseLeftX = centerX + needleBaseHalf * Math.cos(radians + Math.PI / 2);
  const baseLeftY = centerY + needleBaseHalf * Math.sin(radians + Math.PI / 2);
  const baseRightX = centerX + needleBaseHalf * Math.cos(radians - Math.PI / 2);
  const baseRightY = centerY + needleBaseHalf * Math.sin(radians - Math.PI / 2);
  const badgeY = 244;

  host.innerHTML = `
    <svg viewBox="0 0 320 300" class="gauge-svg gauge-dial gauge-tone-${meta.band}" role="img" aria-label="Data health gauge ${safeScore}">
      <defs>
        <filter id="gaugeShadow" x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="12" stdDeviation="12" flood-color="rgba(15,35,64,0.10)"/>
        </filter>
      </defs>
      <path d="M 62 156 Q 68 274 160 274 Q 252 274 258 156" class="gauge-base-shell"></path>
      <path d="${arcPath(centerX, centerY, outerRadius, 180, 0)}" class="gauge-dial-shadow"></path>
      ${segmentMarkup}
      <circle cx="${centerX}" cy="${centerY}" r="64" class="gauge-center-disc"></circle>
      <path d="M ${baseLeftX} ${baseLeftY} L ${tipX} ${tipY} L ${baseRightX} ${baseRightY} Z" class="gauge-needle"></path>
      <circle cx="${centerX}" cy="${centerY}" r="18" class="gauge-needle-cap"></circle>
      <circle cx="${centerX}" cy="${centerY}" r="10" class="gauge-needle-cap-inner"></circle>
      <g transform="translate(${centerX - 44}, ${badgeY})">
        <rect width="88" height="40" rx="10" class="gauge-value-badge ${meta.badgeClass}"></rect>
        <text x="44" y="27" text-anchor="middle" class="gauge-value-text">${formatNumber(safeScore)}</text>
      </g>
      <text x="${centerX}" y="228" text-anchor="middle" class="gauge-caption">Data Health Score</text>
    </svg>
  `;
}

function renderHeroPoints(items) {
  const host = byId('hero-points');
  if (!host) return;
  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '';
    host.classList.add('hidden');
    return;
  }
  host.classList.remove('hidden');
  host.innerHTML = items.map((item) => `<li>${escapeHtml(item)}</li>`).join('');
}

function renderProfileCards(moduleScores, fallbackItems) {
  const host = byId('profile-cards');
  if (!host) return;
  host.innerHTML = '';

  const scoreItems = Array.isArray(moduleScores) ? moduleScores.filter(Boolean) : [];
  const fallback = Array.isArray(fallbackItems) ? fallbackItems.filter(Boolean) : [];

  if (scoreItems.length > 0) {
    scoreItems.forEach((item) => {
      const score = Math.max(0, Math.min(100, Number(item?.score ?? item?.value ?? 0)));
      const variant = item?.variant || scoreBand(score);
      const label = item?.name || item?.label || '';
      const badgeText = variant.charAt(0).toUpperCase() + variant.slice(1);

      const card = document.createElement('div');
      card.className = `mini-card score-card score-${variant}`;
      card.innerHTML = `
        <div class="mini-card-top">
          <div class="mini-card-value">${formatNumber(score)}</div>
          <div class="mini-score-badge score-${variant}">${escapeHtml(badgeText)}</div>
        </div>
        <div class="mini-card-label">${escapeHtml(label)}</div>
      `;
      host.appendChild(card);
    });
    return;
  }

  if (fallback.length === 0) {
    host.innerHTML = '<div class="empty-state">No module scores are available yet.</div>';
    return;
  }

  fallback.forEach((item) => {
    const card = document.createElement('div');
    card.className = 'mini-card';
    card.innerHTML = `
      <div class="mini-card-value">${formatNumber(item?.value)}</div>
      <div class="mini-card-label">${escapeHtml(item?.label)}</div>
    `;
    host.appendChild(card);
  });
}

function renderIssueGroups(items, emptyMessage = 'No module data is available for this scan.') {
  const host = byId('issue-groups');
  if (!host) return;
  host.innerHTML = '';

  const normalizedItems = Array.isArray(items)
    ? items.filter(Boolean).map((item) => ({
        name: item?.name || item?.label || '',
        count: Number(item?.count ?? item?.value ?? 0),
      }))
    : [];

  if (normalizedItems.length === 0) {
    host.innerHTML = `<div class="empty-state">${escapeHtml(emptyMessage)}</div>`;
    return;
  }

  const maxValue = Math.max(...normalizedItems.map((item) => Number(item?.count || 0)), 1);

  normalizedItems.forEach((item) => {
    const width = Math.max((Number(item?.count || 0) / maxValue) * 100, 2);
    const row = document.createElement('div');
    row.className = 'progress-row';
    row.innerHTML = `
      <div class="progress-meta">
        <span>${escapeHtml(item?.name)}</span>
        <span>${formatNumber(item?.count)}</span>
      </div>
      <div class="progress-track"><div class="progress-fill" style="width:${width}%"></div></div>
    `;
    host.appendChild(row);
  });
}

function setModuleVolumeToggleState(view) {
  currentModuleVolumeView = view === 'records' ? 'records' : 'issues';

  document.querySelectorAll('[data-module-view]').forEach((button) => {
    const isActive = button.dataset.moduleView === currentModuleVolumeView;
    button.classList.toggle('is-active', isActive);
    button.setAttribute('aria-pressed', isActive ? 'true' : 'false');
  });

  const kicker = byId('module-volume-kicker');
  const title = byId('module-volume-title');
  const subtitle = byId('module-volume-subtitle');

  if (currentModuleVolumeView === 'records') {
    if (kicker) kicker.textContent = 'Data Volume';
    if (title) title.textContent = 'Records by BC module';
    if (subtitle) subtitle.textContent = 'Scanned records per module';
  } else {
    if (kicker) kicker.textContent = 'Issue Volume';
    if (title) title.textContent = 'Issues by BC module';
    if (subtitle) subtitle.textContent = 'Affected findings per module';
  }
}

function renderModuleVolume(data) {
  const issueGroups = Array.isArray(data?.issue_groups) ? data.issue_groups : [];
  const moduleCounts = data?.module_counts && typeof data.module_counts === 'object'
    ? Object.entries(data.module_counts).map(([name, count]) => ({ name, count }))
    : [];

  const hasRecords = moduleCounts.some((item) => Number(item?.count || 0) > 0);
  const preferredView = currentModuleVolumeView === 'records' && hasRecords ? 'records' : 'issues';

  setModuleVolumeToggleState(preferredView);

  if (preferredView === 'records') {
    renderIssueGroups(moduleCounts, 'No module record counts are available for this scan.');
    return;
  }

  renderIssueGroups(issueGroups, 'No module issue counts are available for this scan.');
}
function renderTrend(containerId, items, asCurrency = false) {
  const host = byId(containerId);
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
  const paddingX = 34;
  const paddingTop = 24;
  const paddingBottom = 39;
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
  const areaPoints = `${paddingX},${height - paddingBottom} ${polylinePoints} ${width - paddingX},${height - paddingBottom}`;

  const gridLines = [0, 0.5, 1].map((ratio) => {
    const y = paddingTop + usableHeight - usableHeight * ratio;
    const labelValue = maxValue * ratio;
    const label = asCurrency ? formatCurrency(labelValue).replace(',00', '') : formatNumber(Math.round(labelValue));
    return `
      <line x1="${paddingX}" y1="${y}" x2="${width - paddingX}" y2="${y}" class="trend-grid-line"></line>
      <text x="${paddingX - 10}" y="${y + 4}" text-anchor="end" class="trend-axis-label">${escapeHtml(label)}</text>
    `;
  }).join('');

  const pointCircles = points.map((point) => `
    <circle cx="${point.x}" cy="${point.y}" r="${point.is_selected ? 6 : 4}" class="trend-point${point.is_selected ? ' is-selected' : ''}"></circle>
  `).join('');

  const xLabels = points.map((point) => `
    <text x="${point.x}" y="${height - 14}" text-anchor="middle" class="trend-axis-label">${escapeHtml(point.label)}</text>
  `).join('');

  host.innerHTML = `
    <svg viewBox="0 0 ${width} ${height}" class="trend-svg" role="img">
      ${gridLines}
      <polygon points="${areaPoints}" class="trend-area"></polygon>
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
      <td>${formatNumber(item?.data_score)}</td>
      <td>${formatNumber(item?.issues_count)}</td>
      <td>${escapeHtml(item?.headline || '')}</td>
    </tr>
  `).join('');
}

function renderRecentScansPagination(pagination) {
  const prevButton = byId('recent-scans-prev');
  const nextButton = byId('recent-scans-next');
  const pageInfo = byId('recent-scans-page-info');
  const container = byId('recent-scans-pagination');
  if (!prevButton || !nextButton || !pageInfo || !container) return;

  const page = Math.max(1, Number(pagination?.page || 1));
  const totalPages = Math.max(1, Number(pagination?.total_pages || 1));
  const hasPrev = Boolean(pagination?.has_prev);
  const hasNext = Boolean(pagination?.has_next);
  const totalItems = Math.max(0, Number(pagination?.total_items || 0));

  recentScansPage = page;
  prevButton.disabled = !hasPrev;
  nextButton.disabled = !hasNext;
  pageInfo.textContent = `Page ${page} / ${totalPages}`;
  container.classList.toggle('hidden', totalItems <= RECENT_SCANS_PAGE_SIZE);
}

function renderFindings(items, isPremium) {
  const host = byId('findings-body');
  if (!host) return;

  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<tr><td colspan="6" class="table-empty">No findings are available for this scan.</td></tr>';
    return;
  }

  host.innerHTML = items.map((item) => {
    const accessClass = isPremium ? 'premium' : 'locked';
    const accessLabel = isPremium ? 'Open in BC' : 'Premium';
    const openInBcUrl = String(item?.open_in_bc_url || '');
    warnOnInvalidBcCompanyFormat(openInBcUrl);
    const accessMarkup = isPremium && openInBcUrl
      ? `<a href="${escapeHtml(openInBcUrl)}" class="access-chip ${accessClass}" target="_blank" rel="noopener noreferrer">${accessLabel}</a>`
      : `<span class="access-chip ${accessClass}">${accessLabel}</span>`;
    return `
      <tr>
        <td><strong>${escapeHtml(item?.title)}</strong></td>
        <td>${escapeHtml(item?.group)}</td>
        <td><span class="severity severity-${escapeHtml(item?.severity)}">${escapeHtml(String(item?.severity || '').toUpperCase())}</span></td>
        <td>${formatNumber(item?.count)}</td>
        <td>${formatCurrency(item?.impact_eur)}</td>
        <td>${accessMarkup}</td>
      </tr>
    `;
  }).join('');
}

function warnOnInvalidBcCompanyFormat(url) {
  const match = String(url || '').match(/[?&]company=([^&#]+)/i);
  if (!match) return;

  const companyValue = match[1];
  if (companyValue.includes('+')) {
    console.warn('Invalid company format detected:', companyValue);
  }
}

function renderPremiumPreview(items) {
  const host = byId('premium-preview-findings');
  if (!host) return;
  host.innerHTML = '';

  if (!Array.isArray(items) || items.length === 0) {
    host.innerHTML = '<div class="empty-state">The Premium preview will appear after the next scan.</div>';
    return;
  }

  host.innerHTML = items.map((item) => `
    <article class="preview-card">
      <div class="preview-card-top">
        <div>
          <h4>${escapeHtml(item?.title)}</h4>
          <div class="muted">${escapeHtml(item?.group)}</div>
        </div>
        <div class="preview-impact">${formatCurrency(item?.impact_eur)}</div>
      </div>
      <div class="preview-metrics">
        <span>${formatNumber(item?.count)} affected</span>
        <span>Recommendations available</span>
      </div>
      <p class="muted">${escapeHtml(item?.recommendation_preview || '')}</p>
    </article>
  `).join('');
}

function renderUnlockPanel(data) {
  setText('unlock-headline', data?.premium_unlock?.headline || 'Premium unlocks record-level details and direct action.');
  setText('unlock-body', data?.premium_unlock?.body || 'Upgrade to see exact affected records and recommendations.');
  setText('upgrade-button', data?.premium_unlock?.button_label || 'Upgrade to Premium');

  const host = byId('unlock-highlights');
  if (host) {
    host.innerHTML = (data?.premium_unlock?.highlights || []).map((item) => `<li>${escapeHtml(item)}</li>`).join('');
  }

  renderPremiumPreview(data?.premium_preview_findings || []);
}

function applyPlanState(currentPlan, visibility) {
  const isPremium = Boolean(visibility?.is_premium);
  const planBadge = byId('current-plan-badge');
  const subBadge = byId('subscription-plan-badge');
  const freeUnlock = byId('free-unlock-panel');
  const premiumPanels = byId('premium-overview-panels');
  const findingsPanel = byId('premium-findings-panel');

  if (planBadge) {
    planBadge.textContent = isPremium ? 'Premium' : 'Free';
    planBadge.classList.toggle('is-free', !isPremium);
  }
  if (subBadge) {
    subBadge.textContent = isPremium ? 'Premium' : 'Free';
    subBadge.classList.toggle('is-free', !isPremium);
  }

  if (freeUnlock) freeUnlock.classList.toggle('hidden', isPremium);
  if (premiumPanels) premiumPanels.classList.toggle('hidden', !isPremium);
  if (findingsPanel) findingsPanel.classList.toggle('hidden', !isPremium);
}

function renderSubscription(data) {
  setText('subscription-plan', data?.subscription?.plan_label || 'Free');
  setText('subscription-note', data?.subscription?.plan_note || '');
  setText('subscription-price', formatCurrency(data?.subscription?.price_monthly));
  setText('subscription-annual', formatCurrency(data?.subscription?.annual_cost));
  setText('subscription-cta', data?.subscription?.cta_label || 'Upgrade to Premium');
}

async function triggerBillingAction(action) {
  const endpoint = action === 'portal'
    ? '/analytics/billing/portal'
    : '/analytics/billing/checkout';

  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { Accept: 'application/json' },
      credentials: 'same-origin',
    });

    if (!response.ok) {
      console.error('Billing action failed:', response.status);
      return;
    }

    const payload = await response.json();
    const targetUrl = payload?.portal_url || payload?.checkout_url || '';
    if (!targetUrl) {
      console.error('Billing action did not return a target URL.');
      return;
    }

    window.location.href = targetUrl;
  } catch (error) {
    console.error('Billing action failed:', error);
  }
}

function switchTab(tab) {
  document.querySelectorAll('.topnav-link').forEach((btn) => {
    btn.classList.toggle('is-active', btn.dataset.tab === tab);
  });
  document.querySelectorAll('.tab-panel').forEach((panel) => {
    panel.classList.toggle('hidden', panel.id !== `${tab}-tab`);
    panel.classList.toggle('is-active', panel.id === `${tab}-tab`);
  });
}

async function loadDashboard(scanId = null) {
  const url = new URL('/analytics/embed/data', window.location.origin);
  if (scanId) url.searchParams.set('scan_id', scanId);
  url.searchParams.set('recent_scans_page', String(recentScansPage));
  url.searchParams.set('recent_scans_page_size', String(RECENT_SCANS_PAGE_SIZE));

  try {
    const response = await fetch(url.toString());
    if (!response.ok) {
      setText('page-subtitle', 'The dashboard could not be loaded.');
      return;
    }

    const data = await response.json();
    currentDashboardState = data;
    currentSelectedScanId = data?.selected_scan_id || null;

    setText('page-title', data?.title || 'BCSentinel Analytics');
    setText('page-subtitle', data?.subtitle || '');
    setText('last-updated', `Last updated: ${data?.last_updated || '—'}`);
    setText('hero-eyebrow', data?.hero?.eyebrow || 'Insight is free. Action is Premium.');
    setText('hero-prefix', data?.hero?.headline_prefix || 'Your data health is');
    setText('hero-highlight', data?.hero?.headline_highlight || 'critical');
    setText('hero-suffix', data?.hero?.headline_suffix || '');
    renderHeroPoints(data?.hero?.points || []);
    const heroHighlight = byId('hero-highlight');
    if (heroHighlight) {
      heroHighlight.className = `hero-highlight ${scoreBand(data?.kpis?.health_score)}`;
    }

    setText('kpi-records', formatNumber(data?.kpis?.total_records));
    setText('kpi-affected-records', formatNumber(data?.kpis?.affected_records));
    setText('kpi-checks', formatNumber(data?.kpis?.checks_run));
    setText('kpi-issues', formatNumber(data?.kpis?.issues_count));
    setText('kpi-loss', formatCurrency(data?.kpis?.estimated_loss_eur));
    setText('kpi-roi', formatCurrency(data?.kpis?.roi_eur));

    renderGauge(data?.kpis?.health_score);
    renderProfileCards(data?.module_scores || [], data?.profile_cards || []);
    renderModuleVolume(data);
    renderRecentScans(data?.recent_scans || []);
    renderRecentScansPagination(data?.recent_scans_pagination || {});
    renderTrend('trend-chart', data?.score_trend || []);
    renderTrend('loss-chart', data?.loss_trend || [], true);
    renderFindings(data?.top_findings || [], Boolean(data?.visibility?.is_premium));
    renderUnlockPanel(data);
    renderSubscription(data);
    renderPricingBreakdown(data);
    applyPlanState(data?.current_plan, data?.visibility);
  } catch (error) {
    console.error('loadDashboard failed:', error);
    setText('page-subtitle', 'The dashboard could not be loaded.');
  }
}

function registerEvents() {
  const scansBody = byId('recent-scans-body');
  if (scansBody) {
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

  const prevButton = byId('recent-scans-prev');
  if (prevButton) {
    prevButton.addEventListener('click', async () => {
      if (recentScansPage <= 1) return;
      recentScansPage -= 1;
      await loadDashboard(currentSelectedScanId);
    });
  }

  const nextButton = byId('recent-scans-next');
  if (nextButton) {
    nextButton.addEventListener('click', async () => {
      recentScansPage += 1;
      await loadDashboard(currentSelectedScanId);
    });
  }

  document.querySelectorAll('.topnav-link').forEach((btn) => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab || 'overview'));
  });

  document.querySelectorAll('[data-module-view]').forEach((button) => {
    button.addEventListener('click', () => {
      const view = button.dataset.moduleView === 'records' ? 'records' : 'issues';
      setModuleVolumeToggleState(view);
      renderModuleVolume(currentDashboardState || {});
    });
  });

  const upgradeButton = byId('upgrade-button');
  if (upgradeButton) {
    upgradeButton.addEventListener('click', async () => {
      await triggerBillingAction(currentDashboardState?.premium_unlock?.button_action || 'checkout');
    });
  }

  const subscriptionButton = byId('subscription-cta');
  if (subscriptionButton) {
    subscriptionButton.addEventListener('click', async () => {
      await triggerBillingAction(currentDashboardState?.subscription?.cta_action || 'checkout');
    });
  }
}

document.addEventListener('DOMContentLoaded', () => {
  registerEvents();
  switchTab('overview');
  recentScansPage = 1;
  loadDashboard();
});
