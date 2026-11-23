// Mission Novomirsk, bloc 3 (Fred, 23/11/2026 ; GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 24 à 28).
// Lancement : node --test outils/bancs/test-bloc3-pnj-sovarka-20261123.mjs
//  24 — « Acheter une information » n'est plus un ordre de pièce : on clique sur le PNJ (R4 : aucun renvoi vers l'ordre).
//  25 — L'habitué du Bar Sever : PNJ visible et social, verre du jour décidé par le serveur, conclusion exacte, ordre
//       « Offrir un verre à l'habitué » supprimé partout.
//  26 — Tout PNJ visible de Sovarka a une fiche de dialogue (relevé calculé sur le vrai data.js, jamais recopié).
//  27 — Ignat Lykov fonctionnaire à la retraite, jamais trappeur ; Kouzma Lapchine batiouchka, plus sonneur de cloches.
//  28 — Matveï Rybakov, référent chasse et bûcheronnage, frère aîné de Prokhor Rybakov.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import { TOUS_PROFILS } from '../../api/_pnj-profils.js';
import { SCENES_PNJ } from '../../api/_pnj-scenes-generes.js';
import { NON_FONCTIONNAIRES } from '../../api/_pnj-fonctionnaires-sovarka.js';

const R = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const MIGRATION = 'migrations/20261123210000_bloc3_pnj_habitue_sociaux.sql';

// Les PNJ que voit un joueur dans chaque pièce de Sovarka, par la même résolution que l'écran (getBuildingContext,
// personnesNormalesDeLaPiece) et le même identifiant de fiche que le dialogue (profilServeurDuPnj).
function extraire(fichier, debut, mot = 'function ') {
  const s = lire(fichier), i = s.indexOf(mot + debut);
  if (i < 0) throw new Error(debut + ' introuvable dans ' + fichier);
  let j = s.indexOf('{', i), p = 0;
  for (; j < s.length; j++) { if (s[j] === '{') p++; else if (s[j] === '}' && --p === 0) break; }
  return s.slice(i, j + 1);
}
function pnjDeSovarka() {
  const ctx = vm.createContext({ console, state: { country: 'soviet', currentCity: 'capitale' } });
  vm.runInContext(lire('data.js'), ctx);
  vm.runInContext(extraire('plateau-navigation.js', 'getBuildingContext'), ctx);
  vm.runInContext(extraire('plateau-multijoueur.js', 'personnesNormalesDeLaPiece'), ctx);
  vm.runInContext(extraire('plateau-pnj.js', 'slugPnj'), ctx);
  vm.runInContext(extraire('plateau-pnj.js', 'PNJ_PROFILS_SERVEUR', 'const ') + ';this.PNJ_PROFILS_SERVEUR = PNJ_PROFILS_SERVEUR;', ctx);
  vm.runInContext(extraire('plateau-pnj.js', 'profilServeurDuPnj'), ctx);
  return vm.runInContext(`(() => { const out = [];
    for (const ville of Object.keys(WORLD.soviet)) { const cite = WORLD.soviet[ville]; if (!cite || !Array.isArray(cite.buildings)) continue;
      state.country = 'soviet'; state.currentCity = ville;
      for (const id of cite.buildings) { const b = BUILDINGS[id]; if (!b) continue; const c = getBuildingContext(id);
        const pieces = new Set([...Object.keys(b.rooms || {}), ...Object.keys(c?.roomsExtra || {})].filter(p => !(c?.roomsExclues || []).includes(p)));
        for (const piece of pieces) for (const p of (personnesNormalesDeLaPiece(id, piece) || [])) {
          if (!p || p.isPJ || typeof p.name !== 'string') continue;
          out.push({ ville, batiment: id, piece, nom: p.name, role: p.role || '', job: p.job || '', photo: p.photoUrl || '',
            profilId: p.profilId || '', alias: p.aliasInformateur || '', profil: profilServeurDuPnj(p) });
        } } }
    return JSON.parse(JSON.stringify(out)); })()`, ctx);
}
const PNJ = Array.from(pnjDeSovarka());
const trouver = (nom) => PNJ.filter(p => p.nom.replace(/\s*\(PNJ\)\s*$/, '') === nom);

test('26 — tout PNJ visible de Sovarka a une fiche de dialogue (relevé calculé)', () => {
  assert.ok(PNJ.length > 150, 'relevé vide : ' + PNJ.length);
  const sans = PNJ.filter(p => !p.profil || !TOUS_PROFILS[p.profil]);
  assert.equal(sans.length, 0, 'PNJ de Sovarka sans fiche : ' + sans.map(p => [p.ville, p.batiment, p.piece, p.nom, p.profil].join(' / ')).join(' ; '));
  // Les fiches citées par le point 26, chacune à sa place.
  for (const [nom, id, ville, batiment, piece] of [
    ['Grigori Zaitsev', 'grigori_zaitsev', 'ville_b', 'cafe-tabac-cheminots-montrouge', 'salle'],
    ['L’habitué du Bar Sever', 'habitue_krasnov', 'ville_b', 'cafe-tabac-cheminots-montrouge', 'salle'],
    ['Zoïa Biletova', 'zoia_biletova', 'ville_b', 'musee-novomirsk', 'hall'],
    ['Arkadi Pamiatnikov', 'arkadi_pamiatnikov', 'ville_b', 'musee-novomirsk', 'hall'],
    ['Matveï Starikov', 'matvei_starikov', 'ville_b', 'dispensaire-public-v', 'ehpad'],
    ['Nadejda Oukolova', 'nadejda_oukolova', 'ville_b', 'dispensaire-public-v', 'attente'],
    ['Antonina Merkoulova', 'antonina_merkoulova', 'ville_b', 'maison-krasnov-bureaux', 'piece_maison'],
    ['Matveï Rybakov', 'matvei_rybakov', 'ville_b', 'maison-krasnov-rouge', 'piece_maison'],
    ['Praskovia Pakhomova', 'praskovia_pakhomova', 'ville_b', 'maison-krasnov-bleue', 'piece_maison'],
    ['Kouzma Lapchine', 'kouzma_lapchine', 'ville_b', 'maison-krasnov-eglise', 'piece_maison'],
    ['Ignat Lykov', 'ignat_lykov', 'ville_b', 'maison-krasnov-terrains', 'piece_maison'],
    ['Stepan Kouznetsov', 'stepan_kouznetsov', 'ville_b', 'maison-krasnov', 'piece_maison'],
    ['Dolgor Tsybikova', 'dolgor_tsybikova', 'ville_a', 'maison-starovka', 'piece_maison']]) {
    const p = trouver(nom).find(x => x.ville === ville && x.batiment === batiment && x.piece === piece);
    assert.ok(p, nom + ' absent de ' + [ville, batiment, piece].join('/'));
    assert.equal(p.profil, id, nom);
    assert.ok(TOUS_PROFILS[id], 'fiche ' + id);
    assert.ok(p.photo && fs.existsSync(path.join(R, p.photo)), 'portrait de ' + nom);
  }
  // Nadejda remplace « Infirmiere » générique à l'hôpital de Krasnov ; plus de PNJ générique au musée.
  const krasnov = PNJ.filter(p => p.ville === 'ville_b');
  assert.ok(!krasnov.some(p => /^Infirmiere\b/.test(p.nom) && p.batiment === 'dispensaire-public-v'));
  assert.ok(!krasnov.some(p => /^(Hôtesse|Guide) du musée de Krasnov/.test(p.nom)));
  // Grigori renvoie à l'habitué, mot pour mot.
  assert.match(TOUS_PROFILS.grigori_zaitsev.caractere, /« Lui, il sait\. Offrez-lui un verre\. »/);
  assert.match(TOUS_PROFILS.grigori_zaitsev.caractere, /essuies toujours le même verre/);
  // Le serveur voit les mêmes personnes (scènes générées depuis data.js).
  assert.ok(SCENES_PNJ[JSON.stringify(['soviet', 'ville_b', 'cafe-tabac-cheminots-montrouge', 'salle'])].personnes.includes('L’habitué du Bar Sever'));
  assert.ok(SCENES_PNJ[JSON.stringify(['soviet', 'ville_b', 'dispensaire-public-v', 'ehpad'])].personnes.includes('Matveï Starikov'));
});

test('26 — PNJ sociaux : client, serveur (migration), hors fonctionnaires', () => {
  const s = lire('plateau-social-pnj.js'), m = lire(MIGRATION);
  for (const [cle, id] of [['soviet|ville_b|maison-krasnov|piece_maison', 'stepan_kouznetsov'],
    ['soviet|ville_b|maison-krasnov-bureaux|piece_maison', 'antonina_merkoulova'], ['soviet|ville_b|maison-krasnov-rouge|piece_maison', 'matvei_rybakov'],
    ['soviet|ville_b|maison-krasnov-terrains|piece_maison', 'ignat_lykov'], ['soviet|ville_a|maison-starovka|piece_maison', 'dolgor_tsybikova'],
    ['soviet|ville_b|dispensaire-public-v|ehpad', 'matvei_starikov']]) {
    assert.match(s, new RegExp("'" + cle.replace(/\|/g, '\\|') + "':\\s+'" + id + "'"), cle);
  }
  for (const id of ['habitue_krasnov', 'matvei_starikov', 'antonina_merkoulova', 'matvei_rybakov', 'ignat_lykov', 'stepan_kouznetsov', 'dolgor_tsybikova']) {
    assert.ok(m.includes("('" + id + "')"), 'règle sociale serveur ' + id);
    assert.ok(NON_FONCTIONNAIRES.has(id), 'hors fonctionnaires ' + id);
  }
  // Clé à quatre parties : l'EHPAD du gabarit existe aussi à Montrouge (Républia).
  assert.match(s, /RP_SOCIAL_LIEUX\[\[pays, ville, buildingId, roomId\]\.join\('\|'\)\]/);
  // « Trinquer » inchangé dans les maisons.
  assert.match(lire('data.js'), /fn: 'trinquer_habitant', label: 'Trinquer avec l’habitant', pa: 3/);
});

test('24 — « Acheter une information » : plus d’ordre de pièce, bouton sur la fiche du PNJ (R4)', () => {
  const inf = lire('plateau-informateurs.js'), pnj = lire('plateau-pnj.js'), routeur = lire('plateau-router.js');
  assert.ok(!/RP_ORDRES_DYNAMIQUES/.test(inf), 'plus de source d’ordres dynamique');
  assert.ok(!/ordresInformateurs/.test(inf));
  assert.ok(!/fn === 'informateur_payer'/.test(routeur), 'route de l’ordre supprimée');
  assert.match(pnj, /id="pnj-informateur-zone"/);
  assert.match(pnj, /informateursBoutonPnj\(pnj\)\.catch/);
  assert.match(inf, /global\.document\.getElementById\('modal-pnj'\)\?\.classList\.remove\('open'\);\n\s+return ouvrirInformateursIci\(id\);/);
  // « Écouter le barman » refusé là où se tient un informateur : le refus dit où cliquer (plus d'ordre à chercher).
  assert.match(lire('plateau-core.js'), /r\.raison === 'ecoute_payante'[\s\S]{0,200}cliquez sur le barman et choisissez « Acheter une information »/);
  // R4 : aucun écran, ordre, banc ou outil de génération ne renvoie plus vers les deux ordres supprimés.
  const racine = fs.readdirSync(R).filter(f => f.endsWith('.js'));
  for (const f of racine) {
    const t = lire(f);
    assert.ok(!/fn\s*:\s*'(informateur_payer|offrir_verre_habitue_krasnov)'/.test(t), 'ordre supprimé encore déclaré : ' + f);
    assert.ok(!/fn === '(informateur_payer|offrir_verre_habitue_krasnov)'/.test(t), 'route vers un ordre supprimé : ' + f);
  }
  for (const f of fs.readdirSync(path.join(R, 'api')).filter(f => f.endsWith('.js'))) {
    assert.ok(!/offrir_verre_habitue_krasnov|Acheter une information|Offrir un verre à l’habitué/.test(lire('api/' + f)), 'aide ou fiche qui renvoie à un ordre supprimé : api/' + f);
  }
  const seed = lire('baseline/seeds/95_a-regenerer/ordres_couts.sql');
  assert.ok(!/'(informateur_payer|offrir_verre_habitue_krasnov)'/.test(seed), 'tarif encore au miroir');
  assert.match(lire(MIGRATION), /DELETE FROM public\.ordres_couts WHERE \(fn, pa, cost\) IN \(\('informateur_payer', 0, 0\), \('offrir_verre_habitue_krasnov', 0, 0\)\);/);
  for (const f of ['outils/bancs/banc-couts-reconciliation-219-local.py', 'outils/livraison/preparer-livraison-complete-219.py', 'outils/livraison/preparer-recette97-219.py'])
    assert.ok(!/informateur_payer|offrir_verre_habitue_krasnov/.test(lire(f)), 'plan de recette : ' + f);
});

test('25 — l’habitué du Bar Sever : visible, social, verre du jour au serveur, conclusion exacte', () => {
  const h = trouver('L’habitué du Bar Sever');
  assert.equal(h.length, 1);
  assert.equal(h[0].profilId, 'habitue_krasnov');
  assert.equal(h[0].photo, 'images/Sovarka/Krasnov/Krasnov_portrait_cafe-tabac-cheminots-montrouge_habitue.webp');
  const img = fs.readFileSync(path.join(R, h[0].photo));
  assert.equal(img.toString('ascii', 0, 4), 'RIFF'); assert.equal(img.toString('ascii', 8, 12), 'WEBP');
  const s = lire('plateau-social-pnj.js');
  assert.ok(s.includes("'Ce verre m’a donné soif ! Et je ne dis pas ça pour que tu m’en offres un en retour, mais je ne te dirais pas non si tu le fais.'"));
  assert.match(s, /sbRpc\('habitue_krasnov_accueillir', \{\}\)/);
  const m = lire(MIGRATION);
  assert.match(m, /PERFORM public\.maladie_verre_interne\(a\);/, 'le verre compte dans la Santé');
  assert.match(m, /'habitue_krasnov_verres_par_jour', 1, 'pnj'/);
  assert.match(m, /'habitue_krasnov_accueil_heures', 3, 'pnj'/);
  assert.match(m, /IF \(p\.country, p\.current_city, p\.current_building\) IS DISTINCT FROM \('soviet', 'ville_b', 'cafe-tabac-cheminots-montrouge'\)/);
  assert.match(m, /^-- NON APPLIQUÉE/);
  // Le barème existant (7 à 20 PSK) reste celui du serveur : l'écran ne fait que l'afficher.
  assert.match(lire('plateau-informateurs.js'), /boutonHabitue: 'Lui offrir un verre'/);
  assert.match(TOUS_PROFILS.habitue_krasnov.caractere, /Tu ne donnes JAMAIS un nom/);
});

test('25 — entrée au Bar Sever : verre offert, Santé suivie, fiche ouverte avec la conclusion ; rien ailleurs', async () => {
  const fiches = [], journal = [], appels = [];
  const ctx = vm.createContext({ console, window: {}, appels, fiches, journal });
  vm.runInContext(`let state = { char: { name: 'Tom' }, country: 'soviet', currentCity: 'ville_b', currentBuilding: 'cafe-tabac-cheminots-montrouge', currentRoom: 'salle', hp: 50 };
    var BUILDINGS = { 'cafe-tabac-cheminots-montrouge': { rooms: { salle: { persons: [] } } } };
    function getBuildingContext() { return { roomOverrides: { salle: { persons: [{ name: 'Grigori Zaitsev (PNJ)' }, { name: 'L’habitué du Bar Sever (PNJ)', profilId: 'habitue_krasnov' }] } } }; }
    function encodePnjSafe(p) { return JSON.stringify(p); }
    function openPnjModal(enc, o) { fiches.push([JSON.parse(enc).name, o.initialSpeech]); }
    function addJournalEntry(t) { journal.push(t); }
    function updateUI() {}
    var REPONSE = { ok: true, mode: 'verre', nom: 'Tom', connu: false, sante: 51 };
    async function sbRpc(fn, p) { appels.push(fn); return REPONSE; }
    async function sbPnjSocialEntrer(id) { appels.push('entrer:' + id); return { ok: true, social: true, jalon: null }; }
    ` + lire('plateau-social-pnj.js') + `;this.__entree = pnjSocialEntreeZone; this.__state = () => state; this.__rep = (r) => { REPONSE = r; };`, ctx);
  await ctx.__entree('cafe-tabac-cheminots-montrouge', 'salle');
  assert.deepEqual(appels, ['habitue_krasnov_accueillir'], 'une seule porte serveur, pas de double comptage');
  assert.equal(fiches[0][0], 'L’habitué du Bar Sever (PNJ)');
  assert.match(fiches[0][1], /^Hé, toi ! Oui, toi, le nouveau\./);
  assert.match(fiches[0][1], /Ce verre m’a donné soif ! Et je ne dis pas ça pour que tu m’en offres un en retour, mais je ne te dirais pas non si tu le fais\.$/);
  assert.equal(ctx.__state().hp, 51, 'Santé du serveur');
  assert.deepEqual(journal, ['L’habitué du Bar Sever vous offre un verre.']);
  ctx.__rep({ ok: true, mode: 'souvenir', nom: 'Tom', connu: true });
  await ctx.__entree('cafe-tabac-cheminots-montrouge', 'salle');
  assert.match(fiches[1][1], /^Ah, Tom ! Encore toi !/);
  assert.doesNotMatch(fiches[1][1], /donné soif/);
  ctx.__rep({ ok: true, mode: null });
  await ctx.__entree('cafe-tabac-cheminots-montrouge', 'salle');
  assert.equal(fiches.length, 2, 'le serveur ne dit rien : aucune fenêtre');
  // En Républia, le même bâtiment du gabarit n'a pas d'habitué.
  vm.runInContext(`state.country = 'republic'`, ctx);
  appels.length = 0;
  await ctx.__entree('cafe-tabac-cheminots-montrouge', 'salle');
  assert.ok(!appels.includes('habitue_krasnov_accueillir'));
});

test('27 — Ignat Lykov fonctionnaire à la retraite, jamais trappeur ; Kouzma batiouchka, plus sonneur', () => {
  // Aucune source du jeu (écran, serveur, fiches, traductions, énigmes, migrations, bancs) ne dit plus « trappeur » ni
  // « sonneur » : ces deux mots ne servaient qu'à ces deux erreurs.
  const sources = [];
  for (const d of ['', 'api', 'i18n', 'migrations', 'outils/bancs']) {
    for (const f of fs.readdirSync(path.join(R, d))) {
      if (!/\.(js|cjs|mjs|sql|py|json)$/.test(f) || f === path.basename(fileURLToPath(import.meta.url))) continue;
      sources.push(path.join(d, f));
    }
  }
  for (const f of sources) {
    const t = lire(f);
    assert.ok(!/trappeur|trapper/i.test(t), '« trappeur » dans ' + f);
    assert.ok(!/sonneur|bell-ringer/i.test(t), '« sonneur » dans ' + f);
  }
  assert.match(TOUS_PROFILS.ignat_lykov.identite, /Fonctionnaire à la retraite/);
  assert.match(TOUS_PROFILS.ignat_lykov.caractere, /fonctionnaire à la retraite/);
  assert.match(lire('api/_reaction-habitant.js'), /'Ignat Lykov': "Tu es Ignat Lykov, fonctionnaire à la retraite/);
  assert.match(lire('data.js'), /un fonctionnaire à la retraite, lunettes rondes et barbiche/);
  const k = TOUS_PROFILS.kouzma_lapchine;
  assert.match(k.caractere, /le batiouchka/); assert.match(k.caractere, /un peu sourd, tu parles fort/);
  assert.match(lire('api/_reaction-habitant.js'), /'Kouzma Lapchine': "Tu es Kouzma Lapchine, le batiouchka/);
});

test('28 — Matveï Rybakov : référent chasse et bûcheronnage, frère aîné de Prokhor, ironie sur les valises', () => {
  const m = TOUS_PROFILS.matvei_rybakov;
  assert.match(m.identite, /référent chasse et bûcheronnage de Krasnov/);
  assert.match(m.caractere, /frère aîné de Prokhor Rybakov, inspecteur des douanes à Novomirsk/);
  assert.match(m.caractere, /« Mon frère, il fouille des valises toute la journée\./);
  assert.match(m.savoir, /Couper du bois » \(1 PA\) rapporte le double d'une récolte/);
  assert.match(m.savoir, /aucun ordre de chasse/);
  assert.match(lire('api/_reaction-habitant.js'), /'Matveï Rybakov': "[^"]*référent de la ville pour la chasse et le bûcheronnage[^"]*frère aîné de Prokhor Rybakov[^"]*« mon frère, il fouille des valises toute la journée »/);
  assert.match(TOUS_PROFILS.sovarka_inspecteur_prokhor_rybakov.caractere, /TON FRÈRE AÎNÉ, Matveï Rybakov/);
  assert.match(lire('plateau-pnj.js'), /'matvei_rybakov',\n/);
  assert.match(lire(MIGRATION), /SELECT 'matvei_rybakov', 'chasse et bûcheronnage/);
});
