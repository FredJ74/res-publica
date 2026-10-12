-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012093701 (UTC), nom
-- `parquet_requalification_et_consignation_qui_ne_se_tait_plus`.
-- Le registre passe de 675 a 676 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 48ab091d0c2c52efb49a1c211d64c4d8, 8787 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE PARQUET (5/7) -- LE TYPE MANQUANT, ET UNE CONSIGNATION QUI NE SE TAIT PLUS
--
-- DEUX DEFAUTS TROUVES PAR UNE SEULE EPREUVE DU BANC, et le second est le plus grave.
--
-- `requalification` manquait a la liste blanche des types d'actes : douze types etaient declares,
-- et la requalification du juge -- l'un des faits que le cahier des charges exige de pouvoir
-- retrouver -- n'en faisait pas partie. Il y en a treize.
--
-- ET LA CONSIGNATION ECHOUAIT EN SILENCE. `dossier_acte_consigner` rendait
-- `{ok: false, raison: 'type_acte_inconnu'}` -- un refus propre, honnete, et parfaitement inutile :
-- ses ONZE appelants sont internes et l'invoquent tous par `PERFORM`, qui JETTE la valeur rendue.
-- Le jugement s'enregistrait, le dossier recevait sa qualification finale, la porte repondait
-- `ok: true` avec `requalifiee: true` -- et l'acte de requalification n'existait nulle part.
--
-- LA CORRECTION N'EST PAS D'AJOUTER LE TYPE, C'EST DE CHANGER LA FACON D'ECHOUER. Une fonction
-- interne dont l'appelant ne peut rien faire du refus doit LEVER. La transaction entiere --
-- jugement compris -- est desormais annulee si la chronologie ne peut pas etre ecrite : un acte
-- judiciaire et sa trace sont le meme fait, ou ils ne valent rien.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE PARQUET DE REPUBLIA (5/5) -- LE TYPE MANQUANT, ET UNE CONSIGNATION QUI NE SE TAIT PLUS
-- 12 octobre 2026
--
-- DEUX DEFAUTS, TROUVES PAR UNE SEULE EPREUVE DU BANC, ET LE SECOND EST LE PLUS GRAVE.
--
-- UN -- `requalification` MANQUAIT A LA LISTE BLANCHE DES TYPES D'ACTES. Douze types etaient
-- declares ; la requalification du juge, qui est precisement l'un des faits que le cahier des
-- charges exige de pouvoir retrouver, n'en faisait pas partie. Il y en a treize.
--
-- DEUX -- ET LA CONSIGNATION ECHOUAIT EN SILENCE. `dossier_acte_consigner` rendait
-- `{ok: false, raison: 'type_acte_inconnu'}` -- un refus propre, honnete, et parfaitement inutile :
-- ses ONZE appelants sont internes et l'invoquent tous par `PERFORM`, qui JETTE la valeur rendue.
-- Le jugement s'enregistrait donc normalement, le dossier recevait sa qualification finale, la
-- porte repondait `ok: true` avec `requalifiee: true` -- et l'acte de requalification n'existait
-- nulle part. Une chronologie a trou, sans un signal.
--
-- LA CORRECTION N'EST PAS D'AJOUTER LE TYPE, C'EST DE CHANGER LA FACON D'ECHOUER. Une fonction
-- INTERNE dont l'appelant ne peut rien faire du refus ne doit pas rendre un refus : elle doit
-- LEVER. `dossier_acte_consigner` leve desormais, et la transaction entiere -- jugement compris --
-- est annulee si la chronologie ne peut pas etre ecrite. C'est la seule garantie qui tienne : un
-- acte judiciaire et sa trace sont le meme fait, ou ils ne valent rien.
--
-- C'est le defaut deja rencontre deux fois dans ce projet sous une autre forme -- le registre des
-- causes qui repondait `ok` sans rien ecrire, et le courrier avale qui faisait croire qu'un acte
-- avait eu lieu. Ici, c'est l'inverse exact : l'acte avait lieu, et sa trace etait avalee.

-- ============================================================================================
-- 1. LE TREIZIEME TYPE
-- ============================================================================================
INSERT INTO public.dossiers_judiciaires_actes_types (type, libelle, pose_par, note) VALUES
  ('requalification', 'Requalification des faits par le juge', 'juge',
   'Porte la qualification AVANT et APRES. Elle n''efface pas celle du parquet : les deux coexistent, et c''est la raison d''etre des colonnes qualif_avant / qualif_apres.')
ON CONFLICT (type) DO UPDATE SET libelle = EXCLUDED.libelle,
  pose_par = EXCLUDED.pose_par, note = EXCLUDED.note;

-- ============================================================================================
-- 2. LA CONSIGNATION LEVE AU LIEU DE SE TAIRE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.dossier_acte_consigner(
  p_affaire text, p_pays text, p_ville text, p_type text,
  p_acteur text DEFAULT NULL, p_acteur_poste text DEFAULT NULL,
  p_qualif_avant text DEFAULT NULL, p_qualif_apres text DEFAULT NULL,
  p_donnees jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_rang integer; v_id text;
BEGIN
  -- ELLE LEVE, ELLE NE REFUSE PAS. Tous ses appelants sont internes et l'invoquent par PERFORM,
  -- qui jette la valeur rendue : un refus propre serait un trou silencieux dans la chronologie.
  -- En levant, elle annule la transaction entiere -- l'acte judiciaire ET sa trace, ou ni l'un ni
  -- l'autre.
  IF NOT EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes_types t WHERE t.type = p_type) THEN
    RAISE EXCEPTION 'chronologie judiciaire : type d''acte inconnu (%)', p_type;
  END IF;
  IF coalesce(btrim(coalesce(p_affaire, '')), '') = '' THEN
    RAISE EXCEPTION 'chronologie judiciaire : acte sans affaire';
  END IF;
  IF coalesce(btrim(coalesce(p_pays, '')), '') = '' THEN
    RAISE EXCEPTION 'chronologie judiciaire : acte sans pays (affaire %)', p_affaire;
  END IF;

  -- LE RANG EST CALCULE PAR LE SERVEUR. La contrainte UNIQUE (affaire, rang) fait le reste :
  -- deux actes simultanes sur la meme affaire ne peuvent pas partager un rang.
  SELECT coalesce(max(a.rang), 0) + 1 INTO v_rang
    FROM public.dossiers_judiciaires_actes a WHERE a.affaire = p_affaire;
  v_id := 'acte-' || p_affaire || '-' || v_rang;
  INSERT INTO public.dossiers_judiciaires_actes
    (id, affaire, pays, ville, rang, type, acteur, acteur_poste,
     qualif_avant, qualif_apres, donnees)
  VALUES (v_id, p_affaire, p_pays, p_ville, v_rang, p_type, p_acteur, p_acteur_poste,
          p_qualif_avant, p_qualif_apres, p_donnees);
  RETURN jsonb_build_object('ok', true, 'acte', v_id, 'rang', v_rang);
END;
$$;
COMMENT ON FUNCTION public.dossier_acte_consigner(text,text,text,text,text,text,text,text,jsonb) IS
  'Ajoute un acte a la chronologie d''un dossier. INTERNE : aucun client ne l''appelle, sinon un navigateur pourrait fabriquer un fait procedural. ELLE LEVE au lieu de refuser -- ses onze appelants l''invoquent par PERFORM, qui jette la valeur rendue, donc un refus propre serait un trou silencieux dans la chronologie. En levant, elle annule la transaction entiere : l''acte judiciaire et sa trace sont le meme fait, ou ils ne valent rien.';

-- ============================================================================================
-- 3. PREUVES STRUCTURELLES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : TREIZE TYPES, et `requalification` en fait partie.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes_types;
  IF v_n <> 13 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % type(s) d''acte au lieu de 13', v_n; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes_types
                  WHERE type = 'requalification' AND pose_par = 'juge') THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le type requalification manque toujours'; END IF;

  -- P2 : LES TREIZE TYPES DE LA CHAINE SONT TOUS LA. Depuis que la consignation LEVE, un type
  --      manquant annule la transaction au lieu de creuser un trou -- mais mieux vaut le savoir
  --      ici qu'au premier jugement.
  SELECT count(*) INTO v_n FROM (VALUES
    ('plainte_deposee'),('affaire_transmise_police'),('enquete_diligentee'),
    ('enquete_acte_police'),('non_lieu'),('poursuites_engagees'),('juge_saisi'),
    ('abandon_poursuites'),('juge_arret_accepte'),('juge_poursuite_maintenue'),
    ('requalification'),('relaxe'),('condamnation')) AS attendu(t)
   WHERE EXISTS (SELECT 1 FROM public.dossiers_judiciaires_actes_types y WHERE y.type = attendu.t);
  IF v_n <> 13 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- % type(s) attendu(s) presents sur 13', v_n; END IF;

  -- P3 : LA CONSIGNATION LEVE. Plus aucun refus propre sur un type inconnu : ses appelants
  --      l'invoquent par PERFORM et ne pourraient pas le lire.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'dossier_acte_consigner';
  IF position('RAISE EXCEPTION ''chronologie judiciaire : type d''''acte inconnu' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la consignation ne leve pas sur un type inconnu'; END IF;
  IF position('''raison'', ''type_acte_inconnu''' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le refus silencieux subsiste'; END IF;

  -- P4 : ET ELLE REFUSE AUSSI UN ACTE SANS AFFAIRE NI PAYS -- deux NULL qui produiraient une
  --      ligne de chronologie orpheline, donc inexploitable par les couches futures.
  IF position('acte sans affaire' IN v_txt) = 0 OR position('acte sans pays' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- un acte orphelin serait accepte'; END IF;

  -- P5 : ONZE APPELANTS, ET CE SONT LES SEULS. Trois portes historiques migrees (depot, enquete
  --      de police, transmission), les cinq actes du parquet, et les trois actes du juge.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND position('public.dossier_acte_consigner(' IN pg_get_functiondef(p.oid)) > 0
     AND p.proname <> 'dossier_acte_consigner';
  IF v_n <> 11 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- % appelant(s) de la consignation au lieu de 11', v_n; END IF;

  -- P6 : ET AUCUN D'EUX N'EST ACCESSIBLE A anon. La chronologie n'a qu'une porte d'ecriture, et
  --      elle n'est accordee qu'au serveur.
  SELECT count(*) INTO v_n FROM pg_proc p, aclexplode(p.proacl) ae
   LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'dossier_acte_consigner'
     AND coalesce(r.rolname, 'PUBLIC') IN ('anon', 'authenticated', 'PUBLIC');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- un client peut consigner un acte procedural'; END IF;

  RAISE NOTICE 'LES 6 PREUVES SONT VERTES.';
END
$preuves$;
