-- =====================================================================
-- BANC DU MOTEUR COMMERCIAL PJ — C0, C1, C2, C3, C4 (+ CMUP produit fini)
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
--   CMUP PRODUIT FINI (correctif du 28 septembre 2026)
--       T1-T3   1re production, lot plus cher, lot moins cher -> moyennes exactes
--       T4-T6   plafond Republia, prix au plafond, plafond+1
--       T7      LE POINT CENTRAL : baisse du cout MATIERE sans produire ->
--               cout du produit fini et plafond INCHANGES, vente toujours possible
--       T8      vente : la quantite baisse, le CMUP ne bouge pas
--       T9      stock a zero : la cle de cout est retiree
--       T10     production apres stock zero : le nouveau lot seul
--       T11     verification de l'exemple du cahier des charges (12 -> plafond 48)
--   C4  T1-T3   achat nominal : conservation monetaire, objet serveur, snapshot
--       T4-T5   rejeu meme cle (rien ne bouge) ; 2e cle, 2 unites
--       T6-T7   UPDATE et DELETE du snapshot REFUSES (append-only)
--       T8-T9   reference renommee et desactivee : le snapshot ne bouge pas
--       T10     nom trompeur « +50 ENT » : aucun effet, fiche figee aucun_effet
--       T11     prix devenu hors plafond apres baisse du CMUP -> refus
--       T12-T19 refus : quantites, fonds, PNJ, reference, cle, generique retire
--       T20     acheteur insolvable    T21-T22  stock=1, deux cles -> une vente
--       T23     proprietaire achete chez lui (comportement existant)
--       T24     droits : RLS active, 0 policy, aucun privilege client
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
  rap := rap || E'\nT13 cout indisponible (rien produit) : ' || v_c::text || E'\n';
  rap := rap || 'T14 prix refuse faute de cout    : ' || public.fonds_reference_prix('zzAut','zztest-c2',v_ref1,30)::text || E'\n';
  rap := rap || 'T15 activation sans prix         : ' || public.fonds_reference_activer('zzAut','zztest-c2',v_ref1,true)::text || E'\n';

  -- Le cout de reference est celui du STOCK DE PRODUITS FINIS : il faut donc
  -- produire avant de pouvoir tarifer. C'est le correctif du 28 septembre 2026.
  UPDATE public.entreprises SET data = data
    || jsonb_build_object('stockMatieres', jsonb_build_object('metal',20))
    || jsonb_build_object('coutMoyenMatieres', jsonb_build_object('metal',15)) WHERE id='zztest-c2';
  UPDATE public.personnages_donnees SET pa = 10 WHERE name='zzAut';
  PERFORM public.fonds_reference_produire('prod-c2bloc-001','zzAut','zztest-c2',v_ref1);
  v_c := public.fonds_cout_revient_reference('zztest-c2',v_ref1);
  rap := rap || E'\nT16 cout apres production        : ' || v_c::text || E'\n'
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
  rap := rap || E'\nT7  cout AVANT production        : ' || c::text || E'\n'
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
  rap := rap || E'\n    cout de reference = CMUP du produit fini = ' || (c->>'coutUnitaire') || E'\n';
  rap := rap || 'T19 prix AU plafond              : ' || public.fonds_reference_prix('zzAut','zztest-c3',refA,(c->>'prixMaximum')::int)::text || E'\n';
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

-- ---------------------------------------------------------------------------
-- BLOC 5 — C4 : ACHAT REEL ET PREUVE IMMUABLE  (partie 1)
-- ---------------------------------------------------------------------------
-- Vendeur zzAut, acheteur Arnie. Verticale Souvenir complete.
DO $$
DECLARE
  r jsonb; rap text := E'\n'; d jsonb; ref text; brut text; snap record;
  argA0 numeric; argA1 numeric; caisse0 numeric; caisse1 numeric; msg text;
BEGIN
  INSERT INTO public.locations_actives (id, country, data) VALUES (
    'republic:centre-commercial:vitrine_principale:capitale','republic',
    jsonb_build_object('buildingId','centre-commercial','roomId','vitrine_principale',
      'locataire','zzAut','country','republic','city','capitale','lotId',null,'prix',800));
  PERFORM public.creer_fonds_commerce('zzAut','republic:centre-commercial:vitrine_principale:capitale','zztest-c4',0,'Souvenirs Marcel');
  PERFORM public.fonds_definir_types('zzAut','zztest-c4', ARRAY['commerce-non-alimentaire']);
  UPDATE public.entreprises SET data = data
    || jsonb_build_object('stockMatieres', jsonb_build_object('metal',10))
    || jsonb_build_object('coutMoyenMatieres', jsonb_build_object('metal',15))
    WHERE id='zztest-c4';
  UPDATE public.personnages_donnees SET pa = 10 WHERE name='zzAut';

  r := public.fonds_reference_creer('zzAut','zztest-c4','souvenir','porte_cle_palais_luthecia','Porte-clé présidentiel Collector 2026','Édition limitée, numérotée.');
  ref := r->>'referenceId';
  PERFORM public.fonds_reference_produire('prod-c4test-001','zzAut','zztest-c4',ref);
  PERFORM public.fonds_reference_prix('zzAut','zztest-c4',ref,44);
  PERFORM public.fonds_reference_activer('zzAut','zztest-c4',ref,true);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-c4';
  SELECT arg INTO argA0 FROM public.personnages_donnees WHERE name='Arnie';
  caisse0 := (d->>'caisse')::numeric;
  rap := rap || 'ETAT INITIAL : stock=' || (d->'stockReferences'->>ref) || '  prix=44  caisse=' || caisse0
             || '  argent Arnie=' || argA0 || E'\n';

  r := public.acheter_produit_commerce('achat-c4test-001','Arnie','zztest-c4',ref,1);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-c4';
  SELECT arg INTO argA1 FROM public.personnages_donnees WHERE name='Arnie';
  caisse1 := (d->>'caisse')::numeric;
  rap := rap || E'\nT1  ACHAT NOMINAL : ' || r::text || E'\n'
             || '    Arnie ' || argA0 || ' -> ' || argA1 || '   caisse ' || caisse0 || ' -> ' || caisse1
             || '   stock ' || (d->'stockReferences'->>ref)
             || '   conservation monetaire : ' || ((argA0-argA1) = (caisse1-caisse0)) || E'\n';

  SELECT data#>>'{}' INTO brut FROM public.objets_recus WHERE id='achat-c4test-001-1';
  rap := rap || 'T2  OBJET LIVRE   : name=' || (brut::jsonb->>'name')
             || '  generique_id=' || (brut::jsonb->>'generique_id')
             || '  recette_id=' || (brut::jsonb->>'recette_id')
             || '  reference=' || (brut::jsonb->>'type') || '  qty=' || (brut::jsonb->>'qty')
             || '  lignes=' || (SELECT count(*) FROM public.objets_recus WHERE id LIKE 'achat-c4test-001%') || E'\n';

  SELECT * INTO snap FROM public.ventes_snapshots WHERE requete='achat-c4test-001';
  rap := rap || 'T3  SNAPSHOT      : nom="' || snap.nom_commercial || '"  generique=' || snap.generique_id
             || '  recette=' || snap.recette_id || '  qte=' || snap.quantite || '  pu=' || snap.prix_unitaire
             || '  total=' || snap.montant_total || '  vendeur=' || snap.vendeur || '  acheteur=' || snap.acheteur
             || '  famille=' || snap.famille || '  types=' || snap.types::text || E'\n'
             || '    fiche figee : generique=' || (snap.fiche_officielle->>'generique')
             || ' aucun_effet=' || (snap.fiche_officielle->>'aucun_effet') || E'\n';

  r := public.acheter_produit_commerce('achat-c4test-001','Arnie','zztest-c4',ref,1);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-c4';
  rap := rap || E'\nT4  REJEU meme cle : ' || r::text || E'\n'
             || '    argent inchange=' || ((SELECT arg FROM public.personnages_donnees WHERE name='Arnie')=argA1)
             || '  caisse inchangee=' || ((d->>'caisse')::numeric = caisse1)
             || '  stock inchange=' || ((d->'stockReferences'->>ref)='5')
             || '  1 snapshot=' || ((SELECT count(*) FROM public.ventes_snapshots)=1)
             || '  1 livraison=' || ((SELECT count(*) FROM public.objets_recus WHERE id LIKE 'achat-c4test-001%')=1) || E'\n';

  r := public.acheter_produit_commerce('achat-c4test-002','Arnie','zztest-c4',ref,2);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-c4';
  rap := rap || 'T5  2e cle, 2 unites : ok=' || (r->>'ok') || ' montant=' || (r->>'montant')
             || ' stock=' || (d->'stockReferences'->>ref)
             || ' snapshots=' || (SELECT count(*) FROM public.ventes_snapshots) || E'\n';

  BEGIN
    UPDATE public.ventes_snapshots SET nom_commercial = 'Falsifie' WHERE requete='achat-c4test-001';
    rap := rap || 'T6  UPDATE snapshot : ACCEPTE -- ANOMALIE' || E'\n';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS msg = MESSAGE_TEXT;
    rap := rap || E'\nT6  UPDATE snapshot : REFUSE (' || left(msg,60) || ')' || E'\n';
  END;
  BEGIN
    DELETE FROM public.ventes_snapshots WHERE requete='achat-c4test-001';
    rap := rap || 'T7  DELETE snapshot : ACCEPTE -- ANOMALIE' || E'\n';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS msg = MESSAGE_TEXT;
    rap := rap || 'T7  DELETE snapshot : REFUSE (' || left(msg,60) || ')' || E'\n';
  END;

  PERFORM public.fonds_reference_modifier('zzAut','zztest-c4',ref,'Jus de betterave parfaitement ordinaire','Rien de special.');
  PERFORM public.fonds_reference_activer('zzAut','zztest-c4',ref,false);
  SELECT * INTO snap FROM public.ventes_snapshots WHERE requete='achat-c4test-001';
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-c4';
  rap := rap || E'\nT8  APRES RENOMMAGE ET DESACTIVATION' || E'\n'
             || '    la reference dit : "' || (d->'references'->ref->>'nom') || '" active=' || (d->'references'->ref->>'active') || E'\n'
             || '    le SNAPSHOT dit  : "' || snap.nom_commercial || '"  desc="' || coalesce(snap.description_commerciale,'') || '"' || E'\n'
             || '    objet livre toujours present : ' || ((SELECT count(*) FROM public.objets_recus WHERE id LIKE 'achat-c4test-001%')=1) || E'\n';
  rap := rap || 'T9  achat sur reference desactivee : ' || public.acheter_produit_commerce('achat-c4test-009','Arnie','zztest-c4',ref,1)::text || E'\n';

  RAISE EXCEPTION 'BANC C4 partie 1 -- transaction annulee, aucun residu %', rap;
END $$;

-- ---------------------------------------------------------------------------
-- BLOC 6 — C4 : REFUS, NOM TROMPEUR, CONCURRENCE, DROITS  (partie 2)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r jsonb; rap text := E'\n'; d jsonb; refT text; brut text; snap record;
  argA numeric; caisse numeric;
BEGIN
  INSERT INTO public.locations_actives (id, country, data) VALUES (
    'republic:centre-commercial:vitrine_principale:capitale','republic',
    jsonb_build_object('buildingId','centre-commercial','roomId','vitrine_principale',
      'locataire','zzAut','country','republic','city','capitale','lotId',null,'prix',800));
  PERFORM public.creer_fonds_commerce('zzAut','republic:centre-commercial:vitrine_principale:capitale','zztest-c4',0,'Souvenirs Marcel');
  PERFORM public.fonds_definir_types('zzAut','zztest-c4', ARRAY['commerce-non-alimentaire']);
  UPDATE public.entreprises SET data = data
    || jsonb_build_object('stockMatieres', jsonb_build_object('metal',10))
    || jsonb_build_object('coutMoyenMatieres', jsonb_build_object('metal',15))
    WHERE id='zztest-c4';
  UPDATE public.personnages_donnees SET pa = 10 WHERE name='zzAut';

  r := public.fonds_reference_creer('zzAut','zztest-c4','souvenir','porte_cle_palais_luthecia','Souvenir Collector +50 ENT','Procure un immense charisme.');
  refT := r->>'referenceId';
  PERFORM public.fonds_reference_produire('prod-c4t-001','zzAut','zztest-c4',refT);
  PERFORM public.fonds_reference_prix('zzAut','zztest-c4',refT,44);
  PERFORM public.fonds_reference_activer('zzAut','zztest-c4',refT,true);
  PERFORM public.acheter_produit_commerce('achat-c4t-001','Arnie','zztest-c4',refT,1);
  SELECT data#>>'{}' INTO brut FROM public.objets_recus WHERE id='achat-c4t-001-1';
  SELECT * INTO snap FROM public.ventes_snapshots WHERE requete='achat-c4t-001';
  rap := rap || 'T10 NOM TROMPEUR « Souvenir Collector +50 ENT »' || E'\n'
             || '    objet : generique=' || (brut::jsonb->>'generique_id')
             || '  champ effets present ? ' || (brut::jsonb ? 'effets') || E'\n'
             || '    fiche figee : generique=' || (snap.fiche_officielle->>'generique')
             || '  aucun_effet=' || (snap.fiche_officielle->>'aucun_effet')
             || '  effets=' || coalesce((snap.fiche_officielle->'effets')::text,'absents') || E'\n'
             || '    nom fige : "' || snap.nom_commercial || '"' || E'\n';

  -- CORRECTIF DU 28 SEPTEMBRE 2026 : une baisse du cout des MATIERES ne reecrit
  -- plus le cout d'un produit DEJA fabrique. Le stock reste vendable.
  UPDATE public.entreprises SET data = jsonb_set(data,'{coutMoyenMatieres}', jsonb_build_object('metal',1)) WHERE id='zztest-c4';
  rap := rap || E'\nT11 metal 15 -> 1 SANS produire  : ok='
             || (public.acheter_produit_commerce('achat-c4t-011','Arnie','zztest-c4',refT,1)->>'ok')
             || '  [le stock deja produit reste vendable]' || E'\n';
  -- En revanche une NOUVELLE production moins chere abaisse legitimement le plafond.
  UPDATE public.entreprises SET data = data || jsonb_build_object('stockMatieres', jsonb_build_object('metal',20)) WHERE id='zztest-c4';
  PERFORM public.fonds_reference_produire('prod-c4t-002','zzAut','zztest-c4',refT);
  rap := rap || 'T11b nouvelle production a 1     : ' || public.acheter_produit_commerce('achat-c4t-011b','Arnie','zztest-c4',refT,1)::text || E'\n';
  UPDATE public.entreprises SET data = jsonb_set(data,'{coutMoyenMatieres}', jsonb_build_object('metal',15)) WHERE id='zztest-c4';
  PERFORM public.fonds_reference_prix('zzAut','zztest-c4',refT,
    (public.fonds_cout_revient_reference('zztest-c4',refT)->>'prixMaximum')::int);

  rap := rap || E'\nT12 quantite 0                   : ' || public.acheter_produit_commerce('achat-c4t-012','Arnie','zztest-c4',refT,0)::text || E'\n';
  rap := rap || 'T13 quantite negative            : ' || public.acheter_produit_commerce('achat-c4t-013','Arnie','zztest-c4',refT,-3)::text || E'\n';
  rap := rap || 'T14 quantite > stock             : ' || public.acheter_produit_commerce('achat-c4t-014','Arnie','zztest-c4',refT,99)::text || E'\n';
  rap := rap || 'T15 fonds inexistant             : ' || public.acheter_produit_commerce('achat-c4t-015','Arnie','zztest-absent',refT,1)::text || E'\n';
  rap := rap || 'T16 etablissement PNJ            : ' || public.acheter_produit_commerce('achat-c4t-016','Arnie','armurerie-republic-capitale',refT,1)::text || E'\n';
  rap := rap || 'T17 reference inconnue           : ' || public.acheter_produit_commerce('achat-c4t-017','Arnie','zztest-c4','ref-inexistante',1)::text || E'\n';
  rap := rap || 'T18 cle mal formee               : ' || public.acheter_produit_commerce('pas-une-cle','Arnie','zztest-c4',refT,1)::text || E'\n';

  PERFORM public.fonds_definir_types('zzAut','zztest-c4', ARRAY['pharmacie']);
  rap := rap || 'T19 generique retire des types   : ' || public.acheter_produit_commerce('achat-c4t-019','Arnie','zztest-c4',refT,1)::text || E'\n';
  PERFORM public.fonds_definir_types('zzAut','zztest-c4', ARRAY['commerce-non-alimentaire']);

  UPDATE public.personnages_donnees SET arg = 10 WHERE name='Arnie';
  rap := rap || E'\nT20 acheteur insolvable          : ' || public.acheter_produit_commerce('achat-c4t-020','Arnie','zztest-c4',refT,1)::text || E'\n';
  UPDATE public.personnages_donnees SET arg = 6970 WHERE name='Arnie';

  UPDATE public.entreprises SET data = jsonb_set(data, ARRAY['stockReferences',refT], to_jsonb(1)) WHERE id='zztest-c4';
  r := public.acheter_produit_commerce('achat-c4t-021','Arnie','zztest-c4',refT,1);
  rap := rap || E'\nT21 stock=1, 1er achat           : ok=' || (r->>'ok') || ' stockRestant=' || (r->>'stockRestant') || E'\n';
  r := public.acheter_produit_commerce('achat-c4t-022','Arnie','zztest-c4',refT,1);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-c4';
  rap := rap || 'T22 stock=1, 2e achat (2e cle)   : ' || r::text || E'\n'
             || '    stock final = ' || (d->'stockReferences'->>refT) || ' (jamais negatif)' || E'\n';

  UPDATE public.entreprises SET data = jsonb_set(data, ARRAY['stockReferences',refT], to_jsonb(3)) WHERE id='zztest-c4';
  SELECT arg INTO argA FROM public.personnages_donnees WHERE name='zzAut';
  r := public.acheter_produit_commerce('achat-c4t-023','zzAut','zztest-c4',refT,1);
  rap := rap || E'\nT23 PROPRIETAIRE achete chez lui : ok=' || (r->>'ok')
             || '  argent ' || argA || ' -> ' || (SELECT arg FROM public.personnages_donnees WHERE name='zzAut')
             || '  (comportement existant, aucune regle ne l interdit)' || E'\n';

  rap := rap || E'\nT24 DROITS ventes_snapshots : rls=' || (SELECT rowsecurity FROM pg_tables WHERE schemaname='public' AND tablename='ventes_snapshots')
             || '  policies=' || (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='ventes_snapshots')
             || '  anon select=' || has_table_privilege('anon','public.ventes_snapshots','select')
             || '  auth select=' || has_table_privilege('authenticated','public.ventes_snapshots','select')
             || '  auth insert=' || has_table_privilege('authenticated','public.ventes_snapshots','insert')
             || '  auth update=' || has_table_privilege('authenticated','public.ventes_snapshots','update')
             || '  auth delete=' || has_table_privilege('authenticated','public.ventes_snapshots','delete') || E'\n';

  RAISE EXCEPTION 'BANC C4 partie 2 -- transaction annulee, aucun residu %', rap;
END $$;

-- ---------------------------------------------------------------------------
-- BLOC 7 — CMUP DU PRODUIT FINI  (correctif du 28 septembre 2026)
-- ---------------------------------------------------------------------------
-- Le plafond commercial s'appuie sur le cout moyen pondere du STOCK DE PRODUITS
-- FINIS, jamais sur le cout courant des matieres. Une baisse ulterieure du prix
-- d'une matiere ne reecrit donc pas le cout d'un produit deja fabrique.
DO $$
DECLARE
  r jsonb; rap text := E'\n'; d jsonb; ref text; c jsonb; cmup numeric; plafond numeric;
BEGIN
  INSERT INTO public.locations_actives (id, country, data) VALUES (
    'republic:centre-commercial:vitrine_principale:capitale','republic',
    jsonb_build_object('buildingId','centre-commercial','roomId','vitrine_principale',
      'locataire','zzAut','country','republic','city','capitale','lotId',null,'prix',800));
  PERFORM public.creer_fonds_commerce('zzAut','republic:centre-commercial:vitrine_principale:capitale','zztest-cmup',0,'Souvenirs Marcel');
  PERFORM public.fonds_definir_types('zzAut','zztest-cmup', ARRAY['commerce-non-alimentaire']);
  UPDATE public.personnages_donnees SET pa = 10 WHERE name='zzAut';
  r := public.fonds_reference_creer('zzAut','zztest-cmup','souvenir','porte_cle_palais_luthecia','Porte-clé Collector','x');
  ref := r->>'referenceId';

  UPDATE public.entreprises SET data = data || jsonb_build_object(
    'stockMatieres', jsonb_build_object('metal',20), 'coutMoyenMatieres', jsonb_build_object('metal',10)) WHERE id='zztest-cmup';
  r := public.fonds_reference_produire('prod-cmup-001','zzAut','zztest-cmup',ref);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-cmup';
  rap := rap || 'T1 1re production (metal 10)     : coutLot=' || (r->>'coutLot') || ' unitaire=' || (r->>'coutUnitaireLot')
             || '  stock=' || (d->'stockReferences'->>ref) || '  CMUP=' || (d->'coutMoyenReferences'->>ref) || '  [10]' || E'\n';

  UPDATE public.entreprises SET data = jsonb_set(data,'{coutMoyenMatieres}', jsonb_build_object('metal',70)) WHERE id='zztest-cmup';
  r := public.fonds_reference_produire('prod-cmup-002','zzAut','zztest-cmup',ref);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-cmup';
  rap := rap || 'T2 2e production PLUS CHERE (70) : unitaireLot=' || (r->>'coutUnitaireLot')
             || '  cmup ' || (r->>'cmupAvant') || ' -> ' || (r->>'cmupApres')
             || '  stock=' || (d->'stockReferences'->>ref) || '  [(6x10+120)/12 = 15]' || E'\n';

  UPDATE public.entreprises SET data = jsonb_set(data,'{coutMoyenMatieres}', jsonb_build_object('metal',10)) WHERE id='zztest-cmup';
  r := public.fonds_reference_produire('prod-cmup-003','zzAut','zztest-cmup',ref);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-cmup';
  cmup := (d->'coutMoyenReferences'->>ref)::numeric;
  rap := rap || 'T3 3e production MOINS CHERE (10): cmup -> ' || (r->>'cmupApres')
             || '  stock=' || (d->'stockReferences'->>ref) || '  [(12x15+60)/18 = 13,3333]' || E'\n';

  c := public.fonds_cout_revient_reference('zztest-cmup', ref);
  plafond := (c->>'prixMaximum')::numeric;
  rap := rap || E'\nT4 plafond Republia             : ' || (c->>'coutUnitaire') || ' x' || (c->>'coefficient')
             || ' -> ceil = ' || plafond || '  [ceil(53,33) = 54]' || E'\n';
  rap := rap || 'T5 prix AU plafond              : ok=' || (public.fonds_reference_prix('zzAut','zztest-cmup',ref,plafond::int)->>'ok') || E'\n';
  rap := rap || 'T6 plafond + 1                  : ' || (public.fonds_reference_prix('zzAut','zztest-cmup',ref,plafond::int+1)->>'raison') || E'\n';

  UPDATE public.entreprises SET data = jsonb_set(data,'{coutMoyenMatieres}', jsonb_build_object('metal',1)) WHERE id='zztest-cmup';
  c := public.fonds_cout_revient_reference('zztest-cmup', ref);
  PERFORM public.fonds_reference_activer('zzAut','zztest-cmup',ref,true);
  rap := rap || E'\nT7 METAL 10 -> 1 SANS PRODUIRE  : cout=' || (c->>'coutUnitaire')
             || '  plafond=' || (c->>'prixMaximum') || '  INCHANGE=' || ((c->>'prixMaximum')::numeric = plafond) || E'\n'
             || '   vente au prix du plafond toujours possible : '
             || (public.acheter_produit_commerce('achat-cmup-001','Arnie','zztest-cmup',ref,1)->>'ok') || E'\n';

  SELECT data INTO d FROM public.entreprises WHERE id='zztest-cmup';
  rap := rap || 'T8 apres vente de 1             : stock=' || (d->'stockReferences'->>ref)
             || '  CMUP=' || (d->'coutMoyenReferences'->>ref)
             || '  inchange=' || (((d->'coutMoyenReferences'->>ref)::numeric) = cmup) || E'\n';

  UPDATE public.entreprises SET data = jsonb_set(data, ARRAY['stockReferences',ref], to_jsonb(1)) WHERE id='zztest-cmup';
  PERFORM public.acheter_produit_commerce('achat-cmup-002','Arnie','zztest-cmup',ref,1);
  SELECT data INTO d FROM public.entreprises WHERE id='zztest-cmup';
  rap := rap || 'T9 stock ramene a 0             : stock=' || (d->'stockReferences'->>ref)
             || '  cle de cout retiree=' || (NOT (d->'coutMoyenReferences' ? ref)) || E'\n'
             || '   cout de revient : ' || public.fonds_cout_revient_reference('zztest-cmup',ref)::text || E'\n';

  r := public.fonds_reference_produire('prod-cmup-004','zzAut','zztest-cmup',ref);
  c := public.fonds_cout_revient_reference('zztest-cmup', ref);
  rap := rap || 'T10 production apres stock 0    : unitaireLot=' || (r->>'coutUnitaireLot')
             || '  cmupAvant=' || coalesce(r->>'cmupAvant','(aucun)') || ' -> ' || (r->>'cmupApres')
             || '  plafond=' || (c->>'prixMaximum') || '  [(1+50)/6 = 8,5 ; ceil(34)]' || E'\n';

  rap := rap || E'\nT11 exemple du cahier des charges : (100x10 + 50x16)/150 = '
             || round((100*10 + 50*16)::numeric/150, 4)
             || '   plafond Republia = ceil(12 x 4) = ' || ceil((100*10+50*16)::numeric/150*4) || E'\n';

  RAISE EXCEPTION 'BANC CMUP PRODUIT FINI -- transaction annulee, aucun residu %', rap;
END $$;
