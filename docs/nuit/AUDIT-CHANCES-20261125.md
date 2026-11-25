# Audit de vérité des ordres à chance (mission de nuit 25/11/2026, point 4.2)

Lecture des définitions de production (lecture seule) comparées aux descriptions de `data.js`. **Aucune règle n'a été
changée** : chaque ligne est un écart que Fred tranchera. Colonnes : ordre, promesse, réalité du serveur, fichier.

## Partie 1

| Ordre | Promesse | Réalité serveur | Fichier |
|---|---|---|---|
| acheter_bombe_illegale « Subtiliser des explosifs » | (avant le bloc 3) 35 %, discrétion, ISN, réputation criminelle ; échec détecté : QHS | `militaire_subtiliser_tenter` : 50 + 2×(DUP−10) − (ISN−45)/3 + réputation (+5/+10/+15) + jet ; réussite ≥ 66 (35 % au neutre) ; ni DIS ni carrière ni Sovarka ni hommes armés ; DUP non annoncée ; détecté si score < 20 (≈ 19 %). Corrigé par le bloc 3 (migration 20261125120000, non appliquée). | baseline/domaines/militaire/20_fonctions-3.sql:120 |
| acheter_ghb « Acheter du GHB » | 80 %, « DIS/10 » | Aucun jet : `objet_acheter` vend à coup sûr (300 FR). | baseline/domaines/socle/20_fonctions.sql:1815 |
| acheter_vipere « Acheter une Vipère des sables » | 85 % | Aucun jet : `objet_acheter` vend à coup sûr. | idem |
| article « Placer un article favorable » | 75 % + modificateurs ; échec : refus sans frais | **Jet tiré dans le navigateur** : clamp(5, 95, 75 + 2×(CHA−13)) ; base 10 si un étouffement est actif ; 1 PA pris même en cas d'échec. | plateau-pnj.js:2650 |
| blocus_portuaire (Port-Sainte-Marie, El Estado) | 60 % / 65 %, VOL/10 + ENT/10, 3 PA | `blocus_syndical_organiser` : min(90, 10 + 6×participants + puissance/5) ; ni VOL ni ENT ; 2 PA par participant, au moins 2, réservé au dirigeant syndical. | migrations/20261102144753_blocus_syndical_participants_cout.sql:11 |
| bourrer_urnes « Bourrer les urnes » | 60 %, aucun modificateur ni conséquence annoncés | `fraude_electorale_tenter` : clamp(5, 95, 60 + (DIS−50)/5) ; échec : 1 jour de détention ; détectabilité croissante selon le rang de la fraude. | baseline/domaines/justice/20_fonctions-2.sql:245 |
| campagne_securite | 80 % | Aucun jet (réussite garantie) ; −3 POP non annoncé. | migrations/20261103094049_mairie_campagne_securite_transactionnelle.sql:3 |
| censurer_media | 70 % | Aucun jet de réussite ; scandale 30 % (0 % en Sovarka) −20 POP ; −8 IS appliqué par le navigateur. | migrations/20261103203000_inspection_cargaisons_jauges_serveur_379.sql:11 ; plateau-politique.js:9318 |
| consulter_dossiers_gouv | 80 % | Aucun jet ; dossier tiré par le navigateur. | idem ; plateau-politique.js:10073 |
| contester_resultats | 60 % | `election_contester` : clamp(5, 95, 60 + 5×(INT−13)) (INT non annoncée) ; fraude révélée seulement sur un second jet ; 2 PA et 200 payés dans tous les cas. | baseline/domaines/politique-et-elections/20_fonctions.sql:1069 |
| contrebande_port (Sovarka 35 %, El Estado 75 %, Al-Khalija 60 %) | DIS/10 + DUP/10 + bonus de pays | `crime_contrebande` : max(5, 55 + DIS/10 + DUP/10 + 15 caché + pays − ISN) (≈ 50 % de base en Sovarka), sans plafond (peut dépasser 100) ; un échec n'a aucune conséquence alors que l'écran dit « la douane a repéré » ; détection seulement après réussite. | baseline/domaines/justice/20_fonctions-1.sql:1115 |
| corrompre_douanier | 55 %, DUP/10 + INF/10, +20 % zone transport, échec non décrit | `crim_corrompre_pnj_interne` : conforme sur la base ; échec : 1 PA et 300 FR confisqués ; échec critique 2 % : dénonciation et peine ; une tentative par jour après un échec. | migrations/20261120050000_crim_lot7_corruption.sql:268 |
| corrompre_fonct « Corrompre le directeur » | 25 % | `crim_corruption_qhs_taux_interne` : clamp(5, 75, 30 + 2×(CHA−8) − (ISN−45)/3) − hommes armés ; base 30 ; échec +1 jour et 1500 confisqués ; réussite : peine divisée par deux. | migrations/20261120050000_crim_lot7_corruption.sql:79, :134 |
| corrompre_gardien | 20 % | même formule (base 30) ; échec : 800 confisqués ; une tentative par jour. | migrations/20261120050000_crim_lot7_corruption.sql:182 |
| corrompre_journaliste | 55 % | `corruption_presse_tenter` : clamp(5, 85, 30 + CHA + INF/4 − ISN) − hommes armés (≈ 43 % au neutre) ; **malus ISN fourni par le navigateur** ; échec critique 2 % non annoncé. | baseline/domaines/presse/20_fonctions.sql:285 |
| defense « Se défendre » | 65 % | `justice_defense_taux` : clamp(5, 80, 50 + 5×(CHA avocat−13) + 3×(CHA prévenu−13) − 35 si trace réelle) ; échec : peine de référence immédiate. | baseline/domaines/justice/20_fonctions-2.sql:1763 |
| demander_parler_loge | 95 % | Valeur conforme mais **jet tiré dans le navigateur**. | plateau-communication.js:1180 |

Conformes : centre_anti_poison (seul ajout : refus quand le centre n'a plus d'antidote), acheter_entreprise (« bientôt »).

## Partie 2

| Ordre | Promesse | Réalité serveur | Fichier |
|---|---|---|---|
| etouffer « Contrer une campagne de presse » | 70 % + modificateurs ; réussite : 1000 FR ; échec sans frais | **Jet tiré dans le navigateur** : clamp(5, 95, 70 + 2×(CHA−13)) ; 1000 FR et enregistrement décidés par le navigateur ; aucune détection pour un ordre illégal. | plateau-pnj.js:2650 |
| mobiliser « Mobiliser les membres » (siège syndical) | 70 % | **Mauvais routage** vers l'intervention de police du commissaire (`mobiliser_police`, sans jet) : refusé au syndicaliste. | plateau-router.js:921 ; migrations/20261103230000_pop_inf_presidence_gouvernement_379.sql:79 |
| emprunter | 70 %, « taux selon dossier » | Aucun jet : prêt accordé si les conditions sont remplies ; la banque privée passe encore par l'ancien chemin. | baseline/domaines/banque/20_fonctions.sql:1420 |
| escort_piege | 55 %, risque de scandale | `escort_piege_tenter` : min(80, 30 + 2×DUP − 1,5×DUP de la cible) (≈ 30-37 % au neutre) ; 3 PA et 800 FR payés même en échec ; enquête puis identification (−15 POP, −10 DIS). | baseline/domaines/personnage-et-presence/20_fonctions-1.sql:1463 |
| lancer_rumeur_cible | « Succès (75 %) » | `rumeur_lancer` / `crim_rumeur_taux_interne` : 60 + DIS + 2×(CHA−8) − dissuasion, 10-90 (60 % au neutre) ; échec critique 10 % des échecs (identifié, −5 POP, annonce) ; détection après réussite max(5, 15 − DIS/10). | migrations/20261120070000_crim_lot8_rumeurs.sql:36 |
| greffe_corrompre_dossier, greffe_corrompre_faux_casier | 75 % fixe ; découvert : le greffier vous dénonce | 75 − dissuasion ; dénonciation seulement sur échec critique (≈ 0,5 % des tentatives), sinon refus simple ; −5 DIS à la réussite. | baseline/domaines/justice/20_fonctions-2.sql:372, :453 |
| falsifier_document | 45 %, « faux casier vierge », échec : alerte possible | `crime_falsifier` : max(5, 45 − ISN) + dissuasion sur le jet ; échec sans conséquence (détection seulement après réussite) ; le faux casier n'existe pas côté serveur. | baseline/domaines/justice/20_fonctions-1.sql:1376 |
| falsifier_listes_electorales | 70 %, rien sur l'échec | 70 + (DIS−50)/5 ; **échec : 20 jours de prison** non annoncés ; scrutin municipal seulement, ville du mandat non vérifiée. | baseline/domaines/justice/20_fonctions-2.sql:245 |
| fabriquer_scandale | 35 + presse/min_info − malus | Formule conforme, mais **malus ISN fourni par le navigateur** ; coût débité hors transaction. | baseline/domaines/presse/20_fonctions.sql:1690 |
| marchander_vote | 50 % + (CHA+ENT)/2 | plafond 66 et +20 lobbyiste non annoncés. | baseline/domaines/assemblee/20_fonctions-2.sql:148 |
| inspecter_cargaisons | 80 %/90 %, INT/10 + ISN/10, Sovarka +25 %, min_def ou commissaire | 80 + INT/10 + 15 en Sovarka ; pas d'ISN ; min_def seul ; variante de Novomirsk probablement refusée (`port-sovarka` attendu). | migrations/20261103203000_inspection_cargaisons_jauges_serveur_379.sql:99 |
| ecouter_rumeurs (poissonnière de Novomirsk) | 95 % | Lieu inconnu du serveur : **toujours refusé**. | migrations/20261120070000_crim_lot8_rumeurs.sql:307 |
| fuite_info | 60 %, fuite d'un document | Hors Sovarka : taux fixe 60, aucun document ne fuite ; en Sovarka : aucun jet. | migrations/20261105013000_pays_du_poste_et_lieu_des_ordres.sql:208 |
| mener_enquete | 35 % ajusté | Formule conforme ; coût payé côté navigateur avant le jet ; sans trace, conclusion « infructueuse » sans serveur. | migrations/20261105110100_commissaire_jets_serveur.sql:18 |

Conformes : dementi, ecouter_rumeurs (hôtel, Capitaine Sauvage, Assemblée), interroger, interroger_renseignement.

## Partie 3

| Ordre | Promesse | Réalité serveur | Fichier |
|---|---|---|---|
| se_cacher | 70 % fixe sur le bouton | 70 + 5×⌊DIS/20⌋ + 15 ninja, plafond 98, −5 par membre (80 % au neutre) ; la fenêtre de confirmation affiche le vrai taux. **Le bouton affiche désormais la chance réelle (bloc 4).** | migrations/20261119130000_crim_lot1_equipement_dissimulation.sql:369 |
| incendier | max(5, 30 − ISN) affiché ; bidon « utilisé » | 30 + DIS + 10 caché + 15 carrière + 15 bidon − 15 orage + 15 canicule, 5-80 ; **l'ISN ne compte pas** ; bidon facultatif. | migrations/20261120010000_crim_lot5_poison_explosifs_incendie.sql:84 |
| crocheter | « ne laisse aucune trace » | une réussite crée une affaire et note une intrusion ; échec critique : kit détruit et propriétaire prévenu. | migrations/20261119220000_crim_lot4_cambriolage.sql:217 |
| tentative_evasion (QHS, prison) | 10 % ; échec : transfert / +7 jours | 10 + 2×(DUP−10) − (ISN−45)/3, 2-40 (bonus jusqu'à 90) ; échec : +1 jour (×2 Sovarka) et 500 FR. | migrations/20261103100000_detention_evasion_rebellion_serveur.sql:62 |
| se_rebeller | 30 % ; échec : QHS ; grilles endommagées dans tous les cas | min(60, 3×VOL + FOR du codétenu/2) ; échec : pas de QHS, grilles intactes, −15 DIS, +4 jours. | migrations/20261120030000_crim_lot6_justice.sql:488 |
| organiser_filature | 50 % fixe | formule PER/ISN/INF ; coût payé à part par le navigateur : relance gratuite possible. | migrations/20261105110100_commissaire_jets_serveur.sql:49 |
| truquer_depouillement | 75 %, échec non annoncé | 75 + (DIS−50)/5 ; échec : 20 jours de détention. | baseline/domaines/justice/20_fonctions-2.sql:245 |
| propagande_etat (variantes à 500) | 75 % | aucun jet ; −5 diplomatie ; payé par le ministère. | baseline/domaines/politique-et-elections/20_fonctions.sql:509 |
| soins_discrets | 95 %, +15 santé modulée par le moral | paliers : +15 dans ≈ 38 % des cas seulement ; pas de modulation par le moral. | migrations/20261105013000_pays_du_poste_et_lieu_des_ordres.sql:208 |
| voler_materiel_chantier | 0, mise en scène parodique, bonus de sympathie | vrai vol ≈ (50 + bonus) % ; indice social −1 à la réussite ; échec < 20 : avis de recherche. | baseline/domaines/justice/20_fonctions-1.sql:1733 |
| faire_disparaitre_cadavre, negocier_squatteurs, donner_argent_pnj | 0 % ou sans description | vraies chances serveur (DIS/CHA/ISN…) ; don : somme prise même en échec ; seuils « inspecteur/gardien » de la fenêtre inutilisés. | baseline/domaines/immobilier-et-territoire/*.sql ; migrations/20261104020000_squatteurs_don_serveur.sql:32 |
| visiter_prisonnier | 70 %, autorisation nécessaire | **aucun serveur, aucun jet, aucune autorisation** : toujours « visite effectuée ». | plateau-justice-economie.js:2195 |
| ouvrir_enquete | 90 % | conforme, mais 400 pris même en échec. | baseline/domaines/justice/20_fonctions-2.sql:128 |

Conformes : se_confesser, propagande_etat (Sovarka), utiliser_explosifs (omission : explosion prématurée = identifié sans masque), empoisonner, neutraliser, voler.
