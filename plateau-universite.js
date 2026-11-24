// Université — « Suivre une formation » : seconde carrière (règles du 13/10 ; Criminalité lot 9, 20/11/2026 : cursus
// « Droit pénal », qui délivre la carrière criminelle, stages chez Pat Hounette ou au siège d'une organisation criminelle).
// Toutes les décisions sont au serveur : cursus ouverts (universite_mon_etat), inscription (universite_inscrire), étape
// courante et date d'ouverture (universite_prochaine_etape), lieu, objectif et PA (universite_valider_etape), diplôme
// (universite_diplomer). Cet écran affiche, rien de plus. Pop-ups cpj-* ; présentation traduite par i18next, sans relancer les actions.
(function (global) {
'use strict';
const T = {
  fr: {
    titre: 'Université — seconde carrière',
    intro: 'Inscription gratuite. Une seule seconde carrière dans votre vie, qui s’ajoute à la première. Un cours coûte 6 PA ; un stage, rien.',
    deja: 'Vous avez déjà acquis votre seconde carrière : {carriere}.', aucun: 'Aucun cursus n’est ouvert pour vous en ce moment.',
    duree: '{semaines} semaines au minimum, {limite} semaines au plus.', inscrire: 'S’inscrire',
    inscrit: 'Inscription enregistrée.', progression: '{cursus} — {faits} / {total} étapes',
    lieu: 'Lieu : {lieu}', ouvre: 'Disponible le {date}', suivre: 'Suivre le cours (6 PA)', stage: 'Rencontrer le maître de stage',
    mission: 'Votre mission : {mission}', effectuer: 'Effectuer : {mission}', etapeOk: 'Étape validée.',
    diplomer: 'Obtenir ma seconde carrière', diplome: 'Félicitations : votre seconde carrière est acquise.',
    attendre: 'Formation terminée : il faut attendre la durée minimale du cursus.', fermer: 'Fermer', retour: 'Retour',
    refuse: 'Refusé', r_cursus_ferme: 'Ce cursus n’accepte pas d’inscriptions pour l’instant.',
    r_seconde_carriere_deja_acquise: 'Vous avez déjà acquis votre seconde carrière.',
    r_personnage_mineur_carriere_unique: 'Un personnage mineur ne peut exercer aucune autre carrière.',
    r_carriere_deja_detenue: 'Vous exercez déjà ce métier.', r_cursus_deja_en_cours: 'Vous suivez déjà un cursus.',
    r_lieu_incorrect: 'Ce n’est pas le bon endroit pour cette étape.', r_objectif_non_valide: 'Ce n’est pas la mission demandée.',
    r_etape_non_ouverte: 'Cette étape n’est pas encore ouverte.', r_etape_non_courante: 'Ce n’est pas l’étape en cours.',
    r_pa_insuffisants: 'Pas assez de PA.', r_cursus_expire: 'Le délai du cursus est dépassé.',
    r_jalons_incomplets: 'Toutes les étapes ne sont pas accomplies.', r_duree_theorique_non_atteinte: 'La durée minimale n’est pas atteinte.',
    c_univ_droit_penal: 'Droit pénal', c_univ_medecin: 'Médecine', c_univ_affaires: 'Économie et affaires',
    c_univ_justice: 'Droit et justice', c_univ_armee: 'Formation militaire',
    r_aucun_cursus_en_cours: 'Aucun cursus en cours.', r_acteur_non_authentifie: 'Connexion indisponible.'
  }
};
function langue() { return global.RPPlateauI18n?.language?.() || global.RPI18nPlateau?.locale?.() || 'fr'; }
function texte(k, v) {
  const fr = T.fr[k] || global.RPUniversityI18n?.words?.fr?.[k] || k;
  let s = typeof global.i18next?.t === 'function' ? global.i18next.t('university.' + k, { lng: langue(), defaultValue: fr }) : fr;
  if (v) {
    const valeurs = { ...v };
    // Garder les identifiants bruts dans les marqueurs, pas la langue de l'ouverture.
    if (k === 'progression' && T.fr['c_' + valeurs.cursus]) valeurs.cursus = texte('c_' + valeurs.cursus);
    if (k === 'deja') valeurs.carriere = carriereTexte(valeurs.carriereId, valeurs.carriere);
    s = s.replace(/\{(\w+)\}/g, (m, n) => (valeurs[n] !== undefined ? String(valeurs[n]) : m));
  }
  return s;
}
const esc = (s) => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
// Marqueurs de présentation : les bascules ne remplacent pas le formulaire et ne relisent pas la progression.
function libelle(k, v) {
  return '<span data-university-key="' + esc(k) + '" data-university-values="' + esc(JSON.stringify(v || {})) + '">' + esc(texte(k, v)) + '</span>';
}
function carriereTexte(id, fr) {
  const reference = global.RPUniversityI18n?.careers?.[id];
  if (langue() === 'fr' || !reference || reference.fr !== fr) return fr;
  // Réutiliser les traductions existantes ; le repli conserve le français reçu, accents compris.
  const valeur = global.i18next?.getResource?.(langue(), 'translation', reference.key);
  return typeof valeur === 'string' && valeur.trim() ? valeur : fr;
}
function referenceTexte(type, id, fr) {
  if (typeof fr !== 'string') return fr;
  if (type === 'carriere') return carriereTexte(id, fr);
  const court = 'c_' + id, catalogue = 'catalogue_' + id;
  if (T.fr[court] === fr) return texte(court);
  if (global.RPUniversityI18n?.words?.fr?.[catalogue] === fr) return texte(catalogue);
  return fr;
}
function referenceLibelle(type, id, fr) {
  return '<span data-university-reference="' + esc(type) + '" data-university-reference-id="' + esc(id) + '" data-university-reference-fr="' + esc(fr) + '">' + esc(referenceTexte(type, id, fr)) + '</span>';
}
function cursusLibelle(c) {
  return referenceLibelle('cursus', c.id, c.libelle);
}
function rafraichir() {
  for (const node of global.document?.querySelectorAll('#toast-result [data-university-key], #toast-sub [data-university-key]') || []) {
    node.textContent = texte(node.getAttribute('data-university-key'));
    node.setAttribute('dir', langue() === 'ar' ? 'rtl' : 'ltr');
  }
  const modal = global.document?.getElementById('modal-postes');
  const root = global.document?.querySelector('[data-university-root]');
  if (!root || !modal?.classList.contains('open')) return;
  root.setAttribute('dir', langue() === 'ar' ? 'rtl' : 'ltr');
  for (const node of root.querySelectorAll('[data-university-key]')) {
    let values; try { values = JSON.parse(node.getAttribute('data-university-values') || '{}'); } catch (_) { continue; }
    node.textContent = texte(node.getAttribute('data-university-key'), values);
  }
  for (const node of root.querySelectorAll('[data-university-reference]')) {
    node.textContent = referenceTexte(node.getAttribute('data-university-reference'), node.getAttribute('data-university-reference-id'), node.getAttribute('data-university-reference-fr'));
  }
  const titre = global.document.getElementById('postes-modal-title');
  if (titre) titre.textContent = texte('titre');
}
// Même chargement paresseux de ressource que les guides existants : une requête statique,
// jamais une porte métier. Le français reste disponible si le catalogue ne charge pas.
let catalogueDemande = false;
function chargerCatalogue() {
  if (catalogueDemande || global.RPUniversityI18n) return;
  if (!global.document?.head) return;
  catalogueDemande = true;
  const script = global.document.createElement('script');
  script.src = 'i18n/university-resources.js?v=20261123';
  script.onload = () => { global.RPUniversityI18n?.register(); rafraichir(); };
  script.onerror = () => {}; // Aucun échec de traduction ne bloque l'université.
  global.document.head.appendChild(script);
}
(global.RP_I18N_CHANGE_CALLBACKS = global.RP_I18N_CHANGE_CALLBACKS || []).push(rafraichir);
if (global.document?.readyState === 'loading') global.document.addEventListener('DOMContentLoaded', chargerCatalogue, {once:true});
else chargerCatalogue();
const un = (r) => (Array.isArray(r) ? r[0] : r);
async function rpc(fn, params) {
  if (typeof global.sbRpc !== 'function') return null;
  return un(await global.sbRpc(fn, params || {}).catch(() => null));
}
function motifCle(r) { const k = 'r_' + (r && r.raison); return T.fr[k] ? k : 'refuse'; }
function motif(r) { return texte(motifCle(r)); }
function toast(t, b, ok) {
  if (typeof global.showToast !== 'function') return;
  global.showToast(t, b, !!ok);
  for (const [id, value] of [['toast-result', t], ['toast-sub', b]]) {
    const node = global.document?.getElementById(id);
    const key = Object.keys(T.fr).find(k => texte(k) === value);
    if (!node || !key || node.textContent !== value) continue;
    const span = global.document.createElement('span');
    span.setAttribute('data-university-key', key); span.textContent = value;
    node.replaceChildren(span);
  }
  rafraichir();
}
function ouvrir(html) {
  const t = global.document.getElementById('postes-modal-title'); if (t) t.textContent = texte('titre');
  global.document.getElementById('postes-body').innerHTML = '<div class="cpj-dialogue" data-university-root style="padding:1rem;display:flex;flex-direction:column;gap:.5rem">'
    + html + '<button class="cpj-touche" onclick="universiteFermer()">' + libelle('fermer') + '</button></div>';
  global.document.getElementById('modal-postes').classList.add('open');
  rafraichir();
}
function universiteFermer() { const m = global.document.getElementById('modal-postes'); if (m) m.classList.remove('open'); }
// Noms affichés des lieux (copie d'affichage de data.js ; le serveur compare les identifiants).
function nomLieu(e) {
  const pays = (typeof state !== 'undefined' && state && state.country) || 'republic';
  const v = (typeof VILLES !== 'undefined' && VILLES[pays] && VILLES[pays][e.ville]) ? VILLES[pays][e.ville].nom : e.ville;
  const b = (typeof BUILDINGS !== 'undefined' && BUILDINGS[e.batiment]) || null;
  const p = b && e.piece && b.rooms && b.rooms[e.piece] ? b.rooms[e.piece].name : e.piece;
  return [v, b ? b.name : e.batiment, p].filter(Boolean).join(' — ');
}
let etapeCourante = null;
let cursusListe = [];
async function ouvrirUniversiteFormation() {
  const [s, n] = await Promise.all([rpc('universite_mon_etat'), rpc('universite_prochaine_etape')]);
  if (!s || !s.ok) { ouvrir('<p class="cpj-note">' + libelle(motifCle(s)) + '</p>'); return; }
  let html = '<p class="cpj-note">' + libelle('intro') + '</p>';
  if (!s.cursus_actif) {
    if (s.slot_consomme) {
      const c = s.seconde_carriere || {};
      ouvrir(html + '<p class="cpj-note">' + libelle('deja', { carriere: c.libelle || c.carriere || '', carriereId: c.carriere }) + '</p>'); return;
    }
    cursusListe = s.cursus_disponibles || [];
    if (!cursusListe.length) html += '<p class="cpj-note">' + libelle('aucun') + '</p>';
    cursusListe.forEach((c, i) => {
      html += '<p><strong>' + cursusLibelle(c) + '</strong><br><span class="cpj-note">' + referenceLibelle('carriere', c.carriere, c.carriere_libelle || '') + ' · '
        + libelle('duree', { semaines: c.semaines_theoriques, limite: 2 * c.semaines_theoriques }) + '</span></p>'
        + '<button class="cpj-touche cpj-primaire" onclick="universiteInscrire(' + i + ')">' + libelle('inscrire') + '</button>';
    });
    ouvrir(html); return;
  }
  const c = s.cursus_actif;
  html += '<p class="cpj-note">' + libelle('progression', { cursus: c.cursus, faits: c.jalons_accomplis, total: c.jalons_total }) + '</p>';
  const e = n && n.ok ? n.etape : null;
  etapeCourante = e;
  if (e) {
    html += '<p><strong>' + esc(e.libelle) + '</strong></p><p class="cpj-note">' + libelle('lieu', { lieu: nomLieu(e) }) + '</p>'
      + '<p class="cpj-note">' + libelle('ouvre', { date: new Date(e.ouvre_le).toLocaleString('fr-FR') }) + '</p>';
    if (e.ouvert) html += '<button class="cpj-touche cpj-primaire" onclick="universiteEtape()">' + libelle(e.genre === 'universite' ? 'suivre' : 'stage') + '</button>';
  } else if (c.diplomable) {
    html += '<button class="cpj-touche cpj-primaire" onclick="universiteDiplomer()">' + libelle('diplomer') + '</button>';
  } else html += '<p class="cpj-note">' + libelle('attendre') + '</p>';
  ouvrir(html);
}
async function universiteInscrire(i) {
  const c = cursusListe[i]; if (!c) return;
  const r = await rpc('universite_inscrire', { p_cursus: c.id });
  if (!r || !r.ok) toast(texte('refuse'), motif(r), false); else toast(texte('titre'), texte('inscrit'), true);
  await ouvrirUniversiteFormation();
}
function universiteEtape() {
  const e = etapeCourante; if (!e) return;
  if (e.genre === 'universite') { universiteValider(); return; }
  ouvrir('<p><strong>' + esc(e.libelle) + '</strong></p><p class="cpj-note">' + libelle('mission', { mission: e.action || e.libelle }) + '</p>'
    + '<button class="cpj-touche cpj-primaire" onclick="universiteValider()">' + libelle('effectuer', { mission: e.action || '' }) + '</button>'
    + '<button class="cpj-touche" onclick="ouvrirUniversiteFormation()">' + libelle('retour') + '</button>');
}
async function universiteValider() {
  const e = etapeCourante; if (!e) return;
  const r = await rpc('universite_valider_etape', { p_jalon: e.id, p_action: e.genre === 'terrain' ? e.action : null });
  if (!r || !r.ok) toast(texte('refuse'), motif(r), false);
  else {
    toast(texte('titre'), texte('etapeOk'), true);
    if (typeof r.pa === 'number' && typeof state !== 'undefined' && state) state.pa = r.pa;   // valeur du serveur, sans calcul
    if (typeof global.updateUI === 'function') { try { global.updateUI(); } catch (_) {} }
  }
  await ouvrirUniversiteFormation();
}
async function universiteDiplomer() {
  const r = await rpc('universite_diplomer');
  if (!r || !r.ok) toast(texte('refuse'), motif(r), false);
  else toast(texte('titre'), texte('diplome'), true);
  await ouvrirUniversiteFormation();
}
Object.assign(global, { ouvrirUniversiteFormation, universiteInscrire, universiteEtape, universiteValider, universiteDiplomer, universiteFermer,
  RP_UNIVERSITE_TEXTES: T });
})(typeof window !== 'undefined' ? window : globalThis);
