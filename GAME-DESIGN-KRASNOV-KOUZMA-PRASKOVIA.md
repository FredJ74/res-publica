# Krasnov — Kouzma et Praskovia : rôles PNJ validés

**Décision explicite de Fred : 15 novembre 2026.** Cette note complète l'histoire et les décors suivis dans la PR #987 et dans `GAME-DESIGN-NOVOMIRSK.md`. Elle fait autorité sur l'attribution des rôles, sans inventer de nouveau comportement.

## Kouzma Lapchine
- Prêtre orthodoxe (batiouchka) officiant à l'**Église de la Sainte-Moisson-Commune**, à Krasnov ; réside dans le **tserkovny dom**.
- **PNJ référent religion** : aide le joueur à comprendre les règles et les actions religieuses réellement disponibles dans le jeu, dans le cadre de son empire ; ne doit pas inventer des effets de piété ou des pouvoirs.
- **PNJ social** : construit une relation au fil des rencontres et des conversations, avec la personnalité de Kouzma, et peut prendre contact selon les règles existantes du moteur social.
- Son amour pour Praskovia, leur foi commune et leur proximité malgré l'impossibilité de se marier constituent sa profondeur narrative. Éviter de dévoiler automatiquement toute l'histoire dès le premier échange.

## Praskovia Pakhomova
- Habite la petite maison bleue de Krasnov, proche de celle de Kouzma ; reste amoureuse de lui et apprécie leur proximité et leurs moments de thé.
- **PNJ référente kolkhoze** : explique les activités, services et règles effectivement disponibles du kolkhoze, sans inventer de mécaniques.
- **PNJ social** : construit sa propre relation avec chaque joueur selon le moteur social existant.
- Sa simplicité, sa piété, son intérieur fleuri et sa douceur caractérisent son accueil ; son passé avec Kouzma ne doit pas être une révélation automatique.

## Contrat technique à appliquer (sans modifier la décision)
- Les deux PNJ **cumulent les rôles « référent » et « social »**. Ce sont deux mécanismes distincts : mémoire pédagogique pour l'aide et mémoire relationnelle pour les interactions. Ne pas sacrifier l'un au bénéfice de l'autre et ne pas créer de moteur parallèle.
- Conserver leurs identifiants stables entre les profils serveur, les déclarations PNJ visibles, les références pédagogiques et les associations du moteur social ; utiliser les lieux réels de Krasnov, pas des lieux homonymes d'autres villes.
- Les explications référentes reposent sur les règles codées et vérifiées ; le PNJ peut ignorer ou signaler ce qu'il ne sait pas. Ne pas déduire automatiquement de nouvelles règles religieuses ou économiques.
- Vérifier les transitions d'entrée, les mémoires par joueur, le dialogue, les permissions serveur et la compatibilité avec les 9 langues avant de considérer l'intégration comme livrée.
- Les portraits déjà livrés sont `images/Sovarka/Krasnov/Kouzma.webp` et `images/Sovarka/Krasnov/Praskovia.webp`.

## État
- **Décision actée**, mise en œuvre **non certifiée** à la date de rédaction.
- La **PR #987 de Claude** traite actuellement du récit et des deux personnages. Y intégrer les rôles décidés, sans travail concurrent sur ses fichiers ; produire les tests, migration et preuve de publication selon les usages du dépôt.
