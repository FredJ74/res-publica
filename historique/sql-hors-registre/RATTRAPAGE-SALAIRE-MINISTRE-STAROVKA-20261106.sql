-- Rattrapage ciblé du salaire omis au sommeil du 6 novembre 2026.
-- Incident corroboré par le repos serveur, le poste, le barème et l'absence
-- de versement civil. Jamais de crédit au navigateur ni de double paiement.
-- À exécuter une seule fois sur production après correction de la RPC.
DO $rattrapage$
DECLARE
  v_personnage constant text := 'Arnie';
  v_jour constant date := DATE '2026-11-06';
  v_poste constant text := 'min_def';
  v_caisse constant text := 'republic_gouvernement-min_def';
  v_ligne_id text;
  v_pays text;
  v_poste_actuel text;
  v_repos date;
  v_montant integer;
  v_solde numeric;
  v_arg_avant integer;
  v_liquide_avant integer;
BEGIN
  IF (now() AT TIME ZONE 'Europe/Paris')::date <> v_jour THEN
    RAISE EXCEPTION 'rattrapage_ferme_hors_du_jour_du_repos';
  END IF;
  SELECT country,poste->>'id',pa_repos_le,arg,liquide
    INTO v_pays,v_poste_actuel,v_repos,v_arg_avant,v_liquide_avant
    FROM public.personnages_donnees
   WHERE name=v_personnage FOR UPDATE;
  IF NOT FOUND OR v_pays<>'soviet' OR v_poste_actuel<>v_poste OR v_repos<>v_jour THEN
    RAISE EXCEPTION 'rattrapage_fiche_non_eligible';
  END IF;
  IF public.militaire_grade_effectif(v_personnage) IS NOT NULL THEN
    RAISE EXCEPTION 'rattrapage_fiche_militaire';
  END IF;
  SELECT montant INTO STRICT v_montant
    FROM public.salaires_civils_declares
   WHERE pays='republic' AND categorie='poste' AND cle=v_poste;
  IF v_montant<>2800 THEN
    RAISE EXCEPTION 'rattrapage_montant_inattendu';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.salaires_caisses WHERE poste_id=v_poste) THEN
    RAISE EXCEPTION 'rattrapage_caisse_salaire_non_referencee';
  END IF;
  SELECT (data->>'solde')::numeric INTO STRICT v_solde
    FROM public.caisses_batiments WHERE id=v_caisse FOR UPDATE;
  IF v_solde<v_montant THEN
    RAISE EXCEPTION 'rattrapage_caisse_insuffisante';
  END IF;

  -- Même clef quotidienne unique que salaire_civil_percevoir().
  -- En cas de versement intervenu entre-temps, zéro modification d'argent.
  INSERT INTO public.salaires_civils_verses(id,personnage,jour,origine,cle,montant)
  VALUES (v_personnage||':'||v_jour::text,v_personnage,v_jour,'poste',v_poste,v_montant)
  ON CONFLICT DO NOTHING RETURNING id INTO v_ligne_id;

  IF v_ligne_id IS NOT NULL THEN
    UPDATE public.caisses_batiments
       SET data=coalesce(data,'{}'::jsonb)||jsonb_build_object('solde',v_solde-v_montant),
           updated_at=now()
     WHERE id=v_caisse;
    UPDATE public.personnages_donnees
       SET liquide=coalesce(liquide,0)+v_montant,
           arg=coalesce(arg,0)+v_montant,
           updated_at=now()
     WHERE name=v_personnage;
    RAISE NOTICE 'Salaire rattrapé : % FR pour % le % (caisse %).',v_montant,v_personnage,v_jour,v_caisse;
  ELSE
    RAISE NOTICE 'Salaire du % deja enregistre pour % : aucune nouvelle operation.',v_jour,v_personnage;
  END IF;
END $rattrapage$;
