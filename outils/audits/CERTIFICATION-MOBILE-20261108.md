# Certification web mobile — 8 novembre 2026

Branche `codex/mobile-certification-20261108`, départ main `520630bd`.
AGENTS.md et RELAIS.md relus ; #553 (`939a6238`) et #585 (`6f75bd26`) présents
au journal de main. Les lots L0–L10 sont conservés. Aucun développement natif.

## Reprise et défauts démontrés

La correction responsive Sovarka, poussée mais absente du main de départ, est
intégrée depuis `bc74ecd6`, sans réécrire ses moteurs. Les nouvelles règles de
Claude (#628) sont conservées ; la fixture de lecture `sovarka_pouvoir_lire` du
banc est raccordée au contrat désormais utilisé par le tribunal. Aucun écran
métier Sovarka modifié, aucune intervention sur #377.

1. **Reprise invalidée pendant sa propre lecture.** Le booléen `aRelire` pouvait
   être remis à faux après une deuxième mise en arrière-plan ou une notification
   d’un autre onglet, survenue pendant l’attente. L’ancien retour déverrouillait le
   prochain ordre sans nouvelle lecture. Reproduit sur les deux profils tactiles.
   Le contrôleur mobile existant mémorise maintenant la génération de suspension ;
   une réponse d’une génération dépassée laisse l’ordre bloqué. Le chargeur et
   l’authentification existants restent seuls utilisés. Pas de polling ni de rejeu.
2. **Reconnexion hors écran avec clavier.** À une hauteur visible de 350 px, le
   formulaire réel `afficherBandeauReconnexion` ne permettait pas d’atteindre le
   bouton de validation, même après demande de défilement. CSS mobile uniquement :
   conteneur défilant, hauteur visible existante, champs 16 px et boutons 44 px.
   Aucun changement des identifiants, de l’authentification ou des messages.
3. **Reconnexion interceptée par la garde métier.** Après une reprise refusée,
   les clics et le submit du vrai formulaire d’authentification étaient aussi
   bloqués. La garde laisse maintenant passer uniquement ce conteneur existant,
   comme son propre bouton de reprise. Le chargeur doit toujours confirmer l’état
   avant le prochain ordre : le test vérifie authentification et restauration,
   puis un premier clic encore suspendu, sans aucun ordre rejoué.

Témoins compressés publics, issus de code public, vérifiés par SHA-256 :
`fixtures/mobile-certification-temoin-520630bd.json.gz` →
`6e0a56feaba4d50f731551e2440f9f2962b50559ec6eabdb63960e3c70289f9c`.
Les contre-épreuves exécutent les vrais anciens JS/CSS et reproduisent les défauts.
Le moteur navigateur des bancs existants est mutualisé dans `mobile-navigateur.cjs` ;
ce fichier est uniquement de l’outillage et n’est jamais chargé dans le jeu.

## Périmètre de recette automatisée

| Parcours | Preuve accessible | Limite |
| --- | --- | --- |
| Accueil / connexion | Vrai HTML et gestionnaires ; refus puis compte existant, dans deux profils tactiles | Authentification fixture, aucun JWT ou compte réel |
| Création | Banc L4 existant, huit étapes dans six langues, lignes « En jeu » conservées | Aucun compte ni personnage créé |
| Journal d’accueil | Vrai lecteur de presse : 0, 1, 2 titres ; vrais boutons de fermeture et journal d’événements | URL, personnage, position, cache inchangés ; chargeur/session fixture |
| Reprise | Masquage, réseau, autre onglet, réponse tardive, délai, changement de contexte, verrou de clic | Événements simulés ; pas de verrouillage OS ni de deux appareils réels |
| Rues / pièces / tactile | Coque L2, flèches, liste tactile, tabs, destinations et gardes clients existants | Autorité distante non retestée sur compte connecté |
| Menus / fenêtres | Focus, fermeture, défilement, clavier réduit simulé | Clavier iOS/Android réel à vérifier |
| Inventaire / finances / commerce | L5, Helvetia double tap, contrôleur client complet | Aucun débit réel ; ces tests clients ne certifient pas seuls les RPC financières |
| PNJ | Panneau de présence / portraits et bancs de dialogue existants | Aucune réponse DeepSeek réellement obtenue dans cette session |
| Forum / messagerie / notifications | L6 tactile et contrôleur client ; reprise sans polling ajouté | Pas de message envoyé ni reçu en production |
| Organisations / institutions / groupes / combat | L7 vrai rendu et droits de rapport, bancs clients de groupes/police/combat | Pas d’arrestation, déplacement ou combat d’un PJ réel |
| Bureau | Comparaisons PNG strictes à 1440 px : plateau, création, forum ; nouveau témoin plateau et reconnexion | Rendu local, pas mesure du déploiement |

Nouveau banc : `outils/bancs/banc-mobile-certification.cjs`. Profils Chromium
390×844 et 360×800, mode tactile/mobile, échelles 3 et 2. Ces noms de profils
ne signifient pas qu’un iPhone ou Android physique a été testé. Les formats
375×667, 393×852, 412×915, 852×393, 768×1024 et Sovarka 360/390/768 sont conservés.

Pour la comparaison stricte bureau, les animations et transitions décoratives
sont figées identiquement des deux côtés. Un écart intermittent de deux rangées
de pixels de bordure du bouton flottant a été observé avant cette stabilisation.
Aucun masque, retrait de zone ni tolérance de pixels n’est utilisé.

## Résultats

Résultats définitifs à consigner après les derniers contrôles.

## Accès extérieurs et état de livraison

Le 08/11, `GET https://api.github.com/repos/FredJ74/res-publica/issues?...`
est refusé par le proxy (`Forbidden`). Impossible de relire les tickets ouverts
ou les derniers commentaires/contrôles CI via cet accès ; les PR fusionnées sont
confirmées par Git, pas par une prétendue lecture API.
`HEAD https://res-publica.vercel.app/plateau.html` échoue au tunnel CONNECT,
HTTP 403 Envoy. Ce refus **ne prouve aucune panne Vercel** et ne fournit aucun
statut READY, SHA servi ou mesure réseau. Aucun déploiement de test déclenché.
Création REST de PR tentée après le premier push :
`POST /repos/FredJ74/res-publica/pulls` → `Forbidden`.
Branche sauvegardée ; pas de PR créée ou fusionnée depuis cette session.

Ni compte recréé, ni secret consulté, ni migration, ni écriture en production.
Le protocole physique court est `RECETTE-PHYSIQUE-MOBILE-20261108.md`.
La recette connectée, les appareils physiques, la CI et le déploiement sont des
preuves distinctes : aucune ne sera déduite des fixtures locales.
