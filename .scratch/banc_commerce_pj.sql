-- =====================================================================
-- BANC DU MOTEUR COMMERCIAL PJ — C0, C1, C2, C3
-- =====================================================================
-- Un bloc par lot, chacun independant. Les lots suivants ajoutent leur bloc a la
-- suite ; le nom du fichier ne suit deliberement pas les numeros de lot.
-- REJOUABLE A VOLONTE, SANS AUCUN RESIDU. Chaque bloc construit sa propre
-- fixture, joue ses cas, puis leve une exception : la transaction est annulee
-- INTEGRALEMENT, fixture comprise. Les resultats arrivent dans le message
-- d'erreur -- c'est volontaire, c'est ce qui garantit le rollback.
--
-- A executer via le workflow technique habituel (jamais demande a l'utilisateur).
-- Les deux blocs utilisent le personnage de test `zzAut` comme acheteur et
-- `Arnie` comme tiers ; ils ne sont jamais modifies durablement.
--
-- ATTENDUS, tels que constates le 28 septembre 2026 :
--   C0  T1  achat de 3 souvenirs : argent 300 -> 180, sas +3, caisse 120, stock 2
--       T2  REJEU de la meme cle : rien ne bouge, ok:true rejeu:true
--       T3  objet construit par le serveur, fiche resolue, aucun_effet:true
--       T4  achat empilable : une seule ligne, stackable/stackKey/qty
--       T5  reference_sans_generique      T6  generique_est_un_service
--       T7  generique_regime_indetermine  T8  variante_incoherente
--       T9  requete_invalide             T10  quantite_invalide
--      T11  fonds_absent                 T12  quantite bornee par les fonds
--   C3  recettes systeme du generique souvenir (3, toutes {metal:1} pa=1 rendement=6)
--       T1-T2   creation avec recette, deux recettes du MEME generique
--       T3-T6   recette omise (obligatoire), hors generique, inexistante,
--               generique sans recette
--       T7      cout de revient (1x15 + 1x50)/6 = 10,8333, plafond 44
--       T8      PRODUCTION : metal 10->9, stock 0->6, PA 10->9, CMUP INCHANGE
--       T9      REJEU : rien ne bouge
--       T10     stocks INDEPENDANTS entre deux references du meme generique
--       T11-T15 refus : non-proprietaire, PNJ, reference absente, autre fonds,
--               cle mal formee
--       T16     PA insuffisants -> AUCUN debit matiere
--       T17     matieres insuffisantes -> AUCUN debit PA
--       T18     cout matiere inconnu -> refus, JAMAIS zero
--       T19-T21 prix au plafond, plafond+1 refuse, activation
--       T22     coefficient par pays    T23  fiche L2 coherente
--   C2  T1-T3   creation, multi-type, deux references sur le meme generique
--       T4-T10  refus : hors perimetre, inexistant, non-proprietaire, PNJ,
--               nom absent, nom > 80, description > 400
--       T11-T12 modification de l'habillage, generique_id inchange ; tiers refuse
--       T13-T15 AUCUN cout calculable en base : prix et activation refuses
--       T16-T19 cout rendu calculable : (1x15 + 1x50)/6 = 10,8333, plafond 44 ;
--               44 accepte, 45 refuse, 0 refuse
--       T20     deux recettes pour un generique -> ambigu, aucun choix arbitraire
--       T21-T22 activation puis desactivation, reference CONSERVEE
--       T23-T25 coefficient par pays : republic 4, soviet et khalija NULL
--       T26     fiche officielle coherente, le nom RP ne cree aucun effet
--   C1  vocations : les 3 centres resolvent, tout le reste rend NULL
--       T1  creation sur local commercial : references={}, typesAutorises=[], pas de famille
--       T2  creation sur suite d'hotel : local_non_commercial
--       T3  1 type   T4  2 types (plafond)   T5  3 types -> trop_de_types
--       T6  type_inconnu   T7  doublons normalises   T8  pas_proprietaire
--       T9  etablissement PNJ legacy -> pas_un_fonds_pj (le legacy est protege)
--      T10  cascade DERIVEE type -> famille -> generique, sans table de jointure

-- ---------------------------------------------------------------------------
-- BLOC 1 — C0 : ACHAT SECURISE
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r jsonb; rap text := E'\n';
  v_svc text; a0 numeric; a1 numeric; a2 numeric; s1 int; s2 int;
  v_caisse numeric; v_stock numeric; v_data jsonb; v_fiche jsonb; v_brut text;
BEGIN
  SELECT id INTO v_svc FROM public.catalogue_generiques WHERE est_service ORDER BY id LIMIT 1;
  -- C2 a sorti le stock de la reference : il vit dans data.stockReferences, et la
  -- reference redevient un pur modele commercial.
  INSERT INTO public.entreprises (id, data) VALUES ('zztest-c0-fonds', jsonb_build_object(
    'version', 2, 'type', 'fonds_commerce', 'statut', 'actif',
    'proprietaire', 'pj:Arnie', 'enseigne', 'Boutique de test C0', 'caisse', 0,
    'stockReferences', jsonb_build_object(
      'ref-souvenir', 5, 'ref-sans-gen', 5, 'ref-service', 5,
      'ref-sans-reg', 5, 'ref-empil', 9, 'ref-var-faux', 5),
    'references', jsonb_build_object(
      'ref-souvenir', jsonb_build_object('active', true, 'prixVente', 40,
                        'generique_id','souvenir','nom','Figurine du Palais','description','Une babiole.'),
      'ref-sans-gen', jsonb_build_object('active', true, 'prixVente', 10),
      'ref-service',  jsonb_build_object('active', true, 'prixVente', 10, 'generique_id', v_svc),
      'ref-sans-reg', jsonb_build_object('active', true, 'prixVente', 10, 'generique_id','boisson'),
      'ref-empil',    jsonb_build_object('active', true, 'prixVente', 5, 'generique_id','aliment-brut','nom','Cereales du Nord'),
      'ref-var-faux', jsonb_build_object('active', true, 'prixVente', 10,
                        'generique_id','souvenir','variante_id','appareil-de-communication--militaire')
    )));
  SELECT arg INTO a0 FROM public.personnages_donnees WHERE name='zzAut';
  SELECT count(*) INTO s1 FROM public.objets_recus;

  r := public.acheter_produit_commerce('achat-c0test-001','zzAut','zztest-c0-fonds','ref-souvenir',3);
  SELECT arg INTO a1 FROM public.personnages_donnees WHERE name='zzAut';
  SELECT count(*) INTO s2 FROM public.objets_recus;
  SELECT (data::jsonb->>'caisse')::numeric, (data::jsonb->'stockReferences'->>'ref-souvenir')::numeric
    INTO v_caisse, v_stock FROM public.entreprises WHERE id='zztest-c0-fonds';
  rap := rap || 'T1 achat nominal (3 individualises) : ' || r::text || E'\n'
             || '   argent ' || a0 || ' -> ' || a1 || '  sas +' || (s2-s1)
             || '  caisse ' || v_caisse || '  stock ' || v_stock || E'\n';

  r := public.acheter_produit_commerce('achat-c0test-001','zzAut','zztest-c0-fonds','ref-souvenir',3);
  SELECT arg INTO a2 FROM public.personnages_donnees WHERE name='zzAut';
  SELECT (data::jsonb->>'caisse')::numeric, (data::jsonb->'stockReferences'->>'ref-souvenir')::numeric
    INTO v_caisse, v_stock FROM public.entreprises WHERE id='zztest-c0-fonds';
  rap := rap || 'T2 REJEU meme cle                   : ' || r::text || E'\n'
             || '   argent inchange=' || (a2=a1) || '  caisse inchangee=' || (v_caisse=120)
             || '  stock inchange=' || (v_stock=2)
             || '  sas inchange=' || (s2=(SELECT count(*) FROM public.objets_recus)) || E'\n';

  SELECT data#>>'{}' INTO v_brut FROM public.objets_recus WHERE id='achat-c0test-001-1';
  v_data := v_brut::jsonb;
  v_fiche := public.objet_fiche_officielle(v_data);
  rap := rap || 'T3 objet construit par le SERVEUR   : name=' || (v_data->>'name')
             || '  generique_id=' || (v_data->>'generique_id')
             || '  qty=' || (v_data->>'qty')
             || '  exemplaire=' || (v_data->'exemplaire'->>'id')
             || '  legal=' || (v_data->>'legal') || E'\n'
             || '   data est une chaine JSON ? ' || (jsonb_typeof((SELECT data FROM public.objets_recus WHERE id='achat-c0test-001-1'))='string') || E'\n'
             || '   fiche: resolu=' || (v_fiche->>'resolu') || ' generique=' || (v_fiche->>'generique')
             || ' famille=' || (v_fiche->>'famille') || ' aucun_effet=' || (v_fiche->>'aucun_effet') || E'\n';

  r := public.acheter_produit_commerce('achat-c0test-002','zzAut','zztest-c0-fonds','ref-empil',4);
  SELECT data#>>'{}' INTO v_brut FROM public.objets_recus WHERE id='achat-c0test-002';
  rap := rap || 'T4 achat empilable (4)              : ' || r::text || E'\n'
             || '   objet: stackable=' || (v_brut::jsonb->>'stackable') || ' stackKey=' || (v_brut::jsonb->>'stackKey')
             || ' qty=' || (v_brut::jsonb->>'qty') || E'\n';

  rap := rap || 'T5 reference sans generique         : ' || public.acheter_produit_commerce('achat-c0test-005','zzAut','zztest-c0-fonds','ref-sans-gen',1)::text || E'\n';
  rap := rap || 'T6 generique est un service         : ' || public.acheter_produit_commerce('achat-c0test-006','zzAut','zztest-c0-fonds','ref-service',1)::text || E'\n';
  rap := rap || 'T7 regime indetermine (boisson)     : ' || public.acheter_produit_commerce('achat-c0test-007','zzAut','zztest-c0-fonds','ref-sans-reg',1)::text || E'\n';
  rap := rap || 'T8 variante incoherente             : ' || public.acheter_produit_commerce('achat-c0test-008','zzAut','zztest-c0-fonds','ref-var-faux',1)::text || E'\n';
  rap := rap || 'T9 cle de requete mal formee        : ' || public.acheter_produit_commerce('pas-une-cle','zzAut','zztest-c0-fonds','ref-souvenir',1)::text || E'\n';
  rap := rap || 'T10 quantite nulle                  : ' || public.acheter_produit_commerce('achat-c0test-010','zzAut','zztest-c0-fonds','ref-souvenir',0)::text || E'\n';
  rap := rap || 'T11 fonds inexistant                : ' || public.acheter_produit_commerce('achat-c0test-011','zzAut','zztest-absent','ref-souvenir',1)::text || E'\n';
  rap := rap || 'T12 quantite bornee par les fonds   : ' || public.acheter_produit_commerce('achat-c0test-012','zzAut','zztest-c0-fonds','ref-souvenir',99)::text || E'\n';

  RAISE EXCEPTION 'BANC C0 -- transaction annulee, aucun residu %', rap;
END $$;

-- ---------------------------------------------------------------------------
-- BLOC 2 — C1 : LOCAL EXISTANT, FONDS, TYPES L2
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r jsonb; rap text := E'\n'; v_data jsonb; n int;
BEGIN
  rap := rap || 'VOCATIONS DERIVEES' || E'\n';
  FOR r IN SELECT jsonb_build_object('b', b, 'v', coalesce(public.local_vocation_commerciale(b),'(aucune)'))
             FROM unnest(ARRAY['centre-commercial','centre-artisanal','centre-affaires',
                               'hotel-republica','banque-nationale','centre-culturel',
                               'immeuble-montrouge','terrain-a-batir-1']) b LOOP
    rap := rap || '   ' || rpad(r->>'b', 22) || ' -> ' || (r->>'v') || E'\n';
  END LOOP;

  INSERT INTO public.locations_actives (id, country, data) VALUES (
    'republic:centre-commercial:vitrine_principale:capitale', 'republic',
    jsonb_build_object('buildingId','centre-commercial','roomId','vitrine_principale',
      'locataire','zzAut','country','republic','city','capitale','lotId',null,
      'localKey','republic|capitale|centre-commercial|vitrine_principale','prix',800));
  INSERT INTO public.locations_actives (id, country, data) VALUES (
    'republic:hotel-republica:suite_privee:capitale', 'republic',
    jsonb_build_object('buildingId','hotel-republica','roomId','suite_privee',
      'locataire','zzAut','country','republic','city','capitale','lotId',null,'prix',500));

  r := public.creer_fonds_commerce('zzAut','republic:centre-commercial:vitrine_principale:capitale','zztest-c1-fonds',0,'Manga Paradise');
  rap := rap || E'\nT1 creation sur local commercial : ' || r::text || E'\n';
  SELECT data INTO v_data FROM public.entreprises WHERE id='zztest-c1-fonds';
  rap := rap || '   version=' || (v_data->>'version') || ' vocation=' || (v_data->'implantation'->>'vocation')
             || ' references=' || (v_data->'references')::text || ' typesAutorises=' || (v_data->'typesAutorises')::text
             || ' famille=' || coalesce(v_data->>'famille','(absente, voulu)') || E'\n';

  r := public.creer_fonds_commerce('zzAut','republic:hotel-republica:suite_privee:capitale','zztest-c1-suite',0,'Boutique illegitime');
  rap := rap || 'T2 creation sur suite d hotel    : ' || r::text || E'\n';

  rap := rap || 'T3 un seul type                  : ' || public.fonds_definir_types('zzAut','zztest-c1-fonds', ARRAY['arts-culture'])::text || E'\n';
  rap := rap || 'T4 deux types (plafond)          : ' || public.fonds_definir_types('zzAut','zztest-c1-fonds', ARRAY['vetements','arts-culture'])::text || E'\n';
  rap := rap || 'T5 trois types (au dela)         : ' || public.fonds_definir_types('zzAut','zztest-c1-fonds', ARRAY['vetements','arts-culture','pharmacie'])::text || E'\n';
  rap := rap || 'T6 type inconnu                  : ' || public.fonds_definir_types('zzAut','zztest-c1-fonds', ARRAY['boulangerie-imaginaire'])::text || E'\n';
  rap := rap || 'T7 doublons normalises           : ' || public.fonds_definir_types('zzAut','zztest-c1-fonds', ARRAY['vetements','vetements','arts-culture'])::text || E'\n';
  rap := rap || 'T8 pas le proprietaire           : ' || public.fonds_definir_types('Arnie','zztest-c1-fonds', ARRAY['vetements'])::text || E'\n';
  rap := rap || 'T9 etablissement legacy (PNJ)    : ' || public.fonds_definir_types('zzAut','armurerie-republic-capitale', ARRAY['armurerie'])::text || E'\n';

  SELECT data INTO v_data FROM public.entreprises WHERE id='zztest-c1-fonds';
  rap := rap || E'\nT10 cascade derivee pour ' || (v_data->'typesAutorises')::text || E'\n';
  FOR r IN SELECT jsonb_build_object('f', f.libelle, 'n', count(*))
             FROM public.catalogue_generique_type gt
             JOIN public.catalogue_generiques g ON g.id = gt.generique_id
             JOIN public.catalogue_familles f ON f.id = g.famille_id
            WHERE gt.type_id IN (SELECT jsonb_array_elements_text(v_data->'typesAutorises'))
            GROUP BY f.libelle ORDER BY f.libelle LOOP
    rap := rap || '   famille ' || rpad(r->>'f', 28) || ' ' || (r->>'n') || ' generique(s)' || E'\n';
  END LOOP;

  RAISE EXCEPTION 'BANC C1 -- transaction annulee, aucun residu %', rap;
END $$;

-- ---------------------------------------------------------------------------
-- BLOC 3 — C2 : REFERENCES COMMERCIALES
-- ---------------------------------------------------------------------------
-- Les deux derniers tiers du bloc RENDENT LE COUT CALCULABLE comme C3 le fera
-- (raccordement recettes_commerce.generique_id + cout moyen d'une matiere), pour
-- prouver que le plafond x4 fonctionne. Ces deux ecritures sont annulees avec le
-- reste : en base, aucune recette n'est raccordee a un generique.
DO $$
DECLARE
  r jsonb; rap text := E'\n'; v_data jsonb; v_ref1 text; v_ref2 text; v_ref3 text;
  n int; v_c jsonb; v_types text[];
BEGIN
  INSERT INTO public.locations_actives (id, country, data) VALUES (
    'republic:centre-commercial:vitrine_principale:capitale', 'republic',
    jsonb_build_object('buildingId','centre-commercial','roomId','vitrine_principale',
      'locataire','zzAut','country','republic','city','capitale','lotId',null,
      'localKey','republic|capitale|centre-commercial|vitrine_principale','prix',800));
  r := public.creer_fonds_commerce('zzAut','republic:centre-commercial:vitrine_principale:capitale','zztest-c2',0,'Manga Paradise');
  PERFORM public.fonds_definir_types('zzAut','zztest-c2', ARRAY['commerce-non-alimentaire','sport-loisirs']);
  SELECT data INTO v_data FROM public.entreprises WHERE id='zztest-c2';
  rap := rap || 'FIXTURE : typesAutorises=' || (v_data->'typesAutorises')::text
             || '  stockReferences=' || (v_data->'stockReferences')::text || E'\n';

  SELECT g.types INTO v_types FROM public.fonds_generiques_accessibles('zztest-c2') g WHERE g.generique_id='article-de-supporter';
  SELECT count(*) INTO n FROM public.fonds_generiques_accessibles('zztest-c2') g WHERE g.generique_id='article-de-supporter';
  rap := rap || 'MULTI-TYPE : article-de-supporter apparait ' || n || ' fois (attendu 1), atteignable par '
             || array_to_string(v_types, ' + ') || E'\n';
  SELECT count(*) INTO n FROM public.fonds_generiques_accessibles('zztest-c2');
  rap := rap || 'generiques accessibles derives : ' || n || E'\n\n';

  r := public.fonds_reference_creer('zzAut','zztest-c2','souvenir','porte_cle_palais_luthecia','Miniature du Palais présidentiel','Un petit palais de plomb, peint à la main.');
  v_ref1 := r->>'referenceId';
  rap := rap || 'T1  creation (Souvenir)          : ' || r::text || E'\n';
  r := public.fonds_reference_creer('zzAut','zztest-c2','article-de-supporter',null,'Écharpe des Lions','Aux couleurs du club.');
  v_ref2 := r->>'referenceId';
  rap := rap || 'T2  creation (multi-type)        : ok=' || (r->>'ok') || ' generique=' || (r->>'generique') || E'\n';
  r := public.fonds_reference_creer('zzAut','zztest-c2','souvenir','garde_republien_plomb','Deuxième souvenir','Autre.');
  v_ref3 := r->>'referenceId';
  rap := rap || 'T3  2 refs, MEME generique       : ok=' || (r->>'ok') || '  ids distincts=' || (v_ref1 <> v_ref3) || E'\n';
  rap := rap || 'T4  generique hors perimetre     : ' || public.fonds_reference_creer('zzAut','zztest-c2','arme-de-poing',null,'Pistolet','x')::text || E'\n';
  rap := rap || 'T5  generique inexistant         : ' || public.fonds_reference_creer('zzAut','zztest-c2','zzz-inexistant',null,'X','y')::text || E'\n';
  rap := rap || 'T6  non-proprietaire             : ' || public.fonds_reference_creer('Arnie','zztest-c2','souvenir','porte_cle_palais_luthecia','Pirate','x')::text || E'\n';
  rap := rap || 'T7  etablissement PNJ            : ' || public.fonds_reference_creer('zzAut','armurerie-republic-capitale','souvenir','porte_cle_palais_luthecia','X','y')::text || E'\n';
  rap := rap || 'T8  nom absent                   : ' || public.fonds_reference_creer('zzAut','zztest-c2','souvenir','porte_cle_palais_luthecia','   ','x')::text || E'\n';
  rap := rap || 'T9  nom > 80                     : ' || public.fonds_reference_creer('zzAut','zztest-c2','souvenir','porte_cle_palais_luthecia', repeat('a',81),'x')::text || E'\n';
  rap := rap || 'T10 description > 400            : ' || public.fonds_reference_creer('zzAut','zztest-c2','souvenir','porte_cle_palais_luthecia','Ok', repeat('b',401))::text || E'\n';

  r := public.fonds_reference_modifier('zzAut','zztest-c2',v_ref1,'Miniature du Palais (édition 1954)',null);
  rap := rap || 'T11 modif nom                    : ok=' || (r->>'ok') || ' nom=' || (r->>'nom')
             || '  generique_id inchange=' || ((r->>'generique_id')='souvenir') || E'\n';
  rap := rap || 'T12 modif par un tiers           : ' || public.fonds_reference_modifier('Arnie','zztest-c2',v_ref1,'Vol','x')::text || E'\n';

  v_c := public.fonds_cout_revient_reference('zztest-c2',v_ref1);
  rap := rap || E'\nT13 cout indisponible (matiere)  : ' || v_c::text || E'\n';
  rap := rap || 'T14 prix refuse faute de cout    : ' || public.fonds_reference_prix('zzAut','zztest-c2',v_ref1,30)::text || E'\n';
  rap := rap || 'T15 activation sans prix         : ' || public.fonds_reference_activer('zzAut','zztest-c2',v_ref1,true)::text || E'\n';

  UPDATE public.entreprises SET data = jsonb_set(data,'{coutMoyenMatieres}', jsonb_build_object('metal',15)) WHERE id='zztest-c2';
  v_c := public.fonds_cout_revient_reference('zztest-c2',v_ref1);
  rap := rap || E'\nT16 cout calculable (metal 15)   : ' || v_c::text || E'\n'
             || '    controle : (1x15 + 1x50)/6 = ' || round((15+50)::numeric/6, 4)
             || '   ceil(x4) = ' || ceil((15+50)::numeric/6*4) || E'\n';
  rap := rap || 'T17 prix AU plafond              : ' || public.fonds_reference_prix('zzAut','zztest-c2',v_ref1, (v_c->>'prixMaximum')::int)::text || E'\n';
  rap := rap || 'T18 prix AU-DESSUS du plafond    : ' || public.fonds_reference_prix('zzAut','zztest-c2',v_ref1, (v_c->>'prixMaximum')::int + 1)::text || E'\n';
  rap := rap || 'T19 prix nul                     : ' || public.fonds_reference_prix('zzAut','zztest-c2',v_ref1, 0)::text || E'\n';

  rap := rap || 'T20 ambiguite de recette : IMPOSSIBLE par construction depuis C3 -- la reference nomme sa recette.' || E'\n';

  rap := rap || E'\nT21 activation avec prix         : ' || public.fonds_reference_activer('zzAut','zztest-c2',v_ref1,true)::text || E'\n';
  rap := rap || 'T22 desactivation                : ' || public.fonds_reference_activer('zzAut','zztest-c2',v_ref1,false)::text || E'\n';
  SELECT data INTO v_data FROM public.entreprises WHERE id='zztest-c2';
  rap := rap || '    reference CONSERVEE : ' || ((v_data->'references'->v_ref1) IS NOT NULL)
             || '   nom toujours present : ' || (v_data->'references'->v_ref1->>'nom') || E'\n';

  rap := rap || E'\nT23 coef republic  : ' || coalesce(public.coef_prix_max_pj('republic')::text,'NULL') || E'\n';
  rap := rap || 'T24 coef soviet    : ' || coalesce(public.coef_prix_max_pj('soviet')::text,'NULL (aucun arbitrage)') || E'\n';
  rap := rap || 'T25 coef khalija   : ' || coalesce(public.coef_prix_max_pj('khalija')::text,'NULL (aucun arbitrage)') || E'\n';

  v_c := public.objet_fiche_officielle(jsonb_build_object('type', v_ref1, 'generique_id', 'souvenir'));
  rap := rap || E'\nT26 fiche officielle : resolu=' || (v_c->>'resolu') || ' generique=' || (v_c->>'generique')
             || ' famille=' || (v_c->>'famille') || ' types=' || (v_c->'types')::text
             || ' aucun_effet=' || (v_c->>'aucun_effet') || E'\n'
             || '    nom RP = "' || (v_data->'references'->v_ref1->>'nom')
             || '"   effets systeme = ' || coalesce((v_c->'effets')::text,'aucun') || E'\n';

  rap := rap || E'\nSTRUCTURE D UNE REFERENCE : ' || (v_data->'references'->v_ref1)::text || E'\n';
  RAISE EXCEPTION 'BANC C2 -- transaction annulee, aucun residu %', rap;
END $$;

-- ---------------------------------------------------------------------------
-- BLOC 4 — C3 : RECETTE SYSTEME, PRODUCTION, STOCK DE LA REFERENCE
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r jsonb; rap text := E'\n'; d jsonb; refA text; refB text;
  pa0 int; c jsonb; sm jsonb;
BEGIN
  INSERT INTO public.locations_actives (id, country, data) VALUES (
    'republic:centre-commercial:vitrine_principale:capitale','republic',
    jsonb_build_object('buildingId','centre-commercial','roomId','vitrine_principale',
      'locataire','zzAut','country','republic','city','capitale','lotId',null,'prix',800));
  INSERT INTO public.locations_actives (id, country, data) VALUES (
    'republic:centre-commercial:boutique_milieu:capitale','republic',
    jsonb_build_object('buildingId','centre-commercial','roomId','boutique_milieu',
      'locataire','Arnie','country','republic','city','capitale','lotId',null,'prix',400));
  PERFORM public.creer_fonds_commerce('zzAut','republic:centre-commercial:vitrine_principale:capitale','zztest-c3',0,'Souvenirs Marcel');
  PERFORM public.creer_fonds_commerce('Arnie','republic:centre-commercial:boutique_milieu:capitale','zztest-c3-autre',0,'Autre boutique');
  PERFORM public.fonds_definir_types('zzAut','zztest-c3', ARRAY['commerce-non-alimentaire']);
  PERFORM public.fonds_definir_types('Arnie','zztest-c3-autre', ARRAY['commerce-non-alimentaire']);
  UPDATE public.entreprises SET data = data
    || jsonb_build_object('stockMatieres', jsonb_build_object('metal', 10))
    || jsonb_build_object('coutMoyenMatieres', jsonb_build_object('metal', 15))
    WHERE id = 'zztest-c3';
  UPDATE public.personnages_donnees SET pa = 10 WHERE name='zzAut';
  SELECT pa INTO pa0 FROM public.personnages_donnees WHERE name='zzAut';

  rap := rap || 'RECETTES SYSTEME DU GENERIQUE souvenir' || E'\n';
  FOR r IN SELECT jsonb_build_object('i', recette_id, 'pa', pa, 'p', portions, 'm', materiaux)
             FROM public.generique_recettes_systeme('souvenir') LOOP
    rap := rap || '   ' || (r->>'i') || '  pa=' || (r->>'pa') || ' rendement=' || (r->>'p')
               || ' matieres=' || (r->'m')::text || E'\n';
  END LOOP;

  r := public.fonds_reference_creer('zzAut','zztest-c3','souvenir','porte_cle_palais_luthecia','Porte-clé présidentiel Collector 2026','Édition limitée.');
  refA := r->>'referenceId';
  rap := rap || E'\nT1  creation avec recette        : ok=' || (r->>'ok') || ' generique=' || (r->>'generique_id')
             || ' recette=' || (r->>'recette_id') || E'\n';
  r := public.fonds_reference_creer('zzAut','zztest-c3','souvenir','garde_republien_plomb','Le Garde de Marcel','Un garde en plomb.');
  refB := r->>'referenceId';
  rap := rap || 'T2  2e recette du MEME generique : ok=' || (r->>'ok') || ' recette=' || (r->>'recette_id')
             || ' ref distincte=' || (refA <> refB) || E'\n';
  rap := rap || 'T3  recette omise (obligatoire)  : ' || left(public.fonds_reference_creer('zzAut','zztest-c3','souvenir',null,'Sans recette','x')::text, 210) || E'\n';
  rap := rap || 'T4  recette hors generique       : ' || public.fonds_reference_creer('zzAut','zztest-c3','souvenir','biere_pression','Biere','x')::text || E'\n';
  rap := rap || 'T5  recette inexistante          : ' || public.fonds_reference_creer('zzAut','zztest-c3','souvenir','zzz-recette','X','y')::text || E'\n';
  rap := rap || 'T6  generique sans recette       : ' || public.fonds_reference_creer('zzAut','zztest-c3','article-de-supporter','porte_cle_palais_luthecia','X','y')::text || E'\n';

  c := public.fonds_cout_revient_reference('zztest-c3', refA);
  rap := rap || E'\nT7  cout de revient              : ' || c::text || E'\n'
             || '    controle (1x15 + 1x50)/6 = ' || round((15+50)::numeric/6,4)
             || '  plafond ceil(x4) = ' || ceil((15+50)::numeric/6*4) || E'\n';

  r := public.fonds_reference_produire('prod-c3test-001','zzAut','zztest-c3',refA);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-c3';
  rap := rap || E'\nT8  PRODUCTION                   : ' || r::text || E'\n'
             || '    metal 10 -> ' || (d->'stockMatieres'->>'metal')
             || '   stock reference = ' || (d->'stockReferences'->>refA)
             || '   PA ' || pa0 || ' -> ' || (SELECT pa FROM public.personnages_donnees WHERE name='zzAut')
             || '   CMUP inchange = ' || ((d->'coutMoyenMatieres'->>'metal') = '15') || E'\n';

  r := public.fonds_reference_produire('prod-c3test-001','zzAut','zztest-c3',refA);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-c3';
  rap := rap || 'T9  REJEU meme cle               : ' || r::text || E'\n'
             || '    metal inchange=' || ((d->'stockMatieres'->>'metal')='9')
             || ' stock inchange=' || ((d->'stockReferences'->>refA)='6')
             || ' PA inchanges=' || ((SELECT pa FROM public.personnages_donnees WHERE name='zzAut')=9) || E'\n';

  PERFORM public.fonds_reference_produire('prod-c3test-002','zzAut','zztest-c3',refB);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-c3';
  rap := rap || 'T10 stocks INDEPENDANTS          : A=' || (d->'stockReferences'->>refA)
             || '  B=' || (d->'stockReferences'->>refB)
             || '  metal=' || (d->'stockMatieres'->>'metal') || E'\n';

  rap := rap || E'\nT11 non-proprietaire             : ' || public.fonds_reference_produire('prod-c3test-011','Arnie','zztest-c3',refA)::text || E'\n';
  rap := rap || 'T12 etablissement PNJ            : ' || public.fonds_reference_produire('prod-c3test-012','zzAut','armurerie-republic-capitale',refA)::text || E'\n';
  rap := rap || 'T13 reference inexistante        : ' || public.fonds_reference_produire('prod-c3test-013','zzAut','zztest-c3','ref-inexistante')::text || E'\n';
  rap := rap || 'T14 reference d un AUTRE fonds   : ' || public.fonds_reference_produire('prod-c3test-014','Arnie','zztest-c3-autre',refA)::text || E'\n';
  rap := rap || 'T15 cle de requete mal formee    : ' || public.fonds_reference_produire('pas-une-cle','zzAut','zztest-c3',refA)::text || E'\n';

  UPDATE public.personnages_donnees SET pa = 0 WHERE name='zzAut';
  SELECT data->'stockMatieres' INTO sm FROM public.entreprises WHERE id='zztest-c3';
  r := public.fonds_reference_produire('prod-c3test-016','zzAut','zztest-c3',refA);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-c3';
  rap := rap || E'\nT16 PA insuffisants             : ' || r::text || E'\n'
             || '    AUCUN debit matiere : ' || ((d->'stockMatieres') = sm) || E'\n';
  UPDATE public.personnages_donnees SET pa = 10 WHERE name='zzAut';

  UPDATE public.entreprises SET data = jsonb_set(data,'{stockMatieres}', jsonb_build_object('metal',0)) WHERE id='zztest-c3';
  r := public.fonds_reference_produire('prod-c3test-017','zzAut','zztest-c3',refA);
  rap := rap || 'T17 matieres insuffisantes       : ' || r::text || E'\n'
             || '    AUCUN debit PA : ' || ((SELECT pa FROM public.personnages_donnees WHERE name='zzAut')=10) || E'\n';

  UPDATE public.entreprises SET data = jsonb_set(jsonb_set(data,'{stockMatieres}', jsonb_build_object('metal',10)),
                                                 '{coutMoyenMatieres}', '{}'::jsonb) WHERE id='zztest-c3';
  rap := rap || 'T18 cout matiere INCONNU         : ' || public.fonds_reference_produire('prod-c3test-018','zzAut','zztest-c3',refA)::text || E'\n'
             || '    et cout de revient           : ' || public.fonds_cout_revient_reference('zztest-c3',refA)::text || E'\n';
  UPDATE public.entreprises SET data = jsonb_set(data,'{coutMoyenMatieres}', jsonb_build_object('metal',15)) WHERE id='zztest-c3';

  c := public.fonds_cout_revient_reference('zztest-c3', refA);
  rap := rap || E'\nT19 prix AU plafond              : ' || public.fonds_reference_prix('zzAut','zztest-c3',refA,(c->>'prixMaximum')::int)::text || E'\n';
  rap := rap || 'T20 prix plafond + 1             : ' || public.fonds_reference_prix('zzAut','zztest-c3',refA,(c->>'prixMaximum')::int + 1)::text || E'\n';
  rap := rap || 'T21 activation                   : ' || public.fonds_reference_activer('zzAut','zztest-c3',refA,true)::text || E'\n';

  rap := rap || E'\nT22 coef republic=' || coalesce(public.coef_prix_max_pj('republic')::text,'NULL')
             || '  soviet=' || coalesce(public.coef_prix_max_pj('soviet')::text,'NULL')
             || '  khalija=' || coalesce(public.coef_prix_max_pj('khalija')::text,'NULL') || E'\n';

  c := public.objet_fiche_officielle(jsonb_build_object('type',refA,'generique_id','souvenir'));
  rap := rap || 'T23 fiche L2 : resolu=' || (c->>'resolu') || ' generique=' || (c->>'generique')
             || ' aucun_effet=' || (c->>'aucun_effet') || E'\n';

  SELECT data INTO d FROM public.entreprises WHERE id='zztest-c3';
  rap := rap || E'\nREFERENCE A : ' || (d->'references'->refA)::text || E'\n';
  rap := rap || 'JOURNAL     : ' || (SELECT count(*)::text FROM public.productions_references WHERE fonds_id='zztest-c3')
             || ' lot(s), couts unitaires ' || (SELECT string_agg(round(cout_unitaire,4)::text, ' / ') FROM public.productions_references WHERE fonds_id='zztest-c3') || E'\n';

  RAISE EXCEPTION 'BANC C3 -- transaction annulee, aucun residu %', rap;
END $$;
