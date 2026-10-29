#!/usr/bin/env python3
"""Taxis spéciaux dans transport_effectuer, tarifs réels et neuf voyageurs fictifs."""
import importlib.util,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('collectif',R/'outils/bancs/banc-groupes-interception-collective-local.py');c=importlib.util.module_from_spec(sp);sp.loader.exec_module(c)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 q.execute((R/'migrations/20261029125000_transport_taxis_speciaux_communs.sql').read_text())
 q.execute((R/'migrations/20261029125000_transport_taxis_speciaux_communs.sql').read_text())
 ctx['c'].commit()
 req=lambda n:f'00000000-0000-4000-8000-{n:012d}'
 def depart():
  sql("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='centre-multinodal-luthecia',current_room='hall_gare',current_street=NULL,pa=12,hp=100 WHERE name IN ('A','B')")
  sql("UPDATE pnj_membres SET pa=12 WHERE leader_pj='B'")
  sql("UPDATE personnages_donnees SET arg=5000,liquide=5000 WHERE name='B'")
 def photo():
  q.execute("SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d");return q.fetchone()[0]
 def trajet(zone):
  depart();v=exige(rpc('transport_effectuer',('taxi_'+zone,'republic',zone,req(8801)),qui='B'))
  assert v['voyageurs']==9 and len(v['paiements'])==1,v
  q.execute("SELECT liquide,pa,current_city,current_building,current_room FROM personnages_donnees WHERE name='B'")
  assert q.fetchone()==(3200,11,zone,'caserne-militaire' if zone=='caserne' else 'qhs-prison','corps_garde' if zone=='caserne' else 'entree_qhs')
  avant=photo();assert rpc('transport_effectuer',('taxi_'+zone,'republic',zone,req(8801)),qui='B')==v;assert photo()==avant
  q.execute("SELECT count(*) FROM pnj_membres m CROSS JOIN LATERAL pnj_position_effective(m.id) p WHERE m.leader_pj='B' AND p.ville=%s",(zone,));assert q.fetchone()[0]==7
  exige(rpc('navigation_interieure',(None,None),qui='B'))
  entree='corps_garde' if zone=='caserne' else 'entree_qhs';bat='caserne-militaire' if zone=='caserne' else 'qhs-prison'
  exige(rpc('navigation_interieure',(bat,entree),qui='B'));exige(rpc('navigation_interieure',(None,None),qui='B'))
  retour=exige(rpc('transport_effectuer',('bus','republic','capitale',req(8802)),qui='B'));assert retour['voyageurs']==9
  q.execute("SELECT liquide,pa,current_city FROM personnages_donnees WHERE name='B'");assert q.fetchone()==(1850,10,'capitale')
 for zone in ['caserne','qhs']:cas('taxi_'+zone+'_9voyageurs_1800FR_1PA_entree_sortie_retour_bus_rejeu',lambda zone=zone:trajet(zone))
 def fonds():
  depart();sql("UPDATE personnages_donnees SET arg=0,liquide=0 WHERE name='B'");avant=photo()
  exige(rpc('transport_effectuer',('taxi_caserne','republic','caserne',req(8803)),qui='B'),'fonds_insuffisants');assert photo()==avant
 cas('taxi_special_insuffisant_annule_ensemble',fonds)
 def prison():
  depart();sql("UPDATE personnages_donnees SET est_emprisonne='{}' WHERE name='A'");avant=photo()
  exige(rpc('transport_effectuer',('taxi_qhs','republic','qhs',req(8804)),qui='B'),'personnage_indisponible');assert photo()==avant
 cas('taxi_special_membre_detenu_refuse_avant_paiement',prison)
 def detour():
  depart();avant=photo();exige(rpc('transport_effectuer',('taxi_qhs','republic','ville_a',req(8805)),qui='B'),'destination_invalide');assert photo()==avant
 cas('taxi_special_ne_permet_pas_destination_arbitraire',detour)
 ctx['preuves_extension']['taxis']='Même transport/paiement/reçu, tarifs extraits du dépôt, zones spéciales du catalogue réel et non de villes. Neuf voyageurs, entrée/sortie publique et bus retour, refus atomiques.'
 if suivante is not None:suivante(ctx)
if __name__=='__main__':sys.exit(c.lancer(suite))
