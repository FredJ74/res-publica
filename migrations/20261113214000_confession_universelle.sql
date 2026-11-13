-- Confession universelle : 2 PA, un acte réussi non découvert tiré au hasard,
-- succès influencé par DUP et (piété - sécurité) de la ville du confesseur.
-- Aucune sélection de trace par le client, aucune récompense de Moral.
CREATE OR REPLACE FUNCTION public.confession_tenter()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $confession$
DECLARE
  v_acteur text;
  v_p public.personnages_donnees%ROWTYPE;
  v_trace record;
  v_dub numeric;
  v_isn numeric;
  v_ip numeric;
  v_taux integer;
  v_jet integer;
  v_paiement jsonb;
  v_lignes integer;
BEGIN
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');
  END IF;

  -- Verrouille l'acteur avant le choix / paiement pour empêcher deux confessions
  -- concurrentes de consommer deux fois la même trace.
  SELECT * INTO v_p FROM public.personnages_donnees
   WHERE name=v_acteur FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable');
  END IF;

  IF NOT (
    (v_p.country='republic' AND
      (v_p.current_building='tabernacle-impots' AND v_p.current_room='nef_principale'
       OR v_p.current_building='notre-dame-mer' AND v_p.current_room='nef'
       OR v_p.current_building='eglise-montrouge' AND v_p.current_room='salle'))
    OR (v_p.country='narco' AND v_p.current_building='laboratoire-priere' AND v_p.current_room='salle_communion')
    OR (v_p.country='soviet' AND v_p.current_building='kolkhoze-spirituel' AND v_p.current_room='grange_sainte')
    OR (v_p.country='khalija' AND v_p.current_building='patisserie-sacree' AND v_p.current_room='salle_degustation')
  ) THEN
    RETURN jsonb_build_object('ok',false,'raison','confession_lieu_invalide');
  END IF;

  -- Deux registres canoniques. Une trace découverte/jugée ou périmée
  -- ne peut pas être blanchie. Les faits sauvegardés dans historique_crimes
  -- proviennent d'un acte déjà commis, pas d'une tentative refusée.
  SELECT source, ident, acte, ord
  INTO v_trace FROM (
    SELECT 'actions_tracables'::text source, a.id::text ident,
           a.type_action::text acte, 0::bigint ord
      FROM public.actions_tracables a
     WHERE a.auteur=v_acteur
       AND coalesce(a.decouvert,false)=false
       AND a.jour_expiration>=coalesce(v_p.day,1)
    UNION ALL
    SELECT 'historique_crimes'::text source,
           coalesce(e.value->>'id', e.ordinality::text) ident,
           e.value->>'acte' acte, e.ordinality ord
      FROM jsonb_array_elements(
        CASE WHEN jsonb_typeof(v_p.historique_crimes)='array'
          THEN v_p.historique_crimes ELSE '[]'::jsonb END
      ) WITH ORDINALITY e(value,ordinality)
     WHERE coalesce(e.value->>'acte','') <> ''
       AND coalesce((e.value->>'decouvert')::boolean,false)=false
       AND (
         (e.value->>'expireTs' IS NOT NULL AND
           now() < (e.value->>'expireTs')::timestamptz)
         OR (e.value->>'expireTs' IS NULL AND
           coalesce((e.value->>'expireJour')::integer,coalesce(v_p.day,1)+1)>=coalesce(v_p.day,1))
       )
  ) traces
  ORDER BY random() LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok',false,'raison','aucune_trace_eligible');
  END IF;

  v_dub := greatest(1,least(20,
    coalesce(CASE WHEN jsonb_typeof(v_p.stats->'DUP')='number'
      THEN (v_p.stats->>'DUP')::numeric END,8)));

  -- Les indices de ville sont la référence là où ils sont déployés
  -- (actuellement les trois villes de Républia).
  SELECT CASE WHEN jsonb_typeof(data->'isn')='number'
           THEN (data->>'isn')::numeric END,
         CASE WHEN jsonb_typeof(data->'piete')='number'
           THEN (data->>'piete')::numeric END
    INTO v_isn,v_ip
    FROM public.indices_villes
   WHERE id=v_p.country||'_'||coalesce(v_p.current_city,'capitale');

  -- Transitoire pour les empires sans indices_villes renseignés :
  -- sécurité nationale actuelle et piété locale issue des dons réels
  -- (base 40, contributions actives sur 7 jours). Ne pas inventer
  -- un indice territorial à partir de l'état non persistant du navigateur.
  v_isn:=coalesce(v_isn,CASE v_p.country
      WHEN 'republic' THEN 30 WHEN 'narco' THEN 15
      WHEN 'soviet' THEN 70 WHEN 'khalija' THEN 60 ELSE 30 END);
  IF v_ip IS NULL THEN
    SELECT least(100,greatest(0,40+coalesce(sum(quantite),0)))
      INTO v_ip FROM public.contributions_piete
     WHERE pays=v_p.country AND ville=coalesce(v_p.current_city,'capitale')
       AND created_at>=now()-interval '7 days';
  END IF;

  v_taux:=greatest(10,least(90,
    round(50+4*(v_dub-8)+0.4*(v_ip-v_isn))::integer));
  v_jet:=floor(random()*100)::integer+1;

  -- Le paiement est autorisé seulement après existence d'une trace, mais
  -- 2 PA sont consommés en cas d'échec du jet.
  v_paiement:=public.payer_ordre_interne(v_acteur,'se_confesser',2,0);
  IF coalesce((v_paiement->>'ok')::boolean,false) IS NOT TRUE THEN
    RETURN v_paiement;
  END IF;

  IF v_jet<=v_taux THEN
    IF v_trace.source='actions_tracables' THEN
      DELETE FROM public.actions_tracables
       WHERE id=v_trace.ident AND auteur=v_acteur AND coalesce(decouvert,false)=false;
    ELSE
      UPDATE public.personnages_donnees
         SET historique_crimes=coalesce((
           SELECT jsonb_agg(e.value ORDER BY e.ordinality)
             FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(historique_crimes)='array'
                 THEN historique_crimes ELSE '[]'::jsonb END
             ) WITH ORDINALITY e(value,ordinality)
            WHERE e.ordinality<>v_trace.ord
          ),'[]'::jsonb)
       WHERE name=v_acteur;
    END IF;
    GET DIAGNOSTICS v_lignes=ROW_COUNT;
    IF v_lignes<>1 THEN
      RAISE EXCEPTION 'confession_tenter: trace sélectionnée impossible à effacer';
    END IF;
  END IF;

  RETURN jsonb_build_object('ok',true,'reussi',v_jet<=v_taux,
    'taux',v_taux,'jet',v_jet,'dup',v_dub,'ip',v_ip,'isn',v_isn,
    'acte',CASE WHEN v_jet<=v_taux THEN v_trace.acte ELSE NULL END,
    'source',CASE WHEN v_jet<=v_taux THEN v_trace.source ELSE NULL END,
    'pa',v_paiement->'pa','liquide',v_paiement->'liquide',
    'arg',v_paiement->'arg','solde_national',v_paiement->'solde_national');
END;
$confession$;
REVOKE ALL ON FUNCTION public.confession_tenter() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.confession_tenter() TO authenticated;
