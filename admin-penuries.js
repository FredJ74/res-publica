// Outils du MJ — pénuries (GAME-DESIGN-DISTILLERIE-ALCOOLS.md § Pénuries ; Fred, 20/11/2026).
// Une matière, une zone (pays, ville ou tout le pays), une intensité (1 à 100 % de production coupée), une durée en jours
// (vide = jusqu'à la levée manuelle), une destruction optionnelle du stock des entrepôts de la zone, une annonce optionnelle
// (bandeau et journal). Le serveur exige un administrateur (admin_exiger) et journalise chaque action (admin_journal).
const ADM_PEN_PAYS = { republic: 'Républia', soviet: 'Sovarka', khalija: 'Al-Khalija', narco: 'El Estado' };
const ADM_PEN_VILLES = { '': 'tout le pays', capitale: 'capitale', ville_a: 'ville A', ville_b: 'ville B' };
function admPenOptions(sel, valeurs) {
 for (const [v, t] of Object.entries(valeurs)) { const o = document.createElement('option'); o.value = v; o.textContent = t; sel.append(o); }
 return sel;
}
async function admPenuriesCharger() {
 const el = document.getElementById('adm-penuries'); if (!el) return;
 el.textContent = 'Chargement…';
 try {
  const d = await rpAdminRpc('admin_penuries_lire', {});
  el.textContent = '';
  const f = document.createElement('div'); f.className = 'adm-dossier';
  const t = document.createElement('strong'); t.textContent = 'Déclarer une pénurie'; f.append(t);
  const ligne = (label, champ) => { const l = document.createElement('label'); l.className = 'adm-detail'; l.style.display = 'block'; l.textContent = label + ' '; l.append(champ); f.append(l); return champ; };
  const mat = ligne('Matière', admPenOptions(document.createElement('select'), Object.fromEntries((d.matieres || []).map(m => [m, m]))));
  const pays = ligne('Pays', admPenOptions(document.createElement('select'), ADM_PEN_PAYS));
  const ville = ligne('Zone', admPenOptions(document.createElement('select'), ADM_PEN_VILLES));
  const inten = document.createElement('input'); inten.type = 'number'; inten.min = 1; inten.max = 100; inten.value = 50; ligne('Intensité (% de production coupée)', inten);
  const duree = document.createElement('input'); duree.type = 'number'; duree.min = 1; duree.placeholder = 'vide = levée manuelle'; ligne('Durée (jours)', duree);
  const destr = document.createElement('input'); destr.type = 'number'; destr.min = 0; destr.max = 100; destr.value = 0; ligne('Stock détruit dans les entrepôts (%)', destr);
  const annonce = document.createElement('input'); annonce.type = 'text'; annonce.style.width = '100%'; annonce.placeholder = 'vide = aucune annonce'; ligne('Annonce (bandeau et journal)', annonce);
  const b = document.createElement('button'); b.type = 'button'; b.textContent = 'Déclarer';
  b.onclick = async () => {
   if (!confirm('Déclarer cette pénurie ?')) return;
   try {
    const r = await rpAdminRpc('admin_penurie_declarer', { p_matiere: mat.value, p_pays: pays.value, p_ville: ville.value || null,
     p_intensite: Number(inten.value), p_duree_jours: duree.value ? Number(duree.value) : null, p_destruction_pct: Number(destr.value || 0),
     p_annonce: annonce.value || null });
    alert(r && r.ok ? 'Pénurie déclarée.' + (Object.keys(r.detruit || {}).length ? ' Stock détruit : ' + JSON.stringify(r.detruit) : '') : 'Refus : ' + (r && r.raison));
    admPenuriesCharger();
   } catch (e) { alert('Échec : ' + e.message); }
  };
  f.append(b); el.append(f);
  const liste = document.createElement('div'); liste.className = 'adm-dossier';
  const lt = document.createElement('strong'); lt.textContent = 'Pénuries (' + (d.penuries || []).length + ')'; liste.append(lt);
  for (const p of (d.penuries || [])) {
   const l = document.createElement('p'); l.className = 'adm-detail';
   l.textContent = '#' + p.id + ' — ' + p.matiere + ' · ' + (ADM_PEN_PAYS[p.pays] || p.pays) + ' · ' + (ADM_PEN_VILLES[p.ville || ''] || p.ville) + ' · ' + p.intensite + ' %'
    + ' · depuis le ' + new Date(p.debut).toLocaleDateString('fr-FR') + (p.fin ? ' jusqu’au ' + new Date(p.fin).toLocaleDateString('fr-FR') : ' (levée manuelle)')
    + (p.destruction_pct ? ' · stock détruit ' + p.destruction_pct + ' %' : '') + (p.annonce ? ' · annoncée' : '')
    + (p.levee_le ? ' · LEVÉE' : (p.active ? ' · EN COURS' : ' · terminée'));
   if (p.active) {
    const x = document.createElement('button'); x.type = 'button'; x.textContent = 'Lever';
    x.onclick = async () => { if (!confirm('Lever cette pénurie ?')) return; try { const r = await rpAdminRpc('admin_penurie_lever', { p_id: p.id }); alert(r && r.ok ? 'Levée.' : 'Refus : ' + (r && r.raison)); admPenuriesCharger(); } catch (e) { alert('Échec : ' + e.message); } };
    l.append(' ', x);
   }
   liste.append(l);
  }
  el.append(liste);
 } catch (e) { el.textContent = 'Erreur : ' + e.message; }
}
