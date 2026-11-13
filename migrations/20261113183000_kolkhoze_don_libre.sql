-- Don libre au Kolkhoze spirituel de Novomirsk : aucun PA, montant choisi par le PJ.
-- Le barème à 200 PSK conserve +5 piété / +3 popularité ; plafonds quotidiens +10/+6.
-- Les dons sont débités et encaissés atomiquement sur le serveur ; aucun autre empire n'est modifié.
INSERT INTO public.ordres_couts(fn,pa,cost)
SELECT 'don_kolkhoze_libre',0,1
WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn='don_kolkhoze_libre');

CREATE TABLE IF NOT EXISTS public.kolkhoze_dons_journaliers (
  acteur text NOT NULL,
  jour date NOT NULL,
  montant_total bigint NOT NULL DEFAULT 0 CHECK (montant_total >= 0),
  piete_attribuee integer NOT NULL DEFAULT 0 CHECK (piete_attribuee BETWEEN 0 AND 10),
  pop_attribuee integer NOT NULL DEFAULT 0 CHECK (pop_attribuee BETWEEN 0 AND 6),
  PRIMARY KEY (acteur,jour)
);
ALTER TABLE public.kolkhoze_dons_journaliers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.kolkhoze_dons_journaliers FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.kolkhoze_donner(p_montant integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_acteur text;
  v_lieu record;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_paye jsonb;
  v_credit jsonb;
  v_avant record;
  v_total bigint;
  v_piete integer;
  v_pop integer;
  v_gain_piete integer;
  v_gain_pop integer;
  v_ressources jsonb;
  v_pop_actuelle integer;
  v_pop_finale integer;
BEGIN
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');
  END IF;
  IF p_montant IS NULL OR p_montant < 1 OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok',false,'raison','montant_invalide');
  END IF;
  SELECT country,current_city,current_building,current_room
    INTO v_lieu FROM public.personnages_donnees WHERE name=v_acteur;
  IF NOT FOUND OR v_lieu.country IS DISTINCT FROM 'soviet'
     OR v_lieu.current_city IS DISTINCT FROM 'capitale'
     OR v_lieu.current_building IS DISTINCT FROM 'kolkhoze-spirituel'
     OR v_lieu.current_room IS DISTINCT FROM 'grange_sainte' THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_au_kolkhoze');
  END IF;

  -- Ligne verrouillable unique, créée avant le paiement pour sérialiser les dons concurrents.
  INSERT INTO public.kolkhoze_dons_journaliers(acteur,jour)
    VALUES(v_acteur,v_jour) ON CONFLICT(acteur,jour) DO NOTHING;
  SELECT montant_total,piete_attribuee,pop_attribuee
    INTO v_avant FROM public.kolkhoze_dons_journaliers
    WHERE acteur=v_acteur AND jour=v_jour FOR UPDATE;

  -- Montant libre : tarif élémentaire 1 PSK, multiplié dans le paiement sécurisé existant.
  -- Ne pas appeler payer_ordre avec un coût arbitraire hors catalogue.
  v_paye := public.payer_ordre_interne(v_acteur,'don_kolkhoze_libre',0,1,p_montant);
  IF coalesce((v_paye->>'ok')::boolean,false) IS NOT TRUE THEN
    RETURN v_paye;
  END IF;
  PERFORM set_config('rp.caisse_interne','on',true);
  v_credit := public.caisse_institution_mouvement('soviet_kolkhoze-spirituel',p_montant,false);
  IF coalesce((v_credit->>'ok')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'kolkhoze_donner: credit caisse impossible : %',coalesce(v_credit->>'raison','inconnu');
  END IF;

  v_total := v_avant.montant_total + p_montant;
  -- Barème cumulatif, robuste au fractionnement : 200 PSK => 5 piété/3 POP ;
  -- 400 PSK ou davantage => plafonds quotidiens 10 piété/6 POP.
  v_piete := least(10,floor(v_total::numeric/40)::integer);
  v_pop := least(6,floor(v_total::numeric*3/200)::integer);
  v_gain_piete := greatest(0,v_piete-v_avant.piete_attribuee);
  v_gain_pop := greatest(0,v_pop-v_avant.pop_attribuee);

  UPDATE public.kolkhoze_dons_journaliers SET
    montant_total=v_total,piete_attribuee=v_piete,pop_attribuee=v_pop
    WHERE acteur=v_acteur AND jour=v_jour;
  IF v_gain_piete > 0 THEN
    INSERT INTO public.contributions_piete(pays,ville,auteur,quantite,created_at)
    VALUES('soviet','capitale',v_acteur,v_gain_piete,now());
  END IF;
  SELECT coalesce(resources,'{}'::jsonb) INTO v_ressources
    FROM public.personnages_donnees WHERE name=v_acteur FOR UPDATE;
  v_pop_actuelle := coalesce(
    CASE WHEN jsonb_typeof(v_ressources->'pop')='number'
      THEN (v_ressources->>'pop')::integer END,50);
  v_pop_finale := least(100,v_pop_actuelle+v_gain_pop);
  IF v_gain_pop > 0 THEN
    UPDATE public.personnages_donnees SET resources=
      jsonb_set(v_ressources,'{pop}',to_jsonb(v_pop_finale),true)
      WHERE name=v_acteur;
  END IF;
  RETURN jsonb_build_object('ok',true,'montant',p_montant,
    'pa',v_paye->'pa','liquide',v_paye->'liquide',
    'arg',v_paye->'arg','solde_national',v_paye->'solde_national',
    'pop',v_pop_finale,'gain_pop',v_pop_finale-v_pop_actuelle,
    'gain_piete',v_gain_piete,'plafond_piete',10,'plafond_pop',6,
    'total_jour',v_total,'caisse','soviet_kolkhoze-spirituel');
END;
$$;
REVOKE ALL ON FUNCTION public.kolkhoze_donner(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.kolkhoze_donner(integer) TO authenticated;
