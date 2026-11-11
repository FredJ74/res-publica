#!/usr/bin/env node
// Régénère les trois catalogues du référentiel (demande de Fred, 10/11/2026) :
//   referentiel-game-design/CATALOGUE-BATIMENTS-PIECES-ORDRES.md  (BUILDINGS de data.js, chargé en vm)
//   referentiel-game-design/CATALOGUE-COUTS-SERVEUR.md            (relevé de production ordres_couts)
//   referentiel-game-design/CROISEMENT-CATALOGUES.md               (croisement des deux)
// Usage : node outils/referentiel/generer_catalogues.cjs <SHA> <relevé.tsv> <date lisible>
// Le relevé de production est un fichier TSV (fn, pa, cost) obtenu par SELECT DISTINCT en lecture seule.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const racine = path.resolve(__dirname, '../..');
const [sha, releve, dateLisible] = process.argv.slice(2);
if (!sha || !releve || !dateLisible) { console.error('usage : generer_catalogues.cjs <SHA> <relevé.tsv> <date>'); process.exit(2); }
const court = sha.slice(0, 8);
const lien = l => `[L${l}](https://github.com/FredJ74/res-publica/blob/${sha}/data.js#L${l})`;
const sortC = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

// --- data.js : structure par évaluation, lignes par recherche séquentielle -----------------
const src = fs.readFileSync(path.join(racine, 'data.js'), 'utf8');
const ctx = { window: {}, console, navigator: {}, localStorage: { getItem() { return null; }, setItem() {} },
  document: { addEventListener() {}, getElementById() { return null; }, querySelector() { return null; } } };
ctx.self = ctx.window;
vm.createContext(ctx);
vm.runInContext(src + ';globalThis.__B = BUILDINGS;', ctx);
const B = ctx.__B;

const debutLigne = [0];
for (let i = 0; i < src.length; i++) if (src[i] === '\n') debutLigne.push(i + 1);
const ligneDe = pos => { let lo = 0, hi = debutLigne.length - 1; while (lo < hi) { const m = (lo + hi + 1) >> 1; if (debutLigne[m] <= pos) lo = m; else hi = m - 1; } return lo + 1; };
const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const chercher = (re, depuis, jusqua) => { re.lastIndex = depuis; const m = re.exec(src); return m && m.index < jusqua ? m.index : -1; };

const debutB = src.indexOf('const BUILDINGS = {');
const cles = Object.keys(B);
const posB = [];
let cur = debutB;
for (const k of cles) {
  const p = chercher(new RegExp(`\\n\\s*['"]?${esc(k)}['"]?\\s*:\\s*\\{`, 'g'), cur, src.length);
  posB.push(p); if (p >= 0) cur = p + 1;
}
const declarations = [];
const repertoire = [];
cles.forEach((k, i) => {
  const b = B[k] || {};
  const rooms = b.rooms || {};
  const deb = posB[i] >= 0 ? posB[i] : debutB;
  const fin = (posB.slice(i + 1).find(p => p >= 0)) || src.length;
  let refs = 0, pos = deb;
  const pieces = Array.isArray(rooms) ? rooms.map(r => [r && r.id, r]) : Object.entries(rooms);
  for (const [rid, room] of pieces) {
    const pr = rid ? chercher(new RegExp(`['"]?${esc(String(rid))}['"]?\\s*:`, 'g'), pos, fin) : -1;
    if (pr >= 0) pos = pr;
    for (const o of (room && Array.isArray(room.orders) ? room.orders : [])) {
      if (!o || !o.fn) continue;
      refs++;
      const pf = chercher(new RegExp(`fn\\s*:\\s*['"]${esc(o.fn)}['"]`, 'g'), pos, fin);
      if (pf >= 0) pos = pf + 1;
      let source = pf >= 0 ? lien(ligneDe(pf)) : null;
      if (!source) {
        const pg = chercher(new RegExp(`fn\\s*:\\s*['"]${esc(o.fn)}['"]`, 'g'), 0, src.length);
        source = pg >= 0 ? `déclaration partagée ${lien(ligneDe(pg))}` : `ordre construit (bâtiment ${lien(ligneDe(deb))})`;
      }
      declarations.push([k, rid, o.fn, source]);
    }
  }
  repertoire.push([k, ligneDe(deb), pieces.length, refs]);
});
const nbPieces = repertoire.reduce((s, r) => s + r[2], 0);
const sansOrdre = repertoire.filter(r => r[3] === 0);

let md = `# Catalogue des bâtiments, pièces et ordres — source statique data.js

**Extraction technique du ${dateLisible}** (\`outils/referentiel/generer_catalogues.cjs\`). Périmètre **uniquement** l'objet littéral \`BUILDINGS\` dans [\`data.js\`](../data.js), version [\`${court}\`](https://github.com/FredJ74/res-publica/blob/${sha}/data.js), évalué tel que le jeu le charge. Les déclarations dynamiques (\`WORLD\`, \`buildingContext\`, \`RP_ORDRES_DYNAMIQUES\` des fichiers \`plateau-*.js\`, comme « Fouiller les lieux » ou « Équipements et serrure »), les variantes de pièces ou les routes serveur peuvent modifier les lieux réellement affichés.

**${cles.length} clés de bâtiments**, **${nbPieces} clés de pièces** et **${declarations.length} références \`fn\`** situées par cette analyse (relevé précédent, 09/11 au SHA \`a8bd5e26\` : 110 / 303 / 956).

**Avertissement** : l'ordre peut être un menu, une action grisée, une fonction conditionnelle, un double emploi ou une entrée dans une ville non jouable ; la présence dans la liste ne certifie aucune interaction. Les lignes de source permettent de poursuivre jusqu'au handler, au contrôle serveur et au test.

## Localisation de chaque déclaration

| Bâtiment | Pièce | Fonction \`fn\` | Source |
|---|---|---|---|
`;
for (const [k, r, fn, s] of declarations) md += `| \`${k}\` | \`${r}\` | \`${fn}\` | ${s} |\n`;
md += `
## Répertoire des bâtiments

Un bâtiment ou une pièce sans ordre dans \`data.js\` peut être purement social, visuel ou géré dans un autre module. Ils ne sont **pas** automatiquement des bâtiments inachevés. Bâtiments sans aucun ordre déclaré : **${sansOrdre.length}**.

`;
for (const [k, l, n, refs] of repertoire) md += `- [\`${k}\`](https://github.com/FredJ74/res-publica/blob/${sha}/data.js#L${l}) : ${n} pièce${n > 1 ? 's' : ''}, ${refs} référence${refs > 1 ? 's' : ''} d'ordres\n`;
md += `
## Limites du découpage automatique

- La structure vient de l'évaluation de \`data.js\` ; les numéros de ligne viennent d'une recherche séquentielle dans le bloc du bâtiment. Un ordre repris d'une constante commune pointe sa « déclaration partagée » ; sans aucun littéral \`fn:\` dans le fichier, il est signalé « ordre construit ».
- L'extraction ne vérifie ni les villes associées à chaque bâtiment, ni les filtres d'apparition, ni les extensions injectées par \`plateau-*.js\` après la déclaration.
- Pour l'audit de la géographie, rapprocher ces identifiants de \`WORLD\`, \`VILLES\`, \`plateau-navigation.js\` et des positions/réseaux en base ; une présence dans \`BUILDINGS\` n'implique pas une entrée accessible à pied.
- Les liens pointent le **SHA figé de l'extraction**, non la version future de \`main\`.
`;
fs.writeFileSync(path.join(racine, 'referentiel-game-design/CATALOGUE-BATIMENTS-PIECES-ORDRES.md'), md);

// --- Coûts de production -----------------------------------------------------------------
const couts = fs.readFileSync(path.resolve(releve), 'utf8').split('\n')
  .filter(l => l && !l.startsWith('#') && !l.startsWith('fn\t'))
  .map(l => { const [fn, pa, cost] = l.split('\t'); return { fn, pa: +pa, cost: +cost }; })
  .sort((a, b) => sortC(a.fn, b.fn) || a.pa - b.pa || a.cost - b.cost);
let mc = `# Coûts des ordres enregistrés en production — catalogue en lecture seule

**Source :** table de configuration \`public.ordres_couts\` de Supabase \`res-publica\`, relevée le ${dateLisible} en **SELECT DISTINCT** (${couts.length} triplets ; relevé brut : \`${path.relative(racine, path.resolve(releve))}\`). Montants configurés, non preuve d'affichage, de permission ou de fonctionnement. Les empires peuvent posséder des règles spéciales ; les tarifs nationaux de Sovarka sont dans \`ordres_couts_pays\`.

| Identifiant de fonction | PA configurés | Coût numérique configuré |
|---|---:|---:|
`;
for (const c of couts) mc += `| \`${c.fn}\` | ${c.pa} | ${c.cost} |\n`;
mc += `\n**Note :** l'unité monétaire varie selon le pays et la mécanique. Les fonctions avec suffixe \`#...\` peuvent représenter des variantes techniques, pas des boutons autonomes. Ce tableau n'est pas un certificat de jouabilité.\n`;
fs.writeFileSync(path.join(racine, 'referentiel-game-design/CATALOGUE-COUTS-SERVEUR.md'), mc);

// --- Croisement --------------------------------------------------------------------------
const sansCommentaires = src.replace(/\/\*[\s\S]*?\*\//g, m => m.replace(/[^\n]/g, ' '))
  .split('\n').map(l => (l.trim().startsWith('//') ? '' : l)).join('\n');
const occ = new Map();
for (const m of sansCommentaires.matchAll(/fn\s*:\s*['"]([^'"]+)['"]/g)) occ.set(m[1], (occ.get(m[1]) || 0) + 1);
const totalDecl = [...occ.values()].reduce((s, n) => s + n, 0);
const fnCouts = new Set(couts.map(c => c.fn));
const direct = couts.filter(c => occ.has(c.fn)).length;
const sansCout = [...occ.keys()].filter(f => !fnCouts.has(f)).sort(sortC);
let mx = `# Croisement des identifiants d'ordres — source client et prix serveur

**Instantané (${dateLisible})** : \`data.js\` au commit \`${court}\` versus configuration Supabase \`ordres_couts\` relevée par \`SELECT\`. Extraction des seuls identifiants \`fn: '...'\` ou \`fn: "..."\` **hors commentaires**. Les variantes dynamiques, les autres fichiers, la disponibilité et les permissions ne sont pas inférées.

## Totaux et précautions

- **${totalDecl} déclarations \`fn:\` non commentées** dans \`data.js\`, regroupées sous **${occ.size} identifiants distincts**.
- **${couts.length} entrées de coûts** sur Supabase, dont **${direct} correspondances nominales directes** et **${couts.length - direct} non retrouvées** selon ce critère. Une absence peut être normale pour une variante \`#reussite\`, un dispatch dynamique ou un ordre déclaré dans un fichier \`plateau-*.js\`.
- **${sansCout.length} identifiants non commentés côté client** sans entrée directe de coût (menus / prestations gratuites / mécanismes externes possibles).
- Une concordance de nom ne démontre ni emplacement réellement accessible, ni respect du coût, ni résultat serveur. Ne supprimer aucun coût sur cette seule comparaison.

## Correspondance par identifiant

| Fonction de coût serveur | PA configurés | Coût numérique configuré | Occurrences client non commentées |
|---|---:|---:|---:|
`;
for (const c of couts) mx += `| \`${c.fn}\` | ${c.pa} | ${c.cost} | ${occ.get(c.fn) || '—'} |\n`;
mx += `\n## Identifiants de data.js sans coût serveur nominal\n\nCette liste n'est pas une liste de bogues. Ces identifiants exigent une lecture du routeur, de l'éventuelle RPC et de l'interface.\n\n`;
for (const f of sansCout) mx += `- \`${f}\` (${occ.get(f)} déclaration${occ.get(f) > 1 ? 's' : ''})\n`;
mx += `\n## Méthode de certification suivante\n\nReconstituer \`pays → ville → bâtiment → pièce → fn → handler → autorité → débit → effet → test → recette\` pour chaque ordre réellement proposé. Les ${couts.length} tarifs comprennent des noms techniques et ne représentent ni ${couts.length} commandes disponibles, ni toutes les commandes possibles.\n`;
fs.writeFileSync(path.join(racine, 'referentiel-game-design/CROISEMENT-CATALOGUES.md'), mx);

console.log(JSON.stringify({ batiments: cles.length, pieces: nbPieces, references: declarations.length,
  construits: declarations.filter(d => d[3].startsWith('ordre construit')).length, partages: declarations.filter(d => d[3].startsWith('déclaration partagée')).length, sansOrdre: sansOrdre.length,
  couts: couts.length, declarationsFn: totalDecl, identifiants: occ.size, direct, sansCout: sansCout.length }));
