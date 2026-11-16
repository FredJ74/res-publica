-- Goulag Sovarka : noyau transactionnel de traversée.
-- NON ACTIF tant que l'admission, la confiscation, le gel de peine et la récupération ne
-- sont pas raccordés. AUCUNE fonction publique ne crée de traversée.
-- Tous les verdicts et les PA sont décidés côté serveur ; jamais par le navigateur.

CREATE TABLE IF NOT EXISTS public.sovarka_goulag_traversees (
  nom text PRIMARY KEY REFERENCES public.personnages_donnees(name),
  destination text NOT NULL CHECK (destination IN ('starovka','krasnov')),
  statut text NOT NULL CHECK (statut IN ('detenu','visiteur')),
  progressions integer NOT NULL DEFAULT 0 CHECK (progressions BETWEEN 0 AND 10),
  en_cours boolean NOT NULL DEFAULT true,
  jour_abri date,
  jour_sommeil date,
  jour_progression date,
  bois_trouve integer NOT NULL DEFAULT 0 CHECK (bois_trouve BETWEEN 0 AND 8),
  detention_id text,
  peine_gelee_jours integer,
  debut_le date NOT NULL DEFAULT public.sovarka_jour_paris(),
  arrivee_le date,
  cree_le timestamptz NOT NULL DEFAULT now(),
  actualise_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_goulag_traversees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_traversees FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.goulag_toundra_lire()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_nom text;
  v_t public.sovarka_goulag_traversees%ROWTYPE;
  v_pa integer;
  v_total integer;
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','sans_personnage'); END IF;
  SELECT * INTO v_t FROM public.sovarka_goulag_traversees WHERE nom=v_nom AND en_cours;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_traversee'); END IF;
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() AND country='soviet';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','hors_sovarka'); END IF;
  v_total := CASE v_t.destination WHEN 'starovka' THEN 7 ELSE 10 END;
  RETURN jsonb_build_object('ok',true,'en_cours',true,'destination',v_t.destination,
    'statut',v_t.statut,'progressions',v_t.progressions,'total',v_total,'pa',v_pa,
    'bois_trouve',v_t.bois_trouve,
    'abri_aujourdhui',v_t.jour_abri=public.sovarka_jour_paris(),
    'dormi_aujourdhui',v_t.jour_sommeil=public.sovarka_jour_paris(),
    'progresse_aujourdhui',v_t.jour_progression=public.sovarka_jour_paris());
END;
$$;

CREATE OR REPLACE FUNCTION public.goulag_toundra_agir(p_action text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_nom text;
  v_pa integer;
  v_pays text;
  v_t public.sovarka_goulag_traversees%ROWTYPE;
  v_jour date := public.sovarka_jour_paris();
  v_total integer;
  v_gain_bois integer := 0;
  v_arrive boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','sans_personnage'); END IF;
  -- Saisir d'abord le verrou personnage : toutes les actions PA concurrentes suivent ce protocole.
  SELECT pa,country INTO v_pa,v_pays
    FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR v_pays IS DISTINCT FROM 'soviet'
    THEN RETURN jsonb_build_object('ok',false,'raison','hors_sovarka'); END IF;
  SELECT * INTO v_t FROM public.sovarka_goulag_traversees
    WHERE nom=v_nom AND en_cours FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_traversee'); END IF;
  IF v_pa IS NULL OR v_pa < 1 THEN RETURN jsonb_build_object('ok',false,'raison','pa_invalides'); END IF;
  v_total := CASE v_t.destination WHEN 'starovka' THEN 7 ELSE 10 END;
  IF p_action = 'abri' THEN
    IF v_t.jour_abri=v_jour OR v_t.jour_sommeil=v_jour
      THEN RETURN jsonb_build_object('ok',false,'raison','abri_deja_fait'); END IF;
    IF v_pa <= 1 THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants'); END IF;
    v_pa := v_pa - 1;
    UPDATE public.sovarka_goulag_traversees
      SET jour_abri=v_jour,actualise_le=now() WHERE nom=v_nom;
  ELSIF p_action = 'dormir' THEN
    IF v_t.jour_sommeil=v_jour
      THEN RETURN jsonb_build_object('ok',false,'raison','sommeil_deja_fait'); END IF;
    -- Le malus des champignons n'est pas encore défini ; le déclencheur futur
    -- devra être ajouté avant toute ouverture de la traversée en production.
    v_pa := v_pa + CASE WHEN v_t.jour_abri=v_jour THEN 6 ELSE 3 END;
    UPDATE public.sovarka_goulag_traversees
      SET jour_sommeil=v_jour,actualise_le=now() WHERE nom=v_nom;
  ELSIF p_action = 'progresser' THEN
    IF v_t.jour_progression=v_jour
      THEN RETURN jsonb_build_object('ok',false,'raison','progression_deja_faite'); END IF;
    IF v_pa <= 5 THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants'); END IF;
    v_pa := v_pa-5;
    IF v_t.progressions+1=v_total-1 THEN v_gain_bois:=5; END IF;
    IF v_t.progressions+1=v_total THEN v_gain_bois:=3; END IF;
    v_arrive:=v_t.progressions+1=v_total;
    UPDATE public.sovarka_goulag_traversees
      SET jour_progression=v_jour,progressions=progressions+1,
          bois_trouve=bois_trouve+v_gain_bois,
          en_cours=NOT v_arrive,
          arrivee_le=CASE WHEN v_arrive THEN v_jour ELSE NULL END,
          actualise_le=now()
      WHERE nom=v_nom;
    IF v_arrive THEN v_pa:=1; END IF;
  ELSE
    RETURN jsonb_build_object('ok',false,'raison','ordre_inconnu');
  END IF;
  -- Pas de déplacement au terme du trajet tant que le repos forcé sécurisé
  -- et les dispositifs judiciaires ne sont pas en place : bloquer la dernière
  -- étape plutôt que laisser sortir un joueur sans contrôle.
  IF v_arrive THEN
    RAISE EXCEPTION 'goulag_arrivee_non_raccordee';
  END IF;
  UPDATE public.personnages_donnees SET pa=v_pa WHERE name=v_nom AND user_id=auth.uid();
  RETURN jsonb_build_object('ok',true,'en_cours',true,'progressions',
    CASE WHEN p_action='progresser' THEN v_t.progressions+1 ELSE v_t.progressions END,
    'pa',v_pa,'bois_gagne',v_gain_bois);
END;
$$;
REVOKE ALL ON FUNCTION public.goulag_toundra_lire() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.goulag_toundra_agir(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.goulag_toundra_lire() TO authenticated;
GRANT EXECUTE ON FUNCTION public.goulag_toundra_agir(text) TO authenticated;
