-- 2 novembre 2026, decisions de Fred : pas de drogue reelle nommee dans le jeu.
--   La boulette de shit devient la Brume (pochon a 50 FR en Republia ; 3 FR a El Estado, a
--   l'ouverture de cet empire). Nouvelle drogue dure : l'Estadine (pochon a 120 FR en Republia ;
--   6 FR a El Estado). Memes dealers (Ced' Labone, Ronan Lafourgue, Jojo Laferraille).
--   Stocks limites par dealer : Estadine +1 par jour, plafond 10 ; Brume +3 par jour, plafond 30.
--   Achat et transport illegaux (trace achat_drogue, objet legal=false) ; consommer est legal.
-- pnj_ced_acheter (ancien ecran) devient un simple appel a dealer_acheter(.., 'brume').

CREATE TABLE IF NOT EXISTS public.drogues_stocks_dealers (
  dealer text NOT NULL,
  produit text NOT NULL CHECK (produit IN ('brume','estadine')),
  stock integer NOT NULL CHECK (stock >= 0),
  jour integer NOT NULL,
  PRIMARY KEY (dealer, produit)
);
ALTER TABLE public.drogues_stocks_dealers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.drogues_stocks_dealers FROM PUBLIC, anon, authenticated;
ALTER TABLE public.pnj_ced_achats_recus ADD COLUMN IF NOT EXISTS produit text;
-- L'ancienne contrainte n'admettait que 50 FR (seul prix de la boulette).
ALTER TABLE public.pnj_ced_achats_recus DROP CONSTRAINT IF EXISTS pnj_ced_achats_recus_prix_check;
ALTER TABLE public.pnj_ced_achats_recus ADD CONSTRAINT pnj_ced_achats_recus_prix_check CHECK (prix > 0);

CREATE OR REPLACE FUNCTION public.drogue_catalogue(p_produit text)
 RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT CASE p_produit
  WHEN 'brume' THEN jsonb_build_object('prix',50,'appro',3,'plafond',30,'name','Pochon de Brume',
   'icon','ti-cloud','desc','Un pochon de Brume, l''herbe qui embrume la Républia. Marchandise illégale.')
  WHEN 'estadine' THEN jsonb_build_object('prix',120,'appro',1,'plafond',10,'name','Pochon d''Estadine',
   'icon','ti-snowflake','desc','Une poudre blanche venue d''El Estado. Marchandise illégale.')
 END
$function$;

-- Stock courant d'un dealer, reapprovisionne a la lecture (jour de jeu commun, aucune tache de fond).
CREATE OR REPLACE FUNCTION public.drogue_stock_courant(p_dealer text, p_produit text, p_verrou boolean DEFAULT false)
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c jsonb := public.drogue_catalogue(p_produit); j integer := public.jour_de_jeu_pays('republic');
  s public.drogues_stocks_dealers%rowtype;
BEGIN
  IF c IS NULL OR p_dealer IS NULL THEN RETURN 0; END IF;
  INSERT INTO public.drogues_stocks_dealers(dealer, produit, stock, jour)
   VALUES (p_dealer, p_produit, (c->>'plafond')::int, j) ON CONFLICT DO NOTHING;
  IF p_verrou THEN
    SELECT * INTO s FROM public.drogues_stocks_dealers WHERE dealer = p_dealer AND produit = p_produit FOR UPDATE;
  ELSE
    SELECT * INTO s FROM public.drogues_stocks_dealers WHERE dealer = p_dealer AND produit = p_produit;
  END IF;
  RETURN least((c->>'plafond')::int, s.stock + greatest(0, j - s.jour) * (c->>'appro')::int);
END;
$function$;

CREATE OR REPLACE FUNCTION public.dealer_local(p_pays text, p_ville text)
 RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT CASE WHEN p_pays = 'republic' THEN
   CASE p_ville WHEN 'capitale' THEN 'Céd'' Labone' WHEN 'ville_a' THEN 'Ronan Lafourgue'
                WHEN 'ville_b' THEN 'Jojo Laferraille' END END
$function$;

CREATE OR REPLACE FUNCTION public.dealer_acheter(p_requete uuid, p_produit text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE acteur text; p public.personnages_donnees%rowtype; rejeu boolean; inv jsonb; cat jsonb;
  v_dealer text; v_stock integer; v_prix integer; v_produit text := coalesce(p_produit, 'brume');
BEGIN
  acteur := public.mon_personnage();
  IF auth.uid() IS NULL OR acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
  cat := public.drogue_catalogue(v_produit);
  IF cat IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','produit_inconnu'); END IF;
  v_prix := (cat->>'prix')::int;
  PERFORM public.inventaire_reception_etat(acteur);
  SELECT * INTO p FROM public.personnages_donnees WHERE name = acteur FOR UPDATE;
  SELECT EXISTS(SELECT 1 FROM public.pnj_ced_achats_recus r WHERE r.acteur = p.id AND r.requete = p_requete) INTO rejeu;
  v_dealer := public.dealer_local(p.country, p.current_city);
  IF NOT rejeu THEN
    IF v_dealer IS NULL OR p.current_building IS DISTINCT FROM 'centre-artisanal'
       OR p.current_room IS DISTINCT FROM 'travees' THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');
    END IF;
    v_stock := public.drogue_stock_courant(v_dealer, v_produit, true);
    IF v_stock < 1 THEN RETURN jsonb_build_object('ok',false,'raison','rupture_stock','stock',0); END IF;
    IF public.inventaire_place_restante(p.inventory) < 1 THEN
      RETURN jsonb_build_object('ok',false,'raison','inventaire_plein');
    END IF;
    IF public.helvetia_debiter_fonds_ordinaires(acteur, v_prix) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants');
    END IF;
    inv := p.inventory || jsonb_build_array(jsonb_build_object(
      'id','drogue-'||p.id::text||'-'||p_requete::text,'type','drogue','drogue',v_produit,
      'name',cat->>'name','icon',cat->>'icon','desc',cat->>'desc',
      'legal',false,'stackable',false,'encombrement',1));
    UPDATE public.personnages_donnees SET inventory = inv WHERE id = p.id;
    SELECT * INTO p FROM public.personnages_donnees WHERE id = p.id;
    IF p.inventory IS DISTINCT FROM inv THEN RAISE EXCEPTION 'inventaire_ecriture_non_appliquee'; END IF;
    UPDATE public.drogues_stocks_dealers SET stock = v_stock - 1, jour = public.jour_de_jeu_pays('republic')
     WHERE dealer = v_dealer AND produit = v_produit;
    INSERT INTO public.actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration)
     VALUES('drogue-'||p.id::text||'-'||p_requete::text, acteur, v_dealer, 'achat_drogue',
      p.country, p.current_city, public.jour_de_jeu_pays(p.country), public.jour_de_jeu_pays(p.country)+7);
    INSERT INTO public.pnj_ced_achats_recus(acteur,requete,prix,produit) VALUES(p.id,p_requete,v_prix,v_produit);
  END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE id = p.id;
  RETURN jsonb_build_object('ok',true,'rejeu',rejeu,'prix',v_prix,'produit',v_produit,'nom',cat->>'name',
   'dealer',v_dealer,'stock',public.drogue_stock_courant(v_dealer, v_produit),
   'inventory',p.inventory,'revision',p.inventory_revision,
   'paiement',jsonb_build_object('pa',p.pa,'arg',p.arg,'liquide',p.liquide,'solde_national',
    coalesce((SELECT cb.solde FROM public.comptes_bancaires cb WHERE cb.personnage=acteur AND cb.banque='nationale'),0)));
END;
$function$;

-- Ancien ecran : meme porte, produit Brume.
CREATE OR REPLACE FUNCTION public.pnj_ced_acheter(p_requete uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN public.dealer_acheter(p_requete, 'brume'); /* dealers_brume_estadine */
END;
$function$;

CREATE OR REPLACE FUNCTION public.dealer_stocks_lire()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE acteur text := public.mon_personnage(); p public.personnages_donnees%rowtype; d text;
BEGIN
  IF auth.uid() IS NULL OR acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = acteur;
  d := public.dealer_local(p.country, p.current_city);
  IF d IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
  RETURN jsonb_build_object('ok',true,'dealer',d,
    'brume',jsonb_build_object('stock',public.drogue_stock_courant(d,'brume'),'prix',50),
    'estadine',jsonb_build_object('stock',public.drogue_stock_courant(d,'estadine'),'prix',120));
END;
$function$;

REVOKE ALL ON FUNCTION public.drogue_catalogue(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.drogue_stock_courant(text,text,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.dealer_local(text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.dealer_acheter(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.dealer_stocks_lire() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pnj_ced_acheter(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dealer_acheter(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dealer_stocks_lire() TO authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_ced_acheter(uuid) TO authenticated;

-- Les boulettes deja possedees deviennent des pochons de Brume (memes effets).
UPDATE public.personnages_donnees d
   SET inventory = (SELECT jsonb_agg(CASE WHEN e->>'type' = 'drogue' AND e->>'name' = 'Boulette de shit'
          THEN e || jsonb_build_object('drogue','brume','name','Pochon de Brume','icon','ti-cloud',
               'desc','Un pochon de Brume, l''herbe qui embrume la Républia. Marchandise illégale.')
          ELSE e END ORDER BY o) FROM jsonb_array_elements(d.inventory) WITH ORDINALITY t(e, o)),
       inventory_revision = coalesce(inventory_revision, 0) + 1
 WHERE jsonb_typeof(d.inventory) = 'array'
   AND EXISTS (SELECT 1 FROM jsonb_array_elements(d.inventory) e
                WHERE e->>'type' = 'drogue' AND e->>'name' = 'Boulette de shit');
