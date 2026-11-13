# Appartements populaires : option premium, colocation, sommeil, matériel

Décisions de Fred, session du 12/11/2026 au soir (questions de Claude une à une). **Codé le 12/11 au soir**
après le feu vert de Fred (voir « Ce qui est codé » en fin de document).

## Périmètre : le logement populaire

- **Tout logement populaire** : logements sociaux de Montrouge ; à Novomirsk, l'immeuble de la pharmacie
  (V14), les Logements du Marché et les Logements des Quais de Sovarka ; à Starovka, le Baraquement
  Sibirsk-9 ; les logements des immeubles collectifs construits par les mairies de Sovarka. Krasnov n'a
  pas encore d'immeuble de logements. En cas de doute sur un logement, demander à Fred.
- Les suites et chambres d'hôtel, la Résidence impériale et le Pavillon gardent leurs propres règles.

## Sommeil : +1 PA

- Dormir dans un appartement populaire, en Républia comme en Sovarka, donne **+1 PA par nuit**
  (aujourd'hui ces logements ne donnent que moral et santé : +3/+4 petit, +5/+7 grand).
- En version gratuite, on dort dans la pièce unique de l'appartement.
- En premium, on dort dans une **chambre** (+1 PA) ; dormir au **salon** ne donne pas le bonus.

## Option premium : purement cosmétique

- **Aucun avantage d'indices ni de PA** : elle ajoute des pièces, des décors par IA et des emplacements
  de matériel (ce dernier point n'est pas un avantage de confort : les gains restent identiques).
- **Attachée à l'appartement** : celui qui part la perd, le suivant hérite des pièces et des décors.
- Gratuite pendant la bêta, comme toutes les options premium ; prix fixé lors de la session premium.
- **Pièces** : version gratuite = une seule pièce (salon et chambres représentés dans la même image) ;
  premium = vraies pièces séparées : **petit appartement = salon + 1 chambre, grand = salon + 2
  chambres**. L'image du salon est l'image actuelle de l'appartement ; ses portes de chambres (une ou
  deux, visibles sur les images de Fred) mènent aux chambres. Les onglets des pièces changent en
  conséquence quand on entre dans son appartement premium.
- **Chambres** : de vrais lieux, chacun avec ses présents ; images de chambres à venir (Fred).
- **Décors par IA**, sur le modèle de l'atelier du Commerce Premium (une génération et deux retouches
  par pièce ; nouvelle image 0,99 € après la bêta) : 2 décors pour un petit appartement (salon, chambre),
  3 pour un grand (salon, deux chambres). Les images de départ restent volontairement modestes, pour
  donner envie de décorer.
- **Qui décore** : le titulaire seul (ni marié ni colocataire) décore tout ; en colocation, le
  colocataire décore **sa chambre uniquement** et le titulaire **sa chambre et le salon** ; des époux
  peuvent décorer **toutes les pièces**.

## Matériel (emplacements)

- **L'armoire à souvenirs ne prend plus qu'un emplacement** (au lieu de 3), partout dans le jeu. Son
  avantage reste lié à la pièce où elle est installée (il faut y dormir).
- Version gratuite : **3 emplacements** pour un petit appartement, **5** pour un grand (somme des pièces
  représentées : 1 au salon, 2 par chambre).
- Premium : **3 au salon et 6 par chambre**, répartis par pièce (petit = 9, grand = 15). Le matériel
  derrière la serrure d'une chambre est protégé par elle.
- On installe dans une chambre : armoire à souvenirs, ordinateur et autres matériels informatiques.

## Serrures et accès

- Entre dans une chambre qui en a la clé : chaque chambre peut recevoir sa serrure (mécanique des
  serrures existante, serrure vendue avec une clé).
- Exemple de Fred : deux PJ partagent le salon (chacun a une clé du salon), chacun pose une serrure sur
  sa chambre et en garde seul la clé.

## Colocation

- **Grands appartements uniquement**, avec ou sans premium.
- Le titulaire du bail désigne **un seul** colocataire, pour **2 PA**. Le colocataire a la jouissance
  légale de l'appartement : il y dort (+1 PA), pose une serrure, installe du matériel. En premium, il
  reçoit la deuxième chambre.
- Loyer : reste au titulaire ; le partage se règle entre les PJ, hors code (« ils se débrouillent »).
- **Fin** : le titulaire retire son colocataire pour 2 PA ; le colocataire peut partir de lui-même
  (gratuit, sauf avis contraire de Fred). Celui qui perd sa place a 48 h pour désinstaller son matériel,
  faute de quoi il revient au titulaire du bail.
- **Départ du titulaire** (départ, bail perdu, mort du personnage) : le colocataire est **prioritaire**
  pour reprendre le bail. Il reçoit un courrier « Reprendre le bail », valable 48 h ; s'il accepte, le
  bail passe à son nom (même loyer, même option premium) et il peut désigner un colocataire ; s'il
  refuse ou ne répond pas, il a 48 h de plus pour partir avec son matériel.

## Couples mariés

- Exception : des époux ont **tous deux** le +1 PA, quel que soit le nom sur le bail et quelle que soit
  la taille de l'appartement, sans désignation.
- Dès le mariage, le conjoint a **automatiquement la jouissance complète** de l'appartement (matériel,
  serrure, sommeil, décors de toutes les pièces).

## Ce qui est codé (Claude, 12/11/2026 au soir, branche `claude/appartements-populaires-20261112`)

Serveur : migration `20261112221500_appartements_populaires` **appliquée** ; banc annulé vert
`outils/bancs/banc-appartements-populaires-20261112.sql` (8 étapes). Écran : `plateau-appartements.js`,
catalogue `i18n/appartements-resources.js` (9 langues), test `outils/bancs/test-appartements-populaires-20261112.mjs`.
Décors : fonction serveur `logement-decoration` (déployée), même atelier que le Commerce Premium.

- **Sommeil** : `pa_repos_nocturne` ajoute +1 PA (titulaire, conjoint, colocataire) dans la pièce unique en
  gratuit, dans une chambre en premium ; le salon premium ne donne rien. Le serveur rend aussi le moral et la
  santé du logement, appliqués par l'écran (plus aucun calcul local).
- **Premium** : ordre « Mon logement » → « Activer l'option premium » (titulaire ou conjoint), gratuit en bêta,
  attaché à l'appartement (table `logements_premium`). Chambres `<appartement>_chambre_1/2` : onglets visibles
  seulement dans l'appartement premium, entrée refusée par le serveur sinon. Images de chambre raccordées pour
  les Logements du Marché et des Quais (et la V14, qui reprend les images des Quais) ; ailleurs, fond neutre
  en attendant les images de Fred.
- **Emplacements** : 3 / 5 en gratuit, 3 au salon et 6 par chambre en premium. L'option « bureau » est refusée
  dans un appartement populaire.
- **Colocation** : désigner (2 PA) / retirer (2 PA) par le titulaire, départ gratuit du colocataire ; matériel
  laissé plus de 48 h → au titulaire du bail (et non plus à la commune). Départ du titulaire (quelle qu'en soit
  la cause : bail supprimé) → offre « Reprendre le bail » de 48 h au colocataire, attribution par la mairie
  bloquée pendant ce temps ; s'il accepte, même loyer, même option premium, sa serrure de chambre reste valable.
- **Époux** : jouissance complète automatique (matériel, serrure, sommeil, décors de toutes les pièces).
- **Serrures** : une serrure de chambre se rattache au bail de l'appartement ; elle tombe si son poseur perd la
  jouissance de la pièce (colocataire parti, divorce).
- **Correctif** : les 8 logements du Baraquement Sibirsk-9 (Starovka) n'existaient pas côté serveur (clé sans
  la ville) ; clé corrigée, logements créés.

### Choix de Claude, à relire par Fred

1. Le **moral et la santé** du logement suivent la même règle que le +1 PA : le colocataire et le conjoint en
   profitent aussi (avant, seul le titulaire) ; en premium, seulement en chambre. **Validé par Fred (13/11).**
2. L'option premium peut être activée par le **titulaire ou son conjoint**, pas par le colocataire.
   **Modifié par Fred (13/11)** : le colocataire peut aussi l'activer, mais seulement avec l'acceptation du
   titulaire du bail. Non codé. Procédure (Fred, 13/11) : le colocataire clique « Demander l'option premium »
   (le bouton et sa confirmation lui disent explicitement que le titulaire du bail doit accepter) ; le titulaire
   reçoit un courrier « Accepter / Refuser », valable 48 h ; sans réponse, la demande tombe.
3. Pour désigner un colocataire, le titulaire doit **être dans l'appartement** ; impossible de désigner son
   conjoint ou quelqu'un déjà colocataire ailleurs. En premium, la **chambre 2 doit être vide de matériel**
   (elle revient au colocataire), pour qu'aucun objet ne soit perdu en silence. **Validé par Fred (13/11).**
4. Reprise du bail : **pas de loyer prélevé à la reprise** (le bail continue, prochaine échéance normale). **Validé par Fred (13/11).**
5. Décors : description écrite seulement, **sans images de référence** (l'atelier du commerce en accepte 5).
   **Modifié par Fred (13/11)** : comme au commerce, le joueur peut fournir jusqu'à **5 images de référence**, en plus
   de l'image de base de la pièce et de la description ; le surcoût OpenAI sera répercuté dans le prix de l'option
   premium (session premium). Non codé.
6. **Chambres premium : seulement les immeubles dessinés** (Montrouge, Novomirsk V14/V16, Starovka). Pour les
   lots sociaux des terrains de Montrouge et les logements des immeubles des mairies de Sovarka, le +1 PA, la
   colocation, les époux et les emplacements marchent, mais l'option premium affiche « pas encore disponible »
   (leurs pièces sont créées à la volée : chantier à part si Fred le veut).
   **Modifié par Fred (13/11)** : l'option premium doit concerner **tous les types de logements**, y compris ceux
   construits en cours de partie (lots des terrains, immeubles des mairies de Sovarka) : son but est de rapporter
   de l'argent, et elle reste purement cosmétique (+1 PA avec ou sans premium, pas de P2W). Chantier à coder :
   chambres créées à la construction, images génériques en attendant. Non codé.
7. Une chambre sans serrure fermée est **ouverte à tous**, comme le salon. **Validé par Fred (13/11)**, avec rappel :
   deux niveaux de serrure se cumulent — une serrure sur l'entrée de l'appartement (clé partagée par les
   occupants), puis une serrure par chambre, si bien que le second occupant n'entre pas dans la chambre de l'autre.
   À vérifier par un banc lors du prochain chantier.

### Écart relevé (à trancher par Fred)

- **Armoire à souvenirs** (corrigé le 13/11) : elle n'occupe déjà qu'**un** emplacement côté serveur ; rien à changer.
  Les règles existent (onglet Règles, Économie) : douze souvenirs exacts par armoire, et **une collection complète
  procure un avantage de confort au personnage qui dort en présence de son armoire** (sans cumul entre armoires).
  Mais ni le dépôt des souvenirs dans l'armoire ni cet avantage ne sont codés, et **la valeur de l'avantage n'est
  écrite nulle part** : question posée à Fred le 13/11.
- **Décision de Fred (13/11/2026, 0 h 13)** : une collection complète donne **+1 PA** au personnage qui dort en
  présence de son armoire (même pièce), sans cumul entre plusieurs armoires complètes. **Non codé** : attend le feu
  vert de Fred, avec le dépôt des souvenirs dans l'armoire (règles déjà écrites, mécanique absente).
- **Décision de Fred (13/11/2026, 0 h 15)** : le +1 PA de l'armoire **se cumule** avec le +1 PA de l'appartement
  (titulaire dans sa chambre avec son armoire complète = +2 PA). Non codé.
- **Décision de Fred (13/11/2026, 0 h 20)** : « un emplacement au lieu de 3 » vaut **dans les deux sens** : 1 emplacement
  de matériel dans un local (déjà le cas côté serveur) **et 1 place dans l'inventaire** au lieu de 3 (encombrement
  aujourd'hui 3 à la fabrication et à l'achat, Scierie Guy Tarembois). Inventaire : non codé.
- **Décision de Fred (13/11/2026, 0 h 28)** : déposer ou retirer un souvenir dans l'armoire est **gratuit** (0 PA). Non codé.
- **Décision de Fred (13/11/2026, 0 h 30)** : un visiteur qui retire un souvenir d'une armoire non fermée à clé ne commet
  **pas d'acte illégal** (pas de jet, pas de trace de crime) ; le propriétaire peut **porter plainte pour vol**, et c'est
  **le juge PJ qui tranche** (parcours de plainte et de tribunal existants). Non codé.
  Précision (0 h 31) : **aucun relevé propre à l'armoire** ; le dépôt de plainte existant suffit (contre X ou contre une
  personne).
- **Décision de Fred (13/11/2026, 0 h 33)** : l'armoire **n'est pas codée maintenant** : elle reste inutilisable tant que
  les **douze villes** de sa liste n'existent pas. Les décisions ci-dessus sont seulement consignées.
