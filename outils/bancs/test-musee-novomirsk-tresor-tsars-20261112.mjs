// Musée municipal de Novomirsk (salles 1 et 2) et énigme du trésor des Tsars (Fred, 12/11/2026).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { contientMotCle, repliqueTresorTsars, PNJ_TRESOR_TSARS } from '../../api/_enigme-tresor-tsars.js';
import { profilsPersonnalites } from '../../api/_pnj-personnalites.js';
const lire = f => readFileSync(new URL('../../' + f, import.meta.url), 'utf8');

function monde() {
  const ctx = { console, state: { country: 'soviet' }, document: { getElementById: () => null, addEventListener() {}, querySelector: () => null }, localStorage: { getItem: () => null } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('data.js').replace(/^const (WORLD|BUILDINGS) =/mg, 'var $1 ='), ctx);
  return ctx;
}
const salles = (c, ville) => {
  const ctx = c.WORLD.soviet[ville].buildingContext['musee-novomirsk'] || {};
  return Object.keys({ ...c.BUILDINGS['musee-novomirsk'].rooms, ...(ctx.roomsExtra || {}) }).filter(r => !(ctx.roomsExclues || []).includes(r));
};

test('Novomirsk montre seulement le hall et les deux nouvelles salles ; Krasnov garde les siennes', () => {
  const c = monde();
  assert.deepEqual(salles(c, 'capitale'), ['hall', 'salle_origines', 'salle_personnalites_discretes', 'salle_bataille_fleuve', 'salle_grand_incendie']);
  const k = salles(c, 'ville_b');
  assert.ok(!k.includes('salle_origines') && !k.includes('salle_personnalites_discretes') && k.includes('salle_criminels'));
  const r = c.BUILDINGS['musee-novomirsk'].rooms;
  assert.equal(r.salle_origines.name, 'Salle des Origines');
  assert.ok(r.salle_origines.orders.some(o => o.fn === 'tresor_ecouter_guide' && o.pa === 0));
  assert.equal(r.salle_personnalites_discretes.name, 'Salle des Personnalités discrètes');
  assert.ok(r.salle_personnalites_discretes.orders.some(o => o.fn === 'consulter_personnalites_musee'));
  assert.match(lire('migrations/20261112200000_musee_novomirsk_tresor_tsars.sql'), /\["hall", "salle_origines", "salle_personnalites_discretes"\]/);
});

test('cinq personnalités discrètes, Belov pour Anna Mouriskova', () => {
  const s = lire('plateau-musee-personnalites.js');
  for (const n of ['Sophia Nouiseteskaïa', 'Viktor Polov', 'Alexander Aspirine', 'Ivan Betonov', 'Anna Mouriskova']) assert.ok(s.includes("nom: '" + n + "'"), n);
  assert.match(s, /maux de tête/);
  assert.match(s, /Taras Sergueïevitch Belov la fit exécuter/);
});

test('Sudakov à l’EHPAD de Novomirsk, avec son profil de dialogue qui ignore le trésor', () => {
  const c = monde();
  const p = c.WORLD.soviet.capitale.buildingContext['dispensaire-public'].roomOverrides.ehpad_tilleuls.persons.map(x => x.name);
  assert.ok(p.includes('Evgueni Sudakov (PNJ)') && p.length === 4);
  const prof = profilsPersonnalites ? profilsPersonnalites.evgueni_sudakov || null : null;
  assert.ok(lire('api/_pnj-personnalites.js').includes("'evgueni_sudakov':"));
  if (prof) assert.match(prof.trait, /Karpov/);
  assert.ok(lire('api/_pnj-scenes-generes.js').includes('"Evgueni Sudakov"'));
});

test('mots clés : mots entiers, neuf langues, et rien hors des trois PNJ', () => {
  assert.deepEqual(PNJ_TRESOR_TSARS, ['galina_karpova', 'evgueni_sudakov', 'tatiana_bortchova']);
  assert.ok(contientMotCle('galina_karpova', "Vos poissons valent de l'or ?", 'fr'));
  assert.ok(!contientMotCle('galina_karpova', 'Encore une carpe, alors ?', 'fr'));
  assert.ok(contientMotCle('galina_karpova', 'Any treasure here?', 'en'));
  assert.ok(contientMotCle('galina_karpova', 'Un coffre ?', 'de'), 'le français vaut toujours');
  assert.ok(!contientMotCle('galina_karpova', 'aigle impérial', 'fr'), 'aigle : seulement pour Sudakov');
  assert.ok(contientMotCle('evgueni_sudakov', "L'aigle impérial du tsar", 'fr'));
  for (const [m, l] of [['Расскажите про царя', 'ru'], ['보물', 'ko'], ['沙皇', 'zh'], ['كنز', 'ar'], ['tesouro', 'pt'], ['Schatz', 'de'], ['tesoro', 'es']]) assert.ok(contientMotCle('evgueni_sudakov', m, l), l);
  assert.ok(!contientMotCle('tatiana_bortchova', 'trésor', 'fr'), 'Tatiana réagit au livre, le serveur en juge');
});

test('répliques fixes : textes de Fred, neuf langues', () => {
  assert.match(repliqueTresorTsars('karpova', 'fr'), /morceau de bois gravé de l'aigle impérial/);
  assert.match(repliqueTresorTsars('karpova', 'fr'), /Evgueni Sudakov/);
  assert.match(repliqueTresorTsars('sudakov', 'fr'), /maudits Karpov/);
  assert.match(repliqueTresorTsars('sudakov', 'fr'), /palais présidentiel/);
  assert.match(repliqueTresorTsars('tatiana_livre', 'fr'), /Donnez-le-moi/);
  for (const l of ['en', 'es', 'zh', 'ru', 'ko', 'ar', 'pt', 'de']) for (const s of ['karpova', 'sudakov', 'tatiana_livre']) {
    assert.ok(repliqueTresorTsars(s, l) && repliqueTresorTsars(s, l) !== repliqueTresorTsars(s, 'fr'), s + ' ' + l);
  }
  assert.equal(repliqueTresorTsars('inconnue', 'fr'), null);
});

test('/api/chat : le serveur décide de la scène avant l’IA', () => {
  const s = lire('api/chat.js');
  assert.match(s, /PNJ_TRESOR_TSARS\.includes\(req\.body\.profil\)/);
  assert.match(s, /rpcJoueur\('tresor_tsars_parler', \{ p_pnj: req\.body\.profil, p_mot_cle: motCle \}/);
  assert.ok(s.indexOf("rpcJoueur('tresor_tsars_parler'") < s.indexOf('appelDeepSeek({'));
});

test('serveur : étapes dans l’ordre, livre à la fouille, gâteaux de 4 jours', () => {
  const m = lire('migrations/20261112200000_musee_novomirsk_tresor_tsars.sql');
  assert.match(m, /etape IN \('guide', 'karpova', 'sudakov', 'livre', 'livre_donne', 'terminee'\)/);
  assert.match(m, /r < 1 OR NOT public\.tresor_tsars_lieu_interne\(a, 'poissonniere-novomirsk', 'etal_poissonniere'\)/);
  assert.match(m, /r < 2 OR NOT public\.tresor_tsars_lieu_interne\(a, 'dispensaire-public', 'ehpad_tilleuls'\)/);
  assert.match(m, /e = 'livre' AND public\.tresor_tsars_livre_index_interne\(inv\) >= 0/);
  assert.match(m, /RETURN public\.tresor_tsars_fouille_interne\(a, l\.batiment, l\.piece\) \|\| jsonb_build_object\('ok', true/);
  assert.match(m, /4 \* 86400000/);
  assert.match(m, /pa = least\(30, coalesce\(pa, 0\) \+ 1\), moral = least\(100, coalesce\(moral, 0\) \+ 10\)/);
  assert.match(m, /"stackKey":"tresor-tsars","qty":2/);
  for (const f of ['tresor_tsars_guide()', 'tresor_tsars_parler(text, boolean)', 'tresor_tsars_donner_livre(uuid)', 'tresor_tsars_recit(uuid)', 'tresor_tsars_manger(uuid)'])
    assert.ok(m.includes('GRANT EXECUTE ON FUNCTION public.' + f + ' TO authenticated'), f);
});

test('écran : textes en neuf langues, ordres de Tatiana, branchements', () => {
  const ctx = { RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => 'en' } };
  ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(lire('i18n/tresor-tsars-resources.js'), ctx);
  const src = lire('i18n/tresor-tsars-resources.js');
  for (const k of ctx.RPTresorTsarsI18n.cles) {
    const ligne = src.match(new RegExp('^ ' + k + ':\\[', 'm')); assert.ok(ligne, k);
  }
  assert.match(ctx.texteTresor('guide'), /fisherman's wife/);
  const fr = { RP_I18N_GAME_ENABLED: true, RPPlateauI18n: { language: () => 'fr' } }; fr.window = fr; vm.createContext(fr);
  vm.runInContext(src, fr);
  assert.match(fr.texteTresor('guide'), /demandez donc à la femme du pêcheur qui vend du poisson le long des quais si ses poissons valent de l'or/);
  assert.match(fr.texteTresor('recit'), /J'ouvre le coffre et je découvre le trésor des tsars/);
  assert.match(fr.texteTresor('book'), /…chez la mère Volga/);
  // Ordres dynamiques de la Mère Volga.
  const c = { window: {}, localStorage: { getItem: () => null }, texteTresor: fr.texteTresor,
    state: { country: 'soviet', currentCity: 'capitale', char: { name: 'A' }, inventory: [{ tresorTsars: 'livre' }] } };
  c.window = c; vm.createContext(c);
  vm.runInContext(lire('plateau-enigme-tresor-tsars.js'), c);
  assert.equal(c.ordresTresorTsars('capitaine-sauvage', 'salle_principale')[0].fn, 'tresor_donner_livre');
  assert.equal(c.ordresTresorTsars('musee-novomirsk', 'hall').length, 0);
  c.state.inventory = []; assert.equal(c.ordresTresorTsars('capitaine-sauvage', 'salle_principale').length, 0);
  c.state.country = 'republic'; c.state.inventory = [{ tresorTsars: 'livre' }];
  assert.equal(c.ordresTresorTsars('capitaine-sauvage', 'salle_principale').length, 0, 'le Capitaine Sauvage de PSM n’est pas concerné');
  assert.match(lire('plateau-router.js'), /fn === 'tresor_ecouter_guide'/);
  assert.match(lire('plateau-surveillance.js'), /tresorTsarsApresFouille\(r\)/);
  assert.equal((lire('plateau-personnage.js').match(/boutonsTresorTsarsObjet\(item/g) || []).length, 2);
  const html = lire('plateau.html');
  assert.ok(html.includes('plateau-enigme-tresor-tsars.js') && html.includes('i18n/tresor-tsars-resources.js'));
});

test('noms, descriptions, rôle et ordre des nouvelles salles au catalogue de Sovarka', () => {
  assert.match(lire('i18n/sovarka-pieces-resources.js'), /\["Salle des Origines", ?"Hall of Origins"/);
  assert.match(lire('i18n/sovarka-pieces-resources.js'), /\["Salle des Personnalités discrètes"/);
  assert.match(lire('i18n/sovarka-roles-resources.js'), /\["Pensionnaire, ancien pêcheur", ?"Resident/);
  assert.match(lire('i18n/sovarka-ordres-resources.js'), /"tresor_ecouter_guide":"Listen to the guide"/);
  assert.match(lire('i18n/sovarka-descriptions-resources.js'), /Cartes anciennes, filets de pêche/);
});
