-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine banque -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- accepter_accord_helvetia(text,text) -> prets | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.accepter_accord_helvetia(p_personnage text, p_pret_id text)
 RETURNS prets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pret public.prets%rowtype;
BEGIN
  PERFORM public.exiger_acteur(p_personnage);
  SELECT * INTO v_pret FROM public.prets WHERE id = p_pret_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pret introuvable'; END IF;
  IF v_pret.emprunteur <> p_personnage THEN RAISE EXCEPTION 'Ce pret n''appartient pas a ce personnage'; END IF;
  IF v_pret.type_banque <> 'helvetia' THEN RAISE EXCEPTION 'Pas un pret Helvetia'; END IF;
  IF v_pret.statut <> 'contentieux' THEN RAISE EXCEPTION 'Accord disponible uniquement en procedure contentieuse'; END IF;
  IF NOT v_pret.proposition_en_attente THEN RAISE EXCEPTION 'Aucune proposition en attente pour ce pret'; END IF;
  IF v_pret.accord_actif THEN RAISE EXCEPTION 'Un accord est deja actif'; END IF;

  UPDATE public.prets
    SET montant_restant = ROUND(montant_restant * 1.20),
        accord_actif = true,
        accord_fin_le = now() + interval '10 days',
        accord_avertissement_envoye = false
    WHERE id = p_pret_id
    RETURNING * INTO v_pret;

  RETURN v_pret;
END;
$function$;

-- banque_nationale_mouvement(text,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.banque_nationale_mouvement(p_acteur text, p_sens text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_liquide numeric; v_arg numeric; v_compte_id text; v_solde numeric; v_pays text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_sens NOT IN ('depot', 'retrait') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant <> trunc(p_montant)
     OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  -- Ordre de verrou fixe : personnage puis compte. Deux operations simultanees se serialisent.
  SELECT COALESCE(liquide,0), COALESCE(arg,0), country
    INTO v_liquide, v_arg, v_pays
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_liquide IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT id, COALESCE(solde,0) INTO v_compte_id, v_solde
    FROM public.comptes_bancaires
   WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;

  IF p_sens = 'depot' THEN
    IF v_liquide < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'liquide_insuffisant', 'liquide', v_liquide);
    END IF;
    IF v_compte_id IS NULL THEN
      -- Premier depot d'un personnage sans compte : la ligne est creee ici, sous verrou,
      -- plutot que par une ecriture cliente separee.
      v_compte_id := 'nationale_' || p_acteur;
      INSERT INTO public.comptes_bancaires (id, personnage, pays, banque, solde, updated_at)
      VALUES (v_compte_id, p_acteur, COALESCE(v_pays,'republic'), 'nationale', 0, now())
      ON CONFLICT (id) DO NOTHING;
      SELECT COALESCE(solde,0) INTO v_solde FROM public.comptes_bancaires WHERE id = v_compte_id;
    END IF;
    UPDATE public.personnages_donnees SET liquide = v_liquide - p_montant, updated_at = now()
     WHERE name = p_acteur;
    UPDATE public.comptes_bancaires SET solde = v_solde + p_montant, updated_at = now()
     WHERE id = v_compte_id;
    v_liquide := v_liquide - p_montant; v_solde := v_solde + p_montant;

  ELSE
    IF v_compte_id IS NULL OR v_solde < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant',
                                'solde', COALESCE(v_solde, 0));
    END IF;
    UPDATE public.comptes_bancaires SET solde = v_solde - p_montant, updated_at = now()
     WHERE id = v_compte_id;
    UPDATE public.personnages_donnees SET liquide = v_liquide + p_montant, updated_at = now()
     WHERE name = p_acteur;
    v_liquide := v_liquide + p_montant; v_solde := v_solde - p_montant;
  END IF;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'montant', p_montant,
    'liquide', v_liquide, 'solde', v_solde, 'arg', v_arg, 'compte', v_compte_id);
END; $function$;

-- compte_bancaire_initial(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.compte_bancaire_initial(p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_arg numeric; v_liquide numeric; v_pays text; v_id text; v_solde numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT COALESCE(arg,0), COALESCE(liquide,0), country
    INTO v_arg, v_liquide, v_pays
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_arg IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_id := 'nationale_' || p_acteur;
  IF EXISTS (SELECT 1 FROM public.comptes_bancaires WHERE id = v_id) THEN
    RETURN jsonb_build_object('ok', true, 'deja_cree', true, 'compte', v_id);
  END IF;

  -- Le solde de depart est la part NON liquide de la fortune reellement enregistree. Il n'est
  -- pas transmis : il se deduit de la ligne du personnage, deja ecrite.
  v_solde := GREATEST(0, v_arg - v_liquide);
  INSERT INTO public.comptes_bancaires (id, personnage, pays, banque, solde, updated_at)
  VALUES (v_id, p_acteur, COALESCE(v_pays,'republic'), 'nationale', v_solde, now())
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'compte', v_id, 'solde', v_solde);
END; $function$;

-- creer_placement_helvetia(text,numeric,text) -> placements_bancaires | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.creer_placement_helvetia(p_personnage text, p_montant numeric, p_type text)
 RETURNS placements_bancaires
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_compte record;
  v_deja_actif int;
  v_placement public.placements_bancaires;
begin
  perform public.exiger_acteur(p_personnage);
  if p_type not in ('declare', 'offshore') then
    raise exception 'Type de placement invalide (declare ou offshore attendu)';
  end if;

  if p_montant is null or p_montant <= 0 then
    raise exception 'Montant invalide';
  end if;

  select * into v_compte
  from public.comptes_bancaires
  where personnage = p_personnage
    and banque = 'helvetia'
  for update;

  if not found then
    raise exception 'Compte Helvetia introuvable';
  end if;

  select count(*) into v_deja_actif
  from public.placements_bancaires
  where personnage = p_personnage
    and banque = 'helvetia'
    and statut = 'actif';

  if v_deja_actif > 0 then
    raise exception 'Un placement Helvetia est deja actif pour ce personnage';
  end if;

  if v_compte.solde - p_montant < 10000 then
    raise exception 'Le compte Helvetia doit conserver au moins 10000 FR apres le placement';
  end if;

  update public.comptes_bancaires
  set solde = solde - p_montant,
      updated_at = now()
  where id = v_compte.id;

  insert into public.placements_bancaires (
    id,
    personnage,
    pays,
    banque,
    type,
    libelle,
    montant,
    visible_fiscalement,
    date_placement,
    prochaine_echeance,
    statut
  )
  values (
    'helvetia-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6),
    p_personnage,
    v_compte.pays,
    'helvetia',
    p_type,
    case
      when p_type = 'declare' then 'Placement Helvetia declare'
      else 'Placement Helvetia offshore'
    end,
    p_montant,
    (p_type = 'declare'),
    now(),
    now() + interval '7 days',
    'actif'
  )
  returning * into v_placement;

  return v_placement;
end;
$function$;

-- creer_placement_national(text,numeric,integer,text) -> placements_bancaires | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.creer_placement_national(p_personnage text, p_montant numeric, p_int_snapshot integer, p_ville text)
 RETURNS placements_bancaires
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_compte comptes_bancaires%ROWTYPE;
  v_pays text;
  v_placement placements_bancaires%ROWTYPE;
  v_id text;
BEGIN
  PERFORM public.exiger_acteur(p_personnage);
  IF p_personnage IS NULL OR btrim(p_personnage) = '' THEN
    RAISE EXCEPTION 'Personnage invalide';
  END IF;

  IF p_montant IS NULL OR p_montant < 500 THEN
    RAISE EXCEPTION 'Montant minimum : 500';
  END IF;

  IF p_ville IS NULL OR btrim(p_ville) = '' THEN
    RAISE EXCEPTION 'Ville invalide';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM placements_bancaires
    WHERE personnage = p_personnage
      AND banque = 'nationale'
      AND type = 'terme'
      AND statut = 'actif'
  ) THEN
    RAISE EXCEPTION 'Un placement Banque nationale est déjà actif';
  END IF;

  SELECT country
  INTO v_pays
  FROM personnages
  WHERE name = p_personnage;

  IF v_pays IS NULL THEN
    RAISE EXCEPTION 'Personnage introuvable';
  END IF;

  -- Verrouillage du compte : deux opérations concurrentes
  -- ne peuvent pas utiliser le même solde.
  SELECT *
  INTO v_compte
  FROM comptes_bancaires
  WHERE personnage = p_personnage
    AND banque = 'nationale'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Compte Banque nationale introuvable';
  END IF;

  IF v_compte.solde < p_montant THEN
    RAISE EXCEPTION 'Solde Banque nationale insuffisant';
  END IF;

  UPDATE comptes_bancaires
  SET
    solde = solde - p_montant,
    updated_at = now()
  WHERE id = v_compte.id;

  v_id :=
    'terme_' ||
    md5(
      p_personnage ||
      clock_timestamp()::text ||
      random()::text
    );

  INSERT INTO placements_bancaires (
    id,
    personnage,
    pays,
    ville,
    banque,
    type,
    libelle,
    montant,
    visible_fiscalement,
    date_placement,
    prochaine_echeance,
    statut,
    int_snapshot
  )
  VALUES (
    v_id,
    p_personnage,
    v_pays,
    p_ville,
    'nationale',
    'terme',
    'Placement Banque nationale',
    p_montant,
    true,
    now(),
    now() + interval '7 days',
    'actif',
    p_int_snapshot
  )
  RETURNING *
  INTO v_placement;

  -- arg reste volontairement inchangé :
  -- compte bancaire -> placement = transfert patrimonial.

  RETURN v_placement;
END;
$function$;

-- creer_pret_helvetia(text,numeric,integer) -> prets | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.creer_pret_helvetia(p_personnage text, p_montant numeric, p_duree_jours integer)
 RETURNS prets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_perso public.personnages%rowtype;
  v_compte public.comptes_bancaires%rowtype;
  v_existant record;
  v_caisse_id text;
  v_montant_du numeric;
  v_mensualite numeric;
  v_pret public.prets%rowtype;
  v_id text;
BEGIN
  PERFORM public.exiger_acteur(p_personnage);
  IF p_montant IS NULL OR p_montant < 1000 OR p_montant > 150000 THEN
    RAISE EXCEPTION 'Montant hors bornes (1000 a 150000)';
  END IF;
  IF p_duree_jours IS NULL OR p_duree_jours < 5 OR p_duree_jours > 30 THEN
    RAISE EXCEPTION 'Duree hors bornes (5 a 30 jours)';
  END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;

  SELECT * INTO v_compte FROM public.comptes_bancaires
    WHERE personnage = p_personnage AND banque = 'helvetia' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Compte Helvetia obligatoire'; END IF;

  SELECT 1 INTO v_existant FROM public.prets
    WHERE emprunteur = p_personnage AND type_banque = 'helvetia' AND statut IN ('en_cours','contentieux')
    FOR UPDATE;
  IF FOUND THEN RAISE EXCEPTION 'Un pret Helvetia est deja actif'; END IF;

  v_caisse_id := v_perso.country || '_banque-privee';
  IF NOT public.helvetia_assurer_liquidite(v_perso.country, p_montant, 'pret_client') THEN
    RAISE EXCEPTION 'Helvetia ne peut pas financer ce pret actuellement';
  END IF;

  UPDATE public.caisses_batiments
    SET data = jsonb_set(data, '{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0) - p_montant)), updated_at = now()
    WHERE id = v_caisse_id;

  v_montant_du := ROUND(p_montant * 1.12);
  v_mensualite := ROUND(v_montant_du / p_duree_jours);
  v_id := 'pret-helvetia-' || p_personnage || '-' || extract(epoch from clock_timestamp())::bigint;

  INSERT INTO public.prets (id, emprunteur, country, building_id, type_banque, type_pret,
      montant_initial, montant_restant, duree_jours, mensualite, jours_impayes, statut)
    VALUES (v_id, p_personnage, v_perso.country, NULL, 'helvetia', 'sans_verification',
      p_montant, v_montant_du, p_duree_jours, v_mensualite, 0, 'en_cours')
    RETURNING * INTO v_pret;

  UPDATE public.comptes_bancaires SET solde = solde + p_montant, updated_at = now()
    WHERE personnage = p_personnage AND banque = 'helvetia';

  UPDATE public.personnages SET arg = COALESCE(arg,0) + p_montant WHERE name = p_personnage;

  RETURN v_pret;
END;
$function$;

-- deposer_helvetia(text,numeric) -> comptes_bancaires | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.deposer_helvetia(p_personnage text, p_montant numeric)
 RETURNS comptes_bancaires
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_perso record;
  v_compte_national public.comptes_bancaires%rowtype;
  v_national_existe boolean;
  v_compte_helvetia record;
  v_liquide numeric;
  v_solde_national numeric;
  v_disponible numeric;
  v_preleve_liquide numeric;
  v_preleve_national numeric;
begin
  perform public.exiger_acteur(p_personnage);
  if p_montant is null or p_montant <= 0 then
    raise exception 'Montant invalide';
  end if;

  select * into v_perso from public.personnages where name = p_personnage for update;
  if not found then
    raise exception 'Personnage introuvable';
  end if;

  select * into v_compte_helvetia from public.comptes_bancaires
  where personnage = p_personnage and banque = 'helvetia' for update;
  if not found then
    raise exception 'Compte Helvetia introuvable';
  end if;

  select * into v_compte_national from public.comptes_bancaires
  where personnage = p_personnage and banque = 'nationale'
  for update;
  v_national_existe := found;

  v_liquide := coalesce(v_perso.liquide, 0);
  v_solde_national := coalesce(v_compte_national.solde, 0);
  v_disponible := v_liquide + v_solde_national;

  if v_disponible < p_montant then
    raise exception 'Fonds ordinaires insuffisants';
  end if;

  v_preleve_liquide := least(v_liquide, p_montant);
  v_preleve_national := p_montant - v_preleve_liquide;

  update public.personnages
  set liquide = v_liquide - v_preleve_liquide
  where name = p_personnage;

  if v_preleve_national > 0 then
    if not v_national_existe then
      raise exception 'Compte Banque nationale introuvable alors qu''un complement y est requis -- etat incoherent';
    end if;

    update public.comptes_bancaires
    set solde = solde - v_preleve_national,
        updated_at = now()
    where id = v_compte_national.id;
  end if;

  update public.comptes_bancaires
  set solde = solde + p_montant,
      updated_at = now()
  where id = v_compte_helvetia.id
  returning * into v_compte_helvetia;

  return v_compte_helvetia;
end;
$function$;

-- deposer_helvetia(text,numeric,text) -> comptes_bancaires | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.deposer_helvetia(p_personnage text, p_montant numeric, p_source_type text)
 RETURNS comptes_bancaires
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_perso public.personnages%rowtype;
  v_compte public.comptes_bancaires%rowtype;
  v_caisse_id text;
BEGIN
  PERFORM public.exiger_acteur(p_personnage);
  IF p_montant IS NULL OR p_montant <= 0 THEN RAISE EXCEPTION 'Montant invalide'; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;

  SELECT * INTO v_compte FROM public.comptes_bancaires
    WHERE personnage = p_personnage AND banque = 'helvetia' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Compte Helvetia inexistant'; END IF;

  IF NOT public.helvetia_debiter_source(p_personnage, p_montant, p_source_type) THEN
    RAISE EXCEPTION 'Fonds insuffisants sur la source choisie';
  END IF;

  UPDATE public.comptes_bancaires SET solde = solde + p_montant, updated_at = now()
    WHERE personnage = p_personnage AND banque = 'helvetia'
    RETURNING * INTO v_compte;

  v_caisse_id := v_perso.country || '_banque-privee';
  UPDATE public.caisses_batiments
    SET data = jsonb_set(data, '{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0) + p_montant)),
        updated_at = now()
    WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', p_montant), now());
  END IF;

  RETURN v_compte;
END;
$function$;

-- fermer_compte_helvetia(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fermer_compte_helvetia(p_personnage text, p_destination_type text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_perso public.personnages%rowtype;
  v_compte public.comptes_bancaires%rowtype;
  v_placements numeric := 0;
  v_placement_row record;
  v_pret public.prets%rowtype;
  v_pret_existe boolean;
  v_dette numeric := 0;
  v_disponible numeric;
  v_applique_a_la_dette numeric;
  v_restitution numeric;
  v_net numeric;
  v_caisse_id text;
BEGIN
  PERFORM public.exiger_acteur(p_personnage);
  SELECT * INTO v_perso FROM public.personnages WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;

  SELECT * INTO v_compte FROM public.comptes_bancaires
    WHERE personnage = p_personnage AND banque = 'helvetia' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Compte Helvetia inexistant'; END IF;

  v_placements := 0;
  FOR v_placement_row IN
    SELECT id, montant FROM public.placements_bancaires
    WHERE personnage = p_personnage AND banque = 'helvetia' AND statut = 'actif'
    FOR UPDATE
  LOOP
    v_placements := v_placements + v_placement_row.montant;
  END LOOP;

  SELECT * INTO v_pret FROM public.prets
    WHERE emprunteur = p_personnage AND type_banque = 'helvetia' AND statut IN ('en_cours','contentieux')
    FOR UPDATE;
  v_pret_existe := FOUND;
  IF v_pret_existe THEN v_dette := v_pret.montant_restant; END IF;

  v_disponible := v_compte.solde + v_placements;
  v_net := v_disponible - v_dette;
  v_applique_a_la_dette := LEAST(v_disponible, v_dette);
  v_restitution := GREATEST(0, v_disponible - v_dette);
  v_caisse_id := v_perso.country || '_banque-privee';

  IF v_restitution > 0 THEN
    IF NOT public.helvetia_assurer_liquidite(v_perso.country, v_restitution, 'fermeture_compte') THEN
      RAISE EXCEPTION 'Helvetia ne peut pas honorer la restitution de fermeture actuellement';
    END IF;
  END IF;

  IF v_placements > 0 THEN
    UPDATE public.placements_bancaires SET statut = 'resolu', date_resolution = now(), montant_final = montant
      WHERE personnage = p_personnage AND banque = 'helvetia' AND statut = 'actif';
  END IF;

  UPDATE public.comptes_bancaires SET solde = 0, updated_at = now()
    WHERE personnage = p_personnage AND banque = 'helvetia';

  UPDATE public.caisses_batiments
    SET data = jsonb_set(data, '{solde}',
        to_jsonb(GREATEST(0, COALESCE((data->>'solde')::numeric,0) + v_applique_a_la_dette - v_restitution))),
        updated_at = now()
    WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data, updated_at)
    VALUES (v_caisse_id, jsonb_build_object('solde', GREATEST(0, v_applique_a_la_dette - v_restitution)), now());
  END IF;

  IF v_pret_existe THEN
    IF v_applique_a_la_dette >= v_dette THEN
      UPDATE public.prets SET montant_restant = 0, statut = 'rembourse' WHERE id = v_pret.id;
    ELSE
      UPDATE public.prets
        SET montant_restant = v_dette - v_applique_a_la_dette, statut = 'contentieux'
        WHERE id = v_pret.id;
    END IF;
  END IF;

  IF v_restitution > 0 THEN
    PERFORM public.helvetia_crediter_destination(p_personnage, v_restitution, p_destination_type);
  END IF;

  IF v_applique_a_la_dette > 0 THEN
    UPDATE public.personnages SET arg = GREATEST(0, COALESCE(arg,0) - v_applique_a_la_dette) WHERE name = p_personnage;
  END IF;

  RETURN jsonb_build_object('net', v_net, 'applique_a_la_dette', v_applique_a_la_dette,
    'restitution', v_restitution, 'dette_restante', GREATEST(0, v_dette - v_applique_a_la_dette));
END;
$function$;

-- finaliser_achat_bien_helvetia(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.finaliser_achat_bien_helvetia(p_personnage text, p_terrain_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_terrain record;
  v_data jsonb;
  v_bien public.biens_saisis_helvetia%rowtype;
  v_acompte numeric;
  v_solde numeric;
  v_caisse_id text;
  v_reste_debiteur numeric;
  v_excedent numeric;
  v_pret public.prets%rowtype;
BEGIN
  PERFORM public.exiger_acteur(p_personnage);
  SELECT id, data, country INTO v_terrain FROM public.terrains_etat WHERE id = p_terrain_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bien introuvable'; END IF;
  v_data := v_terrain.data::jsonb;

  SELECT * INTO v_bien FROM public.biens_saisis_helvetia
    WHERE terrain_id = p_terrain_id AND statut = 'en_vente' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ce bien n''est plus propose a la vente'; END IF;

  IF (v_data->>'proprietaire') <> 'Helvetia' THEN
    RAISE EXCEPTION 'Ce bien n''appartient plus a Helvetia';
  END IF;
  IF (v_data->>'compromis')::boolean IS NOT TRUE OR (v_data->>'compromisPar') <> p_personnage THEN
    RAISE EXCEPTION 'Aucun compromis actif de ce personnage sur ce bien';
  END IF;
  IF ((v_data->>'compromisExpireAt')::bigint) <= (extract(epoch from now())*1000)::bigint THEN
    RAISE EXCEPTION 'Ce compromis a expire';
  END IF;

  v_acompte := COALESCE((v_data->>'acompte')::numeric, 0);
  v_solde := v_bien.prix_notaire - v_acompte;

  IF v_solde > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(p_personnage, v_solde) THEN
      RAISE EXCEPTION 'Fonds insuffisants pour le solde';
    END IF;
  END IF;

  v_caisse_id := v_terrain.country || '_banque-privee';
  UPDATE public.caisses_batiments
    SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_bien.prix_notaire)), updated_at = now()
    WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_bien.prix_notaire), now());
  END IF;

  v_data := v_data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt' - 'compromisExpireAt' - 'pretDemande';
  v_data := v_data || jsonb_build_object('proprietaire', p_personnage, 'coproprietaire', NULL);
  UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_terrain_id;

  UPDATE public.biens_saisis_helvetia
    SET prix_vente_reel = v_bien.prix_notaire, statut = 'vendu', date_vente = now()
    WHERE id = v_bien.id;

  IF v_bien.coproprietaire IS NOT NULL THEN
    INSERT INTO public.obligations_helvetia (id, country, beneficiaire, montant_du, motif, bien_id, pret_id, destination_type)
      VALUES ('obl-coprop-'||v_bien.id, v_bien.country, v_bien.coproprietaire, v_bien.quote_part_coproprietaire,
              'quote_part_coproprietaire', v_bien.id, v_bien.pret_id, 'liquide');

    INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
      VALUES (v_bien.coproprietaire, 'Banque Privée Helvetia', 'Revente de votre bien en copropriété',
        'Le bien a été revendu. Votre quote-part protégée (' || v_bien.quote_part_coproprietaire || ') vous sera réglée dès que possible.',
        now()::text, false, false);

    v_reste_debiteur := GREATEST(0, v_bien.prix_notaire - v_bien.quote_part_coproprietaire);

    SELECT * INTO v_pret FROM public.prets WHERE id = v_bien.pret_id FOR UPDATE;
    IF FOUND AND v_pret.statut IN ('en_cours','contentieux') THEN
      IF v_reste_debiteur >= v_pret.montant_restant THEN
        v_excedent := v_reste_debiteur - v_pret.montant_restant;
        UPDATE public.prets SET montant_restant = 0, statut = 'rembourse' WHERE id = v_pret.id;
        IF v_excedent > 0 THEN
          INSERT INTO public.obligations_helvetia (id, country, beneficiaire, montant_du, motif, bien_id, pret_id, destination_type)
            VALUES ('obl-surplus-'||v_bien.id, v_bien.country, v_pret.emprunteur, ROUND(v_excedent*0.90),
                    'surplus_saisie', v_bien.id, v_pret.id, 'liquide');
        END IF;
      ELSE
        UPDATE public.prets SET montant_restant = montant_restant - v_reste_debiteur WHERE id = v_pret.id;
      END IF;
      INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
        VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Revente de votre bien en copropriété',
          'Le bien a été revendu. Après règlement de la quote-part de votre copropriétaire, ' || v_reste_debiteur ||
          ' ont été appliqués à votre dette.', now()::text, false, false);
    END IF;
  END IF;

  RETURN jsonb_build_object('terrain_id', p_terrain_id, 'prix', v_bien.prix_notaire, 'acheteur', p_personnage);
END;
$function$;

-- helvetia_assurer_liquidite(text,numeric,text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.helvetia_assurer_liquidite(p_pays text, p_montant_necessaire numeric, p_motif text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caisse_id text := p_pays || '_banque-privee';
  v_solde numeric;
  v_manque numeric;
  v_encours numeric;
  v_dispo_normal numeric;
  v_tranche1 numeric := 0;
  v_tranche2 numeric := 0;
  v_taux_normal numeric;
  v_encours_apres1 numeric;
  v_dispo_douteux numeric;
BEGIN
  SELECT COALESCE((data->>'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments WHERE id = v_caisse_id FOR UPDATE;
  IF NOT FOUND THEN v_solde := 0; END IF;

  IF v_solde >= p_montant_necessaire THEN RETURN true; END IF;

  v_manque := p_montant_necessaire - v_solde;

  SELECT COALESCE(SUM(montant), 0) INTO v_encours
    FROM public.bnr_refinancements_helvetia WHERE country = p_pays AND statut = 'actif';

  v_dispo_normal := GREATEST(0, 3000000 - v_encours);
  v_tranche1 := LEAST(v_manque, v_dispo_normal);
  v_encours_apres1 := v_encours + v_tranche1;
  v_dispo_douteux := GREATEST(0, 4000000 - v_encours_apres1);
  v_tranche2 := LEAST(v_manque - v_tranche1, v_dispo_douteux);

  IF (v_tranche1 + v_tranche2) < v_manque THEN RETURN false; END IF;

  v_taux_normal := public.helvetia_taux_refinancement_bnr(p_pays);

  IF v_tranche1 > 0 THEN
    INSERT INTO public.bnr_refinancements_helvetia (id, country, motif, montant, taux_courant, jour_echeance)
    VALUES ('bnr-' || p_pays || '-' || extract(epoch from clock_timestamp())::bigint || '-a',
            p_pays, p_motif, v_tranche1, v_taux_normal, now() + interval '7 days');
  END IF;
  IF v_tranche2 > 0 THEN
    INSERT INTO public.bnr_refinancements_helvetia (id, country, motif, montant, taux_courant, jour_echeance)
    VALUES ('bnr-' || p_pays || '-' || extract(epoch from clock_timestamp())::bigint || '-b',
            p_pays, p_motif, v_tranche2, v_taux_normal + 1.5, now() + interval '7 days');
  END IF;

  UPDATE public.caisses_batiments
    SET data = jsonb_set(data, '{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0) + v_tranche1 + v_tranche2)),
        updated_at = now()
    WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data, updated_at)
    VALUES (v_caisse_id, jsonb_build_object('solde', v_tranche1 + v_tranche2), now());
  END IF;

  RETURN true;
END;
$function$;

-- helvetia_crediter_destination(text,numeric,text) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.helvetia_crediter_destination(p_personnage text, p_montant numeric, p_destination_type text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_destination_type = 'liquide' THEN
    UPDATE public.personnages SET liquide = COALESCE(liquide,0) + p_montant WHERE name = p_personnage;
  ELSIF p_destination_type = 'national' THEN
    UPDATE public.comptes_bancaires SET solde = solde + p_montant, updated_at = now()
      WHERE personnage = p_personnage AND banque = 'nationale';
    IF NOT FOUND THEN RAISE EXCEPTION 'Compte national inexistant'; END IF;
  ELSE
    RAISE EXCEPTION 'Destination non supportee: %', p_destination_type;
  END IF;
END;
$function$;

-- helvetia_debiter_fonds_ordinaires(text,numeric) -> boolean | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.helvetia_debiter_fonds_ordinaires(p_personnage text, p_montant numeric)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_liquide numeric; v_arg numeric; v_solde numeric;
  v_preleve_liquide numeric; v_preleve_national numeric;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 THEN RETURN true; END IF;

  SELECT COALESCE(liquide,0), COALESCE(arg,0) INTO v_liquide, v_arg
    FROM public.personnages_donnees WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;

  SELECT COALESCE(solde,0) INTO v_solde FROM public.comptes_bancaires
   WHERE personnage = p_personnage AND banque = 'nationale' FOR UPDATE;

  IF (v_liquide + COALESCE(v_solde,0)) < p_montant THEN RETURN false; END IF;

  v_preleve_liquide  := LEAST(v_liquide, p_montant);
  v_preleve_national := p_montant - v_preleve_liquide;

  UPDATE public.personnages_donnees
     SET liquide = v_liquide - v_preleve_liquide,
         arg = GREATEST(0, v_arg - p_montant),
         updated_at = now()
   WHERE name = p_personnage;

  IF v_preleve_national > 0 THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_preleve_national, updated_at = now()
     WHERE personnage = p_personnage AND banque = 'nationale';
  END IF;

  RETURN true;
END; $function$;

-- helvetia_debiter_source(text,numeric,text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.helvetia_debiter_source(p_personnage text, p_montant numeric, p_source_type text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_perso public.personnages%rowtype;
  v_compte public.comptes_bancaires%rowtype;
BEGIN
  SELECT * INTO v_perso FROM public.personnages WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;

  IF p_source_type = 'liquide' THEN
    IF COALESCE(v_perso.liquide,0) < p_montant THEN RETURN false; END IF;
    UPDATE public.personnages SET liquide = liquide - p_montant WHERE name = p_personnage;
    RETURN true;
  ELSIF p_source_type = 'national' THEN
    SELECT * INTO v_compte FROM public.comptes_bancaires
      WHERE personnage = p_personnage AND banque = 'nationale' FOR UPDATE;
    IF NOT FOUND OR v_compte.solde < p_montant THEN RETURN false; END IF;
    UPDATE public.comptes_bancaires SET solde = solde - p_montant, updated_at = now()
      WHERE personnage = p_personnage AND banque = 'nationale';
    RETURN true;
  ELSE
    RAISE EXCEPTION 'Source non supportee: %', p_source_type;
  END IF;
END;
$function$;

-- helvetia_ie_national(text) -> numeric | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.helvetia_ie_national(p_pays text)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_villes text[] := ARRAY['capitale','ville_a','ville_b'];
  v_ville text;
  v_data jsonb;
  v_somme numeric := 0;
BEGIN
  FOREACH v_ville IN ARRAY v_villes LOOP
    SELECT data INTO v_data FROM public.indices_villes WHERE id = p_pays || '_' || v_ville;
    v_somme := v_somme + COALESCE((v_data->>'ie')::numeric, 50);
  END LOOP;
  RETURN ROUND(v_somme / array_length(v_villes,1));
END;
$function$;

-- helvetia_inventaire_sortie(jsonb,jsonb,integer,jsonb,integer) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.helvetia_inventaire_sortie(p_inv jsonb, p_quete jsonb, p_index integer, p_signature jsonb, p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pos integer; v_item jsonb; v_cle text; v_detenu numeric; v_nouveau jsonb; v_sorti jsonb;
BEGIN
  IF p_qte IS NULL OR p_qte <= 0 OR p_qte > 1000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  v_pos := public.inventaire_localiser(p_inv, p_index, p_signature);
  IF v_pos < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent');
  END IF;
  v_item := p_inv -> v_pos;

  IF public.inventaire_objet_protege(p_quete, v_item) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_protege');
  END IF;

  v_cle := v_item->>'stackKey';
  IF coalesce((v_item->>'stackable')::boolean, false) AND v_cle IS NOT NULL THEN
    -- Objet empilable : la quantite totale detenue fait foi, jamais la ligne. Verifiee AVANT
    -- le retrait : inventaire_retirer() seule laisserait passer une demande superieure au
    -- stock en supprimant la ligne devenue negative -- un retrait silencieusement partiel,
    -- que l'appelant croirait complet.
    v_detenu := public.inventaire_quantite(p_inv, v_cle);
    IF v_detenu < p_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quantite_insuffisante', 'detenu', v_detenu);
    END IF;
    v_nouveau := public.inventaire_retirer(p_inv, v_cle, p_qte);
    v_sorti := v_item || jsonb_build_object('qty', p_qte);
  ELSE
    -- Objet unique : un exemplaire, jamais plus. Demander 2 exemplaires d'un objet qui n'en a
    -- qu'un est un refus, pas un retrait de ce qui existe.
    IF p_qte <> 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quantite_insuffisante', 'detenu', 1);
    END IF;
    v_nouveau := public.inventaire_retirer_position(p_inv, v_pos);
    v_sorti := v_item;
  END IF;

  RETURN jsonb_build_object('ok', true, 'inventory', v_nouveau, 'objet', v_sorti, 'position', v_pos);
END; $function$;

-- helvetia_taux_refinancement_bnr(text) -> numeric | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.helvetia_taux_refinancement_bnr(p_pays text)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN 5 - ((public.helvetia_ie_national(p_pays) - 50) * 0.10);
END;
$function$;

-- ouvrir_compte_helvetia(text) -> comptes_bancaires | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ouvrir_compte_helvetia(p_personnage text)
 RETURNS comptes_bancaires
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_perso record;
  v_compte_national public.comptes_bancaires%rowtype;
  v_national_existe boolean;
  v_liquide numeric;
  v_solde_national numeric;
  v_disponible numeric;
  v_preleve_liquide numeric;
  v_preleve_national numeric;
  v_nouveau_compte public.comptes_bancaires;
begin
  perform public.exiger_acteur(p_personnage);
  select * into v_perso
  from public.personnages
  where name = p_personnage
  for update;

  if not found then
    raise exception 'Personnage introuvable';
  end if;

  if exists (
    select 1
    from public.comptes_bancaires
    where personnage = p_personnage
      and banque = 'helvetia'
  ) then
    raise exception 'Un compte Helvetia existe deja pour ce personnage';
  end if;

  select * into v_compte_national
  from public.comptes_bancaires
  where personnage = p_personnage
    and banque = 'nationale'
  for update;

  v_national_existe := found;

  v_liquide := coalesce(v_perso.liquide, 0);
  v_solde_national := coalesce(v_compte_national.solde, 0);
  v_disponible := v_liquide + v_solde_national;

  if v_disponible < 10000 then
    raise exception 'Fonds ordinaires insuffisants (10000 FR requis pour ouvrir un compte Helvetia)';
  end if;

  v_preleve_liquide := least(v_liquide, 10000);
  v_preleve_national := 10000 - v_preleve_liquide;

  update public.personnages
  set liquide = v_liquide - v_preleve_liquide
  where name = p_personnage;

  if v_preleve_national > 0 then
    if not v_national_existe then
      raise exception 'Compte Banque nationale introuvable alors qu''un complement y est requis -- etat incoherent';
    end if;

    update public.comptes_bancaires
    set solde = solde - v_preleve_national,
        updated_at = now()
    where id = v_compte_national.id;
  end if;

  insert into public.comptes_bancaires (
    id,
    personnage,
    pays,
    banque,
    solde,
    ouvert_le,
    updated_at
  )
  values (
    'helvetia:' || p_personnage,
    p_personnage,
    v_perso.country,
    'helvetia',
    10000,
    now(),
    now()
  )
  returning * into v_nouveau_compte;

  return v_nouveau_compte;
end;
$function$;

-- regler_creances_helvetia_quotidien(text) -> TABLE(creance_id text, type_creance text, action text) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.regler_creances_helvetia_quotidien(p_pays text)
 RETURNS TABLE(creance_id text, type_creance text, action text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caisse_id text := p_pays || '_banque-privee';
  v_caisse numeric;
  v_item record;
BEGIN
  SELECT COALESCE((data->>'solde')::numeric, 0) INTO v_caisse
    FROM public.caisses_batiments WHERE id = v_caisse_id FOR UPDATE;
  IF NOT FOUND THEN v_caisse := 0; END IF;

  FOR v_item IN
    SELECT id, 'obligation'::text AS type, created_at AS exigible_depuis
      FROM public.obligations_helvetia WHERE country = p_pays AND statut = 'due'
    UNION ALL
    SELECT id, 'bnr'::text AS type, jour_echeance AS exigible_depuis
      FROM public.bnr_refinancements_helvetia WHERE country = p_pays AND statut = 'actif' AND jour_echeance <= now()
    ORDER BY exigible_depuis ASC
  LOOP
    IF v_item.type = 'obligation' THEN
      DECLARE
        v_obl public.obligations_helvetia%rowtype;
        v_paye numeric;
      BEGIN
        SELECT * INTO v_obl FROM public.obligations_helvetia WHERE id = v_item.id FOR UPDATE;
        IF NOT FOUND OR v_obl.statut <> 'due' THEN CONTINUE; END IF;

        v_paye := LEAST(v_caisse, v_obl.montant_du);
        IF v_paye <= 0 THEN CONTINUE; END IF;

        v_caisse := v_caisse - v_paye;
        PERFORM public.helvetia_crediter_destination(v_obl.beneficiaire, v_paye, v_obl.destination_type);
        UPDATE public.personnages SET arg = COALESCE(arg,0) + v_paye WHERE name = v_obl.beneficiaire;

        IF v_paye >= v_obl.montant_du THEN
          UPDATE public.obligations_helvetia SET statut = 'soldee', montant_du = 0, updated_at = now() WHERE id = v_obl.id;
          creance_id := v_obl.id; type_creance := 'obligation'; action := 'soldee'; RETURN NEXT;
        ELSE
          UPDATE public.obligations_helvetia SET montant_du = montant_du - v_paye, updated_at = now() WHERE id = v_obl.id;
          creance_id := v_obl.id; type_creance := 'obligation'; action := 'paiement_partiel'; RETURN NEXT;
        END IF;
      END;
    ELSE
      DECLARE
        v_bnr public.bnr_refinancements_helvetia%rowtype;
        v_total_du numeric;
      BEGIN
        SELECT * INTO v_bnr FROM public.bnr_refinancements_helvetia WHERE id = v_item.id FOR UPDATE;
        IF NOT FOUND OR v_bnr.statut <> 'actif' THEN CONTINUE; END IF;

        v_total_du := v_bnr.montant + v_bnr.interets_cumules + ROUND(v_bnr.montant * v_bnr.taux_courant / 100);

        IF v_caisse >= v_total_du THEN
          v_caisse := v_caisse - v_total_du;
          UPDATE public.bnr_refinancements_helvetia SET statut = 'rembourse', updated_at = now() WHERE id = v_bnr.id;
          creance_id := v_bnr.id; type_creance := 'bnr'; action := 'remboursee'; RETURN NEXT;
        ELSE
          UPDATE public.bnr_refinancements_helvetia
            SET interets_cumules = interets_cumules + ROUND(montant * taux_courant / 100),
                taux_courant = taux_courant + 1,
                nb_tranches = nb_tranches + 1,
                jour_echeance = jour_echeance + interval '7 days',
                updated_at = now()
            WHERE id = v_bnr.id;
          creance_id := v_bnr.id; type_creance := 'bnr'; action := 'prorogee'; RETURN NEXT;
        END IF;
      END;
    END IF;
  END LOOP;

  UPDATE public.caisses_batiments
    SET data = jsonb_set(data, '{solde}', to_jsonb(v_caisse)), updated_at = now()
    WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_caisse), now());
  END IF;

  RETURN;
END;
$function$;

-- rembourser_pret_helvetia_integral(text,text,jsonb) -> prets | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.rembourser_pret_helvetia_integral(p_personnage text, p_pret_id text, p_sources jsonb)
 RETURNS prets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pret public.prets%rowtype;
  v_perso public.personnages%rowtype;
  v_compte_national public.comptes_bancaires%rowtype;
  v_compte_helvetia public.comptes_bancaires%rowtype;
  v_source jsonb;
  v_type text;
  v_montant numeric;
  v_total numeric := 0;
  v_liquide_requis numeric := 0;
  v_national_requis numeric := 0;
  v_helvetia_requis numeric := 0;
  v_helvetia_disponible numeric;
  v_caisse_id text;
BEGIN
  PERFORM public.exiger_acteur(p_personnage);
  SELECT * INTO v_pret FROM public.prets WHERE id = p_pret_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pret introuvable'; END IF;
  IF v_pret.emprunteur <> p_personnage THEN RAISE EXCEPTION 'Ce pret n''appartient pas a ce personnage'; END IF;
  IF v_pret.type_banque <> 'helvetia' THEN RAISE EXCEPTION 'Pas un pret Helvetia'; END IF;
  IF v_pret.statut NOT IN ('en_cours','contentieux') THEN RAISE EXCEPTION 'Pret deja solde ou clos'; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;
  SELECT * INTO v_compte_national FROM public.comptes_bancaires
    WHERE personnage = p_personnage AND banque = 'nationale' FOR UPDATE;
  SELECT * INTO v_compte_helvetia FROM public.comptes_bancaires
    WHERE personnage = p_personnage AND banque = 'helvetia' FOR UPDATE;

  FOR v_source IN SELECT * FROM jsonb_array_elements(p_sources) LOOP
    v_type := v_source->>'type';
    v_montant := (v_source->>'montant')::numeric;
    IF v_montant IS NULL OR v_montant <= 0 THEN RAISE EXCEPTION 'Montant de source invalide'; END IF;
    v_total := v_total + v_montant;
    IF v_type = 'liquide' THEN
      v_liquide_requis := v_liquide_requis + v_montant;
    ELSIF v_type = 'national' THEN
      v_national_requis := v_national_requis + v_montant;
    ELSIF v_type = 'helvetia' THEN
      v_helvetia_requis := v_helvetia_requis + v_montant;
    ELSE
      RAISE EXCEPTION 'Source non supportee pour ce remboursement: %', v_type;
    END IF;
  END LOOP;

  IF v_total <> v_pret.montant_restant THEN
    RAISE EXCEPTION 'La somme des sources (%) doit egaler exactement le montant restant du (%)', v_total, v_pret.montant_restant;
  END IF;

  IF v_liquide_requis > COALESCE(v_perso.liquide,0) THEN
    RAISE EXCEPTION 'Liquide insuffisant pour la source demandee';
  END IF;
  IF v_national_requis > 0 AND (v_compte_national.solde IS NULL OR v_national_requis > v_compte_national.solde) THEN
    RAISE EXCEPTION 'Solde du compte national insuffisant pour la source demandee';
  END IF;
  IF v_helvetia_requis > 0 THEN
    IF v_compte_helvetia.solde IS NULL THEN RAISE EXCEPTION 'Compte Helvetia inexistant'; END IF;
    v_helvetia_disponible := GREATEST(0, v_compte_helvetia.solde - 10000);
    IF v_helvetia_requis > v_helvetia_disponible THEN
      RAISE EXCEPTION 'Le compte Helvetia ne peut fournir que % sans passer sous le plancher de 10000 -- utiliser fermer_compte_helvetia', v_helvetia_disponible;
    END IF;
  END IF;

  IF v_liquide_requis > 0 THEN
    UPDATE public.personnages SET liquide = liquide - v_liquide_requis WHERE name = p_personnage;
  END IF;
  IF v_national_requis > 0 THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_national_requis, updated_at = now()
      WHERE personnage = p_personnage AND banque = 'nationale';
  END IF;
  IF v_helvetia_requis > 0 THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_helvetia_requis, updated_at = now()
      WHERE personnage = p_personnage AND banque = 'helvetia';
  END IF;

  v_caisse_id := v_pret.country || '_banque-privee';
  UPDATE public.caisses_batiments
    SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_total)), updated_at = now()
    WHERE id = v_caisse_id;
  IF NOT FOUND THEN
    INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_total), now());
  END IF;

  UPDATE public.personnages SET arg = GREATEST(0, COALESCE(arg,0) - v_total) WHERE name = p_personnage;

  UPDATE public.prets SET montant_restant = 0, statut = 'rembourse' WHERE id = p_pret_id RETURNING * INTO v_pret;
  RETURN v_pret;
END;
$function$;

-- resoudre_compromis_helvetia_expire(text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.resoudre_compromis_helvetia_expire(p_terrain_id text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_terrain record;
  v_data jsonb;
  v_expire bigint;
  v_maintenant bigint;
  v_pret_demande jsonb;
  v_refus boolean := false;
  v_acompte numeric;
  v_compromis_par text;
  v_caisse_id text;
  v_arg_demandeur numeric;
  v_risque boolean;
  v_accorde boolean;
  v_montant numeric;
BEGIN
  SELECT id, data, country, building_id INTO v_terrain FROM public.terrains_etat WHERE id = p_terrain_id FOR UPDATE;
  IF NOT FOUND THEN RETURN 'non_applicable'; END IF;
  v_data := v_terrain.data::jsonb;

  IF (v_data->>'proprietaire') <> 'Helvetia' THEN RETURN 'non_applicable'; END IF;
  IF (v_data->>'compromis')::boolean IS NOT TRUE THEN RETURN 'non_applicable'; END IF;

  v_expire := (v_data->>'compromisExpireAt')::bigint;
  v_maintenant := (extract(epoch from now())*1000)::bigint;
  IF v_expire IS NULL OR v_expire > v_maintenant THEN RETURN 'pas_encore_expire'; END IF;

  v_pret_demande := v_data->'pretDemande';
  IF v_pret_demande IS NOT NULL AND v_pret_demande->>'statut' = 'attente_validation' THEN
    v_montant := (v_pret_demande->>'montant')::numeric;
    SELECT arg INTO v_arg_demandeur FROM public.personnages WHERE name = v_pret_demande->>'demandeur' FOR UPDATE;
    v_risque := COALESCE(v_arg_demandeur,0) < v_montant * 0.10;
    v_accorde := (NOT v_risque) OR (random() < 0.5);

    IF v_accorde THEN
      UPDATE public.personnages SET arg = COALESCE(arg,0) + v_montant WHERE name = v_pret_demande->>'demandeur';
      INSERT INTO public.prets (id, emprunteur, country, building_id, type_banque, type_pret,
          montant_initial, montant_restant, duree_jours, mensualite, jours_impayes, statut)
        VALUES ('pret-' || extract(epoch from clock_timestamp())::bigint, v_pret_demande->>'demandeur',
          v_terrain.country, v_terrain.building_id, 'nationale', 'travaux',
          v_montant, (v_pret_demande->>'montantTotal')::numeric, (v_pret_demande->>'duree')::integer,
          (v_pret_demande->>'mensualite')::numeric, 0, 'en_cours');
      v_data := jsonb_set(v_data, '{pretDemande,statut}', '"accorde"');
      UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_terrain_id;
      RETURN 'pret_accorde_compromis_gele';
    ELSE
      v_data := jsonb_set(v_data, '{pretDemande,statut}', '"refuse"');
      v_refus := true;
    END IF;
  END IF;

  v_acompte := COALESCE((v_data->>'acompte')::numeric, 0);
  v_compromis_par := v_data->>'compromisPar';
  v_caisse_id := v_terrain.country || '_banque-privee';

  IF v_refus THEN
    IF v_compromis_par IS NOT NULL AND v_acompte > 0 THEN
      UPDATE public.personnages SET liquide = COALESCE(liquide,0) + v_acompte,
          arg = COALESCE(arg,0) + v_acompte
        WHERE name = v_compromis_par;
    END IF;
  ELSE
    IF v_acompte > 0 THEN
      UPDATE public.caisses_batiments
        SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_acompte)), updated_at = now()
        WHERE id = v_caisse_id;
      IF NOT FOUND THEN
        INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_acompte), now());
      END IF;
    END IF;
  END IF;

  v_data := v_data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt' - 'compromisExpireAt' - 'pretDemande';
  UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_terrain_id;

  RETURN CASE WHEN v_refus THEN 'rembourse' ELSE 'perdu_acquis_helvetia' END;
END;
$function$;

-- resoudre_placement_helvetia(text) -> placements_bancaires | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.resoudre_placement_helvetia(p_placement_id text)
 RETURNS placements_bancaires
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_placement record;
  v_compte record;
  v_gain_brut numeric;
  v_frais numeric;
  v_revenu_apres_frais numeric;
  v_impot numeric;
  v_gain_net numeric;
  v_montant_final numeric;
  v_caisse_helvetia_id text;
  v_reserve_id text;
begin
  select * into v_placement
  from public.placements_bancaires
  where id = p_placement_id
    and banque = 'helvetia'
    and statut = 'actif'
  for update;

  if not found then
    raise exception 'Placement Helvetia introuvable ou deja resolu';
  end if;

  if v_placement.prochaine_echeance > now() then
    raise exception 'Placement Helvetia pas encore arrive a echeance';
  end if;

  select * into v_compte
  from public.comptes_bancaires
  where personnage = v_placement.personnage
    and banque = 'helvetia'
  for update;

  if not found then
    raise exception 'Compte Helvetia introuvable pour le personnage %', v_placement.personnage;
  end if;

  v_gain_brut := round(v_placement.montant * 0.08);
  v_frais := round(v_gain_brut * 0.30);
  v_revenu_apres_frais := v_gain_brut - v_frais;

  v_impot := case
    when v_placement.type = 'declare'
      then round(v_revenu_apres_frais * 0.50)
    else 0
  end;

  v_gain_net := v_revenu_apres_frais - v_impot;
  v_montant_final := v_placement.montant + v_gain_net;

  v_caisse_helvetia_id :=
    coalesce(v_placement.pays, 'republic') || '_banque-privee';

  update public.caisses_batiments
  set data = jsonb_set(
        data,
        '{solde}',
        to_jsonb(coalesce((data->>'solde')::numeric, 0) + v_frais)
      ),
      updated_at = now()
  where id = v_caisse_helvetia_id;

  if not found then
    insert into public.caisses_batiments (id, data, updated_at)
    values (
      v_caisse_helvetia_id,
      jsonb_build_object('solde', v_frais),
      now()
    );
  end if;

  if v_impot > 0 then
    v_reserve_id := coalesce(v_placement.pays, 'republic');

    update public.budgets_nationaux
    set data = jsonb_set(
          data,
          '{reserveJour}',
          to_jsonb(coalesce((data->>'reserveJour')::numeric, 0) + v_impot)
        ),
        updated_at = now()
    where id = v_reserve_id;

    if not found then
      raise exception
        'budgets_nationaux introuvable pour le pays % -- aucune ligne artificielle creee',
        v_reserve_id;
    end if;
  end if;

  update public.comptes_bancaires
  set solde = solde + v_montant_final,
      updated_at = now()
  where id = v_compte.id;

  update public.personnages
  set arg = coalesce(arg, 0) + v_gain_net
  where name = v_placement.personnage;

  update public.placements_bancaires
  set statut = 'resolu',
      rendement_pct = 8.00,
      montant_final = v_montant_final,
      date_resolution = now()
  where id = v_placement.id
  returning * into v_placement;

  insert into public.mails (
    id,
    to_player,
    from_player,
    subject,
    body,
    time,
    read,
    archived
  )
  values (
    'mail-helvetia-' || extract(epoch from now())::bigint,
    v_placement.personnage,
    'Banque Privée Helvetia',
    'Placement Helvetia arrivé à échéance',
    'Montant placé : ' || v_placement.montant ||
      ' FR. Gain brut (8%) : ' || v_gain_brut ||
      ' FR. Frais Helvetia (30% du gain, prélevés) : -' || v_frais ||
      ' FR. ' ||
      case
        when v_placement.type = 'declare'
          then 'Impôt sur le revenu financier (50%, versé aux finances de Républia) : -' ||
               v_impot || ' FR. '
        else
          'Placement offshore : aucune imposition républienne. '
      end ||
      'Gain net : ' || v_gain_net ||
      ' FR. Montant crédité sur votre compte : ' ||
      v_montant_final || ' FR.',
    now()::text,
    false,
    false
  );

  return v_placement;
end;
$function$;

-- resoudre_placement_national(text,numeric) -> placements_bancaires | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.resoudre_placement_national(p_placement_id text, p_rendement_pct numeric)
 RETURNS placements_bancaires
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_placement placements_bancaires%ROWTYPE;
  v_compte comptes_bancaires%ROWTYPE;
  v_montant_final numeric;
  v_delta numeric;
  v_mail_id text;
  v_signe text;
  v_libelle_gain text;
BEGIN
  SELECT *
  INTO v_placement
  FROM placements_bancaires
  WHERE id = p_placement_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Placement introuvable';
  END IF;

  -- Idempotence : un placement déjà résolu ne peut jamais être recrédité.
  IF v_placement.statut <> 'actif' THEN
    RETURN v_placement;
  END IF;

  IF v_placement.banque <> 'nationale'
     OR v_placement.type <> 'terme' THEN
    RAISE EXCEPTION 'Type de placement invalide';
  END IF;

  IF v_placement.prochaine_echeance IS NULL
     OR v_placement.prochaine_echeance > now() THEN
    RAISE EXCEPTION 'Placement non arrivé à échéance';
  END IF;

  IF p_rendement_pct IS NULL
     OR p_rendement_pct < -12
     OR p_rendement_pct > 12 THEN
    RAISE EXCEPTION 'Rendement hors bornes';
  END IF;

  -- Equivalent de Math.round pour un montant monétaire entier.
  v_montant_final :=
    round(
      v_placement.montant *
      (1 + p_rendement_pct / 100.0)
    );

  v_delta := v_montant_final - v_placement.montant;

  SELECT *
  INTO v_compte
  FROM comptes_bancaires
  WHERE personnage = v_placement.personnage
    AND banque = 'nationale'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Compte Banque nationale introuvable';
  END IF;

  -- Restitution du capital + gain/perte sur le compte bancaire.
  UPDATE comptes_bancaires
  SET
    solde = solde + v_montant_final,
    updated_at = now()
  WHERE id = v_compte.id;

  -- La fortune globale ne varie QUE du résultat net.
  UPDATE personnages
  SET arg = COALESCE(arg, 0) + v_delta
  WHERE name = v_placement.personnage;

  UPDATE placements_bancaires
  SET
    rendement_pct = p_rendement_pct,
    montant_final = v_montant_final,
    date_resolution = now(),
    statut = 'resolu',
    updated_at = now()
  WHERE id = v_placement.id
  RETURNING *
  INTO v_placement;

  -- Notification persistante.
  v_mail_id :=
    'placement_' ||
    md5(
      v_placement.id ||
      clock_timestamp()::text ||
      random()::text
    );

  v_signe :=
    CASE WHEN v_delta >= 0 THEN '+' ELSE '' END;

  v_libelle_gain :=
    CASE
      WHEN v_delta >= 0 THEN 'Gain'
      ELSE 'Perte'
    END;

  INSERT INTO mails (
    id,
    to_player,
    from_player,
    subject,
    body,
    time,
    read,
    archived
  )
  VALUES (
    v_mail_id,
    v_placement.personnage,
    'Banque Nationale',
    'Placement Banque nationale arrivé à échéance',
    'Montant placé : ' ||
      v_placement.montant::text || ' FR. ' ||
    'Rendement : ' ||
      CASE WHEN p_rendement_pct >= 0 THEN '+' ELSE '' END ||
      p_rendement_pct::text || ' %. ' ||
    v_libelle_gain || ' : ' ||
      v_signe || v_delta::text || ' FR. ' ||
    'Montant crédité : ' ||
      v_montant_final::text || ' FR.',
    now(),
    false,
    false
  );

  RETURN v_placement;
END;
$function$;

-- retirer_helvetia(text,numeric) -> comptes_bancaires | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.retirer_helvetia(p_personnage text, p_montant numeric)
 RETURNS comptes_bancaires
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_compte_helvetia record;
begin
  perform public.exiger_acteur(p_personnage);
  if p_montant is null or p_montant <= 0 then
    raise exception 'Montant invalide';
  end if;

  select * into v_compte_helvetia
  from public.comptes_bancaires
  where personnage = p_personnage
    and banque = 'helvetia'
  for update;

  if not found then
    raise exception 'Compte Helvetia introuvable';
  end if;

  if v_compte_helvetia.solde - p_montant < 10000 then
    raise exception 'Le compte Helvetia doit conserver au moins 10000 FR';
  end if;

  update public.comptes_bancaires
  set solde = solde - p_montant,
      updated_at = now()
  where id = v_compte_helvetia.id
  returning * into v_compte_helvetia;

  update public.personnages
  set liquide = coalesce(liquide, 0) + p_montant
  where name = p_personnage;

  return v_compte_helvetia;
end;
$function$;

-- retirer_helvetia(text,numeric,text) -> comptes_bancaires | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.retirer_helvetia(p_personnage text, p_montant numeric, p_destination_type text)
 RETURNS comptes_bancaires
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_perso public.personnages%rowtype;
  v_compte public.comptes_bancaires%rowtype;
  v_caisse_id text;
BEGIN
  PERFORM public.exiger_acteur(p_personnage);
  IF p_montant IS NULL OR p_montant <= 0 THEN RAISE EXCEPTION 'Montant invalide'; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_personnage FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable'; END IF;

  SELECT * INTO v_compte FROM public.comptes_bancaires
    WHERE personnage = p_personnage AND banque = 'helvetia' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Compte Helvetia inexistant'; END IF;

  IF (v_compte.solde - p_montant) < 10000 THEN
    RAISE EXCEPTION 'Ce retrait entrainerait une fermeture de compte -- utiliser fermer_compte_helvetia';
  END IF;

  v_caisse_id := v_perso.country || '_banque-privee';
  IF NOT public.helvetia_assurer_liquidite(v_perso.country, p_montant, 'retrait_client') THEN
    RAISE EXCEPTION 'Helvetia ne peut pas honorer ce retrait actuellement';
  END IF;

  UPDATE public.caisses_batiments
    SET data = jsonb_set(data, '{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0) - p_montant)), updated_at = now()
    WHERE id = v_caisse_id;

  UPDATE public.comptes_bancaires SET solde = solde - p_montant, updated_at = now()
    WHERE personnage = p_personnage AND banque = 'helvetia'
    RETURNING * INTO v_compte;

  PERFORM public.helvetia_crediter_destination(p_personnage, p_montant, p_destination_type);

  RETURN v_compte;
END;
$function$;

-- signer_compromis_bien_helvetia(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.signer_compromis_bien_helvetia(p_personnage text, p_terrain_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_terrain record;
  v_data jsonb;
  v_bien public.biens_saisis_helvetia%rowtype;
  v_acompte numeric := 1000;
BEGIN
  PERFORM public.exiger_acteur(p_personnage);
  SELECT id, data INTO v_terrain FROM public.terrains_etat WHERE id = p_terrain_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bien introuvable'; END IF;
  v_data := v_terrain.data::jsonb;

  IF (v_data->>'proprietaire') <> 'Helvetia' THEN
    RAISE EXCEPTION 'Ce bien n''appartient pas a Helvetia';
  END IF;
  IF (v_data->>'compromis')::boolean IS TRUE THEN
    RAISE EXCEPTION 'Ce bien est deja sous compromis';
  END IF;

  SELECT * INTO v_bien FROM public.biens_saisis_helvetia
    WHERE terrain_id = p_terrain_id AND statut = 'en_vente' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ce bien n''est pas propose a la vente'; END IF;

  IF NOT public.helvetia_debiter_fonds_ordinaires(p_personnage, v_acompte) THEN
    RAISE EXCEPTION 'Fonds insuffisants pour l''acompte';
  END IF;

  v_data := v_data || jsonb_build_object(
    'compromis', true,
    'compromisPar', p_personnage,
    'acompte', v_acompte,
    'compromisAt', (extract(epoch from now())*1000)::bigint,
    'compromisExpireAt', (extract(epoch from now())*1000)::bigint + 7*86400000
  );
  UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_terrain_id;

  RETURN jsonb_build_object('terrain_id', p_terrain_id, 'acompte', v_acompte, 'prix', v_bien.prix_notaire);
END;
$function$;

-- taux_pret_nationale(text) -> numeric | plpgsql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.taux_pret_nationale(p_pays text)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE v_ie numeric;
BEGIN
  IF p_pays = 'republic' THEN
    SELECT round(avg(COALESCE((data->>'ie')::numeric, 50)))
      INTO v_ie FROM public.indices_villes
     WHERE id IN ('republic_capitale','republic_ville_a','republic_ville_b');
  END IF;
  RETURN 5 + COALESCE(v_ie, 50) / 10;
END; $function$;

-- traiter_prets_helvetia_quotidien() -> TABLE(pret_id text, action text) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.traiter_prets_helvetia_quotidien()
 RETURNS TABLE(pret_id text, action text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pret record;
  v_perso public.personnages%rowtype;
  v_compte_helvetia public.comptes_bancaires%rowtype;
  v_compte_national public.comptes_bancaires%rowtype;
  v_caisse_id text;
  v_du numeric;
  v_dispo numeric;
  v_a_prelever numeric;
  v_seize numeric;
  v_bien record;
  -- Le jour de reference, en Europe/Paris : meme format que jourParisISO() cote JS, qui
  -- ecrit la MEME colonne pour les prets non-Helvetia.
  v_jour text := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD');
BEGIN
  FOR v_pret IN
    SELECT * FROM public.prets
    WHERE type_banque = 'helvetia' AND statut IN ('en_cours','contentieux')
    ORDER BY id FOR UPDATE
  LOOP
    IF v_pret.accord_actif THEN
      IF now() >= v_pret.accord_fin_le THEN
        UPDATE public.prets SET accord_actif = false WHERE id = v_pret.id;
      ELSIF now() >= v_pret.accord_fin_le - interval '1 day' AND NOT v_pret.accord_avertissement_envoye THEN
        UPDATE public.prets SET accord_avertissement_envoye = true WHERE id = v_pret.id;
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Dernier délai',
            'Réglez l''intégralité de votre dette avant minuit demain, faute de quoi le recouvrement reprendra.',
            now()::text, false, false);
        pret_id := v_pret.id; action := 'avertissement_accord'; RETURN NEXT;
        CONTINUE;
      ELSE
        pret_id := v_pret.id; action := 'gele_accord'; RETURN NEXT;
        CONTINUE;
      END IF;
    END IF;

    -- MARQUEUR ANTI-REJEU (chantier 6, 9 octobre 2026). Pose APRES le bloc des accords,
    -- dont les effets sont idempotents et doivent tourner chaque nuit, et AVANT le
    -- prelevement, qui est un delta. Une RPC etant une seule transaction, poser le
    -- marqueur en premier est sans risque : un echec plus loin l'annule avec le reste.
    IF v_pret.jour_dernier_prelevement = v_jour THEN
      pret_id := v_pret.id; action := 'deja_traite_aujourdhui'; RETURN NEXT;
      CONTINUE;
    END IF;
    UPDATE public.prets SET jour_dernier_prelevement = v_jour WHERE id = v_pret.id;
    SELECT * INTO v_perso FROM public.personnages WHERE name = v_pret.emprunteur FOR UPDATE;
    IF NOT FOUND THEN CONTINUE; END IF;
    SELECT * INTO v_compte_helvetia FROM public.comptes_bancaires
      WHERE personnage = v_pret.emprunteur AND banque = 'helvetia' FOR UPDATE;
    SELECT * INTO v_compte_national FROM public.comptes_bancaires
      WHERE personnage = v_pret.emprunteur AND banque = 'nationale' FOR UPDATE;
    v_caisse_id := v_pret.country || '_banque-privee';

    IF v_pret.statut = 'en_cours' THEN
      v_dispo := GREATEST(0, COALESCE(v_compte_helvetia.solde,0) - 10000);
      v_a_prelever := LEAST(v_pret.mensualite, v_pret.montant_restant);

      IF v_dispo >= v_a_prelever THEN
        UPDATE public.comptes_bancaires SET solde = solde - v_a_prelever, updated_at = now()
          WHERE personnage = v_pret.emprunteur AND banque = 'helvetia';
        UPDATE public.caisses_batiments
          SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_a_prelever)), updated_at = now()
          WHERE id = v_caisse_id;
        IF NOT FOUND THEN
          INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_a_prelever), now());
        END IF;
        UPDATE public.personnages SET arg = GREATEST(0, COALESCE(arg,0) - v_a_prelever) WHERE name = v_pret.emprunteur;

        IF v_pret.montant_restant - v_a_prelever <= 0 THEN
          UPDATE public.prets SET montant_restant = 0, jours_impayes = 0, statut = 'rembourse' WHERE id = v_pret.id;
          pret_id := v_pret.id; action := 'solde'; RETURN NEXT;
        ELSE
          UPDATE public.prets SET montant_restant = montant_restant - v_a_prelever, jours_impayes = 0 WHERE id = v_pret.id;
          pret_id := v_pret.id; action := 'preleve'; RETURN NEXT;
        END IF;
        CONTINUE;
      END IF;

      IF v_pret.jours_impayes + 1 >= 2 THEN
        UPDATE public.prets SET jours_impayes = jours_impayes + 1, statut = 'contentieux' WHERE id = v_pret.id;
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Mise en demeure',
            'La totalité du capital restant dû est désormais exigible immédiatement.', now()::text, false, false);
        pret_id := v_pret.id; action := 'passe_contentieux'; RETURN NEXT;
      ELSE
        UPDATE public.prets SET jours_impayes = jours_impayes + 1 WHERE id = v_pret.id;
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Avertissement',
            'Votre échéance n''a pas pu être prélevée.', now()::text, false, false);
        pret_id := v_pret.id; action := 'avertissement'; RETURN NEXT;
        CONTINUE;
      END IF;
    END IF;

    IF NOT v_pret.saisie_financiere_faite THEN
      v_du := v_pret.montant_restant;

      v_seize := LEAST(COALESCE(v_compte_helvetia.solde,0), v_du);
      IF v_seize > 0 THEN
        UPDATE public.comptes_bancaires SET solde = solde - v_seize, updated_at = now()
          WHERE personnage = v_pret.emprunteur AND banque = 'helvetia';
        UPDATE public.caisses_batiments
          SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_seize)), updated_at = now()
          WHERE id = v_caisse_id;
        IF NOT FOUND THEN
          INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_seize), now());
        END IF;
        UPDATE public.personnages SET arg = GREATEST(0, COALESCE(arg,0) - v_seize) WHERE name = v_pret.emprunteur;
        v_du := v_du - v_seize;
      END IF;

      IF v_du > 0 AND v_compte_national.solde IS NOT NULL THEN
        v_seize := LEAST(v_compte_national.solde, v_du);
        IF v_seize > 0 THEN
          UPDATE public.comptes_bancaires SET solde = solde - v_seize, updated_at = now()
            WHERE personnage = v_pret.emprunteur AND banque = 'nationale';
          UPDATE public.caisses_batiments
            SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_seize)), updated_at = now()
            WHERE id = v_caisse_id;
          IF NOT FOUND THEN
            INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_seize), now());
          END IF;
          UPDATE public.personnages SET arg = GREATEST(0, COALESCE(arg,0) - v_seize) WHERE name = v_pret.emprunteur;
          v_du := v_du - v_seize;
        END IF;
      END IF;

      IF v_du > 0 AND COALESCE(v_perso.liquide,0) > 0 THEN
        v_seize := LEAST(v_perso.liquide, v_du);
        UPDATE public.personnages SET liquide = liquide - v_seize, arg = GREATEST(0, COALESCE(arg,0) - v_seize)
          WHERE name = v_pret.emprunteur;
        UPDATE public.caisses_batiments
          SET data = jsonb_set(data,'{solde}', to_jsonb(COALESCE((data->>'solde')::numeric,0)+v_seize)), updated_at = now()
          WHERE id = v_caisse_id;
        IF NOT FOUND THEN
          INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (v_caisse_id, jsonb_build_object('solde', v_seize), now());
        END IF;
        v_du := v_du - v_seize;
      END IF;

      UPDATE public.prets SET montant_restant = v_du, saisie_financiere_faite = true WHERE id = v_pret.id;
      v_pret.montant_restant := v_du;

      IF v_du <= 0 THEN
        UPDATE public.prets SET statut = 'rembourse' WHERE id = v_pret.id;
        pret_id := v_pret.id; action := 'solde_par_saisie'; RETURN NEXT;
        CONTINUE;
      END IF;
      pret_id := v_pret.id; action := 'ladder_financier_execute'; RETURN NEXT;
    END IF;

    IF NOT v_pret.proposition_en_attente THEN
      SELECT t.id, t.data,
             (COALESCE((t.data::jsonb->>'valeur_totale')::numeric,0) +
               CASE t.data::jsonb->>'niveau_construction'
                 WHEN 'hangar' THEN 30000 WHEN 'commerce_standard' THEN 50000
                 WHEN 'commerce_premium' THEN 70000 WHEN 'building' THEN 100000 ELSE 0 END
             ) AS valeur
        INTO v_bien
        FROM public.terrains_etat t
        WHERE t.country = v_pret.country
          AND (t.data::jsonb->>'proprietaire') = v_pret.emprunteur
          AND t.id NOT IN (SELECT terrain_id FROM public.biens_saisis_helvetia WHERE pret_id = v_pret.id)
        ORDER BY
          (CASE WHEN (COALESCE((t.data::jsonb->>'valeur_totale')::numeric,0) +
               CASE t.data::jsonb->>'niveau_construction'
                 WHEN 'hangar' THEN 30000 WHEN 'commerce_standard' THEN 50000
                 WHEN 'commerce_premium' THEN 70000 WHEN 'building' THEN 100000 ELSE 0 END) >= v_pret.montant_restant THEN 0 ELSE 1 END),
          ABS((COALESCE((t.data::jsonb->>'valeur_totale')::numeric,0) +
               CASE t.data::jsonb->>'niveau_construction'
                 WHEN 'hangar' THEN 30000 WHEN 'commerce_standard' THEN 50000
                 WHEN 'commerce_premium' THEN 70000 WHEN 'building' THEN 100000 ELSE 0 END) - v_pret.montant_restant)
        LIMIT 1;

      IF FOUND THEN
        UPDATE public.prets SET bien_cible_id = v_bien.id, proposition_en_attente = true WHERE id = v_pret.id;
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Bien ciblé — proposition d''accord',
            'À défaut de règlement, le bien ' || v_bien.id || ' sera saisi. Un accord amiable reste possible.',
            now()::text, false, false);
        pret_id := v_pret.id; action := 'bien_cible_et_propose'; RETURN NEXT;
      ELSE
        UPDATE public.prets SET proposition_en_attente = true WHERE id = v_pret.id;
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Proposition d''accord',
            'Un bien pourrait être saisi. Un accord amiable reste possible.', now()::text, false, false);
        pret_id := v_pret.id; action := 'proposition_sans_bien'; RETURN NEXT;
      END IF;
      CONTINUE;
    END IF;

    IF v_pret.bien_cible_id IS NULL THEN
      SELECT t.id INTO v_bien
        FROM public.terrains_etat t
        WHERE t.country = v_pret.country
          AND (t.data::jsonb->>'proprietaire') = v_pret.emprunteur
          AND t.id NOT IN (SELECT terrain_id FROM public.biens_saisis_helvetia WHERE pret_id = v_pret.id)
        LIMIT 1;

      IF FOUND THEN
        UPDATE public.prets SET proposition_en_attente = false WHERE id = v_pret.id;
        pret_id := v_pret.id; action := 'nouveau_bien_detecte'; RETURN NEXT;
        CONTINUE;
      END IF;

      IF v_pret.fraude_affaire_id IS NOT NULL THEN
        pret_id := v_pret.id; action := 'attente_fraude'; RETURN NEXT;
      ELSE
        UPDATE public.prets SET montant_restant = 0, statut = 'perte_absorbee' WHERE id = v_pret.id;
        pret_id := v_pret.id; action := 'perte_absorbee'; RETURN NEXT;
      END IF;
      CONTINUE;
    END IF;

    DECLARE
      v_terrain_row record;
      v_terrain_data jsonb;
      v_valeur numeric;
      v_coprop text;
      v_quote_part numeric;
      v_bien_id text;
    BEGIN
      SELECT id, data INTO v_terrain_row FROM public.terrains_etat WHERE id = v_pret.bien_cible_id FOR UPDATE;

      IF NOT FOUND OR (v_terrain_row.data::jsonb->>'proprietaire') <> v_pret.emprunteur THEN
        UPDATE public.prets SET bien_cible_id = NULL, proposition_en_attente = false WHERE id = v_pret.id;
        pret_id := v_pret.id; action := 'cible_invalide_recible'; RETURN NEXT;
        CONTINUE;
      END IF;

      v_terrain_data := v_terrain_row.data::jsonb;
      v_coprop := v_terrain_data->>'coproprietaire';
      v_valeur := COALESCE((v_terrain_data->>'valeur_totale')::numeric,0) +
        CASE v_terrain_data->>'niveau_construction'
          WHEN 'hangar' THEN 30000 WHEN 'commerce_standard' THEN 50000
          WHEN 'commerce_premium' THEN 70000 WHEN 'building' THEN 100000 ELSE 0 END;

      v_terrain_data := v_terrain_data || jsonb_build_object('proprietaire','Helvetia');
      UPDATE public.terrains_etat SET data = v_terrain_data::text, updated_at = now() WHERE id = v_terrain_row.id;

      v_bien_id := 'bien-' || v_pret.id || '-' || extract(epoch from clock_timestamp())::bigint;

      IF v_coprop IS NULL THEN
        IF v_valeur >= v_pret.montant_restant THEN
          DECLARE
            v_surplus numeric := v_valeur - v_pret.montant_restant;
            v_frais numeric := ROUND(v_surplus * 0.10);
            v_restitution numeric := v_surplus - v_frais;
          BEGIN
            UPDATE public.prets SET montant_restant = 0, statut = 'rembourse',
                bien_cible_id = NULL, proposition_en_attente = false WHERE id = v_pret.id;
            INSERT INTO public.biens_saisis_helvetia
              (id, terrain_id, pret_id, country, city, valeur_objective, coproprietaire, quote_part_coproprietaire, prix_notaire)
              VALUES (v_bien_id, v_terrain_row.id, v_pret.id, v_pret.country, v_terrain_data->>'city',
                      v_valeur, NULL, NULL, v_valeur);
            IF v_restitution > 0 THEN
              INSERT INTO public.obligations_helvetia (id, country, beneficiaire, montant_du, motif, bien_id, pret_id, destination_type)
                VALUES ('obl-'||v_bien_id, v_pret.country, v_pret.emprunteur, v_restitution, 'surplus_saisie', v_bien_id, v_pret.id, 'liquide');
            END IF;
          END;
          pret_id := v_pret.id; action := 'saisie_bien_solde'; RETURN NEXT;
        ELSE
          UPDATE public.prets SET montant_restant = montant_restant - v_valeur,
              bien_cible_id = NULL, proposition_en_attente = false WHERE id = v_pret.id;
          INSERT INTO public.biens_saisis_helvetia
            (id, terrain_id, pret_id, country, city, valeur_objective, coproprietaire, quote_part_coproprietaire, prix_notaire)
            VALUES (v_bien_id, v_terrain_row.id, v_pret.id, v_pret.country, v_terrain_data->>'city',
                    v_valeur, NULL, NULL, v_valeur);
          pret_id := v_pret.id; action := 'saisie_bien_partiel'; RETURN NEXT;
        END IF;
      ELSE
        v_quote_part := v_valeur / 2;
        INSERT INTO public.biens_saisis_helvetia
          (id, terrain_id, pret_id, country, city, valeur_objective, coproprietaire, quote_part_coproprietaire, prix_notaire)
          VALUES (v_bien_id, v_terrain_row.id, v_pret.id, v_pret.country, v_terrain_data->>'city',
                  v_valeur, v_coprop, v_quote_part, v_valeur);
        UPDATE public.prets SET bien_cible_id = NULL, proposition_en_attente = false WHERE id = v_pret.id;
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_pret.emprunteur, 'Banque Privée Helvetia', 'Bien en copropriété saisi',
            'Le bien est saisi et mis en vente. Sa quote-part protégée sera réglée à votre copropriétaire à la revente.',
            now()::text, false, false);
        INSERT INTO public.mails (to_player, from_player, subject, body, time, read, archived)
          VALUES (v_coprop, 'Banque Privée Helvetia', 'Bien en copropriété saisi',
            'Un bien que vous détenez en copropriété avec ' || v_pret.emprunteur || ' a été saisi au titre d''une dette qui ne vous concerne pas. Votre quote-part (' || v_quote_part || ') est protégée et vous sera réglée à la revente.',
            now()::text, false, false);
        pret_id := v_pret.id; action := 'saisie_bien_copropriete_en_vente'; RETURN NEXT;
      END IF;
    END;
  END LOOP;
  RETURN;
END;
$function$;
