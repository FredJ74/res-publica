#!/usr/bin/env python3
"""Garde réelle, moteur de rue SIMULÉ : contrôle du verrou et absence d'appel interdit.
Ne démontre pas les règles du moteur vivant, dont la définition reste indisponible.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import tempfile,threading
R=Path(__file__).resolve().parents[2]

def main():
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-garde-rue-'),cleanup_mode='delete');uri=serveur.get_uri();n=0
 try:
  with psycopg2.connect(uri) as c:
   c.autocommit=True;q=c.cursor()
   q.execute("""CREATE ROLE anon;CREATE ROLE authenticated;
    CREATE TABLE personnages_donnees(name text PRIMARY KEY,hp integer,hospitalisation jsonb,pa integer,liquide integer,current_room text);
    CREATE TABLE appels_moteur(noeud text);
    CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT 'Victime'::text$$;
    INSERT INTO personnages_donnees VALUES('Victime',100,NULL,8,2000,'accueil');
    CREATE FUNCTION rue_position_enregistrer(p_noeud text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$BEGIN
     IF p_noeud='prison' THEN RETURN jsonb_build_object('ok',false,'raison','detention');END IF;
     INSERT INTO appels_moteur VALUES(p_noeud);
     UPDATE personnages_donnees SET current_room=NULL,pa=pa-1,liquide=liquide-10 WHERE name=mon_personnage();
     RETURN jsonb_build_object('ok',true,'preuve','moteur_origine');END$$;""")
   c.commit()
   mig=(R/'migrations/20261021120231_rue_garde_realites.sql').read_text()
   def ok(v,t):
    nonlocal n
    assert v,t;n+=1;print('OK',t)
   try:q.execute(mig)
   except psycopg2.Error as e:q.execute('ROLLBACK');ok('prevol_rue_md5_requis' in str(e),'installation aveugle refusee')
   else:raise AssertionError('prevol contourne')
   q.execute("SELECT set_config('hg.prevol.rue_position_md5',md5(prosrc),false) FROM pg_proc WHERE oid='rue_position_enregistrer(text)'::regprocedure")
   q.execute(mig);q.execute(mig)
   q.execute("SELECT rue_position_enregistrer('prison')");ok(q.fetchone()[0]['raison']=='detention','refus moteur conserve sans reinterpretation')
   q.execute("UPDATE personnages_donnees SET hp=0")
   q.execute("SELECT rue_position_enregistrer('place')");ok(q.fetchone()[0]['raison']=='acteur_incapacite','coma refuse avant moteur')
   q.execute('SELECT count(*) FROM appels_moteur');ok(q.fetchone()[0]==0,'aucune mutation moteur en cas de refus')
   q.execute('SELECT pa,liquide,current_room FROM personnages_donnees');ok(q.fetchone()==(8,2000,'accueil'),'PA finances et position inchanges')
   q.execute("UPDATE personnages_donnees SET hp=50,hospitalisation=jsonb_build_object('dateFinParis',current_date+1)")
   q.execute("SELECT rue_position_enregistrer('place')");ok(not q.fetchone()[0]['ok'],'convalescence active refusee meme apres soins')
   q.execute("UPDATE personnages_donnees SET hospitalisation=NULL")
   q.execute("SELECT rue_position_enregistrer('place')");ok(q.fetchone()[0]['preuve']=='moteur_origine','reutilisation exacte du moteur autorise')
   q.execute('SELECT pa,liquide FROM personnages_donnees');ok(q.fetchone()==(7,1990),'une seule execution des contreparties moteur')
   q.execute("SELECT has_function_privilege('authenticated','rue_position_enregistrer_moteur_20261021(text)','EXECUTE'),has_function_privilege('anon','rue_position_enregistrer(text)','EXECUTE')");ok(q.fetchone()==(False,False),'moteur prive inaccessible en RPC et anon refuse')
   # L'attaque tient le verrou. La sortie démarre puis ne peut lire avant son commit.
   attaque=psycopg2.connect(uri);aq=attaque.cursor();aq.execute("UPDATE personnages_donnees SET hp=0 WHERE name='Victime'")
   depart=threading.Event()
   def sortie():
    with psycopg2.connect(uri) as x:
     with x.cursor() as z:
      z.execute("SET statement_timeout='5s'");depart.set();z.execute("SELECT rue_position_enregistrer('place')");return z.fetchone()[0]
   with ThreadPoolExecutor(max_workers=1) as pool:
    travail=pool.submit(sortie);assert depart.wait(3);attaque.commit();v=travail.result(timeout=6)
   attaque.close();ok(v['raison']=='acteur_incapacite','sortie concurrente relit la sante apres verrou attaque')
   q.execute('SELECT count(*) FROM appels_moteur');ok(q.fetchone()[0]==1,'aucun appel supplementaire apres agression concurrente')
  print(f'{n}/{n} scenarios locaux reussis, moteur vivant non teste.')
 finally:serveur.cleanup()
if __name__=='__main__':main()
