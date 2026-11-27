#!/usr/bin/env python3
"""Compose les lots existants (5 + 89 + tarifs), ne les exécute jamais."""
import argparse,hashlib,importlib.util,json,subprocess,sys,tempfile
from pathlib import Path
R=Path(__file__).resolve().parents[2]
def charger(n,p):
 s=importlib.util.spec_from_file_location(n,R/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

def corps_transaction(sql):
 from pglast import parse_sql
 x=parse_sql(sql);begin=parse_sql('BEGIN;')[0].stmt.kind;commit=parse_sql('COMMIT;')[0].stmt.kind
 if len(x)<3 or type(x[0].stmt).__name__!='TransactionStmt' or x[0].stmt.kind!=begin or type(x[-1].stmt).__name__!='TransactionStmt' or x[-1].stmt.kind!=commit or any(type(t.stmt).__name__=='TransactionStmt' for t in x[1:-1]):raise ValueError('Une seule enveloppe transactionnelle attendue')
 return sql[x[1].stmt_location:x[-1].stmt_location]

def preparer(destination=None):
 org=charger('org219','outils/livraison/preparer-organisations-219.py');grp=charger('grp219','outils/livraison/preparer-groupes-219.py')
 om=json.loads(org.MAN.read_text());gm=json.loads(grp.MAN.read_text());cm=json.loads((R/'outils/audits/LIVRAISON-COUTS-219-20261031.json').read_text());p=R/cm['migration'];cout=p.read_text()
 if hashlib.sha256(p.read_bytes()).hexdigest()!=cm['sha256']:raise ValueError('Migration de tarifs modifiée')
 gen=json.loads(subprocess.check_output([sys.executable,str(R/'outils/generateurs/generer_ordres_couts.py'),'--json'],cwd=R,text=True))
 # Le paquet 95 est une photographie historique. Les deux ordres SSM
 # gratuits ont ete ajoutes plus tard, hors de ce paquet historique.
 ajouts_ssm=('ssm_besoin_aide','ssm_demander_rendezvous')
 ssm=sorted((r for r in gen if r['fn'] in ajouts_ssm),key=lambda r:r['fn'])
 if ssm != [{'fn':'ssm_besoin_aide','pa':0,'cost':0},
            {'fn':'ssm_demander_rendezvous','pa':0,'cost':0}]:
  raise ValueError('Tarifs SSM non examines ou absents')
 # Le catalogue manufacturé du 04/11 remplace deux boutons de la scierie.
 # Ils appartiennent à cette photographie historique, pas au jeu actuel.
 nouveau='consulter_catalogue_manufactures'
 if [r for r in gen if r['fn']==nouveau]!=[{'fn':nouveau,'pa':0,'cost':0}]:
  raise ValueError('Ordre catalogue manufacture absent ou incorrect')
 # Sous-menu de virement ajoute apres la photographie 95 : il est gratuit,
 # et les deux voies de paiement originelles restent dans le catalogue historique.
 if [r for r in gen if r['fn']=='virements']!=[{'fn':'virements','pa':0,'cost':0}]:
  raise ValueError('Menu Virements absent ou tarif non conforme')
 retires=[('assigner_mission',1,0),
          ('fabriquer_armoire_souvenirs',3,0),
          ('acheter_armoire_souvenirs',0,0),
          ('virement_joueur',1,0),
          ('virement_automatique',1,0),
          ('consommer_buvette',1,50)]  # retire par #682
 if any(r['fn'] in {t[0] for t in retires} for r in gen):
  raise ValueError('Ordre retiré réintroduit dans les commandes actuelles')
 # Criminalité lot 7 (20/11/2026) : « Falsifier un procès-verbal » et les trois accélérations par corruption retirées ; corrompre_fonct reste (directeur du QHS, 3 PA 1 500).
 retires_variantes=[('corrompre_chantier',2,1500),('corrompre_fonct',3,500),('corrompre_fonct#reussite',0,500),('corrompre_fonctionnaire_permis',2,800),('corrompre_rdv_notaire',2,800)]
 if any((r['fn'],r['pa'],r['cost']) in retires_variantes for r in gen):
  raise ValueError('Tarif retiré réintroduit dans les commandes actuelles')
 retires=retires+retires_variantes
 # Criminalité, décisions du 20/11/2026 : « Obtenir du Polonium » retiré du port orphelin de Novomirsk.
 retires_polonium=[('acheter_polonium',2,600)]
 if any((r['fn'],r['pa'],r['cost']) in retires_polonium for r in gen):
  raise ValueError('Tarif retiré réintroduit dans les commandes actuelles')
 retires=retires+retires_polonium
 # Refonte des informateurs (22/11/2026) : « Recruter un informateur » et les informateurs recrutés retirés ; « Acheter une information » ajouté.
 retires_informateurs=[('recruter_informateur_pnj',1,150),('recruter_informateur_2',1,400),('recruter_info_4',3,0),('consulter_info_4',1,0),('gerer_informateurs',0,0)]
 if any((r['fn'],r['pa'],r['cost']) in retires_informateurs for r in gen):
  raise ValueError('Tarif retiré réintroduit dans les commandes actuelles')
 retires=retires+retires_informateurs
 # Décision de Fred du 26/11/2026 : « Contrebande portuaire » supprimée (la contrebande se joue au fret).
 retires_contrebande=[('contrebande_port',3,0),
  # Décision de Fred du 27/11/2026 : délibérations de la loge, placements Helvetia, caisse et stock de la scierie supprimés.
  ('deliberer_loge',2,0),('compte_offshore',0,0),('consulter_caisse_usine',0,0),('consulter_stock_usine',0,0)]
 if any((r['fn'],r['pa'],r['cost']) in retires_contrebande for r in gen):
  raise ValueError('Tarif retiré réintroduit dans les commandes actuelles')
 retires=retires+retires_contrebande
 # Prix d'achat des nouvelles parcelles de PSM (decision de Fred, 04/11/2026), posterieurs a la photographie.
 ajouts_terrains_psm={('acheter_terrain',2,c) for c in (19800,37200,50400,66000)}
 if not ajouts_terrains_psm<= {(r['fn'],r['pa'],r['cost']) for r in gen}:
  raise ValueError('Prix des terrains de PSM absents du catalogue actuel')
 # Devis du chantier naval : contrôle explicite et exclusion de la capture historique.
 naval=[r for r in gen if r['fn']=='consulter_devis_chantier_naval']
 if naval!=[{'fn':'consulter_devis_chantier_naval','pa':0,'cost':0}]:
  raise ValueError('Ordre devis naval absent ou altéré')
 # Siège du renseignement militaire (05/11) : contrôle explicite et exclusion de la capture historique.
 if [r for r in gen if r['fn']=='interroger_renseignement']!=[{'fn':'interroger_renseignement','pa':1,'cost':0}]:
  raise ValueError('Interrogatoire du renseignement absent ou altéré')
 # Vehicules personnels (05/11) : quatre ordres d'ecran gratuits, exclus de la capture historique.
 vehicules=('garage_reviser','garage_vehicules','mes_vehicules','station_carburant')
 if sorted([r for r in gen if r['fn'] in vehicules],key=lambda r:r['fn'])!=[{'fn':f,'pa':0,'cost':0} for f in vehicules]:
  raise ValueError('Ordres des vehicules absents ou alteres')
 # La sous-famille petro-chimique est posterieure a la coupe historique 95.
 # Controle strict de son unique cout sans reecrire l'empreinte ancienne.
 petro=[r for r in gen if r['fn']=='produire_derives_petrochimiques']
 if petro != [{'fn':'produire_derives_petrochimiques','pa':1,'cost':0}]:
  raise ValueError('Ordre petro-chimique absent ou altere')
 # Sovarka (05-07/11) : ordres postérieurs à la coupe 95, chacun contrôlé (présent, unique, tarif exact).
 # Mêmes listes que preparer-recette97-219.py ; la variante de dîner à 100 n'exclut pas les autres dîners.
 sovarka=[('contrebande_poissonniere',1,0),('pharmacie_medicaments',0,0),('poissonniere_poisson',0,0),('salon_coupe',0,0),('sovarka_cession',1,0),('sovarka_commerces_libres',0,0),('sovarka_demander_local',1,0),('sovarka_dossiers_commerciaux',0,0),('sovarka_retirer_droit',1,0),('sovarka_signer_attribution',1,0),('sovarka_terrain_municipal',0,0),('sovarka_demande_location',1,0),('sovarka_reunion_evenement',1,0),('sovarka_reunion_reserver',0,0),('sovarka_repas_presidentiel',0,0),('sovarka_mon_parti',0,0),('sovarka_parti_fonder',2,15),('sovarka_partis',0,0),('sovarka_autocritique',1,0),('sovarka_conscription',0,0),('sovarka_conscrit_presenter',1,0),('sovarka_lois_examen',0,0),('sovarka_saisir_juge',1,0),('sovarka_seance',0,0),('sovarka_signalements',0,0),('sovarka_sondages',0,0),('sovarka_surveiller',2,0),('sovarka_musee_billet',0,8),('sovarka_acte_officiel',1,8),('sovarka_acte_officiel_autorite',1,0),('sovarka_extrait_parti',1,7),('sovarka_offrir_cafe',0,0),('sovarka_ordres_ministre',0,0),('sovarka_registre_plaintes',0,0)]
 fns_sovarka={f for f,_,_ in sovarka}
 if sorted((r['fn'],r['pa'],r['cost']) for r in gen if r['fn'] in fns_sovarka)!=sorted(sovarka):
  raise ValueError('Ordres Sovarka absents, dupliqués ou mal tarifés')
 # Provinces de Sovarka (10/11, #681/#686) : memes ajouts que preparer-recette97-219.py, controles un par un.
 provinces=[('ferme_lapin',1,0),('ferme_legumes',1,0),('ferme_oeufs',1,0),('ferme_poulet',1,0),('ferme_renne',5,0),('ferme_traire',1,0),('foret_campement',0,0),('foret_couper',1,0),('maison_habitant',0,0),('souscrire_bon_etat',0,0),('sovarka_ecoutes',0,0),('trinquer_habitant',3,0),('voler_archives_ecoute',2,0)]
 if sorted((r['fn'],r['pa'],r['cost']) for r in gen if r['fn'] in {f for f,_,_ in provinces})!=sorted(provinces):
  raise ValueError('Ordres des provinces de Sovarka absents, dupliqués ou mal tarifés')
 fns_sovarka=fns_sovarka|{f for f,_,_ in provinces}
 supporters_dynamo=('rejoindre_club_supporters',1,25)  # variante de tarif du Dynamo (#682)
 if sum((r['fn'],r['pa'],r['cost'])==supporters_dynamo for r in gen)!=1:
  raise ValueError('Adhésion des supporters du Dynamo absente ou dupliquée')
 diner_sovarka=('diner_affaires',2,100)
 casier_sovarka=('casier_mon_extrait',1,8)  # extrait de casier à 8 PSK en Sovarka (08/11)
 if sum((r['fn'],r['pa'],r['cost'])==diner_sovarka for r in gen)!=1 or sum((r['fn'],r['pa'],r['cost'])==casier_sovarka for r in gen)!=1:
  raise ValueError('Dîner Sovarka absent, dupliqué ou mal tarifé')
 # Ordres et variantes ajoutés après le 10/11 (relevé du 15/11) : postérieurs à la coupe, écartés (mêmes que recette 97).
 # #1020 : huit menus gratuits du goulag, postérieurs à la coupe (mêmes que la recette 97).
 # Distillerie (20/11/2026) : trois ordres postérieurs à la coupe (mêmes que la recette 97).
 # Lot de Krasnov, radar (21/11/2026).
 # Lot de Krasnov, école et énigme (21/11/2026).
 # Refonte des informateurs (22/11/2026) : « Recruter un informateur » et les informateurs recrutés retirés ; « Acheter une information » ajouté,
# puis retiré avec « Offrir un verre à l'habitué » (bloc 3 du 23/11/2026 : on clique sur le PNJ ; migration 20261123211000) ; « Soumettre la solution de l'énigme au directeur » retiré (bloc 4, point 29, migration 20261123214000).
 posterieurs_1011={('transferts_detenus', 0, 0), ('indices_interrogatoire', 0, 0), ('acheter_souvenir', 0, 0), ('medecin_diagnostiquer', 1, 0), ('medecin_soigner', 2, 0), ('puiser_eau', 1, 0), ('acheter_guide_baies_musee', 0, 10), ('stage_survie_foret', 3, 25), ('acheter_polonium_colonel', 2, 0), ('demander_fournisseur_kalachnikov', 1, 0), ('interroger_ganbaatar_polonium', 0, 0), ('acheter_spiritueux_local', 0, 0), ('produire_spiritueux', 1, 0), ('produire_sucre', 1, 0), ('boutique_climat', 0, 0), ('acheter_graisse', 0, 0), ('enqueter_plainte', 2, 0), ('crocheter', 3, 0), ('forcer_porte', 2, 0), ('cambrioler', 2, 0), ('voler', 3, 0), ('boutique_discretion', 0, 0), ('acheter_furet', 0, 0), ('changer_domicile', 1, 50), ('consulter_syndicat_etat', 0, 0), ('declencher_election_syndicat_etat', 1, 0), ('manifestation_soutien_president', 0, 0), ('quitter_syndicat_etat', 0, 0), ('se_syndiquer_etat', 1, 15), ('goulag_autorisations_gerer', 0, 0), ('sovarka_graces', 0, 0), ('enigme1_parler_valerie', 0, 0), ('service_etage_carte', 0, 0), ('sovarka_goulag_interroger', 1, 0), ('parti_boite_registre', 0, 0), ('tresor_donner_livre', 0, 0), ('residence_minibar', 0, 0), ('sovarka_habilitations', 0, 0), ('sovarka_goulag_liste', 0, 0), ('clinique_dormir', 0, 0), ('ecouter_guide_musee', 0, 0), ('sovarka_goulag_corrompre', 0, 0), ('pavillon_suite', 0, 0), ('goulag_visite_demander', 0, 0), ('faire_don', 0, 0), ('residence_reserver', 0, 0), ('ilia_ecouter_guide', 0, 0), ('sovarka_goulag_entree', 0, 0), ('marche_krasnov', 0, 0), ('inspecter_piece', 1, 0), ('se_cacher', 1, 0), ('sovarka_goulag_dortoir', 0, 0), ('interieur_dossiers', 0, 0), ('goulag_refuge_nuit', 0, 0), ('pavillon_reception', 0, 0), ('ferme_vaches', 1, 0), ('escort_standard', 0, 0), ('commanditer_sondage', 1, 60), ('tresor_repondre', 0, 0), ('consulter_archives_ecoute', 1, 0), ('diner_affaires', 2, 40), ('regulation_production', 1, 0), ('sovarka_goulag_registre', 0, 0), ('parti_denoncer', 1, 0), ('sovarka_manifs_gerer', 0, 0), ('goulag_visiteur_retour', 0, 0), ('sovarka_goulag_incidents', 0, 0), ('residence_location', 0, 0), ('heros_travail_classement', 0, 0), ('dormir', 0, 0), ('tresor_ecouter_guide', 0, 0), ('sovarka_goulag_dormir', 0, 0), ('sovarka_goulag_manger', 0, 0), ('heros_travail_tableau', 0, 0), ('enigme1_examiner_cadre', 0, 0), ('kolkhoze_caisse', 0, 0), ('goulag_voyager', 0, 0), ('goulag_refuge_terminer', 0, 0), ('goulag_detenu_entree', 0, 0), ('sovarka_goulag_mirador', 0, 0), ('propagande_etat', 3, 150), ('sovarka_goulag_sanction', 1, 0), ('clinique_reserver_nuit', 0, 0), ('goulag_depart_pied', 0, 0), ('acces_reserve_info', 0, 0)}
 if not posterieurs_1011<={(r['fn'],r['pa'],r['cost']) for r in gen}:raise ValueError('Ordre postérieur au 10/11 absent du catalogue')
 gen=[r for r in gen if (r['fn'],r['pa'],r['cost']) not in posterieurs_1011]
 # 16/11/2026 : récolte passée de 2 à 1 PA (régulation de la production) ; la coupe historique garde l'ancien tarif.
 gen=[dict(r,pa=2) if (r['fn'],r['pa'],r['cost'])==('recolter_matiere',1,0) else r for r in gen]
 # 18/11/2026 : naturalisation à 2 PA + 50 ; la coupe historique garde 2 PA sans frais.
 gen=[dict(r,cost=0) if (r['fn'],r['pa'],r['cost'])==('demander_naturalisation',2,50) else r for r in gen]
 # 23/11/2026 : rébellion à 1 PA (mission Novomirsk, point 12) ; la coupe historique garde 2 PA.
 gen=[dict(r,pa=2) if (r['fn'],r['pa'],r['cost'])==('se_rebeller',1,0) else r for r in gen]
 # 25/11/2026 au soir : « Mobiliser les membres » à 0 PA (audit des chances, 1.3a) ; la coupe historique garde 2 PA.
 gen=[dict(r,pa=2) if (r['fn'],r['pa'],r['cost'])==('mobiliser',0,0) else r for r in gen]
 # 27/11/2026 au soir : « Interroger un détenu » (QHS) à 1 PA (modèle du goulag) ; la coupe historique garde 2 PA.
 gen=[dict(r,pa=2) if (r['fn'],r['pa'],r['cost'])==('interroger',1,0) else r for r in gen]
 # 28/11/2026 : « Produire une fuite » à 2 PA ; la coupe historique garde 3 PA.
 gen=[dict(r,pa=3) if (r['fn'],r['pa'],r['cost'])==('fuite_info',2,0) else r for r in gen]
 t=sorted([(r['fn'],r['pa'],r['cost']) for r in gen if r['fn'] not in ajouts_ssm+(nouveau,'virements','produire_derives_petrochimiques','consulter_devis_chantier_naval','interroger_renseignement')+vehicules and r['fn'] not in fns_sovarka and (r['fn'],r['pa'],r['cost'])!=diner_sovarka and (r['fn'],r['pa'],r['cost'])!=casier_sovarka and (r['fn'],r['pa'],r['cost'])!=supporters_dynamo and (r['fn'],r['pa'],r['cost']) not in ajouts_terrains_psm]+retires)
 md5=hashlib.md5('\n'.join('%s|%d|%d'%r for r in t).encode()).hexdigest()
 if md5!=cm['apres']['md5'] or len(t)!=cm['apres']['lignes']:raise ValueError('Sources de tarifs changées : réexaminer le plan')
 entrees=om['migrations']+gm['prerequis']+gm['migrations']+[{'version':cm['version'],'fichier':cm['migration'],'sha256':cm['sha256']}]
 versions=[e['version'] for e in entrees]
 if len(entrees)!=95 or versions!=sorted(set(versions)):raise ValueError('Ordre exact 5 + 89 + 1 requis')
 with tempfile.TemporaryDirectory(prefix='hg219-compose-') as d:
  f=Path(d)/'groupe.sql';grp.preparer(f,inclure_prerequis=True);groupe=f.read_text()
 citer=lambda v:"'"+v.replace("'","''")+"'"
 sql="""-- PR #219 : composition préparée, NON exécutée et NON validée contre le catalogue 1008.
-- Aucun des 65 autres préparatifs n'est inclus. Pas de déploiement autorisé ici.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='120s';
DO $versions_globales$ BEGIN
 IF EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version IN ("""+','.join(citer(v) for v in versions)+""")) THEN RAISE EXCEPTION '219_complet_versions_presentes_prevol_frais_requis';END IF;
END $versions_globales$;
"""
 sql+=corps_transaction(org.preparer())+'\n'+corps_transaction(groupe)+'\n'+cout+'\n'
 sql+='INSERT INTO supabase_migrations.schema_migrations(version,name,statements) VALUES('+citer(cm['version'])+','+citer(p.stem[15:])+',ARRAY['+citer(cout)+']);\nCOMMIT;\n'
 from pglast import parse_sql
 if len([x for x in parse_sql(sql) if type(x.stmt).__name__=='TransactionStmt'])!=2:raise ValueError('Transaction interne détectée')
 if destination:Path(destination).write_text(sql)
 return sql,entrees
if __name__=='__main__':
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--sortie');o=a.parse_args();sql,entrees=preparer(o.sortie);print(json.dumps({'migrations':len(entrees),'sha256':hashlib.sha256(sql.encode()).hexdigest(),'transaction_unique':True,'production_executee':False,'compatibilite_catalogue1008':'non_verifiee'},ensure_ascii=False,indent=2))
