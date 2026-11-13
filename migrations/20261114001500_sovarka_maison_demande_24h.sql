-- SOVARKA : MAISONS DE STAROVKA ET KRASNOV — le service demandé reste valable 24 heures (décision de Fred, 14/11/2026).
-- Avant : le service du jour était recalculé à chaque visite et changeait à minuit ; un PJ parti acheter 3 bois à
-- 23 h 50 trouvait un autre service à son retour. Désormais, le service demandé à un PJ est retenu pour lui pendant
-- 24 heures à partir de sa première visite (table sovarka_maisons_demandes) ; il est effacé une fois rendu.
-- La règle « une hospitalité par jour et par PJ » ne change pas. Patchs en place, ancrages vérifiés.
BEGIN;

CREATE TABLE IF NOT EXISTS public.sovarka_maisons_demandes (
  personnage text NOT NULL,
  maison text NOT NULL,
  service jsonb NOT NULL,
  expire_le timestamptz NOT NULL,
  PRIMARY KEY (personnage, maison)
);
ALTER TABLE public.sovarka_maisons_demandes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_maisons_demandes FROM PUBLIC, anon, authenticated;

-- Service demandé à ce PJ : la demande encore valable, sinon le service du jour, retenu 24 heures.
CREATE OR REPLACE FUNCTION public.sovarka_maison_service_joueur_interne(p_perso text, p_maison jsonb, p_jour date)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE s jsonb;
BEGIN
  IF p_perso IS NULL OR p_maison IS NULL THEN RETURN public.sovarka_maison_service_interne(p_maison, p_jour); END IF;
  SELECT d.service INTO s FROM public.sovarka_maisons_demandes d
   WHERE d.personnage = p_perso AND d.maison = p_maison->>'id' AND d.expire_le > now();
  IF s IS NOT NULL THEN RETURN s; END IF;
  s := public.sovarka_maison_service_interne(p_maison, p_jour);
  IF s IS NOT NULL THEN
    INSERT INTO public.sovarka_maisons_demandes (personnage, maison, service, expire_le)
    VALUES (p_perso, p_maison->>'id', s, now() + interval '24 hours')
    ON CONFLICT (personnage, maison) DO UPDATE SET service = EXCLUDED.service, expire_le = EXCLUDED.expire_le;
  END IF;
  RETURN s;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_maison_service_joueur_interne(text, jsonb, date) FROM PUBLIC, anon, authenticated;

DO $raccord$
DECLARE d text; avant text; apres text;
BEGIN
  -- Lecture de la maison.
  d := pg_get_functiondef('public.sovarka_maison_lire()'::regprocedure);
  IF position('sovarka_maison_service_joueur_interne' IN d) = 0 THEN
    avant := 's := public.sovarka_maison_service_interne(v->''maison'', v_jour);';
    apres := 's := public.sovarka_maison_service_joueur_interne(a, v->''maison'', v_jour);';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'sovarka_maison_lire : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  -- Rendre le service : le service retenu, puis la demande effacée une fois rendue.
  d := pg_get_functiondef('public.sovarka_maison_agir(text, text)'::regprocedure);
  IF position('sovarka_maison_service_joueur_interne' IN d) = 0 THEN
    avant := 's := public.sovarka_maison_service_interne(m, v_jour);';
    apres := 's := public.sovarka_maison_service_joueur_interne(a, m, v_jour);';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'sovarka_maison_agir : ancrage service introuvable'; END IF;
    d := replace(d, avant, apres);
    avant := 'INSERT INTO public.sovarka_maisons_hospitalite (jour, personnage, maison, service) VALUES (v_jour, a, m->>''id'', s);';
    apres := avant || E'\n    DELETE FROM public.sovarka_maisons_demandes WHERE personnage = a AND maison = m->>''id'';';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'sovarka_maison_agir : ancrage hospitalite introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
END $raccord$;

COMMIT;
