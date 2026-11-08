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

Pour la comparaison stricte bureau, les feuilles du témoin sont servies dès le
premier rendu, dans leur ordre d’origine. Le remplacement après affichage produisait
un écart intermittent de deux rangées de pixels sur la bordure du bouton flottant.
Les animations et transitions décoratives sont figées identiquement des deux côtés.
Aucun masque, retrait de zone ni tolérance de pixels n’est utilisé. Le lancement
Sovarka réutilise le helper commun qui détecte Chromium ou Google Chrome, au lieu
de présumer `/usr/bin/chromium` (portabilité runner, pas incident CI prétendu).

## Résultats

- Passe globale unique sur le code applicatif `6251fe6a` : **10/12**.
  Workflow et Authority conformes. Baseline : seeds `chaines_production_usine`
  (6 lignes contre 5) et `entreprises_constantes` (23 contre 22), empreintes de
  manifeste discordantes. Referential : déclarations historiques `ordres_couts`
  (439 lignes) et `pa_bonus_differes` (10 lignes) divergentes des sources actuelles.
  Ces sources/seeds ne sont pas modifiés par ce lot ; aucune mesure vivante
  Supabase, empreinte ou tolérance n’a été fabriquée.
- Première passe client complète : **202/203**, seul échec dans la comparaison
  du nouveau témoin bureau. Le chargement du témoin a été corrigé comme décrit
  ci-dessus ; le test n’a été ni désactivé ni rendu tolérant.
- Passe client complète finale sur `65ecf3f445c339f8a832f55005aa1f6f1073a536` :
  **203/203 bancs**, zéro échec, aucun SQL exécuté. Le nouveau banc compte
  **17/17 scénarios**, dont quatre contre-épreuves. Les 22 cas certification et
  Sovarka avaient aussi été validés ensemble avant cette passe.
- Pilote de recette : **119/119 tests**, sur fixtures/serveurs locaux. Aucune
  campagne authentifiée Arnie lancée, aucun secret lu.
- Analyseur API : **28/28 modules**, sans appel distant.
- Cinq paires PNG 1440×900 strictement identiques (plateau, création, forum,
  plateau témoin actuel et reconnexion). Empreintes et résultats structurés :
  `CERTIFICATION-MOBILE-PREUVES-20261108.json`.
- Main revérifié après tests : toujours `520630bd`, inclus dans la branche,
  aucun conflit. `git diff --check` conforme.
- Environnement : Node 24.19.0, Playwright 1.62.1, Chromium 154.0.8037.57,
  Debian 13. Ces résultats locaux ne sont pas ceux d’un runner GitHub.
- Contre-épreuves conservées pour les trois défauts. Aucun SQL exécuté.

La passe globale n’est pas répétée à chaque essai : les modifications de
stabilisation ultérieures concernent seulement les bancs navigateur, pas le
code applicatif ni les fichiers examinés par Baseline/Referential.

## Accès extérieurs et état de livraison

Le 08/11, `GET https://api.github.com/repos/FredJ74/res-publica/issues?...`
est refusé par le proxy (`Forbidden`). Impossible de relire les tickets ouverts
ou les derniers commentaires/contrôles CI via cet accès ; les PR fusionnées sont
confirmées par Git, pas par une prétendue lecture API.
`HEAD https://res-publica.vercel.app/plateau.html` échoue au tunnel CONNECT,
HTTP 403 Envoy. Ce refus **ne prouve aucune panne Vercel** et ne fournit aucun
statut READY, SHA servi ou mesure réseau. Aucune commande Vercel ni mise en production effectuée. D’éventuels Preview
automatiques liés aux pushs ne sont pas observables depuis cette session.
Création REST de PR tentée après le premier push :
`POST /repos/FredJ74/res-publica/pulls` → `Forbidden`.
Branche sauvegardée ; pas de PR créée ou fusionnée depuis cette session.
Titre prêt : **Mobile : fiabiliser la reprise et certifier les parcours critiques**.
Head : `codex/mobile-certification-20261108` ; base : `main`.
Description prête : « Trois correctifs du socle de reprise/reconnexion, fenêtres
Sovarka existantes réutilisées, aucune modification de règle ou SQL. Tests des
vrais boutons du journal, connexion sur fixtures, contre-épreuves et témoins
bureau 1440 stricts. Rapport CERTIFICATION-MOBILE-20261108.md et protocole physique
associé. Exiger la CI du SHA final avant fusion ; ne pas annoncer le déploiement
ou les appareils physiques comme validés. »
Les contrôles distants attendus restent ceux du dépôt ; aucune garde contournée.

Ni compte recréé, ni secret consulté, ni migration, ni écriture en production.
Le protocole physique court est `RECETTE-PHYSIQUE-MOBILE-20261108.md`.
La recette connectée, les appareils physiques, la CI et le déploiement sont des
preuves distinctes : aucune ne sera déduite des fixtures locales.


## Verdict par niveau

| Niveau | État réel |
| --- | --- |
| Codé | Trois correctifs de reprise/reconnexion ; formulaires communs Sovarka déjà préparés repris |
| Testé automatiquement | 203/203 bancs clients, 119/119 pilote, syntaxe 28/28 ; globaux 10/12 avec restes explicites |
| Appareil réel | Aucun ; protocole court prêt pour Safari iPhone / Chrome Android |
| Fusionné | Anciens L0–L10 déjà dans main ; cette branche n’est pas fusionnée |
| Déployé | Aucune mise en production par Codex ; version servie et READY non vérifiables ici |
| Validé en jeu | Aucune connexion réelle, réponse IA ou transaction production certifiée par cette session |

**Certification complète non acquise.** La branche et les preuves sont livrables
pour revue ; restent l’ouverture de PR et la CI sur son SHA final, l’intégration,
la vérification Vercel et la recette connectée/physique. Les appareils réels
restent explicitement à tester même si les automatismes passent. Aucune décision
de game design n’est requise, aucune opération SQL demandée à Fred.
