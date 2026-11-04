// node outils/generateurs/rue-ville-serveur.cjs <pays> <ville> <prefixe-noeud> [fichier.sql] [--verifier]
//
// Duplique la COUCHE RUE d'une ville vers le serveur, depuis la seule source : les vues déclarées
// dans plateau-rue-centrale.js (RUE_CENTRALE_NOEUDS[pays]). Rien n'est inventé :
//  - un nœud serveur par vue dont l'identifiant commence par <prefixe-noeud> ;
//  - voisins = destinations des flèches (liens et liensParArrivee), dans le sens déclaré ;
//  - directions = même forme que navigation-directions.cjs ({liens, parArrivee}) ;
//  - une entrée/sortie de bâtiment (rue_sorties_batiments) par zone { type:'batiment', buildingId }
//    (zones et zonesParArrivee). Une zone 'a-venir' n'ouvre rien.
// Le bâtiment doit exister dans navigation_lieux_regles (contrôle à la fin du SQL généré).
// Créé le 04/11/2026 pour Novomirsk (test de duplication du socle sur Sovarka) ; vaut pour
// toute ville qui déclare ses vues.
const fs = require('node:fs'), vm = require('node:vm'), path = require('node:path');
const root = path.resolve(__dirname, '../..');
const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
const [pays, ville, prefixe, sortie] = args;
if (!pays || !ville || !prefixe) throw Error('usage : <pays> <ville> <prefixe-noeud> [fichier.sql] [--verifier]');
const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(root, 'plateau-rue-centrale.js'), 'utf8') + ';globalThis.__N=RUE_CENTRALE_NOEUDS;', ctx);
const noeuds = Object.entries(ctx.__N[pays] || {}).filter(([id]) => id.startsWith(prefixe));
if (!noeuds.length) throw Error('aucune vue ' + prefixe + '* pour ' + pays);
const q = x => "'" + String(x).replace(/'/g, "''") + "'";
const ids = new Set(noeuds.map(([id]) => id));
const lignesNoeuds = [], sorties = new Map();
for (const [id, n] of noeuds) {
  const liens = n.liens || {}, parArrivee = n.liensParArrivee || {};
  const voisins = [...new Set([...Object.values(liens), ...Object.values(parArrivee).flatMap(l => Object.values(l || {}))])];
  for (const v of voisins) if (!ids.has(v)) throw Error(`${id} : voisin ${v} hors de la ville`);
  lignesNoeuds.push(`  (${q(pays)},${q(ville)},${q(id)},ARRAY[${voisins.map(q).join(',')}]::text[],${q(JSON.stringify({ liens, parArrivee }))}::jsonb)`);
  const zones = [...(n.zones || []), ...Object.values(n.zonesParArrivee || {}).flat()];
  for (const z of zones) if (z && z.type === 'batiment' && z.buildingId) sorties.set(z.buildingId + '|' + id, [z.buildingId, id]);
}
const lignesSorties = [...sorties.values()].map(([b, id]) => `  (${q(pays)},${q(ville)},${q(id)},${q(b)})`);
const batiments = [...new Set([...sorties.values()].map(([b]) => b))];
const sql = `-- Généré par outils/generateurs/rue-ville-serveur.cjs ${pays} ${ville} ${prefixe}. Ne pas modifier à la main.
-- Couche rue de la ville au serveur : ${noeuds.length} nœuds, ${lignesSorties.length} entrées de bâtiment (${batiments.length} bâtiments).
-- Idempotente ; ne déplace aucun personnage.
INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions) VALUES
${lignesNoeuds.join(',\n')}
ON CONFLICT(country,city,noeud) DO UPDATE SET voisins=EXCLUDED.voisins,directions=EXCLUDED.directions;

INSERT INTO public.rue_sorties_batiments(country,city,noeud,building) VALUES
${lignesSorties.join(',\n')}
ON CONFLICT DO NOTHING;

DO $$
DECLARE manquants text;
BEGIN
  SELECT string_agg(b, ', ') INTO manquants FROM unnest(ARRAY[${batiments.map(q).join(',')}]::text[]) b
  WHERE NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles l WHERE l.pays=${q(pays)} AND l.ville=${q(ville)} AND l.batiment=b);
  IF manquants IS NOT NULL THEN RAISE EXCEPTION 'batiments_sans_regle_navigation: %', manquants; END IF;
  IF (SELECT count(*) FROM public.rue_noeuds_serveur WHERE country=${q(pays)} AND city=${q(ville)} AND noeud LIKE ${q(prefixe + '%')}) <> ${noeuds.length} THEN
    RAISE EXCEPTION 'noeuds_incomplets'; END IF;
END $$;
`;
if (!sortie) { process.stdout.write(sql); process.exit(0); }
const f = path.resolve(root, sortie);
if (process.argv.includes('--verifier')) { if (fs.readFileSync(f, 'utf8') !== sql) throw Error('Couche rue divergente de plateau-rue-centrale.js : ' + sortie); }
else fs.writeFileSync(f, sql);
console.log(`${noeuds.length} nœuds, ${lignesSorties.length} entrées, ${batiments.length} bâtiments`);
