-- #95 : decisions d'heritier sur la ligne verrouillee, jamais remplacement du dossier.
-- Preparee seulement. Le prevol doit verifier les dossiers historiques et l'ouverture client.
BEGIN;
REVOKE UPDATE, DELETE, TRUNCATE ON public.successions FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS successions_maj_acteur ON public.successions;
-- Defense supplementaire meme si un droit UPDATE est reaccorde par erreur.
DROP POLICY IF EXISTS successions_maj_interdite ON public.successions;
CREATE POLICY successions_maj_interdite ON public.successions AS RESTRICTIVE
 FOR UPDATE TO authenticated USING(false) WITH CHECK(false);
DROP POLICY IF EXISTS successions_ecriture_acteur ON public.successions;
CREATE POLICY successions_ecriture_acteur ON public.successions FOR INSERT TO authenticated
 WITH CHECK(defunt=public.mon_personnage() AND country=(SELECT country FROM public.personnages_donnees WHERE name=public.mon_personnage()));

CREATE OR REPLACE FUNCTION public.succession_repondre(p_succession text,p_disposition text,p_reponse text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE s public.successions; d jsonb; e jsonb; prochaine jsonb; i integer; pos integer;
 moi text:=public.mon_personnage(); candidat text; role_suivant text; maintenant timestamptz:=clock_timestamp();
BEGIN
 IF moi IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
 IF p_reponse NOT IN ('accepte','renonce') OR p_reponse IS NULL THEN RAISE EXCEPTION 'reponse_invalide'; END IF;
 SELECT * INTO s FROM public.successions WHERE id=p_succession FOR UPDATE;
 IF NOT FOUND OR s.statut<>'en_attente' THEN RETURN jsonb_build_object('ok',false,'raison','succession_indisponible'); END IF;
 IF jsonb_typeof(s.dispositions)<>'array' THEN RAISE EXCEPTION 'dispositions_invalides'; END IF;
 -- Un id ambigu ne peut autoriser une autre disposition.
 IF (SELECT count(*) FROM jsonb_array_elements(s.dispositions) x WHERE x->>'id'=p_disposition)<>1 THEN
  RETURN jsonb_build_object('ok',false,'raison','disposition_introuvable');
 END IF;
 FOR i IN 0..jsonb_array_length(s.dispositions)-1 LOOP
  d:=s.dispositions->i; CONTINUE WHEN d->>'id' IS DISTINCT FROM p_disposition;
  IF coalesce((d->>'regle')::boolean,false) OR (d->'resultat' IS NOT NULL AND d->'resultat'<>'null'::jsonb) THEN
   RETURN jsonb_build_object('ok',false,'raison','disposition_resolue');
  END IF;
  pos:=jsonb_array_length(d->'chaine')-1; e:=d->'chaine'->pos;
  -- Rejeu d'une acceptation/renonciation deja enregistree, sans refaire la cascade.
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(d->'chaine') x
    WHERE x->>'beneficiaire'=moi AND x->>'reponse'=p_reponse) THEN
   RETURN jsonb_build_object('ok',true,'deja_repondu',true);
  END IF;
  IF e IS NULL OR e->>'beneficiaire' IS DISTINCT FROM moi THEN RAISE EXCEPTION 'heritier_non_convoque' USING ERRCODE='42501'; END IF;
  IF e->>'reponse' IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison','reponse_deja_fixee'); END IF;
  IF (e->>'expires_at')::timestamptz IS NULL OR (e->>'expires_at')::timestamptz<maintenant THEN
   RETURN jsonb_build_object('ok',false,'raison','convocation_expiree');
  END IF;
  e:=e||jsonb_build_object('reponse',p_reponse,'repondu_le',maintenant);
  d:=jsonb_set(d,ARRAY['chaine',pos::text],e);
  IF p_reponse='renonce' THEN
   IF e->>'role'='principal' AND nullif(d->>'remplacant_prevu','') IS NOT NULL
    AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(d->'chaine') x WHERE x->>'role'='remplacant')
    AND EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=d->>'remplacant_prevu') THEN
     candidat:=d->>'remplacant_prevu';role_suivant:='remplacant';
   ELSIF e->>'role'<>'legal_conjoint' AND s.conjoint IS NOT NULL
    AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(d->'chaine') x WHERE x->>'role'='legal_conjoint')
    AND EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=s.conjoint) THEN
     candidat:=s.conjoint;role_suivant:='legal_conjoint';
   END IF;
   IF candidat IS NOT NULL THEN
    prochaine:=jsonb_build_object('role',role_suivant,'beneficiaire',candidat,'convoque_le',maintenant,
     'expires_at',maintenant+interval '10 days','reponse',NULL,'repondu_le',NULL);
    d:=jsonb_set(d,'{chaine}',(d->'chaine')||jsonb_build_array(prochaine));
   ELSE
    d:=d||jsonb_build_object('etat','resolue','resultat',jsonb_build_object('beneficiaire',NULL,'statut','devolution_etat'));
   END IF;
  END IF;
  UPDATE public.successions SET dispositions=jsonb_set(s.dispositions,ARRAY[i::text],d) WHERE id=s.id;
  RETURN jsonb_build_object('ok',true,'nouveauConvoque',candidat);
 END LOOP;
 RETURN jsonb_build_object('ok',false,'raison','disposition_introuvable');
END $f$;
REVOKE ALL ON FUNCTION public.succession_repondre(text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.succession_repondre(text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.succession_regler(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.succession_regler(text) TO service_role;
COMMIT;
