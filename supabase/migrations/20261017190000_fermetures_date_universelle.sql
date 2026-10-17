-- Préparation rétrocompatible : les fermetures possèdent désormais une échéance civile.
-- Aucune fermeture historique n'existe au moment de l'audit du 17 octobre 2026.
ALTER TABLE public.batiments_fermes
  ADD COLUMN IF NOT EXISTS date_fin_universelle date;

-- Les nouvelles fermetures doivent porter une date commune, indépendante du PJ.
-- Le champ jour_fin est conservé provisoirement pour compatibilité avec les anciens producteurs.
COMMENT ON COLUMN public.batiments_fermes.date_fin_universelle IS
  'Premier jour civil Europe/Paris de réouverture, indépendant des compteurs de PJ.';
