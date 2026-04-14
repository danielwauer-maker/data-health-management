// cleaned gauge version
function renderGauge(score) {
  const host = document.getElementById('gauge-meter');
  if (!host) return;

  const safeScore = Math.max(0, Math.min(100, Number(score || 0)));

  const centerX = 160;
  const centerY = 158;
  const outerRadius = 118;
  const innerRadius = 84;

  const segments = [
    { start: 180, end: 108, color: '#ff4d3d', label: 'POOR' },
    { start: 108, end: 72, color: '#f59e0b', label: 'FAIR' },
    { start: 72, end: 45, color: '#facc15', label: 'MODERATE' },
    { start: 45, end: 18, color: '#84cc16', label: 'GOOD' },
    { start: 18, end: 0, color: '#22c55e', label: 'EXCELLENT' },
  ];

  function polarToCartesian(cx, cy, r, angleDeg) {
    const angleRad = (angleDeg - 90) * Math.PI / 180;
    return {
      x: cx + r * Math.cos(angleRad),
      y: cy + r * Math.sin(angleRad),
    };
  }

  function arcPath(cx, cy, r, startAngle, endAngle) {
    const start = polarToCartesian(cx, cy, r, startAngle);
    const end = polarToCartesian(cx, cy, r, endAngle);
    const largeArcFlag = Math.abs(endAngle - startAngle) > 180 ? 1 : 0;
    const sweepFlag = startAngle > endAngle ? 1 : 0;
    return `M ${start.x} ${start.y} A ${r} ${r} 0 ${largeArcFlag} ${sweepFlag} ${end.x} ${end.y}`;
  }

  function ringSlicePath(cx, cy, rOuter, rInner, startAngle, endAngle) {
    const outerStart = polarToCartesian(cx, cy, rOuter, startAngle);
    const outerEnd = polarToCartesian(cx, cy, rOuter, endAngle);
    const innerEnd = polarToCartesian(cx, cy, rInner, endAngle);
    const innerStart = polarToCartesian(cx, cy, rInner, startAngle);
    const largeArcFlag = Math.abs(endAngle - startAngle) > 180 ? 1 : 0;
    const sweepFlagOuter = startAngle > endAngle ? 1 : 0;
    const sweepFlagInner = sweepFlagOuter ? 0 : 1;

    return [
      `M ${outerStart.x} ${outerStart.y}`,
      `A ${rOuter} ${rOuter} 0 ${largeArcFlag} ${sweepFlagOuter} ${outerEnd.x} ${outerEnd.y}`,
      `L ${innerEnd.x} ${innerEnd.y}`,
      `A ${rInner} ${rInner} 0 ${largeArcFlag} ${sweepFlagInner} ${innerStart.x} ${innerStart.y}`,
      'Z'
    ].join(' ');
  }

  const segmentMarkup = segments.map((segment) => {
    return `<path d="${ringSlicePath(centerX, centerY, outerRadius, innerRadius, segment.start, segment.end)}" fill="${segment.color}"></path>`;
  }).join('');

  const pointerAngle = 180 - (safeScore * 1.8);
  const needleLength = 78;
  const radians = (pointerAngle - 90) * (Math.PI / 180);

  const tipX = centerX + needleLength * Math.cos(radians);
  const tipY = centerY + needleLength * Math.sin(radians);

  host.innerHTML = `
    <svg viewBox="0 0 320 290">
      ${segmentMarkup}
      <line x1="${centerX}" y1="${centerY}" x2="${tipX}" y2="${tipY}" stroke="#111" stroke-width="4"/>
    </svg>
  `;
}
