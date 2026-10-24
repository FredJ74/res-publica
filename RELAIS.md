# Relais entre agents

Passage de témoin entre Codex et Claude. Mis à jour à **chaque push**.
Règles : voir `AGENTS.md`.

## En cours

**Ambassades et Bureau de l'Emploi (Claude)** — **Codex : ne pas toucher aux
ambassades ni au Bureau de l'Emploi** tant que ces chantiers sont ouverts.
- Contexte : objectif actuel = terminer Luthécia. Les ambassades ne seront
  raccordées aux autres empires que lorsqu'ils seront codés (arbitrage
  Fred, 24/10). Nouvelle règle de Fred : **une seule réalité, celle du
  serveur** (voir `AGENTS.md`).
- PR #142 (branche `claude/ambassadeurs-pnj-20261024`) : trois ambassadeurs
  PNJ reçus **sur audience seulement** — Valery Antonov (Sovarka, la
  rigidité), Guillermo Vasquez (El Estado, la corruption), Mohamed
  Al-Mansoori (Al-Khalija, le snobisme). Fenêtre à la charte ardoise et or.
  **Fusionnée le 24/10.** Son tirage de 70 % côté navigateur est remplacé par
  le parcours d'audience ci-dessous.
- PR #141 (branche `claude/audit-ambassades-20261024`, documentation) :
  `AUDIT_AMBASSADES.md` v2 (game design retrouvé, 12 écarts écran/serveur)
  et `AUDIT_BNE.md` (audit complet du Bureau). Chacun finit par les
  questions à trancher par Fred.
- **Audiences d'ambassade (nouveau parcours, arbitrage Fred 24/10)** — branche
  `claude/audiences-ambassades-20261024` : demande à l'accueil (1 PA, une par
  ambassade) → mail « transmise » → délai tiré par le serveur (0 à 3 jours,
  jamais de refus) → mail « accordée » → bureau ouvert 48 h pour ce joueur,
  ambassadeur PNJ dedans. Fonctions `ambassade_*` **appliquées en production**
  (registre 20261024185323 et 20261024185346), baseline pas encore
  réextrait. Passe de nuit ajoutée dans `api/cron-minuit.js`.
- 25/10 : voyants de la messagerie synchronisés (bouton « Messages/Forums »,
  « Boîte Mail », « Mails reçus » lisent la même copie de ce que rend le
  serveur), et règle commune : **l'agent fusionne lui-même** quand les
  contrôles passent (voir `AGENTS.md`).
- Prochaines étapes, **après réponses de Fred** :
  1. BNE B1 (le mail d'arbitrage rejoué peut faire perdre l'emploi) :
     migration de `bne_agir` + test ;
  2. BNE B2-B4 (textes faux : mail de cumul, montant de « Dormir »,
     « 0 FR/jour ») ;
  3. griser « Bientôt disponible » les ordres d'ambassade non raccordables.
- Bancs : 85/102 en local, les 17 échecs sont identiques sur `main`
  (bancs navigateur, environnement).
- Issue #143 : passer toutes les fenêtres à la charte (plus tard).

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
