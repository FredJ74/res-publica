-- #69 PREPAREE. Extension du moteur commun : conserver les morceaux et leurs metadonnees.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.helvetia_inventaire_sortie(jsonb,jsonb,integer,jsonb,integer)');IF h IS NULL OR h NOT IN ('56c9f7b823d0fb91c1d73282e9587bab','1f965a32561aca5580ebba868292831b') THEN RAISE EXCEPTION 'extraction_definition_non_examinee';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.helvetia_inventaire_sortie(p_inv jsonb,p_quete jsonb,p_index integer,p_signature jsonb,p_qte integer)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $f$
DECLARE pos integer;item jsonb;cle text;detenu numeric;nouveau jsonb;sorti jsonb;objets jsonb:='[]';ligne jsonb;reste integer:=p_qte;pris integer;q numeric;empilable boolean;
BEGIN
 IF p_qte IS NULL OR p_qte<=0 OR p_qte>1000 THEN RETURN jsonb_build_object('ok',false,'raison','quantite_invalide');END IF;
 pos:=public.inventaire_localiser(p_inv,p_index,p_signature);
 IF pos<0 THEN RETURN jsonb_build_object('ok',false,'raison','objet_absent');END IF;
 item:=p_inv->pos;
 IF public.inventaire_objet_protege(p_quete,item) THEN RETURN jsonb_build_object('ok',false,'raison','objet_protege');END IF;
 cle:=item->>'stackKey';
 empilable:=CASE WHEN item->>'regime'='individuel' THEN false WHEN item->>'regime'='empilable' THEN true ELSE coalesce((item->>'stackable')::boolean,false) END;
 IF empilable AND cle IS NOT NULL THEN
  detenu:=public.inventaire_quantite(p_inv,cle);
  IF detenu<p_qte THEN RETURN jsonb_build_object('ok',false,'raison','quantite_insuffisante','detenu',detenu);END IF;
  -- Le retrait commun repartit le total ; ses morceaux doivent conserver CHAQUE provenance.
  nouveau:=public.inventaire_retirer(p_inv,cle,p_qte);
  FOR ligne IN SELECT value FROM jsonb_array_elements(p_inv) LOOP
   IF ligne->>'stackKey'=cle AND reste>0 THEN
    IF ligne->>'regime'='individuel' OR public.inventaire_objet_protege(p_quete,ligne) THEN RETURN jsonb_build_object('ok',false,'raison','pile_incompatible');END IF;
    q:=coalesce((ligne->>'qty')::numeric,1);pris:=least(q,reste)::integer;reste:=reste-pris;
    IF q>pris AND nullif(ligne->'exemplaire'->>'id','') IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison','exemplaire_non_fractionnable');END IF;
    objets:=objets||jsonb_build_array(ligne||jsonb_build_object('qty',pris));
   END IF;
  END LOOP;
  sorti:=item||jsonb_build_object('qty',p_qte);
 ELSIF empilable THEN
  -- References du noyau sans stackKey historique : une ligne reste une pile, pas un exemplaire.
  detenu:=coalesce((item->>'qty')::numeric,1);
  IF detenu<p_qte THEN RETURN jsonb_build_object('ok',false,'raison','quantite_insuffisante','detenu',detenu);END IF;
  IF detenu<>trunc(detenu) OR detenu::text IN('NaN','Infinity','-Infinity') THEN RETURN jsonb_build_object('ok',false,'raison','quantite_invalide');END IF;
  IF detenu>p_qte AND nullif(item->'exemplaire'->>'id','') IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison','exemplaire_non_fractionnable');END IF;
  nouveau:=CASE WHEN detenu=p_qte THEN public.inventaire_retirer_position(p_inv,pos) ELSE jsonb_set(p_inv,ARRAY[pos::text,'qty'],to_jsonb(detenu-p_qte)) END;
  sorti:=item||jsonb_build_object('qty',p_qte);objets:=jsonb_build_array(sorti);
 ELSE
  IF p_qte<>1 THEN RETURN jsonb_build_object('ok',false,'raison','quantite_insuffisante','detenu',1);END IF;
  nouveau:=public.inventaire_retirer_position(p_inv,pos);sorti:=item;objets:=jsonb_build_array(item);
 END IF;
 -- Contrat historique objet conserve ; les coffres consomment objets pour ne fusionner aucune identite.
 RETURN jsonb_build_object('ok',true,'inventory',nouveau,'objet',sorti,'objets',objets,'position',pos);
END;$f$;

COMMIT;
