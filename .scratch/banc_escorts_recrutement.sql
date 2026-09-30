-- ===========================================================================
-- BANC DU RECRUTEMENT PAR IDENTITE (1er octobre 2026)
-- ---------------------------------------------------------------------------
-- METHODE : le DDL de PostgreSQL etant transactionnel, ce banc envoie LA
-- MIGRATION ELLE-MEME puis son banc dans une seule requete qui se termine par
-- RAISE EXCEPTION. Tout s'execute, tout est annule : on obtient le rapport sans
-- rien persister en production. C'est ainsi qu'une migration se verifie AVANT
-- d'etre appliquee.
--
-- CE QU'IL PROUVE :
--   R1  un joueur engage QUATRE escorts, dont trois femmes -- l'ancien quota
--       « une par genre » a disparu ; et le libelle de role vient de la donnee
--       (escorts_agences), non d'un litteral
--   R2  deux fois la meme personne : refuse par construction de l'identifiant
--   R3  l'emploi porte l'escort_id : un contrat sait quelle personne il instancie
--   R4  une identite inconnue est refusee
--   R5  l'ANCIENNE PORTE est fermee au serveur (metier_non_recrutable), et le
--       chemin informateur reste intact
--   R6  un SECOND joueur emploie la MEME Natacha : identifiants distincts,
--       deux emplois -- l'exigence multijoueur tenue par la forme de la cle
--   R7  depuis Novomirsk, une escort de Republia n'existe pas
--
-- RESULTAT DU 1er OCTOBRE 2026 :
--   R1a Natacha            ok=true libelle=Escort — Agence Roxane Velours
--   R1b Roxane, 2e femme   ok=true
--   R1c Beatrice, 3e femme ok=true
--   R1d Julien, un homme   ok=true
--   R1  escorts employees   = 4
--   R2  Natacha deux fois   ok=false raison=deja_employee
--   R3  l'emploi porte      escort_id=escort_natacha
--   R4  identite inconnue   ok=false raison=escort_inconnue
--   R5  ancienne porte      ok=false raison=metier_non_recrutable recrutables=["informateur"]
--   R5b informateur intact  ok=true
--   R6  2e joueur, meme escort ok=true identifiant distinct=t
--   R6  emplois de Natacha  = 2
--   R7  depuis Novomirsk    ok=false raison=escort_inconnue
--
-- PIEGES RENCONTRES, pour qui rejouerait ce banc :
--   * l'argent d'un personnage vit dans la COLONNE `liquide`, pas dans le jsonb
--     `resources` : un test dote via resources voit tous ses paiements refuses ;
--   * une variable PL/pgSQL nommee `U` entre en collision avec l'alias de table
--     `u` -- les identifiants ne sont pas sensibles a la casse.
--
-- POUR REJOUER : coller le contenu de
-- migration_20261001_escorts_recrutement_par_identite.sql, puis le bloc DO
-- ci-dessous, dans une seule requete.
-- ===========================================================================
DO $banc$
DECLARE
  R text := ''; A text := 'zzEscRec'; B text := 'zzEscRec2'; U uuid; U2 uuid;
  v jsonb; n integer; id1 text; id2 text;
BEGIN
  SELECT u.id INTO U FROM auth.users u LEFT JOIN public.personnages_donnees p ON p.user_id=u.id
   WHERE p.user_id IS NULL LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',U::text,'role','authenticated')::text, true);
  INSERT INTO public.personnages_donnees (name, country, resources, current_building, current_room)
  VALUES (A,'republic',jsonb_build_object('pa',20,'arg',50000,'liquide',50000),'hotel-republica','bar');

  -- R1 : plusieurs escorts du MEME genre, ce que l'ancien quota interdisait
  v := public.escort_recruter('escort_natacha');
  R := R || format('R1a Natacha        ok=%s role via agence=%s', v->>'ok',
        (SELECT role_libelle FROM public.pnj_employes_metier WHERE pnj_id = v->>'pnj_id')) || E'\n';
  id1 := v->>'pnj_id';
  v := public.escort_recruter('escort_roxane');
  R := R || format('R1b Roxane (2e femme) ok=%s raison=%s', v->>'ok', coalesce(v->>'raison','-')) || E'\n';
  v := public.escort_recruter('escort_beatrice');
  R := R || format('R1c Beatrice (3e femme) ok=%s', v->>'ok') || E'\n';
  v := public.escort_recruter('escort_julien');
  R := R || format('R1d Julien (un homme) ok=%s', v->>'ok') || E'\n';
  SELECT count(*) INTO n FROM public.pnj_membres m JOIN public.pnj_employes_metier e ON e.pnj_id=m.id
   WHERE m.proprietaire_pj=A AND m.statut='actif' AND e.job='escort';
  R := R || format('R1  total employees par le joueur = %s', n) || E'\n';

  -- R2 : deux fois la meme personne, impossible
  v := public.escort_recruter('escort_natacha');
  R := R || format('R2  Natacha deux fois ok=%s raison=%s', v->>'ok', v->>'raison') || E'\n';

  -- R3 : l'emploi connait l'identite
  SELECT escort_id INTO id2 FROM public.pnj_employes_metier WHERE pnj_id = id1;
  R := R || format('R3  l''emploi porte escort_id=%s', id2) || E'\n';

  -- R4 : une identite d'un autre empire est refusee (le joueur est en Republia)
  v := public.escort_recruter('escort_inexistante');
  R := R || format('R4  identite inconnue ok=%s raison=%s', v->>'ok', v->>'raison') || E'\n';

  -- R5 : L'ANCIENNE PORTE EST FERMEE
  v := public.employe_recruter('escort','Marlene','F');
  R := R || format('R5  ancienne porte   ok=%s raison=%s recrutables=%s',
        v->>'ok', v->>'raison', v->>'recrutables') || E'\n';
  v := public.employe_recruter('informateur','Momo Fouine','H');
  R := R || format('R5b informateur intact ok=%s', v->>'ok') || E'\n';

  -- R6 : UN AUTRE JOUEUR emploie la MEME escort -- exigence multijoueur
  SELECT u.id INTO U2 FROM auth.users u LEFT JOIN public.personnages_donnees p ON p.user_id=u.id
   WHERE p.user_id IS NULL AND u.id <> U LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',U2::text,'role','authenticated')::text, true);
  INSERT INTO public.personnages_donnees (name, country, resources, current_building, current_room)
  VALUES (B,'republic',jsonb_build_object('pa',20,'arg',50000,'liquide',50000),'hotel-republica','bar');
  v := public.escort_recruter('escort_natacha');
  R := R || format('R6  un 2e joueur emploie Natacha ok=%s, identifiant different=%s',
        v->>'ok', (v->>'pnj_id') IS DISTINCT FROM id1) || E'\n';
  SELECT count(*) INTO n FROM public.pnj_employes_metier WHERE escort_id='escort_natacha';
  R := R || format('R6  emplois distincts de Natacha = %s', n) || E'\n';

  -- R7 : un joueur a Novomirsk ne peut pas engager une escort de Republia
  UPDATE public.personnages_donnees SET country='soviet' WHERE name=B;
  v := public.escort_recruter('escort_roxane');
  R := R || format('R7  depuis Novomirsk ok=%s raison=%s', v->>'ok', v->>'raison') || E'\n';

  RAISE EXCEPTION E'\n===== BANC RECRUTEMENT PAR IDENTITE (migration NON appliquee) =====\n%', R;
END $banc$;
