// Mission « Purge » (Fred, 24/11/2026), point A.6 : la case des PA devient une jauge comme Santé et Moral, et le lien
// « Plus d'informations sur les PA ? » mène à l'infirmière d'accueil de l'hôpital ou du dispensaire de la ville.
//  - plateau.html : jauge #hg-jauge-pa (data-jauge="pa", bulle commune), #r-pa enfant direct (updateUI, accueil, mobile) ;
//  - plateau-medecin-montrer.js : la bulle de la jauge pa existe ; la table des infirmières désigne, ville par ville, un PNJ
//    réellement présent dans la pièce (même résolution que l'écran : personnesNormalesDeLaPiece) et la pièce a une image ;
//  - api/_pnj-personnalites.js : la fiche DeepSeek de chacune explique les PA (Ekaterina Bintova par dérivation).
// Lancement : node --test outils/bancs/banc-pa-jauge-infirmiere-20261124.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const R = path.resolve(__dirname, '../..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');

function monde() {
  const c = vm.createContext({ console, window: {}, state: { country: 'soviet' } });
  vm.runInContext(lire('data.js').replace(/^const (WORLD|BUILDINGS) =/mg, 'var $1 ='), c);
  return c;
}
// Copie de personnesNormalesDeLaPiece (plateau-multijoueur.js), pour un pays et une ville donnés.
function personnes(c, pays, ville, bat, piece) {
  const b = c.BUILDINGS[bat], ctx = c.WORLD[pays][ville].buildingContext[bat];
  assert.ok(ctx, `${pays}/${ville} : bâtiment ${bat} absent`);
  const room = (b && b.rooms && b.rooms[piece]) || (ctx.roomsExtra || {})[piece];
  const ro = (ctx.roomOverrides || {})[piece];
  const premiere = Object.keys((b && b.rooms) || {})[0] === piece;
  let liste;
  if (ro && ro.personsVides === true) liste = [];
  else if (ro && ro.persons && ro.persons.length) liste = ro.persons;
  else if (premiere && ctx.persons && ctx.persons.length) liste = ctx.persons;
  else liste = (room && room.persons) || [];
  return { liste, image: (ro && ro.imageUrl) || (room && room.imageUrl) };
}
function tableInfirmieres() {
  const js = lire('plateau-medecin-montrer.js'), i = js.indexOf('const INFIRMIERES_PA = {');
  assert.ok(i > 0, 'table INFIRMIERES_PA absente');
  let j = js.indexOf('{', i), p = 0;
  for (; j < js.length; j++) { if (js[j] === '{') p++; else if (js[j] === '}' && --p === 0) break; }
  return vm.runInNewContext('(' + js.slice(js.indexOf('{', i), j + 1) + ')');
}

test('plateau.html : la case des PA est une jauge comme Santé et Moral, suivie du lien vers l’infirmière', () => {
  const html = lire('plateau.html');
  const m = html.match(/<div class="hg-jauge" id="hg-jauge-pa" data-jauge="pa"[^>]*aria-describedby="hg-jauge-bulle">\s*<div class="hg-jauge-nom">PA<\/div>\s*<div class="hg-jauge-val" id="r-pa">/);
  assert.ok(m, 'jauge PA absente ou #r-pa pas enfant direct');
  assert.ok(html.includes('id="b-pa"'), '#b-pa (barre écrite par updateUI) conservée');
  const iLien = html.indexOf('onclick="ouvrirInfirmierePa()"');
  assert.ok(iLien > html.indexOf('id="hg-jauge-moral"') && iLien < html.indexOf('id="hg-jauge-influence"'), 'lien sous la ligne PA / Santé / Moral');
  assert.match(html, />Plus d'informations sur les PA \?<\/button>/);
  const css = lire('style.css');
  assert.match(css, /#hg-jauge-pa \.hg-jauge-barre\{/);
  assert.match(css, /\.hg-pa-infos\{[^}]*font-size:\.8rem/);
  const js = lire('plateau-medecin-montrer.js');
  assert.match(js, /SOURCES_JAUGES = \{ pa: 'r-pa',/);
  assert.match(js, /pa_txt: 'PA \{n\} \/ \{max\} :/);
  assert.match(js, /global\.ouvrirInfirmierePa = ouvrirInfirmierePa/);
});

test('une infirmière d’accueil par ville, réellement présente dans une pièce qui a une image', () => {
  const c = monde(), table = tableInfirmieres();
  const attendu = { republic: ['capitale', 'ville_a', 'ville_b'], soviet: ['capitale', 'ville_a', 'ville_b'] };
  for (const [pays, villes] of Object.entries(attendu)) for (const ville of villes) {
    const inf = table[pays] && table[pays][ville];
    assert.ok(inf, `${pays}/${ville} : aucune infirmière`);
    const { liste, image } = personnes(c, pays, ville, inf.batiment, inf.piece);
    const p = liste.find(x => String(x.name).replace(/\s*\(PNJ\)\s*$/i, '').trim() === inf.nom);
    assert.ok(p, `${pays}/${ville} : ${inf.nom} absente de ${inf.batiment}/${inf.piece} (${liste.map(x => x.name)})`);
    assert.match(String(p.role), /Infirmi|Soignante/, `${inf.nom} : rôle de soignante`);
    assert.ok(image, `${pays}/${ville} : la pièce ${inf.piece} a une image`);
  }
  assert.equal(table.soviet.ville_b.nom, 'Nadejda Oukolova', 'Krasnov : Nadejda Oukolova (consigne de Fred)');
});

test('fiches DeepSeek : chaque infirmière explique les PA', async () => {
  const table = tableInfirmieres();
  const { TOUS_PROFILS } = await import(path.join(R, 'api/_pnj-profils.js'));
  const ids = { 'Anne Tibiotique': 'anne_tibiotique', 'Betty Dine': 'betty_dine', 'Agnès Thésie': 'agnes_thesie',
    'Ekaterina Bintova': 'sovarka_ekaterina_bintova', 'Raïssa Bintova': 'raissa_bintova', 'Nadejda Oukolova': 'nadejda_oukolova' };
  const noms = Object.values(table).flatMap(v => Object.values(v).map(x => x.nom));
  assert.deepEqual(noms.slice().sort(), Object.keys(ids).sort());
  for (const [nom, id] of Object.entries(ids)) {
    const p = TOUS_PROFILS[id];
    assert.ok(p, id + ' : fiche absente');
    assert.equal(p.nom, nom);
    assert.match(p.savoir, /LES PA, les points d'action/, id + ' : savoir des PA');
    assert.match(p.savoir, /Dormir recharge les PA/);
    assert.match(p.limites, /SAUF CE QUE TU SAIS DES PA/, id + ' : limites ouvertes aux PA');
    assert.doesNotMatch(p.limites, /cout en points d'action/);
  }
});
