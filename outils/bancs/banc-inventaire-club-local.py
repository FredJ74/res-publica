#!/usr/bin/env python3
"""Achat accessoire par le moteur existant : PostgreSQL jetable, authenticated, rollback."""
from pathlib import Path
import importlib.util,re
R=Path(__file__).resolve().parents[2]
def scenario(q,own,call,check,uid,snapshot,Json):
 import psycopg2
 for table,domain in [('clubs_sportifs_regles','sport'),('budgets_clubs','finances-publiques')]:
  s=(R/f'baseline/domaines/{domain}/10_tables.sql').read_text();own(re.search(r'CREATE TABLE public\.'+table+r' \([\s\S]*?\n\);',s)[0]);own(f'ALTER TABLE {table} ADD PRIMARY KEY('+('club_id' if table=='clubs_sportifs_regles' else 'id')+');')
 for _ in range(2):own((R/'historique/migrations-appliquees/20261027213522_inventaire_accessoires_club.sql').read_text())
 own("INSERT INTO clubs_sportifs_regles VALUES('fixture-club','Club fictif','republic','capitale',70);INSERT INTO ordres_couts VALUES('choisir_accessoire_club',0,0)")
 own("UPDATE personnages_donnees SET current_building='stade',current_room='buvette',inventory='[]',liquide=100,arg=300 WHERE name='Fixture'")
 def achat(k,modele='echarpe',pa=0,cost=0):return call('club_accessoire_acheter',[uid(k),modele,pa,cost])
 def snap():return own("SELECT jsonb_build_array((SELECT to_jsonb(d) FROM personnages_donnees d WHERE name='Fixture'),(SELECT jsonb_agg(to_jsonb(b)) FROM budgets_clubs b),(SELECT jsonb_agg(to_jsonb(c)) FROM comptes_bancaires c),(SELECT jsonb_agg(to_jsonb(r)) FROM inventaire_actions_recus r))")
 v=achat(301);check(v['ok'] and v['prix']==80 and v['inventory'][0]['name']=='Écharpe — Club fictif','club et objet issus des catalogues serveur')
 check(own("SELECT (data->>'caisse')::integer FROM budgets_clubs")==80,'credit exact du budget existant')
 before=snap();check(achat(301)['rejeu'] and snap()==before,'accessoire reponse perdue sans second debit credit objet')
 before=snap();check(achat(302,'pirate').get('raison')=='accessoire_inconnu' and snap()==before,'modele inconnu refuse sans contrepartie')
 check(achat(302,'maillot',3).get('raison')=='cout_non_declare','cout non declare refuse')
 own("UPDATE personnages_donnees SET current_room='vestiaires' WHERE name='Fixture'");before=snap();check(achat(303).get('raison')=='pas_sur_place' and snap()==before,'achat hors buvette refuse')
 own("UPDATE personnages_donnees SET current_room='buvette',liquide=0,arg=0 WHERE name='Fixture'");own("UPDATE comptes_bancaires SET solde=0 WHERE personnage='Fixture'");before=snap();check(achat(303).get('raison')=='fonds_insuffisants' and snap()==before,'fonds insuffisants sans depot ni credit')
 own("UPDATE personnages_donnees SET liquide=100,arg=300 WHERE name='Fixture'");own("UPDATE comptes_bancaires SET solde=200 WHERE personnage='Fixture'")
 # Budget mal forme : le debit qui precede ne doit jamais survivre a l'erreur.
 own("UPDATE budgets_clubs SET data='\"historique illisible\"'");before=snap();q.execute('SAVEPOINT panne_club')
 try:achat(304);raise AssertionError('budget ignore')
 except psycopg2.Error:q.execute('ROLLBACK TO SAVEPOINT panne_club')
 check(snap()==before,'budget invalide : rollback du debit et de toutes les contreparties')
 own("UPDATE budgets_clubs SET data=%s",(Json({'caisse':80,'salaires':{'titulaire':123},'historique':[{'jour':i} for i in range(55)]}),))
 v=achat(305,'casquette');check(v['prix']==60,'tarif casquette historique conserve')
 budget=own('SELECT data FROM budgets_clubs');check(len(budget['historique'])==50 and budget['salaires']['titulaire']==123 and budget['caisse']==140,'historique borne et salaires existants preserves')
 own("UPDATE personnages_donnees SET inventory=%s WHERE name='Fixture'",(Json([{'stackable':True,'stackKey':'stock','qty':100}]),));before=snap();check(achat(306).get('raison')=='inventaire_plein' and snap()==before,'inventaire plein sans paiement de l accessoire')
if __name__=='__main__':
 spec=importlib.util.spec_from_file_location('base',R/'outils/bancs/banc-inventaire-receptions-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.main(scenario)
