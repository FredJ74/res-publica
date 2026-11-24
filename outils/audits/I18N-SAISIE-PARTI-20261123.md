# Sens de saisie des champs de création d’un parti — 23/11/2026

PR #1184 ; branche `codex/i18n-politique-saisie-20261123` ; code b70d7def (correctif 737312d5, installation Chromium en CI b70d7def). Aucune base ni migration, aucun libellé modifié.

Défaut reproduit : `dir=auto` prend le sens du premier caractère. Un nom commençant en arabe restait RTL en français. Deux champs seulement (`orga-nom-input`, `orga-desc-input`) suivent maintenant la langue : ar RTL, fr/en/es/zh-TW/ru/ko/pt-BR/de LTR, alignement au début. L’observation de l’apparition des champs est passive ; elle n’écrit ni valeur ni état du personnage, ne reconstruit pas le formulaire, ne provoque aucun événement ou appel métier. Le moteur i18next et les 22 traductions existantes sont conservés.

CI dédiée **45221674750 : succès, 7/7 tests**. Chromium : 320, 390 et 1280 px ; neuf langues ; champs vides, arabes, mixtes ; changement de langue et nouveau formulaire ; valeur/focus/sélection/état inchangés, zéro appel métier. Banc existant : 28 états, 756 bascules, six types, 22 clés ; conditions, confirmation et paramètres inchangés. L’ancienne assertion dir=auto est remplacée par la direction attendue, sans relâcher les autres contrôles. Transport Brotli : 3/3 tests locaux, restitution sans perte.

Les essais utilisent des réponses simulées : pas de PJ connecté, de téléphone physique ou de recette réelle en production. Aucun fichier du panneau des organisations/personnage n’a été édité. Aucun fichier des zones Claude ni de la PR #1132 modifié.

**Historique initial avant rebase** : le CI général de main d0f0e127 était rouge (45216697377 et 45216697281), et l’ancien banc de raccord du panneau réclame cash/statistics désormais absents de main. Les mêmes erreurs bloquent #1183 et #1184. Elles concernent les tarifs, descriptions, fiche/panneau de personnage : ces zones sont réservées à Claude. Aucun banc n’est assoupli pour forcer la fusion.

Vercel : aucun déploiement de cette branche trouvé ; production READY sur d0f0e127, dpl_6w4msZ18wAvT8qd9t78LTBDozCHP. Le nouveau correctif n’est donc pas présenté comme vérifié en production.

Reprise : après correction des contrôles communs par le chantier responsable, fetch/rebase sur main, conserver les fichiers interdits de main, régénérer/vérifier Brotli si le catalogue change, rejouer les bancs, fusionner si CI entièrement verte, puis vérifier commit et ressources effectivement servis. Rien à appliquer en base.

Actualisation : rebase sans conflit sur main **14d0716e**, après les corrections communes de Claude. Recette locale rejouée : **10/10** tests saisie/transport. CI dédiée **45223029458 verte** ; contrôle complet et livraison suivis dans #1184. Les erreurs initiales ci-dessus sont historiques, pas un diagnostic des nouvelles exécutions.

## Comparaison complète sur le main actualisé

- main 14d0716e, **45222382938 : 449/455**, six échecs.
- #1184 82b05288, **45223911404 : 450/456**, exactement les mêmes six échecs.
- #1183 80b89c03, **45223825981 : 450/456**, exactement les mêmes six échecs.
- Aucun échec supplémentaire observé ; les onze autres contrôles de #1184 sont verts, dont la recette dédiée **45223911116** (7/7).

Bancs en échec : `banc-cycle-plaintes.js`, `banc-groupes-bataille-client.cjs`, `banc-mobile-certification.cjs`, `banc-nominations-municipales.cjs`, `banc-parquet-client.js`, `banc-sorties-batiments.cjs`. Ils concernent le registre des postes, le journal, les pixels du plateau et la navigation du chantier parallèle. Aucun banc ni fichier responsable n’est modifié dans les lots. Empreintes et résultats dans `I18N-SAISIE-PARTI-20261123-CI.json`.

**Non fusionné, non déployé : batterie générale rouge.** Vercel production READY sur 14d0716e (`dpl_E2rUtNMfgsgqknvZyXhGKJktCK7B`), sans ces lots. Les anciennes erreurs de d0f0e127 sont historiques ; ce sont désormais ces six écarts qui bloquent. Après correction par le chantier responsable, rebase et contrôles complets avant fusion. Aucun contournement, aucune écriture en base.

## Reprise après correction des six bancs

Main **a0aba273** intègre les corrections de Claude ; CI générale **45250421305 verte**. Rebase de la branche sans conflit, aucun fichier de Claude modifié. **10/10** tests locaux saisie/transport passent sur cette base. Les erreurs sur 14d0716e décrites plus haut sont historiques. La CI complète est relancée avant fusion, suivie sur #1184 ; aucun nouveau texte, aucune mécanique ni base modifiés.
