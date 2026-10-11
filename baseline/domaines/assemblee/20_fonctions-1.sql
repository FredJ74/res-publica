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
CREATE OR REPLACE FUNCTION public.assemblee_cloturer_echues(p_country text)
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

-- assemblee_dans_hemicycle(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_dans_hemicycle(p_pays text, p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.acteur_present_sur_site(p_nom, p_pays, 'capitale', 'assemblee', 'hemicycle');
$function$;

-- assemblee_debat_dire(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_debat_dire(p_texte text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_t text; v_id text; v_autorise boolean; v_fonction text; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  -- LA GARDE, AVANT TOUTE ECRITURE.
  SELECT * INTO d FROM public.assemblee_debats WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'id', d.id, 'autorise', d.autorise);
  END IF;

  v_t := nullif(btrim(coalesce(p_texte, '')), '');
  IF v_t IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'texte_vide'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  -- ON NE PARLE PAS DANS UNE SEANCE SUSPENDUE -- pas meme le President : c'est lui qui l'a
  -- suspendue, et il a « Reprendre la seance » pour la rouvrir.
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seance_suspendue'); END IF;

  -- LE PRESIDENT PARLE TOUJOURS DE DROIT : il preside la seance. Un depute, lui, doit etre dans
  -- l'hemicycle -- on ne parle pas en seance depuis le hall.
  IF public.assemblee_president(v_pays) = v_moi THEN
    v_autorise := true; v_fonction := 'president_assemblee';
  ELSIF public.assemblee_est_depute(v_pays, v_moi) THEN
    IF NOT public.assemblee_dans_hemicycle(v_pays, v_moi) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_hemicycle'); END IF;
    v_autorise := EXISTS (SELECT 1 FROM public.assemblee_paroles
                           WHERE pays = v_pays AND depute = v_moi AND a_la_parole);
    v_fonction := 'depute';
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute');
  END IF;

  -- L'IDENTIFIANT EST DERIVE DE LA REQUETE : deuxieme garde, portee par la cle primaire.
  v_id := 'debat-' || left(md5(p_requete), 20);
  INSERT INTO public.assemblee_debats (id, pays, auteur, auteur_fonction, texte, autorise, requete)
  VALUES (v_id, v_pays, v_moi, v_fonction, left(v_t, 4000), v_autorise, p_requete);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'autorise', v_autorise);
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
    PERFORM public.mail_systeme_poser_interne(
        'Commissariat', p_nom, 'Convocation officielle',
        CASE WHEN p_role = 'vente'
          THEN 'Une vente portant sur une marchandise interdite (« ' || (p_loi ->> 'titre') || ' ») a été constatée dans votre commerce. '
          ELSE 'Une transaction portant sur une marchandise interdite (« ' || (p_loi ->> 'titre') || ' ») vous a été imputée. ' END
        || 'Présentez-vous au commissariat sous 36 heures pour vous justifier. '
        || 'Passé ce délai sans vous présenter, vous serez arrêté(e) et détenu(e) deux jours.',
        to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'));
  END IF;

  RETURN jsonb_build_object('role', p_role, 'detecte', v_detecte, 'taux', v_taux, 'jet', v_jet,
    'convocation_creee', v_conv IS NOT NULL, 'trace', v_trace, 'convocation', v_conv, 'dis', v_dis);
END;
$function$;

-- assemblee_discipline_matiere(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_discipline_matiere(p_limite integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_lim integer := least(greatest(coalesce(p_limite,20),1),50);
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT g.pays INTO v_pays FROM public.presse_membres m
    JOIN public.groupes_presse g ON g.id = m.groupe_id
   WHERE m.personnage = v_moi LIMIT 1;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_a_la_redaction'); END IF;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays,
    'actes', (SELECT coalesce(jsonb_agg(x ORDER BY (x->>'fait_le') DESC), '[]'::jsonb) FROM (
      SELECT jsonb_build_object(
               'id', d.id, 'type', d.genre,
               'auteur', d.president, 'auteur_fonction', d.president_fonction,
               'cible', d.cible, 'cible_fonction', d.cible_fonction,
               'motif', d.motif,
               'pop', d.pop_delta, 'amende', d.amende, 'caisse_creditee', d.caisse_creditee,
               'rappel_consomme', d.rappel_id, 'fait_le', d.fait_le) AS x
        FROM public.assemblee_disciplines d WHERE d.pays = v_pays
        ORDER BY d.fait_le DESC LIMIT v_lim) z));
END;
$function$;

-- assemblee_dissoudre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_dissoudre(p_pays text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_id text; v_data jsonb; v_n integer; v_revoques integer;
BEGIN
  -- SEUL LE PRESIDENT DISSOUT. exiger_poste leve pour un client sans le poste, et rend NULL pour
  -- un appel serveur -- le cron n'a pas de personnage et traverse, comme partout ailleurs.
  v_moi := public.exiger_poste('president');

  IF v_moi IS NULL THEN
    IF coalesce(btrim(coalesce(p_pays, '')), '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_manquant');
    END IF;
    v_pays := p_pays;
  ELSE
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
    IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu'); END IF;
    IF p_pays IS NOT NULL AND p_pays <> v_pays THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_hors_autorite');
    END IF;
  END IF;

  -- PREMIERE VAGUE : le drapeau, par COMPARE-AND-SWAP, et AVANT toute revocation.
  v_id := v_pays || '_president';
  SELECT c.data::jsonb INTO v_data FROM public.cycles_electoraux c WHERE c.id = v_id FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_presidentiel_introuvable');
  END IF;
  IF coalesce((v_data ->> 'dissolutionUtilisee')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'dissolution_deja_utilisee');
  END IF;

  UPDATE public.cycles_electoraux
     SET data = jsonb_set(v_data, '{dissolutionUtilisee}', 'true'::jsonb, true)::text,
         updated_at = now()
   WHERE id = v_id
     AND coalesce((data::jsonb ->> 'dissolutionUtilisee')::boolean, false) = false;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'dissolution_deja_utilisee');
  END IF;

  -- DEUXIEME VAGUE : tous les deputes du pays, en UNE instruction, sur la TABLE. La vue
  -- refuserait la fiche d'autrui -- c'est precisement le defaut ferme.
  UPDATE public.personnages_donnees
     SET poste_depute = NULL
   WHERE country = v_pays
     AND poste_depute IS NOT NULL
     AND (poste_depute ->> 'id') = 'depute';
  GET DIAGNOSTICS v_revoques = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'revoques', v_revoques,
    'cycle_president', jsonb_set(v_data, '{dissolutionUtilisee}', 'true'::jsonb, true));
END; $function$;

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

-- assemblee_est_depute(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_est_depute(p_pays text, p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.assemblee_occupation_sieges(p_pays) o
                  WHERE o.pj_nom = p_nom);
$function$;

-- assemblee_est_des_neuf(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_est_des_neuf(p_pays text, p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.assemblee_occupation_sieges(p_pays) o
                  WHERE coalesce(o.pj_nom, o.pnj_nom) = p_nom);
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
CREATE OR REPLACE FUNCTION public.assemblee_marquer_convocations_echues(p_country text)
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

      -- Notification isolee : un echec d'envoi ne doit JAMAIS annuler le verdict. C'est le
      -- poseur systeme qui le garantit maintenant — il ne leve pas et consigne son echec.
      PERFORM public.mail_systeme_poser_interne(
          'Commissariat', v_perso.name, 'Non-présentation à convocation',
          'Vous ne vous êtes pas présenté(e) dans le délai de 36 heures qui vous était imparti. '
          || 'Vous serez placé(e) en détention pour deux jours à votre prochaine présence.',
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'));
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

-- assemblee_occupation_sieges(text) -> TABLE(siege_id text, city text, rang integer, pnj_id text, pnj_nom text, endormi boolean, pj_nom text, est_pnj boolean) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_occupation_sieges(p_country text)
 RETURNS TABLE(siege_id text, city text, rang integer, pnj_id text, pnj_nom text, endormi boolean, pj_nom text, est_pnj boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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
      -- LE MANDAT EST ATTESTE, OU LE SIEGE N'EXISTE PAS (correctif du 11 octobre 2026).
      -- `poste_depute` est une valeur POSEE sur la fiche : le declencheur d'attestation ne la
      -- verifie qu'a l'ECRITURE, donc un mandat acheve y survit tant que la fiche n'est pas
      -- reecrite -- indefiniment pour un joueur deconnecte. On relit donc la regle d'attestation
      -- UNIQUE du projet, qui pour un depute lit `cycles_electoraux.data -> 'elus' ? nom`.
      --
      -- CONSEQUENCE VOULUE, ET C'EST TOUT L'ARBITRAGE : les neuf mandats commencent et finissent
      -- A L'INSTANT ou le cycle de leur ville les liste ou cesse de les lister. Le cycle est
      -- reecrit en UNE ecriture par ville, donc le renouvellement est SIMULTANE par construction
      -- -- il n'y a aucun depute « en cours de sortie ».
      AND public.poste_est_atteste(p.name, p.poste_depute, p.country)
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
CREATE OR REPLACE FUNCTION public.assemblee_ouvrir_sessions_eligibles(p_country text)
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

-- assemblee_parole_demander() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_parole_demander()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_rang integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.assemblee_est_depute(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute'); END IF;
  IF NOT public.assemblee_dans_hemicycle(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_hemicycle'); END IF;
  -- UNE SEANCE SUSPENDUE NE DISTRIBUE PAS LA PAROLE.
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seance_suspendue'); END IF;

  -- IDEMPOTENT PAR CONSTRUCTION : un double clic ne cree pas deux demandes et ne repousse pas la
  -- place deja acquise dans la file. On ne touche a rien si une demande existe.
  IF EXISTS (SELECT 1 FROM public.assemblee_paroles WHERE pays = v_pays AND depute = v_moi) THEN
    SELECT count(*) INTO v_rang FROM public.assemblee_paroles
     WHERE pays = v_pays AND NOT a_la_parole
       AND demande_le <= (SELECT demande_le FROM public.assemblee_paroles
                           WHERE pays = v_pays AND depute = v_moi);
    RETURN jsonb_build_object('ok', true, 'deja_demande', true, 'rang', v_rang);
  END IF;

  INSERT INTO public.assemblee_paroles (pays, depute) VALUES (v_pays, v_moi);
  SELECT count(*) INTO v_rang FROM public.assemblee_paroles WHERE pays = v_pays AND NOT a_la_parole;
  RETURN jsonb_build_object('ok', true, 'rang', v_rang);
END;
$function$;

-- assemblee_parole_donner(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_parole_donner(p_depute text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_premier text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seance_suspendue'); END IF;

  -- LE VERROU EST PRIS SUR LA FILE ENTIERE : deux « donner la parole » concurrents ne peuvent pas
  -- lire le meme premier et produire deux orateurs.
  PERFORM 1 FROM public.assemblee_paroles WHERE pays = v_pays FOR UPDATE;
  SELECT depute INTO v_premier FROM public.assemblee_paroles
   WHERE pays = v_pays AND NOT a_la_parole ORDER BY demande_le, depute LIMIT 1;
  IF v_premier IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'file_vide'); END IF;
  IF p_depute IS NOT NULL AND p_depute <> v_premier THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_premier_de_la_file',
                              'premier', v_premier);
  END IF;
  IF EXISTS (SELECT 1 FROM public.assemblee_paroles WHERE pays = v_pays AND a_la_parole) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'un_orateur_a_deja_la_parole'); END IF;

  UPDATE public.assemblee_paroles SET a_la_parole = true, donnee_le = clock_timestamp()
   WHERE pays = v_pays AND depute = v_premier;
  RETURN jsonb_build_object('ok', true, 'orateur', v_premier);
END;
$function$;

-- assemblee_parole_retirer() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_parole_retirer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_orateur text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seance_suspendue'); END IF;

  SELECT depute INTO v_orateur FROM public.assemblee_paroles
   WHERE pays = v_pays AND a_la_parole FOR UPDATE;
  IF v_orateur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_orateur'); END IF;

  DELETE FROM public.assemblee_paroles WHERE pays = v_pays AND depute = v_orateur;
  RETURN jsonb_build_object('ok', true, 'retire', v_orateur);
END;
$function$;

-- assemblee_parti_de(text,text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_parti_de(p_pays text, p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT o.id FROM public.organisations o
   CROSS JOIN LATERAL (SELECT CASE WHEN o.data IS JSON OBJECT
                                   THEN o.data::jsonb ELSE '{}'::jsonb END AS d) j
   WHERE j.d ->> 'type' = 'politique'
     AND coalesce(j.d ->> 'country', o.country_origine) = p_pays
     AND EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(j.d -> 'membres', '[]'::jsonb)) m
                  WHERE m ->> 'nom' = p_nom)
   LIMIT 1;
$function$;

-- assemblee_peut_deposer(text,text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_peut_deposer(p_nom text, p_country text)
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

-- assemblee_presidence_convoquer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_presidence_convoquer(p_pays text, p_cause text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text; v_cloture timestamptz; v_elig jsonb; v_pres text; v_n integer := 0;
  v_d record; v_heure text;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF coalesce(p_cause,'') NOT IN ('renouvellement','deux_boycotts') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cause_inconnue');
  END IF;
  -- LE CALENDRIER EST UNE REGLE DE BASE. Sans elle, un cron quotidien ouvrirait une election par
  -- jour -- celle du lundi venant de se clore a 23 heures.
  IF NOT public.assemblee_presidence_fenetre_convocation(now()) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_fenetre_convocation');
  END IF;

  IF EXISTS (SELECT 1 FROM public.assemblee_presidence_scrutins
              WHERE pays = p_pays AND statut = 'ouvert') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_deja_ouvert');
  END IF;
  -- UN SEUL SCRUTIN PAR LUNDI. Deux passes du cron le meme jour ne doivent pas rouvrir une
  -- election qui vient d'etre depouillee -- ni effacer son resultat.
  IF EXISTS (SELECT 1 FROM public.assemblee_presidence_scrutins
              WHERE pays = p_pays
                AND (ouvert_le AT TIME ZONE 'Europe/Paris')::date
                    = (now() AT TIME ZONE 'Europe/Paris')::date) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_deja_tenu_aujourd_hui');
  END IF;

  -- LES NEUF, FIGES A L'OUVERTURE. Si un siege change de main pendant la semaine, le scrutin garde
  -- la liste devant laquelle les deputes ont vote : on ne deplace pas les regles en cours de route.
  SELECT coalesce(jsonb_agg(jsonb_build_object('depute', e.depute, 'ville', e.ville,
                                               'rang', e.rang, 'est_pnj', e.est_pnj)
                            ORDER BY e.ville, e.rang), '[]'::jsonb)
    INTO v_elig FROM public.assemblee_presidence_eligibles(p_pays) e;
  IF jsonb_array_length(v_elig) <> 9 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'composition_incomplete',
                              'sieges', jsonb_array_length(v_elig));
  END IF;

  v_cloture := public.assemblee_presidence_prochaine_cloture();
  v_pres := public.assemblee_president(p_pays);
  v_id := 'presidence-' || p_pays || '-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISS');

  INSERT INTO public.assemblee_presidence_scrutins
    (id, pays, cause, cloture_ts, eligibles, president_sortant)
  VALUES (v_id, p_pays, p_cause, v_cloture, v_elig, v_pres);

  -- L'ELECTION EXCEPTIONNELLE EN ATTENTE EST HONOREE PAR CELLE-CI, quelle que soit sa cause : la
  -- presidence vient d'etre remise en jeu, il n'y a plus rien a rattraper.
  UPDATE public.assemblee_presidence_dues
     SET honore_le = clock_timestamp(), scrutin_id = v_id
   WHERE pays = p_pays AND honore_le IS NULL;

  -- LE COURRIER DE CONVOCATION. Il part aux neuf -- mais seuls les deputes JOUEURS ont une boite :
  -- les PNJ n'ont aucune fiche de personnage, et leur ecrire serait ecrire a personne.
  v_heure := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  FOR v_d IN SELECT e.depute, e.ville FROM public.assemblee_presidence_eligibles(p_pays) e
              WHERE NOT e.est_pnj
  LOOP
    PERFORM public.mail_systeme_poser_interne(
      'Secrétariat de l''Assemblée nationale', v_d.depute,
      'Convocation — élection du Président de l''Assemblée',
      'L''Assemblée nationale élit son Président. Les neuf députés sont éligibles : vous pouvez '
      || 'voter pour n''importe lequel d''entre eux, y compris vous-même. Le scrutin est ouvert '
      || 'jusqu''au lundi 23h00, à un seul tour, et le décompte est visible pendant toute sa '
      || 'durée. En cas d''égalité en tête, le départage se fera à la courte paille.',
      v_heure);
    v_n := v_n + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'scrutin', v_id, 'cause', p_cause,
                            'cloture_ts', v_cloture, 'convoques', v_n,
                            'eligibles', jsonb_array_length(v_elig));
END;
$function$;

-- assemblee_presidence_depouiller(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_presidence_depouiller(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  s record; v_max integer; v_tete jsonb; v_elu text; v_pnj boolean;
  v_decompte jsonb; v_chron text; v_heure text; v_d record; v_sortant text;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;

  SELECT * INTO s FROM public.assemblee_presidence_scrutins
   WHERE pays = p_pays AND statut = 'ouvert' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'depouille', false, 'raison', 'aucun_scrutin_ouvert');
  END IF;
  IF now() < s.cloture_ts THEN
    RETURN jsonb_build_object('ok', true, 'depouille', false, 'raison', 'pas_encore_echu',
                              'cloture_ts', s.cloture_ts);
  END IF;

  -- LE DECOMPTE PORTE SUR LES NEUF, zero voix comprise : un eligible sans voix doit apparaitre,
  -- sinon l'egalite a zero serait invisible.
  SELECT coalesce(jsonb_agg(jsonb_build_object('depute', x.depute, 'voix', x.voix)
                            ORDER BY x.voix DESC, x.depute), '[]'::jsonb)
    INTO v_decompte
    FROM (SELECT e ->> 'depute' AS depute,
                 (SELECT count(*) FROM public.assemblee_presidence_bulletins b
                   WHERE b.scrutin_id = s.id AND b.pour = e ->> 'depute')::integer AS voix
            FROM jsonb_array_elements(s.eligibles) e) x;

  SELECT max((d ->> 'voix')::integer) INTO v_max FROM jsonb_array_elements(v_decompte) d;
  SELECT coalesce(jsonb_agg(d ->> 'depute' ORDER BY d ->> 'depute'), '[]'::jsonb)
    INTO v_tete FROM jsonb_array_elements(v_decompte) d WHERE (d ->> 'voix')::integer = v_max;

  IF jsonb_array_length(v_tete) = 1 THEN
    v_elu := v_tete ->> 0;
    v_tete := NULL;                       -- aucune egalite : rien a tirer, rien a rejouer
  ELSE
    -- LA COURTE PAILLE, TIREE PAR LE SERVEUR. Le resultat est ecrit ici et ne bougera plus.
    SELECT t INTO v_elu FROM jsonb_array_elements_text(v_tete) t ORDER BY random() LIMIT 1;
  END IF;

  SELECT e.est_pnj INTO v_pnj FROM public.assemblee_presidence_eligibles(p_pays) e
   WHERE e.depute = v_elu;
  v_sortant := public.assemblee_president(p_pays);
  v_chron := 'chronique-presidence-' || s.id;

  -- LA PROCLAMATION : le registre des postes nommes change de titulaire. C'est la SEULE ligne que
  -- la seance regarde -- les pouvoirs suivent donc immediatement, et l'ancien President les perd
  -- dans la meme transaction. Son siege de depute, lui, ne vient pas d'ici et reste intact.
  DELETE FROM public.postes_attribues
   WHERE country = p_pays AND poste_id = 'president_assemblee' AND city IS NULL;
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('presidence-assemblee-' || p_pays, p_pays, 'president_assemblee', NULL, v_elu,
          'election_assemblee');

  UPDATE public.assemblee_presidence_scrutins
     SET statut = 'clos', elu = v_elu, elu_est_pnj = coalesce(v_pnj, true),
         egalite = v_tete, decompte = v_decompte,
         clos_le = clock_timestamp(), chronique_id = v_chron
   WHERE id = s.id;

  -- LA TRACE PUBLIQUE EST FACTUELLE : qui a ete elu, avec combien de voix, et s'il a fallu tirer.
  -- Aucune appreciation, aucun commentaire.
  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref)
  VALUES (v_chron, p_pays, 'assemblee_presidence', 'capitale',
          jsonb_build_array(v_elu) || coalesce(jsonb_build_array(v_sortant), '[]'::jsonb),
          v_elu || ' est elu President de l''Assemblee nationale'
          || CASE WHEN v_tete IS NULL THEN '.' ELSE ' apres un tirage a la courte paille.' END,
          jsonb_build_object('scrutin', s.id, 'cause', s.cause, 'elu', v_elu,
                             'voix', v_max, 'decompte', v_decompte, 'egalite', v_tete,
                             'president_sortant', v_sortant),
          s.id);

  -- LE RESULTAT PAR COURRIER AUX DEPUTES JOUEURS. Les PNJ n'ont pas de boite.
  v_heure := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  FOR v_d IN SELECT e.depute FROM public.assemblee_presidence_eligibles(p_pays) e
              WHERE NOT e.est_pnj
  LOOP
    PERFORM public.mail_systeme_poser_interne(
      'Secrétariat de l''Assemblée nationale', v_d.depute,
      'Résultat — élection du Président de l''Assemblée',
      v_elu || ' est élu Président de l''Assemblée nationale avec ' || v_max || ' voix'
      || CASE WHEN v_tete IS NULL THEN '.'
              ELSE ', après un départage à la courte paille entre '
                   || jsonb_array_length(v_tete) || ' députés à égalité.' END,
      v_heure);
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'depouille', true, 'scrutin', s.id,
                            'elu', v_elu, 'elu_est_pnj', coalesce(v_pnj, true),
                            'voix', v_max, 'egalite', v_tete, 'decompte', v_decompte,
                            'president_sortant', v_sortant);
END;
$function$;

-- assemblee_presidence_eligibles(text) -> TABLE(depute text, ville text, rang integer, est_pnj boolean) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_presidence_eligibles(p_pays text)
 RETURNS TABLE(depute text, ville text, rang integer, est_pnj boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(o.pj_nom, o.pnj_nom), o.city, o.rang, o.est_pnj
    FROM public.assemblee_occupation_sieges(p_pays) o
   ORDER BY o.city, o.rang;
$function$;

-- assemblee_presidence_etat() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_presidence_etat()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; s record; v_depute boolean; v_revoir jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_depute := public.assemblee_est_depute(v_pays, v_moi);

  SELECT * INTO s FROM public.assemblee_presidence_scrutins
   WHERE pays = v_pays AND statut = 'ouvert';

  SELECT to_jsonb(z) INTO v_revoir FROM (
    SELECT c.id, c.elu, c.egalite, c.decompte, c.cause, c.clos_le, c.eligibles
      FROM public.assemblee_presidence_scrutins c
     WHERE c.pays = v_pays AND c.statut = 'clos' AND c.egalite IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.assemblee_presidence_tirage_vu v
                        WHERE v.scrutin_id = c.id AND v.personnage = v_moi)
     ORDER BY c.clos_le DESC LIMIT 1) z;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays,
    'je_suis_depute', v_depute,
    -- §5 : LA MEME LECTURE QUE CELLE DE LA PORTE. L'ecran n'en deduit aucun droit ; il s'en sert
    -- pour expliquer, et c'est tout.
    'je_suis_dans_hemicycle', public.assemblee_dans_hemicycle(v_pays, v_moi),
    'president', public.assemblee_president(v_pays),
    'eligibles', (SELECT coalesce(jsonb_agg(jsonb_build_object('depute', e.depute,
                           'ville', e.ville, 'rang', e.rang, 'est_pnj', e.est_pnj)
                         ORDER BY e.ville, e.rang), '[]'::jsonb)
                    FROM public.assemblee_presidence_eligibles(v_pays) e),
    'scrutin', CASE WHEN s.id IS NULL THEN NULL ELSE jsonb_build_object(
        'id', s.id, 'cause', s.cause, 'ouvert_le', s.ouvert_le, 'cloture_ts', s.cloture_ts,
        'eligibles', s.eligibles,
        'mon_bulletin', (SELECT b.pour FROM public.assemblee_presidence_bulletins b
                          WHERE b.scrutin_id = s.id AND b.votant = v_moi),
        -- LE DECOMPTE EN DIRECT, zero voix comprise : sans les zeros, l'egalite serait illisible.
        'decompte', (SELECT coalesce(jsonb_agg(jsonb_build_object('depute', x.depute, 'voix', x.voix)
                             ORDER BY x.voix DESC, x.depute), '[]'::jsonb)
                       FROM (SELECT e ->> 'depute' AS depute,
                                    (SELECT count(*) FROM public.assemblee_presidence_bulletins b
                                      WHERE b.scrutin_id = s.id AND b.pour = e ->> 'depute')::integer AS voix
                               FROM jsonb_array_elements(s.eligibles) e) x),
        'bulletins', (SELECT count(*) FROM public.assemblee_presidence_bulletins b
                       WHERE b.scrutin_id = s.id)) END,
    'a_revoir', v_revoir,
    -- UNE ELECTION EXCEPTIONNELLE EST-ELLE DUE ? Un fait, pas une menace.
    'election_due', (SELECT to_jsonb(y) FROM (
        SELECT u.cause, u.du_le FROM public.assemblee_presidence_dues u
         WHERE u.pays = v_pays AND u.honore_le IS NULL LIMIT 1) y));
END;
$function$;

-- assemblee_presidence_fenetre_convocation(timestamp with time zone) -> boolean | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_presidence_fenetre_convocation(p_instant timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT extract(isodow FROM (p_instant AT TIME ZONE 'Europe/Paris')) = 1;
$function$;

-- assemblee_presidence_fin_de_legislature(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_presidence_fin_de_legislature(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_sortis jsonb := '[]'::jsonb;
BEGIN
  IF p_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_absent');
  END IF;

  FOR r IN
    SELECT a.id, a.titulaire, a.depuis FROM public.postes_attribues a
     WHERE a.country = p_pays AND a.poste_id = 'president_assemblee' AND a.city IS NULL
       AND NOT public.assemblee_est_des_neuf(p_pays, a.titulaire)
     FOR UPDATE
  LOOP
    DELETE FROM public.postes_attribues WHERE id = r.id;
    v_sortis := v_sortis || jsonb_build_object('ancien_president', r.titulaire, 'depuis', r.depuis);
  END LOOP;

  RETURN jsonb_build_object('ok', true,
    'sortis', jsonb_array_length(v_sortis), 'detail', v_sortis,
    'president', public.assemblee_president(p_pays));
END;
$function$;

-- assemblee_presidence_prochaine_cloture() -> timestamp with time zone | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_presidence_prochaine_cloture()
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_local timestamp; v_cible timestamp;
BEGIN
  v_local := now() AT TIME ZONE 'Europe/Paris';
  -- le lundi de la semaine courante a 23h00 (isodow : 1 = lundi)
  v_cible := date_trunc('day', v_local)
             - make_interval(days => extract(isodow from v_local)::integer - 1)
             + interval '23 hours';
  IF v_cible <= v_local THEN v_cible := v_cible + interval '7 days'; END IF;
  RETURN v_cible AT TIME ZONE 'Europe/Paris';
END;
$function$;

-- assemblee_presidence_tirage_vu(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_presidence_tirage_vu(p_scrutin_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.assemblee_presidence_scrutins
                  WHERE id = p_scrutin_id AND statut = 'clos') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_inconnu'); END IF;

  INSERT INTO public.assemblee_presidence_tirage_vu (scrutin_id, personnage)
  VALUES (p_scrutin_id, v_moi)
  ON CONFLICT (scrutin_id, personnage) DO NOTHING;
  RETURN jsonb_build_object('ok', true, 'scrutin', p_scrutin_id);
END;
$function$;

-- assemblee_presidence_voter(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_presidence_voter(p_pour text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; s record; d record; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  -- LA GARDE, AVANT TOUTE ECRITURE : une reponse perdue et rejouee ne depose pas deux bulletins.
  SELECT * INTO d FROM public.assemblee_presidence_bulletins WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'pour', d.pour);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.assemblee_est_depute(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute'); END IF;

  -- §5 : LA PRESENCE PHYSIQUE, LUE EN BASE. Le hall ne suffit pas, et la convocation du lundi
  -- cesse d'etre une formalite : il faut etre assis dans l'hemicycle pour elire son President.
  IF NOT public.assemblee_dans_hemicycle(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_hemicycle'); END IF;

  SELECT * INTO s FROM public.assemblee_presidence_scrutins
   WHERE pays = v_pays AND statut = 'ouvert' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_scrutin_ouvert'); END IF;
  -- L'HEURE DU SERVEUR, ET ELLE SEULE. Un bulletin arrive apres 23h00 est refuse meme si le
  -- depouillement n'a pas encore tourne.
  IF now() >= s.cloture_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_clos', 'cloture_ts', s.cloture_ts); END IF;

  -- LE NOM VOTE DOIT ETRE L'UN DES NEUF FIGES A L'OUVERTURE. C'est ce qui interdit d'elire un
  -- dixieme parlementaire, ou quelqu'un qui n'est pas depute du tout.
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(s.eligibles) e
                  WHERE e ->> 'depute' = p_pour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_eligible', 'pour', p_pour); END IF;

  -- UN SEUL BULLETIN. Le double vote est REFUSE, et la voix deja deposee reste celle qui compte.
  IF EXISTS (SELECT 1 FROM public.assemblee_presidence_bulletins
              WHERE scrutin_id = s.id AND votant = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_vote'); END IF;

  INSERT INTO public.assemblee_presidence_bulletins (scrutin_id, votant, pour, requete)
  VALUES (s.id, v_moi, p_pour, p_requete);

  SELECT count(*) INTO v_n FROM public.assemblee_presidence_bulletins WHERE scrutin_id = s.id;
  RETURN jsonb_build_object('ok', true, 'scrutin', s.id, 'pour', p_pour, 'bulletins', v_n);
END;
$function$;

-- assemblee_president(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_president(p_pays text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- L'INVARIANT, ECRIT LA OU TOUT LE MONDE LE LIT : un President de l'Assemblee est l'un des
  -- neuf deputes de la legislature en cours. Le registre des postes nomme un titulaire ; cette
  -- fonction ne le rend que s'il siege encore. Un ancien depute ne preside donc RIEN, et il n'y
  -- a aucune periode a couvrir : la presidence tombe dans la meme lecture que le mandat.
  SELECT a.titulaire FROM public.postes_attribues a
   WHERE a.country = p_pays AND a.poste_id = 'president_assemblee' AND a.city IS NULL
     AND public.assemblee_est_des_neuf(p_pays, a.titulaire)
   LIMIT 1;
$function$;

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

-- assemblee_protester() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_protester()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_pres text; v_parti text;
  v_disc text; v_motif text; v_etat jsonb; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_pays := a.country;
  IF NOT public.assemblee_est_depute(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute'); END IF;
  IF NOT (a.current_building = 'assemblee' AND a.current_room = 'hemicycle') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_hemicycle'); END IF;

  v_pres  := public.assemblee_president(v_pays);
  v_parti := public.assemblee_parti_de(v_pays, v_moi);

  -- A. UN ACTE SUBI PAR LUI-MEME, sous la presidence en cours.
  SELECT d.id INTO v_disc FROM public.assemblee_disciplines d
   WHERE d.pays = v_pays AND d.cible = v_moi
     AND (v_pres IS NULL OR d.president = v_pres)
   ORDER BY d.fait_le DESC LIMIT 1;
  IF v_disc IS NOT NULL THEN v_motif := 'soi_meme'; END IF;

  -- B. UN ACTE SUBI PAR UN DEPUTE DE SON PARTI. Le parti est relu en base pour les DEUX cotes --
  -- celui du protestataire et celui de la victime -- et jamais recu du navigateur.
  IF v_motif IS NULL AND v_parti IS NOT NULL THEN
    SELECT d.id INTO v_disc FROM public.assemblee_disciplines d
     WHERE d.pays = v_pays AND (v_pres IS NULL OR d.president = v_pres)
       AND public.assemblee_parti_de(v_pays, d.cible) = v_parti
     ORDER BY d.fait_le DESC LIMIT 1;
    IF v_disc IS NOT NULL THEN v_motif := 'parti'; END IF;
  END IF;

  -- LE DEPLACEMENT REEL, et il est le meme pour tous : qualifie ou pas, on sort.
  UPDATE public.personnages_donnees SET current_room = 'accueil_assemblee' WHERE name = v_moi;

  INSERT INTO public.assemblee_protestations (pays, depute, qualifie, motif_qualifiant, discipline_id)
  VALUES (v_pays, v_moi, v_motif IS NOT NULL, v_motif, v_disc)
  ON CONFLICT (pays, depute) DO UPDATE
    SET qualifie = EXCLUDED.qualifie, motif_qualifiant = EXCLUDED.motif_qualifiant,
        discipline_id = EXCLUDED.discipline_id;

  v_etat := public.assemblee_recalculer_suspension(v_pays);
  RETURN jsonb_build_object('ok', true, 'qualifie', v_motif IS NOT NULL, 'motif', v_motif,
                            'parti', v_parti, 'piece', 'accueil_assemblee', 'seance', v_etat);
END;
$function$;

-- assemblee_rappeler(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_rappeler(p_depute text, p_motif text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_RAPPEL constant integer := -15;
  v_moi text; v_pays text; v_m text; v_id text; v_chron text; v_pop jsonb; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  SELECT * INTO d FROM public.assemblee_disciplines WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'rappel', d.id, 'cible', d.cible, 'pop', d.pop_delta);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seance_suspendue'); END IF;
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_obligatoire'); END IF;
  IF p_depute IS NULL OR p_depute = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF NOT public.assemblee_est_depute(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_pas_deputee'); END IF;
  IF NOT public.assemblee_dans_hemicycle(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente_de_l_hemicycle'); END IF;

  v_pop := public.personnage_ajuster_pop_inf(v_moi, p_depute, POP_RAPPEL, NULL, 'assemblee_rappel');
  IF coalesce((v_pop->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'assemblee_rappel_popularite_refusee: %', coalesce(v_pop->>'raison', 'inconnue');
  END IF;

  v_id    := 'rappel-' || left(md5(p_requete), 20);
  v_chron := 'chronique-assemblee_rappel-' || left(md5(p_requete), 20);

  INSERT INTO public.assemblee_disciplines
    (id, pays, genre, president, president_fonction, cible, cible_fonction, motif, pop_delta,
     chronique_id, requete)
  VALUES (v_id, v_pays, 'rappel', v_moi, 'president_assemblee', p_depute, 'depute', v_m,
          POP_RAPPEL, v_chron, p_requete);

  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref)
  VALUES (v_chron, v_pays, 'assemblee_rappel', 'capitale',
          jsonb_build_array(v_moi, p_depute),
          'Le President de l''Assemblee a rappele ' || p_depute || ' au reglement.',
          jsonb_build_object('president', v_moi, 'cible', p_depute, 'motif', v_m,
                             'pop', POP_RAPPEL, 'discipline', v_id),
          v_id);

  RETURN jsonb_build_object('ok', true, 'rappel', v_id, 'cible', p_depute,
                            'pop', POP_RAPPEL, 'pop_cible', v_pop -> 'pop');
END;
$function$;

-- assemblee_recalculer_suspension(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_recalculer_suspension(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  SEUIL constant integer := 5;
  v_qualifies integer; v_dehors integer; v_ouvert text; v_id text; v_pres text;
  v_episodes integer; v_due boolean := false;
BEGIN
  SELECT count(*) FILTER (WHERE qualifie), count(*)
    INTO v_qualifies, v_dehors
    FROM public.assemblee_protestations WHERE pays = p_pays;

  SELECT id INTO v_ouvert FROM public.assemblee_suspensions
   WHERE pays = p_pays AND cause = 'boycott' AND close_le IS NULL FOR UPDATE;

  IF v_ouvert IS NOT NULL AND v_qualifies < SEUIL THEN
    -- clock_timestamp() et non now() : la fermeture doit etre POSTERIEURE aux sorties inscrites
    -- dans la meme transaction, sinon le test de dissolution complete ci-dessous ne tranche plus.
    UPDATE public.assemblee_suspensions SET close_le = clock_timestamp() WHERE id = v_ouvert;
    v_ouvert := NULL;
  ELSIF v_ouvert IS NULL AND v_qualifies >= SEUIL THEN
    -- DISSOLUTION COMPLETE EXIGEE : s'il reste un protestataire qualifie depuis l'episode
    -- precedent, on est dans le MEME boycott et on ne l'ouvre pas une seconde fois. 5 -> 4 -> 5,
    -- 5 -> 3 -> 1 -> 5 : meme episode. Seul un retour a ZERO le termine.
    IF EXISTS (SELECT 1 FROM public.assemblee_suspensions s
                WHERE s.pays = p_pays AND s.cause = 'boycott' AND s.close_le IS NOT NULL
                  AND EXISTS (SELECT 1 FROM public.assemblee_protestations p
                               WHERE p.pays = p_pays AND p.qualifie
                                 AND p.sorti_le < s.close_le)) THEN
      NULL;   -- meme boycott : aucun episode neuf
    ELSE
      v_pres := public.assemblee_president(p_pays);
      v_id := 'suspension-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSUS');
      INSERT INTO public.assemblee_suspensions (id, pays, cause, president, protestataires)
      VALUES (v_id, p_pays, 'boycott', v_pres,
              (SELECT coalesce(jsonb_agg(depute ORDER BY depute), '[]'::jsonb)
                 FROM public.assemblee_protestations
                WHERE pays = p_pays AND qualifie));
      v_ouvert := v_id;

      -- LE DEUXIEME EPISODE DISTINCT SOUS UNE MEME PRESIDENCE REMET LA PRESIDENCE EN JEU. On
      -- inscrit que l'election est DUE ; la convocation du lundi l'ouvrira. Ouvrir le scrutin ici
      -- reviendrait a declencher une election dans la transaction du clic d'un depute.
      SELECT count(*) INTO v_episodes FROM public.assemblee_suspensions s
       WHERE s.pays = p_pays AND s.cause = 'boycott'
         AND s.president IS NOT DISTINCT FROM v_pres;
      IF v_episodes >= 2
         AND NOT EXISTS (SELECT 1 FROM public.assemblee_presidence_dues u
                          WHERE u.pays = p_pays AND u.honore_le IS NULL) THEN
        INSERT INTO public.assemblee_presidence_dues (id, pays, cause, episode_id)
        VALUES ('due-' || p_pays || '-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSUS'),
                p_pays, 'deux_boycotts', v_id);
        v_due := true;
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object('suspendue', v_ouvert IS NOT NULL, 'episode', v_ouvert,
                            'qualifies', v_qualifies, 'dehors', v_dehors, 'seuil', SEUIL,
                            'election_presidentielle_due', v_due);
END;
$function$;

-- assemblee_regards(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_regards(p_jours integer DEFAULT 7)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_jour integer;
  v_fen integer := least(greatest(coalesce(p_jours, 7), 1), 30);
  v_depuis integer; v_scrutins jsonb; v_passages jsonb; v_ensemble jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- LE PAYS N'EST PAS RECU DU NAVIGATEUR, il est relu en base : une Renee de Republia ne raconte
  -- pas ce qui s'est passe dans l'Assemblee d'un autre empire. Meme regle que
  -- `presidence_memoire_mon_pays`, posee le matin meme pour exactement ce motif.
  SELECT coalesce(country, 'republic'), coalesce(day, 1) INTO v_pays, v_jour
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu');
  END IF;
  v_depuis := greatest(v_jour - v_fen, 0);

  -- LES SCRUTINS CLOS. Nominatifs, tels que la cloture du mercredi les a archives.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'titre', s.titre, 'resultat', s.resultat, 'session', s.session_num,
           'pour', s.pour, 'contre', s.contre, 'abstention', s.abstention,
           'non_votants', s.non_votants, 'endormis', s.endormis,
           'clos_le', s.cloture_ts) ORDER BY s.cloture_ts DESC), '[]'::jsonb)
    INTO v_scrutins
    FROM (SELECT * FROM public.assemblee_scrutins WHERE country = v_pays
           ORDER BY cloture_ts DESC LIMIT 5) s;

  -- LES PASSAGES. Un joueur, le nombre de fois qu'il est entre, les pieces ou Renee l'a croise, et
  -- la derniere fois. `poste_actuel` est son poste AUJOURD'HUI -- pas necessairement celui qu'il
  -- avait ce jour-la : le journal des passages ne garde pas la fonction du moment.
  --
  -- `raison_institutionnelle` N'EST PAS UN JUGEMENT : c'est la reponse a une question factuelle --
  -- cette personne a-t-elle une raison officielle de venir ici ? La liste est celle que
  -- `assemblee_peut_deposer` applique reellement (depute, Premier ministre, ministres), plus
  -- l'appartenance a un groupe de presse, qui est le titre du correspondant parlementaire. Le
  -- President n'y figure pas, et ce n'est pas un oubli : il n'est pas eligible au depot.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'qui', q.name, 'passages', q.n, 'pieces', q.pieces,
           'dernier_jour', q.dernier_jour, 'derniere_heure', q.derniere_heure,
           'poste_actuel', q.poste_actuel,
           'raison_institutionnelle', q.raison) ORDER BY q.n DESC, q.name), '[]'::jsonb)
    INTO v_passages
    FROM (
      SELECT h.name, count(*)::int AS n,
             (SELECT jsonb_agg(DISTINCT h2.room_id) FROM public.historique_deplacements h2
               WHERE h2.country = v_pays AND h2.building_id = 'assemblee'
                 AND h2.jour >= v_depuis AND h2.name = h.name) AS pieces,
             max(h.jour) AS dernier_jour,
             (SELECT h3.heure FROM public.historique_deplacements h3
               WHERE h3.country = v_pays AND h3.building_id = 'assemblee' AND h3.name = h.name
               ORDER BY h3.created_at DESC LIMIT 1) AS derniere_heure,
             (SELECT coalesce(pd.poste->>'id', pd.poste_depute->>'id')
                FROM public.personnages_donnees pd WHERE pd.name = h.name) AS poste_actuel,
             (SELECT coalesce((pd.poste_depute->>'id') = 'depute', false)
                  OR coalesce((pd.poste->>'id') IN ('pm','min_int','min_fin','min_just',
                                                    'min_def','min_info','min_ae'), false)
                  OR EXISTS (SELECT 1 FROM public.presse_membres m
                               JOIN public.groupes_presse g ON g.id = m.groupe_id
                              WHERE m.personnage = h.name AND g.pays = v_pays)
                FROM public.personnages_donnees pd WHERE pd.name = h.name) AS raison
        FROM public.historique_deplacements h
       WHERE h.country = v_pays AND h.building_id = 'assemblee' AND h.jour >= v_depuis
       GROUP BY h.name) q;

  -- CEUX QUI S'Y SONT TROUVES EN MEME TEMPS. Meme jour, meme heure, meme batiment : c'est tout ce
  -- que le journal permet de dire, et c'est deja une observation. Le couple est ordonne pour qu'une
  -- rencontre ne soit pas comptee deux fois.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'qui_a', c.a, 'qui_b', c.b, 'fois', c.fois,
           'dernier_jour', c.dernier_jour) ORDER BY c.fois DESC, c.a, c.b), '[]'::jsonb)
    INTO v_ensemble
    FROM (
      SELECT x.name AS a, y.name AS b, count(DISTINCT (x.jour || ':' || x.heure))::int AS fois,
             max(x.jour) AS dernier_jour
        FROM public.historique_deplacements x
        JOIN public.historique_deplacements y
          ON y.country = x.country AND y.building_id = x.building_id
         AND y.jour = x.jour AND y.heure = x.heure AND y.name > x.name
       WHERE x.country = v_pays AND x.building_id = 'assemblee' AND x.jour >= v_depuis
       GROUP BY x.name, y.name) c;

  RETURN jsonb_build_object(
    'ok', true, 'pays', v_pays, 'jour', v_jour, 'fenetre_jours', v_fen,
    -- LES NEUF SIEGES, tels qu'ils sont occupes. Un depute endormi se voit : c'est une observation
    -- legitime pour qui passe la serpilliere entre les rangees.
    'deputes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
          'ville', s.city, 'rang', s.rang, 'nom', s.pnj_nom, 'endormi', s.endormi)
          ORDER BY s.city, s.rang), '[]'::jsonb)
        FROM public.assemblee_sieges s WHERE s.country = v_pays),
    'scrutins', v_scrutins,
    -- AUCUN SCRUTIN CLOS : l'assiduite des deputes n'est donc PAS etablissable, et la porte le dit
    -- au lieu de laisser deviner. C'est ce drapeau qui empeche d'inventer une habitude.
    'aucun_scrutin', (jsonb_array_length(v_scrutins) = 0),
    'passages', v_passages,
    'ensemble', v_ensemble,
    -- RIEN A SIGNALER EST UNE REPONSE VALIDE, et meme la plus frequente. Sans ce drapeau, un
    -- silence se raconterait comme une anecdote inventee.
    'rien_a_signaler', (jsonb_array_length(v_passages) = 0 AND jsonb_array_length(v_ensemble) = 0
                        AND jsonb_array_length(v_scrutins) = 0));
END;
$function$;

-- assemblee_registre_execution(text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_registre_execution(p_country text)
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

-- assemblee_reporter_si_suspendue(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_reporter_si_suspendue(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_n integer := 0; v_ids jsonb := '[]'::jsonb; r record;
BEGIN
  IF NOT public.assemblee_suspendue(p_pays) THEN
    RETURN jsonb_build_object('ok', true, 'suspendue', false, 'reportes', 0);
  END IF;

  FOR r IN SELECT id, cloture_ts FROM public.assemblee_propositions
            WHERE country = p_pays AND statut = 'session'
              AND cloture_ts IS NOT NULL AND cloture_ts <= now()
            FOR UPDATE
  LOOP
    UPDATE public.assemblee_propositions
       SET cloture_ts = ((r.cloture_ts AT TIME ZONE 'Europe/Paris') + interval '7 days')
                          AT TIME ZONE 'Europe/Paris',
           updated_at = now()
     WHERE id = r.id;
    v_n := v_n + 1;
    v_ids := v_ids || to_jsonb(r.id);
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'suspendue', true, 'reportes', v_n, 'propositions', v_ids);
END;
$function$;

-- assemblee_reporter_vote(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_reporter_vote(p_proposition_id text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; p record; v_neuve timestamptz; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  SELECT * INTO d FROM public.assemblee_reports WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'proposition', d.proposition_id,
                              'ancienne_cloture', d.ancienne_cloture,
                              'nouvelle_cloture', d.nouvelle_cloture);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;

  SELECT * INTO p FROM public.assemblee_propositions
   WHERE id = p_proposition_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_inconnue'); END IF;
  IF p.country IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autre_empire'); END IF;
  -- ON NE REPOUSSE QUE CE QUI A UNE ECHEANCE. Un texte encore en debat n'a pas de cloture : il n'y
  -- a rien a repousser, et le dire est plus utile que de deviner une date.
  IF p.statut <> 'session' OR p.cloture_ts IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_session', 'statut', p.statut); END IF;
  IF p.cloture_ts <= now() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'echeance_deja_passee'); END IF;
  IF EXISTS (SELECT 1 FROM public.assemblee_reports WHERE proposition_id = p_proposition_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_reporte_une_fois'); END IF;

  -- UNE SEMAINE CALENDAIRE DE PARIS, jamais +7 x 24 h : une echeance du mercredi 22 heures reste
  -- un mercredi 22 heures a travers un changement d'heure.
  v_neuve := ((p.cloture_ts AT TIME ZONE 'Europe/Paris') + interval '7 days') AT TIME ZONE 'Europe/Paris';

  INSERT INTO public.assemblee_reports
    (proposition_id, pays, president, ancienne_cloture, nouvelle_cloture, requete)
  VALUES (p_proposition_id, v_pays, v_moi, p.cloture_ts, v_neuve, p_requete);

  UPDATE public.assemblee_propositions
     SET cloture_ts = v_neuve, updated_at = now() WHERE id = p_proposition_id;

  RETURN jsonb_build_object('ok', true, 'proposition', p_proposition_id,
                            'ancienne_cloture', p.cloture_ts, 'nouvelle_cloture', v_neuve);
END;
$function$;

-- assemblee_reprendre_seance(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_reprendre_seance(p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_id text; d record; v_seuil jsonb; v_duree interval;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  -- LA GARDE : sans elle, un rejeu repondrait « aucune suspension » a un President dont la reprise
  -- venait d'aboutir.
  SELECT * INTO d FROM public.assemblee_suspensions WHERE reprise_requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'suspension', d.id);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;

  SELECT id INTO v_id FROM public.assemblee_suspensions
   WHERE pays = v_pays AND cause = 'presidence' AND close_le IS NULL FOR UPDATE;
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_suspension'); END IF;

  -- La duree est lue SUR LA LIGNE QU'ON VIENT D'ECRIRE, pas sur une horloge relue a cote : la
  -- valeur rendue au President est alors exactement celle que l'application du seuil mesure.
  UPDATE public.assemblee_suspensions
     SET close_le = clock_timestamp(), reprise_le = clock_timestamp(), reprise_requete = p_requete
   WHERE id = v_id
  RETURNING close_le - ouverte_le INTO v_duree;

  -- §4 : LA CONSEQUENCE, TOUT DE SUITE. Si la suspension a depasse l'heure, les scrutins qu'elle
  -- a geles sont renvoyes a la prochaine session et leurs suffrages annules -- sans attendre un
  -- cron, et sans que le President ait quoi que ce soit a decider. En deca du seuil, cet appel ne
  -- trouve rien et n'ecrit rien : l'echeance initiale demeure.
  v_seuil := public.assemblee_suspension_appliquer_seuil(v_pays);

  RETURN jsonb_build_object('ok', true, 'suspension', v_id, 'reprise', true, 'pop', 0,
                            'duree', v_duree::text,
                            'seuil_depasse', v_duree > public.assemblee_suspension_seuil(),
                            'renvois', v_seuil);
END;
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
CREATE OR REPLACE FUNCTION public.assemblee_reveil_minuit(p_country text)
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

-- assemblee_revenir() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_revenir()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_etat jsonb; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_pays := a.country;
  IF NOT public.assemblee_est_depute(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute'); END IF;
  IF a.current_building IS DISTINCT FROM 'assemblee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_l_assemblee'); END IF;

  UPDATE public.personnages_donnees SET current_room = 'hemicycle' WHERE name = v_moi;
  DELETE FROM public.assemblee_protestations WHERE pays = v_pays AND depute = v_moi;

  v_etat := public.assemblee_recalculer_suspension(v_pays);
  RETURN jsonb_build_object('ok', true, 'piece', 'hemicycle', 'seance', v_etat);
END;
$function$;

-- assemblee_sanctionner(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_sanctionner(p_depute text, p_motif text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_SANCTION constant integer := -20;
  AMENDE       constant integer := 100;
  v_moi text; v_pays text; v_m text; v_id text; v_chron text; v_rappel text;
  v_caisse text; v_paye boolean; v_pop jsonb; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  SELECT * INTO d FROM public.assemblee_disciplines WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'sanction', d.id, 'cible', d.cible, 'pop', d.pop_delta,
                              'amende', d.amende, 'caisse', d.caisse_creditee,
                              'rappel_consomme', d.rappel_id);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seance_suspendue'); END IF;
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_obligatoire'); END IF;
  IF NOT public.assemblee_est_depute(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_pas_deputee'); END IF;

  SELECT x.id INTO v_rappel FROM public.assemblee_disciplines x
   WHERE x.pays = v_pays AND x.genre = 'rappel' AND x.cible = p_depute
     AND x.president = v_moi
     AND NOT EXISTS (SELECT 1 FROM public.assemblee_disciplines s WHERE s.rappel_id = x.id)
   ORDER BY x.fait_le
   FOR UPDATE
   LIMIT 1;
  IF v_rappel IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_rappel_a_consommer'); END IF;

  v_paye := public.helvetia_debiter_fonds_ordinaires(p_depute, AMENDE);
  IF v_paye IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'montant_requis', AMENDE, 'cible', p_depute);
  END IF;
  v_caisse := v_pays || '_assemblee';
  PERFORM public.assemblee_crediter_caisse(v_caisse, AMENDE);

  v_pop := public.personnage_ajuster_pop_inf(v_moi, p_depute, POP_SANCTION, NULL, 'assemblee_sanction');
  IF coalesce((v_pop->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'assemblee_sanction_popularite_refusee: %', coalesce(v_pop->>'raison', 'inconnue');
  END IF;

  v_id    := 'sanction-' || left(md5(p_requete), 20);
  v_chron := 'chronique-assemblee_sanction-' || left(md5(p_requete), 20);

  INSERT INTO public.assemblee_disciplines
    (id, pays, genre, president, president_fonction, cible, cible_fonction, motif, pop_delta,
     amende, caisse_creditee, rappel_id, chronique_id, requete)
  VALUES (v_id, v_pays, 'sanction', v_moi, 'president_assemblee', p_depute, 'depute', v_m,
          POP_SANCTION, AMENDE, v_caisse, v_rappel, v_chron, p_requete);

  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref)
  VALUES (v_chron, v_pays, 'assemblee_sanction', 'capitale',
          jsonb_build_array(v_moi, p_depute),
          'Le President de l''Assemblee a sanctionne ' || p_depute || '.',
          jsonb_build_object('president', v_moi, 'cible', p_depute, 'motif', v_m,
                             'pop', POP_SANCTION, 'amende', AMENDE, 'caisse', v_caisse,
                             'rappel', v_rappel, 'discipline', v_id),
          v_id);

  RETURN jsonb_build_object('ok', true, 'sanction', v_id, 'rappel_consomme', v_rappel,
                            'cible', p_depute, 'pop', POP_SANCTION, 'amende', AMENDE,
                            'caisse', v_caisse, 'pop_cible', v_pop -> 'pop');
END;
$function$;

-- assemblee_sanctionner_lois_non_appliquees(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_sanctionner_lois_non_appliquees(p_country text)
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

-- assemblee_seance(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_seance(p_limite integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_pres text; v_lim integer := least(greatest(coalesce(p_limite,50),1),200);
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_pres := public.assemblee_president(v_pays);

  RETURN jsonb_build_object('ok', true, 'pays', v_pays,
    'president', v_pres,
    'je_suis_le_president', (v_pres IS NOT NULL AND v_pres = v_moi),
    'je_suis_depute', public.assemblee_est_depute(v_pays, v_moi),
    'je_suis_dans_hemicycle', public.assemblee_dans_hemicycle(v_pays, v_moi),
    'mon_parti', public.assemblee_parti_de(v_pays, v_moi),
    'suspendue', public.assemblee_suspendue(v_pays),
    -- DEUX SUSPENSIONS DISTINCTES, ET ELLES NE SE CONFONDENT JAMAIS. Le boycott empeche un vote de
    -- conclure ; la suspension presidentielle arrete la seance elle-meme.
    'suspendue_par_la_presidence', public.assemblee_suspendue_par_la_presidence(v_pays),
    'suspension_presidence', (SELECT to_jsonb(z) FROM (
        SELECT s.id, s.president, s.motif, s.ouverte_le,
               (now() - s.ouverte_le)::text AS depuis,
               (now() - s.ouverte_le) > public.assemblee_suspension_seuil() AS seuil_depasse
          FROM public.assemblee_suspensions s
         WHERE s.pays = v_pays AND s.cause = 'presidence' AND s.close_le IS NULL LIMIT 1) z),
    -- §4 : L'HEURE EST UN FAIT PUBLIC. Le seuil est nomme une seule fois en base ; l'ecran le lit
    -- au lieu de le recopier, et ne compte rien lui-meme : il n'y a aucun minuteur client dans
    -- cette regle.
    'seuil_suspension_presidence', public.assemblee_suspension_seuil()::text,
    'suspension_presidence_depassee', public.assemblee_suspension_depassee(v_pays),
    -- LES RENVOIS POUR CAUSE DE SUSPENSION, distincts des reports volontaires ci-dessous.
    'renvois_pour_suspension', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                 'proposition', r.proposition_id, 'session_annulee', r.session_annulee,
                 'bulletins_annules', r.bulletins_annules, 'duree', r.suspension_duree::text,
                 'fait_le', r.fait_le) ORDER BY r.fait_le DESC), '[]'::jsonb)
       FROM public.assemblee_reports_suspension r WHERE r.pays = v_pays),
    'deputes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'depute', o.pj_nom, 'ville', o.city,
                   'dans_hemicycle', public.assemblee_dans_hemicycle(v_pays, o.pj_nom),
                   'parti', public.assemblee_parti_de(v_pays, o.pj_nom))
                 ORDER BY o.city, o.rang), '[]'::jsonb)
       FROM public.assemblee_occupation_sieges(v_pays) o WHERE o.pj_nom IS NOT NULL),
    'file', (SELECT coalesce(jsonb_agg(jsonb_build_object('depute', q.depute, 'depuis', q.demande_le)
              ORDER BY q.demande_le, q.depute), '[]'::jsonb)
       FROM public.assemblee_paroles q WHERE q.pays = v_pays AND NOT q.a_la_parole),
    'orateur', (SELECT q.depute FROM public.assemblee_paroles q
                 WHERE q.pays = v_pays AND q.a_la_parole LIMIT 1),
    'debat', (SELECT coalesce(jsonb_agg(x ORDER BY (x->>'dit_le')), '[]'::jsonb) FROM (
        SELECT jsonb_build_object('id', d.id, 'auteur', d.auteur, 'fonction', d.auteur_fonction,
                 'texte', d.texte, 'autorise', d.autorise, 'dit_le', d.dit_le) AS x
          FROM public.assemblee_debats d WHERE d.pays = v_pays
          ORDER BY d.dit_le DESC LIMIT v_lim) z),
    'dehors', (SELECT coalesce(jsonb_agg(jsonb_build_object('depute', p.depute,
                 'qualifie', p.qualifie, 'motif', p.motif_qualifiant, 'depuis', p.sorti_le)
                 ORDER BY p.sorti_le), '[]'::jsonb)
       FROM public.assemblee_protestations p WHERE p.pays = v_pays),
    'protestataires_qualifies', (SELECT count(*) FROM public.assemblee_protestations p
                                  WHERE p.pays = v_pays AND p.qualifie),
    'seuil_suspension', 5,
    'rappels_consommables', (SELECT coalesce(jsonb_agg(d.cible ORDER BY d.cible), '[]'::jsonb)
       FROM public.assemblee_disciplines d
      WHERE d.pays = v_pays AND d.genre = 'rappel' AND d.president IS NOT DISTINCT FROM v_pres
        AND NOT EXISTS (SELECT 1 FROM public.assemblee_disciplines s WHERE s.rappel_id = d.id)),
    'textes_reportes', (SELECT coalesce(jsonb_agg(r.proposition_id ORDER BY r.proposition_id), '[]'::jsonb)
       FROM public.assemblee_reports r WHERE r.pays = v_pays),
    'episodes_sous_cette_presidence', (SELECT count(*) FROM public.assemblee_suspensions s
       WHERE s.pays = v_pays AND s.cause = 'boycott'
         AND s.president IS NOT DISTINCT FROM v_pres),
    -- UNE ELECTION EXCEPTIONNELLE EST-ELLE DUE ? Un fait rendu, et c'est la convocation du lundi
    -- qui l'ouvrira -- pas cet ecran.
    'election_presidentielle_due', EXISTS (SELECT 1 FROM public.assemblee_presidence_dues u
       WHERE u.pays = v_pays AND u.honore_le IS NULL));
END;
$function$;

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

-- assemblee_suspendre_seance(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_suspendre_seance(p_motif text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_SUSPENSION constant integer := -20;
  v_moi text; v_pays text; v_id text; v_m text; v_pop jsonb; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  SELECT * INTO d FROM public.assemblee_suspensions WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'suspension', d.id, 'pop', POP_SUSPENSION,
                              'compte_pour_le_boycott', false,
                              'ouverte', d.close_le IS NULL);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  -- ON NE SUSPEND PAS UNE SEANCE DEJA SUSPENDUE : ce serait payer deux fois pour le meme etat.
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_suspendue'); END IF;

  -- LE MOTIF EST CONSERVE S'IL EST DONNE, ET N'EST NI EXIGE NI JUGE : l'arbitrage ne le rend pas
  -- obligatoire pour cette prerogative, contrairement au rappel et a la sanction.
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  v_id := 'suspension-pres-' || left(md5(p_requete), 20);

  -- IL SE PAIE LUI-MEME, et le registre des causes le verifie. Un refus annule tout : pas de
  -- suspension gratuite.
  v_pop := public.personnage_ajuster_pop_inf(v_moi, v_moi, POP_SUSPENSION, NULL, 'assemblee_suspension_seance');
  IF coalesce((v_pop->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'assemblee_suspension_popularite_refusee: %', coalesce(v_pop->>'raison', 'inconnue');
  END IF;

  -- `close_le` RESTE NUL : l'etat PERSISTE jusqu'a la reprise. C'est tout l'arbitrage neuf.
  INSERT INTO public.assemblee_suspensions (id, pays, cause, president, motif, requete)
  VALUES (v_id, v_pays, 'presidence', v_moi, v_m, p_requete);

  RETURN jsonb_build_object('ok', true, 'suspension', v_id, 'pop', POP_SUSPENSION,
                            'compte_pour_le_boycott', false, 'ouverte', true,
                            'pop_president', v_pop -> 'pop');
END;
$function$;

-- assemblee_suspendue(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_suspendue(p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.assemblee_suspensions
                  WHERE pays = p_pays AND cause = 'boycott' AND close_le IS NULL);
$function$;

-- assemblee_suspendue_par_la_presidence(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_suspendue_par_la_presidence(p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.assemblee_suspensions
                  WHERE pays = p_pays AND cause = 'presidence' AND close_le IS NULL);
$function$;
