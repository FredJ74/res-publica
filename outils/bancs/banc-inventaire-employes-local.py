#!/usr/bin/env python3
"""Extension du socle PNJ reel sur schema jetable, authenticated, transaction annulee.
Aucune conversion des anciennes charges ni aucun acces distant.
"""
from pathlib import Path
import importlib.util,re
R=Path(__file__).resolve().parents[2]
def scenario(q,own,call,check,uid,snapshot,Json):
 import psycopg2
 spec=importlib.util.spec_from_file_location('base2',R/'outils/bancs/banc-inventaire-receptions-local.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
 s=(R/'baseline/domaines/socle-PNJ/10_tables.sql').read_text()
 for table in ['pnj_membres','pnj_possessions','pnj_institutions']:own(re.search(r'CREATE TABLE public\.'+table+r' \([\s\S]*?\n\);',s)[0])
 own('ALTER TABLE pnj_membres ADD PRIMARY KEY(id);ALTER TABLE pnj_possessions ADD PRIMARY KEY(id);ALTER TABLE pnj_possessions ENABLE ROW LEVEL SECURITY;ALTER TABLE personnages_donnees ADD COLUMN employes jsonb DEFAULT \'[]\';ALTER TABLE personnages_donnees ADD COLUMN quete_carriere jsonb;')
 for fn in ['pnj_autorite_de_perimetre','pnj_autorite_de','pnj_peut_administrer','pnj_position_effective','pnj_co_present','pnj_possessions_lire']:
  own(mod.fonction('baseline/domaines/socle-PNJ/20_fonctions.sql',fn))
 own(mod.fonction('baseline/domaines/socle/20_fonctions.sql','inventaire_objet_protege'))
 for _ in range(2):own((R/'migrations/20261027213521_inventaire_employes_socle.sql').read_text())
 own("UPDATE personnages_donnees SET current_building='mairie-capitale',current_room='hall_mairie',inventory='[]' WHERE name='Fixture'")
 own("INSERT INTO pnj_membres(id,famille,nom,pays,proprietaire_pj,ville,building_id,room_id) VALUES('emp-fixture','employe','Porteur fictif','republic','Fixture','capitale','mairie-capitale','hall_mairie')")
 def transfert(k,sens,idx=0,qty=None,rev=None,pos=None):return call('pnj_objet_transferer',['emp-fixture',idx,sens,qty,rev,pos,uid(k)])
 def snap():return own("SELECT jsonb_build_array((SELECT jsonb_agg(to_jsonb(d)) FROM personnages_donnees d),(SELECT jsonb_agg(to_jsonb(p)) FROM pnj_possessions p),(SELECT jsonb_agg(to_jsonb(r)) FROM inventaire_actions_recus r))")
 obj={'id':'bois-initial','name':'Bois','stackable':True,'stackKey':'bois','qty':8,'memoire':'conservee'}
 own("UPDATE personnages_donnees SET inventory=%s WHERE name='Fixture'",(Json([obj]),));rev=own("SELECT inventory_revision FROM personnages_donnees WHERE name='Fixture'")
 before=snap();check(transfert(200,'donner',qty=3,rev=rev-1).get('raison')=='inventaire_perime' and snap()==before,'PNJ index lie a la revision')
 v=transfert(200,'donner',qty=3,rev=rev);check(v['ok'] and v['inventory'][0]['qty']==5,'PNJ donne exactement trois unites du vrai stock')
 before=snap();check(transfert(200,'donner',qty=3,rev=rev)['rejeu'] and snap()==before,'PNJ don rejoue sans double retrait')
 v=call('pnj_possessions_lire',['emp-fixture']);p=v['possessions'][0];check(p['possession_id'] and p['objet']['memoire']=='conservee','lecteur commun rend identite stable et metadonnees')
 v=transfert(201,'retirer',qty=2,pos=p['possession_id']);check(v['ok'] and v['inventory'][0]['qty']==7,'reprise partielle via depot commun')
 check(own('SELECT (objet->>\'qty\')::integer FROM pnj_possessions')==1,'reste PNJ conserve')
 before=snap();check(transfert(201,'retirer',qty=2,pos=p['possession_id'])['rejeu'] and snap()==before,'PNJ reponse perdue sans duplication')
 for col,val,raison in [('proprietaire_pj','Autre','autorite_insuffisante'),('room_id','ailleurs','pas_co_presents'),('statut','absent','autorite_insuffisante')]:
  old=own('SELECT '+col+' FROM pnj_membres');own('UPDATE pnj_membres SET '+col+'=%s',(val,));before=snap();check(transfert(202,'retirer',pos=p['possession_id']).get('raison')==raison and snap()==before,'PNJ controle reel '+col);own('UPDATE pnj_membres SET '+col+'=%s',(old,))
 own("UPDATE pnj_possessions SET origine='blob_accessoires'");before=snap();check(transfert(202,'retirer',pos=p['possession_id']).get('raison')=='objet_non_cessible' and snap()==before,'miroir militaire non duplique');own("UPDATE pnj_possessions SET origine='socle'")
 own("UPDATE personnages_donnees SET inventory=%s WHERE name='Fixture'",(Json([{'type':'colis_secret_pat','name':'Colis'}]),));rev=own("SELECT inventory_revision FROM personnages_donnees WHERE name='Fixture'");before=snap();check(transfert(202,'donner',rev=rev).get('raison')=='objet_protege' and snap()==before,'colis protege par helper commun cote serveur')
 own("UPDATE personnages_donnees SET employes=%s WHERE name='Fixture'",(Json([{'pnjId':'emp-fixture','nom':'Porteur fictif','charge':{'bois':2}}]),));before=snap();check(transfert(202,'retirer',pos=p['possession_id']).get('raison')=='charge_historique_a_reconcilier' and snap()==before,'ancienne charge conservee sans normalisation inventee')
 own("UPDATE personnages_donnees SET employes='[]',inventory='[]' WHERE name='Fixture'");own("UPDATE pnj_possessions SET objet=%s",(Json({'id':'unique','name':'Lettre','memoire':{'auteur':'ancien'}}),))
 v=transfert(203,'retirer',pos=p['possession_id']);check(v['inventory'][0]['id']=='unique' and v['inventory'][0]['memoire']=={'auteur':'ancien'},'objet unique reprend identite et memoire exactes')
 check(own('SELECT count(*) FROM pnj_possessions')==0,'possession retiree uniquement apres depot confirme')
 check(call('pnj_objet_transferer',['emp-fixture',0,'retirer']).get('raison')=='contrat_versionne_requis','ancienne porte index seul ne peut viser un autre objet au rejeu')
 own("UPDATE personnages_donnees SET inventory=%s WHERE name='Fixture'",(Json([obj]),));rev=own("SELECT inventory_revision FROM personnages_donnees WHERE name='Fixture'");own("INSERT INTO pnj_possessions(pnj_id,objet) VALUES('emp-fixture',%s)",(Json({'name':'Stock','stackable':True,'stackKey':'stock','qty':99}),))
 v=transfert(204,'donner',qty=3,rev=rev);check(v['qte']==1 and v['inventory'][0]['qty']==7,'plafond employe limite au nombre vraiment transfere')
 before=snap();rev=v['revision'];check(transfert(205,'donner',qty=1,rev=rev).get('raison')=='charge_maximale' and snap()==before,'charge pleine : aucun retrait PJ')

 # Echec au recu, apres le depot : aucune contrepartie ne doit survivre.
 own("UPDATE personnages_donnees SET inventory='[]' WHERE name='Fixture'")
 pid=own('SELECT id FROM pnj_possessions ORDER BY id LIMIT 1')
 own("CREATE FUNCTION fixture_recu_refuser() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.action='pnj_objet' THEN RAISE EXCEPTION 'fixture panne recu';END IF;RETURN NEW;END $$; CREATE TRIGGER fixture_recu BEFORE INSERT ON inventaire_actions_recus FOR EACH ROW EXECUTE FUNCTION fixture_recu_refuser();")
 before=snap();q.execute('SAVEPOINT panne_pnj')
 try:transfert(206,'retirer',qty=1,pos=pid);raise AssertionError('panne recu non detectee')
 except psycopg2.Error:q.execute('ROLLBACK TO SAVEPOINT panne_pnj')
 check(snap()==before,'PNJ panne apres depot : source inventaire revision et recu annules')

if __name__=='__main__':
 spec=importlib.util.spec_from_file_location('base',R/'outils/bancs/banc-inventaire-receptions-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.main(scenario)
