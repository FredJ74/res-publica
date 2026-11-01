#!/usr/bin/env python3
"""Requêtes SELECT uniquement pour l'intégrateur ; aucun accès Supabase ici."""
import importlib.util,json,re
from pathlib import Path
R=Path(__file__).resolve().parents[2]
def requetes():
 sp=importlib.util.spec_from_file_location('autorite219',R/'outils/baseline/verifier-autorite.py');a=importlib.util.module_from_spec(sp);sp.loader.exec_module(a)
 gm=json.loads((R/'outils/audits/LIVRAISON-GROUPES-219-20261030.json').read_text());om=json.loads((R/'outils/audits/LIVRAISON-ORGANISATIONS-219-20261031.json').read_text())
 noms={'payer_ordre','payer_ordre_interne','helvetia_debiter_fonds_ordinaires','inventaire_sauver_revision','inventaire_revision_garder','inventaire_deposer_interne','mon_personnage','est_mon_personnage','exiger_acteur','est_appel_serveur','sb_save_personnage','banque_nationale_operation','resoudre_placement_helvetia','helvetia_crediter_destination','helvetia_debiter_source','objet_acheter','organisation_ordre_financier','organisation_adhesion_payante','club_supporters_cotiser','club_sponsoriser','club_transfert_conclure','fonds_transit_deposer_interne','fonds_transit_consommer_interne'}
 for e in gm['prerequis']+gm['migrations']+om['migrations']:
  s=(R/e['fichier']).read_text();noms|=a.fonctions_creees_migration(s);noms|=set(re.findall(r"public\.([a-z_][a-z_0-9]*)\(",s))
 if any(not re.fullmatch('[a-z_][a-z_0-9]*',n) for n in noms):raise ValueError('Nom de fonction non littéral')
 citer=lambda x:"'"+x.replace("'","''")+"'"
 tables=('personnages_donnees','personnages','comptes_bancaires','objets_recus','organisations','organisation_commandes_recus','fonds_en_transit','budgets_clubs','transferts_clubs','caisses_collectives_operations')
 tab=','.join(citer(t) for t in tables);fns=','.join(citer(n) for n in sorted(noms))
 registre="""SELECT jsonb_build_object('snapshot',pg_current_snapshot()::text,'releve_utc',now(),'server_version_num',current_setting('server_version_num'),
 'registre',(SELECT jsonb_agg(jsonb_build_object('version',version,'name',name) ORDER BY version) FROM supabase_migrations.schema_migrations));"""
 catalogue="""SELECT jsonb_build_object('snapshot',pg_current_snapshot()::text,'releve_utc',now(),
 'fonctions_publiques',(SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'),
 'fonctions',(SELECT jsonb_agg(jsonb_build_object('schema',n.nspname,'signature',p.oid::regprocedure::text,'arguments',p.proargnames,'defauts',p.pronargdefaults,'retour',p.prorettype::regtype::text,'security_definer',p.prosecdef,'config',p.proconfig,'owner',pg_get_userbyid(p.proowner),'acl',p.proacl::text,'authenticated_execute',has_function_privilege('authenticated',p.oid,'EXECUTE'),'anon_execute',has_function_privilege('anon',p.oid,'EXECUTE'),'md5_corps',md5(p.prosrc),'md5_definition',md5(pg_get_functiondef(p.oid)),'definition',pg_get_functiondef(p.oid)) ORDER BY n.nspname,p.oid::regprocedure::text) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE (n.nspname='public' AND p.proname IN ("""+fns+""")) OR p.oid IN (SELECT t.tgfoid FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace z ON z.oid=c.relnamespace WHERE z.nspname='public' AND c.relname IN ("""+tab+""" ) AND NOT t.tgisinternal)),
 'relations',(SELECT jsonb_agg(jsonb_build_object('table',c.relname,'type',c.relkind,'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,'acl',c.relacl::text,'colonnes',(SELECT jsonb_agg(jsonb_build_object('nom',a.attname,'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull) ORDER BY a.attnum) FROM pg_attribute a WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped)) ORDER BY c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN ("""+tab+""")),
 'triggers',(SELECT jsonb_agg(jsonb_build_object('table',c.relname,'nom',t.tgname,'active',t.tgenabled,'definition',pg_get_triggerdef(t.oid)) ORDER BY c.relname,t.tgname) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN ("""+tab+""" ) AND NOT t.tgisinternal),
 'policies',(SELECT jsonb_agg(to_jsonb(p) ORDER BY p.tablename,p.policyname) FROM pg_policies p WHERE p.schemaname='public' AND p.tablename IN ("""+tab+""")),
 'vue_personnages',(SELECT pg_get_viewdef(c.oid,true) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='personnages' AND c.relkind='v'));"""
 refs=('postes_nommes_regles','ressources_economie','chantiers_paliers','chantiers_besoins_jour','entreprises_constantes','recettes_production','recettes_commerce','commerces_types','commerces_dotations','armureries_dotations','entreprises_prix_rachat','offres_emploi_bne')
 contenus=','.join(citer(t)+",(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]'::jsonb) FROM public."+t+' x)' for t in refs)
 referentiels="""SELECT jsonb_build_object('snapshot',pg_current_snapshot()::text,'releve_utc',now(),
 'couts_controle',(SELECT jsonb_build_object('lignes',count(*),'md5',md5(string_agg(fn||'|'||pa||'|'||cost,E'\\n' ORDER BY fn COLLATE "C",pa,cost))) FROM public.ordres_couts),
 'ordres_couts',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.fn COLLATE "C",x.pa,x.cost),'[]'::jsonb) FROM public.ordres_couts x),
 'couts_sentinelle',(SELECT jsonb_agg(to_jsonb(e)) FROM public.ordres_couts_empreinte e),
 'referentiels',jsonb_build_object("""+contenus+"""));"""
 resultats=[('registre',registre),('catalogue_cible',catalogue),('referentiels',referentiels)]
 for nom,s in resultats:
  if len(s)>12500:raise ValueError('Requête supérieure à la limite : '+nom)
 return resultats
if __name__=='__main__':
 print('# #219 — demande technique de prévol actualisé à ChatGPT\n')
 print('Ces requêtes ne font que lire. Aucun ordre métier, aucun inventaire, aucun solde ni aucun enregistrement auth.users n’est extrait. Ne pas appliquer le paquet. Les sorties de catalogue doivent rester privées hors Git ; transmettre les JSON complets par un canal privé. Le dernier compte rapporté 1 021 (dernière version 20261101134313) reste une indication externe : seul le registre retourné établit la coupe. Les nombres seuls ne remplacent pas les définitions et droits.\n')
 print('La capture historique des 438 coûts ne doit pas être réinjectée : exporter les coûts complets actuels avec leur empreinte et leur sentinelle (439 lignes annoncées, à vérifier). Les autres lignes sont des référentiels de configuration, jamais les entreprises ou personnages des joueurs. Chaque sortie porte sa provenance ; recouper les versions si le catalogue change entre les lectures.\n')
 for nom,s in requetes():print('## '+nom+'\n\n```sql\n'+s+'\n```\n')
