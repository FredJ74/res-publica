// Page MJ — Revenu universel (décision n° 7 de Fred, 26/11/2026) : versé seulement pendant les premiers jours d'un
// personnage, dans les deux empires (Sovarka 45 PSK, Républia 150 FR par défaut). Migration 20261126100000.
// Pour Codex : page MJ, français seulement.
async function admRevenuUniverselCharger() {
  const el = document.getElementById('adm-revenu-universel'); if (!el) return;
  el.textContent = 'Chargement…';
  let r;
  try { r = await rpAdminRpc('admin_revenu_universel_lire', {}); } catch (e) { el.textContent = 'Échec : ' + e.message + ' (migration 20261126100000 non appliquée ?)'; return; }
  el.textContent = '';
  if (!r || !r.ok) { el.textContent = 'Refus : ' + (r && r.raison); return; }
  const f = document.createElement('div'); f.className = 'adm-dossier'; el.append(f);
  const ligne = (libelle, cle, valeur, unite) => {
    const d = document.createElement('div'); d.className = 'adm-detail';
    const champ = document.createElement('input'); champ.type = 'number'; champ.min = cle === 'jours' ? 0 : 1; champ.value = valeur ?? ''; champ.style.width = '6rem';
    const m = document.createElement('span');
    const b = document.createElement('button'); b.type = 'button'; b.textContent = 'Enregistrer';
    b.onclick = async () => {
      try { const x = await rpAdminRpc('admin_revenu_universel_fixer', { p_cle: cle, p_valeur: Math.round(Number(champ.value)) });
        if (x && x.ok) admRevenuUniverselCharger(); else m.textContent = ' Refus : ' + (x && x.raison); }
      catch (e) { m.textContent = ' Échec : ' + e.message; }
    };
    d.append(libelle + ' : ', champ, ' ' + unite + ' ', b, m); f.append(d);
  };
  ligne('Durée du versement (premiers jours du personnage)', 'jours', r.jours, 'jours');
  ligne('Républia, par jour', 'republic', (r.montants || {}).republic, 'FR');
  ligne('Sovarka, par jour', 'soviet', (r.montants || {}).soviet, 'PSK');
}
