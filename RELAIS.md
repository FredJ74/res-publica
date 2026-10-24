# Relais entre agents

Passage de témoin entre Codex et Claude. Mis à jour à **chaque push**.
Règles : voir `AGENTS.md`.

## En cours

**Ambassades (Claude)** — **Codex : ne pas toucher aux ambassades** tant que
ce chantier est ouvert.
- Contexte : objectif actuel = terminer Luthécia. Les ambassades ne seront
  raccordées aux autres empires que lorsqu'ils seront codés ; les ordres
  existent mais restent en attente jusque-là (arbitrage Fred, 24/10).
- Audit : `AUDIT_AMBASSADES.md`, PR #141 (brouillon, documentation seule).
- En cours : branche `claude/ambassadeurs-pnj-20261024` — trois ambassadeurs
  PNJ reçoivent **sur audience seulement** depuis l'accueil (bureaux fermés) :
  Valery Antonov (Sovarka, la rigidité), Guillermo Vasquez (El Estado, la
  corruption), Mohamed Al-Mansoori (Al-Khalija, le snobisme). Profils dans
  `api/_pnj-personnalites.js`, ordre dans `plateau-politique.js`
  (`doDemanderAudienceAmbassadeur`). Fait, à tester par Fred.
- Reste à proposer à Fred : griser « Bientôt disponible » les autres ordres
  des ambassades (ministre AE : ouvrir/nommer/démettre/expulser ; accueil :
  asile, réservation de salle).
- Bancs : 85/102 en local, les 17 échecs sont identiques sur `main`
  (bancs navigateur, environnement).

Travaux déjà ouverts avant la mise en place du relais (pull requests
existantes, à reprendre si Fred le demande) :
- #139 `integration/livraison-terrain-135-20261024` — terrains : occupation
  transactionnelle, réaménagement, protection des locaux (issue #135).
  Restent L11 acquisition/financement, L04 prêt conso, L09 bénédiction.
- Nombreuses PR WIP plus anciennes (construction #94, successions #95,
  interception policière…) : voir la liste des PR ouvertes.

## Derniers chantiers

- 24/10/2026 — Mise en place du relais Codex/Claude (`AGENTS.md`,
  `CLAUDE.md`, `RELAIS.md`).
