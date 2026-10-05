-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260925093500
-- Nom original      : observation_inventaire
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-25 09:35:00 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 0991e9ebd40abdac95f76e5e6e2ec7b2
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
-- =============================================================================================
-- OBSERVER L'INVENTAIRE AVANT DE LE FERMER (25 septembre 2026)
-- =============================================================================================
-- CE QUI EST DEMONTRE, SUR BANC, 7 CAPACITES SUR 7 : un joueur authentifie peut, par un simple
-- PATCH sur la vue `personnages`, ajouter un objet arbitraire, porter une quantite a 99 999,
-- fabriquer une arme illegale a bonus 50, forger du materiel militaire (radio, rations, tente,
-- jumelles -- la radio conditionne le commandement a distance), vider son inventaire, et se
-- donner 999 999 FR et 500 000 en liquide.
--
-- POURQUOI JE NE FERME PAS CE SOIR, ET C'EST LA TELEMETRIE QUI LE DIT.
-- `fiche_hausses_observees` tourne depuis le 20 septembre. Elle a enregistre, pour de VRAIS
-- joueurs, CINQ hausses d'argent cliente parfaitement plausibles (+150 deux fois, +1062 et +208
-- une fois). Le verrou existe pourtant deja -- `rp_transition_active('argent_verrou')` -- et il
-- est DELIBEREMENT a false : des mecaniques crediitent encore l'argent depuis le navigateur, sans
-- equivalent serveur. L'activer aveuglement casserait ces parcours. La meme prudence vaut pour
-- l'inventaire, dont les ecrivains legitimes sont encore majoritairement clients.
--
-- CE QUE JE LIVRE DONC : le meme dispositif d'observation, pour l'inventaire. Il ne bloque RIEN.
-- Il produit la preuve qui manquait -- quelles mecaniques ajoutent reellement des objets, depuis
-- quel role, avec quelle requete -- et c'est exactement ce qui a permis de raisonner sur l'argent.
-- Sans cette base, toute fermeture serait un pari.
--
-- VOLUME MAITRISE : seules les CROISSANCES sont notees (un objet de plus qu'avant), jamais les
-- retraits ni les simples deplacements, et seuls les appels venant d'un navigateur.
CREATE TABLE IF NOT EXISTS public.fiche_inventaire_observe (
  id          bigserial PRIMARY KEY,
  personnage  text,
  avant       integer,
  apres       integer,
  delta       integer,
  objets_ajoutes jsonb,
  role_sql    text,
  requete     text,
  vu_le       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.fiche_inventaire_observe ENABLE ROW LEVEL SECURITY;
-- Aucune policy : table de diagnostic, lisible par le seul service_role. Les joueurs n'ont
-- evidemment pas a savoir qu'ils sont observes, ni a lire l'inventaire des autres.
REVOKE ALL ON public.fiche_inventaire_observe FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.personnages_observer_inventaire()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_avant int; v_apres int; v_ajoutes jsonb;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF NEW.inventory IS NOT DISTINCT FROM OLD.inventory THEN RETURN NEW; END IF;

  v_avant := CASE WHEN jsonb_typeof(OLD.inventory)='array' THEN jsonb_array_length(OLD.inventory) ELSE 0 END;
  v_apres := CASE WHEN jsonb_typeof(NEW.inventory)='array' THEN jsonb_array_length(NEW.inventory) ELSE 0 END;
  IF v_apres <= v_avant THEN RETURN NEW; END IF;   -- retrait ou remplacement : hors sujet

  -- Les identifiants apparus, sans le reste de l'objet (les images base64 n'ont rien a faire ici).
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', o->>'id', 'name', o->>'name',
                                               'type', o->>'type', 'pm', o->>'produitMilitaire')), '[]'::jsonb)
    INTO v_ajoutes
    FROM jsonb_array_elements(NEW.inventory) o
   WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(OLD.inventory,'[]'::jsonb)) a
                      WHERE a->>'id' = o->>'id');

  INSERT INTO public.fiche_inventaire_observe
         (personnage, avant, apres, delta, objets_ajoutes, role_sql, requete)
  VALUES (NEW.name, v_avant, v_apres, v_apres - v_avant, left(v_ajoutes::text, 2000)::jsonb,
          coalesce(nullif(current_setting('role', true), 'none'), session_user),
          left(coalesce(current_query(), ''), 300));

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_personnages_observer_inventaire
  BEFORE UPDATE ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_observer_inventaire();