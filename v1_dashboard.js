import { getPoints, addPoints, redeemPoints, showToast } from './src/points/points.js';

async function updatePointsUI() {
  document.getElementById('points-count').textContent = await getPoints();
}

// Przykład obsługi akcji:
async function onAddCard(card) {
  await addPoints(5,'add_card',card.id);
  showToast("+5 💎 LifeHub Points!");
  updatePointsUI();
}
async function onGenerateAISummary(card) {
  await addPoints(10,'ai_summary',card.id);
  showToast("+10 💎 LifeHub Points!");
  updatePointsUI();
}
updatePointsUI();

// Panel nagród — handlers:
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

// Możesz też obsługiwać backup/import w podobnym stylu — patrz points.js!