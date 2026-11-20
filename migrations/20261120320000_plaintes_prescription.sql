-- PRESCRIPTION DES PLAINTES (décision de Fred du 20/11/2026). GAME-DESIGN-CRIMINALITE.md § 3 (plainte et enquête).
--  • Une plainte (contre X ou contre une personne nommée) qui n'a pas abouti — toujours au parquet ou en enquête, affaire
--    liée jamais identifiée, aucun procès engagé — devient CADUQUE 30 jours après son dépôt. Passe de nuit
--    (api/cron-minuit.js → plaintes_prescrire, réservée au serveur).
--  • Une plainte qui a mené à une identification ou à un procès (poursuites, audience, jugement, appel) n'est jamais
--    prescrite : seuls les statuts « au_parquet » et « enquete » sont prescriptibles.
--  • À la prescription : une ligne d'historique minimale (plaintes_historique : date de dépôt, ville, type d'acte,
--    « prescrite »), la plainte quitte plaintes_en_cours, l'affaire liée (crim_affaires) est archivée et ses données
--    lourdes (indices, détails) purgées. Le plaignant PJ reçoit un COURRIER (exception voulue : notification
--    administrative) ; un PNJ plaignant (employeur), rien.
-- Idempotente.
BEGIN;

CREATE TABLE IF NOT EXISTS public.plaintes_historique (
  id bigserial PRIMARY KEY,
  plainte_id text NOT NULL UNIQUE,
  pays text, ville text, acte text,
  depose_le date,
  statut text NOT NULL DEFAULT 'prescrite',
  clos_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.plaintes_historique ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.plaintes_historique FROM anon, authenticated;

ALTER TABLE public.crim_affaires ADD COLUMN IF NOT EXISTS archivee_le timestamptz;

CREATE OR REPLACE FUNCTION public.plaintes_prescrire(p_jours integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; d jsonb; v_aff bigint; v_acte text; v_libelle text; v_ville text; v_depose timestamptz; n integer := 0; m integer := 0;
BEGIN
  FOR r IN SELECT * FROM public.plaintes_en_cours ORDER BY created_at FOR UPDATE SKIP LOCKED LOOP
    BEGIN d := r.data::jsonb; EXCEPTION WHEN others THEN CONTINUE; END;
    IF coalesce(d ->> 'status', '') NOT IN ('au_parquet', 'enquete') THEN CONTINUE; END IF;
    v_depose := coalesce(CASE WHEN coalesce(d ->> 'depose_le', '') ~ '^\d{4}-\d{2}-\d{2}' THEN (d ->> 'depose_le')::timestamptz END, r.created_at);
    IF v_depose > now() - make_interval(days => p_jours) THEN CONTINUE; END IF;
    v_aff := CASE WHEN coalesce(d ->> 'affaire', '') ~ '^\d+$' THEN (d ->> 'affaire')::bigint END;
    -- Jamais prescrite après une identification (échec critique, enquête réussie, arrestation, démasquage).
    IF EXISTS (SELECT 1 FROM public.crim_affaires a WHERE (a.id = v_aff OR a.plainte_id = r.id) AND a.identifie) THEN CONTINUE; END IF;
    SELECT a.acte INTO v_acte FROM public.crim_affaires a WHERE a.id = v_aff OR a.plainte_id = r.id ORDER BY a.id LIMIT 1;
    v_acte := coalesce(v_acte, d ->> 'qualification_parquet', d ->> 'categorie_alleguee', 'plainte');
    v_libelle := CASE v_acte WHEN 'neutraliser' THEN 'neutralisation' WHEN 'voler' THEN 'vol' WHEN 'cambrioler' THEN 'cambriolage'
                    WHEN 'empoisonner' THEN 'empoisonnement' WHEN 'utiliser_explosifs' THEN 'attentat à l''explosif'
                    WHEN 'incendier' THEN 'incendie' WHEN 'crocheter' THEN 'effraction' WHEN 'forcer_porte' THEN 'effraction'
                    WHEN 'fausse_rumeur' THEN 'rumeur calomnieuse' WHEN 'tracts_calomnieux' THEN 'tracts calomnieux' END;
    v_libelle := coalesce(v_libelle, (SELECT b.libelle FROM public.peine_acte_interne(v_acte, coalesce(r.country, d ->> 'country')) b LIMIT 1), replace(v_acte, '_', ' '));
    v_ville := coalesce(public.climat_nom_ville_interne(coalesce(r.country, d ->> 'country'), coalesce(r.city, d ->> 'city')), r.city);
    INSERT INTO public.plaintes_historique (plainte_id, pays, ville, acte, depose_le, statut)
    VALUES (r.id, coalesce(r.country, d ->> 'country'), coalesce(r.city, d ->> 'city'), v_acte, v_depose::date, 'prescrite')
    ON CONFLICT (plainte_id) DO NOTHING;
    UPDATE public.crim_affaires SET indices = '{}'::jsonb, details = '{}'::jsonb, archivee_le = now(), maj_le = now()
     WHERE (id = v_aff OR plainte_id = r.id) AND archivee_le IS NULL;
    DELETE FROM public.plaintes_en_cours WHERE id = r.id;
    n := n + 1;
    -- Courrier au plaignant PJ (un PNJ plaignant, représenté par son employeur, ne reçoit rien).
    IF coalesce(d ->> 'auteur', '') <> '' AND EXISTS (SELECT 1 FROM public.personnages_donnees p WHERE p.name = d ->> 'auteur') THEN
      PERFORM public.mail_systeme_poser_interne('Ministère public', d ->> 'auteur', 'Plainte prescrite',
        'Votre plainte du ' || to_char(v_depose AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY') || ' pour ' || lower(v_libelle)
        || ' à ' || v_ville || ' est prescrite : faute d''élément nouveau, l''enquête est close.', NULL);
      m := m + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'prescrites', n, 'courriers', m);
END $$;
REVOKE ALL ON FUNCTION public.plaintes_prescrire(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.plaintes_prescrire(integer) TO service_role;

COMMIT;
