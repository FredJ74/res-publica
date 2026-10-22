#!/usr/bin/env python3
"""Lecture physique PostgreSQL jetable ; identite simulee, aucune production."""
from pathlib import Path
import tempfile
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-realites-'),cleanup_mode='delete')
 try:
  with psycopg2.connect(serveur.get_uri()) as c:
   c.autocommit=True;q=c.cursor()
   q.execute('''CREATE ROLE anon;CREATE ROLE authenticated;
    CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,current_city text,current_building text,current_room text,current_street text,updated_at timestamptz DEFAULT now(),hp integer,hospitalisation jsonb,photo_url text);
    CREATE TABLE presences(name text PRIMARY KEY,country text,city text,building_id text,room_id text,groupe_pnj jsonb,updated_at timestamptz);
    CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT 'Alice'::text$$;
    INSERT INTO personnages_donnees VALUES('Alice','republic','capitale','mairie','hall',NULL,now(),0,'{}','secret'),('Bob','republic','capitale','mairie','hall',NULL,now()-interval '1 day',100,NULL,'secret'),('Ailleurs','republic','capitale','banque','hall',NULL,now(),100,NULL,'secret');
    INSERT INTO presences VALUES('Bob','republic','capitale','mairie','hall','[{"nom":"Accompagnant"}]',now()-interval '1 day'),('Ailleurs','republic','capitale','mairie','hall','[]',now());''')
   migration=next((R/'migrations').glob('*_presences_realites_sans_battement.sql')).read_text();q.execute(migration);q.execute(migration)
   def lire(b='mairie',r='hall',ville='capitale'):
    q.execute('SELECT presences_realites_lire(%s,%s,%s,%s)',('republic',ville,b,r));return q.fetchone()[0]
   v=lire();assert v['ok'] and [r['name'] for r in v['presences']]==['Alice','Bob'] # inactif visible, fantome filtre
   assert v['presences'][1]['groupe_pnj'][0]['nom']=='Accompagnant';assert all('photo_url' not in p and 'hp' not in p and 'hospitalisation' not in p for p in v['presences'])
   assert lire('banque')['raison']=='pas_sur_place';assert lire(ville='ville_a')['raison']=='pas_sur_place'
   q.execute("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='place' WHERE name='Alice'")
   assert not lire()['ok'];assert lire('rue-centrale','place')['ok'];assert not lire('rue-centrale','autre')['ok']
   q.execute("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='place' WHERE name='Bob'")
   assert [p['name'] for p in lire('rue-centrale','place')['presences']]==['Alice','Bob']
   q.execute("SELECT has_function_privilege('anon','public.presences_realites_lire(text,text,text,text)','EXECUTE'),has_function_privilege('authenticated','public.presences_realites_lire(text,text,text,text)','EXECUTE')");assert q.fetchone()==(False,True)
   q.execute("ALTER TABLE personnages_donnees DROP COLUMN current_street");assert lire('rue-centrale','place')['raison']=='schema_rue_indetermine'
  print('Presences PostgreSQL locales : inactivite, source physique, absence de fantomes, pays/ville/piece/rue, confidentialite, droits, garde schema et rejeu reussis. Auth simulee.')
 finally:serveur.cleanup()
if __name__=='__main__':main()
