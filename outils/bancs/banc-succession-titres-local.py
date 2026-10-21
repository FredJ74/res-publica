#!/usr/bin/env python3
"""Vrais moteur successoral et garde de titres #66 ; PostgreSQL jetable, serveur/auth simules."""
from pathlib import Path
import re,tempfile,json
R=Path(__file__).resolve().parents[2]
def fonction(src,nom):
 s=src if src.startswith('CREATE') else (R/src).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
def main():
 import pgserver,psycopg2
 from psycopg2.extras import Json
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-titres66-'),cleanup_mode='delete');n=0
 try:
  with psycopg2.connect(server.get_uri()) as db:
   db.autocommit=True;c=db.cursor()
   for d,t in [('personnage-et-presence','successions'),('immobilier-et-territoire','terrains_etat')]:
    s=(R/f'baseline/domaines/{d}/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public\.'+t+r' \(.*?\n\);',s,re.S)[0]);c.execute(f'ALTER TABLE {t} ADD PRIMARY KEY(id)')
   c.execute("CREATE TABLE immobilier_biens(id text,terrain_id text,entreprise_id text);CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$SELECT true$$")
   for fn in ['immobilier_ref_pj','immobilier_titre_proteger']:c.execute(fonction('migrations/20261021203047_immobilier_offres_fonds_murs.sql',fn))
   c.execute('CREATE TRIGGER titre BEFORE UPDATE ON terrains_etat FOR EACH ROW EXECUTE FUNCTION immobilier_titre_proteger()')
   original=fonction('baseline/domaines/personnage-et-presence/20_fonctions.sql','succession_regler');c.execute(original)
   def ok(v,t):
    nonlocal n
    assert v,t;n+=1;print('OK',t,flush=True)
   def creer(id='s',terrain_id=None,benef='Heritier'):
    d={'type':'terrain','id':'batiment','resultat':{'beneficiaire':benef}}
    if terrain_id:d['terrain_id']=terrain_id
    c.execute("INSERT INTO successions(id,defunt,country,dispositions) VALUES(%s,'Defunt','republic',%s)",(id,Json([d])))
   def regler(id='s'):c.execute('SELECT succession_regler(%s)',(id,));return c.fetchone()[0]
   c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('titre','republic','batiment','Defunt','{\"proprietaire\":\"Defunt\",\"city\":\"capitale\",\"subdivisions\":[{\"id\":\"lot\",\"surface\":300}],\"stock\":{\"bois\":2}}');INSERT INTO immobilier_biens VALUES('bien','titre',NULL)")
   creer();r=regler();ok(not r['cloturee'] and 'titres_murs_divergents' in r['echecs'][0],'contre-exemple : ancien reglement bloque par le vrai garde de titre #66')
   migration=(R/'migrations/20261021220316_succession_titres_canoniques.sql').read_text();c.execute(migration);c.execute(migration)
   r=regler();ok(r['cloturee'],'reglement commun compatible avec titre enregistre')
   c.execute("SELECT proprietaire,data::jsonb FROM terrains_etat WHERE id='titre'");owner,data=c.fetchone();ok(owner==data['proprietaire']=='Heritier','colonne et miroir transferee au meme beneficiaire')
   ok(data['subdivisions']==[{'id':'lot','surface':300}] and data['stock']=={'bois':2},'lots et stocks preserves')
   ok(not regler()['cloturee'],'rejeu aucun second transfert')
   c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('titre2','republic','batiment','Defunt','{\"proprietaire\":\"Defunt\",\"city\":\"ville_a\"}')")
   creer('ambigu');r=regler('ambigu');ok(not r['cloturee'] and 'ambigu' in r['echecs'][0],'ancien identifiant multi villes refuse, pas de selection arbitraire')
   creer('canonique','titre2');ok(regler('canonique')['cloturee'],'identifiant canonique resout exactement la bonne ville')
   creer('revendu','titre');r=regler('revendu');ok(not r['cloturee'] and 'titulaire_modifie' in r['echecs'][0],'titre deja transmis ou revendu non repris de force')
   c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('titre3','republic','local3','Defunt','{\"proprietaire\":\"Defunt\"}')")
   creer('sans-heritier','titre3',None);ok(regler('sans-heritier')['cloturee'],'absence de beneficiaire conserve le moteur existant')
   c.execute("SELECT proprietaire IS NULL AND data::jsonb->>'proprietaire' IS NULL FROM terrains_etat WHERE id='titre3'");ok(c.fetchone()[0],'vacance canonique coherente')
   # Ordre de consolidation : garde #69 puis coherence #66. Le patch ne retire pas la garde.
   c.execute(original)
   garde=R/'migrations/20261021220151_succession_refuser_actifs_non_raccordes.sql'
   if garde.exists():c.execute(garde.read_text())
   else:
    # Photographie du patch #69 pour cette PR independante ; aucun acces a une branche locale/au reseau en CI.
    avant="    BEGIN\n      IF (v_d ->> 'type') = 'terrain' THEN"
    apres="""    BEGIN
      -- #69 : jamais marquer un actif inconnu comme transmis sans moteur de transfert.
      IF coalesce(v_d->>'type','') NOT IN('terrain','entreprise','argent') THEN
        RAISE EXCEPTION 'type_disposition_non_pris_en_charge:%',coalesce(v_d->>'type','absent');
      END IF;
      IF (v_d ->> 'type') = 'terrain' THEN"""
    assert original.count(avant)==1;c.execute(original.replace(avant,apres))
   c.execute(migration);c.execute(migration)
   c.execute("SELECT position('type_disposition_non_pris_en_charge' in prosrc)>0 FROM pg_proc WHERE oid='succession_regler(text)'::regprocedure");ok(c.fetchone()[0],'compatibilite de garde #69 conservee')
  print(f'{n}/{n} assertions locales ; aucun patrimoine reel modifie.')
 finally:server.cleanup()
if __name__=='__main__':main()
