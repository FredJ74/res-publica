#!/usr/bin/env python3
"""Contre-exemple serveur : fonction archivee reelle, PostgreSQL jetable, identite simulee.
Sans --avec-correctif : contre-exemple archive. Avec : meme assertion, migration locale reelle.
Renvoie 1 si la regle immediate echoue. Un resultat rouge ne compte jamais comme succes.
"""
from pathlib import Path
import tempfile,re,json,argparse
R=Path(__file__).resolve().parents[2]
def main():
 args=argparse.ArgumentParser(description=__doc__);args.add_argument('--avec-correctif',action='store_true');options=args.parse_args()
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-audit-impact-'),cleanup_mode='delete')
 try:
  with psycopg2.connect(serveur.get_uri()) as c:
   c.autocommit=True;q=c.cursor()
   q.execute("""CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;
   CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql AS $$SELECT 'authenticated'::text$$;
   CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT 'Agresseur'::text$$;""")
   for domaine,table in [('personnage-et-presence','personnages_donnees'),('justice','impacts_indices_attente')]:
    texte=(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text()
    q.execute(re.search(r'CREATE TABLE public\.'+table+r' \(.*?\n\);',texte,re.S)[0])
   q.execute("""ALTER TABLE personnages_donnees ADD PRIMARY KEY(name);ALTER TABLE impacts_indices_attente ADD PRIMARY KEY(id);
   INSERT INTO personnages_donnees(name,user_id,country,current_city,current_building,current_room,hp,pa) VALUES
   ('Agresseur',gen_random_uuid(),'republic','capitale','mairie','hall',100,8),
   ('Victime',gen_random_uuid(),'republic','capitale','mairie','hall',100,8);""")
   src=(R/'baseline/domaines/justice/20_fonctions-1.sql').read_text();a=src.index('CREATE OR REPLACE FUNCTION public.impact_deposer(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',src[a:],re.S);q.execute(src[a:a+m.end()])
   if options.avec_correctif:q.execute((R/'migrations/20261021115429_impacts_realites_immediates.sql').read_text())
   q.execute("SELECT impact_deposer('audit-impact','Victime','hp_set',0,'totale')");v=q.fetchone()[0]
   q.execute("SELECT hp,pa,hospitalisation FROM personnages_donnees WHERE name='Victime'");hp,pa,hospitalisation=q.fetchone()
   q.execute("SELECT count(*) FROM impacts_indices_attente WHERE victime='Victime' AND traite=false");files=q.fetchone()[0]
   effets=files
   if options.avec_correctif:
    q.execute("SELECT count(*) FROM impacts_indices_attente WHERE victime='Victime' AND NOT applique_serveur");effets=q.fetchone()[0]
   conforme=bool(v['ok'] and hp==0 and hospitalisation is not None)
   print(json.dumps({'portee':'PostgreSQL jetable, fonction SQL archivee reelle, dependances et personnages fictifs ; pas la production','correctif_local_applique':options.avec_correctif,'fonction':'impact_deposer','impact_accepte':v['ok'],'sante_victime_apres':hp,'pa_victime_apres':pa,'hospitalisation_victime_apres':hospitalisation,'notifications_non_lues':files,'impacts_differes_non_traites':effets,'realite_immediate_satisfaite':conforme,'fusion_autorisee':False},ensure_ascii=False,indent=2))
   return 0 if conforme else 1
 finally:serveur.cleanup()
if __name__=='__main__':raise SystemExit(main())
