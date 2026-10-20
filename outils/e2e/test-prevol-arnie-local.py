#!/usr/bin/env python3
"""Execute le vrai audit sur PostgreSQL JETABLE, jamais Supabase. Donnees fictives uniquement."""
import tempfile,json,argparse
from pathlib import Path

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--local-jetable',action='store_true',required=True);p.parse_args()
 import pgserver,psycopg2
 s=pgserver.get_server(tempfile.mkdtemp(prefix='hg-audit-arnie-'),cleanup_mode='delete')
 db=psycopg2.connect(s.get_uri());db.autocommit=True;c=db.cursor()
 c.execute("CREATE ROLE authenticated; CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY,is_anonymous boolean,email text,email_confirmed_at timestamptz,new_email text,encrypted_password text); CREATE TABLE auth.identities(user_id uuid,provider text); CREATE TABLE personnages_donnees(id int,name text,user_id uuid,country text,current_city text,current_building text,current_room text,updated_at timestamptz,inventory jsonb,liquide int,stats jsonb,progression jsonb)")
 uid='00000000-0000-4000-8000-000000000001'
 c.execute("INSERT INTO auth.users VALUES(%s,true,NULL,NULL,NULL,NULL)",(uid,))
 c.execute("INSERT INTO personnages_donnees VALUES(1,'Arnie',%s,'republic','capitale',NULL,NULL,now(),'[{\"objet\":\"fictif\"}]',123,'{\"ENT\":4}','{\"etape\":7}')",(uid,))
 c.execute("INSERT INTO personnages_donnees VALUES(2,'Autre Fixture',NULL,'republic','capitale',NULL,NULL,now(),'[]',10,'{}','{}')")
 sql=(Path(__file__).resolve().parents[1]/'bancs/prevol-arnie.sql').read_text()
 def etat():
  c.execute("SELECT jsonb_agg(to_jsonb(p) ORDER BY id) FROM personnages_donnees p");return c.fetchone()[0]
 def lecture():c.execute(sql)
 avant=etat();lecture();assert etat()==avant
 print('OK 1 audit Arnie anonyme, aucun changement des deux fiches fictives')
 c.execute("UPDATE auth.users SET is_anonymous=false,email='fixture@example.invalid',email_confirmed_at=now(),encrypted_password='hash-factice' WHERE id=%s",(uid,))
 avant=etat();lecture();assert etat()==avant
 print('OK 2 audit Arnie classique, aucun changement de fiche')
 def refuse(motif):
  try:lecture();raise AssertionError('audit aurait du refuser')
  except psycopg2.Error as e:
   c.execute('ROLLBACK');assert motif in str(e),str(e)
 c.execute("INSERT INTO personnages_donnees SELECT 3,name,user_id,country,current_city,current_building,current_room,updated_at,inventory,liquide,stats,progression FROM personnages_donnees WHERE name='Arnie'")
 avant=etat();refuse('Arnie_non_identifie_sans_ambiguite');assert etat()==avant
 print('OK 3 homonymes exacts refuses, pas de selection arbitraire')
 c.execute('DELETE FROM personnages_donnees WHERE id=3');c.execute("UPDATE personnages_donnees SET user_id=NULL WHERE name='Arnie'");avant=etat();refuse('Arnie_sans_UID');assert etat()==avant
 print('OK 4 UID absent refuse sans rattachement automatique')
 c.execute("UPDATE personnages_donnees SET user_id=%s WHERE name='Arnie'",(uid,));c.execute('DELETE FROM auth.users');avant=etat();refuse('compte_Arnie_absent');assert etat()==avant
 print('OK 5 compte absent refuse sans recreation')
 db.close();print('5/5 groupes PostgreSQL locaux reussis ; AUCUN UID reel verifie, aucun acces Supabase.')
if __name__=='__main__':main()
