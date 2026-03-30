function byId(id) {
  return document.getElementById(id);
}

let currentSelectedScanId = null;
let currentRecentScansPage = 1;

/* =========================
   MAIN LOAD
========================= */
async function loadDashboard(scanId = null, recentScansPage = currentRecentScansPage) {
  const token = document.body.dataset.token;

  const url = new URL('/analytics/embed/data', window.location.origin);
  url.searchParams.set('token', token);

  if (scanId) {
    url.searchParams.set('scan_id', scanId);
  }

  url.searchParams.set('recent_scans_page', String(recentScansPage));
  url.searchParams.set('recent_scans_page_size', '10');

  const response = await fetch(url);
  const data = await response.json();

  currentSelectedScanId = data.selected_scan_id || null;
  currentRecentScansPage = Number(data?.recent_scans_pagination?.page || 1);

  renderHeader(data);
  renderHero(data.hero);
  renderKPIs(data.kpis);
  renderProfile(data.profile_cards);
  renderIssueGroups(data.issue_groups);

  renderRecentScans(data.recent_scans || []);
  renderRecentScansPagination(data.recent_scans_pagination || {});

  renderVisibility(data.visibility);
  renderSubscription(data.subscription);

  // Wichtig → Loading entfernen
  const subtitle = byId('page-subtitle');
  if (subtitle) {
    subtitle.textContent = data.subtitle || '';
  }

  const lastUpdated = byId('last-updated');
  if (lastUpdated) {
    lastUpdated.textContent = `Last updated: ${data.last_updated || '—'}`;
  }
}

/* =========================
   HEADER / HERO
========================= */
function renderHeader(data) {
  const badge = byId('current-plan-badge');
  if (badge) {
    badge.textContent = data.current_plan?.toUpperCase() || 'FREE';
    badge.classList.toggle('is-free', data.current_plan === 'free');
  }
}

function renderHero(hero) {
  if (!hero) return;

  byId('hero-eyebrow').textContent = hero.eyebrow || '';
  byId('hero-prefix').textContent = hero.headline_prefix || '';
  byId('hero-highlight').textContent = hero.headline_highlight || '';
  byId('hero-suffix').textContent = hero.headline_suffix || '';
}

/* =========================
   KPIs
========================= */
function renderKPIs(kpis) {
  if (!kpis) return;

  byId('kpi-score').textContent = kpis.health_score ?? 0;
  byId('kpi-records').textContent = kpis.total_records ?? 0;
  byId('kpi-affected-records').textContent = kpis.affected_records ?? 0;
  byId('kpi-loss').textContent = `${kpis.estimated_loss_eur ?? 0} €`;
  byId('kpi-checks').textContent = kpis.checks_run ?? 0;
  byId('kpi-issues').textContent = kpis.issues_count ?? 0;
  byId('kpi-price').textContent = `${kpis.estimated_premium_price_monthly ?? 0} €`;
  byId('kpi-roi').textContent = `${kpis.roi_eur ?? 0} €`;
}

/* =========================
   PROFILE
========================= */
function renderProfile(cards) {
  const container = byId('profile-cards');
  if (!container) return;

  container.innerHTML = '';

  (cards || []).forEach(c => {
    const div = document.createElement('div');
    div.className = 'mini-card';
    div.innerHTML = `
      <div class="mini-card-value">${c.value}</div>
      <div class="mini-card-label">${c.label}</div>
    `;
    container.appendChild(div);
  });
}

/* =========================
   ISSUE GROUPS
========================= */
function renderIssueGroups(groups) {
  const container = byId('issue-groups');
  if (!container) return;

  container.innerHTML = '';

  (groups || []).forEach(g => {
    const div = document.createElement('div');
    div.className = 'progress-row';
    div.innerHTML = `
      <div class="progress-meta">
        <span>${g.name}</span>
        <span>${g.count}</span>
      </div>
      <div class="progress-track">
        <div class="progress-fill" style="width:${Math.min(g.count, 100)}%"></div>
      </div>
    `;
    container.appendChild(div);
  });
}

/* =========================
   RECENT SCANS
========================= */
function renderRecentScans(scans) {
  const tbody = byId('recent-scans-body');
  if (!tbody) return;

  tbody.innerHTML = '';

  if (!scans.length) {
    tbody.innerHTML = '<tr><td colspan="5">No scans available</td></tr>';
    return;
  }

  scans.forEach(scan => {
    const tr = document.createElement('tr');
    tr.className = 'scan-row' + (scan.is_selected ? ' is-selected' : '');

    tr.innerHTML = `
      <td>${scan.generated_at}</td>
      <td>${scan.scan_type}</td>
      <td>${scan.data_score}</td>
      <td>${scan.issues_count}</td>
      <td>${scan.headline || ''}</td>
    `;

    tr.onclick = () => loadDashboard(scan.scan_id, currentRecentScansPage);

    tbody.appendChild(tr);
  });
}

function renderRecentScansPagination(pagination) {
  const prevBtn = byId('recent-scans-prev');
  const nextBtn = byId('recent-scans-next');
  const pageInfo = byId('recent-scans-page-info');

  const page = pagination.page || 1;
  const total = pagination.total_pages || 1;

  if (pageInfo) pageInfo.textContent = `Page ${page} / ${total}`;
  if (prevBtn) prevBtn.disabled = !pagination.has_prev;
  if (nextBtn) nextBtn.disabled = !pagination.has_next;
}

/* =========================
   VISIBILITY
========================= */
function renderVisibility(v) {
  if (!v) return;

  toggle('premium-overview-panels', v.is_premium);
  toggle('premium-findings-panel', v.is_premium);
  toggle('free-unlock-panel', v.show_upgrade_preview);
}

function toggle(id, show) {
  const el = byId(id);
  if (!el) return;
  el.classList.toggle('hidden', !show);
}

/* =========================
   SUBSCRIPTION
========================= */
function renderSubscription(sub) {
  if (!sub) return;

  byId('subscription-plan').textContent = sub.plan_label || '';
  byId('subscription-price').textContent = `${sub.price_monthly || 0} €`;
  byId('subscription-annual').textContent = `${sub.annual_cost || 0} €`;
}

/* =========================
   EVENTS
========================= */
function registerEvents() {
  byId('recent-scans-prev')?.addEventListener('click', () => {
    if (currentRecentScansPage > 1) {
      loadDashboard(currentSelectedScanId, currentRecentScansPage - 1);
    }
  });

  byId('recent-scans-next')?.addEventListener('click', () => {
    loadDashboard(currentSelectedScanId, currentRecentScansPage + 1);
  });
}

/* =========================
   INIT
========================= */
document.addEventListener('DOMContentLoaded', async () => {
  registerEvents();
  await loadDashboard();
});