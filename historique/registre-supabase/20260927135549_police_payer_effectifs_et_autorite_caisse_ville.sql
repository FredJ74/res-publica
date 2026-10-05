-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927135549
-- Nom original      : police_payer_effectifs_et_autorite_caisse_ville
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 13:55:49 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 56769d1dcb297542b10e9565a980e8ac
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LOT 3c — LA PAYE POLICIERE PASSE DU NAVIGATEUR AU CRON, ET L'AUTORITE DE CAISSE APPREND LA
-- VILLE (27 septembre 2026)
--
-- CE QUI N'ALLAIT PAS. La paye etait prelevee par le `doDormir()` de N'IMPORTE QUEL joueur
-- present dans la ville. Or le debit de la caisse du commissariat n'exige que le POSTE
-- (`{commissaire, min_int}`), jamais la VILLE, alors que l'ecriture des effectifs, elle, exige le
-- commissaire DE CETTE VILLE. Un commissaire d'une autre ville, ou le ministre de l'Interieur,
-- qui dormait la : le debit passait, l'ecriture etait refusee. Argent sorti de la caisse,
-- `dernierPaiementJour` non avance, aucun policier paye ni retire. Seul le sommeil du commissaire
-- local bouclait correctement.
--
-- DEUX CORRECTIONS, ET ELLES SONT COMPLEMENTAIRES :
--   1. la paye devient une tache de cron, comme la douane. Le chemin client disparait, donc la
--      fuite decrite ci-dessus n'a plus d'occasion de se produire ;
--   2. l'autorite de caisse apprend la ville, pour que la meme fuite ne puisse pas revenir par
--      une autre porte.

-- ---------------------------------------------------------------------------------------
-- 1. L'AUTORITE DE CAISSE APPREND LA VILLE
-- ---------------------------------------------------------------------------------------
-- Les caisses locales sont nommees `<pays>_<categorie>_<ville>`. La ville est donc DEJA dans
-- l'identifiant : il suffisait de la lire. Regle posee, volontairement minimale :
--   * un poste NATIONAL (sans ville : min_int, min_fin, pm...) conserve son acces -- comportement
--     inchange, c'est ce qui permet a un ministre de renflouer une caisse locale ;
--   * un poste DE VILLE (commissaire, maire, juge...) ne peut agir que sur SA ville.
-- Un separateur `_` designe une ville, conformement a `getCaisseLocaleId(categorie, ville)`.
-- Un `-` n'en designe pas une : `commissariat-local` reste un batiment, pas une ville.
CREATE OR REPLACE FUNCTION public.caisse_ville_de(p_caisse text, p_pays text)
RETURNS text LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE v_suffixe text; r record;
BEGIN
  v_suffixe := regexp_replace(p_caisse, '^' || p_pays || '_', '');
  IF v_suffixe LIKE 'gouvernement-%' THEN RETURN NULL; END IF;   -- ministere : national
  SELECT * INTO r FROM public.caisses_autorites c
   WHERE c.est_prefixe AND v_suffixe LIKE c.motif || '\_%'
   ORDER BY length(c.motif) DESC LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN substring(v_suffixe from '^' || r.motif || '_(.+)$');
END; $$;

CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement_plafonne(
  p_id text, p_montant numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_data jsonb; v_solde numeric; v_verse numeric;
        v_moi text; v_pays text; v_postes text[]; v_ville text;
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_montant IS NULL OR p_montant <= 0
     OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  IF coalesce(current_setting('rp.caisse_interne', true), '') <> 'on'
     AND NOT public.est_appel_serveur() THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
    IF v_pays IS NULL OR p_id NOT LIKE v_pays || '\_%' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_pays');
    END IF;
    v_postes := public.caisse_postes_requis(p_id, v_pays);
    v_ville  := public.caisse_ville_de(p_id, v_pays);
    IF v_postes IS NOT NULL THEN
      IF array_length(v_postes, 1) IS NULL
         OR NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                         WHERE a.poste_id = ANY (v_postes) AND a.pays = v_pays
                           -- LA VILLE : un poste national passe, un poste de ville doit etre
                           -- celui de CETTE ville.
                           AND (v_ville IS NULL OR a.poste_city IS NULL
                                OR a.poste_city = v_ville)) THEN
        INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
        VALUES (v_moi, p_id, -p_montant, 'primitive_heritee_plafonnee', false,
                CASE WHEN v_ville IS NULL THEN 'autorite_insuffisante'
                     ELSE 'autorite_insuffisante_hors_ville' END);
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'verse', 0);
      END IF;
    END IF;
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', 0);
  END IF;
  v_solde := CASE WHEN jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  v_verse := least(greatest(v_solde, 0), p_montant);
  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', v_solde);
  END IF;
  UPDATE public.caisses_batiments
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
         updated_at = now()
   WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'solde', v_solde - v_verse);
END; $$;

-- ---------------------------------------------------------------------------------------
-- 2. LA PAYE, COTE SERVEUR
-- ---------------------------------------------------------------------------------------
-- Reprend au comportement pres la fonction cliente qu'elle remplace : cout 50 FR standard /
-- 100 FR cynophile, debit PLAFONNE sur la caisse du commissariat de la ville, accumulation
-- gloutonne du plus ancien au plus recent, les DERNIERS RECRUTES partent en premier, aucune
-- dette, aucun salaire differe.
-- La police etant MULTI-VILLE, on boucle sur toutes les villes du pays qui portent un effectif.
-- Le marqueur `dernierPaiementJour` est par ville : un seul prelevement par ville et par jour,
-- quel que soit le nombre d'appels.
-- Le jour retenu est la JOURNEE ECOULEE, comme pour la douane -- une seule convention temporelle
-- dans tout le cron.
CREATE OR REPLACE FUNCTION public.police_payer_effectifs(p_pays text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  c_standard  constant integer := 50;
  c_cynophile constant integer := 100;
  v_serveur boolean; v_moi text; v_poste text;
  v_jour date; r record; v_etat jsonb; v_eff jsonb; v_liste jsonb;
  v_du numeric; v_verse numeric; v_rep jsonb; v_n integer; v_gardes integer;
  v_cumul numeric; v_el jsonb; v_caisse text;
  v_villes jsonb := '[]'::jsonb; v_total_verse numeric := 0; v_total_partis integer := 0;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  v_serveur := public.est_appel_serveur();
  IF NOT v_serveur THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
    SELECT (poste->>'id') INTO v_poste FROM public.personnages_donnees WHERE name = v_moi;
    IF v_poste IS DISTINCT FROM 'min_int' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
    IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees
                    WHERE name = v_moi AND COALESCE(country,'republic') = p_pays) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_hors_autorite'); END IF;
  END IF;

  v_jour := ((now() AT TIME ZONE 'Europe/Paris')::date - 1);

  FOR r IN SELECT b.id, b.city, b.building_id, b.data
             FROM public.batiments_etat b
            WHERE b.country = p_pays
              AND b.building_id IN ('commissariat','commissariat-local')
            ORDER BY b.city
            FOR UPDATE
  LOOP
    v_etat := COALESCE(public.batiment_etat_lire(r.data), '{}'::jsonb);
    v_eff  := v_etat -> 'effectifsPolice';
    CONTINUE WHEN v_eff IS NULL OR jsonb_typeof(v_eff) <> 'object';
    CONTINUE WHEN COALESCE(v_eff ->> 'dernierPaiementJour', '') = v_jour::text;

    v_liste := COALESCE(v_eff -> 'policiers', '[]'::jsonb);
    IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;
    v_n := jsonb_array_length(v_liste);

    IF v_n = 0 THEN
      v_etat := jsonb_set(v_etat, ARRAY['effectifsPolice','dernierPaiementJour'],
                          to_jsonb(v_jour::text), true);
      UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
       WHERE id = r.id;
      v_villes := v_villes || jsonb_build_array(jsonb_build_object(
        'ville', r.city, 'effectif_avant', 0, 'verse', 0, 'partis', 0));
      CONTINUE;
    END IF;

    v_du := 0;
    FOR v_el IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
      v_du := v_du + CASE WHEN COALESCE(v_el->>'type','standard') = 'cynophile'
                          THEN c_cynophile ELSE c_standard END;
    END LOOP;

    -- La caisse est celle du commissariat DE CETTE VILLE. L'autorite propre a l'operation vient
    -- d'etre verifiee : on ouvre la porte interne pour cette transaction seulement.
    v_caisse := p_pays || '_commissariat_' || r.city;
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_rep := public.caisse_institution_mouvement_plafonne(v_caisse, v_du);
    PERFORM set_config('rp.caisse_interne', '', true);
    IF NOT COALESCE((v_rep->>'ok')::boolean, false) THEN
      v_villes := v_villes || jsonb_build_array(jsonb_build_object(
        'ville', r.city, 'refus', COALESCE(v_rep->>'raison','debit_refuse')));
      CONTINUE;
    END IF;
    v_verse := COALESCE((v_rep->>'verse')::numeric, 0);

    v_cumul := 0; v_gardes := 0;
    FOR v_el IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
      v_cumul := v_cumul + CASE WHEN COALESCE(v_el->>'type','standard') = 'cynophile'
                                THEN c_cynophile ELSE c_standard END;
      EXIT WHEN v_cumul > v_verse;
      v_gardes := v_gardes + 1;
    END LOOP;

    IF v_gardes < v_n THEN
      SELECT COALESCE(jsonb_agg(e ORDER BY o), '[]'::jsonb) INTO v_liste
        FROM jsonb_array_elements(v_liste) WITH ORDINALITY AS t(e, o)
       WHERE o <= v_gardes;
      v_etat := jsonb_set(v_etat, ARRAY['effectifsPolice','policiers'], v_liste, true);
    END IF;
    v_etat := jsonb_set(v_etat, ARRAY['effectifsPolice','dernierPaiementJour'],
                        to_jsonb(v_jour::text), true);
    UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
     WHERE id = r.id;

    v_total_verse  := v_total_verse + v_verse;
    v_total_partis := v_total_partis + (v_n - v_gardes);
    v_villes := v_villes || jsonb_build_array(jsonb_build_object(
      'ville', r.city, 'caisse', v_caisse, 'du', v_du, 'verse', v_verse,
      'effectif_avant', v_n, 'effectif_apres', v_gardes, 'partis', v_n - v_gardes));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'jour', v_jour, 'pays', p_pays,
    'verse_total', v_total_verse, 'partis_total', v_total_partis, 'villes', v_villes);
END; $$;

REVOKE ALL ON FUNCTION public.caisse_ville_de(text,text)          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.police_payer_effectifs(text)        FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.police_payer_effectifs(text)     TO authenticated, service_role;