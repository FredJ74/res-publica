-- Enquête du musée de Luthécia : échange écrit sécurisé avec Jodie Moitout.
-- La réponse guide vers les bilans des mandats de la mairie, sans résoudre l'énigme.
-- Le message et la réponse sont conservés dans la fiche du PJ, sans créer d'objet,
-- de courrier externe, d'indices ou de progression artificielle.
CREATE OR REPLACE FUNCTION public.jodie_enquete_ecrire(p_message text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
DECLARE
  v_nom text := public.mon_personnage();
  d public.personnages_donnees%ROWTYPE;
  e jsonb; c jsonb; v_cadres jsonb; v_message text; v_reponse text;
  v_courrier jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  SELECT * INTO d FROM public.personnages_donnees
    WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok',false,'raison','personnage_non_autorise'); END IF;
  e:=CASE WHEN jsonb_typeof(d.enigme1)='object' THEN d.enigme1 ELSE '{}'::jsonb END;
  IF coalesce(e->>'etape','') NOT IN ('declenchee','relancee') THEN
    RETURN jsonb_build_object('ok',false,'raison','enquete_inactive'); END IF;
  v_cadres:=CASE WHEN jsonb_typeof(e->'cadresVus')='array' THEN e->'cadresVus' ELSE '[]'::jsonb END;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements_text(v_cadres) v(salle)
     WHERE v.salle IN ('salle_maires','salle_criminels','salle_entrepreneurs','salle_plumes')
  ) THEN
    RETURN jsonb_build_object('ok',false,'raison','aucune_plaque_examinee'); END IF;
  v_courrier:=CASE WHEN jsonb_typeof(e->'jodieCourrier')='object'
    THEN e->'jodieCourrier' ELSE NULL END;
  IF p_message IS NULL THEN
    RETURN jsonb_build_object('ok',true,'courrier',v_courrier); END IF;
  v_message:=btrim(p_message);
  IF length(v_message)<1 OR length(v_message)>500 THEN
    RETURN jsonb_build_object('ok',false,'raison','message_invalide'); END IF;
  IF v_courrier->>'message' IS NOT DISTINCT FROM v_message THEN
    RETURN jsonb_build_object('ok',true,'courrier',v_courrier,'deja_envoye',true); END IF;
  v_reponse:='Hmmm… Vous devriez commencer par aller voir à la mairie. '
    ||'Il y a le bilan des mandats de chaque maire. '
    ||'Peut-être y aura-t-il quelque chose au sujet de celui dont le portrait a disparu. '
    ||'Cherchez les archives des mandats municipaux, et notez ce qui vous paraît étrange. '
    ||'Tenez-moi au courant de vos découvertes ! — Jodie Moitout';
  v_courrier:=jsonb_build_object('message',v_message,'reponse',v_reponse,
    'envoye_le',now(),'destinataire','Jodie Moitout');
  e:=jsonb_set(e,'{jodieCourrier}',v_courrier,true);
  UPDATE public.personnages_donnees
    SET enigme1=e,updated_at=now() WHERE name=v_nom AND user_id=auth.uid();
  RETURN jsonb_build_object('ok',true,'courrier',v_courrier);
END $$;
REVOKE ALL ON FUNCTION public.jodie_enquete_ecrire(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.jodie_enquete_ecrire(text) TO authenticated;
