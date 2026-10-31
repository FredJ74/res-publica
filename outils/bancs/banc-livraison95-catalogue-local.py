#!/usr/bin/env python3
"""95 migrations sur le catalogue reconstruit, jamais sur une URL distante.

Exports privés explicitement fournis. Ne certifie pas un registre plus récent
que les exports : la capture des tarifs porte sa propre provenance.
"""
import argparse,hashlib,importlib.util,json,re,tempfile,traceback
from pathlib import Path
R=Path(__file__).resolve().parents[2]
def charger(n,p):
 s=importlib.util.spec_from_file_location(n,R/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def verifier_temoin(avant,apres):
 """Préserve tous les champs anciens ; seule l'extension DDL nullable est prévue."""
 ecarts={k:{'avant':avant[k],'apres':apres.get(k)} for k in avant if k not in apres or avant[k]!=apres[k]}
 assert not ecarts,ecarts
 ajouts=set(apres)-set(avant)
 assert ajouts<={'current_street_from'} and all(apres[k] is None for k in ajouts),'nouvelle valeur non prévue'
 return {'ecarts_temoin':ecarts,'colonnes_ajoutees_temoin':sorted(ajouts)}
def verifier_empreinte_complete(observe,reference):
 """Bloque l'installation si UNE racine, un seau ou le registre diffère."""
 attendu=reference.get('empreinte',reference)
 ecarts={}
 for cle in ('version_serveur','registre','categories'):
  if observe.get(cle)!=attendu.get(cle):
   if cle=='categories':
    for famille in sorted(set(observe.get(cle,{})|set(attendu.get(cle,{})))):
     if observe.get(cle,{}).get(famille)!=attendu.get(cle,{}).get(famille):
      ecarts['categorie:'+famille]={'observé':observe.get(cle,{}).get(famille),'attendu':attendu.get(cle,{}).get(famille)}
   else:ecarts[cle]={'observé':observe.get(cle),'attendu':attendu.get(cle)}
 assert not ecarts,ecarts
 return {'conforme':True,'familles':sorted(attendu['categories'])}

def main():
 a=argparse.ArgumentParser(description=__doc__)
 for x in ['exports','registre','capture-couts','postgres-bin','rapport']:a.add_argument('--'+x,type=Path,required=True)
 a.add_argument('--caisses-source',type=Path,help='Répertoire privé des deux sources exactes PR300, aucune application distante.')
 a.add_argument('--delta-candidat',type=Path,help='Deltas documentés par sources publiques, sans certifier un export canonique frais.')
 a.add_argument('--empreinte-reference',type=Path,help='Empreinte exhaustive du catalogue vivant avant le paquet 95. Rejette la moindre différence.')
 a.add_argument('--gotrue-bin',type=Path)
 a.add_argument('--postgrest-bin',type=Path)
 o=a.parse_args()
 if bool(o.gotrue_bin)!=bool(o.postgrest_bin):a.error('GoTrue et PostgREST doivent être fournis ensemble')
 e=charger('epreuve95','outils/baseline/epreuve-postgresql.py');lot=charger('lot95','outils/livraison/preparer-livraison-complete-219.py')
 registre=e.lire_registre(o.registre);capture=json.loads(o.capture_couts.read_text());plan=json.loads((R/'outils/audits/LIVRAISON-COUTS-219-20261031.json').read_text())
 triples=sorted((x['fn'],x['pa'],x['cost']) for x in capture['ordres_couts'])
 if len(triples)!=len(set(triples)) or len(triples)!=plan['avant']['lignes'] or hashlib.md5('\n'.join('%s|%d|%d'%t for t in triples).encode()).hexdigest()!=plan['avant']['md5']:raise ValueError('Capture des tarifs différente du prévol examiné')
 e.configurer_binaires(o.postgres_bin)
 import pgserver,psycopg2
 rapport={'production':False,'registre_source_versions':len(registre),'catalogue_1009_certifie':False,'catalogue_1012_certifie':False,'authentification':'JWT SQL pour les scénarios de catalogue ; recette GoTrue HTTP séparée si présente','tarifs_snapshot':capture['snapshot'],'cas':[]}
 with tempfile.TemporaryDirectory(prefix='hg95-catalogue-') as d:
  srv=pgserver.get_server(Path(d)/'data',cleanup_mode='delete');c=psycopg2.connect(srv.get_uri());q=c.cursor();services=None
  try:
   q.execute('SHOW server_version_num');assert q.fetchone()[0]=='170006'
   for role in ['anon','authenticated','service_role','authenticator','supabase_auth_admin','supabase_admin','dashboard_user','supabase_read_only_user']:q.execute('CREATE ROLE '+role)
   if o.gotrue_bin:
    q.execute('CREATE SCHEMA auth AUTHORIZATION supabase_auth_admin;ALTER ROLE supabase_auth_admin LOGIN;ALTER ROLE supabase_auth_admin SET search_path=auth,public');c.commit();auth=charger('authlocale95','outils/bancs/auth-locale-groupes-219.py');services=auth.Services(srv.get_uri(),d,o.gotrue_bin,o.postgrest_bin);services.demarrer_auth()
    # auth.users vient du vrai service GoTrue, aucune table d'authentification simulée.
    q.execute(('CREATE FUNCTION auth.jwt()'+e.PLATEFORME.split('CREATE FUNCTION auth.jwt()',1)[1]).replace('CREATE FUNCTION auth.','CREATE OR REPLACE FUNCTION auth.'))
   else:q.execute(e.PLATEFORME)
   morceaux,_=e.assembler();rapport.update(e.installer(q,morceaux))
   ecarts=e.comparer_catalogues(q,o.exports);assert not ecarts,ecarts
   rapport['schema_conforme_aux_exports_fournis']=True
   q.execute("SELECT md5(prosrc),md5(pg_get_functiondef(oid)) FROM pg_proc WHERE oid='public.payer_ordre(text,text,integer,integer)'::regprocedure");source_md5,definition_md5=q.fetchone();assert source_md5=='5cf45c19e4b9559f6b29e2b9207d3969' and source_md5!=definition_md5;rapport['payeur_avant']={'source_md5':source_md5,'definition_md5':definition_md5,'garde_source_satisfaite':True}
   q.execute('CREATE SCHEMA supabase_migrations;CREATE TABLE supabase_migrations.schema_migrations(version text PRIMARY KEY,name text,statements text[])')
   q.executemany('INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES(%s,%s)',[(x['version'],x.get('name')) for x in registre])
   if o.delta_candidat:
    delta=json.loads(o.delta_candidat.read_text());assert delta['registre_base']==len(registre);c.commit()
    for entree in delta['migrations']:
     if entree['fichier']:
      p=R/entree['fichier'];assert hashlib.sha256(p.read_bytes()).hexdigest()==entree['sha256']
      # Une session distincte comme pour les opérations d'origine : pg_temp ne fuit pas.
      autre=psycopg2.connect(srv.get_uri())
      try:
       with autre:
        with autre.cursor() as cq:cq.execute(p.read_text())
      finally:autre.close()
     else:assert entree['statut']=='donnees_uniquement_non_rejouees'
     # Métadonnées rapportées, jamais prétendues extraites par ce banc.
     q.execute('INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES(%s,%s)',(entree['version_observee'],entree['nom_rapporte']));c.commit()
    rapport['delta_candidat']=delta;rapport['catalogue_candidat_non_certifie']=True;rapport['comparaison_exports']='avant_delta_candidat_uniquement'
    attendus={'organisation_ordre_financier':'73b9d936361d5c158b0bdfae44cf0db8','organisation_adhesion_payante':'f47b4e550f62fe6e1cfbf6c1d0c10cb7','club_supporters_cotiser':'b9324e4f910534fa6f03056bf91da5a7','club_sponsoriser':'d5a1250fbf53e53a32169bbbc8245b12','club_transfert_conclure':'fe760fbedd1bd7cafbf691bdccc45481'}
    q.execute("SELECT proname,md5(regexp_replace(prosrc,E'\\n[ \\t]*--[^\\n]*','','g')),has_function_privilege('authenticated',oid,'EXECUTE') FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname=ANY(%s)",(list(attendus),));finances=q.fetchall();rapport['contrats_financiers_candidat']=finances;rapport['contrats_financiers_attendus_releve']=attendus;q.execute("SELECT proname,md5(prosrc),md5(pg_get_functiondef(oid)) FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname=ANY(%s)",(list(attendus),));rapport['objets_haches_distincts_candidat']=q.fetchall();assert len(finances)==5 and all(h==attendus[n] and droit for n,h,droit in finances),finances
   if o.empreinte_reference:
    # Épreuve par définitions normalisées, ACL/RLS, déclencheurs, index et registre.
    # Le SQL référentiel est strictement SELECT ; il ne modifie pas de joueur.
    racines=(R/'outils/bancs/empreinte-catalogue-racine.sql').read_text()
    racines=re.sub(r'(?im)^\\s*(?:BEGIN;|ROLLBACK;|SET TRANSACTION READ ONLY;)\\s*   q.execute('DELETE FROM ordres_couts');q.executemany('INSERT INTO ordres_couts(fn,pa,cost) VALUES(%s,%s,%s)',triples)
   q.execute("INSERT INTO ordres_couts_empreinte(seul,empreinte) VALUES(true,'6de4a84c58ed9b2b') ON CONFLICT(seul) DO UPDATE SET empreinte=excluded.empreinte")
   e.temoin_integrite_local(q);q.execute("SELECT to_jsonb(p) FROM personnages_donnees p WHERE name='__hg219_canari_avant'");temoin=q.fetchone()[0];c.commit();avant=e.empreinte_installation(q);rapport['registre_local_avant95']=avant['registre'];c.commit()
   sql,entrees=lot.preparer();assert len(entrees)==95
   contre=sql.rsplit('COMMIT;',1)[0]+"DO $$ BEGIN RAISE EXCEPTION 'panne_apres_95';END $$;COMMIT;"
   try:q.execute(contre);raise AssertionError('panne tardive ignorée')
   except psycopg2.Error as ex:
    if 'panne_apres_95' not in str(ex):raise
    c.rollback()
   assert e.empreinte_installation(q)==avant,'installation partielle après panne';c.commit();rapport['rollback_95']=True
   q.execute(sql);rapport['95_installees']=True;c.commit()
   q.execute("SELECT md5(prosrc) FROM pg_proc WHERE oid='public.payer_ordre(text,text,integer,integer)'::regprocedure");rapport['payeur_final_md5_corps']=q.fetchone()[0];assert rapport['payeur_final_md5_corps']=='d5c9f4e8bdbdc2858c8b908fd6c460c5'
   apres=e.empreinte_installation(q);rapport['registre_local_apres95']=apres['registre'];assert apres['registre']==avant['registre']+95;q.execute("SELECT to_jsonb(p) FROM personnages_donnees p WHERE name='__hg219_canari_avant'");temoin_apres=q.fetchone()[0];rapport.update(verifier_temoin(temoin,temoin_apres));c.commit()
   try:q.execute(sql);raise AssertionError('rejeu du paquet non refusé')
   except psycopg2.Error as ex:
    if 'versions_presentes_prevol_frais_requis' not in str(ex):raise
    c.rollback()
   assert e.empreinte_installation(q)==apres;c.commit();rapport['rejeu_sans_mutation']=True

   if o.delta_candidat:
    q.execute("SELECT proname,md5(regexp_replace(prosrc,E'\\n[ \\t]*--[^\\n]*','','g')),has_function_privilege('authenticated',oid,'EXECUTE') FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname=ANY(%s)",(list(attendus),));assert sorted(q.fetchall())==sorted(finances),'contrats financiers modifiés par le lot';c.commit()
   q.execute('BEGIN');rec=charger('recette95','outils/bancs/recette-groupes-catalogue-219.py');rapport['cas']=rec.recette(q)
   assert all(x['ok'] for x in rapport['cas']),rapport['cas']
   org=charger('recetteorg95','outils/bancs/recette-organisations-catalogue-219.py');rapport['organisations']=org.recette(q)
   rapport['rpc_clients']=e.verifier_rpc_clients(q);c.rollback()
   if o.caisses_source and not o.delta_candidat:
    provenance=json.loads((o.caisses_source/'provenance.json').read_text())
    for entree in provenance['migrations']:
     p=o.caisses_source/entree['fichier'];assert hashlib.sha256(p.read_bytes()).hexdigest()==entree['sha256'];q.execute(p.read_text())
    q.execute('BEGIN');rapport['pr300']={'source':provenance,'organisations':org.recette(q),'groupes':rec.recette(q)}
    assert all(x['ok'] for x in rapport['pr300']['groupes']);rapport['pr300']['rpc_clients']=e.verifier_rpc_clients(q);c.rollback()
   if services:
    services.demarrer_rest(q);rapport['recette_authentifiee_isolee']=services.recette(q);rapport['binaires_auth_sha256']={str(p.name):hashlib.sha256(p.read_bytes()).hexdigest() for p in [o.gotrue_bin,o.postgrest_bin]}
  except Exception as ex:
   rapport['erreur']=str(ex);rapport['trace']=traceback.format_exc();c.rollback()
   if services:
    prive=Path(str(o.rapport)+'.services-privees');prive.mkdir(mode=0o700,exist_ok=True)
    for f in Path(d).glob('*.log'):
     dest=prive/f.name;dest.write_bytes(f.read_bytes());dest.chmod(0o600)
  finally:
   if services:services.fermer()
   c.close();srv._cleanup()
 o.rapport.write_text(json.dumps(rapport,ensure_ascii=False,indent=2)+'\n');print(json.dumps(rapport,ensure_ascii=False,indent=2));return int('erreur' in rapport)
if __name__=='__main__':raise SystemExit(main())
, '', racines)
    c.commit();q.execute(racines)
    vivante=json.loads(o.empreinte_reference.read_text(encoding='utf-8'))
    rapport['empreinte_complete_avant95']=verifier_empreinte_complete(q.fetchone()[0],vivante)
    rapport['catalogue_1012_certifie']=(vivante.get('empreinte',vivante).get('registre',{}).get('lignes')==1012)
    assert rapport['catalogue_1012_certifie'],'La référence ne correspond pas au catalogue vivant 1012'
    c.commit()
   # Référentiel réellement capturé, pas un catalogue 1009 inventé.
   q.execute('DELETE FROM ordres_couts');q.executemany('INSERT INTO ordres_couts(fn,pa,cost) VALUES(%s,%s,%s)',triples)
   q.execute("INSERT INTO ordres_couts_empreinte(seul,empreinte) VALUES(true,'6de4a84c58ed9b2b') ON CONFLICT(seul) DO UPDATE SET empreinte=excluded.empreinte")
   e.temoin_integrite_local(q);q.execute("SELECT to_jsonb(p) FROM personnages_donnees p WHERE name='__hg219_canari_avant'");temoin=q.fetchone()[0];c.commit();avant=e.empreinte_installation(q);rapport['registre_local_avant95']=avant['registre'];c.commit()
   sql,entrees=lot.preparer();assert len(entrees)==95
   contre=sql.rsplit('COMMIT;',1)[0]+"DO $$ BEGIN RAISE EXCEPTION 'panne_apres_95';END $$;COMMIT;"
   try:q.execute(contre);raise AssertionError('panne tardive ignorée')
   except psycopg2.Error as ex:
    if 'panne_apres_95' not in str(ex):raise
    c.rollback()
   assert e.empreinte_installation(q)==avant,'installation partielle après panne';c.commit();rapport['rollback_95']=True
   q.execute(sql);rapport['95_installees']=True;c.commit()
   q.execute("SELECT md5(prosrc) FROM pg_proc WHERE oid='public.payer_ordre(text,text,integer,integer)'::regprocedure");rapport['payeur_final_md5_corps']=q.fetchone()[0];assert rapport['payeur_final_md5_corps']=='d5c9f4e8bdbdc2858c8b908fd6c460c5'
   apres=e.empreinte_installation(q);rapport['registre_local_apres95']=apres['registre'];assert apres['registre']==avant['registre']+95;q.execute("SELECT to_jsonb(p) FROM personnages_donnees p WHERE name='__hg219_canari_avant'");temoin_apres=q.fetchone()[0];rapport.update(verifier_temoin(temoin,temoin_apres));c.commit()
   try:q.execute(sql);raise AssertionError('rejeu du paquet non refusé')
   except psycopg2.Error as ex:
    if 'versions_presentes_prevol_frais_requis' not in str(ex):raise
    c.rollback()
   assert e.empreinte_installation(q)==apres;c.commit();rapport['rejeu_sans_mutation']=True

   if o.delta_candidat:
    q.execute("SELECT proname,md5(regexp_replace(prosrc,E'\\n[ \\t]*--[^\\n]*','','g')),has_function_privilege('authenticated',oid,'EXECUTE') FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname=ANY(%s)",(list(attendus),));assert sorted(q.fetchall())==sorted(finances),'contrats financiers modifiés par le lot';c.commit()
   q.execute('BEGIN');rec=charger('recette95','outils/bancs/recette-groupes-catalogue-219.py');rapport['cas']=rec.recette(q)
   assert all(x['ok'] for x in rapport['cas']),rapport['cas']
   org=charger('recetteorg95','outils/bancs/recette-organisations-catalogue-219.py');rapport['organisations']=org.recette(q)
   rapport['rpc_clients']=e.verifier_rpc_clients(q);c.rollback()
   if o.caisses_source and not o.delta_candidat:
    provenance=json.loads((o.caisses_source/'provenance.json').read_text())
    for entree in provenance['migrations']:
     p=o.caisses_source/entree['fichier'];assert hashlib.sha256(p.read_bytes()).hexdigest()==entree['sha256'];q.execute(p.read_text())
    q.execute('BEGIN');rapport['pr300']={'source':provenance,'organisations':org.recette(q),'groupes':rec.recette(q)}
    assert all(x['ok'] for x in rapport['pr300']['groupes']);rapport['pr300']['rpc_clients']=e.verifier_rpc_clients(q);c.rollback()
   if services:
    services.demarrer_rest(q);rapport['recette_authentifiee_isolee']=services.recette(q);rapport['binaires_auth_sha256']={str(p.name):hashlib.sha256(p.read_bytes()).hexdigest() for p in [o.gotrue_bin,o.postgrest_bin]}
  except Exception as ex:
   rapport['erreur']=str(ex);rapport['trace']=traceback.format_exc();c.rollback()
   if services:
    prive=Path(str(o.rapport)+'.services-privees');prive.mkdir(mode=0o700,exist_ok=True)
    for f in Path(d).glob('*.log'):
     dest=prive/f.name;dest.write_bytes(f.read_bytes());dest.chmod(0o600)
  finally:
   if services:services.fermer()
   c.close();srv._cleanup()
 o.rapport.write_text(json.dumps(rapport,ensure_ascii=False,indent=2)+'\n');print(json.dumps(rapport,ensure_ascii=False,indent=2));return int('erreur' in rapport)
if __name__=='__main__':raise SystemExit(main())
