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
t('les fonctions serveur et le cron restent libres', (mig.match(/current_user NOT IN \('authenticated', 'anon'\)/g) || []).length === 2);
// Contrats de l'écran
t('ecran : sbUpdatePret seulement avec { statut: succession }',
  (tous.match(/sbUpdatePret\(/g) || []).length === 2 && /sbUpdatePret\(pret\.id, \{ statut: 'succession' \}\)/.test(perso));
t('ecran : sbCreerPret n est plus appele', !/[^/]\s*await sbCreerPret\(|[;{]\s*sbCreerPret\(/.test(tous.replace(/async function sbCreerPret/, '')));
t('ecran : budget neuf = { key, tauxFoncier: 0.05 }', /function budgetMunicipalNeuf\(key\) \{\s*return \{\s*key,[\s\S]{0,300}?tauxFoncier: 0\.05\s*\};/.test(poli));
t('ecran : sbSaveBudgetMunicipal a exactement 3 appelants', (tous.match(/await sbSaveBudgetMunicipal\(/g) || []).length === 3);
t('ecran : les taux du maire passent par taux_imposition_fixer', /taux_imposition_fixer/.test(tous));

// Mariage (décision de Fred : pas de mariage contre son gré)
const mm = lire('migrations/20261029201000_mariage_par_serveur.sql'), mf = lire('migrations/20261029201100_mariage_fermer_ecran.sql');
t('mariage : officialiser exige une demande acceptee entre les deux', /statut = 'acceptee'[\s\S]{0,200}demandeur = moi AND destinataire = p_conjoint\) OR \(demandeur = p_conjoint AND destinataire = moi/.test(mm) && /'consentement_absent'/.test(mm));
t('mariage : seul le destinataire repond', /dm\.destinataire IS DISTINCT FROM moi/.test(mm));
t('mariage : presence dans la meme piece verifiee au serveur', /p\.current_room IS DISTINCT FROM c\.current_room/.test(mm));
t('mariage : couts par payer_ordre (referentiel)', /payer_ordre\(moi, 'demander_mariage', 1, 0\)/.test(mm) && /payer_ordre\(moi, 'officialiser_mariage', 2, 200\)/.test(mm) && /payer_ordre\(moi, 'demander_divorce', 1, 200\)/.test(mm));
t('mariage : tirage PNJ au serveur', /random\(\)/.test(mm));
t('mariage : veuvage seulement avec succession ouverte', /successions WHERE defunt = moi/.test(mm));
t('mariage : fermeture ecran sur les deux tables', /ON public\.mariages/.test(mf) && /ON public\.demandes_mariage/.test(mf));
t('gardes : distinguent l ecran des fonctions serveur (current_user)', [mig, mf].every(x => /SECURITY INVOKER/.test(x) && /current_user NOT IN \('authenticated', 'anon'\)/.test(x) && !/est_appel_serveur/.test(x.replace(/--.*$/gm, ''))));
t('ecran : plus aucune ecriture directe de mariage', !/(sbCreerMariage|sbUpdateDemandeMariage|sbCreerDemandeMariage|sbDissoudreMariage)\(/.test(tous.replace(/async function sb\w+Mariage\(/g, '')));
t('ecran : plus de tirage PNJ dans le navigateur', (() => { const i = poli.indexOf('async function confirmerDemandeMariage'); const c = poli.slice(i, poli.indexOf('\nasync function ', i + 10)); return i > 0 && !/Math\.random/.test(c) && /mariage_demander/.test(c); })());
t('ecran : les quatre commandes serveur sont appelees', ['mariage_demander', 'mariage_repondre', 'mariage_officialiser', 'mariage_dissoudre'].every(f => tous.includes("'" + f + "'")));
console.log(`\n${n - ko}/${n} tests passes`);
process.exit(ko ? 1 : 0);
