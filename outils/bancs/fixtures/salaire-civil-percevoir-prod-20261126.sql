CREATE OR REPLACE FUNCTION public.salaire_civil_percevoir()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text; v_ville text; v_grade text;
  v_jour date; v_id text; v_cle text; v_origine text; v_montant integer;
  v_offres jsonb; v_offre text; v_caisse text; v_solde numeric;
  v_arg numeric; v_liquide numeric; v_paye numeric;
  v_poste_pays text; v_poste_pays_count integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT coalesce(nationalite,country,'republic'), poste ->> 'id',
         public.salaire_ville_du_poste(poste ->> 'id', poste ->> 'city')
    INTO v_pays, v_poste, v_ville
    FROM public.personnages_donnees WHERE name = v_moi;
  -- Le pays de presence (country) ne doit pas déterminer l'employeur du poste.
  -- Pour un poste avec barème unique, le pays payeur vient du registre serveur.
  -- S'il existe plusieurs pays possibles pour une même clé, refuser plutôt
  -- que choisir arbitrairement une trésorerie étrangère.
  IF v_poste IS NOT NULL THEN
    SELECT a.country INTO v_poste_pays
      FROM public.postes_attribues a
     WHERE a.titulaire = v_moi AND a.poste_id = v_poste
     ORDER BY a.updated_at DESC NULLS LAST LIMIT 1;
    IF v_poste_pays IS NULL THEN
      SELECT c.country INTO v_poste_pays
        FROM public.cycles_electoraux c
       WHERE c.poste_id = v_poste AND c.data::jsonb ->> 'eluId' = v_moi
       ORDER BY c.updated_at DESC NULLS LAST LIMIT 1;
    END IF;
  END IF;
  IF v_poste_pays IS NOT NULL THEN
    v_pays := v_poste_pays;
  ELSIF v_poste IS NOT NULL THEN
    SELECT count(DISTINCT s.pays), min(s.pays)
      INTO v_poste_pays_count, v_poste_pays
      FROM public.salaires_civils_declares s
     WHERE s.categorie = 'poste' AND s.cle = v_poste;
    IF v_poste_pays_count > 1 THEN
      RETURN jsonb_build_object('ok',false,'raison','pays_employeur_ambigu','poste',v_poste);
    ELSIF v_poste_pays_count = 1 THEN
      v_pays := v_poste_pays;
    END IF;
  END IF;
  v_grade := public.militaire_grade_effectif(v_moi);
  IF v_grade IS NOT NULL OR coalesce(v_poste,'') IN ('soldat','lieutenant','capitaine','commandant') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paye_par_la_caserne');
  END IF;
  IF v_poste IS NOT NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s
     WHERE s.pays = v_pays AND s.cle = v_poste AND s.categorie = 'poste';
  END IF;
  IF v_cle IS NULL THEN
    SELECT coalesce(public.batiment_etat_lire(e.data) -> 'offres', public.batiment_etat_lire(e.data) -> 'bne' -> 'offres')
      INTO v_offres FROM public.batiments_etat e WHERE e.id = v_pays || '_national_bne';
    IF v_offres IS NOT NULL AND jsonb_typeof(v_offres) = 'object' THEN
      SELECT t.k INTO v_offre
        FROM jsonb_each(v_offres) AS t(k, v)
        WHERE EXISTS (
          SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(t.v)='array' THEN t.v ELSE '[]'::jsonb END) o
           WHERE o ->> 'pjNom' = v_moi AND coalesce(o ->> 'statut','actif') = 'actif')
        LIMIT 1;
      IF v_offre IS NOT NULL THEN
        SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
          FROM public.salaires_civils_declares s
         WHERE s.pays = v_pays AND s.cle = v_offre AND s.categorie = 'emploi';
      END IF;
    END IF;
  END IF;
  IF v_cle IS NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s
     WHERE s.pays = v_pays AND s.cle = 'default';
  END IF;
  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bareme_absent', 'pays', v_pays);
  END IF;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := v_moi || ':' || v_jour::text;
  IF v_origine = 'poste' THEN
    v_caisse := public.salaire_caisse_de(v_poste, v_pays, v_ville);
    IF v_caisse IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_payeuse_non_declaree', 'poste', v_poste);
    END IF;
  END IF;
  -- Emplois du Bureau de l'Emploi (25/10/2026, decision de Fred) : payes par leur employeur.
  IF v_origine = 'emploi' THEN
    v_caisse := public.salaire_caisse_de(v_cle, v_pays, NULL);
    IF v_caisse IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_payeuse_non_declaree', 'poste', v_cle);
    END IF;
  END IF;
  BEGIN
    INSERT INTO public.salaires_civils_verses (id, personnage, jour, origine, cle, montant)
    VALUES (v_id, v_moi, v_jour, v_origine, v_cle, v_montant);
  EXCEPTION WHEN unique_violation THEN
    SELECT coalesce(arg,0), coalesce(liquide,0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = v_moi;
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percu_aujourdhui',
                              'jour', v_jour, 'arg', v_arg, 'liquide', v_liquide);
  END;
  v_paye := v_montant;
  IF v_caisse IS NOT NULL THEN
    SELECT (data->>'solde')::numeric INTO v_solde
      FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    v_paye := floor(least(v_montant, greatest(coalesce(v_solde, 0), 0)));
    IF v_paye <= 0 THEN
      DELETE FROM public.salaires_civils_verses WHERE id = v_id;
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide',
                                'caisse', v_caisse, 'solde', coalesce(v_solde,0), 'du', v_montant);
    END IF;
    UPDATE public.caisses_batiments
       SET data = coalesce(data,'{}'::jsonb) || jsonb_build_object('solde', v_solde - v_paye),
           updated_at = now()
     WHERE id = v_caisse;
    IF v_paye <> v_montant THEN
      UPDATE public.salaires_civils_verses SET montant = v_paye WHERE id = v_id;
    END IF;
  END IF;
  UPDATE public.personnages_donnees
     SET liquide = coalesce(liquide,0) + v_paye, arg = coalesce(arg,0) + v_paye,
         updated_at = now()
   WHERE name = v_moi
   RETURNING arg, liquide INTO v_arg, v_liquide;
  RETURN jsonb_build_object('ok', true, 'montant', v_paye, 'du', v_montant,
                            'partiel', v_paye <> v_montant, 'origine', v_origine,
                            'cle', v_cle, 'jour', v_jour, 'caisse', v_caisse,
                            'arg', v_arg, 'liquide', v_liquide);
END; $function$
