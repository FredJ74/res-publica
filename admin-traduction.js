// Page MJ — Traduction des textes de joueurs (décision n° 10 de Fred, 26/11/2026 : forum, rumeurs de la chronique).
// Interrupteur et plafonds quotidiens par compte (migration 20261126300000). Pour Codex : page MJ, français seulement.
async function admTraductionCharger() {
  const el = document.getElementById('adm-traduction'); if (!el) return;
  el.textContent = 'Chargement…';
  let r;
  try { r = await rpAdminRpc('admin_traduction_lire', {}); } catch (e) { el.textContent = 'Échec : ' + e.message + ' (migration 20261126300000 non appliquée ?)'; return; }
  el.textContent = '';
  if (!r || !r.ok) { el.textContent = 'Refus : ' + (r && r.raison); return; }
  const d = document.createElement('div'); d.className = 'adm-detail';
  const actif = document.createElement('input'); actif.type = 'checkbox'; actif.checked = !!r.actif;
  const req = document.createElement('input'); req.type = 'number'; req.min = 0; req.value = r.requetes_jour; req.style.width = '5rem';
  const car = document.createElement('input'); car.type = 'number'; car.min = 0; car.value = r.caracteres_jour; car.style.width = '7rem';
  const m = document.createElement('span');
  const b = document.createElement('button'); b.type = 'button'; b.textContent = 'Enregistrer';
  b.onclick = async () => {
    try { const x = await rpAdminRpc('admin_traduction_regler', { p_actif: actif.checked, p_requetes: Math.round(Number(req.value)), p_caracteres: Math.round(Number(car.value)) });
      if (x && x.ok) admTraductionCharger(); else m.textContent = ' Refus : ' + (x && x.raison); }
    catch (e) { m.textContent = ' Échec : ' + e.message; }
  };
  const l = document.createElement('label'); l.append(actif, ' Traduction active');
  d.append(l, ' — par compte et par jour : ', req, ' traductions, ', car, ' caractères ', b, m);
  const s = document.createElement('div'); s.className = 'adm-detail';
  s.textContent = 'En cache : ' + r.en_cache + ' traductions ; aujourd’hui : ' + r.traductions_du_jour + ' traductions payées.';
  el.append(d, s);
}
