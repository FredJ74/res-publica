# Matrice initiale de couverture — décisions, code, tests, jouabilité

**Lecture :** D = document de règle ; C = point d'entrée code constaté dans l'arbre et, pour les lignes marquées « vu », fichier lu ; T = rapport de test attribué, non rejoué ici ; M/P = publication/migration uniquement quand identifiée ; J = recette humaine. « ? » ne signifie pas absent. **Aucune ligne ne reçoit J=oui à partir de cette revue statique.**

| Domaine | Décision / référence | Code sur main inspecté ou repéré | Test / preuve historique | Réserve et preuve manquante |
|---|---|---|---|---|
| Principes et trajectoires | D : `CONSTITUTION.md` | C : mécanique distribuée dans les modules | T : sans objet | J : capacité réelle des PJ à se rencontrer non mesurée |
| Identité, création, carrière | D : `ARCHITECTURE.md` | C repéré : `creation.js`, `auth.js`, `plateau-personnage.js` | TEST-F : nombreux bancs création et carrière | J ?, parcours entier non joué |
| Accueil et première quête | D : Constitution art. 15 | C repéré : `plateau-quete-accueil.js` | TEST-F : bancs accueil et quêtes | J ?, guidage à mesurer |
| Horloge, nuit, sommeil, paie, loyers | D : `ARCHITECTURE.md` | C repéré : `api/cron-minuit.js`, `vercel.json` (vu) | TEST-F : banc cron Paris, nocturnes | J ?, vérifier changement d'heure et traitement effectif |
| PA, santé, moral, hospitalisation | D : `GAME-DESIGN-HOSPITALISATION.md` | C repéré : `plateau-personnage.js` | TEST-F : banc hospitalisation | J ?, sorties à 0 PA |
| Objets, inventaire, dons | D : Constitution art. 13 ; Architecture | C repéré : `plateau-objets.js`, `supabase.js` | TEST-F : bancs inventaire | J ?, cohérence multi-session |
| Argent, banque, prêts, caisses | D : `GAME-DESIGN-BANQUES.md` | C repéré : `plateau-justice-economie.js`, `plateau-terrain-banque.js` | TEST-F : tests banque et fonds | J ?, transfert et risque perte de réponse |
| Emploi, NPC employeurs, métiers | D : `GAME-DESIGN-BNE.md` | C repéré : `plateau-agence-emploi.js` | TEST-F : tests paie | J ?, recrutement et salaire réel |
| Commerces, fonds et murs | D : `GAME-DESIGN-FONDS-MURS.md` | C repéré : `plateau-commerce*.js`, `plateau-fonds.js` | TEST-F : bancs commerce / transactions | J ?, stock vide / caisses / rôles |
| Matières, entrepôts, trading, douane | D : `GAME-DESIGN-TRADING.md`, `GAME-DESIGN-DOUANES.md` | C repéré : `plateau-entrepots.js`, `plateau-navigation.js` | TEST-F : bancs entrepôts / douanes | J ?, livraison/économie interempire |
| Terrain, compromis, permis, chantier | D : `GAME-DESIGN-TERRAINS.md` et Architecture | C repéré : `plateau-immobilier.js`, `plateau-chantiers.js` | TEST-F : construction/compromis | J ?, signature et réception atomiques |
| Droit d'exploiter Sovarka | D : `GAME-DESIGN-NOVOMIRSK.md` | C repéré : `plateau-sovarka-droits.js` | TEST-F : bancs Sovarka | J ?, tribunal et droits après décès |
| Construction navale | D : `GAME-DESIGN-CHANTIER-NAVAL.md` (vu) | **C vu** : `plateau-naval.js`, commandes RPC de devis/commande | TEST-F : `banc-chantier-naval-local.py` | J ?, navigation privée **non livrée selon la règle écrite** |
| Véhicules routiers | D : `GAME-DESIGN-VEHICULES.md` | C repéré : `plateau-vehicules.js` | TEST-F : bancs dédiés | J ?, trajets et carburant en condition |
| Cartes, déplacements, groupes | D : Architecture, `REGLES-GROUPES-UNIVERSELS-20261028.md` | C repéré : `plateau-navigation.js`, `plateau-multijoueur.js` | TEST-F nombreux bancs groupes | J ?, carte lisible et reprise réseau |
| Police, combat, justice Républia | D : Architecture, sécurité privée | C repéré : `plateau-justice-economie.js`, `plateau-militaire-terminal.js` | TEST-F : bancs arrestation/combat | J ?, vrais droits et présence |
| Justice Sovarka | D : `GAME-DESIGN-NOVOMIRSK.md` | C repéré : `plateau-sovarka-justice.js` | **TEST-R déclaré** : banc annulé vert prod dans `RELAIS.md` 08/11 ; **M-R déclaré** migration appliquée | J ? explicitement à constater en jeu |
| Élections, partis, fonctions | D : `GAME-DESIGN-ELECTIONS.md` | C repéré : `plateau-politique.js`, `plateau-assemblee*.js` | TEST-F : bancs chaîne élective | J ?, candidats et frauduleux testés isolément |
| Gouvernement et pouvoirs Sovarka | D : `GAME-DESIGN-NOVOMIRSK.md` | C repéré : `plateau-sovarka-pouvoir.js`, `plateau-sovarka-partis.js` | TEST-R déclarés dans relais, migrations annoncées appliquées | J ?, séances et rémunération députés |
| Manif, grèves, blocus | D : `GAME-DESIGN-MANIFESTATIONS.md`, `GAME-DESIGN-BLOCUS.md` | C repéré : `plateau-politique.js`, divers RPC | TEST-F : bancs blocus/grève | J ?, contre-pouvoirs entre PJ |
| Presse et journaux | D : Constitution, Architecture | C repéré : `api/journal-generer.js`, `plateau-communication.js` | TEST-F : bancs presse | J ?, lecteurs et propagande |
| Organisations, forum, mails, chat | D : `GAME-DESIGN-FORUMS.md` | C repéré : `forum.js`, `plateau-organisations-quetes.js` | TEST-F : bancs forum / mails | J ?, sociabilité et réactivité |
| PNJ IA classiques | D : Architecture, Constitution | **C vu** : `api/chat.js`, validation des profils et auth | TEST-F : bancs dialogue | J ?, fournisseur DeepSeek jamais testé dans cette revue |
| PNJ sociaux et mémoire | D : conception commentée dans `plateau-social-pnj.js` | **C vu** : deux déclencheurs déclarés + RPC lue par `api/chat.js` ; seed **2 règles** | TEST-F : fichiers SQL de jalons/relations | J ?, contact spontané et mémoire à éprouver |
| Sport/football, supportérisme | D : `GAME-DESIGN-FOOTBALL.md` | C repéré : `plateau-ced.js` | TEST-F : bancs football | J ?, présence de vrais supporters |
| Religion, prestige, musées | D : Constitution + Architecture | C repéré : `plateau-musee-personnalites.js`, `plateau-publicite-premium.js` | TEST-F partiels | J ?, interactions réelles |
| Multilingue | D : architecture i18n, activation soumise à validation | **C vu** : `i18n/i18n-init.js`, `i18n/resources.js` | TEST-F : nombreux bancs i18n | J ?, couverture 9 langues/activation non établie |
| Mobile | D : objectif de compatibilité smartphone | **C vu** : `plateau-mobile.js` | **TEST-R rapporté** : `CERTIFICATION-MOBILE-20261108.md` ; PR #633 indiquée fusionnée dans relais | **J non** : recette physique explicitement non faite selon protocole |
| Diplomatie / interempire | D : `GAME-DESIGN-AMBASSADES.md`, Architecture | C repéré : `plateau-gouvernement.js`, ambassades | TEST-F : bancs ambassades | J ?, voyage individuel entre empires déclaré absent (architecture oct.) |
| Premium et publicité | D : principe non P2W, arbitrages dispersés | C repéré : `plateau-publicite-premium.js` | TEST-F : contrôles premium | J ?, facturation bêta non ouverte |

## Légende de complétude
La matrice est un **registre de couverture initial**, non une liste exhaustive des 346 actions historiques : elle doit être développée en fiches **ordre → préconditions → coût → effet → RPC → contre-épreuve → test connecté**. Rien ici ne certifie que les migrations annoncées par les relais sont toutes présentes dans la base de production.

## Tests restant impératifs pour clôturer la matrice
Pour chaque ligne, relever un SHA courant, le ou les handlers actifs, la RPC et sa migration canonique, la preuve de droits SQL, l'exécution de test reproductible, la disponibilité de déploiement et une recette utilisateur. La matrice ne passe en statut « exhaustive et certifiée » que lorsque **chaque ordre accessible** possède une telle traçabilité ; ce seuil n'est pas atteint dans cette édition.
