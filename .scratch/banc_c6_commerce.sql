-- ===========================================================================
-- BANC C6 — APPROVISIONNEMENT, PRESENCE, CMUP, FISCALITE, FREEMIUM
-- Se termine par un RAISE : la transaction entiere est annulee, zero residu.
-- ===========================================================================
DO $banc$
DECLARE
  R text := '';
  n_ok int := 0; n_ko int := 0;
  FONDS constant text := 'zzc6-fonds';
  REF_ID text;
  v jsonb; v2 jsonb; d jsonb; q int;
  IMPL constant jsonb := jsonb_build_object('country','republic','city','capitale',
        'buildingId','centre-commercial','roomId','boutique_milieu','bailId','zzc6-bail');

  c_avant numeric; c_apres numeric; rid text;
BEGIN
  -- ---------- FIXTURE ----------
  -- FIXTURE : on emprunte des personnages REELS et on les repositionne. Tout est
  -- annule par le RAISE final, donc aucun d'eux n'est modifie durablement. On
  -- evite ainsi de fabriquer des comptes auth.users pour un banc.
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale',
         current_building='centre-commercial', current_room='boutique_milieu',
         arg=0, liquide=0, inventory='[{"name":"Métal","stackable":true,"stackKey":"metal","qty":50}]'::jsonb
   WHERE name IN ('Marsault','Phileas Frogg');
  UPDATE public.personnages_donnees SET country='republic', current_city='ville_b',
         arg=0, liquide=0, inventory='[{"name":"Métal","stackable":true,"stackKey":"metal","qty":50}]'::jsonb
   WHERE name='Vince Kubrick';
  UPDATE public.personnages_donnees SET country='republic', current_city='capitale',
         current_building='centre-commercial', current_room='boutique_milieu',
         arg=5000, liquide=5000 WHERE name='zzAut';

  INSERT INTO public.entreprises (id, data) VALUES (FONDS, jsonb_build_object(
    'id', FONDS, 'version', 2, 'type', 'fonds_commerce', 'statut', 'actif',
    'proprietaire', 'Marsault', 'enseigne', 'Banc C6', 'caisse', 1000,
    'implantation', IMPL,
    'references', '{}'::jsonb, 'stockReferences', '{}'::jsonb, 'coutMoyenReferences', '{}'::jsonb,
    'stockMatieres', '{}'::jsonb, 'coutMoyenMatieres', '{}'::jsonb, 'stockProduits', '{}'::jsonb,
    'typesAutorises', '["commerce-non-alimentaire","vetements"]'::jsonb, 'historique', '[]'::jsonb));

  v := public.fonds_reference_creer('Marsault', FONDS, 'souvenir',
        'porte_cle_palais_luthecia', 'Porte-cle du banc', null);
  REF_ID := v->>'referenceId';
  IF REF_ID IS NULL THEN RAISE EXCEPTION 'FIXTURE KO : %', v::text; END IF;

  -- ================= A. APPROVISIONNEMENT =================
  -- A1 matiere derivee de la recette
  IF EXISTS (SELECT 1 FROM public.fonds_matieres_recherchees(FONDS) m WHERE m.matiere='metal')
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    A1 metal derive de la recette';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] A1 metal non derive'; END IF;

  -- A2 matiere etrangere refusee
  v := public.fonds_matiere_apporter('appro-a2aaaa','Phileas Frogg',FONDS,'poisson',1,'vente');
  IF v->>'raison' = 'matiere_hors_activites'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    A2 poisson refuse (matiere_hors_activites)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] A2 -> ' || v::text; END IF;

  -- A3 prix de rachat fixe par le proprietaire
  v := public.fonds_matiere_parametres('Marsault',FONDS,'metal', 20, 20, true);
  IF (v->>'ok')::boolean AND (v->>'prixAchat')::numeric = 20
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    A3 prix de rachat fixe a 20 (hors fourchette legacy 0,5x-1,5x)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] A3 -> ' || v::text; END IF;

  -- A4 absence physique refusee
  v := public.fonds_matiere_apporter('appro-a4aaaa','Vince Kubrick',FONDS,'metal',1,'vente');
  IF v->>'raison' = 'pas_sur_place'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    A4 vente a distance refusee (pas_sur_place)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] A4 -> ' || v::text; END IF;

  -- A5 quantite nulle / negative
  v := public.fonds_matiere_apporter('appro-a5aaaa','Phileas Frogg',FONDS,'metal',0,'vente');
  v2 := public.fonds_matiere_apporter('appro-a5bbbb','Phileas Frogg',FONDS,'metal',-3,'vente');
  IF v->>'raison'='quantite_invalide' AND v2->>'raison'='quantite_invalide'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    A5 quantites 0 et -3 refusees';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] A5'; END IF;

  -- A6 un autre PJ vend 10 metal a 20 FR
  v := public.fonds_matiere_apporter('appro-a6aaaa','Phileas Frogg',FONDS,'metal',10,'vente');
  SELECT arg INTO q FROM public.personnages_donnees WHERE name='Phileas Frogg';
  IF (v->>'ok')::boolean AND (v->>'quantite')::int=10 AND (v->>'montant')::numeric=200 AND q=200
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    A6 vente 10x20 : PJ +200 FR, caisse -200';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] A6 -> ' || v::text || ' arg=' || q; END IF;

  -- A7 bornage par la capacite restante (max 20, deja 10)
  v := public.fonds_matiere_apporter('appro-a7aaaa','Phileas Frogg',FONDS,'metal',40,'vente');
  IF (v->>'ok')::boolean AND (v->>'quantite')::int = 10 AND (v->>'demandee')::int = 40
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    A7 40 demandes, 10 realises (capacite bornee, pas de refus sec)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] A7 -> ' || v::text; END IF;

  -- A8 stock plein
  v := public.fonds_matiere_apporter('appro-a8aaaa','Phileas Frogg',FONDS,'metal',1,'vente');
  IF v->>'raison' = 'stock_plein'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    A8 stock plein refuse';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] A8 -> ' || v::text; END IF;

  -- A9 rejeu de la meme cle
  SELECT arg INTO q FROM public.personnages_donnees WHERE name='Phileas Frogg';
  v := public.fonds_matiere_apporter('appro-a6aaaa','Phileas Frogg',FONDS,'metal',10,'vente');
  IF (v->>'rejeu')::boolean
     AND (SELECT arg FROM public.personnages_donnees WHERE name='Phileas Frogg') = q
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    A9 rejeu neutre (double clic sans double paiement)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] A9 -> ' || v::text || ' arg=' || q; END IF;

  -- ================= C. CMUP =================
  -- On libere de la place puis on melange deux prix.
  UPDATE public.entreprises SET data = jsonb_set(data,'{stockMatieres,metal}','10'::jsonb)
   WHERE id = FONDS;
  UPDATE public.entreprises SET data = jsonb_set(data,'{coutMoyenMatieres,metal}','15'::jsonb)
   WHERE id = FONDS;
  v := public.fonds_matiere_apporter('appro-c1aaaa','Phileas Frogg',FONDS,'metal',10,'vente');
  IF (v->>'coutMoyen')::numeric = 17.5
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C1 CMUP (10 a 15 + 10 a 20) = 17,5';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C1 -> ' || coalesce(v->>'coutMoyen','?'); END IF;

  -- C2 don a cout nul : dilue le CMUP, ne cree pas de valeur
  UPDATE public.entreprises SET data = jsonb_set(jsonb_set(data,'{stockMatieres,metal}','10'::jsonb),
                                                 '{coutMoyenMatieres,metal}','20'::jsonb)
   WHERE id = FONDS;
  SELECT arg INTO q FROM public.personnages_donnees WHERE name='Marsault';
  v := public.fonds_matiere_apporter('appro-c2aaaa','Marsault',FONDS,'metal',10,'don');
  IF (v->>'ok')::boolean AND (v->>'montant')::numeric = 0 AND (v->>'coutMoyen')::numeric = 10
     AND (SELECT arg FROM public.personnages_donnees WHERE name='Marsault') = q
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C2 don : 0 FR echange, CMUP dilue de 20 a 10';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C2 -> ' || v::text; END IF;

  -- C3 le proprietaire vend a son propre commerce : patrimoines distincts
  UPDATE public.entreprises SET data = jsonb_set(data,'{stockMatieres,metal}','0'::jsonb) WHERE id=FONDS;
  SELECT arg INTO q FROM public.personnages_donnees WHERE name='Marsault';
  v := public.fonds_matiere_apporter('appro-c3aaaa','Marsault',FONDS,'metal',5,'vente');
  IF (v->>'ok')::boolean AND (v->>'montant')::numeric = 100
     AND (SELECT arg FROM public.personnages_donnees WHERE name='Marsault') = q + 100
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C3 proprietaire vend a son commerce : caisse -100, poche +100';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C3 -> ' || v::text; END IF;

  -- C4 caisse insuffisante
  UPDATE public.entreprises SET data = jsonb_set(jsonb_set(data,'{caisse}','10'::jsonb),
                                                 '{stockMatieres,metal}','0'::jsonb) WHERE id=FONDS;
  v := public.fonds_matiere_apporter('appro-c4aaaa','Phileas Frogg',FONDS,'metal',5,'vente');
  IF (v->>'ok')::boolean AND (v->>'quantite')::int = 0
    THEN n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C4 quantite nulle acceptee';
  ELSIF v->>'raison' = 'caisse_insuffisante'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C4 caisse 10 / prix 20 : refus caisse_insuffisante';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C4 -> ' || v::text; END IF;

  -- ================= D. PRODUCTION ET CMUP PRODUIT FINI =================
  UPDATE public.entreprises SET data = jsonb_set(jsonb_set(jsonb_set(data,'{caisse}','1000'::jsonb),
                                    '{stockMatieres,metal}','10'::jsonb),
                                    '{coutMoyenMatieres,metal}','20'::jsonb) WHERE id=FONDS;
  v := public.fonds_reference_produire('prod-c6aaaa','Marsault',FONDS,REF_ID);
  IF (v->>'ok')::boolean
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    D1 production a partir du stock approvisionne : ' || v::text;
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] D1 -> ' || v::text; END IF;

  -- ================= E. FREEMIUM =================
  -- D2 le lot complet ferait depasser le maximum : refus ENTIER
  PERFORM public.fonds_reference_stock_max('Marsault',FONDS,REF_ID,8);
  SELECT (data->'stockMatieres'->>'metal')::numeric INTO c_avant FROM public.entreprises WHERE id=FONDS;
  v := public.fonds_reference_produire('prod-d2aaaa','Marsault',FONDS,REF_ID);
  IF v->>'raison'='stock_max_reference_depasse' AND (v->>'rendement')::int=6
     AND (v->>'maximum')::int=8 AND (v->>'stock')::int=6
    THEN n_ok:=n_ok+1; R:=R||E'\n  [OK]    D2 stock 6 + rendement 6 > max 8 : lot entier refuse';
    ELSE n_ko:=n_ko+1; R:=R||E'\n  [ECHEC] D2 -> '||v::text; END IF;

  -- D3 un refus ne coute rien : la matiere est intacte
  SELECT (data->'stockMatieres'->>'metal')::numeric INTO c_apres FROM public.entreprises WHERE id=FONDS;
  IF c_apres = c_avant
    THEN n_ok:=n_ok+1; R:=R||E'\n  [OK]    D3 le refus n''a consomme aucune matiere';
    ELSE n_ko:=n_ko+1; R:=R||E'\n  [ECHEC] D3 metal '||c_avant||' -> '||c_apres; END IF;

  -- D4 maximum suffisant : le meme lot passe
  PERFORM public.fonds_reference_stock_max('Marsault',FONDS,REF_ID,30);
  v := public.fonds_reference_produire('prod-d4aaaa','Marsault',FONDS,REF_ID);
  IF (v->>'ok')::boolean AND (v->>'stockApres')::int=12
    THEN n_ok:=n_ok+1; R:=R||E'\n  [OK]    D4 max 30 : le meme lot passe (6 -> 12)';
    ELSE n_ko:=n_ko+1; R:=R||E'\n  [ECHEC] D4 -> '||v::text; END IF;

  PERFORM public.fonds_reference_creer('Marsault',FONDS,'souvenir','garde_republien_plomb','R2',null);
  PERFORM public.fonds_reference_creer('Marsault',FONDS,'souvenir','figurine_maxence_monfils','R3',null);
  PERFORM public.fonds_reference_creer('Marsault',FONDS,'souvenir','porte_cle_palais_luthecia','R4',null);
  v := public.fonds_reference_creer('Marsault',FONDS,'souvenir','porte_cle_palais_luthecia','R5',null);
  SELECT count(*) INTO q FROM jsonb_each((SELECT data->'references' FROM public.entreprises WHERE id=FONDS));
  IF v->>'raison' = 'plafond_references_atteint' AND q = 4
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    E1 5e reference refusee, les 4 existantes preservees';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] E1 -> ' || v::text || ' refs=' || q; END IF;

  -- E2 desactiver ne libere AUCUNE place : la limite porte sur le CATALOGUE
  PERFORM public.fonds_reference_activer('Marsault',FONDS,REF_ID,false);
  v := public.fonds_reference_creer('Marsault',FONDS,'souvenir','porte_cle_palais_luthecia','R6',null);
  SELECT count(*) INTO q FROM jsonb_each((SELECT data->'references' FROM public.entreprises WHERE id=FONDS));
  IF v->>'raison'='plafond_references_atteint' AND q=4
    THEN n_ok:=n_ok+1; R:=R||E'\n  [OK]    E2 desactiver ne libere pas de place (catalogue, pas actives)';
    ELSE n_ko:=n_ko+1; R:=R||E'\n  [ECHEC] E2 -> '||v::text||' refs='||q; END IF;

  -- E3 l'activation n'est plus plafonnee : les 4 references peuvent etre en vente
  UPDATE public.entreprises SET data = jsonb_set(data, '{references}', (
    SELECT jsonb_object_agg(k, jsonb_set(val,'{prixVente}','40'::jsonb))
      FROM jsonb_each(data->'references') AS t(k,val))) WHERE id=FONDS;
  q := 0;
  FOR rid IN SELECT k FROM jsonb_each((SELECT data->'references' FROM public.entreprises WHERE id=FONDS)) AS t(k,val) LOOP
    v := public.fonds_reference_activer('Marsault',FONDS,rid,true);
    IF (v->>'ok')::boolean THEN q := q + 1; END IF;
  END LOOP;
  IF q = 4 THEN n_ok:=n_ok+1; R:=R||E'\n  [OK]    E3 les 4 references activables : plus de plafond concurrent';
    ELSE n_ko:=n_ko+1; R:=R||E'\n  [ECHEC] E3 activees='||q; END IF;

  -- ================= F. FACE PUBLIQUE ET FISCALITE =================
  UPDATE public.entreprises SET data = jsonb_set(jsonb_set(jsonb_set(data,
        ARRAY['references', REF_ID, 'prixVente'],'40'::jsonb),
        ARRAY['references', REF_ID, 'active'],'true'::jsonb),
        ARRAY['stockReferences', REF_ID],'6'::jsonb) WHERE id=FONDS;

  -- F1 achat a distance refuse
  v := public.acheter_produit_commerce('achat-f1aaaa','Vince Kubrick',FONDS,REF_ID,1);
  IF v->>'raison' = 'pas_sur_place'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F1 achat a distance refuse (pas_sur_place)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F1 -> ' || v::text; END IF;

  -- F2 achat sur place + fiscalite
  SELECT (data->>'caisse')::numeric INTO c_avant FROM public.entreprises WHERE id=FONDS;
  v := public.acheter_produit_commerce('achat-f2aaaa','zzAut',FONDS,REF_ID,2);
  IF (v->>'ok')::boolean AND (v->>'montant')::numeric = 80
     AND (v->>'taxeLocale') IS NOT NULL AND (v->>'net')::numeric < 80
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F2 achat 2x40 : brut 80, taxes '
         || (v->>'taxeLocale') || '+' || (v->>'taxeNationale') || ', net ' || (v->>'net');
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F2 -> ' || v::text; END IF;

  -- F3 la caisse recoit le NET, pas le brut
  SELECT (data->>'caisse')::numeric INTO c_apres FROM public.entreprises WHERE id=FONDS;
  IF c_apres = c_avant + (v->>'net')::numeric
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F3 la caisse encaisse le NET';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F3 caisse='
         || (SELECT (data->>'caisse')::text FROM public.entreprises WHERE id=FONDS); END IF;

  -- F4 rejeu : pas de double taxe
  v2 := public.acheter_produit_commerce('achat-f2aaaa','zzAut',FONDS,REF_ID,2);
  IF (v2->>'rejeu')::boolean
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F4 rejeu d''achat : ni seconde vente ni seconde taxe';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F4 -> ' || v2::text; END IF;

  -- F5 le proprietaire peut acheter chez lui
  v := public.acheter_produit_commerce('achat-f5aaaa','Marsault',FONDS,REF_ID,1);
  IF (v->>'ok')::boolean
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F5 le proprietaire achete dans son propre commerce';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F5 -> ' || v::text; END IF;

  -- ================= G. MAXIMUMS DISTINCTS =================
  v := public.fonds_reference_stock_max('Marsault',FONDS,REF_ID,30);
  SELECT data->'parametres' INTO d FROM public.entreprises WHERE id=FONDS;
  IF (v->>'ok')::boolean
     AND (d->'stockMaxReferences'->>REF_ID)::int = 30
     AND (d->'stockMaxMatieres'->>'metal')::int = 20
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    G1 stockMaxReferences=30 et stockMaxMatieres=20 coexistent sans se confondre';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] G1 -> ' || d::text; END IF;

  -- G2 maximum matiere hors plafond pays
  v := public.fonds_matiere_parametres('Marsault',FONDS,'metal',20,25,true);
  IF v->>'raison' = 'maximum_invalide'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    G2 maximum 25 refuse (plafond pays 20)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] G2 -> ' || v::text; END IF;

  -- G3 un tiers ne peut pas parametrer le commerce
  v := public.fonds_matiere_parametres('Phileas Frogg',FONDS,'metal',99,5,true);
  IF v->>'raison' = 'pas_proprietaire'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    G3 parametrage refuse a un tiers';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] G3 -> ' || v::text; END IF;

  -- ================= I. RACCORDEMENT L2 ET FILTRAGE =================
  -- Second fonds : le premier a atteint ses 4 references, et la limite gratuite
  -- ne doit evidemment pas etre contournee pour les besoins d'un test.
  INSERT INTO public.entreprises (id, data) VALUES ('zzc6-fonds-2', jsonb_build_object(
    'id','zzc6-fonds-2','version',2,'type','fonds_commerce','statut','actif',
    'proprietaire','Marsault','enseigne','Banc C6 bis','caisse',1000,
    'implantation', jsonb_build_object('country','republic','city','capitale',
       'buildingId','centre-commercial','roomId','boutique_milieu','bailId','zzc6-bail-2'),
    'references','{}'::jsonb,'stockReferences','{}'::jsonb,'coutMoyenReferences','{}'::jsonb,
    'stockMatieres','{}'::jsonb,'coutMoyenMatieres','{}'::jsonb,'stockProduits','{}'::jsonb,
    'typesAutorises','["commerce-non-alimentaire","vetements"]'::jsonb,'historique','[]'::jsonb));

  -- I1 plus aucun cul-de-sac : tout generique propose a au moins une recette
  SELECT count(*) INTO q FROM public.fonds_generiques_accessibles('zzc6-fonds-2') g
   WHERE NOT EXISTS (SELECT 1 FROM public.recettes_commerce r WHERE r.generique_id = g.generique_id);
  IF q = 0 THEN n_ok:=n_ok+1; R:=R||E'\n  [OK]    I1 aucun generique propose sans recette';
    ELSE n_ko:=n_ko+1; R:=R||E'\n  [ECHEC] I1 '||q||' generiques sans recette encore proposes'; END IF;

  -- I2 T-SHIRT : generique propose, recette proposee, reference creable
  IF EXISTS (SELECT 1 FROM public.fonds_generiques_accessibles('zzc6-fonds-2') g WHERE g.generique_id='haut')
     AND EXISTS (SELECT 1 FROM public.generique_recettes_systeme('haut') x WHERE x.recette_id='tshirt_psm')
    THEN n_ok:=n_ok+1; R:=R||E'\n  [OK]    I2 T-shirt : generique « haut » propose et recette tshirt_psm offerte';
    ELSE n_ko:=n_ko+1; R:=R||E'\n  [ECHEC] I2'; END IF;

  v := public.fonds_reference_creer('Marsault','zzc6-fonds-2','haut','tshirt_psm','T-shirt de PSM',null);
  IF (v->>'ok')::boolean
    THEN n_ok:=n_ok+1; R:=R||E'\n  [OK]    I3 reference T-shirt creee';
    ELSE n_ko:=n_ko+1; R:=R||E'\n  [ECHEC] I3 -> '||v::text; END IF;

  -- I4 les matieres du T-shirt sont derivees de SA recette
  IF EXISTS (SELECT 1 FROM public.fonds_matieres_recherchees('zzc6-fonds-2') m WHERE m.matiere='textile')
    THEN n_ok:=n_ok+1; R:=R||E'\n  [OK]    I4 textile derive de la recette du T-shirt';
    ELSE n_ko:=n_ko+1; R:=R||E'\n  [ECHEC] I4 textile non derive'; END IF;

  -- I5 CARTE POSTALE : creable, et sa matiere (bois) s'ajoute aux matieres du fonds
  v := public.fonds_reference_creer('Marsault','zzc6-fonds-2','carte-postale','carte_psm_touristique','Souvenir de PSM',null);
  IF (v->>'ok')::boolean
     AND EXISTS (SELECT 1 FROM public.fonds_matieres_recherchees('zzc6-fonds-2') m WHERE m.matiere='bois')
    THEN n_ok:=n_ok+1; R:=R||E'\n  [OK]    I5 carte postale creee, bois derive de sa recette';
    ELSE n_ko:=n_ko+1; R:=R||E'\n  [ECHEC] I5 -> '||v::text; END IF;

  -- I6 un generique sans recette n'est plus proposable
  IF NOT EXISTS (SELECT 1 FROM public.fonds_generiques_accessibles('zzc6-fonds-2') g WHERE g.generique_id='chaussures')
    THEN n_ok:=n_ok+1; R:=R||E'\n  [OK]    I6 « chaussures » (0 recette) n''est plus propose';
    ELSE n_ko:=n_ko+1; R:=R||E'\n  [ECHEC] I6'; END IF;

  -- I7 aucun effet de bord sur restauration et armurerie
  SELECT count(*) INTO q FROM public.recettes_commerce
   WHERE categorie <> 'objet' AND generique_id IS NOT NULL;
  IF q = 0 AND (SELECT count(*) FROM public.recettes_production WHERE generique_id IS NOT NULL) = 0
    THEN n_ok:=n_ok+1; R:=R||E'\n  [OK]    I7 restauration et armurerie intactes (0 raccordement)';
    ELSE n_ko:=n_ko+1; R:=R||E'\n  [ECHEC] I7 restauration raccordees='||q; END IF;

  RAISE EXCEPTION E'\n=========================================================\n  BANC C6 — %/% cas verts\n=========================================================%\n',
    n_ok, n_ok + n_ko, R;
END $banc$;
