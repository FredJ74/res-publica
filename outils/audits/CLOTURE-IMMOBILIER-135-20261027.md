# Recette immobilière #135 — 27 octobre 2026

**CHANTIER NON TERMINÉ ET NON VALIDÉ EN PRODUCTION.** Le présent lot corrige un défaut reproductible, éprouve les mécanismes existants et conserve les limitations réelles. Il ne vaut pas validation de la sécurité privée ni du parcours authentifié mobile.

## Reprise et livraison

Branche `codex/cloture-immobilier-135-20261027`, issue du main `74128ee3ac8118f12c1e5e48577fafb43a2598ad`. Les modifications précédentes de #174, #175, #178 et #188 sont présentes et conservées. Les instructions AGENTS, RELAIS, Constitution, Architecture et workflow Supabase ont été lues. Les fichiers métier ambassades/BNE et les corrections transversales de Claude ne sont pas modifiés. Aucune migration créée ou appliquée, aucun baseline retouché.

Défaut reproduit dans `confirmerVolMateriaux` (`plateau-justice-economie.js`) : le serveur répond au vol, puis le client réaffecte `const qte`, ce qui lève `Assignment to constant variable` avant l'ajout local et l'affichage. La quantité demandée et la quantité réellement accordée sont maintenant deux constantes distinctes. Seule la quantité accordée est utilisée ensuite. Aucun tarif, coût, jet ou seuil n'est changé. La version du script dans `plateau.html` est incrémentée pour éviter l'ancienne copie en cache.

Quatre tests exécutent le handler réel sur contreparties fictives : accord de deux unités pour cinq demandées, stock vidé, refus serveur et contre-épreuve qui rétablit exactement l'exception historique. Ces tests ne prouvent ni l'atomicité complète du vol ni une réparation rétroactive des inventaires ; aucune réparation de données de joueurs n'est tentée.

Le banc complet des cinq terrains assemble également la migration de taux horaire actuelle `20261025070000`, deux fois pour vérifier son rejeu, en complément du banc salarial existant.

## Résultats isolés réellement obtenus

Les sorties et leur manifeste SHA-256 sont dans [cloture-135-20261027](cloture-135-20261027/RESULTATS.json). Les identités et services annexes des bancs sont des fixtures, pas une authentification Supabase réelle.

| Banc | Résultat |
|---|---|
| Pilote, dont Chromium local et quatre nouveaux tests de vol | 105/105, aucun ignoré |
| Contrôleur client existant | 105/105 |
| Sorties, navigation et occupation après confirmation | 60/60 (sous-ensemble des bancs clients) |
| Occupation, fermeture de visites et changement de ville #188 | 30 assertions PostgreSQL |
| Cohérence SQL des rues et sorties | 5 groupes |
| Négociation des squatteurs | 59 assertions PostgreSQL |
| Dépôt atomique de permis | 56 assertions PostgreSQL |
| Cinq parcours acquisition → permis → financement → travaux → lots → réception, avec salaire actuel | 324 assertions PostgreSQL ; 61 bancaires sous-jacentes |
| Progression et salaire du moteur commun | 62 + 15 assertions PostgreSQL |
| Matériaux, prix entiers, dons, concurrence et rollback | Tous les groupes annoncés réussis ; aucun nombre d'assertions inventé |
| Contre-épreuves du parcours | 3/3 régressions détectées : prix/superficies uniformisés, jour rejoué et tranche 70 % altérée |
| Contrôles globaux | **4/12**, mêmes sorties que main, avant et après correction |

Les huit contrôles rouges sont Workflow, Classification, Baseline, Authority, Referential, Fonctions, Assemblage et Reconstruction. Ils restent des échecs préexistants, pas des réussites du présent lot. Aucun résultat, référence ou empreinte de contrôle n'a été adapté pour les masquer.

Les 60 cas de navigation comprennent l'office notarial, les refus HTTP/session, la réponse perdue avec réconciliation sans nouvelle mutation, les doubles clics, les réponses tardives lors de changements de personnage/compte/session/ville/pièce, la prison et l'interception, les sorties spéciales et les quatre orientations de Port-Sainte-Marie. Ils utilisent les fonctions réelles et un transport fictif ; ils ne constituent pas dix déplacements authentifiés en jeu.

## Conditions réelles : provenance et limites

L'audit archivé `AUDIT-DEPLACEMENTS-LECTURE-SEULE-20261026.md` rapporte une cinquième campagne authentifiée confirmant la position initiale d'Arnie sans déplacement. La mission reçue rapporte également la migration de fermeture des visites appliquée et contrôlée sur Supabase. Ces acquis sont conservés, sans réapplication. Ils ne sont pas présentés comme des opérations exécutées par cette session.

L'accès Git fonctionne (fetch et push). La lecture des dernières campagnes par `gh api .../actions/workflows/beta-testeur-luthecia.yml/runs?per_page=3` échoue par `Forbidden`. La production HTTPS échoue avant la réponse du site : `Tunnel connection failed: 403 Forbidden`. Ceci ne prouve pas une panne Vercel. Aucun outil Supabase ou Vercel n'est exposé dans cette session. Les secrets Arnie ne sont pas présents localement et n'ont pas été recherchés en clair.

Le workflow existant reste sur main, environnement `luthecia-e2e`, mode `consultation_seule` pour Arnie. Les RPC de mouvement et de contrôle policier/garde demeurent interdites ; aucune autorisation n'est élargie. Le mode `tests_isoles` demande des comptes et un plan explicitement autorisés ; leur disponibilité n'est pas démontrée ici. Aucune opération réelle ne peut donc être lancée sur cette hypothèse.

## Sécurité privée : écart concret restant

Les cinq terrains utilisent les mêmes fonctions de chantier. Cependant, partager un helper ne prouve pas un raccordement de sécurité complet :

- `vigilesDuChantier` lit un nombre ou un tableau du blob ; son commentaire indique que le recrutement n'est pas raccordé. Il ne vérifie pas les identités, employeurs, affectations ou présences des agents.
- Le malus au vol est bien commun (`malusVigiles`, premier 20, suivants 10). Le handler de vol utilise encore un tirage navigateur. La correction de constante ne transforme pas ce circuit en autorité serveur.
- Le parcours de vol séparait déjà le paiement, la diminution du stock et l'ajout local d'inventaire. Il ne possède donc pas, dans ces sources, de preuve d'acte atomique complet/reçu couvrant ces contreparties. Un résultat réseau perdu reste à sécuriser sur ce chemin.
- L'agence commune de recrutement existe (`plateau-agence-emploi.js`, `employeur_embaucher`). Elle ne démontre pas à elle seule une affectation au chantier ni une intervention de vigiles.
- Le circuit policier existant distingue détection serveur puis intervention ; il ne doit pas être assimilé arbitrairement aux agents privés ou appelé en lecture seule. Aucun raccordement chantier → détection privée → arrestation → combat n'est attesté par les sources examinées.

**Il n'est donc pas exact d'annoncer les vigiles opérationnels.** Avant de modifier une porte sensible, il faut lire les fonctions vivantes, leurs ACL/RLS et les tables d'affectation, comparer avec le recrutement et le combat communs réellement installés, puis éprouver leur raccordement sur PostgreSQL jetable. Un catalogue généré ancien ne suffit pas à inventer ces contrats. Aucun nouveau taux ni moteur parallèle n'a été créé pour combler ce manque.

Le helper BNE `chantier_besoin_jour_interne`, auparavant non archivé, est signalé présent sur la base par l'audit du 26 : cette ancienne réserve d'absence de vérification ne doit pas devenir une affirmation d'absence en production. Sa définition vivante reste inaccessible depuis cette session.

## Suite unique nécessaire et critère de clôture

L'intervention nécessaire est de rendre disponibles les accès techniques GitHub, Supabase et Vercel dans une session d'exécution poursuivant cette branche. Pas de nouveau compte Arnie, pas de changement de secret, pas de SQL à faire exécuter par Fred. L'agent pourra alors lire les campagnes existantes et le catalogue réel, terminer le raccordement privé, éprouver puis ouvrir/fusionner les corrections admissibles et vérifier les ressources effectivement servies. Des comptes explicitement réservés seront nécessaires pour les déplacements authentifiés ; Arnie ne les remplace pas.

Ne pas fermer #135 tant que le raccordement privé, l'intégration et le déploiement ainsi que les limites de la recette authentifiée ne sont pas réellement établis. Aucun déplacement de joueur réel, prêt, transfert, achat, combat ou écriture Supabase n'a été effectué ici.

## Sauvegarde et tentative de revue

Le correctif et les preuves sont poussés dans le commit `736ab07` sur `codex/cloture-immobilier-135-20261027`. La création de PR en brouillon a été tentée avec le client GitHub autorisé ; elle échoue avant création par `Post "https://api.github.com/graphql": Forbidden`. Aucun numéro de PR n'est attribué, aucune fusion effectuée et aucun déploiement revendiqué. La mise à jour de l'issue #135 est également inaccessible par cette API ; son texte de suivi est conservé ici et dans RELAIS.
