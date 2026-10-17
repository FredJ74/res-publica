# Audit fonctionnel et sociopolitique du championnat — 17 octobre 2026

**Statut : audit de code en cours, lecture seule ; aucune migration ni modification des règles.** Sources examinées : `plateau-organisations-quetes.js`, `plateau-core.js`, `api/cron-minuit.js`, `api/_journal-collecte.js`, et ligne 2 de `public.championnat` (lecture seule).

## 1. Place du championnat dans la société du jeu
Le football n'est pas un minijeu autonome : il relie des clubs et leurs présidences, des joueurs licenciés, des supporters organisés, des élus et le ministère de l'Intérieur, les budgets municipaux, les caisses des clubs, les sponsors, la presse, le forum, les paris, la popularité et les rémunérations. Les résultats sportifs peuvent donc devenir des événements sociaux, économiques et politiques.

**Règle de conception confirmée :** les matchs ont lieu le dimanche à 20 h Europe/Paris même sans PJ connecté. Les PJ apportent des interactions et des influences supplémentaires, jamais la condition d'existence du championnat.

## 2. Calendrier et compétitions
- 12 clubs, saison régulière en tour simple : 11 journées de 6 matchs (`genererCalendrierSaison`, vers 1710).
- Une journée au plus par semaine ISO Paris, ancrage/recalage après résolution (`semaineIsoParis`, `marquerResolutionEtReancrer`, vers 1613–1690).
- Fenêtre de match : échauffement 5 min, deux périodes de 10 min séparées par 5 min ; progression et événements persistés (`phaseMatchActuelle`, `avancerFootballLive`).
- Huit qualifiés aux quarts, puis demi-finales et finale ; palmarès durable (`verifierEtJouerJournees`, vers 2261–2400).
- **Écart actuel important** : le rattrapage est déclenché par un navigateur. La règle « même sans PJ » exige un déclencheur serveur indépendant. La logique de rattrapage ne doit pas accélérer artificiellement plusieurs journées dans la même semaine.

## 3. Sportifs et territoire
- Licences, renouvellement/non-renouvellement, performances défense/technique/endurance, sélection 11 titulaires + 4 remplaçants, convocations et blessures (`calculerContributionEquipe`, vers 2485 ; `doPrendreLicenceSportive`, vers 3808).
- Indices municipaux : sécurité→défense, écoles→technique, espaces verts→endurance, vie associative→multiplicateur global ; piété→modificateur secondaire offensif (`multiplicateurIndice`, `multiplicateurPiete`, vers 2450).
- **Point critique de portage serveur** : `calculerContributionEquipe` lit `state.day` (jour propre au PJ du navigateur) pour filtrer les blessures. Le serveur n'a pas ce contexte. Il faut déterminer la source temporelle canonique avant de migrer, sans inventer de nouvelle règle.
- Le verrou des titulaires, les pop-ups et la présence au stade restent des fonctions d'interface client, même quand la simulation devient serveur.

## 4. Supporters, mobilisations et politique
- Les supporters peuvent choisir leur camp pendant le match ; seules les présences vérifiées dans l'enceinte/terrain et hors titulaires sont comptées. L'effet global des tribunes est borné (`compterSupportersActifs`, `bonusTribunes`, vers 2775).
- Clubs de supporters : adhésion, direction, élections, manifestations, boycott du prochain match à domicile (`doRejoindreClubSupporters`, `doOrganiserBoycott`, vers 7717–8450).
- Les manifestations des supporters peuvent cibler un maire et influer sur des attributs politiques (`appliquerEffetManifestationValidee`, vers 8655).
- La Ligue dépose des demandes de manifestation pour les rencontres ; une interdiction ministérielle peut entraîner un forfait 0–1 (`genererDemandesManifestationMatchs`, vers 2416 ; `avancerFootballLive`, vers 3135).
- **Point critique** : ne pas réduire le championnat à un calcul de scores en isolant son moteur ; décisions administratives, boycotts, présence et actions des organisations doivent être pris en compte au bon instant.

## 5. Argent, réputation et circulation de l'information
- Sponsoring et budget des clubs, présidences, transferts et salaires (`doSponsoriserClub`, `chargerBudgetClub`, `doGererSalairesClub`).
- Titulaires : popularité +20 ou +30 en cas de victoire ; remplaçants : rémunération prévue ; blessure et courrier associés (`construireEffetsRestantsMatch`, vers 2949).
- Les salaires/primes monétaires sont confiés aux RPC serveur `football_primes_journee` et `football_primes_tour` ; **ne pas reproduire ces débits/crédits dans le futur cron**, ni interférer avec la reconstruction financière de Codex.
- Résultats publiés via mécanisme serveur idempotent au forum ; collecte journalistique liée à la date réelle de résolution (`publierResultatsJourneeSurForum`, `api/_journal-collecte.js`).
- Paris sportifs réglés après résultat (`doParierMatch`, `resoudreParisJournee`). Audit de leur idempotence et de leurs flux financiers nécessaire avant portage.

## 6. Contraintes techniques et risques
1. Le moteur actuel est massivement couplé à des fonctions de navigateur (`state`, `sb*`, `addExternalEvent`, `sbRpc`) ; un copier-coller dans une fonction Vercel ne serait pas sûr.
2. Le calendrier du dimanche 20 h exige un ordonnanceur serveur compatible avec les limites de déploiement et le fuseau Europe/Paris (heure d'été/hiver).
3. Le moteur live requiert plusieurs transitions au cours d'une demi-heure ; un cron quotidien ne suffit pas. Il faut choisir et valider une cadence de déclenchement et un rattrapage.
4. CAS sur `championnat.updated_at`, garde de `schemaVersion`, verrous hebdomadaires, effets différés et RPC financières doivent rester cohérents.
5. La génération des demandes administratives et les effets externes doivent être rejouables sans duplication.
6. Le polling réduit de la PR #19 **ne garantit pas** les rencontres sans PJ : ne pas fusionner la PR comme solution définitive.
7. Ne pas déplacer les animations visuelles dans le serveur : elles relèvent du client et sont reportées.

## 7. Vérifications complémentaires avant extraction
- Cartographier les lectures/écritures exactes dans les helpers `sb*` et les RPC football, avec les tables, droits et clés d'idempotence.
- Examiner en détail les phases finales et leurs effets externes.
- Vérifier l'origine de la date de blessure sportive et les conditions de sélection des PJ.
- Vérifier le traitement des paris, manifestations, boycotts, transferts, élections, budgets et abonnements en cas de match sans connexion.
- Examiner les appels aux fonctions sportives depuis les autres scripts et le cron minuit.
- Établir des tests de référence : aucun PJ, PJ titulaire, supporters, boycott, interdiction ministérielle, blessures, résultat nul, primes, pari, playoffs, changement d'heure, panne et reprise.

**Conclusion provisoire :** la centralisation est justifiée, mais elle doit être conçue comme une extraction d'un système sociopolitique complet, et non comme le déplacement d'une simple simulation de score.

## Arbitrage explicite — horloge universelle (17 octobre 2026)
**Règle impérative :** une seule horloge, le temps réel commun à tous les PJ, PNJ, villes et empires. À 16 h à Luthécia, il est également 16 h à Sovarka et partout ailleurs dans l'univers du jeu. Aucun fuseau horaire local fictif, aucune horloge personnelle et aucun calendrier temporel dépendant du PJ connecté.

**Dette technique constatée :** `calculerContributionEquipe` utilise `state.day || 1` pour évaluer `blessure_sportive.jusquauJour`. Il faut retracer le stockage, l'attribution et la guérison des blessures avant de corriger la comparaison, sans interpréter `state.day` comme une règle de game design. La correction doit s'appuyer sur un instant/date canonique du serveur, commun à tous, et préserver la durée d'indisponibilité voulue.

**Portée de l'audit :** rechercher d'autres dépendances à `state.day` ou aux heures locales du navigateur dans les systèmes collectifs. Les heures de présentation peuvent être affichées dans le référentiel commun du jeu, sans modifier l'instant réel sous-jacent.
