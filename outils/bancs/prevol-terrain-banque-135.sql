-- Post-installation en lecture seule. Agent principal : aucune commande métier ici.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT version,name FROM supabase_migrations.schema_migrations
WHERE version IN('20261024121400','20261024121900','20261024122600','20261024123500','20261024123600','20261024123700','20261024123800','20261024124000','20261024124100','20261024131720','20261024132140','20261024133310','20261024134528','20261024135353') ORDER BY version;
SELECT p.oid::regprocedure::text AS signature,md5(p.prosrc) AS empreinte,p.prosecdef,p.proconfig,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS client_execute,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anonyme_execute,
 has_function_privilege('service_role',p.oid,'EXECUTE') AS serveur_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN
 ('terrain_acquisition_commande','pret_national_contracter_versionne','finance_terrain_banque_recu',
 'terrain_permis_instruction_jour','pret_national_creer_interne','pret_national_jour_traiter','pret_versionne_ecriture_proteger',
 'pret_national_contracter','payer_ordre','terrain_compromis_acte','terrain_proprietaire_muter','compromis_expire_resoudre','terrain_permis_deposer') ORDER BY 1;
SELECT c.relname,c.relrowsecurity,c.relforcerowsecurity,
 has_table_privilege('authenticated',c.oid,'SELECT,INSERT,UPDATE,DELETE') AS client_droit,
 has_table_privilege('anon',c.oid,'SELECT,INSERT,UPDATE,DELETE') AS anonyme_droit
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN
 ('acquisitions_transactions_internes','terrain_acquisitions_recus','prets_ecritures_internes','prets_nationaux_demandes','terrains_referentiel');
SELECT tgname,tgenabled,pg_get_triggerdef(oid) FROM pg_trigger WHERE tgrelid='public.prets'::regclass AND NOT tgisinternal;
-- Agrégats uniquement : ne pas exporter les personnages ou leurs identifiants.
SELECT count(*) AS nouveaux_prets,count(*) FILTER(WHERE montant_initial<>trunc(montant_initial) OR montant_restant<>trunc(montant_restant) OR montant_restant<0) AS montants_invalides,
 count(*) FILTER(WHERE type_banque IS DISTINCT FROM 'nationale') AS banque_incoherente,
 count(*) FILTER(WHERE jour_dernier_prelevement>((statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text)) AS marqueurs_futurs
FROM public.prets WHERE contrat_version=2;
SELECT count(*) AS credits_absents_ou_doubles FROM public.prets p WHERE p.contrat_version=2 AND
 (SELECT count(*) FROM public.fonds_credits_uniques c WHERE c.acteur=p.emprunteur AND c.source='pret_national' AND c.reference=p.id AND c.montant=p.montant_initial)<>1;
SELECT (SELECT count(*) FROM public.acquisitions_transactions_internes) AS capacites_acquisition_residuelles,
 (SELECT count(*) FROM public.prets_ecritures_internes) AS capacites_prets_residuelles;
SELECT type_pret,contrat_version,count(*) FROM public.prets GROUP BY type_pret,contrat_version ORDER BY 1,2;
-- Prévol AVANT activation du cron SQL : aucun dossier actif incomplet ne doit être
-- transformé silencieusement. En cas de compte non nul, examiner ces cas, sans inventer les données.
SELECT count(*) AS permis_actifs,
 count(*) FILTER(WHERE coalesce(data::jsonb#>>'{permis,numeroDossier}','')='' OR coalesce(data::jsonb#>>'{permis,demandeur}','')='' OR coalesce(data::jsonb->>'city','')='') AS dossiers_incomplets,
 count(*) FILTER(WHERE coalesce((data::jsonb#>>'{permis,dureeInstruction}')::numeric,0)<=0) AS durees_absentes
FROM public.terrains_etat WHERE data::jsonb#>>'{permis,statut}' IN('instruction','attente_validation');
ROLLBACK;
