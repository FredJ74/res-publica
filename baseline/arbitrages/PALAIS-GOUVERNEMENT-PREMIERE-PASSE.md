# Palais du Gouvernement — première passe (visite non terminée)

*11 octobre 2026. **Ce bâtiment n'est PAS clos** : la visite fonctionnelle de Fred
est en cours. Ce document enregistre ce qui a été décidé et livré, et ce qui reste
ouvert — il ne prétend pas faire le tour de la maison.*

---

## Ce qui a été livré

### Le faux Premier ministre a disparu, de la pièce **et** de la table

Un PNJ « Premier Ministre » siégeait dans la Salle du Conseil. Il n'était ni
référent — il n'expliquait rien — ni titulaire : le poste `pm` est pourvu par
nomination présidentielle, et un PNJ assis là laissait croire que le gouvernement
était déjà dirigé.

Il est retiré, **et son profil serveur avec lui** : un PNJ retiré de la pièce mais
laissé dans la table reste adressable, donc vivant. C'est la leçon du Général
Faure à la caserne. La Salle du Conseil n'a plus d'occupant, et c'est normal —
c'est un lieu de réunion, pas un poste.

Le référent de la fonction est désormais **Éric Stricted**, chef de cabinet, dans
le bureau du Premier ministre. Il connaît les coûts réels (nommer 2 PA, révoquer
1 PA, vote de confiance 3 PA), il sait que le Premier ministre est **nommé et
révocable**, et il n'a aucun pouvoir du poste.

### Les ministres PNJ deviennent secrétaires ministériels

Cinq ministères reçoivent la **mécanique générique** déjà posée pour Tom Hawak à
la caserne et pour le Président PNJ à l'Élysée : `resteApresPourvoi` plus deux
libellés déclaratifs. **Trois champs de données, aucun code par ministère.**

| Ministère | Titre quand un joueur tient le poste |
|---|---|
| Intérieur, Finances, Justice, Information, Affaires étrangères | « Secrétaire ministériel de … » |
| Défense | **inchangé** — Martial Bouterin garde ses deux libellés d'origine, au caractère près |

Deux de ces PNJ — Intérieur et Information — n'avaient **aucun profil serveur** :
ils étaient muets au sens propre, pas seulement sans corpus.

> **Chaque secrétaire ne connaît que son ministère.** Donner deux domaines à l'un
> rendrait les autres décoratifs. Le banc vérifie l'exclusion dans les deux sens :
> le secrétaire des Finances connaît le droit de préemption et **ignore** le
> couvre-feu de l'Intérieur.

### La salle de presse : trois défauts superposés, fermés

Fred a constaté qu'un ordre « Conférence de presse » refusait de publier avec
« Seul le Président peut publier depuis la tribune présidentielle ».

| Défaut | Fermeture |
|---|---|
| le verrou portait sur le **mauvais poste** — `exigerPoste('president')` en dur, quelle que soit la salle, alors que `data.js` déclare les ordres du Gouvernement avec `requiresPost: true`. **Aucun ministre n'a jamais pu s'exprimer** | un **registre** (bâtiment, pièce) → postes admis. L'Élysée reste au Président, le Gouvernement s'ouvre au Premier ministre et aux sept ministres |
| le verrou était **client** : une console suffisait à publier au nom du Gouvernement sans tenir de poste | l'autorité est relue en base par `acteur_poste_courant()`, dans une porte serveur |
| rien n'était **atomique** : les PA partaient, puis le sujet et le message par deux appels REST séparés | autorité, prélèvement, sujet et message dans **une seule transaction** |
| l'éditeur était un `<textarea rows="6">` à `resize:none`, sans images | `renderRichEditor` — le **même composant** que les sujets du forum : titres, alignements, listes, couleur, séparateur, emojis et **images** |

**Le Président n'est pas admis à la tribune du Gouvernement**, et ce n'est pas un
oubli : il a la sienne. La frontière joue dans les deux sens — un ministre est
refusé à l'Élysée.

### Les huit assets

16,91 Mo de PNG → **1,32 Mo** de WebP, dimensions identiques au pixel. Les PNG ont
quitté le dépôt (originaux sauvegardés hors dépôt) : le dépôt ne garde pas deux
versions actives du même asset. Le banc vérifie que chaque WebP référencé
**existe réellement sur le disque** — une référence n'est pas une image, et un
WebP cité mais absent est un 404 silencieux en production.

### La Garde du hall utilise bien la couche générique

Vérifié en base : `garde_republicaine_postes` déclare
`(republic, palais-gouvernement, hall)` et un garde permanent y est **en faction,
armé**, avec ses caractéristiques d'élite. Aucune règle n'a été dupliquée.

Le décor l'appelait encore « Garde Martineau » : il est aligné sur le Garde
républicain, parce que deux noms pour un seul homme laissaient croire à un décor
de plus — alors que celui-ci se neutralise, laisse tomber son arme et intervient
contre un recherché.

---

## Ce qui reste ouvert

### Un écart de coût **consigné et non tranché**

L'arbitrage veut que la communication gouvernementale soit financée par le
**budget du ministère de l'Information**. Aujourd'hui `payer_ordre` prélève les
500 FR de la propagande sur la **poche** du responsable. Les deux ne disent pas la
même chose.

**Aucun montant n'a été modifié.** On ne tranche pas un tarif dans une migration
d'autorité : l'écart est écrit dans la note du registre `communications_salles`,
et il attend un arbitrage — pas un correctif.

### Deux mécaniques arbitrées mais non implémentées

**Les questions des Journalistes accrédités.** Le PNJ collectif est en place, avec
son image, et Corinne prévient le visiteur qu'ils posent des questions et qu'un
refus de répondre est rapporté. Mais le mécanisme — 1 à 5 questions, réponse
libre, refus traçable, **aucun contrôle de véracité** — n'est pas écrit. Ce n'est
pas une correction : c'est un sous-système neuf, et une version à moitié câblée
produirait des questions sans conséquence ou des refus sans trace.

**La publication J / J+1.** À J, une entrée courte doit paraître dans le journal
d'événements **individuel** de chaque joueur concerné ; à J+1, la conférence doit
être reprise par le journal du jour avec ses questions, ses réponses exactes et
ses refus. Aujourd'hui `addJournalEntry` n'écrit que dans le journal de
**l'auteur**, et il n'existe aucune table de journal par joueur côté serveur :
diffuser à tous les joueurs demande un mécanisme qui n'existe pas encore. Le
pipeline du journal du jour, lui, existe et sera le point de raccordement.

Ces deux points ne mettent **aucune donnée en jeu** : ni argent, ni autorité, ni
triche possible.

### Ce qui n'a pas été visité

Le reste du bâtiment n'a pas été audité : les archives (au-delà du portrait de
Legrand), les ordres de chaque ministère pris un par un, et le hall hors de
l'accueil. La visite de Fred continue.
