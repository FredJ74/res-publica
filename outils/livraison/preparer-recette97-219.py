#!/usr/bin/env python3
"""Plan 95 + #318 + #324 et delta tarifaire privé. N'exécute aucune migration."""
import argparse,hashlib,importlib.util,json,os,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
COMPLEMENTS=('migrations/20261101170000_circuits_residuels_positions_219.sql','migrations/20261101171000_hospitalisation_pa0.sql')
def module(n,p):
 s=importlib.util.spec_from_file_location(n,R/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def verifier_ordre(entrees):
 versions=[x['version'] for x in entrees]
 if len(entrees)!=97 or versions!=sorted(set(versions)) or [x['fichier'] for x in entrees[-2:]]!=list(COMPLEMENTS):raise ValueError('Ordre canonique 95 puis #318 puis #324 requis')
 for e in entrees:
  p=R/e['fichier']
  if hashlib.sha256(p.read_bytes()).hexdigest()!=e['sha256']:raise ValueError('Source de migration modifiée : '+p.name)
 return entrees
def preparer(paquet=None):
 org=json.loads((R/'outils/audits/LIVRAISON-ORGANISATIONS-219-20261031.json').read_text());grp=json.loads((R/'outils/audits/LIVRAISON-GROUPES-219-20261030.json').read_text());couts=json.loads((R/'outils/audits/LIVRAISON-COUTS-219-20261031.json').read_text())
 es=org['migrations']+grp['prerequis']+grp['migrations']+[{'version':couts['version'],'fichier':couts['migration'],'sha256':couts['sha256']}]
 for nom in COMPLEMENTS:es.append({'version':Path(nom).name[:14],'fichier':nom,'sha256':hashlib.sha256((R/nom).read_bytes()).hexdigest()})
 verifier_ordre(es)
 source=json.loads(subprocess.check_output([sys.executable,str(R/'outils/generateurs/generer_ordres_couts.py'),'--json'],cwd=R,text=True))
 # Le plan 97 est une photographie HISTORIQUE des 461 triplets. Deux ordres SSM
 # gratuits ont ete ajoutes depuis (rendez-vous puis information Pascale).
 # Ils n'etaient pas executes par ce plan : les exclure de la comparaison
 # historique, mais les controler explicitement dans le catalogue actuel.
 ajouts_ssm=('ssm_besoin_aide','ssm_demander_rendezvous')
 hors_coupe=sorted((x for x in source if x['fn'] in ajouts_ssm),key=lambda x:x['fn'])
 if hors_coupe!=[{'fn':'ssm_besoin_aide','pa':0,'cost':0},
                 {'fn':'ssm_demander_rendezvous','pa':0,'cost':0}]:
  raise ValueError('Ordres SSM non conformes ou absents du catalogue actuel')
 # Le catalogue manufacturé gratuit remplace deux anciens boutons (04/11/2026).
 # Ce nouveau point d'entrée n'existait pas lors du plan 97. Les deux anciens
 # ordres restent dans la photographie d'origine, sans revenir à l'écran.
 ajouts_manufactures=('consulter_catalogue_manufactures',)
 hors_coupe_manufactures=[x for x in source if x['fn'] in ajouts_manufactures]
 if hors_coupe_manufactures!=[{'fn':'consulter_catalogue_manufactures','pa':0,'cost':0}]:
  raise ValueError('Catalogue manufacturé absent ou tarif inattendu')
 # Six parcelles de PSM (decision de Fred, 04/11/2026) : nouveaux prix d'achat (12 FR/m²)
 # des lots 9, 11, 12 et 13, absents du plan 97 (26 400 FR existait deja a Montrouge). Exclus de la photographie, controles ici.
 ajouts_terrains_psm=[{'fn':'acheter_terrain','pa':2,'cost':c} for c in (19800,37200,50400,66000)]
 cle=lambda x:(x['fn'],x['pa'],x['cost'])
 if not all(any(cle(x)==cle(t) for x in source) for t in ajouts_terrains_psm):
  raise ValueError('Prix des terrains de PSM absents du catalogue actuel')
 # Nouvelle gamme petro-chimique (04/11) : absente de la coupe historique.
 # Controle explicite de l'unique ordre de la sous-famille, sans polluer l'empreinte du plan 97.
 ajouts_petrochimie=[{'fn':'produire_derives_petrochimiques','pa':1,'cost':0}]
 if [x for x in source if x['fn'] in {t['fn'] for t in ajouts_petrochimie}] != ajouts_petrochimie:
  raise ValueError('Ordres petro-chimiques manquants, dupliques ou mal tarifes')
 ajouts_naval=[{'fn':'consulter_devis_chantier_naval','pa':0,'cost':0}]
 if [x for x in source if x['fn']=='consulter_devis_chantier_naval']!=ajouts_naval:
  raise ValueError('Devis naval absent ou tarif anormal')
 # Siège du renseignement militaire (05/11) : copie de « Interroger un détenu », hors coupe historique.
 ajouts_renseignement=[{'fn':'interroger_renseignement','pa':2,'cost':0}]
 if [x for x in source if x['fn']=='interroger_renseignement']!=ajouts_renseignement:
  raise ValueError('Interrogatoire du renseignement absent ou tarif anormal')
 # Vehicules personnels (05/11) : quatre ordres d'ecran gratuits, hors coupe historique.
 ajouts_vehicules=[{'fn':f,'pa':0,'cost':0} for f in ('garage_reviser','garage_vehicules','mes_vehicules','station_carburant')]
 if sorted([x for x in source if x['fn'] in {t['fn'] for t in ajouts_vehicules}],key=lambda x:x['fn'])!=ajouts_vehicules:
  raise ValueError('Ordres des vehicules absents ou tarif anormal')
 # Sovarka (05–06/11) : ajouts postérieurs à la photographie, provenance auditée.
 ajouts_sovarka=[{'fn': 'contrebande_poissonniere', 'pa': 1, 'cost': 0}, {'fn': 'pharmacie_medicaments', 'pa': 0, 'cost': 0}, {'fn': 'poissonniere_poisson', 'pa': 0, 'cost': 0}, {'fn': 'salon_coupe', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_cession', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_commerces_libres', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_demander_local', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_dossiers_commerciaux', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_retirer_droit', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_signer_attribution', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_terrain_municipal', 'pa': 0, 'cost': 0}]
 if sorted([x for x in source if x['fn'] in {t['fn'] for t in ajouts_sovarka}],key=lambda x:x['fn'])!=ajouts_sovarka:
  raise ValueError('Ordres Sovarka absents, dupliques ou mal tarifes')
 # Galeries et réunions livrées ensuite (#555/#560/#568), hors coupe du plan 97.
 ajouts_sovarka_reunions=[{'fn': 'sovarka_demande_location', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_reunion_evenement', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_reunion_reserver', 'pa': 0, 'cost': 0}]
 if sorted([x for x in source if x['fn'] in {t['fn'] for t in ajouts_sovarka_reunions}],key=lambda x:x['fn'])!=ajouts_sovarka_reunions:
  raise ValueError('Ordres réunions Sovarka absents, dupliques ou mal tarifes')
 # #572 : variante de dîner Sovarka, sans exclure les autres tarifs historiques du même ordre.
 # Variantes de tarif de Sovarka (même fn qu'un ordre historique) : dîner 08/11, extrait de casier 8 PSK (08/11).
 ajouts_diner_sovarka=[{'fn':'diner_affaires','pa':2,'cost':100},{'fn':'casier_mon_extrait','pa':1,'cost':8}]
 if any(sum(x==v for x in source)!=1 for v in ajouts_diner_sovarka):
  raise ValueError('Dîner Sovarka absent, dupliqué ou mal tarifé')
 # #575 : pouvoir de Sovarka (07/11), deux ordres gratuits hors coupe du plan 97.
 # Partis de Sovarka (07/11, PR #617) : salle des partis, mêmes contrôles.
 ajouts_sovarka_pouvoir=[{'fn':'sovarka_autocritique','pa':1,'cost':0},{'fn':'sovarka_conscription','pa':0,'cost':0},{'fn':'sovarka_conscrit_presenter','pa':1,'cost':0},{'fn':'sovarka_lois_examen','pa':0,'cost':0},{'fn':'sovarka_mon_parti','pa':0,'cost':0},{'fn':'sovarka_musee_billet','pa':0,'cost':8},{'fn':'sovarka_parti_fonder','pa':2,'cost':15},{'fn':'sovarka_partis','pa':0,'cost':0},{'fn':'sovarka_repas_presidentiel','pa':0,'cost':0},{'fn':'sovarka_saisir_juge','pa':1,'cost':0},{'fn':'sovarka_seance','pa':0,'cost':0},{'fn':'sovarka_signalements','pa':0,'cost':0},{'fn':'sovarka_sondages','pa':0,'cost':0},{'fn':'sovarka_surveiller','pa':2,'cost':0}]
 # Justice de Sovarka (08/11, PR #644) : greffe, bureau des magistrats, commissariat, salle des partis.
 ajouts_sovarka_pouvoir=sorted(ajouts_sovarka_pouvoir+[{'fn':'sovarka_acte_officiel','pa':1,'cost':8},{'fn':'sovarka_acte_officiel_autorite','pa':1,'cost':0},{'fn':'sovarka_extrait_parti','pa':1,'cost':7},{'fn':'sovarka_offrir_cafe','pa':0,'cost':0},{'fn':'sovarka_ordres_ministre','pa':0,'cost':0},{'fn':'sovarka_registre_plaintes','pa':0,'cost':0}],key=lambda x:x['fn'])
 if sorted([x for x in source if x['fn'] in {t['fn'] for t in ajouts_sovarka_pouvoir}],key=lambda x:x['fn'])!=ajouts_sovarka_pouvoir:
  raise ValueError('Ordres pouvoir Sovarka absents, dupliques ou mal tarifes')
 # Provinces de Sovarka (10/11, #681 et #686) et Dynamo (#682) : ajouts posterieurs a la photographie.
 # L'adhesion des supporters a 25 PSK est une variante de tarif d'un ordre historique (comme le diner).
 ajouts_sovarka_provinces=[{'fn':'ferme_lapin','pa':1,'cost':0},{'fn':'ferme_legumes','pa':1,'cost':0},{'fn':'ferme_oeufs','pa':1,'cost':0},{'fn':'ferme_poulet','pa':1,'cost':0},{'fn':'ferme_renne','pa':5,'cost':0},{'fn':'ferme_traire','pa':1,'cost':0},{'fn':'foret_campement','pa':0,'cost':0},{'fn':'foret_couper','pa':1,'cost':0},{'fn':'maison_habitant','pa':0,'cost':0},{'fn':'souscrire_bon_etat','pa':0,'cost':0},{'fn':'sovarka_ecoutes','pa':0,'cost':0},{'fn':'trinquer_habitant','pa':3,'cost':0},{'fn':'voler_archives_ecoute','pa':2,'cost':0}]
 if sorted([x for x in source if x['fn'] in {t['fn'] for t in ajouts_sovarka_provinces}],key=lambda x:x['fn'])!=ajouts_sovarka_provinces:
  raise ValueError('Ordres des provinces de Sovarka absents, dupliques ou mal tarifes')
 variante_supporters={'fn':'rejoindre_club_supporters','pa':1,'cost':25}
 if sum(x==variante_supporters for x in source)!=1:
  raise ValueError('Adhesion des supporters du Dynamo absente ou dupliquee')
 # Ordres et variantes ajoutés après le 10/11 (relevé du 15/11) : postérieurs au plan 97, écartés de la photographie.
 # Distillerie (20/11/2026) : produire des spiritueux, produire du sucre, spiritueux de la maison.
 # Lot de Krasnov, radar (21/11/2026) : sources du secret du colonel et achat du polonium.
 # Lot de Krasnov, école et énigme (21/11/2026).
# Eau de la place de l'Ours, « Puiser de l'eau » (21/11/2026, soir).
 # Refonte des informateurs (22/11/2026) : « Recruter un informateur » et les informateurs recrutés retirés ; « Acheter une information » ajouté,
# puis retiré avec « Offrir un verre à l'habitué » (bloc 3 du 23/11/2026 : on clique sur le PNJ ; migration 20261123210000).
 ajouts_posterieurs_1011=[{'fn': 'medecin_diagnostiquer', 'pa': 1, 'cost': 0}, {'fn': 'medecin_soigner', 'pa': 2, 'cost': 0}, {'fn': 'puiser_eau', 'pa': 1, 'cost': 0}, {'fn': 'acheter_guide_baies_musee', 'pa': 0, 'cost': 10}, {'fn': 'repondre_enigme_krasnov', 'pa': 0, 'cost': 0}, {'fn': 'stage_survie_foret', 'pa': 3, 'cost': 25}, {'fn': 'acheter_polonium_colonel', 'pa': 2, 'cost': 0}, {'fn': 'demander_fournisseur_kalachnikov', 'pa': 1, 'cost': 0}, {'fn': 'interroger_ganbaatar_polonium', 'pa': 0, 'cost': 0}, {'fn': 'acheter_spiritueux_local', 'pa': 0, 'cost': 0}, {'fn': 'produire_spiritueux', 'pa': 1, 'cost': 0}, {'fn': 'produire_sucre', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_goulag_corrompre', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_goulag_dormir', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_goulag_dortoir', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_goulag_entree', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_goulag_incidents', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_goulag_interroger', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_goulag_liste', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_goulag_manger', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_goulag_mirador', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_goulag_registre', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_goulag_sanction', 'pa': 1, 'cost': 0}, {'fn': 'diner_affaires', 'pa': 2, 'cost': 40}, {'fn': 'regulation_production', 'pa': 1, 'cost': 0}, {'fn': 'acces_reserve_info', 'pa': 0, 'cost': 0}, {'fn': 'clinique_dormir', 'pa': 0, 'cost': 0}, {'fn': 'clinique_reserver_nuit', 'pa': 0, 'cost': 0}, {'fn': 'commanditer_sondage', 'pa': 1, 'cost': 60}, {'fn': 'consulter_archives_ecoute', 'pa': 1, 'cost': 0}, {'fn': 'dormir', 'pa': 0, 'cost': 0}, {'fn': 'ecouter_guide_musee', 'pa': 0, 'cost': 0}, {'fn': 'enigme1_examiner_cadre', 'pa': 0, 'cost': 0}, {'fn': 'escort_standard', 'pa': 0, 'cost': 0}, {'fn': 'faire_don', 'pa': 0, 'cost': 0}, {'fn': 'ferme_vaches', 'pa': 1, 'cost': 0}, {'fn': 'marche_krasnov', 'pa': 0, 'cost': 0}, {'fn': 'inspecter_piece', 'pa': 1, 'cost': 0}, {'fn': 'se_cacher', 'pa': 1, 'cost': 0}, {'fn': 'heros_travail_classement', 'pa': 0, 'cost': 0}, {'fn': 'heros_travail_tableau', 'pa': 0, 'cost': 0}, {'fn': 'ilia_ecouter_guide', 'pa': 0, 'cost': 0}, {'fn': 'interieur_dossiers', 'pa': 0, 'cost': 0}, {'fn': 'kolkhoze_caisse', 'pa': 0, 'cost': 0}, {'fn': 'parti_boite_registre', 'pa': 0, 'cost': 0}, {'fn': 'parti_denoncer', 'pa': 1, 'cost': 0}, {'fn': 'pavillon_reception', 'pa': 0, 'cost': 0}, {'fn': 'pavillon_suite', 'pa': 0, 'cost': 0}, {'fn': 'propagande_etat', 'pa': 3, 'cost': 150}, {'fn': 'residence_location', 'pa': 0, 'cost': 0}, {'fn': 'residence_minibar', 'pa': 0, 'cost': 0}, {'fn': 'residence_reserver', 'pa': 0, 'cost': 0}, {'fn': 'service_etage_carte', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_goulag_gestion', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_graces', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_habilitations', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_manifs_gerer', 'pa': 0, 'cost': 0}, {'fn': 'tresor_donner_livre', 'pa': 0, 'cost': 0}, {'fn': 'tresor_ecouter_guide', 'pa': 0, 'cost': 0}, {'fn': 'tresor_repondre', 'pa': 0, 'cost': 0}, {'fn': 'enigme1_parler_valerie', 'pa': 0, 'cost': 0}, {'fn': 'changer_domicile', 'pa': 1, 'cost': 50}, {'fn': 'consulter_syndicat_etat', 'pa': 0, 'cost': 0}, {'fn': 'declencher_election_syndicat_etat', 'pa': 1, 'cost': 0}, {'fn': 'manifestation_soutien_president', 'pa': 0, 'cost': 0}, {'fn': 'quitter_syndicat_etat', 'pa': 0, 'cost': 0}, {'fn': 'se_syndiquer_etat', 'pa': 1, 'cost': 15}, {'fn': 'acheter_furet', 'pa': 0, 'cost': 0}, {'fn': 'boutique_discretion', 'pa': 0, 'cost': 0}, {'fn': 'voler', 'pa': 3, 'cost': 0}, {'fn': 'crocheter', 'pa': 3, 'cost': 0}, {'fn': 'forcer_porte', 'pa': 2, 'cost': 0}, {'fn': 'cambrioler', 'pa': 2, 'cost': 0}, {'fn': 'enqueter_plainte', 'pa': 2, 'cost': 0}, {'fn': 'acheter_graisse', 'pa': 0, 'cost': 0}, {'fn': 'boutique_climat', 'pa': 0, 'cost': 0}]
 if any(x not in source for x in ajouts_posterieurs_1011):
  raise ValueError('Ordre posterieur au 10/11 absent du catalogue')
 # #1020 : huit menus gratuits, postérieurs au plan historique ; validation exacte.
 noms_goulag=('goulag_autorisations_gerer','goulag_depart_pied','goulag_detenu_entree','goulag_refuge_nuit','goulag_refuge_terminer','goulag_visite_demander','goulag_visiteur_retour','goulag_voyager')
 ajouts_goulag=sorted((x for x in source if x['fn'] in noms_goulag),key=lambda x:x['fn'])
 if ajouts_goulag!=[{'fn':f,'pa':0,'cost':0} for f in noms_goulag]:
  raise ValueError('Ordres Goulag non conformes')
 source_historique=[x for x in source if x['fn'] not in ajouts_ssm+ajouts_manufactures and cle(x) not in {cle(t) for t in ajouts_terrains_psm} and x not in ajouts_petrochimie+ajouts_naval+ajouts_renseignement+ajouts_vehicules+ajouts_sovarka+ajouts_sovarka_reunions+ajouts_diner_sovarka+ajouts_sovarka_pouvoir+ajouts_sovarka_provinces+ajouts_posterieurs_1011+ajouts_goulag+[variante_supporters]]
 # Les deux virements bancaires sont désormais un sous-menu graphique (04/11) :
 # leurs anciens triplets sont maintenus dans la photographie d'origine,
 # et le menu gratuit 'virements' n'appartenait pas au plan 97.
 menu_virements=('virements',)
 if [x for x in source if x['fn'] in menu_virements]!=[{'fn':'virements','pa':0,'cost':0}]:
  raise ValueError('Menu Virements absent ou facture : un choix ne coute aucun PA')
 source_historique=[x for x in source_historique if x['fn'] not in menu_virements]
 # Ordres retirés depuis la coupe historique : restauration UNIQUEMENT pour
 # vérifier son empreinte d'origine, jamais dans le catalogue de jeu courant.
 retires=[{'fn':'assigner_mission','pa':1,'cost':0},
          {'fn':'fabriquer_armoire_souvenirs','pa':3,'cost':0},
          {'fn':'acheter_armoire_souvenirs','pa':0,'cost':0},
          {'fn':'virement_joueur','pa':1,'cost':0},
          {'fn':'virement_automatique','pa':1,'cost':0},
          {'fn':'consommer_buvette','pa':1,'cost':50}]  # retire par #682 (doublon de « Consulter la carte »)
 if any(x['fn'] in {r['fn'] for r in retires} for x in source):
  raise ValueError('Un ordre retiré ne doit plus figurer au catalogue actuel')
 source_historique=source_historique+retires
 # Criminalité lot 7 (20/11/2026) : « Falsifier un procès-verbal » et les trois accélérations par corruption retirées ; corrompre_fonct reste (directeur du QHS, 3 PA 1 500).
 retires_variantes=[{'fn':'corrompre_chantier','pa':2,'cost':1500},{'fn':'corrompre_fonct','pa':3,'cost':500},{'fn':'corrompre_fonct#reussite','pa':0,'cost':500},{'fn':'corrompre_fonctionnaire_permis','pa':2,'cost':800},{'fn':'corrompre_rdv_notaire','pa':2,'cost':800}]
 if any(x in source for x in retires_variantes):
  raise ValueError('Un tarif retiré ne doit plus figurer au catalogue actuel')
 source_historique=source_historique+retires_variantes
 # Criminalité, décisions du 20/11/2026 : « Obtenir du Polonium » retiré du port orphelin de Novomirsk (le marché noir le vend à 150 PSK, tarif serveur hors coupe).
 retires_polonium=[{'fn':'acheter_polonium','pa':2,'cost':600}]
 if any(x in source for x in retires_polonium):
  raise ValueError('Un tarif retiré ne doit plus figurer au catalogue actuel')
 source_historique=source_historique+retires_polonium
 # Refonte des informateurs (22/11/2026) : « Recruter un informateur » et les informateurs recrutés retirés ; « Acheter une information » ajouté.
 retires_informateurs=[{'fn':'recruter_informateur_pnj','pa':1,'cost':150},{'fn':'recruter_informateur_2','pa':1,'cost':400},{'fn':'recruter_info_4','pa':3,'cost':0},{'fn':'consulter_info_4','pa':1,'cost':0},{'fn':'gerer_informateurs','pa':0,'cost':0}]
 if any(x in source for x in retires_informateurs):
  raise ValueError('Un tarif retiré ne doit plus figurer au catalogue actuel')
 source_historique=source_historique+retires_informateurs
 # 16/11/2026 : récolte passée de 2 à 1 PA (régulation de la production) ; la photographie garde l'ancien tarif.
 source_historique=[{'fn':'recolter_matiere','pa':2,'cost':0} if x=={'fn':'recolter_matiere','pa':1,'cost':0} else x for x in source_historique]
 # 18/11/2026 : naturalisation passée à 2 PA + 50 (nationalité, domicile et élections) ; la coupe historique garde 2 PA sans frais.
 source_historique=[{'fn':'demander_naturalisation','pa':2,'cost':0} if x=={'fn':'demander_naturalisation','pa':2,'cost':50} else x for x in source_historique]
 # 23/11/2026 : rébellion passée à 1 PA (mission Novomirsk, point 12) ; la coupe historique garde 2 PA.
 source_historique=[{'fn':'se_rebeller','pa':2,'cost':0} if x=={'fn':'se_rebeller','pa':1,'cost':0} else x for x in source_historique]
 cmp=module('delta_recette97','outils/baseline/comparer-couts-captures.py')
 ts=sorted(cmp.triples(source_historique))
 md5=hashlib.md5('\n'.join('%s|%d|%d'%t for t in ts).encode()).hexdigest()
 triplets_actuels=sorted(cmp.triples(source))
 md5_actuel=hashlib.md5('\n'.join('%s|%d|%d'%t for t in triplets_actuels).encode()).hexdigest()
 rapport={'production_executee':False,'execution_autorisee':False,'migrations':es,'nombre':97,'tarifs_source':{'lignes':len(ts),'md5':md5},'tarifs_ajoutes_apres_plan97':hors_coupe,'tarifs_ajoutes_manufactures':hors_coupe_manufactures,'tarifs_ajoutes_petrochimie':ajouts_petrochimie,'tarifs_ajoutes_naval':ajouts_naval,'tarifs_ajoutes_renseignement':ajouts_renseignement,'tarifs_ajoutes_vehicules':ajouts_vehicules,'tarifs_ajoutes_sovarka':ajouts_sovarka,'tarifs_ajoutes_sovarka_reunions':ajouts_sovarka_reunions,'tarifs_ajoutes_diner_sovarka':ajouts_diner_sovarka,'tarifs_ajoutes_sovarka_pouvoir':ajouts_sovarka_pouvoir,'tarifs_ajoutes_sovarka_provinces':ajouts_sovarka_provinces+[variante_supporters],'tarifs_ajoutes_goulag':ajouts_goulag,'tarifs_actuels':{'lignes':len(triplets_actuels),'md5':md5_actuel},'ancien_plan_tarifaire_conforme_source':couts['apres']=={'lignes':len(ts),'md5':md5},'etapes':['valider paquet atomique et SHA indépendants','rendre et seeds depuis les exports ; comparer six racines, douze référentiels et locale','réconcilier le delta tarifaire complet ; régénérer le plan SQL et ses contrôles','95 : panne tardive + rollback, installation atomique, rejeu refusé sans mutation','recettes groupes/organisations puis #318 et #324 dans cet ordre, avec leurs gardes et reçus de registre','recette finale GoTrue/PostgREST : 27 cas, puis contre-épreuves et contrôles globaux'], 'limite':'Plan d’ordre et de provenance seulement ; aucun clone courant certifié ni migration exécutée.'}
 if paquet:
  editor=module('paquet_recette97','outils/livraison/export-sql-editor-219.py');paquet=Path(paquet).resolve()
  # Les sept octets originaux doivent être présents, pas une reconstruction manuelle.
  fs={e['fichier']:(paquet/e['fichier']).read_bytes() for e in editor.manifeste()['requetes']};ann=editor.lire_json((paquet/editor.MANIFESTE).read_bytes());docs,_=editor.verifier_documents(fs,ann)
  for e in ann['fichiers']:
   if len(fs[e['fichier']])!=e['octets'] or editor.h(fs[e['fichier']])!=e['sha256']:raise ValueError('Intégrité privée contraire au manifeste')
  rapport['registre_capture']=docs['empreinte']['registre'];rapport['delta_tarifaire_a_revoir']=cmp.comparer(source_historique,docs['referentiels']['ordres_couts'])
 return rapport
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--paquet',type=Path);a.add_argument('--sortie',type=Path,required=True);o=a.parse_args();sortie=o.sortie.resolve();relais=module('prive_plan97','outils/livraison/relais-canonique-219.py')
 if any(relais.marqueur_git_actif(p) for p in (sortie,*sortie.parents)):a.error('Plan privé hors Git requis')
 v=preparer(o.paquet);fd=os.open(sortie,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
 with os.fdopen(fd,'w') as f:json.dump(v,f,ensure_ascii=False,indent=2)
 print(json.dumps({k:v[k] for k in ('nombre','production_executee','execution_autorisee','tarifs_source','ancien_plan_tarifaire_conforme_source')}))
if __name__=='__main__':main()
