-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916193641
-- Nom original      : justice_qhs_autorite_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 19:36:41 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 25dace9925b0b26417da40b14655e99d
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
-- LE QHS PASSE SOUS AUTORITE SERVEUR (16 septembre 2026).
--
-- LES DEFAUTS. Les trois pouvoirs du Ministre de la Justice sur un detenu du QHS -- transfert,
-- amelioration des conditions, torture -- ecrivaient directement la fiche de la CIBLE. Depuis le
-- chantier B la vue personnages refuse cette ecriture : la ligne prisonniers_qhs changeait bien
-- d'etat (table ouverte) et l'interface annoncait le resultat, mais le detenu ne subissait rien.
--
-- L'amelioration avait en plus une consequence financiere : 500 FR sortaient reellement de la
-- caisse du QHS (debiterCaisseBatimentAtomique, RPC serveur) avant l'ecriture refusee -- argent
-- public detruit, exactement comme la subvention.
--
-- La torture etait DOUBLEMENT cassee : elle ecrivait des colonnes `inf`, `pop`, `dis` qui
-- n'existent pas -- ce sont des cles du blob `resources`. Meme sans RLS, elle n'aurait rien fait.
--
-- LA SOURCE DE VERITE EST `detentions` (arbitrage du 16 septembre 2026). Le serveur n'accepte un
-- pouvoir QHS que si la CIBLE A UNE DETENTION CANONIQUE ACTIVE -- il ne lit jamais le
-- est_emprisonne fourni par le client. Le miroir de la fiche est mis a jour dans la meme
-- transaction, pour qu'aucune divergence ne s'installe.
--
-- Les regles de jeu sont inchangees : autorite min_just, cout 500 FR pour l'amelioration,
-- +15 Moral plafonne a 100, torture qui remet indices et moral a zero et plafonne les PA a 1 le
-- lendemain. Aucune duree, aucun montant, aucun effet n'est invente.

-- Detention canonique active : lue dans detentions, jamais dans la fiche. Une detention est
-- active tant qu'elle n'a pas de fin effective et que son jour de fin n'est pas depasse --
-- memes colonnes que celles deja utilisees par le filet de securite nocturne.
CREATE OR REPLACE FUNCTION public.detention_active(p_nom text)
RETURNS TABLE (id text, country text, city text, jour_debut integer, jour_fin integer, qhs boolean)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT d.id, d.country, d.city, d.jour_debut, d.jour_fin, coalesce(d.qhs, false)
    FROM public.detentions d
   WHERE d.nom = p_nom
     AND d.mode_fin IS NULL
     AND d.jour_fin_effective IS NULL
   ORDER BY d.created_at DESC
   LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.qhs_pouvoir(p_prisonnier_id text, p_acte text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_acteur text; v_pays text; v_data jsonb; v_nom text; v_det record;
  v_caisse text; v_solde numeric; v_cout integer := 500; v_res jsonb; v_moral integer;
BEGIN
  -- 1. AUTORITE : le poste est relu sur la ligne de l'appelant, jamais annonce par lui.
  v_acteur := public.exiger_poste('min_just');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_acte NOT IN ('transferer', 'ameliorer', 'torturer') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;

  -- 2. LE PRISONNIER DU REGISTRE QHS.
  SELECT data INTO v_data FROM public.prisonniers_qhs
   WHERE id = p_prisonnier_id AND coalesce(statut, '') <> 'transfere' FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prisonnier_introuvable');
  END IF;
  v_nom := v_data->>'nom';

  -- 3. LA DETENTION CANONIQUE. Sans elle, aucun pouvoir QHS ne s'exerce.
  SELECT * INTO v_det FROM public.detention_active(v_nom);
  IF v_det.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_detenue');
  END IF;

  -- 4. L'ACTE.
  IF p_acte = 'transferer' THEN
    UPDATE public.detentions SET qhs = false WHERE id = v_det.id;
    UPDATE public.prisonniers_qhs SET statut = 'transfere' WHERE id = p_prisonnier_id;
    UPDATE public.personnages_donnees
       SET detention_qhs = jsonb_build_object('enQHS', false, 'eligibleBonusAvocat', true)
     WHERE name = v_nom;
    RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'cible', v_nom);
  END IF;

  IF p_acte = 'ameliorer' THEN
    -- Debit et effet dans la MEME transaction : plus jamais 500 FR sortis pour rien.
    v_caisse := v_pays || '_qhs-prison';
    SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde
      FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    IF v_solde IS NULL OR v_solde < v_cout THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'cout', v_cout);
    END IF;
    UPDATE public.caisses_batiments
       SET data = data || jsonb_build_object('solde', v_solde - v_cout), updated_at = now()
     WHERE id = v_caisse;

    SELECT coalesce(moral, 50) INTO v_moral FROM public.personnages_donnees WHERE name = v_nom;
    UPDATE public.personnages_donnees
       SET moral = least(100, v_moral + 15),
           detention_qhs = jsonb_build_object('enQHS', true, 'paLimite1Jour', false,
                                              'conditionsAmeliorees', true)
     WHERE name = v_nom;
    RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'cible', v_nom, 'cout', v_cout);
  END IF;

  -- torture : indices et moral a zero, PA plafonnes a 1 le lendemain.
  -- inf/pop/dis sont des CLES DE `resources`, pas des colonnes -- l'ancien code l'ignorait.
  SELECT CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END
    INTO v_res FROM public.personnages_donnees WHERE name = v_nom;
  UPDATE public.personnages_donnees
     SET resources = v_res || jsonb_build_object('inf', 0, 'pop', 0, 'dis', 0),
         moral = 0,
         detention_qhs = jsonb_build_object('enQHS', true, 'paLimite1Jour', true)
   WHERE name = v_nom;
  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'cible', v_nom);
END; $$;

REVOKE ALL ON FUNCTION public.detention_active(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.qhs_pouvoir(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.detention_active(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qhs_pouvoir(text, text) TO authenticated;