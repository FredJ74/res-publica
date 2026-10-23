#!/usr/bin/env python3
"""Baux, loyers, banque et commande existants sur PostgreSQL jetable."""
import importlib.util,json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('construction',R/'outils/bancs/banc-construction-jour-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def suite(db,server):
 import psycopg2
 from psycopg2.extras import Json
 c=db.cursor();n=0
 def q(s,a=()):
  c.execute(s,a);v=c.fetchone()[0];db.commit();return v
 def ok(v,t):
  nonlocal n
  assert v,t;n+=1;print('OK location',t,flush=True)
 c.execute('CREATE VIEW public.personnages AS SELECT * FROM public.personnages_donnees')
 for f,nom in [('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','bail_destination_attestee'),('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','bail_cle_coherente'),('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','prelever_loyer_bail'),('baseline/domaines/economie/20_fonctions-2.sql','payer_ordre')]:c.execute(m.fn(f,nom))
 c.execute('CREATE TRIGGER trg_bail_cle_coherente BEFORE INSERT OR UPDATE ON locations_actives FOR EACH ROW EXECUTE FUNCTION bail_cle_coherente()')
 for p in ['20261023090008_chantier_travailleur_et_client.sql','20261023090009_chantier_reamenagement_socle.sql','20261023090010_chantier_reamenagement_commandes.sql','20261023090011_chantier_reamenagement_jour_travail.sql','20261023090014_loyers_lots_financement_commun.sql','20261023090015_location_lot_commandes_socle.sql','20261023090016_location_lot_raccordement.sql','20261023090017_location_lot_legacy_avant_paiement.sql']:
  c.execute((R/'migrations'/p).read_text());c.execute((R/'migrations'/p).read_text())
 c.execute("SET test.acteur='Alice';SET test.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='locaux',pa=50,hp=100,liquide=40,arg=100;UPDATE comptes_bancaires SET solde=60;UPDATE organisations SET data='{\"chef\":\"Chef\",\"caisse\":1000}'")
 lots=[{'id':'a','label':'Atelier','surface':600,'loyer':90,'destination':'commerce','locataire':None,'identite':'historique'},{'id':'b','label':'Local B','surface':600,'loyer':200,'destination':'commerce','locataire':None}]
 etat={'city':'capitale','proprietaire':'orga:orga','niveau_construction':'commerce_premium','surface':1500,'subdivisions':lots}
 c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('locaux','republic','locaux','orga:orga',%s)",(json.dumps(etat),));db.commit()
 def photo():return q("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(b ORDER BY personnage,banque) FROM comptes_bancaires b),(SELECT jsonb_agg(o ORDER BY id) FROM organisations o),(SELECT jsonb_agg(l ORDER BY id) FROM locations_actives l),(SELECT jsonb_agg(t ORDER BY id) FROM terrains_etat t),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM chantier_commandes_recus r))")
 def cmd(req,lot='a',cur=c):
  cur.execute('SELECT chantier_commande(%s,%s,%s,%s)',(req,'locaux','louer',Json({'lot':lot})));v=cur.fetchone()[0];cur.connection.commit();return v
 avant=photo();r=q("SELECT payer_ordre('Alice','louer_lot_ici',1,0)");ok(r['raison']=='commande_versionnee_requise' and photo()==avant,'ancien navigateur refuse avant PA')
 r=cmd('ch-location-a00001');ok(r['ok'],'tiers peut louer sans etre proprietaire')
 ok(q('SELECT jsonb_build_array(pa,liquide,arg) FROM personnages_donnees')==[49,10,10] and q('SELECT solde FROM comptes_bancaires')==0,'90 FR : banque 60 puis liquide 30, PA unique')
 ok(q("SELECT data::jsonb->>'caisse' FROM organisations")=='1090','proprietaire organisation credite par moteur de loyer existant')
 bail=q("SELECT data FROM locations_actives WHERE id='republic:locaux:lot_dyn_a:capitale'");ok(bail['prix']==90 and bail['lotId']=='a' and bail['locataire']=='Alice' and bail['dernierLoyerPaye'],'bail canonique et premier loyer confirms')
 avant=photo();ok(cmd('ch-location-a00001')['rejeu'] and photo()==avant,'rejeu aucun deuxieme paiement ou PA')
 avant=photo();r=cmd('ch-location-a00002');ok(r['raison']=='local_occupe' and photo()==avant,'double demande differente refusee')
 avant=photo();r=cmd('ch-location-b00001','b');ok(r['raison']=='premier_loyer_refuse' and photo()==avant,'manque : aucun bail, debit partiel, PA ou avertissement persistant')
 for sql in ["INSERT INTO locations_actives(id,country,data) VALUES('republic:locaux:lot_dyn_c:capitale','republic','{\"country\":\"republic\",\"city\":\"capitale\",\"buildingId\":\"locaux\",\"roomId\":\"lot_dyn_c\",\"prix\":0,\"locataire\":\"Alice\"}')","UPDATE locations_actives SET data=jsonb_set(data,'{prix}','0') WHERE id='republic:locaux:lot_dyn_a:capitale'","UPDATE locations_actives SET data=jsonb_set(data,'{jourPaiement}',to_jsonb('2099-01-01'::text)) WHERE id='republic:locaux:lot_dyn_a:capitale'"]:
  avant=photo()
  try:c.execute(sql);raise AssertionError('ecriture directe refusee')
  except psycopg2.Error as e:db.rollback();assert 'location_commande_versionnee_requise' in str(e)
  ok(photo()==avant,'INSERT ou alteration financiere directe refusee')
 c.execute("UPDATE locations_actives SET data=jsonb_set(data,'{visible}','false') WHERE id='republic:locaux:lot_dyn_a:capitale'");db.commit();ok(not q("SELECT (data->>'visible')::boolean FROM locations_actives WHERE id='republic:locaux:lot_dyn_a:capitale'"),'option de visibilite preservee')
 c.execute("UPDATE personnages_donnees SET liquide=400,arg=400;CREATE FUNCTION panne_location() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.requete='ch-location-panne1' AND NEW.resultat->>'ok'='true' THEN RAISE EXCEPTION 'panne_location_fixture';END IF;RETURN NEW;END$$;CREATE TRIGGER panne_location BEFORE UPDATE ON chantier_commandes_recus FOR EACH ROW EXECUTE FUNCTION panne_location()")
 avant=photo()
 try:cmd('ch-location-panne1','b');raise AssertionError('panne attendue')
 except psycopg2.Error as e:db.rollback();assert 'panne_location_fixture' in str(e)
 ok(photo()==avant,'panne apres paiement : PA, contrepartie, bail et recu annules')
 c.execute("UPDATE personnages_donnees SET pa=0");avant=photo();ok(cmd('ch-location-sansPA','b')['raison']=='pa_insuffisants' and photo()==avant,'PA insuffisants avant paiement')
 c.execute("UPDATE personnages_donnees SET pa=50,current_building='ailleurs'");avant=photo();ok(cmd('ch-location-loin01','b')['raison']=='pas_sur_place' and photo()==avant,'presence serveur exigee')
 c.execute("UPDATE personnages_donnees SET current_building='locaux'");db.commit()
 def concurrent(_):
  with psycopg2.connect(server.get_uri()) as d:
   cc=d.cursor();cc.execute("SET test.acteur='Alice';SET test.serveur='off'");return cmd('ch-location-concur','b',cc)
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,range(2)))
 ok(all(r['ok'] for r in rs) and sum(bool(r.get('rejeu')) for r in rs)==1,'concurrence un bail un loyer un PA')
 avant=photo();c.execute("SET test.serveur='on'");ok(q("SELECT prelever_loyer_bail('republic:locaux:lot_dyn_b:capitale')")=='deja_preleve' and photo()==avant,'cron du jour ne repaie pas le premier loyer')
 c.execute("SET test.serveur='off'")
 for signature in ['location_lot_enregistrer_interne(jsonb,text,text,text,text,integer)','location_lot_ecriture_attester()']:
  ok(not q("SELECT has_function_privilege('authenticated',%s,'EXECUTE')",(signature,)),'helper non appelable directement')
 ok(not q("SELECT has_table_privilege('authenticated','chantier_commandes_recus','INSERT')"),'capabilite transactionnelle non forgeable par le client')
 # Les deux variantes examinees du payeur conservent leurs gardes de permis.
 import re,hashlib
 definition=m.fn('baseline/domaines/economie/20_fonctions-2.sql','payer_ordre')
 depot="""  IF v_fn = 'deposer_demande_permis' AND NOT EXISTS (
    SELECT 1 FROM public.permis_transactions_internes WHERE transaction_id=txid_current() AND acteur=auth.uid()
  ) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise'); END IF;
"""
 decision="  IF v_fn='traiter_demandes_permis' AND NOT EXISTS(SELECT 1 FROM public.urbanisme_decisions_internes WHERE transaction_id=txid_current() AND acteur=auth.uid()) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;\n"
 for prefixe,empreinte in [(depot,'9a461bfc3c33f04f342ce6f5586393a7'),(depot+decision,'c3098e80ece8a156c8ad393284a816de')]:
  source=definition.replace('  PERFORM public.exiger_acteur(p_acteur);',prefixe+'  PERFORM public.exiger_acteur(p_acteur);')
  corps=re.search(r'AS (\$\w*\$)(.*?)\1;',source,re.S)[2];assert hashlib.md5(corps.encode()).hexdigest()==empreinte
  c.execute(source);garde=(R/'migrations/20261023090017_location_lot_legacy_avant_paiement.sql').read_text();c.execute(garde);c.execute(garde)
  ok(q("SELECT payer_ordre('Alice','louer_lot_ici',1,0)")['raison']=='commande_versionnee_requise','garde location compatible avec variante permis examinee')
  texte=q("SELECT prosrc FROM pg_proc WHERE oid='payer_ordre(text,text,integer,integer)'::regprocedure")
  ok(prefixe in texte,'gardes du depot et des decisions preservees integralement')
 print(json.dumps({'location_transactionnelle':True,'assertions':n,'production':False}))
if __name__=='__main__':m.main(suite)
