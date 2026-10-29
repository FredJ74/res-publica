#!/usr/bin/env python3
"""Fret existant + depot commun sur PostgreSQL jetable, role authenticated, rollback final.
Ce banc ne prouve pas les droits ou transitions du catalogue Supabase vivant.
"""
from pathlib import Path
import importlib.util,re
R=Path(__file__).resolve().parents[2]
def scenario(q,own,call,check,uid,snapshot,Json):
 import psycopg2
 src=(R/'baseline/domaines/economie/10_tables.sql').read_text()
 for table in ['caisses_fret','contenu_caisses_fret']:
  own(re.search(r'CREATE TABLE public\.'+table+r' \([\s\S]*?\n\);',src)[0])
 own('ALTER TABLE caisses_fret ADD PRIMARY KEY(id);ALTER TABLE contenu_caisses_fret ADD PRIMARY KEY(id);ALTER TABLE contenu_caisses_fret ADD FOREIGN KEY(caisse_id) REFERENCES caisses_fret(id);')
 for _ in range(2):own((R/'migrations/20261027213520_inventaire_fret_transactionnel.sql').read_text())
 own("INSERT INTO ordres_couts VALUES('receptionner_commande',1,0)")
 crate=uid(1000);line=uid(1001)
 own("INSERT INTO caisses_fret(id,leader,pays_origine,ville_origine,building_origine,destinataire,pays_destination,ville_destination,building_destination) VALUES(%s,'Fixture','republic','capitale','centre-multinodal-luthecia','Fixture','republic','capitale','centre-multinodal-luthecia')",(crate,))
 own("UPDATE personnages_donnees SET current_building='centre-multinodal-luthecia',current_room='entrepot',inventory='[]',pa=30,liquide=100,arg=300 WHERE name='Fixture'")
 def fret(k,action,ln=None,idx=None,qty=None,rev=None):return call('fret_objet_agir',[uid(k),crate,action,ln,idx,qty,rev])
 def snap():return own("SELECT jsonb_build_array((SELECT to_jsonb(d) FROM personnages_donnees d WHERE name='Fixture'),(SELECT jsonb_agg(to_jsonb(c)) FROM caisses_fret c),(SELECT jsonb_agg(to_jsonb(l)) FROM contenu_caisses_fret l),(SELECT jsonb_agg(to_jsonb(r)) FROM inventaire_actions_recus r),(SELECT jsonb_agg(to_jsonb(b)) FROM caisses_batiments b),(SELECT jsonb_agg(to_jsonb(b)) FROM comptes_bancaires b))")
 obj={'id':'pile-ancienne','name':'Bois','stackable':True,'stackKey':'bois','qty':8,'memoire':{'origine':'conservee'}}
 own("UPDATE personnages_donnees SET inventory=%s WHERE name='Fixture'",(Json([obj]),));rev=own("SELECT inventory_revision FROM personnages_donnees WHERE name='Fixture'")
 before=snap();check(fret(100,'deposer',idx=0,qty=3,rev=rev-1).get('raison')=='inventaire_perime' and snap()==before,'fret index protege par revision')
 v=fret(100,'deposer',idx=0,qty=3,rev=rev);check(v['ok'] and v['inventory'][0]['qty']==5,'depot retire exactement la quantite de la vraie pile')
 ln=own('SELECT id::text FROM contenu_caisses_fret WHERE caisse_id=%s',(crate,));own('UPDATE contenu_caisses_fret SET id=%s WHERE id=%s',(uid(999),ln));ln=uid(999);check(own('SELECT quantite FROM contenu_caisses_fret WHERE id=%s',(ln,))==3,'depot inscrit le contenu serveur')
 before=snap();check(fret(100,'deposer',idx=0,qty=3,rev=rev)['rejeu'] and snap()==before,'rejeu depot sans deuxieme retrait')
 v=fret(101,'reprendre',ln);check(v['ok'] and v['inventory'][0]['qty']==8 and v['inventory'][0]['memoire']==obj['memoire'],'reprise conserve quantites identite et metadonnees')
 before=snap();check(fret(102,'reprendre',ln).get('raison')=='ligne_indisponible' and snap()==before,'reprise epuisee sans duplication')
 own("UPDATE caisses_fret SET statut='fermee' WHERE id=%s",(crate,));before=snap();check(fret(103,'reprendre',ln).get('raison')=='caisse_fermee' and snap()==before,'caisse fermee non reprise')
 own("UPDATE caisses_fret SET statut='arrivee',dedouanee=false WHERE id=%s",(crate,));own('UPDATE contenu_caisses_fret SET quantite=3 WHERE id=%s',(ln,));before=snap();check(fret(104,'retirer',ln,qty=2).get('raison')=='caisse_non_dedouanee' and snap()==before,'douane obligatoire avant retrait')
 own("UPDATE caisses_fret SET dedouanee=true WHERE id=%s",(crate,));v=fret(104,'retirer',ln,qty=2);check(v['ok'] and v['paie']['pa']==29 and v['qte']==2,'retrait entier et un PA du miroir commun')
 before=snap();check(fret(104,'retirer',ln,qty=2)['rejeu'] and snap()==before,'reponse perdue retrait sans deuxieme PA')
 check(fret(105,'retirer',ln,qty=3)['qte']==1,'retrait plafonne au stock restant');check(own('SELECT statut FROM caisses_fret')=='videe','caisse videe dans la transaction du dernier retrait')
 # Vente indivisible, deux lignes dont une erreur tardive : rollback du paiement et du premier depot.
 own("INSERT INTO caisses_batiments VALUES('republic_centre-multinodal-luthecia','{\"solde\":0}',now())")
 own("UPDATE caisses_fret SET statut='a_vendre',valeur_declaree=100,quantite_arrivee=3 WHERE id=%s",(crate,))
 own('UPDATE contenu_caisses_fret SET quantite=2 WHERE id=%s',(ln,))
 own("INSERT INTO contenu_caisses_fret(id,caisse_id,deposant,objet,quantite) VALUES(%s,%s,'Fixture',%s,1)",(line,crate,Json({'id':'unique','name':'Document','type':'document','legal':True})))
 own("UPDATE personnages_donnees SET inventory='[]',liquide=100,arg=300 WHERE name='Fixture'")
 v=fret(106,'acheter');check(v['ok'] and v['qte']==3 and v['prix']==50,'lot indivisible : prix historique 50 pourcent et depot complet')
 check(len(v['inventory'])==2 and any(i.get('id')=='unique' for i in v['inventory']),'lot conserve les identifiants individuels')
 before=snap();check(fret(106,'acheter')['rejeu'] and snap()==before,'achat rejoue sans autre debit ou credit de caisse')
 own("UPDATE caisses_fret SET statut='a_vendre' WHERE id=%s",(crate,));own('UPDATE contenu_caisses_fret SET quantite=2');own("UPDATE personnages_donnees SET inventory='[]' WHERE name='Fixture'")
 before=snap();q.execute('SAVEPOINT panne_fret')
 try:fret(107,'acheter');raise AssertionError('ambiguite non refusee')
 except psycopg2.Error:q.execute('ROLLBACK TO SAVEPOINT panne_fret')
 check(snap()==before,'erreur apres premier depot : rollback lot paiement caisse et inventaire')
 # Seules les diminutions douanieres legacy restent autorisees hors commande serveur.
 own('GRANT INSERT,UPDATE ON contenu_caisses_fret TO authenticated');own('GRANT SELECT ON contenu_caisses_fret TO authenticated')
 q.execute("SELECT set_config('role','authenticated',true),set_config('request.path','/contenu_caisses_fret',true)");q.execute('SAVEPOINT forge')
 try:q.execute('UPDATE contenu_caisses_fret SET quantite=99');raise AssertionError('augmentation libre')
 except psycopg2.Error:q.execute('ROLLBACK TO SAVEPOINT forge')
 check(True,'augmentation de contenu via PATCH refusee au vrai role navigateur')
 q.execute('UPDATE contenu_caisses_fret SET quantite=0');check(True,'diminution douaniere legacy preservee')
 # RLS/grants vivants des caisses et transitions douanieres restent un prevol obligatoire.

if __name__=='__main__':
 spec=importlib.util.spec_from_file_location('base',R/'outils/bancs/banc-inventaire-receptions-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.main(scenario)
