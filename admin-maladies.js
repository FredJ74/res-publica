// Outils du MJ — maladies (GAME-DESIGN-MALADIES-CLIMAT.md § 1 ; lot 1 du 18/11/2026).
// Tous les paramètres sont modifiables (« qui peut le plus peut le moins ») ; nom et symptôme temporaires en texte libre ;
// infliger ou guérir un personnage ; déclarer la fin d'une épidémie (tous les malades d'une maladie guéris).
// Le serveur exige un administrateur (admin_exiger) et journalise chaque action (admin_journal).
const ADM_MAL_CHAMPS = [
 ['actif', 'booléen', 'Actif'], ['duree_heures', 'entier', 'Durée (heures)'], ['deltas', 'json', 'Malus (ex. {"INT":-2})'],
 ['pa_max', 'entier?', 'Plafond de PA (vide = aucun)'], ['sans_bonus_arme', 'booléen', 'Bonus d’arme supprimé'],
 ['medicament', 'texte', 'Médicament adapté (clé)'], ['contagieuse', 'booléen', 'Contagieuse'], ['risques', 'json', 'Risques (%)'],
 ['prix_fixe', 'entier?', 'Prix fixe (vide = 2 × prix de base)'], ['stock_journalier', 'entier', 'Stock journalier par pharmacie (0 = pénurie)'],
 ['nom_mj', 'texte?', 'Nom temporaire (texte libre)'], ['symptome_mj', 'texte?', 'Symptôme temporaire (texte libre)'],
 // Santé (Fred, 22/11/2026, points 4 et 5) : affichés seulement quand le serveur les connaît (migration 20261122233000).
 ['perte_sante', 'entier', 'Santé perdue à la contraction'], ['guerison_spontanee', 'booléen', 'Guérit seule à l’échéance (non = seulement par médicament)']
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
    if (!(k in m)) continue;
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

// Aliments (lot 2b, 18/11/2026) : péremption, détection à la réception, prix des bandelettes réactives.
const ADM_ALIM_CHAMPS = [['peremption_jours', 'Péremption (jours)'], ['detection_base', 'Détection à la réception sans bandelette (%)'],
 ['detection_bandelette', 'Détection avec bandelette (%)'], ['prix_bandelette', 'Prix d’une bandelette']];
async function admAlimentsCharger() {
 const el = document.getElementById('adm-aliments'); if (!el) return;
 el.textContent = 'Chargement…';
 try {
  const d = await rpAdminRpc('admin_aliments_lire', {});
  el.textContent = '';
  const p = (d && d.parametres) || {};
  for (const [cle, label] of ADM_ALIM_CHAMPS) {
   const lab = document.createElement('label'); lab.className = 'adm-detail'; lab.style.display = 'block'; lab.textContent = label + ' ';
   const inp = document.createElement('input'); inp.type = 'number'; inp.min = '0'; inp.value = p[cle] ?? ''; inp.style.width = '6rem';
   const b = document.createElement('button'); b.type = 'button'; b.textContent = 'Enregistrer';
   b.onclick = async () => {
    try {
     const r = await rpAdminRpc('admin_aliment_modifier', { p_cle: cle, p_valeur: Number(inp.value) });
     alert(r && r.ok ? 'Enregistré.' : 'Refus : ' + (r && r.raison));
    } catch (e) { alert('Échec : ' + e.message); }
   };
   lab.append(inp, ' ', b); el.append(lab);
  }
 } catch (e) { el.textContent = 'Erreur : ' + e.message; }
}

// Climat (lot 3, 18/11/2026) : réglages par type et par pays, calendrier (annuler), création d'un événement à une date.
const ADM_CLIMAT_CHAMPS = [['actif', 'booléen', 'Actif'], ['par_periode', 'entier', 'Nombre par période'], ['delai_min', 'entier', 'Délai min. entre villes (jours)'],
 ['delai_max', 'entier', 'Délai max. entre villes (jours)'], ['duree_heures', 'entier', 'Durée (heures)'], ['preavis_heures', 'entier', 'Préavis de l’alerte (heures)'],
 ['bloque_chantiers', 'booléen', 'Bloque les chantiers'],
 // Crue seulement (Fred, 22/11/2026, point 31) : état de catastrophe naturelle EN SOMMEIL, intérêt à définir. Laisser à « non ».
 ['catastrophe_active', 'booléen', 'État de catastrophe naturelle (en sommeil : laisser à non)', 'crue']];
const ADM_CLIMAT_VILLES = { republic: { capitale: 'Luthécia', ville_a: 'Port-Sainte-Marie', ville_b: 'Montrouge' }, soviet: { capitale: 'Novomirsk', ville_a: 'Starovka', ville_b: 'Krasnov' } };
async function admClimatCharger() {
 const el = document.getElementById('adm-climat'); if (!el) return;
 el.textContent = 'Chargement…';
 try {
  const d = await rpAdminRpc('admin_climat_lire', {});
  el.textContent = '';
  for (const c of (d.parametres || [])) {
   const bloc = document.createElement('div'); bloc.className = 'adm-dossier';
   const t = document.createElement('strong'); t.textContent = c.type + ' — ' + (c.pays === 'republic' ? 'Républia' : 'Sovarka') + ' (' + c.frequence + ')'; bloc.append(t);
   for (const [k, type, label, seulement] of ADM_CLIMAT_CHAMPS) {
    if (seulement && seulement !== c.type) continue;
    const lab = document.createElement('label'); lab.className = 'adm-detail'; lab.style.display = 'block'; lab.textContent = label + ' ';
    let inp;
    if (type === 'booléen') { inp = document.createElement('select'); for (const o of ['true', 'false']) { const op = document.createElement('option'); op.value = o; op.textContent = o === 'true' ? 'oui' : 'non'; inp.append(op); } inp.value = String(!!c[k]); }
    else { inp = document.createElement('input'); inp.type = 'number'; inp.min = '0'; inp.value = c[k]; inp.style.width = '5rem'; }
    inp.dataset.champ = k; inp.dataset.type = type; lab.append(inp); bloc.append(lab);
   }
   const b = document.createElement('button'); b.type = 'button'; b.textContent = 'Enregistrer';
   b.onclick = async () => {
    const p = {}; bloc.querySelectorAll('[data-champ]').forEach(i => { p[i.dataset.champ] = i.dataset.type === 'booléen' ? i.value === 'true' : Number(i.value); });
    try { const r = await rpAdminRpc('admin_climat_parametre_modifier', { p_type: c.type, p_pays: c.pays, p_parametres: p }); alert(r && r.ok ? 'Enregistré.' : 'Refus : ' + (r && r.raison)); }
    catch (e) { alert('Échec : ' + e.message); }
   };
   bloc.append(b); el.append(bloc);
  }
  const cal = document.createElement('div'); cal.className = 'adm-dossier';
  const ct = document.createElement('strong'); ct.textContent = 'Calendrier (' + (d.evenements || []).length + ')'; cal.append(ct);
  for (const e of (d.evenements || [])) {
   const p = document.createElement('p'); p.className = 'adm-detail';
   const ville = (ADM_CLIMAT_VILLES[e.pays] || {})[e.ville] || e.ville;
   p.textContent = new Date(e.debut).toLocaleDateString('fr-FR') + ' — ' + e.type + ' à ' + ville
    + ((e.lieux || []).length ? ' (' + e.lieux.map(l => l.nom).join(', ') + ')' : '') + (e.alerte_le ? ' · annoncé' : '') + (e.annule ? ' · ANNULÉ' : '') + (e.origine === 'mj' ? ' · MJ' : '');
   if (!e.annule && new Date(e.fin) > new Date()) {
    const x = document.createElement('button'); x.type = 'button'; x.textContent = 'Annuler';
    x.onclick = async () => { if (!confirm('Annuler cet événement ?')) return; try { const r = await rpAdminRpc('admin_climat_annuler', { p_id: e.id }); alert(r && r.ok ? 'Annulé.' : 'Refus'); admClimatCharger(); } catch (er) { alert('Échec : ' + er.message); } };
    p.append(' ', x);
   }
   cal.append(p);
  }
  const f = document.createElement('div');
  f.innerHTML = '<select id="adm-cl-type"><option>crue</option><option>canicule</option><option>orage</option><option>brouillard</option><option>blizzard</option></select> '
   + '<select id="adm-cl-pays"><option value="republic">Républia</option><option value="soviet">Sovarka</option></select> '
   + '<select id="adm-cl-ville"><option value="capitale">capitale</option><option value="ville_a">ville A</option><option value="ville_b">ville B</option></select> '
   + '<input id="adm-cl-jour" type="date"> ';
  const cr = document.createElement('button'); cr.type = 'button'; cr.textContent = 'Créer l’événement';
  cr.onclick = async () => {
   try {
    const r = await rpAdminRpc('admin_climat_creer', { p_type: document.getElementById('adm-cl-type').value, p_pays: document.getElementById('adm-cl-pays').value,
     p_ville: document.getElementById('adm-cl-ville').value, p_jour: document.getElementById('adm-cl-jour').value });
    alert(r && r.ok ? 'Événement créé.' : 'Refus : ' + (r && r.raison)); admClimatCharger();
   } catch (e) { alert('Échec : ' + e.message); }
  };
  f.append(cr); cal.append(f); el.append(cal);
 } catch (e) { el.textContent = 'Erreur : ' + e.message; }
}
