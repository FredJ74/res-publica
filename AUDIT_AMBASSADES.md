# Audit des ambassades — 24 octobre 2026 (version 2)

Audit en lecture seule, par Claude, à la demande de Fred. Aucun code du jeu
n'est modifié par ce document.

- **Version 1** (après-midi) : état du code.
- **Version 2** (soir) : ajout du **game design retrouvé** dans l'historique et
  relecture complète sous la règle posée par Fred le 24 octobre :

  > « Je ne veux plus qu'une seule réalité, celle du serveur. L'écran ne doit
  > pas pouvoir afficher autre chose que cette réalité. »

**Sources examinées** : les 2 230 commits de `main` (messages et différences),
`JOURNAL-SESSION.md`, `AUDIT_INDICES.md`, `baseline/arbitrages/`,
`historique/`, l'audit des ordres `.scratch/audit-ordres-luthecia.csv`, les
143 issues et pull requests GitHub, les profils PNJ (`api/`), le schéma et les
règles d'accès de la base (`baseline/`).

**Numéros de ligne** : ceux de `main` au 24 octobre, avant la fusion de la #142.

**Limites** : aucune requête sur la base de production, aucun test en jeu. Ce
qui est dit du serveur vient du schéma versionné (`baseline/`), pas d'une
observation de la production.

---

## 1. Ce que Fred a décidé — tout ce qui a été retrouvé

Les décisions sont classées par date. Pour chacune : la source, et ce qu'il en
reste aujourd'hui dans le code.

### 14 juillet 2026 — naissance de la diplomatie

| Décision | Source | Dans le code aujourd'hui |
|---|---|---|
| Un **Quartier des Ambassades** à Luthécia : un accueil, trois bureaux (Al-Khalija, Sovarka, El Estado). | `df042a85` | ✅ présent |
| **Accès à un bureau conditionné à l'ouverture réelle de l'ambassade** de ce pays. | `df042a85` | ✅ présent (contrôle côté écran, voir R7) |
| Place dans la ville : collé au mur nord, entre le carrefour stade/commercial et l'aéroport ; boucle de la rue centrale en « grand 8 ». | `ae570715`, `dd56081f`, `ae345cc1` | ✅ présent |
| Traités et négociations passent par une **file d'attente diplomatique commune** (proposer / accepter / refuser), réponse au ministre des Affaires étrangères. | `aefe119d`, `5aa286f9` | ✅ table `propositions_diplomatiques` |
| **Sanctions** : effet aléatoire sur l'empire visé. | `5aa286f9` | ⚠️ effet sur un indice non enregistré (voir R1) |

### 15 juillet 2026 — les ambassadeurs

| Décision | Source | Dans le code aujourd'hui |
|---|---|---|
| La nomination et le renvoi d'un ambassadeur sont **enregistrés et partagés**. | `4ed6521d` | ✅ table `ambassades_ouvertes` |
| Six ordres : **audience, asile, relations bilatérales, corruption d'un homologue, réception, mécénat culturel**. | `4ed6521d` | ⚠️ présents, effets en grande partie fictifs (voir partie 3) |
| Une **Salle de Réception commune** aux trois ambassades. | `4ed6521d` | ✅ réservation une fois par jour, contrôlée en base |
| **Démettre** (son propre ambassadeur) : perte du poste **immédiate**. **Expulser** (un ambassadeur étranger) : **24 h réelles** pour quitter le pays. | `263217b5` | ✅ présent |
| **Arrestation automatique** de l'ambassadeur expulsé qui n'est pas parti à temps : **3 jours de prison**, perte du poste, annonce publique. Le même jour, corrigée pour utiliser la vraie détention du jeu. | `e62b2c31`, `c81d6350` | ❌ **perdue par accident** (voir ci-dessous) |

**L'arrestation n'a pas été abandonnée, elle a été effacée par erreur.** Le
commit `654e1d9b` du 15 juillet (« Vote de loi entièrement basé sur le temps
réel ») a réécrit `api/cron-minuit.js` à partir d'une copie plus ancienne et a
supprimé 459 lignes, dont l'arrestation des expulsés. Le traitement des
expulsions a été reconstruit le 8 septembre (`9ab4e73f`), mais seulement comme
« fin de mission » : l'ambassadeur perd son poste, sans arrestation. Aucune
trace d'une décision de Fred de renoncer à la prison n'a été trouvée.

Une variante non retenue mérite d'être notée : la version de juillet arrêtait
l'ambassadeur **sans vérifier s'il avait quitté le pays**. Il était donc
toujours arrêté, même parti.

### Août – octobre 2026 — ajustements

| Décision | Source | Dans le code aujourd'hui |
|---|---|---|
| L'**hôtesse d'accueil diplomatique** fait partie des offres du Bureau de l'Emploi, portée « internationale » : **une étiquette, sans mécanique** pour l'instant. | `d2d682b5` (9 août), journal | ✅ conforme |
| La « salle des Relations Diplomatiques » du Musée national est supprimée (doublon). | `ab732557` (2 août) | ✅ |
| La **Doctrine V2** range « Corrompre un homologue » au palier standard (70 %) ; le jeu affiche 65 %, noté « bruit de calibration ±5 % ». | audit des ordres | ⚠️ écart toléré |
| L'ambassadeur **ne passe pas par le système de candidatures** : il est choisi dans le répertoire du ministre. Ce manque est **signalé, pas comblé**. | `acee9772`, `9ab4e73f` (8 sept.) | ✅ conforme au constat |
| Le bureau du ministre passe à trois entrées ; trêve et ambassades restent à part. | `acee9772` | ✅ |
| **Postes itinérants non salariés**, hôtesse diplomatique comprise : son titulaire touche le revenu universel. | arbitrage du 20 sept. | ✅ côté serveur (voir l'audit du Bureau de l'Emploi) |
| L'**hôtesse PNJ du hall** : politesse comme arme, aime le protocole, ne répète rien de ce qui se passe derrière les portes. | `fb66d3b9` (5 oct.) | ✅ profil de dialogue |
| Le **ministre des Affaires étrangères PNJ, Jean-Jacques Carlin** : avenant, sait dire non, pas pacifiste par principe ; son domaine inclut les ambassades. | `93a6f27f` (11 oct.) | ✅ |

### 24 octobre 2026 — décisions de la journée

- **Feuille de route** : terminer Luthécia, puis Port-Sainte-Marie et
  Montrouge, puis la traduction, puis les trois autres empires.
- Les ordres liés aux autres empires **existent mais ne seront raccordés
  qu'avec ces empires**. Il est donc normal qu'aucune ambassade ne puisse
  s'ouvrir aujourd'hui.
- **Trois ambassadeurs PNJ**, reçus **sur audience seulement** (bureaux
  fermés) : Valery Antonov (Sovarka, **la rigidité**), Guillermo Vasquez
  (El Estado, **la corruption**), Mohamed Al-Mansoori (Al-Khalija, **le
  snobisme**). Pull request #142.
- **Une seule réalité : celle du serveur.**

### Ce qui n'a jamais été décidé

Aucune trace de décision n'a été trouvée sur :
- **l'effet de l'asile politique** : ce qu'il protège, et qui l'accorde ;
- la nature de la **« faveur »** gagnée en corrompant un homologue ;
- **l'effet réel de l'Indice Diplomatique**. `AUDIT_INDICES.md` (13 août) a
  constaté que c'est l'indice le plus modifié du jeu pour presque aucun effet ;
- le **contenu d'une audience** avant aujourd'hui.

---

## 2. Ce que l'écran affiche sans que le serveur le confirme

Chaque ligne viole la règle « une seule réalité ». Les niveaux :
**P1** = l'écran ment au joueur sur une action qu'il paie ou sur son
personnage ; **P2** = l'écran est seul à décider ; **P3** = mineur.

| # | Constat | Où | Niveau |
|---|---|---|---|
| R1 | **L'Indice Diplomatique n'existe que dans le navigateur.** `INDICES_NATIONAUX` est une constante en mémoire, jamais enregistrée. Chaque gain ou perte affiché (+6, +5, +8, −10…) disparaît au rechargement et n'est vu par personne d'autre. | `data.js` 8606 ; `plateau-politique.js` 9298-9386, 7409 | P1 |
| R2 | **Les traités vivent dans l'état personnel** du joueur qui signe (`state.traites`). « Relations bilatérales » affiche donc les traités du lecteur, pas ceux de son pays. | `plateau-politique.js` 7339, 9278 | P1 |
| R3 | **Le tirage de l'audience (70 %) est fait par le navigateur.** Cela vaut aussi pour la version de la #142 : c'est l'écran qui décide si l'ambassadeur reçoit. | `plateau-politique.js`, `confirmerAudienceAmbassadeur` | P2 |
| R4 | **Les tirages de la corruption (65 %), et les effets de la réception et du mécénat** sont calculés et appliqués par le navigateur. | `plateau-politique.js` 9298-9386 | P2 |
| R5 | **« Ambassadeur nommé » et « Ambassade ouverte » s'affichent sans attendre la réponse** de la base. Si la base refuse, ou si l'ambassade n'est pas ouverte, rien n'est enregistré, mais l'écran annonce le succès et la notification part quand même. | `plateau-politique.js` 9433, 7417 | P1 |
| R6 | **L'échéance d'expulsion est calculée avec l'horloge du joueur** (`Date.now() + 24 h` dans le navigateur), pas avec celle du serveur. | `plateau-politique.js`, `confirmerExpulsionAmbassadeur` | P2 |
| R7 | **L'accès aux bureaux et aux ordres de l'ambassadeur se décide dans l'écran**, sur une liste chargée en arrière-plan à l'entrée du bâtiment. Si on entre dans un bureau avant la fin du chargement, il est déclaré « fermé » alors qu'il est peut-être ouvert. Seule la réservation de salle est vérifiée par la base. | `plateau-navigation.js` 358, 617 ; `plateau-politique.js` 4202 | P2 |
| R8 | **La demande d'asile** est écrite par le navigateur dans la fiche du personnage, et rien ne la lit jamais. | `plateau-politique.js` 9401 | P1 |
| R9 | **L'expulsion promet « sous peine d'arrestation »** dans le message à l'ambassadeur, mais l'arrestation n'existe plus (partie 1). | `plateau-politique.js` 9545 | P1 |
| R10 | Les **annonces publiques** des actions diplomatiques (« réception donnée », « scandale ») sont écrites par le navigateur, après un effet que le serveur n'a pas constaté. | `addExternalEvent` | P2 |
| R11 | **La fin d'une expulsion est appliquée deux fois** : dans le navigateur du premier joueur qui passe minuit, et par le serveur. C'est volontaire et documenté (20 sept.), mais contraire à la nouvelle règle. | `plateau-politique.js` 14362 ; `api/cron-minuit.js` 4056 | P3 |
| R12 | La base autorise le ministre **du pays hôte** à modifier toute la ligne d'une ambassade étrangère, y compris le nom de l'ambassadeur (règle d'accès « ambassade gérée par l'empire ou par l'hôte »). | `baseline/.../60_rls-policies.sql` | P3 |

Points conformes :
- le **coût en PA** de tous ces ordres est prélevé par le serveur
  (`payer_ordre`), avec un coût vérifié contre le catalogue ;
- la **réservation de la Salle de Réception** est contrôlée en base ;
- l'**ouverture d'une ambassade** n'est permise par la base qu'au ministre des
  Affaires étrangères de l'empire concerné.

---

## 3. État de chaque ordre

| Ordre | Qui | Aujourd'hui à Luthécia | Commentaire |
|---|---|---|---|
| Ouvrir une ambassade | Ministre AE | Inutile tant que les autres empires ne sont pas codés | Faux succès possible (R5) |
| Nommer / démettre un ambassadeur | Ministre AE | Idem | Faux succès (R5), aucune vérification de la personne nommée |
| Expulser un ambassadeur étranger | Ministre AE | Personne à expulser | Arrestation perdue (R9), horloge du joueur (R6) |
| Demander audience | Tous | **Fonctionne avec la #142** : 3 ambassadeurs PNJ | Tirage côté écran (R3) |
| Demander l'asile | Tous | Paie 2 PA pour rien | Aucun effet (R8), aucun design |
| Réserver la salle | Ambassadeur | Impossible (aucun ambassadeur) | Solide côté base |
| Relations bilatérales, corruption, réception, mécénat | Ambassadeur | Impossibles (bureaux fermés) | Effets fictifs (R1, R2, R4) |

---

## 4. Recommandations

**Pour la #142, avant fusion.** Le tirage de 70 % se fait dans le navigateur
(R3). Deux options conformes à la règle :
1. **pas de tirage** : l'ambassadeur reçoit toujours. C'est simple, et rien ne
   reste à décider côté écran ;
2. **tirage par le serveur** : une petite fonction en base qui prélève le PA et
   tire le résultat dans la même opération, comme le font déjà la banque ou
   l'Assemblée. Elle demande une migration, à appliquer selon
   `WORKFLOW-SUPABASE.md`.

**Pour finir proprement Luthécia sans les autres empires** : passer en
« Bientôt disponible » les ordres qui ne peuvent pas fonctionner aujourd'hui
(ouvrir, nommer, démettre, expulser, asile, réservation). Un ordre grisé ne
prélève rien et n'affiche rien de faux. Cela supprime d'un coup R5, R6, R8 et R9
pour les joueurs de la bêta.

**Avant la finalisation de Républia** : décider du sort de l'**Indice
Diplomatique** (R1). Ce n'est pas qu'une question d'ambassades : traités,
sanctions, trêves et guerre l'utilisent aussi.

**Quand les autres empires seront codés** : rétablir l'arrestation des expulsés
(3 jours, décision du 15 juillet), cette fois avec une vérification de la
présence dans le pays ; trancher l'asile et la faveur ; passer tous les effets
par des fonctions serveur.

## 5. Questions pour Fred

1. **Audience** : on garde 70 % de chances, donc une fonction serveur, ou
   l'ambassadeur reçoit toujours ?
2. **Ordres non raccordables** : je les passe en « Bientôt disponible » ?
3. **Arrestation des expulsés** : la décision du 15 juillet (3 jours de prison)
   tient-elle toujours, pour le jour où on raccordera les empires ?
4. **Asile politique** : contre quoi protège-t-il, et qui l'accorde ?
5. **Indice Diplomatique** : le rendre réel et partagé, ou le retirer de
   l'affichage tant qu'il ne l'est pas ?
