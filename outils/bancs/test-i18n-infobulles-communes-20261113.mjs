// Descriptions d'ordres communes à la Républia et à Sovarka (13/11/2026) : 253 textes, neuf langues,
// même résolveur que les 113 textes propres à Sovarka (RPSovarkaInfobullesI18n), dans les deux pays.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const R = new URL('../../', import.meta.url);
const lire = f => readFileSync(new URL(f, R), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
const fnSource = (src, nom) => { const i = src.indexOf('function ' + nom + '('); const j = src.indexOf('\n}', i); return src.slice(i, j + 2); };

function charger(pays, langue, { communes = true, extra = {} } = {}) {
  const ctx = { RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => langue }, ...extra };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext('var state = { country: ' + JSON.stringify(pays) + ' };', ctx);
  vm.runInContext(fnSource(lire('plateau-politique.js'), 'deviseDansTexte'), ctx);
  vm.runInContext(fnSource(lire('data.js'), 'montantDansTexte'), ctx);
  if (communes) vm.runInContext(lire('i18n/infobulles-communes-resources.js'), ctx);
  vm.runInContext(lire('i18n/sovarka-infobulles-resources.js'), ctx);
  return ctx;
}
const I = (pays, langue, o) => charger(pays, langue, o).RPSovarkaInfobullesI18n;

// Descriptions réellement affichées : même fusion que l'écran (ordresDeclaresDeLaPiece : gabarit moins
// exclusions, plus ordres de la surcharge), hors pièces exclues. Corrigé le 13/11 (Héros du Travail) :
// l'ancien modèle laissait la surcharge remplacer le gabarit et sous-comptait 54 descriptions communes.
function descsParPays() {
  const ctx = { console, state: { country: 'soviet' }, document: { getElementById: () => null, addEventListener() {}, querySelector: () => null }, localStorage: { getItem: () => null } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js').replace(/^const (WORLD|BUILDINGS) =/mg, 'var $1 ='), ctx);
  const parPays = p => { const d = new Set();
    for (const city of Object.values(ctx.WORLD[p] || {})) for (const b of city.buildings || []) {
      const c = city.buildingContext?.[b] || {};
      for (const [r, room] of Object.entries({ ...(ctx.BUILDINGS[b]?.rooms || {}), ...(c.roomsExtra || {}) })) {
        if (c.roomsExclues?.includes(r)) continue;
        const ov = c.roomOverrides?.[r] || {};
        for (const o of [...ctx.ordresDeclaresDeLaPiece(room, c, r), ...(ov.ordersExtra || [])]) if (o?.desc) d.add(o.desc);
      } }
    return d; };
  return { sov: parPays('soviet'), rep: parPays('republic') };
}

test('inventaire : 237 descriptions communes affichées après isolation du goulag, aucune nouvelle hors catalogue', t => {
  const { sov, rep } = descsParPays();
  const communesJeu = [...sov].filter(d => rep.has(d));
  const cat = [...I('republic', 'fr').communes].map(l => l[0]);
  // Mesuré le 13/11 avec la fusion réelle : 246 descriptions communes affichées (exclusions des ordres propres à Républia dans les ministères de Sovarka), dont 2 pas encore au
  // catalogue (trou antérieur, chantier de traduction à venir, consigné dans RELAIS.md). Le plafond
  // autorise la seule description de gestion de caserne rétablie à Sovarka ;
  // elle doit rejoindre le catalogue partagé dans le prochain lot i18n.
  assert.equal(communesJeu.length, 230, // +1 le 25/11 en fin de soirée (Fred, 1.8) : « Visiter un détenu » aussi au commissariat, sa description devient commune ; -1 le 23/11 (bloc 4, point 32) : « +6 INF +5 DIS +1 POP. » (location des bureaux de Krasnov) disparaît, les bureaux se demandent à la mairie ; -1 le 23/11 (mission Novomirsk, point 5) : « Taxi vers le QHS » masqué en Sovarka tant que le goulag est fermé, sa description n'y est plus affichée ; -2 le 22/11 au soir (Santé, Suites, point 1) : « boissons et snacks » du bar du Grand Hôtel et des buvettes de stade devient « en-cas » en Républia et « zakouski » en Sovarka, ces deux descriptions ne sont plus communes ; -6 le 22/11 : refonte des informateurs (« Écouter le barman / la serveuse », « Recruter un informateur », ordres d'informateurs de la loge retirés) ; -1 le 21/11 : boycott des supporters retiré en Sovarka (lot de Krasnov, point 6), sa description n'est plus affichée qu'en Républia ; +1 le 19/11 : boutique climat (lot 5) ; +1 le 18/11 : furet renifleur (maladies lot 2c) ; +1 le 18/11 : pharmacie de Républia (maladies lot 1).  Le 16/11 : 245 -> 237 ; les ordres hérités du QHS de Républia disparaissent du goulag de Sovarka (entrée, cellules et salles républicaines), sans retirer leurs traductions encore nécessaires en Républia.
    'nombre de descriptions communes affichées après exclusions ministérielles spécifiques à Sovarka');
  const manquantes = communesJeu.filter(d => !cat.includes(d));
  t.diagnostic('Descriptions communes manquantes : ' + JSON.stringify(manquantes));
  // +1 le 15/11 : « +6 INF +5 DIS +1 POP. » (location d'un des quatre bureaux de Krasnov, texte du catalogue de Républia, à passer au catalogue commun par le lot i18n).
  // +1 le 20/11 : « Suivre une formation » ouvert (criminalité lot 9), nouvelle description française à traduire par Codex.
  // +3 le 22/11 (Santé, consommation) : service d'étage (plat du jour), soins accélérés (+25) et soins sans trace (+15), à traduire par Codex.
  // +2 le 22/11 au soir (Santé, Suites, point 3) : repas de l'hôpital (+4 Santé) et de la clinique (+5 Santé), à traduire par Codex.
  // +15 le 25/11 au soir (mission du soir, bloc 1A, audit des chances) : descriptions alignées sur le serveur (rumeur, piège,
  // propagande, fuite, enquête, défense, soins sans trace, rébellion, évasion, campagne de sécurité ×2, contestation, trois
  // fraudes électorales, corruption du douanier), à traduire par Codex (liste dans docs/soir/BLOC-1A.md).
  // +3 le 25/11 au soir (mission du soir, 1.2) : corrompre un journaliste, fabriquer un scandale, frapper à la loge, à traduire par Codex.
  // +2 le 25/11 en fin de soirée (agent B) : visiter un détenu (désormais commune) et censurer un média (Sovarka), à traduire par Codex.
  assert.ok(manquantes.length <= 30, 'nouvelles communes absentes du catalogue');
  // Français strictement identique : chaque texte du catalogue est une description exacte de data.js,
  // affichée dans au moins un pays (avec la fusion réelle, quelques-unes ne sont plus visibles qu'en Républia,
  // l'exclusion de Sovarka étant désormais prise en compte ; leur traduction y reste utile).
  // Ancienne description de la récolte (avant le 16/11) : gardée à sa place, les bancs historiques figent les lignes livrées.
  // « Falsifier un procès-verbal » (QHS) supprimé le 20/11 (criminalité lot 7) : sa ligne livrée reste au catalogue.
  // « Suivre une formation » ouvert le 20/11 (criminalité lot 9) : l'ancienne infobulle « Bientôt disponible » reste au catalogue.
  const HISTORIQUES = ['Recolter une matiere premiere locale. Maximum 2 fois par jour.', 'Modifier les declarations. Tres risque.',
    'Bientôt disponible : cet ordre permettra d\'acquérir une seconde carrière.',
    // Refonte des informateurs (22/11/2026) : ordres retirés, lignes livrées gardées au catalogue.
    'Le barman entend tout. Revele une rumeur vraie ou generee selon le contexte.',
    "1 PA, 150 FR puis 150 FR/jour. Un PNJ (PER 12-18) rejoint votre groupe en permanence tant que vous le payez : sa PER s'ajoute a celle du groupe pour les recherches, enquetes et localisations.",
    '400 FR/jour. Localisation précise, intentions vote, voyages récents.', '1500 FR/jour. Confessions, transactions, ordres passés 24h.',
    'Obtenir une information de votre taupe niveau 4.', 'Voir et gérer vos informateurs actifs.',
    // Santé (consommation, 22/11/2026) : anciennes valeurs en dur, lignes livrées gardées au catalogue.
    '+40 Sante immediatement.', '+30 Sante. Aucune trace medicale.', 'Dejeuner servi en chambre. +10 Sante, +1 Moral immediats. +1 PA au prochain Dormir.',
    // Santé, Suites (22/11/2026 au soir) : « snacks » retiré, repas de l'hôpital et de la clinique avec leur Santé ; lignes livrées gardées.
    'Préparer boissons et snacks pour le service (consomme les matières en stock, rémunéré en FR).',
    'Preparer bieres, boissons et snacks pour le service (consomme le stock, remunere en FR).',
    'Une fois par jour, servi au chevet. +4 PA à votre prochain sommeil.',
    'Réservé aux patients hospitalisés, une fois par jour. +2 PA à votre prochain sommeil.',
    // « Subtiliser des explosifs » (mission de nuit du 25/11/2026, bloc 3) : nouvelle description fidèle au serveur ;
    // l'ancienne ligne livrée reste au catalogue jusqu'à la traduction de la nouvelle par Codex.
    "Voler un explosif dans le stock de la caserne. 35% de base, module par la discretion, l'ISN et la reputation criminelle. Echec detecte : QHS.",
    // Audit des chances (mission du soir, 25/11/2026, bloc 1A) : descriptions alignées sur le serveur ; les lignes livrées
    // restent au catalogue jusqu'à la traduction des nouvelles par Codex.
    "Piéger un adversaire politique. Risque de scandale.",
    "Influence massive de l'opinion publique. +POP important.",
    "Faire fuiter un document secret.",
    "Procedure simplifiee, reservee aux faits les plus legers (2 jours de reference au plus, hors crime). Un avocat commis d'office plaide pour vous ; le tribunal tranche sur le champ. Le jugement est definitif et sans appel.",
    "Reserve aux emprisonnes. Defi bruyant aux gardiens : succes = +DIS mais peine allongee, echec = transfert au QHS. Endommage les grilles dans tous les cas.",
    "Tres risque, une tentative par jour. Succes : liberte. Echec : transferement en prison.",
    "Rediger une rumeur visant un PJ, une organisation, un local, un gouvernement ou un pays. Succes (75%) : effet selon la cible. Echec : retour de bâton limite + risque de detection.",
    "Dans les 24h suivant la proclamation, pour tout electeur habilite pour ce scrutin. Peut reveler une fraude.",
    "Reserve au maire ou a l'adjoint au maire sortant de cette ville. Ajoute 1 a 10 voix frauduleuses a un candidat.",
    "Pendant les 24h de vote, pour tout electeur inscrit sur ce scrutin. Ajoute 1 a 3 voix frauduleuses.",
    "Reserve au commissaire ou au juge. Ajoute ou retire 1 a 10 voix a un candidat.",
    "Éviter le contrôle. DUP/10 + INF/10. +20% zone transport.",
    "Rendre visite a un detenu du QHS. Necessite autorisation.",
    "Taux tres faible. Consequence severe si echec.",
    "Tres difficile. Obtenir des privileges ou informations.",
    "Quasi impossible, une tentative par jour. Echec = peine aggravee de 7 jours.",
    "+10 ISN local. Preleve sur budget mairie.",
    "Influencer massivement l'opinion publique. +POP.",
    "+10 ISN local. Deploiement de forces de l'ordre supplementaires. Preleve sur budget mairie.",
    "Cibler un citoyen, un club sportif, une entreprise ou une organisation. Coute a la caisse du gouvernement.",
    // Fin de soirée du 25/11 (agent B) : censure réécrite (effet en Sovarka) ; ligne livrée gardée jusqu'à la traduction.
    "Interdire un organe de presse. -liberte +controle.",
    // Mission du soir (25/11/2026, 1.2) : descriptions alignées sur le serveur ; anciennes lignes livrées gardées.
    "Accuser publiquement un PJ, sous votre nom. La rédaction accepte ou refuse (35 % + 15 si carrière presse, ou + 10 si ministre de l'Information, moins le malus de sécurité intérieure). Acceptation : 3 PA et 800 FR pour La Tribune, la cible perd 15 POP et 15 INF. Refus : rien n'est prélevé. Une tentative par jour.",
    "Choisir une affaire judiciaire du jour puis demander à la rédaction de l'étouffer ou d'en publier un angle favorable. Accord : 2 PA et 500 FR pour La Tribune. Refus : rien n'est prélevé, mais la démarche laisse une trace. Le dossier judiciaire n'est jamais modifié.",
    "Frapper a la porte et demander une audience. Reussite a 95%.",
    "Contre-lobbying preventif visant une cible (PJ, organisation, local, gouvernement ou pays) : pendant 7 jours, un futur \"Placer un article favorable\" contre cette meme cible devient beaucoup plus difficile (base 10% au lieu de 75%). N'affecte jamais l'actualite reelle (scandales, condamnations, elections...). Reussite (70% + modificateurs) : 1000 FR preleves. Echec : aucun frais.",
    "Choisir une cible (PJ, organisation, local, gouvernement ou pays) et indiquer le sujet/l'angle souhaite : la redaction redige elle-meme un veritable article favorable, vous n'apparaissez jamais comme commanditaire. Reussite (75% + modificateurs) : 500 FR preleves. Echec : la redaction refuse, aucun frais.",
    "Choisir une cible (PJ, organisation, local, gouvernement ou pays) et indiquer le sujet/l'angle souhaite : la redaction redige elle-meme un veritable article favorable, vous n'apparaissez jamais comme commanditaire. Reussite (75% + modificateurs) : 500 FR preleves, article integre a une prochaine edition de La Tribune. Echec : la redaction refuse, aucun frais."];
  assert.deepEqual(cat.filter(d => !sov.has(d) && !rep.has(d) && !HISTORIQUES.includes(d)), [], 'textes du catalogue introuvables tels quels');
  assert.equal(new Set(cat).size, cat.length);
});

test('257 lignes de neuf colonnes non vides, sans guillemet droit ni balise, toutes traduites', () => {
  const lignes = I('soviet', 'fr').communes;
  assert.equal(lignes.length, 259); // +1 le 19/11 : boutique climat ; +1 le 18/11 : furet renifleur ; +1 le 18/11 : pharmacie de Républia ; +2 le 16/11 : récolte (nouvelle description) et régulation de la production ; +1 le 14/11 : Dormir dans la chambre d’hôpital
  for (const l of lignes) {
    assert.equal(l.length, 9, l[0]);
    for (const v of l) assert.ok(v.trim(), l[0]);
    for (const v of l.slice(1)) { assert.ok(!/["<>]/.test(v), v); assert.notEqual(v, l[0], 'non traduit : ' + l[0]); }
  }
});

test('nombres, pourcentages, devises et sigles conservés dans les huit traductions', () => {
  for (const l of I('soviet', 'fr').communes) {
    const nombres = l[0].match(/\d+(?:[  ]\d{3})*/g) || [];
    for (const v of l.slice(1)) {
      for (const n of nombres) assert.ok(v.includes(n), JSON.stringify(n) + ' manquant : ' + l[0] + ' → ' + v);
      assert.equal((v.match(/%/g) || []).length, (l[0].match(/%/g) || []).length, '% : ' + l[0] + ' → ' + v);
      for (const s of ['FR', 'PSK', 'POP', 'INF', 'DIS', 'IP', 'PER', 'CHA', 'DUP', 'ENT', 'MG', 'QHS', 'ISN', 'HP']) {
        const re = new RegExp('\\b' + s + '\\b', 'g');
        assert.equal((v.match(re) || []).length, (l[0].match(re) || []).length, s + ' : ' + l[0] + ' → ' + v);
      }
      for (const nom of ['Luthécia', 'Republia', 'La Tribune']) if (l[0].includes(nom)) assert.ok(v.includes(nom), nom + ' : ' + v);
    }
  }
});

test('traduit dans les deux pays, jamais en français, texte inconnu intact', () => {
  const fr = "Voir ce qui est disponible au bar et commander.";
  for (const pays of ['republic', 'soviet']) {
    assert.equal(I(pays, 'en').desc(fr), 'See what is available at the bar and order.');
    assert.equal(I(pays, 'fr').desc(fr), fr);
    assert.equal(I(pays, 'ru').desc('Texte inconnu'), 'Texte inconnu');
  }
  assert.match(I('republic', 'ar').desc(fr), /البار/);
  assert.match(I('soviet', 'zh-TW').desc(fr), /吧台/);
});

test('113 textes propres à Sovarka inchangés et prioritaires ; restent limités à Sovarka', () => {
  const avec = I('soviet', 'en'), sans = I('soviet', 'en', { communes: false });
  assert.equal(avec.lignes.length, 144); // +1 le 19/11 : bocal de graisse (lot 4) ; -1 le 18/11 : « Médicaments vendus au comptoir. » passe au catalogue commun (pharmacie de Républia) ; +5 le 18/11 : bureau du syndicat national ; +1 le 18/11 : magasin du kolkhoze de Starovka ; +1 le 18/11 : dîner d'affaires du restaurant de Starovka ; +1 le 17/11 : dîner de l'Hôtel des Voyageurs de Starovka ; +2 le 16/11 : administration portuaire de Starovka ; +3 le 15/11 au soir : usines d'État de Sovarka (carburant, dérivés, alcool) ; +2 le 14/11 : Tabac/Presse de Krasnov ; +2 le 14/11 : salle électorale de la mairie de Krasnov ; -1 le 14/11 : « Dormir » de la chambre devenu commun ; +1 le 14/11 : « Retrouver son chemin » (forêt de Krasnov) ; +4 le 14/11 : kolkhoze (légumes et œufs reformulés, anciennes formulations gardées ; traite ; caisse) ; +1 boutique de l’Étoile Rouge
  assert.equal(JSON.stringify(avec.lignes), JSON.stringify(sans.lignes));
  for (const l of avec.lignes) assert.equal(avec.desc(l[0]), sans.desc(l[0]));
  const propre = 'Voir les présidents qui ont marqué Sovarka.';
  assert.equal(I('republic', 'en').desc(propre), propre);
  // Aucun texte n'est à la fois propre à Sovarka et commun.
  const communs = new Set(avec.communes.map(l => l[0]));
  assert.equal([...avec.textes].filter(t => communs.has(t)).length, 0);
  // Sans le fichier des communes, le comportement d'avant est intact.
  assert.equal(sans.desc("Voir ce qui est disponible au bar et commander."), "Voir ce qui est disponible au bar et commander.");
  assert.equal(sans.communes.length, 0);
});

test('devise et tarif national : FR en Républia, PSK et tarif réappliqués en Sovarka', () => {
  const src = { desc: '75 FR. 2 PA. Transport intra-empire vers une autre ville.', cost: 75, pa: 2 };
  assert.equal(I('republic', 'en').descOrdre(src, { desc: src.desc }, 'FR', null), '75 FR. 2 AP. Intra-empire transport to another city.');
  const ctx = charger('soviet', 'de');
  const affiche = { desc: ctx.montantDansTexte(ctx.deviseDansTexte(src.desc, 'PSK'), 75, 40) };
  assert.equal(ctx.RPSovarkaInfobullesI18n.descOrdre(src, affiche, 'PSK', { cost: 40, pa: 2 }), '40 PSK. 2 AP. Transport innerhalb des Imperiums in eine andere Stadt.');
  assert.equal(I('soviet', 'fr').descOrdre(src, affiche, 'PSK', { cost: 40, pa: 2 }), affiche.desc);
});

test('infobulle complète et repeinte au changement de langue, en Républia, sans requête', () => {
  let langue = 'fr';
  const appels = [];
  const spec = { d: 'Voir ce qui est disponible au bar et commander.', a: 'Voir ce qui est disponible au bar et commander.', c: 0, p: 0, v: 'FR', n: null, g: [['+5', 'sante']], r: [], s: 100 };
  const badge = { textContent: '+5 Sante' };
  const b = { attrs: { 'data-rp-tip': encodeURIComponent(JSON.stringify(spec)), title: 'x' },
    getAttribute(n) { return this.attrs[n]; }, setAttribute(n, v) { appels.push(n); this.attrs[n] = v; }, querySelector: () => badge };
  const reseau = [];
  const ctx = charger('republic', 'fr', { extra: { document: { querySelectorAll: () => [b] }, RPPlateauI18n: { language: () => langue },
    fetch: (...a) => { reseau.push(a); return Promise.reject(Error('interdit')); } } });
  langue = 'es';
  for (const cb of ctx.RP_I18N_CHANGE_CALLBACKS) cb('es');
  assert.equal(b.attrs.title, 'Ver lo que hay disponible en la barra y pedir. | Ganancia: +5 Salud | Éxito: 100%');
  assert.equal(badge.textContent, '+5 Salud');
  assert.deepEqual([...new Set(appels)], ['title']);
  assert.deepEqual(reseau, []);
});

test('branchements : catalogue chargé avant le résolveur, audit éditorial, aucun changement de plateau-politique.js', () => {
  const html = lire('plateau.html');
  const a = html.indexOf('i18n/infobulles-communes-resources.js'), b = html.indexOf('i18n/sovarka-infobulles-resources.js'), c = html.indexOf('i18n/plateau-init.js');
  assert.ok(a > 0 && b > a && c > b);
  assert.ok(lire('outils/audits/audit-i18n-editorial.cjs').includes("'infobulles-communes-resources.js'"));
  const cat = lire('i18n/infobulles-communes-resources.js');
  assert.doesNotMatch(cat, /\bfunction\s*\(|=>|fetch\(|sbRpc|\bstate\.[a-z]/);
});
