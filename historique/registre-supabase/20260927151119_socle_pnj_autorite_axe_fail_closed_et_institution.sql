-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927151119
-- Nom original      : socle_pnj_autorite_axe_fail_closed_et_institution
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 15:11:19 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ca19c750ed953a74574f3d742a0c44b7
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
-- CHECKPOINT C — L'AUTORITE D'UN AXE SE LIT PAR UNE SEULE FONCTION, ET ELLE EST FAIL-CLOSED
--
-- LE PIEGE QUE CECI FERME. `pnj_axe_verrouille` verrouillait l'axe quand l'autorite valait
-- EXACTEMENT 'blob'. Toute valeur nouvelle aurait donc **ouvert** la garde -- exactement le
-- symetrique du piege de logique ternaire deja rencontre : la garde s'ouvre precisement dans le cas
-- qu'elle n'a pas prevu. Or je m'apprete a introduire une troisieme valeur d'autorite. La garde doit
-- donc dire l'inverse : elle verrouille des que l'autorite n'est PAS le socle.
--
-- POURQUOI UNE TROISIEME VALEUR. La position d'un douanier ou d'un policier n'est pas "dans un
-- blob". Elle est DERIVEE de son perimetre institutionnel : le miroir ecrit `ville = p_ville` et
-- `building_id = p_batiment`, c'est-a-dire le poste lui-meme. Aucune RPC ne deplace un douanier, et
-- le socle n'a donc rien a decider. L'appeler 'blob' laissait croire a un magasin concurrent qu'il
-- suffirait de basculer ; la verite est qu'il n'y a personne a qui prendre l'autorite. 'institution'
-- nomme cet etat. Cela ne change AUCUN comportement de jeu : c'est le meme etat, correctement nomme.
CREATE OR REPLACE FUNCTION public.pnj_axe_au_socle(p_famille text, p_axe text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  -- Totale par construction : une famille ou un axe inconnu rend false, jamais NULL.
  SELECT COALESCE((SELECT a.autorite = 'socle' FROM public.pnj_axes_autorite a
                    WHERE a.famille = p_famille AND a.axe = p_axe), false);
$$;

-- FAIL-CLOSED : verrouille des que le socle ne fait pas autorite, quelle que soit la valeur.
CREATE OR REPLACE FUNCTION public.pnj_axe_verrouille(p_ids text[], p_axe text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT m.id FROM public.pnj_membres m
   WHERE m.id = ANY(p_ids)
     AND NOT public.pnj_axe_au_socle(m.famille, p_axe)
   LIMIT 1;
$$;

ALTER TABLE public.pnj_axes_autorite DROP CONSTRAINT pnj_axes_autorite_autorite_check;
ALTER TABLE public.pnj_axes_autorite ADD CONSTRAINT pnj_axes_autorite_autorite_check
  CHECK (autorite = ANY (ARRAY['socle', 'blob', 'institution']));

UPDATE public.pnj_axes_autorite
   SET autorite = 'institution',
       note = 'La position d''un agent de la force publique EST son poste : le miroir la derive du '
           || 'batiment ou vit son effectif. Aucune RPC ne le deplace, et il ne suit aucun leader. '
           || 'Ce n''est donc pas un magasin concurrent a basculer : il n''y a personne a qui '
           || 'prendre l''autorite. Rendre le socle autoritaire ici n''ajouterait aucune capacite '
           || 'et lui ferait seulement cesser de suivre son institution. Deplacer un agent est une '
           || 'mecanique qui n''existe pas ; l''inventer demanderait un arbitrage.'
 WHERE famille IN ('douanier', 'policier') AND axe = 'position_leader';

REVOKE ALL ON FUNCTION public.pnj_axe_au_socle(text, text)   FROM authenticated, anon;
REVOKE ALL ON FUNCTION public.pnj_axe_verrouille(text[], text) FROM authenticated, anon;