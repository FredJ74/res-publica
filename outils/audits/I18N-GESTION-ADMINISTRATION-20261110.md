# Internationalisation : gestion, entrepôt, notaire, vente/don, port/douanes — 10/11/2026

## Résultat et portée

Quatre lots cumulatifs, **159 nouvelles clés dans les neuf langues** (fr, en, es,
zh-TW, ru, ko, ar, pt-BR, de). Architecture i18next existante conservée ; aucun
service de traduction appelé. Code final testé `08336f09`, réconcilié avec
`main` **2f30d23b** (#699, #700, #701). Les 153 clés précédemment intégrées par
#698 ne sont pas refaites. La traduction complète du jeu reste en cours.

| Lot | Branche / SHA poussé | Couverture effective | Clés |
|---|---|---|---:|
| A | `codex/i18n-gestion-commerces-20261110` / `b73a86b8` | Gestion PJ : caisse, stocks, produits, matières, approvisionnement, tableaux, statuts, formulaires | 52 |
| B | `codex/i18n-entrepot-notaire-20261110` / `f2b8212b` | Achat entrepôt et consultation/recherche du dossier notarial | 21 |
| C | `codex/i18n-vente-don-matieres-20261110` / `dd451135` | Vente/don de matières : quantité, confirmation, refus, erreurs, succès | 65 |
| D | `codex/i18n-port-douanes-20261110` / `08336f09` | Consultation du port, exportations, origines, caisse et effectifs douaniers | 21 |

## Modifications

Quatre catalogues spécialisés dans `i18n/`, sept alias supplémentaires dans
`toast-resources.js`. Raccordements ciblés dans `plateau-commerce-pj.js`,
`plateau-justice-economie.js`, `plateau-actions-illegales-rumeurs.js` et extension
rétrocompatible du helper de présentation `ficheLibelleHtml` dans `plateau-objets.js`.
`plateau-init.js` étend le passage de traduction existant aux libellés mobiles
`data-l` et aux préfixes textuels contenant un compteur en gras : aucun nouvel
écouteur, moteur ou mécanisme de synchronisation. Versions de cache augmentées
dans `plateau.html`, en conservant celles des changements concurrents de main.

Repli canonique français conservé (clé absente, traduction vide ou variable non
résolue). Les valeurs zéro, prix, unités, dates et paramètres restent ceux du
parcours existant. Les textes inconnus et contenus personnels restent littéraux.
Les noms de lieux, matricules, noms de personnes et destinations ne sont pas
traduits arbitrairement. Les citations d'ordres du port réutilisent les libellés
existants, vérifiés dans les neuf langues.

**Aucun changement de coût, PA, formule, permission, RPC, migration ou état joueur.**
Les handlers, paramètres, refus et conditions d'exécution restent les mêmes ;
changer de langue ne relance aucune commande et ne relit pas le serveur.
Aucun diff introduit dans `data.js`, `plateau-multijoueur.js`, les images,
les migrations, les modules Sovarka ou le chantier Règles/Claude.

## Vérifications et contre-épreuves

- **28/28 tests ciblés** : 22 nouveaux cas, plus notifications et audit éditorial.
  Les boucles couvrent les neuf langues, 360/390 px, RTL, libellés longs, bascule
  à chaud et conservation des saisies ; 768 px également pour la gestion.
- Six comparaisons PNG françaises **strictement identiques octet pour octet à
  1440 px** : gestion, entrepôt, notaire, vente/don, port, douanes. Témoins de code
  public figés au main de départ `336eace8`, hashes vérifiés par les bancs.
  Pas de tolérance visuelle ajoutée. Des différences de façonnage de texte et
  d'attributs ont été corrigées avant livraison, pas masquées.
- Catalogue éditorial : **1 579 clés françaises**, neuf langues, aucune clé
  manquante ni incohérence de variables. Les listes `unchanged` de l'auditeur
  restent disponibles : ce contrôle ne remplace pas une validation linguistique.
- Contre-épreuves réelles de l'auditeur : retrait d'une clé allemande de stock
  détecté ; substitution du paramètre date du notaire détectée. Script
  `contre-i18n-gestion-20261110.py`, travaille uniquement sur copies temporaires.
- Refus/erreurs/succès vente-don : comparaison avec les anciens handlers et états,
  neuf langues et vingt résultats par mode ; quantités nulles/invalides,
  double exécution, absence d'effet du changement de langue vérifiées.
- Stock civil entrepôt distinct du stock physique, refus légal préservé ; erreurs
  partielles de lecture notariale et dates conservées ; aucune lecture additionnelle.
- Banc historique stock unique : mêmes vingt vérifications, son harnais charge
  désormais les vrais helpers de présentation. Le don vérifie toujours le handler,
  le mode et le libellé. Aucun test désactivé.

**275/276 bancs clients réussis** sur le code final réconcilié. Le seul rouge est
`banc-pnj-localisation-psm.mjs`, assertion de régénération exacte des scènes.
Reproduit sur main intact **2f30d23b** : quatre scènes du centre artisanal de
Novomirsk conservent les anciens noms alors que #701 a renommé le bâtiment et
ses pièces. Diff conservé dans `pnj-main-ecart.diff`, log compressé et résultats
complets joints. Les quinze autres cas de ce banc passent. Le précédent écart
Dynamo est corrigé sur main ; ce nouveau décalage est distinct. Aucun fichier
PNJ/Sovarka de Claude n'a été modifié pour obtenir un résultat artificiellement vert.
L'intégrateur doit faire réconcilier ce fichier généré par le chantier concerné,
puis observer la CI sur les SHA intégrés.

**Globaux : 10/12 sur branche ET main intact 2f30d23b**, journaux identiques.
Workflow et Authority conformes. Les deux rouges restent Baseline (fonction
club_accessoire_acheter, fichier sport et seeds/observations anciens) et
Referential (empreintes ordres_couts, pa_bonus_differes, miroirs_entreprises).
Détail intégral dans les journaux conservés. Aucune empreinte, référence,
observation ni assertion modifiée pour masquer ces anomalies.

## Intégration : instructions prêtes

Les quatre branches sont poussées, toutes réconciliées avec main 2f30d23b.
Ouvrir/intégrer dans l'ordre **A → B → C → D**, en redirigeant chaque PR vers le
main actualisé après intégration précédente (ou conserver la pile pour la revue).
Ne pas importer une ancienne version complète des fichiers de main.

| Lot | Titre de PR | Description prête / contrôles attendus |
|---|---|---|
| A | i18n : gestion des commerces PJ, stocks et approvisionnement | 52 clés / neuf langues ; repli canonique, libellés mobiles et bascule sans perte de saisie ; trois tests ciblés, PNG français strict, CI habituelle ; aucun ordre/RPC modifié. |
| B | i18n : achat entrepôt et consultation notariale | 21 clés / neuf langues ; réutilisation du renderer, noms/dates/lois conservés ; quatre tests ciblés et deux PNG stricts ; lectures identiques. |
| C | i18n : vente et don de matières | 65 clés / neuf langues, confirmation/refus et messages ; transactions inchangées ; douze tests ciblés, stock unique et notifications ; PNG strict. |
| D | i18n : consultations du port et des effectifs douaniers | 21 clés / neuf langues ; sources/chiffres/noms conservés, aucun recrutement/paiement changé ; trois tests ciblés, deux PNG stricts, preuves cumulatives. |

Une tentative REST de création de PR a reçu **403 Forbidden**. Aucun numéro de PR
inventé, aucune fusion effectuée. Les branches et ces descriptions permettent
à l'intégrateur de créer les PR. Les contrôles CI distants et Vercel READY ne sont
pas observés sur ces branches. HEAD production tenté le 10/11 à 21:49 UTC :
**CONNECT tunnel failed, 403 envoy**, accès bloqué par le proxy local ; ce n'est
pas une preuve d'échec de Vercel. Aucun déploiement déclenché.

## Reste à traduire / limites

L'inventaire complémentaire est conservé dans `surface-candidate.json.gz` et
`gestion-restante-a-examiner.json`. La table française locale de gestion contient
218 clés : 52 raccordées dans ce lot, **166 à examiner** (ce nombre inclut des
chemins de compatibilité ; ce n'est pas 166 écrans actifs certifiés).
Restent notamment création/configuration des références, agences et certains
refus détaillés ; autres procédures notariales ; gestion douanière/logistique
modificatrice ; écrans spécifiques d'usine/armurerie. Le commerce premium et les
travaux PNJ/Sovarka ne sont pas repris. Les anciens écrans de marché inactifs ne
sont pas réactivés pour les traduire.

Tests Chromium locaux avec fixtures et réseaux externes bloqués : **pas de
recette authentifiée, pas d'essai sur téléphone physique, pas de transaction
réelle et pas de certification du serveur par ces tests de présentation**.
La revue linguistique humaine et la recette du déploiement restent distinctes.

## Rejouer les contrôles locaux

Avec les dépendances de test du dépôt installées et Chromium disponible :

```sh
node --test outils/bancs/banc-i18n-gestion-commerce.cjs outils/bancs/banc-i18n-administration-economie.cjs outils/bancs/banc-i18n-vente-don-matieres.cjs outils/bancs/banc-i18n-port-douanes.cjs outils/bancs/banc-i18n-notifications.cjs outils/bancs/banc-i18n-editorial.cjs
python outils/audits/contre-i18n-gestion-20261110.py
node outils/audits/audit-i18n-editorial.cjs
python outils/bancs/controler-client.py --rapport /tmp/hg-i18n-clients
python outils/baseline/controler-tout.py
```

Les bancs navigateur lancent exclusivement un serveur HTTP local et bloquent les
accès externes. Les chemins `/tmp` utilisés pour les preuves ne contiennent aucun
compte ni secret. La CI existante découvre les quatre nouveaux bancs ; pas de
pipeline redondant ajouté. Les résultats ci-dessus ont été exécutés, pas seulement
préparés ; leurs sorties et empreintes sont dans le dossier de preuves.
