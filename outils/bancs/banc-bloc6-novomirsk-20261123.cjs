'use strict';
// Bloc 6 de la mission « Novomirsk, PNJ, interface » (Fred, 23/11/2026, points 37 à 39) :
// GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md. Gare (images, Prokhor Rybakov frère de Matveï), Direction du
// Renseignement (Tamara Naouchnikova, Colonel Oleg Doprossov, Fiodor Koulakov, salle sans miroir sans tain),
// église (portraits du Pontife et de Frère Kolkhoze). Lit le VRAI data.js et la vraie résolution du casting par ville.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');

function charger() {
  const ctx = vm.createContext({ console, state: { country: 'soviet', currentCity: 'capitale' } });
  vm.runInContext(lire('data.js'), ctx);
  const extraire = (fichier, debut) => {
    const s = lire(fichier), i = s.indexOf('function ' + debut + '(');
    let j = s.indexOf('{', i), prof = 0;
    for (; j < s.length; j++) { if (s[j] === '{') prof++; else if (s[j] === '}' && --prof === 0) break; }
    return s.slice(i, j + 1);
  };
  vm.runInContext(extraire('plateau-navigation.js', 'getBuildingContext'), ctx);
  vm.runInContext(extraire('plateau-multijoueur.js', 'personnesNormalesDeLaPiece'), ctx);
  vm.runInContext(`this.__piece = (b, r) => { const c = getBuildingContext(b) || {}; const ro = (c.roomOverrides || {})[r] || {};
    const room = (BUILDINGS[b].rooms || {})[r] || (c.roomsExtra || {})[r] || {};
    const premiere = Object.keys(BUILDINGS[b].rooms || {})[0] === r;
    return JSON.parse(JSON.stringify({ persons: personnesNormalesDeLaPiece(b, r), imageUrl: ro.imageUrl || room.imageUrl || null,
      desc: ro.desc || ((premiere && c.desc) ? c.desc : (room.desc || '')) })); };`, ctx);
  return (b, r) => JSON.parse(JSON.stringify(ctx.__piece(b, r)));   // objets du domaine du banc (deepEqual strict)
}
const piece = charger();
const pnj = lire('api/_pnj-personnalites.js');
const fiche = id => { const i = pnj.indexOf("'" + id + "':"); assert.ok(i >= 0, 'fiche absente : ' + id); const fin = pnj.indexOf('` },', i); return pnj.slice(i, fin > i ? fin : i + 4000); };
const photo = (p, nom) => { const x = p.persons.find(q => q.name === nom); assert.ok(x, nom + ' absent'); return x.photoUrl; };
const existe = f => assert.ok(fs.existsSync(path.join(root, f)), 'image absente : ' + f);

test('gare de Novomirsk : les trois images fournies sont raccordées', () => {
  const G = 'centre-multinodal-luthecia';
  assert.equal(piece(G, 'hall_gare').imageUrl, 'images/Sovarka/Novomirsk/novo-gare-hall-chef-de-gare.webp');
  assert.equal(piece(G, 'hall_douanes').imageUrl, 'images/Sovarka/Novomirsk/novo-gare-hall-douanes.webp');
  assert.equal(piece(G, 'zone_embarquement').imageUrl, 'images/Sovarka/Novomirsk/novo-gare-zone-embarquement.webp');
  for (const r of ['hall_gare', 'hall_douanes', 'zone_embarquement']) existe(piece(G, r).imageUrl);
  // La description de Républia (« Prosper Tampon ») ne s'affiche plus à Novomirsk.
  assert.doesNotMatch(piece(G, 'hall_douanes').desc, /Prosper Tampon/);
  assert.match(piece(G, 'hall_douanes').desc, /Prokhor Rybakov/);
});

test('Prokhor Rybakov : aux douanes, portrait raccordé, frère cadet de Matveï, demande de ses nouvelles', () => {
  const p = piece('centre-multinodal-luthecia', 'hall_douanes');
  assert.equal(photo(p, 'Inspecteur Prokhor Rybakov (PNJ)'), 'images/Sovarka/Novomirsk/novo-prokhor-rybakov-portrait.webp');
  assert.equal(p.persons.find(q => q.name === 'Inspecteur Prokhor Rybakov (PNJ)').profilId, 'sovarka_inspecteur_prokhor_rybakov');
  const f = fiche('sovarka_inspecteur_prokhor_rybakov');
  assert.match(f, /FRÈRE CADET DE MATVEÏ RYBAKOV/);
  assert.match(f, /KRASNOV/);
  assert.match(f, /nouvelles de ton frère/);
  assert.match(f, /loupe/); assert.match(f, /cornichons/);
});

test('Direction du Renseignement : cinq PNJ à leur place, avec portrait et fiche de dialogue', () => {
  const R = 'siege-renseignement', D = 'images/Sovarka/Novomirsk/';
  const attendus = [
    ['accueil_renseignement', 'Sergent Viktor Muetov (PNJ)', 'novo-viktor-muetov-portrait.webp', 'sergent_viktor_muetov'],
    ['accueil_renseignement', 'Elena Diamentevia (PNJ)', 'novo-elena-diamentevia-portrait.webp', 'elena_diamentevia'],
    ['salle_ecoutes', 'Tamara Naouchnikova (PNJ)', 'novo-tamara-naouchnikova-portrait.webp', 'tamara_naouchnikova'],
    ['salle_interrogatoire_renseignement', 'Colonel Oleg Doprossov (PNJ)', 'novo-oleg-doprossov-portrait.webp', 'colonel_oleg_doprossov'],
    ['salle_interrogatoire_renseignement', 'Fiodor Koulakov (PNJ)', 'novo-fiodor-koulakov-portrait.webp', 'fiodor_koulakov']
  ];
  for (const [r, nom, img, id] of attendus) {
    assert.equal(photo(piece(R, r), nom), D + img); existe(D + img); fiche(id);
  }
  assert.match(fiche('colonel_oleg_doprossov'), /Parlez, s'il vous plaît/);
  assert.match(fiche('colonel_oleg_doprossov'), /n'élèves JAMAIS la voix/);
  assert.match(fiche('fiodor_koulakov'), /Le Colonel est de mauvaise humeur ce matin, faites attention, après c'est moi qui vais en pâtir\./);
});

test("salle d'interrogatoire : description d'après l'image, aucun miroir sans tain", () => {
  const d = piece('siege-renseignement', 'salle_interrogatoire_renseignement').desc;
  assert.doesNotMatch(d, /miroir/i);
  assert.match(d, /cave de pierre/); assert.match(d, /chaînes/); assert.match(d, /chaise de contention/);
});

test('église de Novomirsk : portraits du Pontife et de Frère Kolkhoze (512 × 512) et fiches', () => {
  const p = piece('kolkhoze-spirituel', 'grange_sainte'), D = 'images/Sovarka/Novomirsk/';
  for (const [nom, img, id] of [['Camarade Pontife Tractorenko (PNJ)', 'novo-pontife-tractorenko-portrait.webp', 'camarade_pontife_tractorenko'],
                                ['Frère Kolkhoze (PNJ)', 'novo-frere-kolkhoze-portrait.webp', 'frere_kolkhoze']]) {
    assert.equal(photo(p, nom), D + img); existe(D + img);
    // En-tête RIFF/WEBP ; dimensions lues dans le bloc VP8 (avec perte).
    const b = fs.readFileSync(path.join(root, D + img));
    assert.equal(b.toString('ascii', 8, 12), 'WEBP');
    const i = b.indexOf('VP8 ');
    assert.ok(i > 0, 'webp avec perte attendu');
    assert.equal(b.readUInt16LE(i + 14) & 0x3fff, 512); assert.equal(b.readUInt16LE(i + 16) & 0x3fff, 512);
    assert.match(fiche(id), /trait:/);
  }
});

// ── Renommages liés à la base (dernier commit du bloc 6 ; SQL : migrations/20261123230000_renommages_pnj_finale.sql, appliquée le 23/11/2026) ──
test('gare : Vassili Sukhoï au hall principal, Lioudmila Proverkina aux douanes avec Prokhor Rybakov, portraits raccordés', () => {
  const G = 'centre-multinodal-luthecia', D = 'images/Sovarka/Novomirsk/';
  const hall = piece(G, 'hall_gare'), douanes = piece(G, 'hall_douanes');
  assert.deepEqual(hall.persons.map(p => p.name), ['Vassili Sukhoï (PNJ)']);
  assert.equal(hall.persons[0].job, 'chef_gare');
  assert.deepEqual(douanes.persons.map(p => p.name), ['Lioudmila Proverkina (PNJ)', 'Inspecteur Prokhor Rybakov (PNJ)']);
  assert.equal(douanes.persons[0].role, 'Agente de contrôle');
  assert.equal(photo(hall, 'Vassili Sukhoï (PNJ)'), D + 'novo-vassili-sukhoi-portrait.webp');
  assert.equal(photo(douanes, 'Lioudmila Proverkina (PNJ)'), D + 'novo-lioudmila-proverkina-portrait.webp');
  assert.match(hall.desc, /Vassili Sukhoï/);
  assert.match(douanes.desc, /Lioudmila Proverkina/);
  fiche('vassili_sukhoi'); fiche('lioudmila_proverkina');
});

test('anciens noms disparus du jeu (R4) et graphie « Sukhoï » jamais « corrigée »', () => {
  const fichiers = ['data.js', 'plateau-core.js', 'api/_pnj-personnalites.js', 'api/_pnj-scenes-generes.js', 'api/_pnj-sovarka-genere.js'];
  for (const f of fichiers) {
    const s = lire(f);
    for (const ancien of ['Camarade Horaire', 'Agente Nadejda', 'Nadejda Contrôle']) {
      // Seules mentions admises : les commentaires qui retracent le renommage (« ex-« Agente Nadejda » »).
      const hors = s.split('\n').filter(l => l.includes(ancien) && !/^\s*\/\//.test(l));
      assert.deepEqual(hors, [], ancien + ' encore dans ' + f);
    }
    assert.ok(!/Soukho/.test(s.split('\n').filter(l => !/^\s*\/\//.test(l)).join('\n')), '« Soukhoï » dans ' + f + ' : la graphie voulue est « Sukhoï »');
  }
  assert.ok(lire('plateau-core.js').includes("'Vassili Sukhoï': { trait:"));
  assert.ok(lire('plateau-core.js').includes("'Lioudmila Proverkina': { trait:"));
});

test('référentiel des informateurs : les deux PNJ renommés sont posés par le fragment SQL de la migration finale', () => {
  const { lignes } = require(path.join(root, 'outils/generateurs/generer-informateurs-lieux.cjs'));
  const ids = lignes().map(x => x.id).filter(id => id.startsWith('soviet:capitale:centre-multinodal-luthecia:'));
  assert.deepEqual(ids, ['soviet:capitale:centre-multinodal-luthecia:hall_douanes:Lioudmila Proverkina',
                         'soviet:capitale:centre-multinodal-luthecia:hall_gare:Vassili Sukhoï']);
  const sql = lire('migrations/20261123230000_renommages_pnj_finale.sql');
  assert.match(sql, /^-- (NON )?APPLIQUÉE/m);
  for (const id of ids) assert.ok(sql.includes("SET id = '" + id + "'"), id);
  assert.match(sql, /WHERE id = 'soviet:capitale:centre-multinodal-luthecia:hall_gare:Camarade Horaire'/);
  assert.match(sql, /WHERE id = 'soviet:capitale:centre-multinodal-luthecia:hall_gare:Agente Nadejda'/);
  assert.match(sql, /piece = 'hall_douanes'/);
  assert.ok(!fs.readdirSync(path.join(root, 'migrations')).some(f => /bloc6/.test(f)), 'pas de migration autonome du bloc 6');
});
