# Commissariat PSM — contexte PNJ et portrait, 4 novembre 2026

## État de livraison

Code sauvegardé sur `codex/psm-commissariat-dialogue-portrait-20261104`. Correction fonctionnelle `1400042f`, intégration de main `578764b2` (PR #449, serrures) sans conflit. PR #447 conservée. Aucun SQL ajouté ni exécuté, aucune donnée PJ ou configuration distante modifiée.

Création de PR tentée avec GitHub CLI : `Post https://api.github.com/graphql: Forbidden`. La branche est poussée, mais aucune PR créée, aucune fusion ni CI distante certifiée. Lien de création : https://github.com/FredJ74/res-publica/pull/new/codex/psm-commissariat-dialogue-portrait-20261104

Lecture de production tentée le 04/11 : le proxy refuse CONNECT vers `res-publica.vercel.app` (HTTP403). Ce refus ne démontre aucune panne du jeu. Aucun déploiement de ce lot effectué ou vérifié. Aucune clé fournisseur disponible : aucune réponse DeepSeek réelle vérifiée.

## Cause établie et limites

Le casting place Martial Morvan dans `republic/ville_a/commissariat-local/bureau_commissaire`. Sa fiche donnait seulement son nom et son rôle ; le prompt commun ne recevait aucune position serveur. La phrase « cour »/« porte verte » n'a pas été retrouvée dans les sources examinées. L'insuffisance du contexte est démontrée ; le journal historique exact du fournisseur n'est pas accessible, donc l'origine détaillée de cette génération ne peut pas être certifiée.

Le chat lit maintenant `rue_position_lire()` sous le JWT existant, en parallèle des autres lectures. Aucun lieu fourni par le navigateur n'est accepté. Le générateur de casting existant produit les libellés pays/ville/bâtiment/pièce et les identités présentes. Le prompt distingue la position vérifiée du visiteur de la présence attestée du PNJ ; il privilégie cette scène sur les anciennes répliques contradictoires. En l'absence de preuve, il indique une localisation non confirmée et interdit d'inventer une cour, une porte ou un itinéraire. La fiche de Morvan précise son bureau, sans changer sa personnalité, ses pouvoirs ni son métier. Il ne s'agit pas d'une réponse générique substituée à l'IA ; le respect effectif de ces consignes par le fournisseur reste à recetter.

## Portrait et fichiers

Source inchangée : `images/port-sainte-marie-commissariat-accueil.webp`, 1536×1024. Policier choisi : celui au premier plan à gauche derrière le comptoir ACCUEIL. Recadrage exact 320×320 à x55,y260, sans génération ni retouche ; WebP sans perte de 87426 octets : `images/port-sainte-marie-commissariat-brigadier-accueil.webp`. SHA256 des pixels RGBA décodés du crop et du portrait identiques : `f100c309bedb73fcb9a29a151974eee9907ef5f63740ffaac62b216ccc6bb3ff`.

- `data.js` : seul portrait du brigadier d'accueil PSM, identité/rôle inchangés. `index.html`, `plateau.html` : cache de data.js majoré.
- `api/chat.js`, `api/_pnj-profils.js`, `api/_pnj-localisation.js` : lecture et contexte commun autoritaires ; authentification, fournisseur et budget conservés.
- `api/_pnj-personnalites.js` : lieu professionnel de Morvan.
- `outils/generateurs/generer-pnj-lieux-metiers.cjs`, `api/_pnj-scenes-generes.js` : mode `--scenes-js`, métadonnées générées depuis le moteur de casting existant. Sortie SQL par défaut comparée octet pour octet au main de référence : identique.
- Bancs localisation, portrait Chromium et assertion du hall : couverture de la huitième lecture parallèle, sans suppression d'assertion.

## Vérifications exécutées localement

- 53 tests contexte/dialogue/police réussis ; 56 avec les trois tests serrures après intégration #449. Les trois questions demandées traversent le vrai handler ; réponses fournisseur SIMULÉES. Contrôle de la requête réellement envoyée au modèle, refus des positions navigateur forgées, panne de position, autre pièce, Luthécia, Montrouge et identifiant de ville partagé avec El Estado.
- 2 tests Chromium réussis (390/1280) : vraie carte « Personnes présentes » et composant avatar utilisé par la fenêtre de dialogue, image chargée 320×320, position identique. Ce banc ne constitue pas une session authentifiée ni une vérification complète du dialogue en production.
- 13 tests de bundle Vercel réussis : compilation réelle et chargement CommonJS des fonctions, contre-épreuve ESM préservée. Aucun déploiement Vercel déclenché pour ces essais.
- 95 assertions du hall réussies. Contrôleur client complet : 191/191 avant et après intégration #449. Journaux et empreintes dans `preuves-psm-commissariat-20261104/`.

## Échecs hérités : comparaison différentielle

Sur cette branche ET sur un worktree isolé du main `06657545`, les mêmes résultats ont été exécutés : contrôles globaux 8/12 et tests transversaux 96/98. Aucune référence, empreinte ni assertion modifiée pour masquer ces échecs.

Les quatre contrôles rouges : seed ordres_couts divergent du générateur ; Authority dépend de `couvre_feu_patrouille()` absente de sa chaîne ; Referential attend une ancienne empreinte du générateur ; contrôle Functions attend l'ancienne référence client `modifierIndiceVille`. Les deux tests transversaux rouges attendent encore des routes usine masquées par l'interface et l'ancien appel `sbGreveGeneraleSynchroniser(ggId)`. Ces problèmes précèdent ce lot ; les corrections déjà travaillées dans le chantier Forums ne sont pas importées ici pour éviter le chevauchement.

## Conditions avant clôture

Créer la PR avec un accès GitHub autorisé, obtenir les contrôles requis sur son SHA final après résolution/intégration coordonnée des échecs hérités, puis fusionner. Vérifier ensuite Vercel READY et les ressources réellement servies. Effectuer avec un compte de recette autorisé les trois questions à Morvan et l'affichage des deux portraits, sans ordre métier ni mutation de PJ réel. Aucun succès de CI distante, de dialogue IA réel ou de production n'est déclaré par ce rapport.
