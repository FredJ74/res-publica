-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927012639
-- Nom original      : socle_pnj_compteurs_anti_rejeu_militaires
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 01:26:39 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : fa9d0bc393a5823db36f93197d5b98fe
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LES QUATRE COMPTEURS ANTI-REJEU MILITAIRES ENTRENT DANS LE METIER DU SOCLE (27 sept. 2026)
--
-- CE QUE L'AUDIT AVAIT VU. Le blob porte, SUR CHAQUE SOLDAT, quatre marqueurs qui empechent de
-- rejouer un ordre le meme jour :
--   dernier_ration  + nb_ration  -- militaire_ordre_collectif('ration')  : 2 rations/jour maxi
--   dernier_bivouac             -- militaire_ordre_collectif('bivouac') : 1 fois par jour
--   dernier_sommeil             -- militaire_reposer_section (DORMIR)   : 1 fois par jour
-- Le socle ne les copiait pas. Aujourd'hui aucun des 96 soldats ne les porte -- personne n'a
-- encore mange ni dormi -- ce qui est exactement ce qui rendait le trou invisible : la copie
-- paraissait fidele parce qu'il n'y avait rien a perdre. Au premier ordre de ration, le socle
-- aurait commence a divergier sans que rien ne le signale, et le jour de la bascule un soldat
-- aurait pu manger deux fois.
--
-- OU ILS VONT. Dans pnj_soldats_metier, pas dans pnj_membres : « ne pas rejouer un ordre
-- militaire le meme jour » n'a aucun sens generique. Le socle ignore ces champs.
--
-- POURQUOI DU TEXTE ET NON UNE DATE. Le socle MIROITE, il ne reinterprete pas. Le blob ecrit
-- (now() AT TIME ZONE 'Europe/Paris')::date::text ; on conserve la chaine telle quelle pour que
-- la comparaison blob/socle soit exacte et TOTALE, sans cast susceptible d'echouer sur une
-- valeur inattendue. La discipline est tenue par un CHECK, pas par une conversion silencieuse.
--
-- nb_ration RESTE SEPARE de son marqueur : le metier applique la regle « ancien marqueur sans
-- compteur vaut 1 » (coalesce(..., 1) dans militaire_ordre_collectif). Fusionner les deux
-- champs detruirait cette nuance.
ALTER TABLE public.pnj_soldats_metier
  ADD COLUMN IF NOT EXISTS dernier_ration  text,
  ADD COLUMN IF NOT EXISTS nb_ration       integer,
  ADD COLUMN IF NOT EXISTS dernier_bivouac text,
  ADD COLUMN IF NOT EXISTS dernier_sommeil text;

ALTER TABLE public.pnj_soldats_metier
  DROP CONSTRAINT IF EXISTS pnj_soldats_compteurs_bien_formes;
ALTER TABLE public.pnj_soldats_metier ADD CONSTRAINT pnj_soldats_compteurs_bien_formes CHECK (
      (dernier_ration  IS NULL OR dernier_ration  ~ '^\d{4}-\d{2}-\d{2}$')
  AND (dernier_bivouac IS NULL OR dernier_bivouac ~ '^\d{4}-\d{2}-\d{2}$')
  AND (dernier_sommeil IS NULL OR dernier_sommeil ~ '^\d{4}-\d{2}-\d{2}$')
  AND (nb_ration IS NULL OR nb_ration >= 0));

COMMENT ON COLUMN public.pnj_soldats_metier.dernier_ration  IS
  'Miroir de sol->>''dernier_ration'' : jour Paris de la derniere ration. Gardes anti-rejeu du '
  'metier militaire, sans equivalent generique.';
COMMENT ON COLUMN public.pnj_soldats_metier.nb_ration       IS
  'Miroir de sol->>''nb_ration''. NULL avec un marqueur du jour vaut 1 dans la regle metier : '
  'ne jamais fusionner ce champ avec son marqueur.';
COMMENT ON COLUMN public.pnj_soldats_metier.dernier_bivouac IS
  'Miroir de sol->>''dernier_bivouac'' : un bivouac par jour.';
COMMENT ON COLUMN public.pnj_soldats_metier.dernier_sommeil IS
  'Miroir de sol->>''dernier_sommeil'' : un DORMIR par jour.';