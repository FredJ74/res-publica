# Continuité des PNJ municipaux de Luthécia — 15 octobre 2026

## Périmètre et résultat

Les deux bureaux de Luthécia conservent chacun un PNJ permanent. Un titulaire
PJ fait afficher « Secrétaire général de la mairie » ou « Secrétaire du maire
adjoint ». Une vacance confirmée rétablit le titre PNJ. Une lecture impossible
affiche une fonction non vérifiée, jamais une vacance supposée.

Le nom, le métier technique et l'identifiant de dialogue du maire existant
restent inchangés : `Le Maire de Luthecia (PNJ)`, `maire`,
`le_maire_de_luthecia`. Les conversations restent donc rattachées au même profil.
L'ancien déplacement vers le hall, qui fabriquait un autre personnage nommé
Gaston Ferule, est supprimé. Aucun historique persistant n'est réécrit.

Le bureau de l'adjoint était vide dans le casting. Une seule entrée permanente
`Le Maire Adjoint de Luthecia (PNJ)` et son profil de dialogue sont ajoutés,
uniquement dans la surcharge `WORLD.republic.capitale`. Il s'agit du casting
applicatif : aucune ligne de titulaire ni aucun personnage joueur n'est créé
en base. L'absence de doublon dans les données réelles n'a pas pu être auditée.

## Audit des circuits existants

- Le titulaire élu du poste de maire vient de `cycles_electoraux.data.eluId`.
  La présence dans une pièce ne constitue pas un mandat. L'ancien résolveur
  conservait un cache électoral pouvant rester périmé.
- Pour l'adjoint, `postes_attribues` porte l'attribution ; `personnages` permet
  de confirmer le PJ et `titulaires_pnj` fournit le repli PNJ.
- Le nouveau module `continuite-municipale.mjs` centralise ces lectures pour
  l'affichage et le dialogue serveur. Les filtres comprennent pays, ville et
  poste ; les lectures ambiguës, invalides ou indisponibles sont refusées.
  Le schéma et les politiques de lecture ont été consultés dans le dépôt,
  sans réextraction ni modification du baseline.
- L'affichage relit ces registres à l'entrée et via le rafraîchissement de
  présence existant (30 secondes). Les réponses devenues obsolètes après
  navigation ou une autre lecture ne peuvent pas écraser le titre récent.
- `api/chat.js` détermine lui-même la fonction sous le jeton authentifié du
  joueur. Le navigateur ne peut pas lui transmettre une fonction. Sous mandat
  PJ, le contexte impose le rôle de secrétaire et interdit les décisions
  réservées au titulaire ; si la lecture échoue, il reste neutre.
- Aucun pouvoir n'est attribué par ces cartes ou par le dialogue. Les circuits
  de candidature, nomination, révocation et les portes serveur existantes
  restent en place. Aucun ordre, coût ou droit n'est ajouté.

## Vérifications exécutées

`node --experimental-vm-modules --test outils/bancs/banc-continuite-municipale.mjs`
: **24 tests réussis** sur les vrais modules applicatifs, avec registres et
transports simulés : deux transitions PNJ → PJ → vacance, rechargement, stabilité
des identités et de l'historique, conservation par le filtre de présence,
actualisation périodique, cache périmé, panne, attribution orpheline, ambiguïté,
réponses tardives, dialogue serveur et rejet d'une fonction fournie par le client.
Le test du dialogue traverse le handler et son contrôle d'authentification avec
une réponse d'authentification simulée : ce n'est pas une connexion réelle.

Non-régression, tous réussis :

- `banc-nominations-municipales.cjs` : 101 tests.
- `banc-titre-pnj-de-poste.js` : 93 épreuves.
- `banc-dialogue-pnj-republia.js` : 40 épreuves.
- `banc-contexte-public-dialogue.js` : 28 épreuves.
- `banc-memoire-mandats-dialogue.js` : 34 épreuves.

Les quatre bancs historiques JS sont exécutés avec `lancer-banc.py` et
l'adaptateur JS local de l'environnement cloud. Aucun test ne modifie de joueur
réel. Les contrôles syntaxiques, `git diff --check` et la garde du payload Vercel
complètent les bancs fonctionnels.

## Vérifications restantes et image

Le fichier `bureau-maire-luthecia-corrige.webp` et son ZIP ne sont pas présents
dans les pièces jointes accessibles à cette session. Le seul ZIP accessible est
l'ancien `mairie-luthecia-pour-codex.zip`, destiné à l'accueil. Il n'est pas utilisé
pour le bureau. L'image actuelle `images/bureau-maire-luthecia.webp` est conservée.
À réception du bon fichier, seule la référence
`ROOM_IMAGES_EMPIRE.republic['mairie-capitale'].bureau_maire` doit changer si le
nom du fichier change. Le visuel partagé `images/bureau-maire.webp`, utilisé
notamment par l'adjoint, ne doit pas être remplacé.

Aucun connecteur Supabase n'est exposé à cette session et aucun accès de test
authentifié utilisable n'est disponible. L'audit des données vivantes et les
transitions réelles avec un compte de test restent à réaliser. Aucune modification
SQL, migration, réextraction ou réouverture du chantier baseline n'est nécessaire
pour ce correctif applicatif. Le remplacement visuel et la validation en situation
réelle restent **non terminés**.
