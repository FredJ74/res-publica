#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tableaux d'arbitrage de l'etat initial de REPUBLIA (chantier 2E).

Deux tableaux, parce que deux questions differentes :

  TABLEAU 1  dotations-initiales-republia   -- l'argent et les matieres premieres
  TABLEAU 2  etat-initial-republia          -- les batiments, commerces, terrains

FRONTIERE ENTRE LES DEUX, explicite pour que rien ne tombe entre :
  - tableau 1 : caisses_batiments, budgets_nationaux, budgets_municipaux,
    budgets_clubs, et les stocks de matieres premieres (entrepots de ville,
    caserne, armurerie nationale) ;
  - tableau 2 : batiments_etat, entreprises, terrains_etat -- y compris les
    caisses qui vivent DANS leur blob, parce qu'elles font partie de l'etat
    initial du lieu et non d'une dotation institutionnelle.

CE QUE CES TABLEAUX NE FONT JAMAIS
  - proposer un montant deduit d'un solde de bêta ;
  - proposer un montant deduit du journal dotations_amorcage_caisses ;
  - inventer une categorie qui n'existe pas dans le modele reel.

La colonne `valeur_actuelle` est INFORMATIVE. Elle sert a reconnaitre un lieu,
pas a suggerer une reponse. Quand une valeur est IDENTIQUE sur les trois villes,
c'est dit : une valeur uniforme est un indice fort qu'elle est d'origine, une
valeur divergente est un indice fort qu'elle a derive en partie.

Usage :
    python3 outils/baseline/arbitrages.py --sql
    python3 outils/baseline/arbitrages.py --rendre <resultat.txt>

Ce module n'ecrit jamais dans la base. La requete qu'il imprime ne contient que
des SELECT.
"""

import csv
import json
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
CIBLE = os.path.join(RACINE, "baseline", "arbitrages")

PAYS = "republic"
VILLES = {"capitale": "Luthecia", "ville_a": "Port-Sainte-Marie", "ville_b": "Montrouge"}

# Valeurs DEJA ARBITREES par le game designer. Elles sont preremplies ; tout le
# reste est laisse vide. Aucune autre valeur n'est proposee.
REMARQUE_ENTREPOT = (
    "LA CAISSE A DEMENAGE LE 8 OCTOBRE 2026, ET LE MONTANT ARBITRE NE CHANGE PAS. L'audit du 5 "
    "octobre avait tranche que la tresorerie de l'entrepot vivait dans le blob de batiments_etat, "
    "et que le motif `entrepot` de caisses_autorites etait INERTE faute d'appelant. Les deux "
    "constats etaient justes a cette date ; le chantier des budgets municipaux les a rendus faux. "
    "La tresorerie est desormais une VRAIE caisse, caisses_batiments.<pays>_entrepot_<ville>, "
    "pilotable par les primitives verrouillees, journalisee, et beneficiaire declare de 40 % des "
    "recettes municipales du jour. Le motif `entrepot` (directeur_entrepot, maire_adjoint) est "
    "devenu vivant. DOTATION D'AMORCAGE DE 5 000 FR, inchangee depuis l'arbitrage du 5 octobre "
    "2026 : les entrepots amorcent la chaine economique, qui prend ensuite le relais. C'est aussi "
    "le fonds de roulement que entrepot_reverser conserve (c_roulement), ce qui rend les deux "
    "chiffres coherents par construction.")

DECIDE = {
    # Dotations CANONIQUES D'AMORCAGE, arbitrees le 5 octobre 2026. Ce ne sont pas
    # des budgets durables : ensuite, l'economie produit les recettes publiques et
    # la repartition nationale nocturne les distribue.
    ("Ministeres", "republic_gouvernement-min_def"): ("35000",
        "ARBITRE. Exception volontaire : un monde neuf n'a ni compagnie ni section, "
        "la creation d'une compagnie coute 20 000 FR, et le ministre doit pouvoir "
        "amorcer l'armee. Il transfere ensuite lui-meme vers la caserne, via "
        "caserne_virement_journalier_fixer()."),
    ("Ministeres", "republic_gouvernement-min_ae"): ("10000", "ARBITRE."),
    ("Ministeres", "republic_gouvernement-min_fin"): ("10000",
        "ARBITRE. A noter : cette caisse n'est PAS le guichet des recettes "
        "publiques. La repartition nocturne ne lui verse que sa part (6 % par "
        "defaut), comme a chaque autre poste. Voir AUDIT-FISCAL.md."),
    ("Ministeres", "republic_gouvernement-min_info"): ("10000", "ARBITRE."),
    ("Ministeres", "republic_gouvernement-min_int"): ("10000", "ARBITRE."),
    ("Ministeres", "republic_gouvernement-min_just"): ("10000", "ARBITRE."),
    ("Ministeres", "republic_gouvernement-pm"): ("10000",
        "ARBITRE, sur la caisse CANONIQUE du Premier ministre. L'inspection a "
        "tranche : gouvernement-pm est la caisse reelle -- elle recoit la part `pm` "
        "de la repartition nocturne et c'est elle que la piece `bureaux` du palais "
        "du gouvernement affiche. palais-gouvernement est un vestige."),
    ("Etat national", "republic_palais-presidentiel"): ("10000", "ARBITRE."),
    ("Etat national", "republic_assemblee"): ("5000",
        "ARBITRE. A rapprocher des faits de l'audit : l'Assemblee recoit 8 % de la "
        "repartition nocturne, soit environ 1 968 FR/jour avec la cle actuelle, et "
        "depense jusqu'a 2 250 FR/jour si les 9 sieges sont tenus par des PJ qui "
        "reclament tous leur indemnite de 250 FR. La dotation couvre donc environ "
        "deux jours de deficit maximal. Si la caisse se vide, le versement devient "
        "partiel ou nul, sans erreur ni dette : le mecanisme ne casse pas."),
    ("Agence privee", "republic_agence-grobras-securite"): ("0",
        "ARBITRE A ZERO, et c'est une decision, pas un defaut : Grobras ne vend que "
        "de la prestation de service. Aucun stock, aucune matiere premiere a "
        "financer pour demarrer. Sa tresorerie doit venir de son activite."),
    ("Municipalites", "republic_mairie-capitale"): ("5000", None),
    ("Municipalites", "republic_mairie_ville_a"): ("5000", None),
    ("Municipalites", "republic_mairie_ville_b"): ("5000", None),
    # LA CAISSE D'ENTREPOT A DEMENAGE LE 8 OCTOBRE 2026, et le montant arbitre ne
    # change pas. L'adresse etait un volet de blob -- batiments_etat.data.entrepot.caisse,
    # d'ou la forme « <ville>/<batiment>#entrepot » -- elle est maintenant une vraie
    # caisse de caisses_batiments. Le « # » excluait d'ailleurs ces lignes du seed :
    # seeds.py ne retient que les identifiants sans « # » ni « . ».
    ("Entrepots", "republic_entrepot_capitale"): ("5000", REMARQUE_ENTREPOT),
    ("Entrepots", "republic_entrepot_ville_a"): ("5000", REMARQUE_ENTREPOT),
    ("Entrepots", "republic_entrepot_ville_b"): ("5000", REMARQUE_ENTREPOT),
}

# Montant complementaire attache a certaines cles de DECIDE : quand la remarque
# vaut None, celle de l'analyse est conservee et ce texte-ci est ajoute.
JUSTIFICATION_5000 = (
    " DOTATION D'AMORCAGE DE 5 000 FR, arbitree le 5 octobre 2026. Les mairies "
    "financent desormais les equipements municipaux (regle canonique de financement "
    "territorial) : elles doivent pouvoir amorcer leur premiere distribution. Les "
    "entrepots amorcent la chaine economique, qui prend ensuite le relais. Meme "
    "montant que l'Assemblee, pour une raison identique : couvrir le demarrage, pas "
    "rendre autonome.")

# --- 2. REGLE CANONIQUE pour les caisses d'equipement restantes.
# Plutot que de faire arbitrer 43 lignes une par une, une seule regle : le
# PLANCHER D'AMORCAGE. Ce n'est pas un montant invente -- c'est exactement celui
# que le projet s'est lui-meme donne le 11 septembre 2026, quand l'amorcage a
# porte 103 caisses a 200 FR. Une caisse d'equipement n'a pas besoin de reserve :
# elle existe, et son circuit l'alimente des la premiere nuit ou la premiere
# distribution municipale.
PLANCHER_AMORCAGE = "200"
JUSTIFICATION_PLANCHER = (
    "PLANCHER D'AMORCAGE DE 200 FR, regle canonique appliquee le 5 octobre 2026. Ce "
    "n'est pas un montant invente : c'est celui que le projet s'est donne le 11 "
    "septembre 2026, quand le journal d'amorcage a porte 103 caisses a exactement "
    "200 FR. Une caisse d'equipement n'a pas besoin d'une reserve : il lui faut "
    "exister et ne pas etre a zero le premier jour. Son circuit l'alimente ensuite "
    "-- repartition nocturne, distribution municipale, ou sa propre activite.")

# ARBITRAGE DU 8 OCTOBRE 2026, et il ne concerne QUE quatre familles. Il serait faux
# de l'ajouter au plancher generique ci-dessus : le commissariat est lui aussi dote au
# plancher, et il recoit bel et bien 40 % de la repartition municipale. Seules les
# caisses de ces quatre equipements portent cette note.
EQUIPEMENTS_SANS_RECURRENT = ("multinodal", "multimodal", "stade", "marche", "dispensaire")
ARBITRAGE_SANS_RECURRENT = (
    " ARBITRAGE DU 8 OCTOBRE 2026 -- DOTATION DE DEPART, PUIS AUCUN FINANCEMENT MUNICIPAL "
    "RECURRENT. Le centre multimodal, le stade, le marche et le dispensaire recoivent cette "
    "dotation a l'initialisation du monde, et rien ensuite : ils doivent s'autofinancer par "
    "leurs propres recettes et mecaniques. La repartition municipale automatique ne connait "
    "que trois beneficiaires -- commissariat 40 %, entrepot municipal 40 %, mairie 20 % -- et "
    "le maire n'a AUCUNE obligation de financement recurrent envers ces quatre equipements. Un "
    "virement ponctuel depuis la mairie, quand une mecanique generique existante l'autorise, "
    "reste DISTINCT de leur financement structurel.")

# Familles dont la consequence de jeu est REELLEMENT differente : elles ne
# recoivent pas le plancher, et aucun montant n'est invente a leur place.
FAMILLES_ISOLEES = {
    "Clubs sportifs": (
        "CATEGORIE ISOLEE, aucun montant propose. Le plancher de 200 FR serait ici "
        "trompeur : un club paie 100 FR par titulaire, 50 par remplacant et 150 de "
        "prime de victoire, donc 200 FR ne couvrent pas une rencontre. Et l'audit a "
        "etabli que la subvention municipale aux clubs est BRANCHEE SUR UNE CLE "
        "INEXISTANTE (allocation.associatif, alors que `associatif` vit dans "
        "data.indices) : son montant est toujours 0. Un club n'a donc AUCUNE recette "
        "automatique aujourd'hui. Fixer 200 FR reviendrait a creer trois clubs "
        "insolvables des la premiere journee de championnat. C'est une vraie decision "
        "de jeu, pas un montant de remplissage."),
}

# Dotations initiales de matieres premieres, ARBITREES le 5 octobre 2026.
# Meme quantite dans chacune des TROIS villes de Republia. Treize de ces valeurs
# etaient deja identiques sur les trois entrepots et sont confirmees telles
# quelles ; les quatre autres -- tabac, viande, cereales, medicaments -- avaient
# derive differemment selon la ville et recoivent ici une valeur de reference.
# AUCUNE n'est deduite d'un stock de bêta.
MATIERES_ARBITREES = {
    "bois": 750, "minerai": 500, "charbon": 400, "plantes": 300,
    "metal": 200, "petrole": 200, "fruits_legumes": 150, "poisson": 125,
    "textile": 125, "produits_exotiques": 125, "alcool": 100, "viande": 85,
    "cereales": 75, "desinfectant": 32, "tabac": 30, "medicaments": 25,
    "carburant": 17,
}

# Lignes de bêta a ne jamais presenter comme un element du monde initial.
def est_artefact(cle):
    return bool(re.search(r"(^|[^a-z])zz|zztest|17[0-9]{11}", cle or ""))


def est_de_test(cle):
    """Marqueur de TEST seulement -- pas un horodatage. Un identifiant engendre
    en partie (epoch a 13 chiffres) n'est pas une ligne de test : c'est du
    contenu cree par un joueur, et il doit etre SIGNALE, pas ecarte."""
    return bool(re.search(r"(^|[^a-z])zz|zztest", cle or ""))


# Tout ce que les tableaux ecartent est collecte ici et imprime en fin de
# document. Une ligne ecartee en silence serait une ligne perdue.
ECARTEES = []
MANQUANTES = []


def ecarter(ou, quoi, pourquoi):
    ECARTEES.append((ou, quoi, pourquoi))


REQUETE = """
with
caisses as (
  select replace(id, '{pays}_', '') as batiment, (data->>'solde')::numeric as solde
  from public.caisses_batiments where id like '{pays}\\_%'),
nationaux as (select data from public.budgets_nationaux where id = '{pays}'),
municipaux as (
  select replace(id, '{pays}_', '') as cle, data from public.budgets_municipaux
  where id like '{pays}\\_%'),
clubs as (
  select c.id, c.nom, c.ville, b.data as budget
  from public.clubs_football c
  left join public.budgets_clubs b on b.id = c.id
  where c.pays = '{pays}'),
entrepots as (
  select city as ville, building_id as batiment, (data #>> '{{}}')::jsonb -> 'entrepot' as bloc
  from public.batiments_etat
  where country = '{pays}' and building_id like 'entrepot-logistique%'),
batiments as (
  select city as ville, building_id as batiment, (data #>> '{{}}')::jsonb as bloc
  from public.batiments_etat
  where country = '{pays}' and city in ('capitale','ville_a','ville_b')),
commerces as (
  select id, data->>'city' as ville, data->>'type' as type_commerce,
         data->>'buildingId' as batiment, data->>'roomId' as piece,
         data->>'enseigne' as enseigne, data->>'proprietaire' as proprietaire,
         data->>'statut' as statut, (data->>'caisse')::numeric as caisse,
         data->'stockMatieres' as stock_matieres, data->'stockProduits' as stock_produits,
         data->'stockReferences' as stock_references, data->'carte' as carte,
         data->'parametres' as parametres
  from public.entreprises),
terrains as (
  select building_id as batiment, (data::jsonb) as bloc, proprietaire, valeur_totale,
         niveau_construction, coproprietaire
  from public.terrains_etat where country = '{pays}'),
amorcage as (
  select stockage, cle from public.dotations_amorcage_caisses where pays = '{pays}')
select jsonb_build_object(
  'caisses', (select jsonb_agg(jsonb_build_object('batiment', batiment, 'solde', solde)
     order by batiment) from caisses),
  'national', (select data from nationaux),
  'municipaux', (select jsonb_agg(jsonb_build_object('cle', cle, 'data', data) order by cle)
     from municipaux),
  'clubs', (select jsonb_agg(jsonb_build_object('id', id, 'nom', nom, 'ville', ville,
     'budget', budget) order by id) from clubs),
  'entrepots', (select jsonb_agg(jsonb_build_object('ville', ville, 'batiment', batiment,
     'bloc', bloc) order by ville) from entrepots),
  'batiments', (select jsonb_agg(jsonb_build_object('ville', ville, 'batiment', batiment,
     'bloc', bloc) order by ville, batiment) from batiments),
  'commerces', (select jsonb_agg(to_jsonb(c) order by c.ville, c.id) from commerces c),
  'terrains', (select jsonb_agg(to_jsonb(t) order by t.batiment) from terrains t),
  'amorcage', (select jsonb_agg(jsonb_build_object('stockage', stockage, 'cle', cle)
     order by stockage, cle) from amorcage),
  'controle', jsonb_build_object(
     'caisses', (select count(*) from caisses),
     'municipaux', (select count(*) from municipaux),
     'clubs', (select count(*) from clubs),
     'entrepots', (select count(*) from entrepots),
     'batiments', (select count(*) from batiments),
     'commerces', (select count(*) from commerces),
     'terrains', (select count(*) from terrains),
     'amorcage', (select count(*) from amorcage))
) as export_arbitrages
"""

# -------------------------------------------------------------- nomenclature
# Role concret de chaque caisse, deduit de caisses_autorites (motif -> postes
# autorises a debiter) et des noms de batiment. Aucune categorie inventee : si
# un motif n'est pas reconnu, la ligne sort en « a qualifier » plutot qu'en
# categorie fausse.
MOTIFS = [
    (r"^gouvernement-(min_\w+|pm)$", "ministere", "Caisse d'un ministere. Le poste est lu dans l'identifiant."),
    (r"^caserne-militaire$", "militaire", "Caisse de la caserne. Debitee par le Commandant et le ministre de la Defense."),
    (r"^palais-presidentiel$", "presidence", "Caisse de la Presidence."),
    (r"^palais-gouvernement$", "gouvernement", "Caisse du siege du Premier ministre."),
    (r"^assemblee$", "assemblee", "Caisse de l'Assemblee, par chemin serveur dedie."),
    (r"^reserve-nationale$", "reserve", "Reserve nationale, debitee par le ministre des Finances."),
    (r"^mairie[-_]", "municipal", "Caisse d'une mairie. Debitee par le maire et son adjoint."),
    (r"^commissariat", "police", "Caisse d'un commissariat."),
    (r"^tribunal", "justice", "Caisse d'un tribunal."),
    (r"^qhs-prison$", "justice", "Caisse du quartier de haute securite."),
    (r"^dispensaire", "sante", "Caisse d'un dispensaire."),
    (r"^hotel[-_]", "hotellerie", "Caisse d'un hotel."),
    (r"^marche", "commerce public", "Caisse d'un marche."),
    (r"^stade", "sport", "Caisse d'un stade ou de sa buvette."),
    (r"^centre-multinodal", "transport", "Caisse d'un centre multimodal."),
    (r"^port-sainte-marie$", "port", "Caisse de la capitainerie du port industriel."),
    (r"^(eglise|notre-dame|tabernacle)", "culte", "Caisse d'un lieu de culte ou de collecte."),
    (r"^office-notarial$", "notariat", "Caisse de l'office notarial."),
    (r"^banque-privee$", "banque", "Caisse de la banque privee."),
    (r"^agence-", "agence privee", "Caisse d'une agence privee, reservee au serveur."),
]


def qualifier(batiment):
    for motif, categorie, role in MOTIFS:
        if re.match(motif, batiment):
            return categorie, role
    return "a qualifier", "Role non reconnu par la nomenclature. A examiner avant d'arbitrer."


# Ville d'une caisse dont le nom ne la porte pas. Etablie en lisant les listes
# `buildings` de data.js, ville par ville -- jamais devinee sur le nom. Une
# premiere version placait « notre-dame-mer » a Montrouge a cause du mot
# « mer » : data.js la declare a Port-Sainte-Marie.
VILLE_EXPLICITE = {
    "notre-dame-mer": "ville_a", "eglise-montrouge": "ville_b",
    "tabernacle-impots": "capitale", "office-notarial": "capitale",
    "palais-gouvernement": "capitale", "stade-buvette": "capitale",
    "commissariat": "capitale", "tribunal": "capitale",
    "dispensaire-public": "capitale", "marche": "capitale",
}


def ville_de(batiment):
    for suffixe, nom in (("_capitale", "capitale"), ("_ville_a", "ville_a"),
                         ("_ville_b", "ville_b"), ("-capitale", "capitale")):
        if batiment.endswith(suffixe):
            return nom
    if batiment in VILLE_EXPLICITE:
        return VILLE_EXPLICITE[batiment]
    if "luthecia" in batiment:
        return "capitale"
    if "psm" in batiment or "port-sainte-marie" in batiment:
        return "ville_a"
    if "montrouge" in batiment:
        return "ville_b"
    return ""



# ---------------------------------------------------------------------------
# SOUS-TABLEAU FINANCIER. Une entree par caisse REELLE du schema. Rien n'est
# invente : chaque cle ci-dessous est un identifiant releve en base. Le champ
# `doter` dit ce que l'observation permet de conclure -- et quand elle ne permet
# pas de conclure, elle le dit aussi plutot que de reclamer un montant.
#
#   oui      : dotation initiale a arbitrer
#   non      : ne doit pas recevoir de dotation independante -- raison donnee
#   vestige  : ligne heritee d'avant la dimension ville, solde 0, a ne pas doter
#   ambigu   : la question est mal posee tant qu'une ambiguite n'est pas levee
# ---------------------------------------------------------------------------
FAMILLES = ["Etat national", "Ministeres", "Militaire", "Municipalites", "Police",
            "Justice", "Sante", "Commerce public", "Sport", "Transport",
            "Hotellerie", "Culte", "Port", "Notariat", "Banque", "Agence privee",
            "Entrepots", "Industrie", "Presse", "Clubs sportifs", "A qualifier"]

# nom de caisse -> (famille, nom lisible, a quoi ca sert, doter, remarque)
ROLES = {
 'agence-grobras-securite': ('Agence privee', 'Agence Grobras Securite',
   "Caisse d'une agence privee de securite, qui emploie et paie des gardes.",
   'oui',
   "CAISSE D'UNE ENTREPRISE PRIVEE, reservee au serveur : aucun poste public"
      "nepeut la debiter (motif `agence-`, postes_debit vide). L'agence paie"
      'pourtantses gardes via employeur_embaucher. La dotation est donc un vrai'
      "choix dejeu : l'agence ouvre-t-elle avec un fonds de roulement, ou a 0 en"
      'attendantses premiers clients ?'),
 'banque-privee': ('Banque', 'Banque privee',
   'Caisse de contrepartie de la banque Helvetia : les depots, retraits, pretset'
      'placements des joueurs y passent (deposer_helvetia,'
      'creer_pret_helvetia,helvetia_assurer_liquidite).',
   'non',
   'CAISSE DE CONTREPARTIE, pas un budget : deposer_helvetia calcule'
      "sonidentifiant par `pays || '_banque-privee'`, elle sert donc de"
      'contrepartieNATIONALE aux depots, retraits, prets et placements des joueurs,'
      'et sonsolde en est le miroir. NE PAS DOTER.'),
 'marche': ('Commerce public', 'Marche -- caisse non suffixee',
   'Caisse de marche sous un identifiant de batiment partage par deux villes.',
   'non',
   "VESTIGE DATE, tranche par l'audit. Jusqu'au 16 aout"
      "2026,getBuildingIdPourCategorieBudget() renvoyait l'identifiant de"
      'navigation TELQUEL -- le commentaire du correctif le dit : « un buildingId'
      'de navigationpartage entre plusieurs villes, fusionnant leurs caisses ».'
      'Depuis le lot «A3, caisses locales », la convention canonique'
      'estgetCaisseLocaleId(categorie, ville) = `categorie_ville`. Cette ligne'
      "estl'etat d'AVANT le correctif, elle est a 0, et aucun appelant ne"
      "l'adresseplus. NE PAS DOTER."),
 'marche_capitale': ('Commerce public', 'Marche de Luthecia',
   'Caisse du marche municipal.',
   'oui',
   "CAISSE ACTIVE DU LIEU MUNICIPAL, tranche par l'audit. Ce n'est PAS unedouble"
      "comptabilite avec l'entreprise `marche-republic-capitale-marche` : lacaisse"
      "du lieu est alimentee par l'activite du marche,l'entreprise"
      'est le fonds de commerce des etals. Deux fonctions economiquesdistinctes,'
      'deux caisses legitimes.'),
 'marche_ville_b': ('Commerce public', 'Marche de Montrouge',
   'Caisse du marche municipal.',
   'oui',
   "CAISSE ACTIVE DU LIEU MUNICIPAL : meme lecture qu'a Luthecia."),
 'marche_ville_a': ('Commerce public', 'Marche de Port-Sainte-Marie',
   'Caisse du marche municipal.',
   'oui',
   "CAISSE ACTIVE DU LIEU MUNICIPAL : meme lecture qu'a Luthecia."),
 'eglise-montrouge': ('Culte', 'Eglise de Montrouge',
   'Caisse du lieu de culte, alimentee par les dons des fideles.',
   'non',
   "CAISSE INERTE, tranche par l'audit : AUCUN appel, nulle part, ne credite"
      'nine debite cette caisse -- ni fonction serveur, ni client, ni cron.'
      'Lecircuit de piete existe bien, mais il passe par le'
      "ledgercontributions_piete, d'ou l'indice de piete est DERIVE : il ne"
      "transite paraucune caisse. Doter une caisse qu'aucun mecanisme ne touche"
      "n'aurait aucuneffet dans le jeu. NE PAS DOTER."),
 'notre-dame-mer': ('Culte', 'Notre-Dame-de-la-Mer (Port-Sainte-Marie)',
   'Caisse du lieu de culte.',
   'non',
   "CAISSE INERTE : meme constat que l'eglise de Montrouge. Le lieu est"
      "bienjouable (PNJ, rue centrale, actions), mais sa caisse n'est touchee par"
      'rien.NE PAS DOTER.'),
 'tabernacle-impots': ('Culte', 'Tabernacle des impots',
   "Caisse d'un lieu de collecte.",
   'non',
   'CAISSE INERTE : meme constat. Le lieu existe et se joue, sa caisse'
      "n'esttouchee par rien, et malgre son nom aucun flux fiscal ne l'atteint. NE"
      'PASDOTER.'),
 'assemblee': ('Etat national', 'Assemblee nationale',
   "Caisse de l'Assemblee. Elle paie notamment les indemnites de depute."
      "Ellen'est debitee par aucun poste directement : un chemin serveur dedie"
      "s'encharge (assemblee_debiter_caisse_plafonne, assemblee_crediter_caisse).",
   'oui',
   'CAISSE ACTIVE, dotation NON ENCORE ARBITREE a votre demande. Alimentation'
      ':part `assemblee` de la repartition nocturne, 8 % par defaut,'
      'plusassemblee_marchander. Depense automatique : indemnite de 250 FR par'
      'deputePJ et par jour, versee a la demande du depute, une seule fois par'
      'jour, etPLAFONNEE PAR LA CAISSE -- si elle est insuffisante le versement est'
      'partielou nul, enregistre tel quel dans assemblee_indemnites, sans erreur ni'
      'dette.Voir AUDIT-FISCAL.md.'),
 'palais-gouvernement': ('Etat national', 'Premier ministre -- siege du gouvernement',
   'Caisse du siege du Premier ministre. Seul le PM la debite.',
   'non',
   "VESTIGE, tranche par l'audit. Le palais du gouvernement est un BATIMENT"
      'dontchaque piece porte la caisse de son ministere'
      '(ROOMS_AVEC_CAISSE_SPECIFIQUE: `bureaux` -> gouvernement-pm,'
      "`bureau_min_def` ->gouvernement-min_def...). Le batiment lui-meme n'est PAS"
      'dansROOMS_AVEC_CAISSE ; aucune fonction serveur, aucun appel client et'
      'aucuncron ne credite ou debite cette caisse ; la repartition nationale ne'
      'laconnait pas. La caisse canonique du Premier ministre est gouvernement-pm.'
      'NEPAS DOTER.'),
 'palais-presidentiel': ('Etat national', 'Presidence -- Palais presidentiel',
   'Caisse de la Presidence. Seul le President la debite.',
   'oui',
   ''),
 'reserve-nationale': ('Etat national', 'Reserve nationale',
   "Reserve monetaire de l'Etat. Seul le ministre des Finances la debite.",
   'oui',
   'CAISSE ACTIVE : elle recoit la part `reserve` de la repartition'
      'nationalenocturne, 2 % par defaut.'),
 'hotel_capitale': ('Hotellerie', 'Hotel de Luthecia',
   "Caisse de l'hotel. L'hotel accorde un bonus de PA (pa_bonus_hotel).",
   'oui',
   "CAISSE ACTIVE, tranche par l'audit : creditee via"
      "getCaisseLocaleId('hotel',ville), donc dans la convention canonique"
      "`categorie_ville`. L'amorcage du11 septembre ne l'a pas dotee alors qu'il a"
      'dote celles de Port-Sainte-Marieet Montrouge : asymetrie a signaler, pas un'
      'motif pour ne pas la doter.'),
 'hotel_ville_b': ('Hotellerie', 'Hotel de Montrouge',
   "Caisse de l'hotel.",
   'oui',
   "CAISSE ACTIVE, creditee via getCaisseLocaleId('hotel', ville). Encore a 200."),
 'hotel_ville_a': ('Hotellerie', 'Hotel de Port-Sainte-Marie',
   "Caisse de l'hotel.",
   'oui',
   "CAISSE ACTIVE, creditee via getCaisseLocaleId('hotel', ville)."),
 'qhs-prison': ('Justice', 'Quartier de haute securite',
   "Caisse du QHS. Debitee par les ministres de l'Interieur et de la Justice.",
   'oui',
   'Encore a 200 : jamais utilisee en bêta, et aucune part dans la'
      'repartitionnocturne.'),
 'tribunal_capitale': ('Justice', 'Tribunal de Luthecia',
   'Caisse du tribunal. Debitee par le juge et le ministre de la Justice.',
   'oui',
   ''),
 'tribunal': ('Justice', 'Tribunal de Luthecia -- caisse non suffixee',
   'Caisse du tribunal de Luthecia, sous son identifiant de batiment brut.',
   'non',
   "VESTIGE DATE, tranche par l'audit. Jusqu'au 16 aout"
      "2026,getBuildingIdPourCategorieBudget() renvoyait l'identifiant de"
      'navigation TELQUEL -- le commentaire du correctif le dit : « un buildingId'
      'de navigationpartage entre plusieurs villes, fusionnant leurs caisses ».'
      'Depuis le lot «A3, caisses locales », la convention canonique'
      'estgetCaisseLocaleId(categorie, ville) = `categorie_ville`. Cette ligne'
      "estl'etat d'AVANT le correctif, elle est a 0, et aucun appelant ne"
      "l'adresseplus. NE PAS DOTER."),
 'tribunal_ville_b': ('Justice', 'Tribunal de Montrouge',
   'Caisse du tribunal. Debitee par le juge et le ministre de la Justice.',
   'oui',
   ''),
 'tribunal_ville_a': ('Justice', 'Tribunal de Port-Sainte-Marie',
   'Caisse du tribunal. Debitee par le juge et le ministre de la Justice.',
   'oui',
   ''),
 'tribunal-local': ('Justice', 'Tribunal local -- caisse non suffixee',
   'Caisse de tribunal sous un identifiant de batiment partage par deux villes.',
   'non',
   "VESTIGE DATE, tranche par l'audit. Jusqu'au 16 aout"
      "2026,getBuildingIdPourCategorieBudget() renvoyait l'identifiant de"
      'navigation TELQUEL -- le commentaire du correctif le dit : « un buildingId'
      'de navigationpartage entre plusieurs villes, fusionnant leurs caisses ».'
      'Depuis le lot «A3, caisses locales », la convention canonique'
      'estgetCaisseLocaleId(categorie, ville) = `categorie_ville`. Cette ligne'
      "estl'etat d'AVANT le correctif, elle est a 0, et aucun appelant ne"
      "l'adresseplus. NE PAS DOTER."),
 'mairie_caserne': ('Militaire', 'Caserne -- caisse « mairie »',
   'Caisse portant le prefixe mairie, donc debitable par un maire et sonadjoint,'
      'mais rattachee a la caserne.',
   'non',
   "ARTEFACT TECHNIQUE, tranche par l'audit. La caserne est une ZONE"
      'SPECIALE,declaree isSpecial dans data.js et explicitement exclue des villes'
      'reellespar getVillesReelles() -- « hors zones speciales caserne/qhs ».'
      'MaisgetVilleKey() lit state.currentCity sans filtrer, et'
      "plateau-politique.js yecrit 'caserne' : un joueur present a la caserne a"
      "donc fait naitre une clemunicipale pour un lieu qui n'est pas une ville."
      'Meme origine que la 4eligne republic_caserne de budgets_municipaux. NE PAS'
      'DOTER.'),
 'caserne-militaire': ('Militaire', 'Caserne militaire',
   'Caisse de la caserne. Elle paie les soldes, le ravitaillement'
      "etl'equipement. Debitee par le Commandant et par le ministre de la Defense.",
   'non',
   "ALIMENTEE PAR UNE AUTRE CAISSE, confirme par l'audit"
      ':virementCaserneServeur() vire chaque nuit `virementJournalierCaserne`'
      'depuisgouvernement-min_def vers cette caisse, montant fixe par le ministre'
      "de laDefense, DEFAUT 0 -- « un ministre qui n'y touche pas ne finance rien,"
      "etc'est voulu ». Conforme a votre arbitrage. 0 au premier jour."),
 'mairie-capitale': ('Municipalites', 'Mairie de Luthecia',
   'Caisse municipale. Debitee par le maire et son adjoint.',
   'oui',
   "CAISSE PROPRE DU MAIRE, tranche par l'audit : ce n'est PAS un doublon du"
      "compte de collecte budgets_municipaux, c'est l'etape AVAL d'un autre"
      'circuit. Le compte de collecte recoit les recettes LOCALES et les'
      'redistribue ; cette caisse-ci recoit une part de la'
      'repartition NATIONALE nocturne. Elle recoit 12 % par defaut (part `mairie`).'
      'ASYMETRIE A SIGNALER : la table de repartition nationale'
      '(CAISSE_PAR_POSTE_BUDGET_SERVEUR) ne connait que `mairie-capitale`.'
      'Port-Sainte-Marie et Montrouge ne recoivent donc RIEN de la repartition'
      'nationale, ni leurs mairies, ni leurs tribunaux, ni leurs commissariats.'
      "Seule Luthecia est servie. Cela ne bloque pas la dotation, mais c'est une"
      'vraie question de jeu.'),
 'mairie_ville_b': ('Municipalites', 'Mairie de Montrouge',
   'Caisse municipale. Debitee par le maire et son adjoint.',
   'oui',
   "CAISSE PROPRE DU MAIRE, tranche par l'audit : ce n'est PAS un doublon du"
      "compte de collecte budgets_municipaux, c'est l'etape AVAL d'un autre"
      'circuit. Le compte de collecte recoit les recettes LOCALES et les'
      'redistribue ; cette caisse-ci recoit une part de la'
      'repartition NATIONALE nocturne. Elle ne recoit RIEN de la repartition'
      'nationale. ASYMETRIE A SIGNALER : la table de repartition nationale'
      '(CAISSE_PAR_POSTE_BUDGET_SERVEUR) ne connait que `mairie-capitale`.'
      'Port-Sainte-Marie et Montrouge ne recoivent donc RIEN de la repartition'
      'nationale, ni leurs mairies, ni leurs tribunaux, ni leurs commissariats.'
      "Seule Luthecia est servie. Cela ne bloque pas la dotation, mais c'est une"
      'vraie question de jeu.'),
 'mairie_ville_a': ('Municipalites', 'Mairie de Port-Sainte-Marie',
   'Caisse municipale. Debitee par le maire et son adjoint.',
   'oui',
   "CAISSE PROPRE DU MAIRE, tranche par l'audit : ce n'est PAS un doublon du"
      "compte de collecte budgets_municipaux, c'est l'etape AVAL d'un autre"
      'circuit. Le compte de collecte recoit les recettes LOCALES et les'
      'redistribue ; cette caisse-ci recoit une part de la'
      'repartition NATIONALE nocturne. Elle ne recoit RIEN de la repartition'
      'nationale. ASYMETRIE A SIGNALER : la table de repartition nationale'
      '(CAISSE_PAR_POSTE_BUDGET_SERVEUR) ne connait que `mairie-capitale`.'
      'Port-Sainte-Marie et Montrouge ne recoivent donc RIEN de la repartition'
      'nationale, ni leurs mairies, ni leurs tribunaux, ni leurs commissariats.'
      "Seule Luthecia est servie. Cela ne bloque pas la dotation, mais c'est une"
      'vraie question de jeu.'),
 'office-notarial': ('Notariat', 'Office notarial',
   "Caisse de l'office notarial, qui enregistre les ventes de biens.",
   'oui',
   "CAISSE ACTIVE, tranche par l'audit : le cron de minuit la credite de la"
      'partdu notaire sur chaque succession (`part_notaire`), par une ecriture'
      'verifieepuis marquee. Elle est encore a 200, ce qui indique seulement'
      "qu'aucunesuccession n'a encore ete reglee."),
 'commissariat_capitale': ('Police', 'Commissariat de Luthecia',
   'Caisse du commissariat. Debitee par le commissaire et le ministre'
      "del'Interieur.",
   'oui',
   ''),
 'commissariat': ('Police', 'Commissariat de Luthecia -- caisse non suffixee',
   'Caisse du commissariat de Luthecia, sous son identifiant de batiment brut.',
   'non',
   "VESTIGE DATE, tranche par l'audit. Jusqu'au 16 aout"
      "2026,getBuildingIdPourCategorieBudget() renvoyait l'identifiant de"
      'navigation TELQUEL -- le commentaire du correctif le dit : « un buildingId'
      'de navigationpartage entre plusieurs villes, fusionnant leurs caisses ».'
      'Depuis le lot «A3, caisses locales », la convention canonique'
      'estgetCaisseLocaleId(categorie, ville) = `categorie_ville`. Cette ligne'
      "estl'etat d'AVANT le correctif, elle est a 0, et aucun appelant ne"
      "l'adresseplus. NE PAS DOTER."),
 'commissariat_ville_b': ('Police', 'Commissariat de Montrouge',
   'Caisse du commissariat. Debitee par le commissaire et le ministre'
      "del'Interieur.",
   'oui',
   ''),
 'commissariat_ville_a': ('Police', 'Commissariat de Port-Sainte-Marie',
   'Caisse du commissariat. Debitee par le commissaire et le ministre'
      "del'Interieur.",
   'oui',
   ''),
 'commissariat-local': ('Police', 'Commissariat local -- caisse non suffixee',
   'Caisse de commissariat sous un identifiant de batiment partage par'
      'deuxvilles.',
   'non',
   "VESTIGE DATE, tranche par l'audit. Jusqu'au 16 aout"
      "2026,getBuildingIdPourCategorieBudget() renvoyait l'identifiant de"
      'navigation TELQUEL -- le commentaire du correctif le dit : « un buildingId'
      'de navigationpartage entre plusieurs villes, fusionnant leurs caisses ».'
      'Depuis le lot «A3, caisses locales », la convention canonique'
      'estgetCaisseLocaleId(categorie, ville) = `categorie_ville`. Cette ligne'
      "estl'etat d'AVANT le correctif, elle est a 0, et aucun appelant ne"
      "l'adresseplus. NE PAS DOTER."),
 'port-sainte-marie': ('Port', 'Capitainerie du port industriel',
   'Caisse de la capitainerie. Debitee par le capitaine du port et le'
      'ministredes Finances. Le port gere la criee, les arrivages et les'
      'exportations.',
   'oui',
   'Encore a 200 alors que le port brasse des exportations quotidiennes :'
      'lecircuit monetaire du port ne passe donc pas par cette caisse. Aucune'
      'partdans la repartition nocturne.'),
 'dispensaire_capitale': ('Sante', 'Dispensaire de Luthecia',
   'Caisse du dispensaire, qui achete les medicaments et paie les soins.',
   'oui',
   'AUCUNE GARDE DE POSTE : cette caisse ne figure dans aucun motif'
      "decaisses_autorites, donc aucun poste public n'en est declare responsable."),
 'dispensaire-public': ('Sante', 'Dispensaire de Luthecia -- caisse non suffixee',
   'Caisse du dispensaire de Luthecia, sous son identifiant de batiment brut.',
   'non',
   "VESTIGE DATE, tranche par l'audit. Jusqu'au 16 aout"
      "2026,getBuildingIdPourCategorieBudget() renvoyait l'identifiant de"
      'navigation TELQUEL -- le commentaire du correctif le dit : « un buildingId'
      'de navigationpartage entre plusieurs villes, fusionnant leurs caisses ».'
      'Depuis le lot «A3, caisses locales », la convention canonique'
      'estgetCaisseLocaleId(categorie, ville) = `categorie_ville`. Cette ligne'
      "estl'etat d'AVANT le correctif, elle est a 0, et aucun appelant ne"
      "l'adresseplus. NE PAS DOTER."),
 'dispensaire_ville_b': ('Sante', 'Dispensaire de Montrouge',
   'Caisse du dispensaire.',
   'oui',
   "Aucune garde de poste. Encore au montant d'amorcage de 200."),
 'dispensaire_ville_a': ('Sante', 'Dispensaire de Port-Sainte-Marie',
   'Caisse du dispensaire.',
   'oui',
   'Aucune garde de poste (voir Luthecia).'),
 'dispensaire-public-v': ('Sante', 'Dispensaire local -- caisse non suffixee',
   'Caisse de dispensaire sous un identifiant de batiment partage par'
      'deuxvilles.',
   'non',
   "VESTIGE DATE, tranche par l'audit. Jusqu'au 16 aout"
      "2026,getBuildingIdPourCategorieBudget() renvoyait l'identifiant de"
      'navigation TELQUEL -- le commentaire du correctif le dit : « un buildingId'
      'de navigationpartage entre plusieurs villes, fusionnant leurs caisses ».'
      'Depuis le lot «A3, caisses locales », la convention canonique'
      'estgetCaisseLocaleId(categorie, ville) = `categorie_ville`. Cette ligne'
      "estl'etat d'AVANT le correctif, elle est a 0, et aucun appelant ne"
      "l'adresseplus. NE PAS DOTER."),
 'stade-buvette': ('Sport', 'Buvette du stade',
   'Caisse de la buvette du stade.',
   'non',
   "VESTIGE DATE, tranche par l'audit. Le code le dit : « Buvette : pas decaisse"
      'autonome (A3, lot finition financiere locale, 17 aout 2026) --affiche le'
      "solde de la caisse du stade de cette ville ». La buvette n'a plusde caisse"
      "propre ; ses 88 FR sont l'etat d'avant ce lot. Ce n'est donc PASune double"
      "comptabilite avec l'entreprise buvette : c'est une caisse retireedu modele."
      'NE PAS DOTER.'),
 'stade': ('Sport', 'Stade -- caisse non suffixee',
   'Caisse de stade sous un identifiant de batiment partage par les troisvilles.',
   'non',
   "VESTIGE DATE, tranche par l'audit. Jusqu'au 16 aout"
      "2026,getBuildingIdPourCategorieBudget() renvoyait l'identifiant de"
      'navigation TELQUEL -- le commentaire du correctif le dit : « un buildingId'
      'de navigationpartage entre plusieurs villes, fusionnant leurs caisses ».'
      'Depuis le lot «A3, caisses locales », la convention canonique'
      'estgetCaisseLocaleId(categorie, ville) = `categorie_ville`. Cette ligne'
      "estl'etat d'AVANT le correctif, elle est a 0, et aucun appelant ne"
      "l'adresseplus. NE PAS DOTER."),
 'stade_capitale': ('Sport', 'Stade de Luthecia',
   'Caisse du stade municipal.',
   'oui',
   'Aucune garde de poste.'),
 'stade_ville_b': ('Sport', 'Stade de Montrouge',
   'Caisse du stade municipal.',
   'oui',
   "Aucune garde de poste. Encore au montant d'amorcage de 200."),
 'stade_ville_a': ('Sport', 'Stade de Port-Sainte-Marie',
   'Caisse du stade municipal.',
   'oui',
   'Aucune garde de poste.'),
 'centre-multinodal-luthecia': ('Transport', 'Centre multimodal de Luthecia',
   'Caisse du centre multimodal, point de transport de la ville.',
   'oui',
   'Aucune garde de poste. INCOHERENCE DE NOMMAGE : la cle de'
      "repartitionmunicipale s'appelle `multimodal`, ces caisses s'appellent"
      '`multinodal`.'),
 'centre-multinodal-montrouge': ('Transport', 'Centre multimodal de Montrouge',
   'Caisse du centre multimodal.',
   'oui',
   "Aucune garde de poste. Meme incoherence. Encore au montant d'amorcage de200."),
 'centre-multinodal-port-sainte-marie': ('Transport', 'Centre multimodal de Port-Sainte-Marie',
   'Caisse du centre multimodal.',
   'oui',
   'Aucune garde de poste. Meme incoherence de nommage.'),
}

# Role des « volets » qui portent une caisse dans le blob de batiments_etat.
# L'identifiant technique suit la convention du journal d'amorcage :
# <ville>/<batiment>#<volet>.
VOLETS = {
 "entrepot": ("Entrepots", "Entrepot logistique",
   "Caisse de l'entrepot, qui achete les matieres aux producteurs et les revend aux "
   "commerces."),
 "usine": ("Industrie", "Usine",
   "Caisse de l'usine, qui achete ses matieres et encaisse sa vente directe."),
 "imprimerie": ("Presse", "Imprimerie",
   "Caisse de l'imprimerie, qui achete le bois et encaisse les tirages."),
 "redaction": ("Presse", "Redaction",
   "Caisse de la redaction d'un journal."),
 "sante": ("Sante", "Etablissement de sante",
   "Caisse de l'etablissement, qui achete les medicaments et encaisse les soins."),
 "port": ("Port", "Port industriel",
   "Bloc du port : criee, arrivages, exportations."),
}

MINISTERES = {
 "min_ae": "Affaires etrangeres", "min_def": "Defense", "min_fin": "Finances",
 "min_info": "Information", "min_int": "Interieur", "min_just": "Justice",
 "pm": "Premier ministre",
}

EN_TETE_F = ["famille", "nom_lisible", "ville", "identifiant_technique",
             "a_quoi_sert_cette_caisse", "solde_actuel_beta", "dotation_deja_decidee",
             "dotation_a_arbitrer", "remarque"]


def tableau_financier(d):
    lignes = []
    soldes = {c["batiment"]: c["solde"] for c in (d.get("caisses") or [])}
    # Inventaire authored des caisses que le projet traite comme dotables : le
    # journal d'amorcage du 11 septembre 2026. Il ne dit PAS quel montant verser
    # -- 2C l'a etabli -- mais il dit QUELLES caisses comptent, et c'est le seul
    # inventaire de ce genre. Il sert ici de controle de completude.
    amorces = {(a["stockage"], a["cle"]) for a in (d.get("amorcage") or [])}
    vus_blob = set()

    def ajoute(famille, nom, ville, ident, sert, doter, remarque, solde=None,
               decide=""):
        d_ = DECIDE.get((famille, ident))
        if d_:
            decide = d_[0]
            remarque = (remarque + JUSTIFICATION_5000) if d_[1] is None else d_[1]
        elif doter == "oui" and famille in FAMILLES_ISOLEES:
            remarque = FAMILLES_ISOLEES[famille]
        elif doter == "oui":
            decide = PLANCHER_AMORCAGE
            remarque = (JUSTIFICATION_PLANCHER + " " + remarque).strip()
            # Les quatre equipements qui ne recoivent plus rien apres leur dotation de
            # depart le disent sur leur propre ligne, et nulle part ailleurs.
            if any(f in ident for f in EQUIPEMENTS_SANS_RECURRENT):
                remarque = (remarque + ARBITRAGE_SANS_RECURRENT).strip()
        a_arbitrer = {"oui": "", "non": "0", "vestige": "0", "ambigu": ""}[doter]
        # Le prefixe n'est ajoute que si la remarque ne porte pas DEJA son propre
        # verdict en tete : sinon il le repeterait en l'aplatissant, alors que la
        # remarque dit precisement DE QUEL genre de « ne pas doter » il s'agit --
        # vestige date, compte de transit, contrepartie, caisse inerte.
        deja = remarque.lstrip().startswith((
            "VESTIGE", "ARTEFACT", "COMPTE DE TRANSIT", "CAISSE DE CONTREPARTIE",
            "CAISSE INERTE", "ALIMENTEE PAR UNE AUTRE CAISSE", "CE N'EST PAS UN MONTANT"))
        prefixe = "" if (doter == "oui" or deja) else {
            "non": "NE PAS DOTER INDEPENDAMMENT. ",
            "vestige": "VESTIGE, NE PAS DOTER. ",
            "ambigu": "A CLARIFIER AVANT DE CHIFFRER. "}[doter]
        lignes.append([famille, nom, nom_ville(ville), ident, sert,
                       "" if solde is None else str(solde), decide, a_arbitrer,
                       (prefixe + remarque).strip()])

    # --- tout ce qui vient de caisses_batiments et qui est decrit dans ROLES
    nat = d.get("national") or {}
    vus = set()
    for fam in FAMILLES:
        if fam == "Etat national":
            ajoute("Etat national", "Reserve monetaire du jour", "",
                   "republic.reserveJour",
                   "Accumulateur des recettes fiscales de la journee : la taxe sur "
                   "les transactions y tombe, et la repartition nocturne le vide.", "non",
                   "COMPTE DE TRANSIT, tranche par l'audit. distribuerFiscaliteServeur() "
                   "fait `reserveJour = 0` chaque nuit apres l'avoir ajoute au total "
                   "distribue. Un solde initial y serait distribue la premiere nuit puis "
                   "efface : ce n'est pas un capital de depart. 0.",
                   nat.get("reserveJour"))
            ajoute("Etat national", "Taux de prelevement national", "",
                   "republic.tauxNational",
                   "Taux national en pourcentage, preleve par "
                   "appliquer_taxe_transaction() sur chaque vente de commerce, soin et "
                   "vente de structure, et verse dans reserveJour.", "non",
                   "CE N'EST PAS UN MONTANT mais un TAUX : il n'a pas sa place dans une "
                   "dotation. Valeur actuelle 5 %, defaut du code 2 % si la cle manque. "
                   "A confirmer separement s'il doit changer.", nat.get("tauxNational"))
        if fam == "Ministeres":
            for cle, libelle in sorted(MINISTERES.items(), key=lambda x: x[1]):
                nom_caisse = "gouvernement-" + cle
                decide, rem = "", ("Le poste autorise a debiter est lu dans "
                                   "l'identifiant de la caisse.")
                doter = "oui"
                ajoute("Ministeres", "Ministere -- " + libelle, "",
                       "republic_" + nom_caisse,
                       "Caisse du ministere. Elle finance l'action du ministre et les "
                       "transferts vers les institutions dont il a la charge.",
                       doter, rem, soldes.get(nom_caisse))
                vus.add(nom_caisse)
        for nom_caisse, (f, nom, sert, doter, rem) in sorted(ROLES.items(),
                                                             key=lambda x: x[1][1]):
            if f != fam:
                continue
            vus.add(nom_caisse)
            ajoute(fam, nom, ville_de(nom_caisse), "republic_" + nom_caisse, sert,
                   doter, rem, soldes.get(nom_caisse))
        for b in sorted(d.get("batiments") or [], key=lambda x: (x["ville"], x["batiment"])):
            if est_artefact(b["batiment"]) or est_artefact(b["ville"]):
                continue
            for volet, contenu in sorted((b.get("bloc") or {}).items()):
                if not isinstance(contenu, dict) or "caisse" not in contenu:
                    continue
                vf, vnom, vsert = VOLETS.get(volet, ("A qualifier", volet,
                                                     "Volet non decrit."))
                if vf != fam:
                    continue
                ident = "%s/%s#%s" % (b["ville"], b["batiment"], volet)
                vus_blob.add(("batiments_etat", ident))
                dote = ("batiments_etat", ident) in amorces
                # L'audit a tranche la source de verite de chacune de ces caisses.
                if volet == "entrepot":
                    rem = ("SOURCE DE VERITE TRANCHEE PAR L'AUDIT : la caisse de "
                           "l'entrepot vit ICI, dans le blob de batiments_etat. Les deux "
                           "seules fonctions qui la manipulent, entrepot_commander() et "
                           "entrepot_reverser(), la lisent et l'ecrivent a cet endroit et "
                           "nulle part ailleurs. Le motif `entrepot` de caisses_autorites "
                           "(postes directeur_entrepot et maire_adjoint) est INERTE : "
                           "aucun appelant ne passe jamais un identifiant d'entrepot a "
                           "caisse_institution_mouvement(), donc aucune seconde caisse "
                           "n'est jamais creee. L'ambiguite signalee dans mon rapport "
                           "precedent est levee : il ne reste qu'un montant a fixer.")
                elif volet == "redaction":
                    rem = ("CAISSE ACTIVE, tranche par l'audit : CAISSE_REDACTION = "
                           "'redaction', et la vente des journaux est creditee « dans la "
                           "caisse de la redaction du lieu ». L'amorcage du 11 septembre "
                           "ne l'a pas dotee, contrairement aux autres caisses de blob -- "
                           "asymetrie a signaler, pas un motif pour ne pas la doter.")
                elif dote:
                    rem = ("Caisse logee dans le BLOB de batiments_etat, pas dans "
                           "caisses_batiments. L'amorcage du 11 septembre 2026 l'a bien "
                           "dotee : le projet la traite comme une caisse a doter.")
                else:
                    rem = ("Caisse logee dans le BLOB de batiments_etat. L'amorcage du "
                           "11 septembre 2026 ne l'a PAS dotee alors qu'il a dote les "
                           "autres caisses de blob. A confirmer avant de chiffrer.")
                ajoute(fam, "%s -- %s" % (vnom, b["batiment"]), b["ville"], ident, vsert,
                       "oui", rem, contenu.get("caisse"))
        if fam == "Municipalites":
            for m in d.get("municipaux") or []:
                data, cle = (m.get("data") or {}), m["cle"]
                est_ville = cle in VILLES
                ajoute("Municipalites",
                       "Budget municipal -- " + (nom_ville(cle) if est_ville else cle),
                       cle if est_ville else "", "republic_%s.caisse" % cle,
                       "Compte de COLLECTE des recettes locales : taxe sur les "
                       "transactions (tauxLocal), taxe fonciere et loyers y tombent.",
                       "non",
                       ("CETTE CAISSE N'EXISTE PLUS depuis le 8 octobre 2026, et la ligne "
                        "est conservee pour que le lecteur du tableau ne la cherche pas. "
                        "budgets_municipaux.data.caisse etait un COMPTE DE TRANSIT -- "
                        "l'audit du 5 octobre l'avait tranche ainsi -- vide chaque jour par "
                        "distribuerBudgetMunicipalVersBatiments() vers six equipements, "
                        "selon les pourcentages d'`allocation` fixes par le maire. Le "
                        "chantier des budgets municipaux a supprime les trois a la fois : la "
                        "cle `caisse` (une seconde bourse), la cle `allocation` (une seconde "
                        "regle de repartition) et la distribution cliente. La tresorerie "
                        "d'une mairie est desormais caisses_batiments.<pays>_mairie_<ville>, "
                        "et elle seule ; la mesure des recettes du jour est la table "
                        "recettes_municipales. Aucune dotation : rien a doter. 0.")
                       if est_ville else
                       ("ARTEFACT TECHNIQUE : la caserne est une zone speciale, pas une "
                        "ville, mais getVilleKey() lit state.currentCity sans filtrer. "
                        "Meme origine que republic_mairie_caserne. 0."),
                       data.get("caisse"))
                if "tauxFoncier" in data:
                    ajoute("Municipalites",
                           "Taux foncier -- " + (nom_ville(cle) if est_ville else cle),
                           cle if est_ville else "", "republic_%s.tauxFoncier" % cle,
                           "Taux de la taxe fonciere, preleve chaque nuit sur la surface "
                           "de chaque terrain au profit du compte de collecte municipal.",
                           "non",
                           "CE N'EST PAS UN MONTANT mais un TAUX, et il EST ACTIF : "
                           "preleverTaxeFonciere() le lit chaque nuit dans le cron "
                           "(defaut 0,05) et applique surface x taux. CORRECTION de mon "
                           "rapport precedent, qui le disait non lu : il n'est lu par "
                           "aucune fonction SQL, mais il l'est par le cron. Present sur "
                           "2 des 4 lignes seulement, les deux autres prenant le defaut.",
                           data.get("tauxFoncier"))
        if fam == "Clubs sportifs":
            for c in d.get("clubs") or []:
                bud = c.get("budget") or {}
                ajoute("Clubs sportifs", "Club -- " + c["nom"], c.get("ville"),
                       c["id"] + ".caisse",
                       "Caisse du club de football. Elle paie les salaires des joueurs "
                       "et les primes de victoire.", "oui",
                       "Le bareme de salaires (titulaire 100, remplacant 50, prime de "
                       "victoire 150) est IDENTIQUE sur les 12 clubs des 4 empires : il "
                       "releve du socle et n'est pas a arbitrer ici. A noter : le blob "
                       "porte derniereSubventionJour, mais AUCUNE fonction de subvention "
                       "n'ecrit cette table.", bud.get("caisse"))

    # CONTROLE DE COMPLETUDE : une caisse que le journal d'amorcage a dotee et
    # que ce tableau ne montrerait pas serait un oubli. On le dit plutot que de
    # l'ignorer.
    attendues = {c for (st, c) in amorces if st == "caisses_batiments"}
    presentes = set(vus) | {"gouvernement-" + k for k in MINISTERES}
    global MANQUANTES
    MANQUANTES = sorted(c for c in attendues
                        if c.split("/")[-1] not in presentes)
    for c in MANQUANTES:
        ajoute("A qualifier", c, "", "republic_" + c.split("/")[-1],
               "Caisse dotee par le journal d'amorcage mais absente de la nomenclature.",
               "ambigu", "OUBLI POSSIBLE DE CE TABLEAU : le journal d'amorcage du 11 "
               "septembre 2026 a dote cette caisse, mais la nomenclature ne la decrit "
               "pas. A qualifier.", soldes.get(c.split("/")[-1]))

    orphelines = sorted(set(soldes) - vus)
    for o in orphelines:
        if est_artefact(o):
            continue
        ajoute("A qualifier", o, ville_de(o), "republic_" + o,
               "Role non reconnu par la nomenclature.", "ambigu",
               "CAISSE NON DECRITE : elle existe en base mais n'entre dans aucune "
               "famille connue. A qualifier avant d'arbitrer.", soldes.get(o))
    return lignes


INTRO_F = """**À remplir par Fred.** Sous-tableau **financier** du tableau 1 :
toutes les caisses et budgets de Républia, **aucune matière première**.

Une seule colonne à renseigner : `dotation_a_arbitrer`. Elle est déjà remplie à
`0` là où l'observation montre qu'une dotation indépendante ne doit pas exister.

Les remarques commencent par un verdict :

- *(rien)* — dotation à arbitrer normalement ;
- **NE PAS DOTER INDÉPENDAMMENT** — la caisse est alimentée par une autre, ou
  c'est une contrepartie, pas un budget ;
- **VESTIGE, NE PAS DOTER** — ligne héritée d'avant la dimension ville, solde 0 ;
- **À CLARIFIER AVANT DE CHIFFRER** — la question est mal posée tant qu'une
  ambiguïté n'est pas levée ; demander un montant serait vous faire deviner.

`solde_actuel_beta` est **informatif** : il sert à reconnaître la caisse. Aucun
montant n'en a été déduit."""

EN_TETE_1 = [
    "categorie", "entite", "table", "ville", "identifiant_technique",
    "role_dans_le_jeu", "valeur_actuelle_informative", "montant_initial_a_arbitrer",
    "remarque",
]
EN_TETE_2 = [
    "type", "nom_lisible", "identifiant_technique", "ville", "champ_a_arbitrer",
    "etat_actuel_informatif", "proposition_si_valeur_authored", "decision_finale",
    "remarque",
]


def nom_ville(v):
    return VILLES.get(v, v or "")


def tableau_dotations(d):
    lignes = []

    def ajoute(cat, entite, table, ville, ident, role, actuel, remarque=""):
        decide = DECIDE.get((cat, ident))
        lignes.append([cat, entite, table, nom_ville(ville), ident, role,
                       "" if actuel is None else str(actuel),
                       decide[0] if decide else "",
                       decide[1] if decide else remarque])

    # --- budget national : argent, taux, et matieres detenues au niveau national
    nat = d.get("national") or {}
    ajoute("budget national", "Reserve du jour", "budgets_nationaux", "", "republic.reserveJour",
           "Reserve monetaire nationale du jour.", nat.get("reserveJour"))
    ajoute("budget national", "Taux national", "budgets_nationaux", "", "republic.tauxNational",
           "Taux de prelevement national, en pourcentage.", nat.get("tauxNational"))
    ajoute("budget national", "Rations du refectoire", "budgets_nationaux", "",
           "republic.refectoire.rations",
           "Nombre de rations disponibles au refectoire de la caserne.",
           (nat.get("refectoire") or {}).get("rations"))
    for res, qte in sorted((nat.get("caserneMatieres") or {}).items()):
        ajoute("matiere premiere", "Caserne -- " + res, "budgets_nationaux", "",
               "republic.caserneMatieres." + res,
               "Stock de %s detenu par la caserne, consomme par le refectoire et "
               "l'infirmerie." % res, qte,
               "NON COUVERT par l'arbitrage des matieres premieres du 5 octobre 2026, qui "
               "porte sur les ENTREPOTS DE VILLE. Ce stock-ci est celui de la caserne, et "
               "il est national, pas municipal. A arbitrer separement -- en gardant a "
               "l'esprit qu'un monde neuf n'a ni compagnie ni soldat au premier jour.")
    # L'armurerie nationale tient un REGISTRE DE LOTS a cote de son stock, et
    # chaque lot porte son origine. Un lot nomme « dotation-initiale » est donc
    # une provenance ECRITE, pas un solde dont on deduirait quelque chose : c'est
    # la seule trace exploitable de la dotation voulue, et elle est citee comme
    # telle. Le reste vient d'un lot « dotation-beta-2026-09-22 ».
    lots = nat.get("lotsMilitaires") or {}
    for art, qte in sorted((nat.get("stockArmurerieMilitaire") or {}).items()):
        origine = {}
        for l in (lots.get(art) or []):
            if isinstance(l, dict):
                origine[l.get("lot")] = origine.get(l.get("lot"), 0) + (l.get("qte") or 0)
        initiale = origine.get("dotation-initiale")
        detail = ", ".join("%s = %s" % (k, v) for k, v in sorted(origine.items())) or "aucun lot"
        if initiale is not None:
            remarque = ("PROVENANCE ECRITE : le registre des lots porte un lot nomme "
                        "`dotation-initiale` de %s unite(s). C'est la dotation voulue telle "
                        "qu'elle a ete enregistree. Le reste du stock vient d'un autre lot "
                        "(%s). A confirmer plutot qu'a redefinir." % (initiale, detail))
        elif origine:
            remarque = ("AUCUN lot `dotation-initiale` pour cet article : la totalite du "
                        "stock vient de lots posterieurs (%s). La dotation voulue n'est "
                        "donc pas lisible, elle doit etre decidee." % detail)
        else:
            remarque = ("Stock a %s et AUCUN lot enregistre : ni dotation initiale ni "
                        "ajout. A decider." % qte)
        ajoute("equipement militaire", "Armurerie nationale -- " + art, "budgets_nationaux", "",
               "republic.stockArmurerieMilitaire." + art,
               "Quantite de %s en armurerie nationale, distribuable aux sections." % art,
               qte, remarque)

    # --- caisses de batiment
    for c in d.get("caisses") or []:
        b = c["batiment"]
        if est_artefact(b):
            ecarter("tableau 1 / caisses_batiments", "republic_" + b,
                    "Identifiant portant un marqueur de test. N'appartient pas au monde "
                    "initial : il n'y a donc rien a arbitrer. La ligne existe toujours en base.")
            continue
        cat, role = qualifier(b)
        remarque = ""
        if c["solde"] in (0, None) and ville_de(b) == "" and not re.match(
                r"^(palais-gouvernement|mairie_caserne|banque-privee|agence-)", b):
            remarque = ("Solde a 0 et aucune ville dans l'identifiant : ressemble a une "
                        "ligne heritee d'avant la dimension ville. A qualifier avant d'arbitrer.")
        ajoute(cat, b, "caisses_batiments", ville_de(b), "republic_" + b, role,
               c["solde"], remarque)

    # --- budgets municipaux
    for m in d.get("municipaux") or []:
        data = m.get("data") or {}
        cle = m["cle"]
        ville = cle if cle in VILLES else ""
        libelle = nom_ville(cle) if cle in VILLES else cle
        ajoute("budget municipal", "Caisse -- " + libelle, "budgets_municipaux", ville,
               "republic_%s.caisse" % cle, "Caisse de la municipalite.", data.get("caisse"),
               "" if cle in VILLES else
               "Cette ligne n'est pas une ville : elle porte le budget de la caserne. "
               "A confirmer avant d'arbitrer.")
        if "tauxFoncier" in data:
            ajoute("budget municipal", "Taux foncier -- " + libelle, "budgets_municipaux", ville,
                   "republic_%s.tauxFoncier" % cle,
                   "Taux de la taxe fonciere municipale.", data.get("tauxFoncier"))

    # --- budgets de clubs
    for c in d.get("clubs") or []:
        bud = c.get("budget") or {}
        ajoute("club sportif", c["nom"], "budgets_clubs", c.get("ville"), c["id"],
               "Caisse du club de football.", bud.get("caisse"),
               "Le bareme de salaires (titulaire / remplacant / prime de victoire) est "
               "identique sur les 12 clubs des 4 empires : il releve du socle et n'a pas "
               "a etre arbitre ici.")

    # --- matieres premieres des entrepots de ville
    # Une valeur identique sur les trois villes est un indice fort qu'elle est
    # d'origine ; une valeur divergente, qu'elle a derive en partie. On le dit.
    # Une ligne par ressource : la dotation est la MEME dans les trois villes,
    # donc une seule decision par matiere. La valeur de bêta reste en remarque,
    # a titre informatif, avec mention de celles qui avaient derive.
    stocks = {}
    for e in d.get("entrepots") or []:
        for res, qte in ((e.get("bloc") or {}).get("stock") or {}).items():
            stocks.setdefault(res, {})[e["ville"]] = qte
    for res in sorted(set(stocks) | set(MATIERES_ARBITREES)):
        par_ville = stocks.get(res, {})
        valeurs = set(par_ville.values())
        arbitree = MATIERES_ARBITREES.get(res)
        detail = ", ".join("%s=%s" % (nom_ville(k), par_ville[k]) for k in sorted(par_ville))
        if len(valeurs) == 1:
            remarque = ("ARBITRE. La bêta portait deja cette valeur a l'identique sur les "
                        "trois villes (%s) : elle est confirmee, pas deduite." % detail)
        else:
            remarque = ("ARBITRE. La bêta avait DERIVE selon la ville (%s) : la valeur "
                        "d'origine n'y etait plus lisible, elle est donc fixee." % detail)
        lignes.append(["matiere premiere", "Entrepots de ville -- " + res, "batiments_etat",
                       "les 3 villes", "entrepot-logistique-*.entrepot.stock." + res,
                       "Stock de %s dans l'entrepot logistique de chaque ville." % res,
                       detail, str(arbitree) if arbitree is not None else "",
                       remarque if arbitree is not None else
                       "Presente en base mais ABSENTE de la liste arbitree : a trancher."])
    for e in d.get("entrepots") or []:
        ajoute("caisse d'entrepot", "Entrepot de " + nom_ville(e["ville"]), "batiments_etat",
               e["ville"], "%s.entrepot.caisse" % e["batiment"],
               "Caisse de l'entrepot logistique, qui achete et revend les matieres.",
               (e.get("bloc") or {}).get("caisse"))
    return lignes


def tableau_etat_initial(d):
    lignes = []

    def ajoute(typ, nom, ident, ville, champ, actuel, propose="", remarque=""):
        lignes.append([typ, nom, ident, nom_ville(ville), champ,
                       "" if actuel is None
                       else json.dumps(actuel, ensure_ascii=False)
                       if isinstance(actuel, (dict, list))
                       else ("true" if actuel is True else "false" if actuel is False
                             else str(actuel)),
                       propose, "", remarque])

    # --- batiments : on n'expose QUE les champs qui demandent une decision
    for b in d.get("batiments") or []:
        bat, ville, bloc = b["batiment"], b["ville"], (b.get("bloc") or {})
        if est_artefact(bat) or est_artefact(ville):
            ecarter("tableau 2 / batiments_etat", "%s (%s)" % (bat, ville),
                    "Batiment ou ville de test. Rien a arbitrer.")
            continue
        for volet, contenu in sorted(bloc.items()):
            if not isinstance(contenu, dict):
                continue
            if "caisse" in contenu:
                ajoute("batiment", "%s (%s)" % (bat, volet), bat, ville,
                       "%s.caisse" % volet, contenu.get("caisse"), "",
                       "Caisse de ce volet du batiment.")
            for cle in ("stockMatieres", "stockBois", "stock", "venteDirecte",
                        "coutMoyenMatieres"):
                if cle in contenu:
                    remarque = {
                        "venteDirecte": "Prix de vente directe. Ressemble a une valeur "
                                        "authored : a confirmer plutot qu'a redefinir.",
                        "stock": "Stock. Pour le port, il accumule les arrivages "
                                 "quotidiens : la valeur actuelle n'est PAS un etat initial.",
                    }.get(cle, "Etat consomme en partie : la valeur actuelle n'est pas "
                                "un etat initial.")
                    ajoute("batiment", "%s (%s)" % (bat, volet), bat, ville,
                           "%s.%s" % (volet, cle), contenu.get(cle), "", remarque)

    # --- commerces
    for c in d.get("commerces") or []:
        if est_de_test(c["id"]) or est_de_test(c.get("ville")):
            ecarter("tableau 2 / entreprises", c["id"],
                    "Commerce de test. Rien a arbitrer.")
            continue
        nom = c.get("enseigne") or c["id"]
        # Un fonds de commerce cree par un joueur se reconnait a son
        # PROPRIETAIRE, pas a sa ville : ce test passe donc en premier, sinon
        # un fonds de joueur serait diagnostique comme une ligne heritee.
        if c.get("proprietaire") not in (None, "PNJ"):
            ajoute("commerce", nom, c["id"], c.get("ville"), "existence",
                   "proprietaire = %s, statut = %s"
                   % (c.get("proprietaire"), c.get("statut")), "",
                   "FONDS DE COMMERCE CREE PAR UN JOUEUR pendant la bêta. Ne fait pas "
                   "partie du monde initial : rien a arbitrer. A ne pas seeder.")
            continue
        if not c.get("ville"):
            ajoute("commerce", nom, c["id"], "", "existence",
                   "ville et batiment absents", "",
                   "LIGNE SANS VILLE NI BATIMENT : ressemble a un reste d'avant la "
                   "dimension ville. A qualifier avant d'arbitrer, pas a seeder.")
            continue
        ajoute("commerce", nom, c["id"], c["ville"], "caisse", c.get("caisse"),
               "", "Une dotation de caisse par type de commerce existe deja, authored, "
                   "dans commerces_dotations : verifier si elle suffit avant d'arbitrer.")
        if c.get("stock_matieres"):
            ajoute("commerce", nom, c["id"], c["ville"], "stockMatieres",
                   c.get("stock_matieres"), "",
                   "Une dotation de stock par type existe deja dans commerces_dotations.")
        if c.get("stock_produits"):
            ajoute("commerce", nom, c["id"], c["ville"], "stockProduits",
                   c.get("stock_produits"), "",
                   "Produits finis en rayon. Un commerce neuf en a-t-il, ou part-il a vide ?")

    # --- terrains
    for t in d.get("terrains") or []:
        bat, bloc = t["batiment"], (t.get("bloc") or {})
        if est_artefact(bat):
            ecarter("tableau 2 / terrains_etat", bat,
                    "Terrain de test, porteur d'un chantier de bêta. Rien a arbitrer.")
            continue
        ville = bloc.get("city", "")
        ajoute("terrain", bat, bat, ville, "proprietaire",
               t.get("proprietaire") or bloc.get("proprietaire"), "",
               "Un terrain appartient-il a quelqu'un au premier jour, ou est-il libre ?")
        ajoute("terrain", bat, bat, ville, "constructionAutorisee",
               bloc.get("constructionAutorisee"),
               str(bloc.get("constructionAutorisee")).lower()
               if bloc.get("constructionAutorisee") is not None else "",
               "Valeur authored vraisemblable : a confirmer.")
        ajoute("terrain", bat, bat, ville, "valeur_totale", bloc.get("valeur_totale"),
               str(bloc.get("valeur_totale") or ""),
               "Valeur authored vraisemblable (surface x prix) : a confirmer.")
        if bloc.get("pnj"):
            ajoute("terrain", bat, bat, ville, "occupant PNJ",
                   bloc.get("pnj"), str(bloc.get("pnj")),
                   "Un PNJ est pose dans le blob du terrain (squatteurs). Contenu "
                   "authored vraisemblable : a confirmer.")
        if bloc.get("niveau_construction") or bloc.get("chantier"):
            ajoute("terrain", bat, bat, ville, "niveau_construction / chantier",
                   bloc.get("niveau_construction") or "chantier en cours", "",
                   "Etat vivant : un monde neuf ne demarre pas avec un chantier en cours.")
    return lignes


def ecrire_csv(chemin, entete, lignes):
    with open(chemin, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh, delimiter=";")
        w.writerow(entete)
        w.writerows(lignes)


def ecrire_md(chemin, titre, intro, entete, lignes, prefixe_ecartees=None):
    with open(chemin, "w", encoding="utf-8", newline="") as fh:
        fh.write("# %s\n\n%s\n\n" % (titre, intro))
        fh.write("| " + " | ".join(entete) + " |\n")
        fh.write("|" + "|".join(["---"] * len(entete)) + "|\n")
        for l in lignes:
            fh.write("| " + " | ".join(
                (x or "").replace("|", "\\|").replace("\n", " ") for x in l) + " |\n")
        miennes = [e for e in ECARTEES if prefixe_ecartees and e[0].startswith(prefixe_ecartees)]
        if miennes:
            fh.write("\n## Lignes écartées de ce tableau, et pourquoi\n\n")
            fh.write("Elles existent toujours en base. Elles ne sont pas à arbitrer, "
                     "mais vous devez savoir qu'elles existent : rien n'est écarté en silence.\n\n")
            fh.write("| source | ligne | raison |\n|---|---|---|\n")
            for ou, quoi, pourquoi in sorted(miennes):
                fh.write("| %s | `%s` | %s |\n" % (ou, quoi, pourquoi))


INTRO_1 = """**À remplir par Fred.** Une ligne = une décision. La colonne
`montant_initial_a_arbitrer` est la seule à renseigner.

`valeur_actuelle_informative` sert à reconnaître le lieu, **pas** à suggérer une
réponse : c'est un solde de bêta. Aucun montant n'en a été déduit, et aucun n'a
été déduit du journal `dotations_amorcage_caisses`, qui dit ce qui *a été* versé
et non ce qui *doit* l'être.

Une seule ligne est préremplie, parce qu'elle est déjà arbitrée : le budget du
ministère de la Défense de Républia.

Périmètre : Républia uniquement. Les trois villes sont Luthécia (`capitale`),
Port-Sainte-Marie (`ville_a`) et Montrouge (`ville_b`).

Ce tableau couvre l'argent et les matières premières. Les bâtiments, commerces
et terrains sont dans le tableau 2, y compris les caisses qui vivent dans leur
blob — la frontière est posée pour que rien ne tombe entre les deux."""

INTRO_2 = """**À remplir par Fred.** Une ligne = un champ d'état initial qui
demande vraiment une décision. Les champs purement techniques et les champs
dérivés ne sont pas listés.

`etat_actuel_informatif` est l'état de la bêta : il n'est **pas** une proposition.
`proposition_si_valeur_authored` n'est rempli que là où une valeur d'origine est
clairement identifiable (surface d'un terrain, autorisation de construire…).

Les lignes de test et celles créées par un joueur pendant la bêta sont signalées
plutôt que supprimées : elles n'ont pas à être arbitrées, mais vous devez savoir
qu'elles existent.

Périmètre : Républia uniquement."""


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    if sys.argv[1] == "--sql":
        print(REQUETE.format(pays=PAYS).strip())
        return 0
    if sys.argv[1] != "--rendre" or len(sys.argv) != 3:
        print(__doc__)
        return 2

    brut = open(sys.argv[2], encoding="utf-8").read()
    try:
        externe = json.loads(brut)["result"]
    except Exception:
        externe = brut
    m = re.search(r"<untrusted-data-[0-9a-f-]+>\n(.*)\n</untrusted-data-", externe, re.S)
    donnees = json.loads(m.group(1) if m else externe)
    while isinstance(donnees, list) or "caisses" not in donnees:
        donnees = donnees[0] if isinstance(donnees, list) else donnees["export_arbitrages"]

    # Controle d'integrite de l'extraction, avant toute ecriture.
    ctl = donnees.get("controle")
    if not ctl:
        raise SystemExit(
            "extraction sans bloc `controle` : elle a ete produite par une version "
            "anterieure de la requete. Rejouer `arbitrages.py --sql`.")
    manques = []
    for cle, attendu in sorted(ctl.items()):
        recu = len(donnees.get(cle) or [])
        if recu != attendu:
            manques.append("%s : %d recu(s), %d annonce(s) par la base" % (cle, recu, attendu))
    if manques:
        raise SystemExit(
            "EXTRACTION INCOMPLETE -- aucun fichier ecrit.\n  "
            + "\n  ".join(manques)
            + "\nLa base a compte elle-meme ces lignes : le fichier recu en a perdu. "
              "Ne pas rendre un tableau d'arbitrage ampute. Rejouer l'extraction.")
    print("integrite de l'extraction : " + ", ".join(
        "%s=%d" % (k, v) for k, v in sorted(ctl.items())))

    os.makedirs(CIBLE, exist_ok=True)
    t1 = tableau_dotations(donnees)
    t2 = tableau_etat_initial(donnees)

    ecrire_csv(os.path.join(CIBLE, "dotations-initiales-republia.csv"), EN_TETE_1, t1)
    ecrire_md(os.path.join(CIBLE, "dotations-initiales-republia.md"),
              "Tableau d'arbitrage 1 — dotations initiales de Républia", INTRO_1, EN_TETE_1, t1,
              "tableau 1")
    tf = tableau_financier(donnees)
    ecrire_csv(os.path.join(CIBLE, "dotations-financieres-republia.csv"), EN_TETE_F, tf)
    ecrire_md(os.path.join(CIBLE, "dotations-financieres-republia.md"),
              "Sous-tableau financier — dotations initiales de Républia",
              INTRO_F, EN_TETE_F, tf)

    ecrire_csv(os.path.join(CIBLE, "etat-initial-republia.csv"), EN_TETE_2, t2)
    ecrire_md(os.path.join(CIBLE, "etat-initial-republia.md"),
              "Tableau d'arbitrage 2 — état initial des lieux de Républia", INTRO_2, EN_TETE_2, t2,
              "tableau 2")

    print("tableau 1 : %d lignes a arbitrer" % len(t1))
    print("lignes ecartees et nommees : %d" % len(ECARTEES))
    print("tableau financier : %d lignes" % len(tf))
    verdicts = {}
    for l in tf:
        v = ("a doter" if not l[8] else
             "ne pas doter" if l[8].startswith("NE PAS") else
             "vestige" if l[8].startswith("VESTIGE") else
             "a clarifier" if l[8].startswith("A CLARIFIER") else "a doter")
        verdicts[v] = verdicts.get(v, 0) + 1
    for k in sorted(verdicts):
        print("   %-16s %3d" % (k, verdicts[k]))
    print("tableau 2 : %d lignes a arbitrer" % len(t2))
    cat = {}
    for l in t1:
        cat[l[0]] = cat.get(l[0], 0) + 1
    for k in sorted(cat):
        print("   %-22s %3d" % (k, cat[k]))
    typ = {}
    for l in t2:
        typ[l[0]] = typ.get(l[0], 0) + 1
    for k in sorted(typ):
        print("   %-22s %3d" % (k, typ[k]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
