// analytics-dashboard.js
function renderModuleScores(data){
  const el=document.getElementById("profile-cards");
  el.innerHTML="";
  (data||[]).forEach(m=>{
    const d=document.createElement("div");
    d.className="mini-card score-"+m.variant;
    d.innerHTML=`<div class="score">${m.score}</div><div>${m.name}</div>`;
    el.appendChild(d);
  });
}
