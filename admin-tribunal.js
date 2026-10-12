/* ===========================================================================
   HUMAN GAMBIT — ADMIN-TRIBUNAL.JS
   Panneau d'administration du Tribunal (12 octobre 2026)
   ===========================================================================

   CE QUE CET ECRAN EST. Une vue des dossiers judiciaires qui attendent
   peut-etre une intervention institutionnelle, et les actions que le PNJ
   titulaire -- Saad au parquet, Honore au tribunal de la capitale -- peut
   REELLEMENT accomplir a ce stade du dossier.

   CE QU'IL N'EST PAS, et c'est l'essentiel. Il n'ecrit rien. Il n'offre aucune
   modification de colonne, aucune console SQL, aucun bouton « forcer ». Il
   n'appelle que deux portes : `admin_tribunal_dossiers()` pour lire, et
   `admin_incarner(poste, action, affaire, parametres)` pour agir -- et celle-ci
   ne fait qu'appeler la fonction metier que le titulaire appellerait, gardes
   intactes. Les boutons affiches ici ne sont donc qu'une PROPOSITION : le
   serveur revalide tout, et refuse si le statut, le delai, la juridiction, la
   presence ou la titularite ne le permettent pas.

   CACHER UN BOUTON N'EST PAS UNE SECURITE, et aucun bouton de cette page n'en
   tient lieu. Si Fred ouvre cet ecran sans autorite administrateur, les deux
   portes LEVENT au serveur ; si un PJ prend le poste de Procureur entre
   l'ouverture de l'ecran et le clic, le serveur refuse `poste_tenu_par_un_pj`.

   LE RAFRAICHISSEMENT EST DISCRET. Une relecture toutes les 20 secondes, mise
   en pause quand l'onglet n'est pas visible, et un compteur sobre. AUCUN SON,
   aucune notification, aucune bulle : c'est un compteur, pas une alerte.
   =========================================================================== */

const ADMIN_PERIODE_MS = 20000;
let ADMIN_ETAT = null;
let ADMIN_MINUTEUR = null;
let ADMIN_DERNIER_COMPTE = null;

function admEl(id) { return document.getElementById(id); }
function admEchapper(t) {
  return String(t === null || t === undefined ? '' : t)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}
function admMessage(t, mauvais) {
  const z = admEl('adm-message');
  if (!z) return;
  z.textContent = t || '';
  z.className = 'adm-message' + (t ? (mauvais ? ' mauvais' : ' bon') : '');
}

/* --- CONNEXION ----------------------------------------------------------- */
async function admConnecter(ev) {
  if (ev) ev.preventDefault();
  const email = (admEl('adm-email').value || '').trim();
  const mdp   = admEl('adm-mdp').value || '';
  if (!email || !mdp) { admMessage('Adresse et mot de passe sont requis.', true); return; }
  admMessage('Connexion…', false);
  const r = await rpAdminSeConnecter(email, mdp);
  if (!r.ok) {
    admMessage('Connexion refusée (' + r.raison + ').', true);
    return;
  }
  admEl('adm-mdp').value = '';
  await admDemarrer();
}

function admDeconnecter() {
  rpAdminSeDeconnecter();
  if (ADMIN_MINUTEUR) { clearInterval(ADMIN_MINUTEUR); ADMIN_MINUTEUR = null; }
  ADMIN_ETAT = null;
  admEl('adm-connexion').hidden = false;
  admEl('adm-panneau').hidden = true;
  admMessage('Session fermée.', false);
}

/* --- DECLARATION DU PREMIER COMPTE --------------------------------------
   Elle n'ouvre qu'une fois dans la vie de la base, et seulement pour un compte
   qui a une adresse, qui n'est pas anonyme, et qui ne porte AUCUN personnage.
   Le serveur verifie les quatre conditions ; ce bouton ne fait que les demander. */
async function admSeDeclarer() {
  const libelle = (prompt('Nom de cette administration (pour l\'audit privé) :', 'Administration') || '').trim();
  if (!libelle) return;
  const r = await rpAdminRpc('admin_se_declarer', { p_libelle: libelle });
  if (r && r.ok === true) { admMessage('Compte administrateur déclaré.', false); await admDemarrer(); }
  else admMessage('Déclaration refusée (' + ((r && r.raison) || 'inconnue') + ').', true);
}

/* --- DEMARRAGE ----------------------------------------------------------- */
async function admDemarrer() {
  const moi = await rpAdminRpc('admin_moi', {});
  if (!moi || moi.ok !== true) {
    admEl('adm-connexion').hidden = false;
    admEl('adm-panneau').hidden = true;
    admEl('adm-bootstrap').hidden = true;
    if (moi && moi.raison !== 'session_absente') admMessage('Lecture refusée (' + moi.raison + ').', true);
    return;
  }
  // LE BOUTON DE DECLARATION N'APPARAIT QUE SI LA BASE N'A AUCUN ADMINISTRATEUR -- et son absence
  // n'est pas la securite : la porte serveur refuse de toute facon des qu'un administrateur existe.
  admEl('adm-bootstrap').hidden = !(moi.bootstrap_ouvert === true && moi.administrateur !== true);
  if (moi.administrateur !== true) {
    admEl('adm-connexion').hidden = false;
    admEl('adm-panneau').hidden = true;
    admMessage('Ce compte est authentifié mais ne porte aucune autorité d\'administration.', true);
    return;
  }
  admEl('adm-connexion').hidden = true;
  admEl('adm-panneau').hidden = false;
  admEl('adm-identite').textContent = (moi.libelle || 'Administration') + ' — ' + (rpAdminEmail() || '');
  admMessage('', false);
  await admRelire();
  if (ADMIN_MINUTEUR) clearInterval(ADMIN_MINUTEUR);
  ADMIN_MINUTEUR = setInterval(function () {
    // L'onglet cache ne travaille pas : un panneau laisse ouvert toute la nuit ne doit pas
    // interroger la base 4 000 fois pour rien.
    if (document.hidden) return;
    admRelire();
  }, ADMIN_PERIODE_MS);
}

/* --- LECTURE ------------------------------------------------------------- */
async function admRelire() {
  const v = await rpAdminRpc('admin_tribunal_dossiers', {});
  if (!v || v.ok !== true) {
    admMessage('Lecture refusée par le serveur (' + ((v && v.raison) || 'inconnue') + ').', true);
    return;
  }
  ADMIN_ETAT = v;
  admRendre();
}

function admActionsPour(poste, statut) {
  const actions = (ADMIN_ETAT && ADMIN_ETAT.actions) || [];
  return actions.filter(a => a.poste === poste
    && Array.isArray(a.statuts) && a.statuts.indexOf(statut) >= 0);
}

function admDossierHtml(poste, d) {
  const dos = d.dossier || {};
  const statut = dos.status || '?';
  const possibles = admActionsPour(poste, statut);
  const presenceManquante = (poste === 'procureur' && d.present === false);
  let h = '<div class="adm-dossier">';
  h += '<div class="adm-ligne"><strong>' + admEchapper(d.id) + '</strong>'
     + '<span class="adm-statut">' + admEchapper(statut) + '</span>'
     + '<span class="adm-ville">' + admEchapper(d.ville || dos.city || '') + '</span>';
  if (possibles.length > 0 && !presenceManquante) h += '<span class="adm-attente">action possible</span>';
  h += '</div>';
  h += '<div class="adm-detail">'
     + 'Mis en cause : <strong>' + admEchapper(dos.cible || '?') + '</strong>'
     + ' · Plaignant : ' + admEchapper(dos.plaignant || '—')
     + ' · Motif : ' + admEchapper(dos.motif || '—')
     + (dos.qualification_parquet ? ' · Qualification : ' + admEchapper(dos.qualification_parquet) : '')
     + (dos.delai_jugement_jour ? ' · Échéance de jugement : jour ' + admEchapper(dos.delai_jugement_jour) : '')
     + '</div>';

  const actes = Array.isArray(d.actes) ? d.actes : [];
  if (actes.length > 0) {
    h += '<details class="adm-chrono"><summary>Chronologie (' + actes.length + ')</summary><ol>';
    actes.forEach(function (a) {
      h += '<li>' + admEchapper(a.libelle || a.type) + ' — ' + admEchapper(a.acteur || '?')
         + (a.poste ? ' (' + admEchapper(a.poste) + ')' : '') + '</li>';
    });
    h += '</ol></details>';
  }

  if (presenceManquante) {
    h += '<div class="adm-refus">Le Procureur siège au tribunal de la capitale : il ne peut pas '
       + 'instruire un dossier de ' + admEchapper(d.ville || '') + '.</div>';
  } else if (possibles.length === 0) {
    h += '<div class="adm-refus">Aucune action institutionnelle n\'est ouverte à ce stade.</div>';
  } else {
    h += '<div class="adm-actions">';
    possibles.forEach(function (a) {
      h += '<button type="button" onclick="admOuvrirAction(\'' + admEchapper(a.poste) + '\',\''
         + admEchapper(a.action) + '\',\'' + admEchapper(d.id) + '\')">'
         + admEchapper(a.libelle) + '</button>';
    });
    h += '</div>';
  }
  h += '</div>';
  return h;
}

function admBlocHtml(titre, poste, bloc) {
  let h = '<section class="adm-bloc"><h2>' + admEchapper(titre) + '</h2>';
  if (bloc.incarnable !== true) {
    h += '<p class="adm-refus">Ce poste est tenu par un personnage joueur : il n\'y a rien à '
       + 'incarner ici, et le serveur refuserait toute action.</p></section>';
    return h;
  }
  h += '<p class="adm-pnj">Titulaire : <strong>' + admEchapper(bloc.pnj) + '</strong></p>';
  const vue = bloc.vue || {};
  if (vue.ok !== true) {
    h += '<p class="adm-refus">' + admEchapper(vue.raison || 'lecture indisponible') + '</p></section>';
    return h;
  }
  const dossiers = Array.isArray(vue.dossiers) ? vue.dossiers : [];
  if (dossiers.length === 0) h += '<p class="adm-vide">Aucun dossier.</p>';
  else dossiers.forEach(function (d) { h += admDossierHtml(poste, d); });
  h += '</section>';
  return h;
}

function admRendre() {
  const v = ADMIN_ETAT;
  if (!v) return;
  const compte = v.en_attente || 0;
  const badge = admEl('adm-compteur');
  if (badge) {
    badge.textContent = compte > 0 ? (compte + (compte > 1 ? ' dossiers en attente' : ' dossier en attente'))
                                   : 'rien en attente';
    badge.className = 'adm-compteur' + (compte > 0 ? ' actif' : '');
  }
  ADMIN_DERNIER_COMPTE = compte;
  admEl('adm-lu').textContent = 'relu à ' + new Date().toLocaleTimeString('fr-FR');
  admEl('adm-contenu').innerHTML =
      admBlocHtml('Parquet', 'procureur', v.parquet || {})
    + admBlocHtml('Tribunal de la capitale', 'juge', v.juge || {});
}

/* --- ACTION -------------------------------------------------------------
   LES PARAMETRES SONT CEUX DE LA FONCTION METIER, et rien de plus : on ne peut
   pas inventer un champ que le titulaire ne renseignerait pas. Les valeurs
   proposees viennent du dossier ou du bareme ; le serveur les revalide toutes
   (bornes de peine, genre connu, decision connue). */
const ADMIN_CHAMPS = {
  poursuivre:          [{ cle: 'infraction', libelle: 'Qualification retenue', type: 'text' }],
  non_lieu:            [{ cle: 'motif', libelle: 'Motif du non-lieu', type: 'text' }],
  abandonner:          [{ cle: 'motif', libelle: 'Motif de l\'abandon', type: 'text' }],
  relaxer:             [{ cle: 'infraction', libelle: 'Qualification (requalification possible)', type: 'text' }],
  rendre_sentence:     [{ cle: 'infraction', libelle: 'Qualification', type: 'text' },
                        { cle: 'genre', libelle: 'Genre de peine', type: 'select',
                          options: ['prison', 'amende', 'amenagement', 'qhs'] },
                        { cle: 'jours', libelle: 'Jours', type: 'number' },
                        { cle: 'amende', libelle: 'Amende (FR)', type: 'number' }],
  suite_apres_abandon: [{ cle: 'decision', libelle: 'Décision', type: 'select',
                          options: ['arret', 'poursuivre'] }],
  juger_appel:         [{ cle: 'verdict', libelle: 'Verdict d\'appel', type: 'select',
                          options: ['condamnation', 'relaxe'] },
                        { cle: 'infraction', libelle: 'Qualification', type: 'text' },
                        { cle: 'genre', libelle: 'Genre de peine', type: 'select',
                          options: ['prison', 'amende', 'amenagement', 'qhs'] },
                        { cle: 'jours', libelle: 'Jours', type: 'number' },
                        { cle: 'amende', libelle: 'Amende (FR)', type: 'number' }]
};

function admDossierDe(id) {
  const v = ADMIN_ETAT; if (!v) return null;
  const listes = [((v.parquet || {}).vue || {}).dossiers, ((v.juge || {}).vue || {}).dossiers];
  for (let k = 0; k < listes.length; k++) {
    const l = listes[k]; if (!Array.isArray(l)) continue;
    for (let m = 0; m < l.length; m++) if (l[m] && l[m].id === id) return l[m].dossier || {};
  }
  return null;
}

function admOuvrirAction(poste, action, affaire) {
  const champs = ADMIN_CHAMPS[action] || [];
  const dos = admDossierDe(affaire) || {};
  const defautInfraction = dos.qualification_finale || dos.qualification_parquet
                        || dos.infraction_constatee || '';
  let h = '<h3>' + admEchapper(action.replace(/_/g, ' ')) + ' — ' + admEchapper(affaire) + '</h3>';
  h += '<form onsubmit="return admEnvoyerAction(event,\'' + admEchapper(poste) + '\',\''
     + admEchapper(action) + '\',\'' + admEchapper(affaire) + '\')">';
  champs.forEach(function (c) {
    const defaut = c.cle === 'infraction' ? defautInfraction : '';
    h += '<label>' + admEchapper(c.libelle) + '<br>';
    if (c.type === 'select') {
      h += '<select name="' + c.cle + '">';
      c.options.forEach(function (o) { h += '<option value="' + o + '">' + o + '</option>'; });
      h += '</select>';
    } else {
      h += '<input type="' + (c.type === 'number' ? 'number' : 'text') + '" name="' + c.cle
         + '" value="' + admEchapper(defaut) + '">';
    }
    h += '</label>';
  });
  if (champs.length === 0) h += '<p>Cette action ne prend aucun paramètre.</p>';
  h += '<div class="adm-boutons"><button type="submit">Exécuter</button>'
     + '<button type="button" onclick="admFermerAction()">Annuler</button></div></form>';
  admEl('adm-modale-corps').innerHTML = h;
  admEl('adm-modale').hidden = false;
}

function admFermerAction() {
  admEl('adm-modale').hidden = true;
  admEl('adm-modale-corps').innerHTML = '';
}

async function admEnvoyerAction(ev, poste, action, affaire) {
  ev.preventDefault();
  const form = ev.target;
  const params = {};
  (ADMIN_CHAMPS[action] || []).forEach(function (c) {
    const el = form.elements[c.cle];
    if (!el) return;
    const brut = (el.value || '').trim();
    if (brut === '') return;
    params[c.cle] = (c.type === 'number') ? Number(brut) : brut;
  });
  admFermerAction();
  admMessage('Envoi…', false);
  const r = await rpAdminRpc('admin_incarner',
    { p_poste: poste, p_action: action, p_affaire_id: affaire, p_params: params });
  if (r && r.ok === true) {
    admMessage('Acte accompli.', false);
  } else {
    admMessage('Refusé par le serveur : ' + ((r && r.raison) || 'inconnue')
               + (r && r.statut ? ' (statut ' + r.statut + ')' : ''), true);
  }
  await admRelire();
  return false;
}

/* --- ENTREE ------------------------------------------------------------- */
window.addEventListener('DOMContentLoaded', function () {
  admEl('adm-formulaire').addEventListener('submit', admConnecter);
  // Une session deja ouverte reprend la main sans rien demander : c'est le propre d'un panneau
  // qu'on laisse ouvert a cote du jeu.
  if (rpAdminJeton()) admDemarrer();
  else rpAdminRenouveler().then(function (ok) { if (ok) admDemarrer(); });
});
