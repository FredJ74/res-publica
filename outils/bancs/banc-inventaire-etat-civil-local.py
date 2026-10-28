#!/usr/bin/env python3
"""Documents : sources reelles archivees, schema/identites fictifs, authenticated, rollback."""
from pathlib import Path
import importlib.util,re
R=Path(__file__).resolve().parents[2]
def scenario(q,own,call,check,uid,snapshot,Json):
 spec=importlib.util.spec_from_file_location('base2',R/'outils/bancs/banc-inventaire-receptions-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 for table,domain in [('mariages','personnage-et-presence'),('etat_civil_naissances','personnage-et-presence'),('etat_civil_deces','personnage-et-presence'),('successions','personnage-et-presence'),('villes','immobilier-et-territoire'),('postes_attribues','postes-et-institutions')]:
  src=(R/f'baseline/domaines/{domain}/10_tables.sql').read_text();own(re.search(r'CREATE TABLE public\.'+table+r' \([\s\S]*?\n\);',src)[0])
 own("ALTER TABLE personnages_donnees ADD COLUMN created_at timestamp without time zone DEFAULT now();ALTER TABLE personnages_donnees ADD COLUMN poste jsonb;")
 own(m.fonction('baseline/domaines/politique-et-elections/20_fonctions.sql','poste_est_atteste'))
 for _ in range(2):
  for file in ['20261027214000_inventaire_etat_civil_catalogue.sql','20261027214001_inventaire_etat_civil_documents.sql']:own((R/'migrations'/file).read_text())
 own("INSERT INTO ordres_couts VALUES('acte_officiel_notaire',1,100),('acte_officiel_mairie',1,0),('acte_officiel_juge',1,0),('acte_officiel',1,50)")
 own("INSERT INTO villes VALUES('republic','capitale','Luthécia',true,1);INSERT INTO etat_civil_naissances VALUES('n1','Fixture','republic','capitale','2020-01-02T12:00:00Z')")
 own("UPDATE personnages_donnees SET current_building='office-notarial',current_room='bureau_contrats',inventory='[]',liquide=100,arg=300,pa=30 WHERE name='Fixture'")
 def doc(k,nom='Fixture',typ='naissance',ref=None,pa=1,cost=100):return call('etat_civil_document_recevoir',[uid(k),nom,typ,ref,pa,cost])
 def snap():return own("SELECT jsonb_build_array((SELECT to_jsonb(d) FROM personnages_donnees d WHERE name='Fixture'),(SELECT jsonb_agg(to_jsonb(b)) FROM comptes_bancaires b),(SELECT jsonb_agg(to_jsonb(r)) FROM inventaire_actions_recus r))")
 v=doc(400);check(v['ok'] and v['inventory'][0]['type']=='acte_officiel_naissance' and v['inventory'][0]['concerne']=='Fixture','acte genere depuis source serveur, pas le texte du client')
 check(v['paie']['pa']==29 and v['paie']['montant_preleve']==100,'un seul paiement notarial existant')
 before=snap();check(doc(400)['rejeu'] and snap()==before,'rejeu acte sans second paiement ni document')
 check(doc(401).get('raison')=='deja_possede','unicite acteCle controlee par le serveur')
 before=snap();check(doc(402,ref='autre').get('raison')=='reference_invalide' and snap()==before,'reference artificielle ne cree pas une seconde naissance')
 own("INSERT INTO etat_civil_deces VALUES('d1','Disparu fictif','republic','2021-03-04T10:00:00Z','capitale')")
 v=doc(403,'Disparu fictif','deces');check(v['ok'] and '4 mars 2021' in v['inventory'][-1]['desc'],'deces delivre meme si PJ supprime, sans fausse naissance')
 own("INSERT INTO mariages(id,conjoint1,conjoint2,country,statut,jour_union,created_at,city) VALUES('m1','Fixture','Autre','republic','dissous',1,'2022-05-06T10:00:00Z','capitale')")
 own("UPDATE personnages_donnees SET liquide=100,arg=300 WHERE name='Fixture'")
 v=doc(404,typ='mariage',ref='m1');check(v['ok'] and 'Union dissoute (divorce)' in v['inventory'][-1]['desc'],'union reelle avec dissolution conservee')
 own("INSERT INTO successions(id,defunt,country,statut,dispositions) VALUES('s1','Defunt fictif','republic','en_attente',%s)",(Json([{'type':'argent','part_nette':200,'resultat':{'beneficiaire':'Fixture'}}]),))
 before=snap();check(doc(405,typ='succession',ref='s1').get('raison')=='acte_introuvable' and snap()==before,'succession non resolue non divulguee ni delivree')
 own("UPDATE successions SET statut='resolue'");own("UPDATE personnages_donnees SET liquide=100,arg=300 WHERE name='Fixture'")
 v=doc(405,typ='succession',ref='s1');check(v['ok'] and '200 FR' in v['inventory'][-1]['desc'],'succession resolue pour le vrai beneficiaire')
 before=snap();check(doc(406,'Autre','succession','s1').get('raison')=='acte_introuvable' and snap()==before,'autre beneficiaire non invente')
 own("UPDATE personnages_donnees SET current_building='mairie-capitale',current_room='bureau_maire_adjoint',poste=%s,inventory='[]' WHERE name='Fixture'",(Json({'id':'maire_adjoint','city':'capitale'}),))
 before=snap();check(doc(407,cost=0).get('raison')=='lieu_ou_autorite_refuse' and snap()==before,'poste de presentation sans attestation refuse')
 own("INSERT INTO postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('p1','republic','maire_adjoint','capitale','Fixture','fixture')")
 v=doc(407,cost=0);check(v['ok'] and v['paie']['montant_preleve']==0,'adjoint atteste utilise son ordre gratuit en francs')
 own("UPDATE personnages_donnees SET current_room='salle_archives' WHERE name='Fixture'")
 v=doc(408,'Pierre Thibault','fiche',pa=0,cost=0);check(v['ok'] and '1898' in v['inventory'][-1]['desc'] and v['inventory'][-1]['id'].startswith('fiche-etat-civil-'),'fiche historique copie exacte du modele, identifiant protege pour fret')
 v=doc(409,typ='fiche',pa=0,cost=0);check(v['ok'] and 'Union avec Autre dissoute' in v['inventory'][-1]['desc'],'fiche PJ depuis evenements reels et union dissoute')
 before=snap();check(doc(410,typ='fiche',pa=0,cost=0).get('raison')=='deja_possede' and snap()==before,'fiche deja possedee sans ajout local')
 before=snap();check(doc(411,'Personne inconnue','fiche',pa=0,cost=0).get('raison')=='personne_introuvable' and snap()==before,'fiche inexistante refusee sans objet invente')
 own("UPDATE personnages_donnees SET current_room=NULL WHERE name='Fixture'");before=snap();check(doc(412,typ='fiche',pa=0,cost=0).get('raison')=='pas_sur_place' and snap()==before,'absence de piece refusee')
if __name__=='__main__':
 spec=importlib.util.spec_from_file_location('base',R/'outils/bancs/banc-inventaire-receptions-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.main(scenario)
