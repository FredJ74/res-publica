#!/usr/bin/env python3
"""Sélection de cinq préparations existantes ; jamais de connexion distante."""
import argparse,hashlib,json,re
from pathlib import Path
R=Path(__file__).resolve().parents[2]
MAN=R/'outils/audits/LIVRAISON-ORGANISATIONS-219-20261031.json'
NOMS=('organisations_commandes_administratives','organisations_adhesions_grades','organisations_progression_elections','organisations_invitations_elections_atomiques','organisations_refus_silencieux')
CONTRATS=('organisation_commande_administrative','organisation_commande_membres','organisation_commande_evenement')

def preparer(destination=None,manifeste=MAN):
 from pglast import parse_sql
 m=json.loads(Path(manifeste).read_text());entrees=m['migrations'];blocs=[]
 if len(entrees)!=5 or [Path(e['fichier']).stem[15:] for e in entrees]!=list(NOMS):raise ValueError('Les cinq préparations sélectionnées seulement, dans leur ordre')
 if m['contrats']!=list(CONTRATS):raise ValueError('Trois contrats exacts requis')
 versions=[e['version'] for e in entrees]
 if versions!=sorted(set(versions)):raise ValueError('Versions distinctes et ordonnées requises')
 for e in entrees:
  p=R/e['fichier'];s=p.read_text()
  if p.parent!=R/'migrations' or not re.fullmatch(r'\d{14}',e['version']) or not p.name.startswith(e['version']+'_'):raise ValueError('Chemin/version de migration invalide')
  if hashlib.sha256(p.read_bytes()).hexdigest()!=e['sha256']:raise ValueError('Empreinte de source modifiée : '+p.name)
  if len(s)>12500:raise ValueError('Source supérieure à la limite documentaire par migration')
  stmts=parse_sql(s)
  if len(stmts)<3 or type(stmts[0].stmt).__name__!='TransactionStmt' or stmts[0].stmt.kind!=parse_sql('BEGIN;')[0].stmt.kind or type(stmts[-1].stmt).__name__!='TransactionStmt' or stmts[-1].stmt.kind!=parse_sql('COMMIT;')[0].stmt.kind:raise ValueError('Transaction externe BEGIN/COMMIT attendue')
  if any(type(x.stmt).__name__=='TransactionStmt' for x in stmts[1:-1]):raise ValueError('Transaction interne interdite')
  # pglast restitue ici des positions dans le texte Python, accents compris.
  corps=s[stmts[1].stmt_location:stmts[-1].stmt_location]
  if any(type(x.stmt).__name__=='TransactionStmt' for x in parse_sql(corps)):raise ValueError('Transaction non retirée')
  blocs.append((e,corps))
 citer=lambda x:"'"+x.replace("'","''")+"'"
 liste=','.join(citer(v) for v in versions)
 sql="""-- PR #219 : complément sélectionné, non autorisé pour la production par cet outil.
-- Les trois commandes et leurs gardes sont indivisibles ; quatre équipements exclus.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='120s';
DO $prevol$ BEGIN
 IF EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version IN ("""+liste+""")) THEN RAISE EXCEPTION 'organisations219_versions_deja_presentes_prevol_requis';END IF;
 IF to_regprocedure('public.mon_personnage()') IS NULL OR to_regprocedure('public.payer_ordre(text,text,integer,integer)') IS NULL THEN RAISE EXCEPTION 'organisations219_dependances_absentes';END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('organisation_commande_administrative','organisation_commande_membres','organisation_commande_evenement')) THEN RAISE EXCEPTION 'organisations219_contrat_preexistant_a_reconcilier';END IF;
END $prevol$;
CREATE TEMP TABLE organisations219_integrite ON COMMIT DROP AS
 SELECT (SELECT md5(coalesce(string_agg(md5(to_jsonb(o)::text),'' ORDER BY o.id),'')) FROM public.organisations o) AS organisations,
 (SELECT md5(coalesce(string_agg(md5(to_jsonb(p)::text),'' ORDER BY p.name),'')) FROM public.personnages_donnees p) AS fiches;
"""
 # La garde financière d'installation est extraite du contrat existant,
 # jamais une deuxième liste de corps acceptés.
 source_evenement=(R/entrees[3]['fichier']).read_text()
 garde=re.search(r" -- Corps examinés :(.*?)END IF;",source_evenement,re.S)
 if garde is None:raise ValueError('Garde financière explicite requise')
 controle=' -- Corps examinés :'+garde.group(1)+'END IF;'
 sql=sql.replace('END $prevol$;',controle.replace('paiement_definition_a_reexaminer','organisations219_paiement_non_examine')+'\nEND $prevol$;',1)
 for e,corps in blocs:
  sql+='\n-- '+e['fichier']+' SHA256 '+e['sha256']+'\n'+corps+'\n'
  sql+='INSERT INTO supabase_migrations.schema_migrations(version,name,statements) VALUES('+citer(e['version'])+','+citer(Path(e['fichier']).stem[15:])+',ARRAY['+citer(corps)+']);\n'
 sql+="""DO $integrite$ DECLARE sig text;BEGIN
 IF (SELECT organisations FROM organisations219_integrite) IS DISTINCT FROM (SELECT md5(coalesce(string_agg(md5(to_jsonb(o)::text),'' ORDER BY o.id),'')) FROM public.organisations o)
 OR (SELECT fiches FROM organisations219_integrite) IS DISTINCT FROM (SELECT md5(coalesce(string_agg(md5(to_jsonb(p)::text),'' ORDER BY p.name),'')) FROM public.personnages_donnees p) THEN RAISE EXCEPTION 'organisations219_donnees_modifiees';END IF;
 FOREACH sig IN ARRAY ARRAY['organisation_commande_administrative(text,text,text,jsonb)','organisation_commande_membres(text,text,text,jsonb)','organisation_commande_evenement(text,text,text,jsonb)'] LOOP
  IF to_regprocedure('public.'||sig) IS NULL OR NOT has_function_privilege('authenticated','public.'||sig,'EXECUTE') OR has_function_privilege('anon','public.'||sig,'EXECUTE') OR NOT (SELECT prosecdef AND prorettype='jsonb'::regtype FROM pg_proc WHERE oid=to_regprocedure('public.'||sig)) THEN RAISE EXCEPTION 'organisations219_contrat_ou_ACL_invalide: %',sig;END IF;
 END LOOP;
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.organisation_commandes_recus'::regclass) OR has_table_privilege('authenticated','public.organisation_commandes_recus','SELECT,INSERT,UPDATE,DELETE') THEN RAISE EXCEPTION 'organisations219_registre_non_prive';END IF;
END $integrite$;
COMMIT;
"""
 if destination:Path(destination).write_text(sql)
 return sql
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--sortie');o=p.parse_args();sql=preparer(o.sortie);print('5 migrations vérifiées ; transaction unique ; aucune connexion ni exécution distante.')
