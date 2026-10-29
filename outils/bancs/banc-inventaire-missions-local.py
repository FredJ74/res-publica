#!/usr/bin/env python3
"""Objets de mission/enigme, schema jetable. Les autres etapes restent explicitement legacy.
Appels authenticated avec path RPC, aucune transaction ni personnage de production.
"""
from pathlib import Path
import importlib.util
R=Path(__file__).resolve().parents[2]
def scenario(q,own,call,check,uid,snapshot,Json):
 own("ALTER TABLE personnages_donnees ADD COLUMN quete_carriere jsonb;ALTER TABLE personnages_donnees ADD COLUMN enigme1 jsonb;ALTER TABLE personnages_donnees ADD COLUMN created_at timestamp without time zone DEFAULT now();INSERT INTO ordres_couts VALUES('presenter_autorisation_coffre',1,0)")
 for _ in range(2):own((R/'migrations/20261027214213_inventaire_missions_et_enigme.sql').read_text())
 def mission(k,typ='pat'):return call('mission_carriere_recevoir',[uid(k),typ])
 def enigme(k,action='verifier',pa=0):return call('enigme_objet_recevoir',[uid(k),action,pa,0])
 def snap():return own("SELECT jsonb_build_array((SELECT to_jsonb(d) FROM personnages_donnees d WHERE name='Fixture'),(SELECT jsonb_agg(to_jsonb(r)) FROM inventaire_actions_recus r),(SELECT jsonb_agg(to_jsonb(t)) FROM actions_tracables t))")
 own("UPDATE personnages_donnees SET current_building='place-formulaire-liberte',current_room='place',inventory='[]',quete_carriere=%s WHERE name='Fixture'",(Json({'ambition':'criminel','etape':'a_rencontrer'}),))
 v=mission(501);check(v['ok'] and v['quete_carriere']['etape']=='colis_recu' and v['inventory'][0]['type']=='colis_secret_pat','colis et etape de mission dans la meme transaction')
 check(own("SELECT count(*) FROM actions_tracables WHERE type_action='colis_recu_pat_hounette'")==1,'trace publique de remise serveur unique')
 before=snap();check(mission(501)['rejeu'] and snap()==before,'rejeu colis sans seconde trace ni objet')
 own("UPDATE personnages_donnees SET quete_carriere=%s WHERE name='Fixture'",(Json({'ambition':'criminel','etape':'a_rencontrer'}),));before=snap();check(mission(502).get('raison')=='objet_deja_remis' and snap()==before,'ancienne sauvegarde ne reemet pas le colis')
 own("UPDATE personnages_donnees SET current_building='bureau-national-emploi',current_room='accueil',quete_carriere=%s WHERE name='Fixture'",(Json({'ambition':'politique','etape':'a_rencontrer'}),));v=mission(503,'jean_lou');check(v['ok'] and v['inventory'][-1]['quantite']==3 and v['inventory'][-1]['cible']=='Fixture','Jean-Lou : trois tracts pour le seul personnage authentifie')
 before=snap();check(mission(504,'pat').get('raison')=='pas_sur_place' and snap()==before,'Pat absent : refus sans mutation')
 # Horloge et variante ne viennent plus du navigateur.
 own("UPDATE personnages_donnees SET enigme1=NULL,created_at=now()-interval '71 hours',inventory='[]' WHERE name='Fixture'")
 v=enigme(505);check(v['ok'] and v['statut']=='inchange' and v['inventory']==[],'pas de calepin avant 72 heures reelles')
 own("UPDATE personnages_donnees SET created_at=now()-interval '73 hours' WHERE name='Fixture'");v=enigme(506);check(v['statut']=='declenchee' and v['inventory'][0]['id']=='calepin-enigme1' and v['enigme']['variante'] in ['maire','criminel','entrepreneur','plume'],'declenchement et tirage par horloge et RNG serveur')
 variante=v['enigme']['variante'];before=snap();check(enigme(506)['rejeu'] and snap()==before,'declenchement rejoue sans autre variante ou calepin')
 v=enigme(507);check(v['enigme']['variante']==variante and len(v['inventory'])==1,'nouvelle consultation conserve la variante et l objet')
 own("UPDATE personnages_donnees SET created_at=now()-interval '145 hours' WHERE name='Fixture'");v=enigme(508);check(v['enigme']['etape']=='relancee','relance apres 144 heures reelles sans autre objet')
 own("UPDATE personnages_donnees SET current_building='banque-nationale',current_room='accueil_banque',pa=20 WHERE name='Fixture'")
 v=enigme(509,'coffre',1);check(v['ok'] and v['statut']=='sans_autorisation' and v['paie']['pa']==19,'cout historique de presentation sans autorisation conserve')
 own("UPDATE personnages_donnees SET enigme1=jsonb_set(enigme1,'{autorisationCoffre}','true') WHERE name='Fixture'");v=enigme(510,'coffre',1);check(v['statut']=='cle_remise' and v['inventory'][-1]['id']=='cle-debarras-musee' and v['enigme']['coffreOuvert'],'cle et ouverture persistantes ensemble')
 before=snap();check(enigme(510,'coffre',1)['rejeu'] and snap()==before,'reponse coffre perdue : aucun nouveau PA ni cle')
 v=enigme(511,'coffre',1);check(v['statut']=='deja_ouvert' and len(v['inventory'])==2,'nouvelle presentation coffre vide sans duplication')
 own("UPDATE personnages_donnees SET enigme1=jsonb_set(enigme1,'{coffreOuvert}','false') WHERE name='Fixture'");v=enigme(512,'coffre',1);check(v['statut']=='deja_ouvert' and len(v['inventory'])==2,'ancienne sauvegarde ne rend pas une seconde cle')
 own("UPDATE personnages_donnees SET current_room='ailleurs' WHERE name='Fixture'");before=snap();check(enigme(513,'coffre',1).get('raison')=='pas_sur_place' and snap()==before,'coffre hors banque refuse avant cout')
if __name__=='__main__':
 spec=importlib.util.spec_from_file_location('base',R/'outils/bancs/banc-inventaire-receptions-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.main(scenario)
