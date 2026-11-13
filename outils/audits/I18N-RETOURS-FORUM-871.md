# Issue #871 — retours fixes du forum et de la messagerie

## Périmètre

**43 clés nouvelles dans neuf langues**, soit **344 traductions étrangères** :
30 messages et 13 titres. Le refus « Remplissez tous les champs. » réutilise la
ressource livrée dans le lot courrier ; les titres déjà traduits sont conservés.
Les 44 points de présentation couvrent notamment lecture/accès non confirmés,
identité d’organisation, champs requis, hospitalisation, publication/modification,
insertion d’image et forum local périmé. Le nom du forum **La Présidence à la Nation**
reste inchangé dans toutes les langues.

L’enregistrement facultatif `RPToastI18n.registerTitle(original,key)` permet de
raccorder un titre à une ressource déclarative sans ajouter de moteur ou réécrire
les anciens titres. Un titre déjà connu ne peut pas être remplacé. `label` et `key`
restent compatibles, et toute ressource manquante se replie sur le français.

`showToast` reçoit toujours ses arguments canoniques d’origine. Le point commun
`RPI18nPlateau.markToast` marque ensuite les mêmes textes et titres. Aucune règle,
condition, lecture/écriture, requête ou vérification de droit n’est rejouée par une
bascule de langue. Les messages et titres disparaissent naturellement au prochain
toast ; ils ne se réaffichent pas sur une notification différente.

## Preuve de non-modification métier

Le banc compare l’AST **entier** de `forum.js` à la référence : après retrait des
44 appels de présentation, les programmes sont identiques. Un seul `if` sans
accolades est enveloppé pour garder son marqueur sous la même garde ; son bloc
d’une seule expression est normalisé dans cette comparaison. Aucun autre arbre
de conditions, appel, argument, date, droit, verrou ou traitement n’est écarté.

Les trois variantes « composition vide » conservent exactement leurs conditions
et leurs phrases originales ; seul l’identifiant de présentation correspondant
est sélectionné avec ces mêmes booléens locaux.

## Vérifications

- 43 références françaises exactes retrouvées dans le code d’origine ; neuf
  langues, aucun manque et nom de forum préservé.
- Titres existants, refus d’enregistrement concurrent et repli français testés.
- Chromium : **31 messages × 9 langues × 3 formats = 837 rendus**, avec titres,
  arabe RTL, curseur/brouillon inchangés et absence de débordement horizontal.
- Treize chemins réels de validation (courrier, hospitalisation, rôles, champs,
  réponse vide, trois compositions vides et ville locale périmée) : **351 bascules**,
  sans nouvelle RPC, sérialisation, publication, débit ou notification.
- Les autres états d’erreur sont rendus sans rejouer de transaction serveur.
  Aucun compte de joueur, publication réelle ou courrier réel utilisé.
- Traduction absente et notification suivante non marquée : français conservé,
  aucun ancien texte ou titre ne revient.

L’audit reconnaît les branches de notification seulement si les mêmes conditions
choisissent la clé et le français. Les titres sont prouvés via la référence
effectivement enregistrée dans le service commun. Comparaison contrôlée avec le même extracteur : **+43 textes uniques entièrement
raccordés et +313 mots source** dans chacune des huit langues étrangères ;
+43 ressources uniques et +311 mots en ressources. Le corpus demeure identique
(7 538 textes, 50 314 mots) ; aucun gain artificiel par suppression de textes.
L’extracteur vérifie désormais le chargement effectif des catalogues : les taux
antérieurs calculés avec une méthode différente ne constituent pas une comparaison
valide. Preuve détaillée : `I18N-RETOURS-FORUM-871-mesures.json`.

## Hors couverture

Les contenus libres, les réponses serveur variables, les notifications de
suppression à titre seul et les autres fenêtres de l’éditeur ne sont pas déclarés
traduits par ce lot. Relecture native, compte authentifié et téléphone physique
restent non vérifiés. Aucun chantier de rétention ou d’énigme n’est ouvert.
