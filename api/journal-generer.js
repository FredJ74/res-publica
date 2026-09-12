// =====================================================================
// GÉNÉRATION ISOLÉE DU JOURNAL DU JOUR (12 septembre 2026)
// =====================================================================
// POURQUOI CET ENDPOINT EXISTE. Jusqu'ici, le SEUL déclencheur de la génération d'une édition était
// /api/cron-minuit, qui exécute AVANT elle seize tâches quotidiennes à effets économiques et
// politiques réels (taxe foncière, loyers, prêts, successions, licences, cotisations, salaires...).
// Rejouer le journal signifiait donc rejouer tout cela : impossible. Conséquence mesurée : le
// mécanisme de reprise des éditions en échec, écrit le 8 septembre, n'a jamais pu s'exécuter une
// seule fois (nb_regenerations = 0 sur les 66 lignes existantes), car l'identifiant d'une édition
// contient sa date et le cron du lendemain crée toujours une ligne neuve.
//
// CET ENDPOINT N'APPELLE QUE LA GÉNÉRATION DU JOURNAL. Il n'importe rien de cron-minuit.js et ne
// peut donc, par construction, déclencher aucune autre tâche : la seule fonction appelée est
// genererEditionPays (ou genererToutesLesEditions), qui n'écrit que dans journal_editions,
// journal_articles_en_attente (file de reports) et mails (sollicitations d'interview).
//
// PROTECTIONS.
//   - Authentification FAIL CLOSED sur CRON_SECRET, exactement comme cron-minuit.js : si la
//     variable n'est pas configurée, l'endpoint refuse tout. Aucun accès depuis le jeu, aucun accès
//     anonyme : ce n'est pas un outil de joueur.
//   - Idempotence : inchangée et déjà solide. genererEditionPays réserve la ligne par un INSERT
//     avant tout appel IA ; une édition 'publiee' renvoie 'ignoree_deja_existante' et n'est JAMAIS
//     remplacée. Appeler cet endpoint deux fois de suite ne publie donc jamais deux fois.
//   - Reprise : une édition en 'echec' est re-réservable (correctif du 8 septembre) — c'est
//     précisément le cas que cet endpoint rend enfin atteignable, y compris sur le créneau du jour
//     dont le contenu est resté NULL.
//   - Une édition 'en_cours' n'est jamais reprise : c'est le verrou d'exclusion mutuelle.
//
// Le joueur, lui, n'a rien à faire : il ouvre le journal normalement dans le jeu.
// =====================================================================

import { genererEditionPays, genererToutesLesEditions } from './_journal-generation.js';
import { PAYS_JEU } from './_journal-collecte.js';

export default async function handler(req, res) {
  // Même garde que api/cron-minuit.js : sans CRON_SECRET configuré, rien ne démarre.
  const authHeader = req.headers['authorization'];
  if (!process.env.CRON_SECRET || authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const paysDemande = (req.query && req.query.pays) || (req.body && req.body.pays) || null;

  try {
    if (paysDemande) {
      if (!PAYS_JEU.includes(paysDemande)) {
        return res.status(400).json({ error: 'Pays inconnu', pays: paysDemande, attendus: PAYS_JEU });
      }
      const resultat = await genererEditionPays(paysDemande);
      return res.status(200).json({ ok: true, portee: 'un_pays', resultats: [resultat] });
    }
    const resultats = await genererToutesLesEditions();
    return res.status(200).json({ ok: true, portee: 'tous_pays_eligibles', resultats });
  } catch (e) {
    console.error('journal-generer : erreur', e);
    return res.status(500).json({ ok: false, error: e.message });
  }
}
