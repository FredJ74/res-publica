-- Migration requise avant que la publication au nom d'une organisation ne fonctionne
-- effectivement sur le forum.
--
-- Contexte : verifie en direct via l'API REST Supabase (requetes GET de sonde avant toute
-- ecriture) -- ni forum_topics ni forum_posts n'ont de colonne author_real/author_org_id/
-- author_org_icon aujourd'hui (confirme par l'erreur 42703 "column ... does not exist" sur les
-- deux tables). Aucune colonne equivalente a reutiliser.
--
-- Risque de deploiement DELIBEREMENT ecarte : forum_topics/forum_posts sont sur le chemin
-- critique de TOUTE publication (personnelle ou organisationnelle), contrairement aux tables
-- plus rarement ecrites du lot etat-civil precedent. Le code cote client (sbCreateTopic/
-- sbCreatePost, supabase.js) n'inclut donc ces 3 colonnes dans le payload d'ecriture QUE
-- lorsque authorIsOrg est vrai -- une publication personnelle (l'immense majorite du trafic
-- forum) n'ecrit jamais ces colonnes et reste entierement fonctionnelle, deploiement compris,
-- meme AVANT que cette migration ne soit appliquee. Seule la publication au nom d'une
-- organisation en depend, et echoue proprement (message "la publication n'a pas pu etre
-- enregistree", aucun etat local corrompu, meme garde-fou que le correctif forum du 16 aout
-- 2026 deja en place) tant que la migration n'a pas ete executee.
--
-- author_real : identite technique reelle du personnage ayant effectue l'action, distincte de
-- l'identite publique affichee (author). Sert a la moderation/l'audit, jamais affichee
-- publiquement. Seulement rempli pour les publications organisationnelles (une publication
-- personnelle n'a pas besoin de ce champ : author EST deja l'identite reelle dans ce cas).
--
-- author_org_id : identifiant de l'organisation au moment de la publication, pour tracabilite
-- eventuelle. Ne sert PAS a retrouver le logo/nom a l'affichage (voir author_org_icon
-- ci-dessous) -- l'organisation peut etre dissoute plus tard, l'ancien message doit rester
-- lisible avec son identite d'origine intacte.
--
-- author_org_icon : icone (classe Tabler Icons, ex. 'ti-flag') du TYPE d'organisation, FIGEE au
-- moment de la publication -- aucune organisation n'a de logo propre a ce jour, c'est le seul
-- avatar institutionnel generique deja disponible dans le jeu (TYPES_ORGANISATIONS[type].icon,
-- data.js). Duree de stockage negligeable (quelques caracteres), pas de duplication d'image.
--
-- La cle anon (utilisee par le client via l'API REST) n'a pas les privileges DDL necessaires
-- pour executer ceci elle-meme (deja le cas pour tous les changements de schema de ce projet --
-- voir migration_origin_school_freepts.sql, migration_etat_civil_ville.sql -- toujours executes
-- manuellement par Fred dans l'editeur SQL Supabase).

ALTER TABLE forum_topics ADD COLUMN IF NOT EXISTS author_real text;
ALTER TABLE forum_topics ADD COLUMN IF NOT EXISTS author_org_id text;
ALTER TABLE forum_topics ADD COLUMN IF NOT EXISTS author_org_icon text;

ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS author_real text;
ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS author_org_id text;
ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS author_org_icon text;
