#!/usr/bin/env python3
"""Don de tracts : pile reelle et file existante, PostgreSQL jetable authenticated, rollback."""
from pathlib import Path
import importlib.util,re
R=Path(__file__).resolve().parents[2]
def scenario(q,own,call,check,uid,snapshot,Json):
 import psycopg2
 src=(R/'baseline/domaines/personnage-et-presence/10_tables.sql').read_text();own(re.search(r'CREATE TABLE public.objets_recus \([\s\S]*?\n\);',src)[0]);own('ALTER TABLE objets_recus ADD PRIMARY KEY(id)')
 for _ in range(2):own((R/'historique/migrations-appliquees/20261027215539_inventaire_dons_tracts.sql').read_text());own((R/'historique/migrations-appliquees/20261028210000_inventaire_anciens_contrats_fermes.sql').read_text())
 own("UPDATE personnages_donnees SET current_building='mairie-capitale',current_room='hall_mairie'")
 objet={'id':'tract-ancien','type':'tract','tractType':'pour','name':'Tracts','cible':'Autre','quantite':5,'memoire':'conservee','legal':True}
 own("UPDATE personnages_donnees SET inventory=%s WHERE name='Fixture'",(Json([objet]),));rev=own("SELECT inventory_revision FROM personnages_donnees WHERE name='Fixture'")
 def don(k,qty=2,revision=rev,dest='Autre'):return call('tracts_donner_joueur',[uid(k),0,revision,dest,qty])
 def snap():return own("SELECT jsonb_build_array((SELECT jsonb_agg(to_jsonb(d)) FROM personnages_donnees d),(SELECT jsonb_agg(to_jsonb(o)) FROM objets_recus o),(SELECT jsonb_agg(to_jsonb(r)) FROM inventaire_actions_recus r))")
 v=don(700);check(v['ok'] and v['inventory'][0]['quantite']==3,'don retire deux vrais tracts sans objet fourni par ecran')
 livraison=own('SELECT data FROM objets_recus');import json
 if isinstance(livraison,str):livraison=json.loads(livraison)
 check(livraison['quantite']==2 and livraison['memoire']=='conservee' and livraison['id']=='tract-ancien','sas existant recoit le lot exact et ses metadonnees')
 before=snap();check(don(700)['rejeu'] and snap()==before,'don reponse perdue sans second retrait ou envoi')
 own('DELETE FROM objets_recus');before=snap();check(don(700)['rejeu'] and snap()==before,'don collecte ne reapparait pas lors du rejeu expediteur')
 before=snap();check(don(701).get('raison')=='inventaire_perime' and snap()==before,'ancien index protege par revision')
 rev2=v['revision'];before=snap();check(don(702,qty=8,revision=rev2).get('raison')=='quantite_invalide' and snap()==before,'quantite superieure au vrai stock refusee')
 check(don(703,revision=rev2,dest='Inconnu').get('raison')=='destinataire_invalide','aucun joueur de simulation ne recoit un objet reel')
 own("UPDATE personnages_donnees SET current_room='ailleurs' WHERE name='Autre'");before=snap();check(don(704,revision=rev2).get('raison')=='pas_co_presents' and snap()==before,'co presence serveur requise');own("UPDATE personnages_donnees SET current_room='hall_mairie' WHERE name='Autre'")
 # Echec d'emission : le retrait qui precede est annule.
 own("CREATE FUNCTION fixture_don_refuser() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'fixture panne don';END $$;CREATE TRIGGER fixture_don BEFORE INSERT ON objets_recus FOR EACH ROW EXECUTE FUNCTION fixture_don_refuser()")
 before=snap();q.execute('SAVEPOINT panne_tracts')
 try:don(705,revision=rev2);raise AssertionError('panne non detectee')
 except psycopg2.Error:q.execute('ROLLBACK TO SAVEPOINT panne_tracts')
 check(snap()==before,'panne sas annule retrait revision et recu sans restitution cliente')
 check(call('tracts_donner_joueur',['don-tracts-ancien','Fixture','Autre',Json(objet)]).get('raison')=='contrat_versionne_requis','ancienne porte avec objet forge fermee')
if __name__=='__main__':
 spec=importlib.util.spec_from_file_location('base',R/'outils/bancs/banc-inventaire-receptions-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.main(scenario)
