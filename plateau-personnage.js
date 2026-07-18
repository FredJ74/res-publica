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
  document.getElementById('vue-self').classList.remove('active');
  if (state.currentBuilding) {
    document.getElementById('vue-batiment').classList.add('active');
  } else {
    document.getElementById('vue-rue').classList.add('active');
  }
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
    const salaire = (state.poste ? (SALAIRES[state.poste.id] || SALAIRES.default) : SALAIRES.default);

    let html = '<div style="padding:1.2rem;max-width:600px">';

    // Ordre Dormir
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:1rem;margin-bottom:.8rem">';
    html += '<div style="display:flex;align-items:center;gap:.6rem;margin-bottom:.5rem">';
    html += '<i class="ti ti-moon" style="font-size:1.2rem;color:#6a8aaa"></i>';
    html += '<div><div style="font-family:Playfair Display,serif;font-size:.95rem;color:#E8C97A">Dormir</div>';
    html += '<div style="font-size:.72rem;color:#6a5a30"><i class="ti ' + confort.icon + '" style="font-size:.7rem"></i> ' + confort.label + '</div></div>';
    html += '</div>';
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem;line-height:1.5">';
    html += (dejaDormi ? '<span style="color:#9a8a68">Vous avez deja dormi aujourd\'hui.</span>' : 'Versement du salaire : <strong style="color:#C9A84C">+' + salaire.toLocaleString('fr-FR') + ' ' + cur + '</strong>') + '<br>';
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

    const tauxIncendie = Math.max(5, 30 - malusISN);
    html += '<button onclick="doOrder(\'incendier\',3,0,\'Incendier\',\'Vous mettez le feu.\','+tauxIncendie+');closeSelfView()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #4a1a08;background:#100805;color:#aa5a30;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
    html += '<span><i class="ti ti-flame" style="font-size:.85rem"></i> Incendier</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#8a3a10">' + tauxIncendie + '% · 3 PA · ISN:' + (INDICES_NATIONAUX[state.country]?.ISN||30) + '</span></button>';
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
        html += '<button onclick="event.stopPropagation();dropItem(' + i + ')" style="font-size:.85rem;color:#cc5540;background:transparent;border:none;cursor:pointer;padding:.2rem .4rem;flex-shrink:0">Jeter</button>';
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

// Transfere les biens (argent + biens immobiliers) du defunt vers le conjoint survivant,
// avec 33% de droits de succession preleves sur la part recue (50% du patrimoine du defunt)
async function traiterSuccession(defunt, conjointSurvivant) {
  const TAUX_DROITS_SUCCESSION = 0.33;
  let biensHerites = [];

  // 1. Argent EN BANQUE du defunt — transmis a 100%, moins 33% de droits (conjoint recupere 67%)
  const argentBanque = state.banque || 0;
  const droitsArgent = Math.floor(argentBanque * TAUX_DROITS_SUCCESSION);
  const montantHerite = argentBanque - droitsArgent;

  // 1bis. Argent LIQUIDE du defunt — ne suit pas la succession, reste au sol dans la piece (comme un objet abandonne)
  const argentLiquide = state.liquide || 0;
  if (argentLiquide > 0 && typeof sbAbandonnerObjet === 'function' && state.currentBuilding && state.currentRoom) {
    await sbAbandonnerObjet(
      { id: 'liquide-succession-' + Date.now(), name: 'Liasse de billets', icon: 'ti-cash', desc: 'De l\'argent liquide trouvé sur place : ' + argentLiquide.toLocaleString('fr-FR') + ' FR.', type: 'argent_liquide', montant: argentLiquide, legal: true },
      state.country, state.currentCity, state.currentBuilding, state.currentRoom
    ).catch(() => {});
  }

  // 1ter. Objets de l'inventaire du defunt — ne suivent pas non plus la succession, restent au sol
  if (state.inventory?.length > 0 && typeof sbAbandonnerObjet === 'function' && state.currentBuilding && state.currentRoom) {
    for (const objet of state.inventory) {
      await sbAbandonnerObjet(objet, state.country, state.currentCity, state.currentBuilding, state.currentRoom).catch(() => {});
    }
  }

  // 2. Biens immobiliers du defunt — transferer la pleine propriete au conjoint.
  // Droits de 33% calcules sur la MOITIE de la valeur du bien (l'autre moitie appartenait deja au conjoint)
  if (typeof sbGetTousLesBiensDe === 'function' && typeof sbSetTerrainState === 'function') {
    try {
      const biens = await sbGetTousLesBiensDe(defunt);
      for (const bien of biens) {
        let etat = {};
        try { etat = JSON.parse(bien.data); } catch(e) {}
        const valeurBien = (typeof getValeurTotaleBien === 'function') ? getValeurTotaleBien(etat) : 25000;
        const moitieValeur = Math.floor(valeurBien * 0.5);
        const droitsBien = Math.floor(moitieValeur * TAUX_DROITS_SUCCESSION);

        // Le conjoint devient seul proprietaire (les deux parts fusionnent)
        await sbSetTerrainState(bien.country, bien.building_id, {
          ...etat,
          proprietaire: conjointSurvivant,
          coproprietaire: null
        }).catch(() => {});

        biensHerites.push({ buildingId: bien.building_id, valeur: valeurBien, droits: droitsBien });
      }
    } catch(e) { console.warn('Erreur transfert biens succession', e); }
  }

  // 3. Crediter reellement l'argent de banque herite via le systeme de vols_en_attente (reutilise comme
  // mecanisme generique de credit differe a la prochaine connexion du beneficiaire)
  if (montantHerite > 0 && typeof sbDeposerVol === 'function') {
    await sbDeposerVol({
      id: 'succession-' + Date.now(),
      victime: conjointSurvivant, // "victime" au sens technique du champ, ici beneficiaire d'un credit positif
      voleur: 'Succession',
      type_butin: 'argent',
      montant: -montantHerite, // montant negatif = credit (la fonction de reprise fait state.arg -= montant)
      objet_id: null,
      traite: false
    }).catch(() => {});
  }

  // 4. Notifier le conjoint survivant par mail
  if (typeof sbSendMail === 'function') {
    const totalDroitsBiens = biensHerites.reduce((s, b) => s + b.droits, 0);
    let corps = (defunt) + ' a quitté ce monde. En tant que conjoint(e) survivant(e), vous héritez de :<br><br>';
    corps += '- ' + montantHerite.toLocaleString('fr-FR') + ' FR de banque (après ' + droitsArgent.toLocaleString('fr-FR') + ' FR de droits de succession)<br>';
    if (biensHerites.length > 0) {
      corps += '- ' + biensHerites.length + ' bien(s) immobilier(s), désormais en pleine propriété<br>';
      corps += '- Droits de succession sur les biens : ' + totalDroitsBiens.toLocaleString('fr-FR') + ' FR (à régler séparément)<br>';
    }
    if (argentLiquide > 0) {
      corps += '- Note : ' + argentLiquide.toLocaleString('fr-FR') + ' FR en liquide ont été laissés sur place, à récupérer physiquement si quelqu\'un ne les a pas pris avant vous.<br>';
    }
    const time = 'Succession';
    await sbSendMail('Notaire', conjointSurvivant, 'Succession — ' + defunt, corps, time).catch(() => {});
  }

  addExternalEvent('⚱️ ' + defunt + ' a quitté ce monde. Succession réglée avec ' + conjointSurvivant + '.', 'local');
}

async function confirmerDestructionPersonnage() {
  const saisie = document.getElementById('confirm-destroy-input')?.value?.trim();
  const nom = state.char?.name;
  if (!nom || saisie !== nom) {
    showToast('Confirmation incorrecte', 'Le nom saisi ne correspond pas.', false);
    return;
  }

  document.getElementById('modal-postes').classList.remove('open');

  // Si le joueur est marie, traiter la succession AVANT de supprimer le personnage
  if (typeof sbGetMariageActif === 'function') {
    try {
      const mariage = await sbGetMariageActif(nom);
      if (mariage) {
        const conjoint = mariage.conjoint1 === nom ? mariage.conjoint2 : mariage.conjoint1;
        await traiterSuccession(nom, conjoint);
        if (typeof sbDissoudreMariage === 'function') {
          await sbDissoudreMariage(mariage.id).catch(() => {});
        }
      }
    } catch(e) { console.warn('Erreur traitement succession', e); }
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

  // Prélever le coût selon l'hôtel
  const coutsDormir = {
    'hotel-republica': 80, 'hotel-port': 60, 'hotel-mineur': 40,
    'hotel-narco': 80, 'hotel-soviet': 60, 'hotel-khalija': 80
  };
  const coutDormir = coutsDormir[state.currentBuilding] || 0;
  const curD = COUNTRIES[state.country]?.cur || 'FR';
  if (coutDormir > 0 && state.arg < coutDormir) {
    showToast('Fonds insuffisants', coutDormir + ' ' + curD + ' requis pour la nuit.', false);
    return;
  }
  if (coutDormir > 0) state.arg -= coutDormir;

  const b = state.currentBuilding ? BUILDINGS[state.currentBuilding] : null;
  const confortMap = {
    'hotel-republica':    { moral: 5, paBonus: 5 },
    'hotel-port':         { moral: 3, paBonus: 2 },
    'hotel-mineur':       { moral: 3, paBonus: 2 },
    'palais-presidentiel':{ moral: 8, paBonus: 8 }
  };
  const confort = confortMap[state.currentBuilding] || { moral: 1, paBonus: 0 };

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
  const salaire = state.poste ? (SALAIRES[state.poste.id] || SALAIRES.default) : SALAIRES.default;
  state.arg += salaire;
  state.liquide += Math.floor(salaire * 0.3);
  state.banque += Math.ceil(salaire * 0.7);
  state.moral = Math.min(100, state.moral + confort.moral);

  // Restauration reelle des PA — corrige un bug de fond ou la recuperation n'etait jamais appliquee
  const PA_BASE_NORMAL = 12;
  let plafondPA = PA_BASE_NORMAL + (confort.paBonus || 0);
  let detentionQHS = null;
  if (typeof sbGet === 'function' && state.char?.name) {
    const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(state.char.name)}&select=detention_qhs`).catch(() => []);
    detentionQHS = rows?.[0]?.detention_qhs ? (typeof rows[0].detention_qhs === 'string' ? JSON.parse(rows[0].detention_qhs) : rows[0].detention_qhs) : null;
  }
  if (detentionQHS?.enQHS) {
    plafondPA = detentionQHS.paLimite1Jour ? 1 : 3;
    if (detentionQHS.paLimite1Jour) {
      detentionQHS.paLimite1Jour = false;
      if (typeof sbUpdate === 'function') await sbUpdate('personnages', `name=eq.${encodeURIComponent(state.char.name)}`, { detention_qhs: JSON.stringify(detentionQHS) }).catch(() => {});
    }
  }
  state.pa = plafondPA;
  state.paMax = plafondPA;

  updateUI();
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';
  showToast('Bonne nuit !', 'Salaire verse : +' + salaire.toLocaleString('fr-FR') + ' ' + cur + ' · +' + confort.moral + ' Moral', true, true);
  addJournalEntry('Vous dormez. Salaire verse : +' + salaire.toLocaleString('fr-FR') + ' ' + cur, 'event-good');

  // Payer les loyers des locations actives
  payerLocations();
  // Payer les escorts actives
  payerEscorts();
  payerEmployes();
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
  if (typeof verifierAutoValidationManifestations === 'function') verifierAutoValidationManifestations(state.country);

  // Rafraichir la vue
  switchSelfTab('actions', null);
  return true;
}

function doTransfertCliniquePrivee() {
  if (!state.hospitalisation) { showToast('Indisponible', 'Vous n\'êtes pas hospitalisé(e).', false); return; }
  if (state.hospitalisation.lieu === 'clinique') { showToast('Déjà en clinique privée', '', false); return; }
  if (state.arg < 1000) { showToast('Fonds insuffisants', '1000 FR requis pour le transfert.', false); return; }
  state.arg -= 1000;
  state.hospitalisation.lieu = 'clinique';
  updateUI();
  if (typeof enterBuilding === 'function') enterBuilding('clinique-privee', true);
  if (typeof enterRoom === 'function') enterRoom('clinique-privee', 'reception_clinique', null);
  showToast('Transfert effectué', 'Vous êtes désormais pris(e) en charge en clinique privée. Convalescence plus rapide.', true, true);
  addJournalEntry('Transfert vers une clinique privée (-1000 FR).', 'event-good');
}

function doCentreAntiPoison() {
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
  if (state.arg < cout) { showToast('Fonds insuffisants', cout + ' FR requis.', false); return; }

  state.centreAntiPoisonToday.tentatives++;
  state.arg -= cout;

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

function doReserverChambreHotel() {
  const confortMap = {
    'hotel-republica': { moral: 5, paBonus: 5 },
    'hotel-port':      { moral: 3, paBonus: 2 },
    'hotel-mineur':    { moral: 3, paBonus: 2 },
    'palais-presidentiel': { moral: 8, paBonus: 8 }
  };
  const bonus = confortMap[state.currentBuilding] || { moral: 2, paBonus: 1 };
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const ordre = room?.orders?.find(o => o.fn === 'reserver_chambre_hotel');
  const cout = ordre?.cost || 60;
  if (state.arg < cout) { showToast('Fonds insuffisants', cout + ' FR requis.', false); return; }
  state.arg -= cout;
  state.reservationHotel = { buildingId: state.currentBuilding, bonus };
  updateUI();
  showToast('Chambre reservee', 'Vous obtiendrez un bonus de +' + bonus.paBonus + ' PA et +' + bonus.moral + ' Moral en passant l\'ordre Dormir <strong>dans cette chambre</strong>.', true, true);
  addJournalEntry('Vous avez reserve une chambre d\'hotel. Vous obtiendrez un bonus de ' + bonus.paBonus + ' PA + ' + bonus.moral + ' moral en passant l\'ordre dormir <strong>dans cette chambre</strong>.', 'event-good');
}

async function doDormirChambre() {
  const reservation = state.reservationHotel;
  if (!reservation || reservation.buildingId !== state.currentBuilding) {
    showToast('Aucune reservation', 'Vous devez d\'abord reserver une chambre a l\'accueil.', false);
    return;
  }
  const reussi = await doDormir();
  if (reussi) {
    state.pa = (state.pa || 0) + reservation.bonus.paBonus;
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

  if (joueursPresents.length > 0) {
    html += '<select id="donner-objet-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none">';
    joueursPresents.forEach(p => { html += '<option value="' + p.name + '">' + p.name + '</option>'; });
    html += '</select>';
    html += '<button onclick="donnerObjetAJoueur(' + idx + ')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #4a6aaa;background:transparent;color:#6a8aca;cursor:pointer"><i class="ti ti-gift"></i> Donner a ce joueur</button>';
  }

  html += '<button onclick="jeterObjetInventaire(' + idx + ')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #8a6a30;background:transparent;color:#a0905a;cursor:pointer"><i class="ti ti-map-pin"></i> Abandonner ici (visible par les autres joueurs)</button>';
  html += '<button onclick="supprimerItemInventaire(' + idx + ');document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .7rem;border:1px solid #6a2a20;background:transparent;color:#cc4444;cursor:pointer"><i class="ti ti-x"></i> Supprimer (destruction definitive)</button>';

  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
}

function donnerObjetAJoueur(idx) {
  const item = state.inventory[idx];
  const cible = document.getElementById('donner-objet-cible')?.value;
  if (!item || !cible) return;

  state.inventory.splice(idx, 1);
  renderInventory();
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Objet donné', 'Vous avez donné "' + item.name + '" à ' + cible + '.', true, true);
  addJournalEntry('Vous avez donné "' + item.name + '" à ' + cible + '.', 'event-info');

  // Notifier le destinataire par mail reel
  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail(state.char?.name || 'Anonyme', cible, 'Objet reçu',
      (state.char?.name || 'Quelqu\'un') + ' vous a remis : "' + item.name + '". ' + (item.desc || ''), time).catch(() => {});
  }
}

async function jeterObjetInventaire(idx) {
  const item = state.inventory[idx];
  if (!item) return;
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

