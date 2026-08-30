function genererStatsHtml() {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const char = state.char;
  const ar = ARCHETYPES.find(x => x.id === char?.archetype);

  const stats = [
    { label: 'Influence',   val: state.inf  || 0, max: 100, col: '#4a6aaa', icon: 'ti-crown',       desc: 'Poids politique et réseau' },
    { label: 'Popularité',  val: state.pop  || 0, max: 100, col: '#aa6a4a', icon: 'ti-speakerphone', desc: 'Soutien de la population' },
    { label: 'Discrétion',  val: state.dis  || 0, max: 100, col: '#8a4aaa', icon: 'ti-eye-off',      desc: 'Capacité à agir sans être détecté' },
    { label: 'Santé',       val: state.hp   || 0, max: 100, col: '#aa4a4a', icon: 'ti-heart',        desc: 'État physique' },
    { label: 'Moral',       val: state.moral|| 0, max: 100, col: '#6a8aaa', icon: 'ti-brain',        desc: 'Résistance psychologique' },
  ];

  const persoStats = char?.stats || {};
  const STAT_DEFS_LOCAL = [
    { k:'INT', n:'Intelligence', col:'#6a8aaa', i:'ti-brain' },
    { k:'CHA', n:'Charisme',     col:'#aa8a4a', i:'ti-speakerphone' },
    { k:'VOL', n:'Volonté',      col:'#4a8a6a', i:'ti-flame' },
    { k:'PER', n:'Perception',   col:'#4a6aaa', i:'ti-eye' },
    { k:'DUP', n:'Duplicité',    col:'#8a4a8a', i:'ti-masks-theater' },
    { k:'ENT', n:'Entregent',    col:'#8a6a4a', i:'ti-network' },
  ];

  const barsHtml = stats.map(s => {
    const pct = Math.round(s.val);
    return '<div style="margin-bottom:.5rem">' +
      '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.2rem">' +
        '<div style="display:flex;align-items:center;gap:.4rem">' +
          '<i class="ti ' + s.icon + '" style="font-size:1rem;color:' + s.col + '"></i>' +
          '<span style="font-family:Bebas Neue,sans-serif;font-size:.95rem;letter-spacing:.08em;color:#a09060">' + s.label + '</span>' +
        '</div>' +
        '<span style="font-family:Bebas Neue,sans-serif;font-size:1.05rem;color:' + s.col + '">' + pct + '</span>' +
      '</div>' +
      '<div style="height:4px;background:#1a1810;border-radius:2px">' +
        '<div style="height:100%;width:' + pct + '%;background:' + s.col + ';border-radius:2px;transition:width .3s"></div>' +
      '</div>' +
      '<div style="font-size:.8rem;color:#9a8a68;margin-top:.1rem">' + s.desc + '</div>' +
    '</div>';
  }).join('');

  const persoHtml = STAT_DEFS_LOCAL.map(s => {
    const val = persoStats[s.k] || 0;
    return '<div style="text-align:center">' +
      '<div style="font-size:.82rem;color:' + s.col + ';font-family:Bebas Neue,sans-serif;letter-spacing:.06em">' + s.k + '</div>' +
      '<div style="font-size:1rem;color:#f0ead6;font-family:Bebas Neue,sans-serif">' + val + '</div>' +
      '<div style="font-size:.78rem;color:#9a8a68">' + s.n + '</div>' +
    '</div>';
  }).join('');

  // Reliquat de création (bêta) : distribution point par point, définitive, sans coût en PA
  // -- même plafond (16) et même barème de coût (2 au-delà de 12) que la création elle-même,
  // puisque ce sont littéralement les mêmes points, seulement dépensés plus tard. Les niveaux
  // 17-20 restent réservés à une future mécanique de progression en jeu (non construite ici).
  const freePts = char?.freePtsRestants || 0;
  const reliquatHtml = freePts > 0
    ? '<div style="border-top:1px solid #2a2010;margin:.6rem 0"></div>' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.15em;color:#C9A84C;margin-bottom:.3rem">POINTS NON DISTRIBUÉS : ' + freePts + '</div>' +
      '<div style="font-size:.75rem;color:#9a8a68;margin-bottom:.5rem">Reliquat de votre création -- attribution définitive, sans coût en PA.</div>' +
      '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:.4rem">' +
        STAT_DEFS_LOCAL.map(function (s) {
          const val = persoStats[s.k] || 0;
          const plafond = val >= 16;
          return '<button onclick="attribuerPointReliquat(\'' + s.k + '\')" ' + (plafond ? 'disabled' : '') +
            ' style="font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.35rem;border:1px solid #4a3a20;background:' + (plafond ? '#1a1810' : '#1a1408') + ';color:' + (plafond ? '#5a5040' : '#C9A84C') + ';cursor:' + (plafond ? 'default' : 'pointer') + '">+1 ' + s.k + (plafond ? ' (max)' : '') + '</button>';
        }).join('') +
      '</div>'
    : '';

  return '<div style="padding:.6rem 1rem">' +
      '<div style="font-size:.9rem;color:#8a8060;margin-bottom:.8rem;font-style:italic">' +
        (ar?.name || '') + ' · ' + (co?.n || '') +
        (state.poste?.name ? ' · ' + state.poste.name : '') +
        (state.posteDepute?.name ? ' · ' + state.posteDepute.name : '') +
      '</div>' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.15em;color:#9a8a68;margin-bottom:.5rem">INDICES</div>' +
      barsHtml +
      '<div style="border-top:1px solid #2a2010;margin:.6rem 0"></div>' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.15em;color:#9a8a68;margin-bottom:.5rem">ATTRIBUTS PERSONNELS</div>' +
      '<div style="display:grid;grid-template-columns:repeat(6,1fr);gap:.4rem">' + persoHtml + '</div>' +
      reliquatHtml +
      '<div style="border-top:1px solid #2a2010;margin:.6rem 0"></div>' +
      '<div style="display:flex;justify-content:space-between;font-size:.92rem;color:#8a8060">' +
        '<span>💰 Liquide : <strong style="color:#C9A84C">' + (state.liquide||0).toLocaleString('fr-FR') + ' ' + cur + '</strong></span>' +
        '<span>🏦 Banque : <strong style="color:#C9A84C">' + (typeof totalComptesBancaires === 'function' ? totalComptesBancaires() : (state.banque||0)).toLocaleString('fr-FR') + ' ' + cur + '</strong></span>' +
      '</div>' +
    '</div>';
}

// Distribution du reliquat de points (bêta) -- voir genererStatsHtml() pour l'affichage.
// Attribution point par point, définitive, sans coût en PA (le reliquat lui-même est la
// ressource rare, pas besoin d'en ajouter une seconde) -- même plafond et même barème de coût
// que la création (adjStat, creation.js), puisque ce sont les mêmes points.
function attribuerPointReliquat(stat) {
  const char = state.char;
  if (!char || !(char.freePtsRestants > 0)) return;
  if (!char.stats) char.stats = {};
  const cur = char.stats[stat] ?? 8;
  if (cur >= 16) {
    if (typeof showToast === 'function') showToast('Plafond atteint', 'Cette caractéristique a atteint son maximum (16) par ce biais -- les niveaux 17-20 se débloquent uniquement en jeu.', false);
    return;
  }
  const cost = cur >= 12 ? 2 : 1;
  if (char.freePtsRestants < cost) {
    if (typeof showToast === 'function') showToast('Points insuffisants', 'Il vous reste ' + char.freePtsRestants + ' point(s), ce palier en coûte ' + cost + '.', false);
    return;
  }
  char.stats[stat] = cur + 1;
  char.freePtsRestants -= cost;
  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  if (typeof showToast === 'function') showToast('Point attribué', '+1 ' + stat + ' (définitif).', true);
  if (typeof ouvrirStatsPerso === 'function') ouvrirStatsPerso();
}

function ouvrirStatsPerso() {
  const char = state.char;
  document.getElementById('postes-modal-title').textContent = 'Statistiques — ' + (char?.name || 'Mon Personnage');
  document.getElementById('postes-body').innerHTML = genererStatsHtml();
  document.getElementById('modal-postes').classList.add('open');
}

function getPnjAvatar(pnj, empireColor) {
  // Photo escort selon empire si pas de photoUrl
  if (!pnj.photoUrl && pnj.job === 'escort') {
    const escortPhotos = {
      republic: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-republic.png',
      narco:    'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-narco.png',
      soviet:   'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-soviet.png',
      khalija:  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/escort-khalija.png',
    };
    pnj.photoUrl = escortPhotos[state.country] || '';
    pnj.photoPos = '50% 10%';
  }
    if (pnj.photoUrl) {
    const col = empireColor || '#C9A84C';
    const safeName = (pnj.name || '').replace(' (PNJ)', '');
    return '<div style="flex-shrink:0;text-align:center">' +
      '<div onclick="ouvrirPhotoPleinEcran(this)" data-url="' + pnj.photoUrl + '" data-nom="' + safeName + '" ' +
      'style="width:90px;height:90px;border-radius:6px;border:2px solid ' + col + ';overflow:hidden;cursor:pointer;position:relative">' +
      '<img src="' + pnj.photoUrl + '" style="width:100%;height:100%;object-fit:cover;object-position:' + (pnj.photoPos || '50% 15%') + '"/>' +
      '<div style="position:absolute;bottom:0;right:0;background:rgba(0,0,0,.6);padding:2px 4px;font-size:9px;color:' + col + '">🔍</div>' +
      '</div></div>';
  }
  const av = PNJ_AVATAR[pnj.job] || PNJ_AVATAR.default;
  const col = empireColor || av.color;
  return '<div style="width:56px;height:56px;border-radius:50%;border:2px solid ' + col + ';background:rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;flex-shrink:0">' +
    '<i class="ti ' + av.icon + '" style="font-size:1.4rem;color:' + col + '"></i>' +
    '</div>';
}

function ouvrirPhotoPleinEcran(el) {
  const url = el.dataset?.url || el;
  const nom = el.dataset?.nom || '';
  // Créer overlay plein écran
  const overlay = document.createElement('div');
  overlay.id = 'photo-overlay';
  overlay.onclick = () => overlay.remove();
  overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.92);z-index:99999;display:flex;flex-direction:column;align-items:center;justify-content:center;cursor:pointer';
  overlay.innerHTML =
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;color:#C9A84C;margin-bottom:.8rem">' + nom.replace(' (PNJ)','') + '</div>' +
    '<img src="' + url + '" style="max-width:90vw;max-height:85vh;object-fit:contain;border:1px solid #3a2a10"/>' +
    '<div style="font-size:.85rem;color:#9a8a68;margin-top:.6rem">Cliquer pour fermer</div>';
  document.body.appendChild(overlay);
}

// =====================
// QUETE CARRIERE — dispatcher des 3 referents (Pat Hounette / Jean-Lou Zeure / Laurent Barre)
// Etat : state.char.queteCarriere = { ambition, etape, resultat, debriefVu }
// Independant du systeme de quete/enquete generique (getQueteActivePourPnj / progresserQuete)
// plus haut dans openPnjModal - deux mecaniques separees qui partagent juste le meme modal PNJ.
// =====================
const QUETE_CARRIERE_REFERENTS_NOMS = { 'Pat Hounette': 'criminel', 'Jean-Lou Zeure': 'politique', 'Laurent Barre': 'entrepreneurial' };

const QUETE_CARRIERE_BRIEFS = {
  // criminel : refonte du 15 aout 2026 (lot Pat Hounette / Brigitte Menottes). Le declenchement
  // ne passe plus par un bouton "Discuter" (voir genererZoneCarriereHtml) mais par la question
  // libre du joueur mentionnant Jeremy (voir talkToPnj) -- .texte/.rappel repris ici tels quels
  // par declencherMissionPatHounette() et rappelMissionCarriere(), .image/.titre inchanges.
  criminel: {
    titre: 'Pat Hounette',
    image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/pat-hounette.png',
    texte: "Jérémy vous envoie ? ... Il parle trop, ce garçon. Alors comme ça, vous cherchez à gagner votre vie sans forcément remplir toutes les cases du formulaire ?<br><br>Bon. J'ai quelque chose à faire livrer. Remettez ce colis à Brigitte Menottes, au commissariat de Luthécia. Ne posez pas de question. Revenez me voir ensuite.",
    rappel: "Le colis secret, toujours à remettre à Brigitte Menottes, au commissariat de Luthécia."
  },
  // politique : refonte du 17 aout 2026 (lot Jean-Lou Zeure). Le declenchement ne passe plus
  // par un bouton "Discuter" (voir genererZoneCarriereHtml) mais par la question libre du
  // joueur mentionnant Jeremy (voir talkToPnj). .introduction et .texte sont les deux fenetres
  // chainees (declencherMissionJeanLou), .rappel reste lu par rappelMissionCarriere() inchangee.
  politique: {
    titre: 'Jean-Lou Zeure',
    image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jean-lou-zeure.png',
    introduction: "Jérémy, le neveu du nouveau maire, vous envoie voir l'ancien maire pour des conseils ? Surprenant...<br><br>Car oui, je suis l'ancien maire de Luthécia. Ancien, oui. C'est important, le mot ancien, en politique. On vous l'ajoute généralement sans vous demander votre avis.<br><br>Vous avez besoin de conseils donc... D'accord.",
    texte: "Pour séduire les électeurs, vous pouvez faire éditer des tracts à votre nom à l'imprimerie, puis les distribuer aux gens que vous croisez. Certains voteront pour vous, d'autres non : c'est la loi de la démocratie.<br><br>Tenez, voici trois tracts. Présentez-vous à une élection, n'importe laquelle, puis distribuez-les. Revenez ensuite me voir et dites-moi les résultats que vous avez obtenus auprès de ces gens.",
    rappel: "Présentez-vous à une élection puis distribuez les 3 tracts. Revenez ensuite me voir avec les résultats."
  },
  // entrepreneurial : refonte du 18 aout 2026 (lot Laurent Barre). L'ancienne mission (terrain
  // squatte, Lot 4 de la Chataigneraie, obligation d'etre plusieurs) est retiree -- la presence
  // de squatteurs n'etait pas garantie, mauvais pour un tutoriel. Declenchement par question
  // libre (mot-cle Jeremy), pas de bouton "Discuter" -- meme principe que Pat/Jean-Lou.
  entrepreneurial: {
    titre: 'Laurent Barre',
    image: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/laurent-barre.png',
    texte: "Vous voulez devenir entrepreneur ? Très bien. Commençons par voir si vous savez négocier.<br><br>Allez voir l'agent immobilier ou le promoteur et dites-lui que vous voulez négocier le prix d'une parcelle. Revenez me donner sa réponse, peu importe qu'elle soit positive ou négative.",
    rappel: "Allez négocier le prix d'une parcelle auprès de l'agent immobilier ou du promoteur, puis revenez me voir avec la réponse."
  }
};

const QUETE_CARRIERE_DEBRIEFS = {
  // criminel.succes : laius existant reutilise tel quel au retour chez Pat (voir
  // patHounetteRetour()), seule la phrase faisant reference au fait d'etre "plusieurs" est
  // retiree -- cette mecanique de groupe n'existe plus dans la nouvelle mission (colis solo).
  // Plus de .echec : la nouvelle mission n'a pas de jet de reussite/echec, juste une remise.
  criminel: {
    succes: "Vous venez de transporter quelque chose sans en connaître le contenu, pour un homme que vous ne connaissez pas. Première leçon : dans ce métier, l'information vaut parfois davantage que la marchandise."
  },
  // Plus d'entree politique ni entrepreneuriale ici : le retour chez Jean-Lou (jeanLouRetour())
  // et chez Laurent (laurentRetour(), refonte du 18 aout 2026) affichent chacun un texte de
  // conseils fixe, connu du jeu, independant d'un succes/echec generique -- ce dispatcher
  // (debriefCarriere, retire) n'est plus appele par aucune des 3 branches.
};

// Construit le bouton d'action de la zone carriere pour ce PNJ, ou '' s'il n'est pas concerne
// (pas un referent, ou pas la branche d'ambition choisie par le joueur).
function genererZoneCarriereHtml(pnj) {
  const nomCourt = (pnj.name || '').replace(' (PNJ)', '').trim();
  const branche = QUETE_CARRIERE_REFERENTS_NOMS[nomCourt];
  if (!branche) return '';
  const qc = state.char?.queteCarriere;
  if (!qc || qc.ambition !== branche) return '';

  // Branche criminelle (Pat Hounette) : etats propres a cette refonte (a_rencontrer inchange,
  // puis colis_recu / colis_livre / terminee) -- pas de bouton "Discuter" ici, le declenchement
  // passe par la question libre du joueur (mot-cle Jeremy, voir talkToPnj). Le retour apres
  // livraison (colis_livre) ne passe plus non plus par un bouton dedie ("Faire le point",
  // retire le 17 aout 2026 sur demande explicite -- eviter de multiplier les ordres
  // specifiques a une etape de quete) : patHounetteRetour() est desormais declenchee par la
  // meme question libre, via un mot-cle (voir talkToPnj).
  if (branche === 'criminel') {
    if (qc.etape === 'colis_recu') {
      return '<button class="pnj-action-btn" style="color:#C9A84C;border-color:#8a6a20" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');rappelMissionCarriere(\'criminel\')"><i class="ti ti-briefcase" style="font-size:.85rem"></i> Rappel de la mission</button>';
    }
    return ''; // a_rencontrer, colis_livre (attend la question libre) ou terminee -> dialogue PNJ normal
  }

  // Branche politique (Jean-Lou Zeure) : meme principe que Pat pour le declenchement (pas de
  // bouton "Discuter", question libre avec mot-cle Jeremy -- voir talkToPnj). Contrairement a
  // Pat, le retour ("Faire le point") reste un bouton dedie -- priorite beta au fonctionnement,
  // pas de conversion en mot-cle pour ce point precis (decision explicite du 17 aout 2026).
  if (branche === 'politique') {
    if (qc.etape === 'tracts_recus') {
      return '<button class="pnj-action-btn" style="color:#C9A84C;border-color:#8a6a20" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');rappelMissionCarriere(\'politique\')"><i class="ti ti-briefcase" style="font-size:.85rem"></i> Rappel de la mission</button>';
    }
    if (qc.etape === 'tracts_termines') {
      return '<button class="pnj-action-btn" style="color:#C9A84C;border-color:#8a6a20;font-weight:bold" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');jeanLouRetour()"><i class="ti ti-briefcase" style="font-size:.85rem"></i> Faire le point</button>';
    }
    return ''; // a_rencontrer (pas encore declenche) ou terminee -> dialogue PNJ normal
  }

  // Branche entrepreneuriale (Laurent Barre) : meme principe que Pat/Jean-Lou (pas de bouton
  // "Discuter", question libre avec mot-cle Jeremy -- voir talkToPnj). Comme Jean-Lou, le
  // retour ("Faire le point") reste un bouton dedie -- priorite beta au fonctionnement,
  // decision explicite du 18 aout 2026, coherente avec le lot precedent.
  if (branche === 'entrepreneurial') {
    if (qc.etape === 'negociation_demandee') {
      return '<button class="pnj-action-btn" style="color:#C9A84C;border-color:#8a6a20" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');rappelMissionCarriere(\'entrepreneurial\')"><i class="ti ti-briefcase" style="font-size:.85rem"></i> Rappel de la mission</button>';
    }
    if (qc.etape === 'negociation_obtenue') {
      return '<button class="pnj-action-btn" style="color:#C9A84C;border-color:#8a6a20;font-weight:bold" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');laurentRetour()"><i class="ti ti-briefcase" style="font-size:.85rem"></i> Faire le point</button>';
    }
    return ''; // a_rencontrer (pas encore declenche) ou terminee -> dialogue PNJ normal
  }

  // Plus aucune branche n'utilise le dispatcher generique a_rencontrer/en_cours/terminee ci-
  // dessus (ouvrirBriefCarriere/debriefCarriere, retires le 18 aout 2026 -- les 3 branches ont
  // desormais chacune leur propre etat/dispatch dedie). Rien a faire ici pour une branche
  // inconnue.
  return '';
}

function rappelMissionCarriere(branche) {
  const b = QUETE_CARRIERE_BRIEFS[branche];
  if (b && typeof showToast === 'function') showToast('Rappel', b.rappel, true);
}

// Hook historique (ordre general confirmerDistribuerTract, hors perimetre des 3 branches
// d'onboarding desormais refaites) : plus aucune des 3 branches ne l'appelle pour sa propre
// progression (chacune a son etat/dispatch dedie -- voir plus bas). Conserve tel quel, non
// touche : ordre general non concerne par ce lot.
function verifierProgressionCarriere(branche, succes) {
  const qc = state.char?.queteCarriere;
  if (!qc || qc.ambition !== branche || qc.etape !== 'en_cours') return;
  qc.etape = 'terminee';
  qc.resultat = succes ? 'succes' : 'echec';
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
}

// =====================
// BRANCHE CRIMINELLE — Pat Hounette / Brigitte Menottes (refonte du 15 aout 2026)
// Etats propres : state.char.queteCarriere = { ambition:'criminel', etape, resultat:null }
//   a_rencontrer -> colis_recu -> colis_livre -> terminee
// Remplace l'ancienne mission "contrebande au port, a plusieurs" (verifierProgressionCarriere
// n'est plus appelee pour cette branche, voir doContrebandePort). Ne passe plus par l'ancien
// dispatcher generique ouvrirBriefCarriere/debriefCarriere (retire le 18 aout 2026, plus aucune
// des 3 branches ne l'utilisait) : dispatch dedie ci-dessous, texte/image repris de
// QUETE_CARRIERE_BRIEFS.criminel et QUETE_CARRIERE_DEBRIEFS.criminel.
// =====================

// Declenchee depuis talkToPnj() des que le joueur mentionne Jeremy a Pat Hounette (question
// libre, pas de bouton). Cree le vrai objet d'inventaire, journalise, trace l'action pour le
// pipeline de rumeurs (fait detectable, pas une annonce publique), et bascule l'etape.
function declencherMissionPatHounette() {
  const qc = state.char?.queteCarriere;
  if (!qc || qc.ambition !== 'criminel' || qc.etape !== 'a_rencontrer') return;
  const b = QUETE_CARRIERE_BRIEFS.criminel;

  qc.etape = 'colis_recu';
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  if (typeof addToInventory === 'function') {
    addToInventory({ type: 'colis_secret_pat', name: 'Colis secret', icon: 'ti-package', desc: "Un colis remis par Pat Hounette. Vous ignorez ce qu'il contient." });
  }
  if (typeof addJournalEntry === 'function') {
    addJournalEntry('Pat Hounette vous a confié un colis secret à remettre à Brigitte Menottes au commissariat de Luthécia.', 'event-info');
  }
  // Fait potentiellement compromettant (quelqu'un a pu voir la remise), pas une rumeur diffusee
  // automatiquement -- alimente le meme pipeline que les autres actions detectables du jeu.
  if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('colis_recu_pat_hounette', 'Pat Hounette');

  document.getElementById('modal-pnj')?.classList.remove('open');
  if (typeof afficherPopupQueteAccueil === 'function') {
    afficherPopupQueteAccueil({ image: b.image, titre: b.titre, texte: b.texte, suivant: null });
  }
}

// Declenchee depuis confirmerDonObjetPnj/confirmerDonObjetPj (plateau-justice-economie.js)
// quand le joueur remet reellement le Colis secret a Brigitte Menottes. L'objet a deja ete
// retire de l'inventaire par l'appelant avant ce point.
function remettreColisBrigitte() {
  const qc = state.char?.queteCarriere;
  if (!qc || qc.ambition !== 'criminel' || qc.etape !== 'colis_recu') return;
  qc.etape = 'colis_livre';
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  const imageBrigitte = 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/commissariat-brigitte-menottes.png';
  document.getElementById('modal-pnj')?.classList.remove('open');
  if (typeof afficherPopupQueteAccueil !== 'function') return;

  afficherPopupQueteAccueil({
    image: imageBrigitte,
    titre: 'Brigitte Menottes',
    texte: "Un cadeau ? Pour moi ? J'espère que vous n'essayez pas de me soudoyer. Voyons voir ce que c'est...",
    suivant: function() {
      afficherPopupQueteAccueil({
        image: 'images/colis-pat-hounette-plaisir-offrir.jpg',
        titre: 'Brigitte Menottes',
        texte: "Ohhhh, des menottes en fourrure roses !!! ❤️❤️❤️",
        suivant: function() {
          afficherPopupQueteAccueil({
            image: imageBrigitte,
            titre: 'Brigitte Menottes',
            texte: "Hum hum... Vous direz au mystérieux inconnu qui vous a demandé de me faire parvenir ce cadeau que je ne suis pas corruptible. Mais pour autant, je les garderai pour un usage personnel : elles ne font pas partie du matériel autorisé pendant le service. Dites-lui merci de ma part.",
            suivant: null
          });
        }
      });
    }
  });
}

// Declenchee par la question libre du joueur a Pat une fois le colis livre (mot-cle, voir
// talkToPnj -- plus de bouton dedie depuis le 17 aout 2026). Reutilise le laius existant
// (chute pedagogique de la mission), puis enchaine sur les conseils finaux avant de clore
// definitivement la branche.
function patHounetteRetour() {
  const qc = state.char?.queteCarriere;
  if (!qc || qc.ambition !== 'criminel' || qc.etape !== 'colis_livre') return;
  const b = QUETE_CARRIERE_BRIEFS.criminel;
  const d = QUETE_CARRIERE_DEBRIEFS.criminel;

  // Ferme la fiche de Pat (fenetre "Posez votre question") avant d'afficher la popup de
  // quete -- meme geste que declencherMissionPatHounette()/remettreColisBrigitte(), omis ici
  // par erreur lors du retrait du bouton "Faire le point" (17 aout 2026). Sans cette fermeture,
  // afficherPopupQueteAccueil() detecte modal-pnj encore ouverte et se re-differe de 2s en 2s
  // (garde-fou anti-empilement existant), donnant l'impression que l'interface reste bloquee
  // en attente d'une reponse jusqu'a ce que le joueur ferme la fiche lui-meme.
  document.getElementById('modal-pnj')?.classList.remove('open');

  afficherPopupQueteAccueil({
    image: b.image,
    titre: b.titre,
    texte: d.succes,
    suivant: function() {
      afficherPopupQueteAccueil({
        image: b.image,
        titre: b.titre,
        texte: "À présent, je sais que vous êtes digne de confiance. Alors je vais vous donner quelques conseils.<br><br>Si vous voulez faire carrière dans le crime, vous pouvez rejoindre un groupe criminel existant, ou créer le vôtre si vous disposez d'un local où installer votre siège. Vous pouvez aussi travailler en solo. C'est vous qui voyez.<br><br>Mais retenez une chose : vous aurez besoin de gens capables de vous aider, et notamment de gens dotés d'une grande duplicité. C'est risqué de faire confiance à ce genre de personnes... mais dans notre métier, on n'a pas toujours le choix.<br><br>Maintenant, éloignez-vous de moi. À rester ensemble trop longtemps, on va finir par se faire remarquer. Continuez à explorer la ville.<br><br>Et si vous avez besoin d'un conseil sur... disons, des activités que l'administration réprouve, ajoutez-moi à votre répertoire et envoyez-moi un mail. Je vous répondrai si je peux.",
        suivant: function() {
          qc.etape = 'terminee';
          if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
        }
      });
    }
  });
}

// "Mes Objectifs" pour les branches criminelle et politique -- meme principe que
// queteAccueilObjectifActuel (plateau-quete-accueil.js) pour le tronc commun, lu en repli par
// afficherObjectifsSecrets() quand ce dernier ne renvoie rien (branche non encore concernee ou
// tronc commun deja termine).
function queteCarriereObjectifActuel() {
  const qc = state.char?.queteCarriere;
  if (!qc) return null;
  if (qc.ambition === 'criminel') {
    if (qc.etape === 'a_rencontrer') return "Rendez-vous chez Pat Hounette et dites-lui que Jérémy vous envoie.";
    if (qc.etape === 'colis_recu') return "Remettez le colis secret à Brigitte Menottes au commissariat de Luthécia.";
    if (qc.etape === 'colis_livre') return "Retournez voir Pat Hounette.";
    return null; // 'terminee' (ou etat inconnu) -> pas d'objectif specifique
  }
  if (qc.ambition === 'politique') {
    if (qc.etape === 'a_rencontrer') return "Rendez-vous chez Jean-Lou Zeure et dites-lui que Jérémy vous envoie.";
    if (qc.etape === 'tracts_recus') return "Présentez-vous à une élection à la mairie, puis distribuez les 3 tracts confiés par Jean-Lou Zeure.";
    if (qc.etape === 'tracts_termines') return "Retournez voir Jean-Lou Zeure et donnez-lui vos résultats.";
    return null; // 'terminee' (ou etat inconnu) -> pas d'objectif specifique
  }
  if (qc.ambition === 'entrepreneurial') {
    if (qc.etape === 'a_rencontrer') return "Rendez-vous chez Laurent Barre et dites-lui que Jérémy vous envoie.";
    if (qc.etape === 'negociation_demandee') return "Demandez à l'agent immobilier ou au promoteur de négocier le prix d'une parcelle, puis retournez voir Laurent Barre.";
    if (qc.etape === 'negociation_obtenue') return "Retournez voir Laurent Barre et donnez-lui la réponse obtenue.";
    return null; // 'terminee' (ou etat inconnu) -> pas d'objectif specifique
  }
  return null;
}

// =====================
// BRANCHE POLITIQUE — Jean-Lou Zeure (refonte du 17 aout 2026)
// Etats propres : state.char.queteCarriere = { ambition:'politique', etape, resultat:null,
//   electionCible: {posteId,country,city} | null, ciblesJeanLou: [nomPNJ,...],
//   resultatsJeanLou: [bool,...] }
//   a_rencontrer -> tracts_recus -> tracts_termines -> terminee
// A la difference de Pat, le retour ("Faire le point") reste un bouton dedie (decision
// explicite, priorite beta au fonctionnement plutot qu'a l'uniformisation ergonomique) : voir
// genererZoneCarriereHtml. Utilise imperativement le vrai systeme electoral (CYCLES_ELECTORAUX/
// votesPNJ/enregistrerVotePNJ, plateau-politique.js) -- jamais distribuerTractPNJ()/
// state.electionsEnCours, le systeme factice identifie par l'audit du 17 aout 2026.
// =====================

// Declenchee depuis talkToPnj() des que le joueur mentionne Jeremy a Jean-Lou Zeure (question
// libre, pas de bouton). Deux fenetres chainees (introduction puis mission), puis remise reelle
// de 3 tracts electoraux (modele d'objet tract deja existant, cible = le PJ lui-meme, marques
// origineQuete:'jean_lou' pour que la quete puisse suivre precisement LEURS distributions sans
// interferer avec d'eventuels autres tracts que le joueur possederait par ailleurs).
function declencherMissionJeanLou() {
  const qc = state.char?.queteCarriere;
  if (!qc || qc.ambition !== 'politique' || qc.etape !== 'a_rencontrer') return;
  const b = QUETE_CARRIERE_BRIEFS.politique;

  document.getElementById('modal-pnj')?.classList.remove('open');
  if (typeof afficherPopupQueteAccueil !== 'function') return;

  afficherPopupQueteAccueil({
    image: b.image,
    titre: b.titre,
    texte: b.introduction,
    suivant: function() {
      afficherPopupQueteAccueil({
        image: b.image,
        titre: b.titre,
        texte: b.texte,
        suivant: function() {
          qc.etape = 'tracts_recus';
          qc.electionCible = null;
          qc.ciblesJeanLou = [];
          qc.resultatsJeanLou = [];
          if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

          if (typeof addToInventory === 'function') {
            addToInventory({
              type: 'tract', name: 'Tracts POUR ' + (state.char?.name || 'vous'),
              icon: 'ti-file-description', tractType: 'pour', cible: state.char?.name || '',
              quantite: 3, legal: true, origineQuete: 'jean_lou'
            });
          }
          if (typeof addJournalEntry === 'function') {
            addJournalEntry('Jean-Lou Zeure vous a confié 3 tracts électoraux à votre nom.', 'event-info');
          }
        }
      });
    }
  });
}

// Cherche une candidature REELLE et active du joueur (CYCLES_ELECTORAUX, jamais
// state.electionsEnCours) dans son empire courant. Parcourt les cles dans un ordre stable pour
// que le choix soit deterministe si le joueur est candidat a plusieurs postes a la fois (voir
// distribuerTractJeanLou : les 3 tracts de cette quete restent tous rattaches a la MEME
// election, jamais repartis/dupliques sur plusieurs).
// Correctif du 18 aout 2026 (bug bloquant remonte en test manuel) : cette fonction exigeait
// encore getPhaseActuelle(...) === CAMPAGNE, un second verrou date/phase independant du delai
// de candidature deja retire de deposerCandidature() (lot precedent). Un cycle fraichement cree
// a sa candidature demarre sa phase CANDIDATURES avec dateDebutCampagne = maintenant + 1
// semaine : juste apres avoir depose sa candidature (desormais possible a tout moment), le
// joueur echouait donc systematiquement ce test de phase, alors qu'il est bien reellement
// candidat. Etre reellement liste dans cycle.candidats suffit desormais a etre considere
// candidat pour les interactions electorales (tracts/prospectus) -- aucune autre condition
// electorale modifiee.
function trouverElectionCandidatJoueur() {
  const country = state.country;
  const cycles = (typeof CYCLES_ELECTORAUX !== 'undefined' && CYCLES_ELECTORAUX[country]) || {};
  const nom = state.char?.name;
  if (!nom) return null;
  const cles = Object.keys(cycles).sort();
  for (const cle of cles) {
    const cycle = cycles[cle];
    if (!cycle || !cycle.candidats) continue;
    if (!cycle.candidats.some(c => c.nom === nom)) continue;
    return { posteId: cycle.posteId, city: cycle.city || null, country };
  }
  return null;
}

// Meme principe que trouverElectionCandidatJoueur ci-dessus, parametre par un nom de candidat
// arbitraire (lot tracts electoraux PSM, 24 aout 2026) -- trouve le cycle electoral ou une
// personne nommee est effectivement candidate, quel que soit le joueur courant. Reutilise pour
// resoudre sans ambiguite la cible d'un tract electoral (choisie a l'impression) au moment de sa
// distribution a un PNJ.
function trouverElectionParCandidat(nomCandidat) {
  const country = state.country;
  const cycles = (typeof CYCLES_ELECTORAUX !== 'undefined' && CYCLES_ELECTORAUX[country]) || {};
  if (!nomCandidat) return null;
  const cles = Object.keys(cycles).sort();
  for (const cle of cles) {
    const cycle = cycles[cle];
    if (!cycle || !cycle.candidats) continue;
    if (!cycle.candidats.some(c => c.nom === nomCandidat)) continue;
    return { posteId: cycle.posteId, city: cycle.city || null, country };
  }
  return null;
}

// Declenchee depuis la fiche d'un PNJ (bouton quete-specifique, voir openPnjModal) une fois le
// joueur reellement candidat. Consomme un tract de mission Jean-Lou, garantit 3 PNJ distincts
// pour CETTE quete, et n'ecrit une voix reelle QUE via enregistrerVotePNJ (plateau-politique.js)
// -- jamais dans state.electionsEnCours. Les 3 tracts restent rattaches a la meme election
// (qc.electionCible, fixee au premier tract distribue).
function distribuerTractJeanLou(pnjName) {
  const qc = state.char?.queteCarriere;
  if (!qc || qc.ambition !== 'politique' || qc.etape !== 'tracts_recus') return;

  const ciblesDeja = qc.ciblesJeanLou || [];
  if (ciblesDeja.includes(pnjName)) {
    if (typeof showToast === 'function') showToast('Déjà tenté', pnjName + ' a déjà été démarché(e) pour cette mission.', false);
    return;
  }

  const election = qc.electionCible || trouverElectionCandidatJoueur();
  if (!election) {
    if (typeof showToast === 'function') showToast('Pas encore candidat', 'Présentez-vous d\'abord à une élection à la mairie avant de distribuer vos tracts.', false);
    return;
  }
  if (!qc.electionCible) {
    qc.electionCible = election;
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  }

  const lot = (state.inventory || []).find(i => i.type === 'tract' && i.origineQuete === 'jean_lou' && (i.quantite || 0) > 0);
  if (!lot) return; // plus de tract de mission -- le bouton ne devrait plus etre visible a ce stade

  lot.quantite -= 1;
  if (lot.quantite <= 0) {
    const idx = state.inventory.indexOf(lot);
    state.inventory.splice(idx, 1);
  }
  if (typeof renderInventory === 'function') renderInventory();

  // Meme mecanisme probabiliste que le tractage existant (distribuerTractPNJ, plateau-
  // communication.js) : 50% de base + bonus INF/10, plafonne a 80%. Seule la destination du
  // succes change (vrai systeme electoral, pas state.electionsEnCours).
  const bonusInf = Math.floor((state.inf || 0) / 10);
  const taux = Math.min(80, 50 + bonusInf);
  const roll = Math.floor(Math.random() * 100) + 1;
  let convaincu = roll <= taux;

  if (convaincu) {
    // Verification synchrone (pas d'attente reseau) : ce PNJ ne peut deja figurer dans
    // cycle.votesPNJ pour cette election puisque la quete garantit 3 cibles distinctes, sauf
    // cas rarissime ou il a ete convaincu par un tout autre biais (ex: distribuerProspectus)
    // avant meme cette mission -- dans ce cas, aucune nouvelle voix n'est ecrite et le tract
    // ne compte pas comme un succes pour la quete. La persistance reelle (asynchrone) est
    // lancee ensuite, mais cette decision synchrone conditionne deja le score/message affiches
    // immediatement ci-dessous.
    const cleCycle = (typeof getCleCycle === 'function') ? getCleCycle(election.posteId, election.city) : null;
    const cycleCible = cleCycle && (typeof CYCLES_ELECTORAUX !== 'undefined') ? CYCLES_ELECTORAUX[election.country]?.[cleCycle] : null;
    if (cycleCible && cycleCible.votesPNJ && cycleCible.votesPNJ[pnjName]) {
      convaincu = false;
    } else if (typeof enregistrerVotePNJ === 'function') {
      enregistrerVotePNJ(election.country, election.posteId, election.city, pnjName, state.char.name).catch(() => {});
    }
  }

  qc.ciblesJeanLou = ciblesDeja.concat([pnjName]);
  qc.resultatsJeanLou = (qc.resultatsJeanLou || []).concat([convaincu]);
  if (qc.ciblesJeanLou.length >= 3) {
    qc.etape = 'tracts_termines';
  }
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  if (typeof addJournalEntry === 'function') {
    addJournalEntry(convaincu
      ? 'Tract distribué à ' + pnjName + ' — convaincu(e).'
      : 'Tract distribué à ' + pnjName + ' — sans effet.', convaincu ? 'event-good' : '');
  }
  if (typeof showToast === 'function') {
    showToast(convaincu ? 'Convaincu !' : 'Sans effet',
      convaincu ? pnjName + ' est convaincu ! Il va voter pour vous.' : pnjName + ' n\'est pas convaincu. Il ne votera pas pour vous.',
      convaincu);
  }
  if (typeof updateUI === 'function') updateUI();
}

// Declenchee par le bouton "Faire le point" sur la fiche de Jean-Lou une fois les 3 tracts
// distribues. Le score est deja connu par le jeu (qc.resultatsJeanLou) : jamais redemande au
// joueur. Affiche d'abord la replique du PJ annoncant le score exact, puis les conseils finaux
// (texte fixe, fourni tel quel), avant de clore definitivement la branche.
function jeanLouRetour() {
  const qc = state.char?.queteCarriere;
  if (!qc || qc.ambition !== 'politique' || qc.etape !== 'tracts_termines') return;
  const b = QUETE_CARRIERE_BRIEFS.politique;
  const total = (qc.resultatsJeanLou || []).length;
  const convaincus = (qc.resultatsJeanLou || []).filter(Boolean).length;

  afficherPopupQueteAccueil({
    image: (state.char && state.char.photoUrl) || null,
    titre: (state.char && state.char.name) || 'Vous',
    texte: 'J\'ai convaincu ' + convaincus + ' personne' + (convaincus > 1 ? 's' : '') + ' sur ' + total + '.',
    suivant: function() {
      afficherPopupQueteAccueil({
        image: b.image,
        titre: b.titre,
        texte: "Bon, eh bien vous savez déjà comment faire voter les gens.<br><br>Maintenant, je vous conseille de faire une belle déclaration de candidature sur le forum dédié à l'élection. Les beaux discours peuvent rallier des électeurs à votre cause, et certains pourront même tracter pour vous.<br><br>N'oubliez pas non plus la puissance du club des supporters du club de football. Si vous parvenez à les mettre de votre côté, ils pourront sérieusement vous aider à remporter une élection.<br><br>Je vous laisse, j'ai des offres d'emploi à éplucher. Mais si vous avez besoin d'aide, ajoutez-moi à vos contacts et écrivez-moi. J'essaierai de répondre à vos questions.",
        suivant: function() {
          qc.etape = 'terminee';
          if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
        }
      });
    }
  });
}

// =====================
// BRANCHE ENTREPRENEURIALE — Laurent Barre (refonte du 18 aout 2026)
// Etats propres : state.char.queteCarriere = { ambition:'entrepreneurial', etape,
//   resultatNegociation: 'non'|'ouvert'|null }
//   a_rencontrer -> negociation_demandee -> negociation_obtenue -> terminee
// Remplace l'ancienne mission (terrain squatte du Lot 4 de la Chataigneraie, obligation d'etre
// plusieurs) : la presence de squatteurs n'etait pas garantie, inadaptee a un tutoriel.
// Aucun achat, aucune depense, aucune modification reelle de prix de parcelle -- uniquement
// une interaction de dialogue, jamais l'ordre reel de negociation avec les squatteurs
// (confirmerNegociation, mecanique generale non touchee et non reutilisee ici).
// =====================

// Declenchee depuis talkToPnj() des que le joueur mentionne Jeremy a Laurent Barre (question
// libre, pas de bouton). Une seule fenetre (texte fourni), pas de grant d'objet/argent.
function declencherMissionLaurent() {
  const qc = state.char?.queteCarriere;
  if (!qc || qc.ambition !== 'entrepreneurial' || qc.etape !== 'a_rencontrer') return;
  const b = QUETE_CARRIERE_BRIEFS.entrepreneurial;

  document.getElementById('modal-pnj')?.classList.remove('open');
  if (typeof afficherPopupQueteAccueil !== 'function') return;

  afficherPopupQueteAccueil({
    image: b.image,
    titre: b.titre,
    texte: b.texte,
    suivant: function() {
      qc.etape = 'negociation_demandee';
      qc.resultatNegociation = null;
      if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    }
  });
}

// Declenchee depuis talkToPnj() quand le joueur demande a negocier le prix d'une parcelle a
// l'agent immobilier (Notaire Fontenelle, office notarial -- "Ventes de terrain" fait partie
// de ses attributions reelles) ou au promoteur (Gerard Speculos et equivalents par empire,
// PNJ id:'promoteur' dans data.js). Reponse aleatoire simple, sans impact economique reel --
// sert uniquement a faire pratiquer l'interaction au joueur. Memorise le resultat une seule
// fois (gate sur l'etape : un deuxieme essai, etape deja passee a negociation_obtenue, ne
// redeclenche plus rien ici et retombe sur le comportement normal du PNJ).
function repondreNegociationParcelle(pnj) {
  const qc = state.char?.queteCarriere;
  if (!qc || qc.ambition !== 'entrepreneurial' || qc.etape !== 'negociation_demandee') return;

  const ouvert = Math.random() < 0.5;
  qc.resultatNegociation = ouvert ? 'ouvert' : 'non';
  qc.etape = 'negociation_obtenue';
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  document.getElementById('modal-pnj')?.classList.remove('open');
  if (typeof afficherPopupQueteAccueil !== 'function') return;
  afficherPopupQueteAccueil({
    image: pnj.photoUrl || null,
    titre: (pnj.name || '').replace(' (PNJ)', ''),
    texte: ouvert
      ? "Négocier ? Pourquoi pas. Mais bon, est-ce que vous avez les fonds ? Si vous payez cash, on peut en reparler. N'hésitez pas à revenir me voir."
      : "Négocier ? Vous plaisantez, j'espère. Le potentiel de ces parcelles est énorme. C'est déjà une bonne affaire à ce prix-là.",
    suivant: null
  });
}

// Declenchee par le bouton "Faire le point" sur la fiche de Laurent une fois la reponse
// obtenue. Le jeu connait deja le resultat (qc.resultatNegociation) : un seul choix cliquable
// est propose, celui correspondant reellement a la reponse obtenue -- le joueur ne peut donc
// pas mentir accidentellement et casser l'etat de la quete (solution minimale demandee, pas de
// systeme general de memoire des mensonges).
function laurentRetour() {
  const qc = state.char?.queteCarriere;
  if (!qc || qc.ambition !== 'entrepreneurial' || qc.etape !== 'negociation_obtenue') return;
  const b = QUETE_CARRIERE_BRIEFS.entrepreneurial;
  const choixTexte = qc.resultatNegociation === 'ouvert' ? 'Ils ne sont pas fermés à la discussion.' : 'Ils ont dit non.';

  afficherPopupQueteAccueil({
    image: b.image,
    titre: b.titre,
    texte: 'Alors, ils ont dit quoi ?',
    suivant: null,
    actionsHtml: '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-quete-accueil\').classList.remove(\'open\');laurentConclusion();">' + choixTexte + '</button>'
  });
}

function laurentConclusion() {
  const qc = state.char?.queteCarriere;
  if (!qc || qc.ambition !== 'entrepreneurial' || qc.etape !== 'negociation_obtenue') return;
  const b = QUETE_CARRIERE_BRIEFS.entrepreneurial;

  afficherPopupQueteAccueil({
    image: b.image,
    titre: b.titre,
    texte: "Vous voyez, pour négocier, il faut avoir des atouts. Un bon businessman se doit d'avoir une bonne intelligence. Si vous voulez être encore meilleur, sachez vous entourer de personnes plus intelligentes que vous.<br><br>N'ayez crainte, vous resterez le boss quoi qu'il arrive : ces personnes seront là pour vous servir.<br><br>À présent, j'ai du travail. Explorez un peu cette ville et détectez les opportunités.<br><br>Si vous avez besoin d'aide, ajoutez-moi à vos contacts et envoyez-moi un mail. Je vous répondrai volontiers si je peux vous apporter une vraie réponse.",
    suivant: function() {
      qc.etape = 'terminee';
      if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    }
  });
}

// Protege le Colis secret contre une perte accidentelle (destruction/abandon) tant que la
// mission en depend -- indispensable a la progression, sa perte rendrait la quete impossible.
// Correctif cible (17 aout 2026), pas un systeme general de protection des objets de quete :
// verifie uniquement ce type d'objet precis, le reste de l'inventaire n'est pas concerne.
// Utilisee par supprimerItemInventaire/jeterObjetInventaire (plateau-personnage.js) et par
// renderInventory (plateau-divers.js, pour masquer les boutons correspondants).
function colisSecretProtege(item) {
  if (!item || item.type !== 'colis_secret_pat') return false;
  const qc = state.char?.queteCarriere;
  return !!(qc && qc.ambition === 'criminel' && qc.etape !== 'terminee');
}

function openPnjModal(encodedPnj) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); }
  catch(e) { return; }

  // Cadavre — photo plein écran uniquement, pas de dialogue
  if (pnj.terrainPnjId === 'cadavre') {
    ouvrirPhotoCadavre(JSON.stringify({
      photoUrl: pnj.photoUrl, photoPos: pnj.photoPos,
      role: pnj.role, trait: pnj.trait
    }));
    return;
  }

  const isPJ = pnj.isPJ === true;
  document.getElementById('modal-pnj').classList.add('open');
  document.getElementById('pnj-modal-title').textContent = pnj.name?.replace(' (PNJ)', '') || 'Inconnu';

  // Avatar CSS par type de PNJ
  const empireCol = COUNTRIES[state.country]?.col || '#C9A84C';
  const avatarHtml = typeof getPnjAvatar === 'function' ? getPnjAvatar(pnj, empireCol) : '';
  const avatarEl = document.getElementById('pnj-avatar-container');
  if (avatarEl) avatarEl.innerHTML = avatarHtml;

  // Rôle et trait de personnalité
  const roleEl = document.getElementById('pnj-role-display');
  if (roleEl) roleEl.textContent = pnj.role?.replace(' (PNJ)', '') || '';
  const traitEl = document.getElementById('pnj-trait-display');
  const pnjKey = pnj.name?.replace(' (PNJ)', '').trim();
  const perso = typeof PNJ_PERSONALITIES !== 'undefined' ? PNJ_PERSONALITIES[pnjKey] : null;
  if (traitEl) traitEl.textContent = perso?.trait || '';

  (async () => {
    if (typeof sbGetMariageActif !== 'function') return;
    const mariage = await sbGetMariageActif(pnjKey).catch(() => null);
    let statutEl = document.getElementById('pnj-statut-marital');
    if (!statutEl && traitEl) {
      statutEl = document.createElement('div');
      statutEl.id = 'pnj-statut-marital';
      statutEl.style.cssText = 'font-size:.72rem;color:#9a7a50;margin-top:.2rem;font-style:italic';
      traitEl.parentNode.insertBefore(statutEl, traitEl.nextSibling);
    }
    if (statutEl) {
      if (mariage) {
        const conjoint = mariage.conjoint1 === pnjKey ? mariage.conjoint2 : mariage.conjoint1;
        statutEl.textContent = '💍 Marié(e) à ' + conjoint;
      } else {
        statutEl.textContent = '';
      }
    }
  })();
  const speech = document.getElementById('pnj-speech');
  speech.innerHTML = '<div class="pnj-loading"><span class="spin"></span> En train de repondre...</div>';
  const enc = encodePnjSafe(pnj);

  let actionBtns = '';
  const pnjSafeName = pnj.name.replace(/'/g, '');
  const pnjSafeRole = (pnj.role||'').replace(/'/g, '');
  const pnjRel = pnj.rel || 'neutral';

  if (isPJ) {
    const inGroup = state.group && state.group.members && state.group.members.includes(pnj.name);
    const pnjJson = encodePnjSafe(pnj);
    actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');ouvrirConversationAvec(\'' + pnjSafeName + '\')" style="color:#6ada6a;border-color:#2a5a2a"><i class="ti ti-message-circle" style="font-size:.85rem"></i> Parler</button>';
    actionBtns += (!inGroup
      ? '<button class="pnj-action-btn" onclick="rejoindrePJ(decodeURIComponent(\'' + pnjJson + '\'))"><i class="ti ti-users" style="font-size:.85rem"></i> Rejoindre ce joueur</button>'
      : '<button class="pnj-action-btn" onclick="quitterGroupe()"><i class="ti ti-user-minus" style="font-size:.85rem"></i> Quitter le groupe</button>');
    actionBtns += '<button class="pnj-action-btn" onclick="addContactByName(\'' + pnjSafeName + '\',\'' + pnjSafeRole + '\',\'' + pnjRel + '\',true)"><i class="ti ti-user-plus" style="font-size:.85rem"></i> Ajouter au repertoire</button>';
    actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');composerMailPour(\'' + pnjSafeName + '\')"><i class="ti ti-mail" style="font-size:.85rem"></i> Envoyer un mail</button>';
  }

  if (!isPJ) {
    const dejaDansRep = (state.contacts || []).some(c => c.name === pnj.name);
    if (!dejaDansRep) {
      actionBtns += '<button class="pnj-action-btn" onclick="addContactByName(\'' + pnjSafeName + '\',\'' + pnjSafeRole + '\',\'' + pnjRel + '\')"><i class="ti ti-user-plus" style="font-size:.85rem"></i> Ajouter au repertoire</button>';
    }
  }

  actionBtns += '<button class="pnj-action-btn" onclick="doSaluerPersonne(\'' + pnjSafeName + '\')"><i class="ti ti-hand-stop" style="font-size:.85rem"></i> Saluer</button>';
  actionBtns += '<button class="pnj-action-btn" onclick="ouvrirDonPnjModal(\'' + enc + '\')"><i class="ti ti-coins" style="font-size:.85rem"></i> Donner</button>';

  // Services religieux en contact (lot "refonte religion Republia", 26 aout 2026 ; job 'pretre'
  // ajoute au lot "carriere religieuse Republia", 26 aout 2026 pour les titulaires locaux Pere
  // Iscope/Abbe Tonniere) : confession et benediction ne sont plus des ordres de salle, mais un
  // service rendu par un religieux habilite (grand_pretre/pretre/clerc) reellement present,
  // uniquement dans l'une des trois eglises de Republia -- jamais depuis un autre batiment ni un
  // autre empire. "Consulter la regle" reutilise le mecanisme deja existant
  // (openRulesView/renderRulesContent, section 'religion') plutot que d'en inventer un nouveau.
  const EGLISES_REPUBLIA_HABILITEES = ['tabernacle-impots', 'notre-dame-mer', 'eglise-montrouge'];
  if (!isPJ && ['grand_pretre', 'pretre', 'clerc'].includes(pnj.job) && EGLISES_REPUBLIA_HABILITEES.includes(state.currentBuilding)) {
    actionBtns += '<button class="pnj-action-btn" onclick="doSeConfeserContact(\'' + pnjSafeName + '\')"><i class="ti ti-message" style="font-size:.85rem"></i> Se confesser</button>';
    actionBtns += '<button class="pnj-action-btn" onclick="doDemanderBenedictionContact(\'' + pnjSafeName + '\')"><i class="ti ti-sparkles" style="font-size:.85rem"></i> Demander une bénédiction</button>';
    actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');openRulesView();renderRulesContent(\'religion\');" style="color:#8a9aca;border-color:#2a3a5a"><i class="ti ti-book" style="font-size:.85rem"></i> Consulter la règle</button>';
    // Pouvoir du Grand Pretre national (§6 du lot 2, 26 aout 2026) : boutons proposes ici, dans
    // n'importe laquelle des 3 eglises (pas seulement Luthecia -- la fonction est nationale, un
    // Grand Pretre base a PSM/Montrouge l'exerce aupres de son propre referent local). Visibles a
    // tout visiteur ; l'autorisation reelle (etre effectivement le Grand Pretre EN EXERCICE) est
    // verifiee fraichement au clic, jamais dans cette liste (ouvrirExcommunierCible,
    // plateau-divers.js), meme doctrine que "controle frais au moment exact" deja etablie ailleurs.
    actionBtns += '<button class="pnj-action-btn" style="color:#8a3a2a;border-color:#5a2020" onclick="ouvrirExcommunierCible()"><i class="ti ti-ban" style="font-size:.85rem"></i> Excommunier (Grand Prêtre)</button>';
    actionBtns += '<button class="pnj-action-btn" style="color:#4a8a6a;border-color:#2a5a3a" onclick="ouvrirLeverExcommunicationCible()"><i class="ti ti-shield-check" style="font-size:.85rem"></i> Lever une excommunication (Grand Prêtre)</button>';
  }

  // Meneur des Supporters, referent de la regle football/tribunes (chantier "tribunes actives",
  // 28 aout 2026) -- meme mecanisme que "Consulter la regle" ci-dessus (openRulesView/
  // renderRulesContent, section 'sport'), jamais un nouveau systeme d'aide.
  if (!isPJ && pnj.job === 'meneur_supporters') {
    actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');openRulesView();renderRulesContent(\'sport\');" style="color:#8a9aca;border-color:#2a3a5a"><i class="ti ti-book" style="font-size:.85rem"></i> Consulter la règle</button>';
  }

  const objetsDispos = (state.inventory || []).filter(i => i.type !== 'acte_officiel');
  if (objetsDispos.length > 0) {
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirDonObjetPnjModal(\'' + enc + '\')"><i class="ti ti-package" style="font-size:.85rem"></i> Donner un objet</button>';
  }

  // Tracts de la mission Jean-Lou Zeure (origineQuete:'jean_lou') separes des tracts
  // "generiques" : les boutons generiques (distribuerTractElectoralPNJ, remplace l'ancien
  // distribuerTractPNJ "systeme factice identifie par l'audit du 17 aout 2026") restent masques
  // tant que le joueur en detient, pour eviter qu'il ne consomme accidentellement un tract de
  // mission via le mauvais circuit. Voir distribuerTractJeanLou plus bas pour le vrai circuit de
  // cette quete, non touche.
  const tractsDispos = (state.inventory || []).filter(i => i.type === 'tract');
  const tractsJeanLou = tractsDispos.filter(i => i.origineQuete === 'jean_lou');
  const tractsGeneriques = tractsDispos.filter(i => i.origineQuete !== 'jean_lou');
  if (tractsGeneriques.length > 0 && tractsJeanLou.length === 0) {
    if (isPJ) {
      actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');donnerTracts(\'' + pnjSafeName + '\')"><i class="ti ti-files" style="font-size:.85rem"></i> Donner des tracts</button>';
    } else {
      actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');distribuerTractElectoralPNJ(\'' + pnjSafeName + '\')"><i class="ti ti-file-description" style="font-size:.85rem"></i> Distribuer un tract électoral</button>';
    }
  }
  // Tracts calomnieux (lot du 24 aout 2026) : distinct du circuit electoral ci-dessus (type
  // 'tract_calomnieux', pas 'tract'), aucun verrouillage electoral applicable. Uniquement pour
  // les PNJ presents (pas de transfert a un vrai PJ demande pour ce type).
  if (!isPJ) {
    const tractsCalomnieuxDispos = (state.inventory || []).filter(i => i.type === 'tract_calomnieux' && (i.quantite || 0) > 0);
    if (tractsCalomnieuxDispos.length > 0) {
      actionBtns += '<button class="pnj-action-btn" style="color:#cc4444;border-color:#8a2020" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');distribuerTractCalomnieuxPNJ(\'' + pnjSafeName + '\')"><i class="ti ti-alert-triangle" style="font-size:.85rem"></i> Distribuer un tract calomnieux</button>';
    }
  }
  if (!isPJ && tractsJeanLou.length > 0 && state.char?.queteCarriere?.ambition === 'politique'
      && state.char.queteCarriere.etape === 'tracts_recus'
      && !(state.char.queteCarriere.ciblesJeanLou || []).includes(pnjSafeName)) {
    actionBtns += '<button class="pnj-action-btn" style="color:#C9A84C;border-color:#8a6a20" onclick="distribuerTractJeanLou(\'' + pnjSafeName + '\')"><i class="ti ti-file-description" style="font-size:.85rem"></i> Distribuer un tract (mission Jean-Lou)</button>';
  }

  if (pnj.rel === 'enemy') {
    actionBtns += '<button class="pnj-action-btn" onclick="talkToPnj(\'' + enc + '\', \'confrontation\')"><i class="ti ti-sword" style="font-size:.85rem"></i> Confronter</button>';
  }

  // Interrogatoire cible (Phase 4 memoire, 22 aout 2026) : reserve aux postes enqueteurs/juges
  // (V1 validee -- commissaire = policier/enqueteur habilite du jeu, juge). Gate cote client
  // uniquement, meme convention que tous les autres ordres a requiresPost de ce projet (aucune
  // verification de poste cote serveur nulle part ailleurs non plus). Mecanique DISTINCTE de
  // "Interroger un detenu" (data.js:4314, gain d'INF, commissariat) et de la torture du QHS
  // (appliquerSentence 'torture', sanction judiciaire) -- aucune des deux n'est touchee ici.
  // Applicable a tout PNJ (jamais un PJ reel, hors perimetre de ce lot).
  if (!isPJ && (state.poste?.id === 'commissaire' || state.poste?.id === 'juge')) {
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirModalInterrogatoireSujet(\'' + pnjSafeName + '\',\'' + (pnj.job || 'default').replace(/'/g,'') + '\')"><i class="ti ti-message-question" style="font-size:.85rem"></i> Interroger sur un sujet</button>';
  }

  // Recruter comme employé (tous PNJ sauf escort qui a son propre bouton)
  if (!isPJ && pnj.job !== 'escort' && pnj.job !== 'codetenu') {
    const nomCourt = pnj.name.replace(' (PNJ)', '').replace(/'/g, '');
    const dejEmploye = (state.employes || []).some(e => e.nom === nomCourt);
    if (!dejEmploye) {
      actionBtns += '<button class="pnj-action-btn" onclick="ouvrirModalRecrutPnj(\'' + enc + '\')"><i class="ti ti-user-plus" style="font-size:.85rem"></i> Recruter comme employé</button>';
    } else {
      const empData = (state.employes || []).find(e => e.nom === nomCourt);
      if (empData && !empData.inGroupe && empData.buildingId === state.currentBuilding && empData.roomId === state.currentRoom) {
        actionBtns += '<button class="pnj-action-btn" onclick="recupererPnjDansGroupe(\'' + nomCourt + '\')"><i class="ti ti-users" style="font-size:.85rem"></i> Rejoindre le groupe</button>';
      }
      if (empData && empData.inGroupe) {
        actionBtns += '<button class="pnj-action-btn" onclick="laisserPnjEnPlace(\'' + nomCourt + '\')"><i class="ti ti-map-pin" style="font-size:.85rem"></i> Laisser ici</button>';
      }
      // Fiche informateur (correctif visibilite, 22 aout 2026) : bloc d'information dedie, meme
      // convention que les blocs job==='escort'/'codetenu'/'hotesse_objets_trouves' plus bas --
      // un texte insere dans actionBtns, jamais un nouveau systeme de dialogue. Aucune IA, aucune
      // donnee inventee : relit directement l'entree reelle de state.employes (empData deja
      // calculee ci-dessus), les memes cout/PER fixes a son recrutement (doRecruterInformateurPNJ).
      // L'effet mecanique (moyenne de PER du groupe, getStatEffective('PER')) reste inchange --
      // ce bloc ne fait que le rendre visible.
      if (pnj.job === 'informateur' && empData) {
        actionBtns += '<div style="margin-top:.6rem;padding:.6rem .7rem;border:1px solid #3a2a10;background:#0f0d05;font-size:.75rem;color:#c0b090;line-height:1.6">' +
          '<div style="font-family:Bebas Neue,sans-serif;letter-spacing:.08em;color:#C9A84C;margin-bottom:.3rem">🕵️ Informateur</div>' +
          'PER ' + (empData.stats?.PER ?? '?') + ' · ' + (empData.cout || 0) + ' FR/jour' +
          '<div style="margin-top:.3rem;color:#9a8a68;font-style:italic">' +
          (empData.inGroupe
            ? 'Sa PER est actuellement intégrée à celle de votre groupe pour les recherches, enquêtes et localisations.'
            : 'Laissé ici : sa PER ne renforce plus votre groupe tant qu\'il n\'est pas rejoint.') +
          '</div></div>';
      }
    }
  }

  // Recruter escort
  if (pnj.job === 'escort') {
    const escortNom = pnj.name.replace(' (PNJ)', '').replace(/'/g, '');
    const escortGenre = pnj.genre || 'F';
    const escortActiveInfo = (state.escortActive || []).find(e => e.nom === escortNom);
    if (escortActiveInfo) {
      actionBtns += '<button class="pnj-action-btn" onclick="confirmerRenvoyerEscort(\'' + escortNom + '\')"><i class="ti ti-heart-off" style="font-size:.85rem"></i> Renvoyer</button>';
    } else {
      actionBtns += '<button class="pnj-action-btn" onclick="ouvrirRecrutementEscort(\'' + escortNom + '\',\'' + escortGenre + '\',\'' + (pnj.photoUrl || '') + '\')"><i class="ti ti-heart" style="font-size:.85rem"></i> Recruter comme escort (800 FR/j)</button>';
    }
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirModalFabriquerKompromat(\'' + escortNom + '\')"><i class="ti ti-file-shredder" style="font-size:.85rem"></i> Fabriquer un kompromat (300 FR)</button>';
    actionBtns += '<button class="pnj-action-btn" style="color:#cc6699;border-color:#4a1a30" onclick="ouvrirModalFaireLAmour(\'' + escortNom + '\')"><i class="ti ti-heart-filled" style="font-size:.85rem"></i> Faire l\'amour</button>';
    // Secret contre secret (Phase 3 memoire, 22 aout 2026) : precondition volontairement
    // INDEPENDANTE de "Faire l'amour" -- accessible des que le PJ peut interagir avec l'escort,
    // jamais liee a escortActiveInfo (l'embauche reste exclusive a "Faire l'amour", precision
    // explicite du game design -- ne pas mutualiser les deux preconditions).
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirModalSecretContreSecret(\'' + escortNom + '\')"><i class="ti ti-message-2-heart" style="font-size:.85rem"></i> Secret contre secret</button>';
  }

  // Recruter codetenu
  if (pnj.job === 'codetenu') {
    const codetenuNom = pnj.name.replace(' (PNJ)', '').replace(/'/g, '');
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirRecrutementCodetenu(\'' + codetenuNom + '\')"><i class="ti ti-users" style="font-size:.85rem"></i> Faire alliance (100 FR/j)</button>';
  }

  // Interroger l'hotesse des objets trouves sur ses souvenirs
  if (pnj.job === 'hotesse_objets_trouves') {
    actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');ouvrirModalInterrogerAccueil()"><i class="ti ti-message-question" style="font-size:.85rem"></i> Demander des confidences</button>';
  }

  const encCible = encodePnjSafe(pnj);
  actionBtns += '<button class="pnj-action-btn" style="color:#aa7a30;border-color:#3a2810" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');ouvrirModalVoler(\'' + encCible + '\')"><i class="ti ti-fingerprint" style="font-size:.85rem"></i> Voler</button>';
  actionBtns += '<button class="pnj-action-btn" style="color:#cc4444;border-color:#3a1010" onclick="document.getElementById(\'modal-pnj\').classList.remove(\'open\');ouvrirModalAssassinat(\'' + encCible + '\')"><i class="ti ti-skull" style="font-size:.85rem"></i> Assassiner</button>';
  // Quete carriere (Pat Hounette / Jean-Lou Zeure / Laurent Barre) — independante du systeme
  // de quete/enquete generique ci-dessous (state.char.queteCarriere, pas state.quetes).
  if (!isPJ && typeof genererZoneCarriereHtml === 'function') {
    actionBtns += genererZoneCarriereHtml(pnj);
  }

  actionBtns += '<div id="quete-action-zone"></div>';
  // Verifier de facon non bloquante si ce PNJ correspond a une quete active
  if (!isPJ && typeof getQueteActivePourPnj === 'function') {
    const nomPnjPourQuete = pnj.name?.replace(' (PNJ)', '');
    getQueteActivePourPnj(nomPnjPourQuete).then(quete => {
      const zone = document.getElementById('quete-action-zone');
      if (zone && quete) {
        zone.innerHTML = '<button class="pnj-action-btn" style="color:#C9A84C;border-color:#8a6a20;font-weight:bold" onclick="progresserQuete(&quot;' + quete.id + '&quot;)"><i class="ti ti-search" style="font-size:.85rem"></i> 🔍 Suivre la piste (' + quete.titre + ')</button>';
      }
    }).catch(() => {});
  }
  document.getElementById('pnj-actions').innerHTML = actionBtns +
    (isPJ
      ? '<div style="margin-top:.6rem;font-size:.7rem;color:#6a5a30;font-style:italic">C\'est un vrai joueur — utilisez "Parler" (chat en temps réel) ou le mail (asynchrone). L\'IA ne répond jamais à sa place.</div>'
      : '<div style="display:flex;gap:.4rem;margin-top:.5rem">' +
        '<input id="pnj-question-libre" type="text" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" placeholder="Posez votre question..." onkeydown="handlePnjKey(event)" />' +
        '<button onclick="envoyerQuestion()" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-send" style="font-size:.8rem"></i></button>' +
        '</div>');

  // Stocker l'enc pour envoyerQuestion
  state._currentPnjEnc = enc;

  // Recharger l'historique de la conversation du jour (uniquement pour les PNJ — jamais pour un vrai joueur)
  if (!isPJ) {
    const pnjNameClean = pnj.name?.replace(' (PNJ)', '').trim();
    const convKeyOpen = 'conv_' + (pnjNameClean||'pnj') + '_day' + (state.day||1);
    const histOpen = state.pnjConversations?.[convKeyOpen] || [];

    if (pnjNameClean === 'Jérémy' && histOpen.length >= 2) {
      // Ne jamais reafficher la derniere reponse pour Jeremy (peut preter a confusion selon
      // le lieu/contexte au moment de la reouverture) : on repart sur une invitation neutre.
      const speechElJeremy = document.getElementById('pnj-speech');
      if (speechElJeremy) speechElJeremy.textContent = 'Une autre question ?';
    } else if (histOpen.length >= 2 && pnj.job !== 'escort') {
      // Afficher le dernier échange
      const lastReply = histOpen.filter(h => h.role === 'assistant').slice(-1)[0];
      if (lastReply) {
        const speechEl = document.getElementById('pnj-speech');
        if (speechEl) speechEl.textContent = lastReply.content;
      }
    } else {
      talkToPnj(enc, 'bonjour');
    }
  } else {
    const speechEl = document.getElementById('pnj-speech');
    if (speechEl) speechEl.textContent = '';
  }
}

function handlePnjKey(event) {
  if (event.key === 'Enter') envoyerQuestion();
}

function envoyerQuestion(enc) {
  const input = document.getElementById('pnj-question-libre');
  if (!input) return;
  const q = input.value.trim();
  if (!q) return;
  input.value = '';
  const encToUse = enc || state._currentPnjEnc;
  if (encToUse) talkToPnj(encToUse, q);
}

async function talkToPnj(encodedPnj, action) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); }
  catch(e) { return; }

  if (!action || action.trim() === '') return;

  const speech = document.getElementById('pnj-speech');
  speech.innerHTML = '<div class="pnj-loading"><span class="spin"></span> En train de repondre...</div>';

  const char = state.char;
  const co = COUNTRIES[state.country];

  // Gestion speciale loge
  if (pnj.job === 'portier' && action === 'bonjour') {
    speech.textContent = 'Le portier vous devisage longuement a travers le judas. "Que voulez-vous ?"';
    document.getElementById('pnj-actions').innerHTML += `
      <div style="margin-top:.8rem;border-top:1px solid #2a2010;padding-top:.8rem">
        <div style="font-size:.72rem;color:#6a5a20;font-family:'Bebas Neue',sans-serif;letter-spacing:.1em;margin-bottom:.4rem">REPONDRE :</div>
        <button class="pnj-action-btn" onclick="logeDemanderResponsable()">
          <i class="ti ti-user-star" style="font-size:.85rem"></i> Je veux parler au responsable de la loge
        </button>
        <button class="pnj-action-btn" onclick="logeDemanderAdhesion()">
          <i class="ti ti-user-plus" style="font-size:.85rem"></i> Je veux faire partie des votres
        </button>
      </div>`;
    return;
  }

  // Maxence Monfils : limite de 2 questions avant qu'il ne detale vers l'autre lieu (parc/serre).
  const nomCourtMaxence = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (nomCourtMaxence === 'Maxence Monfils' && action !== 'bonjour') {
    if (!state.char.maxence) state.char.maxence = { lieu: 'parc', questions: 0 };
    state.char.maxence.questions = (state.char.maxence.questions || 0) + 1;
    if (typeof verifierSuccesMaxence === 'function') verifierSuccesMaxence('parle');

    if (state.char.maxence.questions > 2) {
      speech.textContent = "Maxence n'est plus là... il a déjà détalé ailleurs.";
      return;
    }
    if (state.char.maxence.questions === 2) {
      const autreLieu = state.char.maxence.lieu === 'parc' ? 'serre' : 'parc';
      setTimeout(function() {
        if (!state.char.maxence) return;
        state.char.maxence.lieu = autreLieu;
        state.char.maxence.questions = 0;
        if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
        if (typeof showToast === 'function') {
          showToast('Maxence a détalé', 'Il est parti vers ' + (autreLieu === 'serre' ? 'la serre' : 'le parc') + '...', false);
        }
        if (typeof maxenceVerifierPresence === 'function') {
          maxenceVerifierPresence(state.currentBuilding, state.currentRoom);
        }
      }, 4000);
    }
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  }

  // Legende urbaine de Maxence Monfils : rumeurs independantes de toute enigme, tant que
  // le joueur mentionne son nom, aupres de quelques PNJ qui le "surveillent" sans jamais
  // vraiment le trouver. Le mystere ne doit jamais etre tranche.
// Deux succes caches lies a Maxence Monfils, universels (independants de l'archetype du
// joueur, contrairement au systeme OBJECTIFS_SECRETS). Stockes sur state.char.succesMaxence.
function verifierSuccesMaxence(cle) {
  if (typeof state === 'undefined' || !state.char) return;
  if (!state.char.succesMaxence) state.char.succesMaxence = { parle: false, rumeurs: [] };

  if (cle === 'parle' && !state.char.succesMaxence.parle) {
    state.char.succesMaxence.parle = true;
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});
    if (typeof showToast === 'function') showToast('🎯 Succès débloqué', 'Le fugitif du jardin botanique', true);
    if (typeof addJournalEntry === 'function') addJournalEntry('🎯 Succès débloqué : Le fugitif du jardin botanique', 'event-good');
    return;
  }

  if (cle && cle !== 'parle' && !state.char.succesMaxence.rumeurs.includes(cle)) {
    state.char.succesMaxence.rumeurs.push(cle);
    const toutesLesRumeurs = ['pat', 'florian', 'ciseaux', 'chevillard', 'garde'];
    const complet = toutesLesRumeurs.every(function(n) { return state.char.succesMaxence.rumeurs.includes(n); });
    if (complet && !state.char.succesMaxence.legendeUrbaine) {
      state.char.succesMaxence.legendeUrbaine = true;
      if (typeof showToast === 'function') showToast('🎯 Succès débloqué', 'Légende urbaine', true);
      if (typeof addJournalEntry === 'function') addJournalEntry('🎯 Succès débloqué : Légende urbaine', 'event-good');
    }
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});
  }
}

  const nomCourtMaxenceRumeur = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (/maxence/i.test(action)) {
    if (nomCourtMaxenceRumeur === 'Pat Hounette') {
      speech.textContent = "Chut... si Maxence apprend qu'il y a des scarabées ici, on est mal...";
      if (typeof verifierSuccesMaxence === 'function') verifierSuccesMaxence('pat');
      return;
    }
    if (nomCourtMaxenceRumeur === 'Florian Grès') {
      speech.textContent = "Je le surveille depuis ce matin. Impossible de savoir où il est passé...";
      if (typeof verifierSuccesMaxence === 'function') verifierSuccesMaxence('florian');
      return;
    }
    if (nomCourtMaxenceRumeur === 'Jean-Pierre Ciseaux') {
      speech.textContent = "Les orchidées ne risquent rien... ce sont les insectes qui m'inquiètent.";
      if (typeof verifierSuccesMaxence === 'function') verifierSuccesMaxence('ciseaux');
      return;
    }
    if (nomCourtMaxenceRumeur === 'Louis Chevillard') {
      speech.textContent = "En quarante ans de carrière, j'ai vu des braqueurs, des meurtriers... mais Maxence... celui-là me fait froid dans le dos.";
      if (typeof verifierSuccesMaxence === 'function') verifierSuccesMaxence('chevillard');
      return;
    }
    if (nomCourtMaxenceRumeur === 'Garde Republicain') {
      speech.textContent = "J'ai déjà tenu tête à des manifestants, des émeutiers, même un coup d'État... Mais si je croise Maxence Monfils dans une ruelle un jour, je change de trottoir, foi de Garde Républicain.";
      if (typeof verifierSuccesMaxence === 'function') verifierSuccesMaxence('garde');
      return;
    }
  }

  // Enigme du portrait disparu : Claire Delhune (notaire, ex-"Clerc Delhune" -- renommee lors de
  // la refonte du notaire du 20 aout 2026, reference mise a jour ici pour ne pas casser le
  // parcours) et Laurent Barre (banquier), temoignages parles en complement des archives ecrites.
  const nomCourtEnigme = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (typeof enigme1EtapeActive === 'function' && enigme1EtapeActive()) {
    if (nomCourtEnigme === 'Claire Delhune' && /thibault/i.test(action)) {
      speech.textContent = "Thibault... Pierre Thibault, c'est ça ? Oui, j'ai eu le dossier de sa succession entre les mains, il y a bien longtemps. De mémoire, il y avait mention d'un coffre à la Banque Nationale, toujours actif d'ailleurs. Pour le détail exact, il faudra consulter les archives notariales.";
      return;
    }
    if (nomCourtEnigme === 'Laurent Barre' && /coffre|thibault/i.test(action)) {
      speech.textContent = "Un coffre lié à cette succession ? Oui, la location n'a jamais été interrompue depuis... eh bien, depuis très longtemps. Mais je ne peux vous dire qui la règle aujourd'hui — secret bancaire, vous comprenez. Il vous faudrait une autorisation en bonne et due forme pour aller plus loin.";
      return;
    }
  }

  // Enigme du portrait disparu : temoignages scriptes des 3 pensionnaires de l'EHPAD.
  // Ne se declenchent que si l'enigme est active (evite un texte hors-sujet sinon).
  const nomCourtEhpad = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (typeof enigme1EtapeActive === 'function' && enigme1EtapeActive()) {
    if (nomCourtEhpad === 'Jeanine Dubois' && /thibault|élise|elise/i.test(action)) {
      speech.textContent = "Ah, mes années à l'école... j'en ai vu passer, des enfants ! Thibault... Thibault... Attendez, laissez-moi réfléchir. Oui ! Une petite fille très sage, toujours au premier rang, qui écrivait d'une belle main. Élise, je crois bien qu'elle s'appelait.\nSes parents étaient agriculteurs. Il y a eu un drame dans la famille, et la petite Élise a dû partir travailler dans une maison. Pauvre gamine.\nMais si vous cherchez des informations sur elle, pourquoi vous n'allez pas consulter l'état-civil à la mairie ? Ils ont tout là-bas.";
      if (typeof enigme1DossierCocherCase === 'function') enigme1DossierCocherCase('ehpad_dubois');
      return;
    }
    if (nomCourtEhpad === 'Louis Chevillard' && /caillon/i.test(action)) {
      speech.textContent = "Caillon... oh que oui ce nom me dit quelque chose, forcément, j'ai fait trente ans dans la police. Une drôle d'affaire, à l'époque, l'assassinat d'un conseiller municipal, je me souviens qu'on en parlait beaucoup au commissariat. Un crime à Luthécia, c'est pas si courant quand même.\nOn l'a arrêté, ça j'en suis sûr, et puis... remis en liberté plus tard, je crois. Un acquittement, je ne sais plus exactement. Pourtant, c'était une vraie crapule ce type. Il était impliqué dans toute sorte de trafics. À la fin, il avait été embauché comme gardien sur l'usine de Moulin. On n'a jamais trop cru au fait qu'il s'était rangé des affaires...\nÀ mon âge, la mémoire flanche un peu, mais le commissariat, lui, n'oublie jamais rien. Le dossier doit toujours être dans les archives.";
      if (typeof enigme1DossierCocherCase === 'function') enigme1DossierCocherCase('ehpad_chevillard');
      return;
    }
    if (nomCourtEhpad === 'Noël Chauchay' && /thibault/i.test(action)) {
      speech.textContent = "Thibault ? Ah oui, le père Thibault ! Bien sûr que je m'en souviens, on se croisait tout le temps au marché, avant. Une belle terre qu'il avait, avec des patates comme j'en ai jamais revu depuis — le meilleur producteur du coin à l'époque, croyez-moi.\nEt puis... un jour, plus rien. On lui a pris sa terre. Fini les patates, fini le marché, on ne l'a plus revu du tout jusqu'à ce qu'on apprenne qu'il s'était pendu dans sa grange.\nQuel malheur, cet homme-là. On disait des choses, à l'époque, mais on ne devrait peut-être pas trop répéter les ragots d'un vieux comme moi.";
      if (typeof enigme1DossierCocherCase === 'function') enigme1DossierCocherCase('ehpad_chauchay');
      return;
    }
  }

  // Quete d'accueil : reponse d'accueil scriptee de Jeremy a la toute premiere ouverture de sa
  // fiche (action 'bonjour', envoyee automatiquement par openPnjModal). Pour toute question
  // reelle ensuite, on laisse l'IA repondre normalement (avec le contexte special ci-dessus).
  const nomCourtPnjJeremy = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (nomCourtPnjJeremy === 'Jérémy' && action === 'bonjour') {
    speech.textContent = "Vous avez des questions ? Je peux vous aider, Monsieur Petit sera fier de moi.";
    return;
  }

  // Rappel de l'etape en cours de la quete d'accueil, si le joueur se sent perdu (clic trop
  // rapide, popup fermee sans lire...). Rejoue le meme message et la meme surbrillance que
  // ceux affiches au demarrage de l'etape en cours.
  if (nomCourtPnjJeremy === 'Jérémy' && action !== 'bonjour' && /où en (?:étions|sommes)|rappel|perdu|que dois-je faire|je ne sais plus|c'était quoi déjà/i.test(action)) {
    if (typeof queteAccueilRappel === 'function' && queteAccueilRappel()) {
      speech.textContent = "Ah, vous vous êtes un peu perdu ? Pas de souci, je vous remontre.";
      return;
    }
  }

  // Sophie Stiquay (infirmiere, accueil de la clinique privee de Luthecia) : reponse scriptee sur
  // les visites/chambres (finalisation chambres clinique, 31 aout 2026) -- meme mecanisme deja
  // utilise pour Jeremy/Maxence/les temoins de l'enigme (nom court + regex sur l'action), jamais
  // un second moteur de dialogue. Volontairement hors-IA pour garantir un message toujours exact,
  // sans ID technique ni mention de locations_actives.
  const nomCourtSophie = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (nomCourtSophie === 'Sophie Stiquay' && /voir|visiter|visite|rendre visite|chambre|patient/i.test(action)) {
    speech.textContent = "Les chambres sont privées, on n'y entre pas comme ça. Passez par l'ordre « Chambres » ici même, à l'accueil : si vous êtes vous-même hospitalisé(e), vous rejoindrez directement votre chambre. Sinon, vous y verrez la liste des patients qui acceptent actuellement des visites — un patient reste toujours libre de les refuser, question de tranquillité.";
    return;
  }

  // Quete d'accueil : reponse scriptee du Secretaire Municipal Petit quand un nouveau joueur se presente.
  // Reponse fixe (pas d'IA) pour garantir la progression de la quete a ce moment charniere.
  if (pnj.name === 'Secretaire Municipal Petit'
      && typeof state !== 'undefined' && state.char && state.char.queteAccueil
      && state.char.queteAccueil.etape === 'attente_entree_mairie'
      && /nouveau|nouvelle|nouvellement/i.test(action)) {
    speech.textContent = "Ah, un petit nouveau ! Vous allez avoir besoin d'aide pour découvrir la ville, j'imagine. Ça tombe bien, on a un jeune stagiaire ici qu'on ne sait pas comment occuper. En plus il ne sait pas faire un bon café, mais par contre, il est originaire de la ville. En fait... (en parlant tout bas) c'est le neveu du Maire, on n'a pas eu d'autre choix que de le prendre... Jérémy ! Viens par ici, on a une mission pour toi ! Tu vas accompagner " + (state.char.name || 'vous') + " dans la ville. (se tournant vers vous) Enfin si vous êtes d'accord bien sûr. Vous voulez l'aide de Jérémy ?";
    document.getElementById('pnj-actions').innerHTML = `
      <div style="margin-top:.8rem;border-top:1px solid #2a2010;padding-top:.8rem">
        <button class="pnj-action-btn" onclick="closePnjModal(); queteAccueilAccepterJeremy();">
          <i class="ti ti-check" style="font-size:.85rem"></i> Oui, j'accepte l'aide de Jérémy
        </button>
        <button class="pnj-action-btn" onclick="closePnjModal(); queteAccueilRefuserJeremy();">
          <i class="ti ti-x" style="font-size:.85rem"></i> Non merci
        </button>
      </div>`;
    return;
  }

  // Branche criminelle (Pat Hounette) : declenchement de la mission des que le joueur mentionne
  // Jeremy dans une question libre, quelle que soit l'orthographe (accent ou non). Reponse fixe
  // (pas d'IA) pour garantir la progression, meme pattern que le Secretaire Petit ci-dessus.
  // Gate sur l'etape pour ne jamais redeclencher (ni redonner un colis) une fois la mission
  // commencee ou terminee.
  const nomCourtPat = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (nomCourtPat === 'Pat Hounette' && action !== 'bonjour'
      && state.char?.queteCarriere?.ambition === 'criminel'
      && state.char.queteCarriere.etape === 'a_rencontrer'
      && /j[ée]r[ée]my/i.test(action)) {
    if (typeof declencherMissionPatHounette === 'function') declencherMissionPatHounette();
    return;
  }

  // Branche criminelle (Pat Hounette) : retour apres livraison a Brigitte, declenche par la
  // question libre plutot que par un bouton dedie (retire le 17 aout 2026 -- eviter de
  // multiplier les ordres specifiques a une etape de quete). Normalisation identique a celle
  // deja utilisee ailleurs dans le code pour ignorer accents/casse (voir supabase.js, generation
  // de slug) : minuscules + suppression des diacritiques, puis un seul test sur les racines
  // (ex. "merci" couvre aussi "remercie(r)"/"remercie" et "remerciement(s)" par inclusion).
  // Gate sur l'etape : ne se declenche qu'a colis_livre, jamais avant (ne termine pas la quete
  // prematurement) ni apres (ne rejoue pas le debrief une fois terminee).
  if (nomCourtPat === 'Pat Hounette' && action !== 'bonjour'
      && state.char?.queteCarriere?.ambition === 'criminel'
      && state.char.queteCarriere.etape === 'colis_livre') {
    const actionNormalisee = action.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
    if (/merci|menotte|brigitte|colis/.test(actionNormalisee)) {
      if (typeof patHounetteRetour === 'function') patHounetteRetour();
      return;
    }
  }

  // Branche politique (Jean-Lou Zeure) : reponse scriptee (pas d'IA) a l'ouverture de sa fiche,
  // ton desabus\u00e9 de chomeur plutot que le ton d'autorite que l'IA pouvait prendre a tort a
  // cause du lieu (Bureau National de l'Emploi -- il y est demandeur d'emploi, pas employe).
  const nomCourtJeanLou = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (nomCourtJeanLou === 'Jean-Lou Zeure' && action === 'bonjour') {
    speech.textContent = "Vous aussi vous cherchez un boulot bien planqu\u00e9 et pas trop mal pay\u00e9 ? Attention, on est deux sur le coup.";
    return;
  }

  // Branche politique (Jean-Lou Zeure) : declenchement de la mission des que le joueur
  // mentionne Jeremy, quelle que soit l'orthographe (accent, ou variante "Jeremie"/"J\u00e9r\u00e9mie").
  // Meme pattern que Pat Hounette ci-dessus.
  if (nomCourtJeanLou === 'Jean-Lou Zeure' && action !== 'bonjour'
      && state.char?.queteCarriere?.ambition === 'politique'
      && state.char.queteCarriere.etape === 'a_rencontrer'
      && /j[\u00e9e]r[\u00e9e]m(y|ie)/i.test(action)) {
    if (typeof declencherMissionJeanLou === 'function') declencherMissionJeanLou();
    return;
  }

  // Branche entrepreneuriale (Laurent Barre) : declenchement de la mission des que le joueur
  // mentionne Jeremy, meme pattern que Pat/Jean-Lou ci-dessus.
  const nomCourtLaurent = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (nomCourtLaurent === 'Laurent Barre' && action !== 'bonjour'
      && state.char?.queteCarriere?.ambition === 'entrepreneurial'
      && state.char.queteCarriere.etape === 'a_rencontrer'
      && /j[ée]r[ée]m(y|ie)/i.test(action)) {
    if (typeof declencherMissionLaurent === 'function') declencherMissionLaurent();
    return;
  }

  // Branche entrepreneuriale : l'agent immobilier (Notaire Fontenelle, office notarial) ou le
  // promoteur (Gerard Speculos et equivalents, PNJ id:'promoteur') valident l'etape de mission
  // des que le joueur demande a negocier le prix d'une parcelle/terrain -- reconnaissance
  // souple (racines negoci/prix/parcelle/terrain), pas de phrase exacte requise. Meme
  // normalisation (accents/casse) que le reste de ce fichier.
  if ((nomCourtLaurent === 'Notaire Fontenelle' || nomCourtLaurent === 'Gérard Spéculos' || nomCourtLaurent === 'Don Ladrillo' || nomCourtLaurent === 'Camarade Bâtissov' || nomCourtLaurent === 'Cheikh Al-Bâtisseur')
      && action !== 'bonjour'
      && state.char?.queteCarriere?.ambition === 'entrepreneurial'
      && state.char.queteCarriere.etape === 'negociation_demandee') {
    const actionNormaliseeNego = action.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
    if (/negoci|prix|parcelle|terrain/.test(actionNormaliseeNego)) {
      if (typeof repondreNegociationParcelle === 'function') repondreNegociationParcelle(pnj);
      return;
    }
  }

  // Actions predefinies
  const actionMap = {
    'bonjour':       'vous salue a son arrivee',
    'information':   'lui demande des informations sur la situation politique locale',
    'alliance':      'lui propose une alliance politique discrete',
    'confrontation': 'le confronte directement en lui reprochant ses actions'
  };
  const actionDesc = actionMap[action] || `lui pose la question suivante : "${action}"`;
  const isQuestion = !actionMap[action];

  // Si c'est un journaliste, générer une réaction au forum
  const pnjKey = pnj.name?.replace(' (PNJ)', '').trim();
  const isJournaliste = pnj.job === 'journaliste' || pnj.job === 'redacteur';
  if (isJournaliste && !action) {
    const reaction = await genererReactionJournaliste();
    if (reaction) {
      const speech = document.getElementById('pnj-speech');
      if (speech) speech.textContent = reaction.texte;
      return;
    }
  }

  // Fiche personnalité du PNJ (+ profil enrichi facultatif, meme cle — voir PNJ_PROFILS)
  const perso = PNJ_PERSONALITIES[pnjKey];
  const profil = (typeof PNJ_PROFILS !== 'undefined') ? PNJ_PROFILS[pnjKey] : null;
  const empireStyle = EMPIRE_STYLES[state.country] || EMPIRE_STYLES.republic;

  // Récupérer les derniers posts du forum local pour le contexte
  const recentPosts = (FORUM_TOPICS['local'] || []).slice(0, 2).map(t =>
    `"${t.title}" (par ${t.author})`).join(', ');
  const forumContext = recentPosts ? `Actualité du forum local : ${recentPosts}.` : '';

  // Événements politiques
  const politicalContext = state.poste
    ? `Le joueur occupe le poste de ${state.poste.name}.`
    : 'Le joueur n\'a pas de poste officiel.';
  const recherchéContext = state.recherche?.length > 0
    ? 'ATTENTION : le joueur est recherché par les autorités.'
    : '';

  const autresJoueursPresents = (window._vraisJoueursPresents || []).map(p => p.name).filter(Boolean);
  const autresJoueursTexte = autresJoueursPresents.length > 0
    ? `D'autres personnes sont egalement presentes dans la piece en ce moment : ${autresJoueursPresents.join(', ')}. Tu peux naturellement faire reference a leur presence si c'est pertinent dans ta reponse.`
    : '';

  const lieuBatiment = BUILDINGS[state.currentBuilding]?.name || '';
  const lieuPiece = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom]?.name || '';
  const lieuTexte = lieuBatiment ? (lieuBatiment + (lieuPiece ? ' (' + lieuPiece + ')' : '')) : '';

  // Marcel Ancre (lot logistique portuaire, 25 aout 2026, §16) : talkToPnj() n'injecte par
  // defaut AUCUNE donnee economique dynamique (audit confirme) -- laisser le modele improviser
  // des chiffres reels aurait garanti des inventions. Ici, les faits reels sont calcules AVANT
  // le prompt (etat.port/caisse du port, meme source que ouvrirConsulterPort,
  // plateau-justice-economie.js) et injectes comme des faits enonces, jamais laisses au modele.
  // Volontairement PAS de diagnostic "deficitaire/equilibre/excedentaire" : aucun suivi recettes/
  // depenses fiable n'existe encore (seul le solde instantane est connu) -- l'instruction dans le
  // prompt lui interdit explicitement d'en deduire un. Architecture prete pour un futur suivi.
  let contextePortMarcelAncre = '';
  if (pnjKey === 'Marcel Ancre' && state.country === 'republic' && typeof getEtatPort === 'function') {
    const port = await getEtatPort().catch(() => null);
    if (port) {
      const stockTxt = (typeof RESSOURCES_PORT_IMPORTEES !== 'undefined' ? RESSOURCES_PORT_IMPORTEES : [])
        .filter(cle => (port.stock?.[cle] || 0) > 0)
        .map(cle => (RESSOURCES_ECONOMIE[cle]?.label || cle) + ' : ' + Math.round(port.stock[cle]))
        .join(', ') || 'aucun stock institutionnel en attente de répartition';
      const caissePort = typeof chargerCaisseBatiment === 'function'
        ? await chargerCaisseBatiment('republic', BUILDING_ID_PORT).catch(() => ({ solde: 0 }))
        : { solde: 0 };
      const arrivagesTxt = (port.arrivages || []).slice(0, 3)
        .map(a => (RESSOURCES_ECONOMIE[a.resource]?.label || a.resource) + ' +' + Math.round(a.qte))
        .join(', ') || 'aucun arrivage récent enregistré';
      const exportsTxt = Object.entries(typeof EXPORTATIONS_PORT_INFOS !== 'undefined' ? EXPORTATIONS_PORT_INFOS : {})
        .map(([cle, infos]) => {
          const exp = port.exportations?.[cle];
          return exp ? (infos.label + ' vers ' + infos.destination + ' : ' + Math.round(exp.envoye) + '/' + exp.contrat + ' (' + exp.satisfactionPct + '%)') : null;
        }).filter(Boolean).join(' ; ') || 'aucune exportation enregistrée pour l\'instant';
      contextePortMarcelAncre = `Faits réels et actuels sur la situation du port, à utiliser tels quels sans jamais en inventer d'autres : solde de la caisse du port ${Math.round(caissePort.solde || 0)} FR ; stock institutionnel en attente de répartition : ${stockTxt} ; arrivages récents : ${arrivagesTxt} ; exportations : ${exportsTxt}. Tu ne disposes d'AUCUN suivi fiable des recettes/dépenses passées : ne dis JAMAIS que le port est "déficitaire", "équilibré" ou "excédentaire" — contente-toi d'énoncer les faits ci-dessus.`;
    }
  }

  const prompt = `Tu joues un personnage dans Res Publica, un jeu de rôle politique parodique et satirique.
L'empire est ${co?.n} (${empireStyle.tone}).
La religion locale est ${empireStyle.religion}. Le chef suprême est ${empireStyle.leader}.

Ton personnage : ${pnj.name?.replace(' (PNJ)', '')}, ${pnj.role}.
${perso ? `Ta personnalité : ${perso.trait}` : `Tu es un PNJ typique de ${co?.n}.`}
${perso ? `Ton style : ${perso.style}` : ''}
${profil?.traits?.length ? `Traits de caractère : ${profil.traits.join(', ')}.` : ''}
${profil?.savoirs ? `Ce que tu sais réellement : ${profil.savoirs}` : ''}
${profil?.fonctionPedagogique ? `Tu es chargé d'expliquer au joueur : ${profil.fonctionPedagogique}` : ''}
${profil?.secrets ? `Tu connais ceci mais ne le révèle JAMAIS spontanément, seulement si on insiste beaucoup ou qu'on te corrompt : ${profil.secrets}` : ''}
${profil?.objectifs ? `Ta motivation personnelle : ${profil.objectifs}` : ''}
${profil?.rumeurs ? `Rumeurs que tu peux relayer, informations imparfaites : ${profil.rumeurs}` : ''}
${contextePortMarcelAncre}
Relation avec le joueur : ${pnj.rel === 'ally' ? 'allié de confiance' : pnj.rel === 'enemy' ? 'ennemi déclaré' : 'neutre'}.
${lieuTexte ? `Lieu actuel : vous vous trouvez tous les deux à ${lieuTexte}. N'évoque jamais un autre établissement (mairie, commissariat, tribunal...) comme si vous y étiez actuellement.` : ''}
${(pnj.name || '').replace(' (PNJ)', '').trim() === 'Maxence Monfils' ? `Contexte special : tu es un enfant d'une dizaine d'annees, curieux, insaisissable et un peu mysterieux. Tu passes ton temps a observer des insectes et des plantes avec ta loupe. Tu vouvoies ou tutoies selon ton humeur (tu es un enfant, pas tenu a la politesse formelle). Tu ne reponds JAMAIS de facon claire ou directe aux questions ; reste evasif, enigmatique, parfois carrement hors sujet, sans jamais mentir grossierement ni etre desagreable. Tu ne dis jamais explicitement que tu es recherche par des organisations environnementales ni que tu arraches des ailes d'insectes, mais tu peux le suggerer de facon detournee et innocente si on te pose une question qui s'en approche. Reponds en 1 a 2 phrases maximum, jamais plus.` : ''}
${(pnj.name || '').replace(' (PNJ)', '').trim() === 'Jérémy' ? (() => {
  const ordresIci = (BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom]?.orders || [])
    .map(o => '- ' + o.label + (o.desc ? ' : ' + o.desc : ''))
    .join('\n');
  return `Contexte special : tu es actuellement en train de faire visiter la ville a ce nouveau joueur, dans le cadre de son accueil. Tu es un peu maladroit mais serviable et honnete. Tu vouvoies TOUJOURS le joueur, sans exception.
IMPORTANT : fie-toi UNIQUEMENT au "Lieu actuel" indique plus haut pour savoir ou vous etes reellement. Ne dis JAMAIS que vous etes encore a l'Hotel de Ville, ou a un autre endroit deja visite plus tot dans la visite, si le lieu actuel indique autre chose. Si AUCUN lieu actuel n'est indique plus haut (vous etes dans la rue, pas dans un batiment), ne devine JAMAIS un nom de lieu precis (n'invente jamais "Place de la Concorde" ou autre) : dis simplement que vous etes ensemble dans la rue et propose de consulter le bouton PLAN, en haut de l'ecran, pour s'orienter.
Si on te demande un chemin ou une direction vers un lieu que vous n'avez pas encore visite, reponds de facon coherente avec la vraie geographie de Luthecia. Ne donne jamais d'indication de trajet inventee ou incoherente, et ne mentionne jamais d'activites illegales ou de corruption ; si tu n'es pas sur, propose plutot de consulter le bouton PLAN en haut de l'ecran.
${ordresIci ? 'Voici les actions reellement disponibles dans la piece ou vous vous trouvez, utilise-les pour donner des reponses precises et concretes si le joueur te pose une question sur le fonctionnement d\'un lieu ou d\'un mecanisme du jeu :\n' + ordresIci : ''}`;
})() : ''}
${autresJoueursTexte}

Le joueur : ${char?.name || 'Inconnu'}.
${politicalContext} ${recherchéContext}
${forumContext}

${isQuestion ? `Le joueur te pose cette question : "${action}". Réponds en restant dans ton personnage.` : `Le joueur ${actionDesc}.`}

RÈGLES ABSOLUES :
- 2 phrases maximum, jamais plus
- Reste dans ton personnage parodique
- Reste physiquement à l'endroit indiqué ci-dessus, n'évoque aucun autre lieu comme si tu y étais actuellement
- La seule monnaie existante dans cet univers est désignée par le code ${empireStyle.currency} ; n'utilise JAMAIS l'Euro, le Dollar, ni aucune devise du monde réel
- Jamais de vrais noms de dieux ou religions réelles
- Réponds UNIQUEMENT avec ta réplique, sans guillemets ni introduction`;

  // Récupérer l'historique de la conversation du jour
  const pnjKey2 = pnj.name?.replace(' (PNJ)', '').trim();
  const convKey = 'conv_' + (pnjKey2||'pnj') + '_day' + (state.day||1);
  if (!state.pnjConversations) state.pnjConversations = {};
  if (!state.pnjConversations[convKey]) state.pnjConversations[convKey] = [];
  const history = state.pnjConversations[convKey];

  // Construire les messages avec historique
  const messages = [
    { role: 'user', content: prompt }
  ];
  // Ajouter les échanges précédents (max 6 pour rester léger)
  const recentHistory = history.slice(-6);
  if (recentHistory.length > 0) {
    messages[0].content = prompt + '\n\nHistorique du jour :\n' +
      recentHistory.map(h => (h.role === 'user' ? 'Joueur: ' : pnjKey2 + ': ') + h.content).join('\n');
  }

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 150,
        messages
      })
    });
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    const data = await resp.json();
    const text = data.content?.[0]?.text;
    if (text) {
      speech.textContent = text;
      // Sauvegarder dans l'historique
      history.push({ role: 'user', content: action });
      history.push({ role: 'assistant', content: text });
      state.pnjConversations[convKey] = history;
    } else { throw new Error('no text'); }
  } catch(e) {
    const fallbacks = {
      enemy:   ['Circulez, il n\'y a rien a vous dire.', 'Votre presence m\'importune.', 'Je n\'ai rien a declarer.'],
      ally:    ['Ah, vous voila ! On a des choses a discuter.', 'Je vous attendais justement.', 'Entrons dans le vif du sujet.'],
      neutral: ['Bonjour. Que puis-je faire pour vous ?', 'Oui ? J\'ecoute.', 'En quoi puis-je vous aider ?']
    };
    const list = fallbacks[pnj.rel] || fallbacks.neutral;
    speech.textContent = list[Math.floor(Math.random() * list.length)];
  }
}

function closePnjModal() {
  document.getElementById('modal-pnj').classList.remove('open');
}

function addContactByName(name, role, rel, isPJ) {
  addContact({ name: name, role: role, rel: rel, isPJ: !!isPJ });
}

function addContact(pnj) {
  if ((pnj.name || '').replace(' (PNJ)', '').trim() === 'Jérémy') {
    if (typeof state !== 'undefined' && state.char && state.char.queteAccueil &&
        state.char.queteAccueil.etape === 'attente_depart_jeremy' && typeof queteAccueilProposerCarriere === 'function') {
      // Ajout reel au repertoire = validation naturelle de l'etape "attente_depart_jeremy" :
      // on enchaine directement sur la derniere question d'orientation, plutot que d'attendre
      // un prochain deplacement (queteAccueilVerifierDepartJeremy reste le filet de securite
      // si le joueur s'eloigne sans avoir ajoute Jeremy).
      queteAccueilProposerCarriere();
    } else if (typeof queteAccueilVerifierDepartJeremy === 'function') {
      // Depart immediat de Jeremy des qu'il est ajoute au repertoire a un autre moment de la
      // quete, plutot que d'attendre le prochain deplacement du joueur.
      queteAccueilVerifierDepartJeremy();
    }
  }
  if (!state.contacts) state.contacts = [];
  const exists = state.contacts.find(c => c.name === pnj.name);
  if (exists) {
    showToast('Deja dans le repertoire', pnj.name + ' est deja dans vos contacts.', false);
    return;
  }
  state.contacts.push({ name: pnj.name, role: pnj.role, rel: pnj.rel, isPJ: !!pnj.isPJ });
  showToast('Contact ajoute', pnj.name + ' a ete ajoute a votre repertoire.', true);
  addJournalEntry(pnj.name + ' ajoute au repertoire.', '');
}

async function genererReactionJournaliste() {
  const journaliste = JOURNALISTES_PNJ[state.country];
  if (!journaliste) return null;

  // Récupérer les derniers topics du forum local
  const topics = FORUM_TOPICS[state.country === 'republic' ? 'local' : 'local'] || [];
  const recentTopics = topics.slice(0, 3);
  if (recentTopics.length === 0) return null;

  const topicsText = recentTopics.map(t =>
    `"${t.title}" (par ${t.author})`
  ).join(', ');

  const co = COUNTRIES[state.country];
  const empireStyle = EMPIRE_STYLES[state.country] || EMPIRE_STYLES.republic;

  const prompt = `Tu es ${journaliste.name}, journaliste de "${journaliste.journal}" dans l'empire ${co?.n}.
Ta personnalité : ${journaliste.trait}
Ton style : ${journaliste.style}
Religion locale : ${empireStyle.religion}. Chef suprême : ${empireStyle.leader}.

Sujets récents sur le forum local : ${topicsText}

Rédige UNE courte réaction journalistique (2-3 phrases max) à ces actualités.
Style parodique et satirique. Intègre les éléments de l'empire naturellement.
PAS de vrais dieux ou religions. Réponds UNIQUEMENT avec ta réaction, sans introduction.`;

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        model: 'claude-sonnet-4-5',
        max_tokens: 150,
        messages: [{ role: 'user', content: prompt }]
      })
    });
    if (!resp.ok) return null;
    const data = await resp.json();
    return { journaliste, texte: data.content?.[0]?.text };
  } catch(e) { return null; }
}

async function afficherReactionJournaliste() {
  const reaction = await genererReactionJournaliste();
  if (!reaction) return;

  // Afficher dans le journal des événements
  addJournalEntry(
    `📰 ${reaction.journaliste.journal} — ${reaction.journaliste.name} : "${reaction.texte}"`,
    'event-info'
  );
}

function getAllPJsAndPNJs() {
  const result = [];
  // PJ connus (depuis state.pjConnus ou contacts)
  const pjConnus = state.pjConnus || [];
  pjConnus.forEach(nom => {
    if (!result.some(r => r.name === nom)) {
      result.push({ name: nom, role: 'Joueur', isPJ: true });
    }
  });
  // Contacts du répertoire
  (state.contacts || []).forEach(c => {
    if (!result.some(r => r.name === c.name)) {
      result.push({ name: c.name, role: c.role || 'Contact', isPJ: false });
    }
  });
  // PNJ du bâtiment actuel
  if (state.currentBuilding && state.currentRoom) {
    const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    (room?.persons || []).forEach(p => {
      if (!result.some(r => r.name === p.name)) {
        result.push({ name: p.name, role: p.role || 'PNJ', isPJ: false });
      }
    });
  }
  // Si toujours vide, retourner une cible générique
  if (result.length === 0) {
    result.push({ name: 'Un notable local', role: 'Personnage politique', isPJ: false });
  }
  return result;
}

async function doEscortInfos() {
  const cibles = getAllPJsAndPNJs().filter(c => c.name !== state.char?.name);
  if (cibles.length === 0) { showToast('Personne à cibler', 'Aucune cible disponible.', false); return; }

  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';

  const debit = await debiterFondsOrdinaires(300);
  if (!debit.ok) { showToast('Fonds insuffisants', `300 ${cur} requis.`, false); return; }

  // Choisir une cible au hasard parmi les PJ/PNJ connus
  const cible = cibles[Math.floor(Math.random() * Math.min(3, cibles.length))];

  const prompt = `Tu joues dans Res Publica, jeu politique parodique.
Une escort de luxe (${state.country === 'republic' ? 'Roxane Velours' : state.country === 'narco' ? 'Lola Discreta' : 'Natasha Privilege'}) a recueilli des informations compromettantes sur ${cible.name} (${cible.role || 'personnage politique'}) dans l'empire ${co?.n}.
Génère UNE révélation compromettante, parodique et drôle (2 phrases max). Style scandale politique. Pas de vrais noms de personnes réelles. Pas de religions réelles.`;

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 60, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const info = data.content?.[0]?.text?.trim() || 'Information confidentielle obtenue.';

    // Créer un kompromat dans l'inventaire
    addToInventory({
      id: 'kompromat-' + Date.now(),
      name: 'Kompromat sur ' + cible.name,
      icon: 'ti-file-shredder',
      desc: info,
      type: 'kompromat',
      cible: cible.name,
      legal: false
    });

    state.inf = Math.min(100, (state.inf || 0) + 5);
    updateUI();
    addJournalEntry('Kompromat obtenu sur ' + cible.name + '. Ajouté à l\'inventaire.', 'event-info');
    showToast('Information obtenue !', info.substring(0, 100) + (info.length > 100 ? '...' : ''), true, true);

  } catch(e) {
    showToast('Erreur', 'Impossible d\'obtenir l\'information.', false);
  }
}

function ouvrirModalLancerRumeur(pa, cost, successRate) {
  const pjContacts = (state.contacts || []).filter(c => c.isPJ || c.type === 'pj');
  if (pjContacts.length === 0) {
    showToast('Aucune cible', 'Vous devez avoir des PJ dans votre répertoire pour lancer une rumeur.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = '🗯 Choisir une cible';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Sélectionnez le PJ visé par la rumeur. Acte illégal — un jet raté se retourne contre vous.</div>' +
    pjContacts.map(c =>
      '<div onclick="confirmerLancerRumeur(\'' + c.name.replace(/'/g,'') + '\',' + pa + ',' + cost + ',' + successRate + ')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#1a1005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
        '<i class="ti ti-user" style="font-size:.9rem;color:#8a6a20"></i>' +
        '<div><div style="font-size:.82rem;color:#c0b090">' + c.name + '</div>' +
        '<div style="font-size:.85rem;color:#9a8a68">' + (c.role||'PJ') + '</div></div>' +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerLancerRumeur(nomCible, pa, cost, successRate) {
  document.getElementById('modal-postes').classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  const roll = Math.floor(Math.random() * 100) + 1;
  const succes = roll <= (successRate || 50);

  if (succes) {
    const perte = Math.floor(Math.random() * 16) + 5; // entre 5 et 20

    let texteRumeur = nomCible + ' serait impliqué(e) dans une affaire compromettante.';
    try {
      const resp = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'claude-haiku-4-5-20251001',
          max_tokens: 150,
          messages: [{
            role: 'user',
            content: 'Res Publica, jeu de rôle politique parodique et satirique. Une rumeur compromettante vient d\'être lancée contre ' + nomCible + '. Génère UNE phrase de rumeur courte (1-2 phrases max), diffamatoire mais crédible, ton satirique et cynique. Réponds UNIQUEMENT avec la rumeur, en texte brut sans markdown (pas de #, pas de **), sans introduction.'
          }]
        })
      });
      const data = await resp.json();
      texteRumeur = data.content?.[0]?.text?.trim() || texteRumeur;
    } catch(e) {}

    if (typeof sbAjusterPopJoueur === 'function') {
      sbAjusterPopJoueur(nomCible, -perte).catch(() => {});
    }

    document.getElementById('postes-modal-title').textContent = '🗯 Rumeur lancée !';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1.2rem">' +
      '<div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">"' + texteRumeur + '"</div>' +
      '<div style="font-size:.68rem;color:#9a8a68;margin-top:.8rem">Cible : ' + nomCible + ' · -' + perte + ' POP</div>' +
      '</div>';
    document.getElementById('modal-postes').classList.add('open');

    addExternalEvent('🗯 ' + texteRumeur);
    addJournalEntry('Rumeur lancée avec succès contre ' + nomCible + ' : "' + texteRumeur.substring(0,60) + '" (-' + perte + ' POP).', 'event-good');
    if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('fausse_rumeur', nomCible);
    if (typeof checkDetection === 'function') checkDetection('fausse_rumeur', 'success');
  } else {
    state.pop = Math.max(0, (state.pop || 0) - 5);
    state.dis = Math.max(0, (state.dis || 50) - 5);
    addJournalEntry('Tentative de rumeur contre ' + nomCible + ' ratée. Elle se retourne contre vous. -5 POP -5 DIS.', 'event-bad');
    showToast('Rumeur ratée', 'Votre tentative échoue et se retourne contre vous. -5 POP -5 DIS.', false);
    if (typeof checkDetection === 'function') checkDetection('fausse_rumeur', 'success');
  }

  if (typeof advanceTime === 'function') advanceTime(Math.max(0, pa || 0));
  updateUI();
}

// =====================
// DISTRIBUER UN TRACT (9 aout 2026)
// =====================
// N'existait pas du tout avant ce soir : le routeur appelait doDistribuerTract() sans que la
// fonction soit definie nulle part (ReferenceError silencieuse au clic), et le flag
// requiresTract:true de l'ordre (data.js) n'etait lu par aucun code. Premier ordre construit
// des le depart avec le systeme de moyenne de groupe (getStatEffective) : le taux depend de
// CHA et ENT, donc de qui compose le groupe au moment de l'action.
function doDistribuerTract(pa, cost) {
  const lots = (state.inventory || []).filter(i => i.type === 'tract' && (i.quantite || 0) > 0);
  if (lots.length === 0) {
    showToast('Aucun tract', 'Faites imprimer des tracts avant de pouvoir les distribuer.', false);
    return;
  }
  if (lots.length === 1) {
    confirmerDistribuerTract(lots[0].cible, lots[0].tractType, pa, cost);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Distribuer un tract';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Choisissez le lot à distribuer.</div>' +
    lots.map(l =>
      '<div onclick="confirmerDistribuerTract(\'' + l.cible.replace(/'/g,'') + '\',\'' + l.tractType + '\',' + pa + ',' + cost + ')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#1a1005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
        '<i class="ti ti-file-description" style="font-size:.9rem;color:' + (l.tractType === 'pour' ? '#6a9a6a' : '#9a4a4a') + '"></i>' +
        '<div><div style="font-size:.82rem;color:#c0b090">' + l.name + '</div>' +
        '<div style="font-size:.85rem;color:#9a8a68">' + l.quantite + ' restants</div></div>' +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDistribuerTract(cible, tractType, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');

  const lot = (state.inventory || []).find(i => i.type === 'tract' && i.cible === cible && i.tractType === tractType);
  if (!lot || (lot.quantite || 0) <= 0) {
    showToast('Lot épuisé', 'Ce lot de tracts n\'est plus disponible.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  lot.quantite -= 1;
  if (lot.quantite <= 0) {
    state.inventory = state.inventory.filter(i => i !== lot);
  }

  const cha = getStatEffective('CHA');
  const ent = getStatEffective('ENT');
  const taux = Math.min(90, Math.max(10, 25 + Math.round(cha * 3) + Math.round(ent * 3)));
  const roll = Math.floor(Math.random() * 100) + 1;
  const succes = roll <= taux;

  if (succes) {
    const montant = Math.floor(Math.random() * 6) + 3; // 3 a 8
    const delta = tractType === 'pour' ? montant : -montant;
    if (typeof sbAjusterPopJoueur === 'function') sbAjusterPopJoueur(cible, delta).catch(() => {});
    const verbe = tractType === 'pour' ? 'convaincus' : 'dissuadés';
    showToast('Tract distribué !', 'Efficace — ' + Math.abs(delta) + ' POP ' + (tractType === 'pour' ? 'pour' : 'contre') + ' ' + cible + '. (' + taux + '% de chances)', true, true);
    addJournalEntry('Tract distribué ' + tractType + ' ' + cible + ' avec succès : ' + (tractType === 'pour' ? '+' : '-') + montant + ' POP. (' + taux + '% de chances)', 'event-good');
  } else {
    showToast('Tract distribué', 'Sans effet cette fois — personne n\'a été convaincu. (' + taux + '% de chances)', false);
    addJournalEntry('Distribution de tract ' + tractType + ' ' + cible + ' sans effet. (' + taux + '% de chances)', '');
  }

  if (typeof verifierProgressionCarriere === 'function') verifierProgressionCarriere('politique', succes);
  updateUI();
}

function doSaluerPersonne(nom) {
  const jourActuel = state.day || 1;
  if (!state.salutationsDuJour || state.salutationsDuJour.jour !== jourActuel) {
    state.salutationsDuJour = { jour: jourActuel, noms: [] };
  }
  if (state.salutationsDuJour.noms.includes(nom)) {
    showToast('Deja salue(e)', 'Vous avez deja salue ' + nom + ' aujourd\'hui.', false);
    return;
  }
  state.salutationsDuJour.noms.push(nom);
  state.inf = Math.min(100, (state.inf || 0) + 2);
  updateUI();
  document.getElementById('modal-pnj')?.classList.remove('open');
  showToast('Salutation', 'Vous avez pris le temps d\'echanger quelques mots avec ' + nom + '. +2 INF.', true);
  addJournalEntry('Salutation echangee avec ' + nom + '. +2 INF.', 'event-good');
}

// Arbitrage final diner_affaires (lot plafonds/correctif final, 21 aout 2026) : paDiffere porte a
// 3, moral:2 ajoute explicitement (champ absent jusqu'ici -- les 3 points d'application (hp/inf/
// ent/paDiffere) ne traitaient jamais cfg.moral ; une ligne "if (cfg.moral) state.moral = ..."
// ajoutee aux 3 endroits exacts, meme style que les autres effets, aucun traitement parallele).
// hp:10 et inf:5 INCHANGES. paDiffere/moral/hp/inf s'appliquent tous symetriquement aux DEUX
// convives : envoyerInvitationSociale/verifierReponseInvitationSociale (cote inviteur) ET
// repondreInvitationSociale (cote invite) lisent tous les 3 ce meme objet -- confirme par lecture
// des 3 fonctions, aucune n'applique quoi que ce soit a un seul des deux convives. INF suit donc
// deja la meme portee (aux deux), sans aucun changement necessaire.
const CONFIG_INVITATIONS_SOCIALES = {
  diner_affaires: { verbe: 'dîner', hp: 10, moral: 2, inf: 5, ent: 0, paDiffere: 3, emoji: '🍽️' },
  boire_verre:    { verbe: 'boire un verre', hp: 5, inf: 2, ent: 2, paDiffere: 0, emoji: '🍷' }
};

// Republia — dîner d'affaires (lot finition boucle economique, 21 aout 2026 ; affine lots carte
// gastronomique + Marche, 21 aout 2026) : rattache diner_affaires au stock reel du restaurant SANS
// creer de seconde logique d'invitation -- simples fonctions d'appoint appelees depuis les deux
// points d'acceptation existants (envoyerInvitationSociale, chemin PNJ immediat ;
// verifierReponseInvitationSociale, chemin PJ differe). boire_verre n'appelle jamais ces
// fonctions (gate explicite sur type==='diner_affaires' a chaque appel) : son comportement reste
// strictement inchange. Toujours exactement 2 diners (l'inviteur + le seul invite possible : ce
// mecanisme n'a jamais gere de groupe, contrairement a offrir_tournee) donc 2 menus -- jamais un
// nombre arbitraire -- PLUS 1 vin (demande explicite : le diner necessite specifiquement la
// recette 'vin', pas n'importe quelle boisson de la carte).
//
// Les 2 menus peuvent provenir de N'IMPORTE LEQUEL des 3 types (demande explicite, 21 aout 2026) :
// prelevement simple et deterministe, jamais d'interface de choix -- parcourt data.carte dans son
// ordre de declaration (menu_gastronomique_1 puis 2 puis 3) et prend autant d'unites que
// disponibles a chaque menu jusqu'a atteindre 2 au total. Verification en lecture seule d'abord
// (aucune mutation ici) ; le prelevement precis retourne est ensuite applique tel quel par
// consommerStockDinerAffaires, jamais recalcule.
async function verifierStockDinerAffaires() {
  if (typeof resoudreCommerceActuel !== 'function' || typeof chargerCommerce !== 'function') return null;
  const c = resoudreCommerceActuel();
  if (!c) return null;
  const data = await chargerCommerce(c.type, state.country || 'republic', state.currentCity || 'capitale', c.buildingId, c.roomId);
  if (!data) return null;
  const menuIds = (data.carte || []).filter(id => typeof RECETTES_ALIMENTAIRES !== 'undefined' && RECETTES_ALIMENTAIRES[id]?.categorie === 'menu');
  let restant = 2;
  const prelevement = [];
  for (const id of menuIds) {
    if (restant <= 0) break;
    const dispo = data.stockProduits[id] || 0;
    if (dispo <= 0) continue;
    const pris = Math.min(dispo, restant);
    prelevement.push({ id, qte: pris });
    restant -= pris;
  }
  if (restant > 0) return null;
  if ((data.stockProduits.vin || 0) < 1) return null;
  return { data, prelevement };
}

async function consommerStockDinerAffaires(data, prelevement, cost, nomInvite) {
  prelevement.forEach(p => { data.stockProduits[p.id] -= p.qte; });
  data.stockProduits.vin -= 1;
  let net = cost;
  if (typeof appliquerTaxeTransaction === 'function') {
    const t = await appliquerTaxeTransaction(cost);
    net = t.net;
  }
  data.caisse = (data.caisse || 0) + net;
  const labels = prelevement.map(p => {
    const r = typeof RECETTES_ALIMENTAIRES !== 'undefined' ? RECETTES_ALIMENTAIRES[p.id] : null;
    return (r ? r.label : p.id) + ' x' + p.qte;
  }).join(', ');
  if (typeof ajouterHistoriqueEntreprise === 'function') {
    ajouterHistoriqueEntreprise(data, net, 'Vente — Dîner d\'affaires (' + labels + ' + vin, ' + nomInvite + ') — ' + (state.char?.name || 'Anonyme'));
  }
  if (typeof sbSaveEntreprise === 'function') await sbSaveEntreprise(data.id, data).catch(() => {});
}

function ouvrirModalInvitationSociale(type, pa, cost, successRate) {
  const cfg = CONFIG_INVITATIONS_SOCIALES[type];
  if (!cfg) return;
  const presentsPJ = (window._vraisJoueursPresents || []).filter(p => p.name !== state.char?.name).map(p => ({ name: p.name, isPJ: true }));
  const roomActuelle = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const presentsPNJ = (roomActuelle?.persons || []).filter(p => !p.isPJ).map(p => ({ name: p.name.replace(' (PNJ)', ''), isPJ: false }));
  const monGroupePNJ = typeof getMonGroupePNJ === 'function' ? getMonGroupePNJ() : [];
  const presentsMonGroupe = monGroupePNJ
    .filter(g => !presentsPNJ.some(pp => pp.name === g.nom))
    .map(g => ({ name: g.nom, isPJ: false }));
  const presents = [...presentsPJ, ...presentsPNJ, ...presentsMonGroupe];
  if (presents.length === 0) {
    showToast('Personne à inviter', 'Aucun autre joueur n\'est présent dans cette pièce pour l\'instant.', false);
    return;
  }
  if (state.arg < cost) {
    showToast('Fonds insuffisants', cost + ' FR requis pour inviter quelqu\'un à ' + cfg.verbe + '.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = cfg.emoji + ' Inviter à ' + cfg.verbe;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Choisissez un joueur présent. Le coût n\'est prélevé que s\'il accepte.</div>' +
    '<textarea id="invitation-message-input" placeholder="Message facultatif..." maxlength="200" style="width:100%;min-height:3.5rem;margin-bottom:.7rem;background:#0a0805;border:1px solid #2a2010;color:#c0b090;font-size:.78rem;padding:.4rem;resize:vertical"></textarea>' +
    presents.map(p =>
      '<div onclick="envoyerInvitationSociale(\'' + type + '\',\'' + p.name.replace(/'/g,'') + '\',' + pa + ',' + cost + ',' + (p.isPJ ? 'true' : 'false') + ')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#1a1005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
        '<i class="ti ti-user" style="font-size:.9rem;color:#8a6a20"></i>' +
        '<div><div style="font-size:.82rem;color:#c0b090">' + p.name + '</div></div>' +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Plafonnement + limite de fréquence de la croissance ENT (bêta, exploit corrigé) : aucun des
// 4 points d'écriture directe de state.char.stats.ENT (3 variantes d'invitation sociale
// ci-dessous, plus confirmerFaireLAmour) n'avait jusqu'ici ni plafond ni limite de fréquence --
// un joueur pouvait répéter l'action à volonté pour faire progresser ENT sans limite, seule
// caractéristique du jeu dans ce cas (audit dédié). Plafond dur 20 (même valeur que prévue pour
// le futur système complet d'entraînement des 6 caractéristiques, non construit ici) ; une
// seule progression ENT autorisée par jour, tous mécanismes confondus. Le reste de l'action
// (argent, PA, autres bonus hp/inf/moral) n'est jamais affecté par ce garde-fou -- seul le
// gain ENT lui-même est silencieusement plafonné/ignoré au-delà de la limite.
function appliquerGainENT(montant) {
  if (!montant || !state.char) return false;
  if (!state.char.stats) state.char.stats = {};
  const actuel = state.char.stats.ENT || 0;
  if (actuel >= 20) return false;
  if (state.char.dernierGainENTJour === state.day) return false;
  state.char.stats.ENT = Math.min(20, actuel + montant);
  state.char.dernierGainENTJour = state.day;
  return true;
}

async function envoyerInvitationSociale(type, nomInvite, pa, cost, estPJ) {
  const messageEnvoye = (document.getElementById("invitation-message-input")?.value || "").trim().slice(0, 200);
  document.getElementById('modal-postes').classList.remove('open');
  const cfgPnj = CONFIG_INVITATIONS_SOCIALES[type] || {};

  if (!estPJ) {
    if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' FR requis.', false); return; }
    const estDansMonGroupe = typeof getMonGroupePNJ === 'function' && getMonGroupePNJ().some(g => g.nom === nomInvite);
    const roomActuelle2 = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    const pnjInfo = (roomActuelle2?.persons || []).find(pp => pp.name.replace(' (PNJ)', '') === nomInvite);
    const rel = pnjInfo?.rel || 'neutral';
    const chance = estDansMonGroupe ? 95 : (rel === 'ally' ? 85 : rel === 'enemy' ? 20 : 60);
    const roll = Math.floor(Math.random() * 100) + 1;
    if (roll <= chance) {
      // Republia (lot finition boucle economique, 21 aout 2026) : verifie le stock du restaurant
      // AVANT tout debit si diner_affaires -- rien n'est encore mute a cet instant, refus propre
      // symetrique a repas_gastronomique. N'affecte jamais boire_verre (dinerStock reste null).
      let dinerStock = null;
      if (type === 'diner_affaires') {
        dinerStock = await verifierStockDinerAffaires();
        if (!dinerStock) {
          showToast('Rupture de stock', nomInvite + ' a accepté, mais le restaurant n\'a rien à servir pour l\'instant.', false);
          addJournalEntry('Invitation à dîner avec ' + nomInvite + ' acceptée, mais rupture de stock au restaurant.', 'event-bad');
          return;
        }
      }
      // Deduction PA+cout centralisee (Lot 2A, correctif de fuite PA identifiee par l'audit du
      // 19 aout 2026 : diner_affaires/boire_verre ne debitaient jusqu'ici jamais leurs PA,
      // meme sous TEST_MODE=false, ni via deduireCoutOrdre() ni par mutation directe). Cout du
      // uniquement en cas d'acceptation (roll reussi), comme deja pour l'argent -- meme moment
      // exact que l'ancien `state.arg -= cost` qu'elle remplace.
      const r = await deduireCoutOrdre({ pa, cost });
      if (!r.ok) {
        const raisonTxt = r.raison === 'pa_insuffisants' ? 'plus assez de PA' : 'plus les fonds';
        showToast(r.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Fonds insuffisants', nomInvite + ' a accepté, mais vous n\'avez ' + raisonTxt + ' pour ' + cfgPnj.verbe + '.', false);
        addJournalEntry('Invitation à ' + cfgPnj.verbe + ' avec ' + nomInvite + ' acceptée, mais ' + (r.raison === 'pa_insuffisants' ? 'PA' : 'fonds') + ' insuffisants.', 'event-bad');
        return;
      }
      if (dinerStock) await consommerStockDinerAffaires(dinerStock.data, dinerStock.prelevement, cost, nomInvite);
      if (cfgPnj.hp) state.hp = Math.min(100, (state.hp || 0) + cfgPnj.hp);
      if (cfgPnj.moral) state.moral = Math.min(100, (state.moral || 0) + cfgPnj.moral);
      if (cfgPnj.inf) state.inf = Math.min(100, (state.inf || 0) + cfgPnj.inf);
      if (cfgPnj.ent) appliquerGainENT(cfgPnj.ent);
      if (cfgPnj.paDiffere) state.bonusPaProchainDormir = (state.bonusPaProchainDormir || 0) + cfgPnj.paDiffere;
      updateUI();
      showToast('Invitation acceptée !', nomInvite + ' a accepté votre invitation à ' + cfgPnj.verbe + '. -' + cost + ' FR.', true, true);
      addJournalEntry('Invitation à ' + cfgPnj.verbe + ' avec ' + nomInvite + ' : acceptée. -' + cost + ' FR.', 'event-good');
      if (typeof advanceTime === 'function') advanceTime(Math.max(0, pa || 0));
    } else {
      showToast('Invitation refusée', nomInvite + ' a décliné votre invitation.', false);
      addJournalEntry('Invitation à ' + cfgPnj.verbe + ' avec ' + nomInvite + ' : refusée.', 'event-info');
    }
    return;
  }

  if (typeof sbCreerInvitationDiner !== 'function') return;
  await sbCreerInvitationDiner(state.char?.name, nomInvite, state.country, state.currentCity, state.currentBuilding, state.currentRoom, cost, type, messageEnvoye).catch(() => {});
  state._invitationSocialeEnAttente = {
    type, invite: nomInvite, pa, cost,
    country: state.country, city: state.currentCity,
    buildingId: state.currentBuilding, roomId: state.currentRoom
  };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  const cfg = CONFIG_INVITATIONS_SOCIALES[type] || {};
  showToast('Invitation envoyée', 'En attente de la réponse de ' + nomInvite + '...', true);
  addJournalEntry('Invitation à ' + (cfg.verbe || type) + ' envoyée à ' + nomInvite + '.', 'event-info');
}

async function verifierReponseInvitationSociale() {
  if (!state._invitationSocialeEnAttente || !state.char?.name) return;
  const infos = state._invitationSocialeEnAttente;
  const cfg = CONFIG_INVITATIONS_SOCIALES[infos.type];
  if (!cfg) { state._invitationSocialeEnAttente = null; if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {}); return; }

  // Invitation caduque si l'inviteur (nous-meme) a quitte la piece d'origine
  if (state.currentBuilding !== infos.buildingId || state.currentRoom !== infos.roomId) {
    state._invitationSocialeEnAttente = null;
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    return;
  }

  if (typeof sbGetInvitationsDinerTraitees !== 'function') return;
  try {
    const rows = await sbGetInvitationsDinerTraitees(state.char.name, infos.invite);
    const ligne = (rows || []).find(r => r.type === infos.type);
    if (!ligne) return;

    if (ligne.statut === 'acceptee') {
      // Republia (lot finition boucle economique, 21 aout 2026) : meme verification de stock que
      // le chemin PNJ immediat, AVANT tout debit. N'affecte jamais boire_verre (dinerStock reste
      // null, la branche suivante s'execute alors exactement comme avant ce lot).
      let dinerStock = null;
      if (infos.type === 'diner_affaires') dinerStock = await verifierStockDinerAffaires();
      if (infos.type === 'diner_affaires' && !dinerStock) {
        showToast('Rupture de stock', infos.invite + ' a accepté, mais le restaurant n\'a rien à servir pour l\'instant.', false);
        addJournalEntry('Invitation à dîner avec ' + infos.invite + ' acceptée, mais rupture de stock au restaurant.', 'event-bad');
      } else {
      // Deduction PA+cout centralisee (Lot 2A, correctif de fuite PA) -- moment logique de
      // consommation : exactement celui deja utilise pour l'argent (confirmation de
      // l'acceptation differee), jamais a l'envoi de l'invitation. Aucun changement de
      // comportement pour l'argent : meme instant, meme condition, juste route via
      // deduireCoutOrdre() pour couvrir aussi les PA. Nettoyage (suppression de la ligne
      // Supabase + _invitationSocialeEnAttente=null) deja inconditionnel plus bas, donc aucun
      // risque de retraitement/double debit meme en cas d'echec ici.
      const r = await deduireCoutOrdre({ pa: infos.pa, cost: infos.cost });
      if (r.ok) {
        if (dinerStock) await consommerStockDinerAffaires(dinerStock.data, dinerStock.prelevement, infos.cost, infos.invite);
        if (cfg.hp) state.hp = Math.min(100, (state.hp || 0) + cfg.hp);
        if (cfg.moral) state.moral = Math.min(100, (state.moral || 0) + cfg.moral);
        if (cfg.inf) state.inf = Math.min(100, (state.inf || 0) + cfg.inf);
        if (cfg.ent) appliquerGainENT(cfg.ent);
        if (cfg.paDiffere) state.bonusPaProchainDormir = (state.bonusPaProchainDormir || 0) + cfg.paDiffere;
        showToast('Invitation acceptée !', infos.invite + ' a accepté votre invitation à ' + cfg.verbe + (ligne.reponse ? ' ("' + ligne.reponse + '")' : '') + '. -' + infos.cost + ' FR.', true, true);
        addJournalEntry('Invitation à ' + cfg.verbe + ' avec ' + infos.invite + ' : acceptée. -' + infos.cost + ' FR.', 'event-good');
        if (typeof advanceTime === 'function') advanceTime(Math.max(0, infos.pa || 0));
      } else {
        const raisonTxt = r.raison === 'pa_insuffisants' ? 'plus assez de PA' : 'plus les fonds';
        showToast(r.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Fonds insuffisants', infos.invite + ' a accepté, mais vous n\'avez ' + raisonTxt + ' pour régler.', false);
        addJournalEntry('Invitation à ' + cfg.verbe + ' avec ' + infos.invite + ' acceptée, mais ' + (r.raison === 'pa_insuffisants' ? 'PA' : 'fonds') + ' insuffisants pour payer.', 'event-bad');
      }
      }
      if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur(infos.type + '_accepte', infos.invite);
    } else if (ligne.statut === 'refusee') {
      showToast('Invitation refusée', infos.invite + ' a décliné votre invitation' + (ligne.reponse ? ' ("' + ligne.reponse + '")' : '') + '.', false);
      addJournalEntry('Invitation à ' + cfg.verbe + ' avec ' + infos.invite + ' : refusée.', 'event-info');
      if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur(infos.type + '_refuse', infos.invite);
    }

    if (typeof sbSupprimerInvitationDiner === 'function') sbSupprimerInvitationDiner(ligne.id).catch(() => {});
    state._invitationSocialeEnAttente = null;
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    updateUI();
  } catch(e) {}
}

async function verifierInvitationsSocialesRecues() {
  if (!state.char?.name || !state.currentBuilding || !state.currentRoom) return;
  if (state._invitationSocialeModalOuvert) return;
  if (typeof sbGetInvitationsDinerRecues !== 'function') return;
  try {
    const rows = await sbGetInvitationsDinerRecues(state.char.name);
    const valide = (rows || []).find(r =>
      r.country === state.country && r.city === state.currentCity &&
      r.building_id === state.currentBuilding && r.room_id === state.currentRoom
    );
    if (!valide) return;
    const cfg = CONFIG_INVITATIONS_SOCIALES[valide.type] || { verbe: 'passer un moment', emoji: '🍽️' };
    state._invitationSocialeModalOuvert = true;
    state._invitationSocialeCourante = valide;
    document.getElementById('postes-modal-title').textContent = cfg.emoji + ' Invitation';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1.2rem">' +
      '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">' + valide.inviteur + ' vous invite à ' + cfg.verbe + ', à ses frais.</div>' +
      (valide.message ? '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.8rem;border-left:2px solid #3a2a10;padding-left:.6rem">' + valide.message + '</div>' : '') +
      '<textarea id="invitation-reponse-input" placeholder="Reponse facultative..." maxlength="200" style="width:100%;min-height:3.5rem;margin-bottom:.7rem;background:#0a0805;border:1px solid #2a2010;color:#c0b090;font-size:.78rem;padding:.4rem;resize:vertical"></textarea>' +
      '<div style="display:flex;gap:.5rem">' +
        '<button onclick="repondreInvitationSociale(' + valide.id + ',true,\'' + valide.inviteur.replace(/'/g,'') + '\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.5rem;border:1px solid #4a8a4a;background:transparent;color:#6a9a6a;cursor:pointer">✅ Accepter</button>' +
        '<button onclick="repondreInvitationSociale(' + valide.id + ',false,\'' + valide.inviteur.replace(/'/g,'') + '\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.5rem;border:1px solid #5a2a2a;background:transparent;color:#8a3a2a;cursor:pointer">❌ Refuser</button>' +
      '</div></div>';
    document.getElementById('modal-postes').classList.add('open');
  } catch(e) {}
}

async function repondreInvitationSociale(id, accepte, nomInviteur) {
  const reponseEnvoyee = (document.getElementById("invitation-reponse-input")?.value || "").trim().slice(0, 200);
  document.getElementById('modal-postes').classList.remove('open');
  state._invitationSocialeModalOuvert = false;
  const valide = state._invitationSocialeCourante;
  const cfg = CONFIG_INVITATIONS_SOCIALES[valide?.type] || {};
  if (typeof sbRepondreInvitationDiner === 'function') await sbRepondreInvitationDiner(id, accepte, reponseEnvoyee).catch(() => {});
  if (accepte) {
    if (cfg.hp) state.hp = Math.min(100, (state.hp || 0) + cfg.hp);
    if (cfg.moral) state.moral = Math.min(100, (state.moral || 0) + cfg.moral);
    if (cfg.inf) state.inf = Math.min(100, (state.inf || 0) + cfg.inf);
    if (cfg.ent) appliquerGainENT(cfg.ent);
    if (cfg.paDiffere) state.bonusPaProchainDormir = (state.bonusPaProchainDormir || 0) + cfg.paDiffere;
    updateUI();
    showToast('Invitation acceptée !', 'Vous rejoignez ' + nomInviteur + ' pour ' + (cfg.verbe || 'un moment') + '.', true, true);
    addJournalEntry('Vous avez accepté l\'invitation de ' + nomInviteur + ' (' + (cfg.verbe || '') + ').', 'event-good');
  } else {
    showToast('Invitation déclinée', 'Vous avez refusé l\'invitation de ' + nomInviteur + '.', false);
    addJournalEntry('Vous avez refusé l\'invitation à ' + (cfg.verbe || '') + ' de ' + nomInviteur + '.', 'event-info');
  }
  state._invitationSocialeCourante = null;
}

function demarrerPollingInvitationsDiner() {
  if (window._dinerPollingActif) return;
  window._dinerPollingActif = true;
  setInterval(() => { if (typeof verifierInvitationsSocialesRecues === 'function') verifierInvitationsSocialesRecues(); }, 4000);
  setInterval(() => { if (typeof verifierReponseInvitationSociale === 'function') verifierReponseInvitationSociale(); }, 4000);
  // Lot tournees (20 aout 2026) : deux boucles dediees, memes cadence/mecanisme que les 2
  // ci-dessus mais sur les tables tournees/invitations_diner.tournee_id -- source de verite
  // toujours en base (jamais un state local), donc une tournee en attente survit naturellement
  // a un refresh/reconnexion (la boucle offreur la retrouve au prochain tick).
  setInterval(() => { if (typeof verifierTourneesRecues === 'function') verifierTourneesRecues(); }, 4000);
  setInterval(() => { if (typeof verifierTourneesActivesOffreur === 'function') verifierTourneesActivesOffreur(); }, 4000);
}


function ouvrirModalFabriquerKompromat(nomAgent) {
  const pjContacts = (state.contacts || []).filter(c => c.isPJ || c.type === 'pj');
  if (pjContacts.length === 0) {
    showToast('Aucune cible', 'Vous devez avoir des PJ dans votre répertoire pour fabriquer un kompromat.', false);
    return;
  }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = '🗂️ Choisir une cible';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">' + nomAgent + ' peut fabriquer un kompromat sur un PJ de votre répertoire. Coût : 300 ' + cur + '.</div>' +
    pjContacts.map(c =>
      '<div onclick="confirmerFabriquerKompromat(\'' + nomAgent.replace(/'/g,'') + '\',\'' + c.name.replace(/'/g,'') + '\')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#1a1005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
        '<i class="ti ti-user" style="font-size:.9rem;color:#8a6a20"></i>' +
        '<div><div style="font-size:.82rem;color:#c0b090">' + c.name + '</div></div>' +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFabriquerKompromat(nomAgent, nomCible) {
  document.getElementById('modal-postes').classList.remove('open');
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const debit = await debiterFondsOrdinaires(300);
  if (!debit.ok) { showToast('Fonds insuffisants', '300 ' + cur + ' requis.', false); return; }

  const prompt = `Tu joues dans Res Publica, jeu politique parodique.
${nomAgent} a recueilli des informations compromettantes sur ${nomCible} dans l'empire ${co?.n}.
Génère UNE révélation compromettante, parodique et drôle (2 phrases max). Style scandale politique. Pas de vrais noms de personnes réelles. Pas de religions réelles. Réponds en texte brut uniquement, sans markdown (pas de #, pas de **, pas de titre).`;

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 150, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const info = data.content?.[0]?.text?.trim() || 'Information confidentielle obtenue.';

    addToInventory({
      id: 'kompromat-' + Date.now(),
      name: 'Kompromat sur ' + nomCible,
      icon: 'ti-file-shredder',
      desc: info,
      type: 'kompromat',
      cible: nomCible,
      legal: false
    });

    state.inf = Math.min(100, (state.inf || 0) + 5);
    updateUI();
    addJournalEntry('Kompromat obtenu sur ' + nomCible + ' via ' + nomAgent + '. Ajouté à l\'inventaire.', 'event-info');
    showToast('Kompromat fabriqué !', info.substring(0, 100) + (info.length > 100 ? '...' : ''), true, true);
  } catch(e) {
    crediterFondsOrdinaires(300);
    showToast('Erreur', 'Impossible de fabriquer le kompromat pour le moment. Remboursé.', false);
  }
}

const ETAPES_ESCORT = {
  1: { label: 'Offrir un verre', cost: 100, desc: "Vous invitez a boire un verre. Premiere marque d'attention." },
  2: { label: 'Inviter a diner', cost: 300, desc: 'Un diner en tete-a-tete. La complicite grandit.' },
  3: { label: 'Emmener voir la mer a Port-Sainte-Marie', cost: 600, desc: 'Une escapade qui sort du cadre habituel. Un vrai geste.' }
};

function ouvrirModalEtapeEscort(nomEscort, palierVise) {
  const etape = ETAPES_ESCORT[palierVise];
  if (!etape) return;
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  if (state.arg < etape.cost) { showToast('Fonds insuffisants', etape.cost + ' ' + cur + ' requis.', false); return; }

  document.getElementById('postes-modal-title').textContent = etape.label + ' — ' + nomEscort;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#a09060;margin-bottom:1rem">' + etape.desc + ' Cout : ' + etape.cost + ' ' + cur + '.</div>' +
    '<button onclick="confirmerEtapeEscort(\'' + nomEscort.replace(/'/g,'') + '\',' + palierVise + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #cc6699;background:transparent;color:#cc6699;cursor:pointer">Confirmer</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerEtapeEscort(nomEscort, palierVise) {
  document.getElementById('modal-postes').classList.remove('open');
  const etape = ETAPES_ESCORT[palierVise];
  if (!etape) return;
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const debit = await debiterFondsOrdinaires(etape.cost);
  if (!debit.ok) { showToast('Fonds insuffisants', etape.cost + ' ' + cur + ' requis.', false); return; }

  const escortInfo = (state.escortActive || []).find(e => e.nom === nomEscort);
  if (escortInfo) escortInfo.palier = palierVise;
  updateUI();

  const petitsNoms = ['', 'grand fou', 'mon merveilleux amant', 'cheri(e)'];
  const nouveauPetitNom = petitsNoms[palierVise];
  showToast(etape.label + ' reussi', nomEscort + ' vous appelle desormais "' + nouveauPetitNom + '".', true, true);
  addJournalEntry(etape.label + ' avec ' + nomEscort + '. -' + etape.cost + ' ' + cur + '. Complicite accrue.', 'event-good');

  confirmerFaireLAmour(nomEscort);
}

const ETAPE_SUIVANTE_ESCORT = {
  0: { label: 'Offrir un verre', palierVise: 1 },
  1: { label: 'Inviter a diner', palierVise: 2 },
  2: { label: 'Emmener voir la mer a Port-Sainte-Marie', palierVise: 3 }
};

// Correction du 22 aout 2026 (regle de game design absolue) : ces 4 phrases laissaient
// auparavant entendre une alternative "sans engager" ("a moins que...", "ou alors... allons
// droit au but") -- retiree ici, uniquement l'ambiguite contraire a la regle, sans refondre
// la personnalite/le ton de chaque phrase.
const PHRASES_ESCORT_NON_ENGAGEE = [
  function(nom) { return 'Que vous etes presse(e), ' + nom + '. Engagez-moi si vous voulez qu on aille plus loin.'; },
  function(nom) { return 'Doucement, ' + nom + '. On ne se donne pas comme ca, sans un minimum d engagement.'; },
  function(nom) { return nom + ', vous brulez les etapes. Engagez-moi d abord.'; },
  function(nom) { return 'Un instant, ' + nom + '. Il y a une facon de faire les choses. Engagez-moi.'; }
];

const PHRASES_ESCORT_ETAPE_SUIVANTE = [
  function(nom, etape) { return 'Que vous etes presse(e), ' + nom + '. ' + etape + ' si vous voulez qu on aille plus loin. A moins que vous ne soyez tres presse...'; },
  function(nom, etape) { return nom + ', un peu de patience. ' + etape + ' d abord, et la suite n en sera que meilleure. A moins que vous ne puissiez attendre...'; },
  function(nom, etape) { return 'Toujours aussi presse(e), ' + nom + ' ? ' + etape + ', et je suis toute a vous. Ou alors, allons a l essentiel...'; },
  function(nom, etape) { return 'On y va doucement, ' + nom + '. ' + etape + ' pour de bon, sinon je vous connais a peine.'; }
];

function ouvrirModalFaireLAmour(nomEscort) {
  const nomPJ = state.char?.name || 'vous';
  const escortInfo = (state.escortActive || []).find(e => e.nom === nomEscort);

  if (!escortInfo) {
    // Correction du 22 aout 2026 (regle de game design validee) : "Faire l'amour" exige
    // desormais TOUJOURS une embauche prealable -- l'ancien bouton "sans engager" permettait
    // de contourner cette regle et a ete retire. "Secret contre secret", lui, reste
    // volontairement independant de l'embauche (voir plus bas).
    const phraseFn = PHRASES_ESCORT_NON_ENGAGEE[Math.floor(Math.random() * PHRASES_ESCORT_NON_ENGAGEE.length)];
    document.getElementById('postes-modal-title').textContent = '💗 ' + nomEscort;
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem">' +
      '<div style="font-size:.85rem;color:#c0b090;font-style:italic;margin-bottom:1rem;line-height:1.6">"' + phraseFn(nomPJ) + '"</div>' +
      '<button onclick="ouvrirRecrutementEscort(\'' + nomEscort.replace(/'/g,'') + '\',\'F\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Engager comme escort (800 FR/j)</button>' +
      '</div>';
    document.getElementById('modal-postes').classList.add('open');
    return;
  }

  const palierActuel = escortInfo.palier || 0;
  const etapeSuivante = ETAPE_SUIVANTE_ESCORT[palierActuel];

  if (!etapeSuivante) {
    confirmerFaireLAmour(nomEscort);
    return;
  }

  const phraseFn2 = PHRASES_ESCORT_ETAPE_SUIVANTE[Math.floor(Math.random() * PHRASES_ESCORT_ETAPE_SUIVANTE.length)];
  document.getElementById('postes-modal-title').textContent = '💗 ' + nomEscort;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.85rem;color:#c0b090;font-style:italic;margin-bottom:1rem;line-height:1.6">"' + phraseFn2(nomPJ, etapeSuivante.label) + '"</div>' +
    '<button onclick="ouvrirModalEtapeEscort(\'' + nomEscort.replace(/'/g,'') + '\',' + etapeSuivante.palierVise + ')" style="width:100%;margin-bottom:.5rem;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">' + etapeSuivante.label + '</button>' +
    '<button onclick="confirmerFaireLAmour(\'' + nomEscort.replace(/'/g,'') + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #cc6699;background:transparent;color:#cc6699;cursor:pointer">Passer outre et faire l amour (300 FR)</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFaireLAmour(nomEscort) {
  document.getElementById('modal-postes').classList.remove('open');
  // Garde-fou (22 aout 2026, regle de game design validee) : "Faire l'amour" exige TOUJOURS
  // une embauche active -- verifie ici, pas seulement au niveau du bouton, pour qu'un appel
  // direct de cette fonction ne puisse jamais contourner la regle. Retour immediat avant
  // toute depense, tout bonus, toute trace nuit_escort, toute confidence et tout appel IA.
  const escortInfoGarde = (state.escortActive || []).find(e => e.nom === nomEscort);
  if (!escortInfoGarde) {
    showToast('Escort non engagée', 'Engagez d\'abord ' + nomEscort + ' comme escort.', false);
    return;
  }
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const cost = 300;
  const debit = await debiterFondsOrdinaires(cost);
  if (!debit.ok) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }

  // Phase 2 memoire des renseignements (22 aout 2026) : jet de confidence, best-effort et
  // entierement invisible cote UI (ni toast, ni journal, ni recit modifie -- point 9 du design
  // valide : le coeur de cette Phase 2 est la persistance, pas le dialogue). Ne bloque jamais
  // le reste de l'action -- aucun await. Correctif du 22 aout 2026 (revue avant GO) : le taux
  // complet (CHA_client/pays/ville/jour/piete) est desormais calcule entierement cote serveur,
  // a partir des donnees persistees de "client" (personnages/indices_villes) -- ce client ne
  // transmet plus que le nom du client, le nom de l'escort et chaEscort. chaEscort reste
  // transmis ici car aucune source serveur n'existe pour les stats des PNJ (escorts sans ligne
  // personnages, PNJ_STATS_PAR_JOB/PNJ_STATS_NOMMES vivent uniquement dans data.js, cote client
  // -- voir api/renseignements.js pour le detail). Resolu via getPnjStats (job 'escort',
  // CHA=10 par defaut) -- uniforme entre escorts tant qu'aucun nom precis n'est ajoute a
  // PNJ_STATS_NOMMES (mecanisme deja existant, aucune valeur inventee ici).
  if (typeof sbTirerConfidenceEscort === 'function') {
    const nomClient = state.char?.name || 'Anonyme';
    const chaEscort = (typeof getPnjStats === 'function' ? getPnjStats({ name: nomEscort, job: 'escort' }).CHA : 10) ?? 10;
    sbTirerConfidenceEscort(nomClient, nomEscort, chaEscort).catch(() => {});
  }

  // Phase 5B memoire commerciale (22 aout 2026) : prestation reellement realisee (garde-fou
  // Phase 5A deja passe, paiement deja effectue) -- best-effort, fire-and-forget, ne bloque
  // jamais le reste de l'action. jour calcule cote serveur.
  if (typeof sbEnregistrerEvenementEscort === 'function') {
    sbEnregistrerEvenementEscort(state.char?.name || 'Anonyme', nomEscort, 'prestation').catch(() => {});
  }

  const escortInfo = (state.escortActive || []).find(e => e.nom === nomEscort);
  const palierActuel = escortInfo?.palier || 0;
  const bonusParPalier = [
    { moral: 15, hp: 5,  ent: 2 },
    { moral: 18, hp: 6,  ent: 2 },
    { moral: 22, hp: 7,  ent: 3 },
    { moral: 28, hp: 10, ent: 4 }
  ];
  const bonus = bonusParPalier[palierActuel];

  state.moral = Math.min(100, (state.moral || 0) + bonus.moral);
  state.hp = Math.min(100, (state.hp || 0) + bonus.hp);
  appliquerGainENT(bonus.ent);

  const petitsNoms = ['Monsieur ou Madame', 'grand fou', 'mon merveilleux amant', 'cheri(e)'];
  const petitNomActuel = petitsNoms[palierActuel];
  const longueurParPalier = ['2-3 phrases', '3-4 phrases', '4-5 phrases', '5-6 phrases, ton plus passionne et intime'];
  const longueurVisee = longueurParPalier[palierActuel];
  const maxTokensParPalier = [250, 320, 400, 480];
  const maxTokensVise = maxTokensParPalier[palierActuel];

  const prompt = 'Tu es le narrateur de Res Publica, jeu politique parodique et satirique. Le joueur vient de passer un moment intime avec ' + nomEscort + ", une escort de l'Agence Roxane Velours. La complicite entre eux a atteint un palier ou le petit nom \"" + petitNomActuel + '" est desormais utilise. Redige UN recit (' + longueurVisee + ') qui flatte et valorise le joueur, lui donnant un sentiment de plenitude et de superiorite, integrant naturellement ce petit nom dans le dialogue, mais glisse a la toute fin un doute subtil sur l authenticite du plaisir ressenti par l escort (professionnelle avant tout). Ton elegant, un peu ironique, jamais vulgaire ni explicite. Reponds en texte brut uniquement, sans markdown (pas de #, pas de **).';

  let recit = 'Vous passez un moment agréable avec ' + nomEscort + '.';
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: maxTokensVise, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    recit = data.content?.[0]?.text?.trim() || recit;
  } catch(e) {}

  updateUI();
  document.getElementById('postes-modal-title').textContent = '💗 ' + nomEscort;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.2rem">' +
    '<div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">' + recit + '</div>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');

  addJournalEntry('Moment privé avec ' + nomEscort + '. +' + bonus.moral + ' Moral, +' + bonus.hp + ' Santé, +' + bonus.ent + ' ENT. -' + cost + ' ' + cur + '.', 'event-good');

  if (typeof tracerActionPourRumeur === 'function') {
    // Correction du 22 aout 2026 : la cible etait auparavant toujours null, rendant impossible
    // de savoir quel escort etait concerne par la trace. Duree de actions_tracables (7 jours)
    // inchangee -- distincte de la future memoire commerciale 90 jours.
    tracerActionPourRumeur('nuit_escort', nomEscort);
    try {
      if (typeof sbGetMariageActif === 'function') {
        const mariage = await sbGetMariageActif(state.char?.name);
        if (mariage) tracerActionPourRumeur('nuit_escort', nomEscort);
      }
    } catch(e) {}
  }
}

// Phase 3 memoire des renseignements (22 aout 2026) : echange volontaire "secret contre
// secret". Precondition volontairement INDEPENDANTE de escortActiveInfo (l'embauche reste
// exclusive a "Faire l'amour", precision explicite du game design) -- accessible des que le
// PJ peut ouvrir la fiche de l'escort. Interaction explicite uniquement : aucune ecoute
// automatique des dialogues libres ailleurs dans le jeu (voir bouton dedie, plateau-pnj.js
// ~ligne 898). Le texte libre du joueur n'est jamais interprete/enregistre ici -- transmis
// tel quel au serveur (api/renseignements.js, action secret_contre_secret), qui fait
// entierement l'extraction IA, l'ecriture memoire escort, le tirage de la contrepartie et
// l'ecriture memoire PJ. Ce client ne recoit jamais que le resultat final (accepte ou non,
// contrepartie deja formulee ou null) -- jamais la memoire complete de l'escort.
function ouvrirModalSecretContreSecret(nomEscort) {
  document.getElementById('postes-modal-title').textContent = '🤝 ' + nomEscort;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.85rem;color:#c0b090;font-style:italic;margin-bottom:1rem;line-height:1.6">"Si tu me dis un secret, je t\'en confierai un autre. Mais pas de blague : si on ne peut pas se faire confiance, nos rendez-vous n\'ont aucun sens..."</div>' +
    '<textarea id="secret-contre-secret-texte" placeholder="Confiez-lui quelque chose..." maxlength="500" style="width:100%;min-height:5rem;margin-bottom:.7rem;background:#0a0805;border:1px solid #2a2010;color:#c0b090;font-size:.8rem;padding:.5rem;resize:vertical;box-sizing:border-box;font-family:Crimson Pro,serif"></textarea>' +
    '<button onclick="confirmerSecretContreSecret(\'' + nomEscort.replace(/'/g,'') + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #cc6699;background:transparent;color:#cc6699;cursor:pointer">Confier ce secret</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerSecretContreSecret(nomEscort) {
  const champ = document.getElementById('secret-contre-secret-texte');
  const declaration = (champ?.value || '').trim();
  if (!declaration) { showToast('Rien à confier', 'Écrivez votre confidence avant de valider.', false); return; }
  document.getElementById('modal-postes').classList.remove('open');

  const resultat = typeof sbEchangerSecretEscort === 'function'
    ? await sbEchangerSecretEscort(state.char?.name || 'Anonyme', nomEscort, declaration).catch(() => null)
    : null;

  if (!resultat || !resultat.ok || !resultat.declarationValide) {
    showToast('Refus poli', nomEscort + ' n\'a pas trouvé votre confidence assez intéressante pour un échange.', false);
    addJournalEntry('Tentative d\'échange de confidences avec ' + nomEscort + ' : décline poliment.', 'event-info');
    return;
  }

  if (resultat.contrepartie) {
    showToast('Confidence échangée', nomEscort + ' vous confie quelque chose en retour.', true, true);
    addJournalEntry('Échange de confidences avec ' + nomEscort + '. ' + resultat.contrepartie, 'event-good');
  } else {
    showToast('Confidence reçue', nomEscort + ' garde votre confidence, mais n\'a rien à partager pour l\'instant.', true);
    addJournalEntry('Vous avez confié un secret à ' + nomEscort + ', qui n\'avait rien à partager en retour.', 'event-info');
  }
}

// Phase 4 memoire des renseignements (22 aout 2026) : interrogatoire cible d'un PNJ sur un
// sujet libre. Reserve aux commissaires/juges (voir garde d'affichage du bouton plus haut).
// Le sujet part tel quel vers le serveur (api/renseignements.js, action interroger_pnj_sujet)
// qui fait entierement le ciblage IA, le jet, le tirage et l'ecriture -- ce client ne recoit
// jamais que le resultat final (ignorance/refus/revelation), jamais la memoire complete du PNJ.
function ouvrirModalInterrogatoireSujet(nomPnj, pnjJob) {
  document.getElementById('postes-modal-title').textContent = '🔍 Interroger ' + nomPnj;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#a09060;margin-bottom:.8rem">Sur quel sujet souhaitez-vous interroger ' + nomPnj + ' ?</div>' +
    '<textarea id="interrogatoire-sujet-texte" placeholder="Ex. Que savez-vous sur Gaby ?" maxlength="200" style="width:100%;min-height:3.5rem;margin-bottom:.7rem;background:#0a0805;border:1px solid #2a2010;color:#c0b090;font-size:.8rem;padding:.5rem;resize:vertical;box-sizing:border-box;font-family:Crimson Pro,serif"></textarea>' +
    '<button onclick="confirmerInterrogatoireSujet(\'' + nomPnj.replace(/'/g,'') + '\',\'' + (pnjJob || 'default').replace(/'/g,'') + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Interroger</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerInterrogatoireSujet(nomPnj, pnjJob) {
  const champ = document.getElementById('interrogatoire-sujet-texte');
  const sujet = (champ?.value || '').trim();
  if (!sujet) { showToast('Sujet requis', 'Précisez le sujet de l\'interrogatoire.', false); return; }
  document.getElementById('modal-postes').classList.remove('open');

  // CHA du PNJ desormais entierement geree cote serveur (revue de securite du 22 aout 2026,
  // avant GO) -- ce client ne calcule plus ni ne transmet de CHA pour ce jet.
  const nomEnqueteur = state.char?.name || 'Anonyme';

  const resultat = typeof sbInterrogerPnjSurSujet === 'function'
    ? await sbInterrogerPnjSurSujet(nomEnqueteur, nomPnj, sujet).catch(() => null)
    : null;

  if (!resultat || !resultat.ok || resultat.statut === 'ignorance') {
    showToast('Aucune information', nomPnj + ' affirme ne rien savoir sur ce sujet.', false);
    addJournalEntry('Interrogatoire de ' + nomPnj + ' sur "' + sujet + '" : ne sait rien.', 'event-info');
    return;
  }

  if (resultat.statut === 'refus' || !resultat.revelation) {
    showToast('Silence', nomPnj + ' refuse de vous en dire plus.', false);
    addJournalEntry('Interrogatoire de ' + nomPnj + ' sur "' + sujet + '" : refus de parler.', 'event-info');
    return;
  }

  showToast('Renseignement obtenu', nomPnj + ' vous confie quelque chose.', true, true);
  addJournalEntry('Interrogatoire de ' + nomPnj + ' sur "' + sujet + '". ' + resultat.revelation, 'event-good');
}

function doEscortPiege(pa, cost) {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';

  // Sélectionner une cible PJ dans le répertoire
  const pjContacts = (state.contacts || []).filter(c => c.isPJ || c.type === 'pj');
  if (pjContacts.length === 0) {
    showToast('Aucune cible', 'Vous devez avoir des PJ dans votre répertoire pour organiser un piège.', false);
    return;
  }
  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }

  // Modal de sélection de cible
  document.getElementById('postes-modal-title').textContent = '🕵 Choisir une cible';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Sélectionnez le PJ à piéger. Coût : ' + cost + ' ' + cur + '.</div>' +
    pjContacts.map(c =>
      '<div onclick="confirmerEscortPiege(\'' + c.name.replace(/'/g,'') + '\',' + pa + ',' + cost + ')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#1a1005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
        '<i class="ti ti-user" style="font-size:.9rem;color:#8a6a20"></i>' +
        '<div><div style="font-size:.82rem;color:#c0b090">' + c.name + '</div>' +
        '<div style="font-size:.85rem;color:#9a8a68">' + (c.role||'PJ') + '</div></div>' +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerEscortPiege(nomCible, pa, cost) {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';

  document.getElementById('modal-postes').classList.remove('open');

  if (state.arg < cost) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  // Stats commanditaire
  const dup = getStatEffective('DUP');
  const dis = state.dis || 50;

  // On simule les stats de la cible (on ne les a pas côté client)
  const cibleDUP = Math.floor(Math.random() * 6) + 6; // entre 6 et 12
  const cibleDIS = Math.floor(Math.random() * 40) + 30; // entre 30 et 70

  // Jet de succès
  const taux = Math.min(80, 30 + Math.floor(dup * 2) - Math.floor(cibleDUP * 1.5));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    // SUCCÈS
    const prompt = 'Res Publica, jeu politique parodique. ' + nomCible + ' vient d\'être piégé(e) par une escort dans un scandale compromettant. Génère UN titre de scandale parodique (1 phrase max, style journal à scandales). Réponds en texte brut uniquement, sans markdown (pas de #, pas de **).';
    let scandale = nomCible + ' impliqué(e) dans un scandale compromettant avec une escort.';
    try {
      const resp = await fetch('/api/chat', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 120, messages: [{ role: 'user', content: prompt }] })
      });
      const data = await resp.json();
      scandale = data.content?.[0]?.text?.trim() || scandale;
    } catch(e) {}

    // Effets sur commanditaire
    state.inf = Math.min(100, (state.inf||0) + 10);
    state.pop = Math.min(100, (state.pop||0) + 5);

    // Kompromat généré
    addToInventory({
      name: 'Kompromat sur ' + nomCible,
      icon: 'ti-file-shredder',
      type: 'kompromat',
      cible: nomCible,
      desc: scandale,
      legal: false,
      expireDay: (state.day||1) + 10
    });

    updateUI();
    addExternalEvent('📰 SCANDALE : ' + scandale);
    addJournalEntry('Piège réussi sur ' + nomCible + '. Scandale : "' + scandale.substring(0,60) + '"', 'event-good');
    showToast('Piège réussi !', scandale, true, true);

  } else {
    // ÉCHEC — argent perdu, la cible peut enquêter
    updateUI();
    addJournalEntry('Piège raté sur ' + nomCible + '. -' + cost + ' ' + cur + ' perdus.', 'event-bad');
    showToast('Piège raté', nomCible + ' a éventé la manœuvre. Argent perdu.', false);

    // Jet d\'enquête de la cible contre le commanditaire
    const tauxEnquete = Math.min(70, Math.floor(cibleDUP * 4) + Math.floor(cibleDIS / 10));
    const rollEnquete = Math.floor(Math.random() * 100) + 1;
    if (rollEnquete <= tauxEnquete) {
      // Cible trouve le commanditaire
      const tauxIdentif = Math.min(80, tauxEnquete - Math.floor(dup * 2) - Math.floor(dis / 10));
      const rollIdentif = Math.floor(Math.random() * 100) + 1;
      if (rollIdentif <= tauxIdentif) {
        state.pop = Math.max(0, (state.pop||0) - 15);
        state.dis = Math.max(0, (state.dis||50) - 10);
        updateUI();
        addExternalEvent('📰 ' + nomCible + ' révèle avoir été la cible d\'un complot orchestré par ' + (state.char?.name||'un personnage politique') + ' !');
        addJournalEntry('Enquête de ' + nomCible + ' : vous avez été identifié(e). -15 POP -10 DIS.', 'event-bad');
        showToast('Identifié(e) !', nomCible + ' vous a démasqué(e). -15 POP -10 DIS.', false);
      } else {
        addJournalEntry('La cible enquête mais ne vous retrouve pas.', 'event-info');
      }
    }
  }
}

function genererPnjTerrain(buildingId) {
  const country = state.country || 'republic';
  const profiles = (typeof TERRAIN_PNJ_PROFILES !== 'undefined')
    ? TERRAIN_PNJ_PROFILES[country] || TERRAIN_PNJ_PROFILES.republic
    : [];
  if (!profiles.length) return null;

  // Indices impériaux modifient les probabilités (Securite/Eco/Social calcules -- moyenne des
  // villes pour Republia, ancien national inchange pour les 3 autres empires ; Diplomatie reste
  // un indice national independant, non concerne)
  const idFallback = INDICES_NATIONAUX?.[country]?.ID ?? 40;
  const isn = typeof getIndiceNationalCalcule === 'function' ? getIndiceNationalCalcule(country, 'isn') : 30;
  const ie  = typeof getIndiceNationalCalcule === 'function' ? getIndiceNationalCalcule(country, 'ie') : 50;
  const id  = idFallback;
  const is  = typeof getIndiceNationalCalcule === 'function' ? getIndiceNationalCalcule(country, 'social') : 45;

  // Ajuster les probabilités selon indices
  const adjustedProfiles = profiles.map(p => {
    let prob = p.prob;
    if (p.id === 'squatter_agr')  prob = Math.max(0.01, prob - isn/200 - is/200);
    if (p.id === 'squatter_cool') prob = Math.max(0.02, prob - isn/300);
    if (p.id === 'cadavre')       prob = Math.max(0.005, prob + (100-id)/500);
    if (p.id === 'promoteur')     prob = Math.max(0.03, prob + ie/400);
    if (p.id === 'inspecteur')    prob = Math.max(0.05, prob + isn/300);
    if (p.id === 'vide')          prob = Math.max(0.05, prob + isn/200);
    return { ...p, prob };
  });

  // Normaliser et tirer au sort
  const total = adjustedProfiles.reduce((s, p) => s + p.prob, 0);
  let roll = Math.random() * total;
  for (const p of adjustedProfiles) {
    roll -= p.prob;
    if (roll <= 0) return p.id === 'vide' ? null : p;
  }
  return null;
}

async function interagirPnjTerrain(pnjId) {
  const country = state.country || 'republic';
  const profiles = TERRAIN_PNJ_PROFILES?.[country] || TERRAIN_PNJ_PROFILES?.republic || [];
  const pnj = profiles.find(p => p.id === pnjId);
  if (!pnj) return;

  const indices = INDICES_NATIONAUX?.[country] || { ISN:30, IE:50, ID:40, IS:45 };
  const is = indices.IS || 45;
  const cha = getStatEffective('CHA');
  const cur = COUNTRIES[country]?.cur || 'FR';

  // Squatteurs agressifs — jet CHA + IS
  if (pnj.agressif) {
    const bonusCHA = Math.floor(cha / 2);
    const bonusIS  = Math.floor(is / 10);
    const taux = Math.min(80, 20 + bonusCHA + bonusIS);
    const roll = Math.floor(Math.random() * 100) + 1;

    if (roll <= taux) {
      // Succès — CHA évite l'agression
      state.inf = Math.min(100, (state.inf||0) + 2);
      updateUI();
      addJournalEntry('Vous avez calmé les squatteurs par votre charisme. +2 INF.', 'event-good');
      showToast('Tension désamorcée !', 'Votre charisme a évité la bagarre. (Jet ' + roll + '/' + taux + '%)', true);
    } else {
      // Échec — bagarre
      const degats = Math.floor(Math.random() * 15) + 10;
      state.hp = Math.max(0, (state.hp||100) - degats);
      state.dis = Math.max(0, (state.dis||50) - 5);
      updateUI();
      addJournalEntry('Vous avez été attaqué par des squatteurs. -' + degats + ' HP. -5 DIS.', 'event-bad');
      showToast('Bagarre !', '-' + degats + ' HP · -5 DIS (Jet ' + roll + '/' + taux + '%)', false);
    }
    return;
  }

  // Squatteurs cools — bière et côtelette
  if (pnj.id === 'squatter_cool') {
    const hpBonus = Math.floor(Math.random() * 8) + 5;
    const moralBonus = Math.floor(Math.random() * 8) + 5;
    state.hp = Math.min(100, (state.hp||100) + hpBonus);
    state.moral = Math.min(100, (state.moral||50) + moralBonus);
    // Info gratuite parfois
    const infoBonus = Math.random() > 0.5;
    if (infoBonus) state.inf = Math.min(100, (state.inf||0) + 3);
    updateUI();
    addJournalEntry('Les squatteurs vous offrent bière et côtelette. +' + hpBonus + ' HP · +' + moralBonus + ' Moral' + (infoBonus ? ' · +3 INF' : '') + '.', 'event-good');
    showToast('Accueil chaleureux !', '+' + hpBonus + ' HP · +' + moralBonus + ' Moral' + (infoBonus ? ' · +3 INF (tuyau)' : ''), true);
    return;
  }

  // Cadavre — blocage administratif
  if (pnj.id === 'cadavre') {
    const id_idx = indices.ID || 40;
    const delai = Math.max(1, Math.round(5 - id_idx/25));
    state.dis = Math.max(0, (state.dis||50) - 10);
    updateUI();
    addJournalEntry('Cadavre découvert sur le terrain ! Enquête obligatoire. Blocage administratif : ' + delai + ' jour(s). -10 DIS.', 'event-bad');
    showToast('Cadavre découvert !', 'Enquête requise. Formalités bloquées ' + delai + ' jour(s). -10 DIS.', false);
    // Signaler à la police
    if (!state.recherche) state.recherche = [];
    addExternalEvent('🚨 Cadavre découvert sur un terrain à ' + (WORLD[country]?.[state.currentCity]?.name || 'la ville') + '. Enquête en cours.');
    return;
  }

  // Promoteur — propose rachat à prix gonflé
  if (pnj.id === 'promoteur') {
    const prixGonfle = Math.floor(Math.random() * 5000) + 6000;
    addJournalEntry(pnj.name + ' vous propose de racheter ce terrain pour ' + prixGonfle.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-info');
    showToast(pnj.name, 'Offre de rachat : ' + prixGonfle.toLocaleString('fr-FR') + ' ' + cur + '. Intéressant ?', true);
    return;
  }

  // Gardien — peut être soudoyé
  if (pnj.id === 'gardien') {
    const pot = Math.floor(isn / 5) * 10 + 100;
    document.getElementById('postes-modal-title').textContent = pnj.name + ' — Gardien';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem">' +
      '<div style="font-size:.82rem;color:#a09060;margin-bottom:.8rem;font-style:italic">"' + (pnj.trait || (pnj.job === 'escort' ? 'Je connais tous les secrets de cette ville. Mon tarif : 500 ' + (COUNTRIES[state.country]?.cur || 'FR') + '/réveil.' : 'Un personnage discret.')) + '"</div>' +
      '<button onclick="soudoyerGardienTerrain(' + pot + ');document.getElementById(\'modal-postes\').classList.remove(\'open\')" ' +
      'style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer;display:block;margin-bottom:.4rem;width:100%">' +
      '<i class="ti ti-coin"></i> Soudoyer (' + pot + ' ' + cur + ')</button>' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" ' +
      'style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer;width:100%">Partir</button>' +
      '</div>';
    document.getElementById('modal-postes').classList.add('open');
    return;
  }

  // Inspecteur — vérifie les permis
  if (pnj.id === 'inspecteur') {
    const aPermis = state.inventory?.find(i => i.type === 'permis' && i.building === state.currentBuilding);
    if (aPermis) {
      addJournalEntry(pnj.name + ' vérifie vos permis. Tout est en ordre.', 'event-info');
      showToast('Contrôle passé', 'Vos permis sont valides.', true);
    } else {
      state.dis = Math.max(0, (state.dis||50) - 8);
      updateUI();
      addJournalEntry(pnj.name + ' vous demande un permis de construire. Vous n\'en avez pas. -8 DIS.', 'event-bad');
      showToast('Contrôle raté !', 'Permis manquant. -8 DIS.', false);
    }
    return;
  }

  // Par défaut — juste parler
  showToast(pnj.name, pnj.trait || 'Un personnage mystérieux.', true);
}

function soudoyerGardienTerrain(montant) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < montant) {
    showToast('Fonds insuffisants', montant + ' ' + cur + ' requis.', false);
    return;
  }
  const dup = getStatEffective('DUP');
  const taux = Math.min(80, 40 + Math.floor(dup/2));
  const roll = Math.floor(Math.random() * 100) + 1;
  state.arg -= montant;
  if (roll <= taux) {
    state.dis = Math.min(100, (state.dis||50) + 5);
    updateUI();
    showToast('Gardien soudoyé !', 'Il regarde ailleurs. +5 DIS.', true);
    addJournalEntry('Gardien soudoyé pour ' + montant + ' ' + cur + '. -' + montant + ' ' + cur + ' · +5 DIS.', 'event-good');
  } else {
    state.dis = Math.max(0, (state.dis||50) - 10);
    updateUI();
    showToast('Refus !', 'Il n\'a pas accepté. -10 DIS.', false);
    addJournalEntry('Tentative de corruption du gardien refusée. -' + montant + ' ' + cur + ' · -10 DIS.', 'event-bad');
  }
}

function chargerPnjTerrain(buildingId) {
  if (!buildingId?.startsWith('terrain-a-batir')) return;

  // Vérifier si état persistant existe déjà
  const ts = getTerrainState(buildingId);

  // Si police est intervenue, vider le PNJ
  if (ts.policeInterventionAt && Date.now() > ts.policeInterventionAt && ts.pnj) {
    setTerrainState(buildingId, { pnj: null, pnjData: null, policeAppellee: null, policeInterventionAt: null });
    sessionStorage.removeItem('terrain_pnj_' + buildingId);
    showToast('Terrain libéré', 'La police est intervenue.', true);
    return;
  }

  // Utiliser le PNJ persistant si disponible
  if (ts.pnjData) {
    sessionStorage.setItem('terrain_pnj_' + buildingId, JSON.stringify({
      name: ts.pnjData.name + ' (PNJ)',
      role: ts.pnjData.role,
      job: ts.pnjData.job,
      rel: ts.pnjData.rel,
      trait: ts.pnjData.trait,
      photoUrl: ts.pnjData.photoUrl,
      photoPos: ts.pnjData.photoPos,
      terrainPnjId: ts.pnjData.id
    }));
    return;
  }

  // Générer automatiquement au premier passage
  const pnjObj = genererPnjTerrain(buildingId);
  if (pnjObj) {
    setTerrainState(buildingId, { pnj: pnjObj.id, pnjData: pnjObj, dateGeneration: Date.now() });
    sessionStorage.setItem('terrain_pnj_' + buildingId, JSON.stringify({
      name: pnjObj.name + ' (PNJ)', role: pnjObj.role, job: pnjObj.job,
      rel: pnjObj.rel, trait: pnjObj.trait, photoUrl: pnjObj.photoUrl,
      photoPos: pnjObj.photoPos, terrainPnjId: pnjObj.id
    }));
  } else {
    sessionStorage.removeItem('terrain_pnj_' + buildingId);
  }
}

async function getTerrainsVraimentLibres(country) {
  if (typeof sbGetTerrainsLibres !== 'function') return [];
  try {
    const tousLesEtats = await sbGetTerrainsLibres(country);
    const occupes = new Set(tousLesEtats.filter(t => t.proprietaire).map(t => t.building_id));

    const terrainsLibres = [];
    const villesDuPays = WORLD[country] || {};
    Object.entries(villesDuPays).forEach(([cityId, cityData]) => {
      (cityData.buildings || []).forEach(bId => {
        if (bId.startsWith('terrain-a-batir') && !occupes.has(bId)) {
          terrainsLibres.push({ buildingId: bId, cityId });
        }
      });
    });
    return terrainsLibres;
  } catch(e) { console.warn('getTerrainsVraimentLibres error', e); return []; }
}

// NOTE : getTerrainState/setTerrainState sont definies dans plateau-justice-economie.js
// (systeme unifie, base sur state.terrainsState + Supabase). Une ancienne version basee sur
// localStorage vivait ici, mais etait silencieusement ecrasee (dernier fichier charge gagne
// en JS) — code mort supprime le 3 aout 2026 pour eviter toute confusion future.

function terrainOrdreDisponible(fn, buildingId) {
  const ts = getTerrainState(buildingId);
  const pnj = ts.pnj; // PNJ persistant sur ce terrain

  // Ordres bloqués si cadavre présent
  if (pnj === 'cadavre') {
    const bloques = ['signer_compromis', 'permis_construire', 'permis_corrompu', 'acheter_terrain'];
    if (bloques.includes(fn)) return { ok: false, raison: 'Un cadavre bloque les démarches administratives. Résolvez la situation d\'abord.' };
  }

  // Ordres bloqués si squatteurs présents
  if (pnj === 'squatter_agr' || pnj === 'squatter_cool') {
    if (fn === 'signer_compromis') return { ok: false, raison: 'Des squatteurs occupent le terrain. Faites intervenir la police ou négociez leur départ.' };
  }

  // Ordre cadavre seulement si cadavre présent
  if (fn === 'faire_disparaitre_cadavre' && pnj !== 'cadavre')
    return { ok: false, raison: 'Aucun cadavre sur ce terrain.' };

  // Ordre négociation seulement si squatteurs présents
  if (fn === 'negocier_squatteurs' && pnj !== 'squatter_agr' && pnj !== 'squatter_cool')
    return { ok: false, raison: 'Aucun squatteur à négocier.' };

  // Chantier H2A (28 aout 2026) : un terrain deja possede (par un joueur ou par Helvetia apres
  // saisie, biens_saisis_helvetia) ne doit jamais etre achetable en direct (acheter_terrain,
  // parcours sans RPC dediee) -- seul le compromis (signer_compromis, correctement route vers
  // signer_compromis_bien_helvetia pour un bien Helvetia) est la voie valide pour un bien qui a
  // deja un proprietaire.
  if (fn === 'acheter_terrain' && ts.proprietaire) {
    return { ok: false, raison: 'Ce terrain a déjà un propriétaire. Passez par un compromis de vente.' };
  }

  // Terrain verrouille pour les autres joueurs tant qu'un compromis est actif (non expire)
  const compromisActif = ts.compromis && ts.compromisExpireAt && Date.now() < ts.compromisExpireAt;
  if (compromisActif && ts.compromisPar !== state.char?.name) {
    if (fn === 'acheter_terrain' || fn === 'signer_compromis') {
      return { ok: false, raison: 'Un compromis de vente est déjà en cours sur ce terrain (détenu par ' + ts.compromisPar + ').' };
    }
  }

  // Terrain verrouille pour les autres joueurs tant qu'un achat direct est en attente de
  // rendez-vous notarial (meme principe que le compromis)
  const achatDirectActif = ts.achatDirect && ts.achatDirect.dateLimite && Date.now() < ts.achatDirect.dateLimite;
  if (achatDirectActif && ts.achatDirect.demandeur !== state.char?.name) {
    if (fn === 'acheter_terrain' || fn === 'signer_compromis') {
      return { ok: false, raison: 'Un rendez-vous notarial est déjà en cours sur ce terrain (' + ts.achatDirect.demandeur + ').' };
    }
  }

  return { ok: true };
}

function doVerifierTerrain() {
  const id = state.currentBuilding;
  let ts = getTerrainState(id);

  if (!ts.pnj) {
    // Générer et persister le PNJ
    const pnjObj = genererPnjTerrain(id);
    ts = setTerrainState(id, {
      pnj: pnjObj ? pnjObj.id : null,
      pnjData: pnjObj || null,
      dateGeneration: Date.now()
    });
    // Mettre à jour le sessionStorage aussi pour l'affichage
    if (pnjObj) {
      sessionStorage.setItem('terrain_pnj_' + id, JSON.stringify({
        name: pnjObj.name + ' (PNJ)', role: pnjObj.role, job: pnjObj.job,
        rel: pnjObj.rel, trait: pnjObj.trait, terrainPnjId: pnjObj.id,
        photoUrl: pnjObj.photoUrl, photoPos: pnjObj.photoPos
      }));
    } else {
      sessionStorage.removeItem('terrain_pnj_' + id);
    }
  }

  const pnj = ts.pnjData;
  if (!pnj) {
    addJournalEntry('Terrain inspecté. Rien à signaler.', 'event-info');
    showToast('Terrain libre', 'Aucun obstacle. Vous pouvez procéder aux démarches.', true);
  } else {
    addJournalEntry('Terrain inspecté. ' + (pnj.role || 'Présence') + ' détectée.', 'event-info');
    showToast(pnj.role || 'Obstacle détecté', pnj.trait || '', pnj.rel !== 'enemy');
  }

  // Recharger la pièce complète pour afficher le PNJ
  if (state.currentRoom && state.currentBuilding) {
    enterRoom(state.currentBuilding, state.currentRoom);
  }
}

function doAppelerPoliceTerrain() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN: 30 };
  const isn = indices.ISN || 30;
  const delaiH = Math.max(6, Math.round(96 - isn * 0.6));
  const delaiRapideH = Math.max(1, Math.round(delaiH / 4));
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const coutSoudoiement = Math.floor(100 + isn * 3);

  document.getElementById('postes-modal-title').textContent = '🚔 Appeler la police';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.8rem">' +
      (pnj ? 'Présence détectée : <strong>' + pnj.role + '</strong>.' : 'Terrain occupé.') +
    '</div>' +
    '<div style="display:flex;flex-direction:column;gap:.5rem">' +
    '<button onclick="doExpulsionLegale();fermerModalPostes()" ' +
    'style="text-align:left;padding:.6rem .8rem;border:1px solid #3a5a3a;background:#0a0f0a;color:#6ada6a;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.06em;cursor:pointer">' +
    '⚖️ Expulsion légale — délai ' + delaiH + 'h (gratuit)</button>' +
    '<button onclick="doExpulsionAcceleree(' + coutSoudoiement + ');fermerModalPostes()" ' +
    'style="text-align:left;padding:.6rem .8rem;border:1px solid #5a5a20;background:#0a0f00;color:#C9A84C;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.06em;cursor:pointer">' +
    '💰 Soudoyer l\'inspecteur — ' + coutSoudoiement + ' ' + cur + ' · délai ' + delaiRapideH + 'h</button>' +
    '<button onclick="fermerModalPostes()" ' +
    'style="padding:.4rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;font-family:Bebas Neue,sans-serif;font-size:.68rem;cursor:pointer">Annuler</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function doExpulsionAcceleree(cout) {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN: 30 };
  const isn = indices.ISN || 30;
  const delaiRapideH = Math.max(1, Math.round((96 - isn * 0.6) / 4));
  const dup = getStatEffective('DUP');
  const taux = Math.min(80, 40 + Math.floor(dup * 2));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (state.arg < cout) { showToast('Fonds insuffisants', cout + ' ' + cur + ' requis.', false); return; }

  state.arg -= cout;
  if (roll <= taux) {
    setTerrainState(id, {
      policeAppellee: Date.now(),
      policeInterventionAt: Date.now() + delaiRapideH * 3600000
    });
    state.dis = Math.max(0, (state.dis || 50) - 5);
    updateUI();
    addJournalEntry('Inspecteur soudoyé pour ' + cout + ' ' + cur + '. Expulsion dans ' + delaiRapideH + 'h. -5 DIS.', 'event-good');
    showToast('Arrangé !', 'Expulsion dans ' + delaiRapideH + 'h. -' + cout + ' ' + cur + ' · -5 DIS.', true);
  } else {
    state.dis = Math.max(0, (state.dis || 50) - 15);
    updateUI();
    addJournalEntry('Tentative de corruption refusée. -' + cout + ' ' + cur + ' · -15 DIS.', 'event-bad');
    showToast('Refus !', 'L\'inspecteur a refusé. -' + cout + ' ' + cur + ' · -15 DIS.', false);
  }
}

async function doFaireDisparaitreCadavre(pa, cost) {
  const id = state.currentBuilding;
  // Revalidation au commit (bug remonte avant Phase L, meme pattern que negocier_squatteurs) :
  // aucun code ne verifiait jusqu'ici qu'un cadavre existe reellement avant le jet -- un joueur
  // pouvait "dissimuler" un cadavre inexistant et, en cas d'echec du jet, subir -20 DIS -5 HP et
  // une entree state.recherche de 24h pour un crime qui n'a jamais eu lieu.
  const dispo = typeof terrainOrdreDisponible === 'function' ? terrainOrdreDisponible('faire_disparaitre_cadavre', id) : { ok: true };
  if (!dispo.ok) { showToast('Aucun cadavre', dispo.raison || 'Aucun cadavre a dissimuler.', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  const ts = getTerrainState(id);
  const indices = INDICES_NATIONAUX?.[state.country] || { ISN: 30, ID: 40 };
  const isn = indices.ISN || 30;
  const id_idx = indices.ID || 40;

  const dis = state.dis || 50;
  const cha = getStatEffective('CHA');
  const bonusOrga = calculerBonusOrga();
  const taux = Math.min(85, Math.floor(dis/2 + cha/2) - Math.floor(isn/5) + (bonusOrga.dis || 0) / 3);
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    // Succès — cadavre disparu
    const prescriptionJours = Math.max(7, Math.round(id_idx * 0.6));
    setTerrainState(id, {
      pnj: null, pnjData: null,
      cadavreDisparuAt: Date.now(),
      prescriptionAt: Date.now() + prescriptionJours * 86400000,
      actesIllegaux: [...(ts.actesIllegaux || []), {
        type: 'cadavre_dissimule',
        auteur: state.char?.name,
        date: Date.now(),
        prescriptionAt: Date.now() + prescriptionJours * 86400000
      }]
    });
    sessionStorage.removeItem('terrain_pnj_' + id);
    state.dis = Math.max(0, (state.dis || 50) - 5);
    updateUI();
    addJournalEntry('Cadavre dissimulé avec succès. Jet ' + roll + '/' + taux + '%. Prescription dans ' + prescriptionJours + ' jours.', 'event-good');
    showToast('Cadavre dissimulé !', 'Terrain libre. Prescription dans ' + prescriptionJours + ' jours. -5 DIS.', true);
  } else {
    // Échec — garde à vue
    state.dis = Math.max(0, (state.dis || 50) - 20);
    state.hp = Math.max(0, (state.hp || 100) - 5);
    updateUI();
    addJournalEntry('Flagrant délit ! Garde à vue de 24h. Jet ' + roll + '/' + taux + '%. -20 DIS · -5 HP.', 'event-bad');
    showToast('Arrêté !', 'Garde à vue 24h. -20 DIS · -5 HP. (Jet ' + roll + '/' + taux + '%)', false);
    // Bloquer le joueur 24h
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ type: 'suspicion_cadavre', terrain: id, debut: Date.now(), fin: Date.now() + 86400000 });
    addExternalEvent('🚨 ' + (state.char?.name) + ' a été arrêté pour suspicion de dissimulation de cadavre à ' + (WORLD[state.country]?.[state.currentCity]?.name || 'la ville') + '.');
  }
}

// Bareme par paliers (interpolation lineaire entre paliers), plafond +20 a 4000+
const PALIERS_BONUS_ARGENT_SQUATTEURS = [[0,0],[500,5],[1000,8],[2000,12],[3000,16],[4000,20]];
function bonusArgentSquatteurs(montant) {
  const m = montant || 0;
  if (m >= 4000) return 20;
  for (let i = 0; i < PALIERS_BONUS_ARGENT_SQUATTEURS.length - 1; i++) {
    const [m1, b1] = PALIERS_BONUS_ARGENT_SQUATTEURS[i], [m2, b2] = PALIERS_BONUS_ARGENT_SQUATTEURS[i+1];
    if (m >= m1 && m <= m2) return Math.floor(b1 + (b2 - b1) * (m - m1) / (m2 - m1));
  }
  return 0;
}

// Formule partagee entre l'affichage en direct du modal et la resolution reelle, pour ne
// jamais pouvoir diverger. cha via getStatEffective : reflete deja la moyenne de groupe.
// Doctrine V2, formule validee : P = Base(50, valeur neutre non precisee par la doctrine --
// a ajuster si besoin) + 2*(CHA_groupe-13) + (Social_ville-50)/5 + bonus_argent (bareme dedie).
// Garde l'exception Crime+Syndicat (intimidation automatique, voir bonusOrga) intouchee.
function calculerTauxNegociationSquatteurs(montant) {
  const cha = getStatEffective('CHA');
  const socialVille = (typeof getIndiceVille === 'function') ? getIndiceVille(state.country, state.currentCity || 'capitale', 'social') : 45;
  const bonusArgent = bonusArgentSquatteurs(montant);
  const bonusOrga2 = calculerBonusOrga();
  const taux = 50 + 2 * (cha - 13) + (socialVille - 50) / 5 + bonusArgent + (bonusOrga2.nego_cha || 0);
  return Math.max(5, Math.min(90, Math.round(taux)));
}

function majTauxNegociationLive() {
  const montant = parseInt(document.getElementById('negoc-montant')?.value || 0);
  const taux = calculerTauxNegociationSquatteurs(montant);
  const el = document.getElementById('negoc-taux-live');
  if (el) el.textContent = 'Chances de succès actuelles : ' + taux + '%';
}

function doNegocierSquatteurs(pa, cost) {
  const id = state.currentBuilding;
  // Revalidation a l'ouverture (bug remonte avant Phase L) : requiresSquatteurs n'etait lu par
  // aucun code, le bouton restait affiche/cliquable sans squatteur reel. terrainOrdreDisponible
  // est la meme verification deja utilisee pour signer_compromis/acheter_terrain.
  const dispo = typeof terrainOrdreDisponible === 'function' ? terrainOrdreDisponible('negocier_squatteurs', id) : { ok: true };
  if (!dispo.ok) { showToast('Aucun squatteur', dispo.raison || 'Aucun squatteur a negocier.', false); return; }
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const minMontant = pnj?.id === 'squatter_agr' ? 500 : 0;

  document.getElementById('postes-modal-title').textContent = 'Négocier le départ';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.6rem;font-style:italic">"' + (pnj?.trait || '') + '"</div>' +
    (minMontant > 0 ? '<div style="font-size:.7rem;color:#8a3a2a;margin-bottom:.5rem">Ces squatteurs refuseront toute offre inférieure à ' + minMontant + ' ' + cur + '.</div>' : '') +
    '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.4rem">Chaque 100 ' + cur + ' supplémentaires améliorent vos chances de +1%. Qui vous accompagne compte aussi.</div>' +
    '<input id="negoc-montant" type="number" min="' + minMontant + '" step="100" placeholder="Montant proposé..." oninput="majTauxNegociationLive()" ' +
    'style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,Georgia,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.4rem"/>' +
    '<div id="negoc-taux-live" style="font-size:.78rem;color:#C9A84C;font-weight:bold;margin-bottom:.6rem">Chances de succès actuelles : ' + calculerTauxNegociationSquatteurs(minMontant) + '%</div>' +
    '<button onclick="confirmerNegociation(' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Négocier</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerNegociation(pa, cost) {
  const id = state.currentBuilding;
  // Revalidation au commit (bug remonte avant Phase L) : la modale peut avoir ete ouverte
  // avant que le squat ne disparaisse (police appelee, negociation menee ailleurs, etc.) --
  // aucun PA ni argent ne doit etre preleve si le squat n'existe plus reellement.
  const dispo = typeof terrainOrdreDisponible === 'function' ? terrainOrdreDisponible('negocier_squatteurs', id) : { ok: true };
  if (!dispo.ok) {
    document.getElementById('modal-postes').classList.remove('open');
    showToast('Aucun squatteur', dispo.raison || 'Aucun squatteur a negocier.', false);
    return;
  }
  const ts = getTerrainState(id);
  const pnj = ts.pnjData;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const montant = parseInt(document.getElementById('negoc-montant')?.value || 0);

  if (!montant || montant < (pnj?.id === 'squatter_agr' ? 500 : 0)) {
    showToast('Montant insuffisant', 'Les squatteurs refusent.', false);
    return;
  }
  if (getFondsDisponiblesOrdinaires() < montant) {
    showToast('Fonds insuffisants', 'Vous n\'avez pas ' + montant + ' ' + cur + '.', false);
    return;
  }
  const rNegoc = await deduireCoutOrdre({ pa, cost });
  if (!rNegoc.ok) { showToast('PA insuffisants', '', false); return; }

  // La benediction ne se consomme qu'ici, a la resolution reelle -- pas dans
  // calculerTauxNegociationSquatteurs, appelee aussi par l'apercu en direct du modal (elle
  // bruleraitle bonus a chaque frappe clavier sinon).
  let taux = calculerTauxNegociationSquatteurs(montant);
  taux = (typeof consommerBonusBenediction === 'function') ? consommerBonusBenediction(taux) : taux;
  taux = Math.max(5, Math.min(95, Math.round(taux)));
  const roll = Math.floor(Math.random() * 100) + 1;
  const succesNego = roll <= taux;

  const debitNego = await debiterFondsOrdinaires(montant);
  if (!debitNego.ok) { showToast('Fonds insuffisants', 'Vous n\'avez pas ' + montant + ' ' + cur + '.', false); return; }
  document.getElementById('modal-postes').classList.remove('open');

  if (succesNego) {
    setTerrainState(id, { pnj: null, pnjData: null });
    sessionStorage.removeItem('terrain_pnj_' + id);
    updateUI();
    addJournalEntry('Squatteurs convaincus pour ' + montant + ' ' + cur + '. Jet ' + roll + '/' + taux + '%.', 'event-good');
    showToast('Terrain libéré !', 'Les squatteurs sont partis. -' + montant + ' ' + cur, true);
  } else {
    updateUI();
    addJournalEntry('Négociation échouée. ' + montant + ' ' + cur + ' perdus. Jet ' + roll + '/' + taux + '%.', 'event-bad');
    showToast('Refus !', 'Ils ont pris l\'argent mais restent. -' + montant + ' ' + cur, false);
  }
}

const ACOMPTE_COMPROMIS = 1000;
const PLAFOND_PRET_COMPROMIS = 150000;

// Ouvre une seule fenetre combinant les 3 clauses du compromis : acompte (obligatoire),
// demande de pret (optionnelle), demande de permis (optionnelle). Tout est lance en un clic,
// resolu de facon atomique a J+7 (voir resoudreCompromisExpires, cote cron).
async function doSignerCompromis(pa, cost) {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  // Chantier H2A (28 aout 2026) : un terrain saisi par Helvetia (proprietaire==='Helvetia', voir
  // biens_saisis_helvetia) reste visible et achetable dans ce meme ecran notarial, jamais un
  // marche separe -- seul le traitement financier de la confirmation differe (RPC dediee, voir
  // doConfirmerCompromis). Terrain + construction deja existants : pas de clause "permis" ici.
  const ts = getTerrainState(id);
  const estHelvetia = ts.proprietaire === 'Helvetia';

  const dispo = terrainOrdreDisponible('signer_compromis', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }
  if (state.arg < ACOMPTE_COMPROMIS) {
    showToast('Fonds insuffisants', ACOMPTE_COMPROMIS + ' ' + cur + ' requis pour l\'acompte.', false);
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">' + (estHelvetia
    ? 'Bien saisi par la Banque Privée Helvetia, terrain et construction intacts. Le compromis réserve ce bien 7 jours. Aucun frais de notaire, aucun rabais.'
    : 'Le compromis réserve ce terrain 7 jours. À l\'échéance, les clauses ci-dessous sont tranchées automatiquement (banque, mairie).') + '</div>';

  html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.6rem">';
  html += '<div style="font-size:.85rem;color:#c0b090">✓ Versement de l\'acompte</div>';
  html += '<div style="font-size:.72rem;color:#6a5a30">' + ACOMPTE_COMPROMIS + ' ' + cur + ' — déduits du prix final à la vente, ou remboursés/perdus selon l\'issue.</div>';
  html += '</div>';

  html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.6rem">';
  html += '<label style="display:flex;align-items:center;gap:.4rem;font-size:.85rem;color:#c0b090;cursor:pointer"><input type="checkbox" id="compromis-pret-check" onchange="document.getElementById(\'compromis-pret-champs\').style.display=this.checked?\'block\':\'none\'" /> Demander un prêt à la Banque Nationale</label>';
  html += '<div id="compromis-pret-champs" style="display:none;margin-top:.5rem">';
  html += '<div style="display:flex;gap:.4rem">';
  html += '<input id="compromis-pret-montant" type="number" placeholder="Montant (max ' + PLAFOND_PRET_COMPROMIS.toLocaleString('fr-FR') + ')" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-size:.78rem;outline:none" />';
  html += '<input id="compromis-pret-duree" type="number" placeholder="Durée (jours)" value="30" style="width:120px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-size:.78rem;outline:none" />';
  html += '</div>';
  html += '</div>';
  html += '</div>';

  if (!estHelvetia) {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.8rem">';
    html += '<label style="display:flex;align-items:center;gap:.4rem;font-size:.85rem;color:#c0b090;cursor:pointer"><input type="checkbox" id="compromis-permis-check" onchange="document.getElementById(\'compromis-permis-champs\').style.display=this.checked?\'block\':\'none\'" /> Demander un permis de construire</label>';
    html += '<div id="compromis-permis-champs" style="display:none;margin-top:.5rem">';
    html += '<select id="compromis-permis-type" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-size:.78rem;outline:none">';
    Object.entries(NIVEAUX_CONSTRUCTION || {}).forEach(function([key, niv]) {
      html += '<option value="' + key + '">' + niv.label + ' (' + niv.cout.toLocaleString('fr-FR') + ' ' + cur + ')</option>';
    });
    html += '</select>';
    html += '</div>';
    html += '</div>';
  }

  html += '<button class="pnj-action-btn" onclick="doConfirmerCompromis(' + pa + ',' + cost + ')">Signer le compromis</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Compromis de vente';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doConfirmerCompromis(pa, cost) {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Signer un compromis')) return;

  const ts = getTerrainState(id);
  const estHelvetia = ts.proprietaire === 'Helvetia';

  const demandePret = document.getElementById('compromis-pret-check')?.checked;
  const montantPret = parseInt(document.getElementById('compromis-pret-montant')?.value || 0);
  const dureePret = parseInt(document.getElementById('compromis-pret-duree')?.value || 30);
  const demandePermis = document.getElementById('compromis-permis-check')?.checked;
  const typePermis = document.getElementById('compromis-permis-type')?.value;

  if (demandePret && (!montantPret || montantPret < 1000 || montantPret > PLAFOND_PRET_COMPROMIS)) {
    showToast('Montant invalide', 'Entre 1000 et ' + PLAFOND_PRET_COMPROMIS.toLocaleString('fr-FR') + ' ' + cur + '.', false);
    return;
  }

  if (estHelvetia) {
    // Chantier H2A (28 aout 2026) : bien saisi par Helvetia -- l'acompte (1000 FR, fonds
    // ordinaires) est debite ATOMIQUEMENT par signer_compromis_bien_helvetia (RPC installee),
    // jamais par deduireCoutOrdre/setTerrainState local -- la RPC reste la seule source de
    // verite financiere. RPC d'abord, PA ensuite (meme principe que le pret Helvetia).
    if (!TEST_MODE && (state.pa || 0) < pa) { showToast('PA insuffisants', '', false); return; }
    const resultatHelvetia = (typeof sbSignerCompromisBienHelvetia === 'function')
      ? await sbSignerCompromisBienHelvetia(state.char?.name, id).catch(() => null)
      : null;
    if (!resultatHelvetia) { showToast('Compromis refusé', 'Fonds ordinaires insuffisants pour l\'acompte, ou bien déjà sous compromis.', false); return; }
    if (!TEST_MODE) state.pa = Math.max(0, (state.pa || 0) - pa);

    // La RPC a deja persiste compromis/compromisPar/acompte/compromisAt/compromisExpireAt cote
    // serveur -- on recharge le cache local avant d'y fusionner, le cas echeant, la demande de
    // pret national (champ purement client, lu plus tard par resoudre_compromis_helvetia_expire).
    await chargerTerrainState(id);
    if (demandePret) {
      const taux = typeof getTauxPret === 'function' ? getTauxPret('nationale') : 5;
      const montantTotal = Math.round(montantPret * (1 + taux / 100));
      const nouvelEtat = setTerrainState(id, {
        pretDemande: {
          demandeur: state.char?.name,
          montant: montantPret,
          montantTotal: montantTotal,
          duree: dureePret,
          mensualite: Math.ceil(montantTotal / dureePret),
          statut: 'attente_validation'
        }
      });
      if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});
    }

    document.getElementById('modal-postes')?.classList.remove('open');
    updateUI();
    addJournalEntry('Compromis signé sur un bien Helvetia pour ' + ACOMPTE_COMPROMIS + ' ' + cur + '. Valable 7 jours.' + (demandePret ? ' Prêt demandé.' : ''), 'event-good');
    showToast('Compromis signé !', 'Bien réservé 7 jours auprès d\'Helvetia. -' + ACOMPTE_COMPROMIS + ' ' + cur, true);
    return;
  }

  const rCompromis = await deduireCoutOrdre({ pa, cost });
  if (!rCompromis.ok) { showToast('PA insuffisants', '', false); return; }

  const patch = {
    compromis: true,
    compromisPar: state.char?.name,
    acompte: ACOMPTE_COMPROMIS,
    compromisAt: Date.now(),
    compromisExpireAt: Date.now() + 7 * 86400000
  };

  if (demandePret) {
    const taux = typeof getTauxPret === 'function' ? getTauxPret('nationale') : 5;
    const montantTotal = Math.round(montantPret * (1 + taux / 100));
    patch.pretDemande = {
      demandeur: state.char?.name,
      montant: montantPret,
      montantTotal: montantTotal,
      duree: dureePret,
      mensualite: Math.ceil(montantTotal / dureePret),
      statut: 'attente_validation'
    };
  }
  if (demandePermis && typePermis) {
    patch.permis = {
      demandeur: state.char?.name,
      palierDemande: typePermis,
      statut: 'attente_validation',
      dateEntreeAttente: Date.now()
    };
  }

  const nouvelEtat = setTerrainState(id, patch);
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  addJournalEntry('Compromis de vente signé pour ' + ACOMPTE_COMPROMIS + ' ' + cur + '. Valable 7 jours.' + (demandePret ? ' Prêt demandé.' : '') + (demandePermis ? ' Permis demandé.' : ''), 'event-good');
  showToast('Compromis signé !', 'Terrain réservé 7 jours. -' + ACOMPTE_COMPROMIS + ' ' + cur, true);
}

// Surface reelle de chaque lot (m2), source de verite unique pour le prix au m2 et pour la
// future taxe fonciere (le cron cote serveur lira aussi cette valeur une fois stockee dans
// l'etat du terrain — voir doAcheterTerrain ci-dessous).
const SURFACE_TERRAINS = {
  'terrain-a-batir-1': 2150,
  'terrain-a-batir-2': 2300,
  'terrain-a-batir-3': 2300,
  'terrain-a-batir-4': 1850,
  'terrain-a-batir-5': 2750,
  // Lot 2D (19 aout 2026) -- 5 nouveaux terrains de Montrouge, prix a 12 FR/m² valide par Fred.
  // Le lot 6 existant n'a volontairement AUCUNE entree ici (sa superficie n'a jamais ete
  // officiellement fixee) : ne pas lui en ajouter une dans ce lot, cf. plateau-rue-centrale.js.
  'terrain-a-batir-montrouge-3': 1500,
  'terrain-a-batir-montrouge-7': 1800,
  'terrain-a-batir-montrouge-8': 2200,
  'terrain-a-batir-montrouge-9': 2500,
  'terrain-a-batir-montrouge-12': 3000
};
const PRIX_AU_M2_TERRAIN = 12;

const ACOMPTE_ACHAT_DIRECT = 1000;

// Achat direct (sans compromis) : depot de garantie immediat, rendez-vous chez le notaire
// fixe a une date aleatoire (2 a 7 jours), avec 24h de rattrapage si le jour venu le joueur
// n'est pas passe finaliser. Le solde du prix (moins l'acompte) est paye au notaire, pas ici.
async function doAcheterTerrain() {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Acheter ce terrain')) return;

  const dispo = terrainOrdreDisponible('acheter_terrain', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }
  if (state.arg < ACOMPTE_ACHAT_DIRECT) {
    showToast('Fonds insuffisants', ACOMPTE_ACHAT_DIRECT + ' ' + cur + ' requis pour le dépôt de garantie.', false);
    return;
  }

  // Deduction PA+cout centralisee (Lot 2C) -- avant toute mutation (setTerrainState, Supabase).
  const r = await deduireCoutOrdre({ pa: 2, cost: ACOMPTE_ACHAT_DIRECT });
  if (!r.ok) { showToast(r.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Fonds insuffisants', r.raison === 'pa_insuffisants' ? '2 PA requis.' : ACOMPTE_ACHAT_DIRECT + ' ' + cur + ' requis pour le dépôt de garantie.', false); return; }

  const surface = SURFACE_TERRAINS[id] || 2000;
  const prix = surface * PRIX_AU_M2_TERRAIN;
  const delaiJours = 2 + Math.floor(Math.random() * 6); // 2 a 7 jours
  const dateAchat = Date.now() + delaiJours * 86400000;
  const dateLimite = dateAchat + 24 * 3600000;

  const nouvelEtat = setTerrainState(id, {
    achatDirect: {
      demandeur: state.char?.name,
      acompte: ACOMPTE_ACHAT_DIRECT,
      prix: prix,
      surface: surface,
      dateAchat: dateAchat,
      dateLimite: dateLimite
    }
  });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  const dateTxt = new Date(dateAchat).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });
  updateUI();
  addJournalEntry('Dépôt de garantie versé (' + ACOMPTE_ACHAT_DIRECT + ' ' + cur + '). Rendez-vous chez le notaire fixé au ' + dateTxt + ' pour finaliser l\'achat.', 'event-good');
  showToast('Dépôt versé !', 'Rendez-vous chez le notaire le ' + dateTxt + '. -' + ACOMPTE_ACHAT_DIRECT + ' ' + cur, true);
  if (typeof sendMail === 'function') {
    await sendMail(state.char?.name, 'Office Notarial', 'Rendez-vous fixé — achat de terrain',
      'Votre rendez-vous pour la signature de l\'acte de vente est fixé au ' + dateTxt + '. Présentez-vous à l\'Office Notarial ce jour-là (une tolérance de 24h est accordée en cas d\'absence). Passé ce délai, le dépôt de garantie sera perdu et le terrain remis en vente.');
  }
}

// Finalise reellement l'acquisition d'un terrain (proprietaire, surface, valeur, Supabase,
// copropriete du conjoint). Reutilisee par la signature chez le notaire, que ce soit a
// l'issue d'un compromis ou d'un achat direct avec rendez-vous.
async function finaliserAchatTerrain(id, prix, surface, aPermis) {
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, "Finaliser l'achat")) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[id];
  const localName = b?.shortName || b?.name || id;

  let coproprietaire = null;
  if (typeof sbGetMariageActif === 'function') {
    try {
      const mariage = await sbGetMariageActif(state.char?.name);
      if (mariage) {
        coproprietaire = mariage.conjoint1 === state.char?.name ? mariage.conjoint2 : mariage.conjoint1;
      }
    } catch(e) {}
  }

  const nouvelEtat = setTerrainState(id, {
    proprietaire: state.char?.name,
    coproprietaire: coproprietaire,
    acheteAt: Date.now(),
    constructionAutorisee: !!aPermis,
    surface: surface,
    valeur_totale: prix,
    dette_fonciere: 0,
    // La signature a toujours lieu a l'Office Notarial de Luthecia, quelle que soit la ville du
    // terrain -- ne jamais deduire la ville d'un terrain de state.currentCity (A2, audit du 16
    // aout 2026). getVilleTerrain (plateau-justice-economie.js) fait autorite via l'id du terrain.
    city: typeof getVilleTerrain === 'function' ? getVilleTerrain(id) : (state.currentCity || 'capitale')
  });
  if (typeof sbSetTerrainState === 'function') {
    await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});
  }
  if (typeof sbEnregistrerVenteTerrain === 'function') {
    await sbEnregistrerVenteTerrain(state.country, id, state.char?.name, prix).catch(() => {});
  }

  updateUI();
  if (coproprietaire) {
    showToast('Bien partagé', coproprietaire + ' devient copropriétaire à 50% de ce terrain.', true);
    addJournalEntry('Terrain acheté en copropriété avec ' + coproprietaire + ' (50/50).', 'event-good');
  }
  if (!aPermis) {
    addJournalEntry('Terrain ' + localName + ' acheté pour ' + prix + ' ' + cur + '. SANS permis — construction bloquée jusqu\'autorisation du maire.', 'event-info');
    showToast('Terrain acheté !', 'Sans permis : construction bloquée. Demandez l\'autorisation au maire.', true);
  } else {
    addJournalEntry('Terrain ' + localName + ' acheté pour ' + prix + ' ' + cur + '. Permis valide.', 'event-good');
    showToast('Terrain acheté !', 'Avec permis. Construction autorisée.', true);
  }
}

// Accelere (reduit de moitie le delai restant) le rendez-vous notarial d'un achat direct en
// attente, contre corruption — meme principe que corrompre_fonctionnaire_permis.
async function doCorrompreRdvNotaire(pa, cost) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Accélérer le rendez-vous')) return;
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (!ts.achatDirect || ts.achatDirect.demandeur !== state.char?.name) {
    showToast('Impossible', "Vous n'avez pas de rendez-vous en attente ici.", false);
    return;
  }

  const maintenant = Date.now();
  const restant = ts.achatDirect.dateAchat - maintenant;
  if (restant <= 0) { showToast('Inutile', 'Le rendez-vous est déjà arrivé.', false); return; }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', cost + ' ' + cur + ' requis.', false); return; }
  const nouvelleDateAchat = maintenant + Math.floor(restant / 2);
  const achatDirect = { ...ts.achatDirect, dateAchat: nouvelleDateAchat, dateLimite: nouvelleDateAchat + 24 * 3600000 };
  const nouvelEtat = setTerrainState(id, { achatDirect });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  const dateTxt = new Date(nouvelleDateAchat).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });
  updateUI();
  addJournalEntry('Rendez-vous accéléré par corruption (-' + cost + ' ' + cur + '). Nouveau rendez-vous : ' + dateTxt + '.', 'event-info');
  showToast('Délai réduit', 'Nouveau rendez-vous : ' + dateTxt + '.', true);
}

function initSimulation() {
  if (!state.pjSimules) {
    state.pjSimules = JSON.parse(JSON.stringify(PJ_SIMULES));
  }
}

function getSimulesPresents() {
  if (!state.pjSimules) initSimulation();
  return state.pjSimules.filter(p =>
    p.currentCity === state.currentCity &&
    p.currentBuilding === state.currentBuilding &&
    !p.estAssassine
  );
}

function ouvrirPanneauSimulation() {
  if (!state.pjSimules) initSimulation();
  document.getElementById('postes-modal-title').textContent = 'Joueurs Simules — Mode Test';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#6a5a30;font-style:italic;margin-bottom:.8rem;padding:.5rem;background:#0a0805;border:1px solid #1a1810">Mode simulation actif. Ces PJ fictifs permettent de tester les interactions multijoueur.</div>';

  state.pjSimules.forEach((p, i) => {
    const ar = ARCHETYPES.find(x => x.id === p.archetype);
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:.4rem">';
    html += '<div><div style="font-family:Playfair Display,serif;font-size:.9rem;color:#E8C97A">' + p.name + '</div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">' + p.role + '</div>';
    html += (p.poste ? '<div style="font-size:.68rem;color:#C9A84C;margin-top:.15rem">' + p.poste.name + '</div>' : '') + '</div>';
    html += '<div style="font-size:.68rem;color:' + (p.estAssassine ? '#cc2020' : '#4a8a4a') + '">' + (p.estAssassine ? 'Hospitalise' : 'Actif') + '</div>';
    html += '</div>';

    // Position et deplacement
    const cityName = WORLD[p.country]?.[p.currentCity]?.name || p.currentCity;
    html += '<div style="font-size:.72rem;color:#5a5040;margin-bottom:.5rem">Position : ' + cityName + (p.currentBuilding ? ' · ' + (BUILDINGS[p.currentBuilding]?.shortName || p.currentBuilding) : ' · Rue') + '</div>';

    // Ressources
    html += '<div style="display:flex;gap:.4rem;flex-wrap:wrap;margin-bottom:.5rem">';
    [['INF',p.resources.inf,'#4a6aaa'],['POP',p.resources.pop,'#aa6a4a'],['DIS',p.resources.dis,'#8a4aaa'],['HP',p.resources.hp,'#aa4a4a']].forEach(([k,v,c]) => {
      html += '<div style="font-size:.85rem;padding:.15rem .4rem;background:#0a0805;border:1px solid #1a1810"><span style="color:#9a8a68">' + k + '</span> <span style="color:' + c + ';font-family:Bebas Neue,sans-serif">' + v + '</span></div>';
    });
    html += '</div>';

    // Actions de deplacement
    html += '<div style="display:flex;gap:.3rem;flex-wrap:wrap">';
    Object.entries(WORLD[p.country] || {}).forEach(([cityId, city]) => {
      if (cityId !== p.currentCity) {
        html += '<button onclick="deplacerSimule(' + i + ',\'' + cityId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.82rem;letter-spacing:.06em;padding:.2rem .4rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer">→ ' + city.name + '</button>';
      }
    });
    html += '<button onclick="deplacerSimuleBatiment(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.82rem;letter-spacing:.06em;padding:.2rem .4rem;border:1px solid #2a4a20;background:transparent;color:#4a7a4a;cursor:pointer">Entrer ici</button>';
    html += '</div>';
    html += '</div>';
  });

  html += '<button onclick="actualiserSimules()" style="width:100%;margin-top:.5rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.1em;padding:.4rem;border:1px solid #3a2a10;background:transparent;color:#8a7040;cursor:pointer">Actualiser les positions</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function deplacerSimule(idx, cityId) {
  if (!state.pjSimules?.[idx]) return;
  state.pjSimules[idx].currentCity = cityId;
  state.pjSimules[idx].currentBuilding = null;
  showToast('PJ deplace', state.pjSimules[idx].name + ' est maintenant a ' + (WORLD[state.pjSimules[idx].country]?.[cityId]?.name || cityId), true);
  ouvrirPanneauSimulation();
}

function deplacerSimuleBatiment(idx) {
  if (!state.pjSimules?.[idx]) return;
  state.pjSimules[idx].currentCity = state.currentCity;
  state.pjSimules[idx].currentBuilding = state.currentBuilding;
  showToast('PJ deplace', state.pjSimules[idx].name + ' entre dans ce batiment.', true);
  // Recharger les personnes presentes
  if (state.currentBuilding && state.currentRoom) {
    const b = BUILDINGS[state.currentBuilding];
    const room = b?.rooms?.[state.currentRoom];
    if (room) renderPersonsList(room.persons || []);
  }
  ouvrirPanneauSimulation();
}

function actualiserSimules() {
  ouvrirPanneauSimulation();
}