#!/usr/bin/env python3
"""Raccordement des vrais policiers/douaniers après les 49 cas de référence.
Identités et lieux fictifs, rôle authenticated ; aucun moteur de rue inventé.
"""
import importlib.util,re,sys,json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('corps',R/'outils/bancs/banc-groupes-corps-local.py');corps=importlib.util.module_from_spec(sp);sp.loader.exec_module(corps)

def suite(ctx):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']];a=corps.g.audit
 for nom in ['douane_autorite_de_perimetre','douane_caracteristiques_metier','douane_pnj_id']:
  q.execute(a.fonction('baseline/domaines/renseignement/20_fonctions.sql',nom))
 for nom in ['pnj_miroir_douane','pnj_miroir_douane_declencheur']:
  q.execute(a.fonction('baseline/domaines/socle-PNJ/20_fonctions.sql',nom))
 q.execute("INSERT INTO pnj_institutions VALUES('douane','douane_autorite_de_perimetre','resolveur reel')")
 q.execute("INSERT INTO personnages_donnees(name,user_id,country,current_city,current_building,current_room,inventory,poste,pa) VALUES('D','00000000-0000-4000-8000-000000000004','republic','ville_a','port-sainte-marie','controle-fixture','[{\"produitMilitaire\":\"radio\"}]','{\"id\":\"chef_douanes\"}',12)")
 q.execute("CREATE TRIGGER miroir_douane AFTER INSERT OR UPDATE ON batiments_etat FOR EACH ROW EXECUTE FUNCTION pnj_miroir_douane_declencheur()")
 q.execute("INSERT INTO batiments_etat(id,country,city,building_id,data) VALUES('douane-fixture','republic','ville_a','port-sainte-marie','{\"effectifsDouane\":{\"douaniers\":[{\"matricule\":\"D1\",\"buildingId\":\"port-sainte-marie\",\"roomId\":\"controle-fixture\"},{\"matricule\":\"D2\",\"buildingId\":\"port-sainte-marie\",\"roomId\":\"controle-fixture\"}]},\"autre\":99}')")
 original='--contre-force-publique' in sys.argv
 if not original:
  for f in ['20261028180000_groupes_force_publique_projection.sql','20261028180100_groupes_force_publique_portes.sql']:
   q.execute((R/'migrations'/f).read_text());q.execute((R/'migrations'/f).read_text())
 ctx['c'].commit() # Décor seulement, nouvelles connexions possibles.
 soldats=['cie-S1','cie-S2','cie-S3','cie-S4'];policiers=['police-republic-capitale-P'+str(n) for n in range(1,4)]
 douaniers=['douane-republic-ville_a-D1','douane-republic-ville_a-D2']
 def photo():
  q.execute('SELECT jsonb_agg(to_jsonb(m) ORDER BY id) FROM pnj_membres m');m=q.fetchone()[0]
  q.execute('SELECT jsonb_agg(to_jsonb(b) ORDER BY id) FROM batiments_etat b');return [m,q.fetchone()[0]]
 def groupe():
  exige(rpc('pnj_prendre',(soldats,)));exige(rpc('pnj_prendre',(policiers,),qui='B'))
  exige(rpc('pnj_transferer',(soldats,'B',False)))
  q.execute("SELECT count(*) FROM pnj_membres WHERE leader_pj='B'");assert q.fetchone()[0]==7
 def sept():
  groupe();sql("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='rue-fixture' WHERE name='B'")
  q.execute('SELECT count(*) FROM unnest(%s::text[]) id CROSS JOIN LATERAL pnj_position_effective(id) p WHERE p.rue_noeud_id=%s',(soldats+policiers,'rue-fixture'));assert q.fetchone()[0]==7
  exige(rpc('pnj_quitter_groupe',(['cie-S1'],),qui='B'))
  exige(rpc('pnj_prendre',(['cie-S1'],),qui='B'),'autorite_insuffisante')
  sql("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='rue-fixture' WHERE name='A'")
  exige(rpc('pnj_prendre',(['cie-S1'],)))
  exige(rpc('pnj_quitter_groupe',([policiers[0]],),qui='B'));exige(rpc('pnj_prendre',([policiers[0]],),qui='B'))
 cas('sept_vrais_pnj_suivi_derive_depose_et_reprise_par_autorite',sept)
 def miroir():
  exige(rpc('pnj_prendre',(policiers,),qui='B'))
  sql("UPDATE personnages_donnees SET current_building='bar',current_room='salle-fixture' WHERE name='B'")
  sql("UPDATE batiments_etat SET data=jsonb_set(data,'{autre}','77') WHERE id='capitale'")
  q.execute("SELECT count(*) FROM pnj_membres WHERE id=ANY(%s) AND leader_pj='B' AND ville IS NULL",(policiers,));assert q.fetchone()[0]==3
  q.execute("SELECT data FROM batiments_etat WHERE id='capitale'");v=q.fetchone()[0]
  assert v['autre']==77 and len(v['effectifsPolice']['policiers'])==3
  assert all(p['buildingId']=='bar' for p in v['effectifsPolice']['policiers']),v
 cas('miroir_police_preserve_suiveurs_et_projette_position_commune',miroir)
 def ancien_cache():
  q.execute("SELECT data FROM batiments_etat WHERE id='capitale'");ancien=q.fetchone()[0]
  exige(rpc('pnj_prendre',(policiers,),qui='B'))
  sql("UPDATE personnages_donnees SET current_building='bar',current_room='salle-fixture' WHERE name='B'")
  q.execute("UPDATE batiments_etat SET data=%s::jsonb WHERE id='capitale'",(json.dumps(ancien),))
  q.execute("SELECT data->'effectifsPolice'->'policiers' FROM batiments_etat WHERE id='capitale'")
  assert all(x['buildingId']=='bar' for x in q.fetchone()[0])
 cas('ancien_blob_de_position_ne_retablit_pas_une_ancienne_faction',ancien_cache)
 def territoire():
  exige(rpc('pnj_prendre',(['police-republic-ville_a-E1'],),qui='B'),'autorite_insuffisante')
 cas('commissaire_ne_reprend_pas_agent_autre_commissariat',territoire)
 def douane():
  exige(rpc('pnj_prendre',(douaniers,),qui='D'))
  sql("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='quai-fixture' WHERE name='D'")
  exige(rpc('pnj_deployer_unite',(douaniers,True),qui='D'))
  q.execute("SELECT data FROM batiments_etat WHERE id='douane-fixture'");v=q.fetchone()[0]
  assert v['autre']==99 and all(x['rueNoeudId']=='quai-fixture' for x in v['effectifsDouane']['douaniers']),v
  exige(rpc('pnj_prendre',(douaniers,),qui='D'))
 cas('vrais_douaniers_portes_communes_et_projection_rue',douane)
 def radio_douane():
  exige(rpc('pnj_prendre',(douaniers,),qui='D'));exige(rpc('pnj_deployer_unite',(douaniers,True),qui='D'))
  sql("INSERT INTO pnj_possessions(pnj_id,objet) VALUES('douane-republic-ville_a-D2','{\"produitMilitaire\":\"radio\"}')")
  sql("UPDATE personnages_donnees SET current_building='autre-fixture',current_room='bureau' WHERE name='D'")
  v=exige(rpc('pnj_rappeler_radio',(douaniers[0],),qui='D'));assert v['rappeles']==2
  exige(rpc('pnj_rappeler_radio',(douaniers[0],),qui='D'))
 cas('radio_unite_douaniere_et_rejeu_sans_dupliquer_objet',radio_douane)
 def radio_mixte():
  groupe();exige(rpc('pnj_deployer_unite',(soldats+policiers,True),qui='B'))
  sql("INSERT INTO pnj_possessions(pnj_id,objet) VALUES('cie-S4','{\"produitMilitaire\":\"radio\"}')")
  avant=photo();exige(rpc('pnj_rappeler_radio',('cie-S1',)),'autorite_insuffisante');assert photo()==avant
 cas('unite_mixte_radio_exige_toutes_les_autorites',radio_mixte)
 def confidentialite():
  v=exige(rpc('pnj_unites_administrables_lire',qui='B'))
  ids={m['id'] for m in v['membres']};assert set(policiers)<=ids
  assert not set(soldats)&ids and not set(douaniers)&ids and 'police-republic-ville_a-E1' not in ids
  groupe();v=exige(rpc('pnj_unites_administrables_lire',qui='B'))
  pret=[m for m in v['membres'] if m['id'] in soldats];assert len(pret)==4 and all(m['peut_administrer'] is False for m in pret)
 cas('lecture_groupe_reservee_autorite_ou_commandement_sans_transfert',confidentialite)
 def string_json():
  sql("UPDATE batiments_etat SET data=to_jsonb(data::text) WHERE id='capitale'")
  exige(rpc('pnj_prendre',(policiers,),qui='B'))
  exige(rpc('pnj_quitter_groupe',(policiers,),qui='B'))
  q.execute("SELECT jsonb_typeof(data),jsonb_array_length(batiment_etat_lire(data)->'effectifsPolice'->'policiers') FROM batiments_etat WHERE id='capitale'");assert q.fetchone()==('string',3)
 cas('projection_preserve_format_json_chaine_et_effectifs',string_json)
 def aucun_droit_interne():
  for role in ['anon','authenticated','service_role']:
   q.execute("SELECT has_function_privilege(%s,'pnj_groupes_projeter_institutions_interne(text[])','EXECUTE')",(role,));assert q.fetchone()[0] is False
 cas('projection_institutionnelle_inaccessible_du_reseau',aucun_droit_interne)

if __name__=='__main__':sys.exit(corps.g.main(lambda ctx:corps.extension(ctx,suite)))
