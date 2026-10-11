// =====================================================================================
// LA SEANCE PARLEMENTAIRE — L'ECRAN (11 octobre 2026)
// =====================================================================================
// CE N'EST PAS UN TCHAT, ET C'ETAIT LE POINT DE L'ARBITRAGE. Un tchat generique aurait
// donne a chacun le meme droit de parler ; une seance parlementaire donne a UN SEUL le
// droit de distribuer la parole, et a tous les autres celui de la demander — ou de la
// prendre quand meme, ce qui est une decision, pas un bug.
//
// L'ECRAN NE DECIDE RIEN. Il affiche ce que `assemblee_seance()` rend, et transmet
// l'intention du joueur. Qui preside, qui est depute, qui est physiquement dans
// l'hemicycle, a quel parti chacun appartient, si une protestation est qualifiee, si la
// seance est suspendue : tout cela est relu en base a chaque appel. Si ce fichier
// mentait, le serveur refuserait.
//
// ET IL NE QUALIFIE RIEN. Une intervention prise sans la parole est marquee « hors tour
// de parole » — un FAIT, lisible par tous — et rien de plus : pas de couleur accusatrice
// inventee, pas de compteur d'incivilites, pas de score. Un motif de rappel est affiche
// VERBATIM, entre guillemets, sans un adjectif ajoute. Les joueurs jugent ; l'ecran
// montre.
// =====================================================================================

const SEANCE_VEILLE_MS = 12000;
const SEANCE_DEBAT_LIMITE = 60;
const SEANCE_MOTIF_MAX = 600;
const SEANCE_INTERVENTION_MAX = 2000;

let RP_SEANCE_ETAT = null;
let RP_SEANCE_VEILLE = null;
// CE QUE LE JOUEUR A COMMENCE A TAPER. Un rafraichissement automatique toutes les douze
// secondes qui effacerait un discours en cours de redaction serait insupportable : le
// brouillon survit a chaque redessin.
let RP_SEANCE_BROUILLON = '';
let RP_SEANCE_FORMULAIRE = null;   // { genre:'rappel'|'sanction'|'suspension', cible }
let RP_SEANCE_PROPOSITIONS = [];

// Les motifs de refus des douze portes de seance, en francais. Le serveur nomme la regle,
// l'ecran la traduit — il ne la reinvente pas.
if (typeof ASSEMBLEE_RAISONS !== 'undefined') {
  Object.assign(ASSEMBLEE_RAISONS, {
    acteur_non_authentifie:       'Votre session a expiré. Reconnectez-vous.',
    pas_le_president:             'Seul le Président de l\'Assemblée dispose de cette prérogative.',
    pas_dans_hemicycle:           'Vous n\'êtes pas dans l\'hémicycle.',
    pas_a_l_assemblee:            'Vous n\'êtes pas à l\'Assemblée nationale.',
    file_vide:                    'Personne ne demande la parole.',
    pas_le_premier_de_la_file:    'La parole revient au premier de la file : vous ne pouvez pas choisir.',
    un_orateur_a_deja_la_parole:  'Un orateur a déjà la parole. Retirez-la d\'abord.',
    aucun_orateur:                'Personne n\'a la parole en ce moment.',
    texte_vide:                   'Votre intervention est vide.',
    motif_obligatoire:            'Le motif est obligatoire.',
    cible_invalide:               'Cette cible n\'est pas valide.',
    cible_pas_deputee:            'Cette personne n\'occupe aucun des neuf sièges.',
    cible_absente_de_l_hemicycle: 'On ne rappelle au règlement qu\'un député physiquement présent dans l\'hémicycle.',
    aucun_rappel_a_consommer:     'Une sanction exige un rappel au règlement préalable, non encore utilisé.',
    debit_impossible:             'Le député n\'a pas les 100 FR de l\'amende. Rien n\'a été appliqué.',
    proposition_inconnue:         'Ce texte n\'existe plus.',
    autre_empire:                 'Ce texte n\'appartient pas à votre Assemblée.',
    pas_en_session:               'Ce texte n\'est pas en session : il n\'a pas encore d\'échéance à repousser.',
    echeance_deja_passee:         'L\'échéance est déjà passée : il n\'y a plus rien à repousser.',
    deja_reporte_une_fois:        'Ce texte a déjà été reporté une fois. La prérogative appartient au texte, pas au Président.'
  });
}


// -------------------------------------------------------------------------------------
// OUVERTURE ET FERMETURE
// -------------------------------------------------------------------------------------
async function ouvrirSeanceParlementaire() {
  if (typeof sbAssembleeSeance !== 'function') {
    if (typeof assembleeIndisponible === 'function') assembleeIndisponible();
    return;
  }
  seanceConstruireCadre();
  document.getElementById('rp-seance').style.display = 'flex';
  await seanceRafraichir();
  seanceDemarrerVeille();
}

function fermerSeanceParlementaire() {
  seanceArreterVeille();
  RP_SEANCE_FORMULAIRE = null;
  const cadre = document.getElementById('rp-seance');
  if (cadre) cadre.style.display = 'none';
}

function seanceDemarrerVeille() {
  seanceArreterVeille();
  RP_SEANCE_VEILLE = setInterval(() => {
    const cadre = document.getElementById('rp-seance');
    if (!cadre || cadre.style.display === 'none') { seanceArreterVeille(); return; }
    seanceRafraichir().catch(() => {});
  }, SEANCE_VEILLE_MS);
}

function seanceArreterVeille() {
  if (RP_SEANCE_VEILLE) { clearInterval(RP_SEANCE_VEILLE); RP_SEANCE_VEILLE = null; }
}

async function seanceRafraichir() {
  const etat = await sbAssembleeSeance(SEANCE_DEBAT_LIMITE);
  if (!etat || etat.ok !== true) {
    seanceDessinerPanne(etat);
    return;
  }
  RP_SEANCE_ETAT = etat;
  // L'ELECTION DU PRESIDENT EST UN MOMENT DE LA SEANCE, pas un ecran a part : son etat se
  // charge avec elle, et le bloc de scrutin s'affiche dans le meme panneau.
  if (typeof presidenceRafraichir === 'function') await presidenceRafraichir().catch(() => {});
  // Les textes en session servent au report presidentiel. Lecture REST, autorisee par la
  // policy SELECT historique de assemblee_propositions.
  if (etat.je_suis_le_president && typeof sbGetAssembleePropositions === 'function') {
    RP_SEANCE_PROPOSITIONS = await sbGetAssembleePropositions(etat.pays, ['session']).catch(() => []) || [];
  } else {
    RP_SEANCE_PROPOSITIONS = [];
  }
  seanceDessiner(etat);
}


// -------------------------------------------------------------------------------------
// LE CADRE
// -------------------------------------------------------------------------------------
function seanceConstruireCadre() {
  if (document.getElementById('rp-seance')) return;

  if (!document.getElementById('rp-seance-styles')) {
    const st = document.createElement('style');
    st.id = 'rp-seance-styles';
    st.textContent = [
      '#rp-seance{position:fixed;inset:0;z-index:5000;background:#0a0906;display:none;',
      '  flex-direction:column;font-family:Crimson Pro,serif;color:#c8b894}',
      '#rp-seance .sc-haut{display:flex;align-items:baseline;gap:1rem;flex-wrap:wrap;',
      '  padding:.9rem 1.2rem;border-bottom:1px solid #3a2f14;background:#120f08}',
      '#rp-seance .sc-titre{font-family:Bebas Neue,sans-serif;letter-spacing:.14em;',
      '  font-size:1.15rem;color:#C9A84C}',
      '#rp-seance .sc-sous{font-size:.8rem;color:#8a7d5a}',
      '#rp-seance .sc-fermer{margin-left:auto;font-family:Bebas Neue,sans-serif;font-size:.78rem;',
      '  letter-spacing:.1em;padding:.4rem 1rem;border:1px solid #6a5a20;background:transparent;',
      '  color:#C9A84C;cursor:pointer}',
      '#rp-seance .sc-alerte{padding:.6rem 1.2rem;background:#2a1408;border-bottom:1px solid #6a3a10;',
      '  color:#d8a060;font-size:.84rem}',
      '#rp-seance .sc-corps{flex:1;display:flex;min-height:0}',
      '#rp-seance .sc-cote{width:19rem;flex-shrink:0;overflow-y:auto;padding:1rem;',
      '  border-right:1px solid #2a2210;background:#0d0b06}',
      '#rp-seance .sc-centre{flex:1;display:flex;flex-direction:column;min-width:0}',
      '#rp-seance .sc-debat{flex:1;overflow-y:auto;padding:1rem 1.2rem}',
      '#rp-seance .sc-bas{border-top:1px solid #2a2210;padding:.8rem 1.2rem;background:#100d07}',
      '#rp-seance h3{font-family:Bebas Neue,sans-serif;letter-spacing:.12em;font-size:.82rem;',
      '  color:#8a7d4a;margin:1.1rem 0 .45rem;text-transform:uppercase}',
      '#rp-seance h3:first-child{margin-top:0}',
      '#rp-seance .sc-ligne{font-size:.82rem;line-height:1.5;padding:.18rem 0}',
      '#rp-seance .sc-vide{font-size:.78rem;color:#6a6048;font-style:italic}',
      '#rp-seance .sc-dit{margin-bottom:.9rem;padding-left:.7rem;border-left:2px solid #3a3018}',
      '#rp-seance .sc-dit.sc-hors{border-left-color:#8a5a20}',
      '#rp-seance .sc-qui{font-family:Bebas Neue,sans-serif;letter-spacing:.08em;font-size:.82rem;',
      '  color:#E8C97A}',
      '#rp-seance .sc-quand{font-size:.7rem;color:#5f5740;margin-left:.5rem}',
      '#rp-seance .sc-marque{font-size:.7rem;color:#c08040;margin-left:.5rem;font-style:italic}',
      '#rp-seance .sc-texte{font-size:.9rem;line-height:1.65;white-space:pre-wrap;color:#cdbf9e}',
      '#rp-seance textarea,#rp-seance input[type=text]{width:100%;box-sizing:border-box;',
      '  background:#0a0804;border:1px solid #3a3018;color:#d8cba8;padding:.5rem;',
      '  font-family:Crimson Pro,serif;font-size:.88rem;resize:vertical}',
      '#rp-seance button.sc-b{font-family:Bebas Neue,sans-serif;font-size:.74rem;letter-spacing:.09em;',
      '  padding:.42rem .9rem;border:1px solid #6a5a20;background:transparent;color:#C9A84C;',
      '  cursor:pointer;margin:.2rem .3rem .2rem 0}',
      '#rp-seance button.sc-b:disabled{opacity:.38;cursor:default}',
      '#rp-seance button.sc-b.sc-dur{border-color:#8a3a2a;color:#d08070}',
      '#rp-seance .sc-boite{border:1px solid #4a3a18;background:#140f06;padding:.8rem;margin:.6rem 0}',
      '@media (max-width:760px){#rp-seance .sc-corps{flex-direction:column}',
      '  #rp-seance .sc-cote{width:auto;border-right:none;border-bottom:1px solid #2a2210;max-height:40%}}'
    ].join('');
    document.head.appendChild(st);
  }

  const cadre = document.createElement('div');
  cadre.id = 'rp-seance';
  cadre.innerHTML = '<div class="sc-haut">'
    + '<span class="sc-titre">Séance parlementaire</span>'
    + '<span class="sc-sous" id="sc-presidence"></span>'
    + '<button class="sc-fermer" id="sc-fermer">Quitter l\'écran</button>'
    + '</div>'
    + '<div id="sc-alerte"></div>'
    + '<div class="sc-corps">'
    + '  <div class="sc-cote" id="sc-cote"></div>'
    + '  <div class="sc-centre">'
    + '    <div class="sc-debat" id="sc-debat"></div>'
    + '    <div class="sc-bas" id="sc-bas"></div>'
    + '  </div>'
    + '</div>';
  document.body.appendChild(cadre);
  document.getElementById('sc-fermer').addEventListener('click', fermerSeanceParlementaire);
}

function seanceDessinerPanne(etat) {
  const d = document.getElementById('sc-debat');
  if (!d) return;
  d.textContent = '';
  const p = document.createElement('div');
  p.className = 'sc-vide';
  p.textContent = (etat && etat.raison === 'acteur_non_authentifie')
    ? 'Votre session a expiré : reconnectez-vous pour suivre la séance.'
    : 'La séance est injoignable pour le moment. Rien n\'a été modifié.';
  d.appendChild(p);
}


// -------------------------------------------------------------------------------------
// LE DESSIN
// -------------------------------------------------------------------------------------
function seanceDessiner(e) {
  const moi = (typeof state !== 'undefined' && state.char && state.char.name) || '';

  // --- bandeau de presidence
  const pres = document.getElementById('sc-presidence');
  pres.textContent = e.president
    ? ('Préside : ' + e.president + (e.je_suis_le_president ? ' (vous)' : ''))
    : 'Aucun Président de l\'Assemblée n\'est en fonction.';

  // --- alerte de suspension. UN FAIT, PAS UN JUGEMENT : on dit combien de deputes
  // qualifies sont dehors et quel est le seuil, sans qualifier leur depart.
  // --- alerte de suspension. DEUX SUSPENSIONS DISTINCTES, ET ELLES NE DISENT PAS LA MEME
  // CHOSE : le boycott empeche un vote de conclure, la suspension presidentielle arrete la
  // seance elle-meme. Quand les deux courent, on annonce les deux.
  const al = document.getElementById('sc-alerte');
  al.textContent = '';
  al.className = '';
  const alertes = [];
  if (e.suspendue_par_la_presidence) {
    const sp = e.suspension_presidence || {};
    alertes.push('SÉANCE SUSPENDUE PAR LA PRÉSIDENCE'
      + (sp.president ? ' (' + sp.president + ')' : '')
      + (sp.motif ? ' — « ' + sp.motif + ' »' : '')
      + '. Elle le reste jusqu\'à ce que le Président la reprenne : on n\'y prend pas la parole.');
  }
  if (e.suspendue) {
    alertes.push('SÉANCE SUSPENDUE PAR BOYCOTT — ' + (e.protestataires_qualifies || 0)
      + ' députés protestataires sont hors de l\'hémicycle (seuil : ' + (e.seuil_suspension || 5)
      + '). Aucun vote ne peut être conclu tant que la suspension dure.');
  }
  if (e.election_presidentielle_due) {
    alertes.push('La présidence est remise en jeu : une élection est due et sera convoquée lundi.');
  }
  if (alertes.length) {
    al.className = 'sc-alerte';
    al.textContent = alertes.join(' · ');
  }

  seanceDessinerCote(e, moi);
  seanceDessinerDebat(e);
  seanceDessinerBas(e, moi);
}

function seanceDessinerCote(e, moi) {
  const c = document.getElementById('sc-cote');
  c.textContent = '';

  // --- L'ORATEUR
  c.appendChild(seanceTitre('La parole'));
  if (e.orateur) {
    c.appendChild(seanceLigne(e.orateur + (e.orateur === moi ? ' (vous)' : '') + ' a la parole.',
      '#E8C97A'));
  } else {
    c.appendChild(seanceVide('Personne n\'a la parole.'));
  }

  // --- LA FILE, DANS SON ORDRE EXACT. Le President doit donner la parole au premier :
  // la numerotation n'est pas un ornement, c'est la regle rendue visible.
  c.appendChild(seanceTitre('File des demandes'));
  const file = Array.isArray(e.file) ? e.file : [];
  if (!file.length) {
    c.appendChild(seanceVide('Aucune demande de parole.'));
  } else {
    file.forEach((f, i) => {
      c.appendChild(seanceLigne((i + 1) + '. ' + f.depute + (f.depute === moi ? ' (vous)' : ''),
        i === 0 ? '#E8C97A' : null));
    });
  }

  // --- LES DEPUTES ET LEUR PRESENCE
  c.appendChild(seanceTitre('Les neuf sièges — députés joueurs'));
  const deps = Array.isArray(e.deputes) ? e.deputes : [];
  if (!deps.length) {
    c.appendChild(seanceVide('Aucun siège n\'est tenu par un joueur : les neuf sièges sont occupés par leurs suppléants PNJ.'));
  } else {
    deps.forEach(d => {
      c.appendChild(seanceLigne(d.depute + ' — ' + (d.ville || '?')
        + (d.dans_hemicycle ? ' · présent' : ' · absent de l\'hémicycle')
        + (d.parti ? ' · ' + d.parti : ''),
        d.dans_hemicycle ? null : '#8a7d5a'));
    });
  }

  // --- LES SORTIS. `qualifie` est calcule par le serveur ; l'ecran le RAPPORTE.
  const dehors = Array.isArray(e.dehors) ? e.dehors : [];
  if (dehors.length) {
    c.appendChild(seanceTitre('Hors de l\'hémicycle'));
    dehors.forEach(d => {
      const motif = d.motif === 'soi_meme' ? 'a subi un acte de discipline'
                  : d.motif === 'parti'    ? 'solidarité de parti'
                  : null;
      c.appendChild(seanceLigne(d.depute + (d.qualifie
        ? ' — protestation qualifiée (' + motif + ')'
        : ' — sortie non qualifiée'),
        d.qualifie ? '#d08070' : '#8a7d5a'));
    });
    c.appendChild(seanceLigne((e.protestataires_qualifies || 0) + ' protestataire(s) qualifié(s) sur '
      + (e.seuil_suspension || 5) + ' nécessaires pour suspendre la séance.', '#8a7d5a'));
  }

  // --- LE COMPTEUR D'EPISODES. UN FAIT, ET RIEN DE PLUS : rien ne se declenche a deux,
  // parce que l'election du President n'est pas encore arbitree. On ne fait pas semblant.
  if (typeof e.episodes_sous_cette_presidence === 'number' && e.episodes_sous_cette_presidence > 0) {
    c.appendChild(seanceTitre('Suspensions par boycott'));
    c.appendChild(seanceLigne(e.episodes_sous_cette_presidence
      + ' épisode(s) sous la présidence en cours.', '#8a7d5a'));
  }
}

function seanceDessinerDebat(e) {
  const d = document.getElementById('sc-debat');
  const colle = (d.scrollHeight - d.scrollTop - d.clientHeight) < 60;
  d.textContent = '';

  const dits = Array.isArray(e.debat) ? e.debat : [];
  if (!dits.length) {
    d.appendChild(seanceVide('La séance n\'a encore rien entendu.'));
    return;
  }
  dits.forEach(x => {
    const bloc = document.createElement('div');
    bloc.className = 'sc-dit' + (x.autorise ? '' : ' sc-hors');

    const tete = document.createElement('div');
    const qui = document.createElement('span');
    qui.className = 'sc-qui';
    // textContent : un nom de joueur n'est jamais interprete.
    qui.textContent = x.auteur + (x.fonction === 'president_assemblee' ? ', Président' : '');
    tete.appendChild(qui);

    const quand = document.createElement('span');
    quand.className = 'sc-quand';
    quand.textContent = seanceHeure(x.dit_le);
    tete.appendChild(quand);

    // LA MARQUE EST FACTUELLE. « hors tour de parole » dit ce qui s'est passe : il a parle
    // sans que la parole lui ait ete donnee. Ce n'est ni un reproche, ni une sanction, et
    // le serveur n'en tire rigoureusement rien.
    if (!x.autorise && x.fonction !== 'president_assemblee') {
      const m = document.createElement('span');
      m.className = 'sc-marque';
      m.textContent = '— hors tour de parole';
      tete.appendChild(m);
    }
    bloc.appendChild(tete);

    const txt = document.createElement('div');
    txt.className = 'sc-texte';
    txt.textContent = x.texte || '';
    bloc.appendChild(txt);

    d.appendChild(bloc);
  });
  if (colle) d.scrollTop = d.scrollHeight;
}

function seanceDessinerBas(e, moi) {
  const b = document.getElementById('sc-bas');
  b.textContent = '';

  // --- UN FORMULAIRE OUVERT PREND TOUTE LA PLACE : on ne saisit pas un motif de rappel
  // en meme temps qu'un discours.
  if (RP_SEANCE_FORMULAIRE) { seanceDessinerFormulaire(b, e); return; }

  // UNE SEANCE SUSPENDUE PAR SA PRESIDENCE NE DISTRIBUE PAS LA PAROLE -- pas meme au
  // President, qui a « Reprendre la séance » pour la rouvrir. Le serveur refuse de toute
  // facon ; l'ecran ne propose donc pas un bouton qui serait refuse.
  const jeParle = !e.suspendue_par_la_presidence
    && (e.je_suis_le_president || (e.je_suis_depute && e.je_suis_dans_hemicycle));

  // --- LA ZONE D'INTERVENTION
  if (jeParle) {
    const aLaParole = e.je_suis_le_president || e.orateur === moi;
    const zone = document.createElement('textarea');
    zone.id = 'sc-intervention';
    zone.rows = 3;
    zone.maxLength = SEANCE_INTERVENTION_MAX;
    zone.placeholder = aLaParole
      ? 'Votre intervention…'
      : 'Vous n\'avez pas la parole. Ce que vous direz sera enregistré comme une intervention hors tour de parole.';
    zone.value = RP_SEANCE_BROUILLON;
    zone.addEventListener('input', () => { RP_SEANCE_BROUILLON = zone.value; });
    b.appendChild(zone);

    const ligne = document.createElement('div');
    ligne.style.cssText = 'margin-top:.5rem;display:flex;flex-wrap:wrap;align-items:center';
    ligne.appendChild(seanceBouton(aLaParole ? 'Intervenir' : 'Parler sans la parole',
      seanceDire, false, !aLaParole));
    if (!e.je_suis_le_president) {
      const dejaDansLaFile = (Array.isArray(e.file) ? e.file : []).some(f => f.depute === moi);
      ligne.appendChild(seanceBouton(
        dejaDansLaFile ? 'Parole demandée' : 'Demander la parole',
        seanceDemanderParole, dejaDansLaFile || e.orateur === moi));
      ligne.appendChild(seanceBouton('Quitter l\'hémicycle en signe de protestation',
        seanceProtester, false, true));
    }
    b.appendChild(ligne);
  } else if (e.je_suis_depute && !e.je_suis_dans_hemicycle) {
    const info = document.createElement('div');
    info.className = 'sc-ligne';
    info.textContent = 'Vous êtes hors de l\'hémicycle : vous ne pouvez pas y prendre la parole.';
    b.appendChild(info);
    const ligne = document.createElement('div');
    ligne.style.cssText = 'margin-top:.5rem';
    ligne.appendChild(seanceBouton('Revenir dans l\'hémicycle', seanceRevenir));
    b.appendChild(ligne);
  } else {
    b.appendChild(seanceVide('Vous assistez à la séance. Seuls les députés et le Président y prennent la parole.'));
  }

  // --- L'ELECTION DU PRESIDENT. Rendue dans le meme panneau : elle appartient a la seance.
  if (typeof presidenceDessinerBloc === 'function') presidenceDessinerBloc(b);

  // --- LES PREROGATIVES DU PRESIDENT
  if (e.je_suis_le_president) {
    const boite = document.createElement('div');
    boite.className = 'sc-boite';
    const t = document.createElement('div');
    t.style.cssText = 'font-family:Bebas Neue,sans-serif;letter-spacing:.11em;font-size:.78rem;color:#8a7d4a;margin-bottom:.4rem';
    t.textContent = 'PRÉROGATIVES DE LA PRÉSIDENCE';
    boite.appendChild(t);

    // SUSPENDRE OU REPRENDRE, JAMAIS LES DEUX. L'etat est serveur : c'est lui qui decide
    // lequel des deux boutons existe.
    if (e.suspendue_par_la_presidence) {
      boite.appendChild(seanceBouton('Reprendre la séance', seanceReprendre));
      boite.appendChild(seanceVide('La séance est suspendue. La reprendre ne coûte rien : '
        + 'vous avez déjà payé pour la suspendre.'));
      b.appendChild(boite);
      return;   // une seance suspendue n'a ni file, ni orateur, ni discipline a exercer
    }

    const premier = (Array.isArray(e.file) && e.file.length) ? e.file[0].depute : null;
    boite.appendChild(seanceBouton(
      premier ? ('Donner la parole à ' + premier) : 'Donner la parole',
      seanceDonnerParole, !premier || !!e.orateur));
    boite.appendChild(seanceBouton('Retirer la parole', seanceRetirerParole, !e.orateur));

    const presents = (Array.isArray(e.deputes) ? e.deputes : []).filter(d => d.dans_hemicycle);
    boite.appendChild(seanceBouton('Rappeler au règlement',
      () => seanceOuvrirFormulaire('rappel'), !presents.length, true));

    const consommables = Array.isArray(e.rappels_consommables) ? e.rappels_consommables : [];
    boite.appendChild(seanceBouton('Sanctionner',
      () => seanceOuvrirFormulaire('sanction'), !consommables.length, true));

    boite.appendChild(seanceBouton('Suspendre la séance',
      () => seanceOuvrirFormulaire('suspension'), false, true));

    const reportables = RP_SEANCE_PROPOSITIONS.filter(
      p => (Array.isArray(e.textes_reportes) ? e.textes_reportes : []).indexOf(p.id) === -1);
    boite.appendChild(seanceBouton('Reporter un vote',
      () => seanceOuvrirFormulaire('report'), !reportables.length));

    if (!consommables.length) {
      boite.appendChild(seanceVide('Une sanction exige un rappel au règlement préalable, non encore utilisé.'));
    } else {
      boite.appendChild(seanceVide('Rappels utilisables pour une sanction : ' + consommables.join(', ') + '.'));
    }
    b.appendChild(boite);
  }
}

function seanceDessinerFormulaire(b, e) {
  const f = RP_SEANCE_FORMULAIRE;
  const boite = document.createElement('div');
  boite.className = 'sc-boite';

  const titres = {
    rappel:     'RAPPEL AU RÈGLEMENT',
    sanction:   'SANCTION',
    suspension: 'SUSPENSION DE LA SÉANCE',
    report:     'REPORT D\'UN VOTE'
  };
  const t = document.createElement('div');
  t.style.cssText = 'font-family:Bebas Neue,sans-serif;letter-spacing:.11em;font-size:.82rem;color:#C9A84C;margin-bottom:.5rem';
  t.textContent = titres[f.genre] || '';
  boite.appendChild(boite.appendChild(t) && document.createElement('div'));

  // --- CE QUE L'ACTE COUTE, DIT AVANT LE CLIC. Le joueur ne doit pas decouvrir le prix
  // apres coup : les trois chiffres sont ceux du serveur, ecrits une seule fois ici.
  const prix = {
    rappel:     'Le député perd 15 points de popularité. Le motif est obligatoire, public, et conservé mot pour mot.',
    sanction:   'Le député perd 20 points de popularité et 100 FR, versés à la caisse de l\'Assemblée. Le rappel au règlement qui la rend possible est consommé : il ne pourra plus servir.',
    suspension: 'Vous perdez 20 points de popularité. Cette suspension n\'est pas un boycott et ne compte jamais parmi ceux qui remettraient la présidence en jeu.',
    report:     'L\'échéance du scrutin est repoussée d\'une semaine. Une seule fois par texte : la prérogative appartient au texte, pas au Président.'
  };
  const p = document.createElement('div');
  p.className = 'sc-ligne';
  p.style.color = '#8a7d5a';
  p.textContent = prix[f.genre] || '';
  boite.appendChild(p);

  // --- LA CIBLE
  let choix = null;
  if (f.genre === 'rappel' || f.genre === 'sanction' || f.genre === 'report') {
    choix = document.createElement('select');
    choix.id = 'sc-cible';
    choix.style.cssText = 'width:100%;box-sizing:border-box;margin:.5rem 0;padding:.45rem;'
      + 'background:#0a0804;border:1px solid #3a3018;color:#d8cba8;font-family:Crimson Pro,serif';
    let options = [];
    if (f.genre === 'rappel') {
      options = (Array.isArray(e.deputes) ? e.deputes : [])
        .filter(d => d.dans_hemicycle)
        .map(d => [d.depute, d.depute + ' (' + (d.ville || '?') + ')']);
    } else if (f.genre === 'sanction') {
      options = (Array.isArray(e.rappels_consommables) ? e.rappels_consommables : [])
        .map(n => [n, n]);
    } else {
      options = RP_SEANCE_PROPOSITIONS
        .filter(x => (Array.isArray(e.textes_reportes) ? e.textes_reportes : []).indexOf(x.id) === -1)
        .map(x => [x.id, x.titre + ' — clôture ' + (typeof assembleeFormaterEcheance === 'function'
          ? assembleeFormaterEcheance(x.cloture_ts) : (x.cloture_ts || '?'))]);
    }
    options.forEach(([v, l]) => {
      const o = document.createElement('option');
      o.value = v; o.textContent = l;      // textContent : un titre de loi est du texte joueur
      choix.appendChild(o);
    });
    boite.appendChild(choix);
  }

  // --- LE MOTIF. Obligatoire pour un rappel et une sanction ; facultatif pour une
  // suspension. LE SERVEUR NE LE JUGE PAS, et l'ecran ne le relit pas davantage : il ne
  // verifie que l'absence, parce que l'arbitrage l'exige.
  if (f.genre !== 'report') {
    const m = document.createElement('textarea');
    m.id = 'sc-motif';
    m.rows = 3;
    m.maxLength = SEANCE_MOTIF_MAX;
    m.placeholder = f.genre === 'suspension'
      ? 'Motif (facultatif). Il sera conservé tel quel, sans être interprété.'
      : 'Motif (obligatoire). Il sera public, conservé mot pour mot, et transmis tel quel à la presse.';
    boite.appendChild(m);
  }

  const actions = document.createElement('div');
  actions.style.cssText = 'margin-top:.6rem';
  const libelles = { rappel: 'Rappeler au règlement', sanction: 'Sanctionner',
                     suspension: 'Suspendre la séance', report: 'Reporter ce vote' };
  actions.appendChild(seanceBouton(libelles[f.genre], seanceConfirmerFormulaire, false,
    f.genre !== 'report'));
  actions.appendChild(seanceBouton('Annuler', () => {
    RP_SEANCE_FORMULAIRE = null;
    if (RP_SEANCE_ETAT) seanceDessiner(RP_SEANCE_ETAT);
  }));
  boite.appendChild(actions);

  b.appendChild(boite);
}

function seanceOuvrirFormulaire(genre) {
  RP_SEANCE_FORMULAIRE = { genre };
  if (RP_SEANCE_ETAT) seanceDessiner(RP_SEANCE_ETAT);
}


// -------------------------------------------------------------------------------------
// LES ACTIONS — TOUTES PAR LE SOCLE EXISTANT
// -------------------------------------------------------------------------------------
// assembleeActionServeur() serialise les clics, rejoue une reponse perdue avec le MEME
// identifiant de requete, et recopie l'etat renvoye. Les cinq portes a effet reconnaissent
// cet identifiant : un rejeu renvoie l'acte deja enregistre au lieu d'en creer un second.
async function seanceDemanderParole() {
  const r = await assembleeActionServeur(() => sbAssembleeParoleDemander());
  if (!assembleeIssueAction(r)) return;
  if (r.res.deja_demande !== true) {
    showToast('Parole demandée', 'Vous êtes ' + (r.res.rang || '?') + (r.res.rang === 1 ? 'er' : 'e')
      + ' dans la file. Le Président doit donner la parole au premier.', true);
  }
  await seanceRafraichir();
}

async function seanceDonnerParole() {
  const premier = (RP_SEANCE_ETAT && Array.isArray(RP_SEANCE_ETAT.file) && RP_SEANCE_ETAT.file.length)
    ? RP_SEANCE_ETAT.file[0].depute : null;
  if (!premier) return;
  const r = await assembleeActionServeur(() => sbAssembleeParoleDonner(premier));
  if (!assembleeIssueAction(r)) { await seanceRafraichir(); return; }
  showToast('Parole donnée', r.res.orateur + ' a la parole.', true);
  await seanceRafraichir();
}

async function seanceRetirerParole() {
  const r = await assembleeActionServeur(() => sbAssembleeParoleRetirer());
  if (!assembleeIssueAction(r)) { await seanceRafraichir(); return; }
  // IL REPARTIRA EN FIN DE FILE S'IL REDEMANDE : c'est la regle, elle est dite.
  showToast('Parole retirée', 'La parole est retirée à ' + r.res.retire
    + '. S\'il la redemande, il reprendra place en fin de file.', true);
  await seanceRafraichir();
}

async function seanceDire() {
  const zone = document.getElementById('sc-intervention');
  const texte = (zone && zone.value || '').trim();
  if (!texte) { showToast('Rien à dire', 'Votre intervention est vide.', false); return; }

  const r = await assembleeActionServeur((requete) => sbAssembleeDire(texte, requete));
  if (!assembleeIssueAction(r)) return;
  RP_SEANCE_BROUILLON = '';
  if (zone) zone.value = '';
  // LE SERVEUR DIT SI L'INTERVENTION ETAIT AUTORISEE. L'ecran le repete, sans y ajouter de
  // reproche : le President fera ce qu'il veut de l'information, ou rien.
  if (r.res.autorise === false) {
    showToast('Intervention enregistrée',
      'Vous avez parlé sans avoir la parole. Votre intervention figure au débat, identifiée comme telle.',
      true);
    addJournalEntry('Intervention hors tour de parole à l\'Assemblée.', '');
  }
  await seanceRafraichir();
}

async function seanceProtester() {
  const r = await assembleeActionServeur(() => sbAssembleeProtester());
  if (!assembleeIssueAction(r)) return;
  const res = r.res;
  if (res.qualifie) {
    showToast('Vous quittez l\'hémicycle',
      'Protestation qualifiée (' + (res.motif === 'parti' ? 'solidarité de parti' : 'acte de discipline subi')
      + '). Vous êtes dans le hall de l\'Assemblée.', true);
  } else {
    // ON NE LE CACHE PAS : sortir sans motif qualifiant est permis, mais ne compte pas.
    showToast('Vous quittez l\'hémicycle',
      'Votre sortie est enregistrée, mais elle n\'est pas qualifiée : elle ne compte pas dans le seuil de suspension.',
      true);
  }
  addJournalEntry('Vous quittez l\'hémicycle en signe de protestation.', '');
  seanceNaviguerVers(res.piece || 'accueil_assemblee');
  await seanceRafraichir();
}

async function seanceRevenir() {
  const r = await assembleeActionServeur(() => sbAssembleeRevenir());
  if (!assembleeIssueAction(r)) return;
  showToast('Retour dans l\'hémicycle', 'Votre protestation est annulée.', true);
  addJournalEntry('Vous regagnez l\'hémicycle.', '');
  seanceNaviguerVers(r.res.piece || 'hemicycle');
  await seanceRafraichir();
}

// LE DEPLACEMENT EST DEJA FAIT EN BASE : l'ecran le CONSTATE. Meme patron que
// camionNaviguerVers — on recopie la position serveur, puis on passe par enterRoom pour
// que le socle generique fasse son travail (crochet d'entree de zone, liste des presents,
// ordres de la piece).
function seanceNaviguerVers(piece) {
  if (typeof state === 'undefined') return;
  state.currentRoom = piece;
  if (typeof enterRoom === 'function') enterRoom('assemblee', piece, null);
  if (typeof updateUI === 'function') updateUI();
}

// REPRENDRE LA SEANCE. Le President seul, et sans cout : il a paye pour suspendre.
async function seanceReprendre() {
  const r = await assembleeActionServeur((rq) => sbAssembleeReprendreSeance(rq));
  if (!assembleeIssueAction(r)) { await seanceRafraichir(); return; }
  if (r.res.rejeu !== true) {
    showToast('Séance reprise', 'La séance reprend. La parole peut être demandée de nouveau.', true);
    addJournalEntry('Vous reprenez la séance.', '');
  }
  await seanceRafraichir();
  if (typeof updateUI === 'function') updateUI();
}

async function seanceConfirmerFormulaire() {
  const f = RP_SEANCE_FORMULAIRE;
  if (!f) return;
  const cible = (document.getElementById('sc-cible') || {}).value || null;
  const motifBrut = (document.getElementById('sc-motif') || {}).value || '';
  const motif = motifBrut.trim();

  // LE MOTIF EST EXIGE ICI AUSSI, pour ne pas faire perdre un aller-retour au joueur. Le
  // serveur le reexige de toute facon : cette verification est une politesse, pas la regle.
  if ((f.genre === 'rappel' || f.genre === 'sanction') && !motif) {
    showToast('Motif obligatoire', 'Un rappel et une sanction exigent un motif. Il sera public.', false);
    return;
  }

  let r = null;
  if (f.genre === 'rappel') {
    r = await assembleeActionServeur((rq) => sbAssembleeRappeler(cible, motif, rq));
  } else if (f.genre === 'sanction') {
    r = await assembleeActionServeur((rq) => sbAssembleeSanctionner(cible, motif, rq));
  } else if (f.genre === 'suspension') {
    r = await assembleeActionServeur((rq) => sbAssembleeSuspendreSeance(motif || null, rq));
  } else if (f.genre === 'report') {
    r = await assembleeActionServeur((rq) => sbAssembleeReporterVote(cible, rq));
  }
  if (!r || !assembleeIssueAction(r)) { await seanceRafraichir(); return; }

  const res = r.res;
  if (f.genre === 'rappel') {
    showToast('Rappel au règlement', cible + ' est rappelé au règlement. −15 points de popularité.', true);
    addJournalEntry('Vous rappelez ' + cible + ' au règlement.', '');
  } else if (f.genre === 'sanction') {
    showToast('Sanction', cible + ' est sanctionné : −20 points de popularité et 100 FR versés à la caisse de l\'Assemblée.', true);
    addJournalEntry('Vous sanctionnez ' + cible + '.', '');
  } else if (f.genre === 'suspension') {
    showToast('Séance suspendue', 'Vous suspendez la séance. −20 points de popularité.', true);
    addJournalEntry('Vous suspendez la séance.', '');
  } else {
    showToast('Vote reporté', 'L\'échéance passe au '
      + (typeof assembleeFormaterEcheance === 'function'
          ? assembleeFormaterEcheance(res.nouvelle_cloture) : String(res.nouvelle_cloture)) + '.', true);
    addJournalEntry('Vous reportez un vote d\'une semaine.', '');
  }

  RP_SEANCE_FORMULAIRE = null;
  await seanceRafraichir();
  if (typeof updateUI === 'function') updateUI();
}


// -------------------------------------------------------------------------------------
// PETITS OUTILS D'AFFICHAGE
// -------------------------------------------------------------------------------------
function seanceTitre(texte) {
  const h = document.createElement('h3');
  h.textContent = texte;
  return h;
}

function seanceLigne(texte, couleur) {
  const d = document.createElement('div');
  d.className = 'sc-ligne';
  if (couleur) d.style.color = couleur;
  d.textContent = texte;           // textContent : noms et motifs sont du texte joueur
  return d;
}

function seanceVide(texte) {
  const d = document.createElement('div');
  d.className = 'sc-vide';
  d.textContent = texte;
  return d;
}

function seanceBouton(libelle, action, desactive, dur) {
  const b = document.createElement('button');
  b.className = 'sc-b' + (dur ? ' sc-dur' : '');
  b.textContent = libelle;
  if (desactive) b.disabled = true;
  else b.addEventListener('click', () => { Promise.resolve(action()).catch(() => {}); });
  return b;
}

function seanceHeure(iso) {
  if (!iso) return '';
  try {
    return new Date(iso).toLocaleTimeString('fr-FR',
      { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Paris' });
  } catch (e) { return ''; }
}
