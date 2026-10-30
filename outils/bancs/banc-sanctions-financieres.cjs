// Banc : une seule primitive pour les sanctions financières + non-régression du budget national.
// Les essais PostgreSQL jetables (transactions annulées) sont consignés dans RELAIS.md.
const fs = require('fs'), path = require('path');
const R = path.join(__dirname, '..', '..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const s = lire('migrations/20261030140000_sanctions_financieres_communes.sql');
const b = lire('migrations/20261030135000_budget_national_credits_serveur.sql');
const g = lire('migrations/20261030110000_budget_national_et_fraude.sql');
const c = lire('api/cron-minuit.js');
let n = 0, ko = 0; const t = (nom, ok) => { n++; if (!ok) ko++; console.log((ok ? 'ok   ' : 'ECHEC') + ' ' + nom); };

// Contrat commun
t('contrat : reference, origine, pays, debiteur, montant, destinataire',
  /sanction_financiere_imposer_interne\(\s*p_reference text, p_origine text, p_pays text, p_debiteur text, p_montant integer, p_destinataire text DEFAULT 'tresor'\)/.test(s));
t('une sanction par reference ; reprise = aucune seconde sanction', /ON CONFLICT \(jugement_id\) DO NOTHING RETURNING true INTO cree/.test(s) && /'deja_enregistree', cree IS NOT TRUE/.test(s));
t('meme reference avec d autres donnees : refusee', /'reference_deja_utilisee'/.test(s));
t('prelevement immediat seulement a la creation', /IF cree THEN\s+pris := public\.amende_prelever_interne\(p_reference\)/.test(s));
t('montant borne et strictement positif', /p_montant <= 0 OR p_montant > 100000000/.test(s));
t('destinataire : Tresor du pays ou caisse existante', /'tresor_introuvable'/.test(s) && /'caisse_introuvable'/.test(s) && /'destinataire_invalide'/.test(s));
t('jamais de debit sans destinataire valide (verifie avant)', s.indexOf("IF NOT FOUND THEN RETURN 0; END IF;") < s.indexOf('helvetia_debiter_fonds_ordinaires(a.condamne, pris)'));
t('versement en caisse par le moteur commun, refus = annulation', /caisse_institution_mouvement\(substr\(a\.destinataire, 8\), pris, true\)/.test(s) && /RAISE EXCEPTION 'sanction_versement_refuse'/.test(s));
t('reserve au serveur : aucun droit ecran', /REVOKE ALL ON FUNCTION public\.sanction_financiere_imposer_interne\(text,text,text,text,integer,text\) FROM PUBLIC, anon, authenticated/.test(s)
  && /REVOKE ALL ON FUNCTION public\.amende_prelever_interne\(text\) FROM PUBLIC, anon, authenticated/.test(s));
t('fraude electorale : ancien point d entree branche sur le contrat', /amende_imposer_interne[\s\S]*sanction_financiere_imposer_interne\(p_id/.test(s) && /amende_imposer_interne\(''fraude-''/.test(g));
t('recouvrement nocturne inchange (minuit_amendes)', /sbRpc\('minuit_amendes'/.test(c));

// Raccordements
t('decouverte nocturne : plus de retrait sec de arg, reference par crime', /coalesce\(arg, 0\) - v_amende\) WHERE name = r\.name;',/.test(s) && /''decouverte-'' \|\| r\.name \|\| ''-'' \|\| coalesce\(t ->> ''id''/.test(s));
t('vol rate : contravention 300 FR (Republia) et amende 100 FR (Union sovietique) au Tresor', /v_moi, 300, ''tresor''/.test(s) && /v_moi, 100, ''tresor''/.test(s));
t('vol rate : le racket du cartel n est pas touche', !/v_perte/.test(s.split('-- =====')[2] || ''));
t('raccords en place : fragment unique sinon arret', /fragment_introuvable_decouverte/.test(s) && /fragment_introuvable_vol_%/.test(s));

// Budget national (non-regression)
t('budget : la garde distingue l ecran par current_user (credits des fonctions serveur conserves)',
  /'IF current_user NOT IN \(''authenticated'', ''anon''\) THEN RETURN coalesce\(NEW, OLD\); END IF;'/.test(b) && /ALTER FUNCTION public\.budgets_nationaux_ecran_fusionner\(\) SECURITY INVOKER/.test(b));
t('budget : registre toujours illisible, seuls les noms de rubriques sont fournis', /budget_national_rubriques_ecran\(\)\s+RETURNS text\[\]/.test(b) && /SECURITY DEFINER/.test(b) && !/GRANT SELECT/.test(b));
t('budget : fusion, defauts et suppression refusee conserves', /base := coalesce\(OLD\.data/.test(g) && /TG_OP = 'DELETE' THEN RAISE EXCEPTION/.test(g));
t('ordre : correctif budget avant les sanctions', '20261030135000' < '20261030140000');

console.log(`\n${n - ko}/${n} tests passes`); process.exit(ko ? 1 : 0);
