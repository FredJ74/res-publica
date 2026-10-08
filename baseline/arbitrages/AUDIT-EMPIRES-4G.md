# Chantier 4G — ce qui reste à fermer sur les trois autres empires

> **Audit statique du 8 octobre 2026.** Aucun accès à Supabase : conclusions
> tirées du dépôt seul, et l'état live n'en est jamais déduit.
>
> Règle de socle applicable, rappelée parce qu'elle tranche la moitié des cas :
> **absence de configuration ≠ repli sur Républia.** Un empire sans paramètre
> économique n'est pas un empire qui hérite de ceux de Républia ; c'est un empire
> dont la mécanique ne tourne pas encore. Voir
> `republia_jamais_le_monde_entier` et `empires_mecaniques_communes_casting_specifique`.

---

## 1. Ce qui est déjà fail-closed, et qu'il ne faut pas « réparer »

| Mécanique | Ce qui la ferme |
|---|---|
| Recettes fiscales du jour | `RECETTES_FISCALES_JOUR_SERVEUR` ne déclare que `republic`. Un autre empire ne lève rien : la constante est consultée, pas complétée par défaut |
| Assemblée nationale | Fermée **par la donnée** : aucun siège déclaré hors Républia, et `sbGetAssembleeSieges` rendant une liste vide suffit à éteindre l'écran |
| Hubs multimodaux des villes secondaires | `getBuildingIdCentreMultimodal` porte `if (pays && pays !== 'republic') return null;` |

Ces trois-là sont le modèle : **la fermeture vit dans la donnée ou dans un
garde-fou explicite**, pas dans une liste de `if` répartie chez les appelants.

---

## 2. Corrigé cette nuit — le garde-fou qui ne pouvait pas se déclencher

`plateau-justice-economie.js`, `ouvrirModalFinancerCommunal` : l'écran de
virement communal du Maire Adjoint appelait
`getBuildingIdCentreMultimodal(ville)` **sans le pays**. Le garde-fou ci-dessus
ne pouvait donc jamais mordre — `pays` arrivait toujours `undefined` — et un
adjoint d'un autre empire se voyait proposer le hub de Port-Sainte-Marie, c'est
à dire une caisse de Républia.

C'était le **jumeau exact** de `getBuildingIdPourCategorieBudget`
(`plateau-politique.js`), corrigé le 7 octobre : le même défaut vivait dans deux
écrans, et seul l'un des deux avait été balayé.

Corrigé en passant `state.country`, **et** en retirant de la liste les
catégories qui rendent `null` : sans ce second point, la catégorie absente
devenait `<option value="null">` et le virement créditait `<pays>_null`, un
identifiant qui n'est celui d'aucun bâtiment.

---

## 3. Reste ouvert, et c'est purement technique

### 3a. Le cron ne traite qu'un empire, en dur

`api/cron-minuit.js` appelle `traiterQuotidienNationalServeur('republic')` avec
la chaîne littérale, hors `tacheQuotidienne`. Ce n'est pas un défaut
aujourd'hui — les autres empires n'ont pas de circuit national — mais c'est un
littéral là où il devrait y avoir une **liste d'empires configurés**, dérivée de
la donnée. Le jour où un second empire reçoit un circuit, ce site est le premier
à oublier.

Décision technique, pas de game design : la liste doit venir de la table qui
déclare les empires ayant une fiscalité, jamais d'un tableau recopié dans le
cron.

### 3b. Les onze `DEFAULT 'republic'::text` en SQL

Onze paramètres de fonctions SQL portent `DEFAULT 'republic'::text`. Un appelant
qui oublie le pays se voit donc servir Républia **en silence**, ce qui est
exactement le repli que la règle de socle interdit. Retirer ces défauts rendrait
l'oubli bruyant au lieu de le rendre faux.

**Ne peut pas se faire cette nuit** : c'est une migration. À porter dans un lot
dédié, avec le balayage des appelants d'abord — un `DEFAULT` retiré casse tout
appel qui s'appuyait dessus, et il faut la liste avant, pas après.

### 3c. Les vingt-trois `|| 'republic'` côté navigateur — et pourquoi je n'y ai pas touché

Vingt-trois sites écrivent `(state.country || 'republic')`. La tentation est de
les resserrer en `state.country === 'republic'`. **Je ne l'ai pas fait, et c'est
délibéré :**

1. `applyCharToState` (`plateau-core.js`) pose déjà
   `state.country = char.country || 'republic'`. Une fois un personnage chargé,
   `state.country` est **toujours** défini : les vingt-trois replis en aval sont
   donc morts, et les resserrer ne changerait rien.
2. Dans la seule fenêtre où ils vivent — avant tout chargement — les resserrer
   irait parfois dans le **mauvais sens**. `assembleeLoiApplicable()` rendrait
   `false`, donc les lois ne s'appliqueraient pas, donc une matière interdite
   redeviendrait librement commerçable. C'est un fail-**open** sur
   l'application de la loi.
3. La racine n'est pas en aval, elle est à la ligne de naturalisation :
   `char.country || 'republic'` **fait d'un personnage sans empire un
   Républien**. Corriger vingt-trois replis en laissant la racine serait
   cosmétique.

**Ce qu'il faut faire, et pourquoi pas cette nuit** : refuser un personnage sans
empire à l'hydratation, au lieu de le naturaliser. Mais si un seul personnage
vivant arrive aujourd'hui avec un `country` absent de la lecture — masquage
partiel, lecture dégradée — ce changement le met dehors. Cela ne se décide pas
sans avoir compté, en base, les personnages dont `country` est nul ou vide. La
sonde est à faire au retour de Supabase ; elle est en lecture seule.

---

## 4. Décisions de GAME DESIGN — rien n'est inventé ici

Trois questions seulement, et aucune n'a de réponse déductible du dépôt.

### Q1 — À quel hub multimodal appartient chaque empire ?

`caisses_batiments` porte trois caisses `*_centre-multinodal-luthecia`, une par
empire autre que Républia. Luthécia **est la capitale de Républia**. Trois
lectures sont possibles et le dépôt ne tranche pas :

- le hub de Luthécia est un **hub partagé** où chaque empire tient un comptoir
  (c'est ce que suggère le commentaire « hub partagé, contenu par
  `buildingContext` selon l'empire ») ;
- ce sont des **artefacts** d'une époque où le pays ne traversait pas la
  résolution, et il faut les retirer ;
- chaque empire doit avoir **son propre** hub, et ces lignes sont des
  placeholders mal nommés.

Conséquence du choix : si c'est un comptoir, ces caisses sont légitimes et
doivent recevoir un financement ; si c'est un artefact, elles doivent être
supprimées, et il faut d'abord vérifier qu'elles ne portent pas d'argent.

### ~~Q2~~ — TRANCHÉE LE 8 OCTOBRE 2026 : **24 600 FR/jour est la valeur voulue**

`RECETTES_FISCALES_JOUR_SERVEUR` déclare pour Républia
`{ capitale: 18000, ville_a: 2400, ville_b: 4200 }`, soit **24 600 FR/jour**.

Deux faits rendent ce chiffre suspect :

- la population déclarée dans `CITY_POPULATION` conduit, au barème en vigueur,
  à **52 200 FR/jour** — plus du double ;
- la répartition 18 000 / 2 400 / 4 200 **est celle d'El Estado**, pas celle que
  la population de Républia produirait. Le chiffre semble avoir été recopié
  d'un empire à l'autre.

**Arbitrage de Fred, 8 octobre 2026 : les 24 600 FR/jour sont la valeur voulue.**
Ce montant est une décision de game design, pas une erreur de recopie. **Ne pas
le recalculer depuis la population ; 52 200 FR n'est pas la valeur à utiliser.**

Le rapprochement avec la ventilation d'El Estado était donc une coïncidence de
lecture, pas une preuve. Ce qui restait de ce constat — la cohérence entre
`CITY_POPULATION` et le barème — est une question de modèle économique, pas un
défaut à corriger : si les deux doivent concorder un jour, c'est le barème ou la
population qu'on bougera, consciemment.

Conséquence pour le chantier municipal, maintenant clos : ces 24 600 FR partent
**intégralement au circuit national** et ne touchent aucune caisse municipale.
L'assiette municipale, elle, est la somme des recettes du jour mesurées par
`recettes_municipales` — taxe foncière, loyers, taxe locale sur les
transactions. Les deux circuits ne se croisent pas.

### Q3 — Les trois autres empires ont-ils un état fiscal ?

Pas « quels chiffres » — cela découlerait de Q2 — mais la question préalable :
**ces empires lèvent-ils l'impôt dans la bêta, ou sont-ils volontairement hors
circuit économique pour l'instant ?** Tant que la réponse n'est pas donnée,
`RECETTES_FISCALES_JOUR_SERVEUR` reste à un seul empire, ce qui est le
comportement correct par défaut.
