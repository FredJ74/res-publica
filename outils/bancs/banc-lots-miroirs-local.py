#!/usr/bin/env python3
"""Ancienne RPC lot : seuls miroirs attestes, aucun remplacement du JSON du navigateur."""
import importlib.util,json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('construction',R/'outils/bancs/banc-construction-jour-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def suite(db,server):
 from psycopg2.extras import Json
 c=db.cursor();n=0
 def q(s,a=()):
  c.execute(s,a);v=c.fetchone()[0];db.commit();return v
 def ok(v,t):
  nonlocal n
  assert v,t;n+=1;print('OK lots',t,flush=True)
 c.execute(m.fn('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','terrain_lots_acte'))
 sql=(R/'migrations/20261023090012_terrain_lots_miroirs_attestes.sql').read_text();c.execute(sql);c.execute(sql)
 c.execute(m.fn('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','terrain_reamenagement_poser'))
 garde=(R/'migrations/20261023090013_terrain_reamenagement_legacy_ferme.sql').read_text();c.execute(garde);c.execute(garde)
 ok(q("SELECT terrain_reamenagement_poser('inconnu','{\"coutTotal\":0,\"progressionJours\":999}')")['raison']=='commande_versionnee_requise','ancienne pose ne forge ni cout ni progression')
 c.execute("SET test.acteur='Alice';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='immeuble',hp=100;UPDATE organisations SET data='{\"chef\":\"Chef\",\"caisse\":1000}'")
 lots=[{'id':'a','surface':600,'destination':'commerce','label':'Local A','loyer':123,'locataire':None,'identite':'historique'}, {'id':'b','surface':600,'destination':'commerce','label':'Local B','loyer':234,'locataire':'Autre'}]
 etat={'city':'capitale','surface':1500,'proprietaire':'orga:orga','niveau_construction':'commerce_premium','subdivisions':lots}
 c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('immeuble','republic','immeuble','orga:orga',%s)",(json.dumps(etat),))
 def appel(acte,payload,retirer=None):return q('SELECT terrain_lots_acte(%s,%s,%s,%s)',('immeuble',acte,Json(payload),retirer))
 def photo():return q("SELECT data::jsonb FROM terrains_etat WHERE id='immeuble'")
 def refuse(acte,payload,raison,retirer=None):
  avant=photo();r=appel(acte,payload,retirer);ok(not r['ok'] and r['raison']==raison and photo()==avant,raison)
 # Faille L08 : NULL ne peut plus contourner l'autorite sur p_retirer.
 for ids in [['b'],['a','b'],['inconnu']]:
  avant=photo();r=appel('lot_bail_libere',None,ids)
  ok(not r['ok'] and r['raison']=='suppression_interdite' and photo()==avant,'retrait sans lots refuse '+str(ids))
 faux=dict(lots[0],surface=9999,loyer=1,locataire='Alice',proprietaire='Alice')
 refuse('lot_ajouter',[faux],'reamenagement_payant_requis');refuse('lot_fusion_accepter',[faux],'reamenagement_payant_requis')
 refuse('lot_louer',[faux],'suppression_interdite',['b']);refuse('lot_louer',[faux],'pas_mon_bail')
 c.execute("INSERT INTO locations_actives(id,country,data) VALUES('local-a','republic',%s)",(Json({'city':'capitale','buildingId':'immeuble','roomId':'lot_dyn_a','locataire':'Alice'}),))
 r=appel('lot_louer',[faux]);ok(r['ok'] and r['lots'][0]==dict(lots[0],locataire='Alice') and r['lots'][1]==lots[1],'seul locataire canonique change, aucune geometrie ni prix ni titre')
 avant=photo();r=appel('lot_louer',[faux]);ok(r['ok'] and r['rejeu'] and photo()==avant,'miroir rejoue sans historique duplique')
 refuse('lot_bail_libere',[faux],'bail_encore_actif')
 c.execute("DELETE FROM locations_actives WHERE id='local-a'");r=appel('lot_bail_libere',[faux]);ok(r['ok'] and r['lots'][0]['locataire'] is None,'fin de bail ne reinstalle personne')
 try:appel('lot_bail_libere',[lots[1]]);raise AssertionError('autorite requise')
 except Exception as e:
  db.rollback();assert 'representation_organisation_refusee' in str(e)
 ok(photo()['subdivisions'][1]['locataire']=='Autre','tiers ne libere pas le lot des autres')
 c.execute("UPDATE organisations SET data='{\"chef\":\"Alice\",\"caisse\":1000}'");r=appel('lot_bail_libere',[lots[1]]);ok(r['ok'],'representant organisation atteste peut nettoyer miroir sans bail')
 refuse('lot_bail_libere',[{'id':'a'},{'id':'a'}],'identifiant_lot_invalide')
 # Validation de tout le tableau avant mutation : un lot valide suivi d'un introuvable.
 refuse('lot_bail_libere',[{'id':'a'},{'id':'inconnu'}],'lot_introuvable')
 c.execute("UPDATE personnages_donnees SET country='soviet'");refuse('lot_bail_libere',[{'id':'a'}],'terrain_introuvable')
 print(json.dumps({'lots_miroirs':True,'assertions':n,'production':False}))
if __name__=='__main__':m.main(suite)
