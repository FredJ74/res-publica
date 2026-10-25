#!/usr/bin/env python3
"""Contre la simplification des anciennes fixtures : resources réelles, sans inf/pop.
Les gardes vivantes restent à contrôler ; aucune prétention de test Supabase.
"""
from pathlib import Path
import importlib.util,re,json,sys,uuid
R=Path(__file__).resolve().parents[2]
VOL='--vol' in sys.argv;sys.argv[:]=[x for x in sys.argv if x!='--vol']
fichier='banc-vol-ordinaire-135-local.py' if VOL else 'banc-chasse-benediction-135-local.py'
spec=importlib.util.spec_from_file_location('parent',R/'outils/bancs'/fichier);base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
def suite(db,q,srv):
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK schema reel',msg,flush=True)
 def lire(s,args=()):q.execute(s,args or None);return q.fetchone()[0]
 q.execute("ALTER TABLE personnages_donnees ADD COLUMN IF NOT EXISTS resources jsonb DEFAULT '{}';ALTER TABLE personnages_donnees DROP COLUMN IF EXISTS inf;ALTER TABLE personnages_donnees DROP COLUMN IF EXISTS pop")
 check(lire("SELECT count(*) FROM pg_attribute WHERE attrelid='personnages_donnees'::regclass AND attname IN('inf','pop') AND NOT attisdropped")==0,'aucune colonne artificielle inf ou pop')
 if not VOL:q.execute((R/'migrations/20261025011201_filature_confirmation_financiere.sql').read_text())
 for _ in range(2):q.execute((R/'migrations/20261025105001_jets_resources_canoniques.sql').read_text())
 q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='commissariat',current_room='bureau_commissaire',pa=50,hp=100,stats='{\"PER\":13,\"CHA\":9}',resources='{\"inf\":30,\"pop\":50,\"dis\":12}' WHERE name='Fixture';UPDATE personnages_donnees SET resources='{\"inf\":0,\"pop\":40}',stats='{\"PER\":8,\"INT\":9}' WHERE name='Autre';CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT 1$$;UPDATE indices_villes SET data=data||'{\"isn\":45}' WHERE id='republic_capitale';UPDATE caisses_batiments SET data='{\"solde\":10000}' WHERE id='republic_commissariat_capitale'")
 lire("SELECT religion_benediction_consommer_interne(id,'fixture_schema_reel',gen_random_uuid()) FROM personnages_donnees WHERE name='Fixture'")
 if VOL:
  q.execute("UPDATE personnages_donnees SET country='soviet',current_building='armurerie',current_room='magasin',career='neutre',liquide=1000,arg=1000,stats='{\"PER\":9,\"CHA\":9}' WHERE name='Fixture';UPDATE personnages_donnees SET country='soviet',current_building='armurerie',current_room='magasin',stats='{\"PER\":10,\"INT\":9}' WHERE name='Autre';UPDATE comptes_bancaires SET solde=0;UPDATE terrain_actions_regles SET data=jsonb_set(data,'{indices,soviet,ISN}','0');CREATE OR REPLACE FUNCTION vol_hasard_interne() RETURNS numeric LANGUAGE sql AS $$SELECT 0$$")
  r=lire('SELECT vol_commande(%s,%s,%s)',('Autre','argent',str(uuid.uuid4())))
  check(r['ok'] and not r['succes'] and r['pop']==40,'sanction sovietique lit et ecrit resources.pop')
  res=lire("SELECT resources FROM personnages_donnees WHERE name='Fixture'")
  check(res=={'inf':30,'pop':40,'dis':12},'influence et discretion conservees avec la baisse de popularite')
  q.execute("ALTER TABLE pnj_membres ADD COLUMN IF NOT EXISTS car_int integer;INSERT INTO pnj_membres(id,nom,pays,ville,building_id,room_id,statut,car_per,car_int) VALUES('pnj-stats-schema-fixture','PNJ stats fixture','republic','capitale','armurerie','magasin','actif',16,17);UPDATE personnages_donnees SET country='republic' WHERE name='Fixture';UPDATE indices_villes SET data=data||'{\"isn\":0}' WHERE id='republic_capitale';CREATE OR REPLACE FUNCTION vol_hasard_interne() RETURNS numeric LANGUAGE sql AS $$SELECT .9999$$")
  r=lire('SELECT vol_commande(%s,%s,%s)',('PNJ stats fixture','argent',str(uuid.uuid4())))
  check(r['score']==75,'defaut prototype reproduit estimation neuf ignorant les caracteristiques du PNJ')
  for _ in range(2):q.execute((R/'migrations/20261025113501_vol_pnj_caracteristiques_reelles.sql').read_text())
  r=lire('SELECT vol_commande(%s,%s,%s)',('PNJ stats fixture','argent',str(uuid.uuid4())))
  check(r['score']==60 and r['butin']=='rien','caracteristiques PNJ seize et dix sept relues sans inventer de butin')

 else:
  r=lire('SELECT police_filature_commande(%s,%s)',('Autre',str(uuid.uuid4())))
  check(r['ok'] and r['taux']==63,'filature influence de trente points lue dans resources')
  lire("SELECT detention_clore_interne('Autre','fixture_fin')")
  q.execute("INSERT INTO actions_tracables(id,auteur,type_action,country,city,jour,jour_expiration) VALUES('trace-resources-schema','Autre','vol','republic','capitale',1,16)")
  r=lire('SELECT police_enquete_commande(%s,%s)',('Autre',str(uuid.uuid4())))
  check(r['ok'] and r['taux']==54 and r['decision']=='enquete_ouverte','enquete utilise la meme influence canonique')
  lire("SELECT detention_clore_interne('Autre','fixture_fin')")
  q.execute("INSERT INTO jugements(id,country,city,accuse,motif,jour,data) VALUES('jugement-resources-schema','republic','capitale','Autre','Fixture',900,'{\"motifs\":[{\"jours\":3}]}')")
  r=lire('SELECT police_chasse_commande(%s,%s)',('Autre',str(uuid.uuid4())))
  check(r['ok'] and r['taux']==64 and r['succes'],'chasse utilise la meme influence sans colonne inventee')
 check(lire("SELECT bool_and(prosrc !~ '(p|d)\\.(inf|pop)\\M') FROM pg_proc WHERE oid IN(to_regprocedure('police_filature_commande(text,uuid)'),to_regprocedure('police_enquete_commande(text,uuid)'),to_regprocedure('police_chasse_commande(text,uuid)'),to_regprocedure('vol_commande(text,text,uuid)'))"),'aucun hote installe ne lit inf ou pop comme colonne')
 print(json.dumps({'schema_canonique':True,'profil':'vol' if VOL else 'police','assertions':n,'supabase_vivant':False,'production':False}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':
 driver=base.base.base.base.base.banque.m if VOL else base.base.base.base.banque.m
 driver.main(tout)
