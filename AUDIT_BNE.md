# Audit du Bureau National de l'Emploi — 24 octobre 2026

Audit complet en lecture seule, par Claude, à la demande de Fred. Aucun code du
jeu n'est modifié par ce document. Il suit la règle posée par Fred le 24
octobre :

> « Je ne veux plus qu'une seule réalité, celle du serveur. L'écran ne doit
> pas pouvoir afficher autre chose que cette réalité. »

**Sources examinées** : `data.js` (bâtiment, annexes, catalogue des offres),
`plateau-justice-economie.js` (module du Bureau, lignes 13675-13950),
`plateau-personnage.js` (salaire au sommeil), `forum.js` (boutons des mails),
`plateau-chantiers.js` (offres de chantier), `api/cron-minuit.js`, les
fonctions serveur `bne_agir` et `salaire_civil_percevoir`, les catalogues
`offres_emploi_bne` et `salaires_civils_declares` (`baseline/`), l'historique
Git complet, `JOURNAL-SESSION.md`, `historique/` et les issues GitHub.

**Numéros de ligne** : ceux de `main` au 24 octobre, avant la fusion de la #142.

**Limites** : aucune requête sur la base de production, aucun test en jeu. Les
scénarios ci-dessous sont établis par lecture du code et du schéma versionné ;
ils n'ont pas été rejoués sur une base.

---

## 1. Ce que Fred a décidé — tout ce qui a été retrouvé

| Date | Décision | Source | Dans le code aujourd'hui |
|---|---|---|---|
| 6 août | **Modèle économique V1** : un Bureau à Luthécia (accueil + bureau de direction), entre le Centre Artisanal et le Quartier des Ambassades ; une **annexe** dans le Centre d'Affaires de Port-Sainte-Marie et dans celui de Montrouge. | `85bafef5`, `07a626fe`, `ceb9330a` | ✅ les trois guichets existent |
| 9 août | Le Bureau donne un **revenu régulier à un personnage sans poste politique** : inscription, consultation des offres, candidature. | `d2d682b5` (« modèle discuté avec Fred ») | ✅ |
| 9 août | **7 offres**, trois portées : **locale** (une ville), **nationale**, **internationale** (simple étiquette, sans mécanique entre empires). | `d2d682b5`, journal | ✅ |
| 9 août | Salaire **au-dessus du revenu universel (150 FR)** et **en dessous des salaires politiques**. | journal | ⚠️ voir l'arbitrage du 20 sept. |
| 9 août | **Incompatible avec un poste politique**, vérifié à la candidature. **Démission immédiate et gratuite.** | `d2d682b5` | ⚠️ vérifié par l'écran seulement (B5) |
| 9 août | **Règle de conflit de Fred** : une situation déjà active n'est **jamais écrasée automatiquement**. Postuler avec un emploi en cours réserve la nouvelle offre et envoie un **mail d'arbitrage** (garder / prendre). Cumul avec un poste politique : détecté la nuit, mail, **rien n'est tranché d'office**. | `d2d682b5`, journal | ⚠️ le mail d'arbitrage est rejouable (B1) |
| 9 août | **Jean-Lou Zeure**, ancien maire de Luthécia, attend à l'accueil : il est lui-même demandeur d'emploi. Il devient le référent des élections de la quête de carrière (15 août). | `d85c5774`, `7dbb5ea4` | ✅ |
| 9 août | Idée pour plus tard : des **annonces d'emploi entre joueurs**, y compris pour des « jobs » illégaux, distinctes du Bureau officiel. | `63254f94`, journal | non commencé |
| 6 sept. | Le Bureau **annonce les heures de travail des chantiers** de la ville (70 FR/h) : offres calculées à chaque ouverture, jamais enregistrées, sans mention de PA. Pour travailler, il faut être **sur le chantier**. | `d279a3dc` | ✅ (voir B8) |
| 7 sept. | Le Bureau **n'a pas de système de candidatures** : c'est une prise de poste immédiate. Il ne porte donc pas la candidature au poste de commandant. | `plateau-gouvernement.js` 1635 | ✅ |
| 8 sept. | L'inscription est **enregistrée sur le personnage** : avant, le PA payé était perdu au rechargement. | `9ab4e73f` | ✅ |
| 20 sept. | **Chaque salaire est payé par la caisse de son institution**, sans création d'argent. **Seul le revenu universel (150 FR) est créé de rien.** | `historique/.../migration_20260920_salaires_par_caisse.sql` | ⚠️ pas pour le Bureau (B9) |
| 20 sept. | **Postes itinérants non salariés** : secrétaire, commerçant itinérant, conseiller bancaire, hôtesse diplomatique n'ont pas d'employeur, donc pas de salaire. Leur titulaire touche le revenu universel. « Leur rôle fonctionnel et leurs places sont inchangés. » | `historique/registre-supabase/20260920100447_…` | ✅ côté serveur ; ⚠️ affichage (B3, B4) ; aucun rôle (B11) |
| 10 oct. | Les quatre actions du Bureau passent par **une seule fonction serveur** (`bne_agir`) qui verrouille et relit le nombre de places dans un catalogue généré, pas dans ce qu'annonce le navigateur. | `9a19b473` | ✅ |
| 12 oct. | Les offres n'ont **aucun prérequis** et le jeu n'a **aucune profession réglementée**. | `9de8d380` | constat |

Rien n'a été trouvé sur : le rôle du **bureau de direction**, un **directeur**
du Bureau, ou ce que fait concrètement un employé pendant sa journée.

---

## 2. Ce qui fonctionne bien

- **Prise de poste, réservation, arbitrage, démission** : une seule fonction
  serveur, sous verrou. Deux joueurs ne peuvent plus prendre la même dernière
  place.
- **Le nombre de places** est lu par le serveur dans son propre catalogue.
- **Chaque refus est nommé** au joueur (« poste complet », « candidature en
  attente »…), et une panne n'est plus présentée comme un succès.
- **Le salaire est versé par le serveur** (`salaire_civil_percevoir`), une seule
  fois par jour réel, avec retour au revenu universel quand aucun salaire n'est
  déclaré.
- **Le cumul avec un poste politique est détecté par le serveur** chaque nuit,
  avec un seul mail tant qu'il n'est pas traité.
- **Les boutons des mails** sont reconstruits à partir d'une liste fermée : un
  joueur ne peut pas fabriquer un faux bouton.

---

## 3. Constats

Niveaux : **P1** = l'écran ment au joueur, ou le joueur perd quelque chose ;
**P2** = l'écran est seul à décider ; **P3** = mineur.

### P1 — l'écran ment, ou le joueur perd quelque chose

**B1 — Le mail d'arbitrage peut faire perdre son emploi.** Les deux boutons du
mail (« Garder mon poste actuel » / « Prendre le nouveau poste ») restent
cliquables après usage, et le serveur ne vérifie pas qu'une réservation est
encore en attente.
- *Scénario* : je clique « Garder », puis plus tard « Prendre » dans le même
  mail. Le serveur retire mon emploi actuel, ne trouve aucune réservation à
  activer, et répond « ok ». L'écran affiche **« Nouveau poste confirmé »**
  alors que je n'ai **plus aucun emploi**.
- Variante : « Prendre », puis « Garder ». L'écran affiche **« Poste
  conservé »** alors que le serveur m'a donné le nouveau.
- *Cause* : `bne_agir`, actes `trancher_prendre` et `trancher_garder`
  (`baseline/domaines/immobilier-et-territoire/20_fonctions.sql` 467).
- *Correction* : le serveur refuse l'arbitrage s'il n'y a pas de réservation
  en attente (motif nommé), et l'écran le signale.

**B2 — Le mail de cumul affirme une chose fausse.** Il dit : « Votre emploi BNE
reste actif **et payé** en attendant votre décision. » Or le serveur paie
d'abord le poste politique quand il a un salaire déclaré (président, Premier
ministre, les six ministres, maire, adjoint au maire, juge, commissaire).
L'emploi du Bureau n'est alors **pas payé**.
*Où* : `api/cron-minuit.js`, `verifierConflitsEmploiBNE`.

**B3 — La fiche « Dormir » annonce un montant calculé par l'écran.** Le montant
affiché avant de dormir vient de `calculerSalaireDormir` (navigateur), pas du
serveur. Pour un poste itinérant, l'écran annonce **+0**, alors que le serveur
verse **150 FR**. Le libellé dit toujours « salaire universel », même pour un
salaire de poste. Après le sommeil, le message de confirmation, lui, donne le
vrai montant versé.
*Où* : `plateau-personnage.js` 415 et 494.

**B4 — Les offres itinérantes affichent « 0 FR/jour ».** Le joueur comprend
qu'il ne touchera rien, alors qu'il garde son revenu universel de 150 FR.
*Où* : `ouvrirOffresEmploiBNE`.

### P2 — l'écran est seul à décider

**B5 — L'incompatibilité avec un poste politique n'est vérifiée que par
l'écran** (`state.poste`). Le serveur accepte qu'un ministre prenne un emploi
du Bureau. Le cumul est ensuite détecté la nuit, mais le message de B2 est
faux. De plus, **le député** (enregistré à part, dans `poste_depute`) n'est vu
ni par l'écran ni par la vérification de nuit.

**B6 — L'inscription n'est qu'une barrière d'écran.** Elle coûte 1 PA et est
écrite par le navigateur dans la fiche. Le serveur ne l'exige pas pour prendre
un poste. Et on peut s'inscrire plusieurs fois : chaque fois, 1 PA est prélevé,
sans vérifier qu'on est déjà inscrit.

**B7 — La portée locale n'est vérifiée que par l'écran.** Le serveur ne
contrôle pas que le joueur est dans la ville d'une offre « locale » ; seul
l'affichage la masque ailleurs.

**B8 — Les heures de chantier annoncées sont calculées par le navigateur**, à
partir de l'état brut des terrains (`offreBNEChantier`). Le serveur applique ses
propres règles au moment de travailler ; les deux calculs peuvent diverger.
⚠️ Ce code est dans la zone des chantiers et terrains, **en cours chez Codex**
(#135, #139) : ne pas y toucher sans coordination.

**B9 — Trois salaires sont créés de rien, contrairement à la règle du 20
septembre.** Serveur (Hôtel Républica, 200 FR), docker (port de PSM, 220 FR)
et hôtelier (Hôtel du Mineur, 250 FR) sont versés **sans débiter aucune
caisse**. La règle dit pourtant que seul le revenu universel est créé de rien,
et c'est précisément pour cette raison que les postes itinérants ont perdu leur
salaire. Ces trois postes ont, eux, un employeur réel.

### P3 — mineurs

**B10** — Un arbitrage envoyé avec un identifiant d'offre inconnu crée une
entrée vide dans le registre partagé, au lieu d'être refusé.

**B11** — **Un emploi du Bureau ne fait rien d'autre que payer.** Aucun ordre
n'est réservé à un serveur, un docker, une hôtesse… Le texte du 20 septembre
parle d'un « rôle fonctionnel », mais aucun n'existe dans le code.

**B12** — **Le bureau de direction est un décor** : aucun PNJ, aucun ordre,
« accès sur rendez-vous » sans rendez-vous possible. C'est aussi la seule pièce
du Bureau dont l'image vient d'un site externe (Unsplash).

**B13** — **Personne n'explique le Bureau.** Jean-Lou Zeure, seul PNJ de
l'accueil, est le référent des **élections**. Ses limites lui interdisent
l'économie. Un joueur qui demande comment trouver un emploi n'a pas
d'interlocuteur.

**B14** — **Fenêtre des offres à l'ancienne palette brune**, hors charte
ardoise et or (voir issue #143).

**B15** — Le catalogue `data.js` annonçait que l'offre internationale serait
« visible aussi au Quartier des Ambassades » : ce n'est pas le cas. C'est
cohérent avec la décision « simple étiquette ».

---

## 4. Ordre de correction proposé

1. **B1** (perte d'emploi possible) : correction serveur ciblée dans
   `bne_agir`, par migration selon `WORKFLOW-SUPABASE.md`, plus un test qui
   rejoue le double clic.
2. **B2, B3, B4** (textes faux) : corriger le mail de nuit ; afficher dans
   « Dormir » le montant donné par le serveur, ou aucun montant avant le
   sommeil ; afficher « revenu universel » pour les postes itinérants.
3. **B5, B6, B7** : faire vérifier par `bne_agir` l'inscription, le poste
   politique (y compris député, si Fred le décide) et la ville ; rendre
   l'inscription idempotente (pas de 2e PA).
4. **B9** : après arbitrage de Fred.
5. **B14** : avec le chantier de la charte (#143).
6. **B8** : avec Codex, une fois les chantiers stabilisés.

## 5. Questions pour Fred

1. **Salaires des trois emplois locaux (B9)** : payés par la caisse de leur
   employeur (Hôtel Républica, port de PSM, Hôtel du Mineur), et donc rien si
   la caisse est vide, comme les postes politiques ? Ou bien une exception
   assumée ?
2. **Député (B5)** : est-il un « poste politique » incompatible avec un emploi
   du Bureau ?
3. **À quoi sert un emploi (B11)** au-delà du salaire ? Par exemple, un
   serveur qui sert vraiment au restaurant de l'Hôtel Républica, ou une hôtesse
   qui tient le hall des ambassades. Ou bien le salaire suffit-il pour la bêta ?
4. **Bureau de direction (B12)** : un directeur, un PNJ, ou on retire la
   pièce ?
5. **Un interlocuteur pour le Bureau (B13)** : un agent d'accueil PNJ qui
   explique les offres, ou Jean-Lou reste seul ?

## 6. Réponses de Fred et corrections (25 octobre 2026)

Réponses de Fred : 1. « Oui, bien sûr » (salaires payés par l'employeur) ;
2. le député **peut** cumuler ; 3. « les emplois sont là pour donner une vie
au plateau » (direction de design pour B11, pas encore codée) ; 4 et 5 : à
reformuler.

**Corrigé** (migration `20261025030000_bne_corrections.sql`, registre Supabase
20261025010423, éprouvée en transaction annulée sur 10 cas, puis côté écran) :

| Constat | Correction |
|---|---|
| B1, B10 | `bne_agir` refuse de trancher sans réservation en attente (`aucune_reservation`) ou avec une offre inconnue. Un bouton de mail rejoué ne fait plus rien perdre. |
| B2 | Le mail de nuit dit la vérité : un seul salaire par jour, celui du poste politique. Le député n'est plus signalé. |
| B3 | « Dormir » n'affiche plus de montant calculé par l'écran ; il dit qui paie. Le montant réel s'affiche après le versement. Motif `caisse_vide` nommé. |
| B4 | Les offres sans salaire affichent « Non salarié — revenu universel conservé » ; les autres « payés par l'employeur ». |
| B5, B6, B7 | `bne_agir` refuse un emploi à qui a un poste politique (sauf député), à qui n'est pas inscrit, et hors de la ville d'une offre locale. L'écran n'en décide plus. |
| B6 bis | Inscription par `bne_inscrire` : 1 PA, une seule fois. |
| B9 | Serveur, hôtelier et docker payés par la caisse de leur employeur ; caisse vide = pas de salaire. |
| **Nouveau** | Trouvé au banc : `salaire_civil_percevoir` lisait mal le registre du Bureau (enregistré en texte) — **aucun emploi n'était jamais payé**, les employés ne touchaient que le revenu universel. Corrigé. |

Restent ouverts : B8 (chantiers, avec Codex), B11 (donner un rôle aux emplois),
B12, B13, B14 (charte, #143). Point d'attention : les caisses des employeurs
sont maigres (Hôtel du Mineur et port de PSM : 200 FR chacune), un employé y
sera vite non payé.

## 7. Bilan au 25 octobre 2026 (soir)

La formule d'août est remplacée par celle de `GAME-DESIGN-BNE.md`, entièrement
livrée : postes à pourvoir, candidature (1 PA) par le circuit du 25 août, armée,
annonces des joueurs (+ Tribune), virements simples et automatiques, salaire
horaire des chantiers, trois référentes emploi.

Constats de l'audit : B1-B7, B9, B10 réglés ; B11 et B13 réglés par la nouvelle
formule ; B15 sans objet. **Restent** :
- **B8** : les heures de chantier affichées au Bureau sont calculées par l'écran
  (mêmes formules que le serveur, mais deux réalités possibles) ;
- **B12** : le Bureau de direction, vide (question reportée par Fred) ;
- **B14** : la fenêtre « Travailler sur le chantier » garde l'ancienne palette.

**Nouveaux points** :
- le dossier de candidature auprès d'un recruteur **joueur** (fenêtre de 48 h) est
  écrit par le navigateur dans `batiments_etat` (circuit du 25 août, conservé tel
  quel) : seul le PA passe par le serveur ;
- **restes de l'ancienne formule** à retirer : `bne_agir`, `bne_inscrire`, boutons
  de mail « garder / prendre », vérification de cumul de nuit, salaires « emploi »
  et caisses des trois emplois supprimés, ligne « salaire de votre emploi » de
  « Dormir » ;
- les **ouvriers PNJ** des chantiers restent payés 70 FR de l'heure par la nuit,
  quel que soit le taux fixé par le propriétaire ;
- la **caisse du Bureau** reçoit les 30 FR des annonces presse et ne dépense rien ;
- le **caractère** des trois référentes est provisoire.
