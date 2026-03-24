function formatNumber(value) {
  return new Intl.NumberFormat('de-DE').format(Number(value || 0));
}
function formatCurrency(value) {
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR', maximumFractionDigits: 2 }).format(Number(value || 0));
}
function renderProfileCards(items) {
  const host = document.getElementById('profile-cards');
  host.innerHTML = '';
  items.forEach((item) => {
    const card = document.createElement('div');
    card.className = 'mini-card';
    card.innerHTML = `<div class="mini-card-value">${formatNumber(item.value)}</div><div class="mini-card-label">${item.label}</div>`;
    host.appendChild(card);
  });
}
function renderTrend(items) {
  const host = document.getElementById('trend-bars');
  host.innerHTML = '';
  const maxValue = Math.max(...items.map((item) => Number(item.value || 0)), 1);
  items.forEach((item) => {
    const wrapper = document.createElement('div');
    wrapper.className = 'bar-item';
    const height = Math.max((Number(item.value || 0) / maxValue) * 180, 14);
    wrapper.innerHTML = `<div class="bar" style="height:${height}px"></div><div>${formatNumber(item.value)}</div><div class="bar-label">${item.label}</div>`;
    host.appendChild(wrapper);
  });
}
function renderRecentScans(items) {
  const host = document.getElementById('recent-scans-body');
  host.innerHTML = items.map((item) => `<tr><td>${item.generated_at}</td><td>${item.scan_type}</td><td>${formatNumber(item.data_score)}</td><td>${formatNumber(item.issues_count)}</td><td>${item.headline || ''}</td></tr>`).join('');
}
function renderIssueGroups(items) {
  const host = document.getElementById('issue-groups');
  host.innerHTML = '';
  const maxValue = Math.max(...items.map((item) => Number(item.count || 0)), 1);
  items.forEach((item) => {
    const width = Math.max((Number(item.count || 0) / maxValue) * 100, 2);
    const row = document.createElement('div');
    row.className = 'progress-row';
    row.innerHTML = `<div class="progress-meta"><span>${item.name}</span><span>${formatNumber(item.count)}</span></div><div class="progress-track"><div class="progress-fill" style="width:${width}%"></div></div>`;
    host.appendChild(row);
  });
}
function renderFindings(items) {
  const host = document.getElementById('findings-body');
  host.innerHTML = items.map((item) => `<tr><td>${item.code}</td><td>${item.title}</td><td>${item.group}</td><td>${item.severity}</td><td>${formatNumber(item.count)}</td><td>${formatCurrency(item.impact_eur)}</td></tr>`).join('');
}
async function loadDashboard() {
  const token = document.body.dataset.token;
  const response = await fetch(`/analytics/embed/data?token=${encodeURIComponent(token)}`);
  if (!response.ok) {
    document.getElementById('page-subtitle').textContent = 'Dashboard konnte nicht geladen werden.';
    return;
  }
  const data = await response.json();
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
loadDashboard();
