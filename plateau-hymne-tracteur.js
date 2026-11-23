// « CHANTER L'HYMNE AU TRACTEUR » (Fred, 23/11/2026, point 33 ; GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md).
// Commun à toutes les églises de la Sainte-Moisson-Commune (ordre « prier » des églises du Tractorisme). Après le
// paiement de l'ordre (inchangé, doPrier de plateau-divers.js), un karaoké de 5 à 6 secondes : un tracteur rouge cahote
// en bas de l'écran en crachant une fumée noire en rythme, une étoile dorée saute de mot en mot, des cierges vacillent,
// bouton « Passer ». Puis le religieux du lieu s'exclame, et le résultat de l'ordre s'affiche (toast habituel).
// Paroles : français de Fred ; adaptation rimée, au ton de cantique pompeux, dans chacune des neuf langues du jeu
// (exception à la règle i18n demandée par Fred). En arabe, l'étoile va de droite à gauche.
// Mouvement réduit (prefers-reduced-motion) : pas de tracteur ni d'étoile qui saute, paroles affichées, durée abrégée.
// Une seule fenêtre à la fois : toute fenêtre de #modal-postes est fermée avant le chant ; aucun texte plus petit que le
// texte courant.
(function (global) {
'use strict';
const DUREE_CHANT_MS = 5600;
const DUREE_REDUITE_MS = 1800;
const PAROLES = Object.freeze({
  fr: ['Ô Tracteur, roue de lumière,', 'Tu laboures nos prières.', 'Gloire au Plan et à ton moteur,', 'Que la moisson remplisse nos cœurs !'],
  en: ['O Tractor, wheel of holy light,', 'You plough our prayers by day and night.', 'Glory to the Plan and to your engine’s roar,', 'May the harvest fill our hearts for evermore!'],
  es: ['¡Oh Tractor, rueda de luz divina,', 'tu arado nuestras plegarias afina!', '¡Gloria al Plan y a tu motor sagrado,', 'que la cosecha colme al pueblo amado!'],
  zh: ['偉哉拖拉機，光明之輪照四方，', '你犁開我們的祈禱與希望。', '榮耀歸於計畫與你引擎聲響，', '願豐收充滿我們的心房！'],
  ru: ['О Трактор, колесо сиянья,', 'Ты пашешь наши упованья.', 'Хвала мотору, и Плану слава —', 'Пусть урожай сердца наполнит величаво!'],
  ko: ['오 트랙터여, 빛의 바퀴여,', '우리 기도를 갈아엎으소서.', '계획과 엔진에 영광 있으라,', '풍작으로 우리 마음 채우소서!'],
  ar: ['يا جرّارُ، يا عجلةَ الأنوار،', 'تحرثُ صلواتِنا ليلَ نهار.', 'المجدُ للخطّةِ ولمحرّكِك الهدّار،', 'ليملأِ الحصادُ قلوبَنا بالثمار!'],
  pt: ['Ó Trator, roda de luz sem par,', 'nossas preces vens arar.', 'Glória ao Plano e ao teu motor,', 'que a colheita encha os corações de amor!'],
  de: ['O Traktor, Rad aus hellem Licht,', 'du pflügst Gebete, Schicht um Schicht.', 'Ruhm sei dem Plan und deinem Motorenklang,', 'die Ernte fülle unsre Herzen lebenslang!']
});
const LIBELLES = Object.freeze({
  fr: { titre: 'Hymne au Tracteur', passer: 'Passer', fermer: 'Amen' },
  en: { titre: 'Hymn to the Tractor', passer: 'Skip', fermer: 'Amen' },
  es: { titre: 'Himno al Tractor', passer: 'Saltar', fermer: 'Amén' },
  zh: { titre: '拖拉機頌歌', passer: '跳過', fermer: '阿們' },
  ru: { titre: 'Гимн Трактору', passer: 'Пропустить', fermer: 'Аминь' },
  ko: { titre: '트랙터 찬가', passer: '건너뛰기', fermer: '아멘' },
  ar: { titre: 'نشيد الجرّار', passer: 'تخطٍّ', fermer: 'آمين' },
  pt: { titre: 'Hino ao Trator', passer: 'Pular', fermer: 'Amém' },
  de: { titre: 'Hymne an den Traktor', passer: 'Überspringen', fermer: 'Amen' }
});
// Religieux du lieu et son exclamation (textes de Fred en français ; traduits dans le même esprit).
const RELIGIEUX = Object.freeze({
  ville_b: { nom: 'Kouzma Lapchine', portrait: 'images/Sovarka/Krasnov/Kouzma.webp', dit: {
    fr: 'PLUS FORT, MON ENFANT ! LE TRACTEUR N’ENTEND PAS !', en: 'LOUDER, MY CHILD! THE TRACTOR CAN’T HEAR YOU!',
    es: '¡MÁS FUERTE, HIJO MÍO! ¡EL TRACTOR NO TE OYE!', zh: '大聲點，我的孩子！拖拉機聽不見！', ru: 'ГРОМЧЕ, ДИТЯ МОЁ! ТРАКТОР НЕ СЛЫШИТ!',
    ko: '더 크게, 내 아이야! 트랙터가 못 듣는다!', ar: 'بصوتٍ أعلى يا بُنيّ! الجرّار لا يسمع!', pt: 'MAIS ALTO, MEU FILHO! O TRATOR NÃO ESTÁ OUVINDO!',
    de: 'LAUTER, MEIN KIND! DER TRAKTOR HÖRT DICH NICHT!' } },
  capitale: { nom: 'Camarade Pontife Tractorenko', portrait: '', dit: {
    fr: 'Le Tracteur vous a entendus, mes enfants. Il ronronne de satisfaction.', en: 'The Tractor has heard you, my children. It purrs with satisfaction.',
    es: 'El Tractor os ha oído, hijos míos. Ronronea de satisfacción.', zh: '孩子們，拖拉機聽見你們了。它滿意地呼嚕作響。',
    ru: 'Трактор услышал вас, дети мои. Он урчит от удовольствия.', ko: '내 자녀들이여, 트랙터가 들었노라. 흡족하여 가르릉거리는구나.',
    ar: 'لقد سمعكم الجرّار يا أبنائي. إنّه يهدر رضًا.', pt: 'O Trator vos ouviu, meus filhos. Ele ronrona de satisfação.',
    de: 'Der Traktor hat euch gehört, meine Kinder. Er schnurrt vor Zufriedenheit.' } }
});

function langue() {
  const l = typeof global.langueDuJeu === 'function' ? global.langueDuJeu() : 'fr';
  return PAROLES[l] ? l : 'fr';
}
function echapper(t) {
  return String(t == null ? '' : t).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
// Mots chantés : séparés par les espaces ; en chinois, chaque caractère (la ponctuation reste avec le précédent).
function mots(ligne, l) {
  if (l !== 'zh') return ligne.split(/\s+/).filter(Boolean);
  const r = [];
  for (const c of Array.from(ligne)) { if (/[，。！？、；：]/.test(c) && r.length) r[r.length - 1] += c; else r.push(c); }
  return r;
}
function religieuxIci() {
  const s = global.state || {};
  return RELIGIEUX[s.currentCity] || RELIGIEUX.capitale;
}
function mouvementReduit() {
  try { return !!global.matchMedia?.('(prefers-reduced-motion: reduce)').matches; } catch (e) { return false; }
}

const STYLE = '#hymne-tracteur{position:fixed;inset:0;z-index:4000;background:rgba(8,6,2,.88);display:flex;flex-direction:column;'
  + 'align-items:center;justify-content:center;padding:16px;box-sizing:border-box;overflow:hidden;font-size:1rem;color:#f0e2b0}'
  + '#hymne-tracteur .ht-carte{position:relative;max-width:640px;width:100%;background:#1a1408;border:2px solid #C9A84C;border-radius:10px;'
  + 'padding:1.2rem 1.2rem 1rem;box-sizing:border-box;text-align:center}'
  + '#hymne-tracteur h3{margin:0 0 .8rem;font-family:"Bebas Neue",sans-serif;letter-spacing:.08em;color:#C9A84C;font-size:1.6rem}'
  + '#hymne-tracteur .ht-paroles{position:relative;line-height:2.4;font-size:1.25rem;padding-top:.6rem}'
  + '#hymne-tracteur .ht-mot{display:inline-block;margin:0 .18em;transition:color .15s}'
  + '#hymne-tracteur .ht-mot.chante{color:#ffd76a;text-shadow:0 0 8px rgba(255,200,60,.6)}'
  + '#hymne-tracteur .ht-etoile{position:absolute;top:0;left:0;font-size:1.3rem;color:#ffd700;pointer-events:none;'
  + 'transition:transform .16s ease-out;text-shadow:0 0 10px #ffb300}'
  + '#hymne-tracteur .ht-etoile.saut{animation:htSaut .2s ease-out}'
  + '#hymne-tracteur .ht-cierge{position:absolute;top:50%;font-size:2rem;animation:htFlamme 1.1s ease-in-out infinite alternate}'
  + '#hymne-tracteur .ht-cierge.g{left:-.4rem}#hymne-tracteur .ht-cierge.d{right:-.4rem;animation-delay:.4s}'
  + '#hymne-tracteur .ht-route{position:absolute;left:0;right:0;bottom:0;height:120px;pointer-events:none}'
  + '#hymne-tracteur .ht-tracteur{position:absolute;bottom:14px;left:-140px;width:120px;height:80px;animation:htRouler ' + DUREE_CHANT_MS + 'ms linear forwards}'
  + '#hymne-tracteur[dir=rtl] .ht-tracteur{left:auto;right:-140px;animation-name:htRoulerRtl}'
  + '#hymne-tracteur[dir=rtl] .ht-tracteur svg{transform:scaleX(-1)}'
  + '#hymne-tracteur .ht-caisse{animation:htCahot .28s ease-in-out infinite alternate}'
  + '#hymne-tracteur .ht-fumee{position:absolute;width:18px;height:18px;border-radius:50%;background:#111;opacity:.85;animation:htFumee 1s ease-out forwards}'
  + '#hymne-tracteur .ht-actions{margin-top:1rem;display:flex;gap:.6rem;justify-content:center}'
  + '#hymne-tracteur .ht-actions button{min-height:44px;min-width:120px;font-size:1rem}'
  + '#hymne-tracteur .ht-religieux{display:flex;gap:.8rem;align-items:center;text-align:start;font-size:1.15rem;line-height:1.45}'
  + '#hymne-tracteur .ht-religieux img{width:72px;height:72px;border-radius:50%;object-fit:cover;flex-shrink:0;border:2px solid #C9A84C}'
  + '#hymne-tracteur[dir=rtl] .ht-fumee{animation-name:htFumeeRtl}'
  + '@keyframes htSaut{0%{margin-top:0}50%{margin-top:-14px}100%{margin-top:0}}'
  + '@keyframes htFlamme{from{opacity:.75;transform:translateY(-50%) scale(1)}to{opacity:1;transform:translateY(-50%) scale(1.08)}}'
  + '@keyframes htRouler{to{left:calc(100% + 20px)}}@keyframes htRoulerRtl{to{right:calc(100% + 20px)}}'
  + '@keyframes htCahot{from{transform:translateY(0) rotate(-1.5deg)}to{transform:translateY(-4px) rotate(1.5deg)}}'
  + '@keyframes htFumee{from{transform:translate(0,0) scale(.6);opacity:.9}to{transform:translate(-30px,-70px) scale(2.4);opacity:0}}'
  + '@keyframes htFumeeRtl{from{transform:translate(0,0) scale(.6);opacity:.9}to{transform:translate(30px,-70px) scale(2.4);opacity:0}}'
  + '@media (prefers-reduced-motion: reduce){#hymne-tracteur .ht-tracteur,#hymne-tracteur .ht-caisse,#hymne-tracteur .ht-cierge,'
  + '#hymne-tracteur .ht-etoile,#hymne-tracteur .ht-fumee{animation:none!important;transition:none!important}'
  + '#hymne-tracteur .ht-route,#hymne-tracteur .ht-etoile{display:none}}';
const TRACTEUR_SVG = '<svg viewBox="0 0 120 80" width="120" height="80" aria-hidden="true"><g class="ht-caisse">'
  + '<rect x="30" y="22" width="44" height="26" rx="3" fill="#c0201a"/><rect x="62" y="8" width="24" height="26" rx="2" fill="#a81812"/>'
  + '<rect x="66" y="12" width="16" height="12" fill="#cfe6f2"/><rect x="24" y="12" width="6" height="16" fill="#333"/>'
  + '<rect x="72" y="40" width="30" height="10" rx="2" fill="#c0201a"/></g>'
  + '<circle cx="40" cy="58" r="18" fill="#222"/><circle cx="40" cy="58" r="8" fill="#c9a84c"/>'
  + '<circle cx="94" cy="64" r="11" fill="#222"/><circle cx="94" cy="64" r="5" fill="#c9a84c"/></svg>';

function installerStyle() {
  if (global.document.getElementById('hymne-tracteur-style')) return;
  const st = global.document.createElement('style');
  st.id = 'hymne-tracteur-style';
  st.textContent = STYLE;
  global.document.head.appendChild(st);
}

// Joue le chant puis l'exclamation ; la promesse se résout quand le joueur ferme (aucun effet métier ici).
function jouerHymneTracteur() {
  const doc = global.document;
  if (!doc || !doc.body) return Promise.resolve();
  // Une seule fenêtre à la fois (R8).
  doc.getElementById('modal-postes')?.classList.remove('open');
  doc.getElementById('hymne-tracteur')?.remove();
  installerStyle();
  const l = langue(), t = LIBELLES[l], rtl = l === 'ar', reduit = mouvementReduit();
  const lignes = PAROLES[l].map(ligne => mots(ligne, l));
  let index = 0;
  const html = '<div class="ht-carte" role="dialog" aria-modal="true" aria-label="' + echapper(t.titre) + '">'
    + '<span class="ht-cierge g" aria-hidden="true">🕯️</span><span class="ht-cierge d" aria-hidden="true">🕯️</span>'
    + '<h3>' + echapper(t.titre) + '</h3>'
    + '<div class="ht-paroles" lang="' + (l === 'zh' ? 'zh-Hant' : l) + '"><span class="ht-etoile" aria-hidden="true">★</span>'
    + lignes.map(ls => '<div>' + ls.map(m => '<span class="ht-mot" data-i="' + (index++) + '">' + echapper(m) + '</span>').join('') + '</div>').join('')
    + '</div><div class="ht-actions"><button type="button" class="cpj-touche" data-ht-passer>' + echapper(t.passer) + '</button></div></div>'
    + '<div class="ht-route" aria-hidden="true"><div class="ht-tracteur">' + TRACTEUR_SVG + '</div></div>';
  const fond = doc.createElement('div');
  fond.id = 'hymne-tracteur';
  fond.dir = rtl ? 'rtl' : 'ltr';
  fond.innerHTML = html;
  doc.body.appendChild(fond);
  const motsEl = Array.from(fond.querySelectorAll('.ht-mot'));
  const etoile = fond.querySelector('.ht-etoile');
  const paroles = fond.querySelector('.ht-paroles');
  const tracteur = fond.querySelector('.ht-tracteur');
  const minuteries = [];
  return new Promise(resoudre => {
    let fini = false;
    const nettoyer = () => { minuteries.forEach(id => global.clearTimeout(id)); minuteries.length = 0; };
    const fermer = () => { nettoyer(); fond.remove(); resoudre(); };
    // Fin du chant (ou « Passer ») : le religieux du lieu s'exclame dans la même fenêtre.
    const exclamation = () => {
      if (fini) return;
      fini = true;
      nettoyer();
      fond.querySelector('.ht-route')?.remove();
      const r = religieuxIci();
      const carte = fond.querySelector('.ht-carte');
      carte.innerHTML = '<h3>' + echapper(t.titre) + '</h3><div class="ht-religieux">'
        + (r.portrait ? '<img src="' + r.portrait + '" alt="">' : '')
        + '<div><strong>' + echapper(r.nom) + '</strong><br>« ' + echapper(r.dit[l] || r.dit.fr) + ' »</div></div>'
        + '<div class="ht-actions"><button type="button" class="cpj-touche cpj-primaire" data-ht-fermer>' + echapper(t.fermer) + '</button></div>';
      carte.querySelector('[data-ht-fermer]').addEventListener('click', fermer);
      carte.querySelector('[data-ht-fermer]').focus?.();
    };
    fond.querySelector('[data-ht-passer]').addEventListener('click', exclamation);
    if (reduit) {
      motsEl.forEach(m => m.classList.add('chante'));
      minuteries.push(global.setTimeout(exclamation, DUREE_REDUITE_MS));
      return;
    }
    const pas = Math.max(90, Math.floor(DUREE_CHANT_MS / Math.max(1, motsEl.length)));
    const placerEtoile = (m) => {
      const bp = paroles.getBoundingClientRect(), bm = m.getBoundingClientRect();
      const x = bm.left - bp.left + bm.width / 2 - 8, y = bm.top - bp.top - 22;
      etoile.style.transform = 'translate(' + Math.round(x) + 'px,' + Math.round(y) + 'px)';
      etoile.classList.remove('saut'); void etoile.offsetWidth; etoile.classList.add('saut');
    };
    // Fumée noire en rythme : une bouffée à chaque mot, au pot d'échappement du tracteur.
    const fumee = () => {
      if (!tracteur) return;
      const f = doc.createElement('span');
      f.className = 'ht-fumee';
      f.style.left = (rtl ? 92 : 24) + 'px';
      f.style.top = '4px';
      tracteur.appendChild(f);
      minuteries.push(global.setTimeout(() => f.remove(), 1000));
    };
    motsEl.forEach((m, i) => {
      minuteries.push(global.setTimeout(() => {
        motsEl.forEach((x, j) => x.classList.toggle('chante', j <= i));
        placerEtoile(m);
        fumee();
      }, i * pas));
    });
    minuteries.push(global.setTimeout(exclamation, Math.max(DUREE_CHANT_MS, motsEl.length * pas) + 200));
  });
}

global.HYMNE_TRACTEUR_PAROLES = PAROLES;
global.HYMNE_TRACTEUR_RELIGIEUX = RELIGIEUX;
global.HYMNE_TRACTEUR_DUREE_MS = DUREE_CHANT_MS;
global.jouerHymneTracteur = jouerHymneTracteur;
})(typeof window !== 'undefined' ? window : globalThis);
