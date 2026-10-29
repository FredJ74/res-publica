#!/usr/bin/env python3
"""Véritables contrôles, embarquement, billets et positions du groupe fictif."""
import importlib.util,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('douanes',R/'outils/bancs/banc-groupes-douanes-local.py');d=importlib.util.module_from_spec(sp);sp.loader.exec_module(d)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 for nom in ['20261028215600_transport_zone_embarquement.sql','20261028215800_transport_international_moteur_commun.sql']:
  q.execute((R/'migrations'/nom).read_text());q.execute((R/'migrations'/nom).read_text())
 if '--contre-controle-par-membre' in sys.argv:
  q.execute("SELECT pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure)")
  s=q.fetchone()[0];a="public.douane_passage_valide_interne(p_nom,'avion')";assert s.count(a)==1
  q.execute(s.replace(a,"public.douane_passage_valide_interne(public.mon_personnage(),'avion')"))
 ctx['c'].commit()
 req=lambda n:f'00000000-0000-4000-8000-{n:012d}'
 def depart():
  sql("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='centre-multinodal-luthecia',current_room='hall_douanes',current_street=NULL,pa=12 WHERE name IN ('A','B');UPDATE personnages_donnees SET liquide=5000,arg=5000 WHERE name='B'")
 def controle():return rpc('douane_controle_groupe',('avion',req(601)),qui='B')
 def embarquer():return rpc('navigation_interieure',('centre-multinodal-luthecia','zone_embarquement'),qui='B')
 def billet(mode='avion'):return rpc('transport_effectuer',(mode,'soviet','capitale',req(602)),qui='B')
 def photo():
  q.execute('SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d');return q.fetchone()[0]
 def vol():
  depart();exige(controle());exige(embarquer());v=exige(billet())
  assert v['voyageurs']==9 and v['paie']['montant_preleve']==2700,v
  q.execute("SELECT liquide,pa,country,current_city,current_building,current_room FROM personnages_donnees WHERE name='B'")
  assert q.fetchone()==(2300,10,'soviet','capitale','centre-multinodal-luthecia','hall_gare')
  q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()==(500,12)
  q.execute("SELECT count(*) FROM pnj_membres m CROSS JOIN LATERAL pnj_position_effective(m.id) pe WHERE m.leader_pj='B' AND pe.pays='soviet'");assert q.fetchone()[0]==7
  q.execute('SELECT count(*) FROM navigation_passages_douaniers');assert q.fetchone()[0]==0
  avant=photo();assert billet()==v;assert photo()==avant
 cas('voyage_vol_complet_controle_embarquement_9_paiement_unique_arrivee_rejeu',vol)
 def sans_controle():
  depart();avant=photo();exige(embarquer(),'controle_douanier_requis');assert photo()==avant
 cas('voyage_faux_douanePassee_ne_permet_pas_embarquement',sans_controle)
 def membre_omis():
  depart();exige(controle());sql("DELETE FROM navigation_passages_douaniers WHERE personnage='A'")
  avant=photo();exige(embarquer(),'controle_douanier_requis');assert photo()==avant
 cas('voyage_autorisation_du_chef_ne_couvre_pas_autre_PJ',membre_omis)
 def fonds():
  depart();exige(controle());exige(embarquer());sql("UPDATE personnages_donnees SET liquide=500,arg=500 WHERE name='B'")
  # Objet reçu après le contrôle : recontrôlé avant le départ. Si le paiement
  # global échoue, cette nouvelle saisie et sa convocation sont aussi annulées.
  sql("UPDATE personnages_donnees SET inventory='[{\"id\":\"recu-apres-controle\",\"type\":\"poison\",\"name\":\"Objet interdit\",\"legal\":false}]' WHERE name='A'")
  avant=photo();exige(billet(),'fonds_insuffisants');assert photo()==avant
  q.execute('SELECT count(*) FROM confiscations_douanieres');assert q.fetchone()[0]==0
 cas('voyage_fonds_insuffisants_annule_ensemble_nouvelle_saisie_debit_positions',fonds)
 def bateau():
  depart();sql("UPDATE personnages_donnees SET current_city='ville_a',current_building='port-sainte-marie',current_room='quai_principal' WHERE name IN ('A','B')")
  v=exige(billet('bateau'));assert v['voyageurs']==9 and v['paie']['montant_preleve']==900 and v['paie']['pa_preleves']==5,v
  q.execute("SELECT liquide,pa,country FROM personnages_donnees WHERE name='B'");assert q.fetchone()==(4100,7,'soviet')
 cas('voyage_bateau_controle_existants_9_voyageurs_tarif_et_PA_historiques',bateau)
 def intra():
  depart();sql("UPDATE personnages_donnees SET current_room='hall_gare' WHERE name IN ('A','B')")
  v=exige(rpc('transport_effectuer',('train','republic','ville_a',req(602)),qui='B'))
  assert v['voyageurs']==9 and v['paie']['montant_preleve']==675 and v['paie']['pa_preleves']==2,v
 cas('voyage_extension_internationale_ne_casse_pas_train_collectif',intra)
 def individuel():
  sql("UPDATE personnages_donnees SET current_building='centre-multinodal-luthecia',current_room='hall_douanes',current_city='capitale',country='republic',current_street=NULL,pa=12,liquide=500,arg=500 WHERE name='C'")
  exige(rpc('douane_controle_groupe',('avion',req(601)),qui='C'))
  exige(rpc('navigation_interieure',('centre-multinodal-luthecia','zone_embarquement'),qui='C'))
  v=exige(rpc('transport_effectuer',('avion','soviet','capitale',req(602)),qui='C'))
  assert v['voyageurs']==1 and v['paie']['montant_preleve']==300 and v['paie']['pa_preleves']==2,v
  q.execute("SELECT liquide,pa,country FROM personnages_donnees WHERE name='C'");assert q.fetchone()==(200,10,'soviet')
 cas('voyage_vol_individuel_conserve_tarif_et_PA_existants',individuel)
 if suivante is not None:suivante(ctx)
if __name__=='__main__':sys.exit(d.i.lancer(lambda c:d.suite(c,suite)))
