# Audit de la chaîne élective — 2 novembre 2026 (Claude)

Périmètre : président, maire, député, chef syndical. Chaîne suivie de bout en bout :
création du scrutin → candidature → campagne (tracts, voix PNJ) → vote → dépouillement de
minuit → prise de fonctions / second tour / prolongation → contestation et fraudes → secours PNJ.

Sources lues : `baseline/domaines/politique-et-elections/20_fonctions.sql`,
`baseline/domaines/justice/20_fonctions-2.sql` (fraudes), `api/cron-minuit.js`
(l. 345-650, 5245-5300, 5880-6133), `plateau-politique.js` (l. 690-1070, 1424-1770).
Production relue en lecture seule le 02/11 vers 21 h 50 (`cycles_electoraux`, `candidatures`,
`votes_electoraux`, `evenements_globaux`, `chronique_nationale`). Aucune écriture.

## Ce qui tient

- Plus aucune écriture de l'écran dans `cycles_electoraux` (lecture seule pour `authenticated`).
- Le vote (`election_voter`) : identité lue par le serveur, domicile, fenêtre dimanche 00:01 →
  lundi 00:00, candidat présent sur le bulletin, un bulletin par tour (clé primaire), écriture
  du bulletin et du cycle dans la même transaction.
- Le dépouillement de minuit : une seule consignation par scrutin (garde sur `dateResultats`),
  le titulaire sortant n'est jamais effacé, pas de vacance pendant une élection, mandat
  prolongé de 2 semaines si aucun verdict.
- Calendrier aligné sur le dimanche (déclencheur `cycles_electoraux_dimanche`), dates
  calendaires de Paris, heure d'été comprise.
- Contestation : fenêtre de 24 h sur la photographie du scrutin (`dernierScrutin`), jet et
  recompte au serveur.

## Défauts trouvés

### E1 — BLOQUANT : la candidature par le programme n'inscrit pas sur le bulletin

Le bouton « 📋 Se porter candidat » du calendrier électoral (`ouvrirRedactionProgramme`,
`plateau-politique.js` l. 704) mène à `candidature_publier`. Cette fonction prélève les 2 PA,
écrit la ligne `candidatures` et le programme au forum, **mais n'ajoute pas le candidat au
cycle** (`cycle.candidats`), seul bulletin lu par `election_voter` et par le dépouillement.
Seul l'autre chemin (salle des élections → `confirmerCandidature` → `candidature_deposer`)
écrit le bulletin.

L'écran masque le défaut : `syncCyclesDepuisSupabase` réinjecte la table `candidatures` dans
la copie locale du cycle, donc le joueur se voit candidat et les électeurs le voient au bureau
de vote. Mais tout vote pour lui est refusé (`candidat_inconnu`) et il n'est jamais compté.

**Constaté en production** : Jean Népa, candidat par programme à la mairie de ville_a
(empire narco) le 14/10 à 21 h 24 ; le scrutin clos le 02/11 à 00 h 00 avait un bulletin
vide (`dernierScrutin.candidats = []`), annonce « Aucun bulletin ».

Correction proposée (technique, sans décision de jeu) : `candidature_publier` ajoute le
candidat au cycle sous verrou, dans sa transaction, comme `candidature_deposer` ; rattrapage
des candidatures du scrutin en cours absentes du bulletin.

### E2 — BLOQUANT : la mairie de Luthécia est figée depuis le 12 octobre

`republic_maire_capitale` est encore à l'ancien format : `phase = 'mandat'`,
`resultatsTraites = true`, résultats du 12/10 déjà passés, fin de mandat 16/11.
Le dépouillement l'ignore (`if (cycle.resultatsTraites) continue`, cron l. 5912), aucun
scrutin de succession n'y est ouvert, et le déclencheur `candidatures_cloture` refuse toute
candidature (`resultatsTraites`). Aucune élection municipale n'est possible à Luthécia, et le
16/11 rien ne se passera : le PNJ restera maire indéfiniment.

Correction proposée : ouvrir sur ce cycle le scrutin de succession du mandat en cours
(`ouvrirSuccessionSurCycle` à partir de `dateDebutMandatTs`, ce qui garde le PNJ jusqu'au
16/11 avec un vote le 15/11), par une migration ciblée ; et faire traiter par la passe de
nuit tout cycle échu resté à `resultatsTraites = true`, pour qu'aucun autre ne se fige.

### E3 — MAJEUR : les fraudes du premier tour comptent aussi au second

Une fraude est rattachée au scrutin par `cycle_debut = dateDebutCandidatures`
(`fraude_electorale_tenter`). Le passage au second tour ne change pas cette date : les voix
truquées au premier tour sont ajoutées une seconde fois au candidat qualifié, par le
dépouillement (`chargerFraudesActivesServer`) comme par le recompte de contestation. Le
plafond de fraudes par type est aussi partagé entre les deux tours.

### E4 — MAJEUR : contester un premier tour pendant le second tour

Si le premier tour a envoyé au second tour, la contestation des 24 h suivantes recompte le
premier tour. Si la fraude retirée donne une majorité absolue, `election_contester` pose
`eluId` en plein second tour, sans prise de fonctions ni fermeture du second tour : le nouvel
élu est considéré comme le sortant, et le second tour continue. À l'inverse, une fraude
révélée qui changerait les deux qualifiés ne change rien.

### E5 — MOYEN : un résultat changé par contestation n'est ni annoncé ni archivé

Quand le recompte change l'élu, seul `eluId` / `elus` est remplacé. Pas d'annonce publique,
la chronique garde l'ancien vainqueur, et pour un maire ni archive du mandat ni relevé des
indicateurs de début.

### E6 — MOYEN : le secours PNJ du lundi efface un scrutin en cours

`pourvoirCycleElu` (cron l. 5245) installe le PNJ par défaut sur un cycle sans titulaire et
rouvre une succession (`ouvrirSuccessionSurCycle`), qui vide les candidats et les bulletins
du scrutin en cours. Sans effet aujourd'hui (président et maires ont un titulaire), mais un
poste devenu vacant avec des candidats déclarés les perdrait au premier lundi.

### E7 — MINEUR : textes visibles

- Annonces de résultats avec l'identifiant brut de la ville (« Maire (capitale) »,
  « Maire (ville_a) ») au lieu de Luthécia / PSM / Montrouge (constaté en production).
- Bandeau du calendrier électoral périmé : « Candidatures : 7 jours · Campagne : 7 jours ·
  Vote : 24h » (`plateau-politique.js` l. 714), alors que la règle est : candidatures pendant
  les 4 premières semaines du mandat, gel la 5e, vote le dernier dimanche ; 1 semaine de
  candidatures seulement après une prolongation.

### E8 — MINEUR : portes directes restantes

`authenticated` garde INSERT et DELETE sur `candidatures` et INSERT sur `votes_electoraux`.
Sans effet sur le scrutin (seul le cycle compte), mais un retrait par DELETE laisse le
candidat sur le bulletin, et un INSERT direct de bulletin bloque ensuite le vrai vote
(`deja_vote`). À fermer après correction de E1.

## État de la production (02/11, 21 h 50)

- Aucun candidat, aucun bulletin dans les 14 cycles. Aucun résultat proclamé (chronique
  `election_resultat`) depuis 60 jours. Aucun PJ ne tient un poste électif.
- 12 cycles ont été prolongés cette nuit (« Aucun bulletin ») : vote le dimanche 15/11.
  Exceptions : député de PSM (vote le 08/11), maire de PSM (22/11), maire de Luthécia (figé, E2).
- Les sièges de député du cycle sont vides (`elus` absent) ; les 9 PNJ siègent par
  `assemblee_sieges`, ce qui est le fonctionnement prévu.

## Corrections (02/11/2026)

E1, E2 et E3 corrigés par la migration `20261102222500_chaine_elective_bulletin_fraudes_mairie` (appliquée) et `api/cron-minuit.js` ; règle E3 dans `GAME-DESIGN-ELECTIONS.md`.

E4 à E8 (02-03/11/2026, branche `claude/chaine-elective-e4-e8-20261102`) :
- **E4/E5** : décision de Fred « le recompte s'impose » (`GAME-DESIGN-ELECTIONS.md`).
  `election_contester` délègue à `election_contestation_appliquer` (interne) : prise de fonctions,
  second tour relancé ou annulé, prolongation, retour du titulaire précédent, annonce publique et
  chronique. `election_recompter_interne` rend aussi les qualifiés du second tour. La passe de nuit
  garde dans `dernierScrutin` le titulaire d'avant la proclamation et les noms affichés.
- **E6** : le secours PNJ du lundi n'efface plus un scrutin engagé (candidats ou bulletins, résultat
  à venir) ; le PNJ assure l'intérim jusqu'à ce résultat.
- **E7** : annonces de la passe de nuit avec le nom de la ville (`VILLES_SERVEUR`) ; bandeau du
  calendrier électoral aligné sur la règle de succession. Deux anciens écrans de calendrier aux
  textes périmés (`ouvrirCalendrierElections`, `openElectionsModal`) n'ont plus aucun appelant :
  laissés en l'état.
- **E8** : INSERT retiré à `authenticated` sur `candidatures` ; DELETE de soi gardé (suppression du
  personnage) et un déclencheur retire désormais le nom du bulletin du scrutin ouvert.
  `votes_electoraux` : aucun droit d'INSERT en production (déjà fermé), la policy « vote de soi »
  reste en garde-fou.
Migration `20261103001000_chaine_elective_contestation_portes` ; banc annulé
`outils/bancs/banc-contestation-e4-e8.sql`.

## Ordre de correction proposé

E1 et E2 d'abord (sans eux, aucune élection ne peut aboutir), puis E3-E6, puis E7-E8.
Décision de jeu nécessaire pour E3 et E4 seulement : voir les questions à Fred.
