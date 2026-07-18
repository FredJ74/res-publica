with open('plateau-pnj.js', encoding='utf-8') as f:
    content = f.read()

ancre = "function ouvrirStatsPerso() {"

ajout = '''function genererStatsHtml() {
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const char = state.char;
  const ar = ARCHETYPES.find(x => x.id === char?.archetype);

  const stats = [
    { label: 'Influence',   val: state.inf  || 0, max: 100, col: '#4a6aaa', icon: 'ti-crown',       desc: 'Poids politique et réseau' },
    { label: 'Popularité',  val: state.pop  || 0, max: 100, col: '#aa6a4a', icon: 'ti-speakerphone', desc: 'Soutien de la population' },
    { label: 'Discrétion',  val: state.dis  || 0, max: 100, col: '#8a4aaa', icon: 'ti-eye-off',      desc: 'Capacité à agir sans être détecté' },
    { label: 'Santé',       val: state.hp   || 0, max: 100, col: '#aa4a4a', icon: 'ti-heart',        desc: 'État physique' },
    { label: 'Moral',       val: state.moral|| 0, max: 100, col: '#6a8aaa', icon: 'ti-brain',        desc: 'Résistance psychologique' },
  ];

  const persoStats = char?.stats || {};
  const STAT_DEFS_LOCAL = [
    { k:'INT', n:'Intelligence', col:'#6a8aaa', i:'ti-brain' },
    { k:'CHA', n:'Charisme',     col:'#aa8a4a', i:'ti-speakerphone' },
    { k:'VOL', n:'Volonté',      col:'#4a8a6a', i:'ti-flame' },
    { k:'PER', n:'Perception',   col:'#4a6aaa', i:'ti-eye' },
    { k:'DUP', n:'Duplicité',    col:'#8a4a8a', i:'ti-masks-theater' },
    { k:'ENT', n:'Entregent',    col:'#8a6a4a', i:'ti-network' },
  ];

  const barsHtml = stats.map(s => {
    const pct = Math.round(s.val);
    return '<div style="margin-bottom:.5rem">' +
      '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.2rem">' +
        '<div style="display:flex;align-items:center;gap:.4rem">' +
          '<i class="ti ' + s.icon + '" style="font-size:.75rem;color:' + s.col + '"></i>' +
          '<span style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;color:#a09060">' + s.label + '</span>' +
        '</div>' +
        '<span style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:' + s.col + '">' + pct + '</span>' +
      '</div>' +
      '<div style="height:4px;background:#1a1810;border-radius:2px">' +
        '<div style="height:100%;width:' + pct + '%;background:' + s.col + ';border-radius:2px;transition:width .3s"></div>' +
      '</div>' +
      '<div style="font-size:.6rem;color:#4a4030;margin-top:.1rem">' + s.desc + '</div>' +
    '</div>';
  }).join('');

  const persoHtml = STAT_DEFS_LOCAL.map(s => {
    const val = persoStats[s.k] || 0;
    return '<div style="text-align:center">' +
      '<div style="font-size:.62rem;color:' + s.col + ';font-family:Bebas Neue,sans-serif;letter-spacing:.06em">' + s.k + '</div>' +
      '<div style="font-size:1rem;color:#f0ead6;font-family:Bebas Neue,sans-serif">' + val + '</div>' +
      '<div style="font-size:.58rem;color:#4a4030">' + s.n + '</div>' +
    '</div>';
  }).join('');

  return '<div style="padding:.6rem 1rem">' +
      '<div style="font-size:.7rem;color:#8a8060;margin-bottom:.8rem;font-style:italic">' +
        (ar?.name || '') + ' · ' + (co?.n || '') +
        (state.poste?.name ? ' · ' + state.poste.name : '') +
      '</div>' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.15em;color:#4a4030;margin-bottom:.5rem">INDICES</div>' +
      barsHtml +
      '<div style="border-top:1px solid #2a2010;margin:.6rem 0"></div>' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.65rem;letter-spacing:.15em;color:#4a4030;margin-bottom:.5rem">ATTRIBUTS PERSONNELS</div>' +
      '<div style="display:grid;grid-template-columns:repeat(6,1fr);gap:.4rem">' + persoHtml + '</div>' +
      '<div style="border-top:1px solid #2a2010;margin:.6rem 0"></div>' +
      '<div style="display:flex;justify-content:space-between;font-size:.72rem;color:#8a8060">' +
        '<span>💰 Liquide : <strong style="color:#C9A84C">' + (state.liquide||0).toLocaleString('fr-FR') + ' ' + cur + '</strong></span>' +
        '<span>🏦 Banque : <strong style="color:#C9A84C">' + (state.banque||0).toLocaleString('fr-FR') + ' ' + cur + '</strong></span>' +
      '</div>' +
    '</div>';
}

function ouvrirStatsPerso() {'''

n = content.count(ancre)
if n != 1:
    print("ERREUR : ancre trouvee " + str(n) + " fois, attendu 1. Rien modifie.")
else:
    content = content.replace(ancre, ajout, 1)
    with open('plateau-pnj.js', 'w', encoding='utf-8') as f:
        f.write(content)
    print("OK, genererStatsHtml() ajoutee dans plateau-pnj.js.")
