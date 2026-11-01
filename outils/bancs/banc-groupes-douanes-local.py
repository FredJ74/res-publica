#!/usr/bin/env python3
"""Contrôles douaniers avec saisie/lois/justice réelles du dépôt ; décor fictif."""
import importlib.util,sys,re,json,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('international',R/'outils/bancs/banc-groupes-international-local.py');i=importlib.util.module_from_spec(sp);sp.loader.exec_module(i)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 a=i.t.lots.amb.rondes.interieur.natif.rue.force.corps.g.audit
 q.execute("ALTER TABLE personnages_donnees ADD COLUMN IF NOT EXISTS quete_carriere jsonb,ADD COLUMN IF NOT EXISTS convocations jsonb DEFAULT '[]',ADD COLUMN IF NOT EXISTS inventory_revision bigint NOT NULL DEFAULT 0,ADD COLUMN IF NOT EXISTS recherche jsonb DEFAULT '[]',ADD COLUMN IF NOT EXISTS photo_url text,ADD COLUMN IF NOT EXISTS detention_qhs jsonb")
 q.execute("ALTER TABLE pnj_possessions ADD COLUMN IF NOT EXISTS origine text NOT NULL DEFAULT 'socle'")
 installer=ctx['installer_fonction_canonique']
 # L'ancienne suite démontre explicitement un détecteur avec éligibilité fictive.
 # Elle est terminée : remplacer maintenant cette seule fixture par le vrai corps,
 # sans DROP, pour que les nouveaux scénarios ne puissent utiliser ce substitut.
 q.execute('ALTER FUNCTION justice_recherches(text) RENAME TO justice_recherches_fixture_ancienne')
 for nom in ['justice_recherches','inventaire_confisquer','detention_active','detention_qhs_poser_interne','detention_transferer_qhs','detention_ouvrir_soi','pnj_miroir_possessions_si_axe_blob']:installer(nom)
 source=json.loads((R/'outils/bancs/fixtures/groupes-justice-corps-git-20261028.json').read_text())
 assert hashlib.sha256(source['sql'].encode()).hexdigest()==source['sha256'];q.execute(source['sql'])
 q.execute(a.fonction('migrations/20261031113546_reception_objets_atomique.sql','inventaire_revision_garder'))
 q.execute('CREATE TRIGGER zzzz_hg_inventory_revision BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION inventaire_revision_garder()')
 q.execute("SELECT to_regclass('public.indices_villes')")
 if q.fetchone()[0] is None:
  for p in (R/'baseline/domaines').glob('*/10_tables.sql'):
   m=re.search(r'CREATE TABLE public.indices_villes \(.*?\n\);',p.read_text(),re.S)
   if m:q.execute(m[0]);break
 q.execute(a.fonction('historique/migrations-appliquees/20261027110100_crimes_actes_serveur.sql','crime_malus_isn_interne'))
 src=(R/'historique/migrations-appliquees/20261027110000_crimes_socle_serveur.sql').read_text()
 q.execute(re.search(r'CREATE TABLE IF NOT EXISTS public.actes_illegaux \(.*?\n\);',src,re.S)[0])
 q.execute(re.search(r'INSERT INTO public.actes_illegaux .*?maj_le = now\(\);',src,re.S)[0])
 for nom,fichier in [('crime_rechercher_interne','20261027110000_crimes_socle_serveur.sql'),('crime_detecter_interne','20261027110000_crimes_socle_serveur.sql'),('crime_dis_ajuster_interne','20261027130000_crimes_ordres_detection.sql'),('crime_etat_acteur_interne','20261027130000_crimes_ordres_detection.sql'),('crime_corrompre_douanier','20261027130000_crimes_ordres_detection.sql')]:
  q.execute(a.fonction('migrations/'+fichier,nom))
 for nom in ['20261031115809_transport_adaptateur_confiscation.sql','20261031115810_transport_adaptateur_recherches.sql','20261031115811_transport_adaptateur_execution.sql','20261031115812_transport_passages_douaniers.sql','20261031115813_transport_controle_douanier_commun.sql','20261031115816_transport_corruption_passage_serveur.sql','20261031115817_justice_position_cellule_serveur.sql']:
  if '--contre-position-cellule' in sys.argv and nom=='20261031115817_justice_position_cellule_serveur.sql':continue
  q.execute((R/'migrations'/nom).read_text());q.execute((R/'migrations'/nom).read_text())
 ctx['c'].commit()
 req='00000000-0000-4000-8000-000000000600'
 def depart():
  sql("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='centre-multinodal-luthecia',current_room='hall_douanes',current_street=NULL WHERE name IN ('A','B')")
 def controle():return rpc('douane_controle_groupe',('avion',req),qui='B')
 def photo():
  q.execute('SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d');return q.fetchone()[0]
 def groupe():
  depart();avant=photo();v=exige(controle());assert v['controles']==9,v
  q.execute('SELECT count(*) FROM navigation_passages_douaniers');assert q.fetchone()[0]==2
  assert photo()==avant
 cas('douane_2PJ_7PNJ_controles_sans_debit_ni_faux_deplacement',groupe)
 def saisie():
  depart();sql("UPDATE personnages_donnees SET inventory='[{\"id\":\"ilegal-A\",\"name\":\"Objet prohibé\",\"type\":\"poison\",\"legal\":false},{\"id\":\"secret\",\"type\":\"colis_secret_pat\",\"legal\":false}]' WHERE name='A'")
  sql("INSERT INTO pnj_possessions(pnj_id,objet,origine) VALUES('police-republic-capitale-P1','{\"id\":\"illegal-PNJ\",\"type\":\"poison\",\"name\":\"Objet PNJ\",\"legal\":false}','socle')")
  v=exige(controle());assert v['controles']==9
  q.execute("SELECT inventory,jsonb_array_length(convocations) FROM personnages_donnees WHERE name='A'");inv,n=q.fetchone();assert len(inv)==1 and inv[0]['id']=='secret' and n==1
  q.execute("SELECT jsonb_array_length(convocations) FROM personnages_donnees WHERE name='B'");assert q.fetchone()[0]==0,'responsabilité attribuée à tort au chef'
  q.execute("SELECT count(*) FROM pnj_possessions WHERE objet->>'id'='illegal-PNJ'");assert q.fetchone()[0]==0
  q.execute('SELECT count(*) FROM confiscations_douanieres');assert q.fetchone()[0]==2
  avant=photo();exige(controle());assert photo()==avant
 cas('douane_saisie_PJ_PNJ_colis_protege_convocation_PJ_seulement_et_rejeu',saisie)
 def disperse():
  depart();sql("UPDATE personnages_donnees SET current_room='hall_gare' WHERE name='A'");avant=photo()
  exige(controle(),'groupe_disperse');assert photo()==avant
 cas('douane_pas_de_dispense_collective_si_un_PJ_absent',disperse)
 def faux_lieu():
  depart();sql("UPDATE personnages_donnees SET current_room='hall_gare' WHERE name IN ('A','B')")
  exige(controle(),'pas_au_controle')
 cas('douane_controle_refuse_hors_piece_reelle',faux_lieu)
 def sortie():
  depart();exige(controle());sql("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='rue-1' WHERE name IN ('A','B')");depart()
  q.execute('SELECT count(*) FROM navigation_passages_douaniers');assert q.fetchone()[0]==0
  exige(controle(),'controle_a_renouveler')
 cas('douane_sortie_annule_attestation_et_recu_ne_reautorise_pas',sortie)
 def prive():
  for sig in ['douane_confisquer_personnage_interne(text)','douane_recherches_interne(text)','douane_condamnation_executer_interne(text,text)','douane_controle_groupe_interne(text,text)']:
   for role in ['anon','authenticated','service_role']:
    q.execute('SELECT has_function_privilege(%s,%s,\'EXECUTE\')',(role,sig));assert q.fetchone()[0] is False
 cas('douane_adaptateurs_identite_prives_non_appelables',prive)
 def prison():
  depart();sql("INSERT INTO jugements(id,country,city,accuse,motif,data,executee) VALUES('jugement-fixture','republic','capitale','A','Peine fictive','{\"motifs\":[{\"jours\":2}]}',false)")
  sql("UPDATE personnages_donnees SET resources='{\"dis\":0}' WHERE name='A'")
  vus=set()
  for seed in range(30):
   q.execute('SAVEPOINT jet_douane');q.execute('SELECT setseed(%s)',(seed/30,));v=controle()
   try:
    if v.get('arrestation'):
     vus.add('arrestation');assert v['membre']=='A' and v['detention_id'] and v['jours']==2,v
     q.execute("SELECT current_building,current_room,est_emprisonne->>'detentionId' FROM personnages_donnees WHERE name='A'");assert q.fetchone()==('commissariat','prison',v['detention_id'])
     q.execute("SELECT count(*) FROM detentions WHERE nom='A'");assert q.fetchone()[0]==1
     assert controle()==v,'le reçu perdu déclenche une nouvelle arrestation'
     q.execute("SELECT current_building,est_emprisonne,liquide FROM personnages_donnees WHERE name='B'");assert q.fetchone()==('centre-multinodal-luthecia',None,1325)
    else:exige(v);vus.add('passe')
   finally:q.execute('ROLLBACK TO SAVEPOINT jet_douane')
  assert vus=={'arrestation','passe'},vus
 cas('douane_vrais_jets_vraie_condamnation_ecrou_cellule_rejeu_sans_faux_joueur',prison)
 def corruption():
  depart();sql("UPDATE personnages_donnees SET pa=12,liquide=5000,arg=5000 WHERE name='B'")
  sql("UPDATE personnages_donnees SET inventory='[{\"id\":\"interdit\",\"name\":\"Objet interdit\",\"type\":\"poison\",\"legal\":false}]' WHERE name IN ('A','B')")
  vus=set()
  for seed in range(15):
   q.execute('SAVEPOINT corruption');q.execute('SELECT setseed(%s)',(seed/15,))
   v=exige(rpc('crime_corrompre_douanier',(1,300,'00000000-0000-4000-8000-000000000700'),qui='B'))
   try:
    q.execute("SELECT pa,liquide FROM personnages_donnees WHERE name='B'");assert q.fetchone()==(11,4700)
    assert rpc('crime_corrompre_douanier',(1,300,'00000000-0000-4000-8000-000000000700'),qui='B')==v
    if v['reussi']:
     vus.add('reussite');q.execute('SELECT personnage,corruption FROM navigation_passages_douaniers');assert q.fetchall()==[('B',True)]
     exige(controle())
     q.execute("SELECT jsonb_array_length(inventory),jsonb_array_length(convocations) FROM personnages_donnees WHERE name='A'");assert q.fetchone()==(0,1)
     q.execute("SELECT jsonb_array_length(inventory),jsonb_array_length(convocations) FROM personnages_donnees WHERE name='B'");assert q.fetchone()==(1,0)
    else:
     vus.add('echec');q.execute('SELECT count(*) FROM navigation_passages_douaniers');assert q.fetchone()[0]==0
   finally:q.execute('ROLLBACK TO SAVEPOINT corruption')
  assert vus=={'reussite','echec'},vus
 cas('douane_corruption_vrais_jets_cout_unique_et_dispense_personnelle_seulement',corruption)
 def ancien_sans_recu():
  depart();avant=photo();exige(rpc('crime_corrompre_douanier',(1,300),qui='B'),'requete_absente');assert photo()==avant
 cas('douane_ancienne_corruption_sans_recu_refusee_avant_paiement',ancien_sans_recu)
 def accessoire_historique():
  depart();sql("INSERT INTO pnj_possessions(pnj_id,objet,origine) VALUES('cie-S1','{\"id\":\"accessoire-interdit\",\"name\":\"Accessoire interdit\",\"type\":\"poison\",\"legal\":false}','blob_accessoires')")
  exige(controle())
  q.execute("SELECT pnj_miroir_possessions_si_axe_blob('cie-S1','[{\"id\":\"accessoire-interdit\",\"name\":\"Accessoire interdit\",\"type\":\"poison\",\"legal\":false}]')")
  q.execute("SELECT count(*) FROM pnj_possessions WHERE objet->>'id'='accessoire-interdit'");assert q.fetchone()[0]==0
 cas('douane_accessoire_historique_socle_confisque_sans_reapparaitre_au_miroir',accessoire_historique)
 def qhs():
  depart();sql("INSERT INTO jugements(id,country,city,accuse,motif,data,executee) VALUES('jugement-qhs-fixture','republic','capitale','B','Peine fictive','{\"motifs\":[{\"jours\":2}]}',false)")
  premier=exige(rpc('justice_executer_condamnation_soi',('jugement-qhs-fixture',),qui='B'))
  dernier=exige(rpc('detention_transferer_qhs',('Motif QHS fictif',2,None,None),qui='B'))
  assert dernier['detention_precedente']==premier['detention_id']
  q.execute("SELECT current_city,current_building,current_room,est_emprisonne->'qhs' FROM personnages_donnees WHERE name='B'");assert q.fetchone()==('qhs','qhs-prison','cellules_qhs',True)
  q.execute("SELECT mode_fin FROM detentions WHERE id=%s",(premier['detention_id'],));assert q.fetchone()[0]=='transfert_qhs'
  q.execute("SELECT count(*) FROM detentions WHERE nom='B' AND mode_fin IS NULL");assert q.fetchone()[0]==1
 cas('justice_vraie_reddition_puis_transfert_QHS_enregistre_position_et_chaine',qhs)
 def faux_transport_carceral():
  depart();avant=photo()
  exige(rpc('detention_ouvrir_soi',('Fausse peine',0,'capitale',None,False,None),qui='B'),'duree_invalide')
  exige(rpc('detention_ouvrir_soi',('Fausse destination',2,'ville_a',None,False,None),qui='B'),'ville_detention_invalide')
  assert photo()==avant
 cas('justice_ancienne_porte_soi_ne_permet_pas_peine_nulle_ou_teleportation',faux_transport_carceral)
 if suivante is not None:suivante(ctx)
if __name__=='__main__':sys.exit(i.lancer(suite))
