-- Banc annulé (lève une exception à la fin) : le service demandé reste valable 24 heures.
-- Jouer après la migration 20261114001500 ; la sortie BANC doit montrer retenu=t, renouvele=t et les trois patchs à t.

DO $banc$
DECLARE m jsonb := public.sovarka_maison_interne('ville_b','maison-krasnov'); s1 jsonb; s2 jsonb; s3 jsonb; j2 date; k int := 1; dl text; da text;
BEGIN
  s1 := public.sovarka_maison_service_joueur_interne('__banc__', m, '2026-11-14');
  LOOP j2 := date '2026-11-14' + k; EXIT WHEN public.sovarka_maison_service_interne(m, j2) IS DISTINCT FROM s1 OR k > 30; k := k + 1; END LOOP;
  s2 := public.sovarka_maison_service_joueur_interne('__banc__', m, j2);
  UPDATE public.sovarka_maisons_demandes SET expire_le = now() - interval '1 minute' WHERE personnage = '__banc__';
  s3 := public.sovarka_maison_service_joueur_interne('__banc__', m, j2);
  dl := pg_get_functiondef('public.sovarka_maison_lire()'::regprocedure);
  da := pg_get_functiondef('public.sovarka_maison_agir(text,text)'::regprocedure);
  RAISE EXCEPTION 'BANC s1=% jour_suivant=% s2=% (retenu=%) s3=% (renouvele=%) lire_patch=% agir_patch=% delete=%',
    s1->>'label', public.sovarka_maison_service_interne(m, j2)->>'label', s2->>'label', s1 = s2, s3->>'label', s3 = public.sovarka_maison_service_interne(m, j2),
    position('service_joueur_interne' in dl) > 0, position('service_joueur_interne' in da) > 0, position('DELETE FROM public.sovarka_maisons_demandes' in da) > 0;
END $banc$;
