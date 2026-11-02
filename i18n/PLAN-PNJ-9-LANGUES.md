# Internationalisation des PNJ — contrat de raccordement (préparation, non activé)

## Coexistence des chantiers
Ce document ne modifie ni les profils PNJ, ni DeepSeek, ni les endpoints de Claude. Avant toute implémentation, récupérer la dernière version intégrée de leurs fichiers et éviter les doubles moteurs de traduction : i18next reste le moteur commun d'interface.

## Contrat des messages
- Une requête de dialogue conserve l'identité, les droits, la ville, le contexte narratif et les intentions serveur dans leurs identifiants canoniques ; elle transmet séparément la locale de présentation (`fr`, `en`, `es`, `zh-TW`, `ru`, `ko`, `ar`, `pt-BR`, `de`).
- Le texte d'origine, sa langue déclarée ou détectée, et le texte traduit sont deux valeurs distinctes. La commande « voir l'original » restitue strictement le texte sauvegardé, sans regénération.
- Les textes de personnages restent du contenu non fiable. Aucune instruction de dialogue ne change les autorisations, effets, prix, inventaires ou déplacements ; les actes métier sont confirmés par les fonctions serveur.
- La personnalité et l'historique du PNJ ne doivent pas varier selon la langue : seuls ses mots et formats de présentation changent. Les noms propres et toponymes demeurent inchangés.
- Une traduction manquante ne fait pas échouer une action métier ; elle affiche clairement le texte canonique avec indication de sa langue. Ne jamais persister une traduction partielle comme original.
- Sens de lecture RTL réservé à la zone de texte arabe, sans renverser la grille de commandes.
- Les limites de contenu et les filtres de sécurité s'appliquent aux deux versions, sans injecter le HTML généré dans le DOM.

## Recette attendue
1. PNJ fixe : mêmes offres/choix/conséquences pour les neuf langues.
2. PNJ DeepSeek : langue de réponse demandée, fallback observable, refus d'action hors autorité.
3. Traduction PJ→PNJ et PNJ→PJ : original et traduction interchangeables, sans perte ni double facturation.
4. Changement de langue pendant la conversation : historique et effets métier stables.
5. PNJ communs aux trois villes : même ID, personnalité et métier, ville géographique indépendante.
6. Arabe, russe, chinois et coréen : RTL, pluriels, caractères non latins, prompts et notifications.
7. Échec ou timeout de traduction : message non perdu, pas de nouvelle commande métier ni nouvelle dépense.
8. Comptes de test isolés, aucun dialogue expérimental avec un PJ réel sans recette autorisée.

## Dépendance
Intégration uniquement après la stabilisation et le merge autorisé du socle PNJ/DeepSeek tenu par Claude. Ne pas activer publiquement les neuf langues au seul motif que les dialogues pilotes passent.
