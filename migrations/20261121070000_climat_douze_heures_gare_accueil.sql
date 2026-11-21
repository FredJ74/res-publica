-- CLIMAT — décisions de Fred du 21/11/2026 (GAME-DESIGN-CLIMAT-20261121.md).
-- Contexte : un nouveau joueur, arrivé à Novomirsk pendant un orage, a cru être bloqué par une crue et a abandonné.
-- (La cause du blocage était une vue de rue jamais initialisée : correctif à part, branche claude/position-initiale-20261121.)
-- • Une crue n'entrave jamais les déplacements : elle ne ferme que les 2 ou 3 lieux tirés (refus d'ENTRER, mode « piece »,
--   déjà le seul effet de navigation du raccord climat_crue_v1) ; les rues, la gare et le train restent libres.
-- • La gare n'est jamais touchée : exclue du tirage dans toutes les villes, et interdite dans la table des zones inondables.
-- • Crue, orage, canicule et brouillard durent 12 heures (au lieu de 24). Tous leurs effets lisent la fenêtre debut/fin
--   de l'événement : lieux fermés, chantiers bloqués, coupures, canicule (fin traitée à « fin »), brouillard, filtres.
--   Le blizzard (coup ponctuel) n'est pas concerné. Fréquence, propagation et préavis de 48 h inchangés.
-- • Aucune exemption pour un nouveau personnage (aucune n'existait : rien à retirer, le banc le vérifie).
-- • Fenêtre d'accueil : un personnage créé depuis moins de 24 heures, dans une ville où un événement est en cours, reçoit
--   une fois par événement une explication (climat_accueil_lire / climat_accueil_vu).
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN RAISE EXCEPTION '% : ancrage (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- ── Gare : jamais inondée ────────────────────────────────────────────────────────────────────────
-- Bâtiments de gare : « centre multimodal » (graphie historique « multinodal » comprise), « gare-… », « …-gare ».
-- Le Café de la Gare n'est pas la gare.
CREATE OR REPLACE FUNCTION public.climat_lieu_est_gare_interne(p_batiment text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(p_batiment ~ '(multimodal|multinodal)' OR p_batiment ~ '^hall_gare'
         OR (p_batiment ~ '(^|-)gare(-|$)' AND p_batiment !~ '^cafe-'), false);
$$;
ALTER TABLE public.climat_zones_inondables DROP CONSTRAINT IF EXISTS climat_zones_jamais_gare;
ALTER TABLE public.climat_zones_inondables ADD CONSTRAINT climat_zones_jamais_gare CHECK (NOT public.climat_lieu_est_gare_interne(batiment));

SELECT pg_temp.rp_raccorder('public.climat_creer_interne(text,text,text,date,text,text)'::regprocedure,
  $a$FROM public.climat_zones_inondables WHERE pays = p_pays AND ville = p_ville$a$,
  $b$FROM public.climat_zones_inondables WHERE pays = p_pays AND ville = p_ville AND NOT public.climat_lieu_est_gare_interne(batiment) /* climat_gare_jamais_v1 */$b$,
  'climat_gare_jamais_v1');

-- ── Durées : 12 heures pour crue, orage, canicule, brouillard ────────────────────────────────────
UPDATE public.climat_parametres SET duree_heures = 12 WHERE type IN ('crue', 'orage', 'canicule', 'brouillard');
-- Événements déjà planifiés (et en cours) : même fin, debut + 12 h. Ceux dont la fin est déjà traitée ne changent pas.
UPDATE public.climat_evenements SET fin = debut + interval '12 hours'
 WHERE type IN ('crue', 'orage', 'canicule', 'brouillard') AND fin_traitee_le IS NULL AND fin > debut + interval '12 hours';
-- Groupes électrogènes déjà alimentés pour un orage écourté : ils ne consomment rien de plus, la date suit l'orage.
UPDATE public.equipements_installes g SET objet = jsonb_set(g.objet, '{actif_jusqu}', to_jsonb(e.fin))
  FROM public.climat_evenements e
 WHERE g.generique_id = 'groupe-electrogene' AND e.type = 'orage' AND NOT e.annule AND e.effets_le IS NOT NULL
   AND e.fin_traitee_le IS NULL AND g.pays = e.pays AND g.ville = e.ville
   AND (g.objet->>'actif_jusqu')::timestamptz > e.fin;

SELECT pg_temp.rp_raccorder('public.climat_texte_alerte_interne(public.climat_evenements)'::regprocedure,
  $a$' seront sous les eaux pendant 24 heures.'$a$,
  $b$' seront sous les eaux pendant 12 heures.' /* climat_douze_heures_v1 */$b$,
  'climat_douze_heures_v1');

-- ── Fenêtre d'accueil du nouveau personnage ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.climat_accueils (
  personnage text NOT NULL,
  evenement  bigint NOT NULL REFERENCES public.climat_evenements(id) ON DELETE CASCADE,
  vu_le      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (personnage, evenement)
);
ALTER TABLE public.climat_accueils ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_accueils FROM anon, authenticated;

-- L'événement en cours dans la ville du personnage, s'il est nouveau (créé depuis moins de 24 heures) et ne l'a pas vu.
CREATE OR REPLACE FUNCTION public.climat_accueil_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p public.personnages_donnees; e public.climat_evenements;
BEGIN
  SELECT * INTO p FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF p.created_at IS NULL OR p.created_at < localtimestamp - interval '24 hours' THEN
    RETURN jsonb_build_object('ok', true, 'evenement', NULL);
  END IF;
  SELECT * INTO e FROM public.climat_evenements ev
   WHERE ev.pays = p.country AND ev.ville = p.current_city AND NOT ev.annule AND ev.alerte_le IS NOT NULL
     AND now() >= ev.debut AND now() < ev.fin
     AND NOT EXISTS (SELECT 1 FROM public.climat_accueils a WHERE a.personnage = p_nom AND a.evenement = ev.id)
   ORDER BY ev.debut LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'evenement', NULL); END IF;
  RETURN jsonb_build_object('ok', true, 'maintenant', now(), 'evenement', jsonb_build_object('id', e.id, 'type', e.type,
    'ville', e.ville, 'debut', e.debut, 'fin', e.fin,
    'lieux', (SELECT coalesce(jsonb_agg(l->>'batiment'), '[]'::jsonb) FROM jsonb_array_elements(e.lieux) l)));
END $$;

CREATE OR REPLACE FUNCTION public.climat_accueil_vu_interne(p_nom text, p_evenement bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.climat_evenements WHERE id = p_evenement) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'evenement_inconnu');
  END IF;
  INSERT INTO public.climat_accueils (personnage, evenement) VALUES (p_nom, p_evenement) ON CONFLICT DO NOTHING;
  RETURN jsonb_build_object('ok', true);
END $$;

CREATE OR REPLACE FUNCTION public.climat_accueil_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN public.climat_accueil_interne(a);
END $$;

CREATE OR REPLACE FUNCTION public.climat_accueil_vu(p_evenement bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN public.climat_accueil_vu_interne(a, p_evenement);
END $$;

REVOKE ALL ON FUNCTION public.climat_lieu_est_gare_interne(text), public.climat_accueil_interne(text),
  public.climat_accueil_vu_interne(text, bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.climat_accueil_lire(), public.climat_accueil_vu(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.climat_accueil_lire(), public.climat_accueil_vu(bigint) TO authenticated;

COMMIT;
