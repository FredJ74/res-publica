// =====================================================================================
// L'ELECTION DU PRESIDENT DE L'ASSEMBLEE — L'ECRAN ET LA COURTE PAILLE (11 octobre 2026)
// =====================================================================================
// NEUF DEPUTES, PAS NEUF PLUS UN. La presidence n'est pas un dixieme siege : c'est une
// fonction portee par l'un des neuf. Cet ecran ne propose donc jamais d'autre nom que
// ceux que le serveur a figes a l'ouverture du scrutin.
//
// IL N'Y A AUCUNE CANDIDATURE A DEPOSER, et c'est l'arbitrage : les neuf sont eligibles
// d'office. On ne trouvera donc ici ni bouton « se porter candidat », ni liste de
// candidats -- seulement les neuf deputes, et une voix a donner.
//
// ET LE NAVIGATEUR NE TIRE JAMAIS LA COURTE PAILLE. Quand l'animation commence, le
// vainqueur est deja ecrit en base depuis 23 heures : le halo s'arrete sur la paille du
// depute que le SERVEUR a designe. Rafraichir la page, rejouer l'animation, ouvrir un
// autre onglet -- le resultat ne bouge pas d'un pouce.
//
// LE RESULTAT NE DEPEND JAMAIS DE LA PRESENCE DES JOUEURS. Celui qui etait la voit le
// tirage sur le moment ; celui qui etait absent le decouvre a son retour a l'Assemblee,
// UNE FOIS, et l'etat « deja vu » est serveur -- pas un drapeau de navigateur.
// =====================================================================================

const PRESIDENCE_TIRAGE_MS = 3400;        // duree totale de l'animation du tirage
const PRESIDENCE_PAS_MIN_MS = 70;         // le halo le plus rapide
const PRESIDENCE_PAS_MAX_MS = 460;        // le halo le plus lent, juste avant l'arret

let RP_PRESIDENCE_ETAT = null;
let RP_PRESIDENCE_ANIMATION = null;       // le minuteur en cours, pour pouvoir l'arreter

if (typeof ASSEMBLEE_RAISONS !== 'undefined') {
  Object.assign(ASSEMBLEE_RAISONS, {
    aucun_scrutin_ouvert:   'Aucune élection du Président n\'est en cours.',
    scrutin_clos:           'Le scrutin est clos : il est 23h00 passées.',
    pas_eligible:           'Ce nom n\'est pas l\'un des neuf députés.',
    deja_vote:              'Vous avez déjà voté. Une voix déposée ne se reprend pas.',
    scrutin_inconnu:        'Ce scrutin n\'existe pas.',
    aucune_suspension:      'La séance n\'est pas suspendue.',
    deja_suspendue:         'La séance est déjà suspendue.',
    seance_suspendue:       'La séance est suspendue : le Président doit la reprendre.',
    reserve_au_serveur:     'Cette opération appartient au serveur.',
    hors_fenetre_convocation: 'Une élection ne se convoque que le lundi.'
  });
}


// -------------------------------------------------------------------------------------
// L'ETAT DU SCRUTIN
// -------------------------------------------------------------------------------------
async function presidenceRafraichir() {
  if (typeof sbAssembleePresidenceEtat !== 'function') return null;
  const e = await sbAssembleePresidenceEtat();
  if (e && e.ok === true) {
    RP_PRESIDENCE_ETAT = e;
    presidenceAdopterLeTitre(e);
  }
  return RP_PRESIDENCE_ETAT;
}

// LE TITRE SUIT LE TITULAIRE REEL, ET LE REGISTRE EN FAIT FOI.
//
// La proclamation a lieu a 23 heures, au serveur, et le joueur peut etre deconnecte a ce
// moment-la : aucun code client ne peut donc ecrire son titre « au moment ou il gagne ».
// L'ecran ADOPTE donc la presidence lue en base des qu'il la voit -- et la retire des que la
// base ne la dit plus. Le declencheur d'attestation de la fiche verifie ce poste contre
// `postes_attribues` : un titre pose ici sans ligne au registre serait annule en silence.
//
// LA PRESIDENCE NE TOUCHE JAMAIS AU MANDAT DE DEPUTE (`state.posteDepute`) : perdre la
// presidence n'est pas perdre son siege. Les deux qualites vivent dans deux champs distincts,
// et c'est ce qui permet de les afficher ensemble.
//
// RESERVE, ET ELLE EST AU RAPPORT : `state.poste` est un emplacement UNIQUE. Si un depute
// President detenait par ailleurs un poste nomme -- un ministere, par exemple --, l'un des deux
// titres ne tiendrait pas dans la fiche. On n'ecrase donc JAMAIS un poste existant : on n'adopte
// la presidence que sur un emplacement libre, et le cumul reste a arbitrer.
function presidenceAdopterLeTitre(e) {
  if (typeof state === 'undefined' || !state.char || !state.char.name) return;
  const moi = state.char.name;
  const jeSuisPresident = !!e.president && e.president === moi;
  const porteDejaLaPresidence = state.poste && state.poste.id === 'president_assemblee';

  if (jeSuisPresident && !porteDejaLaPresidence) {
    if (state.poste) return;    // un autre poste nomme occupe la place : on ne l'ecrase pas
    state.poste = { id: 'president_assemblee',
                    name: 'Président de l\'Assemblée nationale',
                    city: null, nommeLe: Date.now() };
  } else if (!jeSuisPresident && porteDejaLaPresidence) {
    state.poste = null;         // il n'est plus President : le titre tombe, le siege reste
  } else {
    return;
  }
  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  if (typeof updateUI === 'function') updateUI();
}


// -------------------------------------------------------------------------------------
// LE BLOC DE SCRUTIN, DANS L'ECRAN DE SEANCE
// -------------------------------------------------------------------------------------
// Rendu dans le panneau de seance, qui l'appelle a chaque redessin. Il n'y a pas de
// second ecran : l'election du President est un moment de la seance, pas un lieu a part.
function presidenceDessinerBloc(parent) {
  const e = RP_PRESIDENCE_ETAT;
  if (!e || e.ok !== true) return;

  const moi = (typeof state !== 'undefined' && state.char && state.char.name) || '';
  const s = e.scrutin;

  const boite = document.createElement('div');
  boite.className = 'sc-boite';

  const t = document.createElement('div');
  t.style.cssText = 'font-family:Bebas Neue,sans-serif;letter-spacing:.11em;font-size:.82rem;'
    + 'color:#C9A84C;margin-bottom:.4rem';
  t.textContent = s ? 'ÉLECTION DU PRÉSIDENT DE L\'ASSEMBLÉE' : 'LA PRÉSIDENCE';
  boite.appendChild(t);

  // --- HORS SCRUTIN : qui preside, et une election est-elle due ?
  if (!s) {
    boite.appendChild(presidenceLigne(e.president
      ? ('Préside : ' + e.president)
      : 'Aucun Président n\'est en fonction.'));
    if (e.election_due) {
      // UN FAIT, PAS UNE MENACE. Le deuxieme episode de boycott a remis la presidence en
      // jeu ; la convocation du lundi ouvrira le scrutin.
      boite.appendChild(presidenceLigne(
        'La présidence est remise en jeu : une élection est due et sera convoquée lundi.',
        '#d8a060'));
    }
    boite.appendChild(presidenceLigne(
      'Les neuf députés sont éligibles d\'office — il n\'y a aucune candidature à déposer.',
      '#8a7d5a'));
    parent.appendChild(boite);
    return;
  }

  // --- LE SCRUTIN EST OUVERT
  boite.appendChild(presidenceLigne('Scrutin à un seul tour, clos le '
    + presidenceHeure(s.cloture_ts) + '. Le décompte est visible pendant toute sa durée.',
    '#8a7d5a'));
  if (s.cause === 'deux_boycotts') {
    boite.appendChild(presidenceLigne(
      'Élection exceptionnelle : deux suspensions par boycott ont remis la présidence en jeu.',
      '#d8a060'));
  }

  const decompte = Array.isArray(s.decompte) ? s.decompte : [];
  const peutVoter = e.je_suis_depute && !s.mon_bulletin;

  if (e.je_suis_depute) {
    boite.appendChild(presidenceLigne(s.mon_bulletin
      ? ('Votre voix est allée à ' + s.mon_bulletin + '. Elle ne se reprend pas.')
      : 'Vous pouvez voter pour n\'importe lequel des neuf, y compris vous-même.',
      s.mon_bulletin ? '#4a8a4a' : null));
  } else {
    boite.appendChild(presidenceLigne(
      'Seuls les neuf députés votent. Les députés PNJ s\'abstiennent systématiquement.',
      '#8a7d5a'));
  }

  // --- LE DECOMPTE, ET LE BULLETIN
  const liste = document.createElement('div');
  liste.style.cssText = 'margin-top:.5rem';
  decompte.forEach(d => {
    const el = (Array.isArray(s.eligibles) ? s.eligibles : [])
      .filter(x => x.depute === d.depute)[0] || {};
    const ligne = document.createElement('div');
    ligne.style.cssText = 'display:flex;align-items:center;gap:.5rem;padding:.22rem 0;'
      + 'border-bottom:1px solid #1e1a0e';

    const nom = document.createElement('div');
    nom.style.cssText = 'flex:1;font-size:.84rem';
    // textContent : un nom de joueur n'est jamais interprete.
    nom.textContent = d.depute + (d.depute === moi ? ' (vous)' : '')
      + ' — ' + (el.ville || '?') + (el.est_pnj ? ' · PNJ' : '');
    ligne.appendChild(nom);

    const voix = document.createElement('div');
    voix.style.cssText = 'font-family:Bebas Neue,sans-serif;letter-spacing:.06em;font-size:.86rem;'
      + 'color:' + (d.voix > 0 ? '#E8C97A' : '#5f5740');
    voix.textContent = d.voix + (d.voix === 1 ? ' voix' : ' voix');
    ligne.appendChild(voix);

    if (peutVoter) {
      const b = document.createElement('button');
      b.className = 'sc-b';
      b.style.margin = '0';
      b.textContent = 'Voter';
      b.addEventListener('click', () => { presidenceVoter(d.depute).catch(() => {}); });
      ligne.appendChild(b);
    }
    liste.appendChild(ligne);
  });
  boite.appendChild(liste);

  const pied = document.createElement('div');
  pied.className = 'sc-vide';
  pied.textContent = s.bulletins + (s.bulletins === 1 ? ' bulletin déposé.' : ' bulletins déposés.')
    + ' En cas d\'égalité en tête, le départage se fera à la courte paille.';
  boite.appendChild(pied);

  parent.appendChild(boite);
}

async function presidenceVoter(pour) {
  if (typeof assembleeActionServeur !== 'function') return;
  const r = await assembleeActionServeur((rq) => sbAssembleePresidenceVoter(pour, rq));
  if (!assembleeIssueAction(r)) { await presidenceRafraichir(); return; }
  if (r.res.rejeu !== true) {
    showToast('Voix déposée', 'Votre voix est allée à ' + pour + '. Elle ne se reprend pas.', true);
    addJournalEntry('Vote pour la présidence de l\'Assemblée : ' + pour + '.', '');
  }
  await presidenceRafraichir();
  if (typeof seanceRafraichir === 'function') await seanceRafraichir();
}


// -------------------------------------------------------------------------------------
// LA COURTE PAILLE
// -------------------------------------------------------------------------------------
// LE VAINQUEUR EST DEJA ECRIT. Cette fonction ne choisit rien : elle fait circuler un
// halo entre les pailles, le ralentit, et l'arrete sur celle du depute que le serveur a
// designe. Puis la paille se revele courte, et la seconde popup annonce le President.
//
// AUCUN ASSET GRAPHIQUE N'A ETE INVENTE : la main et les pailles sont dessinees en
// HTML/CSS. Une vraie illustration serait plus belle -- elle est demandee au rapport.
function presidenceTirageOuvrir(scrutin, surFermeture) {
  if (!scrutin || !Array.isArray(scrutin.egalite) || scrutin.egalite.length < 2) {
    if (typeof surFermeture === 'function') surFermeture();
    return;
  }
  presidenceTirageFermer();

  const pailles = scrutin.egalite.slice();
  const gagnant = scrutin.elu;
  const iGagnant = pailles.indexOf(gagnant);
  if (iGagnant < 0) {           // incoherence : on annonce sans animer plutot que de mentir
    presidenceAnnonceOuvrir(scrutin, surFermeture);
    return;
  }

  presidenceStyles();
  const cadre = document.createElement('div');
  cadre.id = 'rp-presidence-tirage';
  cadre.className = 'pr-cadre';

  const boite = document.createElement('div');
  boite.className = 'pr-boite';

  const titre = document.createElement('div');
  titre.className = 'pr-titre';
  titre.textContent = 'Égalité — tirage à la courte paille';
  boite.appendChild(titre);

  const sous = document.createElement('div');
  sous.className = 'pr-sous';
  sous.textContent = pailles.length + ' députés sont à égalité en tête. Une paille par député. '
    + 'Le tirage a été fait par le serveur : vous en voyez le résultat.';
  boite.appendChild(sous);

  // --- LA MAIN ET LES PAILLES
  const main = document.createElement('div');
  main.className = 'pr-main';
  const poing = document.createElement('div');
  poing.className = 'pr-poing';
  main.appendChild(poing);

  const rangee = document.createElement('div');
  rangee.className = 'pr-pailles';
  const brins = [];
  pailles.forEach((nom, i) => {
    const colonne = document.createElement('div');
    colonne.className = 'pr-colonne';

    const brin = document.createElement('div');
    brin.className = 'pr-brin';
    colonne.appendChild(brin);

    const etiquette = document.createElement('div');
    etiquette.className = 'pr-nom';
    etiquette.textContent = nom;      // textContent : un nom de joueur reste du texte
    colonne.appendChild(etiquette);

    rangee.appendChild(colonne);
    brins.push({ colonne, brin });
  });
  main.appendChild(rangee);
  boite.appendChild(main);

  const etat = document.createElement('div');
  etat.className = 'pr-etat';
  etat.textContent = 'Tirage en cours…';
  boite.appendChild(etat);

  cadre.appendChild(boite);
  document.body.appendChild(cadre);

  // --- LE HALO : il circule, ralentit, et s'arrete sur la paille du vainqueur.
  // Le nombre de pas est calcule pour FINIR sur iGagnant : aucun hasard local.
  const n = pailles.length;
  let pas = Math.max(n * 3, 12);
  while (((pas % n) + n) % n !== ((iGagnant - 0) % n + n) % n) pas++;   // atterrir juste

  let i = 0, fait = 0;
  const avancer = () => {
    brins.forEach(b => b.colonne.classList.remove('pr-vise'));
    brins[i % n].colonne.classList.add('pr-vise');
    fait++;
    if (fait > pas) {
      RP_PRESIDENCE_ANIMATION = null;
      // LA PAILLE SE REVELE COURTE. C'est le seul moment ou les brins cessent d'etre
      // identiques : jusque-la, rien ne devait trahir le resultat.
      brins[iGagnant].brin.classList.add('pr-courte');
      brins[iGagnant].colonne.classList.add('pr-gagnante');
      etat.textContent = gagnant + ' a tiré la courte paille.';
      setTimeout(() => { presidenceAnnonceOuvrir(scrutin, surFermeture); }, 900);
      return;
    }
    i++;
    // Le pas s'allonge a mesure qu'on approche : le halo ralentit.
    const t = Math.min(1, fait / pas);
    const delai = PRESIDENCE_PAS_MIN_MS
      + (PRESIDENCE_PAS_MAX_MS - PRESIDENCE_PAS_MIN_MS) * Math.pow(t, 2.4);
    RP_PRESIDENCE_ANIMATION = setTimeout(avancer, delai);
  };
  RP_PRESIDENCE_ANIMATION = setTimeout(avancer, PRESIDENCE_PAS_MIN_MS);
}

// LA SECONDE POPUP : elle annonce le President. La fermer ferme TOUT -- animation
// comprise --, rafraichit la piece et la liste laterale des personnes presentes.
function presidenceAnnonceOuvrir(scrutin, surFermeture) {
  presidenceStyles();
  const cadre = document.createElement('div');
  cadre.id = 'rp-presidence-annonce';
  cadre.className = 'pr-cadre';

  const boite = document.createElement('div');
  boite.className = 'pr-boite';

  const titre = document.createElement('div');
  titre.className = 'pr-titre';
  titre.textContent = 'Président de l\'Assemblée nationale';
  boite.appendChild(titre);

  const nom = document.createElement('div');
  nom.className = 'pr-elu';
  nom.textContent = scrutin.elu;     // textContent : c'est un nom de joueur ou de PNJ
  boite.appendChild(nom);

  const detail = document.createElement('div');
  detail.className = 'pr-sous';
  const voix = (Array.isArray(scrutin.decompte) ? scrutin.decompte : [])
    .filter(d => d.depute === scrutin.elu)[0];
  detail.textContent = (voix ? (voix.voix + (voix.voix === 1 ? ' voix' : ' voix')) : 'élu')
    + (Array.isArray(scrutin.egalite) && scrutin.egalite.length > 1
       ? ', après un départage à la courte paille entre ' + scrutin.egalite.length + ' députés.'
       : '.')
    + ' Il reste député : la présidence est une fonction, pas un mandat de plus.';
  boite.appendChild(detail);

  const actions = document.createElement('div');
  actions.style.cssText = 'margin-top:1.1rem';
  const b = document.createElement('button');
  b.className = 'pr-bouton';
  b.textContent = 'Fermer';
  b.addEventListener('click', () => {
    presidenceTirageFermer();
    if (typeof surFermeture === 'function') surFermeture();
  });
  actions.appendChild(b);
  boite.appendChild(actions);

  cadre.appendChild(boite);
  document.body.appendChild(cadre);
}

function presidenceTirageFermer() {
  if (RP_PRESIDENCE_ANIMATION) { clearTimeout(RP_PRESIDENCE_ANIMATION); RP_PRESIDENCE_ANIMATION = null; }
  ['rp-presidence-tirage', 'rp-presidence-annonce'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.remove();
  });
}


// -------------------------------------------------------------------------------------
// LA REVELATION DIFFEREE — SIXIEME CONSOMMATEUR DE L'EVENEMENT D'ENTREE
// -------------------------------------------------------------------------------------
// Un joueur absent a 23 heures decouvre le resultat a son retour a l'Assemblee. UNE
// FOIS : l'etat « deja vu » est enregistre au serveur, donc il survit a un
// rafraichissement, a un changement de machine, et a un onglet ferme trop vite.
//
// No-op immediat partout ailleurs : deux comparaisons de chaines, aucun appel reseau.
async function presidenceEntreeZone(buildingId, roomId) {
  if (buildingId !== 'assemblee') return;
  if (roomId !== 'hemicycle' && roomId !== 'accueil_assemblee') return;
  if (typeof sbAssembleePresidenceEtat !== 'function') return;
  if (document.getElementById('rp-presidence-tirage')
      || document.getElementById('rp-presidence-annonce')) return;

  const e = await presidenceRafraichir();
  const a = e && e.a_revoir;
  if (!a || !a.id) return;

  presidenceStyles();
  const cadre = document.createElement('div');
  cadre.id = 'rp-presidence-tirage';          // meme identifiant : une seule popup a la fois
  cadre.className = 'pr-cadre';

  const boite = document.createElement('div');
  boite.className = 'pr-boite';

  const titre = document.createElement('div');
  titre.className = 'pr-titre';
  titre.textContent = 'Égalité à l\'élection du Président';
  boite.appendChild(titre);

  const sous = document.createElement('div');
  sous.className = 'pr-sous';
  sous.textContent = (Array.isArray(a.egalite) ? a.egalite.length : 0)
    + ' députés sont arrivés à égalité en tête. Le départage s\'est fait à la courte paille, '
    + 'et le résultat est enregistré depuis la clôture du scrutin. Vous pouvez y assister.';
  boite.appendChild(sous);

  const actions = document.createElement('div');
  actions.style.cssText = 'margin-top:1.1rem;display:flex;gap:.5rem;flex-wrap:wrap';

  const voir = document.createElement('button');
  voir.className = 'pr-bouton';
  voir.textContent = 'Assister au tirage';
  voir.addEventListener('click', () => {
    presidenceTirageFermer();
    // LE MEME RESULTAT, REJOUE. Aucune nouvelle randomisation : `a` vient de la base.
    presidenceTirageOuvrir(a, () => presidenceApresRevelation(a.id));
  });
  actions.appendChild(voir);

  const plusTard = document.createElement('button');
  plusTard.className = 'pr-bouton pr-discret';
  plusTard.textContent = 'Plus tard';
  plusTard.addEventListener('click', presidenceTirageFermer);
  actions.appendChild(plusTard);

  boite.appendChild(actions);
  cadre.appendChild(boite);
  document.body.appendChild(cadre);
}

// LA FERMETURE FAIT LES TROIS CHOSES QUE L'ARBITRAGE DEMANDE : elle note au serveur que
// ce joueur a vu le tirage, elle rafraichit la piece, et elle rafraichit les titres de
// la liste laterale -- ou le nouveau President doit apparaitre comme tel.
async function presidenceApresRevelation(scrutinId) {
  if (scrutinId && typeof sbAssembleePresidenceTirageVu === 'function') {
    await sbAssembleePresidenceTirageVu(scrutinId).catch(() => {});
  }
  await presidenceRafraichir().catch(() => {});
  if (typeof state !== 'undefined' && typeof enterRoom === 'function'
      && state.currentBuilding === 'assemblee') {
    enterRoom('assemblee', state.currentRoom, null);
  }
  if (typeof updateUI === 'function') updateUI();
  if (typeof seanceRafraichir === 'function') await seanceRafraichir().catch(() => {});
}


// -------------------------------------------------------------------------------------
// STYLES ET PETITS OUTILS
// -------------------------------------------------------------------------------------
function presidenceStyles() {
  if (document.getElementById('rp-presidence-styles')) return;
  const st = document.createElement('style');
  st.id = 'rp-presidence-styles';
  st.textContent = [
    '.pr-cadre{position:fixed;inset:0;z-index:6000;background:rgba(6,5,3,.93);display:flex;',
    '  align-items:center;justify-content:center;padding:1.2rem;font-family:Crimson Pro,serif}',
    '.pr-boite{max-width:34rem;width:100%;border:1px solid #6a5a20;background:#12100a;',
    '  padding:1.5rem;text-align:center;color:#c8b894;box-sizing:border-box}',
    '.pr-titre{font-family:Bebas Neue,sans-serif;letter-spacing:.13em;font-size:1.05rem;',
    '  color:#C9A84C;margin-bottom:.7rem}',
    '.pr-sous{font-size:.84rem;line-height:1.65;color:#a89878}',
    '.pr-elu{font-family:Bebas Neue,sans-serif;letter-spacing:.1em;font-size:1.6rem;',
    '  color:#E8C97A;margin:.9rem 0 .5rem}',
    '.pr-etat{margin-top:1rem;font-size:.86rem;color:#E8C97A;min-height:1.3rem}',
    // LA MAIN : un poing stylise, et les pailles qui en sortent. Dessine, jamais une image.
    '.pr-main{position:relative;margin:1.4rem auto .4rem;width:100%;max-width:26rem;',
    '  display:flex;flex-direction:column-reverse;align-items:center}',
    '.pr-poing{width:7.5rem;height:4.2rem;background:linear-gradient(170deg,#c9a071,#8a6440);',
    '  border:1px solid #6a4a28;border-radius:2.4rem 2.4rem 1.1rem 1.1rem;',
    '  box-shadow:inset 0 .5rem .9rem rgba(255,230,190,.18),inset 0 -.4rem .7rem rgba(0,0,0,.35)}',
    '.pr-pailles{display:flex;align-items:flex-end;justify-content:center;gap:.55rem;',
    '  margin-bottom:-.5rem;z-index:1}',
    '.pr-colonne{display:flex;flex-direction:column;align-items:center;gap:.3rem;',
    '  padding:.25rem .2rem;border:1px solid transparent;border-radius:.2rem}',
    '.pr-brin{width:.42rem;height:6.5rem;border-radius:.22rem .22rem 0 0;',
    '  background:linear-gradient(to bottom,#e8d79a,#bfa469 60%,#9c8244);',
    '  transition:height .55s ease}',
    '.pr-brin.pr-courte{height:2.3rem}',
    '.pr-colonne.pr-vise{border-color:#C9A84C;box-shadow:0 0 .9rem rgba(201,168,76,.75);',
    '  background:rgba(201,168,76,.1)}',
    '.pr-colonne.pr-gagnante{border-color:#E8C97A;background:rgba(232,201,122,.16);',
    '  box-shadow:0 0 1.4rem rgba(232,201,122,.55)}',
    '.pr-nom{font-size:.7rem;color:#9a8a68;max-width:4.6rem;overflow:hidden;',
    '  text-overflow:ellipsis;white-space:nowrap}',
    '.pr-colonne.pr-gagnante .pr-nom{color:#E8C97A}',
    '.pr-bouton{font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;',
    '  padding:.5rem 1.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;',
    '  cursor:pointer}',
    '.pr-bouton.pr-discret{border-color:#4a4228;color:#8a7d5a}',
    '@media (max-width:520px){.pr-brin{height:4.6rem}.pr-nom{max-width:3.2rem;font-size:.64rem}}'
  ].join('');
  document.head.appendChild(st);
}

function presidenceLigne(texte, couleur) {
  const d = document.createElement('div');
  d.className = 'sc-ligne';
  if (couleur) d.style.color = couleur;
  d.textContent = texte;
  return d;
}

function presidenceHeure(iso) {
  if (!iso) return '?';
  try {
    return new Date(iso).toLocaleString('fr-FR',
      { weekday: 'long', hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Paris' });
  } catch (e) { return '?'; }
}
