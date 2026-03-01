import { getPoints, addPoints, redeemPoints, showToast, getHistory, exportPointsState, importPointsState } from './src/points/points.js';

async function updatePointsUI() {
  document.getElementById('points-count').textContent = await getPoints();
}
async function onAddCard(card) {
  await addPoints(5,'add_card',card.id); showToast("+5 💎 LifeHub Points!"); updatePointsUI();
}
async function onGenerateAISummary(card) {
  await addPoints(10,'ai_summary',card.id); showToast("+10 💎 LifeHub Points!"); updatePointsUI();
}
updatePointsUI();

// Panel nagród — handlers
document.getElementById('rewards-btn').onclick=()=>{
  document.getElementById('rewards-modal').classList.remove('hidden');
};
document.getElementById('close-rewards').onclick=()=>{
  document.getElementById('rewards-modal').classList.add('hidden');
};
document.querySelectorAll('.redeem-btn').forEach(b=>{
  b.onclick=async()=>{
    const c=parseInt(b.dataset.cost),r=b.dataset.reward;
    if(await redeemPoints(c,r))
      showToast(`🎉 Odblokowano: ${r}`);
    else showToast(`❌ Za mało punktów!`);
    updatePointsUI();
  }
});

// Panel historii, backup/import
document.getElementById('history-btn').onclick= async ()=>{
  document.getElementById('history-modal').classList.remove('hidden');
  // render historia
  const hist=await getHistory(); const tbody=document.getElementById('history-table');
  tbody.innerHTML=hist.slice(-100).reverse().map(ev=>`
    <tr>
      <td>${new Date(ev.timestamp).toLocaleString()}</td>
      <td>${ev.action.replace("_"," ")}</td>
      <td>${ev.points}</td>
    </tr>`).join("");
};
document.getElementById('close-history').onclick=()=>{
  document.getElementById('history-modal').classList.add('hidden');
};
document.getElementById('history-export').onclick= async ()=>{
  const json=await exportPointsState();
  const blob = new Blob([json], {type:"application/json"});
  const a=document.createElement("a");
  a.href=URL.createObjectURL(blob); a.download="lifehub-points-backup.json";
  document.body.appendChild(a); a.click(); a.remove();
};
document.getElementById('history-table').addEventListener('dblclick', function(e){
  if(e.target.tagName==='TD' && e.target.parentNode)
    showToast("ID akcji: "+(e.target.parentNode.dataset.id||"n/a"));
});
document.getElementById('history-modal').onkeydown = e=>{
  if(e.key==="Escape") document.getElementById('history-modal').classList.add('hidden');
};
document.getElementById('history-import').onchange = async (ev)=>{
  const file = ev.target.files[0]; if (!file) return;
  let json = await file.text();
  if(await importPointsState(json)) showToast("Backup przywrócony!"); else showToast("Błąd pliku backup.");
  updatePointsUI();
};

window.addEventListener("keydown",e=>{
  if(e.key==="Escape") document.querySelectorAll('.modal:not(.hidden)').forEach(m=>m.classList.add('hidden'));
});