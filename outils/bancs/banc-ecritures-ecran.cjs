// Banc de non-régression : écritures de l'écran sur prets et budgets_municipaux (29/10/2026).
// Vérifie que la migration garde ce qu'elle doit garder et que l'écran n'écrit que ce que la
// garde laisse passer. Répétition serveur (transaction annulée) : voir ECRITURES-ECRAN-20261029.md.
const fs = require('fs'), path = require('path');
const R = path.join(__dirname, '..', '..');
const lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const mig = lire('migrations/20261029200000_prets_budgets_municipaux_gardes.sql');
const perso = lire('plateau-personnage.js'), poli = lire('plateau-politique.js'), sb = lire('supabase.js');
const tous = fs.readdirSync(R).filter(f => f.endsWith('.js')).map(f => lire(f)).join('\n');
let ko = 0, n = 0;
const t = (nom, ok) => { n++; if (!ok) ko++; console.log((ok ? 'ok   ' : 'ECHEC') + ' ' + nom); };
t('garde prets sur INSERT, UPDATE et DELETE', /BEFORE INSERT OR UPDATE OR DELETE ON public\.prets/.test(mig));
t('prets : seule exception = ses propres prets en succession, rien d autre ne bouge',
  /OLD\.emprunteur = public\.mon_personnage\(\)/.test(mig) && /NEW\.statut = 'succession'/.test(mig)
  && /\(to_jsonb\(NEW\) - 'statut'\) = \(to_jsonb\(OLD\) - 'statut'\)/.test(mig));
t('garde budgets_municipaux sur INSERT et UPDATE', /BEFORE INSERT OR UPDATE ON public\.budgets_municipaux/.test(mig));
t('budget : creation limitee a key + tauxFoncier 0.05', /\(NEW\.data - 'key' - 'tauxFoncier'\) = '\{\}'::jsonb/.test(mig) && /= 0\.05/.test(mig));
t('budget : upsert d une ligne existante renvoye a la garde UPDATE', /IF EXISTS \(SELECT 1 FROM public\.budgets_municipaux b WHERE b\.id = NEW\.id\)/.test(mig));
t('budget : seule manifestationInterdite peut changer', /\(NEW\.data - 'manifestationInterdite'\) IS DISTINCT FROM \(OLD\.data - 'manifestationInterdite'\)/.test(mig));
t('budget : manifestationInterdite reservee au ministre de l Interieur', /mon_poste_est_dans\('min_int', v_pays\)/.test(mig));
t('les appels serveur restent libres (cron, RPC)', (mig.match(/est_appel_serveur\(\)/g) || []).length === 2);
// Contrats de l'écran
t('ecran : sbUpdatePret seulement avec { statut: succession }',
  (tous.match(/sbUpdatePret\(/g) || []).length === 2 && /sbUpdatePret\(pret\.id, \{ statut: 'succession' \}\)/.test(perso));
t('ecran : sbCreerPret n est plus appele', !/[^/]\s*await sbCreerPret\(|[;{]\s*sbCreerPret\(/.test(tous.replace(/async function sbCreerPret/, '')));
t('ecran : budget neuf = { key, tauxFoncier: 0.05 }', /function budgetMunicipalNeuf\(key\) \{\s*return \{\s*key,[\s\S]{0,300}?tauxFoncier: 0\.05\s*\};/.test(poli));
t('ecran : sbSaveBudgetMunicipal a exactement 3 appelants', (tous.match(/await sbSaveBudgetMunicipal\(/g) || []).length === 3);
t('ecran : les taux du maire passent par taux_imposition_fixer', /taux_imposition_fixer/.test(tous));
console.log(`\n${n - ko}/${n} tests passes`);
process.exit(ko ? 1 : 0);
