function byId(id) {
  return document.getElementById(id);
}

let currentSelectedScanId = null;
let currentRecentScansPage = 1;

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

  renderRecentScans(data.recent_scans || []);
  renderRecentScansPagination(data.recent_scans_pagination || {});
}

function renderRecentScans(scans) {
  const tbody = byId('recent-scans-body');
  if (!tbody) return;

  tbody.innerHTML = '';

  if (!scans.length) {
    tbody.innerHTML = '<tr><td colspan="5" class="table-empty">No scans available</td></tr>';
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

    tr.addEventListener('click', async () => {
      await loadDashboard(scan.scan_id, currentRecentScansPage);
    });

    tbody.appendChild(tr);
  });
}

function renderRecentScansPagination(pagination) {
  const prevBtn = byId('recent-scans-prev');
  const nextBtn = byId('recent-scans-next');
  const pageInfo = byId('recent-scans-page-info');

  const page = Number(pagination?.page || 1);
  const totalPages = Number(pagination?.total_pages || 1);
  const hasPrev = Boolean(pagination?.has_prev);
  const hasNext = Boolean(pagination?.has_next);

  if (pageInfo) {
    pageInfo.textContent = `Page ${page} / ${totalPages}`;
  }

  if (prevBtn) {
    prevBtn.disabled = !hasPrev;
  }

  if (nextBtn) {
    nextBtn.disabled = !hasNext;
  }
}

function registerEvents() {
  const prevBtn = byId('recent-scans-prev');
  const nextBtn = byId('recent-scans-next');

  if (prevBtn) {
    prevBtn.addEventListener('click', async () => {
      if (currentRecentScansPage <= 1) return;
      await loadDashboard(currentSelectedScanId, currentRecentScansPage - 1);
    });
  }

  if (nextBtn) {
    nextBtn.addEventListener('click', async () => {
      await loadDashboard(currentSelectedScanId, currentRecentScansPage + 1);
    });
  }
}

document.addEventListener('DOMContentLoaded', async () => {
  registerEvents();
  await loadDashboard();
});