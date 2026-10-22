# Sécurité des successions

Le contrôle en lecture seule révèle que la policy UPDATE de `public.successions` accepte tous les acteurs identifiés, sans contrôle de propriété du dossier. La fonction `succession_regler` est SECURITY DEFINER. Vérifier tous ses contrôles d'autorité et les usages directs avant de modifier les autorisations. Ne pas activer les coffres avant correction et contre-épreuve authentifiée.
