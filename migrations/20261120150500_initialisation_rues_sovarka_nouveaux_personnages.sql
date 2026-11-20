-- Correctif production 20/11/2026 : premier départ des nouveaux PJ Sovarka.
-- Ancien CASE indexé uniquement sur la ville, avec les noeuds Républia pour Sovarka.
-- Conserver la vérification serveur du graphe, de la sortie de bâtiment et des voisins.
CREATE OR REPLACE FUNCTION public.navigation_rue_trajet_interne(p_pays text, p_ville text, p_batiment text, p_rue text, p_noeud text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
 v_noeud public.rue_noeuds_serveur%ROWTYPE;
 v_depart text;
BEGIN
 SELECT * INTO v_noeud FROM public.rue_noeuds_serveur
 WHERE country = p_pays AND city = p_ville AND noeud = p_noeud;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','noeud_inconnu'); END IF;
 IF p_batiment IS NOT NULL THEN
   IF NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments
     WHERE country=p_pays AND city=p_ville AND building=p_batiment AND noeud=p_noeud)
   THEN RETURN jsonb_build_object('ok',false,'raison','sortie_invalide'); END IF;
 ELSIF p_rue IS NOT NULL AND p_rue <> p_noeud THEN
   IF NOT EXISTS (SELECT 1 FROM public.rue_noeuds_serveur
     WHERE country=p_pays AND city=p_ville AND noeud=p_rue AND p_noeud=ANY(voisins))
   THEN RETURN jsonb_build_object('ok',false,'raison','trajet_invalide'); END IF;
 ELSIF p_rue IS NULL THEN
   v_depart := CASE p_pays
     WHEN 'republic' THEN CASE p_ville
       WHEN 'capitale' THEN 'luthecia-palais-presidentiel'
       WHEN 'ville_a' THEN 'psm-centre-multimodal'
       WHEN 'ville_b' THEN 'montrouge-vue-3' END
     WHEN 'soviet' THEN CASE p_ville
       WHEN 'capitale' THEN 'novomirsk-vue-1'
       WHEN 'ville_a' THEN 'starovka-rue-gare'
       WHEN 'ville_b' THEN 'krasnov-rue-gare' END
     END;
   IF p_noeud IS DISTINCT FROM v_depart
   THEN RETURN jsonb_build_object('ok',false,'raison','position_initiale_invalide'); END IF;
 END IF;
 RETURN jsonb_build_object('ok',true);
END;
$function$

