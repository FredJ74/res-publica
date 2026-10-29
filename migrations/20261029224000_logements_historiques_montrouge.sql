-- =====================================================================================
-- LES QUATRE APPARTEMENTS HISTORIQUES DE MONTROUGE ENTRENT DANS LE SOCLE (29/10/2026, Claude).
-- NON APPLIQUÉE — application par ChatGPT, APRÈS 20261029223000. Compatible avec l'écran en ligne.
--
-- Décision de Fred : l'adjoint de Montrouge fixe aussi leur loyer, appartement par appartement,
-- depuis le même tableau de bord. Jusqu'ici, leur loyer était figé dans data.js et l'attribution
-- était écrite par le navigateur. Désormais :
--  - leur fiche (libellé, type, loyer, bonus de sommeil) est tenue au serveur, avec les valeurs
--    d'aujourd'hui : 30 FR pour les petits, 60 FR pour les grands ;
--  - l'adjoint attribue l'appartement par logement_social_attribuer et en fixe le loyer par
--    logement_social_loyer_fixer, comme pour les logements de la commune : il faut une demande en
--    attente, un demandeur domicilié dans la ville, et le premier loyer est payé, versé à la
--    caisse de la mairie ;
--  - chaque changement de loyer est inscrit dans logements_loyers_historique.
-- La résiliation au départ de la ville (20261029223000) s'applique déjà à ces baux.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS public.logements_sociaux_historiques (
  pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL,
  label text NOT NULL, type_logement text NOT NULL, loyer integer NOT NULL CHECK (loyer >= 1),
  bonus_moral integer NOT NULL DEFAULT 0, bonus_sante integer NOT NULL DEFAULT 0,
  PRIMARY KEY (pays, batiment, piece));
ALTER TABLE public.logements_sociaux_historiques ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.logements_sociaux_historiques FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.logements_sociaux_historiques TO authenticated;
DROP POLICY IF EXISTS logements_sociaux_historiques_lecture ON public.logements_sociaux_historiques;
CREATE POLICY logements_sociaux_historiques_lecture ON public.logements_sociaux_historiques FOR SELECT TO authenticated USING (true);
INSERT INTO public.logements_sociaux_historiques VALUES
  ('republic','ville_b','logements-montrouge','petit_appartement_1','Petit appartement n°1','petit',30,3,4),
  ('republic','ville_b','logements-montrouge','petit_appartement_2','Petit appartement n°2','petit',30,3,4),
  ('republic','ville_b','logements-montrouge','grand_appartement_1','Grand appartement n°1','grand',60,5,7),
  ('republic','ville_b','logements-montrouge','grand_appartement_2','Grand appartement n°2','grand',60,5,7)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.logements_loyers_historique (
  id bigserial PRIMARY KEY, pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL,
  ancien integer, nouveau integer NOT NULL, autorite text NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.logements_loyers_historique ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.logements_loyers_historique FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.logements_historiques_liste_interne(p_pays text, p_ville text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT coalesce(jsonb_agg(jsonb_build_object('terrain',h.batiment,'lot',h.piece,'label',h.label,'type',h.type_logement,'loyer',h.loyer,
         'locataire',(SELECT nullif(l.data->>'locataire','') FROM public.locations_actives l WHERE l.id = h.pays||':'||h.batiment||':'||h.piece||':'||h.ville),
         'batiment','historique') ORDER BY h.piece), '[]')
        FROM public.logements_sociaux_historiques h WHERE h.pays = p_pays AND h.ville = p_ville $$;
REVOKE ALL ON FUNCTION public.logements_historiques_liste_interne(text,text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.logement_historique_loyer_fixer_interne(p_moi text, p_ville text, p_batiment text, p_piece text, p_loyer integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE h public.logements_sociaux_historiques; v_pays text; idb text; occupe boolean;
BEGIN
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_moi;
  SELECT * INTO h FROM public.logements_sociaux_historiques x WHERE x.pays = v_pays AND x.batiment = p_batiment AND x.piece = p_piece FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','logement_introuvable'); END IF;
  IF h.ville IS DISTINCT FROM p_ville THEN RETURN jsonb_build_object('ok',false,'raison','hors_commune'); END IF;
  UPDATE public.logements_sociaux_historiques x SET loyer = p_loyer WHERE x.pays = h.pays AND x.batiment = h.batiment AND x.piece = h.piece;
  idb := h.pays||':'||h.batiment||':'||h.piece||':'||h.ville;
  UPDATE public.locations_actives SET data = data || jsonb_build_object('prix', p_loyer) WHERE id = idb;
  occupe := FOUND;
  INSERT INTO public.logements_loyers_historique(pays, ville, batiment, piece, ancien, nouveau, autorite)
    VALUES (h.pays, h.ville, h.batiment, h.piece, h.loyer, p_loyer, p_moi);
  RETURN jsonb_build_object('ok',true,'lot',h.piece,'ancien',h.loyer,'loyer',p_loyer,'occupe',occupe);
END;
$function$;
REVOKE ALL ON FUNCTION public.logement_historique_loyer_fixer_interne(text,text,text,text,integer) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.logement_historique_attribuer_interne(p_moi text, p_ville text, p_batiment text, p_piece text, p_demande text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE h public.logements_sociaux_historiques; v_pays text; dm record; idb text; jour int; v text;
BEGIN
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_moi;
  SELECT * INTO h FROM public.logements_sociaux_historiques x WHERE x.pays = v_pays AND x.batiment = p_batiment AND x.piece = p_piece FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','logement_introuvable'); END IF;
  IF h.ville IS DISTINCT FROM p_ville THEN RETURN jsonb_build_object('ok',false,'raison','hors_commune'); END IF;
  SELECT * INTO dm FROM public.logements_demandes WHERE id = p_demande FOR UPDATE;
  IF NOT FOUND OR dm.statut <> 'en_attente' OR dm.country <> h.pays OR dm.ville <> h.ville THEN RETURN jsonb_build_object('ok',false,'raison','demande_introuvable'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees r WHERE r.name = dm.demandeur AND r.domicile->>'country' = h.pays AND r.domicile->>'city' = h.ville) THEN
    RETURN jsonb_build_object('ok',false,'raison','demandeur_non_resident'); END IF;
  idb := h.pays||':'||h.batiment||':'||h.piece||':'||h.ville;
  IF EXISTS (SELECT 1 FROM public.locations_actives WHERE id = idb) THEN RETURN jsonb_build_object('ok',false,'raison','local_occupe'); END IF;
  SELECT coalesce(day,1) INTO jour FROM public.personnages_donnees WHERE name = dm.demandeur;
  BEGIN
    INSERT INTO public.locations_actives(id, country, data) VALUES (idb, h.pays, jsonb_build_object(
      'country',h.pays,'city',h.ville,'buildingId',h.batiment,'roomId',h.piece,'localKey',h.pays||'|'||h.ville||'|'||h.batiment||'|'||h.piece,
      'localLabel',h.label,'batimentLabel','Logements','prix',h.loyer,'bonusPOP',0,'bonusINF',0,'bonusDIS',0,'orgaId','','orgaAutorisee',false,
      'locataire',dm.demandeur,'depuis',jour,'visible',true,'logementSocial',true,'typeLogement',h.type_logement,
      'bonusMoralSommeil',h.bonus_moral,'bonusSanteSommeil',h.bonus_sante,'attribuePar',p_moi,
      'destinationLoyer',public.bail_destination_attestee(jsonb_build_object('roomId',h.piece,'country',h.pays,'city',h.ville))));
    v := public.prelever_loyer_bail(idb);
    IF v IS DISTINCT FROM 'paye' THEN RAISE EXCEPTION 'premier_loyer_refuse'; END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok',false,'raison',CASE WHEN SQLERRM = 'premier_loyer_refuse' THEN SQLERRM ELSE 'attribution_refusee' END,'detail',SQLERRM);
  END;
  UPDATE public.logements_demandes SET statut = 'attribuee', room_id_attribue = h.piece WHERE id = p_demande;
  INSERT INTO public.logements_attributions_historique(id, country, ville, room_id, beneficiaire, autorite)
    VALUES ('attrib-'||h.piece||'-'||floor(extract(epoch FROM clock_timestamp())*1000), h.pays, h.ville, h.piece, dm.demandeur, p_moi);
  PERFORM public.mail_systeme_poser_interne('Mairie', dm.demandeur, 'Logement social attribué',
    'Un logement social vous a été attribué : '||h.label||'. Loyer : '||h.loyer||' FR par échéance, versé à la commune.', NULL);
  RETURN jsonb_build_object('ok',true,'bail',idb,'beneficiaire',dm.demandeur);
END;
$function$;
REVOKE ALL ON FUNCTION public.logement_historique_attribuer_interne(text,text,text,text,text) FROM PUBLIC, anon, authenticated;

-- Raccordement aux trois portes de l'adjoint (fragments uniques, vérifiés).
DO $$
DECLARE d text; f text; g text := '  IF ville IS NULL THEN RETURN jsonb_build_object(''ok'',false,''raison'',''reserve_adjoint''); END IF;';
BEGIN
  d := pg_get_functiondef('public.logement_social_attribuer(text,text,text)'::regprocedure);
  IF position('logement_historique_attribuer_interne' IN d) = 0 THEN
    IF (length(d)-length(replace(d,g,'')))/length(g) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_attribuer_historique'; END IF;
    EXECUTE replace(d, g, g||'
  IF EXISTS (SELECT 1 FROM public.logements_sociaux_historiques h WHERE h.batiment = p_terrain) THEN
    RETURN public.logement_historique_attribuer_interne(moi, ville, p_terrain, p_lot, p_demande); END IF;');
  END IF;

  d := pg_get_functiondef('public.logement_social_loyer_fixer(text,text,integer)'::regprocedure);
  IF position('logement_historique_loyer_fixer_interne' IN d) = 0 THEN
    f := '  IF p_loyer IS NULL OR p_loyer < 1 OR p_loyer > 100000 THEN RETURN jsonb_build_object(''ok'',false,''raison'',''loyer_invalide''); END IF;';
    IF (length(d)-length(replace(d,f,'')))/length(f) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_loyer_historique'; END IF;
    EXECUTE replace(d, f, f||'
  IF EXISTS (SELECT 1 FROM public.logements_sociaux_historiques h WHERE h.batiment = p_terrain) THEN
    RETURN public.logement_historique_loyer_fixer_interne(moi, ville, p_terrain, p_lot, p_loyer); END IF;');
  END IF;

  d := pg_get_functiondef('public.logements_sociaux_tableau()'::regprocedure);
  IF position('logements_historiques_liste_interne' IN d) = 0 THEN
    f := '    ''demandes'', coalesce(';
    IF (length(d)-length(replace(d,f,'')))/length(f) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_tableau_historique'; END IF;
    EXECUTE replace(d, f, '    ''historiques'', public.logements_historiques_liste_interne(pays, v_ville),
'||f);
  END IF;
END $$;
