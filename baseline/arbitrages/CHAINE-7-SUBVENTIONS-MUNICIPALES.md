# Chaîne 7 — Les subventions municipales

> Arbitrage de game design rendu le **10 octobre 2026**. Ce document dit ce qui a été arbitré,
> ce qui ne l'a pas été, comment la mécanique est construite, et ce qui reste à constater en vrai.
> Il ne propose rien : tout ce qu'il décrit est appliqué et éprouvé.

---

## 1. Ce qui a été arbitré, et ce qui ne l'a pas été

**Arbitré.** Une commune peut subventionner financièrement les organisations éligibles de son
territoire. C'est volontairement un levier politique important. Les clubs de football du
championnat sont éligibles ; les organisations criminelles ne le sont pas.

**Non arbitré, et laissé tel quel.** Les huit autres familles d'organisation
(`politique`, `religieuse`, `syndicale`, `economique`, `loge`, `mediatique`, `sportive`,
`supporters`) sont inscrites en base avec le motif littéral `NON ARBITRE`. Ce n'est pas un refus
de jeu : c'est un état d'attente qu'un futur arbitrage renversera d'un `UPDATE`. La distinction
est dans la donnée — la famille criminelle, elle, porte un refus **explicite**.

**Hors périmètre, par consigne.** `budgets_municipaux.data.indices.associatif` n'est branché à
rien. Il n'a reçu aucun effet nouveau, et les subventions n'en dépendent pas. Il reste lu par le
football (`multiplicateurIndice`) et écrit par personne, exactement comme avant ce lot.

**Distinct, et qui le reste.** La subvention nationale du Ministre des Finances
(`ajusterSoldeCibleFiscale`, `typeCible === 'club_sportif'`) n'a pas été touchée. Commune et État
sont deux leviers politiques différents ; les fusionner aurait supprimé un choix de jeu.

---

## 2. La mécanique, en deux étages

### Étage 1 — l'enveloppe

Une quatrième ligne de `repartitions_budgetaires` par mairie, libellée **« Subventions »**,
`poste_autorite = 'maire'`, **part à 0 % par défaut**. La cascade nocturne
(`budget_municipal_cascade`) y verse la part décidée par le maire, dans une caisse municipale
dédiée : `republic_subventions_capitale`, `_ville_a`, `_ville_b`.

Cette caisse est **cumulative** — `caisse_institution_mouvement` ajoute un delta, il ne remplace
pas un solde — donc l'argent non dépensé reste disponible les jours suivants. Elle appartient à la
**commune**, pas au maire : un changement de titulaire n'y touche pas (épreuve 17 du banc 2).
Et **aucune distribution n'est automatique** : la caisse se remplit, rien n'en sort tout seul.

Le 0 % par défaut suit le précédent du QHS (8 octobre 2026) : la ligne existe, elle est visible,
elle est éditable, et elle ne déplace pas un franc tant que personne ne l'a décidée. Les trois
communes restent donc à 40/40/20/**0** = 100 %, et aucun flux existant n'a changé.

**Ni le stade ni un club n'ont été détournés** pour représenter cette enveloppe. `stade_<ville>`
est un bâtiment municipal avec ses propres dépenses ; la caisse d'un club lui appartient. La
preuve P7 de la migration du registre 624 refuse qu'un bénéficiaire de répartition soit un stade
ou un club.

### Étage 2 — les propositions

Le maire propose des montants **bruts, entiers, ponctuels**. Aucune clé de répartition entre
organisations : autant de propositions que les fonds le permettent. **2 PA** par proposition.

Une proposition **réserve** sans payer. Enveloppe à 5 000, proposition de 1 500 → 1 500 réservés,
3 500 disponibles, et **l'enveloppe est toujours à 5 000** (épreuve 14 du banc 1). L'organisation
a **trois jours** pour répondre.

---

## 3. La réserve n'est pas une colonne

C'est le choix d'architecture central, et il mérite d'être défendu.

La somme réservée n'est **écrite nulle part** : c'est la somme des propositions encore `proposee`,
calculée à la demande. Une colonne l'aurait dupliquée, et une donnée dupliquée finit par diverger —
un incident entre le débit de la colonne et la clôture de la proposition suffirait à perdre de
l'argent ou à en inventer.

Conséquence directe : **accepter, refuser ou expirer libère la réserve par le seul fait de changer
un statut**. Il n'y a aucune écriture financière à faire sur un refus ou une expiration, donc
aucune à rater. C'est ce qui rend l'expiration nocturne idempotente par nature, et c'est pourquoi
elle ne pose **aucune revendication** dans `actes_nocturnes` : la brique existe pour rendre
idempotent ce qui ne l'est pas, et une cérémonie inutile finit par être prise pour une garantie.

---

## 4. Qui peut répondre — et d'où vient la règle

La consigne demandait d'inspecter l'existant avant de coder, et de ne pas inventer une liste de
titres supposés communs à toutes les organisations. **L'inspection a trouvé la réponse, et aucun
arbitrage n'a été nécessaire.**

La responsabilité financière existe déjà dans le jeu, et c'est **un champ, pas un grade** :

| Entité | Qui gère la caisse | Où c'est écrit |
|---|---|---|
| Organisation | `tresorier` s'il est posé, `chef` sinon | `gestionnaireCaisseOrga`, plateau-gouvernement.js:1829 — arbitrage du 7 septembre 2026 |
| Club du championnat | le **président** | `presidents_clubs.data.president` ; `gerer_salaires_club` est déjà « réservé au président » |

Les `grades` des neuf familles d'organisation sont des **paliers d'ancienneté par empire**
(`Junior / Titulaire / Capitaine / Legende` pour la sportive de Républia, `Adherent / Delegue /
Secretaire Adjoint / Secretaire General` pour la syndicale) — jamais des fonctions. **Aucune
famille n'a de grade financier.** Un trésorier existe donc bien, mais comme un champ désigné, pas
comme un échelon.

Le motif de refus réutilise le nom que le jeu emploie déjà : **`pas_gestionnaire_caisse`**.

**Un fait du monde, à dire plutôt qu'à masquer** : `presidents_clubs` est **vide**. Aucun club n'a
de président aujourd'hui, donc personne ne peut accepter une subvention, et une proposition
expirerait au bout de trois jours. Ce n'est pas un défaut de la mécanique — c'est l'état du monde,
et la mécanique le rend visible : `subvention_organisations_locales` rend `peut_repondre: false`,
et l'écran du maire l'avertit **avant** qu'il engage ses 2 PA. (`organisations` est vide aussi,
mais c'est sans effet : aucune famille d'organisation n'est éligible.)

---

## 5. La couche d'éligibilité, et son verrou

La mécanique ne connaît pas « le club de football » : elle connaît des **familles éligibles**,
déclarées dans `subventions_familles` (RLS active, **aucune policy** — un navigateur ne lit pas
cette table et ne peut donc pas inventer une éligibilité).

**Un piège à connaître.** Un club du championnat **n'est pas** une organisation : il vit dans
`clubs_football` (miroir généré), sa caisse est dans `budgets_clubs`, tandis que les organisations
vivent dans `organisations`. Et la famille d'organisation `sportive` porte justement le label
« Club Sportif ». Deux choses différentes sous des mots voisins — d'où la colonne `registre`, qui
dit pour chaque famille **où** se trouve l'entité. Confondre les deux aurait rendu éligible une
association sportive de quartier en croyant parler de l'Olympique.

**Le verrou est structurel, pas disciplinaire.** Un trigger interroge
`subvention_familles_resolues()` — la liste des familles que le **code** sait traiter — et refuse
tout `eligible = true` pour une famille absente de cette liste. On ne peut pas déclarer sans
implémenter, et la base le garantit elle-même (preuve P5 du registre 625 : la tentative de rendre
`loge` éligible est refusée).

**Ajouter une famille, plus tard, demande quatre gestes et pas un de moins** : sa clé dans
`subvention_familles_resolues()`, sa branche d'énumération dans `subvention_entites`, sa branche de
gestionnaire dans `subvention_gestionnaire`, sa branche de crédit dans
`subvention_caisse_crediter`. Puis l'`UPDATE` qui la déclare éligible.

**Une seule fonction énumère les entités**, et c'est délibéré. Il aurait été tentant d'écrire deux
fonctions — une pour lister les bénéficiaires d'une commune, une pour vérifier la domiciliation
d'un seul — mais c'eût été deux branches à maintenir par famille, donc une occasion de divergence :
la liste pourrait montrer un club que le verdict refuse. **La domiciliation vue par l'interface est
celle que la porte applique.**

**La territorialité est stricte, et jamais déduite d'une chaîne.** `clubs_football` porte `pays` et
`ville` en **colonnes**. On ne dérive jamais une ville en découpant un identifiant — la leçon du
chantier municipal, où `republic_mairie_caserne` se résolvait en ville « caserne ».

---

## 6. Les quatre portes, et ce que le navigateur n'apporte plus

| Porte | Qui l'appelle | Ce que le client transmet |
|---|---|---|
| `subvention_proposer(famille, bénéficiaire, montant)` | le maire | **rien d'autre** |
| `subvention_repondre(id, 'accepter' \| 'refuser')` | le gestionnaire | un id et un **verbe** |
| `subvention_enveloppe_lire()` | le maire | **aucun argument** |
| `subventions_recues_lire()` | tout joueur | **aucun argument** |
| `subventions_expirer(pays)` | le cron seul | — (aucun droit client) |

Le navigateur n'apporte **ni** son poste, **ni** sa commune, **ni** l'éligibilité du bénéficiaire,
**ni** le solde de l'enveloppe, **ni** la somme déjà réservée, **ni** le jour de jeu, **ni** le
coût en PA de l'acte. Tout est relu au serveur. C'est la doctrine de la purge : *un paramètre
client qui borne une autorisation est une faille, même derrière un RPC.*

Le client ne nomme jamais un **statut** — il choisit un verbe dans une liste close de deux valeurs,
et le serveur en déduit l'issue. Un client modifié ne peut donc pas écrire `expiree` lui-même.

### Trois décisions de concurrence

**Le verrou de sérialisation est la caisse elle-même.** Deux propositions simultanées sur la même
commune pourraient chacune lire « 5 000 disponibles » et réserver 4 000 : 8 000 engagés sur 5 000.
Le `FOR UPDATE` sur la ligne de l'enveloppe met les deux appels en file **avant** le calcul de la
réserve. Ce n'est pas un verrou ajouté à côté : c'est la ligne d'argent qui sert de verrou.

**Les deux portes verrouillent dans le même ordre** — caisse, puis proposition. L'ordre inverse
dans la porte de réponse aurait produit des interblocages sous charge.

**La première décision est définitive, par compare-and-swap.** L'`UPDATE` porte
`WHERE id = p_id AND statut = 'proposee'` dans sa propre clause : le second appel ne trouve plus la
condition, modifie zéro ligne, et apprend qu'il a perdu la course. Il n'y a pas de « vérifier puis
écrire » — ce serait précisément la fenêtre par laquelle deux acceptations passeraient.

### Deux décisions de robustesse qui méritent d'être dites

**L'`INSERT` précède le paiement, et un refus efface.** Une fonction appelée par PostgREST qui
*retourne* normalement voit sa transaction **commiter** : un refus rendu après une écriture
laisserait l'écriture en base. D'où deux précautions : l'`INSERT` passe en premier pour qu'un rejeu
(index unique partiel) soit refusé **sans avoir facturé 2 PA** — un double-clic ne coûte rien ; et
si le paiement échoue ensuite, la proposition est **supprimée** avant que le refus soit rendu.
C'est le patron de `budget_repartition_fixer`, qui restaure l'ancienne part avant de refuser une
somme au-delà de 100 %.

**Un débit refusé à l'acceptation lève, au lieu de rendre un refus.** La réserve garantit que
l'enveloppe couvre le montant ; un débit refusé là n'est pas un refus métier mais une incohérence.
On lève donc, pour que **toute** la transaction soit annulée — rendre un refus laisserait la
proposition acceptée sans transfert, ce qui est pire.

**L'expiration se constate par tous les chemins.** La passe du 8 octobre 2026 n'a pas tourné. Si
cela se reproduit, une proposition échue resterait `proposee` et immobiliserait de l'argent
indéfiniment. La porte de réponse clôt donc elle-même une proposition dont l'échéance est passée,
au lieu de se contenter de la refuser : la réserve est libérée à la première occasion, par qui que
ce soit.

**Le délai, sans ambiguïté** : proposée au jour J, échéance J+3. Répondable les jours J, J+1 et
J+2 — trois journées — et expirée dès que le jour de jeu atteint J+3. La contrainte
`jour_echeance = jour + 3` vit **dans la table** : aucune ligne ne peut exister avec un autre
délai, et un délai recopié dans chaque porte aurait fini par différer d'une porte à l'autre.

---

## 7. La traçabilité publique

Les trois issues — **ACCEPTÉE / REFUSÉE / EXPIRÉE** — sont publiquement archivées, avec la date, le
maire proposant, l'organisation bénéficiaire, le montant et le statut. Un non-dit de trois jours
laisse donc bien une trace publique : la proposition expirée reste en base, `clos_par` à `NULL` —
**personne ne l'a décidée, le temps l'a close**.

**L'archive est la ligne elle-même.** Aucune table d'archive parallèle n'a été créée : une archive
recopiée est une archive qui peut diverger de la réalité. La policy de lecture ne laisse voir que
les propositions **closes** ; les propositions en attente se lisent par les portes, qui savent qui
est le maire émetteur et qui est le gestionnaire destinataire.

**Pourquoi la publicité s'arrête exactement là.** L'arbitrage impose la publicité des trois issues.
Il ne dit **rien** sur une proposition encore en attente, et rendre publiques les négociations en
cours serait un arbitrage de game design que personne n'a rendu.

**Le nom du bénéficiaire est figé** à la proposition : une archive publique doit rester lisible même
si l'organisation est renommée ou dissoute plus tard. Une archive qui change n'est pas une archive.

**Aucun jugement de jeu n'est porté.** Pas de colonne « favoritisme », pas de score de
clientélisme, pas d'indice — une épreuve de banc interdit structurellement qu'une telle colonne
apparaisse, et une autre qu'un écran emploie ces mots. Le système expose des faits ; les joueurs,
la presse et les opposants interprètent.

---

## 8. L'interface n'a pas inventé de paradigme

**L'Étage 1 n'a demandé aucune ligne de code.** La ligne « Subventions » est une ligne de
`repartitions_budgetaires` comme les trois autres, et `doRepartirBudgetMunicipal` lit ses
bénéficiaires **en base** depuis le 8 octobre. Elle apparaît donc dans l'écran de répartition que
le maire connaît déjà, sans qu'on y touche. L'architecture promettait qu'« ajouter un bénéficiaire
sera une ligne de donnée, pas une modification de cet écran » — c'est vérifié.

**L'Étage 2** ajoute un ordre au Bureau du Maire (`subvention_proposer`, 2 PA, déclaré dans les
deux bureaux) qui ouvre un écran de gestion de l'enveloppe : solde, réservé, disponible réel, part
budgétaire de l'étage 1, propositions en attente avec leurs jours restants, et les organisations
localement éligibles avec un champ de montant.

**La réponse de l'organisation vit dans l'écran du Budget du club**, là où le dirigeant vient déjà
voir sa caisse — plutôt que dans un écran neuf qu'il n'aurait aucune raison d'ouvrir.

**Aucun coût n'est déduit côté client**, et ce n'est pas un oubli : la porte appelle `payer_ordre`
elle-même, avec un coût en dur. Passer **en plus** par `deduireCoutOrdre` prélèverait deux fois.
C'est le patron de `employeur_embaucher` : quand la porte facture, l'écran ne facture pas. L'écran
recopie ensuite `appliquerPaiementServeur(r.paiement)` — l'état client n'est qu'une projection de
ce que le serveur a écrit.

---

## 9. L'ancienne chaîne 7 est résorbée

`verifierSubventionMairie` et son auxiliaire `joursEcoulesDepuisMarqueurISO` sont **supprimés**, et
le marqueur `derniereSubventionJour` n'est plus écrit.

**La preuve a été faite avant de supprimer** : `verifierSubventionMairie` n'avait qu'**un** appelant
(`doConsulterBudgetClub`, un écran de consultation), `joursEcoulesDepuisMarqueurISO` n'était appelé
que par elle, et `derniereSubventionJour` n'était lu par aucun autre fichier, aucun cron, aucun
générateur.

**Pourquoi supprimer plutôt que rebrancher** : garder cette fonction aurait laissé **deux**
mécaniques de subvention municipale en parallèle — l'une fantôme et quotidienne, l'autre délibérée.
La consigne l'interdisait, et elle avait raison : le chemin mort lisait une catégorie « associatif »
qui n'a jamais existé dans une clé `allocation` elle-même supprimée, et son montant valait `0` écrit
en dur. Aucun club n'a jamais touché un franc par là.

**La leçon survit à son code.** Le commentaire de résorption conserve le piège que ce chemin
documentait : un marqueur de journée vivant dans une ligne **partagée**, comparé à `state.day`, un
compteur **propre à chaque personnage**. Un habitant au jour 47 croisant un marqueur posé par un
joueur au jour 3 calculait 44 jours écoulés. Le même motif avait déjà frappé trois autres
mécaniques. La nouvelle chaîne n'a **aucun** marqueur de journée : le jour vient de
`jour_de_jeu_pays()`, au serveur, le même pour tous.

Le banc `banc-chaine-7-inertie.js`, qui tenait le gel, est **remplacé** par
`banc-subventions-client.js`. Un banc qui surveille un gel levé rougirait pour la bonne raison, ce
qui est la pire façon de rougir — le nouveau tient la résorption et la discipline du côté client.

---

## 10. L'état de la preuve

| Dispositif | Compte |
|---|---:|
| Preuves **structurelles** dans les migrations (registres 624→635) | 66 |
| Épreuves **comportementales** SQL, en transaction annulée | **52** |
| Épreuves **du côté navigateur** (`banc-subventions-client.js`) | **34** |
| **Contre-épreuves SQL** par sabotage de fonction en base | 3 |
| **Contre-épreuves JS** par régression de fichier (total du dispositif) | 68 |
| Bancs du dépôt relancés, tous verts | 28 |

### Ce que les bancs établissent, point par point

Maire de la bonne commune → valide. Maire d'une autre commune → `beneficiaire_hors_commune`.
Non-maire → `autorite_insuffisante`. Ancien maire destitué → `autorite_insuffisante`. Famille non
éligible → `famille_non_eligible`. Famille criminelle → refusée **par sa famille**. Famille forgée
par un navigateur → `famille_inconnue`. Montant nul, négatif, ou à centimes → `montant_invalide`.
Montant > disponible → `fonds_insuffisants`. Plusieurs propositions ne peuvent sur-réserver
(1 500 + 3 000 sur 5 000, puis 1 000 refusés). Acceptation → enveloppe 5 000 → 3 500 **et** caisse
du club 0 → 1 500, dans la même transaction. Refus → 3 000 libérés, **aucun** franc déplacé.
Expiration à l'échéance → 1 200 libérés, aucun franc déplacé, `clos_par` NULL. Double acceptation
et refus après acceptation → `deja_close`, et **l'argent ne bouge pas**. Gestionnaire non habilité,
et le maire lui-même → `pas_gestionnaire_caisse`. Changement de maire → enveloppe préservée au
franc. Rejeu d'une proposition → refusé **sans coûter de PA**. Les PA : 10 − 2 − 2 = 6, ni 2, ni 6,
ni 8. Un maire ne peut pas débiter l'enveloppe à la main → `caisse_reservee_au_serveur`. Les
propositions en attente sont invisibles sous la RLS ; les trois issues sont publiques et exactes.

### Ce que les contre-épreuves ont mesuré

Trois sabotages, en transaction annulée, pour vérifier que les épreuves mesurent quelque chose :

1. sans le verdict de territorialité, **le maire de ville_a a subventionné un club de la
   capitale** — la porte a rendu `ok: true` ;
2. sans la soustraction de la réserve, **7 000 FR ont été engagés sur une enveloppe de 5 000** ;
3. sans le compare-and-swap (et sans sa garde amont), **le club a reçu 3 000 FR pour une
   subvention de 1 500** — le double versement est réel, et c'est exactement ce qu'un double-clic
   de président aurait produit.

Les quatre fragments sabotés ont été vérifiés intacts en base après les trois `ROLLBACK`.

### Une limite, nommée plutôt que masquée

La consigne demande que « si plusieurs dirigeants habilités agissent en même temps, une seule
réponse puisse gagner ». Pour la famille `club_football`, la structure du jeu ne désigne qu'**un**
gestionnaire — le président — donc deux dirigeants habilités simultanément **ne peuvent pas
exister aujourd'hui**. Le compare-and-swap est en place quand même, et il est éprouvé par la seule
voie qu'une session SQL unique autorise : une seconde réponse après la première, qui perd. La
concurrence **vraiment simultanée** demanderait deux sessions, ce qu'un banc en transaction ne peut
pas faire ; la structure de l'`UPDATE` est prouvée séparément, par la preuve P2 du registre 629.

### Les bancs n'ont rien laissé en base

Les trois bancs SQL doivent écrire un décor dans des tables de **jeu** — `cycles_electoraux`,
`personnages_donnees`, `presidents_clubs`, `caisses_batiments` — parce que
`poste_est_atteste` refuse un poste de maire qui ne vient pas du dépouillement : on ne peut pas
« se déclarer maire », pas même en `postgres`. Chacun se termine donc par un `RAISE EXCEPTION`
**que les épreuves soient vertes ou rouges**, et le `ROLLBACK` est inconditionnel.

Vérifié après coup : 0 proposition, 0 président, Ben à ses 10 PA et sans poste, enveloppes à 0,
aucun élu forgé, caisse du club à 0. Les deux seuls postes posés en base sont ceux de vrais
joueurs (Arnie au Ministère de la Défense, Vince Kubrick lieutenant).

Cette discipline n'est pas théorique : un banc du 4 octobre 2026 a laissé dans
`fraudes_electorales` une accusation forgée au nom d'un joueur réel, restée six jours en
production. Il avait commité.

---

## 11. Le miroir des coûts : une ligne ajoutée, pas un miroir régénéré

`payer_ordre` est fail-closed : un ordre absent de `ordres_couts` est refusé (`ordre_inconnu`).
`subvention_proposer` coûte 2 PA, donc il traverse cette vérification — contrairement aux ordres
gratuits, que `deduireCoutOrdre` n'envoie jamais à `payer_ordre`.

Le dépôt **interdit explicitement** de régénérer ce miroir : `referentiels.json` porte deux
divergences déclarées (`ordres_couts/posee` et `ordres_couts/base`), fermées par le lot 4D, avec la
mention « *Ne pas regenerer ce miroir [...] Faire concorder une empreinte en touchant au contenu,
c'est fabriquer le resultat du controle* ». Une seule ligne a donc été insérée —
`('subvention_proposer', 2, 0)` — et la preuve P3 du registre 631 vérifie que le miroir passe de
405 à **406** lignes, sans qu'aucune autre ait bougé.

Insérer un ordre neuf n'est pas réparer le miroir : c'est déclarer le coût d'un acte qui n'avait pas
de coût parce qu'il n'existait pas.

---

## 12. Les deux reliquats techniques, fermés le même jour

### Les droits d'écriture clients sur `terrains_etat` et `plaintes_en_cours`

Les portes des 9 et 10 octobre avaient retiré ces écritures du navigateur, mais les droits étaient
restés ouverts **volontairement** : le précédent du dépôt (registre 584) exige de prouver d'abord,
sur le code **déployé** et octet par octet, qu'aucun joueur n'en a plus besoin. Fermer avant la
preuve, c'est casser le jeu en croyant le protéger.

**La preuve, en quatre points.**

1. **Le déployé est le dépôt.** Les 47 scripts chargés par `plateau.html` en production ont été
   téléchargés — 6 533 336 octets — et les six fichiers qui portaient les écritures sont
   **identiques par empreinte** à leur version poussée : `supabase.js`
   `730c83728bcf51896a3f87ce031574e5`, `plateau-justice-economie.js`
   `cf8e75f227a92f342f5a36a518398779`, `plateau-politique.js` `56f54bd5f29024606fbc569ff0023a88`,
   `plateau-pnj.js` `88a4928d5270174ac0cb18f88cba6413`, `plateau-immobilier.js`
   `dd7e8427ac39431bf79820780f2b952d`, `plateau-personnage.js`
   `532665c52a40266b16bf8ff334ad6131`. Ce n'est donc pas « le dépôt devrait aller », c'est « ce qui
   tourne ne le fait plus ».
2. **Chaque mention classée.** 24 occurrences de `terrains_etat` et 4 de `plaintes_en_cours` dans
   le déployé. Toutes sont des **commentaires**, sauf six `sbGet` — des lectures.
3. **Aucune écriture générique ne peut les viser.** Les helpers d'écriture reçoivent un nom de
   table, il fallait donc vérifier que tout *appel* nomme sa table par un littéral : les cinq
   occurrences de `sb*(table` sont les **définitions** des helpers (`sbInsertVerdict`, `sbUpsert`,
   `sbPatcherBlob`, `sbInsert`, `sbDelete`), pas des appels, et aucun littéral de table d'un appel
   d'écriture ne vaut l'une de ces deux.
4. **Aucun contournement par `fetch`.** Les appels REST directs visent `rpc/rattacher_personnage`,
   `personnages`, `presences` et `rpc/<fn>` ; les trois écritures HTTP des écrans visent
   `/api/assemblee-seblex`, `/api/journal-interview` et `/api/chat` — des fonctions serverless.

**Ce qui est révoqué** : `INSERT` et `UPDATE` à `authenticated` sur les deux tables, et leurs
quatre policies d'écriture. **Ce qui est conservé** : le `SELECT` d'`authenticated` sur les deux et
celui d'`anon` sur `terrains_etat` — six lectures en dépendent, et les fermer serait une régression
et non un durcissement ; plus tous les droits de `service_role`, dont la passe de minuit a besoin.

**Pourquoi les policies partent aussi.** Sans droit, une policy d'écriture est inerte — mais
**trompeuse** : elle décrit une surface qui n'existe plus, et un `GRANT` réaccordé par erreur la
rouvrirait en silence. C'est exactement le piège des policies dormantes.

**Et la vérification d'après coup**, celle qui comptait vraiment : les portes écrivent-elles
encore ? Les bancs SQL de la justice et du terrain ont été relancés **après** la révocation —
`affaire_transmettre` crée toujours ses affaires, 18 épreuves vertes sur la seule transmission, et
une sonde dédiée a montré **10 portes sur 10** qui écrivent encore.

### L'effet de bord que la révocation a produit, et sa réparation

Quatre bancs du dépôt sont devenus **structurellement inexécutables** :
`banc-etat-terrain-1.sql`, `banc-etat-terrain-2.sql`, `banc-cycle-plaintes-2.sql`,
`banc-cycle-plaintes-3.sql`.

La cause est instructive. Ces bancs ne contiennent pas que des épreuves : ils contiennent des
**contre-épreuves** qui rejouent délibérément l'ancien chemin client — un `INSERT` ou un `UPDATE`
direct sous `authenticated` — pour prouver que le banc n'est pas creux. Ce chemin était bloqué par
la **policy** et renvoyait proprement 0 ligne, ce que le banc lisait avec `ROW_COUNT`. Il est
maintenant bloqué par le **droit** : il lève `42501` et abat le bloc `DO` entier. Le banc ne peut
plus se terminer — et pourtant rien n'y accusait le serveur.

Les huit contre-épreuves concernées ont été transformées : l'écriture d'origine est conservée mot
pour mot à l'intérieur d'un `BEGIN … EXCEPTION WHEN insufficient_privilege … END`, et l'épreuve
vérifie le refus — plus, quand c'était mesurable, que la donnée n'a pas bougé. **`WHEN others` est
proscrit** : il ferait passer l'épreuve sur une faute de frappe ou une table absente, et elle ne
mesurerait plus rien. Les quatre comptes d'origine sont conservés (15, 17, 17, 16) : aucune épreuve
n'a été retirée pour faire passer un banc.

La mesure est désormais **plus forte** qu'avant : un refus de privilège est absolu, là où un refus
de policy dépendait d'un prédicat. Deux nuances sont consignées dans les fichiers : l'épreuve 15 de
`banc-etat-terrain-1` vivait du gel que sa contre-épreuve posait — le gel est maintenant posé en
`postgres` comme **décor**, et le commentaire dit que ce n'est pas la preuve ; et l'épreuve 17 de
`banc-cycle-plaintes-2` ne mesure plus la fermeture du laissez-passer `rp.verdict_interne` par ce
chemin, puisque le droit arrête l'écriture avant le trigger — elle mesure une garantie plus large,
et l'en-tête renvoie au banc qui conserve l'autre mesure.

### `zz_snap_cka_membres`, et une dette qui disait faux

La dette annonçait « artefact de banc, **vidée** mais pas supprimée ». C'était faux, et la mesure a
dit pourquoi : la table contenait **101 lignes**, et la purge du registre 623 en avait retiré **une
seule** — un policier de banc. Avoir purgé le résidu avait fait croire que la table entière l'était.

**Leçon générale : une purge partielle laisse croire à une purge totale.** Vérifier le compte en
base avant d'agir sur la foi d'une dette.

Les cent lignes restantes étaient un instantané des soldats PNJ de la compagnie
`compagnie-republic-1790116175239`, pris les 26-27 septembre. Avant de supprimer, trois mesures :
les 100 identifiants existaient **tous** dans `pnj_membres` — aucun PNJ n'avait disparu ; mais **24
divergeaient** de leur état courant, donc la table portait une information réelle ; et la compagnie
compte aujourd'hui 96 membres. Les cent lignes sont donc **archivées dans
`purges_residus_bancs`** — le mécanisme de réversibilité du registre 623 — dans la **même
transaction** que le `DROP`.

**La première tentative a échoué sur sa propre preuve** : elle comptait « 100 archives sous ce
nom » et en a trouvé 101, à cause de la ligne du registre 623. Rien n'avait été appliqué. C'est
cette preuve qui a révélé la ligne préexistante.

**Le `DROP TABLE` est passé sans déclencher la demande de confirmation MCP** qui avait bloqué la
migration 622 : le blocage n'est donc pas systématique.

---

## 13. Ce qui reste à constater en vrai

**Aucune subvention n'a encore été proposée par un joueur.** Comme les quinze portes du 9 octobre
et les vingt-trois du 10, cette chaîne est éprouvée par des bancs et par des contre-épreuves, mais
**personne ne l'a encore empruntée** — c'est-à-dire avec une vraie identité, une vraie RLS et une
vraie latence.

Trois choses à voir pour de vrai, dans l'ordre où elles arriveront :

1. **un maire dote la ligne « Subventions »** d'un pourcentage, et la cascade de minuit verse
   réellement dans l'enveloppe — la cascade a déjà tourné le 10 octobre avec `{"verse": 320,
   "villes": 3, "conserve": 80}`, mais sur trois lignes, pas quatre ;
2. **un club élit un président**, sans quoi aucune proposition ne peut être acceptée ;
3. **une proposition expire** par la passe de minuit — la tâche `subventions_expirees` est posée,
   elle n'a jamais eu de sujet.
