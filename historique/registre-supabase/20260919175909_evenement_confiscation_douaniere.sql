-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919175909
-- Nom original      : evenement_confiscation_douaniere
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:59:09 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3731678e64afec4647be2d630f500ba0
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
-- EVENEMENT MONDE : CONFISCATION DOUANIERE.
--
-- Constat de l'audit : une confiscation reussie ne laissait AUCUNE trace
-- persistante. inventaire_confisquer se bornait a un UPDATE de l'inventaire et
-- JETAIT la liste des objets saisis ; les seuls vestiges etaient un mail et une
-- convocation, ni l'un ni l'autre ne portant le lieu ni la quantite.
--
-- CE N'EST PAS UN JOURNAL D'ESPIONNAGE : c'est un fait du monde, au meme titre
-- qu'une detention ou un jugement, reutilisable par la police, la presse ou la
-- justice. Le Coordinateur ne fera que le LIRE.
--
-- CONTENU STRICTEMENT LIMITE a ce que le GD autorise : personne controlee,
-- objet reellement confisque, lieu canonique, horodatage serveur, reference
-- technique. JAMAIS l'inventaire complet.
--
-- IDEMPOTENCE : naturelle, et c'est ce qui evite d'ajouter un parametre a la
-- signature (une signature modifiee creerait une SURCHARGE, piege connu du
-- projet). Un rejeu apres succes ne trouve plus rien a saisir -- v_saisis est
-- vide -- donc aucun evenement n'est ecrit une seconde fois. L'evenement est
-- ecrit dans LA MEME TRANSACTION que le retrait des objets : jamais de saisie
-- sans trace, jamais de trace sans saisie.
--
-- RLS activee, AUCUNE policy : lecture serveur uniquement. Decider qui, parmi
-- les joueurs, peut consulter le registre des douanes serait un arbitrage de
-- brouillard d'information -- il n'est pas pris ici.

CREATE TABLE IF NOT EXISTS public.confiscations_douanieres (
  id           text PRIMARY KEY,
  personne     text NOT NULL,
  objet_nom    text NOT NULL,
  objet_type   text,
  quantite     integer,
  pays         text,
  ville        text,
  building_id  text,
  room_id      text,
  reference    text NOT NULL,
  cree_le      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_confiscations_lieu
  ON public.confiscations_douanieres (pays, ville, building_id, cree_le DESC);
CREATE INDEX IF NOT EXISTS idx_confiscations_personne
  ON public.confiscations_douanieres (personne, cree_le DESC);

ALTER TABLE public.confiscations_douanieres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.confiscations_douanieres FROM PUBLIC, anon, authenticated;

-- inventaire_confisquer : comportement INCHANGE (meme signature, meme predicat
-- de saisie, meme valeur de retour). Seul ajout : l'ecriture de l'evenement.
CREATE OR REPLACE FUNCTION public.inventaire_confisquer(p_acteur text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_inv jsonb; v_quete jsonb; v_pays text; v_trouve boolean;
  v_saisis jsonb; v_restant jsonb;
  v_ville text; v_bat text; v_room text; v_ref text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT true, coalesce(inventory, '[]'::jsonb), quete_carriere, coalesce(country, 'republic'),
         current_city, current_building, current_room
    INTO v_trouve, v_inv, v_quete, v_pays, v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT coalesce(v_trouve, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  WITH elements AS (
    SELECT e, (coalesce((e->>'legal')::boolean, true) = false
               OR public.assemblee_loi_en_vigueur(v_pays, e, now()) IS NOT NULL)
              AND NOT public.inventaire_objet_protege(v_quete, e) AS saisi
      FROM jsonb_array_elements(v_inv) e
  )
  SELECT coalesce(jsonb_agg(e) FILTER (WHERE saisi), '[]'::jsonb),
         coalesce(jsonb_agg(e) FILTER (WHERE NOT saisi), '[]'::jsonb)
    INTO v_saisis, v_restant FROM elements;

  IF jsonb_array_length(v_saisis) = 0 THEN
    RETURN jsonb_build_object('ok', true, 'saisis', '[]'::jsonb, 'inventory', v_inv, 'noms', '');
  END IF;

  UPDATE public.personnages_donnees SET inventory = v_restant WHERE name = p_acteur;

  -- EVENEMENT MONDE, une ligne par objet reellement confisque, dans la meme
  -- transaction que le retrait.
  v_ref := 'conf-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
           substr(md5(p_acteur || random()::text), 1, 8);
  INSERT INTO public.confiscations_douanieres
    (id, personne, objet_nom, objet_type, quantite, pays, ville, building_id, room_id, reference)
  SELECT v_ref || '-' || o.ord, p_acteur,
         coalesce(o.e ->> 'name', o.e ->> 'nom', '?'),
         o.e ->> 'type',
         nullif(coalesce(o.e ->> 'qty', o.e ->> 'quantite'), '')::integer,
         v_pays, v_ville, v_bat, v_room, v_ref
    FROM jsonb_array_elements(v_saisis) WITH ORDINALITY AS o(e, ord);

  RETURN jsonb_build_object('ok', true, 'saisis', v_saisis, 'inventory', v_restant,
    'noms', (SELECT string_agg(e->>'name', ', ') FROM jsonb_array_elements(v_saisis) e));
END; $function$;
