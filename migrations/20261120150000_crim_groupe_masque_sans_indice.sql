-- Correctif Criminalité (Fred, 20/11/2026) : écrire à un masqué par son vrai nom reste permis (le masque
-- ne cache que l'identité dans la pièce), mais aucune demande ne doit révéler sa position.
-- groupe_pj_rejoindre(vrai nom) répondait « pas_co_presents » ou acceptait : un oracle « ce masqué est X,
-- et il est ici ». Un chef caché ou masqué répond désormais exactement comme un absent.
-- (Le courrier ne lit aucune position : rien à corriger.)
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

SELECT pg_temp.rp_raccorder('public.groupe_pj_rejoindre(text)'::regprocedure,
  $a$ IF a.country IS NULL OR b.country IS NULL$a$,
  $a$ IF coalesce(public.crim_mode_action_interne(p_chef), 'decouvert') <> 'decouvert' /* crim_groupe_masque_v1 */ THEN
   RETURN jsonb_build_object('ok',false,'raison','pas_co_presents'); END IF;
 IF a.country IS NULL OR b.country IS NULL$a$,
  'crim_groupe_masque_v1');
