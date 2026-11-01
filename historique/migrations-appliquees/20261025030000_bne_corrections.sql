-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261025010423.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025010423.
-- Eprouvee avant application en transaction annulee (10 cas). Baseline NON reextrait.
-- ============================================================================
-- BUREAU NATIONAL DE L'EMPLOI -- corrections de l'audit (AUDIT_BNE.md) et decisions de Fred
-- (25 octobre 2026)
-- ============================================================================
-- 1. SALAIRES DES EMPLOIS LOCAUX PAYES PAR LEUR EMPLOYEUR (decision de Fred, 25/10, B9). La
--    regle du 20 septembre -- chaque salaire est paye par la caisse de son institution, seul le
--    revenu universel est cree de rien -- s'applique desormais aux trois emplois locaux :
--      serveur_luthecia   -> caisse de l'hotel de Luthecia (Hotel Republica)
--      hotelier_montrouge -> caisse de l'hotel de Montrouge (Hotel du Mineur)
--      docker_psm         -> caisse du Port de Port-Sainte-Marie
--    Caisse vide : le salaire n'est pas verse, exactement comme pour un poste.
--    Correctif trouve au banc : salaire_civil_percevoir lisait le registre du BNE comme un
--    objet alors qu'il est enregistre en texte JSON -- aucun emploi n'etait jamais paye.
-- 2. bne_agir (patch en place) :
--    B1  -- trancher exige une reservation en attente : un bouton de mail rejoue ne fait plus
--           perdre son emploi au joueur ; refus nomme 'aucune_reservation'.
--    B10 -- trancher avec une offre inconnue est refuse ('offre_inconnue').
--    B5  -- prendre un emploi est refuse a qui occupe un poste (colonne poste) ; le mandat de
--           depute, tenu a part (poste_depute), reste cumulable (decision de Fred, 25/10).
--    B6  -- prendre un emploi exige l'inscription comme demandeur d'emploi.
--    B7  -- une offre locale ne se prend que depuis sa ville.
-- 3. bne_inscrire : inscription par le serveur, 1 PA preleve une seule fois (B6).
-- Patchs en place sur fragments exacts (WORKFLOW-SUPABASE.md) ; deja patche = laisse tel quel.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES
  ('serveur_luthecia',   '{pays}_hotel_capitale',      false, 'emploi BNE -- Hotel Republica (decision Fred 25/10/2026)', NULL),
  ('hotelier_montrouge', '{pays}_hotel_ville_b',       false, 'emploi BNE -- Hotel du Mineur (decision Fred 25/10/2026)', NULL),
  ('docker_psm',         '{pays}_port-sainte-marie',   false, 'emploi BNE -- Port de Port-Sainte-Marie (decision Fred 25/10/2026)', NULL)
ON CONFLICT (poste_id) DO UPDATE SET motif = excluded.motif, par_ville = excluded.par_ville,
  note = excluded.note, ville_defaut = excluded.ville_defaut;

DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'IF v_origine = ''poste'' THEN\n    v_caisse := public.salaire_caisse_de(v_poste, v_pays, v_ville);\n    IF v_caisse IS NULL THEN\n      RETURN jsonb_build_object(''ok'', false, ''raison'', ''caisse_payeuse_non_declaree'', ''poste'', v_poste);\n    END IF;\n  END IF;\n';
  v_ajout text := E'  -- Emplois du Bureau de l''Emploi (25/10/2026, decision de Fred) : payes par leur employeur.\n  IF v_origine = ''emploi'' THEN\n    v_caisse := public.salaire_caisse_de(v_cle, v_pays, NULL);\n    IF v_caisse IS NULL THEN\n      RETURN jsonb_build_object(''ok'', false, ''raison'', ''caisse_payeuse_non_declaree'', ''poste'', v_cle);\n    END IF;\n  END IF;\n';
  -- Le registre du BNE est enregistre comme TEXTE JSON (bne_agir) : `data -> 'offres'` y rendait
  -- NULL, et un employe du Bureau ne touchait que le revenu universel. Lecture par
  -- batiment_etat_lire, comme partout ailleurs.
  v_frag_lec text := E'SELECT coalesce(e.data -> ''offres'', e.data -> ''bne'' -> ''offres'')';
  v_lec text := E'SELECT coalesce(public.batiment_etat_lire(e.data) -> ''offres'', public.batiment_etat_lire(e.data) -> ''bne'' -> ''offres'')';
BEGIN
  v_def := pg_get_functiondef('public.salaire_civil_percevoir()'::regprocedure);
  v_new := v_def;
  IF position('IF v_origine = ''emploi''' in v_new) = 0 THEN
    v_new := replace(v_new, v_frag, v_frag || v_ajout);
    IF position('IF v_origine = ''emploi''' in v_new) = 0 THEN
      RAISE EXCEPTION 'patch non applique : fragment de salaire_civil_percevoir introuvable';
    END IF;
  END IF;
  IF position('batiment_etat_lire' in v_new) = 0 THEN
    v_new := replace(v_new, v_frag_lec, v_lec);
    IF position('batiment_etat_lire' in v_new) = 0 THEN
      RAISE EXCEPTION 'patch non applique : lecture du registre BNE introuvable dans salaire_civil_percevoir';
    END IF;
  END IF;
  IF v_new <> v_def THEN EXECUTE v_new; END IF;
END $mig$;

DO $mig$
DECLARE v_def text; v_new text;
  v_frag1 text := E'  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;\n  IF v_pays IS NULL THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''pays_inconnu''); END IF;\n';
  v_ajout1 text := E'  -- Audit du BNE (25/10/2026) : B5, B6, B7.\n  IF p_acte IN (''prendre'',''reserver'') THEN\n    IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_moi AND coalesce(poste ->> ''id'','''') NOT IN ('''',''depute'')) THEN\n      RETURN jsonb_build_object(''ok'', false, ''raison'', ''poste_politique'');\n    END IF;\n    IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_moi AND demandeur_emploi) THEN\n      RETURN jsonb_build_object(''ok'', false, ''raison'', ''inscription_requise'');\n    END IF;\n    IF EXISTS (SELECT 1 FROM public.offres_emploi_bne o WHERE o.id = p_offre AND o.portee = ''locale''\n                 AND o.ville IS DISTINCT FROM (SELECT coalesce(current_city,''capitale'') FROM public.personnages_donnees WHERE name = v_moi)) THEN\n      RETURN jsonb_build_object(''ok'', false, ''raison'', ''hors_ville'');\n    END IF;\n  END IF;\n';
  v_frag2 text := E'  IF p_acte IN (''prendre'',''reserver'') THEN\n    IF EXISTS (SELECT 1 FROM jsonb_each(v_offres) o,';
  v_ajout2 text := E'  -- Audit du BNE (25/10/2026) : B1 et B10 -- trancher exige une offre connue et une\n  -- reservation en attente ; un bouton de mail rejoue ne fait plus perdre son emploi.\n  IF p_acte IN (''trancher_garder'',''trancher_prendre'') THEN\n    IF NOT EXISTS (SELECT 1 FROM public.offres_emploi_bne WHERE id = p_offre) THEN\n      RETURN jsonb_build_object(''ok'', false, ''raison'', ''offre_inconnue'');\n    END IF;\n    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_offres -> p_offre)=''array''\n                     THEN v_offres -> p_offre ELSE ''[]''::jsonb END) e\n                    WHERE e ->> ''pjNom'' = v_moi AND e ->> ''statut'' = ''en_attente_arbitrage'') THEN\n      RETURN jsonb_build_object(''ok'', false, ''raison'', ''aucune_reservation'');\n    END IF;\n  END IF;\n\n';
BEGIN
  v_def := pg_get_functiondef('public.bne_agir(text,text,text)'::regprocedure);
  IF position('aucune_reservation' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag1, v_frag1 || v_ajout1);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : fragment 1 de bne_agir introuvable'; END IF;
  v_def := v_new;
  v_new := replace(v_def, v_frag2, v_ajout2 || v_frag2);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : fragment 2 de bne_agir introuvable'; END IF;
  EXECUTE v_new;
END $mig$;

-- B6 bis : l'inscription passe par le serveur et ne coute qu'une fois (1 PA, cout declare de
-- l'ordre sinscrire_demandeur_emploi). Deja inscrit : reponse ok, rien n'est preleve.
CREATE OR REPLACE FUNCTION public.bne_inscrire()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_deja boolean; v_paie jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT coalesce(demandeur_emploi, false) INTO v_deja
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_deja THEN
    RETURN jsonb_build_object('ok', true, 'deja_inscrit', true);
  END IF;
  v_paie := public.payer_ordre(v_moi, 'sinscrire_demandeur_emploi', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN v_paie;
  END IF;
  UPDATE public.personnages_donnees SET demandeur_emploi = true, updated_at = now()
   WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'deja_inscrit', false, 'pa', v_paie -> 'pa');
END; $function$;
REVOKE ALL ON FUNCTION public.bne_inscrire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bne_inscrire() TO authenticated;
