# Inventaire exhaustif — carrières, parcours, qualifications et leurs usages

**Relevé le 12 octobre 2026.** Lecture seule.

---

## 1. Le constat principal, à lire avant tout le reste

**Il n'existe aucun système de qualification dans le jeu.**

Le personnage porte **quatre valeurs de parcours**, choisies une fois à la création et jamais
modifiables : `origin`, `school`, `archetype`, `career`. Elles sont stockées dans
`personnages_donnees` (colonnes `origin`, `school`, `archetype`, `career`) et relues dans
`state.char`.

Ces quatre valeurs produisent **deux sortes d'effets, et deux seulement** :

1. **Des effets ponctuels appliqués À LA CRÉATION** — bonus/malus de caractéristiques, capital de
   départ, INF/POP/DIS initiaux. Une fois la fiche écrite, ces nombres sont dans les
   caractéristiques : **la valeur de parcours n'est plus jamais relue pour les recalculer.**
2. **Un seul effet mécanique permanent**, et il ne porte que sur `career` : le bonus de carrière de
   l'action **Neutraliser**.

Tout le reste est de l'**affichage**.

### Les 9 usages réels, après la création

| Fichier:ligne | Ce qui est lu | Ce que ça fait |
|---|---|---|
| `plateau-core.js:1655-1658` | `char.career` | `migrerCareerId()` : remappe un ancien id vers les 10 actuels |
| `plateau-core.js:1722-1723` | `char.archetype`, `char.career` | **affichage** du rôle dans le HUD |
| `plateau-personnage.js:13-16` | les **quatre** | **affichage** de la fiche de personnage |
| `plateau-actions-illegales-rumeurs.js:32` | `char.career` | `BONUS_CARRIERE_VOL` → taux de **Voler** |
| `plateau-actions-illegales-rumeurs.js:1653` | `char.career` | `BONUS_CARRIERE_VOL` → second site de calcul |
| `plateau-actions-illegales-rumeurs.js:316` | `char.career` | `neutraliserBonusCarriere()` → +15 si `criminal_c` |

**Aucun ordre, aucun poste, aucune action, aucune candidature ne vérifie `career`, `school`,
`origin` ni `archetype`.** Les prérequis (`blocks`) sont relus par `creation.js:557` seulement :
ce sont des verrous **de création**, jamais des contrôles de jeu.

---

## 2. ORIGINS — 4 origines (`data.js:177`)

| id | Libellé | Capital | Bonus | Malus | Obtention | Effet permanent |
|---|---|---|---|---|---|---|
| `poor` | Milieu défavorisé | 300 | VOL+2, DUP+2 | CHA−1 | choix libre à la création | **aucun** |
| `worker` | Classe ouvrière | 600 | VOL+1, PER+1 | DUP−1 | choix libre | **aucun** |
| `bourgeois` | Petite bourgeoisie | 1 000 | INT+1, CHA+1 | ENT−1 | choix libre | **aucun** |
| `elite` | Haute société | 2 200 | ENT+2 | VOL−2 | choix libre | **aucun** |

Stocké : `personnages_donnees.origin`. Vérifié par : **rien**. Affiché : fiche de personnage.

---

## 3. SCHOOLS — 4 parcours scolaires (`data.js:190`)

| id | Libellé | Bonus | Malus | Argent | **Bloque les carrières** |
|---|---|---|---|---|---|
| `none` | Pas d'école | DUP+2, VOL+1 | INT−1 | 0 | `magistrat`, `business`, `doctor` |
| `basic` | École basique | PER+1, ENT+1 | — | 0 | `magistrat`, `business` |
| `higher` | Études supérieures | INT+1, CHA+1 | — | 0 | `doctor` |
| `elite` | Hautes écoles | INT+2, ENT+1 | VOL−1 | **+400** | aucune |

**C'est le seul endroit du jeu où un parcours conditionne un accès** — et il ne s'applique qu'à
l'écran de création (`creation.js:557`, `careerBlocked()`). Après création, le lien école → carrière
n'est plus jamais vérifié.

Stocké : `personnages_donnees.school`. Vérifié par : **rien** après création.

---

## 4. ARCHETYPES — 9 natures (`data.js:201`)

| id | Libellé | Bonus | Malus | Argent | INF | POP | DIS |
|---|---|---|---|---|---|---|---|
| `politician` | Ambitieux | CHA+2, ENT+2 | DUP−2 | 400 | +15 | +20 | −10 |
| `authoritarian` | Ordre et discipline | VOL+2, PER+2 | ENT−2 | 600 | +20 | +5 | +5 |
| `oligarch` | Capitaliste | INT+2, DUP+2 | CHA−2 | 900 | +10 | −5 | +5 |
| `informer` | Diffuseur d'informations | PER+2, INT+2 | VOL−2 | 350 | +5 | +15 | −5 |
| `legalist` | Légaliste | INT+2, VOL+2 | CHA−2 | 700 | +15 | +5 | +10 |
| `believer` | Homme de foi | CHA+2, ENT+2 | DUP−2 | 300 | +10 | +25 | 0 |
| `shadow` | Homme de l'ombre | DUP+2, PER+2 | CHA−2 | 500 | +5 | −10 | +20 |
| `anticapitalist` | Anti-capitaliste | CHA+2, VOL+2 | INT−2 | 350 | +10 | +20 | −5 |
| `criminal` | Criminel | DUP+2, VOL+2 | ENT−2 | 1 200 | +5 | −15 | +15 |

Stocké : `personnages_donnees.archetype`. Vérifié par : **rien**. Affiché : HUD + fiche.

> **À noter** : `archetype: 'criminal'` (la nature) et `career: 'criminal_c'` (la carrière) sont
> deux champs différents. Seul `criminal_c` a un effet mécanique.

---

## 5. CAREERS — 10 carrières (`data.js:221`)

**C'est le champ le plus proche d'une qualification.** Immuable, unique, choisi à la création.

| id | Libellé | Argent | statKey (+1 à la création) | « Compétences » affichées | Prérequis scolaire |
|---|---|---|---|---|---|
| `officer` | Armée — Officier supérieur / Mercenaire | 700 | VOL | Commandement, Intimidation | aucun |
| `business` | Affaires — Homme d'affaires / Lobbyiste | 1 200 | INT | Lobbying, Blanchiment, Négociation | **≠ none, basic** |
| `magistrat` | **Justice — Magistrat / Avocat** | 800 | INT | **Droit, Procédure judiciaire**, Négociation | **≠ none, basic** |
| `press` | Médias & Communication — Grand journaliste / Influenceur | 450 | PER | Kompromat, Propagande, Réseaux sociaux | aucun |
| `clergy` | Religion — Chef de culte | 150 | CHA | Rhétorique, Mobilisation | aucun |
| `doctor` | Professions intellectuelles — Médecin / Universitaire | 550 | INT | Réseau civil, Discrétion, Rhétorique | **≠ none, basic, higher** |
| `worker` | Monde ouvrier — Ouvrier / Syndicaliste | 300 | VOL | Force, Solidarité, Mobilisation | aucun |
| `intel` | Renseignement — Agent des services | 500 | PER | Surveillance, Infiltration | aucun |
| `criminal_c` | Crime organisé — Criminel organisé | 900 | DUP | Milices, Blanchiment | aucun |
| `escort` | Prostitution — Prostitué(e) | 450 | CHA | Séduction, Kompromat | aucun |

**Le champ `comp` (« compétences ») est purement décoratif** : une chaîne de texte affichée à la
création et sur la fiche. Rien ne la parse, rien ne la vérifie. « Droit, Procédure judiciaire » de
`magistrat` n'ouvre aucune action.

### Le seul effet mécanique permanent d'une carrière

`BONUS_CARRIERE_VOL` (`plateau-actions-illegales-rumeurs.js:3195`), lu en 2 endroits
(lignes 32 et 1653) pour le taux de **Voler** :

| Carrière | Bonus au vol |
|---|---|
| `criminal_c`, `intel`, `escort` | **+15** |
| `magistrat`, `officer`, `clergy`, `doctor` | **−10** |
| `business`, `press`, `worker` | 0 |

Et `neutraliserBonusCarriere()` : **+15 uniquement pour `criminal_c`**, sur le taux de Neutraliser.
Volontairement différent de `BONUS_CARRIERE_VOL` (commentaire du §18, 10 septembre 2026).

### Migration des anciens id

`MIGRATION_CAREER_IDS` (`data.js`) : 18 → 10. `civil`/`local_civil`/`lawyer` → `magistrat`,
`influencer` → `press`, `academic` → `doctor`, `lobbyist` → `business`, `union` → `worker`,
`unemployed` → `worker`. Appliqué en mémoire au chargement, jamais en base.

---

## 6. Professions et postes — ce qui est RÉELLEMENT vérifié

Aucun poste ne vérifie une qualification. Tous vérifient un **poste attribué**, jamais un parcours.

| Mécanisme | Ce qu'il vérifie | Source d'autorité |
|---|---|---|
| `exiger_poste('juge')`, `('commissaire')`, `('min_just')`… | le **poste tenu** | `postes_attribues` / `cycles_electoraux` via `poste_est_atteste` |
| `requiresPost` (`plateau-politique.js:4104`) | le poste tenu | `state.poste` (client) + revalidé serveur |
| `postes_nommes_regles` | qui nomme qui | — |
| `postes_electifs_regles` | `min_inf` seulement (3/5/5/10) | **influence**, pas qualification |
| `offres_emploi_bne` (7 lignes) | **rien** | la table n'a **aucune colonne de prérequis** : `id, job, portee, ville, salaire, places`. Les 7 emplois (banquier, commerçant, docker, hôtelier, hôtesse, secrétaire, serveur) sont ouverts à tous |
| `pnj_metiers_profils` (11 lignes) | métiers **PNJ** | sans rapport avec les carrières PJ |

**Aucune profession réglementée n'existe.** Il n'y a aucun endroit du jeu où l'on refuse une action
à un joueur parce qu'il n'a pas la bonne formation.

---

## 7. Qualifications qui « semblent » exister mais ne sont jamais contrôlées

| Ce que le jeu laisse croire | Réalité |
|---|---|
| `magistrat` sait le « Droit, Procédure judiciaire » | chaîne décorative. Aucune action judiciaire ne la vérifie |
| `doctor` est « Médecin / Universitaire » | aucun soin, aucun acte médical ne la vérifie |
| `officer` a « Commandement » | le recrutement militaire vérifie le **poste** (Capitaine/Lieutenant), jamais la carrière |
| `press` est « Grand journaliste » | la presse vérifie `presse_membres`, jamais la carrière |
| `clergy` est « Chef de culte » | les services religieux vérifient le **job du PNJ** et le poste `grand_pretre`, jamais la carrière du PJ |
| `business` sait « Lobbying, Blanchiment » | `blanchiment` est un acte illégal ouvert à tous |
| `intel` est « Agent des services » | le renseignement vérifie `agents_renseignement` et le poste `min_def` |
| `escort` | les escorts sont des **PNJ** (`escorts_catalogue`), sans lien avec la carrière PJ |

---

## 8. Incohérences et doublons

1. **`archetype: 'criminal'` et `career: 'criminal_c'`** : deux champs quasi homonymes, un seul a un
   effet.
2. **`statKey` n'est lu que par `creation.js`** (lignes 568 et 599) : c'est un +1 appliqué une fois.
   Le champ survit sur la fiche sans jamais être relu.
3. **`comp` n'est parsé par rien.** Dix chaînes de compétences décoratives.
4. **`SCHOOLS[].blocks` et `CAREERS[].blocks` sont redondants** : `creation.js:557` ne lit que
   `CAREERS[].blocks` (`c.blocks.includes(G.school)`). Les `blocks` de `SCHOOLS` (avec leur
   `blockLabel`) ne servent qu'à l'affichage du texte d'avertissement.
5. **`BONUS_CARRIERE_VOL` est lu en deux endroits** avec la même formule recopiée — pas de fonction
   unique.
6. **`MIGRATION_CAREER_IDS` ne migre jamais la base** : un personnage en base garde `career:'lawyer'`
   indéfiniment, remappé en mémoire à chaque chargement.

---

## 9. Ce que le game designer doit décider (et que je n'ai pas décidé)

| Décision | Pourquoi je ne l'ai pas prise |
|---|---|
| **Quelle qualification permet d'être avocat PJ** (section J) | aucune qualification n'existe. Le plus proche est `career === 'magistrat'`, mais c'est un **choix de création immuable**, pas un diplôme. Décider que `magistrat` suffit fermerait l'avocature à tous les autres personnages **à vie** |
| Quels cursus l'Université propose | aucun catalogue de formation n'existe |
| Quelles qualifications chaque cursus délivre | idem |
| Quels métiers/postes exigent quelle qualification | **aucun n'en exige aujourd'hui** : tout est à créer |
| Si une carrière de création compte comme qualification | question de fond : les 4 axes sont aujourd'hui décoratifs à 95 % |
| Si `comp` devient une vraie liste de qualifications | les 10 chaînes contiennent 24 « compétences » distinctes, jamais normalisées |

---

## Reproduire cet inventaire

```bash
grep -rnE "(char|state)\.(career|school|origin|archetype)\b" --include=*.js . \
  | grep -v node_modules | grep -v "^creation.js"
sed -n '177,245p' data.js        # les quatre catalogues
grep -rn "BONUS_CARRIERE_VOL\|statKey\|\.blocks" --include=*.js . | grep -v node_modules
```
