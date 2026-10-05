-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927141512
-- Nom original      : socle_pnj_autorite_par_axe
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 14:15:12 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 19e04a3f341bbd5596cbae0e3c87fec5
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
-- LOT 4a — L'AUTORITE DEVIENT UNE PROPRIETE PAR AXE (27 septembre 2026)
--
-- Jusqu'ici un seul verrou, `pnj_axe_partage_verrouille`, disait a la fois deux choses qui n'ont
-- rien a voir :
--   (a) « le blob fait encore autorite pour cette donnee » -- un etat de MIGRATION, temporaire ;
--   (b) « on ne deplace pas un soldat un par un » -- une regle de JEU, permanente : le modele
--       militaire opere par NOMBRE, pas par soldat designe.
-- Les confondre rendait la bascule tout-ou-rien : liberer (a) aurait libere (b), c'est-a-dire
-- change le gameplay. Ce lot les separe, et c'est ce qui rend la bascule incrementale possible.

-- ---------------------------------------------------------------------------------------
-- (a) L'ETAT DE MIGRATION, AXE PAR AXE
-- ---------------------------------------------------------------------------------------
CREATE TABLE public.pnj_axes_autorite (
  famille   text NOT NULL,
  axe       text NOT NULL,
  autorite  text NOT NULL CHECK (autorite IN ('socle','blob')),
  note      text,
  PRIMARY KEY (famille, axe)
);
ALTER TABLE public.pnj_axes_autorite ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pnj_axes_autorite FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.pnj_axes_autorite IS
  'Ou vit la verite, axe par axe et famille par famille, pendant la migration vers le socle. '
  'La matrice est renseignee EN ENTIER : une case absente serait une ambiguite, pas un defaut.';

-- La matrice complete. « blob » designe le magasin historique de la famille : le blob de
-- compagnie pour les soldats, la sous-cle d'effectifs de batiment pour la force publique.
INSERT INTO public.pnj_axes_autorite (famille, axe, autorite, note) VALUES
  ('soldat',   'position_leader', 'blob',  'Cinq ecrivains dans le blob. Position et leader sont '
     || 'INDIVISIBLES : trois de ces ecrivains les posent dans la meme ecriture, et la contrainte '
     || 'des deux etats porte sur les deux a la fois -- les separer creerait un etat intermediaire '
     || 'invalide.'),
  ('soldat',   'possessions',     'blob',  'Le tableau `accessoires` du blob fait autorite ; le '
     || 'socle en porte le miroir sous origine=blob_accessoires.'),
  ('soldat',   'pa',              'blob',  'Hors perimetre du lot 4 : la bascule des PA est le lot 5.'),
  ('soldat',   'argent',          'socle', 'Le blob militaire n''a aucune notion d''argent : cet axe '
     || 'n''a jamais eu de concurrent.'),
  ('soldat',   'propriete',       'socle', 'Propriete et autorite sont resolues par le socle et le '
     || 'registre des institutions depuis le 27/09. Le blob ne decide que le PERIMETRE -- section '
     || 'ou reserve -- qui est une donnee metier et le reste.'),
  ('douanier', 'position_leader', 'blob',  'La fiche d''effectif porte le batiment et la piece.'),
  ('douanier', 'possessions',     'socle', 'Aucune possession dans le magasin historique.'),
  ('douanier', 'pa',              'socle', 'Sans objet : la classe beta interdit tout debit.'),
  ('douanier', 'argent',          'socle', NULL),
  ('douanier', 'propriete',       'socle', NULL),
  ('policier', 'position_leader', 'blob',  'La fiche d''effectif porte le batiment, la piece ou le '
     || 'noeud de rue.'),
  ('policier', 'possessions',     'socle', 'Aucune possession dans le magasin historique.'),
  ('policier', 'pa',              'socle', 'Sans objet : la classe beta interdit tout debit.'),
  ('policier', 'argent',          'socle', NULL),
  ('policier', 'propriete',       'socle', NULL);

-- Rend l'identifiant du premier PNJ dont l'axe demande vit encore dans le magasin historique.
-- Une famille ou un axe non declare est traite comme VERROUILLE : on n'ouvre pas une ecriture
-- generique par omission.
CREATE OR REPLACE FUNCTION public.pnj_axe_verrouille(p_ids text[], p_axe text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT m.id FROM public.pnj_membres m
   WHERE m.id = ANY(p_ids)
     AND COALESCE((SELECT a.autorite FROM public.pnj_axes_autorite a
                    WHERE a.famille = m.famille AND a.axe = p_axe), 'blob') = 'blob'
   LIMIT 1;
$$;

-- ---------------------------------------------------------------------------------------
-- (b) LA REGLE DE JEU, QUI NE DEPEND D'AUCUNE MIGRATION
-- ---------------------------------------------------------------------------------------
-- Un soldat ne se deplace pas individuellement : les ordres militaires prennent un NOMBRE
-- d'hommes, pas un homme designe. Cette regle survivra a la bascule -- elle n'a jamais decrit
-- ou vivait la donnee, mais ce que le joueur a le droit de faire.
CREATE TABLE public.pnj_mouvement_individuel (
  famille  text PRIMARY KEY,
  autorise boolean NOT NULL,
  raison   text NOT NULL,
  note     text
);
ALTER TABLE public.pnj_mouvement_individuel ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pnj_mouvement_individuel FROM PUBLIC, anon, authenticated;

INSERT INTO public.pnj_mouvement_individuel (famille, autorise, raison, note) VALUES
  ('soldat', false, 'mouvement_individuel_interdit',
   'Le modele militaire opere par NOMBRE : militaire_deposer_soldats et '
   'militaire_recuperer_soldats prennent une quantite, jamais un matricule. Rien dans '
   'l''interface ne permet de designer un soldat pour le deplacer. Regle de jeu, pas etat de '
   'migration.'),
  ('douanier', false, 'affectation_par_le_service',
   'Un douanier est affecte par le Chef des Douanes, jamais pris dans un groupe.'),
  ('policier', false, 'affectation_par_le_service',
   'Un policier est affecte a une piece ou a une rue par le Commissaire, jamais pris dans un '
   'groupe.');

CREATE OR REPLACE FUNCTION public.pnj_mouvement_individuel_refus(p_ids text[])
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('pnj', m.id, 'famille', m.famille,
                            'raison', r.raison, 'explication', r.note)
    FROM public.pnj_membres m
    JOIN public.pnj_mouvement_individuel r ON r.famille = m.famille
   WHERE m.id = ANY(p_ids) AND r.autorise = false
   LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.pnj_axe_verrouille(text[],text)          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_mouvement_individuel_refus(text[])   FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_axe_verrouille(text[],text)        TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_mouvement_individuel_refus(text[]) TO service_role;