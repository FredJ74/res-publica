# Correspondance de la publication Vercel — lecture seule

**Contrôle effectué le 9 novembre 2026 auprès du connecteur Vercel**, sans action de déploiement. Projet **`res-publica`**, identifiant `prj_xMwOQ03J3TaBGGbO3JDu3iia4DbU`.

| Critère | Résultat directement observé |
|---|---|
| Déploiement interrogé | `dpl_BGzfC4U7qkckKJV5NGzC9SBKGQno` |
| Environnement | `production` |
| État Vercel | **READY** |
| Branche GitHub associée | `main` |
| SHA associé | `a8bd5e266f18f3432ec3feb11d53dbb799043531` |
| Alias public enregistré | `res-publica.vercel.app` |
| Autres alias | `res-publica-fred-s-projects25.vercel.app`, `res-publica-git-main-fred-s-projects25.vercel.app` |

[Inspection Vercel du déploiement](https://vercel.com/fred-s-projects25/res-publica/BGzfC4U7qkckKJV5NGzC9SBKGQno).

## Ce que prouve ce contrôle
- La **version GitHub de référence** du présent référentiel correspond à un **déploiement de production Vercel READY**, avec alias du domaine habituel enregistré.
- Les six contrôles GitHub du SHA correspondant sont terminés en succès (voir `METHODE-ET-PREUVES.md`).
- Les contenus clients et les fonctions Vercel inclus dans ce SHA sont dans le périmètre de l'artefact déployé, sous réserve du routage réel des fonctions et caches.

## Ce que cela ne prouve pas
- Qu'un joueur peut se connecter, parcourir chaque salle, déclencher chaque ordre, percevoir ses gains et les conserver après reconnexion.
- Que toutes les migrations de `migrations/` sont présentes, dans le bon ordre, sur la base Supabase active. Quelques migrations précises ont été recoupées séparément dans `ETAT-SUPABASE-LECTURE-SEULE.md`.
- Qu'un fournisseur externe tel que DeepSeek répond, que les permissions RLS sont toutes correctes, que les paiements sont sécurisés ou que les fonctionnalités i18n sont autorisées et exposées.
- Que les rendus mobile et les cartes des villes sont ergonomiques pour un nouveau joueur.

**Niveau de preuve : P = vérifié pour le commit de référence, J = inconnu pour les parcours.** Cette distinction doit être conservée dans chaque fiche du catalogue. Aucun changement ni promotion n'a été effectué chez Vercel.
