-- Lecture exclusivement. A faire par l'agent via un acces catalogue autorise, pas par le game designer.
-- Aucune preuve de production n'est acquise tant que ces resultats ne sont pas disponibles.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT current_database() AS base, current_user AS role_catalogue, version() AS version;
SELECT table_schema,table_name,column_name,data_type,domain_name,is_nullable,column_default
 FROM information_schema.columns WHERE table_schema='public'
 AND (column_name IN ('arg','liquide','banque','solde','montant','montant_final','montant_initial','montant_restant','mensualite','inventory_revision','revision_financiere')
 OR table_name IN ('hg_fin_requetes','hg_fin_actes_en_cours'))
 ORDER BY table_name,ordinal_position;
-- Definitions reelles : comparees aux fichiers prepares, jamais aux seules empreintes declarees.
SELECT p.oid::regprocedure::text AS signature,p.prosecdef,p.proconfig,p.provolatile,
 pg_get_functiondef(p.oid) AS definition,p.proacl
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prokind='f'
 AND (p.proname ~ '^(hg_fin_|hg_fr_|inventaire_|fret_|helvetia_)'
 OR p.proname IN ('personnages_vue_modifier','prelever_loyer_bail','payer_ordre','succession_regler',
 'ouvrir_compte_helvetia','deposer_helvetia','retirer_helvetia','fermer_compte_helvetia',
 'creer_placement_helvetia','creer_pret_helvetia','rembourser_pret_helvetia_integral','accepter_accord_helvetia','batiment_caisse_mouvement'))
 ORDER BY signature;
SELECT c.relname,c.relkind,c.relrowsecurity,c.relforcerowsecurity,c.relacl,c.reloptions,
 pg_get_userbyid(c.relowner) AS proprietaire
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'
 AND c.relname IN ('personnages','personnages_donnees','dons_en_attente','dons_requetes','prets','comptes_bancaires','placements_bancaires','caisses_fret','contenu_caisses_fret','batiments_etat','objets_recus');
SELECT t.tgrelid::regclass::text AS relation,t.tgname,t.tgenabled,pg_get_triggerdef(t.oid) AS definition
 FROM pg_trigger t WHERE NOT t.tgisinternal AND t.tgrelid IN
 ('public.personnages'::regclass,'public.personnages_donnees'::regclass,'public.comptes_bancaires'::regclass,'public.dons_en_attente'::regclass);
SELECT * FROM pg_policies WHERE schemaname='public' AND tablename IN
 ('personnages_donnees','dons_en_attente','comptes_bancaires','prets','caisses_fret','contenu_caisses_fret','batiments_etat','objets_recus');
SELECT d.classid::regclass::text,d.objid,pg_describe_object(d.classid,d.objid,d.objsubid) AS dependance,
 pg_describe_object(d.refclassid,d.refobjid,d.refobjsubid) AS objet_reference
 FROM pg_depend d WHERE d.refobjid IN ('public.personnages'::regclass,'public.personnages_donnees'::regclass,
 'public.comptes_bancaires'::regclass,'public.prets'::regclass,'public.placements_bancaires'::regclass);
-- Statistiques agregees : aucun nom, aucun solde individuel, aucune modification de donnees.
SELECT 'personnages_donnees' AS source,count(*) AS lignes,
 count(*) FILTER(WHERE arg::text IN ('NaN','Infinity','-Infinity') OR arg<>trunc(arg,2)
  OR liquide::text IN ('NaN','Infinity','-Infinity') OR liquide<>trunc(liquide,2)
  OR banque::text IN ('NaN','Infinity','-Infinity') OR banque<>trunc(banque,2)) AS montants_invalides,
 sum(arg::numeric)::text AS somme_arg_fr,sum(liquide::numeric)::text AS somme_liquide_fr,sum(banque::numeric)::text AS somme_banque_fr
 FROM public.personnages_donnees;
SELECT 'comptes_bancaires' AS source,count(*) AS lignes,
 count(*) FILTER(WHERE solde::text IN ('NaN','Infinity','-Infinity') OR solde<>trunc(solde,2)) AS montants_invalides,
 sum(solde)::text AS somme_fr FROM public.comptes_bancaires;
SELECT 'prets' AS source,count(*) AS lignes,
 count(*) FILTER(WHERE montant_initial<>trunc(montant_initial,2) OR montant_restant<>trunc(montant_restant,2) OR mensualite<>trunc(mensualite,2)
 OR montant_initial::text IN ('NaN','Infinity','-Infinity') OR montant_restant::text IN ('NaN','Infinity','-Infinity') OR mensualite::text IN ('NaN','Infinity','-Infinity')) AS montants_invalides
 FROM public.prets;
SELECT 'placements_bancaires' AS source,count(*) AS lignes,
 count(*) FILTER(WHERE montant<>trunc(montant,2) OR montant_final<>trunc(montant_final,2)
 OR montant::text IN ('NaN','Infinity','-Infinity') OR montant_final::text IN ('NaN','Infinity','-Infinity')) AS montants_invalides
 FROM public.placements_bancaires;
ROLLBACK;
