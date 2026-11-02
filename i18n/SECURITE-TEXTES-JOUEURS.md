# Livraison des traductions de textes joueurs — verrou de sécurité

État 03/11/2026 : **interne seulement**. Aucun endpoint de traduction ouvert.

## Source de vérité
Le client ne fournit **jamais** le texte à traduire comme preuve d'accès. Il envoie uniquement l'identifiant et la catégorie. Le serveur vérifie un JWT Supabase Auth réel, puis **lit le contenu sous ce même JWT**, avec la clé publique anon (jamais `service_role`). Pour le chat, la politique RLS déjà en production invoque `chat_participe(conversation_id, salon)`. Toute absence de ligne retourne le même refus, sans distinguer ID inexistant et message privé.

## État des sources vérifiées sur Supabase
- Forum sujets : `forum_topics.title`, SELECT RLS `true`.
- Forum réponses : `forum_posts.content`, SELECT RLS `true`.
- Chat : `messages_chat.message`, SELECT RLS `chat_participe(conversation_id, salon)`.
- Audience et presse en attente : **non autorisés** par le contrat de traduction tant que leurs portes de lecture serveur n'ont pas été auditées.

Contrôle reproductible : `outils/audits/PREFLIGHT-I18N-RLS-LECTURE-SEULE.sql` (3/3 conformes le 03/11).

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
