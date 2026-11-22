-- Santé et forêt (Fred, 22/11/2026, après-midi : GAME-DESIGN-SANTE-20261122.md), points 12, 14, 17 et 22.
-- Écrite à partir des définitions de PRODUCTION (pg_get_functiondef du 22/11/2026). NON appliquée. Rejouable.
-- Suppose le socle 20261122230000_sante_socle (sante_param, sante_gagner_interne, personnage_evenement_ajouter_interne).
--
--  Point 12, médecin de terrain (carrière « doctor ») sur un autre personnage présent au même endroit (pièce ou rue,
--  forêt comprise ; présence vérifiée par le serveur à la proposition ET à l'acceptation) :
--   • medecin_proposer(patient, acte, prix) : le médecin fixe librement son tarif ; une proposition est écrite en base
--     (medecin_propositions) et le patient la reçoit dans son journal d'événements (cle « medecin_proposition »).
--     Rien n'est prélevé à ce stade, ni au médecin ni au patient.
--   • medecin_repondre(id, accepte) : refus → rien ne bouge ; accord → contrôle de tout (présence, PA du médecin,
--     trousse, fonds du patient), paiement du patient au médecin (argent liquide puis banque nationale → liquide du
--     médecin), PA du médecin débités, puis l'acte :
--       « diagnostic » (sante_param medecin_diagnostic_pa) : Santé exacte, maladies en cours par leur nom et médicament
--         qui soigne chacune, au médecin et au patient seulement (journal d'événements des deux) ;
--       « soin » (medecin_soin_pa) : une trousse de premiers secours (produitMilitaire « trousse_secours ») quitte
--         l'inventaire du médecin et le patient gagne medecin_soin_sante (12) par sante_gagner_interne (modulé par son Moral).
--   • medecin_propositions_lire() : propositions en attente du patient (fenêtre rouverte au chargement).
--   • medecin_etat() : le joueur est-il médecin, coûts et trousses (libellés des boutons, jamais décidés à l'écran).
--   • Tarifs : ordres_couts medecin_diagnostiquer (1 PA) et medecin_soigner (2 PA), miroir des paramètres.
--  Point 22, « Montrer un objet » : objet_montrer(destinataire, index, nom) ; rien ne change de main ; l'autre reçoit
--    nom, image et description (cle « objet_montre », fenêtre) ; une ligne au journal des deux.
--  Point 14 : sante_paliers_lire() expose au navigateur les seuils du Moral et la robustesse (infobulles des jauges).
--  Point 17 : piece_plein_air_interne() (miroir de PIECES_PLEIN_AIR, plateau-climat.js) ; inspecter_piece,
--    desinstaller_lire et desinstaller_materiel refusent « plein_air » dans une vue en plein air (remplacements contrôlés,
--    marques plein_air_inspecter_v1, plein_air_desinstaller_lire_v1, plein_air_desinstaller_v1).
-- Aucune Santé actuelle n'est modifiée (point 16). Rien du goulag.

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- ---------------------------------------------------------------------------------------------------------------
-- 1. Paramètres (réglables par un MJ depuis l'administration, page Santé)
-- ---------------------------------------------------------------------------------------------------------------
INSERT INTO public.sante_parametres (cle, valeur, groupe, libelle) VALUES
  ('medecin_proposition_minutes', 30, 'medecin', 'Médecin : durée de validité d''une proposition (minutes)'),
  ('medecin_tarif_max', 100000, 'medecin', 'Médecin : tarif maximal d''un acte')
ON CONFLICT (cle) DO NOTHING;

-- ---------------------------------------------------------------------------------------------------------------
-- 2. Propositions du médecin
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.medecin_propositions (
  id bigserial PRIMARY KEY,
  medecin text NOT NULL,
  patient text NOT NULL,
  acte text NOT NULL CHECK (acte IN ('diagnostic', 'soin')),
  prix integer NOT NULL CHECK (prix >= 0),
  statut text NOT NULL DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'acceptee', 'refusee', 'annulee', 'expiree', 'echouee')),
  salle text,
  cree_le timestamptz NOT NULL DEFAULT now(),
  expire_le timestamptz NOT NULL,
  repondu_le timestamptz,
  resultat jsonb
);
CREATE INDEX IF NOT EXISTS medecin_propositions_patient ON public.medecin_propositions (patient, id) WHERE statut = 'en_attente';
CREATE INDEX IF NOT EXISTS medecin_propositions_medecin ON public.medecin_propositions (medecin, id) WHERE statut = 'en_attente';
ALTER TABLE public.medecin_propositions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.medecin_propositions FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 3. Outils internes
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.medecin_monnaie_interne(p_pays text)
 RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT CASE p_pays WHEN 'soviet' THEN 'PSK' WHEN 'narco' THEN 'PS' WHEN 'khalija' THEN 'DR' ELSE 'FR' END /* medecin_montrer_v1 */ $function$;

CREATE OR REPLACE FUNCTION public.medecin_maladie_nom_interne(p_cle text)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(nullif((SELECT nom_mj FROM public.maladies_parametres WHERE cle = p_cle), ''),
    CASE p_cle WHEN 'intoxication' THEN 'Intoxication alimentaire' WHEN 'gueule_de_bois' THEN 'Gueule de bois'
               WHEN 'grippe' THEN 'Grippe' WHEN 'coup_de_chaleur' THEN 'Coup de chaleur' WHEN 'mst' THEN 'MST'
               ELSE initcap(replace(coalesce(p_cle, ''), '_', ' ')) END) /* medecin_montrer_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.medecin_medicament_nom_interne(p_cle text)
 RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE p_cle WHEN 'antinauseeux' THEN 'Anti-nauséeux' WHEN 'aspirine' THEN 'Aspirine' WHEN 'antigrippal' THEN 'Antigrippal'
                    WHEN 'sels_rehydratation' THEN 'Sels de réhydratation' WHEN 'antibiotique' THEN 'Antibiotique'
                    ELSE initcap(replace(p_cle, '_', ' ')) END /* medecin_montrer_v1 */
$function$;

-- Deux personnages au même endroit : même pays, même ville, même pièce (ou même rue), forêt comprise ; une personne
-- cachée ne compte que pour les membres de son groupe (même règle que presents_ici).
CREATE OR REPLACE FUNCTION public.personnages_meme_lieu_interne(p_a text, p_b text)
 RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE x record; y record; v_chef_a text; v_chef_b text;
BEGIN
  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN RETURN false; END IF;
  SELECT country, current_city, current_building, current_room, current_street INTO x FROM public.personnages_donnees WHERE name = p_a;
  IF NOT FOUND THEN RETURN false; END IF;
  SELECT country, current_city, current_building, current_room, current_street INTO y FROM public.personnages_donnees WHERE name = p_b;
  IF NOT FOUND THEN RETURN false; END IF;
  IF coalesce(x.current_building, '') = '' AND coalesce(x.current_street, '') = '' THEN RETURN false; END IF;
  IF coalesce(x.current_building, '') <> '' AND coalesce(x.current_room, '') = '' THEN RETURN false; END IF;
  IF public.salle_cle_interne(x.country, x.current_city, x.current_building, x.current_room, x.current_street)
     IS DISTINCT FROM public.salle_cle_interne(y.country, y.current_city, y.current_building, y.current_room, y.current_street) THEN
    RETURN false;
  END IF;
  IF public.crim_cache_interne(p_b) THEN
    v_chef_a := public.groupe_chef_de_interne(p_a); v_chef_b := public.groupe_chef_de_interne(p_b);
    IF v_chef_a IS NULL OR v_chef_a IS DISTINCT FROM v_chef_b THEN RETURN false; END IF;
  END IF;
  RETURN true; /* medecin_montrer_v1 */
END $function$;

-- Position (0 = premier) de la première trousse de premiers secours d'un inventaire.
CREATE OR REPLACE FUNCTION public.medecin_trousse_position_interne(p_inv jsonb)
 RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT (o.ord - 1)::integer FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_inv) = 'array' THEN p_inv ELSE '[]'::jsonb END) WITH ORDINALITY o(val, ord)
   WHERE o.val->>'produitMilitaire' = 'trousse_secours' OR lower(coalesce(o.val->>'name', '')) = 'trousse de premiers secours'
   ORDER BY o.ord LIMIT 1 /* medecin_montrer_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.medecin_trousses_compter_interne(p_inv jsonb)
 RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(sum(CASE WHEN coalesce(o->>'qty', '') ~ '^[0-9]+$' THEN greatest(1, (o->>'qty')::integer) ELSE 1 END), 0)::integer
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_inv) = 'array' THEN p_inv ELSE '[]'::jsonb END) o
   WHERE o->>'produitMilitaire' = 'trousse_secours' OR lower(coalesce(o->>'name', '')) = 'trousse de premiers secours' /* medecin_montrer_v1 */
$function$;

-- Diagnostic : Santé exacte et maladies en cours (nom, médicament qui soigne). Lu seulement par le médecin et le patient.
CREATE OR REPLACE FUNCTION public.medecin_diagnostic_interne(p_patient text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_hp integer; v_mal jsonb;
BEGIN
  PERFORM public.maladies_echeances_interne(p_patient);
  SELECT coalesce(hp, public.sante_param('sante_max', 100)::integer) INTO v_hp FROM public.personnages_donnees WHERE name = p_patient;
  SELECT coalesce(jsonb_agg(jsonb_build_object('cle', pm.cle, 'nom', public.medecin_maladie_nom_interne(pm.cle),
           'medicament', mp.medicament, 'medicament_nom', public.medecin_medicament_nom_interne(mp.medicament),
           'traitee', pm.traitee_le IS NOT NULL) ORDER BY pm.debut), '[]'::jsonb)
    INTO v_mal FROM public.personnages_maladies pm LEFT JOIN public.maladies_parametres mp ON mp.cle = pm.cle
   WHERE pm.nom = p_patient AND pm.guerie_le IS NULL;
  RETURN jsonb_build_object('sante', v_hp, 'maladies', v_mal); /* medecin_montrer_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.medecin_diagnostic_texte_interne(p_diag jsonb)
 RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT 'Santé ' || coalesce(p_diag->>'sante', '?') || '. '
    || CASE WHEN jsonb_array_length(coalesce(p_diag->'maladies', '[]'::jsonb)) = 0 THEN 'Aucune maladie en cours.'
            ELSE 'Maladies en cours : ' || (SELECT string_agg(m->>'nom' || CASE WHEN m->>'medicament_nom' IS NOT NULL
                   THEN ' (se soigne avec : ' || (m->>'medicament_nom') || CASE WHEN (m->>'traitee')::boolean THEN ', déjà pris' ELSE '' END || ')'
                   ELSE '' END, ' ; ' ORDER BY o) FROM jsonb_array_elements(p_diag->'maladies') WITH ORDINALITY t(m, o)) || '.' END /* medecin_montrer_v1 */
$function$;

-- Nom affiché d'un personnage à un autre : « un personnage masqué » s'il porte un masque.
CREATE OR REPLACE FUNCTION public.medecin_nom_vu_interne(p_nom text)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT CASE WHEN public.crim_masque_interne(p_nom) THEN 'Un personnage masqué' ELSE p_nom END /* medecin_montrer_v1 */ $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 4. RPC du médecin
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.medecin_etat()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); d record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT career, pa, inventory, country INTO d FROM public.personnages_donnees WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'medecin', coalesce(d.career, '') = 'doctor', 'pa', coalesce(d.pa, 0),
    'pa_diagnostic', public.sante_param('medecin_diagnostic_pa', 1)::integer, 'pa_soin', public.sante_param('medecin_soin_pa', 2)::integer,
    'sante_soin', public.sante_param('medecin_soin_sante', 12)::integer, 'tarif_max', public.sante_param('medecin_tarif_max', 100000)::integer,
    'trousses', public.medecin_trousses_compter_interne(d.inventory), 'monnaie', public.medecin_monnaie_interne(d.country)); /* medecin_montrer_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.medecin_proposer(p_patient text, p_acte text, p_prix integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); m record; v_pa integer; v_id bigint; v_cur text; v_nom text; v_txt text;
        v_max integer := public.sante_param('medecin_tarif_max', 100000)::integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_acte NOT IN ('diagnostic', 'soin') THEN RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu'); END IF;
  IF p_prix IS NULL OR p_prix < 0 OR p_prix > v_max THEN RETURN jsonb_build_object('ok', false, 'raison', 'tarif_invalide', 'max', v_max); END IF;
  SELECT name, career, pa, inventory, country, current_city, current_building, current_room, current_street INTO m
    FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(m.career, '') <> 'doctor' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_aux_medecins'); END IF;
  IF coalesce(p_patient, '') = '' OR p_patient = a THEN RETURN jsonb_build_object('ok', false, 'raison', 'patient_invalide'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_patient) THEN RETURN jsonb_build_object('ok', false, 'raison', 'patient_introuvable'); END IF;
  IF NOT public.personnages_meme_lieu_interne(a, p_patient) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit'); END IF;
  v_pa := CASE p_acte WHEN 'diagnostic' THEN public.sante_param('medecin_diagnostic_pa', 1) ELSE public.sante_param('medecin_soin_pa', 2) END::integer;
  IF coalesce(m.pa, 0) < v_pa THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', v_pa, 'pa', coalesce(m.pa, 0)); END IF;
  IF p_acte = 'soin' AND public.medecin_trousse_position_interne(m.inventory) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_trousse'); END IF;
  -- Une seule proposition en attente par médecin et par patient : la nouvelle remplace l'ancienne.
  UPDATE public.medecin_propositions SET statut = 'annulee', repondu_le = now()
   WHERE medecin = a AND patient = p_patient AND statut = 'en_attente';
  INSERT INTO public.medecin_propositions (medecin, patient, acte, prix, salle, expire_le)
  VALUES (a, p_patient, p_acte, p_prix,
          public.salle_cle_interne(m.country, m.current_city, m.current_building, m.current_room, m.current_street),
          now() + make_interval(mins => greatest(1, public.sante_param('medecin_proposition_minutes', 30)::integer)))
  RETURNING id INTO v_id;
  v_cur := public.medecin_monnaie_interne(m.country);
  v_nom := public.medecin_nom_vu_interne(a);
  v_txt := v_nom || CASE p_acte WHEN 'diagnostic' THEN ' vous propose un diagnostic' ELSE ' vous propose des soins' END
        || CASE WHEN p_prix = 0 THEN ', gratuitement.' ELSE ' pour ' || p_prix || ' ' || v_cur || '.' END
        || ' Acceptez ou refusez dans la fenêtre : rien n''est prélevé sans votre accord.';
  PERFORM public.personnage_evenement_ajouter_interne(p_patient, 'medecin_proposition', v_txt,
    jsonb_build_object('id', v_id, 'medecin', v_nom, 'acte', p_acte, 'prix', p_prix, 'monnaie', v_cur, 'ton', 'neutre',
      'sante_soin', CASE WHEN p_acte = 'soin' THEN public.sante_param('medecin_soin_sante', 12)::integer END));
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'patient', p_patient, 'acte', p_acte, 'prix', p_prix, 'monnaie', v_cur,
    'pa_requis', v_pa); /* medecin_montrer_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.medecin_propositions_lire()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  UPDATE public.medecin_propositions SET statut = 'expiree', repondu_le = now()
   WHERE patient = a AND statut = 'en_attente' AND expire_le <= now();
  RETURN jsonb_build_object('ok', true, 'propositions', coalesce((SELECT jsonb_agg(jsonb_build_object('id', p.id,
      'medecin', public.medecin_nom_vu_interne(p.medecin), 'acte', p.acte, 'prix', p.prix,
      'monnaie', public.medecin_monnaie_interne((SELECT country FROM public.personnages_donnees WHERE name = p.medecin)),
      'sante_soin', CASE WHEN p.acte = 'soin' THEN public.sante_param('medecin_soin_sante', 12)::integer END,
      'expire_le', p.expire_le) ORDER BY p.id)
    FROM public.medecin_propositions p WHERE p.patient = a AND p.statut = 'en_attente'), '[]'::jsonb)); /* medecin_montrer_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.medecin_repondre(p_proposition bigint, p_accepte boolean)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); p public.medecin_propositions; m record; pt record; v_pa integer; v_dispo numeric;
        v_pos integer; v_inv jsonb; v_qte integer; v_paye numeric := 0; v_diag jsonb; v_soin jsonb; v_res jsonb;
        v_cur text; v_nom_m text; v_nom_p text; v_acte_txt text; v_raison text; v_txt text; v_prix_txt text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO p FROM public.medecin_propositions WHERE id = p_proposition AND patient = a FOR UPDATE;
  IF p.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'proposition_introuvable'); END IF;
  IF p.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', false, 'raison', 'proposition_close', 'statut', p.statut); END IF;
  v_nom_p := public.medecin_nom_vu_interne(a);
  v_acte_txt := CASE p.acte WHEN 'diagnostic' THEN 'diagnostic' ELSE 'soins' END;
  IF p.expire_le <= now() THEN
    UPDATE public.medecin_propositions SET statut = 'expiree', repondu_le = now() WHERE id = p.id;
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_expiree');
  END IF;
  IF p_accepte IS NOT TRUE THEN
    UPDATE public.medecin_propositions SET statut = 'refusee', repondu_le = now() WHERE id = p.id;
    PERFORM public.personnage_evenement_ajouter_interne(p.medecin, 'medecin_refus',
      v_nom_p || ' refuse votre proposition de ' || v_acte_txt || '. Rien n''a été prélevé.',
      jsonb_build_object('id', p.id, 'patient', v_nom_p, 'acte', p.acte, 'ton', 'neutre'));
    RETURN jsonb_build_object('ok', true, 'statut', 'refusee', 'id', p.id);
  END IF;

  -- Accord : on verrouille les deux fiches (ordre alphabétique, pas d'interblocage) et on contrôle TOUT avant d'écrire.
  PERFORM 1 FROM public.personnages_donnees WHERE name IN (a, p.medecin) ORDER BY name FOR UPDATE;
  SELECT name, career, pa, inventory, country INTO m FROM public.personnages_donnees WHERE name = p.medecin;
  SELECT name, liquide, country INTO pt FROM public.personnages_donnees WHERE name = a;
  v_pa := CASE p.acte WHEN 'diagnostic' THEN public.sante_param('medecin_diagnostic_pa', 1) ELSE public.sante_param('medecin_soin_pa', 2) END::integer;
  v_raison := CASE
    WHEN m.name IS NULL OR coalesce(m.career, '') <> 'doctor' THEN 'medecin_indisponible'
    WHEN NOT public.personnages_meme_lieu_interne(a, p.medecin) THEN 'pas_au_meme_endroit'
    WHEN coalesce(m.pa, 0) < v_pa THEN 'medecin_sans_pa'
    WHEN p.acte = 'soin' AND public.medecin_trousse_position_interne(m.inventory) IS NULL THEN 'medecin_sans_trousse'
  END;
  IF v_raison IS NULL AND p.prix > 0 THEN
    v_dispo := greatest(coalesce(pt.liquide, 0), 0) + coalesce((SELECT greatest(solde, 0) FROM public.comptes_bancaires
                 WHERE personnage = a AND banque = 'nationale' ORDER BY id LIMIT 1), 0);
    IF v_dispo < p.prix THEN v_raison := 'fonds_insuffisants'; END IF;
  END IF;
  IF v_raison IS NOT NULL THEN
    UPDATE public.medecin_propositions SET statut = 'echouee', repondu_le = now(), resultat = jsonb_build_object('raison', v_raison) WHERE id = p.id;
    PERFORM public.personnage_evenement_ajouter_interne(p.medecin, 'medecin_echec',
      v_nom_p || ' accepte votre proposition de ' || v_acte_txt || ', mais l''acte n''a pas pu avoir lieu ('
      || CASE v_raison WHEN 'pas_au_meme_endroit' THEN 'vous n''êtes plus au même endroit'
                       WHEN 'medecin_sans_pa' THEN 'vous n''avez plus assez de PA'
                       WHEN 'medecin_sans_trousse' THEN 'vous n''avez plus de trousse de premiers secours'
                       WHEN 'fonds_insuffisants' THEN 'le patient ne peut pas payer'
                       ELSE 'vous ne pouvez plus exercer' END || '). Rien n''a été prélevé.',
      jsonb_build_object('id', p.id, 'raison', v_raison, 'ton', 'mauvais'));
    RETURN jsonb_build_object('ok', false, 'raison', v_raison, 'id', p.id);
  END IF;

  -- Paiement (serveur), puis PA du médecin, puis l'acte.
  v_cur := public.medecin_monnaie_interne(m.country);
  IF p.prix > 0 THEN
    v_paye := public.argent_debiter_interne(a, p.prix, 'liquide_puis_nationale');
    IF v_paye < p.prix THEN RAISE EXCEPTION 'medecin_paiement_incomplet'; END IF;
    PERFORM public.argent_crediter_interne(p.medecin, v_paye, 'liquide');
  END IF;
  UPDATE public.personnages_donnees SET pa = pa - v_pa WHERE name = p.medecin;
  v_nom_m := public.medecin_nom_vu_interne(p.medecin);
  v_prix_txt := CASE WHEN p.prix = 0 THEN 'gratuitement' ELSE p.prix || ' ' || v_cur END;

  IF p.acte = 'diagnostic' THEN
    v_diag := public.medecin_diagnostic_interne(a);
    v_txt := public.medecin_diagnostic_texte_interne(v_diag);
    v_res := jsonb_build_object('acte', 'diagnostic', 'diagnostic', v_diag);
    PERFORM public.personnage_evenement_ajouter_interne(a, 'medecin_diagnostic',
      'Diagnostic de ' || v_nom_m || ' (' || v_prix_txt || ') : ' || v_txt,
      jsonb_build_object('id', p.id, 'medecin', v_nom_m, 'prix', p.prix, 'monnaie', v_cur, 'ton', 'neutre') || v_diag);
    PERFORM public.personnage_evenement_ajouter_interne(p.medecin, 'medecin_diagnostic_resultat',
      'Votre diagnostic de ' || v_nom_p || ' (' || v_prix_txt || ', −' || v_pa || ' PA) : ' || v_txt,
      jsonb_build_object('id', p.id, 'patient', v_nom_p, 'prix', p.prix, 'monnaie', v_cur, 'pa', v_pa, 'ton', 'neutre') || v_diag);
  ELSE
    SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name = p.medecin;
    v_pos := public.medecin_trousse_position_interne(v_inv);
    v_qte := CASE WHEN coalesce(v_inv->v_pos->>'qty', '') ~ '^[0-9]+$' THEN (v_inv->v_pos->>'qty')::integer ELSE 1 END;
    IF v_qte > 1 THEN v_inv := jsonb_set(v_inv, ARRAY[v_pos::text, 'qty'], to_jsonb(v_qte - 1));
    ELSE v_inv := v_inv - v_pos; END IF;
    UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p.medecin;
    v_soin := public.sante_gagner_interne(a, public.sante_param('medecin_soin_sante', 12)::integer, 'medecin',
                jsonb_build_object('medecin', p.medecin, 'proposition', p.id));
    v_res := jsonb_build_object('acte', 'soin', 'soin', v_soin);
    PERFORM public.personnage_evenement_ajouter_interne(a, 'medecin_soin',
      v_nom_m || ' vous a soigné (' || v_prix_txt || ') : Santé ' || (v_soin->>'avant') || ' → ' || (v_soin->>'apres')
      || ' (+' || (v_soin->>'gain') || ').',
      jsonb_build_object('id', p.id, 'medecin', v_nom_m, 'prix', p.prix, 'monnaie', v_cur, 'ton', 'bon',
        'avant', v_soin->'avant', 'apres', v_soin->'apres', 'gain', v_soin->'gain', 'multiplicateur', v_soin->'multiplicateur'));
    PERFORM public.personnage_evenement_ajouter_interne(p.medecin, 'medecin_soin_fait',
      'Vous avez soigné ' || v_nom_p || ' (' || v_prix_txt || ', −' || v_pa || ' PA, une trousse de premiers secours utilisée) : +'
      || (v_soin->>'gain') || ' Santé.',
      jsonb_build_object('id', p.id, 'patient', v_nom_p, 'prix', p.prix, 'monnaie', v_cur, 'pa', v_pa, 'gain', v_soin->'gain', 'ton', 'bon'));
  END IF;
  UPDATE public.medecin_propositions SET statut = 'acceptee', repondu_le = now(), resultat = v_res || jsonb_build_object('paye', v_paye) WHERE id = p.id;
  RETURN jsonb_build_object('ok', true, 'statut', 'acceptee', 'id', p.id, 'paye', v_paye, 'monnaie', v_cur) || v_res
    || (SELECT jsonb_build_object('hp', hp, 'liquide', liquide) FROM public.personnages_donnees WHERE name = a); /* medecin_montrer_v1 */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 5. Montrer un objet (point 22)
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.objet_montrer(p_destinataire text, p_index integer, p_nom text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); v_inv jsonb; o jsonb; v_nom text; v_img text; v_desc text; v_de text; v_vers text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(p_destinataire, '') = '' OR p_destinataire = a THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;
  IF NOT public.personnages_meme_lieu_interne(a, p_destinataire) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit'); END IF;
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END INTO v_inv FROM public.personnages_donnees WHERE name = a;
  IF p_index IS NOT NULL AND p_index >= 0 THEN o := v_inv->p_index; END IF;
  IF o IS NULL OR (p_nom IS NOT NULL AND o->>'name' IS DISTINCT FROM p_nom) THEN
    SELECT x INTO o FROM jsonb_array_elements(v_inv) x WHERE x->>'name' = p_nom LIMIT 1;
  END IF;
  IF o IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_introuvable'); END IF;
  v_nom := coalesce(nullif(o->>'name', ''), 'Objet');
  v_img := nullif(coalesce(o->>'imageUrl', o->>'image', o->>'photoUrl', ''), '');
  v_desc := nullif(coalesce(o->>'desc', o->>'description', ''), '');
  v_de := public.medecin_nom_vu_interne(a);
  v_vers := public.medecin_nom_vu_interne(p_destinataire);
  PERFORM public.personnage_evenement_ajouter_interne(p_destinataire, 'objet_montre', v_de || ' vous montre : ' || v_nom || '.',
    jsonb_build_object('de', v_de, 'nom', v_nom, 'image', v_img, 'desc', v_desc, 'icon', o->>'icon', 'ton', 'neutre'));
  PERFORM public.personnage_evenement_ajouter_interne(a, 'objet_montre_envoye', 'Vous montrez « ' || v_nom || ' » à ' || v_vers || '.',
    jsonb_build_object('vers', v_vers, 'nom', v_nom, 'ton', 'neutre'));
  RETURN jsonb_build_object('ok', true, 'destinataire', p_destinataire, 'nom', v_nom); /* medecin_montrer_v1 */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 6. Paliers des jauges (point 14) : le navigateur n'invente aucun seuil.
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sante_paliers_lire()
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('ok', true, 'sante_max', public.sante_param('sante_max', 100),
    'moral_seuil_haut', public.sante_param('moral_seuil_haut', 75), 'moral_seuil_bas', public.sante_param('moral_seuil_bas', 25),
    'moral_mult_haut', public.sante_param('moral_mult_haut', 1.5), 'moral_mult_moyen', public.sante_param('moral_mult_moyen', 1),
    'moral_mult_bas', public.sante_param('moral_mult_bas', 0.5),
    'robustesse_f0', public.sante_param('robustesse_f0', 1.3), 'robustesse_f50', public.sante_param('robustesse_f50', 1.0),
    'robustesse_f100', public.sante_param('robustesse_f100', 0.8)) /* medecin_montrer_v1 */
$function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 7. Vues en plein air (point 17) : ni « Inspecter la pièce » ni « Désinstaller du matériel ».
--    Miroir de PIECES_PLEIN_AIR (plateau-climat.js, 22/11/2026).
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.piece_plein_air_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
 RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(p_batiment, '') <> '' AND coalesce(p_piece, '') <> '' AND (
       (p_pays = 'soviet' AND p_ville = 'ville_b' AND p_batiment = 'zone-production' AND p_piece ~ '^(zone_recolte|foret_clairiere|foret_vue_[1-4])$')
    OR (p_pays = 'soviet' AND p_ville = 'ville_a' AND p_batiment = 'zone-production' AND p_piece = 'zone_recolte')
    OR (p_batiment = 'champ-petrole-starovka' AND p_piece = 'zone_recolte')
    OR (p_batiment ~ '^ferme-' AND p_piece = 'cour_ferme')
    OR (p_batiment ~ '^terrain-a-batir' AND p_piece ~ '^terrain')
    OR (p_batiment = 'stade' AND p_piece = 'terrain')
    OR (p_batiment = 'parc-botanique-national')
    OR (p_batiment ~ '^port-' AND p_piece ~ '^quai_')) /* medecin_montrer_v1 */
$function$;

SELECT pg_temp.rp_remplacer('public.inspecter_piece()'::regprocedure,
  $a$IF l.batiment IS NULL OR l.piece IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'lieu_invalide'); END IF;$a$,
  $b$IF l.batiment IS NULL OR l.piece IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'lieu_invalide'); END IF;
  IF coalesce(d.current_building, '') <> '' AND public.piece_plein_air_interne(d.country, d.current_city, d.current_building, d.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plein_air'); END IF; /* plein_air_inspecter_v1 */$b$,
  1, 'plein_air_inspecter_v1');

SELECT pg_temp.rp_remplacer('public.desinstaller_lire()'::regprocedure,
  $a$IF d.current_building IS NULL OR d.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;$a$,
  $b$IF d.current_building IS NULL OR d.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  IF public.piece_plein_air_interne(d.country, d.current_city, d.current_building, d.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plein_air'); END IF; /* plein_air_desinstaller_lire_v1 */$b$,
  1, 'plein_air_desinstaller_lire_v1');

SELECT pg_temp.rp_remplacer('public.desinstaller_materiel(uuid,uuid)'::regprocedure,
  $a$IF m.current_building IS NULL OR m.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;$a$,
  $b$IF m.current_building IS NULL OR m.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  IF public.piece_plein_air_interne(m.country, m.current_city, m.current_building, m.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plein_air'); END IF; /* plein_air_desinstaller_v1 */$b$,
  1, 'plein_air_desinstaller_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- 8. Tarifs (miroir des paramètres ; les PA sont débités au médecin par medecin_repondre, à l'acceptation du patient)
-- ---------------------------------------------------------------------------------------------------------------
INSERT INTO public.ordres_couts (fn, pa, cost) SELECT v.fn, v.pa, v.cost
  FROM (VALUES ('medecin_diagnostiquer', public.sante_param('medecin_diagnostic_pa', 1)::integer, 0),
               ('medecin_soigner', public.sante_param('medecin_soin_pa', 2)::integer, 0)) v(fn, pa, cost)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = v.fn);

-- ---------------------------------------------------------------------------------------------------------------
-- 9. Droits
-- ---------------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.medecin_monnaie_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medecin_maladie_nom_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medecin_medicament_nom_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.personnages_meme_lieu_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medecin_trousse_position_interne(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medecin_trousses_compter_interne(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medecin_diagnostic_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medecin_diagnostic_texte_interne(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medecin_nom_vu_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.piece_plein_air_interne(text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medecin_etat() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.medecin_proposer(text, text, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.medecin_propositions_lire() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.medecin_repondre(bigint, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.objet_montrer(text, integer, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sante_paliers_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medecin_etat() TO authenticated;
GRANT EXECUTE ON FUNCTION public.medecin_proposer(text, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.medecin_propositions_lire() TO authenticated;
GRANT EXECUTE ON FUNCTION public.medecin_repondre(bigint, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.objet_montrer(text, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sante_paliers_lire() TO authenticated;
