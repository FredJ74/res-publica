#!/usr/bin/env python3
"""Contre-exemple serveur : fonction archivee reelle, PostgreSQL jetable, identite simulee.
Renvoie 1 lorsque la regle de realite immediate n'est pas satisfaite. Ne jamais compter comme succes.
"""
from pathlib import Path
import tempfile,re,json
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-audit-impact-'),cleanup_mode='delete')
 try:
  with psycopg2.connect(serveur.get_uri()) as c:
   c.autocommit=True;q=c.cursor()
   q.execute('''CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,current_city text,current_building text,current_room text,hp integer,pa integer,hospitalisation jsonb);
   CREATE TABLE impacts_indices_attente(id text PRIMARY KEY,victime text,indice text,delta integer,palier text,traite boolean);
   CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT 'Agresseur'::text$$;
   INSERT INTO personnages_donnees VALUES('Agresseur','republic','capitale','mairie','hall',100,8,NULL),('Victime','republic','capitale','mairie','hall',100,8,NULL);''')
   src=(R/'baseline/domaines/justice/20_fonctions-1.sql').read_text();a=src.index('CREATE OR REPLACE FUNCTION public.impact_deposer(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',src[a:],re.S);q.execute(src[a:a+m.end()])
   q.execute("SELECT impact_deposer('audit-impact','Victime','hp_set',0,'totale')");v=q.fetchone()[0]
   q.execute("SELECT hp,pa,hospitalisation FROM personnages_donnees WHERE name='Victime'");hp,pa,hospitalisation=q.fetchone()
   q.execute("SELECT count(*) FROM impacts_indices_attente WHERE victime='Victime' AND traite=false");files=q.fetchone()[0]
   conforme=bool(v['ok'] and hp==0 and hospitalisation is not None)
   print(json.dumps({'portee':'PostgreSQL jetable, fonction SQL archivee reelle, dependances et personnages fictifs ; pas la production','fonction':'impact_deposer','impact_accepte':v['ok'],'sante_victime_apres':hp,'pa_victime_apres':pa,'hospitalisation_victime_apres':hospitalisation,'impacts_differes_non_traites':files,'realite_immediate_satisfaite':conforme,'fusion_autorisee':False},ensure_ascii=False,indent=2))
   return 0 if conforme else 1
 finally:serveur.cleanup()
if __name__=='__main__':raise SystemExit(main())
