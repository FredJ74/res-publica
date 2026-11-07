# Contrôles globaux — 7 novembre 2026

Base de départ : main `efeee90a` (#585/#586, ancêtre `6f75bd26`).
Intégration finale : main `947caad7` (#588) conservé sans conflit. Branche
`codex/controles-globaux-verts-20261107`. Lecture AGENTS.md, WORKFLOW-SUPABASE.md et
RELAIS.md. Aucune écriture/connexion Supabase, aucun PJ utilisé, aucune migration
appliquée ou préparée. Fichiers de Claude exclus inchangés.

## Avant / après

Commandes depuis la racine, Python avec pglast installé. Le lanceur réel est
`python outils/baseline/controler-tout.py --detail` ; aucun contrôle court-circuité.

| Contrôle / commande | Avant | Après | Cause et classement |
|---|---|---|---|
| `verifier-workflow.py` | OK | OK | Rangement déjà corrigé par Claude. |
| `verifier-classification.py` | OK | OK | Inchangé. |
| `verifier-baseline.py` | ÉCHEC | ÉCHEC | 10 messages initialement, 6 restants : deux seeds socle modifiés sans rendu canonique et deux mesures de nombre de lignes périmées. Classes a/b : décisions livrées mais fidélité du catalogue non attestée. |
| `verifier-autorite.py` | ÉCHEC | **OK** | Deux faux « signature inconnue trading_acheter(text,text,text,integer,text) ». Classe c : extension d'en-tête par copie/replace/EXECUTE non inventoriée. |
| `verifier-referentiels.py` | ÉCHEC | ÉCHEC | 27 messages initialement, 3 restants : mesures anciennes ordres/coûts, bonus différés, miroirs d'entreprises ; artefact des 19 ressources désormais prouvé identique. Classes a/c ; observations vivantes indispensables. |
| `verifier-faits-publics.py` | OK | OK | Inchangé. |
| `verifier-fonctions.py` | OK | OK | Inchangé. |
| `verifier-monde-neuf.py` | OK | OK | Inchangé. |
| `assembler.py` | OK | OK | Inchangé. |
| `reconstruire.py` | OK | OK | Contrôle existant du dépôt, pas une nouvelle certification PostgreSQL de production. |
| `verifier.py communication` | OK | OK | Inchangé. |
| `outils/verifier-archive-registre.py` | OK | OK | Archive inchangée. |

**9/12 → 10/12. Aucun verdict 12/12 annoncé.** Les deux rouges restent visibles.
Les trois mesures `posee/reelle` et la date de capture de referentiels.json n'ont
pas été actualisées depuis une déduction locale. Aucun contrôle ou seuil relâché.

## Origine démontrée des échecs

| Diagnostic | Apparition / preuve Git |
|---|---|
| Baseline, hashes des seeds chaîne de production / coûts / ressources | Première rupture observée sur la première-parenté depuis 27b9bf56 : `fddc86e9`, 04/11/2026 22:23:15 +0100, #470. Changements de branche `532deca0`, `e238beae`, `8dd0c7ec` : ajout de dérivés pétrochimiques et modifications de SQL généré sans actualisation par le rendu. Comparaison MD5 des fichiers à l'INVENTAIRE de chaque révision bornée. |
| Baseline, entreprises_constantes | `61998041`, 06/11 23:22:26 +0100, #557 ; modification initiale `d5ce394e`, 23:18:07 : ajout de coef_prix_max_pj_soviet. 23 lignes contre 22 observées, hash ancien conservé. Décision livrée, pas une permission d'inventer la capture. |
| Authority, signature à cinq arguments | `a7e352f4`, 04/11 17:49:27 +0100 : livraison terrestre ajoute le paramètre p_livraison par DO/replace et exécute le résultat. Le corps présent est légitime ; l'ancien analyseur ne reconnaissait que le renommage d'en-tête constant. |
| Referential, première transition bornée | **Bisect réel** entre 27b9bf56 et efeee90a, dix exécutions ; bornes adjacentes rejouées : `a6d6fb71` vert (03/11 10:02:28 +0100), `1b51fee1` rouge (03/11 10:23:14 +0100, #390 SSM). Un seul diagnostic : nouveau catalogue ff9d27096e7e8dbd contre déclaration 0ffc6e1caad1f581. Le vert historique acceptait explicitement des divergences connues : il ne certifiait pas une base synchronisée. Résultats exacts dans CONTROLES-GLOBAUX-BISECT-20261107.json. |
| Referential, artefact ressources | `f698a6dc`, 04/11 22:14:06 +0100 : l'artefact livré contient 19 ressources mais son générateur gardait un ordre explicite à 18 ; manque derives_petrochimiques. Décision : GAME-DESIGN-CHANTIER-NAVAL.md §1 et regroupement #470. |
| Referential, mesure ressources et déclaration | `9142473a`, 04/11 22:15:12 +0100, a déjà relevé 19 ressources et laissé la vieille sentinelle signalée. Ne pas « réparer » la mesure en la déduisant de la copie serveur. |
| Bonus différés / entreprises | Nouveaux menus de Sovarka `4d3624d6` (06/11 21:24:25), véhicules `40606289` (06/11 00:15:27), autres décisions énumérées dans RELAIS et TARIFS-PLAN97-SOVARKA-20261106.md. Mesure historique restée datée du 01/11 17:55:21.375915. |

## Corrections et contre-épreuves

### Authority : reconnaître une extension réellement exécutée

Analyse statique stricte dans declarations_dynamiques.py, raccordée au vérificateur.
Exige signature source connue ET nom réel du dernier paramètre ET ancre présente dans l’en-tête canonique
(pas un alias de type ni un paramètre à valeur par défaut incompatible), ancien/nouvel en-tête
parsés PostgreSQL, remplacements à littéraux, même variable exécutée hors branche
conditionnelle, pas de retour ni réaffectation opaque/SELECT INTO. Ce n'est pas une
liste blanche de trading_acheter et ce n'est pas une preuve de déploiement.

Positif : vraie migration 20261104173000 et fixture d'extension. Contre-épreuves :
source absente, ancre de mauvais nom/type, mauvaise variable, EXECUTE commenté/absent
ou conditionnel, source conditionnelle, écrasement opaque, SELECT INTO, RETURN,
fonction jamais exécutée, autre langage, bloc commenté. Une signature à six arguments
n'est pas attestée. Anciens bancs des détecteurs et des déclarations dérivées conservés.
Aucune migration historique ni permission modifiée.

### Référence du générateur de ressources

Ajout de derives_petrochimiques à l'ordre explicite, à la place qu'elle occupe DÉJÀ
dans api/_referentiels-generes.js, entre carburant et desinfectant. Le générateur
rend maintenant exactement les 24 constantes déjà livrées ; **aucun octet du module
serveur changé**. Retirer cette clé fait échouer la génération ; altérer son prix
fait détecter un écart par le comparateur. Aucun nouveau montant choisi.

### Seeds miroirs, exclusivement par leur générateur existant

Commande : `python outils/baseline/regenerer-seeds-miroirs.py`.
Les huit sorties sont vérifiées à nouveau ; trois hashes d'artefacts sont mis à jour
par ce rendu, jamais des observations de production.

- ordres_couts : **463 → 488**, 27 ajouts et 2 retraits. Ajouts : quatre prix PSM
  (19 800 / 37 200 / 50 400 / 66 000), quatre menus véhicules gratuits,
  renseignement 2/0, coiffure/pharmacie/poissonnière, les ordres Sovarka livrés,
  dîner 2/100, menu Virements 0/0. Retraits : les anciens virements joueur et
  automatique 1/0, remplacés par ce menu. Toutes ces valeurs sont dans les sources
  actuelles et décisions déjà livrées, détaillées dans le plan 97 et RELAIS ; aucune
  n'est introduite dans data.js ou dans une RPC par ce chantier.
- pa_bonus_differes : **10 → 13**, uniquement les trois menus russes avec le bonus
  existant +3, déjà livrés au Grand Hôtel (RELAIS, 06/11, `4d3624d6`).
- ressources_economie : **19 → 19**, aucune ligne ajoutée/retirée/modifiée. Seul le
  hash d'artefact était ancien ; le vrai générateur produit exactement le SQL présent.

Contre-épreuve sur copie temporaire : un tarif de terrain altéré est refusé par
`--verifier`, même si les autres fichiers sont intacts. Les sources ne sont jamais
modifiées pour obtenir un résultat positif.

### Convention de dotation <clé>@<ville>

Le générateur d'entreprises exécutait toutes les fonctions uniquement à capitale.
Il exécute désormais les MÊMES fonctions dans les villes du référentiel et n'émet
une clé locale que si sa projection diffère. Il trouve marche@ville_b : six produits,
carbonade comprise, contre la carte de Luthécia inchangée. Aucune recette, caisse,
valeur de stock ou règle inventée. L'UPSERT des clés générées conserve les variantes
non générées posées par d'autres migrations ; le DELETE des seules clés générales
est maintenu. Aucun SQL ainsi produit n'a été appliqué.

Source de décision : RELAIS, « Catalogues de Montrouge M-02/M-03 », livraison #316 ;
migration archivée 20261101030000. Contre-épreuve : ancienne extraction limitée à la
capitale perd la clé locale. Le vrai seeds.py testé sur export de fixture conserve
intégralement cette clé et calcule son hash ; il ne nécessitait pas de tolérance ni de
filtre supplémentaire. La capture actuelle des seeds reste à refaire, pas à simuler.

## Tests et limites

Six tests Python nouveaux, raccordés au contrôleur client par un banc Node, plus
les détecteurs existants : huit tests Node ciblés passent. Le témoin Chromium 1440
reste strictement identique. Vérificateur Workflow conforme et diff sans erreur.
Les deux campagnes complètes avant et après intégration de #588 passent à 200/200.
La contre-épreuve Python -O confirme qu’un mauvais nom de paramètre reste refusé
même avec l’optimisation de l’interpréteur ; aucune garde du vérificateur ne repose
sur une instruction assert. Dernier rejeu complet consigné dans les résultats finaux.

## Pourquoi les deux rouges ne sont pas maquillés

Baseline conserve deux seeds socle de six / vingt-trois lignes alors que ses
observations en attendent cinq / vingt-deux ; leurs hashes ne correspondent pas au
rendu archivé. Restaurer les anciennes lignes perdrait des décisions livrées ;
recalculer uniquement le hash et le nombre masquerait l'absence d'une capture réelle.
Il faut réextraire, puis rendre ces seeds par seeds.py et les attentes par l'outil
canonique. Les SQL concernés n'ont donc pas été édités dans cette branche.

Referential reste à trois écarts de déclaration : ordres_couts, pa_bonus_differes,
miroirs_entreprises. Une nouvelle mesure doit distinguer photographie périmée d'une
vraie divergence de contenu ou de sentinelle. Aucune connexion Supabase n'est exposée
par les outils de cette session ; aucune donnée vivante n'a été reçue ou inventée.

Le dispositif de reprise est `outils/livraison/COLLECTE-CONTROLES-GLOBAUX-20261107.json` :
réutilisation des quatre exports, contrôle global, mesures et rendu des seeds existants,
en lecture seule et transaction cohérente par l'intégrateur. Aucun script à lancer par
Fred. Si une vraie dérive est constatée, banc annulé puis migration séparée à préparer,
application uniquement par Claude après contrôle du NOM de registre. Ce chantier ne
prépare pas de migration spéculative et n'a besoin d'aucun arbitrage de game design.

## Rejeu final et livraison de la branche

Main 947caad7 intégré et resté inchangé pendant la validation. SHA de code testé :
`db1496d6f9ca25db4181864b8eb6e57240687464`. **200/200 bancs clients**, six tests Python, huit bancs Node
ciblés, Workflow et diff conformes ; bureau 1440 strictement inchangé. Les douze
contrôles ont tous été réexécutés sur cette intégration : **10/12**, seuls
Baseline et Referential restent rouges. Résultats structurés :
`CONTROLES-GLOBAUX-RESULTATS-20261107.json`.

POST REST de création PR tenté : `Forbidden`. Aucune PR créée/fusionnée depuis
cette session. Titre et description prêts dans RELAIS.md ; Claude peut ouvrir
la PR de la branche poussée. Aucune nouvelle migration, aucun déploiement.
Le chantier **n'est pas clos à 12/12** : les deux restes exigent le relevé
canonique décrit, puis un rendu/rejeu réel, pas une décision de montant de Fred.
