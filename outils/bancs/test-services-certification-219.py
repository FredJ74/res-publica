#!/usr/bin/env python3
"""Préparation native 17.6/ICU/GoTrue/PostgREST : fixture, PAS les 27 cas métier."""
import argparse,importlib.util,json,secrets,tempfile,uuid
from pathlib import Path
R=Path(__file__).resolve().parents[2]
def module(n,p):
 s=importlib.util.spec_from_file_location(n,R/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def main():
 a=argparse.ArgumentParser(description=__doc__)
 for n in ('postgres-bin','gotrue-bin','postgrest-bin','rapport'):a.add_argument('--'+n,type=Path,required=True)
 o=a.parse_args();p=o.rapport.resolve()
 if p.is_relative_to(R):raise ValueError('Rapport de services hors dépôt requis')
 e=module('config_services219','outils/baseline/epreuve-postgresql.py');e.configurer_binaires(o.postgres_bin)
 import pgserver,psycopg2
 auth=module('services_prepares219','outils/bancs/auth-locale-groupes-219.py');cas=[]
 with tempfile.TemporaryDirectory(prefix='hg219-services-') as d:
  srv=pgserver.get_server(Path(d)/'data',cleanup_mode='delete');c=None;services=None
  try:
   c=psycopg2.connect(srv.get_uri());c.autocommit=True;q=c.cursor()
   q.execute("CREATE DATABASE hg219_services TEMPLATE template0 LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' LOCALE_PROVIDER icu ICU_LOCALE 'en-US'")
   c.close();uri=srv.get_uri(database='hg219_services');c=psycopg2.connect(uri);q=c.cursor()
   q.execute('SHOW server_version_num');assert q.fetchone()[0]=='170006';cas.append('postgresql_17_6')
   q.execute("SELECT datlocprovider,datlocale,datcollversion,pg_database_collation_actual_version(oid) FROM pg_database WHERE datname=current_database()")
   assert q.fetchone()==('i','en-US','153.121','153.121');cas.append('icu_en_US_153_121')
   q.execute('CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE authenticator;CREATE ROLE supabase_auth_admin LOGIN;CREATE SCHEMA auth AUTHORIZATION supabase_auth_admin;ALTER ROLE supabase_auth_admin SET search_path=auth,public');c.commit()
   services=auth.Services(uri,d,o.gotrue_bin,o.postgrest_bin);services.demarrer_auth();cas.append('gotrue_health')
   q.execute("CREATE FUNCTION public.hg219_identite_fixture() RETURNS text LANGUAGE plpgsql STABLE AS $$BEGIN RETURN current_setting('request.jwt.claims',true)::jsonb->>'sub'; END$$;REVOKE ALL ON FUNCTION public.hg219_identite_fixture() FROM PUBLIC;GRANT USAGE ON SCHEMA public TO authenticated,anon;GRANT EXECUTE ON FUNCTION public.hg219_identite_fixture() TO authenticated");c.commit()
   q.execute("CREATE FUNCTION public.hg219_role_fixture() RETURNS text LANGUAGE sql STABLE AS $$SELECT current_user::text$$");c.commit()
   services.demarrer_rest(q);cas.append('postgrest_health')
   q.execute("SELECT has_function_privilege('anon','public.hg219_identite_fixture()','EXECUTE')");assert q.fetchone()[0] is False, 'privilege_anon_present'
   status,role_observe=services.http(services.rest_url+'/rpc/hg219_role_fixture',{});assert status==200 and role_observe=='anon', ('role_anonyme',status,role_observe)
   email='hg219-preparation-'+secrets.token_hex(8)+'@example.invalid';password=secrets.token_urlsafe(32)
   status,v=services.http(services.auth_url+'/signup',{'email':email,'password':password});assert status in (200,201);cas.append('signup_fictif')
   status,v=services.http(services.auth_url+'/token?grant_type=password',{'email':email,'password':password});assert status==200 and v.get('access_token');token=v['access_token'];uid=v['user']['id'];uuid.UUID(uid);cas.append('login_reel_fictif')
   status,v=services.http(services.rest_url+'/rpc/hg219_identite_fixture',{},token);assert status==200 and v==uid;cas.append('uid_transmis_gotrue_postgrest')
   status,v=services.http(services.rest_url+'/rpc/hg219_identite_fixture',{});assert status in (401,403), ('anonyme_non_refuse',status,v.get('code') if isinstance(v,dict) else type(v).__name__);cas.append('anonyme_refuse')
   parts=token.split('.');parts[2]=('A' if parts[2][0]!='A' else 'B')+parts[2][1:]
   status,v=services.http(services.rest_url+'/rpc/hg219_identite_fixture',{},'.'.join(parts));assert status==401;cas.append('jwt_falsifie_refuse')
   status,v=services.http(services.auth_url+'/token?grant_type=password',{'email':email,'password':password});assert status==200 and v['user']['id']==uid;cas.append('reconnexion_meme_uid')
   p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps({'production':False,'catalogue_certifie':False,'tests_metier_27_executes':False,'cas':[{'cas':n,'ok':True} for n in cas]},indent=2));p.chmod(0o600)
   print(json.dumps({'tests_services':len(cas),'reussis':len(cas),'catalogue_certifie':False,'production':False}))
  finally:
   if services:services.fermer()
   if c:c.close()
   srv._cleanup()
if __name__=='__main__':main()
