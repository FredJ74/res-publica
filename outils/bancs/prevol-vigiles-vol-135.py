#!/usr/bin/env python3
"""Imprime un prevol de catalogue en lecture seule. Aucun acces reseau, aucun secret.
A executer par l'agent via le connecteur du bon projet, jamais par le game designer.
Reutilise le prevol du moteur commun des interceptions, sans le recopier.
"""
from pathlib import Path
R=Path(__file__).resolve().parents[2]
if __name__=='__main__':
 print((R/'outils/bancs/PREFLIGHT-INTERCEPTION-46.sql').read_text())
 print('''
BEGIN;
SET TRANSACTION READ ONLY;
SELECT signature, to_regprocedure(signature) IS NOT NULL AS presente
FROM unnest(ARRAY['public.mon_personnage()','public.payer_ordre(text,text,integer,integer)',
 'public.pnj_position_effective(text)','public.pnj_quitter_groupe(text[])',
 'public.inventaire_ajouter(jsonb,text,integer,text)',
 'public.inventaire_revision_garder()',
 'public.chantier_commande(text,text,text,jsonb)',
 'public.terrain_chantier_acte(text,text,text,integer,integer)']) signature;
SELECT n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) AS arguments,
 p.prosecdef,p.proconfig,p.proacl,md5(p.prosrc) AS empreinte,pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN
 ('chantier_commande','terrain_chantier_acte','chantier_autorite_exiger_interne',
 'inventaire_revision_garder','inventaire_ajouter','payer_ordre','recherche_inscrire',
 'pnj_position_effective','pnj_quitter_groupe','pnj_prendre','employe_liberer','employeur_embaucher')
ORDER BY p.proname,arguments;
SELECT c.relname,c.relrowsecurity,c.relacl,a.attname,format_type(a.atttypid,a.atttypmod) AS type
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
WHERE n.nspname='public' AND c.relname IN
 ('pnj_membres','pnj_employes_metier','pnj_employeurs','pnj_candidats_catalogue',
 'chantier_commandes_recus','chantier_vigiles_affectations','personnages_donnees','terrains_etat')
ORDER BY c.relname,a.attnum;
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies
WHERE schemaname='public' AND tablename IN
 ('personnages_donnees','terrains_etat','pnj_membres','chantier_commandes_recus','chantier_vigiles_affectations');
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) FROM pg_trigger t
JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN('personnages_donnees','terrains_etat','pnj_membres') AND NOT t.tgisinternal;
SELECT c.relname,k.conname,k.contype,pg_get_constraintdef(k.oid)
FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid
WHERE k.connamespace='public'::regnamespace AND c.relname IN
 ('pnj_membres','pnj_employes_metier','pnj_candidats_catalogue','pnj_employeurs',
 'chantier_commandes_recus','chantier_vigiles_affectations','personnages_donnees','terrains_etat');
-- Identifier les producteurs/consommateurs vivants avant d'adopter un stockage de bonus.
SELECT p.oid::regprocedure::text,p.prosecdef,p.proacl,md5(p.prosrc)
FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.prosrc ~* 'benediction';
-- Ne lit aucun solde, inventaire, identifiant de joueur ou compte auth.
ROLLBACK;
''')
