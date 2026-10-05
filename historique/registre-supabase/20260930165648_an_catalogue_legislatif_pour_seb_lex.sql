-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260930165648
-- Nom original      : an_catalogue_legislatif_pour_seb_lex
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-30 16:56:48 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8b5bea3b467d56cc5741b6ed32cf4867
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
-- LE CATALOGUE LEGISLATIF -- CE QUE SEB LEX EST AUTORISE A CONNAITRE (30/09/2026)
-- Le juriste de l'Assemblee ne doit jamais inventer une matiere, une categorie ni
-- un effet. Sa vision du monde vient donc d'ICI, lue en base a chaque
-- consultation, et non d'une liste recopiee dans un prompt. Quand une categorie
-- ou une matiere est ajoutee au jeu, Seb la connait sans qu'on touche a son code.
--
-- Cette fonction ne decide rien et n'ecrit rien : elle decrit. La validation de
-- ce que l'IA repond se fait ensuite contre ce meme catalogue.
create or replace function public.assemblee_catalogue_legislatif()
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT jsonb_build_object(
    -- Les categories reellement votables, avec ce qu'elles visent.
    'categories', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'categorie', c.categorie,
               'label', c.label,
               'matieres', coalesce(to_jsonb(c.matieres), '[]'::jsonb),
               'types_objet', coalesce(to_jsonb(c.types_objet), '[]'::jsonb),
               'sous_types', coalesce(to_jsonb(c.sous_types), '[]'::jsonb),
               -- Y a-t-il, dans cette categorie, au moins une matiere que l'on
               -- peut transformer ? Sinon la question du cas B n'a pas de sens et
               -- Seb ne doit pas la poser.
               'transformation_pertinente', EXISTS (
                 SELECT 1 FROM unnest(c.matieres) m
                  WHERE (public.matiere_circuits_disponibles(m) ->> 'transformation')::boolean),
               'production_pertinente', EXISTS (
                 SELECT 1 FROM unnest(c.matieres) m
                  WHERE (public.matiere_circuits_disponibles(m) ->> 'production_usine')::boolean
                     OR (public.matiere_circuits_disponibles(m) ->> 'recolte')::boolean)
             ) ORDER BY c.label)
        FROM public.assemblee_categories_interdiction c), '[]'::jsonb),
    -- Les circuits reels de chaque matiere, pour que Seb ne parle jamais d'un
    -- mecanisme inexistant.
    'matieres', coalesce((
      SELECT jsonb_agg(public.matiere_circuits_disponibles(r.cle) ORDER BY r.cle)
        FROM public.ressources_economie r), '[]'::jsonb),
    -- Les dimensions de portee que le moteur sait REELLEMENT appliquer. Liste
    -- fermee, la meme que celle qu'assemblee_portee_valider accepte.
    'portee_dimensions', jsonb_build_array('transformation_stock_interdite')
  );
$fn$;

comment on function public.assemblee_catalogue_legislatif() is
  'Tout ce qu''un juriste de l''Assemblee est autorise a connaitre : les categories d''interdiction votables (avec ce qu''elles visent et si la transformation ou la production ont un sens pour elles), les circuits reels de chaque matiere economique, et la liste FERMEE des dimensions de portee que le moteur sait appliquer. Lu en base a chaque consultation : ajouter une categorie ou une matiere suffit a ce que Seb Lex la connaisse. Ne decide rien, n''ecrit rien.';

revoke all on function public.assemblee_catalogue_legislatif() from public, anon;
grant execute on function public.assemblee_catalogue_legislatif() to authenticated, service_role;

DO $garde$
DECLARE v_cat jsonb; n integer;
BEGIN
  v_cat := public.assemblee_catalogue_legislatif();
  SELECT jsonb_array_length(v_cat -> 'categories') INTO n;
  IF n <> 21 THEN RAISE EXCEPTION 'catalogue : % categories, 21 attendues (15 + les 6 ajoutees)', n; END IF;
  SELECT jsonb_array_length(v_cat -> 'matieres') INTO n;
  IF n <> 17 THEN RAISE EXCEPTION 'catalogue : % matieres, 17 attendues', n; END IF;
  -- La dimension de portee du catalogue doit etre exactement celle que le
  -- validateur accepte : sans quoi Seb proposerait un effet refuse au depot.
  IF NOT (public.assemblee_portee_valider(
            jsonb_build_object('transformation_stock_interdite', true)) ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'le validateur refuse la dimension annoncee par le catalogue';
  END IF;
  IF (public.assemblee_portee_valider(
        jsonb_build_object('effet_invente', true)) ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'le validateur accepte une dimension inventee';
  END IF;
END $garde$;