#!/usr/bin/env python3
"""Emission de recompenses objets, pas validation de toute la progression encore legacy.
Role authenticated, schema jetable et rollback ; aucun personnage reel.
"""
from pathlib import Path
import importlib.util,re
R=Path(__file__).resolve().parents[2]
def scenario(q,own,call,check,uid,snapshot,Json):
 import psycopg2
 src=(R/'baseline/domaines/personnage-et-presence/10_tables.sql').read_text();own(re.search(r'CREATE TABLE public.quetes_actives \([\s\S]*?\n\);',src)[0]);own('ALTER TABLE quetes_actives ADD PRIMARY KEY(id)')
 for _ in range(2):own((R/'historique/migrations-appliquees/20261027215214_inventaire_recompenses_objets.sql').read_text())
 own("UPDATE personnages_donnees SET current_building='mairie-capitale',current_room='hall_mairie',inventory='[]' WHERE name='Fixture'")
 own("INSERT INTO quetes_actives(id,country,titre,description,etape_actuelle,nb_etapes_total,building_id,room_id,recompense_type,jour_creation) VALUES('q1','republic','Titre fictif','Description fictive',2,3,'mairie-capitale','hall_mairie','objet',1)")
 def cadeau(k):return call('quete_objet_reclamer',[uid(k),'q1'])
 def snap():return own("SELECT jsonb_build_array((SELECT to_jsonb(d) FROM personnages_donnees d WHERE name='Fixture'),(SELECT jsonb_agg(to_jsonb(t)) FROM quetes_actives t),(SELECT jsonb_agg(to_jsonb(r)) FROM inventaire_actions_recus r))")
 before=snap();check(cadeau(600).get('raison')=='quete_non_terminee' and snap()==before,'pas de recompense avant derniere etape')
 own("UPDATE quetes_actives SET etape_actuelle=3");v=cadeau(600);check(v['ok'] and len(v['inventory'])==1 and 'origine' not in v['inventory'][0],'objet tire du catalogue sans fausse origine objets trouves')
 check(own("SELECT statut FROM quetes_actives")=='resolue','resolution et depot ensemble')
 before=snap();check(cadeau(600)['rejeu'] and snap()==before,'reponse perdue sans seconde recompense')
 check(cadeau(601).get('raison')=='quete_indisponible','autre requete sur quete resolue refusee')
 own("UPDATE quetes_actives SET statut='active'");before=snap();check(cadeau(602).get('raison')=='recompense_deja_remise' and snap()==before,'ancienne sauvegarde ne reouvre pas un cadeau deja remis')
 own("INSERT INTO quetes_actives(id,country,titre,description,etape_actuelle,nb_etapes_total,building_id,room_id,recompense_type,cible_dossier,jour_creation) VALUES('q2','republic','Dossier fictif','Description',3,3,'mairie-capitale','hall_mairie','dossier_surveillance','Autre',1)")
 own("INSERT INTO actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration) VALUES('t1','Autre','Cible fictive','fait_fixture','republic','capitale',1,99999),('t2','Autre',NULL,'expire','republic','capitale',1,0),('t3','Autre',NULL,'autre_ville','republic','ville_a',1,99999)")
 v=call('quete_objet_reclamer',[uid(603),'q2']);texte=v['inventory'][-1]['desc'];check(v['ok'] and 'fait_fixture' in texte and 'expire' not in texte and 'autre_ville' not in texte,'dossier derive seulement des faits reels encore valides de cette ville')
 own("INSERT INTO quetes_actives(id,country,titre,description,etape_actuelle,nb_etapes_total,building_id,room_id,recompense_type,jour_creation) VALUES('q3','republic','Sans place','Description',3,3,'mairie-capitale','hall_mairie','objet',1)")
 own("UPDATE personnages_donnees SET inventory=%s WHERE name='Fixture'",(Json([{'stackable':True,'stackKey':'bois','qty':100}]),));before=snap();check(call('quete_objet_reclamer',[uid(604),'q3']).get('raison')=='inventaire_plein' and snap()==before,'inventaire plein : quete non consommee sans objet')
 own("UPDATE personnages_donnees SET inventory='[]' WHERE name='Fixture'");own("CREATE FUNCTION fixture_quetes_refus() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.statut='resolue' THEN RAISE EXCEPTION 'fixture panne resolution';END IF;RETURN NEW;END $$;CREATE TRIGGER fixture_resolution BEFORE UPDATE ON quetes_actives FOR EACH ROW EXECUTE FUNCTION fixture_quetes_refus()")
 before=snap();q.execute('SAVEPOINT panne_quete')
 try:call('quete_objet_reclamer',[uid(605),'q3']);raise AssertionError('panne ignoree')
 except psycopg2.Error:q.execute('ROLLBACK TO SAVEPOINT panne_quete')
 check(snap()==before,'panne resolution apres depot annule objet revision et recu')
if __name__=='__main__':
 spec=importlib.util.spec_from_file_location('base',R/'outils/bancs/banc-inventaire-receptions-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.main(scenario)
