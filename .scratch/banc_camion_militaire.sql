-- ===========================================================================
-- BANC CAMION MILITAIRE — 29 septembre 2026
-- Se termine par un RAISE : la transaction entiere est annulee, zero residu.
-- Aucun personnage, aucun soldat, aucun camion de production n'est modifie
-- durablement : on les emprunte le temps de la transaction.
-- ===========================================================================
DO $banc$
DECLARE
  R text := ''; n_ok int := 0; n_ko int := 0;
  CAM constant text := 'zzbanc-camion';
  BAT text;
  u_vince uuid; u_arnie uuid; u_mars uuid; u_phil uuid; u_zz uuid;
  v jsonb; v2 jsonb;
  cv text; cb text; cr text;                 -- position du camion
  pv text; pb text; pr text; pp int;         -- position/PA d'un personnage
  qv text; qb text; qr text; qp int;         -- idem, second personnage
  pa_av int; pa_ap int; n int; n2 int;
  sol_id text; libere text[];
  arg0 numeric; arg1 numeric;
BEGIN
  BAT := public.camion_batiment_interieur();

  -- ---------- FIXTURE ----------
  SELECT user_id INTO u_vince FROM public.personnages_donnees WHERE name='Vince Kubrick';
  SELECT user_id INTO u_arnie FROM public.personnages_donnees WHERE name='Arnie';
  SELECT user_id INTO u_mars  FROM public.personnages_donnees WHERE name='Marsault';
  SELECT user_id INTO u_phil  FROM public.personnages_donnees WHERE name='Phileas Frogg';
  SELECT user_id INTO u_zz    FROM public.personnages_donnees WHERE name='zzAut';
  IF u_vince IS NULL OR u_arnie IS NULL OR u_zz IS NULL OR u_mars IS NULL OR u_phil IS NULL THEN
    RAISE EXCEPTION 'FIXTURE KO : comptes manquants'; END IF;

  INSERT INTO public.camions_militaires (id,pays,institution,perimetre,libelle,capacite,
    caserne_ville,caserne_building,caserne_room,caserne_libelle, ville,building_id,room_id)
  VALUES (CAM,'republic','militaire','zzbanc','Camion de banc',25,
    'caserne','caserne-militaire','corps_garde','Caserne du banc',
    'caserne','caserne-militaire','corps_garde');

  UPDATE public.personnages_donnees SET country='republic', current_city='caserne',
     current_building='caserne-militaire', current_room='corps_garde', pa=12,
     arg=1000, liquide=1000
   WHERE name IN ('Vince Kubrick','Arnie','Marsault','Phileas Frogg','zzAut');
  -- Un Capitaine pour les cas R et S : aucun PJ n'en est un en production, le
  -- grade est pose ici et disparait avec la transaction.
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','capitaine','name','Capitaine')
   WHERE name='zzAut';
  SELECT sum(arg)+sum(liquide) INTO arg0 FROM public.personnages_donnees
   WHERE name IN ('Vince Kubrick','Arnie','Marsault','Phileas Frogg','zzAut');

  -- ================= A. LE CAMION EST A SA CASERNE =================
  SELECT ville, building_id, room_id INTO cv, cb, cr
    FROM public.camions_militaires WHERE id=CAM;
  IF cv='caserne' AND cb='caserne-militaire' AND cr='corps_garde'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    A  camion initial a sa caserne, capacite 25';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] A  position initiale ' || cv || '/' || cb || '/' || cr; END IF;

  -- ================= U. LE BOUTON N'EXISTE QU'OU EST LE CAMION ============
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);
  v  := public.camions_ici('republic','caserne','caserne-militaire','corps_garde');
  v2 := public.camions_ici('republic','capitale','centre-multinodal-luthecia','hall_gare');
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v->'camions') e WHERE e->>'id'=CAM)
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v2->'camions') e WHERE e->>'id'=CAM)
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    B/C bouton present a la caserne, ABSENT du centre multimodal de Luthecia';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] B/C -> ' || v::text || ' / ' || v2::text; END IF;

  -- ================= B. UN CIVIL MONTE ET DESCEND, 0 PA =================
  SELECT pa INTO pa_av FROM public.personnages_donnees WHERE name='Arnie';
  v := public.camion_monter(CAM,'k-b1');
  SELECT current_city,current_building,current_room,pa INTO pv,pb,pr,pp
    FROM public.personnages_donnees WHERE name='Arnie';
  IF (v->>'ok')::boolean AND pb=BAT AND pr=CAM AND pv='caserne' AND pp=pa_av
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F1 civil monte : il est dans la piece du camion, 0 PA';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F1 -> ' || v::text; END IF;

  v := public.camion_descendre(CAM);
  SELECT current_building,current_room,pa INTO pb,pr,pp
    FROM public.personnages_donnees WHERE name='Arnie';
  IF (v->>'ok')::boolean AND pb='caserne-militaire' AND pr='corps_garde' AND pp=pa_av
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F2 civil descend : retour au lieu de stationnement, 0 PA';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F2 -> ' || v::text; END IF;

  -- ================= C. UN CIVIL NE COMMANDE PAS =================
  PERFORM public.camion_monter(CAM,'k-c1');
  v := public.camion_deplacer(CAM,'multimodal_capitale',true,'k-c2');
  SELECT ville INTO cv FROM public.camions_militaires WHERE id=CAM;
  IF v->>'raison'='grade_insuffisant' AND cv='caserne'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    G  civil sans grade : grade_insuffisant, camion immobile';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] G  -> ' || v::text || ' ville=' || cv; END IF;

  -- ================= F. CIVIL + SECTION INCOMPLETE = CIVIL CONSERVE =======
  -- Quatre soldats sont detaches de Vince et restent au corps de garde : sa
  -- section en compte 20, et le civil deja a bord doit y rester.
  SELECT array_agg(id) INTO libere FROM (
    SELECT m.id FROM public.pnj_membres m
      LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id=m.id
     WHERE m.famille='soldat' AND m.leader_pj='Vince Kubrick'
       AND COALESCE(sm.en_reserve,false)=false ORDER BY m.id LIMIT 4) t;
  UPDATE public.pnj_membres SET leader_pj=NULL, ville='caserne',
         building_id='caserne-militaire', room_id='corps_garde'
   WHERE id = ANY(libere);

  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_vince,'role','authenticated')::text, true);
  v := public.camion_monter(CAM,'k-f2');
  SELECT count(*) INTO n FROM public.camion_occupants(CAM);
  SELECT current_room INTO pr FROM public.personnages_donnees WHERE name='Arnie';
  IF (v->>'ok')::boolean AND (v->>'embarques')::int=21 AND n=22 AND pr=CAM
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    J1 Arnie + Vince et 20 soldats = 22 : Arnie reste a bord (place disponible)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] J1 occupants=' || n || ' arnie=' || coalesce(pr,'?') || ' -> ' || v::text; END IF;

  -- ================= O. LE GROUPE RESTE RATTACHE, SANS AUCUNE ECRITURE ====
  SELECT count(*) INTO n FROM public.pnj_membres
   WHERE leader_pj='Vince Kubrick' AND famille='soldat'
     AND ville IS NULL AND building_id IS NULL AND room_id IS NULL;
  SELECT count(*) INTO n2 FROM public.camion_occupants(CAM) o
   WHERE o.chef='Vince Kubrick' AND NOT o.est_pj;
  IF n=20 AND n2=20
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    H  20 soldats a bord sans aucune position ecrite (resolus par leur chef)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] H  sans position=' || n || ' a bord=' || n2; END IF;

  -- ================= D/E/G. SECTION COMPLETE = 25, LE CIVIL DESCEND =======
  PERFORM public.camion_descendre(CAM);
  UPDATE public.pnj_membres SET leader_pj='Vince Kubrick', ville=NULL,
         building_id=NULL, room_id=NULL WHERE id = ANY(libere);
  v := public.camion_monter(CAM,'k-g1');
  SELECT count(*) INTO n FROM public.camion_occupants(CAM);
  SELECT current_building,current_room INTO pb,pr
    FROM public.personnages_donnees WHERE name='Arnie';
  IF (v->>'ok')::boolean AND (v->>'embarques')::int=25 AND n=25
     AND pb='caserne-militaire' AND pr='corps_garde'
     AND jsonb_array_length(v->'debarques')=1
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    I/J/K capacite 25 atteinte, priorite section, Arnie ejecte et reste sur place';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] I/J/K occupants=' || n || ' -> ' || v::text; END IF;

  -- ================= J/W. UN SOLDAT SANS PA = REFUS GLOBAL ===============
  SELECT id INTO sol_id FROM public.pnj_membres
   WHERE leader_pj='Vince Kubrick' AND famille='soldat' ORDER BY id LIMIT 1;
  UPDATE public.pnj_membres SET pa=1 WHERE id=sol_id;
  SELECT pa INTO pa_av FROM public.personnages_donnees WHERE name='Vince Kubrick';
  v := public.camion_deplacer(CAM,'multimodal_capitale',true,'k-j1');
  SELECT ville INTO cv FROM public.camions_militaires WHERE id=CAM;
  SELECT pa INTO pa_ap FROM public.personnages_donnees WHERE name='Vince Kubrick';
  SELECT count(*) INTO n FROM public.pnj_membres
   WHERE leader_pj='Vince Kubrick' AND famille='soldat' AND pa=12;
  SELECT count(*) INTO n2 FROM public.camion_occupants(CAM);
  IF v->>'raison'='pa_insuffisants_section' AND cv='caserne' AND pa_ap=pa_av
     AND n=23 AND n2=25
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    N/V refus global : aucun PA preleve, camion immobile, 25 occupants intacts';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] P2 -> ' || v::text || ' ville=' || cv || ' paV=' || pa_ap || ' a12=' || n || ' occ=' || n2; END IF;
  UPDATE public.pnj_membres SET pa=12 WHERE id=sol_id;

  -- ================= H/I/L/M. TRAJET NORMAL ==============================
  SELECT pa INTO pa_av FROM public.personnages_donnees WHERE name='Vince Kubrick';
  v := public.camion_deplacer(CAM,'multimodal_capitale',true,'k-h1');
  SELECT ville,building_id,room_id INTO cv,cb,cr FROM public.camions_militaires WHERE id=CAM;
  SELECT current_city,current_building,current_room,pa INTO pv,pb,pr,pp
    FROM public.personnages_donnees WHERE name='Vince Kubrick';
  SELECT count(*) INTO n FROM public.pnj_membres
   WHERE leader_pj='Vince Kubrick' AND famille='soldat' AND pa=10;
  IF (v->>'ok')::boolean AND cv='capitale' AND cb='centre-multinodal-luthecia'
     AND cr='hall_gare' AND pp=pa_av-2 AND n=24
     AND pv='capitale' AND pb=BAT AND pr=CAM
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    L/M/P camion a Luthecia, Vince -2 PA, 24 soldats -2 PA chacun, tous encore a bord';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] L  -> ' || v::text || ' camion=' || cv || ' paV=' || pp || ' soldats10=' || n; END IF;

  -- ================= D2. IL A DISPARU DE LA CASERNE, IL EST A LUTHECIA ====
  -- Une seule position reelle : il ne peut jamais y avoir deux acces simultanes
  -- au meme camion. On interroge les DEUX lieux, pas seulement celui d'arrivee.
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);
  v  := public.camions_ici('republic','caserne','caserne-militaire','corps_garde');
  v2 := public.camions_ici('republic','capitale','centre-multinodal-luthecia','hall_gare');
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v->'camions') e WHERE e->>'id'=CAM)
     AND EXISTS (SELECT 1 FROM jsonb_array_elements(v2->'camions') e WHERE e->>'id'=CAM)
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    D  apres le trajet : disparu de la caserne, apparu au centre multimodal de Luthecia';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] D  -> caserne=' || v::text || ' luthecia=' || v2::text; END IF;

  -- Un PJ reste a la caserne ne peut PAS monter dans un camion parti.
  v := public.camion_monter(CAM,'k-d2');
  IF v->>'raison'='pas_sur_place'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    D3 un PJ reste a la caserne ne peut pas monter dans le camion parti';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] D3 -> ' || v::text; END IF;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_vince,'role','authenticated')::text, true);

  -- ================= T. IDEMPOTENCE ======================================
  v2 := public.camion_deplacer(CAM,'multimodal_ville_b',true,'k-h1');
  SELECT ville INTO cv FROM public.camions_militaires WHERE id=CAM;
  SELECT pa INTO pa_ap FROM public.personnages_donnees WHERE name='Vince Kubrick';
  SELECT count(*) INTO n FROM public.pnj_membres
   WHERE leader_pj='Vince Kubrick' AND famille='soldat' AND pa=10;
  IF (v2->>'rejeu')::boolean AND cv='capitale' AND pa_ap=pa_av-2 AND n=24
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    U  rejeu de la meme cle : aucun second debit, aucun second deplacement';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] U  -> ' || v2::text || ' ville=' || cv; END IF;

  -- ================= Y. LA DESTINATION COURANTE N'EST PAS PROPOSEE =======
  IF NOT EXISTS (SELECT 1 FROM public.camion_destinations(CAM) d WHERE d.cle='multimodal_capitale')
     AND EXISTS (SELECT 1 FROM public.camion_destinations(CAM) d WHERE d.cle='__caserne__')
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    Y1 Luthecia retiree des destinations, caserne de rattachement proposee';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] Y1 destinations incorrectes'; END IF;

  -- ================= N. DESCENTE APRES UN TRAJET =========================
  v := public.camion_descendre(CAM);
  SELECT current_city,current_building,current_room INTO pv,pb,pr
    FROM public.personnages_donnees WHERE name='Vince Kubrick';
  IF (v->>'ok')::boolean AND pv='capitale'
     AND pb='centre-multinodal-luthecia' AND pr='hall_gare'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    P2 descente a l''arrivee : hall du centre multimodal de Luthecia';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] P2 -> ' || v::text; END IF;

  -- ================= K. UN OPPORTUNISTE SANS PA EST DEBARQUE =============
  UPDATE public.pnj_membres SET leader_pj=NULL, ville='caserne',
         building_id='caserne-militaire', room_id='corps_garde' WHERE id = ANY(libere);
  UPDATE public.personnages_donnees SET current_city='capitale',
         current_building='centre-multinodal-luthecia', current_room='hall_gare', pa=1
   WHERE name='Marsault';
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_mars,'role','authenticated')::text, true);
  PERFORM public.camion_monter(CAM,'k-k1');
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_vince,'role','authenticated')::text, true);
  PERFORM public.camion_monter(CAM,'k-k2');
  SELECT pa INTO pa_av FROM public.personnages_donnees WHERE name='Vince Kubrick';
  v := public.camion_deplacer(CAM,'multimodal_ville_b',true,'k-k3');
  SELECT ville INTO cv FROM public.camions_militaires WHERE id=CAM;
  SELECT current_building,current_room,pa INTO pb,pr,pp
    FROM public.personnages_donnees WHERE name='Marsault';
  SELECT pa INTO pa_ap FROM public.personnages_donnees WHERE name='Vince Kubrick';
  IF (v->>'ok')::boolean AND cv='ville_b' AND pp=1
     AND pb='centre-multinodal-luthecia' AND pr='hall_gare'
     AND pa_ap=pa_av-2 AND (v->'debarques')::text LIKE '%Marsault%'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    O  Marsault (1 PA) est debarque et reste sur place ; le trajet a lieu quand meme';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] O  -> ' || v::text || ' marsault=' || coalesce(pr,'?') || '/' || pp; END IF;

  -- ================= E2. IL A QUITTE LUTHECIA POUR MONTROUGE =============
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);
  v  := public.camions_ici('republic','capitale','centre-multinodal-luthecia','hall_gare');
  v2 := public.camions_ici('republic','ville_b','centre-multinodal-montrouge','hall_gare_montrouge');
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v->'camions') e WHERE e->>'id'=CAM)
     AND EXISTS (SELECT 1 FROM jsonb_array_elements(v2->'camions') e WHERE e->>'id'=CAM)
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    E  second trajet : disparu de Luthecia, apparu a Montrouge';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] E  -> luthecia=' || v::text || ' montrouge=' || v2::text; END IF;
  -- Et nulle part ailleurs : un camion n'est jamais dans deux villes.
  SELECT count(*) INTO n FROM public.camions_destinations d
   WHERE d.pays='republic'
     AND EXISTS (SELECT 1 FROM jsonb_array_elements(
           public.camions_ici('republic', d.ville, d.building_id, d.room_id)->'camions') e
          WHERE e->>'id'=CAM);
  IF n=1
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    E3 balayage des 4 destinations : le camion n''apparait qu''a UNE seule';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] E3 camion visible dans ' || n || ' lieux'; END IF;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_vince,'role','authenticated')::text, true);

  -- ================= Z. LIEUTENANT : A VIDE, SEULEMENT SA CASERNE ========
  v := public.camion_deplacer(CAM,'multimodal_capitale',false,'k-z1');
  IF v->>'raison'='envoi_a_vide_hors_caserne'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    Y2 un Lieutenant ne renvoie le camion qu''a sa caserne de rattachement';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] Y2 -> ' || v::text; END IF;

  -- ================= P/Q. RETOUR A VIDE AVEC UN PASSAGER A BORD ==========
  UPDATE public.personnages_donnees SET current_city='ville_b',
         current_building='centre-multinodal-montrouge', current_room='hall_gare_montrouge', pa=10
   WHERE name='Phileas Frogg';
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_phil,'role','authenticated')::text, true);
  PERFORM public.camion_monter(CAM,'k-p1');
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_vince,'role','authenticated')::text, true);
  SELECT pa INTO pa_av FROM public.personnages_donnees WHERE name='Vince Kubrick';
  v := public.camion_deplacer(CAM,'__caserne__',false,'k-p2');
  SELECT ville INTO cv FROM public.camions_militaires WHERE id=CAM;
  SELECT current_city,current_building,current_room,pa INTO pv,pb,pr,pp
    FROM public.personnages_donnees WHERE name='Vince Kubrick';
  SELECT current_city,current_building,current_room,pa INTO qv,qb,qr,qp
    FROM public.personnages_donnees WHERE name='Phileas Frogg';
  SELECT count(*) INTO n FROM public.pnj_membres
   WHERE leader_pj='Vince Kubrick' AND famille='soldat' AND ville IS NULL;
  IF (v->>'ok')::boolean AND cv='caserne' AND pp=pa_av
     AND pb='centre-multinodal-montrouge' AND pr='hall_gare_montrouge'
     AND n=20 AND qb=BAT AND qr=CAM AND qv='caserne' AND qp=8
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    Q/R retour a vide : Vince reste a Montrouge avec ses 20 soldats (0 PA), le camion rentre avec Phileas (-2 PA)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] Q  -> ' || v::text || ' vince=' || coalesce(pr,'?') || '/' || pp
                       || ' phileas=' || coalesce(qr,'?') || '/' || coalesce(qv,'?') || '/' || qp || ' soldats=' || n; END IF;

  -- ================= AD. UN CIVIL NE FORCE PAS UN CAMION PLEIN ===========
  UPDATE public.camions_militaires SET capacite=1 WHERE id=CAM;
  UPDATE public.personnages_donnees SET current_city='caserne',
         current_building='caserne-militaire', current_room='corps_garde', pa=10
   WHERE name='Marsault';
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_mars,'role','authenticated')::text, true);
  v := public.camion_monter(CAM,'k-ad1');
  IF v->>'raison'='camion_complet'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    I2 un civil ne monte pas dans un camion plein (camion_complet)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] I2 -> ' || v::text; END IF;
  UPDATE public.camions_militaires SET capacite=25 WHERE id=CAM;

  -- ================= AA. AUCUN ORDRE A DISTANCE ==========================
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_zz,'role','authenticated')::text, true);
  v := public.camion_deplacer(CAM,'multimodal_capitale',false,'k-aa1');
  IF v->>'raison'='officier_absent_du_camion'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    T1 aucun ordre a distance : il faut etre physiquement dans le camion';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] T1 -> ' || v::text; END IF;

  -- ================= R/S. ENVOI A VIDE PAR LE CAPITAINE ==================
  PERFORM public.camion_monter(CAM,'k-r1');
  SELECT pa INTO pa_av FROM public.personnages_donnees WHERE name='zzAut';
  v := public.camion_deplacer(CAM,'multimodal_ville_b',false,'k-r2');
  SELECT ville INTO cv FROM public.camions_militaires WHERE id=CAM;
  SELECT current_building,current_room,pa INTO pb,pr,pp
    FROM public.personnages_donnees WHERE name='zzAut';
  SELECT current_city,current_building,current_room,pa INTO qv,qb,qr,qp
    FROM public.personnages_donnees WHERE name='Phileas Frogg';
  IF (v->>'ok')::boolean AND cv='ville_b' AND pp=pa_av
     AND pb='caserne-militaire' AND pr='corps_garde'
     AND qb=BAT AND qr=CAM AND qv='ville_b' AND qp=6
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    S  le Capitaine envoie le camion a vide : il reste, Phileas voyage et paie 2 PA';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] S  -> ' || v::text || ' zz=' || coalesce(pr,'?') || '/' || pp
                       || ' phileas=' || coalesce(qr,'?') || '/' || coalesce(qv,'?') || '/' || qp; END IF;

  -- ================= AB. MONTER SANS ETRE SUR PLACE ======================
  v := public.camion_monter(CAM,'k-ab2');
  IF v->>'raison'='pas_sur_place'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    T2 on ne monte pas dans un camion stationne ailleurs';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] T2 -> ' || v::text; END IF;

  -- ================= V. LE PASSAGER A BIEN SUIVI LE CAMION ===============
  IF qv = cv
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    R2 la ville du passager suit celle du camion (' || cv || ')';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] R2 passager=' || coalesce(qv,'?') || ' camion=' || cv; END IF;

  -- ================= X. AUCUNE DEPENSE EN ARGENT =========================
  SELECT sum(arg)+sum(liquide) INTO arg1 FROM public.personnages_donnees
   WHERE name IN ('Vince Kubrick','Arnie','Marsault','Phileas Frogg','zzAut');
  IF arg1 = arg0
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    W  pas un franc depense ni encaisse (' || arg0 || ')';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] W  ' || arg0 || ' -> ' || arg1; END IF;

  RAISE EXCEPTION E'\n===== BANC CAMION MILITAIRE =====%\n\n  %/% reussis, % echec(s).\n(transaction annulee, aucun residu)',
    R, n_ok, n_ok+n_ko, n_ko;
END $banc$;
