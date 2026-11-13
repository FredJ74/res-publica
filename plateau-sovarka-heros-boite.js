// HÉROS DU TRAVAIL ET BOÎTE AUX LETTRES DU PARTI (13/11/2026, décisions de Fred, GAME-DESIGN-NOVOMIRSK.md).
// Le serveur décide de tout (migration 20261113163000) : points, clôture hebdomadaire, décideur, record
// en attente, une décoration par semaine, médaille, anonymat des dénonciations, droits du chef.
// Cet écran n'affiche que ses réponses. Textes : i18n/sovarka-heros-boite-resources.js (français de repli).

const hbT = (k, v) => (typeof texteSovHerosBoite === 'function' ? texteSovHerosBoite(k, v) : k);
const hbE = v => String(v == null ? '' : v).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const hbModal = (titre, html, rouvrir) => (typeof sovModal === 'function') ? sovModal(titre, html, rouvrir) : vehModal(titre, html);
const hbSection = (titre, corps) => '<div class="cpj-titre">' + titre + '</div>' + corps;
const hbBouton = (libelle, js, primaire) =>
  '<button class="cpj-touche' + (primaire ? ' cpj-primaire' : '') + '" style="margin:.4rem .4rem 0 0" onclick="' + js + '">' + libelle + '</button>';
const HB_VILLES = { capitale: 'Novomirsk', ville_a: 'Starovka', ville_b: 'Krasnov' };
const HB_RAISONS = ['acteur_non_authentifie', 'requete_absente', 'pas_decideur', 'record_introuvable', 'deja_decore',
  'deja_decore_cette_semaine', 'record_superieur_en_attente', 'personnage_introuvable', 'pas_dans_la_salle',
  'parti_introuvable', 'texte_vide', 'texte_trop_long', 'pa_insuffisants', 'pas_chef', 'chef_deja_acces', 'denonciation_introuvable'];
let hbEnCours = false;
let hbBoites = null;

function hbDate(d) {
  if (!d) return '';
  const s = String(d).slice(0, 10).split('-');
  return s.length === 3 ? s[2] + '/' + s[1] + '/' + s[0] : String(d);
}
function hbHeure(t) {
  try { return new Date(t).toLocaleString(undefined, { timeZone: 'Europe/Paris', day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }); }
  catch (e) { return ''; }
}
function hbRefus(v) {
  showToast(hbT('tRefused'), HB_RAISONS.includes(v?.raison) ? hbT('r_' + v.raison, { record: v.record, max: v.max }) : hbT('notConfirmed'), false);
}
async function hbLire(fn, params) {
  const v = await sbRpcVerdict(fn, params || {}).catch(() => null);
  if (!v || v.ok !== true) { if (v && HB_RAISONS.includes(v.raison)) hbRefus(v); else showToast(hbT('tRefused'), hbT('noServer'), false); return null; }
  return v;
}
// Acte unique par requête : un double clic ou une reprise réseau ne rejoue jamais l'acte.
async function hbActe(fn, cle, params) {
  if (hbEnCours) return null;
  hbEnCours = true;
  const k = 'hg-heros-boite:' + (state.char?.name || '') + ':' + fn + ':' + cle;
  try {
    let requete = sessionStorage.getItem(k);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(k, requete); }
    const v = await sbRpcVerdict(fn, Object.assign({ p_requete: requete }, params)).catch(() => null);
    if (v && !v.transport) sessionStorage.removeItem(k);
    if (!v || v.ok !== true) { hbRefus(v); return null; }
    if (typeof appliquerPaiementServeur === 'function' && v.pa != null) appliquerPaiementServeur({ pa: v.pa });
    if (typeof updateHeader === 'function') updateHeader();
    return v;
  } finally { hbEnCours = false; }
}

// ---------------------------------------------------------------- Héros du Travail
function hbLigneRecord(r, extra) {
  return '<div style="border-top:1px solid #344354;padding:.4rem 0;display:flex;justify-content:space-between;align-items:center;gap:.5rem">' +
    '<span><b>' + hbE(r.personnage) + '</b> — ' + hbT('points', { n: r.points }) +
    (r.semaine ? '<br><span class="cpj-note">' + hbT('weekOf', { date: hbDate(r.semaine) }) + '</span>' : '') + '</span>' + (extra || '') + '</div>';
}

// Accueil des mairies : la liste publique des décorés.
async function ouvrirHerosTravailTableau() {
  const v = await hbLire('heros_travail_tableau');
  if (!v) return;
  const l = v.decores || [];
  hbModal(hbT('titleBoard'), '<p class="cpj-note">' + hbT('boardIntro') + '</p>' +
    (l.length ? l.map(r => hbLigneRecord(r)).join('') : '<p class="cpj-note">' + hbT('noHero') + '</p>'), ouvrirHerosTravailTableau);
}

let hbClassement = null;
// Bureau du ministre de l'Économie collective : classement, records en attente, décoration.
async function ouvrirHerosTravailClassement(cache) {
  const v = (cache === true && hbClassement) ? hbClassement : await hbLire('heros_travail_lire');
  if (!v) return;
  hbClassement = v;
  const peut = v.decideur === true && v.deja_decore_cette_semaine !== true;
  let h = '<p class="cpj-note">' + hbT(v.decideur ? 'deciderIntro' : 'notDecider') + '</p>';
  if (v.deja_decore_cette_semaine) h += '<p class="cpj-note"><b>' + hbT('alreadyThisWeek') + '</b></p>';
  h += hbSection(hbT('secPending'), (v.attente || []).length
    ? v.attente.map(r => hbLigneRecord(r, (peut && r.eligible) ? hbBouton(hbT('decorate'), 'herosTravailDecorer(\'' + hbE(r.id) + '\')', true)
        : (r.eligible ? '' : '<span class="cpj-note">' + hbT('notEligible') + '</span>'))).join('')
    : '<p class="cpj-note">' + hbT('noPending') + '</p>');
  h += hbSection(v.derniere_semaine ? hbT('secLastWeek', { date: hbDate(v.derniere_semaine) }) : hbT('secLastWeekNone'),
    (v.classement || []).length ? v.classement.map((r, i) => '<div style="padding:.15rem 0">' + (i + 1) + '. <b>' + hbE(r.personnage) + '</b> — ' + hbT('points', { n: r.points }) + '</div>').join('')
      : '<p class="cpj-note">' + hbT('noRanking') + '</p>');
  h += '<p class="cpj-note">' + hbT('myPoints', { n: v.mes_points_semaine || 0 }) + '</p>';
  hbModal(hbT('titleRanking'), h, ouvrirHerosTravailClassement);
}

async function herosTravailDecorer(id) {
  const r = (hbClassement?.attente || []).find(x => x.id === id);
  if (!r || !confirm(hbT('confirmDecorate', { nom: r.personnage, n: r.points }))) return;
  const v = await hbActe('heros_travail_decorer', id, { p_record: id });
  if (!v) return;
  showToast(hbT('tDecorated'), hbT('decorated', { nom: v.personnage }), true);
  ouvrirHerosTravailClassement();
}

// Fenêtre d'interaction d'un personnage : ses décorations (générique, pour d'autres distinctions).
async function herosDecorationsDans(el, nom) {
  if (!el || !nom || typeof sbRpcVerdict !== 'function') return;
  const v = await sbRpcVerdict('decorations_lire', { p_personnage: nom }).catch(() => null);
  if (!v || v.ok !== true || !Array.isArray(v.decorations) || !v.decorations.length) { el.textContent = ''; return; }
  el.innerHTML = '<i class="ti ti-medal"></i> ' + hbT('decorationsHead') + ' ' +
    v.decorations.map(d => hbE(hbT('dec_' + d.type, { date: hbDate(d.semaine), n: d.points }))).join(' · ');
}

// Médaille dans l'inventaire : nom et description traduits à partir des données gravées.
function herosObjetTexte(item, champ) {
  if (!item || item.generique_id !== 'medaille_heros_travail') return champ === 'desc' ? item?.desc : item?.name;
  if (champ === 'desc') return item.decore ? hbT('medalDesc', { nom: hbE(item.decore), date: hbE(hbDate(item.semaine)), n: hbE(item.points) }) : item.desc;
  return hbT('medalName');
}

// ---------------------------------------------------------------- Boîte aux lettres du Parti
async function ouvrirPartiDenoncer(cache) {
  const v = (cache === true && hbBoites) ? hbBoites : await hbLire('parti_boite_lire');
  if (!v) return;
  hbBoites = v;
  if (!v.dans_la_salle) { showToast(hbT('tRefused'), hbT('r_pas_dans_la_salle'), false); return; }
  if (!(v.partis || []).length) { hbModal(hbT('titlePost'), '<p class="cpj-note">' + hbT('noParty') + '</p>', ouvrirPartiDenoncer); return; }
  hbModal(hbT('titlePost'),
    '<p><b>' + hbT('whichBox') + '</b></p>' +
    '<select id="hb-parti" class="cpj-champ" style="width:100%">' + v.partis.map(p => '<option value="' + hbE(p.id) + '">' + hbE(p.nom) + '</option>').join('') + '</select>' +
    '<textarea id="hb-texte" class="cpj-champ" maxlength="2000" rows="6" placeholder="' + hbE(hbT('textPh')) + '" style="width:100%;margin-top:.5rem"></textarea>' +
    '<p class="cpj-note">' + hbT('postNote') + '</p>' +
    hbBouton(hbT('post'), 'partiDenoncerEnvoyer()', true), ouvrirPartiDenoncer);
}

async function partiDenoncerEnvoyer() {
  const parti = document.getElementById('hb-parti')?.value || '';
  const texte = (document.getElementById('hb-texte')?.value || '').trim();
  if (!texte) { showToast(hbT('tRefused'), hbT('r_texte_vide'), false); return; }
  // Clé liée au contenu : renvoyer le même texte après une coupure ne le dépose pas deux fois.
  let empreinte = 0;
  for (let i = 0; i < texte.length; i++) empreinte = (empreinte * 31 + texte.charCodeAt(i)) | 0;
  const v = await hbActe('parti_boite_poster', parti + ':' + empreinte, { p_parti: parti, p_texte: texte });
  if (!v) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast(hbT('tPosted'), hbT('posted'), true);
}

async function ouvrirPartiRegistre(cache) {
  const v = (cache === true && hbBoites) ? hbBoites : await hbLire('parti_boite_lire');
  if (!v) return;
  hbBoites = v;
  if (!v.dans_la_salle) { showToast(hbT('tRefused'), hbT('r_pas_dans_la_salle'), false); return; }
  const boites = v.boites || [];
  if (!boites.length) { hbModal(hbT('titleRegistry'), '<p class="cpj-note">' + hbT('noAccess') + '</p>', ouvrirPartiRegistre); return; }
  const h = boites.map((b, i) => {
    const den = (b.denonciations || []).length
      ? b.denonciations.map(d => '<div style="border-top:1px solid #344354;padding:.4rem 0">' +
          '<span class="cpj-note">' + hbE(hbHeure(d.depose_le)) + (d.ville ? ' · ' + hbE(HB_VILLES[d.ville] || d.ville) : '') + '</span>' +
          '<div style="white-space:pre-wrap;margin:.2rem 0">' + hbE(d.texte) + '</div>' +
          (b.est_chef ? hbBouton(hbT('delete'), 'partiRegistreSupprimer(\'' + hbE(d.id) + '\')', false) : '') + '</div>').join('')
      : '<p class="cpj-note">' + hbT('noDenunciation') + '</p>';
    let acces = '';
    if (b.est_chef) {
      acces = hbSection(hbT('secAccess'), '<p class="cpj-note">' + hbT('accessIntro') + '</p>' +
        ((b.acces || []).length ? b.acces.map((n, j) => '<div style="display:flex;justify-content:space-between;align-items:center">' + hbE(n) +
            hbBouton(hbT('revoke'), 'partiRegistreAcces(' + i + ',' + j + ',false)', false) + '</div>').join('')
          : '<p class="cpj-note">' + hbT('noOneElse') + '</p>') +
        '<input id="hb-acces-' + i + '" class="cpj-champ" maxlength="60" placeholder="' + hbE(hbT('namePh')) + '" style="width:100%;margin-top:.4rem">' +
        hbBouton(hbT('grant'), 'partiRegistreAcces(' + i + ',null,true)', true));
    }
    return hbSection(hbE(b.nom) + (b.est_chef ? ' — ' + hbT('youChief') : ''), den) + acces;
  }).join('');
  hbModal(hbT('titleRegistry'), h, ouvrirPartiRegistre);
}

async function partiRegistreSupprimer(id) {
  if (hbEnCours || !confirm(hbT('confirmDelete'))) return;
  hbEnCours = true;
  try {
    const v = await sbRpcVerdict('parti_boite_supprimer', { p_id: id }).catch(() => null);
    if (!v || v.ok !== true) { hbRefus(v); return; }
  } finally { hbEnCours = false; }
  ouvrirPartiRegistre();
}

async function partiRegistreAcces(i, j, acces) {
  const b = hbBoites?.boites?.[i];
  const qui = String(j != null ? (b?.acces?.[j] || '') : (document.getElementById('hb-acces-' + i)?.value || '')).trim();
  if (!b || !qui || hbEnCours) return;
  hbEnCours = true;
  try {
    const v = await sbRpcVerdict('parti_boite_acces_fixer', { p_parti: b.parti, p_personnage: qui, p_acces: acces }).catch(() => null);
    if (!v || v.ok !== true) { hbRefus(v); return; }
  } finally { hbEnCours = false; }
  ouvrirPartiRegistre();
}

if (typeof window !== 'undefined') Object.assign(window, {
  ouvrirHerosTravailTableau, ouvrirHerosTravailClassement, herosTravailDecorer, herosDecorationsDans, herosObjetTexte,
  ouvrirPartiDenoncer, partiDenoncerEnvoyer, ouvrirPartiRegistre, partiRegistreSupprimer, partiRegistreAcces
});
