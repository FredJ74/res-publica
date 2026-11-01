#!/usr/bin/env python3
"""Vérifie le manifeste #219 ; produit du SQL à relire, ne se connecte à rien."""
import argparse,hashlib,json,re
from datetime import datetime
from pathlib import Path
R=Path(__file__).resolve().parents[2]
MAN=R/'outils/audits/LIVRAISON-GROUPES-219-20261030.json'
def preparer(destination=None, inclure_prerequis=False):
 m=json.loads(MAN.read_text());versions=set();blocs=[]
 assert len(m['migrations'])==88, 'Le lot #219 doit conserver ses 88 migrations ; aucune omission silencieuse'
 assert [e['version'] for e in m['migrations']]==sorted(e['version'] for e in m['migrations']), 'Ordre des migrations incohérent'
 coupe=datetime.fromisoformat(json.loads((R/'baseline/CONTROLE-GLOBAL.json').read_text())['releve_le']).strftime('%Y%m%d%H%M%S')
 entrees=list(m['migrations'])
 if inclure_prerequis:
  prerequis=m.get('prerequis',[])
  assert len(prerequis)==1 and prerequis[0]['fichier'].endswith('_squatteurs_issue_combat.sql'), 'Prérequis #233 exact requis, aucun glob de migrations'
  assert prerequis[0]['version']<entrees[0]['version'],'Prérequis #233 avant le lot'
  entrees=prerequis+entrees
 if not all(e['version']>coupe for e in entrees) and not (R/'baseline/REGISTRE-OBSERVE.json').is_file():
  raise AssertionError('Versions anciennes sans registre observé : rehorodater ou fournir le prévol réel, jamais reculer la coupe')
 for e in entrees:
  p=R/e['fichier'];s=p.read_text()
  assert re.fullmatch(r'\d{14}',e['version']) and e['version'] not in versions,e
  assert p.name.startswith(e['version']+'_') and p.parent==R/'migrations',p
  assert list((R/'migrations').glob(e['version']+'_*.sql'))==[p], 'Collision de version dans le dépôt : '+e['version']
  assert hashlib.sha256(p.read_bytes()).hexdigest()==e['sha256'],'Contenu changé : '+str(p)
  assert len(s)<=12500,p
  assert not re.search(r'^\s*(BEGIN|COMMIT|ROLLBACK)\s*;',s,re.M|re.I),'transaction interne : '+str(p)
  versions.add(e['version']);blocs.append((e,s))
 if not all(e['version']>coupe for e in entrees):
  import importlib.util
  spec=importlib.util.spec_from_file_location('registre_garde219',R/'outils/baseline/verifier-workflow.py');garde=importlib.util.module_from_spec(spec);spec.loader.exec_module(garde)
  ctl=json.loads((R/'baseline/CONTROLE-GLOBAL.json').read_text())
  observation=garde.verifier_registre_observe(json.loads((R/'baseline/REGISTRE-OBSERVE.json').read_text()),ctl['registre'])
  assert all(not garde.migration_presente_au_registre(Path(e['fichier']).name,observation) for e in entrees),'Version ou nom déjà appliqué : prévol frais requis'
 if destination:
  citer=lambda s:"'"+s.replace("'","''")+"'"
  liste=','.join(citer(x) for x in sorted(versions))
  sql="""-- PR #219 : document généré, à valider contre le catalogue réel AVANT exécution.
-- Une transaction indivisible : toute collision/erreur annule l'ensemble.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $prevol$
BEGIN
 IF EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version IN ("""+liste+""")) THEN
  RAISE EXCEPTION '219_version_deja_enregistree_reconcilier_avant_application';END IF;
 IF to_regprocedure('public.terrain_squatteurs_issue_interne(text,text,text,uuid)') IS NULL
 OR to_regprocedure('public.pnj_position_effective(text)') IS NULL
 OR to_regprocedure('public.crime_neutraliser(text,text,integer)') IS NULL
 OR to_regprocedure('public.militaire_bataille_combattants(bigint,text)') IS NULL
 OR to_regprocedure('public.sanction_financiere_imposer_interne(text,text,text,text,integer,text)') IS NULL
 OR to_regprocedure('public.fiche_fusionner_ecran(jsonb,jsonb,jsonb)') IS NULL THEN
  RAISE EXCEPTION '219_prerequis_main_manquant';END IF;
END $prevol$;
LOCK TABLE public.personnages_donnees IN SHARE ROW EXCLUSIVE MODE;
CREATE TEMP TABLE hg219_integrite ON COMMIT DROP AS
 SELECT (SELECT array_agg(attname::text) FROM pg_attribute WHERE attrelid='public.personnages_donnees'::regclass AND attnum>0 AND NOT attisdropped) AS champs,
 md5(coalesce(string_agg(md5(to_jsonb(d)::text),'' ORDER BY d.name),'')) AS empreinte FROM public.personnages_donnees d;
"""
  if inclure_prerequis:
   # Le prérequis ne doit pas être activé isolément. Il rejoint la même
   # transaction, le même contrôle d'intégrité et le même registre que le lot.
   sql=sql.replace(" IF to_regprocedure('public.terrain_squatteurs_issue_interne(text,text,text,uuid)') IS NULL\n OR", " IF")
   point="END $prevol$;"
   garde=" IF to_regprocedure('public.terrain_squatteurs_issue_interne(text,text,text,uuid)') IS NOT NULL THEN RAISE EXCEPTION '219_prerequis_233_preexistant_reconcilier';END IF;\n"
   sql=sql.replace(point,garde+point,1)
  for e,s in blocs:sql+='\n-- FICHIER '+e['fichier']+' SHA256 '+e['sha256']+'\n'+s+'\n'
  sql+="""
DO $integrite$
BEGIN
 IF (SELECT empreinte FROM hg219_integrite) IS DISTINCT FROM
 (SELECT md5(coalesce(string_agg(md5((SELECT jsonb_object_agg(x.key,x.value) FROM jsonb_each(to_jsonb(d)) x WHERE x.key=ANY((SELECT champs FROM hg219_integrite)::text[]))::text),'' ORDER BY d.name),'')) FROM public.personnages_donnees d) THEN
 RAISE EXCEPTION '219_fiche_PJ_modifiee_par_DDL_annulation';END IF;
 IF to_regprocedure('public.combat_cibles_lire()') IS NULL
 OR to_regprocedure('public.combat_ouvrir(text,text,uuid)') IS NULL
 OR to_regprocedure('public.combat_bataille_completer_groupes_interne(bigint,text,text,text,text)') IS NULL THEN
 RAISE EXCEPTION '219_installation_incomplete';END IF;
END $integrite$;
"""
  for e,s in blocs:
   nom=Path(e['fichier']).stem[15:]
   sql+='INSERT INTO supabase_migrations.schema_migrations(version,name,statements) VALUES ('+citer(e['version'])+','+citer(nom)+',ARRAY['+citer(s)+']);\n'
  sql+="NOTIFY pgrst,'reload schema';\nCOMMIT;\n"
  Path(destination).write_text(sql)
 return len(blocs)
if __name__=='__main__':
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--sortie');a.add_argument('--inclure-prerequis-233',action='store_true');o=a.parse_args();print(str(preparer(o.sortie,o.inclure_prerequis_233))+' migrations vérifiées ; aucune connexion ni exécution SQL.')
