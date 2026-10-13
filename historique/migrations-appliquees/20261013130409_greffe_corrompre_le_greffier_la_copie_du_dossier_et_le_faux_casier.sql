-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013130409 (UTC), nom
-- `greffe_corrompre_le_greffier_la_copie_du_dossier_et_le_faux_casier`.
-- Le registre passe de 710 a 711 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 095d9c4efcc3d0e98cb53cba9bd828fa, 24572 caracteres, 1
-- instruction au registre. Empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE REGISTRE STOCKE LE MEME CORPS SUIVI D'UN SAUT DE LIGNE FINAL : md5
-- 36ad9c46d25b656bb90d3545ddf1c208, 24573 caracteres. Le corps archive ici a ete RELU DEPUIS LE
-- REGISTRE par outils/baseline/extraire-corps-migration.py -- il n'a pas ete recopie a la main.
--
-- CORROMPRE LE GREFFIER : UNE COPIE DE DOSSIER, OU UN FAUX CASIER VIERGE
--
-- UNE SEULE MECANIQUE POUR LES DEUX PORTES, ET ELLE EXISTAIT : celle de
-- `doCorrompreFonctionnairePermis` -- couts preleves A LA TENTATIVE, jet de decouverte a 25 %,
-- denonciation du corrupteur quand il est decouvert. L'autre generique (`doCorruption`) ne
-- denonce RIEN en cas d'echec, ce que l'arbitrage exige : c'est pourquoi il n'a pas ete retenu,
-- et l'en-tete du corps le documente.
--
-- LES 300 FR SONT DETRUITS : aucune caisse ne les encaisse (preuve P4).
--
-- LA COPIE EST AUTHENTIQUE ET FIGEE ; elle reprend la definition du DOSSIER COMPLET deja posee
-- par `avocat_dossier`, sans sa garde d'avocat (preuve P9).
--
-- LE FAUX CASIER MENT, PORTE LA VRAIE DATE, ET NE TOUCHE JAMAIS AU CASIER REEL (preuve P6). Il
-- se presente comme un vrai extrait -- meme libelle, meme description, meme genre apparent.
--
-- AUCUNE MECANIQUE SPECIALE : ni vente, ni chantage, ni divulgation (preuve P8).
--
-- PREUVES STRUCTURELLES -- 11.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CORROMPRE LE GREFFIER : UNE COPIE DE DOSSIER, OU UN FAUX CASIER VIERGE.
--
-- DEUX PORTES, UNE SEULE MECANIQUE, ET ELLE EXISTAIT DEJA. Le jeu avait deja un ordre « corrompre
-- le fonctionnaire » : `doCorrompreFonctionnairePermis`, a l'instruction d'un permis de
-- construire. Sa logique est celle-ci, et c'est elle qui est reprise mot pour mot :
--   * les PA ET les FR sont preleves A LA TENTATIVE, jamais a la reussite ;
--   * un jet unique decide si la corruption est DECOUVERTE -- 25 %, la valeur existante ;
--   * decouverte : AUCUN service rendu, et le fonctionnaire DENONCE -- le corrupteur passe sous
--     avis de recherche pour `corruption_fonctionnaire`, l'infraction qui existe au code penal ;
--   * non decouverte : le service est rendu.
--
-- POURQUOI PAS L'AUTRE GENERIQUE. `doCorruption` -- les trois ordres `corrompre_fonct`,
-- `corrompre_police`, `corrompre_gardien` -- preleve les FR a la seule reussite et, en cas
-- d'ECHEC, NE FAIT RIEN : `checkDetection` rend la main des que le resultat est `fail`
-- (« Pas d'acte = pas de detection »). Elle ne DENONCE donc jamais un echec. L'arbitrage demande
-- explicitement une denonciation automatique sur echec : c'est le precedent du fonctionnaire
-- nomme qui la porte, et c'est aussi le plus proche -- on corrompt un AGENT NOMME, dans son
-- bureau, pour un acte precis.
--
-- LES 300 FR SONT DETRUITS. `payer_ordre` preleve et ne credite personne : ni le greffier, ni le
-- tribunal, ni aucune institution. C'est deja le comportement de tous les ordres de corruption du
-- jeu, et aucune caisse n'est touchee ici.
--
-- AUCUNE MECANIQUE SPECIALE N'EST CREEE. Ni vente du dossier, ni chantage, ni divulgation : le
-- document produit est un OBJET D'INVENTAIRE ORDINAIRE, comme l'extrait de casier. Ce qu'un
-- joueur en fait ensuite passe par les portes generiques de l'inventaire -- donner, detruire,
-- abandonner -- ou par le jeu social, qui n'a pas besoin de code.
--
-- LA COPIE DU DOSSIER EST AUTHENTIQUE, et c'est tout le probleme qu'elle pose en jeu : elle a ete
-- obtenue illegalement, mais elle ne mentit pas. Son contenu est celui que le DOSSIER COMPLET
-- designe deja -- la definition de `avocat_dossier`, reprise sans etre reinventee -- et il est
-- FIGE a l'instant de la copie : les actes posterieurs n'y figureront jamais.
--
-- LE FAUX CASIER, LUI, MENT. Il porte la VRAIE identite du PJ visee, affirme un casier vierge,
-- et porte la VRAIE DATE DE FABRICATION -- aucune date n'est choisie par le joueur. Il NE TOUCHE
-- JAMAIS au casier reel : le casier est derive du registre des jugements, et aucune de ces deux
-- portes n'ecrit dans ce registre (la preuve P6 le mesure). Et il se presente comme un vrai : le
-- registre des documents porte `genre = 'casier_faux'` et `authentique = false`, l'objet
-- d'inventaire porte le genre APPARENT `casier_extrait` -- rien, dans ce que le porteur ou un
-- lecteur ordinaire voit, ne dit « FAUX ».
--
-- LE CASIER EST NATIONAL, LE DOSSIER NE L'EST PAS. Un faux casier se fabrique au greffe de
-- N'IMPORTE LEQUEL des trois tribunaux ; une copie de dossier exige le greffe du tribunal
-- COMPETENT pour cette affaire. Dans les deux cas, la presence PHYSIQUE au greffe est exigee.

-- ---------------------------------------------------------------------------------------------
-- 1. LE DOSSIER COMPLET, SANS LA QUALITE D'AVOCAT
-- ---------------------------------------------------------------------------------------------
-- MEME CONTENU QUE `avocat_dossier`, et c'est volontaire : « le dossier complet » est deja
-- defini, et en redefinir une seconde version ferait deux verites. Seules les GARDES changent --
-- celle-ci n'en a aucune, elle est interne et n'a aucun droit client.
CREATE OR REPLACE FUNCTION public.dossier_judiciaire_copie(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_brut text; v_a jsonb; v_ville text; v_pays text; v_quals text[];
BEGIN
  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente'); END IF;
  v_a := v_brut::jsonb;

  v_quals := ARRAY(SELECT DISTINCT x FROM unnest(ARRAY[
      v_a ->> 'infraction_constatee', v_a ->> 'qualification_parquet',
      v_a ->> 'qualification_finale']) AS x WHERE x IS NOT NULL);

  RETURN jsonb_build_object('ok', true,
    'affaire', p_affaire_id, 'ville', v_ville, 'pays', v_pays,
    'prevenu', v_a ->> 'cible',
    'plaignant', coalesce(v_a ->> 'plaignant', v_a ->> 'auteur'),
    'motif', v_a ->> 'motif',
    'categorie_alleguee', v_a ->> 'categorie_alleguee',
    'statut', v_a ->> 'status',
    'jour_depot', v_a ->> 'jour',
    'qualification_constatee', v_a ->> 'infraction_constatee',
    'qualification_parquet', v_a ->> 'qualification_parquet',
    'qualification_finale', v_a ->> 'qualification_finale',
    'delai_jugement_jour', v_a ->> 'delai_jugement_jour',
    'audience_ouverte', public.affaire_audience_ouverte(v_a),
    'audience_jour', v_a ->> 'audience_jour',
    'audition', (SELECT jsonb_build_object(
                   'personne', a.personne, 'refus', a.refus,
                   'declaration', a.declaration, 'jour', a.jour_pv, 'fait_le', a.fait_le)
                  FROM public.dossiers_auditions a
                 WHERE a.affaire = p_affaire_id AND a.personne = (v_a ->> 'cible')
                   AND a.qualite = 'prevenu'),
    'temoins', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'temoin', c.temoin, 'cite_par', c.cite_par, 'qualite', c.cite_par_qualite,
                  'convocation', c.convocation_rang, 'echeance_jour', c.echeance_jour,
                  'etat', c.etat, 'issue', c.issue) ORDER BY c.rang), '[]'::jsonb)
                 FROM public.temoins_citations c WHERE c.affaire = p_affaire_id),
    'temoignages', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                      'personne', a.personne, 'refus', a.refus, 'declaration', a.declaration,
                      'jour', a.jour_pv, 'fait_le', a.fait_le) ORDER BY a.fait_le), '[]'::jsonb)
                     FROM public.dossiers_auditions a
                    WHERE a.affaire = p_affaire_id AND a.qualite = 'temoin'),
    'preuves', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'id', t.id, 'acte', t.type_action, 'jour', t.jour, 'ville', t.city,
                  'jour_expiration', t.jour_expiration) ORDER BY t.jour, t.id), '[]'::jsonb)
                 FROM public.actions_tracables t
                WHERE t.country IS NOT DISTINCT FROM v_pays
                  AND t.auteur = (v_a ->> 'cible')
                  AND t.type_action = ANY (v_quals)),
    'actes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                 'rang', x.rang, 'type', x.type, 'libelle', t.libelle,
                 'acteur', x.acteur, 'poste', x.acteur_poste,
                 'qualif_avant', x.qualif_avant, 'qualif_apres', x.qualif_apres,
                 'donnees', x.donnees, 'fait_le', x.fait_le) ORDER BY x.rang), '[]'::jsonb)
                FROM public.dossiers_judiciaires_actes x
                JOIN public.dossiers_judiciaires_actes_types t ON t.type = x.type
               WHERE x.affaire = p_affaire_id));
END $function$;
REVOKE ALL ON FUNCTION public.dossier_judiciaire_copie(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.dossier_judiciaire_copie(text) TO service_role;

-- ---------------------------------------------------------------------------------------------
-- 2. LA DENONCIATION, QUAND LA CORRUPTION EST DECOUVERTE
-- ---------------------------------------------------------------------------------------------
-- UNE SEULE REGLE POUR LES DEUX PORTES. `recherche_inscrire` est la porte generique de l'avis de
-- recherche -- celle que `checkDetection` appelle deja --, et `corruption_fonctionnaire` est une
-- infraction du code penal, de categorie `delit`, avec son propre bareme. Rien n'est invente :
-- ni acte, ni categorie, ni peine.
CREATE OR REPLACE FUNCTION public.greffe_denoncer_corruption(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jour integer;
BEGIN
  v_jour := coalesce(public.jour_de_jeu_pays(p_pays), 1);
  RETURN public.recherche_inscrire(jsonb_build_object(
    'acte', 'corruption_fonctionnaire', 'type', 'delit', 'jour', v_jour,
    'origine', 'greffe'));
END $function$;
REVOKE ALL ON FUNCTION public.greffe_denoncer_corruption(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.greffe_denoncer_corruption(text) TO service_role;

-- ---------------------------------------------------------------------------------------------
-- 3. CORROMPRE LE GREFFIER POUR UNE COPIE DE DOSSIER -- 300 FR ET 3 PA
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.greffe_corrompre_dossier(p_affaire_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_inv jsonb; v_g record;
        v_aff_ville text; v_aff_pays text; v_jour integer;
        v_paye jsonb; v_copie jsonb; v_doc jsonb; v_decouvert boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT country, current_city, coalesce(inventory, '[]'::jsonb)
    INTO v_pays, v_ville, v_inv
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- TOUTE AFFAIRE, EN COURS OU ARCHIVEE : aucun filtre de statut.
  SELECT p.city, p.country INTO v_aff_ville, v_aff_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_aff_ville IS NULL AND v_aff_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;

  -- LE GREFFE DU TRIBUNAL COMPETENT POUR CETTE AFFAIRE, ET LUI SEUL : un dossier ne se copie pas
  -- a distance, et pas davantage au greffe d'une autre ville.
  SELECT * INTO v_g FROM public.justice_greffe_competent(v_aff_pays, v_aff_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_aff_ville);
  END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_aff_pays, v_aff_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
                              'ville', v_aff_ville, 'site', v_g.batiment, 'piece', v_g.piece);
  END IF;
  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  -- LES DEUX COUTS SONT PRELEVES A LA TENTATIVE. C'est la regle du precedent, et l'arbitrage
  -- interdit d'y faire une exception.
  v_paye := public.payer_ordre(v_moi, 'greffe_corrompre_dossier', 3, 300);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_decouvert := random() < 0.25;

  IF v_decouvert THEN
    PERFORM public.greffe_denoncer_corruption(v_pays);
    RETURN jsonb_build_object('ok', true, 'decouvert', true, 'document', NULL,
      'raison_metier', 'corruption_decouverte', 'jour', v_jour);
  END IF;

  v_copie := public.dossier_judiciaire_copie(p_affaire_id);
  IF coalesce((v_copie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'greffe_corrompre_dossier : copie impossible (%)', v_copie ->> 'raison';
  END IF;

  v_doc := public.document_officiel_emettre(
    'dossier_copie', 'dossier_copie', true,
    v_aff_pays, v_aff_ville, v_copie ->> 'prevenu', NULL, p_affaire_id, v_moi, v_moi, v_jour,
    'Copie du dossier judiciaire ' || p_affaire_id,
    'Copie integrale etablie au greffe au jour ' || v_jour || '. Document FIGE : les actes '
      || 'posterieurs a cette date n''y figurent pas.',
    'ti-folder', v_copie,
    jsonb_build_object('motif', 'greffier_corrompu'));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'greffe_corrompre_dossier : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'decouvert', false,
    'document', v_doc ->> 'document', 'affaire', p_affaire_id,
    'jour', v_jour, 'tribunal', v_aff_ville, 'emis_par', v_doc ->> 'emis_par');
END;
$function$;
REVOKE ALL ON FUNCTION public.greffe_corrompre_dossier(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.greffe_corrompre_dossier(text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------
-- 4. CORROMPRE LE GREFFIER POUR UN FAUX CASIER VIERGE -- 300 FR ET 3 PA
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.greffe_corrompre_faux_casier(p_personne text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_inv jsonb; v_g record;
        v_jour integer; v_paye jsonb; v_doc jsonb; v_decouvert boolean; v_contenu jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF coalesce(btrim(coalesce(p_personne, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personne_manquante');
  END IF;
  -- POUR N'IMPORTE QUEL PJ, pas seulement pour soi -- et la personne doit exister : un faux au
  -- nom de quelqu'un qui n'existe pas ne serait un document de rien.
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_personne) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personne_introuvable');
  END IF;

  SELECT country, current_city, coalesce(inventory, '[]'::jsonb)
    INTO v_pays, v_ville, v_inv
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- LE CASIER EST NATIONAL : n'importe lequel des trois greffes fait l'affaire. La presence
  -- PHYSIQUE au greffe ou l'on se trouve, elle, reste exigee.
  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_ville);
  END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
                              'ville', v_ville, 'site', v_g.batiment, 'piece', v_g.piece);
  END IF;
  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  v_paye := public.payer_ordre(v_moi, 'greffe_corrompre_faux_casier', 3, 300);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_decouvert := random() < 0.25;

  IF v_decouvert THEN
    PERFORM public.greffe_denoncer_corruption(v_pays);
    RETURN jsonb_build_object('ok', true, 'decouvert', true, 'document', NULL,
      'raison_metier', 'corruption_decouverte', 'jour', v_jour);
  END IF;

  -- LE CONTENU MENT, ET IL EST LE SEUL A MENTIR : la forme est exactement celle d'un vrai
  -- extrait -- memes cles, meme ordre --, et la DATE est la vraie date de fabrication.
  v_contenu := jsonb_build_object(
    'personne', p_personne,
    'pays', v_pays,
    'vierge', true,
    'condamnations', '[]'::jsonb);

  v_doc := public.document_officiel_emettre(
    'casier_faux', 'casier_extrait', false,
    v_pays, v_ville, p_personne, NULL, NULL, v_moi, v_moi, v_jour,
    'Extrait de casier judiciaire — ' || p_personne,
    'Delivre par le greffe au jour ' || v_jour || '. Document FIGE : il dit l''etat du casier '
      || 'au moment de sa delivrance, et ne se met jamais a jour.',
    'ti-file-certificate', v_contenu,
    jsonb_build_object('motif', 'greffier_corrompu'));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'greffe_corrompre_faux_casier : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'decouvert', false,
    'document', v_doc ->> 'document', 'personne', p_personne,
    'jour', v_jour, 'tribunal', v_ville, 'emis_par', v_doc ->> 'emis_par');
END;
$function$;
REVOKE ALL ON FUNCTION public.greffe_corrompre_faux_casier(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.greffe_corrompre_faux_casier(text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------
-- 5. LES DEUX ORDRES AU MIROIR DES COUTS
-- ---------------------------------------------------------------------------------------------
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('greffe_corrompre_dossier', 3, 300),
  ('greffe_corrompre_faux_casier', 3, 300)
ON CONFLICT (fn, pa, cost) DO NOTHING;

-- =============================================================================================
-- PREUVES STRUCTURELLES
-- =============================================================================================
DO $$
DECLARE v_n integer; v_a text; v_b text;
BEGIN
  -- P1. LES DEUX PORTES SONT CLIENTES, LES DEUX INTERNES NE LE SONT PAS.
  SELECT count(*) INTO v_n FROM information_schema.role_routine_grants
   WHERE specific_schema = 'public' AND grantee = 'authenticated' AND privilege_type = 'EXECUTE'
     AND routine_name IN ('greffe_corrompre_dossier', 'greffe_corrompre_faux_casier');
  IF v_n <> 2 THEN RAISE EXCEPTION 'P1 ECHOUEE : % porte(s) cliente(s) sur 2', v_n; END IF;
  SELECT count(*) INTO v_n FROM information_schema.role_routine_grants
   WHERE specific_schema = 'public' AND grantee IN ('anon', 'authenticated')
     AND routine_name IN ('dossier_judiciaire_copie', 'greffe_denoncer_corruption');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1b ECHOUEE : % droit(s) client sur les internes', v_n; END IF;

  -- P2. LES QUATRE SONT DEFINER A SEARCH_PATH FIGE, et sans surcharge.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('greffe_corrompre_dossier', 'greffe_corrompre_faux_casier',
                       'dossier_judiciaire_copie', 'greffe_denoncer_corruption')
     AND p.prosecdef AND array_to_string(p.proconfig, ',') LIKE '%search_path=public, pg_temp%';
  IF v_n <> 4 THEN RAISE EXCEPTION 'P2 ECHOUEE : % fonction(s) conforme(s) sur 4', v_n; END IF;

  -- P3. LA MECANIQUE EST CELLE DU PRECEDENT, ET ELLE EST LA MEME DANS LES DEUX PORTES :
  -- cout preleve a la tentative, jet de decouverte a 25 %, denonciation sur decouverte.
  SELECT public.sans_commentaires(p.prosrc) INTO v_a FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'greffe_corrompre_dossier';
  SELECT public.sans_commentaires(p.prosrc) INTO v_b FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'greffe_corrompre_faux_casier';
  IF v_a !~ 'random\(\) < 0\.25' OR v_b !~ 'random\(\) < 0\.25' THEN
    RAISE EXCEPTION 'P3 ECHOUEE : le jet de decouverte n est pas celui du precedent (25 %%)';
  END IF;
  IF v_a !~ 'greffe_denoncer_corruption' OR v_b !~ 'greffe_denoncer_corruption' THEN
    RAISE EXCEPTION 'P3b ECHOUEE : une porte ne denonce pas la corruption decouverte';
  END IF;
  IF v_a !~ 'payer_ordre\(v_moi, ''greffe_corrompre_dossier'', 3, 300\)'
     OR v_b !~ 'payer_ordre\(v_moi, ''greffe_corrompre_faux_casier'', 3, 300\)' THEN
    RAISE EXCEPTION 'P3c ECHOUEE : les couts ne sont pas preleves a la tentative';
  END IF;
  -- ET LE JET VIENT APRES LE PAIEMENT : aucune exception sur la consommation des couts.
  IF position('payer_ordre' in v_a) > position('random()' in v_a)
     OR position('payer_ordre' in v_b) > position('random()' in v_b) THEN
    RAISE EXCEPTION 'P3d ECHOUEE : le jet precede le paiement dans une des deux portes';
  END IF;

  -- P4. AUCUNE CAISSE N'ENCAISSE LES 300 FR : ils sont detruits.
  IF v_a ~ 'caisse_institution_mouvement' OR v_b ~ 'caisse_institution_mouvement'
     OR v_a ~ 'batiment_caisse_mouvement' OR v_b ~ 'batiment_caisse_mouvement' THEN
    RAISE EXCEPTION 'P4 ECHOUEE : une caisse encaisse le prix de la corruption';
  END IF;

  -- P5. LE FAUX SE PRESENTE COMME UN VRAI, et le registre sait qu'il est faux.
  IF v_b !~ '''casier_faux'', ''casier_extrait'', false' THEN
    RAISE EXCEPTION 'P5 ECHOUEE : le faux casier ne se presente pas comme un vrai extrait';
  END IF;
  -- Son libelle et sa description sont ceux de l'extrait authentique, mot pour mot.
  IF v_b !~ 'Extrait de casier judiciaire — ' OR v_b !~ 'Document FIGE' THEN
    RAISE EXCEPTION 'P5b ECHOUEE : le faux ne porte pas le libelle de l extrait authentique';
  END IF;

  -- P6. NI LA COPIE NI LE FAUX NE TOUCHENT AU REGISTRE DES JUGEMENTS, donc jamais au vrai casier.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('greffe_corrompre_dossier', 'greffe_corrompre_faux_casier',
                       'dossier_judiciaire_copie')
     AND public.sans_commentaires(p.prosrc) ~ '(INSERT INTO public.jugements|UPDATE public.jugements|DELETE FROM public.jugements|UPDATE public.plaintes_en_cours)';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE : % porte(s) de corruption ecrivent au registre ou au dossier', v_n;
  END IF;

  -- P7. LA PRESENCE AU GREFFE EST EXIGEE DANS LES DEUX, et la copie exige le greffe COMPETENT.
  IF v_a !~ 'presence_au_greffe_requise' OR v_b !~ 'presence_au_greffe_requise' THEN
    RAISE EXCEPTION 'P7 ECHOUEE : une porte ne verifie pas la presence au greffe';
  END IF;
  IF v_a !~ 'justice_greffe_competent\(v_aff_pays, v_aff_ville\)' THEN
    RAISE EXCEPTION 'P7b ECHOUEE : la copie du dossier n exige pas le greffe du tribunal competent';
  END IF;
  IF v_b !~ 'justice_greffe_competent\(v_pays, v_ville\)' THEN
    RAISE EXCEPTION 'P7c ECHOUEE : le faux casier n exige pas un greffe';
  END IF;

  -- P8. AUCUNE MECANIQUE SPECIALE N'EST CREEE : ni vente, ni chantage, ni divulgation.
  IF v_a ~ '(vente|vendre|chantage|divulg)' OR v_b ~ '(vente|vendre|chantage|divulg)' THEN
    RAISE EXCEPTION 'P8 ECHOUEE : une mecanique speciale a ete codee sur le document';
  END IF;

  -- P9. LA COPIE DU DOSSIER EST LE DOSSIER COMPLET, et c'est la MEME definition que celle de
  -- l'avocat : les deux fonctions nomment les memes sept blocs.
  SELECT public.sans_commentaires(p.prosrc) INTO v_a FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'dossier_judiciaire_copie';
  SELECT public.sans_commentaires(p.prosrc) INTO v_b FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'avocat_dossier';
  SELECT count(*) INTO v_n FROM unnest(ARRAY['''audition''', '''temoins''', '''temoignages''',
         '''preuves''', '''actes''', '''prevenu''', '''plaignant''']) AS x
   WHERE v_a LIKE '%' || x || '%' AND v_b LIKE '%' || x || '%';
  IF v_n <> 7 THEN
    RAISE EXCEPTION 'P9 ECHOUEE : % bloc(s) communs sur 7 entre la copie et le dossier d avocat', v_n;
  END IF;
  -- ET ELLE N'A PAS LA GARDE DE L'AVOCAT : c'est tout ce qui les distingue.
  IF v_a ~ 'defense_avocat_de' OR v_a ~ 'pas_mon_dossier' THEN
    RAISE EXCEPTION 'P9b ECHOUEE : la copie a herite de la garde de l avocat';
  END IF;

  -- P10. LES DEUX ORDRES SONT AU MIROIR DES COUTS, aux montants de l'arbitrage.
  SELECT count(*) INTO v_n FROM public.ordres_couts
   WHERE (fn, pa, cost) IN (('greffe_corrompre_dossier', 3, 300),
                            ('greffe_corrompre_faux_casier', 3, 300));
  IF v_n <> 2 THEN RAISE EXCEPTION 'P10 ECHOUEE : % ligne(s) sur 2 au miroir', v_n; END IF;

  -- P11. AUCUN DOCUMENT N'EST EMIS PAR LA MIGRATION.
  SELECT count(*) INTO v_n FROM public.documents_officiels;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P11 ECHOUEE : % document(s) emis', v_n; END IF;

  RAISE NOTICE 'LES 11 PREUVES STRUCTURELLES SONT VERTES.';
END $$;
