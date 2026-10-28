#!/usr/bin/env python3
"""Parcours intérieur et rue avec les mêmes acteurs/contraintes, sans production.
Catalogue réel généré de data.js ; 86 cas précédents conservés avant extension.
"""
import importlib.util,sys,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('natif',R/'outils/bancs/banc-groupes-detecteur-historique-local.py');natif=importlib.util.module_from_spec(sp);sp.loader.exec_module(natif)
def suite(ctx):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 subprocess.run(['node','outils/generateurs/navigation-lieux.cjs','--verifier'],cwd=R,check=True,stdout=sys.stderr)
 q.execute('''CREATE TABLE batailles_engagements(bataille_id bigint,personnage text,sorti_round integer);
 CREATE TABLE batiments_fermes(pays text,ville text,batiment_id text,date_fin_universelle date,jour_fin integer);
 INSERT INTO rue_sorties_batiments VALUES('republic','capitale','hotel-republica','rue-1');''')
 for p in sorted((R/'migrations').glob('20261028185*.sql')):
  if '185800_' not in p.name:q.execute(p.read_text());q.execute(p.read_text())
 q.execute((R/'migrations/20261028185800_navigation_positions_sauvegardes.sql').read_text())
 q.execute((R/'migrations/20261028185800_navigation_positions_sauvegardes.sql').read_text())
 q.execute("""CREATE VIEW sauvegarde_fixture AS SELECT name,country,current_city,current_building,current_room,current_street FROM personnages_donnees;
 GRANT SELECT,UPDATE ON sauvegarde_fixture TO authenticated;""")
 ctx['c'].commit()
 def photo():
  q.execute('SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d');a=q.fetchone()[0]
  q.execute('SELECT jsonb_agg(to_jsonb(m) ORDER BY id) FROM pnj_membres m');b=q.fetchone()[0]
  q.execute('SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM batiments_etat t');return [a,b,q.fetchone()[0]]
 def dedans(piece='accueil',qui='B',building='hotel-republica'):return rpc('navigation_interieure',(building,piece),qui=qui)
 def trajet():
  v=exige(dedans());assert v['membres']==['A','B']
  for piece in ['bar','restaurant','accueil']:
   exige(dedans(piece))
   q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_building='hotel-republica' AND current_room=%s AND current_street IS NULL",(piece,));assert q.fetchone()[0]==2
   q.execute("SELECT count(*) FROM pnj_membres m CROSS JOIN LATERAL pnj_position_effective(m.id) p WHERE m.leader_pj IN ('A','B') AND p.building_id='hotel-republica' AND p.room_id=%s",(piece,));assert q.fetchone()[0]==7
  avant=photo();v=exige(dedans());assert v['deja_present'] and photo()==avant
  exige(rpc('rue_position_enregistrer',('rue-1',),qui='B'));exige(rpc('rue_position_enregistrer',('rue-2',),qui='B'))
 cas('interieur_parcours_2PJ_7PNJ_rue_accueil_bar_restaurant_sortie_rue',trajet)
 def refus(raison,prepare='SELECT 1',piece='accueil',qui='B',building='hotel-republica'):
  sql(prepare);avant=photo();exige(dedans(piece,qui,building),raison);assert photo()==avant
 cas('interieur_membre_ne_commande_pas',lambda:refus('chef_de_groupe_requis',qui='A'))
 cas('interieur_piece_inconnue_refusee',lambda:refus('destination_inconnue',piece='inventee'))
 cas('interieur_entree_sans_raccord_rue_refusee',lambda:refus('entree_non_accessible',building='banque-nationale',piece='accueil_banque'))
 cas('interieur_prison_membre_refusee',lambda:refus('personnage_indisponible',"UPDATE personnages_donnees SET est_emprisonne='{}' WHERE name='A'"))
 cas('interieur_combat_membre_refuse',lambda:refus('combat_en_cours',"INSERT INTO batailles(id,pays,statut) VALUES(1,'republic','en_cours');INSERT INTO batailles_engagements VALUES(1,'A',NULL)"))
 cas('interieur_interception_membre_refusee',lambda:refus('interception_en_cours',"INSERT INTO police_interceptions(personnage,expires_at) VALUES('A',now()+interval '1 hour')"))
 cas('interieur_surcharge_membre_refusee',lambda:refus('inventaire_surcharge',"UPDATE personnages_donnees SET inventory='[{\"qty\":101}]' WHERE name='A'"))
 def surcharge_dedans():
  exige(dedans());sql("UPDATE personnages_donnees SET inventory='[{\"qty\":101}]' WHERE name='A'");exige(dedans('bar'))
 cas('interieur_surcharge_ne_bloque_pas_changement_piece',surcharge_dedans)
 cas('interieur_fermeture_refusee',lambda:refus('batiment_ferme',"INSERT INTO batiments_fermes VALUES('republic','capitale','hotel-republica','2999-01-01',99)"))
 cas('interieur_coma_membre_refuse',lambda:refus('acteur_incapacite',"UPDATE personnages_donnees SET hp=0 WHERE name='B'"))
 cas('interieur_groupe_disperse_refuse',lambda:refus('groupe_disperse',"UPDATE personnages_donnees SET current_street='rue-2' WHERE name='A'"))
 def rue_combat():
  sql("INSERT INTO batailles(id,pays,statut) VALUES(1,'republic','en_cours');INSERT INTO batailles_engagements VALUES(1,'A',NULL)")
  avant=photo();exige(rpc('rue_position_enregistrer',('rue-2',),qui='B'),'combat_en_cours');assert photo()==avant
 cas('rue_meme_garde_combat_que_interieur',rue_combat)
 def acl():
  for role in ['anon','authenticated','service_role']:
   for sig in ['navigation_disponibilite_interne(text)','navigation_commander_interne(text,text,text)','navigation_interieure_personnage_interne(text,text,text,boolean)']:
    q.execute('SELECT has_function_privilege(%s,%s,%s)',(role,sig,'EXECUTE'));assert q.fetchone()[0] is False
 cas('interieur_helpers_non_appelables_par_client',acl)
 def sauvegarde():
  exige(dedans());
  q.execute("SELECT current_building,current_room,current_street FROM personnages_donnees WHERE name='A'");avant=q.fetchone()
  q.execute("SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true),set_config('request.path','/personnages',true),set_config('role','authenticated',true)")
  q.execute("UPDATE sauvegarde_fixture SET country='autre',current_city='autre',current_building='mairie',current_room='ancien',current_street='ancien' WHERE name='A'")
  q.execute('RESET ROLE')
  q.execute("SELECT current_building,current_room,current_street,country,current_city FROM personnages_donnees WHERE name='A'");assert q.fetchone()==(*avant,'republic','capitale')
  exige(rpc('rue_position_enregistrer',('rue-1',),qui='B'))
 cas('interieur_sauvegarde_ancienne_via_vue_ne_retablit_pas_position',sauvegarde)

if __name__=='__main__':
 rue=natif.rue;f=rue.force
 sys.exit(f.corps.g.main(lambda c:f.corps.extension(c,lambda c:f.suite(c,lambda c:rue.suite(c,lambda c:natif.suite(c,suite))))))
