#!/usr/bin/env python3
"""Contre-exemple et garde sur le vrai moteur successoral ; PostgreSQL jetable uniquement."""
from pathlib import Path
import re,tempfile,json
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver,psycopg2
 from psycopg2.extras import Json
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-succession69-'),cleanup_mode='delete');n=0
 try:
  with psycopg2.connect(server.get_uri()) as db:
   db.autocommit=True;c=db.cursor()
   src=(R/'baseline/domaines/personnage-et-presence/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public.successions \(.*?\n\);',src,re.S)[0]);c.execute('ALTER TABLE successions ADD PRIMARY KEY(id)')
   src=(R/'baseline/domaines/personnage-et-presence/20_fonctions.sql').read_text();a=src.index('CREATE OR REPLACE FUNCTION public.succession_regler(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',src[a:],re.S);c.execute(src[a:a+m.end()])
   def ok(v,t):
    nonlocal n
    assert v,t;n+=1;print('OK',t,flush=True)
   def creer(id,typ='coffre',extra=False):
    d=[{'id':'coffre-fixture','type':typ,'resultat':{'beneficiaire':'Heritier'}}]
    if extra:d.append({'id':'zero','type':'argent','part_nette':0,'resultat':{'beneficiaire':'Heritier'}})
    c.execute("INSERT INTO successions(id,defunt,country,dispositions) VALUES(%s,'Defunt-fixture','republic',%s)",(id,Json(d)))
   def regler(id):c.execute('SELECT succession_regler(%s)',(id,));return c.fetchone()[0]
   creer('avant');r=regler('avant');ok(r['cloturee'] and r['dispositions_reglees']==1,'contre-exemple archive : coffre declare regle sans aucun transfert')
   c.execute("DELETE FROM successions WHERE id='avant'")
   sql=(R/'migrations/20261021220151_succession_refuser_actifs_non_raccordes.sql').read_text();c.execute(sql);c.execute(sql)
   for typ in ['coffre','inconnu','']:
    id=typ or 'vide';creer(id,typ,True);r=regler(id)
    ok(not r['cloturee'] and r['dispositions_reglees']==1,'actif non raccorde retenu, autre disposition independante '+id)
    ok(len(r['echecs'])==1 and 'type_disposition_non_pris_en_charge' in r['echecs'][0],'refus precis '+id)
    c.execute('SELECT dispositions,statut FROM successions WHERE id=%s',(id,));ds,statut=c.fetchone()
    ok(not ds[0].get('regle') and ds[1]['regle'] and statut=='en_attente','marqueur inconnu jamais valide '+id)
    r=regler(id);ok(r['dispositions_reglees']==0 and not r['cloturee'],'rejeu ne double aucun reglement '+id)
   creer('connu','argent');r=regler('connu');ok(r['cloturee'],'type argent connu a zero preserve')
   c.execute("CREATE OR REPLACE FUNCTION succession_regler(p_succession_id text) RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$")
   try:c.execute(sql);raise AssertionError('corps inconnu ecrase')
   except psycopg2.Error as e:db.rollback();ok('succession_definition_non_examinee' in str(e),'definition inconnue refusee avant remplacement')
  print(f'{n}/{n} assertions locales ; aucun coffre reel, aucun transfert production.')
 finally:server.cleanup()
if __name__=='__main__':main()
