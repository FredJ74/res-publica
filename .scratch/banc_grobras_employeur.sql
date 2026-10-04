-- ===========================================================================
-- BANC DE BOUT EN BOUT — SOCLE D'EMBAUCHE DES AGENCES (5 octobre 2026)
-- ---------------------------------------------------------------------------
-- IL EMBAUCHE POUR DE VRAI, puis annule tout. On se fait passer pour un
-- personnage de test (zztest-eco-a) via request.jwt.claims, on recrute six
-- personnes chez Grobras, et on verifie ce que le serveur a REELLEMENT ecrit :
-- les quotas, la classe, les deux couts, la caisse de l'agence, les PA.
--
-- LE ROLLBACK FINAL N'EST PAS OPTIONNEL. Ce banc modifie les fonds et le pays
-- du personnage de test ; il ne doit JAMAIS etre execute sans son rollback.
--
-- Lancement : via le MCP Supabase (execute_sql), d'un seul bloc.
--
-- DEUX PIEGES RENCONTRES EN L'ECRIVANT, consignes pour la prochaine fois :
--
--   1. LES FONDS NE SONT PAS `arg`. payer_ordre preleve via
--      debiter_fonds_ordinaires, qui lit personnages_donnees.LIQUIDE puis le
--      compte bancaire national. Crediter `arg` ne donne pas un sou de plus a
--      depenser -- le premier jet de ce banc a echoue sur
--      « fonds_insuffisants, disponible: 100 » alors qu'il venait d'ecrire
--      20 000 dans `arg`.
--
--   2. LE QUOTA EST VERIFIE AVANT L'IDENTITE, et c'est le bon ordre : quand il
--      n'y a plus de place, il n'y a plus de place, quel que soit le nom. Pour
--      tester `deja_employe` il faut donc re-embaucher quelqu'un ALORS QU'IL
--      RESTE DES PLACES. Le premier jet attendait `deja_employe` sur le 5e
--      agent et recevait `quota_metier_atteint` : l'assertion etait fausse, pas
--      le code.
-- ===========================================================================

begin;
do $$
declare
  v_uid uuid; v_r jsonb; v_n integer; v_i integer;
  v_liq0 numeric; v_pa0 integer; v_caisse0 numeric; v_lib text;
  v_ids text[] := '{}';
begin
  select user_id into v_uid from public.personnages where name = 'zztest-eco-a';
  if v_uid is null then raise exception 'personnage de test introuvable'; end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);
  if public.mon_personnage() <> 'zztest-eco-a' then
    raise exception 'usurpation echouee : %', public.mon_personnage(); end if;

  -- Des moyens, pour que les refus testes soient des QUOTAS et pas des fonds.
  update public.personnages_donnees set liquide = 20000, pa = 12 where name = 'zztest-eco-a';
  select coalesce(liquide,0), pa into v_liq0, v_pa0
    from public.personnages_donnees where name='zztest-eco-a';
  select (data->>'solde')::numeric into v_caisse0 from public.caisses_batiments
   where id = 'republic_agence-grobras-securite';
  raise notice '0  depart : liquide=% pa=% caisse_agence=%', v_liq0, v_pa0, v_caisse0;

  -- 1. LE COMPTOIR REPOND : 12 identites, 2 metiers, tout vient de la base.
  v_r := public.employeur_candidats('grobras-securite');
  if (v_r->>'ok')::boolean is not true then raise exception 'comptoir refuse : %', v_r; end if;
  raise notice '1  comptoir « % » : % candidats, % metiers',
    v_r->>'employeur', jsonb_array_length(v_r->'candidats'), jsonb_array_length(v_r->'metiers');

  -- 2. PREMIER AGENT, puis RE-EMBAUCHE DU MEME avec 3 places libres.
  v_r := public.employeur_embaucher('grobras-ag-01');
  if (v_r->>'ok')::boolean is not true then raise exception '2 ag-01 : %', v_r; end if;
  v_ids := v_ids || (v_r->>'pnj_id');
  raise notice '2.1  % | embauche=% FR | jour=% FR | %',
    v_r->>'nom', v_r->>'cout_embauche', v_r->>'cout_jour', v_r->>'role_libelle';
  v_r := public.employeur_embaucher('grobras-ag-01');
  if v_r->>'raison' <> 'deja_employe' then
    raise exception '2b re-embauche sous quota : % (attendu deja_employe)', v_r; end if;
  raise notice '2b re-embaucher le meme (3 places libres) : REFUSE -> %', v_r->>'raison';

  for v_i in 2..4 loop
    v_r := public.employeur_embaucher('grobras-ag-0' || v_i);
    if (v_r->>'ok')::boolean is not true then
      raise exception '2  agent % refuse : %', v_i, v_r; end if;
    v_ids := v_ids || (v_r->>'pnj_id');
    raise notice '2.%  % | embauche=% FR | jour=% FR',
      v_i, v_r->>'nom', v_r->>'cout_embauche', v_r->>'cout_jour';
  end loop;

  -- 3. LE QUOTA DE 4 TIENT. Le moteur ne suppose PAS un representant unique :
  --    quatre agents coexistent, le cinquieme seulement est refuse.
  v_r := public.employeur_embaucher('grobras-ag-05');
  if v_r->>'raison' <> 'quota_metier_atteint' or (v_r->>'quota')::int <> 4 then
    raise exception '3  5e agent : %', v_r; end if;
  raise notice '3  5e agent REFUSE : % (quota %, deja %)',
    v_r->>'raison', v_r->>'quota', v_r->>'employes';

  -- 4. LE QUOTA DE 2 DU MAITRE-CHIEN, independant de celui de l'agent.
  v_r := public.employeur_embaucher('grobras-mc-01');
  if (v_r->>'ok')::boolean is not true then raise exception '4  mc-01 : %', v_r; end if;
  v_ids := v_ids || (v_r->>'pnj_id');
  raise notice '4.1  % | embauche=% FR | jour=% FR | %',
    v_r->>'nom', v_r->>'cout_embauche', v_r->>'cout_jour', v_r->>'role_libelle';
  v_r := public.employeur_embaucher('grobras-mc-02');
  if (v_r->>'ok')::boolean is not true then raise exception '4  mc-02 : %', v_r; end if;
  v_ids := v_ids || (v_r->>'pnj_id');
  v_r := public.employeur_embaucher('grobras-mc-03');
  if v_r->>'raison' <> 'quota_metier_atteint' or (v_r->>'quota')::int <> 2 then
    raise exception '4  3e maitre-chien : %', v_r; end if;
  raise notice '4  3e maitre-chien REFUSE : % (quota %)', v_r->>'raison', v_r->>'quota';

  -- 5. CE QUE LE JOUEUR A PAYE : 4x500 + 2x700 = 3400 FR, et 6 PA (1 par acte).
  select coalesce(liquide,0), pa into v_liq0, v_pa0
    from public.personnages_donnees where name='zztest-eco-a';
  raise notice '5  joueur : liquide=% (attendu 16600) pa=% (attendu 6)', v_liq0, v_pa0;
  if v_liq0 <> 16600 then raise exception '5  debit errone : %', v_liq0; end if;
  if v_pa0 <> 6 then raise exception '5  PA errones : %', v_pa0; end if;

  -- 6. CE QUE L'AGENCE A RECU : les memes 3400 FR. L'argent change de main, il
  --    ne disparait pas.
  select (data->>'solde')::numeric into v_liq0 from public.caisses_batiments
   where id = 'republic_agence-grobras-securite';
  raise notice '6  caisse de l''agence : % (attendu %)', v_liq0, v_caisse0 + 3400;
  if v_liq0 <> v_caisse0 + 3400 then raise exception '6  caisse : %', v_liq0; end if;

  -- 7. LE COUT JOURNALIER STOCKE EST NUL. C'est l'arbitrage du 5 octobre :
  --    « Le joueur ne doit subir aucun prelevement quotidien dans ce lot. »
  --    C'est la preuve que le frais d'embauche n'a PAS ete recopie en salaire.
  select count(*) into v_n from public.pnj_employes_metier
   where pnj_id = any(v_ids) and cout_jour <> 0;
  if v_n <> 0 then raise exception '7  % employe(s) a cout_jour non nul', v_n; end if;
  raise notice '7  les 6 portent cout_jour = 0 : aucun prelevement quotidien';

  -- 8. LA CLASSE ALPHA EST SUR L'INDIVIDU. La famille employe reste beta.
  select count(*) into v_n from public.pnj_membres where id = any(v_ids) and classe = 'alpha';
  if v_n <> 6 then raise exception '8  % alpha sur 6', v_n; end if;
  raise notice '8  les 6 sont alpha ; pnj_classe_de du 1er = %', public.pnj_classe_de(v_ids[1]);

  -- 9. ET ALPHA SERT A QUELQUE CHOSE : pnj_pa_garde laisse passer le debit.
  v_r := public.pnj_pa_debiter(array[v_ids[1]], 1);
  if (v_r->>'ok')::boolean is not true then
    raise exception '9  un alpha doit pouvoir depenser des PA : %', v_r; end if;
  raise notice '9  agent alpha : 1 PA debite, ACCEPTE';

  -- 10. LE LIBELLE EST COMPOSE : metier (referentiel) + agence (employeur).
  select count(*) into v_n from public.pnj_employes_metier
   where pnj_id = any(v_ids) and role_libelle like '%— Grobras Sécurité';
  if v_n <> 6 then raise exception '10 % libelles sur 6', v_n; end if;
  select role_libelle into v_lib from public.pnj_employes_metier where pnj_id = v_ids[5];
  raise notice '10 libelle compose, ex. « % »', v_lib;
  select count(*) into v_n from public.pnj_employes_metier
   where pnj_id = any(v_ids) and candidat_id is not null;
  if v_n <> 6 then raise exception '10b % liens de catalogue sur 6', v_n; end if;
  raise notice '10b les 6 gardent leur lien vers le catalogue';

  -- 11. LE COMPTOIR SAIT QUI EST DEJA A VOTRE SERVICE.
  v_r := public.employeur_candidats('grobras-securite');
  select count(*) into v_n from jsonb_array_elements(v_r->'candidats') c
   where (c->>'deja_employe')::boolean;
  if v_n <> 6 then raise exception '11 % marques pris sur 6', v_n; end if;
  raise notice '11 le comptoir marque % candidats « a votre service »', v_n;

  -- 12. TEMOIN BETA : l'informateur n'a rien perdu, et il ne depense pas de PA.
  --     Les deux moities du temoin comptent : son cout_jour reste 150 (non
  --     regression), et sa classe beta lui refuse les PA (la classe alpha des
  --     agents est donc NECESSAIRE, pas decorative).
  v_r := public.employe_recruter('informateur','Temoin Beta','H','recruter_informateur_pnj',1,150);
  if (v_r->>'ok')::boolean is not true then raise exception '12 informateur : %', v_r; end if;
  if (v_r->>'cout_jour')::int <> 150 then raise exception '12 cout_jour = %', v_r->>'cout_jour'; end if;
  raise notice '12 informateur recrute : cout_jour=% (inchange)', v_r->>'cout_jour';
  v_r := public.pnj_pa_debiter(array[v_r->>'pnj_id'], 1);
  if (v_r->>'ok')::boolean is true then
    raise exception '12 un beta ne doit PAS depenser de PA : %', v_r; end if;
  raise notice '12 temoin beta : PA REFUSES -> %', v_r->>'raison';

  -- 13. ET SON QUOTA DE 1 EST PRESERVE : la generalisation n'a rien relache.
  v_r := public.employe_recruter('informateur','Temoin Deux','H','recruter_informateur_pnj',1,150);
  if v_r->>'raison' <> 'quota_metier_atteint' then
    raise exception '13 2e informateur : %', v_r; end if;
  raise notice '13 2e informateur REFUSE : quota 1 preserve';

  -- 14. UN CASTING N'EXISTE JAMAIS HORS DE SON EMPIRE.
  update public.personnages_donnees set country = 'soviet' where name = 'zztest-eco-a';
  v_r := public.employeur_embaucher('grobras-mc-03');
  if v_r->>'raison' <> 'employeur_hors_pays' then
    raise exception '14 joueur sovietique : %', v_r; end if;
  raise notice '14 joueur d''un autre empire : REFUSE -> %', v_r->>'raison';
  v_r := public.employeur_candidats('grobras-securite');
  if v_r->>'raison' <> 'employeur_inconnu' then
    raise exception '14b comptoir hors pays : %', v_r; end if;
  raise notice '14b le comptoir n''existe pas hors de Republia -> %', v_r->>'raison';

  raise notice '';
  raise notice '=== BOUT EN BOUT : TOUTES LES ASSERTIONS PASSENT ===';
end $$;
rollback;
