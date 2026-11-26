# Mission « décisions du 26/11/2026 » — séance de game design avec Fred

Feu vert de Fred pour coder l'ensemble (26/11/2026, 15 h 11 : « Je réponds à tes questions et ensuite tu auras le feu
vert pour coder l'ensemble des décisions »). Reprise : « Reprends docs/mission-decisions-20261126.md au premier point
non coché ». Une branche par bloc, PR, CI verte, fusion ; migrations appliquées une à une, contrôles en tête de fichier.

Questions sources : `docs/soir/BLOC-*.md` et `docs/soir2/BLOC-*.md`. Les questions de la première mission du soir
étaient déjà tranchées par la seconde (contrebande à l'amende, médaille du Tractorisme, censure, bénédiction et charisme
au serveur, demi-effet, Simone Aiguillard au guichet du cinéma) : ne pas les reposer.

## Décisions de Fred

1. **Biographie des PNJ** : abandonnée. Seule la fiche de personnalité compte (ton des réponses de DeepSeek).
2. **Publicités de joueurs** : premium ponctuel, on vend une **campagne** (une seule génération d'image, rediffusée).
   Deux durées au choix, **5 et 10 jours** (30 jours : trop long et répétitif), prix **dégressif** ; durées et prix
   réglables dans la page MJ. Mêmes règles pour tous les supports (rue, avant le film, presse) ; les formules
   « 5 / 10 parutions » de l'atelier de presse disparaissent.
3. **Fin d'abonnement** (déjà décidé le 25/11) : ce qui a été activé reste acquis.
4. **Remise à zéro** (déjà décidé le 25/11) : tous les personnages disparaissent.
5. **Commerces** : la remise à zéro concerne **tous** les commerces, PNJ compris, chacun avec une **dotation initiale**
   permettant d'amorcer le commerce (stock et caisse par type de commerce, réglables dans la page MJ).
6. **Caisses publiques** : même principe, **dotation initiale** pour toutes (mairies, ministères, Sovarka comme Républia).
7. **Revenu universel** : Sovarka en reçoit un, **45 PSK par jour** (Républia : 150 FR). Dans les deux empires, il n'est
   versé que pendant les **10 premiers jours d'un personnage**, pour l'aider à démarrer. Montants réglables dans la page MJ.
8. **Contrebande** : l'amende va à la **caisse de la douane** du pays. L'ordre est jugé « assez creux » : séance de
   reprise à prévoir avec Fred (ne rien changer d'autre d'ici là ; pas de dette si l'amende dépasse l'argent du joueur).
9. **Censure en Sovarka** : normale, **aucun effet** sur le gouvernement ni sur les indices, jamais de scandale.
10. **Traduction** : le **forum** est la priorité de raccordement (Fred fait venir des joueurs étrangers pour éprouver la
    qualité des traductions) ; les **rumeurs** de la chronique sont branchées aussi, en attendant la traduction partout.
11. **Rumeur ratée** : on ne sait pas ce qu'elle contenait ; la chronique dit simplement
    « une rumeur a couru, mais personne n'a su dire laquelle ».

## Décisions techniques de Claude (dans la ligne de la remise à zéro complète)

- Blocus (`blocus_ordres_batiments`) et événements climatiques (`climat_evenements`) en cours : effacés au lancement.
- `budgets_nationaux` et `ports_commerce` : retour aux valeurs de départ.
- `avocats_barreau`, `compagnies_militaires` : vidés ; `admin_journal` (journal du MJ) : **gardé**.
- Bénédiction : vérifier au serveur qu'un religieux habilité est présent dans la pièce.
- Mobiliser : ne plus dépendre des organisations chargées pour le pays courant (syndicat d'un joueur à l'étranger).
- Médaille du Tractorisme : un chant antérieur à la migration n'est pas rattrapé (aucune trace) ; la médaille vient au
  prochain chant.

## Cases

- [x] A. Migrations de la fin de soirée, **avant application** : adapter 810000 (deux durées 5 / 10 jours, prix
      dégressif, réglages MJ, plus de formules à parutions), 820000 (censure en Sovarka sans effet ni scandale ;
      amende de contrebande versée à la caisse de la douane), 860000 (phrase de la rumeur ratée). Puis appliquer
      800000, 810000, 820000, 850000, 860000 dans l'ordre, redéployer `commerce-decoration`, `logement-decoration`,
      `publicite-premium`, et contrôler.
- [x] B. Revenu universel : Sovarka 45 PSK, limite aux 10 premiers jours d'un personnage dans les deux empires,
      paramètres MJ ; banc.
- [ ] C. Remise à zéro : dotations initiales des commerces (PNJ compris) et des caisses publiques, réglables par le MJ ;
      tables du point technique ci-dessus ; mettre à jour `docs/premium/REMISE-A-ZERO-20261219.md`, le générateur et
      son banc.
- [ ] D. Traduction : raccorder le forum (priorité), puis les rumeurs de la chronique.
- [ ] E. Correctifs techniques : bénédiction au serveur, Mobiliser à l'étranger.
- [ ] F. Contrôle final : CI verte, déploiement, compte rendu dans `RELAIS.md`.

## File d'après (hors feu vert)

- Séance de reprise de l'ordre « Contrebande » avec Fred.
- Portrait de Boris Kovaliov (usine Pharmanov) : dernier portrait manquant de Novomirsk.
- Codex de retour le 27/11 au soir : préparer alors le prompt du contrôle de la traduction.
- Paiement (Stripe classique, couche unique) : CGV, remboursement, page des prix, vérification des CGU, de la politique
  de confidentialité et des mentions légales ; compte Stripe créé par Fred.
- Premium restant : reportage hebdomadaire, film mensuel (images animées + narration), portrait IA, mini-jeux (5 sur 10).
- Séance suggérée : premiers jours du joueur, densité de population, parrainage.
