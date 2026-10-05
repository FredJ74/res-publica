-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920121515
-- Nom original      : bail_destination_attestee
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 12:15:15 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3c2d552965ac8a5b7390a231cb69b51c
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
-- §6.3 — LA DESTINATION D'UN LOYER NE SE LIT PLUS DANS LE BAIL
-- ---------------------------------------------------------------------------
-- L'INVARIANT VIOLE. prelever_loyer_bail() est une RPC rigoureuse : FOR UPDATE,
-- anti-rejeu par jourPaiement, credit avant debit, aucune destination implicite.
-- Toute cette rigueur etait sans effet, parce que son ENTREE est falsifiable :
-- locations_actives est ouverte en ecriture directe a tout joueur connecte
-- (verifie sous veritable role authenticated). Un joueur pouvait donc ecrire
--     destinationLoyer = {"type":"titulaire_murs","titulaire":"<lui-meme>"}
-- sur le bail d'autrui, et la RPC payait fidelement -- elle lit le `titulaire`
-- explicite EN PRIORITE, un repli de compatibilite pour les baux anterieurs.
--
-- CE QUI CHANGE. La destination est desormais DERIVEE du local, jamais lue dans
-- le bail. C'est un portage fidele de destinationLoyerPourLocal()
-- (plateau-immobilier.js) : meme regle, meme ordre, memes quatre cas. Le champ
-- destinationLoyer du bail devient purement informatif.
--
-- L'INVARIANT AJOUTE : une destination ne peut designer que LE BIEN DU BAIL.
--   * titulaire_murs  -> plus jamais de titulaire explicite. Le proprietaire est
--                        resolu dans terrains_etat au moment du prelevement, ce
--                        que la RPC savait deja faire (c'etait meme le
--                        comportement voulu, documente comme tel : « le loyer
--                        appartient au proprietaire ACTUEL »).
--   * caisse_batiment -> le buildingId est celui du bail, pas un autre. Sans
--                        cela, on pouvait diriger un loyer vers la caisse d'une
--                        institution que l'on dirige.
--   * municipal       -> pays et ville sont ceux du bail.
--
-- Cela NE FERME PAS l'ecriture directe sur locations_actives : fabriquer ou
-- resilier un bail reste possible et reste a traiter. Mais l'argent, lui, ne
-- peut plus etre detourne vers une poche choisie.

CREATE OR REPLACE FUNCTION public.bail_destination_attestee(p_data jsonb)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    -- Un bail sans loyer reel n'a pas de destination.
    WHEN coalesce((p_data ->> 'chambreClinique')::boolean, false) THEN NULL
    -- Box portuaire multi-tenant : caisse du batiment DU BAIL.
    WHEN coalesce((p_data ->> 'isBox')::boolean, false)
      THEN jsonb_build_object('type', 'caisse_batiment',
                              'buildingId', p_data ->> 'buildingId')
    -- Lot dynamique d'un bien subdivise : le proprietaire des murs, resolu au
    -- moment du prelevement. Aucun titulaire n'est inscrit ici, volontairement.
    WHEN left(coalesce(p_data ->> 'roomId', ''), 8) = 'lot_dyn_'
      THEN jsonb_build_object('type', 'titulaire_murs')
    -- Tout le reste : la commune du bail.
    ELSE jsonb_build_object('type', 'municipal',
                            'pays',  coalesce(p_data ->> 'country', 'republic'),
                            'ville', coalesce(p_data ->> 'city', 'capitale'))
  END;
$$;
REVOKE ALL ON FUNCTION public.bail_destination_attestee(jsonb) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bail_destination_attestee(jsonb) TO service_role;

DO $mig$
DECLARE v_src text; v_new text;
BEGIN
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'prelever_loyer_bail';

  -- 1. La destination vient de la regle, plus du bail.
  v_new := replace(v_src,
    '  -- Fail-closed : aucune destination implicite.
  IF NOT (v_data ? ''destinationLoyer'') THEN
    RETURN ''destination_absente'';
  END IF;

  v_dest := v_data -> ''destinationLoyer'';',
    '  -- DESTINATION ATTESTEE (20 septembre 2026). Elle n''est plus lue dans le bail --
  -- ecriture directe falsifiable -- mais DERIVEE du local, par la meme regle que le
  -- client (destinationLoyerPourLocal). Le champ destinationLoyer du bail n''est plus
  -- qu''informatif. Fail-closed inchange : pas de destination -> pas de mouvement.
  v_dest := public.bail_destination_attestee(v_data);
  IF v_dest IS NULL THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object(''jourPaiement'', v_jour)
    WHERE id = p_bail_id;
    RETURN ''ignore_sans_loyer'';
  END IF;');
  IF v_new = v_src THEN RAISE EXCEPTION 'bloc destination introuvable'; END IF;
  v_src := v_new;

  -- 2. Plus jamais de titulaire explicite : on resout toujours le proprietaire reel.
  v_new := replace(v_src,
    '    v_titulaire := v_dest ->> ''titulaire'';

    IF v_titulaire IS NULL OR v_titulaire = '''' THEN',
    '    -- Le titulaire explicite n''est PLUS lu : c''etait la porte par laquelle un bail
    -- falsifie redirigeait le loyer. Le proprietaire ACTUEL fait foi, toujours.
    v_titulaire := NULL;

    IF v_titulaire IS NULL OR v_titulaire = '''' THEN');
  IF v_new = v_src THEN RAISE EXCEPTION 'bloc titulaire introuvable'; END IF;

  EXECUTE 'CREATE OR REPLACE FUNCTION public.prelever_loyer_bail(p_bail_id text) RETURNS text '
       || 'LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS '
       || quote_literal(v_new);
END $mig$;