-- Dynamo de Novomirsk : tarif de boutique, club supporters, renouvellement et carte.
-- Les fonctions ci-dessous sont les définitions réellement présentes en production,
-- avec modifications ciblées. Pas de mutation du championnat ni des joueurs.
INSERT INTO public.ordres_couts_pays (fn,pays,pa,cost) VALUES ('rejoindre_club_supporters','soviet',1,25)
 ON CONFLICT (fn,pays) DO UPDATE SET pa=EXCLUDED.pa,cost=EXCLUDED.cost;

CREATE OR REPLACE FUNCTION public.club_accessoire_acheter(p_requete uuid, p_accessoire text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; c public.clubs_sportifs_regles; o jsonb; prix integer; v jsonb; d jsonb; paiement jsonb; params jsonb; budget jsonb;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
 params:=jsonb_build_object('accessoire',p_accessoire,'pa',p_pa,'cost',p_cost);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'club_accessoire',params);IF v IS NOT NULL THEN RETURN v;END IF;
 IF a.current_building IS DISTINCT FROM 'stade' OR (a.current_room IS DISTINCT FROM 'buvette' AND NOT (a.country='soviet' AND a.current_city='capitale' AND a.current_room='boutique')) THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 SELECT * INTO c FROM public.clubs_sportifs_regles WHERE country=a.country AND city=a.current_city;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','club_local_introuvable');END IF;
 prix:=CASE WHEN a.country='soviet' THEN CASE p_accessoire WHEN 'echarpe' THEN 25 WHEN 'casquette' THEN 20 WHEN 'maillot' THEN 45 END ELSE CASE p_accessoire WHEN 'echarpe' THEN 80 WHEN 'casquette' THEN 60 WHEN 'maillot' THEN 150 END END;
 IF prix IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','accessoire_inconnu');END IF;
 SELECT objet INTO STRICT o FROM public.objets_modeles WHERE id='accessoire:'||p_accessoire;
 o:=o||jsonb_build_object('name',(o->>'name')||' — '||c.nom);
 v:=public.assemblee_verifier_vente(jsonb_build_array(o),a.country);
 IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RETURN v;END IF;
 IF public.inventaire_place_restante(a.inventory)<1 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein');END IF;
 PERFORM 1 FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale' FOR UPDATE;
 IF coalesce(a.liquide,0)+coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale'),0)<prix THEN
 RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants');END IF;
 paiement:=public.payer_ordre(a.name,'choisir_accessoire_club',p_pa,p_cost);
 IF (paiement->>'ok')::boolean IS DISTINCT FROM true THEN RETURN paiement;END IF;
 IF NOT public.helvetia_debiter_fonds_ordinaires(a.name,prix) THEN RAISE EXCEPTION 'club: debit non confirme';END IF;
 INSERT INTO public.budgets_clubs(id,data) VALUES(c.club_id,jsonb_build_object('clubId',c.club_id,'caisse',0,'historique','[]'::jsonb,
  'salaires',jsonb_build_object('titulaire',100,'remplacant',50,'primeVictoire',150))) ON CONFLICT(id) DO NOTHING;
 SELECT data INTO STRICT budget FROM public.budgets_clubs WHERE id=c.club_id FOR UPDATE;
 IF jsonb_typeof(budget) IS DISTINCT FROM 'object' OR (budget?'historique' AND jsonb_typeof(budget->'historique') IS DISTINCT FROM 'array') THEN RAISE EXCEPTION 'club: budget historique invalide';END IF;
 budget:=budget||jsonb_build_object('caisse',coalesce((budget->>'caisse')::numeric,0)+prix,
  'historique',coalesce(budget->'historique','[]')||jsonb_build_array(jsonb_build_object('jour',public.jour_de_jeu_pays(a.country),'montant',prix,'motif','Vente boutique : '||split_part(o->>'name',' — ',1))));
 SELECT jsonb_set(budget,'{historique}',coalesce(jsonb_agg(e ORDER BY n),'[]')) INTO budget
 FROM jsonb_array_elements(budget->'historique') WITH ORDINALITY x(e,n) WHERE n>jsonb_array_length(budget->'historique')-50;
 UPDATE public.budgets_clubs SET data=budget,updated_at=now() WHERE id=c.club_id;
 d:=public.inventaire_deposer_interne(a.name,o);
 IF (d->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'club: depot refuse';END IF;
 SELECT jsonb_build_object('pa',pa,'liquide',liquide,'arg',arg,'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale'),0)) INTO paiement FROM public.personnages_donnees WHERE name=a.name;
 v:=d||jsonb_build_object('paie',paiement,'prix',prix,'objet',o->>'name');
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'club_accessoire',params,v,now());RETURN v;
END; $function$;


CREATE OR REPLACE FUNCTION public.club_supporters_cotiser(p_requete text, p_club text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_recu jsonb; v_cout record; v_paie jsonb; v_nouveau numeric; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.clubs_football WHERE id = p_club) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'club_introuvable');
  END IF;
  v_recu := public.caisse_collective_recu_interne(p_requete, v_moi, 'rejoindre_club_supporters', p_club);
  IF v_recu IS NOT NULL THEN RETURN v_recu; END IF;

  SELECT o.pa,o.cost INTO v_cout FROM public.ordres_couts_pays o JOIN public.clubs_football c ON c.id=p_club AND c.pays=o.pays WHERE o.fn='rejoindre_club_supporters';
  IF NOT FOUND THEN SELECT pa,cost INTO v_cout FROM public.ordres_couts WHERE fn='rejoindre_club_supporters' ORDER BY pa,cost LIMIT 1; END IF;
  v_paie := public.payer_ordre(v_moi, 'rejoindre_club_supporters', v_cout.pa, v_cout.cost);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;
  v_nouveau := public.club_caisse_ajuster_interne(p_club, v_cout.cost, 'Cotisation supporter',
                 coalesce((SELECT day FROM public.personnages_donnees WHERE name = v_moi), 1));
  v_res := jsonb_build_object('ok', true, 'caisse', v_nouveau, 'paiement', v_paie);
  RETURN public.caisse_collective_recu_noter_interne(p_requete, v_moi, 'rejoindre_club_supporters', p_club, v_res);
END $function$;


CREATE OR REPLACE FUNCTION public.cotisation_renouveler(p_orga_id text, p_membre text, p_saison integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data jsonb; v_membres jsonb; v_i integer; v_trouve integer := -1;
  v_type text; v_pays text; v_ville text; v_nom_orga text;
  v_arg numeric; v_existe boolean; v_club text; v_bc jsonb; v_hist jsonb;
  v_montant numeric := 50;
BEGIN
  SELECT o.data::jsonb INTO v_data FROM public.organisations o
   WHERE o.id = p_orga_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok',false,'action','organisation_introuvable'); END IF;
  v_membres := CASE WHEN jsonb_typeof(v_data->'membres')='array' THEN v_data->'membres' ELSE '[]'::jsonb END;
  FOR v_i IN 0 .. greatest(0, jsonb_array_length(v_membres) - 1) LOOP
    IF (v_membres -> v_i ->> 'nom') = p_membre THEN v_trouve := v_i; EXIT; END IF;
  END LOOP;
  IF v_trouve < 0 THEN RETURN jsonb_build_object('ok',false,'action','membre_introuvable'); END IF;
  v_type := v_data ->> 'type'; v_pays := v_data ->> 'country'; v_ville := v_data ->> 'city';
  v_nom_orga := coalesce(v_data ->> 'nom', p_orga_id);
  IF v_type='supporters' AND v_pays='soviet' THEN v_montant := 25; END IF;

  SELECT true, coalesce(arg,0) INTO v_existe, v_arg FROM public.personnages
   WHERE name = p_membre FOR UPDATE;

  IF NOT coalesce(v_existe,false) OR v_arg < v_montant THEN
    -- RESILIATION : le membre quitte la liste, aucune dette n'est creee. Le courrier passe par
    -- l'unique ecrivain de public.mails ; il notifie, il ne decide pas.
    v_data := jsonb_set(v_data, '{membres}', v_membres - v_trouve);
    UPDATE public.organisations SET data = v_data::text WHERE id = p_orga_id;
    PERFORM public.mail_systeme_poser_interne(v_nom_orga, p_membre,
      'Fin d''adhésion — cotisation non renouvelée',
      'Votre adhésion à "' || v_nom_orga || '" a pris fin automatiquement : la cotisation de '
      || v_montant::text || CASE WHEN v_type='supporters' AND v_pays='soviet' THEN ' PSK' ELSE ' FR' END || ' n''a pas pu être prélevée. Aucune dette n''est créée.',
      to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'));
    RETURN jsonb_build_object('ok',true,'action','resiliation','membre',p_membre);
  END IF;

  PERFORM public.argent_debiter_interne(p_membre, v_montant, 'liquide_puis_nationale');

  IF v_type = 'supporters' THEN
    IF p_saison IS NULL THEN
      RAISE EXCEPTION 'cotisation_renouveler : une organisation de supporters exige la saison';
    END IF;
    v_membres := jsonb_set(v_membres, ARRAY[v_trouve::text,'derniereCotisationSaison'], to_jsonb(p_saison));
    SELECT c.id INTO v_club FROM public.clubs_football c
     WHERE c.pays = v_pays AND c.ville = v_ville;
    IF v_club IS NOT NULL THEN
      SELECT b.data INTO v_bc FROM public.budgets_clubs b WHERE b.id = v_club FOR UPDATE;
      IF v_bc IS NULL THEN
        v_bc := jsonb_build_object('clubId', v_club, 'caisse', 0, 'historique', '[]'::jsonb,
                 'derniereSubventionJour', NULL,
                 'salaires', jsonb_build_object('titulaire',100,'remplacant',50,'primeVictoire',150));
      END IF;
      v_hist := CASE WHEN jsonb_typeof(v_bc->'historique')='array' THEN v_bc->'historique' ELSE '[]'::jsonb END;
      v_hist := v_hist || jsonb_build_array(jsonb_build_object('jour', NULL, 'montant', v_montant,
                  'motif', 'Cotisation supporter (renouvellement)'));
      IF jsonb_array_length(v_hist) > 50 THEN
        v_hist := (SELECT jsonb_agg(e) FROM (
          SELECT e FROM jsonb_array_elements(v_hist) WITH ORDINALITY t(e, n)
           ORDER BY n OFFSET jsonb_array_length(v_hist) - 50) z);
      END IF;
      v_bc := v_bc || jsonb_build_object(
                'caisse', greatest(0, coalesce(nullif(v_bc->>'caisse','')::numeric,0) + v_montant),
                'historique', v_hist);
      INSERT INTO public.budgets_clubs (id, data, updated_at) VALUES (v_club, v_bc, now())
      ON CONFLICT (id) DO UPDATE SET data = excluded.data, updated_at = now();
    END IF;
  ELSE
    v_membres := jsonb_set(v_membres, ARRAY[v_trouve::text,'derniereCotisationDate'],
                   to_jsonb(to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
    -- Correctif anterieur conserve : la cotisation d'un syndicat alimente SA caisse, sinon les
    -- 50 FR quittaient le personnage sans arriver nulle part.
    v_data := jsonb_set(v_data, '{caisse}',
                to_jsonb(coalesce(nullif(v_data->>'caisse','')::numeric,0) + v_montant), true);
  END IF;

  v_data := jsonb_set(v_data, '{membres}', v_membres);
  UPDATE public.organisations SET data = v_data::text WHERE id = p_orga_id;
  RETURN jsonb_build_object('ok',true,'action','renouvellement','membre',p_membre,
                            'montant',v_montant,'club',v_club);
END; $function$;


INSERT INTO public.recettes_commerce (id,source,label,pa,portions,materiaux,prix_fixe,categorie,types_autorises,pays_autorises,villes_autorisees,buildings_autorises,effets,image,intermediaires)
VALUES ('the_chaud_sovarka','alimentaire','Thé chaud',1,15,'{"produits_exotiques":1}'::jsonb,5,'boisson','["buvette"]'::jsonb,'["soviet"]'::jsonb,'["capitale"]'::jsonb,'["stade"]'::jsonb,'{"moral":1}'::jsonb,NULL,'{}'::jsonb),
('chocolat_chaud_sovarka','alimentaire','Chocolat chaud',1,10,'{"produits_exotiques":1}'::jsonb,8,'boisson','["buvette"]'::jsonb,'["soviet"]'::jsonb,'["capitale"]'::jsonb,'["stade"]'::jsonb,'{"moral":2}'::jsonb,NULL,'{}'::jsonb),
('vin_chaud_sovarka','alimentaire','Vin chaud',1,10,'{"alcool":1}'::jsonb,12,'boisson','["buvette"]'::jsonb,'["soviet"]'::jsonb,'["capitale"]'::jsonb,'["stade"]'::jsonb,'{"moral":2}'::jsonb,NULL,'{}'::jsonb),
('pirojki_sovarka','alimentaire','Pirojki',1,15,'{"cereales":1}'::jsonb,6,'snack','["buvette"]'::jsonb,'["soviet"]'::jsonb,'["capitale"]'::jsonb,'["stade"]'::jsonb,'{"hp":2,"moral":1}'::jsonb,NULL,'{}'::jsonb)
ON CONFLICT (id) DO UPDATE SET label=excluded.label,pa=excluded.pa,portions=excluded.portions,materiaux=excluded.materiaux,prix_fixe=excluded.prix_fixe,categorie=excluded.categorie,types_autorises=excluded.types_autorises,pays_autorises=excluded.pays_autorises,villes_autorisees=excluded.villes_autorisees,buildings_autorises=excluded.buildings_autorises,effets=excluded.effets;

UPDATE public.entreprises e SET data =
  jsonb_set(
    jsonb_set(
      jsonb_set(e.data, '{carte}',
        '["the_chaud_sovarka","chocolat_chaud_sovarka","vin_chaud_sovarka","pirojki_sovarka"]'::jsonb,true),
      '{parametres,stockMax}',
        (coalesce(e.data#>'{parametres,stockMax}','{}'::jsonb) - 'biere_pression' - 'boisson_sans_alcool' - 'snack_buvette')
        || '{"the_chaud_sovarka":20,"chocolat_chaud_sovarka":20,"vin_chaud_sovarka":20,"pirojki_sovarka":20}'::jsonb,true),
    '{parametres,prixVente}',
       (coalesce(e.data#>'{parametres,prixVente}','{}'::jsonb) - 'biere_pression' - 'boisson_sans_alcool' - 'snack_buvette')
       || '{"the_chaud_sovarka":5,"chocolat_chaud_sovarka":8,"vin_chaud_sovarka":12,"pirojki_sovarka":6}'::jsonb,true)
 WHERE e.id='buvette-soviet-capitale-stade-buvette';

DO $controle$
BEGIN
 IF (SELECT cost FROM public.ordres_couts_pays WHERE pays='soviet' AND fn='rejoindre_club_supporters')<>25
 OR (SELECT count(*) FROM public.recettes_commerce WHERE id IN ('the_chaud_sovarka','chocolat_chaud_sovarka','vin_chaud_sovarka','pirojki_sovarka') AND pays_autorises='["soviet"]'::jsonb)<>4
 THEN RAISE EXCEPTION 'dynamo_tarifs_carte_incomplets'; END IF;
END $controle$;
