# Palais du Gouvernement — deuxième passe : qui paie, qui répond, et qui sont les cinq

*11 octobre 2026. **Ce bâtiment n'est PAS clos** : la visite fonctionnelle de Fred
n'est pas terminée. Ce document enregistre deux arbitrages livrés ensemble, et
nomme ce qui reste ouvert.*

Migrations : registre **20261011111516** (`conference_de_presse_et_financement`),
**20261011115512** (`memoire_un_obstacle_qui_dit_encore_vrai`) et **20261011123403**
(`cinq_secretaires_ministeriels_referents`).

---

## 1. Qui paie une communication officielle

**Les PA sont au joueur qui passe l'ordre. Les francs sortent par défaut du budget
du ministère de l'Information.** C'est l'arbitrage, et il est désormais exécuté
par le serveur, dans la même transaction que la publication.

S'il ne couvre pas, **rien n'est débité**. La porte refuse en **nommant** la caisse
de repli — celle du poste de celui qui parle — et son solde, et elle attend un
accord explicite. Le joueur rappelle alors la porte avec son accord, et la dépense
est prise **en entier** sur sa caisse institutionnelle.

Ce que cela exclut, et qui est vérifié par contre-épreuve :

| règle | contre-épreuve |
|---|---|
| pas de financement mixte | après un paiement sur la caisse du poste, le budget de l'Information est inchangé, ses 100 FR disponibles n'ont pas été versés |
| pas de débit partiel | le débit est fait sous verrou, après relecture du solde ; un solde qui a bougé fait refuser sans rien écrire |
| aucun PA perdu sur un refus | les PA sont verrouillés et vérifiés **avant** le débit financier, et rendus comme refus structuré (`pa_insuffisants`) et non comme exception |
| aucune conférence ouverte sur un refus | le compte de `conferences_presse` est inchangé après chaque refus |
| si aucune des deux caisses ne couvre | `les_deux_caisses_insuffisantes`, et aucune ressource consommée |

**La caisse d'un poste n'a pas été inventée.** `salaires_caisses` la déclarait
déjà pour les sept postes de la tribune, enveloppe du Premier ministre comprise
(`{pays}_gouvernement-pm`, note « Palais du Gouvernement — enveloppe du PM »), et
`salaire_caisse_de()` la résout. On réutilise ce résolveur déclaratif ; écrire une
seconde table de correspondance aurait divergé. Le banc vérifie que **les sept
postes ont une caisse réellement existante en base** : une caisse introuvable,
c'est une tribune morte pour ce poste.

**Aucun montant n'a été modifié.** Les coûts restent ceux du miroir `ordres_couts`
— conférence de presse 2 PA / 0 FR, démenti 2 PA / 0 FR, propagande d'État
3 PA / 500 FR — et le banc les **relit dans le miroir** au lieu de les recopier :
si le game design les change, le banc suit sans être retouché.

### Un trou trouvé en relisant la porte

`p_fn` n'était validé que contre le miroir des coûts. Or le miroir déclare **381
ordres** : un ministre pouvait donc « tenir une conférence de presse » en annonçant
n'importe quel ordre déclaré — `postuler` (2 PA, 0 FR), par exemple — et obtenir
une vraie conférence au nom de l'État. La tribune **déclare désormais ce qu'on peut
y prononcer** (`communications_salles.ordres`), et la porte le consulte.

---

## 2. La conférence de presse

**Ce n'est pas un formulaire de cinq questions.** Rien n'est préparé à l'avance.

1. la communication est publiée, payée, et la conférence s'ouvre dans la **même
   transaction** ;
2. une question arrive ;
3. le ministre répond, **ou refuse de répondre** ;
4. l'échange reste à l'écran ;
5. les journalistes décident alors s'il leur reste un angle.

Entre **une et cinq** questions. Le nombre n'est connu de personne au moment où la
conférence s'ouvre, et **aucun compteur n'est affiché** : un « 3/5 » à l'écran
transformerait la salle de presse en questionnaire.

**Un refus de répondre ne termine jamais la conférence.** La porte serveur ne
touche pas au statut sur un refus : c'est garanti en base, pas par discipline.

**Fermer la pop-up met fin à la conférence, immédiatement.** Il n'y a donc qu'une
seule sortie, et elle est explicite : aucun gestionnaire de clic sur le fond,
aucune fermeture accidentelle. Ce qui a eu lieu avant est conservé, et la fin est
enregistrée comme une **interruption** — une rédaction a le droit de savoir qu'un
ministre a quitté la salle.

### Ce que l'IA reçoit, et ce qu'elle n'a pas le droit de faire

Elle reçoit la fonction publique de celui qui parle, le titre et le texte de la
communication, les questions déjà posées avec les réponses **exactes** et les
refus, et quelques faits publics récents du pays tels que la chronique nationale
les a enregistrés. Rien d'autre : aucune statistique privée, aucun solde, aucune
relation.

Son prompt lui interdit nommément de dire qu'une réponse est vraie ou fausse,
d'accuser quiconque de mentir, d'interpréter un refus, de produire une note, un
score ou une appréciation de crédibilité, d'inventer un fait, de commenter, de
conclure ou de résumer. **Elle formule des questions. Les humains jugent les
réponses.** Aucune colonne de véracité, de crédibilité ni de qualité n'existe dans
les deux tables, et une preuve structurelle de la migration le vérifie à chaque
application.

Si plus aucun angle ne reste, elle répond `FIN` et la conférence se termine
normalement.

### La question est écrite par le serveur, et par lui seul

`conference_question_poser` n'a `EXECUTE` que pour `service_role`. Si le navigateur
pouvait poser la question, il pourrait l'**écrire** — donc choisir ce que les
journalistes demandent, et fabriquer une transcription flatteuse. Le joueur ne
transmet que sa réponse.

**Le minimum d'une question ne dépend pas du fournisseur.** Si l'IA est en panne,
coupée, hors crédit ou hors délai, une question neutre **déterministe** est posée à
sa place : une communication déjà payée ne doit jamais se retrouver sans
conférence. Au-delà de la première question, une panne **ferme la conférence
normalement** — ce qui a eu lieu est conservé, la communication reste publiée, et
rien n'est corrompu.

### Les paroles du ministre sont intangibles

Les deux tables sont sous RLS **sans aucune policy** : aucun joueur n'y écrit, ni
une question, ni une retouche de réponse. Et **aucune porte** ne modifie un échange
déjà renseigné — `conference_repondre` refuse un rang qui a déjà une suite.
Techniquement, la transcription est donc immuable pour tout le monde.

La règle éditoriale qui en découle — **une rédaction peut choisir, citer et
commenter, jamais réécrire les paroles citées** — est **propre à Républia**. Elle
est écrite ici comme une règle de cet empire, et n'est pas posée en invariant pour
les empires à venir.

---

## 3. La trace publique du jour, et la matière du lendemain

**Jour J.** Une phrase factuelle entre dans `chronique_nationale`, écrite **par le
serveur**, dans la même transaction que la communication : « *&lt;fonction&gt; a tenu une
conférence de presse : « &lt;titre&gt; ».* » Elle dit **qu'une** conférence a eu lieu, et
rien de son contenu : ni résumé, ni jugement, ni transcription. Le type a été
raccordé à la collecte du Journal (`api/_journal-collecte.js`) — sans ce raccord la
ligne aurait été jetée en silence comme « type non mappé », donc invisible, ce qui
était exactement le défaut à ne pas reproduire. Le collecteur ne connaît que le
**libellé** ; il ne lit jamais les tables de la conférence.

**Jour J+1 : toute publication automatique de la conférence complète est
abandonnée.** La conférence produit une **source journalistique** mise à
disposition de la rédaction de La Tribune, qui reste souveraine : elle peut ne rien
publier, publier tout ou partie, sélectionner, citer exactement, écrire, interpréter
et commenter librement.

La séparation est stricte, et elle est portée par la porte elle-même :

| ce que le serveur établit | ce qui appartient au journaliste joueur |
|---|---|
| qui a parlé, en quelle qualité, depuis quelle tribune | le titre de l'article |
| ce qui a été déclaré | l'angle |
| les questions réellement posées | la sélection des extraits |
| les réponses **exactes**, les refus, l'ordre | le commentaire et l'appréciation |
| fin normale ou interruption | — |

`conference_matiere()` rend les conférences **closes** du pays — on ne cite pas une
conférence en cours — avec leur transcription complète, **et rien d'autre** : ni
titre, ni angle, ni commentaire. Le droit n'a pas été inventé : c'est
l'appartenance à un groupe de presse (`presse_membres`), le modèle existant. Un
ministre qui demande la matière reçoit `reserve_a_la_redaction`.

Une phrase comme « *le ministre est resté évasif* » est une appréciation **du
journaliste joueur**. Elle n'est jamais générée comme vérité objective par le
moteur, et rien dans le schéma ne permettrait de l'écrire.

---

## 4. Un défaut de la veille, fermé au passage

La migration de la mémoire des mandats, le matin même, avait branché un déclencheur
sur `chronique_nationale` en affirmant : « *elle est ATTESTÉE : aucun navigateur
n'y écrit* ».

**C'était faux.** La table porte une policy `chronique_nationale_ecriture_acteur` —
INSERT ouvert à `authenticated`, avec pour seule condition `acteur_identifie()` — et
elle est massivement écrite **depuis le navigateur** par
`sbEnregistrerEvenementPublic`. Une dizaine de hooks légitimes en dépendent :
organisations, élections, lobbying, immobilier, Tribune.

L'erreur de méthode est nommée : j'avais vérifié quelles **fonctions** citent la
table, pas si un **client** pouvait y insérer. Conséquence réelle : n'importe quel
joueur pouvait fabriquer un « fait national public » et le faire entrer dans la
mémoire présidentielle — ce qui défait la seule règle de cette mémoire.

**La correction porte sur la mémoire, pas sur la chronique.** Fermer l'INSERT client
casserait une dizaine de chemins de jeu légitimes : ce serait une régression hors
périmètre. Le déclencheur est retiré, et la source rejoint
`presidence_memoire_sources_absentes` avec son obstacle réel. `election_presidentielle`
part aussi de la liste active : elle n'était alimentée que par ce déclencheur, et
une source déclarée que rien n'écrit est un mensonge de registre.

La seconde migration du soir corrige une **troisième** ligne du même registre, que
la réextraction du baseline a fait voir : elle affirmait encore que « la chronique
de l'élection est reprise par le déclencheur ». L'obstacle de fond est conservé mot
pour mot — au moment où `election_resultats_consigner` s'exécute, `postes_attribues`
ne porte pas encore le nouveau Président.

---

## 5. Les cinq secrétaires ministériels sont incarnés

Les cinq ministres PNJ ne s'appelaient plus « Le Ministre de l'Intérieur ». Ils ont un nom, un
visage, un caractère, et **un dehors**.

| | nom | caractère | son dehors, et sa borne |
|---|---|---|---|
| Intérieur | **Yvan Danltat** | aigri, sec, attaché à l'autorité ; son premier réflexe devant un problème est la contrainte | le port de plaisance de PSM, où son bateau est amarré — mais il n'est **pas** le référent de PSM |
| Finances | **Alain Théret** | technicien très pointu, parle la langue des économistes sans chercher à impressionner, rit volontiers d'une plaisanterie et revient à son raisonnement | l'investissement locatif — mais il n'**annonce aucun rendement** |
| Justice | **Mathilde Garde** | austère en apparence ; c'est en réalité une inquiétude pour l'avenir, depuis qu'elle est grand-mère | bien manger, et le marché — mais elle n'est **ni médecin ni nutritionniste** |
| Information | **Marie-Eve Beaulieu** | intelligente, sérieuse, parfois rigide ; rejette la séduction et recadre sur la fonction ; sa faiblesse est ses enfants, qu'elle dissimule | la transmission entre générations, l'EHPAD et l'Université — mais elle n'est **référente ni de l'un ni de l'autre** |
| Affaires étrangères | **Jean-Jacques Carlin** | avenant et profondément diplomate, sans être séducteur ; sait dire non à un ministre sans manquer de respect ; pas pacifiste par principe | le football et l'Union Cheminote de Montrouge — mais il ne **connaît pas Montrouge** pour autant |

### Aucune omniscience, et chaque dehors s'arrête net

Chacun reçoit **deux blocs** : son ministère, et son dehors. Le banc vérifie, pour les cinq, que
le prompt contient son propre dehors, sa borne, **et aucun des quatre autres**. Réunir les cinq en
un corpus partagé les aurait rendus interchangeables — exactement ce que la règle de découpage du
Palais présidentiel interdit.

### Trois dehors ont fait apparaître une mécanique absente, et c'est écrit comme telle

C'est le point le plus important de cette passe. **Tout ce que les cinq savent a été relevé dans
le code et les données**, jamais écrit d'après l'intention — et là où la mécanique n'existe pas,
le PNJ le dit au lieu de l'inventer.

- **Le port de plaisance n'a AUCUNE mécanique.** `orders: []` dans ses deux pièces, et data.js le
  dit explicitement : « aucune mecanique portuaire (anneaux, bateaux, navigation, taxes...) :
  volontairement reporte ». Il n'existe donc **ni réglementation du port, ni sortie en mer**.
  Danltat connaît le lieu (le quai, la capitainerie, Patrice Lecap qui la dirige) et dit
  franchement qu'on ne prend pas son bateau pour aller quelque part. Le seul voyage par bateau qui
  existe est le passage **inter-empires depuis le port industriel** : il y envoie Alain Bordage.
- **L'article alimentaire du marché n'a aucun effet de santé déclaré.** Le Croque-Monsieur du
  Marché (céréales + viande + fruits et légumes) ne porte pas d'`effets`, contrairement aux
  recettes PNJ historiques. Mathilde Garde ne promet donc aucun gain de santé au marché. Le seul
  barème établi — prix → effet — ne vaut que pour une référence créée par un **joueur** dans son
  fonds alimentaire, avec **deux paliers seulement** (5–10 FR, 10–15 FR), les tranches au-delà de
  15 FR n'ayant jamais été arbitrées. Elle le dit, plafond compris.
- **Il n'existe aucun PNJ « ancien joueur de football » à Montrouge.** Le référent **social** du
  club y est **Lucas Ténaire**, chef des supporters et cheminot syndicaliste, au siège des
  supporters du Stade Marcel Cazenave. Carlin oriente vers l'homme qui existe, sous son vrai titre.

Les deux autres dehors, eux, portaient une mécanique **complète**, et elle est transmise exacte :
la chaîne locative (terrain → permis → chantier → lots → bail), le **prélèvement nocturne** du
loyer au titulaire **actuel des murs**, l'**ardoise** qui court sans expulser personne, et
l'interdiction de redécouper un lot sous bail ; l'EHPAD Résidence Les Tilleuls avec ses trois
pensionnaires nommés et son `orders: []` assumé — on y va pour écouter — et les deux seules
mécaniques réelles de l'Université, le recrutement de militants (2 PA) et la location de la salle.

### Une opinion n'est jamais une règle du jeu

Danltat préfère la coercition, Théret aime l'investissement locatif, Carlin tient le football pour
un bien commun. Les trois prompts portent la borne explicitement : **« tes opinions ne sont pas des
règles »**, **« c'est un AVIS, pas une recommandation du jeu »**, **« ton désaccord est un avis,
pas un véto »**. Rien n'est programmé derrière : aucun score de sympathie, aucune jauge, aucune
conséquence parce qu'un PNJ exprime un avis — le banc le vérifie sur les cinq.

### La transition PNJ → secrétaire, éprouvée sur les cinq et non lue

La demande était explicite : la mécanique doit valoir **pour les cinq ministères, sans cinq
implémentations ad hoc**. Il n'y en a aucune — `ajusterTitrePnjDePoste` boucle sur tout PNJ portant
`job` + `roleSiPnjTitulaire` + `roleSiPjTitulaire`, et `resteApresPourvoi` court-circuite le filtre
des postes masqués **avant** le test de la liste. Le banc ne le lit pas : il **fait tourner la vraie
fonction** sur les cinq bureaux, dans les deux sens, et compare au titre déclaré dans data.js. Il
vérifie aussi qu'après la prise du poste par un joueur le secrétaire **est toujours là, sous son
nom**, et que son titre ne prétend plus au ministère.

### Un oubli de la première passe, trouvé et corrigé

**Les cinq n'étaient pas inscrits dans `pnj_referents`.** La première passe leur avait donné un
corpus et un rôle de référent sans les déclarer dans la liste fermée qui autorise la mémoire
pédagogique — et `referent_pedagogie_noter` rend `referent: false` **sans rien écrire** pour un
identifiant absent. Les cinq recommençaient donc à zéro à chaque conversation, là où Martial
Bouterin, Tom Hawak et Huguette Papier se souviennent de ce qu'ils ont déjà expliqué. Ce n'était pas
un arbitrage, c'était un oubli. Le registre passe de **22 à 27** référents.

**Le domaine déclaré est celui du ministère, jamais le dehors personnel.** Les inscrire sous « port
de plaisance » ou « investissement locatif » aurait fait de ces cinq les référents officiels de
rayons qui appartiennent à Alain Bordage, Laurent Barre, Marc Hantile et Lucas Ténaire. Une preuve
structurelle de la migration **et** une épreuve du banc l'interdisent désormais.

### Les trois fiches minces périmées ont été retirées

`le_ministre_de_la_justice`, `le_ministre_des_affaires_etrangeres` et `le_ministre_des_finances`
vivaient encore dans `_pnj-personnalites.js` avec un nom générique et aucun savoir. Les y laisser
les aurait gardés **adressables** — c'est la leçon du Général Faure à la caserne et du faux Premier
ministre de ce même Palais. Le banc le vérifie par contre-épreuve sur les cinq anciens identifiants.

---

## Ce qui a été éprouvé

- **`banc-conference-de-presse.sql` — 63 épreuves**, dont les contre-épreuves du
  financement (aucun franc, aucun PA, aucune conférence sur un refus), de
  l'autorité (un joueur authentifié ne peut pas poser une question, un tiers ne
  peut ni répondre ni clore à la place de l'auteur), de l'immuabilité (une réponse
  ne se réécrit pas, même par un UPDATE direct, et la table n'est pas lisible en
  direct), du refus (il ne termine pas la conférence, et on enchaîne après lui), du
  plafond (une sixième question est refusée) et de la matière (un ministre est
  refusé, une conférence ouverte n'est pas livrée, et les champs rendus sont
  exactement ceux qui sont attestés).
- **`banc-conference-presse-client.js` — 70 épreuves** structurelles sur
  `api/conference.js`, `supabase.js`, `plateau-politique.js` et
  `api/_journal-collecte.js` : les interdits de l'IA vivent dans le prompt et non
  dans un commentaire, le repli déterministe existe, une panne ne clôt jamais en
  interruption, le navigateur n'écrit nulle part dans la transcription, la pop-up
  n'a qu'une sortie, aucun compteur n'est affiché, et aucun solde n'est décidé côté
  client.
- **`banc-tribunes-officielles.sql` — 21 épreuves**, maintenu : la conférence
  ouverte par la première épreuve doit être close avant l'épreuve des PA, sinon le
  refus attendu serait masqué par « conférence déjà ouverte » et le banc resterait
  vert **pour la mauvaise raison**.
- **`banc-presidence-memoire.sql` — 22 épreuves** (21 → 22). Deux corrections, et
  les deux étaient des rouges réels : la source `election_presidentielle` a été
  retirée, et l'épreuve de lecture interrogeait encore
  `presidence_memoire_contexte(text,int)`, révoquée la veille au profit de
  `presidence_memoire_mon_pays()`. Une contre-épreuve a été ajoutée : la porte avec
  pays explicite reste fermée au navigateur.
- **`banc-palais-gouvernement.js` — 197 épreuves** (118 → 197). Les cinq portent un nom, leur nom
  se normalise **exactement** en leur identifiant de profil (la même normalisation que `slugPnj`,
  reproduite dans le banc : un accent de divergence rendrait le PNJ muet sans qu'aucune autre
  épreuve ne le voie), leur portrait existe sur le disque, leur ancien identifiant générique **ne
  répond plus**, chaque dehors est présent avec sa borne et **aucun des quatre autres**, les
  mécaniques absentes sont dites absentes, et aucun des cinq ne porte de score de sympathie.
- **`banc-titre-pnj-de-poste.js` — 93 épreuves** (43 → 93) : la vraie `ajusterTitrePnjDePoste`
  tourne sur les **cinq** bureaux, dans les deux sens.
- **`banc-secretaires-referents.sql` — 22 épreuves** : les cinq sont déclarés, la porte pédagogique
  les reconnaît et **compte réellement** les consultations, une seconde visite s'ajoute, et un
  identifiant inconnu — ancienne clé générique ou référent inventé — n'écrit **rien** et le dit.
- **Les 11 contrôles du baseline sont verts**, et les **37 bancs JavaScript** aussi.

### Un défaut de fraîcheur du baseline, trouvé et corrigé

Un contrôle ponctuel — compter les lignes de chaque fichier de seed et les
confronter au compte **réel en base** — a trouvé **six tables du socle PNJ** dont
les seeds dataient d'avant les migrations du Palais présidentiel : la famille, le
métier, les cinq axes et l'institution de la Garde républicaine, quatre fonctions
du Palais et trois référents. Les seeds n'avaient pas été réextraits après ces
migrations. C'est corrigé, et les **71 tables seedées** sont désormais confrontées
une par une au compte réel : **zéro écart**.

---

## Ce qui reste ouvert

1. **La visite de Fred n'est pas terminée.** Ce bâtiment n'est pas clos.
2. **Une fenêtre de collision d'identifiant subsiste**, et elle est antérieure :
   `conf-`, `topic-` et `post-` sont dérivés de l'horodatage en millisecondes, comme
   les sujets du forum le font depuis toujours. Deux auteurs **différents** publiant
   dans la même milliseconde verraient la seconde transaction échouer en entier —
   donc sans rien débiter, et rejouable. Ce n'est pas corrigé ici : c'est la
   convention de la maison, et la changer dépasse ces deux arbitrages.
3. **La réception d'État et le banquet diplomatique présidentiels sont refusés**
   avec `cout_non_declare` : `doReceptionAvecBonus` demande le triplet
   `(reception_etat, 2, 0)`, que le miroir ne déclare pas — il déclare `(2, 1000)`.
   Constaté au Palais présidentiel, qui est CLOS : signalé, non corrigé.
4. **La matière attend son point d'entrée côté joueur, et c'est un arbitrage, pas un oubli.**
   `conference_matiere()` existe, est gardée par le droit de presse, et la porte cliente
   `sbConferenceMatiere` est écrite. Mais **La Tribune n'a aucun outil par lequel un journaliste
   joueur écrit lui-même un article à partir d'une source** : la salle de rédaction ne porte que
   des ordres de **lobbying** — placer un article favorable, étouffer un article, déposer une
   petite annonce. L'arbitrage interdit de construire un nouveau système de journal si les outils
   existent ; ils n'existent pas. Y brancher un ordre neuf demanderait de décider **son coût, sa
   pièce et sa portée** — les trois antennes de La Tribune, ou la seule de Luthécia — soit trois
   décisions de game design qui n'ont pas été rendues. Elles ne sont pas inventées ici.
5. **La chronique nationale reste écrite depuis le navigateur.** Le jour où ses
   écritures publiques passeront par des portes serveur, elle pourra redevenir une
   source de la mémoire présidentielle. L'obstacle est consigné en base.
