#!/usr/bin/env python3
"""Compatibilité justice/asile : lecteurs, garde de détention et trigger réels.
Ne teste pas la demande d'asile ni la détection policière, corps non archivé.
"""
from pathlib import Path
import importlib.util,re,json,uuid
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('chasse',R/'outils/bancs/banc-chasse-benediction-135-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
def suite(db,q,srv):
 import psycopg2
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK justice asile',msg,flush=True)
 def lire(s,args=()):q.execute(s,args or None);return q.fetchone()[0]
 s=(R/'migrations/20261025020000_ambassades_asile.sql').read_text()
 q.execute(re.search(r'CREATE TABLE IF NOT EXISTS public.ambassades_asiles \(.*?\n\);',s,re.S)[0])
 for nom in ['ambassade_refuge_de','ambassade_refugie_protege']:
  a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);q.execute(s[a:a+m.end()])
 protection=(R/'migrations/20261025020200_ambassades_asile_protection.sql').read_text()
 # Le DO de détection n'est pas simulé : il est exclu car sa fonction source manque.
 garde=re.search(r'DO \$mig\$.*?END \$mig\$;',protection,re.S)[0]
 q.execute(garde);q.execute(garde)
 q.execute(protection[protection.index('CREATE OR REPLACE FUNCTION public.personnages_proteger_refugie'):])
 q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='commissariat',current_room='bureau_commissaire',pa=50,hp=100 WHERE name='Fixture';UPDATE personnages_donnees SET current_city='capitale',current_building='quartier-ambassades' WHERE name='Autre';UPDATE caisses_batiments SET data='{\"solde\":10000}' WHERE id='republic_commissariat_capitale';INSERT INTO ambassades_asiles(demandeur,pays_hote,empire,statut,decision_prevue_le,decide_le) VALUES('Autre','republic','soviet','accorde',now(),now());INSERT INTO jugements(id,country,city,accuse,motif,jour,data) VALUES('asile-justice-fixture','republic','capitale','Autre','fixture',100,'{\"motifs\":[{\"jours\":3}]}');CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT 1$$")
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(c ORDER BY id) FROM caisses_batiments c),(SELECT jsonb_agg(j ORDER BY id) FROM jugements j),(SELECT jsonb_agg(d ORDER BY id) FROM detentions d),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM police_chasses_recus r),(SELECT jsonb_agg(b ORDER BY acteur) FROM religion_benedictions b),(SELECT jsonb_agg(c ORDER BY acteur,acte) FROM religion_benedictions_consommations c),(SELECT count(*) FROM courrier_fixture),(SELECT count(*) FROM evenements_globaux),(SELECT count(*) FROM acquisitions_transactions_internes))")
 check(lire("SELECT ambassade_refugie_protege('Autre')"),'protection decidee par lecteur existant et presence serveur')
 avant=photo();r=lire("SELECT justice_executer_condamnation('asile-justice-fixture','capitale')")
 check(r.get('raison')=='refugie_protege' and photo()==avant,'execution commune refuse sans jugement execute ni detention')
 avant=photo();r=lire('SELECT police_chasse_commande(%s,%s)',('Autre',str(uuid.uuid4())))
 check(r.get('raison')=='refugie_protege' and photo()==avant,'chasse nomme le refus et annule PA caisse bonus courrier evenement et recu')
 try:q.execute("UPDATE personnages_donnees SET est_emprisonne='{\"motif\":\"fixture\"}' WHERE name='Autre'");raise AssertionError('protection absente')
 except psycopg2.Error as ex:check('refugie_protege' in str(ex) and photo()==avant,'filet reel refuse une ecriture directe de detention')
 q.execute("UPDATE personnages_donnees SET current_building='rue-centrale' WHERE name='Autre'")
 check(not lire("SELECT ambassade_refugie_protege('Autre')"),'sortie du quartier leve la protection sans effacer le statut')
 r=lire('SELECT police_chasse_commande(%s,%s)',('Autre',str(uuid.uuid4())))
 check(r.get('ok') and r.get('succes') and r['execution']['jours']==3,'meme moteur arrete apres sortie du quartier')
 check(lire("SELECT ambassade_refuge_de('Autre')")=='soviet','arrestation ne modifie pas le dossier d asile')
 print(json.dumps({'justice_asile':True,'assertions':n,'demande_asile_testee':False,'detection_policiere_testee':False,'production':False}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':base.base.base.base.banque.m.main(tout)
