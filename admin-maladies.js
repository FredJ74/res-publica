// Outils du MJ — maladies (GAME-DESIGN-MALADIES-CLIMAT.md § 1 ; lot 1 du 18/11/2026).
// Tous les paramètres sont modifiables (« qui peut le plus peut le moins ») ; nom et symptôme temporaires en texte libre ;
// infliger ou guérir un personnage ; déclarer la fin d'une épidémie (tous les malades d'une maladie guéris).
// Le serveur exige un administrateur (admin_exiger) et journalise chaque action (admin_journal).
const ADM_MAL_CHAMPS = [
 ['actif', 'booléen', 'Actif'], ['duree_heures', 'entier', 'Durée (heures)'], ['deltas', 'json', 'Malus (ex. {"INT":-2})'],
 ['pa_max', 'entier?', 'Plafond de PA (vide = aucun)'], ['sans_bonus_arme', 'booléen', 'Bonus d’arme supprimé'],
 ['medicament', 'texte', 'Médicament adapté (clé)'], ['contagieuse', 'booléen', 'Contagieuse'], ['risques', 'json', 'Risques (%)'],
 ['prix_fixe', 'entier?', 'Prix fixe (vide = 2 × prix de base)'], ['stock_journalier', 'entier', 'Stock journalier par pharmacie (0 = pénurie)'],
 ['nom_mj', 'texte?', 'Nom temporaire (texte libre)'], ['symptome_mj', 'texte?', 'Symptôme temporaire (texte libre)']
];
function admMalLire(type, brut) {
 const v = String(brut ?? '').trim();
 if (type === 'booléen') return v === 'true';
 if (type === 'entier') { const n = Number(v); if (!Number.isInteger(n)) throw Error('entier attendu'); return n; }
 if (type === 'entier?') { if (!v) return null; const n = Number(v); if (!Number.isInteger(n)) throw Error('entier attendu'); return n; }
 if (type === 'json') { const o = JSON.parse(v || '{}'); if (!o || typeof o !== 'object' || Array.isArray(o)) throw Error('objet JSON attendu'); return o; }
 return v;
}
async function admMaladiesCharger() {
 const el = document.getElementById('adm-maladies'); if (!el) return;
 el.textContent = 'Chargement…';
 try {
  const d = await rpAdminRpc('admin_maladies_lire', {});
  el.textContent = '';
  for (const m of (d.parametres || [])) {
   const bloc = document.createElement('div'); bloc.className = 'adm-dossier';
   const t = document.createElement('strong'); t.textContent = m.cle + (m.nom_mj ? ' — « ' + m.nom_mj + ' »' : ''); bloc.append(t);
   for (const [k, type, label] of ADM_MAL_CHAMPS) {
    const lab = document.createElement('label'); lab.className = 'adm-detail'; lab.style.display = 'block';
    lab.textContent = label + ' ';
    let inp;
    if (type === 'booléen') {
     inp = document.createElement('select');
     for (const o of ['true', 'false']) { const op = document.createElement('option'); op.value = o; op.textContent = o === 'true' ? 'oui' : 'non'; inp.append(op); }
     inp.value = String(!!m[k]);
    } else {
     inp = document.createElement('input'); inp.type = 'text'; inp.style.width = '100%';
     inp.value = type === 'json' ? JSON.stringify(m[k] || {}) : (m[k] ?? '');
    }
    inp.dataset.champ = k; inp.dataset.type = type; lab.append(inp); bloc.append(lab);
   }
   const b = document.createElement('button'); b.type = 'button'; b.textContent = 'Enregistrer ' + m.cle;
   b.onclick = async () => {
    try {
     const p = {};
     bloc.querySelectorAll('[data-champ]').forEach(i => { p[i.dataset.champ] = admMalLire(i.dataset.type, i.value); });
     const r = await rpAdminRpc('admin_maladie_modifier', { p_cle: m.cle, p_parametres: p });
     if (!r || r.ok !== true) throw Error((r && r.raison) || 'refus');
     alert('Paramètres enregistrés.'); admMaladiesCharger();
    } catch (e) { alert('Non enregistré : ' + e.message); }
   };
   bloc.append(b);
   const fin = document.createElement('button'); fin.type = 'button'; fin.textContent = 'Fin d’épidémie : guérir tous les malades (' + m.cle + ')';
   fin.onclick = async () => {
    if (!confirm('Guérir tous les personnages atteints de ' + m.cle + ' ?')) return;
    try { const r = await rpAdminRpc('admin_maladie_guerir', { p_nom: null, p_cle: m.cle }); alert((r && r.gueris) + ' personnage(s) guéri(s).'); admMaladiesCharger(); }
    catch (e) { alert('Échec : ' + e.message); }
   };
   bloc.append(' ', fin);
   el.append(bloc);
  }
  const malades = document.createElement('div'); malades.className = 'adm-dossier';
  const mt = document.createElement('strong'); mt.textContent = 'Malades en cours (' + (d.malades || []).length + ')'; malades.append(mt);
  for (const x of (d.malades || [])) {
   const p = document.createElement('p'); p.className = 'adm-detail';
   p.textContent = x.nom + ' — ' + x.cle + ' (' + x.source + ', jusqu’au ' + new Date(x.fin).toLocaleString('fr-FR') + (x.traitee ? ', traité' : '') + ')';
   malades.append(p);
  }
  const form = document.createElement('div');
  form.innerHTML = '<input id="adm-mal-nom" placeholder="Nom du personnage" style="width:45%"> '
   + '<select id="adm-mal-cle">' + (d.parametres || []).map(m => '<option>' + m.cle.replace(/[<>&"]/g, '') + '</option>').join('') + '</select> ';
  const inf = document.createElement('button'); inf.type = 'button'; inf.textContent = 'Infliger';
  inf.onclick = async () => {
   const nom = document.getElementById('adm-mal-nom').value.trim(); const cle = document.getElementById('adm-mal-cle').value;
   if (!nom) return;
   try { const r = await rpAdminRpc('admin_maladie_infliger', { p_nom: nom, p_cle: cle }); alert(r && r.ok ? 'Maladie infligée.' : 'Refus : ' + (r && r.raison)); admMaladiesCharger(); }
   catch (e) { alert('Échec : ' + e.message); }
  };
  const gue = document.createElement('button'); gue.type = 'button'; gue.textContent = 'Guérir';
  gue.onclick = async () => {
   const nom = document.getElementById('adm-mal-nom').value.trim(); const cle = document.getElementById('adm-mal-cle').value;
   if (!nom) return;
   try { const r = await rpAdminRpc('admin_maladie_guerir', { p_nom: nom, p_cle: cle }); alert((r && r.gueris) + ' guérison(s).'); admMaladiesCharger(); }
   catch (e) { alert('Échec : ' + e.message); }
  };
  form.append(inf, ' ', gue); malades.append(form);
  el.append(malades);
 } catch (e) { el.textContent = 'Erreur : ' + e.message; }
}
