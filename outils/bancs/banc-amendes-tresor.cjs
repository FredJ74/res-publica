// Banc : amendes prélevées et versées au Trésor national (décisions de Fred, 30/10/2026).
// Répétition serveur en transaction annulée : voir RELAIS.md.
const fs = require('fs'), path = require('path');
const R = path.join(__dirname, '..', '..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const m = lire('historique/migrations-appliquees/20261030100000_amendes_tresor_national.sql'), c = lire('api/cron-minuit.js');
let n = 0, ko = 0; const t = (nom, ok) => { n++; if (!ok) ko++; console.log((ok ? 'ok   ' : 'ECHEC') + ' ' + nom); };
t('une ligne par jugement (cle = jugement), jamais deux amendes', /jugement_id text PRIMARY KEY/.test(m) && /ON CONFLICT \(jugement_id\) DO NOTHING/.test(m));
t('verse au Tresor national par le canal de la taxe nationale (reserveJour)', /'\{reserveJour\}'/.test(m));
t('dette : on prend ce qui existe, le reste attend les rentrees suivantes', /pris := least\(a\.montant - a\.paye, floor\(coalesce\(dispo,0\)\)\)/.test(m) && /statut = CASE WHEN paye \+ pris >= montant THEN 'soldee' ELSE 'due' END/.test(m));
t('au plus un prelevement par jour de Paris et par amende', /a\.dernier_prelevement IS NOT DISTINCT FROM aujourdhui THEN RETURN 0/.test(m));
t('moteur commun de debit (especes puis compte national)', /helvetia_debiter_fonds_ordinaires\(a\.condamne, pris\)/.test(m));
t('appel suspensif : premiere instance suspendue, appel ouvert = rien preleve', /CASE WHEN instance IN \('appel','simplifiee'\) THEN 'due' ELSE 'suspendue' END/.test(m) && /IF coalesce\(appel, false\) THEN CONTINUE; END IF;/.test(m));
t('la decision d appel remplace la premiere instance', /statut = 'remplacee_appel'/.test(m));
t('relaxe : aucune amende', /IN \('relaxe','acquittement','annulation'\) THEN RETURN NEW/.test(m));
t('minuit_amendes reserve au serveur, appelee une fois par passe', /IF NOT public\.est_appel_serveur\(\)/.test(m) && /sbRpc\('minuit_amendes'/.test(c) && /await traiterAmendesServeur\(\);/.test(c));
const g = lire('historique/migrations-appliquees/20261030110000_budget_national_et_fraude.sql');
t('sanction hors tribunal : meme dette et meme canal', /amende_imposer_interne\(p_id text/.test(m) && /'due'\) ON CONFLICT \(jugement_id\) DO NOTHING/.test(m));
t('fraude electorale : amende au Tresor (plus de retrait sec de arg)', /amende_imposer_interne\(''fraude-''\|\|p_fraude_id/.test(g));
t('budget national : l ecran ne garde que les rubriques du registre d autorite', /FROM public\.budget_national_champs_regles r/.test(g) && /base := coalesce\(OLD\.data/.test(g));
t('budget national : garde INVOKER (laisse passer les commandes serveur)', /SECURITY INVOKER/.test(g) && /current_user NOT IN \('authenticated', 'anon'\)/.test(g));
t('budget national : suppression refusee depuis l ecran', /TG_OP = 'DELETE' THEN RAISE EXCEPTION/.test(g));
console.log(`\n${n - ko}/${n} tests passes`); process.exit(ko ? 1 : 0);
