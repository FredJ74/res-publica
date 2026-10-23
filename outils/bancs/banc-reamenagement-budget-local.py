#!/usr/bin/env python3
"""CONTROLE BLOQUANT : 100 m2 doivent etre finissables avec le financement annonce.

Rouge tant que l'arbitrage du panier arrondi/de l'apport complementaire n'est pas rendu.
Aucun ajustement artificiel des prix, des heures ou du resultat attendu.
"""
import importlib.util,json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('ream',R/'outils/bancs/banc-reamenagement-transactionnel-local.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
def controle(db,server):
 from psycopg2.extras import Json
 c=db.cursor()
 c.execute("SET test.acteur='Alice';SET test.serveur='off';UPDATE personnages_donnees SET liquide=5000,arg=10000;UPDATE comptes_bancaires SET solde=5000")
 c.execute("SELECT data::jsonb->'subdivisions' FROM terrains_etat WHERE id='ream'");lots=c.fetchone()[0];lots[0]['surface']+=100
 c.execute("SELECT chantier_commande('ch-ream-budget100','ream','reamenager',%s)",(Json({'lots':lots}),));r=c.fetchone()[0];assert r['ok'],r
 c.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantierReamenagement,jourTraite}','null')::text WHERE id='ream';SET test.serveur='on'")
 c.execute("SELECT chantier_jour_traiter('ream')");r=c.fetchone()[0];ch=r['etat']['chantierReamenagement']
 print(json.dumps({'controle':'financement_100m2','coutAnnonce':ch['coutTotal'],'avance':ch['progressionJours'],'tresorerie':ch['tresorerie'],'evenements':ch['evenements'],'production':False}),flush=True)
 assert ch['progressionJours']==1,'BLOCAGE REEL : 305 FR de materiaux + 700 FR de travail depassent les 1000 FR annonces ; aucune regle ne doit etre changee sans arbitrage.'
if __name__=='__main__':b.m.main(lambda db,server:b.suite(db,server,controle))
