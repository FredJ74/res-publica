// =====================
// PLATEAU-PERSONNAGE.JS
// Fiche personnage, regles du jeu, photo de profil, suppression, detail inventaire
// =====================

// =====================
// CHAR SHEET
// =====================
function openCharSheet() {
  const char = state.char;
  if (!char) return;
  const co = COUNTRIES[char.country];
  const ar = ARCHETYPES.find(x => x.id === char.archetype);
  const ca = CAREERS.find(x => x.id === char.career);
  const or = ORIGINS.find(x => x.id === char.origin);
  const sc = SCHOOLS.find(x => x.id === char.school);

  const photo = char.photoUrl
    ? `<img src="${char.photoUrl}" style="width:70px;height:70px;border-radius:50%;border:2px solid #8a6a20;object-fit:cover">`
    : `<div style="width:70px;height:70px;border-radius:50%;background:#1a1508;border:2px solid #3a2a10;display:flex;align-items:center;justify-content:center;color:#C9A84C"><i class="ti ti-user" style="font-size:1.8rem"></i></div>`;

  document.getElementById('char-sheet-body').innerHTML = `
    <div style="padding:1rem;display:flex;align-items:center;gap:1rem;border-bottom:1px solid #1a1810">
      ${photo}
      <div>
        <div style="font-family:'Playfair Display',serif;font-size:1.2rem;font-weight:700;color:#E8C97A">${char.name}</div>
        <div style="font-size:.8rem;color:#7a7060;font-style:italic">${ar?.name||''} · ${co?.n||''}</div>
        ${state.poste ? `<div style="font-size:.75rem;color:#C9A84C;margin-top:.2rem"><i class="ti ti-briefcase" style="font-size:.7rem"></i> ${state.poste.name}</div>` : ''}
        ${char.motto ? `<div style="font-size:.75rem;color:#5a5040;margin-top:.3rem;font-style:italic">"${char.motto}"</div>` : ''}
      </div>
    </div>
    <div style="display:flex;gap:.4rem;padding:.6rem 1rem;border-bottom:1px solid #1a1810">
      <button id="cs-tab-btn-identite" onclick="switchCharSheetTab('identite')" style="font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.35rem .8rem;border:1px solid #8a6a20;background:#1a1408;color:#C9A84C;cursor:pointer">Identité</button>
      <button id="cs-tab-btn-stats" onclick="switchCharSheetTab('stats')" style="font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.35rem .8rem;border:1px solid #4a3a20;background:#12100a;color:#c0a060;cursor:pointer">Statistiques</button>
    </div>
    <div id="cs-tab-identite">
    <div class="char-sheet-grid">
      <div class="cs-section">
        <div class="cs-title">Caracteristiques</div>
        ${STAT_DEFS.map(({k,n,i}) => `
          <div class="cs-stat-row">
            <span class="cs-stat-name"><i class="ti ${i}" style="font-size:.75rem;vertical-align:-1px"></i> ${n}</span>
            <span class="cs-stat-val">${char.stats?.[k]||8}</span>
          </div>`).join('')}
      </div>
      <div class="cs-section">
        <div class="cs-title">Ressources</div>
        <div class="cs-stat-row"><span class="cs-stat-name">Argent total</span><span class="cs-stat-val">${state.arg.toLocaleString('fr-FR')} ${co?.cur||'FR'}</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">Liquide</span><span class="cs-stat-val">${state.liquide.toLocaleString('fr-FR')}</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">En banque</span><span class="cs-stat-val">${state.banque.toLocaleString('fr-FR')}</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">Influence</span><span class="cs-stat-val">${state.inf}/100</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">Popularite</span><span class="cs-stat-val">${state.pop}/100</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">Discretion</span><span class="cs-stat-val">${state.dis}/100</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">Sante</span><span class="cs-stat-val">${state.hp}/100</span></div>
        <div class="cs-stat-row"><span class="cs-stat-name">Moral</span><span class="cs-stat-val">${state.moral}/100</span></div>
      </div>
    </div>
    <div style="padding:.8rem 1rem;border-top:1px solid #1a1810">
      <div class="cs-title" style="margin-bottom:.4rem">Parcours</div>
      <div style="display:flex;flex-wrap:wrap;gap:.4rem;margin-bottom:.6rem">
        ${[or,sc,ar,ca].filter(Boolean).map(x => `
          <div style="font-size:.72rem;padding:.2rem .6rem;border:1px solid #2a2010;color:#8a8060;background:#0f0d05;display:flex;align-items:center;gap:.3rem">
            <i class="ti ${x.icon}" style="font-size:.75rem"></i> ${x.name}
          </div>`).join('')}
      </div>
      ${char.bio ? `<div style="font-size:.82rem;color:#8a8060;font-style:italic;line-height:1.6">${char.bio}</div>` : ''}
    </div>
    <div style="padding:.8rem 1rem;border-top:1px solid #1a1810">
      <div class="cs-title" style="margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">
        <span>Signature (forum)</span>
        <button onclick="ouvrirEditeurSignature()" style="font-family:'Bebas Neue',sans-serif;font-size:.68rem;letter-spacing:.06em;padding:.25rem .6rem;border:1px solid #4a3a20;background:transparent;color:#8a6a20;cursor:pointer">Modifier</button>
      </div>
      ${char.signatureHtml
        ? `<div style="font-size:.78rem;color:#8a8060;padding:.5rem;background:#0f0d05;border:1px solid #1a1810">${typeof sanitizeRichHtml === 'function' ? sanitizeRichHtml(char.signatureHtml) : char.signatureHtml}</div>`
        : (char.motto
          ? `<div style="font-size:.78rem;color:#5a5040;font-style:italic">Pas de signature personnalisée — ta devise ("${char.motto}") sera utilisée par défaut.</div>`
          : `<div style="font-size:.75rem;color:#9a8a68;font-style:italic">Aucune signature. Elle apparaîtra automatiquement en bas de tes posts sur le forum.</div>`)}
    </div>
    <div style="padding:.8rem 1rem;border-top:1px solid #1a1810">
      <div class="cs-title" style="margin-bottom:.4rem">Inventaire</div>
      ${state.inventory.length === 0
        ? '<div style="font-size:.75rem;color:#9a8a68;font-style:italic">Aucun objet</div>'
        : state.inventory.map(item => `
            <div style="display:flex;align-items:center;gap:.4rem;font-size:.78rem;color:#c0b090;padding:.2rem 0">
              <i class="ti ${item.icon}" style="font-size:.8rem;color:#8a6a20"></i> ${item.name}
            </div>`).join('')}
    </div>
    </div>
    <div id="cs-tab-stats" style="display:none">${genererStatsHtml()}</div>
  `;

  document.getElementById('modal-char').classList.add('open');
}

function switchCharSheetTab(tab) {
  document.getElementById('cs-tab-identite').style.display = tab === 'identite' ? '' : 'none';
  document.getElementById('cs-tab-stats').style.display = tab === 'stats' ? '' : 'none';
  const btnIdentite = document.getElementById('cs-tab-btn-identite');
  const btnStats = document.getElementById('cs-tab-btn-stats');
  const actif = 'border:1px solid #8a6a20;background:#1a1408;color:#C9A84C;cursor:pointer';
  const inactif = 'border:1px solid #4a3a20;background:#12100a;color:#c0a060;cursor:pointer';
  const base = "font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.35rem .8rem;";
  if (btnIdentite) btnIdentite.style.cssText = base + (tab === 'identite' ? actif : inactif);
  if (btnStats) btnStats.style.cssText = base + (tab === 'stats' ? actif : inactif);
}
function closeCharSheet() {
  document.getElementById('modal-char').classList.remove('open');
}

// =====================
// WORLD MAP
// =====================
function openWorldMap() {
  const body = document.getElementById('world-map-body');
  body.innerHTML = renderWorldMapSVG();
  body.style.display = 'flex';
  body.style.flexDirection = 'column';
  body.style.height = '520px';
  document.getElementById('modal-world').classList.add('open');
}
function closeWorldMap() {
  document.getElementById('modal-world').classList.remove('open');
}

// =====================
// REGLES DU JEU
// =====================
const REGLES = {
  tuto: {
    titre: '🎓 Tutoriel — Premiers pas',
    contenu: `Bienvenue dans Res Publica ! Voici comment commencer en 5 étapes.

━━━━━━━━━━━━━━━━━━━━━━━━
ÉTAPE 1 — Créer votre personnage
━━━━━━━━━━━━━━━━━━━━━━━━
Choisissez votre empire, votre archétype et votre carrière. Chaque combinaison donne des bonus différents. Le criminel est rapide à l'argent, le fonctionnaire est stable, le journaliste accumule de l'influence.

━━━━━━━━━━━━━━━━━━━━━━━━
ÉTAPE 2 — Explorer la ville
━━━━━━━━━━━━━━━━━━━━━━━━
Utilisez le bouton "Plan" pour voir la carte de votre ville. Cliquez sur un bâtiment pour y entrer. Chaque bâtiment contient des pièces et des PNJ avec qui vous pouvez interagir.

━━━━━━━━━━━━━━━━━━━━━━━━
ÉTAPE 3 — Parler aux PNJ
━━━━━━━━━━━━━━━━━━━━━━━━
Cliquez sur un PNJ pour lui parler. Les PNJ répondent en fonction de leur personnalité et de l'actualité du forum. Certains ont des informations, d'autres des services.

━━━━━━━━━━━━━━━━━━━━━━━━
ÉTAPE 4 — Passer des ordres
━━━━━━━━━━━━━━━━━━━━━━━━
Chaque pièce propose des ordres (boutons en bas). Certains coûtent des PA (Points d'Action), d'autres de l'argent. Les ordres légaux sont sans risque, les ordres gris sont risqués, les illégaux peuvent vous valoir une arrestation.

━━━━━━━━━━━━━━━━━━━━━━━━
ÉTAPE 5 — Dormir pour progresser
━━━━━━━━━━━━━━━━━━━━━━━━
Dormez une fois par jour dans un hôtel ou via votre fiche personnage. Cela vous verse votre salaire, restaure vos PA et fait avancer le temps. Sans sommeil, pas de revenus !

━━━━━━━━━━━━━━━━━━━━━━━━
CONSEILS
━━━━━━━━━━━━━━━━━━━━━━━━
• Postez sur le forum — c'est le cœur de la vie politique
• Envoyez des mails aux autres joueurs via le bouton Messages
• Consultez l'organigramme à la mairie pour voir les postes disponibles
• Pour voyager, rendez-vous au Centre Multinodal`
  },
  intro: {
    titre: 'Le Grand Jeu',
    contenu: `Panem et circenses — du pain et des jeux. Voilà, à quelques siècles près, ce qui faisait déjà tourner Rome, et c'est encore ce qui fait tourner le monde aujourd'hui, sous des habits neufs.

Res Publica est un jeu de rôle politique parodique où plusieurs mondes cohabitent, s'entremêlent et se nourrissent les uns des autres. Certains y mènent une guerre de pouvoir sans merci — élections truquées, coups d'État feutrés, alliances de circonstance. D'autres y bâtissent une fortune, terrain après terrain, entreprise après entreprise, préférant le grand livre de comptes aux tribunes de l'Assemblée. D'autres encore y trouvent leur gloire sur un terrain de foot, portés par des supporters aussi capables de vous élire en idole que de vous brûler en effigie. D'autres, enfin, choisissent l'ombre — le vol, la corruption, l'assassinat, l'art délicat de ne jamais se faire prendre.

Comme le citoyen romain d'autrefois, vous ne serez jamais qu'une seule chose à la fois : un politique peut tomber en disgrâce et se relever entrepreneur ; un criminel peut blanchir sa fortune dans le sport ; un capitaine d'industrie peut financer, en coulisses, l'élection qui décidera de son propre avenir. Rien n'est cloisonné. Tout se répond.

Choisissez qui vous voulez être. Mais sachez que dans Res Publica, comme à Rome, le pouvoir ne se donne jamais — il se prend, se négocie, ou se rachète.`
  },
  personnage: {
    titre: 'Créer son personnage',
    contenu: `Votre personnage est défini par 4 choix fondamentaux :

ORIGINE SOCIALE — Détermine votre capital de départ et vos bonus de stats.
• Milieu défavorisé : 200 FR, +VOL +DUP
• Classe ouvrière : 500 FR, +VOL +ENT
• Petite bourgeoisie : 1200 FR, +INT +CHA
• Haute société : 3000 FR, +ENT +CHA

PARCOURS SCOLAIRE — Détermine les carrières accessibles et vos points de compétence.
• Pas d'école : bloque plusieurs carrières
• Études supérieures et Hautes écoles : toutes les carrières accessibles

ARCHÉTYPE — Votre nature profonde. Définit vos bonus de ressources et votre style de jeu.

CARRIÈRE — Votre activité principale. Donne des contacts, des compétences et un salaire journalier.`
  },
  plateau: {
    titre: 'Le plateau de jeu',
    contenu: `POINTS D'ACTION (PA) — Vous disposez de 24 PA par jour. Chaque ordre en consomme selon sa complexité. Certains ordres sont gratuits. En mode test, les PA sont illimités.

RESSOURCES :
• Influence (INF) — Votre poids politique
• Popularité (POP) — Votre cote auprès du public
• Discrétion (DIS) — Votre capacité à agir sans être détecté
• Santé — Votre état physique (0 = hospitalisation)
• Moral — Votre résistance psychologique

ORDRES — Chaque action est résolue par un jet de dés (1-100). Le taux de réussite dépend de vos caractéristiques. Les résultats possibles : succès critique, succès, succès partiel, échec, échec critique.

SALAIRE — Vous ne touchez votre salaire journalier qu'en passant l'ordre "Dormir" (une seule fois par jour).`
  },
  politique: {
    titre: 'La vie politique',
    contenu: `POSTES ET MANDATS :
Les postes sont organisés en pyramide à 7 niveaux. En haut : le Président, le Premier Ministre, les Ministres. En bas : les élus locaux et les citoyens.

ÉLECTIONS :
• Mandat de 5-6 semaines
• Résultats à minuit le dimanche
• Candidatures possibles dès la 3e semaine après les dernières élections
• Campagne électorale : 4e semaine — vote des PJ + distribution de tracts aux PNJ
• 1er tour : >50% = élu direct, sinon 2e tour entre les 2 premiers
• Pour les mairies/gouvernorats : 2e tour entre ceux ayant obtenu >20%
• Députés : scrutin uninominal par circonscription, 1 tour, majorité relative

NOMMER UN MINISTRE :
Seul le Président peut nommer des ministres. La nomination se fait via un mail envoyé au candidat depuis le Bureau du Palais Présidentiel.`
  },
  interactions: {
    titre: 'Les interactions',
    contenu: `PARLER AUX PNJ/PJ — Cliquez sur un personnage présent dans une pièce pour ouvrir le dialogue. Posez n'importe quelle question dans le champ libre. Les réponses sont générées par l'IA.

GROUPES — Un PJ peut rejoindre un autre PJ en cliquant sur sa fiche. Le PJ rejoint devient le leader. Seul le leader peut déplacer le groupe. La taille du groupe influence certains ordres (blocus, etc.).

BOÎTE MAIL — Accessible depuis le bouton "Mail" en haut. Contient vos messages reçus, envoyés et votre répertoire de contacts.

AJOUTER UN CONTACT — Cliquez sur un PJ puis "Ajouter au répertoire". Indispensable pour porter plainte, lancer une rumeur ciblée, ou envoyer un mail.

LE FORUM — Accessible depuis le bouton "Forum" en haut. C'est l'espace de communication publique et privée du jeu. Il comporte plusieurs forums :
• Forum Local — Discussions de votre ville
• Forum Régional — Discussions régionales
• Forum National — Débats politiques nationaux
• Forum International — Relations entre empires
• Forum Gouvernemental — Réservé au gouvernement (Président + ministres)
• Forum Syndical — Réservé aux syndicalistes
Pour créer un sujet : bouton "Nouveau sujet". Pour répondre : bouton "Répondre" dans le sujet. L'éditeur permet la mise en forme (gras, souligné, centrage) et l'insertion d'images. Les sujets créés sont visibles de tous les membres du forum concerné.`
  },
  religion: {
    titre: 'Les Religions',
    contenu: `Chaque empire possède sa propre religion officielle, source de cohésion sociale et de pouvoir politique.

LES 4 RELIGIONS :
• Républia → Le Papyrusisme — Vénération du Formulaire Sacré en 12 exemplaires. Grand Prêtre : le Percepteur Suprême. Temple : le Tabernacle des Impôts. Péché mortel : rendre un formulaire incomplet.

• El Estado → Le Cocaïsme — Culte de la Feuille Sacrée. Grand Prêtre : le Parrain Céleste. Temple : le Laboratoire de Prière. Communion quotidienne obligatoire.

• Sovarka → Le Tractorisme — Vénération du Tracteur Collectif. Grand Prêtre : le Camarade Pontife. Temple : le Kolkhoze Spirituel. Hérésie suprême : le tracteur privé.

• Al-Khalija → Le Loukoumisme — Vénération du Loukoum Divin. Grand Prêtre : le Grand Confiseur. Temple : la Pâtisserie Sacrée. Péché mortel : refuser un loukoum offert.

INDICE DE PIÉTÉ (IP) :
Chaque empire a un Indice de Piété (0-100). Plus il est élevé, plus la religion est influente. Il impacte l'Indice Social, la popularité des élus et l'ordre public.

LIEUX DE CULTE :
Chaque empire possède un lieu de culte accessible à tous. On peut y prier (+IP +Moral), se confesser (+Moral, mais le prêtre sait tout), faire des dons (+IP +POP), ou se déclarer pèlerin (+DIS).

CONFESSION :
Attention ! Tout ce que vous confiez au Grand Prêtre peut être consulté par le chef d'État. Choisissez vos aveux avec soin.

LE CHEF D'ÉTAT ET LA RELIGION :
Le Président peut nommer le Grand Prêtre depuis son bureau. Il peut aussi décréter des jours saints (impact IP et IS).`
  },
  economie: {
    titre: "L'économie",
    contenu: `ARGENT — Séparé entre argent liquide (sur vous) et argent en banque. Le salaire est versé 30% en liquide, 70% en banque.

SALAIRES JOURNALIERS (versés via l'ordre Dormir) :
• Président : 5 000 FR/jour
• Premier Ministre : 3 500 FR/jour
• Ministres : 2 800 FR/jour
• Députés : 1 200 FR/jour
• Maires : 800 FR/jour
• Citoyen sans poste : 150 FR/jour

REVENUS FISCAUX — La population PNJ génère des impôts chaque nuit à minuit. Visibles du Président et du Ministre des Finances.

FREEMIUM — Le jeu est gratuit. Les abonnements premium donnent du confort mais jamais d'avantage compétitif direct.`
  }
};

// =====================
// FICHE PERSONNAGE CENTRALE
// =====================
function openSelfView() {
  if (typeof state !== 'undefined' && state.char?.queteAccueil?.etape === 'attente_fiche_personnage' && typeof queteAccueilSurbrillance === 'function') {
    queteAccueilSurbrillance('.sortir-btn', 15000);
  }
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-self').classList.add('active');
  const char = state.char;
  if (char) {
    document.getElementById('self-view-name').textContent = char.name || 'Mon Personnage';
    document.getElementById('self-view-role').textContent = state.poste?.name || 'Citoyen';
  }
  switchSelfTab('actions', document.querySelector('#vue-self .piece-tab'));
}

function closeSelfView() {
  if (typeof queteAccueilApresFichePersonnage === 'function') queteAccueilApresFichePersonnage();
  document.getElementById('vue-self').classList.remove('active');
  if (state.currentBuilding) {
    document.getElementById('vue-batiment').classList.add('active');
  } else {
    document.getElementById('vue-rue').classList.add('active');
  }
}

// Salaire verse a l'ordre Dormir : poste politique prioritaire, sinon emploi BNE actif
// (state.emploiBNE, cache local rafraichi par rafraichirCacheEmploiBNE — voir
// plateau-justice-economie.js), sinon le plancher universel SALAIRES.default (9 aout 2026).
function calculerSalaireDormir() {
  if (state.poste) return SALAIRES[state.poste.id] || SALAIRES.default;
  if (state.emploiBNE?.offreId && typeof OFFRES_EMPLOI_BNE !== 'undefined') {
    const offre = OFFRES_EMPLOI_BNE[state.emploiBNE.offreId];
    if (offre) return offre.salaire;
  }
  return SALAIRES.default;
}

function switchSelfTab(tab, el) {
  if (el) {
    document.querySelectorAll('#vue-self .piece-tab').forEach(t => t.classList.remove('active'));
    el.classList.add('active');
  }
  const content = document.getElementById('self-content');
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

  if (tab === 'actions') {
    // Determiner le confort du lieu
    const b = state.currentBuilding ? BUILDINGS[state.currentBuilding] : null;
    const confortMap = {
      'hotel-republica': { label: 'Hotel de luxe', moral: 5, paBonus: 5, icon: 'ti-building-castle' },
      'hotel-port':      { label: 'Hotel modeste', moral: 3, paBonus: 2, icon: 'ti-bed' },
      'hotel-mineur':    { label: 'Hotel modeste', moral: 3, paBonus: 2, icon: 'ti-bed' },
      'palais-presidentiel': { label: 'Residence officielle', moral: 8, paBonus: 8, icon: 'ti-building-monument' }
    };
    const confort = confortMap[state.currentBuilding] || { label: 'Lieu ordinaire', moral: 1, paBonus: 0, icon: 'ti-home' };

    const dejaDormi = state.dernierDormir === (state.day || 1);
    const salaire = calculerSalaireDormir();

    let html = '<div style="padding:1.2rem;max-width:600px">';

    // Ordre Dormir
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:1rem;margin-bottom:.8rem">';
    html += '<div style="display:flex;align-items:center;gap:.6rem;margin-bottom:.5rem">';
    html += '<i class="ti ti-moon" style="font-size:1.2rem;color:#6a8aaa"></i>';
    html += '<div><div style="font-family:Playfair Display,serif;font-size:.95rem;color:#E8C97A">Dormir</div>';
    html += '<div style="font-size:.72rem;color:#6a5a30"><i class="ti ' + confort.icon + '" style="font-size:.7rem"></i> ' + confort.label + '</div></div>';
    html += '</div>';
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem;line-height:1.5">';
    html += (dejaDormi ? '<span style="color:#9a8a68">Vous avez deja dormi aujourd\'hui.</span>' : 'Versement du salaire universel : <strong style="color:#C9A84C">+' + salaire.toLocaleString('fr-FR') + ' ' + cur + '</strong>') + '<br>';
    html += '+' + confort.moral + ' Moral · ';
    html += (confort.paBonus > 0 ? '+' + confort.paBonus + ' PA bonus demain' : 'Pas de bonus PA') + '</div>';
    html += '<button onclick="doDormir()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.4rem 1rem;border:1px solid ' + (dejaDormi ? '#2a2010' : '#4a6a8a') + ';background:transparent;color:' + (dejaDormi ? '#4a4030' : '#6a8aaa') + ';cursor:' + (dejaDormi ? 'not-allowed' : 'pointer') + '"' + (dejaDormi ? ' disabled' : '') + '>Dormir maintenant</button>';
    html += '</div>';

    // Se soigner
    const medocs = (state.inventory || []).filter(i => i.type === 'medicament');
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:1rem;margin-bottom:.8rem">';
    html += '<div style="display:flex;align-items:center;gap:.6rem;margin-bottom:.5rem">';
    html += '<i class="ti ti-first-aid-kit" style="font-size:1.2rem;color:#6a9a6a"></i>';
    html += '<div style="font-family:Playfair Display,serif;font-size:.95rem;color:#E8C97A">Se soigner</div></div>';
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem">' + (medocs.length > 0 ? medocs.length + ' medicament(s) en inventaire. +20 HP par utilisation.' : 'Aucun medicament en inventaire.') + '</div>';
    html += '<button onclick="doSesoigner()" ' + (medocs.length === 0 ? 'disabled style="opacity:.4;cursor:not-allowed"' : '') + ' style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.4rem 1rem;border:1px solid #2a4a20;background:transparent;color:#4a8a4a;cursor:pointer">Utiliser un medicament</button>';
    html += '</div>';

    // Mediter
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:1rem">';
    html += '<div style="display:flex;align-items:center;gap:.6rem;margin-bottom:.5rem">';
    html += '<i class="ti ti-brain" style="font-size:1.2rem;color:#8a6aaa"></i>';
    html += '<div style="font-family:Playfair Display,serif;font-size:.95rem;color:#E8C97A">Mediter</div></div>';
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem">Se recentrer. +3 Moral. 1 PA.</div>';
    html += '<button onclick="doOrder(\'se_reposer\',1,0,\'Mediter\',\'Vous prenez le temps de vous recentrer.\',100);closeSelfView()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.4rem 1rem;border:1px solid #3a2a5a;background:transparent;color:#8a6aaa;cursor:pointer">Mediter</button>';
    html += '</div>';

    // Ordres tactiques
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:1rem;margin-bottom:.8rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#8a6a20;margin-bottom:.6rem">ACTIONS TACTIQUES</div>';

    const malusISN = getMalusISN();
    const groupSize = getGroupSize ? getGroupSize() : 1;
    const tauxBlocus = Math.min(90, 25 + (groupSize - 1));

    html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
    html += '<button onclick="doOrder(\'se_cacher\',1,0,\'Se cacher\',\'Vous vous dissimulez dans la piece.\',70);closeSelfView()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #2a3a20;background:#0a0d08;color:#8a9a6a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
    html += '<span><i class="ti ti-eye-off" style="font-size:.85rem"></i> Se cacher</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#4a6a3a">70% · 1 PA</span></button>';

    html += '<button onclick="doOrder(\'organiser_blocus\',3,0,\'Organiser un blocus\',\'Le groupe bloque l\\\'acces.\','+tauxBlocus+');closeSelfView()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #3a1a1a;background:#0d0808;color:#9a6a4a;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
    html += '<span><i class="ti ti-ban" style="font-size:.85rem"></i> Organiser un blocus</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#6a3a20">' + tauxBlocus + '% · 1 PA · groupe:' + groupSize + '</span></button>';

    // Blocus syndical reel — reserve au Secretaire General / Adjoint (voir
    // getMonSyndicatEtGrade, plateau-organisations-quetes.js). Contrairement au blocus
    // generique ci-dessus (roleplay leger), celui-ci bloque reellement les ordres du
    // batiment ou l'on se trouve.
    if (typeof getMonSyndicatEtGrade === 'function') {
      const infosSyndicat = getMonSyndicatEtGrade();
      if (infosSyndicat && infosSyndicat.gradeIdx >= 1 && infosSyndicat.gradeIdx <= 2) {
        html += '<button onclick="closeSelfView();doOrganiserBlocusSyndical()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #3a2a1a;background:#0d0a08;color:#C9A84C;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
        html += '<span><i class="ti ti-flag" style="font-size:.85rem"></i> Organiser un blocus syndical (ici)</span></button>';
        html += '<button onclick="closeSelfView();doRenouvelerBlocusSyndical()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #3a2a1a;background:#0d0a08;color:#C9A84C;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
        html += '<span><i class="ti ti-refresh" style="font-size:.85rem"></i> Renouveler le blocus syndical (ici)</span></button>';
      }
    }

    const tauxIncendie = Math.max(5, 30 - malusISN);
    html += '<button onclick="doOrder(\'incendier\',3,0,\'Incendier\',\'Vous mettez le feu.\','+tauxIncendie+');closeSelfView()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #4a1a08;background:#100805;color:#aa5a30;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
    const isnAffiche = (typeof getIndiceVille === 'function') ? getIndiceVille(state.country, state.currentCity || 'capitale', 'isn') : (INDICES_NATIONAUX[state.country]?.ISN||30);
    html += '<span><i class="ti ti-flame" style="font-size:.85rem"></i> Incendier</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#8a3a10">' + tauxIncendie + '% · 3 PA · ISN:' + isnAffiche + '</span></button>';

    // Utiliser des explosifs — jusqu'ici entierement construite (doUtiliserExplosifs) et
    // routee, mais sans aucun bouton nulle part pour y acceder. Corrige le 5 aout 2026.
    if (typeof doUtiliserExplosifs === 'function') {
      html += '<button onclick="closeSelfView();doUtiliserExplosifs()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #4a1a08;background:#100805;color:#cc6a44;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
      html += '<span><i class="ti ti-bomb" style="font-size:.85rem"></i> Utiliser des explosifs</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#8a3a10">3 PA · nécessite l\'objet</span></button>';
    }
    html += '</div></div>';

    html += '</div>';
    content.innerHTML = html;

  } else if (tab === 'inventaire') {
    const items = state.inventory || [];
    let html = '<div style="padding:1.2rem;max-width:600px">';

    // Argent
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#8a6a20;margin-bottom:.5rem">FINANCES</div>';
    html += '<div style="display:grid;grid-template-columns:1fr 1fr;gap:.4rem">';
    html += '<div style="padding:.5rem;background:#0a0805"><div style="font-size:.68rem;color:#9a8a68">Liquide</div><div style="font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:#C9A84C">' + (state.liquide||0).toLocaleString('fr-FR') + ' ' + cur + '</div></div>';
    html += '<div style="padding:.5rem;background:#0a0805"><div style="font-size:.68rem;color:#9a8a68">En banque</div><div style="font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:#C9A84C">' + (state.banque||0).toLocaleString('fr-FR') + ' ' + cur + '</div></div>';
    html += '</div></div>';

    // Objets
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#8a6a20;margin-bottom:.5rem">OBJETS (' + items.length + ')</div>';
    if (items.length === 0) {
      html += '<div style="font-size:.8rem;color:#9a8a68;font-style:italic">Aucun objet en votre possession.</div>';
    } else {
      items.forEach((item, i) => {
        const hasImage = item.imageUrl && item.imageUrl.length > 5;
        html += '<div style="display:flex;align-items:center;gap:.5rem;padding:.5rem .3rem;border-bottom:1px solid #1a1810;cursor:pointer" onclick="ouvrirDetailObjet(' + i + ')">';
        // Miniature ou icone
        if (hasImage) {
          html += '<div style="width:44px;height:44px;flex-shrink:0;overflow:hidden;border:1px solid #2a2010;background:#0a0805">';
          html += '<img src="' + item.imageUrl + '" style="width:100%;height:100%;object-fit:cover;opacity:.85"/>';
          html += '</div>';
        } else {
          html += '<div style="width:44px;height:44px;flex-shrink:0;background:#0a0805;border:1px solid #2a2010;display:flex;align-items:center;justify-content:center">';
          html += '<i class="ti ' + (item.icon||'ti-package') + '" style="font-size:1.1rem;color:#8a6a20"></i>';
          html += '</div>';
        }
        html += '<div style="flex:1;min-width:0">';
        html += '<div style="font-size:.8rem;color:#c0b090;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + item.name + '</div>';
        html += '<div style="font-size:.85rem;color:#9a8a68">' + (item.legal !== undefined ? (item.legal ? 'Légal' : 'Non enregistré') : '') + (item.usageUnique ? ' · Usage unique' : '') + '</div>';
        html += '</div>';
        html += '<button onclick="event.stopPropagation();jeterObjetInventaire(' + i + ')" style="font-size:.85rem;color:#a0905a;background:transparent;border:none;cursor:pointer;padding:.2rem .4rem;flex-shrink:0">Déposer</button>';
        html += '<button onclick="event.stopPropagation();dropItem(' + i + ')" style="font-size:.85rem;color:#cc5540;background:transparent;border:none;cursor:pointer;padding:.2rem .4rem;flex-shrink:0">Détruire</button>';
        html += '</div>';
      });
    }
    html += '</div>';
    html += '</div>';
    content.innerHTML = html;

  } else if (tab === 'orgas') {
    content.innerHTML = '<div style="padding:.8rem 1rem">' + renderOngletOrgas() + '</div>';

  } else if (tab === 'identite') {
    const char = state.char;
    const ar = ARCHETYPES.find(x => x.id === char?.archetype);
    const ca = CAREERS.find(x => x.id === char?.career);
    const co = COUNTRIES[state.country];
    const photo = char?.photoUrl
      ? '<img src="' + char.photoUrl + '" style="width:80px;height:80px;border-radius:50%;border:2px solid #8a6a20;object-fit:cover">'
      : '<div style="width:80px;height:80px;border-radius:50%;background:#1a1508;border:2px solid #3a2a10;display:flex;align-items:center;justify-content:center;color:#C9A84C"><i class="ti ti-user" style="font-size:1.8rem"></i></div>';

    let html = '<div style="padding:1.2rem;max-width:600px">';
    html += '<div style="display:flex;align-items:center;gap:1rem;margin-bottom:1rem;padding-bottom:1rem;border-bottom:1px solid #1a1810">';
    html += photo;
    html += '<div><div style="font-family:Playfair Display,serif;font-size:1.2rem;font-weight:700;color:#E8C97A">' + (char?.name||'') + '</div>';
    html += '<div style="font-size:.8rem;color:#7a7060;font-style:italic">' + (ar?.name||'') + ' · ' + (co?.n||'') + '</div>';
    if (state.poste) html += '<div style="font-size:.75rem;color:#C9A84C;margin-top:.2rem"><i class="ti ti-briefcase" style="font-size:.7rem"></i> ' + state.poste.name + '</div>';
    if (char?.motto) html += '<div style="font-size:.72rem;color:#5a5040;margin-top:.3rem;font-style:italic">"' + char.motto + '"</div>';
    html += '</div></div>';

    // Stats
    html += '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:.3rem;margin-bottom:.8rem">';
    STAT_DEFS.forEach(s => {
      html += '<div style="text-align:center;padding:.4rem;background:#0f0d05;border:1px solid #1a1810">';
      html += '<div style="font-size:.8rem;color:#9a8a68;text-transform:uppercase">' + s.k + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.2rem;color:#C9A84C">' + (char?.stats?.[s.k]||8) + '</div>';
      html += '</div>';
    });
    html += '</div>';

    if (char?.bio) html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic;line-height:1.7;padding:.8rem;background:#0f0d05;border:1px solid #1a1810">' + char.bio + '</div>';

    html += '<div style="margin-top:1rem;display:flex;gap:.5rem;flex-wrap:wrap">';
    html += '<button onclick="ouvrirModalChangerPhoto()" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #6a5a30;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-camera"></i> Modifier la photo</button>';
    html += '<button onclick="ouvrirEditeurSignature()" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #6a5a30;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-signature"></i> ' + (char?.signatureHtml ? 'Modifier ma signature' : 'Créer ma signature') + '</button>';
    html += '</div>';

    if (char?.signatureHtml) {
      html += '<div style="margin-top:.6rem;padding:.6rem;background:#0f0d05;border:1px solid #1a1810;font-size:.78rem;color:#8a8060">' + (typeof sanitizeRichHtml === 'function' ? sanitizeRichHtml(char.signatureHtml) : char.signatureHtml) + '</div>';
    }

    if (char?.licenceSportive) {
      html += '<div style="margin-top:1rem;display:flex;gap:.5rem;flex-wrap:wrap">';
      html += '<button onclick="doVoirMonClassement()" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #6a5a30;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-chart-bar"></i> Mon niveau sportif</button>';
      html += '<button onclick="doConsulterMesOffresTransfert()" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #6a5a30;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-arrows-exchange"></i> Mes offres de transfert</button>';
      html += '</div>';
    }

    if (state.poste) {
      html += '<div style="margin-top:1rem">';
      html += '<button onclick="ouvrirConfirmationDemission()" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-door-exit"></i> Démissionner de mon poste</button>';
      html += '</div>';
    }

    html += '<div style="margin-top:2rem;padding-top:1rem;border-top:1px solid #2a1a10">';
    html += '<button onclick="ouvrirModalDetruirePersonnage()" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #6a2a20;background:transparent;color:#8a4a3a;cursor:pointer"><i class="ti ti-skull"></i> Détruire mon personnage</button>';
    html += '</div>';

    html += '</div>';
    content.innerHTML = html;
  } else if (tab === 'stats') {
    content.innerHTML = genererStatsHtml();
  }
}

// =====================
// CHANGEMENT DE PHOTO DE PROFIL
// =====================
function ouvrirModalChangerPhoto() {
  document.getElementById('postes-modal-title').textContent = 'Modifier la photo de profil';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">DEPUIS UN FICHIER</div>';
  html += '<input type="file" id="photo-file-input" accept="image/*" onchange="handlePhotoFileChange(event)" style="width:100%;color:#c0b090;font-size:.82rem;margin-bottom:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.5rem">OU DEPUIS UNE URL</div>';
  html += '<input type="text" id="photo-url-input" placeholder="https://..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:1rem;box-sizing:border-box">';
  html += '<div id="photo-preview-zone" style="margin-bottom:1rem"></div>';
  html += '<button onclick="confirmerChangementPhoto()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Enregistrer la photo</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

let _photoTemp = null;
function handlePhotoFileChange(event) {
  const f = event.target.files[0];
  if (!f) return;
  const r = new FileReader();
  r.onload = e => {
    _photoTemp = e.target.result;
    document.getElementById('photo-preview-zone').innerHTML = '<img src="' + _photoTemp + '" style="width:80px;height:80px;border-radius:50%;object-fit:cover;border:2px solid #8a6a20">';
  };
  r.readAsDataURL(f);
}

async function confirmerChangementPhoto() {
  const urlInput = document.getElementById('photo-url-input')?.value?.trim();
  const photoFinal = _photoTemp || urlInput || null;
  if (!photoFinal) { showToast('Aucune photo', 'Choisissez un fichier ou entrez une URL.', false); return; }

  if (!state.char) return;
  state.char.photoUrl = photoFinal;
  localStorage.setItem('respublica_photo_' + state.char.name, photoFinal);
  document.getElementById('modal-postes').classList.remove('open');

  if (typeof sbUpdatePhotoBio === 'function') {
    await sbUpdatePhotoBio(state.char.name, photoFinal, undefined).catch(() => {});
  }

  // Forcer la mise a jour du cache partage immediatement (sinon il faut attendre jusqu'a 60s)
  if (window._cachePhotosJoueurs && state.char.name) {
    window._cachePhotosJoueurs[state.char.name] = photoFinal;
  }

  _photoTemp = null;
  showToast('Photo mise à jour', 'Votre nouvelle photo de profil est enregistrée.', true, true);
  // Rafraîchir l'affichage de la fiche
  switchSelfTab('identite', document.querySelectorAll('#vue-self .piece-tab')[2] || null);
}

// =====================
// SUPPRESSION DE PERSONNAGE
// =====================
function ouvrirModalDetruirePersonnage() {
  document.getElementById('postes-modal-title').textContent = 'Détruire mon personnage';
  let html = '<div style="padding:1rem">';
  html += '<div style="color:#cc4444;font-size:.85rem;line-height:1.6;margin-bottom:1rem"><i class="ti ti-alert-triangle"></i> <strong>Action irréversible.</strong> Votre personnage (' + (state.char?.name||'') + ') sera définitivement supprimé : poste, ressources, candidatures et votes en cours seront effacés.<br><br>Vos messages sur les forums et vos mails resteront visibles, comme une trace historique.</div>';
  html += '<input type="text" id="confirm-destroy-input" placeholder="Tapez le nom de votre personnage pour confirmer" style="width:100%;background:#121005;border:1px solid #6a2a20;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:1rem;box-sizing:border-box">';
  html += '<button onclick="confirmerDestructionPersonnage()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #6a2a20;background:transparent;color:#cc4444;cursor:pointer">Détruire définitivement</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =====================
// SUCCESSION DIFFEREE (architecture v4, 21 aout 2026) -- remplace entierement l'ancien flux
// synchrone (planifierSuccession/executerSuccession, transmission immediate) : plus aucun
// transfert au moment du deces. ouvrirSuccession() cree un dossier successoral autonome
// (statut 'en_attente'), gele les actifs concernes, enregistre les premieres convocations
// (10 jours reels chacune) et nettoie les engagements du defunt -- rien n'est transfere ici.
// Le reglement reel (transferts, credits, degel) n'a lieu que plus tard, exclusivement par le
// cron (resoudreSuccessionsExpirees, api/cron-minuit.js), sur des dispositions independantes
// les unes des autres.
//
// Fail-closed a l'ouverture : chaque ecriture critique (ligne successions, gel de chaque actif,
// nettoyage des engagements) est verifiee explicitement. confirmerDestructionPersonnage()
// n'appelle JAMAIS sbDeletePersonnage() si ouvrirSuccession() echoue a un stade quelconque.
// Limite assumee (aucune transaction multi-table reelle cote Supabase REST) : si une ecriture
// reussit puis qu'une suivante de la MEME ouverture echoue, les ecritures deja faites ne sont pas
// annulees -- mais le personnage n'est alors jamais supprime, donc recuperable manuellement
// (voir rapport d'implementation pour le detail des risques residuels).
// =====================

const TAUX_DROITS_SUCCESSION = 0.33;
const PART_ETAT_DROITS_SUCCESSION = 0.90; // part notaire = droits - part Etat, jamais de FR perdu a l'arrondi
const DELAI_CONVOCATION_MS = 10 * 24 * 60 * 60 * 1000; // 10 jours reels, toutes les convocations (principal/remplacant/conjoint legal)

// Verifie qu'un nom correspond reellement a un personnage existant -- utilise a la fois pour
// valider les dispositions d'un testament au moment de sa redaction ET pour REVALIDER chaque
// beneficiaire au moment ou la succession s'ouvre reellement (jamais de confiance dans une
// existence verifiee au moment de la redaction, qui peut dater de tres longtemps -- section 5).
async function personnageExisteReellement(nom) {
  if (!nom || typeof sbGet !== 'function') return false;
  const rows = await sbGet('personnages', 'name=eq.' + encodeURIComponent(nom) + '&select=name').catch(() => null);
  return !!(rows && rows.length > 0);
}

// Determine la toute premiere etape de la chaine de convocation d'UNE disposition (bien ou part
// d'argent), en cascadant principal -> remplacant -> conjoint legal -> aucune (chaine vide,
// resolue directement par le cron a son prochain passage, sans attente artificielle -- section 8,
// resolution anticipee). Un principal/remplacant designe par testament mais INEXISTANT au moment
// de l'ouverture (section 5) est traite exactement comme s'il avait renonce : on cascade au
// palier suivant, jamais de transmission a un nom qui ne correspond plus a personne.
async function determinerChaineInitiale(dispositionTestament, conjointNom) {
  const maintenant = Date.now();
  const expiresAt = new Date(maintenant + DELAI_CONVOCATION_MS).toISOString();
  const convoqueLe = new Date(maintenant).toISOString();

  const principal = dispositionTestament?.beneficiaire || null;
  if (principal && await personnageExisteReellement(principal)) {
    return [{ role: 'principal', beneficiaire: principal, convoque_le: convoqueLe, expires_at: expiresAt, reponse: null, repondu_le: null }];
  }
  const remplacant = dispositionTestament?.remplacant || null;
  if (remplacant && await personnageExisteReellement(remplacant)) {
    return [{ role: 'remplacant', beneficiaire: remplacant, convoque_le: convoqueLe, expires_at: expiresAt, reponse: null, repondu_le: null }];
  }
  if (conjointNom) {
    return [{ role: 'legal_conjoint', beneficiaire: conjointNom, convoque_le: convoqueLe, expires_at: expiresAt, reponse: null, repondu_le: null }];
  }
  return [];
}

// Determine l'etape SUIVANTE de la chaine d'une disposition, une fois que son etape courante
// (roleActuel) vient de se solder par une renonciation -- explicite (doRepondreHeritage) ou
// tacite (cron, silence a l'echeance). Meme cascade que determinerChaineInitiale, mais amorcee a
// partir du role qui vient de renoncer plutot que depuis le testament brut, et jamais reconvoque
// un role deja present dans la chaine (une disposition ne revient jamais en arriere). Reutilisee
// telle quelle cote client (reponse explicite) ; le cron (resoudreSuccessionsExpirees) en
// implemente une copie fonctionnellement identique dans son propre idiome raw-fetch (aucun code
// partage possible entre les deux runtimes, cf. doctrine du gel).
async function determinerEtapeSuivante(disposition, roleActuel, conjointNom) {
  const maintenant = Date.now();
  const expiresAt = new Date(maintenant + DELAI_CONVOCATION_MS).toISOString();
  const convoqueLe = new Date(maintenant).toISOString();
  const dejaConvoques = new Set((disposition.chaine || []).map(e => e.role));

  if (roleActuel === 'principal' && disposition.remplacant_prevu && !dejaConvoques.has('remplacant')) {
    if (await personnageExisteReellement(disposition.remplacant_prevu)) {
      return { role: 'remplacant', beneficiaire: disposition.remplacant_prevu, convoque_le: convoqueLe, expires_at: expiresAt, reponse: null, repondu_le: null };
    }
  }
  if (roleActuel !== 'legal_conjoint' && conjointNom && !dejaConvoques.has('legal_conjoint')) {
    return { role: 'legal_conjoint', beneficiaire: conjointNom, convoque_le: convoqueLe, expires_at: expiresAt, reponse: null, repondu_le: null };
  }
  return null;
}

// Ouvre une succession complete : photographie le patrimoine, calcule la fiscalite globale une
// seule fois, construit les dispositions avec leurs premieres convocations, cree la ligne
// successions, gele les actifs, nettoie les engagements du defunt. defunt est TOUJOURS le
// personnage actuellement connecte (seul appelant : confirmerDestructionPersonnage) -- l'argent
// de banque est donc lu directement depuis state, deja la source la plus fraiche possible ici.
//
// IDEMPOTENCE (verification demandee le 21 aout 2026) : si une tentative precedente a deja cree
// la ligne successions mais a echoue plus loin (ex. gel partiel : 2 actifs geles, le 3e echoue),
// confirmerDestructionPersonnage() n'a PAS supprime le personnage -- le joueur peut relancer la
// destruction. Sans garde-fou, cette relance recalculerait tout depuis zero et creerait une
// DEUXIEME ligne 'en_attente' pour le meme defunt (dispositions dupliquees, succession_gel de
// certains actifs bascule vers le nouvel id, l'ancienne ligne devient orpheline). Le garde-fou :
// avant tout calcul, on cherche une succession 'en_attente' deja existante pour ce defunt ; si
// elle existe, on la REPREND telle quelle (id, dispositions, montants fiscaux deja figes -- rien
// n'est recalcule, meme si le solde du defunt a change entre deux tentatives) et on retente
// uniquement les etapes qui restent (gel/nettoyage), qui sont toutes naturellement rejouables
// sans effet de bord (re-ecrire succession_gel=successionId sur un actif deja gele, ou relire un
// compromis/pret deja nettoye qui n'apparait alors simplement plus dans le scan, est un no-op).
// Defense en profondeur cote base : index unique partiel sur successions(defunt) WHERE
// statut='en_attente' (voir migration_testament_succession.sql), qui ferait de toute facon
// echouer une deuxieme creation concurrente (ex. double-clic rapide / deux onglets) meme si ce
// garde-fou client venait a manquer.
async function ouvrirSuccession(defunt, country) {
  if (!defunt) return { ok: false, raison: 'defunt_manquant' };

  let successionExistante = null;
  if (typeof sbGetSuccessionsEnAttente === 'function') {
    const enAttente = await sbGetSuccessionsEnAttente(country).catch(() => undefined);
    if (enAttente === undefined) return { ok: false, raison: 'lecture_successions_impossible' };
    successionExistante = (enAttente || []).find(s => s.defunt === defunt) || null;
  }

  // Conjoint -- toujours relu (lecture seule, cout negligeable), y compris en reprise : sert
  // uniquement a la dissolution best-effort du mariage par l'appelant, n'affecte jamais
  // successions.conjoint qui reste fige des la creation initiale de la ligne.
  let mariageId = null;
  if (typeof sbGetMariageActif === 'function') {
    const mariage = await sbGetMariageActif(defunt).catch(() => undefined);
    if (mariage === undefined) return { ok: false, raison: 'lecture_mariage_impossible' };
    if (mariage) mariageId = mariage.id;
  }

  let successionId, dispositions, testamentId, conjointNom = null;

  if (successionExistante) {
    // Reprise stricte : aucune relecture de testament/terrains/entreprises, aucun recalcul
    // fiscal -- la ligne deja creee est l'unique source de verite pour cette succession.
    successionId = successionExistante.id;
    dispositions = successionExistante.dispositions || [];
    testamentId = successionExistante.testament_id || null;
    conjointNom = successionExistante.conjoint || null;
  } else {
    // 1. Testament actif eventuel
    let testament = null;
    if (typeof sbGetTestamentActif === 'function') {
      testament = await sbGetTestamentActif(defunt).catch(() => undefined);
      if (testament === undefined) return { ok: false, raison: 'lecture_testament_impossible' };
    }

    // 2. Conjoint -- revalide reellement son existence (section 9 de l'audit). Simple snapshot
    // informatif (successions.conjoint) : ne porte JAMAIS d'echeance propre -- distinct des
    // eventuelles etapes 'legal_conjoint' des chaines de dispositions individuelles (section 1
    // de l'architecture v4). Assigne a la variable de portee EXTERIEURE (declaree juste avant le
    // if/else) -- pas de redeclaration locale, le mail de convocation (etape 13) et le retour de
    // la fonction en dependent tous les deux, que l'ouverture vienne d'etre creee ou reprise.
    if (mariageId && typeof sbGetMariageActif === 'function') {
      const mariage = await sbGetMariageActif(defunt).catch(() => undefined);
      if (mariage) {
        const nomConjoint = mariage.conjoint1 === defunt ? mariage.conjoint2 : mariage.conjoint1;
        conjointNom = (await personnageExisteReellement(nomConjoint)) ? nomConjoint : null;
      }
    }

    // 3. Terrains/batiments/locaux possedes -- vraie primitive (sbGetTousLesBiensDe corrigee :
    // elle n'a jamais existe nulle part).
    let terrains = [];
    if (typeof sbGetTerrainsPossedesPar === 'function') {
      const r = await sbGetTerrainsPossedesPar(country, defunt).catch(() => undefined);
      if (r === undefined) return { ok: false, raison: 'lecture_terrains_impossible' };
      terrains = r || [];
    }

    // 4. Entreprises possedees (liste fixe et petite, meme scan que rechercherDossierNotarial)
    let entreprises = [];
    if (typeof getEntreprisesRachetables === 'function') {
      for (const def of getEntreprisesRachetables()) {
        const data = await def.charger().catch(() => undefined);
        if (data === undefined) return { ok: false, raison: 'lecture_entreprises_impossible' };
        if (data && data.proprietaire === defunt) entreprises.push({ id: def.id, label: def.label });
      }
    }

    // 5. Fiscalite globale (section 1/9 des arbitrages) : calculee UNE SEULE FOIS sur la masse
    // totale, jamais recalculee par disposition. argentBrutTotal = solde bancaire du defunt au
    // moment de l'ouverture (l'argent liquide et l'inventaire restent hors perimetre, point 9).
    const argentBrutTotal = state.banque || 0;
    const droitsTotal = Math.floor(argentBrutTotal * TAUX_DROITS_SUCCESSION);
    const partEtat = Math.floor(droitsTotal * PART_ETAT_DROITS_SUCCESSION);
    const partNotaire = droitsTotal - partEtat;
    const argentNetTotal = argentBrutTotal - droitsTotal;

    // 6. Construction des dispositions -- une par terrain/entreprise possede, plus une par part
    // d'argent testamentaire (ou une seule pour la totalite si aucun testament exploitable).
    // regle:false des la creation -- marqueur de reglement (transfert/credit reellement execute
    // par le cron), distinct de resultat (decision successorale tranchee) : voir reglerSuccession,
    // api/cron-minuit.js.
    const contenu = testament?.contenu || {};
    const biensTestament = {};
    (contenu.biens || []).forEach(b => { if (b?.id) biensTestament[b.id] = b; });

    dispositions = [];
    for (const t of terrains) {
      const dt = biensTestament[t.buildingId];
      const chaine = await determinerChaineInitiale(dt, conjointNom);
      dispositions.push({
        id: t.buildingId, type: 'terrain',
        libelle: BUILDINGS[t.buildingId]?.shortName || BUILDINGS[t.buildingId]?.name || t.buildingId,
        remplacant_prevu: dt?.remplacant || null,
        chaine, etat: 'en_attente', resultat: null, regle: false
      });
    }
    for (const e of entreprises) {
      const dt = biensTestament[e.id];
      const chaine = await determinerChaineInitiale(dt, conjointNom);
      dispositions.push({ id: e.id, type: 'entreprise', libelle: e.label, remplacant_prevu: dt?.remplacant || null, chaine, etat: 'en_attente', resultat: null, regle: false });
    }

    if (argentNetTotal > 0) {
      const partsArgentTestament = (contenu.argent || []).filter(p => p?.beneficiaire && p?.pourcentage);
      if (partsArgentTestament.length > 0) {
        // Reliquat d'arrondi affecte a la PREMIERE part dans l'ordre du testament (deterministe,
        // section 1) -- montant fixe des l'ouverture, independant de qui l'acceptera au final.
        let distribue = 0;
        const montants = partsArgentTestament.map((p, i) => {
          if (i === 0) return null; // calcule apres coup, reçoit le reliquat
          const m = Math.floor(argentNetTotal * (p.pourcentage / 100));
          distribue += m;
          return m;
        });
        montants[0] = argentNetTotal - distribue;
        for (let i = 0; i < partsArgentTestament.length; i++) {
          const p = partsArgentTestament[i];
          const chaine = await determinerChaineInitiale({ beneficiaire: p.beneficiaire, remplacant: p.remplacant }, conjointNom);
          dispositions.push({ id: 'argent-' + (i + 1), type: 'argent', part_nette: montants[i], remplacant_prevu: p.remplacant || null, chaine, etat: 'en_attente', resultat: null, regle: false });
        }
      } else {
        // Aucun testament exploitable pour l'argent : une seule disposition pour la totalite
        // nette, cascade directement sur le conjoint legal (pas de "principal" testamentaire ici).
        const chaine = await determinerChaineInitiale(null, conjointNom);
        dispositions.push({ id: 'argent-1', type: 'argent', part_nette: argentNetTotal, remplacant_prevu: null, chaine, etat: 'en_attente', resultat: null, regle: false });
      }
    }

    // 7. Creer la ligne successions (avant tout gel, section 4 des arbitrages) -- photographie
    // fiscale globale + dispositions completes, statut 'en_attente'. Protegee cote base par un
    // index unique partiel sur (defunt) WHERE statut='en_attente' : une creation concurrente pour
    // le meme defunt (ex. double-clic) echoue proprement ici (rCreation falsy), sans jamais
    // produire deux lignes 'en_attente'.
    successionId = 'succession-' + Date.now();
    testamentId = testament?.id || null;
    if (typeof sbCreerSuccession !== 'function') return { ok: false, raison: 'primitive_succession_indisponible' };
    const rCreation = await sbCreerSuccession({
      id: successionId, defunt, country, testament_id: testamentId,
      statut: 'en_attente', conjoint: conjointNom,
      argent_brut_total: argentBrutTotal, droits_total: droitsTotal, part_etat: partEtat, part_notaire: partNotaire, argent_net_total: argentNetTotal,
      dispositions
    });
    if (!rCreation) return { ok: false, raison: 'echec_creation_succession' };
  }

  // 8. Gel de tous les terrains/entreprises concernes -- derive des DISPOSITIONS elles-memes
  // (frozen des la creation de la ligne), jamais d'un nouveau scan d'ownership : coherent aussi
  // bien en creation qu'en reprise, et rejouable sans risque (re-ecrire succession_gel=successionId
  // sur un actif deja gele par CETTE meme succession est un no-op). Chaque ecriture verifiee,
  // arret immediat au premier echec (section 2 des arbitrages).
  for (const d of dispositions) {
    if (d.type === 'terrain') {
      await chargerTerrainState(d.id);
      const ts = getTerrainState(d.id);
      if (!ts) return { ok: false, raison: 'echec_gel_terrain', detail: d.id };
      const r = await sbSetTerrainState(country, d.id, { ...ts, succession_gel: successionId });
      if (!r) return { ok: false, raison: 'echec_gel_terrain', detail: d.id };
    } else if (d.type === 'entreprise') {
      const def = getEntrepriseRachetable(d.id);
      const data = def ? await def.charger().catch(() => null) : null;
      if (!data) return { ok: false, raison: 'echec_gel_entreprise', detail: d.id };
      const r = await sbSaveEntreprise(d.id, { ...data, succession_gel: successionId });
      if (!r) return { ok: false, raison: 'echec_gel_entreprise', detail: d.id };
    }
  }

  // 9. Compromis en cours ou le defunt est ACHETEUR sur un bien qui n'est pas le sien (y compris
  // transfertPropose === defunt : un tiers lui proposait de reprendre SON compromis) -- annules a
  // l'ouverture, jamais transmis (section 6). Rescanne a chaque tentative (creation ou reprise) :
  // naturellement idempotent, un compromis deja nettoye n'apparait simplement plus dans le scan.
  const compromisTerrainsAAnnuler = [];
  if (typeof getTousLesTerrainsPays === 'function' && typeof chargerTerrainState === 'function' && typeof getTerrainState === 'function') {
    for (const id of getTousLesTerrainsPays()) {
      await chargerTerrainState(id);
      const ts = getTerrainState(id);
      if (!ts || ts.proprietaire === defunt) continue; // deja traite comme bien possede au point 8 (gel)
      if ((ts.compromis && ts.compromisPar === defunt) || (ts.achatDirect && ts.achatDirect.demandeur === defunt) || ts.transfertPropose === defunt) {
        compromisTerrainsAAnnuler.push(id);
      }
    }
  }
  const compromisEntreprisesAAnnuler = [];
  if (typeof getEntreprisesRachetables === 'function') {
    for (const def of getEntreprisesRachetables()) {
      const data = await def.charger().catch(() => undefined);
      if (data === undefined) return { ok: false, raison: 'lecture_entreprises_impossible' };
      if (data && data.proprietaire !== defunt && data.compromis && data.compromisPar === defunt) {
        compromisEntreprisesAAnnuler.push(def.id);
      }
    }
  }

  // 10. Dettes en cours -- eteintes, jamais transmises (section 6). Meme remarque d'idempotence
  // naturelle : une dette deja passee au statut 'succession' ne ressort plus de ce scan.
  let prets = [];
  if (typeof sbGetPretsEnCours === 'function') {
    const r = await sbGetPretsEnCours(defunt).catch(() => undefined);
    if (r === undefined) return { ok: false, raison: 'lecture_prets_impossible' };
    prets = r || [];
  }

  // 11. Nettoyage des engagements du defunt sur des biens qui ne sont pas les siens (section 6 +
  // transfertPropose === defunt, section 4 des arbitrages).
  for (const id of compromisTerrainsAAnnuler) {
    await chargerTerrainState(id);
    const ts = getTerrainState(id);
    const nettoye = { ...ts, compromis: null, compromisPar: null, acompte: null, compromisAt: null, compromisExpireAt: null, achatDirect: null, transfertPropose: null, transfertProposePar: null };
    const r = await sbSetTerrainState(country, id, nettoye);
    if (!r) return { ok: false, raison: 'echec_nettoyage_compromis_terrain', detail: id };
  }
  for (const id of compromisEntreprisesAAnnuler) {
    const def = getEntrepriseRachetable(id);
    const data = def ? await def.charger().catch(() => null) : null;
    if (!data) return { ok: false, raison: 'echec_nettoyage_compromis_entreprise', detail: id };
    const nettoye = { ...data, compromis: null, compromisPar: null, acompte: null, compromisAt: null, compromisExpireAt: null, pretDemande: null };
    const r = await sbSaveEntreprise(id, nettoye);
    if (!r) return { ok: false, raison: 'echec_nettoyage_compromis_entreprise', detail: id };
  }

  // 12. Dettes eteintes (section 6) -- nouveau statut 'succession' (ni 'rembourse' ni 'saisi',
  // les deux seuls statuts de cloture existants cote cron, ne decrivent pas ce cas -- voir rapport).
  for (const pret of prets) {
    const r = await sbUpdatePret(pret.id, { statut: 'succession' });
    if (!r) return { ok: false, raison: 'echec_extinction_pret', detail: pret.id };
  }

  // 13. Convocations par mail -- best-effort (information/convocation, jamais le point d'entree
  // fonctionnel reel : "Réclamer un héritage" chez le notaire reste la source de verite, section
  // 2 des derniers arbitrages). Un echec d'envoi ne bloque jamais l'ouverture.
  if (typeof sbSendMail === 'function') {
    const dejaConvoques = new Set();
    for (const d of dispositions) {
      const etape = d.chaine[d.chaine.length - 1];
      if (!etape || dejaConvoques.has(etape.beneficiaire)) continue;
      dejaConvoques.add(etape.beneficiaire);
      await sbSendMail('Office Notarial', etape.beneficiaire, 'Succession — ' + defunt,
        defunt + ' est décédé(e). Vous êtes convoqué(e) au sujet d\'une succession. Rendez-vous au Bureau des Successions de l\'Office Notarial de Luthécia, rubrique « Réclamer un héritage », pour consulter et répondre.', '').catch(() => {});
    }
    if (conjointNom) {
      await sbSendMail('Office Notarial', conjointNom, 'Succession — ' + defunt,
        defunt + ', votre conjoint(e), est décédé(e). En tant que conjoint(e) survivant(e), vous pouvez consulter l\'ensemble du règlement successoral au Bureau des Successions de l\'Office Notarial de Luthécia, rubrique « Réclamer un héritage ».', '').catch(() => {});
    }
  }

  // 14. Testament consomme (s'il existait) -- best-effort (bookkeeping), idempotent par nature
  // (repasser un testament deja 'execute' a 'execute' ne change rien).
  if (testamentId && typeof sbMarquerTestamentStatut === 'function') {
    await sbMarquerTestamentStatut(testamentId, 'execute').catch(() => {});
  }

  return { ok: true, successionId, mariageId };
}

// =====================
// RECLAMER UN HERITAGE -- point d'entree fonctionnel reel des successions (Bureau des
// Successions, 0 PA/0 FR, deterministe -- section 2 des derniers arbitrages). Le mail de
// convocation envoye par ouvrirSuccession() n'est qu'une notification best-effort : sa perte,
// son archivage ou un echec d'envoi ne doit jamais empecher un heritier d'agir ici. Un legataire
// ordinaire ne voit QUE ses dispositions actives ; le conjoint (successions.conjoint) voit en
// plus l'integralite du testament/des dispositions, sans que cela ne lui ouvre de decision sur
// une disposition qui ne le concerne pas encore reellement (chaine[].role === 'legal_conjoint'
// uniquement quand elle l'atteint effectivement).
// =====================

function libelleDispositionSuccession(d) {
  if (d.type === 'argent') return (d.part_nette || 0).toLocaleString('fr-FR') + ' FR';
  return d.libelle || d.id;
}

async function doReclamerHeritage() {
  document.getElementById('postes-modal-title').textContent = 'Réclamer un héritage';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const nom = state.char?.name;
  const country = state.country || 'republic';
  const successions = (typeof sbGetSuccessionsEnAttente === 'function') ? await sbGetSuccessionsEnAttente(country).catch(() => []) : [];

  const pertinentes = [];
  for (const s of (successions || [])) {
    const estConjoint = s.conjoint === nom;
    const dispositions = s.dispositions || [];
    const dispositionsActives = dispositions.filter(d => {
      const chaine = d.chaine || [];
      const etape = chaine[chaine.length - 1];
      return etape && etape.beneficiaire === nom && etape.reponse === null;
    });
    if (estConjoint || dispositionsActives.length > 0) pertinentes.push({ succession: s, estConjoint, dispositionsActives });
  }

  if (pertinentes.length === 0) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">Aucune succession ne vous concerne actuellement.</div>';
    return;
  }

  let html = '<div style="padding:1rem">';
  pertinentes.forEach(p => { html += renderSuccessionPourHeritier(p.succession, p.estConjoint, p.dispositionsActives, nom); });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

function renderSuccessionPourHeritier(s, estConjoint, dispositionsActives, nom) {
  const dateTxt = (typeof formaterHorodatageJournal === 'function') ? formaterHorodatageJournal(s.created_at) : (s.created_at || '');
  let html = '<div style="border:1px solid #2a2010;padding:1rem;margin-bottom:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1rem;letter-spacing:.05em;color:#c9a44c;margin-bottom:.4rem">Succession de ' + escapeHtmlText(s.defunt) + '</div>';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.7rem">Ouverte le ' + dateTxt + '.</div>';

  if (estConjoint) {
    // Vue globale, purement informative -- aucun bouton ici (une decision reelle ne peut porter
    // que sur une disposition ou 'legal_conjoint' est effectivement l'etape courante, listee a
    // part ci-dessous dans dispositionsActives).
    html += '<div style="font-size:.78rem;color:#6a5a30;margin-bottom:.4rem;text-transform:uppercase;letter-spacing:.05em">Dispositions testamentaires</div>';
    const dispositions = s.dispositions || [];
    if (dispositions.length === 0) {
      html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic;margin-bottom:.6rem">Aucun bien ni somme à transmettre.</div>';
    }
    dispositions.forEach(d => {
      const chaine = d.chaine || [];
      const etape = chaine[chaine.length - 1];
      const cible = d.resultat ? d.resultat.beneficiaire : (etape ? etape.beneficiaire : null);
      const cibleTxt = cible ? escapeHtmlText(cible) : 'dévolution à l\'État';
      html += '<div style="font-size:.85rem;color:#e0d8c0;margin-bottom:.25rem">• ' + escapeHtmlText(libelleDispositionSuccession(d)) + ' → ' + cibleTxt + '</div>';
    });
    html += '<div style="margin-top:.8rem"></div>';
  }

  if (dispositionsActives.length > 0) {
    html += '<div style="font-size:.78rem;color:#6a5a30;margin-bottom:.4rem;text-transform:uppercase;letter-spacing:.05em">' + (estConjoint ? 'Vos décisions en attente' : 'Le défunt vous a légué') + '</div>';
    dispositionsActives.forEach(d => {
      const chaine = d.chaine || [];
      const etape = chaine[chaine.length - 1];
      const expTxt = (typeof formaterHorodatageJournal === 'function') ? formaterHorodatageJournal(etape.expires_at) : etape.expires_at;
      html += '<div style="border-top:1px solid #2a2010;padding-top:.6rem;margin-top:.6rem">';
      html += '<div style="font-size:.85rem;color:#e0d8c0;margin-bottom:.3rem">' + escapeHtmlText(libelleDispositionSuccession(d)) + '</div>';
      html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.5rem">Vous avez jusqu\'au ' + expTxt + ' pour répondre. Passé ce délai, la disposition sera considérée comme refusée.</div>';
      html += '<div style="display:flex;gap:.5rem">';
      html += '<button onclick="doRepondreHeritage(\'' + s.id + '\',\'' + d.id + '\',\'accepte\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.5rem 1rem;border:1px solid #2a6a2a;background:transparent;color:#4a8a4a;cursor:pointer">Accepter</button>';
      html += '<button onclick="doRepondreHeritage(\'' + s.id + '\',\'' + d.id + '\',\'renonce\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.5rem 1rem;border:1px solid #6a2a20;background:transparent;color:#cc4444;cursor:pointer">Renoncer</button>';
      html += '</div></div>';
    });
  }

  html += '</div>';
  return html;
}

// Enregistre la reponse d'un heritier a UNE disposition precise. N'effectue AUCUN transfert
// patrimonial : le reglement reel reste exclusivement du ressort du cron (resoudreSuccessionsExpirees).
// En cas de renonciation, fait avancer immediatement la chaine vers l'etape suivante (remplacant
// ou conjoint legal) plutot que d'attendre artificiellement l'echeance -- meme doctrine de
// resolution anticipee que le cron applique de son cote pour le silence.
async function doRepondreHeritage(successionId, dispositionId, reponse) {
  const nom = state.char?.name;
  const succession = (typeof sbGetSuccession === 'function') ? await sbGetSuccession(successionId).catch(() => null) : null;
  if (!succession) { showToast('Erreur', "Ce dossier n'existe plus.", false); doReclamerHeritage(); return; }
  if (succession.statut !== 'en_attente') { showToast('Trop tard', 'Cette succession a déjà été réglée.', false); doReclamerHeritage(); return; }

  const dispositions = succession.dispositions || [];
  const disposition = dispositions.find(d => d.id === dispositionId);
  if (!disposition) { showToast('Erreur', "Cette disposition n'existe plus.", false); doReclamerHeritage(); return; }

  const chaine = disposition.chaine || [];
  const etape = chaine[chaine.length - 1];
  if (!etape || etape.beneficiaire !== nom || etape.reponse !== null) {
    showToast('Action impossible', "Cette disposition ne vous concerne plus.", false);
    doReclamerHeritage();
    return;
  }
  if (Date.now() > new Date(etape.expires_at).getTime()) {
    showToast('Délai expiré', 'Le délai de réponse est écoulé pour cette disposition.', false);
    doReclamerHeritage();
    return;
  }

  etape.reponse = reponse;
  etape.repondu_le = new Date().toISOString();

  let nouveauConvoque = null;
  if (reponse === 'renonce') {
    const suivante = await determinerEtapeSuivante(disposition, etape.role, succession.conjoint);
    if (suivante) { disposition.chaine.push(suivante); nouveauConvoque = suivante.beneficiaire; }
  }

  const r = await sbUpdateSuccession(successionId, { dispositions });
  if (!r) { showToast('Erreur', "Votre réponse n'a pas pu être enregistrée. Réessayez.", false); return; }

  if (nouveauConvoque && typeof sbSendMail === 'function') {
    await sbSendMail('Office Notarial', nouveauConvoque, 'Succession — ' + succession.defunt,
      'Vous êtes convoqué(e) au sujet de la succession de ' + succession.defunt + '. Rendez-vous au Bureau des Successions de l\'Office Notarial de Luthécia, rubrique « Réclamer un héritage ».', '').catch(() => {});
  }

  showToast(reponse === 'accepte' ? 'Héritage accepté' : 'Renonciation enregistrée',
    reponse === 'accepte' ? 'Le règlement définitif interviendra lors du traitement notarial.' : 'Votre renonciation a été enregistrée.', true);
  doReclamerHeritage();
}

// =====================
// TESTAMENT -- redaction/consultation/modification/revocation (refonte du 20 aout 2026). Acte
// notarial DETERMINISTE : jamais un ordre a jet, aucune reussite/echec alea (section 12 du lot).
// Actifs couverts pour cette premiere version : argent, terrains/batiments/locaux (terrains_etat),
// entreprises -- caisse/stock d'entreprise jamais touches ici, ils suivent naturellement le bien
// au moment du reglement final (cron, resoudreSuccessionsExpirees), pas de traitement separe necessaire.
// Inventaire/objets/logements sociaux/organisations/postes explicitement hors perimetre.
// =====================

// Patrimoine transmissible du joueur courant, pour l'affichage du formulaire -- meme scan que
// ouvrirSuccession() (sbGetTerrainsPossedesPar + getEntreprisesRachetables), reutilise a
// l'identique.
async function getPatrimoineTransmissible() {
  const nom = state.char?.name;
  const country = state.country || 'republic';
  const terrains = (typeof sbGetTerrainsPossedesPar === 'function') ? await sbGetTerrainsPossedesPar(country, nom).catch(() => []) : [];
  const entreprises = [];
  if (typeof getEntreprisesRachetables === 'function') {
    for (const def of getEntreprisesRachetables()) {
      const data = await def.charger().catch(() => null);
      if (data && data.proprietaire === nom) entreprises.push({ id: def.id, label: def.label });
    }
  }
  return {
    terrains: (terrains || []).map(t => ({ buildingId: t.buildingId, label: BUILDINGS[t.buildingId]?.shortName || BUILDINGS[t.buildingId]?.name || t.buildingId })),
    entreprises,
    argentBanque: state.banque || 0
  };
}

// pa/cost (de l'ordre "Rédiger / modifier son testament") ne sont debites qu'au moment ou un
// testament est reellement enregistre (soumettreTestament) -- jamais a la simple ouverture de
// l'ecran (consultation/revocation restent gratuites), meme logique que le compromis notarial :
// on ne paie pas pour patienter, seulement pour l'acte signe.
async function doGererTestament(pa, cost) {
  document.getElementById('postes-modal-title').textContent = 'Testament';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const testament = (typeof sbGetTestamentActif === 'function') ? await sbGetTestamentActif(state.char?.name).catch(() => null) : null;
  window._testamentActifCourant = testament || null;
  if (testament) {
    renderTestamentActif(testament, pa, cost);
  } else {
    await ouvrirFormulaireTestament(null, pa, cost);
  }
}

function doGererTestamentModifier(pa, cost) {
  ouvrirFormulaireTestament(window._testamentActifCourant || null, pa, cost);
}

function renderTestamentActif(testament, pa, cost) {
  const contenu = testament.contenu || {};
  let html = '<div style="padding:1rem">';
  const dateTxt = (typeof formaterHorodatageJournal === 'function') ? formaterHorodatageJournal(testament.created_at) : (testament.created_at || '');
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Testament rédigé le ' + dateTxt + '.</div>';

  const biens = contenu.biens || [];
  if (biens.length > 0) {
    html += '<div style="font-size:.78rem;color:#6a5a30;margin-bottom:.3rem;text-transform:uppercase;letter-spacing:.05em">Biens</div>';
    biens.forEach(b => {
      const nomBien = BUILDINGS[b.id]?.shortName || BUILDINGS[b.id]?.name || (typeof getEntrepriseRachetable === 'function' ? getEntrepriseRachetable(b.id)?.label : null) || b.id;
      const remplacantTxt = b.remplacant ? ' <span style="color:#8a8060">(remplaçant : ' + escapeHtmlText(b.remplacant) + ')</span>' : '';
      html += '<div style="font-size:.85rem;color:#e0d8c0;margin-bottom:.3rem">• ' + escapeHtmlText(nomBien) + ' → ' + escapeHtmlText(b.beneficiaire) + remplacantTxt + '</div>';
    });
  }
  const argent = contenu.argent || [];
  if (argent.length > 0) {
    html += '<div style="font-size:.78rem;color:#6a5a30;margin:.6rem 0 .3rem;text-transform:uppercase;letter-spacing:.05em">Argent</div>';
    argent.forEach(p => {
      const remplacantTxt = p.remplacant ? ' <span style="color:#8a8060">(remplaçant : ' + escapeHtmlText(p.remplacant) + ')</span>' : '';
      html += '<div style="font-size:.85rem;color:#e0d8c0;margin-bottom:.3rem">• ' + p.pourcentage + '% → ' + escapeHtmlText(p.beneficiaire) + remplacantTxt + '</div>';
    });
  }
  if (biens.length === 0 && argent.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune disposition particulière — la dévolution par défaut s\'appliquera à tout le patrimoine.</div>';
  }

  html += '<div style="margin-top:1rem;display:flex;gap:.5rem;flex-wrap:wrap">';
  html += '<button class="pnj-action-btn" onclick="doGererTestamentModifier(' + pa + ',' + cost + ')">Modifier</button>';
  html += '<button onclick="confirmerRevocationTestament(\'' + testament.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.5rem 1rem;border:1px solid #6a2a20;background:transparent;color:#cc4444;cursor:pointer">Révoquer</button>';
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
}

function _testamentArgentRowsGet() {
  if (!window._testamentArgentRows) window._testamentArgentRows = [];
  return window._testamentArgentRows;
}

async function ouvrirFormulaireTestament(testamentExistant, pa, cost) {
  document.getElementById('postes-modal-title').textContent = 'Testament';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement du patrimoine...</div>';
  const patrimoine = await getPatrimoineTransmissible();
  window._testamentPatrimoineCourant = patrimoine;

  const contenuExistant = testamentExistant?.contenu || {};
  const beneficiairesBiens = {};
  const remplacantsBiens = {};
  (contenuExistant.biens || []).forEach(b => { beneficiairesBiens[b.id] = b.beneficiaire; remplacantsBiens[b.id] = b.remplacant || ''; });
  window._testamentArgentRows = (contenuExistant.argent || []).map(p => ({ beneficiaire: p.beneficiaire, pourcentage: p.pourcentage, remplacant: p.remplacant || '' }));

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Choisissez un bénéficiaire pour chaque bien (facultatif — sans choix, la dévolution par défaut s\'appliquera : conjoint survivant si valide, sinon retour au marché). Un remplaçant facultatif peut être désigné, appelé seulement si le bénéficiaire principal renonce ou ne répond pas. Les noms doivent correspondre à des personnages existants.</div>';

  if (patrimoine.terrains.length > 0) {
    html += '<div style="font-size:.78rem;color:#6a5a30;margin-bottom:.3rem;text-transform:uppercase;letter-spacing:.05em">Terrains, bâtiments et locaux</div>';
    patrimoine.terrains.forEach(t => {
      html += '<div style="display:flex;gap:.4rem;align-items:center;margin-bottom:.4rem">';
      html += '<span style="flex:1;font-size:.82rem;color:#c0b090">' + escapeHtmlText(t.label) + '</span>';
      html += '<input id="testament-bien-' + t.buildingId + '" type="text" placeholder="Bénéficiaire (facultatif)" value="' + escapeHtmlText(beneficiairesBiens[t.buildingId] || '') + '" style="width:180px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.35rem .5rem;font-size:.78rem;outline:none" />';
      html += '<input id="testament-remplacant-' + t.buildingId + '" type="text" placeholder="Remplaçant (facultatif)" value="' + escapeHtmlText(remplacantsBiens[t.buildingId] || '') + '" style="width:180px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.35rem .5rem;font-size:.78rem;outline:none" />';
      html += '</div>';
    });
  }

  if (patrimoine.entreprises.length > 0) {
    html += '<div style="font-size:.78rem;color:#6a5a30;margin:.6rem 0 .3rem;text-transform:uppercase;letter-spacing:.05em">Entreprises</div>';
    patrimoine.entreprises.forEach(e => {
      html += '<div style="display:flex;gap:.4rem;align-items:center;margin-bottom:.4rem">';
      html += '<span style="flex:1;font-size:.82rem;color:#c0b090">' + escapeHtmlText(e.label) + '</span>';
      html += '<input id="testament-bien-' + e.id + '" type="text" placeholder="Bénéficiaire (facultatif)" value="' + escapeHtmlText(beneficiairesBiens[e.id] || '') + '" style="width:180px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.35rem .5rem;font-size:.78rem;outline:none" />';
      html += '<input id="testament-remplacant-' + e.id + '" type="text" placeholder="Remplaçant (facultatif)" value="' + escapeHtmlText(remplacantsBiens[e.id] || '') + '" style="width:180px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.35rem .5rem;font-size:.78rem;outline:none" />';
      html += '</div>';
    });
  }

  if (patrimoine.terrains.length === 0 && patrimoine.entreprises.length === 0) {
    html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.6rem">Aucun terrain, bâtiment ou entreprise à votre nom pour l\'instant.</div>';
  }

  html += '<div style="font-size:.78rem;color:#6a5a30;margin:.6rem 0 .3rem;text-transform:uppercase;letter-spacing:.05em">Argent (' + (patrimoine.argentBanque || 0).toLocaleString('fr-FR') + ' FR en banque actuellement)</div>';
  html += '<div id="testament-argent-rows"></div>';
  html += '<button type="button" onclick="ajouterLigneArgentTestament()" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.08em;padding:.3rem .6rem;border:1px solid #6a5a30;background:transparent;color:#8a8060;cursor:pointer;margin-bottom:.8rem">+ Ajouter un bénéficiaire</button>';
  html += '<div style="font-size:.72rem;color:#6a5a30;font-style:italic;margin-bottom:.8rem">Sans bénéficiaire désigné, l\'argent suit la dévolution par défaut. Si plusieurs bénéficiaires sont désignés, le total doit faire exactement 100%.</div>';

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  html += '<button class="pnj-action-btn" onclick="soumettreTestament(' + pa + ',' + cost + ')">Enregistrer le testament (' + pa + ' PA, ' + cost + ' ' + cur + ')</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  rerenderLignesArgentTestament();
}

function ajouterLigneArgentTestament() {
  _testamentArgentRowsGet().push({ beneficiaire: '', pourcentage: '', remplacant: '' });
  rerenderLignesArgentTestament();
}

function retirerLigneArgentTestament(i) {
  _testamentArgentRowsGet().splice(i, 1);
  rerenderLignesArgentTestament();
}

function rerenderLignesArgentTestament() {
  const rows = _testamentArgentRowsGet();
  const el = document.getElementById('testament-argent-rows');
  if (!el) return;
  el.innerHTML = rows.map((r, i) => (
    '<div style="display:flex;gap:.4rem;align-items:center;margin-bottom:.4rem;flex-wrap:wrap">' +
    '<input type="text" placeholder="Nom du bénéficiaire" value="' + escapeHtmlText(r.beneficiaire || '') + '" oninput="_testamentArgentRowsGet()[' + i + '].beneficiaire=this.value" style="flex:1;min-width:140px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.35rem .5rem;font-size:.78rem;outline:none" />' +
    '<input type="number" min="1" max="100" placeholder="%" value="' + (r.pourcentage || '') + '" oninput="_testamentArgentRowsGet()[' + i + '].pourcentage=parseInt(this.value)||0" style="width:60px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.35rem .5rem;font-size:.78rem;outline:none" />' +
    '<input type="text" placeholder="Remplaçant (facultatif)" value="' + escapeHtmlText(r.remplacant || '') + '" oninput="_testamentArgentRowsGet()[' + i + '].remplacant=this.value" style="width:150px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.35rem .5rem;font-size:.78rem;outline:none" />' +
    '<button type="button" onclick="retirerLigneArgentTestament(' + i + ')" style="border:none;background:transparent;color:#8a3a2a;cursor:pointer;font-size:.9rem"><i class="ti ti-x"></i></button>' +
    '</div>'
  )).join('');
}

async function soumettreTestament(pa, cost) {
  const nom = state.char?.name;
  const patrimoine = window._testamentPatrimoineCourant || { terrains: [], entreprises: [], argentBanque: 0 };

  const biens = [];
  for (const t of patrimoine.terrains) {
    const val = (document.getElementById('testament-bien-' + t.buildingId)?.value || '').trim();
    if (!val) continue;
    const remplacant = (document.getElementById('testament-remplacant-' + t.buildingId)?.value || '').trim();
    biens.push({ id: t.buildingId, beneficiaire: val, remplacant: remplacant || null });
  }
  for (const e of patrimoine.entreprises) {
    const val = (document.getElementById('testament-bien-' + e.id)?.value || '').trim();
    if (!val) continue;
    const remplacant = (document.getElementById('testament-remplacant-' + e.id)?.value || '').trim();
    biens.push({ id: e.id, beneficiaire: val, remplacant: remplacant || null });
  }

  const argentRows = _testamentArgentRowsGet().filter(r => r.beneficiaire && r.pourcentage);
  if (argentRows.length > 0) {
    const total = argentRows.reduce((s, r) => s + (r.pourcentage || 0), 0);
    if (total !== 100) {
      showToast('Répartition invalide', 'Le total des parts d\'argent doit être exactement 100% (actuellement ' + total + '%).', false);
      return;
    }
  }

  // Verifier l'existence reelle de chaque beneficiaire ET remplacant designe AVANT tout
  // enregistrement -- jamais de testament enregistre avec une disposition vers un nom qui
  // n'existe pas (principal comme remplacant).
  const nomsAVerifier = [...new Set([
    ...biens.map(b => b.beneficiaire), ...biens.filter(b => b.remplacant).map(b => b.remplacant),
    ...argentRows.map(r => r.beneficiaire), ...argentRows.filter(r => r.remplacant).map(r => r.remplacant)
  ])];
  for (const b of nomsAVerifier) {
    if (b === nom) { showToast('Bénéficiaire invalide', 'Vous ne pouvez pas vous désigner vous-même comme bénéficiaire ou remplaçant.', false); return; }
    const existe = await personnageExisteReellement(b);
    if (!existe) { showToast('Personnage introuvable', '"' + b + '" ne correspond à aucun personnage existant.', false); return; }
  }

  // Cout deduit seulement maintenant, une fois toutes les validations (repartition, existence
  // des beneficiaires) passees -- jamais de PA/FR perdus pour un formulaire invalide.
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const rCout = await deduireCoutOrdre({ pa, cost });
  if (!rCout.ok) {
    showToast(rCout.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Fonds insuffisants', rCout.raison === 'pa_insuffisants' ? (pa + ' PA requis.') : (cost + ' ' + cur + ' requis.'), false);
    return;
  }

  const contenu = { biens, argent: argentRows.map(r => ({ beneficiaire: r.beneficiaire, pourcentage: r.pourcentage, remplacant: r.remplacant || null })) };

  const ancien = window._testamentActifCourant;
  const nouveau = {
    id: 'testament-' + Date.now(),
    testateur: nom,
    country: state.country || 'republic',
    contenu, // JSONB, objet transmis tel quel (meme convention que entreprises.data)
    statut: 'actif',
    remplace_id: ancien?.id || null
  };

  if (typeof sbSaveTestament !== 'function') { showToast('Indisponible', "La persistance du testament n'est pas encore active.", false); return; }
  const r = await sbSaveTestament(nouveau);
  if (!r) { showToast('Échec', "Le testament n'a pas pu être enregistré. Réessayez.", false); return; }

  if (ancien?.id && typeof sbMarquerTestamentStatut === 'function') {
    await sbMarquerTestamentStatut(ancien.id, 'remplace').catch(() => {});
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Testament enregistré', 'Vos dispositions ont été enregistrées chez le notaire.', true, true);
  addJournalEntry('📜 Testament rédigé chez le notaire.', 'event-info');
}

function confirmerRevocationTestament(id) {
  document.getElementById('postes-modal-title').textContent = 'Révoquer le testament';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">Révoquer votre testament actif ? Sans testament, la dévolution par défaut s\'appliquera à l\'ensemble de votre patrimoine.</div>' +
    '<button onclick="executerRevocationTestament(\'' + id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #6a2a20;background:transparent;color:#cc4444;cursor:pointer;margin-right:.5rem">Révoquer définitivement</button>' +
    '<button onclick="doGererTestament()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #3a2a10;background:transparent;color:#8a8060;cursor:pointer">Annuler</button>' +
    '</div>';
}

async function executerRevocationTestament(id) {
  if (typeof sbMarquerTestamentStatut !== 'function') return;
  const r = await sbMarquerTestamentStatut(id, 'revoque');
  if (!r) { showToast('Échec', 'La révocation a échoué. Réessayez.', false); return; }
  window._testamentActifCourant = null;
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Testament révoqué', 'La dévolution par défaut s\'appliquera désormais.', true, true);
  addJournalEntry('📜 Testament révoqué chez le notaire.', 'event-info');
}

async function doDemanderDivorce(pa, cost) {
  const nom = state.char?.name;
  if (typeof sbGetMariageActif !== 'function') return;

  const mariage = await sbGetMariageActif(nom);
  if (!mariage) {
    showToast('Non marié(e)', "Vous n'êtes pas marié(e) actuellement.", false);
    return;
  }
  const conjoint = mariage.conjoint1 === nom ? mariage.conjoint2 : mariage.conjoint1;

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', '', false); return; }

  if (typeof sbDissoudreMariage === 'function') {
    await sbDissoudreMariage(mariage.id, 'divorce').catch(() => {});
  }

  updateUI();
  showToast('Divorce prononcé', 'Vous êtes désormais divorcé(e) de ' + conjoint + '.', true, true);
  addJournalEntry('💔 Divorce prononcé avec ' + conjoint + '.', 'event-info');
  if (typeof addExternalEvent === 'function') {
    addExternalEvent('💔 ' + nom + ' et ' + conjoint + ' ont divorcé.', 'local');
  }

  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2, '0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail(nom, conjoint, 'Divorce', nom + ' a demandé le divorce devant notaire. Votre mariage est désormais dissous.', time).catch(() => {});
  }
}

async function confirmerDestructionPersonnage() {
  const saisie = document.getElementById('confirm-destroy-input')?.value?.trim();
  const nom = state.char?.name;
  if (!nom || saisie !== nom) {
    showToast('Confirmation incorrecte', 'Le nom saisi ne correspond pas.', false);
    return;
  }

  document.getElementById('modal-postes').classList.remove('open');

  // Succession fail-closed (architecture v4, 21 aout 2026) : la destruction du personnage n'est
  // JAMAIS declenchee si l'OUVERTURE de la succession echoue a un stade quelconque -- voir
  // ouvrirSuccession() ci-dessus pour la doctrine complete et les limites assumees (aucune
  // transaction multi-table reelle disponible cote Supabase REST). Le reglement reel (transferts,
  // credits) n'a plus lieu ici : il est exclusivement pris en charge, plus tard, par le cron.
  const country = state.country || 'republic';
  const ouvertureResult = await ouvrirSuccession(nom, country).catch(e => {
    console.error('Erreur ouverture succession', e);
    return { ok: false, raison: 'exception_ouverture' };
  });
  if (!ouvertureResult.ok) {
    showToast('Destruction annulée', "La succession n'a pas pu être ouverte (" + ouvertureResult.raison + "). Réessayez plus tard — votre personnage n'a pas été supprimé.", false, true);
    console.error('Succession annulée avant toute mutation :', ouvertureResult.raison, ouvertureResult.detail);
    return;
  }

  // A partir d'ici, la succession a ete ouverte avec succes (dossier cree, actifs geles,
  // engagements nettoyes) -- la destruction du personnage peut se poursuivre. Dissolution du
  // mariage : best-effort (bookkeeping, pas un actif transmissible), n'entre pas dans la chaine
  // stricte d'ouverture.
  if (ouvertureResult.mariageId && typeof sbDissoudreMariage === 'function') {
    await sbDissoudreMariage(ouvertureResult.mariageId, 'veuvage').catch(() => {});
  }

  // Archive permanente du deces, pour l'etat-civil (le personnage lui-meme va etre supprime
  // juste apres, cette trace est la seule qui subsistera). Ville : derniere localisation connue
  // du personnage au moment de l'action (17 aout 2026, mini-lot etat-civil) -- action synchrone,
  // sur son propre personnage, state.currentCity est donc fiable ici (contrairement aux flux
  // asynchrones deja corriges par ailleurs, ou l'acteur pouvait differer du sujet de l'acte).
  if (typeof sbEnregistrerDeces === 'function') {
    await sbEnregistrerDeces(nom, state.country, state.currentCity).catch(() => {});
  }

  if (typeof sbDeletePersonnage === 'function') {
    await sbDeletePersonnage(nom).catch(() => {});
  }

  // Nettoyer le localStorage local
  localStorage.removeItem('respublica_char_' + nom);
  localStorage.removeItem('respublica_dormir_' + nom);
  localStorage.removeItem('respublica_photo_' + nom);
  localStorage.removeItem('respublica_evtvus_' + nom);
  localStorage.removeItem('respublica_char');
  localStorage.removeItem('respublica_last_char');

  showToast('Personnage détruit', 'Vous allez être redirigé vers la création d\'un nouveau personnage.', true, true);
  setTimeout(() => { window.location.href = 'index.html'; }, 2000);
}

// Declenche l'hospitalisation automatique (dispensaire ou clinique selon le poste),
// dans la ville OU SE TROUVE ACTUELLEMENT le joueur — utilisee par l'empoisonnement
// (cote victime, meme session) et par l'assassinat (impact differe, plateau-communication.js).
// Durees doublees : dispensaire 6/4/2 jours, clinique 3/2/1 jours selon le palier.
function declencherHospitalisation(palier) {
  const estHautPlace = state.poste && ['president','pm','min_int','min_fin','min_just','min_def','min_info','min_ae'].includes(state.poste.id);
  const lieu = estHautPlace ? 'clinique' : 'dispensaire';
  const dureeParPalier = lieu === 'clinique'
    ? { totale: 3, partielle: 2, echec_partiel: 1 }
    : { totale: 6, partielle: 4, echec_partiel: 2 };
  const duree = dureeParPalier[palier] || (lieu === 'clinique' ? 1 : 2);
  state.hospitalisation = { jourDebut: state.day || 1, palier: palier || 'partielle', lieu, jourFin: (state.day || 1) + duree };
  state.pa = 0;
  const batimentCible = lieu === 'clinique' ? 'clinique-privee' : 'dispensaire-public';
  const pieceCible = lieu === 'clinique' ? 'reception_clinique' : 'salle_attente';
  if (typeof enterBuilding === 'function') enterBuilding(batimentCible, true);
  if (typeof enterRoom === 'function') enterRoom(batimentCible, pieceCible, null);
}

async function doDormir() {
  const today = state.day || 1;
  if (state.dernierDormir === today) {
    showToast('Deja dormi', 'Vous avez deja dormi aujourd\'hui. Attendez demain.', false);
    return false;
  }

  // Logements sociaux de Montrouge (18 aout 2026) : bonus MORAL/SANTE UNIQUEMENT si le bail
  // est actif ET que Dormir est passe physiquement dans ce meme appartement -- n'a AUCUN effet
  // sur le loyer (paye normalement par payerLocations() plus bas, quel que soit le lieu).
  const bonusLogement = typeof getBonusLogementSocialDormir === 'function'
    ? getBonusLogementSocialDormir() : { moral: 0, sante: 0 };

  if (state.empoisonnement?.actif) {
    state.hp = Math.floor((state.hp || 0) / 2);
    if (state.hp < 20) state.hp = 0;
    if (state.hp === 0) {
      const palierPoison = state.empoisonnement.palier || 'partielle';
      state.empoisonnement = null;
      declencherHospitalisation(palierPoison);
      showToast('Empoisonnement fatal', 'Vos PV sont tombes a 0. Hospitalisation d\'urgence.', false, true);
      addJournalEntry('L\'empoisonnement a eu raison de vous. Hospitalisation d\'urgence.', 'event-bad');
      updateUI();
      return false;
    } else {
      showToast('Empoisonnement', 'Le poison progresse. PV : ' + state.hp + '.', false, true);
      addJournalEntry('L\'empoisonnement progresse pendant votre sommeil. PV : ' + state.hp + '.', 'event-bad');
    }
  }

  if (state.regenJour && (state.hp || 0) < 100) {
    state.hp = Math.min(100, (state.hp || 0) + 10);
    addJournalEntry('Regeneration naturelle : +10 PV. PV actuels : ' + state.hp + '.', 'event-info');
  }
  if ((state.hp || 0) >= 100) {
    state.regenJour = null;
    if (state.statsAffaiblies) state.statsAffaiblies = null;
  }

  if (!state.empoisonnement?.actif) {
    state.hp = Math.min(100, (state.hp || 0) + 12);
  }

  // Bonus SANTE du logement social : s'ajoute a la recuperation normale ci-dessus, ne la
  // remplace jamais (meme applique pendant un empoisonnement, comme les autres etapes ci-dessus).
  if (bonusLogement.sante > 0) {
    state.hp = Math.min(100, (state.hp || 0) + bonusLogement.sante);
  }

  // Correctif du 23 aout 2026 (audit dedie "moteur hotel Republia") : l'ancien prelevement
  // automatique d'une "nuitee" ET le bonus Moral/PA ambiant accordes uniquement parce que
  // state.currentBuilding etait un hotel (quelle que soit la piece -- hall, restaurant, bar...)
  // sont retires d'ici. Cela double-comptait avec le bonus de reservation reelle
  // (doDormirChambre ci-dessous) et facturait une seconde fois un sejour deja paye a la
  // reservation. doDormir() redevient la recuperation NORMALE, generique, identique partout :
  // seule une chambre reellement reservee (state.reservationHotel, verifie par
  // doDormirChambre) accorde desormais un bonus hotelier, une seule fois, jamais cumule avec
  // celui-ci. Le paiement d'une chambre a lieu exclusivement a la reservation (voir
  // doReserverChambreHotel), plus jamais ici.
  state.salaireTouche = true;
  state.day = today + 1;
  state.dernierDormir = state.day; // Bloque le jour suivant
  state.douanePassee = false;
  // Le bonus de formation temporaire (voir doSeFormer) expire au sommeil
  if (state.char?.bonusFormation) {
    state.char.bonusFormation = null;
    if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  }
  localStorage.setItem('respublica_dormir_' + (state.char?.name || 'default'), JSON.stringify({dernierDormir: state.dernierDormir, day: state.day}));
  const salaire = calculerSalaireDormir();
  state.arg += salaire;
  state.liquide += Math.floor(salaire * 0.3);
  state.banque += Math.ceil(salaire * 0.7);
  // Moral de base (correctif du 23 aout 2026) : constante unique, plus aucun bonus lie a la
  // simple presence dans un hotel (voir commentaire plus haut) -- seul doDormirChambre() ajoute
  // desormais un bonus hotelier, apres cet appel, jamais ici.
  state.moral = Math.min(100, state.moral + 1 + (bonusLogement.moral || 0));

  // Recuperation des PA (Lot 1, 18 aout 2026) — ADDITIVE : les PA restants avant sommeil ne
  // sont plus jamais ecrases, seule la recuperation elle-meme s'ajoute au stock, sous reserve
  // du plafond de reserve PA_MAX (plateau-core.js). state.paMax n'est plus recalcule ici : le
  // plafond est desormais une constante fonctionnelle unique (PA_MAX). Plus aucun bonus lie a
  // la simple presence dans un hotel (correctif du 23 aout 2026, voir plus haut) -- seul
  // doDormirChambre() ajoute desormais +2 PA, apres cet appel, jamais ici.
  const PA_BASE_NORMAL = 12;
  let recuperationPA = PA_BASE_NORMAL;
  let detentionQHS = null;
  if (typeof sbGet === 'function' && state.char?.name) {
    const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(state.char.name)}&select=detention_qhs`).catch(() => []);
    detentionQHS = rows?.[0]?.detention_qhs ? (typeof rows[0].detention_qhs === 'string' ? JSON.parse(rows[0].detention_qhs) : rows[0].detention_qhs) : null;
  }
  if (detentionQHS?.enQHS) {
    // Sanction QHS : remplace (ne s'ajoute pas a) le stock existant, pour empecher toute
    // accumulation normale jusqu'a PA_MAX pendant la detention. Comportement inchange par
    // rapport a avant ce lot -- seul le plafond global (Math.min ci-dessous) est nouveau, en
    // pure securite (ne change rien en pratique tant que la sanction reste tres inferieure a
    // PA_MAX).
    const plafondQHS = detentionQHS.paLimite1Jour ? 1 : 3;
    if (detentionQHS.paLimite1Jour) {
      detentionQHS.paLimite1Jour = false;
      if (typeof sbUpdate === 'function') await sbUpdate('personnages', `name=eq.${encodeURIComponent(state.char.name)}`, { detention_qhs: JSON.stringify(detentionQHS) }).catch(() => {});
    }
    state.pa = plafondQHS;
    if (state.bonusPaProchainDormir) {
      state.pa += state.bonusPaProchainDormir;
      addJournalEntry('Bonus de repas applique : +' + state.bonusPaProchainDormir + ' PA.', 'event-good');
      state.bonusPaProchainDormir = 0;
    }
    state.pa = Math.min(PA_MAX, Math.max(0, state.pa));
  } else {
    if (state.bonusPaProchainDormir) {
      recuperationPA += state.bonusPaProchainDormir;
      addJournalEntry('Bonus de repas applique : +' + state.bonusPaProchainDormir + ' PA.', 'event-good');
      state.bonusPaProchainDormir = 0;
    }
    state.pa = Math.min(PA_MAX, (state.pa || 0) + recuperationPA);
  }

  updateUI();
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';
  const moralAffiche = 1 + (bonusLogement.moral || 0);
  const suffixeLogement = (bonusLogement.moral || bonusLogement.sante)
    ? ' (dont logement social : +' + (bonusLogement.moral || 0) + ' Moral / +' + (bonusLogement.sante || 0) + ' Santé)' : '';
  showToast('Bonne nuit !', 'Salaire verse : +' + salaire.toLocaleString('fr-FR') + ' ' + cur + ' · +' + moralAffiche + ' Moral' + suffixeLogement, true, true);
  addJournalEntry('Vous dormez. Salaire verse : +' + salaire.toLocaleString('fr-FR') + ' ' + cur, 'event-good');

  // Payer les loyers des locations actives
  payerLocations();
  // Revenu passif + bonus INF/POP/DIS des bâtiments construits sur des terrains possédés
  if (typeof collecterRevenusConstructions === 'function') await collecterRevenusConstructions();
  // NOTE : les loyers des lots subdivises sont desormais preleves par le cron serveur
  // (preleverLoyersLots, api/cron-minuit.js) — pas ici, pour ne pas defavoriser le
  // proprietaire si le locataire ne se connecte jamais.
  // Payer les escorts actives
  payerEscorts();
  payerEmployes();
  // Regeneration quotidienne des grilles de prison de la ville courante (puise sur la
  // caisse du commissariat, s'arrete des que le budget est insuffisant)
  if (typeof regenererGrillesPrison === 'function') regenererGrillesPrison(state.country, state.currentCity).catch(() => {});
  // Distribution quotidienne du budget municipal vers les vraies caisses des batiments communaux
  if (typeof distribuerBudgetMunicipalVersBatiments === 'function') distribuerBudgetMunicipalVersBatiments(state.country, state.currentCity).catch(() => {});
  // Decroissance lente de la reputation criminelle si inactif
  if (state.reputationCriminelle) state.reputationCriminelle = Math.max(0, state.reputationCriminelle - 1);
  updateUI(); // Rafraichir apres les bonus de location (INF/POP/DIS) appliques ci-dessus

  // Traiter les evenements nocturnes
  traiterPlaintes();
  traiterEnquetes();
  traiterConvocations();
  verifierLiberationPrisonniers();
  verifierDecouverteCrimesPasses();
  checkArrestationAuReveil();
  verifierProgressionHospitalisation();
  if (typeof verifierEffetsManifestationsEcoulees === 'function') verifierEffetsManifestationsEcoulees(state.country);
  if (typeof verifierSalairePolitique === 'function') verifierSalairePolitique();
  if (typeof verifierSalaireDirecteur === 'function') verifierSalaireDirecteur();
  if (typeof verifierSalaireDirecteurEntrepot === 'function') verifierSalaireDirecteurEntrepot();
  if (typeof verifierAutoValidationManifestations === 'function') verifierAutoValidationManifestations(state.country);

  // Rafraichir la vue
  switchSelfTab('actions', null);

  // Sauvegarde Supabase immediate et bloquante (contourne le debounce de 3s de
  // sbAutoSave) : le sommeil touche l'argent et les verrous anti-double-salaire
  // (dernierDormir/salaireTouche), donc on ecrit tout de suite sur Supabase avant
  // qu'un rafraichissement ou changement d'appareil ne puisse survenir entre-temps.
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state);

  return true;
}

// =====================
// CHAMBRES INDIVIDUELLES DE LA CLINIQUE PRIVEE (lot chambres, 20 aout 2026) -- reutilise
// integralement locations_actives (plateau-justice-economie.js : getLocationPourRoom/
// chargerLocations/sbSaveLocation, deja charge au demarrage dans state.locationsActives), meme
// patron que l'attribution des logements sociaux de Montrouge (attribuerLogementSocial,
// plateau-logements-montrouge.js) mais en self-service (le patient s'attribue lui-meme sa
// chambre au moment du transfert, pas un tiers). Aucune nouvelle table/colonne Supabase :
// locations_actives.data est un JSONB libre (verifie en lecture directe sur la table de
// production), deja etendu sans migration pour les logements sociaux (logementSocial/
// bonusMoralSommeil/bonusSanteSommeil) -- meme principe ici avec visitesAutorisees/
// chambreClinique.
//
// prix:0 conserve sur chaque attribution pour la compatibilite du schema (payerLocations()
// lit loc.prix pour toute entree dont locataire===state.char?.name), mais payerLocations()
// (plateau-justice-economie.js) exclut desormais explicitement chambreClinique===true avant
// tout traitement -- aucun prelevement, message de loyer, avertissement ni expulsion pour les
// chambres de la clinique (arbitrage UX, 20 aout 2026). N'affecte aucune autre location.
const CHAMBRES_CLINIQUE_PRIVEE = ['chambre_1','chambre_2','chambre_3','chambre_4','chambre_5','chambre_6','chambre_7','chambre_8','chambre_9','chambre_10'];

function getChambreAttribueeClinique(nomPatient) {
  return (state.locationsActives || []).find(l =>
    l.buildingId === 'clinique-privee' && l.chambreClinique === true && l.locataire === nomPatient);
}

function trouverChambreLibreClinique() {
  for (const roomId of CHAMBRES_CLINIQUE_PRIVEE) {
    if (!getLocationPourRoom('clinique-privee', roomId, 'capitale')) return roomId;
  }
  return null;
}

async function doTransfertCliniquePrivee(pa, cost) {
  if (!state.hospitalisation) { showToast('Indisponible', 'Vous n\'êtes pas hospitalisé(e).', false); return; }
  if (state.hospitalisation.lieu === 'clinique') { showToast('Déjà en clinique privée', '', false); return; }

  // Fail-closed (section 2 du lot) : la disponibilite d'une chambre est verifiee AVANT tout
  // debit -- jamais de transfert partiel, jamais de patient envoye dans la chambre d'un autre.
  const patient = state.char?.name;
  const dejaAttribuee = patient ? getChambreAttribueeClinique(patient) : null;
  let roomIdCible = dejaAttribuee ? dejaAttribuee.roomId : trouverChambreLibreClinique();
  if (!roomIdCible) {
    showToast('Aucune chambre disponible', "La clinique ne dispose actuellement d'aucune chambre libre.", false);
    return;
  }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', '1000 FR requis pour le transfert.', false); return; }

  // Nouvelle attribution seulement si le patient n'en avait pas deja une (idempotent : un
  // re-transfert retrouve la meme chambre plutot que d'en creer une seconde).
  if (!dejaAttribuee) {
    const entree = {
      buildingId: 'clinique-privee',
      roomId: roomIdCible,
      city: 'capitale',
      country: state.country || 'republic',
      locataire: patient,
      depuis: state.day || 1,
      visible: true,
      prix: 0,
      chambreClinique: true,
      visitesAutorisees: true
    };
    if (!state.locationsActives) state.locationsActives = [];
    state.locationsActives.push(entree);
    if (typeof sbSaveLocation === 'function') await sbSaveLocation(entree).catch(() => {});
  }

  state.hospitalisation.lieu = 'clinique';
  // clinique-privee n'existe qu'a la capitale de chaque empire (lot chambre, 20 aout 2026) --
  // mise a jour explicite de la ville avant l'entree dans la piece, au cas ou cet ordre serait un
  // jour propose depuis un dispensaire hors capitale (aujourd'hui uniquement celui de la
  // capitale : no-op dans ce cas, mais correct si la portee change plus tard).
  state.currentCity = 'capitale';
  if (state.char) state.char.currentCity = 'capitale';
  updateUI();
  // Destination precise : la chambre attribuee (existante ou nouvelle), pas la reception --
  // meme mecanisme de changement de batiment/piece que partout ailleurs (enterBuilding/
  // enterRoom), qui persiste deja immediatement la position (voir enterRoom,
  // plateau-navigation.js) -- aucune teleportation parallele.
  if (typeof enterBuilding === 'function') enterBuilding('clinique-privee', true);
  if (typeof enterRoom === 'function') enterRoom('clinique-privee', roomIdCible, null);
  showToast('Transfert effectué', 'Vous êtes désormais pris(e) en charge en clinique privée. Convalescence plus rapide.', true, true);
  addJournalEntry('Transfert vers une clinique privée (-1000 FR).', 'event-good');
}

// Liberation de la chambre a la fin REELLE de l'hospitalisation uniquement -- appelee depuis
// verifierProgressionHospitalisation() (plus bas dans ce fichier), seul endroit ou
// state.hospitalisation est efface par la progression naturelle des jours (verifie : aucun
// refresh/navigation/visite ne declenche cette fonction, seulement doDormir()). Meme patron que
// resilierLogementSocialSiDepartMontrouge (plateau-logements-montrouge.js) :
// splice(state.locationsActives) + sbSupprimerLocation.
function libererChambreCliniquePatient(nomPatient) {
  if (!nomPatient) return;
  const idx = (state.locationsActives || []).findIndex(l =>
    l.locataire === nomPatient && l.buildingId === 'clinique-privee' && l.chambreClinique === true);
  if (idx < 0) return;
  const bail = state.locationsActives[idx];
  state.locationsActives.splice(idx, 1);
  if (typeof sbSupprimerLocation === 'function') sbSupprimerLocation(bail.buildingId, bail.roomId, bail.city).catch(() => {});
}

// =====================
// CONTROLE DES VISITES (section 3 du lot) -- ordre unique present sur les 10 chambres, reserve
// au patient occupant. Aucun gain/cout/effet : uniquement le champ visitesAutorisees de
// l'attribution locations_actives.
function doGererVisitesChambre(pa, cost) {
  const loc = (typeof getLocationPourRoom === 'function') ? getLocationPourRoom('clinique-privee', state.currentRoom, 'capitale') : null;
  if (!loc || !loc.chambreClinique) {
    showToast('Chambre inoccupée', "Cette chambre n'est pas attribuée pour l'instant.", false);
    return;
  }
  if (loc.locataire !== state.char?.name) {
    showToast('Accès refusé', 'Seul le patient occupant peut gérer les visites de sa chambre.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Visites de la chambre';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">Visites actuellement ' + (loc.visitesAutorisees !== false ? 'autorisées' : 'interdites') + '.</div>' +
    '<div style="display:flex;flex-direction:column;gap:.4rem">' +
    '<button onclick="confirmerVisitesChambreUI(true)" style="padding:.6rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.85rem;text-align:left">Autoriser les visites</button>' +
    '<button onclick="confirmerVisitesChambreUI(false)" style="padding:.6rem;border:1px solid #5a2a2a;background:transparent;color:#8a3a2a;cursor:pointer;font-size:.85rem;text-align:left">Interdire les visites</button>' +
    '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="padding:.6rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer;font-size:.85rem;text-align:left">Annuler</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVisitesChambreUI(autoriser) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const loc = (typeof getLocationPourRoom === 'function') ? getLocationPourRoom('clinique-privee', state.currentRoom, 'capitale') : null;
  if (!loc || loc.locataire !== state.char?.name) { showToast('Accès refusé', '', false); return; }
  loc.visitesAutorisees = !!autoriser;
  if (typeof sbSaveLocation === 'function') await sbSaveLocation(loc).catch(() => {});
  showToast(autoriser ? 'Visites autorisées' : 'Visites interdites', autoriser ? 'Les autres joueurs peuvent à nouveau vous rendre visite.' : 'Seul le personnel de la clinique peut désormais entrer.', true);
  addJournalEntry(autoriser ? 'Visites de la chambre autorisées.' : 'Visites de la chambre interdites.', 'event-info');
}

// =====================
// ACCES AUX CHAMBRES DEPUIS L'ACCUEIL (arbitrage UX, 20 aout 2026) -- point d'entree unique pour
// rejoindre sa propre chambre ou rendre visite a un patient qui l'autorise. Remplace l'affichage
// des 10 onglets chambre_1..chambre_10 (masques dans enterBuilding, plateau-navigation.js) :
// aucun texte ici ne mentionne jamais un roomId technique, seulement des noms de patients.
function doOuvrirChambresClinique(pa, cost) {
  const moi = state.char?.name;
  const maChambre = moi ? getChambreAttribueeClinique(moi) : null;
  const visiteurs = (state.locationsActives || []).filter(l =>
    l.buildingId === 'clinique-privee' && l.chambreClinique === true &&
    l.locataire !== moi && l.visitesAutorisees !== false);

  let corps = '<div style="padding:1rem"><div style="display:flex;flex-direction:column;gap:.4rem">';
  if (maChambre) {
    corps += '<button onclick="rejoindreChambreClinique(\'' + moi.replace(/'/g, "\\'") + '\')" style="padding:.6rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.85rem;text-align:left">Rejoindre ma chambre</button>';
  }
  visiteurs.forEach(l => {
    const nomEchappe = l.locataire.replace(/'/g, "\\'");
    corps += '<button onclick="rejoindreChambreClinique(\'' + nomEchappe + '\')" style="padding:.6rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.85rem;text-align:left">Rendre visite à ' + l.locataire + '</button>';
  });
  if (!maChambre && visiteurs.length === 0) {
    corps += '<div style="font-size:.85rem;color:#8a8060">Aucun patient ne reçoit actuellement de visites.</div>';
  }
  corps += '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="padding:.6rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer;font-size:.85rem;text-align:left">Annuler</button>';
  corps += '</div></div>';

  document.getElementById('postes-modal-title').textContent = 'Chambres';
  document.getElementById('postes-body').innerHTML = corps;
  document.getElementById('modal-postes').classList.add('open');
}

// Le controle d'acces reel reste enterRoom (plateau-navigation.js), interroge de nouveau au clic
// (pas de donnee figee dans la popup) : si l'etat a change entre l'ouverture (visites interdites
// entre-temps, patient sorti) et ce clic, c'est enterRoom qui refuse -- cette fonction se contente
// de retrouver la chambre actuelle du patient puis d'y naviguer normalement.
function rejoindreChambreClinique(nomPatient) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const loc = getChambreAttribueeClinique(nomPatient);
  if (!loc) {
    showToast('Chambre indisponible', "Ce patient ne dispose plus d'une chambre pour l'instant.", false);
    return;
  }
  if (typeof enterBuilding === 'function') enterBuilding('clinique-privee', true);
  if (typeof enterRoom === 'function') enterRoom('clinique-privee', loc.roomId, null);
}

async function doCentreAntiPoison(pa) {
  if (!state.empoisonnement?.actif) {
    showToast('Rien a traiter', 'Vous n\'etes pas empoisonne(e).', false);
    return;
  }
  const today = state.day || 1;
  if (!state.centreAntiPoisonToday || state.centreAntiPoisonToday.jour !== today) {
    state.centreAntiPoisonToday = { jour: today, tentatives: 0 };
  }
  if (state.centreAntiPoisonToday.tentatives >= 2) {
    showToast('Limite atteinte', 'Deux tentatives maximum par jour.', false);
    return;
  }

  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const ordre = room?.orders?.find(o => o.fn === 'centre_anti_poison');
  const cout = ordre?.cost || 0;
  const successRate = ordre?.successRate || 70;
  const r = await deduireCoutOrdre({ pa, cost: cout });
  if (!r.ok) { showToast('Fonds insuffisants', cout + ' FR requis.', false); return; }

  state.centreAntiPoisonToday.tentatives++;

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= successRate) {
    state.empoisonnement = null;
    if (state.statsAffaiblies) state.statsAffaiblies = null;
    updateUI();
    showToast('Gueri(e) !', 'Le poison a ete neutralise avec succes.', true, true);
    addJournalEntry('Traitement anti-poison reussi. Vous etes gueri(e).', 'event-good');
  } else {
    updateUI();
    showToast('Echec du traitement', 'Le poison resiste. Reessayez, ou attendez d\'y etre force(e).', false);
    addJournalEntry('Tentative de traitement anti-poison infructueuse.', 'event-bad');
  }
}

// =====================
// SOINS STANDARDS -- dispensaire public / clinique privee (lot filiere alcool->desinfectant,
// 20 aout 2026). Fonctions dediees, hors du chemin generique doOrder()/ORDER_EFFECTS/
// applyEffects() : gain Sante/PA strictement fixe, jamais de jet ni de multiplicateur crit --
// meme doctrine que doCentreAntiPoison/doTransfertCliniquePrivee ci-dessus (deduireCoutOrdre(),
// jamais la deduction inline generique de doOrder()).
//
// Stock medical : reutilise integralement le patron batiments_etat deja etabli pour
// entrepot/usine (sbGetBatimentEtat/sbSetBatimentEtat, meme table) -- nouvelle cle "sante" par
// batiment plutot qu'un second moteur economique. Champ stockMatieres nomme a l'identique de
// celui des usines/commerces pour reutiliser crediterStockMatiereCommerce() sans modification
// (plateau-actions-illegales-rumeurs.js, deja generique). Approvisionne exclusivement par un
// joueur via vendreRessourceMedicaleStructure() plus bas (meme squelette que
// vendreMatierePremiereUsine) -- aucun transfert automatique depuis un entrepot.
//
// Limite quotidienne : meme idiome jour-compare que doCentreAntiPoison (state.centreAntiPoisonToday)
// -- MAIS stockee dans state.char.stats plutot qu'en sibling direct de state.char. Verifie ce
// jour meme : ni centreAntiPoisonToday ni dernierGainENTJour (appliquerGainENT, plateau-pnj.js)
// ne figurent dans le mapping de sbSavePersonnage/sbLoadPersonnage (supabase.js) -- aucun des
// deux ne survit reellement a un rafraichissement malgre l'usage de cet idiome. state.char.stats
// est en revanche deja un champ JSONB reellement persiste (mappe tel quel dans les deux sens),
// donc les deux nouveaux compteurs y sont places pour satisfaire l'exigence explicite de
// persistance reelle, sans migration ni nouvelle colonne.
// Financement (correctif, 20 aout 2026, suite audit demande par Fred) : PAS de caisse privee
// inventee pour les structures PUBLIQUES. Les batiments publics/institutionnels comparables
// (commissariat/tribunal/marche/stade/dispensaire) utilisent deja un systeme etabli --
// chargerCaisseBatiment/crediterCaisseBatiment/debiterCaisseBatimentAtomique, table dediee
// (sbGetCaisseBatiment/sbSaveCaisseBatiment), cle getCaisseLocaleId('dispensaire', ville) --
// alimente par le Maire Adjoint via "Financer un batiment communal" (ouvrirModalFinancerCommunal,
// plateau-justice-economie.js), qui liste DEJA "Dispensaire" comme option. Solde de depart 0,
// comme tous les autres batiments communaux -- aucune valeur inventee, c'est le comportement par
// defaut existant de chargerCaisseBatiment. Reutilise ce systeme tel quel pour le dispensaire
// (financement:'institution'), au lieu d'une caisse batiments_etat autonome.
// La clinique privee, elle, reste une entreprise privee (jamais listee dans le financement
// communal) : garde sa propre caisse dans batiments_etat.sante (financement:'propre'), mais SANS
// dotation initiale inventee (correctif, 20 aout 2026, decision explicite de Fred) -- demarre a 0,
// alimentee uniquement par le produit reel (net de taxe, appliquerTaxeTransaction() reutilisee
// telle quelle -- aucune fiscalite specifique clinique) de ses propres soins payes par les
// patients (doSoinCliniquePrivee ci-dessous). Aucun bootstrap autonome ici, contrairement aux
// commerces/usines de lots precedents.

// Les 3 dispensaires publics de Republia partagent le meme mecanisme, meme financement
// institutionnel, et le MEME compteur quotidien (aucun n'a de "city" fixe : state.currentCity
// au moment de l'action determine la ville reelle, stock/caisse restant proprement locaux par
// ville malgre le buildingId partage entre PSM et Montrouge -- meme principe que
// getCaisseLocaleId, deja documente dans ce fichier pour les caisses communales).
const STRUCTURES_MEDICALES = {
  'dispensaire-public':   { ressources: ['desinfectant'], financement: 'institution', categorieCaisse: 'dispensaire' },
  'dispensaire-public-v': { ressources: ['desinfectant'], financement: 'institution', categorieCaisse: 'dispensaire' },
  'clinique-privee':      { ressources: ['desinfectant', 'medicaments'], financement: 'propre' }
};

function structureMedicaleAccepteRessource(buildingId, ressource) {
  return (STRUCTURES_MEDICALES[buildingId]?.ressources || []).includes(ressource);
}

// Phrases d'infirmiere (validees par Fred) pour le soin public -- affichage generique, non lie a
// un PNJ nomme dans le code (les 3 infirmieres nommees -- Anne Tibiotique/Betty Dine/Agnes
// Thesie -- sont implantees cote data.js comme PNJ visibles dans leurs salles respectives, mais
// la phrase elle-meme reste independante de qui est physiquement affiche).
const PHRASES_INFIRMIERE_SOIN_PUBLIC = [
  "On n'avait plus de bisous magiques, du coup on vous a mis du désinfectant.",
  "Ça va piquer un peu. Si ça pique beaucoup, c'est que ça marche beaucoup.",
  "Le médecin ? Ah non, pour 25 francs vous avez moi.",
  "C'est propre. Enfin, suffisamment propre pour l'administration."
];
const PHRASE_INFIRMIERE_RUPTURE_STOCK = "Alors… bonne nouvelle : vous n'avez rien à payer. Mauvaise nouvelle : on n'a plus rien pour vous soigner.";

// Repliques de Sophie Stiquay (infirmiere, clinique privee de Luthecia -- lot dedie, 20 aout
// 2026), validees par Fred. Meme mecanisme de tirage aleatoire que PHRASES_INFIRMIERE_SOIN_PUBLIC
// ci-dessus (aucune duplication : reutilise le meme Math.random()*length au point d'appel,
// affichee uniquement apres un soin reellement reussi -- jamais sur un echec/limite/rupture).
const PHRASES_SOPHIE_STIQUAY_SOIN_CLINIQUE = [
  "Détendez-vous… ici, nous nous occupons de tout.",
  "Vous êtes entre de très bonnes mains.",
  "Ne bougez pas… n'oubliez pas que je suis assise sur vous.",
  "Vous voyez ? Prendre soin de soi peut être très agréable.",
  "Encore quelques secondes… Je vous promets que vous ressortirez en pleine forme.",
  "Nous espérons que vous avez apprécié votre passage. Moi, en tout cas, j'ai été ravie de m'occuper de vous."
];

// Generique pour les 3 dispensaires (Luthecia/PSM/Montrouge) : buildingId/ville lus depuis
// state.currentBuilding/state.currentCity, jamais code en dur -- meme patron que
// doOuvrirVenteDirecteUsine/doProduireUsine (plateau-justice-economie.js). Compteur quotidien
// COMMUN aux 3 (une seule cle state.char.stats.soinPublicJour, jamais scopee par batiment) : un
// joueur ne peut pas repeter le soin public dans une autre ville le meme jour.
async function doSoinPublic(pa, cost) {
  if (!state.char) return;
  const buildingId = state.currentBuilding;
  const cfg = STRUCTURES_MEDICALES[buildingId];
  if (!cfg || cfg.financement !== 'institution') { showToast('Indisponible', '', false); return; }
  const today = state.day || 1;
  if (!state.char.stats) state.char.stats = {};

  // 1) limite quotidienne (commune aux 3 structures publiques)
  if (state.char.stats.soinPublicJour === today) {
    showToast('Déjà soigné(e) aujourd\'hui', 'Un seul soin public par jour, quelle que soit la ville.', false);
    return;
  }
  // 2) fonds du patient
  if ((state.arg || 0) < cost) {
    showToast('Fonds insuffisants', cost + ' FR requis.', false);
    return;
  }
  // 3) stock medical de la structure (local a la ville reelle du batiment)
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, ville, buildingId).catch(() => null) : null;
  const sante = etat?.sante || { stockMatieres: {} };
  if (!sante.stockMatieres) sante.stockMatieres = {};
  const stockDesinfectant = sante.stockMatieres.desinfectant || 0;
  if (stockDesinfectant < 1) {
    showToast('Rupture de stock', PHRASE_INFIRMIERE_RUPTURE_STOCK, false);
    return;
  }

  // 4) debit FR + ressources (seulement maintenant que tout est verifie)
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', cost + ' FR requis.', false); return; }
  sante.stockMatieres.desinfectant = stockDesinfectant - 1;
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(pays, ville, buildingId, { ...etat, sante }).catch(() => {});

  // 5) effets fixes, jamais de jet/multiplicateur
  state.hp = Math.min(100, (state.hp || 0) + 10);
  state.pa = Math.min(PA_MAX, (state.pa || 0) + 1);

  // 6) enregistrement de l'utilisation quotidienne (compteur commun, pas par batiment)
  state.char.stats.soinPublicJour = today;

  updateUI();
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});

  const phrase = PHRASES_INFIRMIERE_SOIN_PUBLIC[Math.floor(Math.random() * PHRASES_INFIRMIERE_SOIN_PUBLIC.length)];
  showToast('Soins reçus', '+10 Santé, +1 PA. « ' + phrase + ' »', true, true);
  addJournalEntry('Soin public reçu au dispensaire (-' + cost + ' FR). +10 Santé, +1 PA.', 'event-good');
}

async function doSoinCliniquePrivee(pa, cost) {
  if (!state.char) return;
  const today = state.day || 1;
  if (!state.char.stats) state.char.stats = {};

  // 1) limite quotidienne (compteur independant de celui du soin public)
  if (state.char.stats.soinCliniqueJour === today) {
    showToast('Déjà soigné(e) aujourd\'hui', 'Un seul soin en clinique privée par jour.', false);
    return;
  }
  // 2) fonds du patient
  if ((state.arg || 0) < cost) {
    showToast('Fonds insuffisants', cost + ' FR requis.', false);
    return;
  }
  // 3) stock medical de la structure (desinfectant ET medicaments) -- clinique privee, Luthecia
  // uniquement (pas concernee par l'extension aux 3 dispensaires publics)
  const pays = state.country || 'republic';
  const ville = 'capitale';
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, ville, 'clinique-privee').catch(() => null) : null;
  const sante = etat?.sante || { caisse: 0, stockMatieres: {} };
  if (!sante.stockMatieres) sante.stockMatieres = {};
  const stockDesinfectant = sante.stockMatieres.desinfectant || 0;
  const stockMedicaments = sante.stockMatieres.medicaments || 0;
  if (stockDesinfectant < 1 || stockMedicaments < 1) {
    showToast('Rupture de stock', 'La clinique manque actuellement de désinfectant et/ou de médicaments.', false);
    return;
  }

  // 4) debit du patient
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', cost + ' FR requis.', false); return; }

  // 5) taxation existante (aucune fiscalite specifique clinique) puis credit reel de la caisse --
  // correctif demande par Fred, 20 aout 2026 : plus aucune dotation initiale inventee, la caisse
  // demarre a 0 et ne se remplit que du produit net (apres taxe) de ses propres soins payes.
  let net = cost;
  if (typeof appliquerTaxeTransaction === 'function') {
    const t = await appliquerTaxeTransaction(cost);
    net = t.net;
  }
  sante.caisse = (sante.caisse || 0) + net;

  // 6) decrement des ressources consommees
  sante.stockMatieres.desinfectant = stockDesinfectant - 1;
  sante.stockMatieres.medicaments = stockMedicaments - 1;
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(pays, ville, 'clinique-privee', { ...etat, sante }).catch(() => {});

  // 7) gains Sante/PA fixes
  state.hp = Math.min(100, (state.hp || 0) + 30);
  state.pa = Math.min(PA_MAX, (state.pa || 0) + 2);

  // 8) enregistrement de l'utilisation quotidienne
  state.char.stats.soinCliniqueJour = today;

  updateUI();
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});

  const phraseSophie = PHRASES_SOPHIE_STIQUAY_SOIN_CLINIQUE[Math.floor(Math.random() * PHRASES_SOPHIE_STIQUAY_SOIN_CLINIQUE.length)];
  showToast('Soins reçus', '+30 Santé, +2 PA. « ' + phraseSophie + ' »', true, true);
  addJournalEntry('Soin reçu en clinique privée (-' + cost + ' FR). +30 Santé, +2 PA.', 'event-good');
}

// =====================
// APPROVISIONNEMENT DES STRUCTURES MEDICALES -- vente par un joueur, depuis son inventaire
// personnel, de desinfectant/medicaments a une structure de soins. Meme squelette que
// vendreMatierePremiereUsine (plateau-justice-economie.js) : verifications sans effet de bord
// d'abord, seul effet de bord (paiement) ensuite. Reutilise crediterStockMatiereCommerce()
// (plateau-actions-illegales-rumeurs.js, deja generique) pour la mise a jour stock/cout moyen --
// aucune logique de stock dupliquee. Prix : prixAchatFournisseur (meme doctrine que
// vendreMatierePremiereUsine, aucun systeme de prix directeur pour l'instant).
//
// Paiement : branche selon STRUCTURES_MEDICALES[buildingId].financement (correctif, 20 aout
// 2026) -- 'institution' (dispensaires publics) paie via la caisse communale existante
// (debiterCaisseBatimentAtomique, plateau-justice-economie.js, meme primitive tout-ou-rien deja
// utilisee ailleurs pour un cout institutionnel fixe) ; 'propre' (clinique privee) continue de
// payer depuis sa propre caisse en batiments_etat.sante.caisse. Aucune duplication de moteur :
// stock (stockMatieres) toujours dans batiments_etat.sante quel que soit le financement.
async function vendreRessourceMedicaleStructure(buildingId, pays, ville, ressource, qte) {
  const cfg = STRUCTURES_MEDICALES[buildingId];
  if (!cfg || !cfg.ressources.includes(ressource)) return { ok: false, raison: 'ressource_non_acceptee' };
  if (!qte || qte <= 0) return { ok: false, raison: 'quantite_invalide' };

  const lot = (state.inventory || []).find(i => i.stackable && i.stackKey === ressource && (i.qty || 0) > 0);
  if (!lot || lot.qty < qte) return { ok: false, raison: 'stock_personnel_insuffisant' };

  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, ville, buildingId).catch(() => null) : null;
  if (!etat) return { ok: false, raison: 'introuvable' };
  const sante = etat.sante || (cfg.financement === 'propre' ? { caisse: 0, stockMatieres: {} } : { stockMatieres: {} });
  if (!sante.stockMatieres) sante.stockMatieres = {};

  const res = RESSOURCES_ECONOMIE[ressource];
  const stockActuel = sante.stockMatieres[ressource] || 0;
  const placeRestante = Math.max(0, res.plafond - stockActuel);
  if (placeRestante < qte) return { ok: false, raison: 'stock_plein', placeRestante };

  const prixUnitaire = res.prixAchatFournisseur;
  const total = prixUnitaire * qte;

  let paiementOk;
  if (cfg.financement === 'institution' && typeof debiterCaisseBatimentAtomique === 'function' && typeof getCaisseLocaleId === 'function') {
    paiementOk = (await debiterCaisseBatimentAtomique(pays, getCaisseLocaleId(cfg.categorieCaisse, ville), total)) === total;
  } else {
    paiementOk = (sante.caisse || 0) >= total;
  }
  if (!paiementOk) return { ok: false, raison: 'caisse_insuffisante' };

  lot.qty -= qte;
  if (lot.qty <= 0) state.inventory = state.inventory.filter(i => i !== lot);

  crediterStockMatiereCommerce(sante, ressource, qte, prixUnitaire);
  if (cfg.financement !== 'institution') sante.caisse = (sante.caisse || 0) - total;
  state.arg = (state.arg || 0) + total;

  const nouvelEtat = { ...etat, sante };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(pays, ville, buildingId, nouvelEtat).catch(() => {});

  return { ok: true, total, prixUnitaire, qte };
}

function doVendreRessourceMedicaleGenerique(pa, cost) {
  const buildingId = state.currentBuilding;
  if (!buildingId) { showToast('Indisponible', '', false); return; }
  doOuvrirVendreRessourceMedicale(buildingId, pa, cost);
}

async function doOuvrirVendreRessourceMedicale(buildingId, pa, cost) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const cur = COUNTRIES[state.country || 'republic']?.cur || 'FR';
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, ville, buildingId).catch(() => null) : null;
  const sante = etat?.sante || { stockMatieres: {} };
  const ressources = STRUCTURES_MEDICALES[buildingId]?.ressources || [];
  const disponibles = ressources.filter(m => (state.inventory || []).some(i => i.stackable && i.stackKey === m && (i.qty || 0) > 0));

  document.getElementById('postes-modal-title').textContent = 'Fournir des ressources médicales';
  let html = '<div style="padding:1rem">';
  if (disponibles.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060">Vous ne possédez aucune ressource utilisée par cette structure' + (ressources.length ? ' (' + ressources.map(m => (RESSOURCES_ECONOMIE[m]?.label || m)).join(', ') + ')' : '') + '.</div>';
  } else {
    html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.7rem">Prix d\'achat au tarif fournisseur en vigueur.</div>';
  }
  disponibles.forEach(m => {
    const lot = (state.inventory || []).find(i => i.stackable && i.stackKey === m && (i.qty || 0) > 0);
    const qteDispo = lot?.qty || 0;
    const res = RESSOURCES_ECONOMIE[m];
    const prixUnitaire = res.prixAchatFournisseur;
    const stockActuel = sante.stockMatieres[m] || 0;
    const placeRestante = Math.max(0, res.plafond - stockActuel);
    const qteInitiale = Math.max(1, Math.min(qteDispo, placeRestante));
    html += '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.5rem">';
    html += '<span style="flex:1;font-size:.85rem;color:#c0b090">' + res.label + ' (' + prixUnitaire.toLocaleString('fr-FR') + ' ' + cur + '/unité) — vous en avez ' + qteDispo + ', capacité restante ' + placeRestante + '</span>';
    html += '<input type="number" id="vendre-sante-qte-' + m + '" min="1" max="' + qteDispo + '" value="' + qteInitiale + '" style="width:70px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.85rem;outline:none"/>';
    html += '<button ' + (placeRestante === 0 ? 'disabled style="padding:.3rem .6rem;border:1px solid #3a2a20;background:transparent;color:#5a5040;cursor:default;font-size:.82rem"' : 'onclick="confirmerVendreRessourceMedicaleUI(\'' + buildingId + '\',\'' + m + '\')" style="padding:.3rem .6rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.82rem"') + '>Vendre</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVendreRessourceMedicaleUI(buildingId, ressource) {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const qte = parseInt(document.getElementById('vendre-sante-qte-' + ressource)?.value || '0');
  document.getElementById('modal-postes')?.classList.remove('open');
  if (!qte || qte <= 0) { showToast('Quantité invalide', '', false); return; }

  const res = await vendreRessourceMedicaleStructure(buildingId, pays, ville, ressource, qte);
  const label = RESSOURCES_ECONOMIE[ressource]?.label || ressource;
  if (!res.ok) {
    const messages = {
      introuvable: '',
      ressource_non_acceptee: "Cette structure n'utilise pas cette ressource.",
      quantite_invalide: '',
      stock_personnel_insuffisant: 'Vous n\'avez pas ' + qte + ' unité(s) de ' + label + '.',
      stock_plein: 'Le stock maximum de cette ressource est atteint pour cette structure.',
      caisse_insuffisante: "Cette structure ne peut pas acheter cette quantité actuellement."
    };
    showToast('Vente refusée', messages[res.raison] || '', false);
    return;
  }
  updateUI();
  showToast('Vente effectuée', '+' + res.total.toLocaleString('fr-FR') + ' FR pour ' + res.qte + ' ' + label + '.', true, true);
  addJournalEntry('Vente de ' + res.qte + ' ' + label + ' à ' + (BUILDINGS[buildingId]?.shortName || buildingId) + ' (+' + res.total.toLocaleString('fr-FR') + ' FR).', 'event-good');
  doOuvrirVendreRessourceMedicale(buildingId, 0, 0);
}

async function doReserverChambreHotel(pa) {
  const confortMap = {
    'hotel-republica': { moral: 3, paBonus: 2 },
    'hotel-port':      { moral: 3, paBonus: 2 },
    'hotel-mineur':    { moral: 3, paBonus: 2 },
    'palais-presidentiel': { moral: 8, paBonus: 8 }
  };
  const bonus = confortMap[state.currentBuilding] || { moral: 2, paBonus: 1 };
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const ordre = room?.orders?.find(o => o.fn === 'reserver_chambre_hotel');
  const cout = ordre?.cost || 60;
  const r = await deduireCoutOrdre({ pa, cost: cout });
  if (!r.ok) { showToast('Fonds insuffisants', cout + ' FR requis.', false); return; }

  // Caisse propre a l'hotel (correctif du 23 aout 2026, audit dedie) : le paiement disparaissait
  // integralement jusqu'ici (aucune caisse creditee nulle part). Reutilise exactement le meme
  // mecanisme deja en place pour les commerces/la buvette -- appliquerTaxeTransaction() (taux
  // local + national INCHANGES) puis crediterCaisseBatiment() sur une caisse identifiee par
  // getCaisseLocaleId('hotel', ville) (meme principe deja eprouve par la buvette/le marche :
  // categorie stable 'hotel', ville reelle du batiment) -- une caisse DISTINCTE par ville, y
  // compris pour hotel-mineur qui partage son buildingId entre plusieurs villes/empires.
  // Reutilise caisses_batiments, deja existante : aucune nouvelle table.
  if (cout > 0) {
    const pays = state.country || 'republic';
    const ville = state.currentCity || 'capitale';
    let net = cout;
    if (typeof appliquerTaxeTransaction === 'function') {
      const t = await appliquerTaxeTransaction(cout);
      net = t.net;
    }
    if (typeof crediterCaisseBatiment === 'function' && typeof getCaisseLocaleId === 'function') {
      await crediterCaisseBatiment(pays, getCaisseLocaleId('hotel', ville), net).catch(() => {});
    }
  }

  state.reservationHotel = { buildingId: state.currentBuilding, bonus };
  updateUI();
  showToast('Chambre reservee', 'Vous obtiendrez un bonus de +' + bonus.paBonus + ' PA et +' + bonus.moral + ' Moral en passant l\'ordre Dormir <strong>dans cette chambre</strong>.', true, true);
  addJournalEntry('Vous avez reserve une chambre d\'hotel. Vous obtiendrez un bonus de ' + bonus.paBonus + ' PA + ' + bonus.moral + ' moral en passant l\'ordre dormir <strong>dans cette chambre</strong>.', 'event-good');
  if (typeof queteAccueilApresReservationChambre === 'function') queteAccueilApresReservationChambre();
}

async function doServiceEtage(pa) {
  const reservation = state.reservationHotel;
  if (!reservation || reservation.buildingId !== state.currentBuilding) {
    showToast('Chambre non reservee', 'Vous devez d\'abord reserver une chambre a l\'accueil pour beneficier du service d\'etage.', false);
    return;
  }
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const ordre = room?.orders?.find(o => o.fn === 'service_etage');
  const cout = ordre?.cost || 150;
  const r = await deduireCoutOrdre({ pa, cost: cout });
  if (!r.ok) { showToast('Fonds insuffisants', cout + ' FR requis.', false); return; }
  state.hp = Math.min(100, (state.hp || 0) + 10);
  state.moral = Math.min(100, (state.moral || 0) + 1);
  state.bonusPaProchainDormir = (state.bonusPaProchainDormir || 0) + 1;
  updateUI();
  showToast('Service d\'etage', 'Dejeuner servi en chambre. +10 Sante, +1 Moral immediats. +1 PA au prochain Dormir.', true, true);
  addJournalEntry('Service d\'etage en chambre : +10 Sante, +1 Moral, +1 PA differe au prochain Dormir.', 'event-good');
}

async function doDormirChambre() {
  const reservation = state.reservationHotel;
  if (!reservation || reservation.buildingId !== state.currentBuilding) {
    showToast('Chambre non reservee', 'Vous n\'avez pas reserve la chambre. Vous devez passer l\'ordre Dormir a partir de votre fiche personnage.', false);
    return;
  }
  // Garde-fou explicite (23 aout 2026, dernier point avant GO) : verifie que le personnage est
  // REELLEMENT dans la chambre de l'hotel reserve, pas seulement que le bouton dormir_chambre
  // n'est affiche que la -- une verification cote fonction, pas seulement cote UI. Reutilise la
  // configuration DEJA existante plutot que d'ajouter une nouvelle table buildingId->roomId en
  // parallele (qui pourrait diverger de data.js) : dormir_chambre n'est declare que par les 3
  // rooms chambre reelles (chambres/chambre_port/chambre_mineur, verifie -- aucune autre room ne
  // porte cet ordre), donc controler que la room courante offre bien cet ordre est strictement
  // equivalent au mapping explicite hotel-republica->chambres/hotel-port->chambre_port/
  // hotel-mineur->chambre_mineur, sans le dupliquer.
  const roomActuelle = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const estDansLaChambre = roomActuelle?.orders?.some(o => o.fn === 'dormir_chambre');
  if (!estDansLaChambre) {
    showToast('Chambre non reservee', 'Vous devez etre physiquement dans la chambre de l\'hotel reserve pour beneficier du bonus.', false);
    return;
  }
  const reussi = await doDormir();
  if (reussi) {
    // Plafonne a PA_MAX (Lot 1) : doDormir() a deja plafonne sa propre recuperation, mais ce
    // bonus de chambre s'applique dans un second temps, en dehors de doDormir() -- sans ce
    // Math.min, il pourrait a lui seul faire depasser la reserve maximale.
    state.pa = Math.min(PA_MAX, (state.pa || 0) + reservation.bonus.paBonus);
    state.moral = Math.min(100, (state.moral || 0) + reservation.bonus.moral);
    state.reservationHotel = null;
    updateUI();
    showToast('Bonus de chambre applique', '+' + reservation.bonus.paBonus + ' PA, +' + reservation.bonus.moral + ' Moral.', true, true);
    addJournalEntry('Bonus de la chambre reservee applique : +' + reservation.bonus.paBonus + ' PA, +' + reservation.bonus.moral + ' moral.', 'event-good');
  }
}

function verifierProgressionHospitalisation() {
  if (!state.hospitalisation) return;
  const jourFin = state.hospitalisation.jourFin || ((state.hospitalisation.jourDebut || state.day || 1) + 1);
  if ((state.day || 1) >= jourFin) {
    // Liberation de la chambre clinique, uniquement ici (fin reelle de l'hospitalisation) --
    // jamais sur un refresh/une navigation interne/une visite, voir libererChambreCliniquePatient.
    if (state.hospitalisation.lieu === 'clinique' && typeof libererChambreCliniquePatient === 'function') {
      libererChambreCliniquePatient(state.char?.name);
    }
    state.hospitalisation = null;
    showToast('Rétabli(e) !', 'Vous avez retrouvé toutes vos capacités.', true, true);
    addJournalEntry('Vous êtes complètement rétabli(e) de votre agression.', 'event-good');
    return;
  }
  const joursRestants = jourFin - (state.day || 1);
  state.pa = 0;
  showToast('En convalescence', 'Encore ' + joursRestants + ' jour(s) avant votre rétablissement complet. Déplacement impossible, sauf transfert vers une clinique privée.', false);
  addJournalEntry('Convalescence en cours (' + state.hospitalisation.lieu + '). Encore ' + joursRestants + ' jour(s).', 'event-info');
}

function doSesoigner() {
  const medocs = (state.inventory || []).filter(i => i.type === 'medicament');
  if (medocs.length === 0) { showToast('Aucun medicament', '', false); return; }
  const idx = state.inventory.indexOf(medocs[0]);
  state.inventory.splice(idx, 1);
  state.hp = Math.min(100, state.hp + 20);
  updateUI();
  showToast('Soins', '+20 Sante. ' + (state.inventory.filter(i=>i.type==='medicament').length) + ' medicament(s) restant(s).', true);
  switchSelfTab('inventaire', null);
}

function dropItem(index) {
  const item = state.inventory[index];
  if (!item) return;
  state.inventory.splice(index, 1);
  showToast('Objet jete', item.name + ' retire de votre inventaire.', false);
  switchSelfTab('inventaire', null);
}


// =====================
// DETAIL D'UN OBJET D'INVENTAIRE (clic) + GESTION (donner/jeter/abandonner/supprimer)
// =====================
async function ouvrirDetailObjetInventaire(idx) {
  const item = state.inventory[idx];
  if (!item) return;

  if (item.calepinEnigme1 && typeof enigme1AfficherCalepin === 'function') {
    enigme1AfficherCalepin(idx);
    return;
  }

  document.getElementById('postes-modal-title').textContent = item.name;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const legal = item.legal === false ? '<span style="color:#cc4444;font-size:.72rem"> ⚠ Objet illégal / compromettant</span>' : '';
  const imageHtml = item.imageUrl
    ? '<img src="' + item.imageUrl + '" style="width:100%;border-radius:4px;margin-bottom:.8rem;max-height:220px;object-fit:cover"/>'
    : '';

  // Charger les vrais joueurs presents pour l'option "donner"
  let joueursPresents = [];
  if (typeof sbGetPresencesInRoom === 'function' && state.currentBuilding && state.currentRoom) {
    try {
      const presents = await sbGetPresencesInRoom(state.country, state.currentCity, state.currentBuilding, state.currentRoom);
      joueursPresents = (presents || []).filter(p => p.name !== state.char?.name);
    } catch(e) {}
  }

  let html = '<div style="padding:1rem">';
  html += imageHtml;
  html += '<div style="font-size:.85rem;color:#a0a080;line-height:1.6;margin-bottom:.8rem">' + (item.desc || '') + legal + '</div>';

  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';

  // Aliment a emporter (Lot 3, 23 aout 2026) : bouton Consommer, toujours affiche independamment
  // de la protection "objet de quete" (manger son propre repas n'est jamais un transfert).
  // AUCUN indice de fraicheur/age ici (peremption volontairement invisible avant consommation,
  // regle de design validee) -- le libelle reste neutre, identique quel que soit l'etat reel.
  if (item.familleProduitMarche === 'aliment') {
    html += '<button onclick="consommerAliment(' + idx + ')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #6a9a4a;background:transparent;color:#8aca6a;cursor:pointer"><i class="ti ti-meat"></i> Consommer</button>';
  }

  // Carte postale (Lot 4, 23 aout 2026) : bouton toujours affiche independamment de la
  // protection "objet de quete" (ni un transfert entre joueurs, ni un abandon). etatCarte
  // 'vierge' -> ouvre la composition ; 'ecrite' -> ouvre la lecture (jamais l'inverse, une carte
  // ecrite ne redevient jamais vierge -- point 14 du cahier des charges).
  if (item.familleProduitMarche === 'carte_postale') {
    if (item.etatCarte === 'vierge') {
      html += '<button onclick="ouvrirEcrireCartePostale(' + idx + ')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #6a9a4a;background:transparent;color:#8aca6a;cursor:pointer"><i class="ti ti-feather"></i> Écrire et envoyer</button>';
    } else if (item.etatCarte === 'ecrite') {
      html += '<button onclick="lireCartePostale(' + idx + ')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #6a9a4a;background:transparent;color:#8aca6a;cursor:pointer"><i class="ti ti-mail-opened"></i> Lire</button>';
    }
  }

  const protege = typeof colisSecretProtege === 'function' && colisSecretProtege(item);
  if (protege) {
    html += '<div style="font-size:.78rem;color:#6a5a30;font-style:italic"><i class="ti ti-lock"></i> Indispensable à une mission en cours — ne peut être ni donné à un autre joueur, ni abandonné, ni détruit.</div>';
  } else {
    if (joueursPresents.length > 0) {
      html += '<select id="donner-objet-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none">';
      joueursPresents.forEach(p => { html += '<option value="' + p.name + '">' + p.name + '</option>'; });
      html += '</select>';
      html += '<button onclick="donnerObjetAJoueur(' + idx + ')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #4a6aaa;background:transparent;color:#6a8aca;cursor:pointer"><i class="ti ti-gift"></i> Donner a ce joueur</button>';
    }

    html += '<button onclick="jeterObjetInventaire(' + idx + ')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #8a6a30;background:transparent;color:#a0905a;cursor:pointer"><i class="ti ti-map-pin"></i> Abandonner ici (visible par les autres joueurs)</button>';
    html += '<button onclick="supprimerItemInventaire(' + idx + ');document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #6a2a20;background:transparent;color:#cc4444;cursor:pointer"><i class="ti ti-x"></i> Supprimer (destruction definitive)</button>';
  }

  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Duree de fraicheur d'un aliment a emporter (Lot 3, 23 aout 2026) : 7x24h REELLES (horloge
// systeme, jamais l'horloge PA/le passage a minuit du jeu -- regle de design validee). Frontiere
// : age <= ce seuil -> consommable normalement ; strictement au-dela -> perime. Constante
// partagee, jamais recalculee ailleurs.
const DUREE_FRAICHEUR_ALIMENT_MS = 7 * 24 * 60 * 60 * 1000;

// Consommation d'un aliment a emporter (Lot 3). Retire l'exemplaire de facon SYNCHRONE, avant
// tout await -- protection naturelle contre un double-clic/double consommation : le second
// appel eventuel trouve soit un index deja disparu (splice), soit le modal deja ferme (aucun
// autre code JS ne peut s'executer entre l'ouverture de la modale et ce retrait, la boucle
// d'evenements ne rend la main qu'apres ce point). Verifie aussi explicitement que l'objet est
// toujours present et de la bonne famille avant d'agir (l'inventaire a pu changer entre
// l'ouverture du detail et le clic). Peremption jamais annoncee avant ce moment (age calcule ici
// pour la premiere fois, jamais expose auparavant) -- voir DUREE_FRAICHEUR_ALIMENT_MS ci-dessus.
async function consommerAliment(idx) {
  const item = state.inventory[idx];
  if (!item || item.familleProduitMarche !== 'aliment') return;

  // Garde-fou horodatage (demande explicite) : un dateAchat absent/invalide ne doit JAMAIS etre
  // traite implicitement comme "frais" -- echec toujours FERME. Refus propre, message technique
  // neutre (jamais un indice de fraicheur), objet CONSERVE en inventaire (aucun retrait tant que
  // la consommation n'a pas reellement pu etre evaluee).
  if (typeof item.dateAchat !== 'number' || !Number.isFinite(item.dateAchat)) {
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast('Consommation impossible', 'Cet objet ne peut pas être consommé pour le moment (donnée technique manquante).', false);
    return;
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  state.inventory.splice(idx, 1);
  renderInventory();

  const age = Date.now() - item.dateAchat;
  const perime = age > DUREE_FRAICHEUR_ALIMENT_MS;

  if (perime) {
    state.pa = Math.max(0, (state.pa || 0) - 1);
    showToast('Intoxication alimentaire', 'Votre ' + item.name + ' avait plus de 7 jours : il était périmé et vous rend malade. -1 PA.', false);
    addJournalEntry('Vous avez consommé "' + item.name + '" — périmé, -1 PA.', 'event-bad');
  } else {
    state.pa = Math.min(PA_MAX, (state.pa || 0) + 1);
    showToast('Casse-croûte', 'Vous avez mangé votre ' + item.name + '. +1 PA.', true, true);
    addJournalEntry('Vous avez consommé "' + item.name + '". +1 PA.', 'event-good');
  }

  updateUI();
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});
}

// =====================
// CARTES POSTALES (Lot 4, 23 aout 2026)
// =====================
// Auditee et reutilisee telle quelle : sbListPersonnages() (repertoire complet des PJ, deja
// utilise par ouvrirRepertoirePJ/composerMailPour -- une carte n'exige pas d'etre dans la meme
// piece que le destinataire, contrairement a "donner", d'ou le choix de ce repertoire plutot que
// sbGetPresencesInRoom). escapeHtmlText (forum.js) : seule fonction d'echappement HTML texte
// brut deja utilisee partout ailleurs dans le jeu (auteur/sujet de mail, titres de forum) --
// reutilisee ici pour auteur/destinataire/message, jamais sanitizeRichHtml (reservee au mail
// riche, autorise des balises : une carte postale est un texte simple, pas un editeur riche).
function ouvrirEcrireCartePostale(idx) {
  const item = state.inventory[idx];
  if (!item || item.familleProduitMarche !== 'carte_postale' || item.etatCarte !== 'vierge') return;

  document.getElementById('carte-postale-modal-title').textContent = 'Écrire et envoyer';
  document.getElementById('carte-postale-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-carte-postale').classList.add('open');

  const esc = typeof escapeHtmlText === 'function' ? escapeHtmlText : (s => String(s == null ? '' : s));
  const myName = state.char?.name || '';

  (typeof sbListPersonnages === 'function' ? sbListPersonnages().catch(() => []) : Promise.resolve([])).then(joueurs => {
    const destinataires = (joueurs || []).filter(j => j.name !== myName);
    const imagePreview = item.imageUrl
      ? '<img src="' + item.imageUrl + '" style="width:100%;max-height:160px;object-fit:cover;border:1px solid #2a2010"/>'
      : '<div style="width:100%;height:100px;border:1px dashed #3a2a10;display:flex;align-items:center;justify-content:center;color:#5a4a20;font-size:.72rem;font-style:italic;gap:.4rem"><i class="ti ti-photo-off" style="font-size:1.3rem"></i> Visuel à venir</div>';

    let html = '<div style="padding:1rem">';
    html += '<div style="margin-bottom:.8rem">';
    html += '<div style="font-size:.68rem;color:#8a6a20;font-family:Bebas Neue,sans-serif;letter-spacing:.1em;margin-bottom:.3rem">RECTO — ' + esc(item.name) + '</div>';
    html += imagePreview;
    html += '</div>';

    html += '<div style="display:flex;border:1px solid #6a5a30;background:#f0ead6;min-height:220px">';
    html += '<div style="flex:1.5;border-right:1px solid #8a7a50;padding:.8rem;display:flex;flex-direction:column">';
    html += '<textarea id="carte-postale-message" maxlength="500" placeholder="Écrivez votre message ici..." style="flex:1;width:100%;background:transparent;border:none;outline:none;resize:none;color:#2a2010;font-family:\'Great Vibes\',cursive;font-size:1.3rem;line-height:1.7"></textarea>';
    html += '<div id="carte-postale-compteur" style="font-family:Crimson Pro,serif;font-size:.65rem;color:#7a6a40;text-align:right;margin-top:.3rem">0/500</div>';
    html += '</div>';
    html += '<div style="flex:1;padding:.8rem;display:flex;flex-direction:column;gap:.5rem;position:relative">';
    html += '<div style="position:absolute;top:.5rem;right:.5rem;width:34px;height:42px;border:1px dashed #8a7a50;display:flex;align-items:center;justify-content:center;color:#8a7a50"><i class="ti ti-stamp" style="font-size:1rem"></i></div>';
    html += '<label style="font-family:Bebas Neue,sans-serif;font-size:.62rem;letter-spacing:.1em;color:#6a5a30;margin-top:1.7rem">Destinataire</label>';
    html += '<select id="carte-postale-destinataire" style="width:100%;background:#fffdf6;border:1px solid #8a7a50;color:#2a2010;padding:.35rem;font-family:Crimson Pro,serif;font-size:.8rem;outline:none"><option value="">— Choisir —</option>';
    destinataires.forEach(j => { html += '<option value="' + esc(j.name) + '">' + esc(j.name) + '</option>'; });
    html += '</select>';
    html += '</div>';
    html += '</div>';

    html += '<div style="margin-top:.8rem;text-align:right">';
    html += '<button id="carte-postale-envoyer-btn" onclick="envoyerCartePostale(' + idx + ')" style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.12em;padding:.5rem 1rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-send"></i> Envoyer</button>';
    html += '</div></div>';

    document.getElementById('carte-postale-body').innerHTML = html;
    const ta = document.getElementById('carte-postale-message');
    const compteur = document.getElementById('carte-postale-compteur');
    if (ta && compteur) ta.addEventListener('input', () => { compteur.textContent = ta.value.length + '/500'; });
  });
}

function fermerModalCartePostale() {
  document.getElementById('modal-carte-postale')?.classList.remove('open');
}

// Envoi (point 9) : strategie fail-closed. Le transfert distant (sbDonnerObjetJoueur, deja
// generique et deja sur pour les dons entre joueurs -- objets_recus, full JSON, lu par
// verifierObjetsRecus) est tente EN PREMIER, avant toute mutation locale. Le retrait de
// l'inventaire de l'expediteur ne survient QUE si ce transfert a reellement reussi : en cas
// d'echec reseau, la carte reste intacte et rien n'a ete cree cote destinataire -- ni perte, ni
// duplication possible dans aucun des deux cas. L'id de l'exemplaire (pose a l'achat,
// commanderProduitCommerce) est conserve tel quel via le spread -- identite unique preservee.
async function envoyerCartePostale(idx) {
  const item = state.inventory[idx];
  if (!item || item.familleProduitMarche !== 'carte_postale' || item.etatCarte !== 'vierge') return;

  const destinataire = document.getElementById('carte-postale-destinataire')?.value?.trim();
  const message = document.getElementById('carte-postale-message')?.value?.trim();
  const moi = state.char?.name || 'Anonyme';

  if (!destinataire) { showToast('Destinataire manquant', 'Choisissez un joueur destinataire.', false); return; }
  if (destinataire === moi) { showToast('Destinataire invalide', 'Vous ne pouvez pas vous envoyer une carte à vous-même.', false); return; }
  if (!message) { showToast('Message vide', 'Écrivez un message avant d\'envoyer.', false); return; }

  const btn = document.getElementById('carte-postale-envoyer-btn');
  if (btn) { btn.disabled = true; btn.style.opacity = '.5'; }

  if (typeof sbDonnerObjetJoueur !== 'function') {
    if (btn) { btn.disabled = false; btn.style.opacity = '1'; }
    showToast('Envoi impossible', 'Le service de courrier est indisponible pour le moment.', false);
    return;
  }

  const carteEcrite = Object.assign({}, item, {
    etatCarte: 'ecrite',
    auteur: moi,
    destinataireInitial: destinataire,
    message: message.slice(0, 500),
    dateEnvoi: typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : new Date().toISOString(),
    bonusDeclenche: false
  });

  const ok = await sbDonnerObjetJoueur(carteEcrite, destinataire, moi).then(() => true).catch(() => false);
  if (!ok) {
    if (btn) { btn.disabled = false; btn.style.opacity = '1'; }
    showToast('Envoi échoué', 'Erreur réseau, la carte n\'a pas pu être envoyée. Réessayez.', false);
    return;
  }

  state.inventory.splice(idx, 1);
  renderInventory();
  fermerModalCartePostale();
  showToast('Carte envoyée', 'Votre carte postale a été envoyée à ' + destinataire + '.', true, true);
  addJournalEntry('Vous avez envoyé une carte postale à ' + destinataire + '.', 'event-info');

  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});
}

// Lecture (points 11/12/13/14/15). Affichage TOUJOURS possible (donnee deja possedee localement,
// aucun appel reseau necessaire pour simplement lire) -- seul le declenchement du bonus depend
// d'un appel reseau, et uniquement pour le lecteur qui est le VRAI destinataire initial (un tiers
// qui recupererait la carte plus tard -- don/abandon/ramassage -- peut lire mais ne declenche
// jamais rien, point 13). echappement systematique via escapeHtmlText avant toute insertion HTML,
// y compris pour un tiers lecteur : meme convention, aucune exception.
async function lireCartePostale(idx) {
  const item = state.inventory[idx];
  if (!item || item.familleProduitMarche !== 'carte_postale' || item.etatCarte !== 'ecrite') return;

  const esc = typeof escapeHtmlText === 'function' ? escapeHtmlText : (s => String(s == null ? '' : s));
  const messageHtml = esc(item.message || '').replace(/\n/g, '<br>');

  document.getElementById('carte-postale-modal-title').textContent = 'Lecture — ' + esc(item.name);
  let html = '<div style="padding:1rem">';
  html += '<div style="display:flex;border:1px solid #6a5a30;background:#f0ead6;min-height:200px">';
  html += '<div style="flex:1.5;border-right:1px solid #8a7a50;padding:.8rem;color:#2a2010;font-family:\'Great Vibes\',cursive;font-size:1.25rem;line-height:1.7">' + messageHtml + '</div>';
  html += '<div style="flex:1;padding:.8rem;color:#2a2010;font-family:Crimson Pro,serif;font-size:.8rem">';
  html += '<div style="margin-bottom:.5rem"><strong>De :</strong> ' + esc(item.auteur || '?') + '</div>';
  html += '<div style="margin-bottom:.5rem"><strong>À :</strong> ' + esc(item.destinataireInitial || '?') + '</div>';
  html += '<div style="color:#6a5a30;font-size:.7rem">' + esc(item.dateEnvoi || '') + '</div>';
  html += '</div></div></div>';
  document.getElementById('carte-postale-body').innerHTML = html;
  document.getElementById('modal-carte-postale').classList.add('open');

  const moi = state.char?.name || '';
  if (item.bonusDeclenche || item.destinataireInitial !== moi) return;

  // Ordre fail-closed : la file distante (impacts_indices_attente, deja generique -- credite
  // l'expediteur, potentiellement hors-ligne, a sa prochaine connexion via
  // recupererImpactsEnAttente, plateau-communication.js) est ecrite EN PREMIER. bonusDeclenche
  // n'est fixe QUE si cette ecriture est CONFIRMEE (valeur non-null retournee, jamais une simple
  // absence d'exception reseau -- sbDeposerImpactIndice/sbInsert renvoient null sur tout echec
  // HTTP, y compris permission/serveur, sans lever d'exception). Un vrai echec (resultat null)
  // laisse le flag a false : une relecture ulterieure retentera proprement. Idempotence du retry
  // lui-meme : sbDeposerImpactIndice utilise resolution=ignore-duplicates (supabase.js) -- un
  // retry apres un accuse de reception reseau perdu (le premier depot avait en realite reussi
  // cote serveur) revient avec un succes HTTP propre au lieu d'une erreur de doublon, donc jamais
  // de carte bloquee definitivement ni de seconde ligne creee pour le meme id.
  if (typeof sbDeposerImpactIndice !== 'function') return;
  const resultat = await sbDeposerImpactIndice({
    id: 'cartepostale-' + item.id,
    victime: item.auteur,
    indice: 'moral_carte_postale',
    delta: 10,
    traite: false
  }).catch(() => null);
  if (!resultat) return;

  item.bonusDeclenche = true;

  // Plafond quotidien LECTEUR (regle definitive de Fred) : au plus une seule occurrence de ce
  // bonus par jour reel (Europe/Paris), toutes cartes/expediteurs confondus. Verifie ici, cote
  // lecteur (necessairement en ligne). Note : le flag bonusDeclenche est deja fixe ci-dessus
  // meme si le plafond du jour est deja atteint -- l'opportunite de LA CARTE est consommee des
  // que le credit expediteur a ete confirme en file, independamment du plafond propre du lecteur
  // ce jour-la (sinon une relecture le meme jour redeposerait un second credit expediteur pour la
  // meme carte : duplication). cartePostaleMoralJour est une colonne PERSISTEE (personnages.
  // carte_postale_moral_jour, supabase.js) -- jamais un state.* implicitement suppose sauvegarde
  // (audit du 23 aout 2026 : un simple state.* nouveau n'est PAS retourne par sbSavePersonnage,
  // qui n'ecrit qu'une liste explicite de colonnes -- sans cette colonne dediee, le plafond etait
  // contournable par un simple refresh).
  const jourDuJour = typeof dateReelleParisStr === 'function' ? dateReelleParisStr() : null;
  if (!state.cartePostaleMoralJour) state.cartePostaleMoralJour = { lecteur: null, expediteur: null };
  if (jourDuJour && state.cartePostaleMoralJour.lecteur !== jourDuJour) {
    state.moral = Math.min(100, Math.max(0, (state.moral || 0) + 10));
    state.cartePostaleMoralJour.lecteur = jourDuJour;
    if (typeof updateUI === 'function') updateUI();
    showToast('Belle surprise', 'Cette carte postale vous touche. +10 Moral.', true, true);
    addJournalEntry('Vous avez lu une carte postale de ' + esc(item.auteur) + '. +10 Moral.', 'event-good');
  }

  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});
}

async function donnerObjetAJoueur(idx) {
  const item = state.inventory[idx];
  const cible = document.getElementById('donner-objet-cible')?.value;
  if (!item || !cible) return;
  // Meme protection que la destruction/l'abandon : ce chemin (fiche detail d'un objet, donner
  // a un vrai joueur present dans la piece) contournerait sinon la restriction "Brigitte
  // Menottes uniquement" deja posee sur confirmerDonObjetPj (plateau-justice-economie.js).
  if (typeof colisSecretProtege === 'function' && colisSecretProtege(item)) {
    showToast('Impossible', 'Ce colis est indispensable à votre mission en cours. Remettez-le à son destinataire avant de vous en séparer.', false);
    return;
  }

  state.inventory.splice(idx, 1);
  renderInventory();
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Objet donné', 'Vous avez donné "' + item.name + '" à ' + cible + '.', true, true);
  addJournalEntry('Vous avez donné "' + item.name + '" à ' + cible + '.', 'event-info');

  // Persistance reelle cote destinataire (corrige un trou : l'objet disparaissait avant
  // sans jamais vraiment arriver chez l'autre joueur — seul le mail etait reel).
  if (typeof sbDonnerObjetJoueur === 'function') {
    await sbDonnerObjetJoueur(item, cible, state.char?.name || 'Anonyme').catch(() => {});
  }

  // Notifier le destinataire par mail reel
  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail(state.char?.name || 'Anonyme', cible, 'Objet reçu',
      (state.char?.name || 'Quelqu\'un') + ' vous a remis : "' + item.name + '". ' + (item.desc || ''), time).catch(() => {});
  }
}

function supprimerItemInventaire(idx) {
  const item = state.inventory[idx];
  if (!item) return;
  if (typeof colisSecretProtege === 'function' && colisSecretProtege(item)) {
    showToast('Impossible', 'Ce colis est indispensable à votre mission en cours. Remettez-le à son destinataire avant de vous en séparer.', false);
    return;
  }
  state.inventory.splice(idx, 1);
  renderInventory();
  showToast('Objet détruit', '"' + item.name + '" a été détruit définitivement. Aucune trace.', true);
  addJournalEntry('Vous avez détruit "' + item.name + '" définitivement.', 'event-info');
}

async function jeterObjetInventaire(idx) {
  const item = state.inventory[idx];
  if (!item) return;
  if (typeof colisSecretProtege === 'function' && colisSecretProtege(item)) {
    showToast('Impossible', 'Ce colis est indispensable à votre mission en cours. Remettez-le à son destinataire avant de vous en séparer.', false);
    return;
  }
  state.inventory.splice(idx, 1);
  renderInventory();
  document.getElementById('modal-postes').classList.remove('open');

  // Persister l'objet dans la piece courante pour qu'un autre PJ puisse le ramasser
  if (typeof sbAbandonnerObjet === 'function' && state.currentBuilding && state.currentRoom) {
    await sbAbandonnerObjet(item, state.country, state.currentCity, state.currentBuilding, state.currentRoom).catch(() => {});
  }
  showToast('Objet abandonné', '"' + item.name + '" laissé sur place. Quelqu\'un pourrait le trouver...', true);
  addJournalEntry('Vous avez abandonné "' + item.name + '" sur place.', 'event-info');
  // Petite chance qu'un PNJ le remarque et que ca se sache (registre comique, sans gravite)
  if (Math.random() < 0.15) {
    addExternalEvent('👀 Un témoin affirme avoir vu ' + (state.char?.name||'quelqu\'un') + ' abandonner un objet suspect.', 'local');
  }
  // Rafraichir immediatement l'affichage maintenant que la sauvegarde est confirmee
  if (typeof chargerObjetsAbandonnesDansPiece === 'function') chargerObjetsAbandonnesDansPiece();
}

// Charge et affiche les objets abandonnes presents dans la piece courante
async function chargerObjetsAbandonnesDansPiece() {
  if (typeof sbGetObjetsAbandonnesDansPiece !== 'function') return;
  if (!state.currentBuilding || !state.currentRoom) return;
  const buildingId = state.currentBuilding, roomId = state.currentRoom;
  try {
    const objets = await sbGetObjetsAbandonnesDansPiece(state.country, state.currentCity, buildingId, roomId);
    if (state.currentBuilding !== buildingId || state.currentRoom !== roomId) return;
    const list = document.getElementById('persons-list');
    if (!list) return;

    // Retirer les anciennes cartes objet avant de reinserer (evite les doublons au rafraichissement periodique)
    list.querySelectorAll('.objet-abandonne-card').forEach(el => el.remove());

    if (objets.length === 0) return;
    const html = objets.map(o =>
      '<div class="person-card objet-abandonne-card" style="border-left:2px solid #8a6a30">' +
      '<div class="person-avatar" style="border-color:#8a6a30"><i class="ti ' + (o.icon||'ti-package') + '" style="font-size:.75rem;color:#a0905a"></i></div>' +
      '<div style="flex:1"><div class="person-name" style="color:#a0905a">' + o.name + '</div>' +
      '<div class="person-role">Objet trouvé ici</div></div>' +
      '<button onclick="ramasserObjetAbandonne(&quot;' + o.id + '&quot;)" style="font-size:.82rem;font-family:Bebas Neue,sans-serif;padding:.15rem .4rem;border:1px solid #4a6a30;background:transparent;color:#6a9a6a;cursor:pointer;flex-shrink:0">Ramasser</button>' +
      '</div>'
    ).join('');
    const empty = list.querySelector('.person-empty');
    if (empty) empty.remove();
    list.insertAdjacentHTML('beforeend', html);
  } catch(e) { console.warn('chargerObjetsAbandonnesDansPiece error', e); }
}

async function ramasserObjetAbandonne(objetId) {
  if (typeof sbGetObjetsAbandonnesDansPiece !== 'function') return;
  try {
    const objets = await sbGetObjetsAbandonnesDansPiece(state.country, state.currentCity, state.currentBuilding, state.currentRoom);
    const objet = objets.find(o => o.id === objetId);
    if (!objet) { showToast('Trop tard', 'Quelqu\'un d\'autre l\'a déjà ramassé.', false); return; }
    addToInventory(objet);
    if (typeof sbRamasserObjetAbandonne === 'function') await sbRamasserObjetAbandonne(objetId).catch(() => {});
    showToast('Objet ramassé', 'Vous récupérez : ' + objet.name + '.', true, true);
    addJournalEntry('Vous avez ramassé "' + objet.name + '" trouvé sur place.', 'event-info');
    chargerObjetsAbandonnesDansPiece();
  } catch(e) { console.warn('ramasserObjetAbandonne error', e); }
}
function toggleSection(panelId, chevronId) {
  const panel = document.getElementById(panelId);
  const chev = document.getElementById(chevronId);
  if (!panel) return;
  const open = panel.style.display !== 'none';
  panel.style.display = open ? 'none' : 'block';
  if (chev) chev.style.transform = open ? '' : 'rotate(90deg)';
}

function ouvrirEditeurSignature() {
  const char = state.char;
  document.getElementById('postes-modal-title').textContent = 'Ma signature';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Apparaîtra automatiquement en bas de tes posts sur le forum (tu pourras décocher au cas par cas). Laisse vide pour utiliser simplement ta devise.</div>';
  html += typeof renderRichEditor === 'function'
    ? renderRichEditor('signature-editor', char?.signatureHtml || '')
    : '<div contenteditable="true" id="signature-editor" style="min-height:100px;padding:.6rem;border:1px solid #2a2010;background:#121005;color:#f0ead6">' + (char?.signatureHtml || '') + '</div>';
  html += '<div style="display:flex;gap:.5rem;margin-top:.8rem">';
  html += '<button onclick="confirmerSignature()" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Enregistrer</button>';
  if (char?.signatureHtml) {
    html += '<button onclick="supprimerSignature()" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #6a2a20;background:transparent;color:#cc6a44;cursor:pointer">Supprimer</button>';
  }
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function refreshApresSignature() {
  const vueSelf = document.getElementById('vue-self');
  if (vueSelf && vueSelf.classList.contains('active')) {
    switchSelfTab('identite', null);
  } else {
    openCharSheet();
  }
}

function confirmerSignature() {
  const el = document.getElementById('signature-editor');
  const raw = el?.innerHTML?.trim() || '';
  const clean = typeof sanitizeRichHtml === 'function' ? sanitizeRichHtml(raw) : raw;
  if (!state.char) return;
  state.char.signatureHtml = clean;
  state.char.signatureBlocks = typeof htmlToBlocks === 'function' ? htmlToBlocks(clean) : [];
  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Signature enregistrée', '', true);
  refreshApresSignature();
}

function supprimerSignature() {
  if (!state.char) return;
  state.char.signatureHtml = null;
  state.char.signatureBlocks = [];
  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Signature supprimée', '', true);
  refreshApresSignature();
}

function toggleInventaire() {
  const panel = document.getElementById('inventaire-panel');
  const chevron = document.getElementById('inv-chevron');
  if (panel.style.display === 'none') {
    panel.style.display = 'block';
    chevron.className = 'ti ti-chevron-down';
  } else {
    panel.style.display = 'none';
    chevron.className = 'ti ti-chevron-right';
  }
}

// =====================


// =====================
// DETAIL OBJET INVENTAIRE
// =====================
function ouvrirDetailObjet(idx) {
  const item = (state.inventory || [])[idx];
  if (!item) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  document.getElementById('postes-modal-title').textContent = item.name;
  let html = '<div style="padding:0">';
  if (item.imageUrl) {
    html += '<div style="width:100%;height:200px;overflow:hidden;background:#0a0805">';
    html += '<img src="' + item.imageUrl + '" style="width:100%;height:100%;object-fit:cover;opacity:.9"/>';
    html += '</div>';
  }
  html += '<div style="padding:1rem">';
  if (item.desc) {
    html += '<div style="font-size:.8rem;color:#a09070;line-height:1.7;font-style:italic;margin-bottom:1rem">' + item.desc + '</div>';
  }
  html += '<div style="font-size:.68rem;color:#9a8a68;margin-bottom:.8rem">';
  html += (item.legal ? '✓ Légal' : '✗ Non enregistré');
  if (item.usageUnique) html += ' · Usage unique';
  html += '</div>';
  html += '<div style="display:flex;gap:.5rem">';
  if (item.type === 'poison') {
    html += '<button onclick="ouvrirModalEmpoisonner();document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #6a2a20;background:transparent;color:#cc4444;cursor:pointer">Utiliser</button>';
  }
  if (item.type === 'medicament') {
    html += '<button onclick="doSesoigner();document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #2a6a2a;background:transparent;color:#4a8a4a;cursor:pointer">Utiliser (+20 PV)</button>';
  }
  if (item.type === 'explosif') {
    html += '<button onclick="doUtiliserExplosifs();document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #6a2a20;background:transparent;color:#cc6a44;cursor:pointer">Utiliser</button>';
  }
  html += '<button onclick="dropItem(' + idx + ');document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #3a2a10;background:transparent;color:#9a8a68;cursor:pointer">Jeter</button>';
  html += '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer">Fermer</button>';
  html += '</div></div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =====================
// REGLES DU JEU (vues)
// =====================

function openRulesView() {
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-rules').classList.add('active');
  renderRulesContent('intro');
}

function closeRulesView() {
  document.getElementById('vue-rules').classList.remove('active');
  if (state.currentBuilding) {
    document.getElementById('vue-batiment').classList.add('active');
  } else {
    document.getElementById('vue-rue').classList.add('active');
  }
}

function renderRulesContent(section) {
  const regle = REGLES[section];
  if (!regle) return;

  document.querySelectorAll('.rules-tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.rules-tab').forEach(t => {
    if (t.dataset.section === section) t.classList.add('active');
  });

  const el = document.getElementById('rules-content');
  if (!el) return;

  // Transformer le contenu texte en HTML riche
  function parseRulesContent(texte) {
    let html = '';
    const lignes = texte.split('\n');
    let inBlock = false;

    for (let i = 0; i < lignes.length; i++) {
      const l = lignes[i];

      // Separateurs ASCII → titre de section
      if (l.match(/^━+$/)) continue;

      // Ligne precedente etait un separateur → titre de bloc
      if (i > 0 && lignes[i-1]?.match(/^━+$/) && !l.match(/^━+$/)) {
        if (inBlock) html += '</div>';
        html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.15em;color:#8a6a20;padding:.5rem 0 .3rem;border-bottom:1px solid #2a2010;margin:.8rem 0 .4rem">' + l + '</div>';
        inBlock = false;
        continue;
      }

      // Ligne en majuscules standalone (type "POSTES ET MANDATS :") → sous-titre
      if (l.match(/^[A-ZÀÂÉÈÊÎÏÔÙÛÜ\s\(\)\/\-:•·]{6,}$/) && l.trim().length > 0 && !l.startsWith('•') && !l.startsWith('·')) {
        html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.12em;color:#7a6a40;margin:.7rem 0 .2rem">' + l + '</div>';
        continue;
      }

      // Lignes avec puce •
      if (l.trim().startsWith('•') || l.trim().startsWith('·')) {
        const texteItem = l.trim().replace(/^[•·]\s*/, '');
        const parts = texteItem.split(' — ');
        let itemHtml = '';
        if (parts.length > 1) {
          itemHtml = '<span style="color:#C9A84C;font-weight:600">' + parts[0] + '</span> — ' + parts.slice(1).join(' — ');
        } else {
          itemHtml = texteItem;
        }
        html += '<div style="display:flex;gap:.5rem;padding:.2rem 0;font-size:.82rem;color:#9a9070;line-height:1.6">';
        html += '<span style="color:#8a6a20;flex-shrink:0">◆</span><span>' + itemHtml + '</span></div>';
        continue;
      }

      // Ligne vide → espacement
      if (l.trim() === '') {
        html += '<div style="height:.4rem"></div>';
        continue;
      }

      // Texte normal
      html += '<div style="font-size:.85rem;color:#a0a080;line-height:1.8;margin:.1rem 0">' + l + '</div>';
    }
    if (inBlock) html += '</div>';
    return html;
  }

  el.innerHTML =
    '<div style="padding:1.5rem;max-width:700px;margin:0 auto">' +
    '<div style="font-family:Playfair Display,serif;font-size:1.4rem;font-style:italic;color:#E8C97A;margin-bottom:1.2rem;padding-bottom:.8rem;border-bottom:2px solid #2a2010">' +
    regle.titre + '</div>' +
    parseRulesContent(regle.contenu) +
    '</div>';
}

