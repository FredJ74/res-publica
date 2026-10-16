// Entree ESM conservee pour les navigateurs et les imports existants.
// La logique canonique reste dans le .js : @vercel/node compile ce dernier en
// CommonJS pour l'API, alors qu'un .mjs resterait ESM derriere un require().
export {
  PROFILS_MUNICIPAUX_LUTHECIA,
  lireTitulaireMunicipal,
  contexteMunicipal
} from './continuite-municipale.js';
