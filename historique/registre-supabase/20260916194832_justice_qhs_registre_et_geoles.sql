-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916194832
-- Nom original      : justice_qhs_registre_et_geoles
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 19:48:32 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4441b83f506699d72325ed4be98f59b0
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
-- REGISTRE QHS VERROUILLE, ET LES GEOLES LISENT LA SOURCE CANONIQUE (16 septembre 2026).
--
-- 1. prisonniers_qhs avait la RLS DESACTIVEE : n'importe quel navigateur pouvait y inscrire qui
--    il voulait. Les pouvoirs QHS exigent deja une detention canonique, donc la fausse
--    inscription ne donnait aucun pouvoir -- mais elle polluait le registre affiche au Ministre.
--    On aligne la table sur `detentions` : lecture publique, ecriture LIMITEE A SOI-MEME. Les
--    deux chemins legitimes du client (placerAuQHS, rebellion matee) inscrivent le joueur
--    lui-meme et continuent de fonctionner ; le seul chemin qui visait un tiers -- la sentence
--    QHS du juge -- passe desormais par justice_prolonger_peine, ci-dessous.
--
-- 2. justice_prolonger_peine cherchait la detention a prolonger dans personnages.est_emprisonne.
--    Conformement a l'arbitrage, elle lit maintenant `detentions`. Et quand le juge force le QHS,
--    c'est elle qui inscrit au registre -- le client n'a plus rien a y ecrire pour autrui.
--
-- 3. La liste des detenus affichee dans les geoles interrogeait personnages.est_emprisonne chez
--    AUTRUI : masque depuis le chantier B, la liste etait donc vide. Elle vient desormais de
--    `detentions`, et ne renvoie que ce qu'il faut pour l'affichage -- un nom, une photo, un
--    drapeau QHS. Aucune autre donnee judiciaire ne sort.

ALTER TABLE public.prisonniers_qhs ENABLE ROW LEVEL SECURITY;
DO $$
DECLARE pol record;
BEGIN
  FOR pol IN SELECT policyname FROM pg_policies
             WHERE schemaname='public' AND tablename='prisonniers_qhs'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.prisonniers_qhs', pol.policyname);
  END LOOP;
END $$;

CREATE POLICY prisonniers_qhs_lecture ON public.prisonniers_qhs
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY prisonniers_qhs_insertion_soi ON public.prisonniers_qhs
  FOR INSERT TO anon, authenticated WITH CHECK (data->>'nom' = public.mon_personnage());
CREATE POLICY prisonniers_qhs_maj_soi ON public.prisonniers_qhs
  FOR UPDATE TO anon, authenticated
  USING (data->>'nom' = public.mon_personnage())
  WITH CHECK (data->>'nom' = public.mon_personnage());
-- DELETE : aucune policy. Une inscription au QHS ne s'efface pas, elle se termine.

-- La liste des geoles, depuis la source canonique et rien de plus.
CREATE OR REPLACE FUNCTION public.geoles_detenus(p_pays text, p_ville text)
RETURNS TABLE (nom text, photo_url text, qhs boolean)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT d.nom,
         (SELECT p.photo_url FROM public.personnages_donnees p WHERE p.name = d.nom),
         coalesce(d.qhs, false)
    FROM public.detentions d
   WHERE d.country = p_pays
     AND d.city = p_ville
     AND d.mode_fin IS NULL
     AND d.jour_fin_effective IS NULL
   ORDER BY d.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.geoles_detenus(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.geoles_detenus(text, text) TO anon, authenticated;

-- Prolongation : source canonique en entree, registre QHS tenu a jour en sortie.
CREATE OR REPLACE FUNCTION public.justice_prolonger_peine(p_cible text, p_motifs jsonb,
                                                          p_forcer_qhs boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_juge text; v_peine jsonb; v_det record;
  v_jours_supp int; v_nouveau_jour_fin int; v_motifs_actuels jsonb;
BEGIN
  v_juge := public.exiger_poste('juge');

  IF p_motifs IS NULL OR jsonb_typeof(p_motifs) <> 'array' OR jsonb_array_length(p_motifs) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motifs_absents');
  END IF;

  -- LA DETENTION CANONIQUE fait foi -- plus est_emprisonne, que le client ecrit.
  SELECT * INTO v_det FROM public.detention_active(p_cible);
  IF v_det.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_detenue');
  END IF;

  SELECT coalesce(sum((m->>'jours')::int), 0) INTO v_jours_supp
    FROM jsonb_array_elements(p_motifs) m;
  v_nouveau_jour_fin := coalesce(v_det.jour_fin, 0) + v_jours_supp;

  SELECT coalesce(motifs, '[]'::jsonb) INTO v_motifs_actuels
    FROM public.detentions WHERE id = v_det.id FOR UPDATE;

  UPDATE public.detentions
     SET motifs = v_motifs_actuels || p_motifs,
         jour_fin = v_nouveau_jour_fin,
         qhs = CASE WHEN p_forcer_qhs THEN true ELSE qhs END
   WHERE id = v_det.id;

  -- Miroir de compatibilite, dans la meme transaction.
  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees WHERE name = p_cible FOR UPDATE;
  IF v_peine IS NOT NULL AND jsonb_typeof(v_peine) = 'object' THEN
    UPDATE public.personnages_donnees
       SET est_emprisonne = v_peine
             || jsonb_build_object('jours', coalesce((v_peine->>'jours')::int, 0) + v_jours_supp)
             || jsonb_build_object('jourFin', v_nouveau_jour_fin)
             || CASE WHEN p_forcer_qhs THEN jsonb_build_object('qhs', true) ELSE '{}'::jsonb END
     WHERE name = p_cible;
  END IF;

  -- Sentence QHS : c'est ici que le registre est tenu, plus dans le navigateur du juge.
  IF p_forcer_qhs AND NOT EXISTS (
       SELECT 1 FROM public.prisonniers_qhs
        WHERE data->>'nom' = p_cible AND coalesce(statut, '') <> 'transfere') THEN
    INSERT INTO public.prisonniers_qhs (id, statut, data)
    VALUES ('qhs-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-'
              || substr(md5(random()::text), 1, 6),
            'detenu',
            jsonb_build_object('pays', v_det.country, 'nom', p_cible,
                               'raison', coalesce(p_motifs->0->>'type', 'Sentence'),
                               'jourDebut', v_det.jour_debut, 'jourFin', v_nouveau_jour_fin));
  END IF;

  RETURN jsonb_build_object('ok', true, 'juge', v_juge, 'cible', p_cible,
                            'jours_ajoutes', v_jours_supp, 'jour_fin', v_nouveau_jour_fin);
END;
$function$;