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
    for famille in sorted((set(observe.get(cle,{})) | set(attendu.get(cle,{})))):
     if observe.get(cle,{}).get(famille)!=attendu.get(cle,{}).get(famille):
      ecarts['categorie:'+famille]={'observé':observe.get(cle,{}).get(famille),'attendu':attendu.get(cle,{}).get(famille)}
   else:ecarts[cle]={'observé':observe.get(cle),'attendu':attendu.get(cle)}
 assert not ecarts,ecarts
 return {'conforme':True,'familles':sorted(attendu['categories'])}

REFERENTIELS_1012=['postes_nommes_regles','ressources_economie','chantiers_paliers','chantiers_besoins_jour','entreprises_constantes','recettes_production','recettes_commerce','commerces_types','commerces_dotations','armureries_dotations','entreprises_prix_rachat','offres_emploi_bne']
def verifier_referentiels(q,reference):
 """Écarte tout clone dont un des 12 référentiels diffère du vivant."""
 attendu=reference['referentiels']
 assert set(attendu)==set(REFERENTIELS_1012), 'référentiel manquant ou inconnu'
 ecarts={}
 for nom in REFERENTIELS_1012:
  q.execute("SELECT count(*),md5(COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text)::text,'[]')) FROM public."+nom+" x")
  n,h=q.fetchone();present={'lignes':int(n),'empreinte':h}
  if present!=attendu[nom]:ecarts[nom]={'local':present,'vivant':attendu[nom]}
 assert not ecarts,ecarts
 return {'conformes':True,'tables':len(REFERENTIELS_1012)}

def verifier_http_27(preuve):
 cas=preuve.get('cas',[])
 assert len(cas)==27 and len({x['cas'] for x in cas})==27 and all(x.get('ok') is True for x in cas), 'Les 27 cas HTTP authentifies distincts sont obligatoires'
 return {'cas':27,'conformes':True}

def main():
 a=argparse.ArgumentParser(description=__doc__)
 for x in ['exports','registre','capture-couts','postgres-bin','rapport']:a.add_argument('--'+x,type=Path,required=True)
 a.add_argument('--caisses-source',type=Path,help='Répertoire privé des deux sources exactes PR300, aucune application distante.')
 a.add_argument('--delta-candidat',type=Path,help='Deltas documentés par sources publiques, sans certifier un export canonique frais.')
 a.add_argument('--empreinte-reference',type=Path,required=True,help='Empreinte exhaustive du catalogue vivant avant le paquet 95. Rejette la moindre différence.')
 a.add_argument('--referentiels-reference',type=Path,required=True,help='Empreintes et cardinalités des 12 référentiels statiques du vivant.')
 a.add_argument('--gotrue-bin',type=Path)
 a.add_argument('--postgrest-bin',type=Path)
 a.add_argument('--referentiels-capture',type=Path,help='Capture privée complète des quatre tables statiques et locale ; hors Git, vérifiée avant 95.')
 a.add_argument('--locale-provider',choices=['libc','icu'],default='libc')
 a.add_argument('--icu-locale',help='Locale ICU exacte relevée dans pg_database.datlocale, jamais déduite du nom libc.')
 a.add_argument('--locale-clone',help='Locale explicite du seul PostgreSQL jetable ; enregistrée dans le rapport.')
 o=a.parse_args()
 if o.locale_provider=='icu' and not (o.locale_clone and o.icu_locale):a.error('ICU exige --locale-clone et --icu-locale relevés, sans valeur inventée')
 if o.icu_locale and o.locale_provider!='icu':a.error('--icu-locale exige --locale-provider icu')
 if not (o.gotrue_bin and o.postgrest_bin):a.error('GoTrue et PostgREST obligatoires pour certifier les 27 cas HTTP authentifies')
 e=charger('epreuve95','outils/baseline/epreuve-postgresql.py');lot=charger('lot95','outils/livraison/preparer-livraison-complete-219.py')
 registre=e.lire_registre(o.registre);capture=json.loads(o.capture_couts.read_text());plan=json.loads((R/'outils/audits/LIVRAISON-COUTS-219-20261031.json').read_text())
 triples=sorted((x['fn'],x['pa'],x['cost']) for x in capture['ordres_couts'])
 if len(triples)!=len(set(triples)) or len(triples)!=plan['avant']['lignes'] or hashlib.md5('\n'.join('%s|%d|%d'%t for t in triples).encode()).hexdigest()!=plan['avant']['md5']:raise ValueError('Capture des tarifs différente du prévol examiné')
 e.configurer_binaires(o.postgres_bin)
 import pgserver,psycopg2
 rapport={'production':False,'registre_source_versions':len(registre),'catalogue_1009_certifie':False,'catalogue_1012_certifie':False,'authentification':'JWT SQL pour les scénarios de catalogue ; recette GoTrue HTTP séparée si présente','tarifs_snapshot':capture['snapshot'],'cas':[]}
 with tempfile.TemporaryDirectory(prefix='hg95-catalogue-') as d:
  srv=pgserver.get_server(Path(d)/'data',cleanup_mode='delete');uri_locale=srv.get_uri();c=psycopg2.connect(uri_locale);q=c.cursor();services=None
  try:
   if o.locale_clone:
    from psycopg2 import sql as sql_pg
    c.autocommit=True
    creation=sql_pg.SQL('CREATE DATABASE hg219_clone TEMPLATE template0 LC_COLLATE {} LC_CTYPE {}').format(sql_pg.Literal(o.locale_clone),sql_pg.Literal(o.locale_clone))
    if o.locale_provider=='icu':creation+=sql_pg.SQL(' LOCALE_PROVIDER icu ICU_LOCALE {}').format(sql_pg.Literal(o.icu_locale))
    else:creation+=sql_pg.SQL(' LOCALE_PROVIDER libc')
    q.execute(creation);q.close();c.close()
    uri_locale=srv.get_uri(database='hg219_clone');c=psycopg2.connect(uri_locale);q=c.cursor();rapport['locale_demandee']=o.locale_clone
   q.execute('SHOW server_version_num');assert q.fetchone()[0]=='170006'
   for role in ['anon','authenticated','service_role','authenticator','supabase_auth_admin','supabase_admin','dashboard_user','supabase_read_only_user']:q.execute('CREATE ROLE '+role)
   if o.gotrue_bin:
    q.execute('CREATE SCHEMA auth AUTHORIZATION supabase_auth_admin;ALTER ROLE supabase_auth_admin LOGIN;ALTER ROLE supabase_auth_admin SET search_path=auth,public');c.commit();auth=charger('authlocale95','outils/bancs/auth-locale-groupes-219.py');services=auth.Services(uri_locale,d,o.gotrue_bin,o.postgrest_bin);services.demarrer_auth()
    # auth.users vient du vrai service GoTrue, aucune table d'authentification simulée.
    q.execute(('CREATE FUNCTION auth.jwt()'+e.PLATEFORME.split('CREATE FUNCTION auth.jwt()',1)[1]).replace('CREATE FUNCTION auth.','CREATE OR REPLACE FUNCTION auth.'))
   else:q.execute(e.PLATEFORME)
   complement=charger('schema_complet219','outils/bancs/completer-schema-clone-219.py');avant_schema,apres_schema,preuve_schema=complement.preparer(o.exports)
   q.execute(avant_schema)
   morceaux,_=e.assembler();rapport.update(e.installer(q,morceaux))
   q.execute(apres_schema);rapport['complement_hors_monde_neuf']=preuve_schema
   rapport['checks_restitues']=complement.restituer_checks(q,o.exports,e.expression_check)
   rapport['normalisations_checks']=[]
   ecarts=e.comparer_catalogues(q,o.exports,rapport['normalisations_checks']);assert not ecarts,ecarts
   rapport['schema_conforme_aux_exports_fournis']=True
   q.execute("SELECT md5(prosrc),md5(pg_get_functiondef(oid)) FROM pg_proc WHERE oid='public.payer_ordre(text,text,integer,integer)'::regprocedure");source_md5,definition_md5=q.fetchone();assert source_md5=='5cf45c19e4b9559f6b29e2b9207d3969' and source_md5!=definition_md5;rapport['payeur_avant']={'source_md5':source_md5,'definition_md5':definition_md5,'garde_source_satisfaite':True}
   q.execute('CREATE SCHEMA supabase_migrations;CREATE TABLE supabase_migrations.schema_migrations(version text PRIMARY KEY,name text,statements text[])')
   q.executemany('INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES(%s,%s)',[(x['version'],x.get('name')) for x in registre])
   if o.delta_candidat:
    delta=json.loads(o.delta_candidat.read_text())
    if 'registre_base' not in delta:
     # Format certifié de Claude #302 : 10 lignes, « genre » déjà présent seulement si base 1003.
     assert len(registre) in (1002,1003) and len(delta['migrations'])==10,'Delta 1012 réservé aux registres privés 1002/1003'
     assert all(x['concorde'] and x['md5_normalise_registre']==(x['md5_normalise_fichier_sans_enveloppe'] if x['enveloppe_retiree_par_supabase'] else x['md5_normalise_fichier']) for x in delta['migrations']),'Delta non certifié'
     versions_base={x['version'] for x in registre}
     delta={**delta,'registre_base':len(registre),'migrations':[{'fichier':x['fichier'],'sha256':x['sha256_fichier'],'version_observee':x['version_registre'],'nom_rapporte':x['nom_registre'],'statut':'deja_dans_1003' if x['version_registre'] in versions_base else 'appliquee'} for x in delta['migrations']]}
     assert {x['version_observee'] for x in delta['migrations'] if x['statut']=='deja_dans_1003'}==({'20261031113025'} if len(registre)==1003 else set()),'Delta privé : migration préexistante inattendue'
    assert delta['registre_base']==len(registre);c.commit()
    for entree in delta['migrations']:
     if entree['fichier']:
      p=R/entree['fichier'];assert hashlib.sha256(p.read_bytes()).hexdigest()==entree['sha256']
     if entree['statut']=='deja_dans_1003':
      assert entree['version_observee'] in {x['version'] for x in registre}
      continue
     if entree['fichier']:
      # Une session distincte comme pour les opérations d'origine : pg_temp ne fuit pas.
      autre=psycopg2.connect(uri_locale)
      try:
       with autre:
        with autre.cursor() as cq:cq.execute(p.read_text())
      finally:autre.close()
     else:assert entree['statut']=='donnees_uniquement_non_rejouees'
     # Métadonnées rapportées, jamais prétendues extraites par ce banc.
     q.execute('INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES(%s,%s)',(entree['version_observee'],entree['nom_rapporte']));c.commit()
    q.execute('SELECT count(*) FROM supabase_migrations.schema_migrations')
    assert q.fetchone()[0]==1012,'Registre local non 1012 après le delta certifié'
    rapport['delta_candidat']=delta;rapport['catalogue_candidat_non_certifie']=True;rapport['comparaison_exports']='avant_delta_candidat_uniquement'
    attendus={'organisation_ordre_financier':'73b9d936361d5c158b0bdfae44cf0db8','organisation_adhesion_payante':'f47b4e550f62fe6e1cfbf6c1d0c10cb7','club_supporters_cotiser':'b9324e4f910534fa6f03056bf91da5a7','club_sponsoriser':'d5a1250fbf53e53a32169bbbc8245b12','club_transfert_conclure':'fe760fbedd1bd7cafbf691bdccc45481'}
    q.execute("SELECT proname,md5(regexp_replace(prosrc,E'\\n[ \\t]*--[^\\n]*','','g')),has_function_privilege('authenticated',oid,'EXECUTE') FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname=ANY(%s)",(list(attendus),));finances=q.fetchall();rapport['contrats_financiers_candidat']=finances;rapport['contrats_financiers_attendus_releve']=attendus;q.execute("SELECT proname,md5(prosrc),md5(pg_get_functiondef(oid)) FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname=ANY(%s)",(list(attendus),));rapport['objets_haches_distincts_candidat']=q.fetchall();assert len(finances)==5 and all(h==attendus[n] and droit for n,h,droit in finances),finances
   if o.empreinte_reference:
    # Vérification exhaustive des empreintes de production AVANT les 95 migrations.
    racines=(R/'outils/bancs/empreinte-catalogue-racine.sql').read_text()
    racines=re.sub(r'(?im)^\s*(?:BEGIN;|ROLLBACK;|SET TRANSACTION READ ONLY;)\s*$', '', racines)
    c.commit();q.execute(racines)
    reference=json.loads(o.empreinte_reference.read_text(encoding='utf-8'))
    observe=q.fetchone()[0];rapport['empreinte_locale_avant95']=observe
    q.execute("SELECT datcollate,datctype,datlocprovider FROM pg_database WHERE datname=current_database()");rapport['locale_clone']=q.fetchone()
    q.execute('SELECT datlocale,datcollversion,pg_database_collation_actual_version(oid) FROM pg_database WHERE datname=current_database()');rapport['locale_clone_interne_et_versions']=q.fetchone()
    q.execute("SELECT EXISTS(SELECT 1 FROM pg_collation WHERE collname='en_US.utf8')")
    if q.fetchone()[0]:
     # Diagnostic de portabilité du collecteur seulement. Ce résultat alternatif
     # n'est JAMAIS fourni au garde de certification, qui reçoit observe intact.
     diagnostic=racines.replace('ORDER BY x.r)', 'ORDER BY x.r COLLATE "en_US.utf8")')
     assert diagnostic!=racines;q.execute(diagnostic);autre_tri=q.fetchone()[0]
     rapport['diagnostic_tri_acl_non_certifiant']={'seule_modification':'tri des bénéficiaires ACL avec COLLATE en_US.utf8','racine_fonctions':autre_tri['categories']['fonctions']['racine'],'reference':reference.get('empreinte',reference)['categories']['fonctions']['racine'],'certification':False}
    rapport['empreinte_complete_avant95']=verifier_empreinte_complete(observe,reference)
    rapport['schema_1012_certifie']=(reference.get('empreinte',reference).get('registre',{}).get('lignes')==1012)
    assert rapport['schema_1012_certifie'],'La référence doit concerner le catalogue vivant 1012'
    rapport['rpc_clients_avant95']=e.verifier_rpc_clients(q)
    rapport['rpc_clients_avant95']['portee']='Schéma du clone conforme aux six empreintes 1012, avant 95 ; pas un verdict de données ni de production'
    equipements=['organisation_equipement_acheter','organisation_equipement_deplacer','organisation_equipements_etat','organisation_equipements_payeurs']
    rapport['equipements_collectifs_avant95']={}
    for nom in equipements:
     q.execute("SELECT pg_get_function_identity_arguments(p.oid),p.prosecdef,has_function_privilege('authenticated',p.oid,'EXECUTE'),has_function_privilege('anon',p.oid,'EXECUTE') FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname=%s",(nom,))
     rapport['equipements_collectifs_avant95'][nom]=[{'arguments':args,'security_definer':sd,'authenticated_execute':au,'anon_execute':an} for args,sd,au,an in q.fetchall()]
    c.commit()
   if o.referentiels_reference:
    reference=json.loads(o.referentiels_reference.read_text(encoding='utf-8'))
    assert reference.get('registre')==1012,'Référence statique de mauvaise version'
    if o.referentiels_capture:
     lieu=json.loads((R/'outils/audits/catalogue-1012/LOCALE-PRODUCTION-1012.json').read_text())
     assert (lieu['registre'],lieu['derniere_version'])==(reference['registre'],reference['derniere_version']),'Relevé de locale périmé'
     reference['locale']=lieu['locale']
     prive=charger('references_privees219','outils/bancs/referentiels-prives-clone-219.py')
     rapport['capture_referentiels_privee']=prive.charger(q,o.referentiels_capture,reference)
    rapport['diagnostic_sources_refs_non_certifiant']=complement.diagnostic_generateurs(q,e.decouper,reference['referentiels'])
    rapport['referentiels_1012']=verifier_referentiels(q,reference)
    c.commit()
   assert rapport.get('capture_referentiels_privee',{}).get('locale',{}).get('conforme') is True, 'Locale réelle complète et capture privée certifiées obligatoires avant 95'
   assert rapport.get('schema_1012_certifie') is True and rapport.get('referentiels_1012',{}).get('conformes') is True, 'Certification complète 1012 et 12 référentiels obligatoire avant installation 95'
   rapport['catalogue_1012_certifie']=True
   # Prix capturés contrôlés séparément, jamais générés depuis des données de joueur.
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
    services.demarrer_rest(q);preuve_http=services.recette(q);rapport['http_27']=verifier_http_27(preuve_http);rapport['recette_authentifiee_isolee']=preuve_http;rapport['binaires_auth_sha256']={str(p.name):hashlib.sha256(p.read_bytes()).hexdigest() for p in [o.gotrue_bin,o.postgrest_bin]}
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
