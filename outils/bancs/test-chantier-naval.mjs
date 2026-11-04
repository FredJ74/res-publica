import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const lire = p => readFileSync(new URL('../../'+p,import.meta.url),'utf8');
const migration = lire('migrations/20261104223000_chantier_naval_modeles_devis.sql');

test('deux gabarits et recettes figés par le game designer', () => {
  assert.match(migration,/\('bateau_3',7,3,300,90000,1200,1200,600\)/);
  assert.match(migration,/\('bateau_5',10,5,500,150000,1800,1800,600\)/);
  assert.match(migration,/derives_petrochimiques integer NOT NULL CHECK/);
  assert.match(migration,/public\.batiment_etat_lire\(data\)->'entrepot'->'stock'/);
  assert.match(migration,/id='republic_ville_a_entrepot-logistique-psm'/);
});
test('autorité serveur pour consultation, pas de création de biens ou de dépense', () => {
  assert.match(migration,/WHERE auth\.uid\(\) IS NOT NULL/);
  assert.match(migration,/p\.user_id = auth\.uid\(\)/);
  assert.match(migration,/p\.current_building='chantier-naval'/);
  assert.match(migration,/REVOKE ALL ON public\.chantier_naval_modeles FROM public,anon,authenticated/);
  assert.match(migration,/GRANT EXECUTE ON FUNCTION public\.chantier_naval_devis\(\) TO authenticated/);
  for (const interdit of [/UPDATE public\.personnages_donnees\b/i,/DELETE FROM public\.batiments_etat\b/i,/naval_bateaux\s*\(/i])
    assert.doesNotMatch(migration,interdit);
});
test('ordres en deux salles, même route, achat toujours sous autorité serveur', () => {
  const data = lire('data.js'), router = lire('plateau-router.js'), ui = lire('plateau-naval.js');
  const a = data.indexOf("'chantier-naval': {");
  const b = data.indexOf("'notre-dame-mer': {",a);
  assert.ok(a>=0 && b>a);
  const chantier = data.slice(a,b);
  assert.equal((chantier.match(/fn:'consulter_devis_chantier_naval'/g)||[]).length,2);
  assert.match(router,/if \(fn === 'consulter_devis_chantier_naval'\) \{ ouvrirDevisChantierNaval\(\); return; \}/);
  assert.match(ui,/sbRpcVerdict\('chantier_naval_devis', \{\}/);
  assert.match(ui,/executerReceptionInventaire\('chantier_naval_commander', \{p_modele:modele\}\)/);
  assert.match(lire('plateau-divers.js'),/sessionStorage\.setItem\(cle, JSON\.stringify\(intention\)\)/);
  assert.doesNotMatch(ui,/naval-commande-attente:/);
  assert.match(ui,/commanderBateauNaval/);
  assert.match(lire('baseline/seeds/95_a-regenerer/ordres_couts.sql'),/\('consulter_devis_chantier_naval',0,0\)/);
});

const moteur = lire('migrations/20261104224500_chantier_naval_construction_transactionnelle.sql');
test('construction bloquée sans matériaux, débit seulement sur étape possible', () => {
  assert.match(moteur,/v_stock->>k/);
  assert.match(moteur,/IF disponible<besoin THEN/);
  assert.match(moteur,/etat='bloque_matieres'/);
  const blocage=moteur.indexOf("IF disponible<besoin THEN");
  const paiement=moteur.indexOf("IF NOT public.helvetia_debiter_fonds_ordinaires(p.name,tranche)");
  assert.ok(blocage > 0 && paiement > blocage,'contrôle des matériaux avant la dépense');
  assert.match(moteur,/IF c.dernier_jour=jour THEN/);
  assert.match(moteur,/c.jours_faits\+1=c.jours_total/);
  assert.match(moteur,/GRANT EXECUTE ON FUNCTION public.chantier_naval_avancer_jour\(\) TO service_role/);
  assert.match(moteur,/REVOKE ALL ON FUNCTION public.chantier_naval_avancer_jour\(\) FROM PUBLIC,anon,authenticated/);
  assert.match(moteur,/navigation_active boolean NOT NULL DEFAULT false/);
});
test('le cron prépare la progression après l arrivée en entrepôt', () => {
  const cron = lire('api/cron-minuit.js');
  assert.ok(cron.indexOf("tacheQuotidienne('chantiers_navals'") >
    cron.indexOf("tacheQuotidienne('transits_entrepots'"));
});
