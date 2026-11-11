'use strict';
// Sovarka, messages dynamiques (11/11/2026) : catalogue i18n/sovarka-messages-resources.js en neuf langues,
// motifs de refus du serveur nommés dans la langue du joueur, salles de réunion de Novomirsk.
// Le serveur garde la décision : l'écran ne traduit que la présentation, sans appel serveur supplémentaire.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
const variables = s => [...s.matchAll(/\{(\w+)\}/g)].map(m => m[1]).sort().join(',');
const balises = s => (s.match(/<\/?[a-z]+>/g) || []).join('');

function catalogue(fichier, api, langue) {
  const ctx = { langue, RP_I18N_GAME_ENABLED: true };
  ctx.RPPlateauI18n = { language: () => ctx.langue };
  vm.createContext(ctx);
  ctx.window = ctx;
  vm.runInContext(lire(fichier), ctx);
  return { ctx, t: ctx[api] };
}

const CATALOGUES = {
  'i18n/sovarka-messages-resources.js': 'RPSovarkaMessagesI18n',
  'i18n/sovarka-droits-resources.js': 'RPSovarkaDroitsI18n',
  'i18n/sovarka-justice-resources.js': 'RPSovarkaJusticeI18n',
  'i18n/sovarka-partis-resources.js': 'RPSovarkaPartisI18n',
  'i18n/sovarka-pouvoir-resources.js': 'RPSovarkaPouvoirI18n',
  'i18n/sovarka-provinces-resources.js': 'RPSovarkaProvincesI18n'
};

for (const [fichier, api] of Object.entries(CATALOGUES)) {
  test(fichier + ' : neuf langues, mêmes clés, mêmes variables et mêmes balises', () => {
    const { ctx, t } = catalogue(fichier, api, 'fr');
    assert.ok(t, api);
    assert.deepEqual([...t.langues], LANGUES);
    const fr = Object.fromEntries(t.cles.map(k => [k, t.text(k)]));
    for (const l of LANGUES) {
      ctx.langue = l;
      for (const k of t.cles) {
        const v = t.text(k);
        assert.ok(v && v.length, l + ' ' + k);
        assert.equal(variables(v), variables(fr[k]), l + ' ' + k + ' (variables)');
        assert.equal(balises(v), balises(fr[k]), l + ' ' + k + ' (balises)');
      }
    }
    const blocs = lire(fichier).split(/\n  "(?:[a-zA-Z-]+)": \{\n/).slice(1);
    assert.equal(blocs.length, 9);
    for (const b of blocs) assert.equal((b.match(/^    "\w+":/gm) || []).length, t.cles.length, fichier);
  });
}

// Lot 1 : chaque motif ajouté est listé par son écran et traduit (sinon l'écran retomberait sur « Refusé »).
const MOTIFS_LOT1 = {
  'plateau-sovarka-droits.js': ['SOV_RAISONS', 'i18n/sovarka-droits-resources.js', 'm_', ['acteur_non_authentifie', 'parametres_invalides', 'cause_invalide']],
  'plateau-sovarka-justice.js': ['JUSTICE_SOV_RAISONS', 'i18n/sovarka-justice-resources.js', 'm_', ['decision_invalide', 'requete_absente']],
  'plateau-sovarka-partis.js': ['PARTI_RAISONS', 'i18n/sovarka-partis-resources.js', 'm_', ['action_inconnue', 'champs_interdits', 'cible_requise']],
  'plateau-sovarka-pouvoir.js': ['SOV_POUVOIR_RAISONS', 'i18n/sovarka-pouvoir-resources.js', 'pm_', ['action_inconnue', 'cause_invalide', 'dans_la_rue', 'local_introuvable']]
};
test('lot 1 : motifs de refus ajoutés, listés par leur écran et traduits dans les neuf langues', () => {
  for (const [ecran, [liste, cat, prefixe, codes]] of Object.entries(MOTIFS_LOT1)) {
    const src = lire(ecran);
    const decl = src.slice(src.indexOf('const ' + liste + ' = ['), src.indexOf('];', src.indexOf('const ' + liste + ' = [')));
    const { ctx, t } = catalogue(cat, CATALOGUES[cat], 'fr');
    for (const c of codes) {
      assert.ok(decl.includes("'" + c + "'"), ecran + ' ' + c);
      assert.ok(t.cles.includes(prefixe + c), cat + ' ' + c);
      for (const l of LANGUES) { ctx.langue = l; assert.ok(t.text(prefixe + c).length > 3, l + ' ' + c); }
    }
  }
  assert.ok(lire('plateau-sovarka-pouvoir.js').includes("const REPAS_PRES_RAISONS = ['requete_absente',"));
  assert.ok(lire('plateau-sovarka-provinces.js').includes("provRaisons(['requete_absente', 'action_inconnue', 'acteur_non_authentifie',"));
});

// Salles de réunion de Novomirsk : écran traduit, français identique à l'ancien affichage, motifs du serveur.
function reunions(langue, reponse) {
  const els = {};
  const el = id => els[id] || (els[id] = { id, value: 'INT', classList: { remove() {} } });
  const toasts = [], appels = [], modales = [];
  const ctx = {
    console, JSON, Object, Array, crypto: { randomUUID: () => 'u1' },
    sessionStorage: { getItem: () => null, setItem() {}, removeItem() {} },
    langue, RP_I18N_GAME_ENABLED: true, state: { currentRoom: 'reunion_grande_a', char: { name: 'Ivan' } },
    document: { getElementById: el },
    vehModal: (t, h) => modales.push([t, h]),
    vehSection: (t, c) => '<section><b>' + t + '</b>' + c + '</section>',
    vehBouton: (l, js) => '<button onclick="' + js + '">' + l + '</button>',
    showToast: (t, m, ok) => toasts.push([t, m, ok]),
    sbRpcVerdict: async (fn, p) => { appels.push([fn, p]); return JSON.parse(JSON.stringify(reponse)); }
  };
  ctx.RPPlateauI18n = { language: () => ctx.langue };
  vm.createContext(ctx);
  ctx.window = ctx;
  vm.runInContext(lire('i18n/sovarka-messages-resources.js'), ctx);
  vm.runInContext(lire('plateau-reunions-evenements.js'), ctx);
  return { ctx, toasts, appels, modales };
}

test('réunions en français : affichage identique à l’ancien écran', async () => {
  const r = reunions('fr', { ok: true, type: 'buffet', titre: 'Buffet du Grand Hôtel', presents: ['A', 'B', 'C'], paye: 120 });
  r.ctx.ouvrirReunionEvenement();
  const [titre, html] = r.modales[0];
  assert.equal(titre, 'Organiser un événement');
  for (const s of ['Vous avez réservé la salle pour la journée ? Organisez-y un événement. Chaque événement coûte 1 PA et ne peut avoir lieu qu’une fois par salle et par jour.',
    '<b>Conférence de presse</b>', '+3 POP, et +1 POP par personne présente dans la salle (au plus +10).', '<b>Soirée de réseautage</b>',
    '<b>Séminaire de formation</b>', '<b>Buffet du Grand Hôtel</b>', '40 PSK par personne présente', '<option value="DUP">Duplicité</option>',
    "lancerReunionEvenement('seminaire','reunion_grande_a')", '>Organiser</button>']) assert.ok(html.includes(s), s);
  await r.ctx.lancerReunionEvenement('buffet', 'reunion_grande_a');
  assert.equal(JSON.stringify(r.toasts.at(-1)), JSON.stringify(['Buffet du Grand Hôtel', '3 personnes présentes ; buffet payé 120 PSK.', true]));
  const un = reunions('fr', { ok: true, type: 'conference_presse', titre: 'Conférence de presse', presents: ['A'] });
  await un.ctx.lancerReunionEvenement('conference_presse', 'reunion_grande_a');
  assert.equal(JSON.stringify(un.toasts.at(-1)), JSON.stringify(['Conférence de presse', '1 personne présente.', true]));
  const refus = reunions('fr', { ok: false, raison: 'salle_non_reservee' });
  await refus.ctx.lancerReunionEvenement('buffet', 'reunion_grande_a');
  assert.equal(JSON.stringify(refus.toasts.at(-1)), JSON.stringify(['Événement refusé', 'Seul celui qui a réservé la salle aujourd’hui peut y organiser un événement.', false]));
  const muet = reunions('fr', { ok: false, raison: 'inattendu' });
  await muet.ctx.lancerReunionEvenement('buffet', 'reunion_grande_a');
  assert.equal(muet.toasts.at(-1)[1], 'Le serveur n’a pas confirmé l’événement.');
});

test('réunions en arabe et en russe : interface et refus traduits, paramètres serveur intacts, un seul appel', async () => {
  const ar = reunions('ar', { ok: false, raison: 'evenement_deja_tenu' });
  ar.ctx.ouvrirReunionEvenement();
  assert.equal(ar.modales[0][0], 'تنظيم فعالية');
  assert.ok(!/[À-ÿ]{3}/.test(ar.modales[0][1].replace(/value="[A-Z]+"/g, '')), 'reste du français');
  await ar.ctx.lancerReunionEvenement('seminaire', 'reunion_grande_a');
  assert.equal(JSON.stringify(ar.appels), JSON.stringify([['sovarka_reunion_evenement', { p_requete: 'u1', p_salle: 'reunion_grande_a', p_type: 'seminaire', p_carac: 'INT' }]]));
  assert.equal(ar.toasts[0][1], 'أُقيمت هذه الفعالية في هذه القاعة اليوم بالفعل.');
  const ru = reunions('ru', { ok: true, type: 'reseautage', titre: 'Soirée de réseautage', presents: ['A', 'B'] });
  await ru.ctx.lancerReunionEvenement('reseautage', 'reunion_grande_a');
  assert.equal(JSON.stringify(ru.toasts[0]), JSON.stringify(['Вечер нетворкинга', 'Присутствующих: 2.', true]));
  assert.equal(ru.appels.length, 1);
});

// Lot 2 : courriers écrits en français par le serveur, présentés dans la langue du joueur à l'affichage.
function courriers(langue) {
  const ctx = { langue, RP_I18N_GAME_ENABLED: true };
  ctx.RPPlateauI18n = { language: () => ctx.langue };
  vm.createContext(ctx);
  ctx.window = ctx;
  vm.runInContext(lire('i18n/sovarka-messages-resources.js'), ctx);
  vm.runInContext(lire('plateau-sovarka-courriers.js'), ctx);
  return ctx;
}
// Courriers tels que les fonctions serveur les composent (concaténations recopiées des migrations).
const COURRIERS = [
  { from: 'Mairie', subject: 'Demande de commerce acceptée',
    body: 'Votre demande (« ' + 'Boulangerie du Peuple' + ' ») est acceptée. Local attribué : ' + 'Galeries, local 3' + ', loyer ' + 75 + ' ' + 'PSK' + ' par jour' + '. Présentez-vous chez le notaire de Novomirsk pour signer l\'attribution.' },
  { from: 'Mairie', subject: 'Demande de commerce acceptée',
    body: 'Votre demande (« Kiosque ») est acceptée. Aucun local n\'est libre : il vous sera attribué dans le prochain immeuble collectif construit par la mairie. Votre dossier reste valide.' },
  { from: 'Tribunal Populaire', subject: 'Droit d\'exploiter retiré',
    body: 'Le Tribunal Populaire vous retire le droit d\'exploiter : ' + 'Pharmacie officielle' + '. Motif : ' + 'Vente de « vodka » frelatée' + '. Le local revient à l\'État, sans indemnité.' },
  { from: 'Parti des Précurseurs Politiques', subject: 'Demande d\'adhésion : ' + 'Boris Kozlov',
    body: 'Boris Kozlov' + ' demande à adhérer à votre parti. Droit d\'entrée actuel : ' + '15' + ' PSK, payé à l\'acceptation. Un refus coûte 2 POP au parti. Répondez depuis la salle des partis d\'une mairie (« Mon parti »).' },
  { from: 'Parti des Précurseurs Politiques', subject: 'Adhésion acceptée',
    body: 'Bienvenue au parti ' + 'Parti des Précurseurs Politiques' + '.' + ' Droit d\'entrée payé : ' + 15 + ' PSK.' },
  { from: 'Conseil du Peuple', subject: 'Loi promulguée : ' + 'Tracteurs pour tous',
    body: 'Le Président du Conseil du Peuple a accepté votre projet. La loi est promulguée et s\'applique dès maintenant ; les députés l\'approuveront jeudi.' },
  { from: 'Secrétariat du Conseil du Peuple', subject: 'Convocation : séance du jeudi',
    body: 'Camarade député, vous êtes convoqué aujourd\'hui au Palais du Gouvernement de Sovarka, Salle du Conseil du Peuple, '
      + 'pour approuver les lois promulguées. Émargez puis approuvez ou abstenez-vous (une abstention est signalée et coûte 5 POP à votre parti).'
      + '\n\nAttention : un député absent perd son indemnité (250 PSK par jour) pour toute la semaine, jusqu\'à la convocation suivante.'
      + '\n\nOrdre du jour :\n' + '(aucune loi promulguée cette semaine)' },
  { from: 'Secrétariat du Conseil du Peuple', subject: 'Indemnité suspendue',
    body: 'Absent à la séance de jeudi : votre indemnité de député est suspendue pour sept jours, jusqu\'au ' + '19/11' + ' inclus.' },
  { from: 'Centre d\'affaires de Novomirsk', subject: 'Séminaire de formation',
    body: 'Séminaire de formation organisé par ' + 'Ivan' + ' : ' + 'PER' + ' +1 jusqu\'à minuit.' },
  { from: 'Banque de Sovarka', subject: 'Bon d\'État remboursé',
    body: 'Camarade, votre bon d\'État de ' + 100 + ' PSK arrive à échéance (rendement fixé à ' + 2.5 + ' %). Le Trésor de Sovarka vous rend ' + 102 + ' PSK sur votre compte. La Patrie vous remercie.' },
  { from: 'Événement', subject: 'Forêt de Krasnov',
    body: 'Vous avez vaincu : ' + 'Ours' + '. Le butin (peaux, viande' + ', dents d\'ours' + ') vous revient, à partager avec votre groupe.' }
];

test('courriers en français : jamais transformés', () => {
  const ctx = courriers('fr');
  for (const m of COURRIERS) { assert.equal(ctx.RPCourriersSovarka.traduire(m), null); assert.equal(ctx.RPCourriersSovarka.vu(m), m); }
});

test('courriers dans les huit autres langues : tous reconnus, données des joueurs et montants intacts', () => {
  for (const l of LANGUES.filter(x => x !== 'fr')) {
    const ctx = courriers(l);
    for (const m of COURRIERS) {
      const t = ctx.RPCourriersSovarka.traduire(m);
      assert.ok(t, l + ' non reconnu : ' + m.subject);
      assert.notEqual(t.body, m.body, l + ' ' + m.subject);
      assert.ok(!/\{\w+\}/.test(t.subject + t.body), l + ' variable non remplie');
    }
    const [loc, , retrait, adh, bienv, loi, conv, indem, sem, bon, foret] = COURRIERS.map(m => ctx.RPCourriersSovarka.traduire(m));
    for (const s of ['Boulangerie du Peuple', 'Galeries, local 3', '75', 'PSK']) assert.ok(loc.body.includes(s), l + ' ' + s);
    assert.ok(retrait.body.includes('Vente de « vodka » frelatée') && retrait.body.includes('Pharmacie officielle'));
    assert.ok(adh.subject.includes('Boris Kozlov') && adh.body.includes('Boris Kozlov') && adh.body.includes('15'));
    assert.ok(bienv.body.includes('Parti des Précurseurs Politiques') && bienv.body.includes('15'));
    assert.ok(loi.subject.includes('Tracteurs pour tous'), 'titre de loi conservé');
    assert.ok(conv.body.includes('250') && !conv.body.includes('aucune loi'), l + ' ordre du jour vide traduit');
    assert.ok(indem.body.includes('19/11'));
    assert.ok(sem.body.includes('Ivan') && !sem.body.includes('PER'), 'caractéristique nommée');
    assert.ok(bon.body.includes('100') && bon.body.includes('2.5') && bon.body.includes('102'));
    assert.ok(!foret.body.includes('Ours'), 'créature nommée dans la langue');
  }
  const de = courriers('de');
  assert.equal(de.RPCourriersSovarka.traduire(COURRIERS[10]).body, 'Sie haben besiegt: Bär. Die Beute (Felle, Fleisch, Bärenzähne) gehört Ihnen, teilen Sie sie mit Ihrer Gruppe.');
});

test('courriers : texte inconnu, expéditeur différent ou modifié = courrier d’origine', () => {
  const ctx = courriers('en');
  const c = ctx.RPCourriersSovarka;
  assert.equal(c.traduire({ from: 'Ivan', subject: 'Demande de commerce acceptée', body: COURRIERS[0].body }), null, 'expéditeur imposé');
  assert.equal(c.traduire({ ...COURRIERS[0], body: COURRIERS[0].body + ' PS : merci.' }), null, 'corps modifié');
  assert.equal(c.traduire({ from: 'Mairie', subject: 'Bonjour', body: 'Texte libre' }), null);
  assert.equal(c.traduire({ ...COURRIERS[4], subject: 'Adhésion acceptée !' }), null);
  const autre = { from: 'Ivan', subject: 'Salut', body: 'Écrit par un joueur.' };
  assert.equal(c.vu(autre), autre);
});

test('courriers : chaque sujet fixe des migrations Sovarka a son modèle dans le catalogue', () => {
  const { t } = catalogue('i18n/sovarka-messages-resources.js', 'RPSovarkaMessagesI18n', 'fr');
  const sujetsFr = new Set(t.cles.filter(k => /^(cs_|re_t_)/.test(k)).map(k => t.fr(k).split('{')[0]));
  const dossier = path.join(racine, 'migrations');
  const sujets = new Set();
  for (const f of fs.readdirSync(dossier).filter(n => /sovarka/.test(n) && n.endsWith('.sql'))) {
    for (const m of fs.readFileSync(path.join(dossier, f), 'utf8').matchAll(/mail_systeme_poser_interne\(\s*('(?:[^']|'')*'|[a-z_>\-'()]+)\s*,\s*[^,]+,\s*'((?:[^']|'')*)'/g)) sujets.add(m[2].replace(/''/g, "'"));
  }
  // Restent en français (listés au relais) : cotisation (module commun des organisations) ; rapports de
  // surveillance et d'écoute, dont le corps reprend des déplacements et des courriers interceptés.
  const ignores = ['Fin d\'adhésion — cotisation non renouvelée', 'Rapport de surveillance — ', 'Rapport d\'écoute — ', 'Rapport d\'écoute dérobé — '];
  for (const s of sujets) {
    if (ignores.some(i => s.startsWith(i))) continue;
    assert.ok([...sujetsFr].some(p => s.startsWith(p)), 'sujet sans modèle : ' + s);
  }
  assert.ok(sujets.size >= 20, 'relevé des sujets anormalement court');
});

test('messagerie : le sujet et le corps affichés passent par la présentation traduite', () => {
  const src = lire('forum.js');
  assert.ok(src.includes('function mailVuTraduit(m)') && src.includes('window.RPCourriersSovarka?.vu?.(m)'));
  assert.equal((src.match(/escapeHtmlText\(mailSujetAffiche\(m\)\)/g) || []).length, 3);
  assert.ok(src.includes("const _actionsMail = extraireActionsMail(mail.body || '');"));
  assert.ok(src.includes("if (_mailVu !== mail) _actionsMail.corps = extraireActionsMail(_mailVu.body || '').corps;"));
  assert.ok(src.includes('${escapeHtmlText(_mailVu.subject)}'));
  const html = lire('plateau.html');
  assert.ok(html.indexOf('i18n/sovarka-messages-resources.js') < html.indexOf('plateau-sovarka-courriers.js'));
});
