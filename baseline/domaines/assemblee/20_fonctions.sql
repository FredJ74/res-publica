-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine assemblee -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- assemblee_achat_illegal(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_achat_illegal(p_nom text, p_circuit text, p_ref text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej     jsonb;
  v_cat     public.assemblee_catalogue_illegal%ROWTYPE;
  v_country text;
  v_res     jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'achat_illegal');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_cat FROM public.assemblee_catalogue_illegal WHERE circuit = p_circuit AND ref = p_ref;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'objet_inconnu'));
  END IF;
  SELECT country INTO v_country FROM public.personnages WHERE name = p_nom;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;

  v_res := public.assemblee_transaction_interdite_interne(v_country, p_nom, NULL, v_cat.objet, v_cat.libelle, 1);
  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'interdit', COALESCE((v_res ->> 'interdit')::boolean, false),
    'loi', v_res -> 'loi', 'acheteur', v_res -> 'acheteur',
    'dis', v_res -> 'acheteur' -> 'dis'));
END;
$function$;

-- assemblee_amender(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_amender(p_nom text, p_id text, p_texte text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej   jsonb;
  v_perso public.personnages%ROWTYPE;
  v_row   public.assemblee_propositions%ROWTYPE;
  v_texte text;
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'amender');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'introuvable'));
  END IF;
  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom;
  IF NOT FOUND OR NOT (v_perso.country = v_row.country AND v_perso.current_building = 'assemblee'
                       AND v_perso.current_room = 'hemicycle') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;
  IF v_row.auteur <> p_nom THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pas_auteur'));
  END IF;
  IF v_row.statut <> 'debat' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_phase_debat'));
  END IF;
  v_texte := btrim(COALESCE(p_texte, ''));
  IF v_texte = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'champs_requis'));
  END IF;
  IF length(v_texte) > 20000 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'texte_trop_long'));
  END IF;

  UPDATE public.assemblee_propositions
     SET amendements = amendements || jsonb_build_object(
           'num',   jsonb_array_length(amendements) + 1,
           'texte', v_texte,
           'ts',    to_jsonb(now()))
   WHERE id = p_id
  RETURNING * INTO v_row;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row)));
END;
$function$;

-- assemblee_catalogue_legislatif() -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_catalogue_legislatif()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object(
    'categories', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'categorie', c.categorie,
               'label', c.label,
               'matieres', coalesce(to_jsonb(c.matieres), '[]'::jsonb),
               'types_objet', coalesce(to_jsonb(c.types_objet), '[]'::jsonb),
               'sous_types', coalesce(to_jsonb(c.sous_types), '[]'::jsonb),
               'choix_volets', (cardinality(c.matieres) > 0 AND cardinality(c.types_objet) > 0),
               'sous_types_disponibles', coalesce((
                  SELECT to_jsonb(array_agg(DISTINCT s ORDER BY s))
                    FROM unnest(c.types_objet) t,
                         unnest(public.assemblee_sous_types_connus(t)) s
                    WHERE cardinality(c.sous_types) = 0 OR s = ANY (c.sous_types)
                 ), '[]'::jsonb),
               'transformation_pertinente', EXISTS (
                 SELECT 1 FROM unnest(c.matieres) m
                  WHERE (public.matiere_circuits_disponibles(m) ->> 'transformation')::boolean),
               'production_pertinente', EXISTS (
                 SELECT 1 FROM unnest(c.matieres) m
                  WHERE (public.matiere_circuits_disponibles(m) ->> 'production_usine')::boolean
                     OR (public.matiere_circuits_disponibles(m) ->> 'recolte')::boolean)
             ) ORDER BY c.label)
        FROM public.assemblee_categories_interdiction c), '[]'::jsonb),
    'matieres', coalesce((
      SELECT jsonb_agg(public.matiere_circuits_disponibles(r.cle) ORDER BY r.cle)
        FROM public.ressources_economie r), '[]'::jsonb),
    'portee_dimensions', jsonb_build_array('transformation_stock_interdite',
                                           'volet_matieres', 'volet_objets', 'sous_types')
  );
$function$;

-- assemblee_cle_convocation(jsonb) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.assemblee_cle_convocation(e jsonb)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT COALESCE(
    e->>'id',
    'legacy|' || COALESCE(e->>'motif', '') || '|' || COALESCE(e->>'jourEmission', '')
      || '|' || COALESCE(e->>'heureEmission', '') || '|' || COALESCE(e->>'limiteTs', '')
  );
$function$;

-- assemblee_cloturer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_cloturer(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row        public.assemblee_propositions%ROWTYPE;
  v_pour       text[]  := '{}';
  v_contre     text[]  := '{}';
  v_abst       text[]  := '{}';
  v_non_vot    text[]  := '{}';
  v_endormis   text[]  := '{}';
  v_pnj_pour   text[]  := '{}';
  v_pnj_contre text[]  := '{}';
  v_score_p    integer := 0;
  v_score_c    integer := 0;
  v_resultat   text;
  v_scrutin_id text;
BEGIN
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;

  v_scrutin_id := p_id || ':' || v_row.session_num;

  -- Idempotence : cette session est deja close.
  IF EXISTS (SELECT 1 FROM public.assemblee_scrutins WHERE id = v_scrutin_id) THEN
    RETURN jsonb_build_object('ok', true, 'deja_cloture', true,
      'scrutin', (SELECT to_jsonb(s) FROM public.assemblee_scrutins s WHERE s.id = v_scrutin_id));
  END IF;

  IF v_row.statut <> 'session' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_session');
  END IF;

  -- Garde temporelle : jamais de depouillement avant l'echeance, quel que soit
  -- l'appelant. Une session sans echeance n'est pas depouillable.
  IF v_row.cloture_ts IS NULL OR now() < v_row.cloture_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_non_echu');
  END IF;

  -- ---- Cote PJ : les sieges reellement tenus par un joueur
  SELECT
    COALESCE(array_agg(o.pj_nom) FILTER (WHERE v.choix = 'POUR'),       '{}'),
    COALESCE(array_agg(o.pj_nom) FILTER (WHERE v.choix = 'CONTRE'),     '{}'),
    COALESCE(array_agg(o.pj_nom) FILTER (WHERE v.choix = 'ABSTENTION'), '{}'),
    COALESCE(array_agg(o.pj_nom) FILTER (WHERE v.choix IS NULL),        '{}')
  INTO v_pour, v_contre, v_abst, v_non_vot
  FROM public.assemblee_occupation_sieges(v_row.country) o
  LEFT JOIN public.assemblee_votes v
    ON v.proposition_id = p_id
   AND v.session_num = v_row.session_num
   AND v.votant = o.pj_nom
  WHERE NOT o.est_pnj;

  -- ---- Cote PNJ : intention comptee UNIQUEMENT si le depute est eveille
  SELECT
    COALESCE(array_agg(o.pnj_nom) FILTER (WHERE NOT o.endormi AND i.intention = 'POUR'),   '{}'),
    COALESCE(array_agg(o.pnj_nom) FILTER (WHERE NOT o.endormi AND i.intention = 'CONTRE'), '{}'),
    COALESCE(array_agg(o.pnj_nom) FILTER (WHERE o.endormi), '{}')
  INTO v_pnj_pour, v_pnj_contre, v_endormis
  FROM public.assemblee_occupation_sieges(v_row.country) o
  LEFT JOIN public.assemblee_intentions i
    ON i.proposition_id = p_id
   AND i.session_num = v_row.session_num
   AND i.siege_id = o.siege_id
  WHERE o.est_pnj;

  v_pour   := v_pour   || v_pnj_pour;
  v_contre := v_contre || v_pnj_contre;

  v_score_p := COALESCE(array_length(v_pour, 1), 0);
  v_score_c := COALESCE(array_length(v_contre, 1), 0);

  -- §26/§27
  IF v_score_p > v_score_c THEN
    v_resultat := 'ADOPTEE';
  ELSIF v_score_c > v_score_p THEN
    v_resultat := 'REJETEE';
  ELSE
    v_resultat := 'RENVOYEE';
  END IF;

  INSERT INTO public.assemblee_scrutins
    (id, proposition_id, session_num, country, titre, resultat,
     score_pour, score_contre, pour, contre, abstention, non_votants, endormis)
  VALUES
    (v_scrutin_id, p_id, v_row.session_num, v_row.country, v_row.titre, v_resultat,
     v_score_p, v_score_c,
     to_jsonb(v_pour), to_jsonb(v_contre), to_jsonb(v_abst),
     to_jsonb(v_non_vot), to_jsonb(v_endormis));

  -- Statut de la proposition
  IF v_resultat = 'ADOPTEE' THEN
    UPDATE public.assemblee_propositions
    SET statut = 'adoptee', adoptee_ts = now()
    WHERE id = p_id;

    -- CHANGEMENT DU 30 SEPTEMBRE 2026 : une abrogation adoptee N'ETEINT PLUS sa
    -- cible ici. Elle rejoint le registre du Ministre de l'Interieur et attend sa
    -- mise en application, comme toute autre decision parlementaire. C'est
    -- assemblee_mettre_en_application qui eteindra la cible.
    -- L'adoptee_ts pose ci-dessus demarre AUSSI le chrono d'execution : le delai
    -- appartient a la loi, pas au gouvernement.

  ELSIF v_resultat = 'REJETEE' THEN
    UPDATE public.assemblee_propositions SET statut = 'rejetee' WHERE id = p_id;
  ELSE
    -- §27 : renvoi. Le projet reste vivant ; ses votes PJ seront effaces et les
    -- intentions rerollees a l'ouverture de la session suivante.
    UPDATE public.assemblee_propositions
    SET statut = 'renvoyee', cloture_ts = NULL, session_ouverte_ts = NULL
    WHERE id = p_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'resultat', v_resultat,
    'score_pour', v_score_p,
    'score_contre', v_score_c,
    'pour', to_jsonb(v_pour),
    'contre', to_jsonb(v_contre),
    'abstention', to_jsonb(v_abst),
    'non_votants', to_jsonb(v_non_vot),
    'endormis', to_jsonb(v_endormis),
    'titre', v_row.titre,
    'type', v_row.type,
    'categorie', v_row.categorie,
    'auteur', v_row.auteur,
    'forum_topic_id', v_row.forum_topic_id,
    'loi_cible_id', v_row.loi_cible_id,
    'exige_application', public.assemblee_exige_application(v_row.type)
  );
END;
$function$;

-- assemblee_cloturer_echues(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_cloturer_echues(p_country text DEFAULT 'republic'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_res  jsonb := '[]'::jsonb;
  v_prop record;
BEGIN
  FOR v_prop IN
    SELECT id FROM public.assemblee_propositions
    WHERE country = p_country
      AND statut = 'session'
      AND cloture_ts IS NOT NULL
      AND now() >= cloture_ts
    ORDER BY cloture_ts
  LOOP
    v_res := v_res || jsonb_build_array(
      public.assemblee_cloturer(v_prop.id) || jsonb_build_object('id', v_prop.id)
    );
  END LOOP;
  RETURN v_res;
END;
$function$;

-- assemblee_compter_unites(jsonb,text) -> numeric | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_compter_unites(p_inventaire jsonb, p_stack_key text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT COALESCE(sum((v ->> 'qty')::numeric), 0)
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_inventaire) = 'array' THEN p_inventaire ELSE '[]'::jsonb END) v
   WHERE v ->> 'stackKey' = p_stack_key AND jsonb_typeof(v -> 'qty') = 'number';
$function$;

-- assemblee_consulter_lobbyiste(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_consulter_lobbyiste(p_nom text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa    CONSTANT integer := 1;
  c_fr    CONSTANT integer := 150;
  c_bonus CONSTANT integer := 20;
  v_rej   jsonb;
  v_perso public.personnages%ROWTYPE;
  v_debit jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'lobbyiste');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;
  IF NOT (v_perso.current_building = 'assemblee' AND v_perso.current_room = 'couloirs') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;
  IF COALESCE(v_perso.bonus_lobbyiste, 0) > 0 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'bonus_deja_acquis'));
  END IF;

  v_debit := public.assemblee_debiter_joueur(p_nom, c_pa, c_fr);
  IF NOT (v_debit ->> 'ok')::boolean THEN
    RETURN public.assemblee_requete_clore(p_requete, v_debit);
  END IF;

  UPDATE public.personnages SET bonus_lobbyiste = c_bonus WHERE name = p_nom;

  RETURN public.assemblee_requete_clore(p_requete, v_debit || jsonb_build_object('ok', true, 'bonus_lobbyiste', c_bonus));
END;
$function$;

-- assemblee_crediter_caisse(text,integer) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_crediter_caisse(p_key text, p_montant integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_solde integer;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RAISE EXCEPTION 'montant_invalide';
  END IF;

  -- Increment en une seule instruction : le verrou de ligne pris par l'UPSERT serialise deux
  -- marchandages simultanes, qui creditent donc bien 200 FR au total, jamais 100.
  -- L'alias c designe la ligne EXISTANTE dans la clause DO UPDATE ; le RETURNING, lui, voit la
  -- ligne finale -- c'est bien le nouveau solde qui est renvoye.
  INSERT INTO public.caisses_batiments AS c (id, data, updated_at)
  VALUES (p_key, jsonb_build_object('solde', p_montant), now())
  ON CONFLICT (id) DO UPDATE
    SET data = jsonb_set(
          COALESCE(c.data::jsonb, '{}'::jsonb),
          '{solde}',
          to_jsonb(
            GREATEST(0, COALESCE((c.data::jsonb->>'solde')::integer, 0) + p_montant)
          )
        ),
        updated_at = now()
  RETURNING (c.data::jsonb->>'solde')::integer INTO v_solde;

  RETURN COALESCE(v_solde, p_montant);
END;
$function$;

-- assemblee_crediter_joueur(text,integer) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_crediter_joueur(p_nom text, p_montant integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_liquide integer;
  v_arg     integer;
BEGIN
  UPDATE public.personnages
     SET liquide = COALESCE(liquide, 0) + GREATEST(0, p_montant),
         arg     = COALESCE(arg, 0) + GREATEST(0, p_montant)
   WHERE name = p_nom
  RETURNING liquide, arg INTO v_liquide, v_arg;
  RETURN jsonb_build_object('liquide', v_liquide, 'arg', v_arg);
END;
$function$;

-- assemblee_debiter_caisse_plafonne(text,integer) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_debiter_caisse_plafonne(p_key text, p_montant integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_solde integer;
  v_verse integer;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RETURN 0;
  END IF;

  SELECT GREATEST(0, COALESCE((data::jsonb->>'solde')::integer, 0))
    INTO v_solde
    FROM public.caisses_batiments
   WHERE id = p_key
     FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 0;                       -- caisse inexistante : rien a verser, jamais d'erreur
  END IF;

  v_verse := LEAST(v_solde, p_montant);
  IF v_verse <= 0 THEN
    RETURN 0;
  END IF;

  UPDATE public.caisses_batiments
     SET data = jsonb_set(COALESCE(data::jsonb, '{}'::jsonb), '{solde}', to_jsonb(v_solde - v_verse)),
         updated_at = now()
   WHERE id = p_key;

  RETURN v_verse;
END;
$function$;

-- assemblee_debiter_joueur(text,integer,integer) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_debiter_joueur(p_nom text, p_pa integer, p_fr integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pa       integer;
  v_liquide  integer;
  v_arg      integer;
  v_nat      numeric;
  v_a_compte boolean;
  v_pl       integer := 0;
  v_pn       integer := 0;
BEGIN
  SELECT pa, liquide, arg INTO v_pa, v_liquide, v_arg
    FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- A. PA d'abord (deduireCoutOrdre, etape A).
  IF COALESCE(v_pa, 0) < p_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa', COALESCE(v_pa, 0), 'pa_requis', p_pa);
  END IF;

  -- B. Fonds ordinaires = liquide + Banque nationale (getFondsDisponiblesOrdinaires).
  SELECT solde INTO v_nat FROM public.comptes_bancaires
   WHERE personnage = p_nom AND banque = 'nationale' FOR UPDATE;
  v_a_compte := FOUND;
  IF p_fr > 0 AND COALESCE(v_liquide, 0) + COALESCE(v_nat, 0) < p_fr THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
      'fonds_disponibles', COALESCE(v_liquide, 0) + COALESCE(v_nat, 0), 'montant_requis', p_fr);
  END IF;

  -- C. debiterFondsOrdinaires : liquide d'abord, complement sur la Banque nationale.
  IF p_fr > 0 THEN
    v_pl := LEAST(COALESCE(v_liquide, 0), p_fr);
    v_pn := p_fr - v_pl;
  END IF;

  UPDATE public.personnages
     SET pa      = GREATEST(0, COALESCE(pa, 0) - p_pa),
         liquide = COALESCE(liquide, 0) - v_pl,
         arg     = COALESCE(arg, 0) - p_fr
   WHERE name = p_nom
  RETURNING pa, liquide, arg INTO v_pa, v_liquide, v_arg;

  IF v_pn > 0 THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pn, updated_at = now()
     WHERE personnage = p_nom AND banque = 'nationale'
    RETURNING solde INTO v_nat;
  END IF;

  RETURN jsonb_build_object('ok', true,
    'pa', v_pa, 'liquide', v_liquide, 'arg', v_arg,
    'solde_national', CASE WHEN v_a_compte THEN v_nat ELSE NULL END,
    'pa_preleves', p_pa, 'montant_preleve', p_fr,
    'preleve_liquide', v_pl, 'preleve_national', v_pn);
END;
$function$;

-- assemblee_deposer(text,text,text,text,text,text,text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_deposer(p_nom text, p_titre text, p_type text, p_texte text, p_categorie text, p_loi_cible_id text, p_requete text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.assemblee_deposer_projet(
    p_requete, p_nom, p_titre, p_type, p_texte, p_categorie, p_loi_cible_id, NULL);
$function$;

-- assemblee_deposer_projet(text,text,text,text,text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_deposer_projet(p_requete text, p_nom text, p_titre text, p_type text, p_texte text, p_categorie text, p_loi_cible_id text, p_portee jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa      CONSTANT integer := 1;
  c_categories text[] := ARRAY(SELECT categorie FROM public.assemblee_categories_interdiction);
  v_rej     jsonb;
  v_perso   public.personnages%ROWTYPE;
  v_cible   public.assemblee_propositions%ROWTYPE;
  v_titre   text;
  v_texte   text;
  v_cat     text := NULL;
  v_cible_id text := NULL;
  v_portee  jsonb := NULL;
  v_vp      jsonb;
  v_debit   jsonb;
  v_id      text;
  v_row     public.assemblee_propositions%ROWTYPE;
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'deposer');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;
  IF NOT (v_perso.current_building = 'assemblee' AND v_perso.current_room = 'hemicycle'
          AND EXISTS (SELECT 1 FROM public.assemblee_sieges s WHERE s.country = v_perso.country)) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;
  IF NOT public.assemblee_peut_deposer(p_nom, v_perso.country) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'ineligible'));
  END IF;
  IF p_type IS NULL OR p_type NOT IN ('rp', 'mecanique', 'abrogation') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'type_invalide'));
  END IF;

  v_texte := btrim(COALESCE(p_texte, ''));
  IF v_texte = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'champs_requis'));
  END IF;
  IF length(v_texte) > 20000 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'texte_trop_long'));
  END IF;

  IF p_type = 'abrogation' THEN
    SELECT * INTO v_cible FROM public.assemblee_propositions
     WHERE id = p_loi_cible_id AND statut = 'adoptee' AND country = v_perso.country;
    IF NOT FOUND THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'loi_cible_introuvable'));
    END IF;
    v_cible_id := v_cible.id;
    v_titre := left('Abrogation — ' || v_cible.titre, 200);
  ELSE
    v_titre := btrim(COALESCE(p_titre, ''));
    IF v_titre = '' THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'champs_requis'));
    END IF;
    IF length(v_titre) > 120 THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'titre_trop_long'));
    END IF;
    IF p_type = 'mecanique' THEN
      -- La liste des categories n'est plus figee dans le corps : elle est LUE dans
      -- assemblee_categories_interdiction, pour qu'ajouter une categorie n'oblige
      -- plus a reecrire cette fonction (les six matieres ajoutees ce jour l'ont
      -- montre).
      IF p_categorie IS NULL OR NOT (p_categorie = ANY (c_categories)) THEN
        RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'categorie_invalide'));
      END IF;
      v_cat := p_categorie;

      v_vp := public.assemblee_portee_valider(p_portee);
      IF NOT (v_vp ->> 'ok')::boolean THEN
        RETURN public.assemblee_requete_clore(p_requete, v_vp);
      END IF;
      v_portee := v_vp -> 'portee';
    END IF;
  END IF;

  -- LE PA N'EST DEBITE QU'ICI, au depot effectif. La conversation avec le juriste
  -- de l'Assemblee ne coute rien : elle ne passe jamais par cette fonction.
  v_debit := public.assemblee_debiter_joueur(p_nom, c_pa, 0);
  IF NOT (v_debit ->> 'ok')::boolean THEN
    RETURN public.assemblee_requete_clore(p_requete, v_debit);
  END IF;

  v_id := 'prop-' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint
          || '-' || substr(md5(random()::text || clock_timestamp()::text), 1, 6);

  INSERT INTO public.assemblee_propositions
    (id, country, auteur, titre, type, categorie, loi_cible_id, texte_original,
     eligible_session_ts, data)
  VALUES
    (v_id, v_perso.country, p_nom, v_titre, p_type, v_cat, v_cible_id, v_texte,
     now() + interval '7 days',
     CASE WHEN v_portee IS NULL THEN '{}'::jsonb
          ELSE jsonb_build_object('portee', v_portee) END)
  RETURNING * INTO v_row;

  RETURN public.assemblee_requete_clore(p_requete,
    v_debit || jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row)));
END;
$function$;

-- assemblee_detecter_partie(text,text,jsonb,text,integer,boolean) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_detecter_partie(p_nom text, p_role text, p_loi jsonb, p_libelle text, p_quantite integer, p_baisse_dis boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_resources jsonb;
  v_convs     jsonb;
  v_hist      jsonb;
  v_dis       numeric;
  v_taux      integer;
  v_jet       integer;
  v_detecte   boolean;
  v_deja      boolean := false;
  v_trace     jsonb;
  v_conv      jsonb := NULL;
BEGIN
  SELECT CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END,
         COALESCE(convocations, '[]'::jsonb), COALESCE(historique_crimes, '[]'::jsonb)
    INTO v_resources, v_convs, v_hist
    FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  v_dis  := CASE WHEN jsonb_typeof(v_resources -> 'dis') = 'number' THEN (v_resources ->> 'dis')::numeric ELSE 0 END;
  v_taux := GREATEST(5, 50 - floor(v_dis / 10)::integer);
  v_jet  := floor(random() * 100)::integer + 1;
  v_detecte := v_jet <= v_taux;

  v_trace := jsonb_build_object(
    'id', 'trace-' || md5(random()::text || clock_timestamp()::text),
    'origine', 'serveur',
    'acte', 'transaction_interdite',
    'cible', COALESCE(p_libelle, p_loi ->> 'categorie'),
    'role', p_role,
    'categorie', p_loi ->> 'categorie',
    'quantite', COALESCE(p_quantite, 1),
    'loiId', p_loi ->> 'id',
    'loiTitre', p_loi ->> 'titre',
    'ts', to_jsonb(now()),
    'expireTs', to_jsonb(now() + interval '8 days'));
  v_hist := v_hist || jsonb_build_array(v_trace);

  IF v_detecte THEN
    SELECT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_convs) c
       WHERE c.value ->> 'motif' = 'transaction_interdite'
         AND COALESCE((c.value ->> 'traitee')::boolean, false) = false
    ) INTO v_deja;
    IF NOT v_deja THEN
      v_conv := jsonb_build_object(
        'id', 'conv-' || md5(random()::text || clock_timestamp()::text),
        'origine', 'serveur',
        'motif', 'transaction_interdite',
        'limiteTs', to_jsonb(now() + interval '36 hours'),
        'role', p_role,
        'categorie', p_loi ->> 'categorie',
        'loiId', p_loi ->> 'id',
        'loiTitre', p_loi ->> 'titre',
        'traitee', false);
      v_convs := v_convs || jsonb_build_array(v_conv);
      IF p_baisse_dis THEN
        v_dis := GREATEST(0, v_dis - 10);
        v_resources := jsonb_set(v_resources, '{dis}', to_jsonb(v_dis));
      END IF;
    END IF;
  END IF;

  UPDATE public.personnages
     SET convocations = v_convs, historique_crimes = v_hist, resources = v_resources
   WHERE name = p_nom;

  IF v_conv IS NOT NULL THEN
    BEGIN
      INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
      VALUES (
        'mail-' || md5(random()::text || clock_timestamp()::text),
        'Commissariat', p_nom, 'Convocation officielle',
        CASE WHEN p_role = 'vente'
          THEN 'Une vente portant sur une marchandise interdite (« ' || (p_loi ->> 'titre') || ' ») a été constatée dans votre commerce. '
          ELSE 'Une transaction portant sur une marchandise interdite (« ' || (p_loi ->> 'titre') || ' ») vous a été imputée. ' END
        || 'Présentez-vous au commissariat sous 36 heures pour vous justifier. '
        || 'Passé ce délai sans vous présenter, vous serez arrêté(e) et détenu(e) deux jours.',
        to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'), false);
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN jsonb_build_object('role', p_role, 'detecte', v_detecte, 'taux', v_taux, 'jet', v_jet,
    'convocation_creee', v_conv IS NOT NULL, 'trace', v_trace, 'convocation', v_conv, 'dis', v_dis);
END;
$function$;

-- assemblee_echeance_application(timestamp with time zone) -> timestamp with time zone | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_echeance_application(p_adoptee_ts timestamp with time zone)
 RETURNS timestamp with time zone
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_adoptee_ts + interval '36 hours';
$function$;

-- assemblee_echeance_palier(timestamp with time zone,integer) -> timestamp with time zone | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_echeance_palier(p_adoptee_ts timestamp with time zone, p_palier integer)
 RETURNS timestamp with time zone
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_adoptee_ts + interval '36 hours' + ((p_palier - 1) * interval '24 hours');
$function$;

-- assemblee_exige_application(text) -> boolean | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_exige_application(p_type text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(p_type, '') IN ('mecanique', 'abrogation');
$function$;

-- assemblee_fenetre_ouverture(timestamp with time zone) -> boolean | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_fenetre_ouverture(p_instant timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT (extract(isodow FROM l) = 3 AND extract(hour FROM l) >= 22)
      OR  extract(isodow FROM l) = 4
    FROM (SELECT p_instant AT TIME ZONE 'Europe/Paris' AS l) x;
$function$;

-- assemblee_fret_vente_legale() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_fret_vente_legale()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_loi jsonb;
BEGIN
  IF OLD.statut = 'a_vendre' AND NEW.statut = 'vendue' THEN
    SELECT public.assemblee_loi_en_vigueur(COALESCE(NEW.pays_destination, 'republic'), c.objet, now())
      INTO v_loi
      FROM public.contenu_caisses_fret c
     WHERE c.caisse_id = NEW.id
       AND COALESCE(c.quantite, 0) > 0
       AND public.assemblee_loi_en_vigueur(COALESCE(NEW.pays_destination, 'republic'), c.objet, now()) IS NOT NULL
     LIMIT 1;
    IF v_loi IS NOT NULL THEN
      RAISE EXCEPTION 'vente_interdite' USING DETAIL = (v_loi ->> 'titre');
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- assemblee_gouvernement_actuel(text) -> TABLE(nom text, poste_id text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_gouvernement_actuel(p_country text)
 RETURNS TABLE(nom text, poste_id text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT pd.name, pd.poste ->> 'id'
    FROM public.personnages_donnees pd
   WHERE pd.country = p_country
     AND pd.poste IS NOT NULL
     AND (pd.poste ->> 'id' IN ('president', 'pm') OR pd.poste ->> 'id' LIKE 'min\_%')
   ORDER BY pd.poste ->> 'id', pd.name;
$function$;

-- assemblee_lier_topic(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_lier_topic(p_nom text, p_id text, p_topic_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row public.assemblee_propositions%ROWTYPE;
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF v_row.auteur IS DISTINCT FROM p_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_auteur');
  END IF;
  IF v_row.forum_topic_id IS NOT NULL THEN
    IF v_row.forum_topic_id = p_topic_id THEN
      RETURN jsonb_build_object('ok', true, 'forum_topic_id', p_topic_id);
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'topic_deja_lie');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.forum_topics t
     WHERE t.id = p_topic_id AND t.forum_id = 'assemblee' AND t.author = p_nom
  ) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'topic_invalide');
  END IF;

  UPDATE public.assemblee_propositions SET forum_topic_id = p_topic_id WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'forum_topic_id', p_topic_id);
END;
$function$;

-- assemblee_loi_en_vigueur(text,jsonb,timestamp with time zone) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_loi_en_vigueur(p_country text, p_objet jsonb, p_instant timestamp with time zone)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object(
           'id', p.id, 'titre', p.titre, 'categorie', p.categorie,
           'adoptee_ts', p.adoptee_ts, 'appliquee_ts', p.appliquee_ts,
           'portee', coalesce(p.data -> 'portee', '{}'::jsonb))
    FROM public.assemblee_propositions p
   WHERE p.country = p_country
     AND p.type = 'mecanique'
     AND p.statut = 'adoptee'
     AND p.adoptee_ts IS NOT NULL
     AND p.adoptee_ts <= p_instant
     AND p.appliquee_ts IS NOT NULL
     AND p.appliquee_ts <= p_instant
     AND public.assemblee_objet_vise(p.categorie, p_objet,
                                     coalesce(p.data -> 'portee', '{}'::jsonb))
   ORDER BY p.appliquee_ts, p.adoptee_ts, p.id
   LIMIT 1;
$function$;

-- assemblee_marchander(text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_marchander(p_nom text, p_id text, p_siege_id text, p_intention text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa      CONSTANT integer := 1;
  c_fr      CONSTANT integer := 100;
  v_rej     jsonb;
  v_perso   public.personnages%ROWTYPE;
  v_prop    public.assemblee_propositions%ROWTYPE;
  v_est_pnj boolean;
  v_debit   jsonb;
  v_bonus   boolean;
  v_taux    integer;
  v_jet     integer;
  v_reussi  boolean;
  v_applique boolean := false;
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'marchander');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF p_intention IS NULL OR p_intention NOT IN ('POUR', 'CONTRE') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'intention_invalide'));
  END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;

  -- FOR SHARE : serialise avec la cloture (FOR UPDATE), aucun marchandage ne chevauche le depouillement.
  SELECT * INTO v_prop FROM public.assemblee_propositions WHERE id = p_id FOR SHARE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'introuvable'));
  END IF;
  IF v_prop.statut <> 'session' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_session'));
  END IF;
  IF v_prop.cloture_ts IS NULL OR now() >= v_prop.cloture_ts THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_clos'));
  END IF;

  IF NOT (v_perso.country = v_prop.country AND v_perso.current_building = 'assemblee'
          AND v_perso.current_room = 'hemicycle') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;

  SELECT o.est_pnj INTO v_est_pnj
    FROM public.assemblee_occupation_sieges(v_prop.country) o WHERE o.siege_id = p_siege_id;
  IF v_est_pnj IS NULL THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'siege_introuvable'));
  END IF;
  IF NOT v_est_pnj THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'siege_tenu_par_pj'));
  END IF;

  -- Paiement AVANT le jet (convention du projet) ; refus = aucune ecriture.
  v_debit := public.assemblee_debiter_joueur(p_nom, c_pa, c_fr);
  IF NOT (v_debit ->> 'ok')::boolean THEN
    RETURN public.assemblee_requete_clore(p_requete, v_debit);
  END IF;

  v_bonus  := COALESCE(v_perso.bonus_lobbyiste, 0) > 0;
  v_taux   := public.assemblee_taux_marchandage(v_perso.stats, v_bonus);
  v_jet    := floor(random() * 100)::integer + 1;
  v_reussi := v_jet <= v_taux;

  IF v_bonus THEN
    UPDATE public.personnages SET bonus_lobbyiste = 0 WHERE name = p_nom;
  END IF;

  PERFORM public.assemblee_crediter_caisse(v_prop.country || '_assemblee', c_fr);

  IF v_reussi THEN
    UPDATE public.assemblee_intentions
       SET intention = p_intention, updated_at = now()
     WHERE proposition_id = p_id AND session_num = v_prop.session_num AND siege_id = p_siege_id;
    v_applique := FOUND;
  END IF;

  RETURN public.assemblee_requete_clore(p_requete, v_debit || jsonb_build_object(
    'ok', true, 'reussi', v_reussi, 'applique', v_applique,
    'taux', v_taux, 'jet', v_jet, 'bonus_applique', v_bonus, 'bonus_lobbyiste', 0));
END;
$function$;

-- assemblee_marquer_convocations_echues(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_marquer_convocations_echues(p_country text DEFAULT 'republic'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_perso   record;
  v_convs   jsonb;
  v_elem    jsonb;
  v_marque  boolean;
  v_noms    jsonb := '[]'::jsonb;
BEGIN
  FOR v_perso IN
    SELECT name, convocations
      FROM public.personnages
     WHERE country = p_country
       AND convocations IS NOT NULL
       AND EXISTS (
         SELECT 1 FROM jsonb_array_elements(convocations) c
          WHERE c.value ? 'limiteTs'
            AND COALESCE((c.value->>'traitee')::boolean, false) = false
            AND COALESCE((c.value->>'echue')::boolean, false) = false
            AND now() >= (c.value->>'limiteTs')::timestamptz
       )
     FOR UPDATE
  LOOP
    v_convs  := '[]'::jsonb;
    v_marque := false;

    FOR v_elem IN SELECT value FROM jsonb_array_elements(v_perso.convocations) LOOP
      IF v_elem ? 'limiteTs'
         AND COALESCE((v_elem->>'traitee')::boolean, false) = false
         AND COALESCE((v_elem->>'echue')::boolean, false) = false
         AND now() >= (v_elem->>'limiteTs')::timestamptz
      THEN
        v_elem := v_elem || jsonb_build_object('echue', true, 'echueTs', to_jsonb(now()));
        v_marque := true;
      END IF;
      v_convs := v_convs || jsonb_build_array(v_elem);
    END LOOP;

    IF v_marque THEN
      UPDATE public.personnages SET convocations = v_convs WHERE name = v_perso.name;
      v_noms := v_noms || jsonb_build_array(v_perso.name);

      -- Notification isolee : un echec d'envoi ne doit JAMAIS annuler le verdict (voir la RPC
      -- vendeur ci-dessus pour la meme justification).
      BEGIN
        INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
        VALUES (
          'mail-' || md5(random()::text || clock_timestamp()::text),
          'Commissariat', v_perso.name, 'Non-présentation à convocation',
          'Vous ne vous êtes pas présenté(e) dans le délai de 36 heures qui vous était imparti. '
          || 'Vous serez placé(e) en détention pour deux jours à votre prochaine présence.',
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'), false
        );
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'marques', v_noms);
END;
$function$;

-- assemblee_mettre_en_application(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_mettre_en_application(p_requete text, p_acteur text, p_loi_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej    jsonb;
  v_perso  public.personnages%ROWTYPE;
  v_row    public.assemblee_propositions%ROWTYPE;
  v_cible  public.assemblee_propositions%ROWTYPE;
  v_poste  text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_acteur, 'appliquer');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  -- 1. IDENTITE ET POSTE. Le poste est lu en base, jamais recu du navigateur ; il
  --    est atteste par le trigger des postes.
  SELECT * INTO v_perso FROM public.personnages WHERE name = p_acteur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;
  SELECT pd.poste ->> 'id' INTO v_poste FROM public.personnages_donnees pd WHERE pd.name = p_acteur;
  IF v_poste IS DISTINCT FROM 'min_int' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', false, 'raison', 'reserve_au_ministre_de_l_interieur',
      'poste_reel', coalesce(v_poste, '(aucun)')));
  END IF;

  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_loi_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'introuvable'));
  END IF;
  IF v_row.country IS DISTINCT FROM v_perso.country THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'autre_pays'));
  END IF;

  -- 2. LA LOI EST-ELLE ADOPTEE ?
  IF v_row.statut <> 'adoptee' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', false, 'raison', 'non_adoptee', 'statut', v_row.statut));
  END IF;
  -- 3. Une loi declarative n'a rien a appliquer.
  IF NOT public.assemblee_exige_application(v_row.type) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', false, 'raison', 'type_sans_application', 'type', v_row.type));
  END IF;
  -- 4. Deux fois, jamais.
  IF v_row.appliquee_ts IS NOT NULL THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', false, 'raison', 'deja_appliquee', 'appliquee_ts', v_row.appliquee_ts));
  END IF;

  -- 5. APPLICATION. Le ministre n'a transmis qu'un identifiant : la portee votee
  --    reste celle de data.portee, relue par les gardes. Rien ne vient du client.
  UPDATE public.assemblee_propositions
     SET appliquee_ts = now(), appliquee_par = p_acteur
   WHERE id = p_loi_id
  RETURNING * INTO v_row;

  -- 6. UNE ABROGATION ETEINT SA CIBLE -- au moment de son application, pas de son
  --    adoption. Meme transaction : la cible cesse ses effets a l'instant ou
  --    l'abrogation prend les siens.
  IF v_row.type = 'abrogation' AND v_row.loi_cible_id IS NOT NULL THEN
    UPDATE public.assemblee_propositions
       SET statut = 'abrogee', abrogee_ts = now()
     WHERE id = v_row.loi_cible_id AND statut = 'adoptee' AND country = v_row.country
    RETURNING * INTO v_cible;
  END IF;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true,
    'loi', jsonb_build_object('id', v_row.id, 'titre', v_row.titre, 'type', v_row.type,
                              'categorie', v_row.categorie,
                              'portee', coalesce(v_row.data -> 'portee', '{}'::jsonb),
                              'adoptee_ts', v_row.adoptee_ts, 'appliquee_ts', v_row.appliquee_ts),
    'cible_eteinte', CASE WHEN v_cible.id IS NULL THEN NULL
                          ELSE jsonb_build_object('id', v_cible.id, 'titre', v_cible.titre) END));
END;
$function$;

-- assemblee_neutraliser_depute(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_neutraliser_depute(p_nom text, p_siege_id text, p_mode text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pa      integer;
  v_sous    text[];
  v_rej     jsonb;
  v_perso   public.personnages%ROWTYPE;
  v_siege   public.assemblee_sieges%ROWTYPE;
  v_est_pnj boolean;
  v_debit   jsonb;
  v_dis     numeric;
  v_taux    integer;
  v_jet     integer;
  v_reussi  boolean;
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  IF p_mode = 'mains' THEN v_pa := 1; v_sous := NULL;
  ELSIF p_mode = 'arme' THEN v_pa := 1; v_sous := ARRAY['blanche'];
  ELSIF p_mode = 'feu' THEN v_pa := 2; v_sous := ARRAY['poing', 'carabine'];
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide');
  END IF;

  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'neutraliser');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;

  SELECT * INTO v_siege FROM public.assemblee_sieges WHERE id = p_siege_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'siege_introuvable'));
  END IF;
  IF NOT (v_perso.country = v_siege.country AND v_perso.current_building = 'assemblee'
          AND v_perso.current_room = 'hemicycle') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;

  SELECT o.est_pnj INTO v_est_pnj
    FROM public.assemblee_occupation_sieges(v_siege.country) o WHERE o.siege_id = p_siege_id;
  IF NOT COALESCE(v_est_pnj, false) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'siege_tenu_par_pj'));
  END IF;
  IF v_siege.endormi THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_endormi'));
  END IF;

  -- Possession de l'arme relue dans l'inventaire persiste (neutraliserPossedeArme).
  IF v_sous IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_perso.inventory) = 'array'
                                            THEN v_perso.inventory ELSE '[]'::jsonb END) i
     WHERE i ->> 'type' = 'arme' AND i ->> 'sousType' = ANY (v_sous)
  ) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'arme_manquante'));
  END IF;

  v_debit := public.assemblee_debiter_joueur(p_nom, v_pa, 0);
  IF NOT (v_debit ->> 'ok')::boolean THEN
    RETURN public.assemblee_requete_clore(p_requete, v_debit);
  END IF;

  v_dis := CASE WHEN jsonb_typeof(v_perso.resources -> 'dis') = 'number'
                THEN (v_perso.resources ->> 'dis')::numeric ELSE 0 END;
  IF p_mode = 'feu' THEN
    v_dis := GREATEST(0, v_dis - 20);
    UPDATE public.personnages
       SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END,
                                 '{dis}', to_jsonb(v_dis))
     WHERE name = p_nom;
  END IF;

  v_taux   := public.assemblee_taux_neutralisation(p_mode, v_perso.stats, v_perso.career);
  v_jet    := floor(random() * 100)::integer + 1;
  v_reussi := v_jet <= v_taux;

  IF v_reussi THEN
    UPDATE public.assemblee_sieges
       SET endormi = true, endormi_ts = now(), endormi_par = NULL, updated_at = now()
     WHERE id = p_siege_id AND endormi = false;
  END IF;

  RETURN public.assemblee_requete_clore(p_requete, v_debit || jsonb_build_object(
    'ok', true, 'reussi', v_reussi, 'endormi', v_reussi, 'mode', p_mode,
    'taux', v_taux, 'jet', v_jet, 'dis', v_dis));
END;
$function$;

-- assemblee_objet_vise(text,jsonb,jsonb) -> boolean | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_objet_vise(p_categorie text, p_objet jsonb, p_portee jsonb DEFAULT NULL::jsonb)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH c AS (
    SELECT * FROM public.assemblee_categories_interdiction WHERE categorie = p_categorie
  ), p AS (
    SELECT coalesce((p_portee ->> 'volet_matieres')::boolean, true) AS vm,
           coalesce((p_portee ->> 'volet_objets')::boolean, true)   AS vo,
           CASE WHEN p_portee ? 'sous_types'
                 AND jsonb_typeof(p_portee -> 'sous_types') = 'array'
                THEN ARRAY(SELECT jsonb_array_elements_text(p_portee -> 'sous_types'))
           END AS st
  )
  SELECT EXISTS (
    SELECT 1 FROM c, p
     WHERE ( p.vm
             AND p_objet ->> 'stackKey' IS NOT NULL
             AND (p_objet ->> 'stackKey') = ANY (c.matieres) )
        OR ( p.vo
             AND p_objet ->> 'type' IS NOT NULL
             AND (p_objet ->> 'type') = ANY (c.types_objet)
             AND ( CASE
                     WHEN p.st IS NULL AND cardinality(c.sous_types) = 0 THEN true
                     ELSE (p_objet ->> 'sousType') = ANY (
                            CASE WHEN p.st IS NULL THEN c.sous_types
                                 WHEN cardinality(c.sous_types) = 0 THEN p.st
                                 ELSE ARRAY(SELECT unnest(c.sous_types)
                                            INTERSECT SELECT unnest(p.st))
                            END)
                   END ) )
  );
$function$;

-- assemblee_occupation_sieges(text) -> TABLE(siege_id text, city text, rang integer, pnj_id text, pnj_nom text, endormi boolean, pj_nom text, est_pnj boolean) | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.assemblee_occupation_sieges(p_country text DEFAULT 'republic'::text)
 RETURNS TABLE(siege_id text, city text, rang integer, pnj_id text, pnj_nom text, endormi boolean, pj_nom text, est_pnj boolean)
 LANGUAGE sql
 STABLE
AS $function$
  WITH deputes_pj AS (
    SELECT
      p.name AS pj_nom,
      p.poste_depute->>'city' AS city,
      -- COLLATE "C" : tri par point de code, PAS par collation locale. Le client doit reproduire
      -- ce classement a l'identique (assembleeCalculerOccupation, plateau-assemblee.js) pour
      -- afficher le bon PNJ en assistant parlementaire. Une collation locale (en_US.utf8) classe
      -- "Émile" avant "Fabien", un tri par point de code le classe apres : les deux moteurs
      -- attribueraient alors des rangs differents sur des noms accentues, tres frequents en
      -- francais. COLLATE "C" cote SQL et le tri par defaut de Array.prototype.sort() cote JS
      -- (ordre des unites de code UTF-16) coincident sur tout le plan multilingue de base.
      row_number() OVER (
        PARTITION BY p.poste_depute->>'city'
        ORDER BY p.name COLLATE "C"
      ) AS rang
    FROM public.personnages p
    WHERE p.country = p_country
      AND p.poste_depute IS NOT NULL
      AND p.poste_depute->>'id' = 'depute'
      AND p.poste_depute->>'city' IS NOT NULL
  )
  SELECT
    s.id, s.city, s.rang, s.pnj_id, s.pnj_nom, s.endormi,
    d.pj_nom,
    (d.pj_nom IS NULL) AS est_pnj
  FROM public.assemblee_sieges s
  LEFT JOIN deputes_pj d
    ON d.city = s.city AND d.rang = s.rang
  WHERE s.country = p_country
  ORDER BY s.city, s.rang;
$function$;

-- assemblee_ouvrir_session(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_ouvrir_session(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row public.assemblee_propositions%ROWTYPE;
  v_num integer;
BEGIN
  -- Controle temporel en base, opposable a tout appelant, cron compris.
  IF NOT public.assemblee_fenetre_ouverture(now()) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_fenetre_ouverture');
  END IF;

  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF v_row.statut NOT IN ('debat', 'renvoyee') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible');
  END IF;
  IF now() < v_row.eligible_session_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'semaine_de_debat_non_ecoulee');
  END IF;

  v_num := v_row.session_num + 1;

  UPDATE public.assemblee_propositions
  SET statut = 'session',
      session_num = v_num,
      session_ouverte_ts = now(),
      cloture_ts = public.assemblee_prochaine_cloture(now())
  WHERE id = p_id
  RETURNING * INTO v_row;

  -- §27 : repartir de zero cote PJ. Les votes de la session precedente restent archives dans
  -- assemblee_scrutins ; ce sont les lignes de vote VIVES qui sont supprimees.
  DELETE FROM public.assemblee_votes
  WHERE proposition_id = p_id AND session_num < v_num;

  -- Intention 50/50 pour chaque siege actuellement tenu par son PNJ. Tirage SERVEUR.
  INSERT INTO public.assemblee_intentions (id, proposition_id, session_num, siege_id, intention)
  SELECT
    p_id || ':' || v_num || ':' || o.siege_id,
    p_id, v_num, o.siege_id,
    CASE WHEN random() < 0.5 THEN 'POUR' ELSE 'CONTRE' END
  FROM public.assemblee_occupation_sieges(v_row.country) o
  WHERE o.est_pnj
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row), 'session_num', v_num);
END;
$function$;

-- assemblee_ouvrir_sessions_eligibles(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_ouvrir_sessions_eligibles(p_country text DEFAULT 'republic'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_res  jsonb := '[]'::jsonb;
  v_prop record;
BEGIN
  IF NOT public.assemblee_fenetre_ouverture(now()) THEN
    RETURN jsonb_build_array(jsonb_build_object('ok', false, 'raison', 'hors_fenetre_ouverture'));
  END IF;

  FOR v_prop IN
    SELECT id FROM public.assemblee_propositions
    WHERE country = p_country
      AND statut IN ('debat', 'renvoyee')
      AND now() >= eligible_session_ts
    ORDER BY depose_ts
  LOOP
    v_res := v_res || jsonb_build_array(
      public.assemblee_ouvrir_session(v_prop.id) || jsonb_build_object('id', v_prop.id)
    );
  END LOOP;
  RETURN v_res;
END;
$function$;

-- assemblee_palier_atteint(timestamp with time zone,timestamp with time zone) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_palier_atteint(p_adoptee_ts timestamp with time zone, p_instant timestamp with time zone)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN p_adoptee_ts IS NULL OR p_instant IS NULL THEN 0
    WHEN p_instant < p_adoptee_ts + interval '36 hours' THEN 0
    ELSE 1 + floor(
      extract(epoch FROM (p_instant - (p_adoptee_ts + interval '36 hours'))) / 86400
    )::integer
  END;
$function$;

-- assemblee_peut_deposer(text,text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_peut_deposer(p_nom text, p_country text DEFAULT 'republic'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  RETURN EXISTS (
    SELECT 1 FROM public.personnages p
    WHERE p.name = p_nom
      AND p.country = p_country
      AND (
        (p.poste_depute IS NOT NULL AND p.poste_depute->>'id' = 'depute')
        OR (p.poste IS NOT NULL AND p.poste->>'id' IN
              ('pm','min_int','min_fin','min_just','min_def','min_info','min_ae'))
      )
  );
END;
$function$;

-- assemblee_pop_du_palier(integer) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_pop_du_palier(p_palier integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN p_palier <= 1 THEN -20 ELSE -10 END;
$function$;

-- assemblee_portee_valider(jsonb) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_portee_valider(p_portee jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_cle text; v_val jsonb; v_st jsonb;
BEGIN
  IF p_portee IS NULL OR p_portee = 'null'::jsonb THEN
    RETURN jsonb_build_object('ok', true, 'portee',
             jsonb_build_object('transformation_stock_interdite', false,
                                'volet_matieres', true,
                                'volet_objets', true,
                                'sous_types', null));
  END IF;
  IF jsonb_typeof(p_portee) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'portee_invalide');
  END IF;

  FOR v_cle IN SELECT jsonb_object_keys(p_portee) LOOP
    IF v_cle NOT IN ('transformation_stock_interdite', 'volet_matieres',
                     'volet_objets', 'sous_types') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'portee_cle_inconnue', 'cle', v_cle);
    END IF;
    v_val := p_portee -> v_cle;
    IF v_cle = 'sous_types' THEN
      IF jsonb_typeof(v_val) NOT IN ('array', 'null') THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'portee_valeur_invalide', 'cle', v_cle);
      END IF;
      IF jsonb_typeof(v_val) = 'array' THEN
        IF jsonb_array_length(v_val) = 0 THEN
          RETURN jsonb_build_object('ok', false, 'raison', 'portee_sous_types_vide');
        END IF;
        IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_val) e
                    WHERE jsonb_typeof(e) <> 'string') THEN
          RETURN jsonb_build_object('ok', false, 'raison', 'portee_valeur_invalide', 'cle', v_cle);
        END IF;
      END IF;
    ELSIF jsonb_typeof(v_val) <> 'boolean' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'portee_valeur_invalide', 'cle', v_cle);
    END IF;
  END LOOP;

  v_st := p_portee -> 'sous_types';
  RETURN jsonb_build_object('ok', true, 'portee', jsonb_build_object(
    'transformation_stock_interdite',
      coalesce((p_portee ->> 'transformation_stock_interdite')::boolean, false),
    'volet_matieres', coalesce((p_portee ->> 'volet_matieres')::boolean, true),
    'volet_objets',   coalesce((p_portee ->> 'volet_objets')::boolean, true),
    'sous_types',     CASE WHEN v_st IS NULL OR jsonb_typeof(v_st) = 'null'
                           THEN NULL ELSE v_st END));
END $function$;

-- assemblee_prochaine_cloture(timestamp with time zone) -> timestamp with time zone | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_prochaine_cloture(p_depuis timestamp with time zone)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH l AS (
    SELECT ((p_depuis + interval '1 day') AT TIME ZONE 'Europe/Paris') AS t
  ), c AS (
    SELECT t,
           date_trunc('day', t)
             + (((3 - extract(isodow FROM t)::int) + 7) % 7) * interval '1 day'
             + interval '22 hours' AS cand
      FROM l
  )
  SELECT (CASE WHEN cand > t THEN cand ELSE cand + interval '7 days' END) AT TIME ZONE 'Europe/Paris'
    FROM c;
$function$;

-- assemblee_proposition_immuable() -> trigger | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.assemblee_proposition_immuable()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.texte_original IS DISTINCT FROM OLD.texte_original THEN
    RAISE EXCEPTION 'texte_original_immuable';
  END IF;
  IF NEW.categorie IS DISTINCT FROM OLD.categorie THEN
    RAISE EXCEPTION 'categorie_verrouillee';
  END IF;
  IF NEW.type IS DISTINCT FROM OLD.type THEN
    RAISE EXCEPTION 'type_verrouille';
  END IF;
  IF NEW.auteur IS DISTINCT FROM OLD.auteur THEN
    RAISE EXCEPTION 'auteur_immuable';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$function$;

-- assemblee_registre_execution(text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_registre_execution(p_country text DEFAULT 'republic'::text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(jsonb_agg(s.ligne ORDER BY s.ordre, s.adoptee_ts DESC), '[]'::jsonb)
    FROM (
      SELECT
        CASE WHEN p.appliquee_ts IS NULL THEN 0 ELSE 1 END AS ordre,
        p.adoptee_ts AS adoptee_ts,
        jsonb_build_object(
          'id', p.id,
          'titre', p.titre,
          'type', p.type,
          'categorie', p.categorie,
          'auteur', p.auteur,
          'portee', coalesce(p.data -> 'portee', '{}'::jsonb),
          'adoptee_ts', p.adoptee_ts,
          'appliquee_ts', p.appliquee_ts,
          'appliquee_par', p.appliquee_par,
          'echeance_ts', public.assemblee_echeance_application(p.adoptee_ts),
          'etat', CASE WHEN p.appliquee_ts IS NOT NULL THEN 'appliquee'
                       WHEN now() >= public.assemblee_echeance_application(p.adoptee_ts) THEN 'en_retard'
                       ELSE 'en_attente' END,
          'loi_cible', CASE WHEN p.loi_cible_id IS NULL THEN NULL ELSE (
            SELECT jsonb_build_object('id', c.id, 'titre', c.titre, 'statut', c.statut)
              FROM public.assemblee_propositions c WHERE c.id = p.loi_cible_id) END,
          -- L'instant SERVEUR accompagne chaque ligne : le navigateur ne doit
          -- jamais decider du temps restant avec sa propre horloge.
          'maintenant', now()
        ) AS ligne
        FROM public.assemblee_propositions p
       WHERE p.country = p_country
         AND p.statut = 'adoptee'
         AND public.assemblee_exige_application(p.type)
    ) s;
$function$;

-- assemblee_requete_clore(text,jsonb) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_requete_clore(p_requete text, p_resultat jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.assemblee_requetes SET resultat = p_resultat WHERE id = p_requete;
  RETURN p_resultat;
END;
$function$;

-- assemblee_requete_ouvrir(text,text,text) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_requete_ouvrir(p_requete text, p_nom text, p_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row public.assemblee_requetes%ROWTYPE;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^[A-Za-z0-9_-]{8,80}$' OR COALESCE(btrim(p_nom), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;

  -- L'insertion EST la garde : un doublon concurrent attend ici la fin de la premiere transaction.
  INSERT INTO public.assemblee_requetes (id, personnage, action)
  VALUES (p_requete, p_nom, p_action)
  ON CONFLICT (id) DO NOTHING;
  IF FOUND THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_row FROM public.assemblee_requetes WHERE id = p_requete;
  IF v_row.personnage IS DISTINCT FROM p_nom OR v_row.action IS DISTINCT FROM p_action THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  RETURN COALESCE(v_row.resultat, jsonb_build_object('ok', false, 'raison', 'requete_en_cours'))
         || jsonb_build_object('rejeu', true);
END;
$function$;

-- assemblee_retirer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_retirer(p_id text, p_auteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row   public.assemblee_propositions%ROWTYPE;
  v_perso public.personnages%ROWTYPE;
BEGIN
  PERFORM public.exiger_acteur(p_auteur);
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  SELECT * INTO v_perso FROM public.personnages WHERE name = p_auteur;
  IF NOT FOUND OR NOT (v_perso.country = v_row.country AND v_perso.current_building = 'assemblee'
                       AND v_perso.current_room = 'hemicycle') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_lieu');
  END IF;
  IF v_row.auteur <> p_auteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_auteur');
  END IF;
  IF v_row.statut <> 'debat' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'session_ouverte');
  END IF;

  UPDATE public.assemblee_propositions SET statut = 'retiree' WHERE id = p_id
  RETURNING * INTO v_row;

  RETURN jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row));
END;
$function$;

-- assemblee_retirer_une_unite(jsonb,text) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_retirer_une_unite(p_inventaire jsonb, p_stack_key text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH e AS (
    SELECT t.v, t.o
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_inventaire) = 'array' THEN p_inventaire ELSE '[]'::jsonb END)
           WITH ORDINALITY AS t(v, o)
  ), cible AS (
    SELECT min(o) AS o FROM e
     WHERE v ->> 'stackKey' = p_stack_key
       AND jsonb_typeof(v -> 'qty') = 'number' AND (v ->> 'qty')::numeric > 0
  )
  SELECT COALESCE(
           jsonb_agg(CASE WHEN e.o = cible.o
                          THEN jsonb_set(e.v, '{qty}', to_jsonb((e.v ->> 'qty')::numeric - 1))
                          ELSE e.v END
                     ORDER BY e.o)
             FILTER (WHERE NOT COALESCE(e.o = cible.o AND (e.v ->> 'qty')::numeric - 1 <= 0, false)),
           '[]'::jsonb)
    FROM e CROSS JOIN cible;
$function$;

-- assemblee_reveil_minuit(text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_reveil_minuit(p_country text DEFAULT 'republic'::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_n      integer;
  v_minuit timestamptz;
BEGIN
  v_minuit := date_trunc('day', now() AT TIME ZONE 'Europe/Paris') AT TIME ZONE 'Europe/Paris';

  UPDATE public.assemblee_sieges
  SET endormi = false, endormi_ts = NULL, endormi_par = NULL, updated_at = now()
  WHERE country = p_country
    AND endormi = true
    AND (endormi_ts IS NULL OR endormi_ts < v_minuit);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$function$;

-- assemblee_reveiller_depute(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_reveiller_depute(p_nom text, p_siege_id text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa      CONSTANT integer := 1;
  c_sels    CONSTANT text := 'sels_ammoniaque';
  v_rej     jsonb;
  v_perso   public.personnages%ROWTYPE;
  v_siege   public.assemblee_sieges%ROWTYPE;
  v_est_pnj boolean;
  v_debit   jsonb;
  v_inv     jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'reveiller');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;

  SELECT * INTO v_siege FROM public.assemblee_sieges WHERE id = p_siege_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'siege_introuvable'));
  END IF;
  IF NOT (v_perso.country = v_siege.country AND v_perso.current_building = 'assemblee'
          AND v_perso.current_room = 'hemicycle') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_lieu'));
  END IF;

  SELECT o.est_pnj INTO v_est_pnj
    FROM public.assemblee_occupation_sieges(v_siege.country) o WHERE o.siege_id = p_siege_id;
  IF NOT COALESCE(v_est_pnj, false) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'siege_tenu_par_pj'));
  END IF;
  IF NOT v_siege.endormi THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_eveille'));
  END IF;

  IF public.assemblee_compter_unites(v_perso.inventory, c_sels) < 1 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'sels_manquants'));
  END IF;

  v_debit := public.assemblee_debiter_joueur(p_nom, c_pa, 0);
  IF NOT (v_debit ->> 'ok')::boolean THEN
    RETURN public.assemblee_requete_clore(p_requete, v_debit);
  END IF;

  v_inv := public.assemblee_retirer_une_unite(v_perso.inventory, c_sels);
  UPDATE public.personnages SET inventory = v_inv WHERE name = p_nom;

  UPDATE public.assemblee_sieges
     SET endormi = false, endormi_ts = NULL, endormi_par = NULL, updated_at = now()
   WHERE id = p_siege_id;

  RETURN public.assemblee_requete_clore(p_requete, v_debit || jsonb_build_object(
    'ok', true, 'reveille', true,
    'sels_restants', public.assemblee_compter_unites(v_inv, c_sels)));
END;
$function$;

-- assemblee_sanctionner_lois_non_appliquees(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_sanctionner_lois_non_appliquees(p_country text DEFAULT 'republic'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_loi     record;
  v_palier  integer;
  v_n       integer;
  v_id      text;
  v_delta   integer;
  v_membre  record;
  v_noms    jsonb;
  v_res     jsonb := '[]'::jsonb;
  v_faits   integer := 0;
BEGIN
  -- Reservee au serveur : un joueur ne declenche pas une sanction gouvernementale.
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;

  FOR v_loi IN
    SELECT p.id, p.titre, p.type, p.adoptee_ts
      FROM public.assemblee_propositions p
     WHERE p.country = p_country
       AND p.statut = 'adoptee'
       AND p.appliquee_ts IS NULL
       AND public.assemblee_exige_application(p.type)
       AND p.adoptee_ts IS NOT NULL
       AND now() >= public.assemblee_echeance_application(p.adoptee_ts)
     ORDER BY p.adoptee_ts
  LOOP
    v_palier := public.assemblee_palier_atteint(v_loi.adoptee_ts, now());

    -- RATTRAPAGE. Si la passe n'a pas tourne pendant deux jours, les paliers
    -- manques sont debites l'un apres l'autre -- jamais fusionnes, jamais perdus.
    FOR v_n IN 1 .. v_palier LOOP
      v_id := v_loi.id || ':' || v_n;

      -- L'INSERTION EST LA GARDE. Un rejeu, deux crons concurrents ou un appel
      -- manuel retombent ici : le second n'insere rien et ne debite rien. Un
      -- concurrent attend la fin de la premiere transaction sur cette ligne.
      INSERT INTO public.assemblee_sanctions_paliers
        (id, proposition_id, country, palier, echeance_ts, pop_delta, titulaires)
      VALUES (v_id, v_loi.id, p_country, v_n,
              public.assemblee_echeance_palier(v_loi.adoptee_ts, v_n),
              public.assemblee_pop_du_palier(v_n), '[]'::jsonb)
      ON CONFLICT (id) DO NOTHING;
      IF NOT FOUND THEN
        CONTINUE;   -- palier deja sanctionne : on ne redebite rien
      END IF;

      v_delta := public.assemblee_pop_du_palier(v_n);
      v_noms  := '[]'::jsonb;

      -- LES TITULAIRES DU MOMENT. Relus a chaque palier : un gouvernement nomme
      -- une heure avant le tick prend la sanction, c'est la regle.
      FOR v_membre IN SELECT * FROM public.assemblee_gouvernement_actuel(p_country) LOOP
        -- Primitive canonique : delta, sous verrou, bornes [0,100] respectees.
        PERFORM public.personnage_ajuster_pop_inf(
          NULL, v_membre.nom, v_delta, NULL, 'loi_non_appliquee');
        v_noms := v_noms || jsonb_build_array(
          jsonb_build_object('nom', v_membre.nom, 'poste', v_membre.poste_id));
      END LOOP;

      UPDATE public.assemblee_sanctions_paliers SET titulaires = v_noms WHERE id = v_id;
      v_faits := v_faits + 1;
      v_res := v_res || jsonb_build_array(jsonb_build_object(
        'loi', v_loi.id, 'titre', v_loi.titre, 'palier', v_n,
        'pop', v_delta, 'sanctionnes', jsonb_array_length(v_noms)));
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'paliers_appliques', v_faits, 'detail', v_res);
END $function$;

-- assemblee_sous_types_connus(text) -> text[] | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_sous_types_connus(p_type text)
 RETURNS text[]
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(array_agg(s ORDER BY s), '{}'::text[])
    FROM (
      SELECT i.objet ->> 'sousType' AS s
        FROM public.assemblee_catalogue_illegal i
       WHERE i.objet ->> 'type' = p_type AND i.objet ->> 'sousType' IS NOT NULL
      UNION
      SELECT r.sous_type
        FROM public.recettes_militaires r
       WHERE r.type_objet = p_type AND r.sous_type IS NOT NULL
    ) z;
$function$;

-- assemblee_stat_base(jsonb,text) -> numeric | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_stat_base(p_stats jsonb, p_cle text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN jsonb_typeof(p_stats -> p_cle) = 'number' THEN (p_stats ->> p_cle)::numeric ELSE 8 END;
$function$;

-- assemblee_taux_marchandage(jsonb,boolean) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_taux_marchandage(p_stats jsonb, p_bonus_lobbyiste boolean)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT GREATEST(0, LEAST(66, round(50 + (public.assemblee_stat_base(p_stats, 'CHA')
                                           + public.assemblee_stat_base(p_stats, 'ENT')) / 2)::integer))
         + CASE WHEN p_bonus_lobbyiste THEN 20 ELSE 0 END;
$function$;

-- assemblee_taux_neutralisation(text,jsonb,text) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_taux_neutralisation(p_mode text, p_stats jsonb, p_career text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT GREATEST(0, LEAST(m.cap, round(m.base
           + public.assemblee_stat_base(p_stats, m.stat) * 2
           + CASE WHEN p_career = 'criminal_c' THEN 15 ELSE 0 END
           - 6 / 2.0)::integer))
    FROM (VALUES ('mains', 'FOR', 15, 65), ('arme', 'DUP', 25, 75), ('feu', 'PER', 35, 85))
         AS m(mode, stat, base, cap)
   WHERE m.mode = p_mode;
$function$;

-- assemblee_tracer_vente_interdite(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_tracer_vente_interdite(p_commerce_id text, p_categorie text, p_libelle text, p_country text DEFAULT 'republic'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_vendeur text;
  v_loi     jsonb;
  v_det     jsonb;
BEGIN
  SELECT NULLIF(e.data ->> 'proprietaire', 'PNJ') INTO v_vendeur FROM public.entreprises e WHERE e.id = p_commerce_id;
  IF v_vendeur IS NULL OR btrim(v_vendeur) = '' THEN
    RETURN jsonb_build_object('ok', true, 'vendeur', null, 'raison', 'commerce_pnj_ou_introuvable');
  END IF;

  SELECT jsonb_build_object('id', p.id, 'titre', p.titre, 'categorie', p.categorie, 'adoptee_ts', p.adoptee_ts)
    INTO v_loi
    FROM public.assemblee_propositions p
   WHERE p.country = p_country AND p.type = 'mecanique' AND p.statut = 'adoptee'
     AND p.categorie = p_categorie AND p.adoptee_ts IS NOT NULL AND p.adoptee_ts <= now()
   ORDER BY p.adoptee_ts, p.id LIMIT 1;
  IF v_loi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'categorie_non_interdite');
  END IF;

  v_det := public.assemblee_detecter_partie(v_vendeur, 'vente', v_loi, COALESCE(p_libelle, p_categorie), 1, false);
  IF v_det IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'vendeur', null, 'raison', 'vendeur_introuvable');
  END IF;

  RETURN jsonb_build_object('ok', true, 'detecte', v_det -> 'detecte',
    'convocation_creee', v_det -> 'convocation_creee', 'loi', v_loi ->> 'titre');
END;
$function$;

-- assemblee_transaction_interdite_interne(text,text,text,jsonb,text,integer) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_transaction_interdite_interne(p_country text, p_acheteur text, p_vendeur text, p_objet jsonb, p_libelle text, p_quantite integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_loi     jsonb;
  v_vendeur text;
  v_a       jsonb := NULL;
  v_v       jsonb := NULL;
BEGIN
  v_loi := public.assemblee_loi_en_vigueur(p_country, p_objet, now());
  IF v_loi IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'interdit', false);
  END IF;

  v_vendeur := NULLIF(NULLIF(btrim(COALESCE(p_vendeur, '')), ''), 'PNJ');
  IF v_vendeur IS NOT DISTINCT FROM p_acheteur THEN v_vendeur := NULL; END IF;

  PERFORM 1 FROM public.personnages
   WHERE name IN (p_acheteur, v_vendeur) ORDER BY name FOR UPDATE;

  IF p_acheteur IS NOT NULL THEN
    v_a := public.assemblee_detecter_partie(p_acheteur, 'achat', v_loi, p_libelle, p_quantite, true);
  END IF;
  IF v_vendeur IS NOT NULL THEN
    v_v := public.assemblee_detecter_partie(v_vendeur, 'vente', v_loi, p_libelle, p_quantite, false);
  END IF;

  RETURN jsonb_build_object('ok', true, 'interdit', true, 'loi', v_loi, 'acheteur', v_a, 'vendeur', v_v);
END;
$function$;

-- assemblee_verifier_vente(jsonb,text) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_verifier_vente(p_objets jsonb, p_country text DEFAULT 'republic'::text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH o AS (
    SELECT (t.ord - 1)::integer AS idx,
           public.assemblee_loi_en_vigueur(p_country, t.val, now()) AS loi
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_objets) = 'array' THEN p_objets ELSE '[]'::jsonb END)
           WITH ORDINALITY AS t(val, ord)
  )
  SELECT CASE WHEN jsonb_typeof(p_objets) IS DISTINCT FROM 'array'
    THEN jsonb_build_object('ok', false, 'instant', now(), 'raison', 'objets_invalides', 'interdits', '[]'::jsonb)
    ELSE jsonb_build_object(
           'ok', NOT EXISTS (SELECT 1 FROM o WHERE loi IS NOT NULL),
           'instant', now(),
           'interdits', COALESCE((SELECT jsonb_agg(jsonb_build_object('index', idx, 'loi', loi) ORDER BY idx)
                                    FROM o WHERE loi IS NOT NULL), '[]'::jsonb))
  END;
$function$;

-- assemblee_verser_indemnite(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_verser_indemnite(p_nom text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_montant CONSTANT integer := 250;
  v_perso   public.personnages%ROWTYPE;
  v_jour    date;
  v_id      text;
  v_verse   integer := 0;
  v_credit  jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable', 'montant', 0);
  END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := p_nom || ':' || v_jour::text;

  IF NOT EXISTS (
    SELECT 1 FROM public.assemblee_occupation_sieges(v_perso.country) o WHERE o.pj_nom = p_nom
  ) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute', 'montant', 0);
  END IF;

  BEGIN
    INSERT INTO public.assemblee_indemnites (id, personnage, jour, montant)
    VALUES (v_id, p_nom, v_jour, 0);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_verse_aujourdhui', 'montant', 0);
  END;

  v_verse := public.assemblee_debiter_caisse_plafonne(v_perso.country || '_assemblee', c_montant);
  UPDATE public.assemblee_indemnites SET montant = v_verse WHERE id = v_id;

  v_credit := public.assemblee_crediter_joueur(p_nom, v_verse);

  RETURN v_credit || jsonb_build_object('ok', true, 'montant', v_verse, 'vise', c_montant);
END;
$function$;

-- assemblee_voter(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_voter(p_id text, p_votant text, p_choix text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row   public.assemblee_propositions%ROWTYPE;
  v_perso public.personnages%ROWTYPE;
  v_city  text;
BEGIN
  PERFORM public.exiger_acteur(p_votant);
  IF p_choix IS NULL OR p_choix NOT IN ('POUR', 'CONTRE', 'ABSTENTION') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'choix_invalide');
  END IF;

  -- FOR SHARE : un vote ne chevauche jamais le depouillement (qui prend FOR UPDATE).
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR SHARE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF v_row.statut <> 'session' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_session');
  END IF;
  IF v_row.cloture_ts IS NULL OR now() >= v_row.cloture_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_clos');
  END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_votant;
  IF NOT FOUND OR NOT (v_perso.country = v_row.country AND v_perso.current_building = 'assemblee'
                       AND v_perso.current_room = 'hemicycle') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_lieu');
  END IF;

  -- Le votant doit occuper reellement l'un des neuf sieges MAINTENANT.
  SELECT o.city INTO v_city
    FROM public.assemblee_occupation_sieges(v_row.country) o
   WHERE o.pj_nom = p_votant
   LIMIT 1;
  IF v_city IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute');
  END IF;

  INSERT INTO public.assemblee_votes (id, proposition_id, session_num, votant, city, choix)
  VALUES (p_id || ':' || v_row.session_num || ':' || p_votant, p_id, v_row.session_num, p_votant, v_city, p_choix)
  ON CONFLICT (id) DO UPDATE SET choix = EXCLUDED.choix, updated_at = now();

  RETURN jsonb_build_object('ok', true, 'choix', p_choix);
END;
$function$;

-- depute_presence(text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.depute_presence(p_country text DEFAULT 'republic'::text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('ok', true, 'pays', p_country,
    'sieges', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'siege_id', o.siege_id, 'ville', o.city, 'rang', o.rang,
        -- IDENTITE GAMMA, conservee en toute circonstance.
        'pnj_id', o.pnj_id, 'pnj_nom', o.pnj_nom, 'fonction', 'depute', 'classe', 'gamma',
        -- PRESENCE : 1 present, 0 absent. Derivee, jamais stockee.
        'present', CASE WHEN o.est_pnj THEN 1 ELSE 0 END,
        'occupe_par_pj', o.pj_nom,
        -- L'endormissement est une entrave METIER, distincte de l'absence : un depute endormi est
        -- PRESENT mais empeche de voter. Il ne disparait pas.
        'endormi', COALESCE(o.endormi, false))
      ORDER BY o.city, o.rang)
      FROM public.assemblee_occupation_sieges(p_country) o), '[]'::jsonb),
    'presents', (SELECT count(*) FROM public.assemblee_occupation_sieges(p_country) o WHERE o.est_pnj),
    'absents',  (SELECT count(*) FROM public.assemblee_occupation_sieges(p_country) o
                  WHERE NOT o.est_pnj));
$function$;
