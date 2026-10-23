#!/usr/bin/env python3
"""Meme vente/don et memes prix, sans dupliquer le moteur d'inventaire."""
import importlib.util,re,json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('materiaux',R/'outils/bancs/banc-construction-materiaux-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def fn(f,nom):
 s=(R/f).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');v=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+v.end()]
def suite(db,c,server):
 import psycopg2
 n=0
 def q(s,a=()):
  c.execute(s,a);v=c.fetchone()[0];db.commit();return v
 def ok(v,t):
  nonlocal n
  assert v,t;n+=1;print('OK materiaux reamenagement',t,flush=True)
 c.execute("CREATE ROLE service_role;ALTER TABLE personnages_donnees ADD COLUMN hp integer DEFAULT 100,ADD COLUMN hospitalisation jsonb;CREATE OR REPLACE VIEW personnages AS SELECT * FROM personnages_donnees;ALTER TABLE terrains_etat ADD COLUMN country text,ADD COLUMN building_id text;UPDATE terrains_etat SET country='republic',building_id=substring(id from 10) WHERE id='republic_terrain'")
 # Le prefixe republic_ fait neuf caracteres ; aucune donnee joueur n'est reconstruite.
 c.execute(fn('migrations/20261022124055_chantier_autorite_et_recus.sql','chantier_autorite_exiger_interne'))
 c.execute(fn('migrations/20261022130419_chantier_prix_representants.sql','chantier_prix_definir'))
 src=(R/'baseline/domaines/justice/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public.detentions \(.*?\n\);',src,re.S)[0]);c.execute(fn('baseline/domaines/justice/20_fonctions-1.sql','detention_active'))
 migration=next((R/'migrations').glob('*_chantier_materiaux_et_prix_reamenagement.sql')).read_text();c.execute(migration);c.execute(migration)
 ch={'type':'reamenagement','dureeJours':3,'progressionJours':0,'coutTotal':3000,'tresorerie':200,'stockMateriaux':{},'prixAchatPJ':{'bois':7}}
 etat={'city':'capitale','proprietaire':'Fixture','niveau_construction':'commerce_premium','chantierReamenagement':ch}
 c.execute("UPDATE terrains_etat SET data=%s WHERE id='republic_terrain'",(json.dumps(etat),));c.execute("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='terrain',hp=100,arg=100,liquide=100,inventory='[{\"stackKey\":\"bois\",\"stackable\":true,\"qty\":50}]';UPDATE comptes_bancaires SET solde=0");db.commit()
 def appel(req,qty=2,prix=999,cur=c):
  cur.execute('SELECT vendre_materiaux_chantier(%s,%s,%s,%s,%s,%s,%s)',('Fixture','republic','terrain','bois',qty,prix,req));v=cur.fetchone()[0];cur.connection.commit();return v
 def photo():return q("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(t ORDER BY id) FROM terrains_etat t))")
 r=q("SELECT chantier_prix_definir('terrain','{\"bois\":8}')");ok(r['ok'] and r['etat']['chantierReamenagement']['prixAchatPJ']['bois']==8,'prix du proprietaire par le meme moteur')
 r=appel('ream-vente-0001');ok(r['ok'] and r['montant']==16 and r['prixUnitaire']==8,'vendeur ne peut imposer 999 FR')
 ok(q('SELECT liquide FROM personnages_donnees')==116 and q("SELECT (data::jsonb->'chantierReamenagement'->>'tresorerie')::numeric FROM terrains_etat WHERE id='republic_terrain'")==184,'contreparties vendeur et tresorerie exactes')
 ok(not q("SELECT data::jsonb ? 'chantier' FROM terrains_etat WHERE id='republic_terrain'"),'aucun second chantier cree')
 avant=photo();ok(appel('ream-vente-0001')['rejeu'] and photo()==avant,'reponse perdue aucun double stock ni credit')
 r=appel('ream-don-000001',qty=1,prix=0);ok(r['ok'] and r['montant']==0 and q('SELECT liquide FROM personnages_donnees')==116,'don gratuit par le meme moteur')
 avant=photo();ok(appel('ream-don-000001',qty=1,prix=0)['rejeu'] and photo()==avant,'rejeu du don sans double transfert')
 c.execute('UPDATE personnages_donnees SET hp=0');avant=photo();ok(appel('ream-coma-00001')['raison']=='acteur_indisponible' and photo()==avant,'coma serveur avant inventaire et paiement');c.execute('UPDATE personnages_donnees SET hp=100');db.commit()
 avant=photo();r=q("SELECT chantier_prix_definir('terrain','{\"bois\":8.5}')");ok(not r['ok'] and photo()==avant,'prix fractionnaire refuse')
 definition=q("SELECT pg_get_functiondef('inventaire_reception_etat(text)'::regprocedure)");c.execute("CREATE OR REPLACE FUNCTION inventaire_reception_etat(text) RETURNS jsonb LANGUAGE sql AS $$SELECT '{\"ok\":false}'::jsonb$$");avant=photo()
 try:appel('ream-panne-00001');raise AssertionError('panne attendue')
 except psycopg2.Error as e:db.rollback();assert 'inventaire_non_confirme' in str(e)
 ok(photo()==avant,'panne inventaire annule argent, objets, stocks et tresorerie');c.execute(definition);db.commit()
 argent=q('SELECT liquide FROM personnages_donnees')
 def concurrent(_):
  with psycopg2.connect(server.get_uri()) as d:return appel('ream-concurrent1',qty=1,cur=d.cursor())
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,range(2)))
 ok(all(r['ok'] for r in rs) and sum(bool(r.get('rejeu')) for r in rs)==1 and q('SELECT liquide FROM personnages_donnees')==argent+8,'concurrence un seul paiement et un seul transfert')
 c.execute("UPDATE personnages_donnees SET current_city='ailleurs'");avant=photo();ok(not appel('ream-autreville1')['ok'] and photo()==avant,'territoire serveur preserve')
 print(json.dumps({'materiaux_reamenagement':True,'assertions':n,'production':False}))
if __name__=='__main__':m.main(suite)
