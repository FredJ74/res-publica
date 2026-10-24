Les sorties de police et la dissimulation ne persistaient que dans le cache ; un retrait de lot pouvait contourner les contrôles avec un NULL SQL, et le réaménagement pouvait être payé sans création durable.

Cette branche reprend les correctifs utiles de réaménagement sur le main courant, ferme l'ancienne porte de lots, réutilise les commandes/journées/loyers existants et ajoute les commandes serveur de police/cadavre avec coûts, occupation versionnée, reçus et échéances idempotentes. Les cinq parcelles partagent un gabarit conservant les achats individuels. Les changements Ced/football de PR136 sont intégrés.

Validation : 107/107 bancs client ; 30/30 bancs PostgreSQL du workflow ; 91/91 contre-épreuves ; banc occupation ensuite enrichi à 40 assertions. Tous les essais sont locaux, avec identités/services annexes fictifs. Aucun compte joueur réel utilisé.

Brouillon obligatoire : aucune migration appliquée par cette intervention, aucun catalogue vivant accessible, aucune vérification de version Vercel. Globaux 6/12 ; les incohérences de baseline restent exposées. L09 (bénédiction), L11 (acquisitions/financement) restent inachevés et L04 partiel. Ne pas fusionner ni déployer ce lot sensible avant prévol réel et installation cohérente.

Bilan complet : outils/audits/CORRECTIONS-LUTHECIA-135-20261024.md ; preuves : outils/audits/luthecia-20261024/. Une branche indépendante existe pour le seul gabarit : codex/parcelles-gabarit-135-20261024.

Refs #135. Ne clôture pas l'issue.
