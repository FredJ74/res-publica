# Audit du circuit fiscal et des flux financiers publics de Républia

> Fait au chantier 2E, le 5 octobre 2026, **par lecture du code exécuté** : les
> 641 corps de fonction PostgreSQL, `api/cron-minuit.js`, et les modules clients.
> Aucune écriture en base. Aucune intention n'est prise pour un fait : chaque
> affirmation ci-dessous cite la fonction ou la ligne qui l'établit.

## Le circuit, tel qu'il tourne

```
RECETTES
├── forfait quotidien de population         RECETTES_FISCALES_JOUR_SERVEUR (cron)
│      Luthécia 18 000 · PSM 2 400 · Montrouge 4 200  =  24 600 FR/jour
│      constante en dur, miroir de CITY_POPULATION — l'économie ne la produit pas
│
├── taxe sur les transactions              appliquer_taxe_transaction(pays, ville, brut)
│      part nationale  tauxNational %  →  budgets_nationaux.reserveJour
│      part locale     tauxLocal %     →  budgets_municipaux.<ville>.caisse
│      appelée par : acheter_produit_commerce, commerce_vendre_produit,
│                    recevoir_soin, vente_structure_encaisser, et le client
│
├── taxe foncière                          preleverTaxeFonciere() — cron, chaque nuit
│      surface du terrain × tauxFoncier (défaut 0,05)  →  compte de collecte municipal
│
├── part d'État sur certaines ventes       cron : part_nette, part_etat → reserveJour
├── part du notaire sur les successions    cron : part_notaire → caisse office-notarial
└── travail NPC des chantiers              cron : → caisse gouvernement-min_fin

           ▼
RÉPARTITION NATIONALE — distribuerFiscaliteServeur(pays), une fois par nuit
           total = 24 600 + reserveJour        puis  reserveJour := 0
           clés de répartition : budgets_nationaux.data.repartition
                                 (défaut REPARTITION_DEFAULT_SERVEUR)
           ▼
    CRÉDITÉE DIRECTEMENT À 13 CAISSES, sans passer par personne :

      palais-presidentiel      15 %        gouvernement-min_def     10 %
      mairie-capitale          12 %        gouvernement-min_int      8 %
      gouvernement-pm           8 %        assemblee                 8 %
      commissariat_capitale     8 %        gouvernement-min_fin      6 %
      gouvernement-min_just     6 %        gouvernement-min_ae       6 %
      tribunal_capitale         6 %        gouvernement-min_info     5 %
      reserve-nationale         2 %

RÉPARTITION MUNICIPALE — distribuerBudgetMunicipalVersBatiments(pays, ville)
           compte de collecte municipal → 6 équipements, puis caisse := 0
           clés : budgets_municipaux.data.allocation, fixées par le maire
           commissariat 20 · dispensaire 20 · multimodal 15 · stade 15 · marché 15 · tribunal 15
           ⚠ CLIENT SEULEMENT : aucun miroir serveur. Ne se déclenche que si un
             joueur de cette ville passe minuit en ligne.

DÉPENSES AUTOMATIQUES
├── virement gouvernement → caserne       virementCaserneServeur() — cron, chaque nuit
│      montant fixé par le ministre de la Défense (caserne_virement_journalier_fixer)
│      DÉFAUT 0 : « un ministre qui n'y touche pas ne finance rien, et c'est voulu »
│      débite gouvernement-min_def (plafonné), crédite caserne-militaire
├── indemnité de député                    assemblee_verser_indemnite(nom)
│      250 FR / député PJ / jour, à la demande, une fois par jour,
│      PLAFONNÉE PAR LA CAISSE — insuffisante = versement partiel ou nul, sans erreur
├── remboursement du prêt de préemption    preleverPreemptionsServeur() — cron
│      débite gouvernement-min_fin ; impayé = report sans pénalité, l'État ne se saisit pas
└── solde des soldats                      payerSoldeServeur() — **vidée le 18 septembre 2026**
       `async function payerSoldeServeur(pays) { return; }` — coquille conservée
```

## La réponse à la question de game design

> « L'économie produit quotidiennement des recettes publiques ; le ministre
> chargé de l'Économie dispose de ces ressources et doit répartir le budget. »

**Ce n'est pas ce que fait le code, sur deux points.**

**1. L'argent ne passe jamais par le ministre des Finances.** La répartition
nocturne crédite les treize caisses **directement et simultanément**. La caisse
`gouvernement-min_fin` ne reçoit que **sa propre part — 6 % par défaut**, comme
chaque autre poste. Elle n'est ni un guichet, ni un intermédiaire.

Le pouvoir du ministre est **réel mais indirect** : il fixe les pourcentages
(`budgets_nationaux.data.repartition`), et c'est cette table de répartition qui
distribue. Il arbitre la clé, il ne manie pas les fonds. L'autorité sur chaque
champ est verrouillée côté serveur par le déclencheur `budget_national_epingler()`,
qui refuse toute écriture venant d'un poste non habilité, champ par champ et
sous-champ par sous-champ, selon `budget_national_champs_regles`.

**2. Les 24 600 FR quotidiens ne viennent pas de l'économie.** C'est une
**constante en dur** dans le cron, miroir de la population déclarée dans
`data.js`. L'économie réelle n'alimente que `reserveJour`, par la taxe sur les
transactions — un filet bien plus mince. Un monde sans aucune activité
économique encaisserait quand même ses 24 600 FR par jour.

**Conséquence pour les dotations d'amorçage** : elles n'ont pas à rendre les
institutions autonomes, puisque la répartition nocturne les alimente dès la
première nuit. Leur seul rôle est de couvrir le **premier jour**, avant la
première passe du cron.

## Asymétrie majeure : seule la capitale est servie

`CAISSE_PAR_POSTE_BUDGET_SERVEUR` ne connaît que **`mairie-capitale`**,
**`tribunal_capitale`** et **`commissariat_capitale`**.

Port-Sainte-Marie et Montrouge ne reçoivent **rien** de la répartition
nationale — ni leurs mairies, ni leurs tribunaux, ni leurs commissariats. Leur
seule ressource est le compte de collecte municipal, alimenté par la taxe locale
et la taxe foncière de leur propre territoire, et redistribué **seulement si un
de leurs joueurs passe minuit en ligne**.

C'est une vraie question de jeu, pas une anomalie technique : l'État de Républia
est fiscalement centralisé sur sa capitale.

## Mécanismes financiers : état réel

| Mécanisme | État | Preuve |
|---|---|---|
| `tauxNational` | **ACTIF** | lu par `appliquer_taxe_transaction`, défaut 2 % si absent, valeur réelle 5 % |
| `tauxLocal` | **DÉCLARATIF — jamais renseigné** | lu par la même fonction, mais **absent des 4 lignes** de `budgets_municipaux` : la taxe locale est donc toujours au défaut de 2 % |
| `tauxFoncier` | **ACTIF** | lu chaque nuit par `preleverTaxeFonciere()` (cron), défaut 0,05. **Correction de mon rapport précédent** : aucune fonction SQL ne le lit, mais le cron si |
| `reserveJour` | **ACTIF, compte de transit** | crédité par la taxe et le cron, remis à 0 chaque nuit par `distribuerFiscaliteServeur` |
| `repartition` (national) | **ACTIF** | lu par `distribuerFiscaliteServeur`, autorité verrouillée par `budget_national_epingler` |
| `allocation` (municipal) | **ACTIF MAIS CLIENT SEULEMENT** | `distribuerBudgetMunicipalVersBatiments`, appelée depuis `plateau-personnage.js`. **Aucun miroir serveur** : une ville sans joueur connecté à minuit ne distribue pas |
| `virementJournalierCaserne` | **ACTIF** | `caserne_virement_journalier_fixer` (configure) + `virementCaserneServeur` (exécute), défaut 0 |
| Indemnités de député | **ACTIF** | `assemblee_verser_indemnite`, 250 FR, plafonné par la caisse |
| Part du notaire | **ACTIF** | cron, sur les successions, écriture vérifiée |
| Solde des soldats | **MORT, vidé exprès** | `payerSoldeServeur` ne fait plus que `return;` — arbitrage du 18 septembre 2026 |
| Subvention municipale aux clubs | **BRANCHÉ SUR UNE CLÉ INEXISTANTE** | lit `budgetMairie.allocation.associatif`, or `associatif` vit dans `data.indices`, pas dans `data.allocation` → toujours `undefined` → **montant toujours 0**. C'est pourquoi les 12 caisses de club sont à 0 et `derniereSubventionJour` n'avance jamais |
| `contributions_piete` | **ACTIF, CLIENT SEULEMENT** | écrite par `sbInsert` depuis `supabase.js` ; l'indice de piété en est **dérivé** (`recalculerPieteVille`). **Correction** : aucun écrivain SQL, mais la table n'est pas morte |
| `fiscalite_journal` | **MORTE** | aucun lecteur, aucun écrivain — ni SQL, ni client, ni cron. Aucune occurrence dans le dépôt |
| `dotations_amorcage_caisses` | **JOURNAL CLOS** | 159 lignes du 11 septembre 2026, qui ont porté 103 caisses à exactement 200. Dit ce qui *a été* versé, jamais ce qui *doit* l'être |

**Règle appliquée** : aucun mécanisme mort ou non branché n'a servi à justifier
une dotation. Les caisses que rien ne touche sortent en « ne pas doter ».

## Verdicts sur les doublons

Pour chacun : l'état, la source de vérité, la cible. **Rien n'a été modifié.**

### Double caisse du Premier ministre — tranché

| | |
|---|---|
| **État** | `republic_gouvernement-pm` = 88 202 FR · `republic_palais-gouvernement` = 0 FR, inchangée depuis le 10 juillet 2026 |
| **Source de vérité** | **`gouvernement-pm`**. Elle reçoit la part `pm` de la répartition nocturne, et c'est elle que la pièce `bureaux` du palais affiche (`ROOMS_AVEC_CAISSE_SPECIFIQUE`) |
| **Verdict** | `palais-gouvernement` est un **vestige**. Le palais est un *bâtiment* dont **chaque pièce** porte la caisse de son ministère ; le bâtiment lui-même n'est pas dans `ROOMS_AVEC_CAISSE`. Aucune fonction, aucun appel client, aucun cron ne la touche, et la répartition nationale l'ignore |
| **Cible** | Une caisse par poste politique, nommée `gouvernement-<poste>`. Retirer la ligne `palais-gouvernement`, **après** avoir vérifié qu'aucun écran ne l'affiche |

### Deux caisses municipales — tranché : ce n'est pas un doublon

| | |
|---|---|
| **État** | `caisses_batiments.mairie-capitale` = 102 845 · `budgets_municipaux.republic_capitale.caisse` = 400 |
| **Verdict** | **Deux étapes de deux circuits différents**, pas deux versions de la même chose. `budgets_municipaux.data.caisse` est un **compte de collecte** : la taxe locale, la taxe foncière et les loyers y tombent, et il est **vidé chaque jour** vers les six équipements. `caisses_batiments.mairie_<ville>` est la **caisse propre du maire**, alimentée par la répartition **nationale** |
| **Cible** | Le modèle est déjà bon. Deux clarifications utiles : renommer le compte de collecte pour qu'il ne se confonde plus avec une caisse (`recettesLocales` plutôt que `caisse`), et **écrire le miroir serveur** de la distribution municipale, aujourd'hui client seulement |

### La caserne traitée comme une ville — tranché

| | |
|---|---|
| **État** | `republic_mairie_caserne` = 0 · 4ᵉ ligne `republic_caserne` dans `budgets_municipaux`, caisse 0, `tauxFoncier` 0,05 |
| **Cause** | La caserne est une **zone spéciale** (`isSpecial` dans `data.js`), explicitement exclue des villes réelles par `getVillesReelles()` — « hors zones spéciales caserne/qhs ». Mais `getVilleKey()` lit `state.currentCity` **sans filtrer**, et `plateau-politique.js` y écrit `'caserne'`. Un joueur présent à la caserne a donc créé une clé municipale pour un lieu qui n'est pas une ville |
| **Cible** | Faire passer `getVilleKey()` par `getVillesReelles()` : une zone spéciale ne doit pas pouvoir engendrer une clé municipale. Puis retirer les deux lignes |

### Identifiants bruts contre identifiants suffixés — tranché

Huit caisses : `commissariat`, `commissariat-local`, `tribunal`, `tribunal-local`,
`dispensaire-public`, `dispensaire-public-v`, `marche`, `stade`. Toutes à **0**.

| | |
|---|---|
| **Cause** | Le commentaire du correctif le dit mot pour mot : jusqu'au **16 août 2026**, `getBuildingIdPourCategorieBudget()` renvoyait « *l'identifiant de navigation tel quel (ex. 'marche'), un buildingId partagé entre plusieurs villes, **fusionnant leurs caisses*** ». Le lot « A3, caisses locales » a introduit `getCaisseLocaleId(categorie, ville) = categorie + '_' + ville` |
| **Source de vérité** | Les caisses **suffixées par la ville**. Ce sont elles qui portent l'argent, et les quatre résolveurs (`getBuildingIdCommissariat`, `...Tribunal`, `...Dispensaire`, `...CentreMultimodal`) délèguent tous à `getCaisseLocaleId` |
| **Verdict** | Les huit lignes brutes sont l'**état d'avant le 16 août**. Elles ne sont ni des doublons de design ni une question de jeu : ce sont les résidus d'un correctif daté. Corroboré par le journal d'amorçage, qui n'en a doté **aucune** |
| **Cible** | `<catégorie>_<ville>` partout, ce qui est déjà le cas. Retirer les huit lignes à 0 |
| **Risque résiduel, signalé** | `caisse_institution_mouvement(p_id)` prend l'identifiant **tel qu'on le lui donne**. Un appelant qui passerait encore l'identifiant brut créditerait la caisse à 0 au lieu de la vraie. Aucun appelant connu ne le fait aujourd'hui ; la garde manquante est côté primitive |

### Entrepôts — tranché, et le seed est débloqué

| | |
|---|---|
| **Source de vérité** | **`batiments_etat.<ville>_<entrepôt>.entrepot.caisse`**. Les deux seules fonctions qui la manipulent, `entrepot_commander()` et `entrepot_reverser()`, la lisent et l'écrivent là, et nulle part ailleurs |
| **Le motif `entrepot` de `caisses_autorites`** | **INERTE**. Il déclare les postes `directeur_entrepot` et `maire_adjoint`, ce qui suppose une caisse dans `caisses_batiments` — mais **aucun appelant ne passe jamais un identifiant d'entrepôt** à `caisse_institution_mouvement()`. Aucune seconde caisse n'est donc jamais créée |
| **Conséquence** | L'ambiguïté signalée au rapport précédent **est levée**. Le seed des matières premières ne dépend plus que du montant de la caisse d'entrepôt |
| **Cible** | Retirer le motif inerte de `caisses_autorites`, **ou** y brancher réellement les deux postes. Ne pas laisser une déclaration d'autorité sans consommateur |

### Marchés et buvette — tranché

| | |
|---|---|
| **Marchés** | **Pas une double comptabilité.** La caisse `marche_<ville>` est l'équipement municipal, alimenté par la part `marche` de la répartition municipale. L'entreprise `marche-republic-<ville>-marche` est le **fonds de commerce des étals**. Deux fonctions économiques distinctes, deux caisses légitimes |
| **Buvette** | **Vestige daté.** Le code le dit : « *Buvette : pas de caisse autonome (A3, lot finition financière locale, 17 août 2026) — affiche le solde de la caisse du stade de cette ville* ». Ses 88 FR sont l'état d'avant ce lot |
| **Cible** | Retirer `stade-buvette`. Laisser les marchés en place |

### Autres doublons et inertes découverts

| Caisse | Verdict |
|---|---|
| `banque-privee` | **Contrepartie, pas un budget.** `deposer_helvetia` calcule son identifiant par `pays \|\| '_banque-privee'` : elle est la contrepartie **nationale** des dépôts, retraits, prêts et placements des joueurs, bien que `banque-privee` soit un bâtiment de Luthécia. Son solde en est le miroir |
| `eglise-montrouge`, `notre-dame-mer`, `tabernacle-impots` | **Caisses inertes.** Aucun appel, nulle part, ne les crédite ni ne les débite. Les lieux se jouent, leurs caisses ne servent à rien. Le circuit de piété existe, mais par le ledger `contributions_piete`, sans passer par une caisse |
| `office-notarial` | **Active** : le cron la crédite de la part du notaire sur chaque succession |
| `hotel_<ville>` | **Actives**, créditées via `getCaisseLocaleId('hotel', ville)` — convention canonique. L'amorçage a doté celles de PSM et Montrouge mais **pas celle de Luthécia** |
| `<ville>/<bâtiment>#redaction` (5) | **Actives** : la vente des journaux est créditée « dans la caisse de la rédaction du lieu ». Seules caisses de blob que l'amorçage n'a pas dotées |
| `qhs-prison`, `port-sainte-marie` | **Actives mais hors répartition** : aucune part nocturne. Le port encaisse des exportations quotidiennes qui ne passent pas par sa caisse |

## Ce que cet audit a corrigé de mon rapport précédent

1. **`tauxFoncier` est actif**, lu par le cron. J'avais écrit qu'aucune fonction
   ne le lisait : c'était vrai des fonctions SQL, faux du système.
2. **`contributions_piete` est écrite** par le client. La table n'est pas morte.
3. **Les huit caisses « non suffixées » ne sont pas des scories sans histoire** :
   ce sont les identifiants de bâtiment *authored* de `data.js`, et leur double
   emploi vient d'un correctif daté du 16 août 2026.
4. **`notre-dame-mer` est à Port-Sainte-Marie**, pas à Montrouge. Mon
   rapprochement se faisait sur le mot « mer » ; `data.js` tranche.
5. **La double caisse municipale n'est pas un doublon** mais deux étapes de deux
   circuits.
6. **L'ambiguïté de la caisse d'entrepôt est levée** : le seed n'est plus bloqué
   que par un montant.
