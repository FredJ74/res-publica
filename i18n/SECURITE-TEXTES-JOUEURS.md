# Livraison des traductions de textes joueurs — verrou de sécurité

État 07/11/2026 : **interne seulement**. Aucun endpoint de traduction ouvert.

## Source de vérité
Le client ne fournit **jamais** le texte à traduire comme preuve d'accès. Il envoie uniquement l'identifiant et la catégorie. Le serveur vérifie un JWT Supabase Auth réel, puis **lit le contenu sous ce même JWT**, avec la clé publique anon (jamais `service_role`). Pour le chat, la politique RLS déjà en production invoque `chat_participe(conversation_id, salon)`. Toute absence de ligne retourne le même refus, sans distinguer ID inexistant et message privé.

## État des sources vérifiées sur Supabase — contrôle direct du 07/11/2026
- Sujet de forum : `forum_topics.title`, politique SELECT RLS `forum_lecture_autorisee(forum_id, country)`. L'accès dépend du pays, de la ville et de l'adhésion aux organisations : **ce contenu n'est pas public par défaut**.
- Réponse de forum : `forum_posts.content`, politique SELECT RLS imposant l'existence du sujet correspondant dans `forum_topics` ; **la visibilité de ce sujet est contrôlée par sa propre RLS**.
- Chat : `messages_chat.message`, politique SELECT RLS `chat_participe(conversation_id, salon)` ; uniquement les participants autorisés.
- Audience et presse en attente : **non autorisés** par le contrat de traduction tant que leurs portes de lecture serveur n'ont pas été auditées.

Le prévol corrigé `historique/i18n/PREFLIGHT-I18N-RLS-LECTURE-SEULE.sql` exige une unique politique de lecture attendue par source, RLS active et le prédicat correspondant. **Exécuté en lecture seule sur le projet Supabase `res-publica` le 07/11/2026 : 3/3 conformes**. Il ne démontre pas encore l'absence de faille dans le futur endpoint : celui-ci demeure inexistant et désactivé.

## Protection contre les coûts et abus, indispensable avant mise en service
1. Compteur de requêtes par UID vérifié, fenêtre glissante persistante côté serveur et limitation simultanée. Ni la mémoire d'une fonction serverless ni le seul navigateur ne sont fiables.
2. Budget plafonné et circuit de refus **avant** `appelDeepSeek` : jamais de débit réexécuté après timeout du fournisseur.
3. Cache lié à `type + id + colonne + empreinte du contenu original + locale`; appliquer RLS **avant chaque hit de cache**, même si la traduction a déjà été calculée.
4. Seule la traduction est cachée ; original, statut, locuteur et langue sont lus du serveur. Toute édition rend la traduction périmée.
5. Texte plafonné, placeholders préservés et contenu traité comme donnée non fiable. Ne pas interpréter de HTML issu du fournisseur.
6. Traduction défaillante : texte original affiché, sans perte, double dépense ou action métier.
7. Essais d'accès : même erreur pour ligne inconnue, secrète et inaccessible ; aucun contenu ni existence ne doit fuiter.
8. `Voir l'original` : bouton local qui retrouve exactement le texte original, même après changement de langue.

## Dépendances
Les modules `api/_traduction.js`, `api/_traduction-sources.js` et `i18n/texte-joueur.js` sont des briques préparatoires. Le raccordement PNJ attend l'intégration des dernières modifications Claude. Le schéma de limitation et de cache doit être audité avant toute migration ; **ne pas activer ou fusionner la PR #377 sans la recette intégrale**.


## Contrat technique ajouté le 7 novembre — sources existantes, sans migration

Un relevé **en lecture seule** d'\`information_schema.columns\` sur les trois sources autorisées montre qu'aucune ne possède de colonne \`language\` ni \`version\`. Ne jamais présumer du français pour un texte libre écrit par un joueur, ni inventer une colonne SQL.

- \`api/_traduction-lecture-rls.js\` utilise le transport serveur commun \`sbGetVerdict\` avec **uniquement** \`{jeton: JWT_du_lecteur}\`, jamais une identité \`service_role\`. La catégorie, la colonne et l'ID sont revalidés selon la liste blanche. Seules les colonnes \`id\` et celle du texte sont sélectionnées ; aucun auteur caché, identité secrète ni autre métadonnée n'est retourné. Une ligne absente, interdite, dupliquée, malformée ou une panne donnent le même refus.
- La langue source est \`und\` (*undetermined*) tant qu'une langue d'origine fiable n'est pas enregistrée. Le traducteur sait traiter une source \`und\` sans affirmer qu'elle était française.
- Le moteur calcule une **version dérivée de l'empreinte SHA-256 du texte**, après la lecture autorisée RLS. Cela rend les éditions invalidantes même sans colonne \`version\`. Une version explicite valide reste acceptée lorsqu'une source dispose ultérieurement d'un véritable identifiant de révision.
- Les tests de garde du lecteur et du moteur sont ajoutés à la CI, dont des contre-épreuves de JWT absent, colonne cachée, contenu vide, source sans version et réponse fournisseur simulée. La lecture RLS en production n'a pas été exercée avec des comptes PJ de test, et aucune traduction payante n'a été demandée.

**Toujours interdit à l'activation :** le compteur/quota atomique persistant et le cache serveur durable ne sont pas implémentés ; aucun endpoint public. Ne pas exposer \`traduireContenu\` en HTTP ni utiliser un cache mémoire serverless comme unique protection.
