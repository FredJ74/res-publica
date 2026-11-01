-- TRANSFERTS SANS PRIME DE SIGNATURE (Claude, 01/11/2026).
--
-- Décision de Fred (01/11/2026, GAME-DESIGN-FOOTBALL.md) : le transfert règle seulement le prix
-- entre le club de départ et le club d'arrivée. Une somme versée au joueur pour signer est une
-- question entre PJ (virement), jamais un versement du transfert.
--
-- Or 20261031220000 (appliquée le 31/10, préparée sans décision de Fred) fait payer par la caisse du
-- club d'arrivée le montant `prixJoueur` que son président inscrit dans l'offre, et le crédite au
-- joueur : de l'argent collectif du club versé à un PJ choisi par le président. Aucune offre
-- n'en porte aujourd'hui (relevé du 01/11 : 0), aucun écran ne le propose.
--
-- Ce correctif, patch en place sur fragments exacts (échec bruyant si le corps diffère) :
--   * transferts_clubs_garder : une offre portant une prime autre que 0 est refusée
--     (`transfert_prime_non_prevue`) ;
--   * club_transfert_conclure : la prime vaut toujours 0 ; seul le prix circule entre les clubs.
-- Indépendante de l'écran (l'écran n'affiche ni ne propose plus de prime depuis la PR #330).
-- Idempotente. Aucune donnée de joueur modifiée.
BEGIN;

DO $mig$
DECLARE d text; n text;
BEGIN
  d := pg_get_functiondef('public.transferts_clubs_garder()'::regprocedure);
  IF strpos(d, 'transfert_prime_non_prevue') = 0 THEN
    n := replace(d,
      $a$    IF v_n ? 'prixJoueur' AND (jsonb_typeof(v_n->'prixJoueur') <> 'number'
         OR (v_n->>'prixJoueur')::numeric < 0 OR (v_n->>'prixJoueur')::numeric <> trunc((v_n->>'prixJoueur')::numeric)) THEN
      RAISE EXCEPTION 'transfert_prime_invalide' USING ERRCODE = '42501';
    END IF;$a$,
      $b$    IF v_n ? 'prixJoueur' AND v_n->'prixJoueur' NOT IN ('0'::jsonb, 'null'::jsonb) THEN
      RAISE EXCEPTION 'transfert_prime_non_prevue' USING ERRCODE = '42501';
    END IF;$b$);
    IF n = d THEN RAISE EXCEPTION 'garde des transferts : fragment de prime introuvable'; END IF;
    EXECUTE n;
  END IF;

  d := pg_get_functiondef('public.club_transfert_conclure(text)'::regprocedure);
  IF strpos(d, 'v_prime := 0;') = 0 THEN
    n := replace(d,
      $a$  v_prime := CASE WHEN NOT v_t ? 'prixJoueur' OR jsonb_typeof(v_t->'prixJoueur') = 'null' THEN 0
                  WHEN jsonb_typeof(v_t->'prixJoueur') = 'number' THEN (v_t->>'prixJoueur')::numeric END;$a$,
      $b$  v_prime := 0;$b$);
    IF n = d THEN RAISE EXCEPTION 'conclusion des transferts : fragment de prime introuvable'; END IF;
    EXECUTE n;
  END IF;
END $mig$;

DO $preuve$ BEGIN
  IF (SELECT prosrc FROM pg_proc WHERE oid = 'public.club_transfert_conclure(text)'::regprocedure) NOT LIKE '%v_prime := 0;%'
     OR (SELECT prosrc FROM pg_proc WHERE oid = 'public.transferts_clubs_garder()'::regprocedure) NOT LIKE '%transfert_prime_non_prevue%' THEN
    RAISE EXCEPTION 'prime de signature encore active';
  END IF;
  IF (SELECT prosecdef FROM pg_proc WHERE oid = 'public.transferts_clubs_garder()'::regprocedure) THEN
    RAISE EXCEPTION 'la garde des transferts ne doit pas être SECURITY DEFINER';
  END IF;
END $preuve$;

COMMIT;
