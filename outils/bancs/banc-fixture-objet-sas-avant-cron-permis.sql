-- Catalogue vivant du 24 octobre : empreinte 5be54b74273872b4bdd5302777d9fa7a.
BEGIN;
SET LOCAL check_function_bodies=off;
CREATE OR REPLACE FUNCTION public.objet_sas_deposer(p_motif text, p_destinataire text, p_objet jsonb, p_reference text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_acteur text;
  v_vol record;
  v_nouveau_type text;
  v_demandeur text;
  v_expediteur text;
  v_id text;
BEGIN
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF coalesce(btrim(coalesce(p_destinataire, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;
  IF p_objet IS NULL OR jsonb_typeof(p_objet) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;

  IF p_motif = 'butin_vol' THEN
    -- La victime depose le butin pour le voleur. La ligne de vol est la piece justificative :
    -- elle doit exister, designer l'acteur comme victime et le destinataire comme voleur.
    SELECT * INTO v_vol FROM public.vols_en_attente
     WHERE id = p_reference FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'vol_introuvable', 'reference', p_reference);
    END IF;
    IF v_vol.victime IS DISTINCT FROM v_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_la_victime');
    END IF;
    IF v_vol.voleur IS DISTINCT FROM p_destinataire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_pas_le_voleur');
    END IF;
    -- Anti-rejeu : un butin deja confirme ne se depose pas deux fois.
    IF v_vol.type_butin IN ('matiere_confirmee', 'objet_confirme') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'butin_deja_confirme');
    END IF;
    v_nouveau_type := CASE v_vol.type_butin
      WHEN 'matiere' THEN 'matiere_confirmee'
      WHEN 'objet'   THEN 'objet_confirme'
      ELSE NULL END;
    IF v_nouveau_type IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'type_butin_non_transferable',
                                'type_butin', v_vol.type_butin);
    END IF;
    v_expediteur := 'Butin de vol';

  ELSIF p_motif = 'document_urbanisme' THEN
    -- L'archive municipale COMMANDE : le joueur ne doit jamais detenir un recepisse d'un acte que
    -- la mairie n'a pas enregistre. La ligne d'archive est donc la piece justificative, et c'est
    -- elle qui nomme le demandeur legitime.
    SELECT demandeur INTO v_demandeur FROM public.dossiers_urbanisme WHERE id = p_reference;
    IF v_demandeur IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'dossier_introuvable',
                                'reference', p_reference);
    END IF;
    IF v_demandeur IS DISTINCT FROM p_destinataire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_pas_le_demandeur');
    END IF;
    v_expediteur := 'Services d''urbanisme';

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_non_declare', 'motif', p_motif);
  END IF;

  v_id := 'objet-recu-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
  VALUES (v_id, p_destinataire, v_expediteur, to_jsonb(p_objet::text));

  -- Meme transaction que le depot : le marquage du butin ne peut plus rester en arriere.
  IF p_motif = 'butin_vol' THEN
    UPDATE public.vols_en_attente SET type_butin = v_nouveau_type WHERE id = p_reference;
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'destinataire', p_destinataire,
                            'motif', p_motif, 'type_butin', v_nouveau_type);
END;
$function$;
ROLLBACK;
