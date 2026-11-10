# Couverture réelle de l’interface — reprise du 10 novembre 2026

Base `b29d676f69ffa7b0f8c7c2f7417c250ff5407d4d`, après #377 et lots #671–676.
Le socle existant est conservé : i18next, neuf catalogues, marqueurs des fenêtres
ouvertes, protection des valeurs et des noms métier. Aucun nouveau moteur.

## Inventaire systématique et limites

L’outil existant `inventaire-i18n-plateau.cjs` est étendu aux entrées index/auth et
aux deux interfaces forum, précédemment absentes de son filtre. La capture après
raccordement est jointe dans `i18n-premiers-parcours-20261110/surface-candidate.json` :
53 fichiers, 163 marqueurs repérés, 667 affectations textuelles littérales et 837
sites de HTML dynamique. **Ce ne sont pas 667 traductions manquantes** : un site
peut être vide, déjà traduit, métier ou un contenu RP à préserver. Pas de taux de
couverture trompeur déduit de ces nombres. L’outil sert de file de vérification.

| Surface | Existant constaté | Lacunes / action |
| --- | --- | --- |
| Accueil et création | Neuf catalogues, formulaires et étapes, exemples de caractéristiques | Plusieurs messages du login à mot de passe encore français dans creation.js:32–110 ; lot suivant |
| Premières scènes/PNJ | Accueil scénarisé, guide, amorces et statuts déjà localisés | Prose RP et réponses IA hors de ce lot ; aucun fournisseur appelé |
| Navigation/plan/transports | Lots #673/#674 en place ; noms et fenêtres conservés | Nouveaux contenus de Sovarka à suivre sans changer les mécaniques de Claude |
| Ordres de bâtiment | 417 clés canoniques ; variantes/templates existants | Le seul « stable manquant » du relevé est le préfixe dynamique de sovarka_reunion_reserver ; son libellé complet est déjà pris en charge par orderTemplates, ne pas créer un doublon |
| Inventaire rempli et détail | Seul le vide était câblé | **32 clés × 9 locales raccordées dans ce lot** : labels, infobulles, expiration affichée, commandes et 14 refus |
| Fiche, organisations, institutions, commerces | Plusieurs catalogues déjà présents | Nombreuses fenêtres et corps de messages encore français ; vérifier la capture fonction par fonction |
| Forum/courrier | Commandes et fenêtres ouvertes déjà raccordées par #674 | Les textes libres ne sont pas traduits par ce travail ; aucun nouveau service privé/HTTP |

## Lot inventaire : périmètre exact

Branche `codex/i18n-premiers-parcours-20261110`. Nouvelle ressource
`i18n/inventory-ui-resources.js`, chargée avant initialisation. Les 18 clés
visuelles et 14 messages réutilisent le moteur existant ; aucune traduction du
nom, de la description RP, du document officiel ou du nom du destinataire.

- `renderInventory` : illégalité, infobulles déposer/supprimer/protection, ligne
  d’expiration avec **la valeur existante** ; quantités et noms intacts.
- `ouvrirDetailObjetInventaire` : chargement et avertissement, consommer/fumer,
  cartes postales, installer/ouvrir/copier une clé, donner/abandonner/détruire,
  avertissement d’objet de mission. Les conditions, handlers et lectures restent
  ceux de main. Aucun effet n’est exécuté pour traduire.
- `messageRefusSortieInventaire` : le motif serveur et le texte français sont
  conservés ; seul le message affiché prend la langue courante. Le titre servant
  au diagnostic d’incident et les journaux métier ne sont pas réécrits.
- Interpolation : extension du point d’entrée commun apply avec
  `data-i18n-values` → `{{values.day}}`. Valeurs primitives isolées des options du
  moteur : aucun remplacement de lng/defaultValue, aucune formule/calcul. Format
  invalide ou variable manquante : retour au texte original et à sa direction.
- Audit éditorial : inclut les quatre catalogues déjà livrés mais oubliés de la
  mesure (municipal/social PNJ/actions/navigation), puis l’inventaire. **1 203 clés
  FR de référence, aucune clé ni variable manquante dans les neuf locales**.
  Sur les 70 clés ajoutées à la mesure, 32 sont nouvelles ici et 38 existaient
  déjà : ne pas revendiquer 70 traductions développées par ce lot.

## Vérifications et contre-épreuves

Nouveau banc : six cas, dont neuf bascules sur inventaire rempli ; neuf types
d’objets ; AR/FR/DE avec mêmes destinataires/handlers/quantités ; aucun effet ni
relecture pendant les bascules ; motifs de refus distincts ; paramètres invalides
et options moteur protégées ; deux images bureau 1440 strictement identiques.
Le témoin contient uniquement les trois fonctions publiques de main b29d676f,
compressées et vérifiées SHA-256, sans dépendre de la profondeur Git de la CI.

Une première comparaison a détecté quatre pixels de l’avertissement FR : le
sous-span séparait le pictogramme et le mot. Le bloc original est maintenant
traduit d’un seul tenant. **Aucune tolérance ou assertion assouplie.**

`contre-i18n-inventaire-20261110.py` joue l’auditeur réel sur des copies : une clé
allemande supprimée et une variable renommée sont bien détectées. La détection des
variables pointées est ajoutée, pas contournée. Un garde assure que tous les
catalogues de ressources référencés dans plateau.html participent à la mesure.

Premier contrôleur complet : **263/264**, uniquement le banc courrier déjà cassé
sur main. Reproduction avec les fichiers exacts de main : le bouton Répondre
lève une erreur JS car trois helpers de #674 n’étaient pas extraits par le banc.
Correction de l’outillage : charger ces vrais helpers, échouer immédiatement sur
pageerror ; les **trois tests** (390/1280 et contre-épreuve) restent et passent.
Aucun fichier forum.js/CSS modifié. Contrôleur final à consigner au relais.

## Livraison et recette

Code et tests locaux ne sont pas une publication. API GitHub de lecture refusée
403 : absence de PR concurrente vérifiée uniquement dans main, le relais et les
références disponibles, pas certifiée sur les métadonnées privées de GitHub.
PR à ouvrir : **Inventaire : commandes, infobulles et refus dans neuf langues**.
Description : « Raccorde 32 clés au moteur existant, valeurs et actions conservées,
AR/FR en session, mêmes pixels FR à 1440. Complète la mesure des ressources et
répare le chargement de trois helpers dans le banc courrier. Aucun SQL, RPC ou
mécanisme de jeu modifié. » Contrôles : bancs clients, workflow, i18n et Chromium.

Sur téléphone : consulter un objet, changer de langue puis revenir en français ;
vérifier nom/quantité, infobulles et destinataire conservés. Aucun don ou abandon
réel n’est nécessaire à cette recette. Safari/iPhone et Android physiques non
exercés ici. Validation linguistique humaine distincte des contrôles structurels.
