const listings = [
  {id:1, title:"Villa moderne 4 chambres", city:"Pétion-Ville", neighborhood:"Berthé", type:"Maison", transaction:"Vente", price:385000, currency:"$", beds:4, baths:3, area:320, desc:"Villa contemporaine récemment construite, grand jardin, garage double et vue dégagée sur les collines de Pétion-Ville."},
  {id:2, title:"Appartement vue sur mer", city:"Jacmel", neighborhood:"Cyvadier", type:"Appartement", transaction:"Location", price:650, currency:"$/mois", beds:2, baths:2, area:95, desc:"Appartement lumineux à deux pas de la plage, balcon avec vue sur la mer des Caraïbes, idéal pour télétravail."},
  {id:3, title:"Maison familiale", city:"Delmas", neighborhood:"Delmas 33", type:"Maison", transaction:"Vente", price:145000, currency:"$", beds:3, baths:2, area:180, desc:"Maison sur trois niveaux dans un quartier calme et accessible, proche des écoles et des commerces."},
  {id:4, title:"Studio meublé centre-ville", city:"Pétion-Ville", neighborhood:"Centre", type:"Appartement", transaction:"Location", price:450, currency:"$/mois", beds:1, baths:1, area:40, desc:"Studio entièrement meublé et équipé, à distance de marche des restaurants et commerces de Pétion-Ville."},
  {id:5, title:"Terrain constructible", city:"Kenscoff", neighborhood:"Fermathe", type:"Terrain", transaction:"Vente", price:60000, currency:"$", beds:null, baths:null, area:800, desc:"Terrain plat en hauteur, climat frais, idéal pour résidence secondaire ou projet agricole."},
  {id:6, title:"Villa avec piscine", city:"Tabarre", neighborhood:"Tabarre 25", type:"Maison", transaction:"Vente", price:520000, currency:"$", beds:5, baths:4, area:410, desc:"Propriété haut de gamme avec piscine, dépendance, génératrice et système de captage d'eau de pluie."},
  {id:7, title:"Appartement 3 chambres", city:"Cap-Haïtien", neighborhood:"Centre-ville", type:"Appartement", transaction:"Location", price:700, currency:"$/mois", beds:3, baths:2, area:130, desc:"Bel appartement rénové au cœur du Cap-Haïtien, proche du bord de mer et des sites historiques."},
  {id:8, title:"Maison de ville", city:"Les Cayes", neighborhood:"Centre", type:"Maison", transaction:"Vente", price:98000, currency:"$", beds:3, baths:2, area:150, desc:"Maison de ville bien entretenue, cour clôturée, proche du marché central et des Cayes."},
  {id:9, title:"Local commercial", city:"Delmas", neighborhood:"Delmas 31", type:"Local commercial", transaction:"Location", price:1200, currency:"$/mois", beds:null, baths:1, area:220, desc:"Local en rez-de-chaussée sur axe passant, idéal pour commerce, pharmacie ou banque."},
  {id:10, title:"Maison rénovée style gingerbread", city:"Port-au-Prince", neighborhood:"Pacot", type:"Maison", transaction:"Vente", price:275000, currency:"$", beds:4, baths:3, area:260, desc:"Maison historique de style gingerbread entièrement rénovée, boiseries d'origine préservées, jardin arboré."},
  {id:11, title:"Appartement neuf", city:"Pétion-Ville", neighborhood:"Juvénat", type:"Appartement", transaction:"Location", price:900, currency:"$/mois", beds:2, baths:2, area:110, desc:"Construction neuve avec ascenseur, parking sécurisé et génératrice partagée."},
  {id:12, title:"Terrain agricole", city:"Léogâne", neighborhood:"Route nationale", type:"Terrain", transaction:"Vente", price:25000, currency:"$", beds:null, baths:null, area:5000, desc:"Grand terrain plat, sol fertile, accès direct à la route nationale, idéal pour exploitation agricole."},
  {id:13, title:"Maison de campagne", city:"Jacmel", neighborhood:"Cyvadier", type:"Maison", transaction:"Vente", price:165000, currency:"$", beds:3, baths:2, area:200, desc:"Maison paisible entourée de verdure, à quelques minutes des plages de Jacmel."},
  {id:14, title:"Studio étudiant", city:"Delmas", neighborhood:"Delmas 75", type:"Appartement", transaction:"Location", price:300, currency:"$/mois", beds:1, baths:1, area:30, desc:"Petit studio simple et fonctionnel, proche des universités, idéal pour étudiant."}
];
 
const palette = [
  {roof:"#E25C3B", facade:"#F2B134"},
  {roof:"#1E8F6F", facade:"#F2F5F1"},
  {roof:"#16243B", facade:"#E25C3B"},
  {roof:"#F2B134", facade:"#1E8F6F"},
  {roof:"#C2473A", facade:"#2F8F6E"},
  {roof:"#2C3E63", facade:"#F2B134"}
];
 
function houseSVG(i, size){
  const p = palette[i % palette.length];
  return `<svg width="${size}" height="${size}" viewBox="0 0 100 100" aria-hidden="true">
    <rect x="20" y="45" width="60" height="42" fill="${p.facade}"/>
    <path d="M14 48 L50 16 L86 48 Z" fill="${p.roof}"/>
    <rect x="30" y="58" width="14" height="14" fill="#16243B" opacity="0.85"/>
    <rect x="56" y="58" width="14" height="14" fill="#16243B" opacity="0.85"/>
    <rect x="44" y="72" width="12" height="15" fill="#16243B" opacity="0.85"/>
    <rect x="46" y="22" width="6" height="10" fill="${p.facade}"/>
  </svg>`;
}
 
let state = { transaction:"", city:"" };
 
function fmtPrice(l){
  return l.currency === "$" ? `$${l.price.toLocaleString('en-US')}` : `$${l.price.toLocaleString('en-US')}${l.currency.replace('$','')}`;
}
 
function populateCitySelect(){
  const cities = [...new Set(listings.map(l => l.city))].sort();
  const sel = document.getElementById('f-city');
  cities.forEach(c => {
    const opt = document.createElement('option');
    opt.value = c; opt.textContent = c;
    sel.appendChild(opt);
  });
}
 
function renderChips(){
  const cities = [...new Set(listings.map(l => l.city))].sort();
  const row = document.getElementById('chip-row');
  let html = `<button class="chip ${state.transaction==='' ? 'active':''}" onclick="setTransactionFilter('')">Toutes</button>`;
  html += `<button class="chip ${state.transaction==='Vente' ? 'active':''}" onclick="setTransactionFilter('Vente')">À vendre</button>`;
  html += `<button class="chip ${state.transaction==='Location' ? 'active':''}" onclick="setTransactionFilter('Location')">À louer</button>`;
  cities.forEach(c => {
    html += `<button class="chip ${state.city===c ? 'active':''}" onclick="setCityFilter('${c}')">${c}</button>`;
  });
  row.innerHTML = html;
}
 
function setTransactionFilter(t){
  state.transaction = (state.transaction === t) ? "" : t;
  document.getElementById('f-transaction').value = state.transaction;
  renderChips();
  renderListings();
}
function setCityFilter(c){
  state.city = (state.city === c) ? "" : c;
  document.getElementById('f-city').value = state.city;
  renderChips();
  renderListings();
}
 
function applySearchPanel(){
  state.transaction = document.getElementById('f-transaction').value;
  state.city = document.getElementById('f-city').value;
  state.type = document.getElementById('f-type').value;
  state.budget = document.getElementById('f-budget').value;
  renderChips();
  renderListings();
  document.getElementById('listings').scrollIntoView({behavior:'smooth'});
}
 
function renderListings(){
  const grid = document.getElementById('listings-grid');
  let filtered = listings.filter(l => {
    if(state.transaction && l.transaction !== state.transaction) return false;
    if(state.city && l.city !== state.city) return false;
    if(state.type && l.type !== state.type) return false;
    if(state.budget && l.price > Number(state.budget)) return false;
    return true;
  });
 
  document.getElementById('stat-count').textContent = listings.length;
 
  if(filtered.length === 0){
    grid.innerHTML = `<div class="empty-state"><strong>Aucune annonce ne correspond</strong>Essayez d'élargir votre recherche ou de modifier vos filtres.</div>`;
    return;
  }
 
  grid.innerHTML = filtered.map((l) => {
    const i = listings.indexOf(l);
    const specs = [];
    if(l.beds !== null) specs.push(`${l.beds} ch.`);
    if(l.baths !== null) specs.push(`${l.baths} sdb`);
    specs.push(`${l.area} m²`);
    const p = palette[i % palette.length];
    return `
    <div class="card">
      <div class="card-art" style="background:${p.facade}1A;">
        <span class="card-badge ${l.transaction==='Vente'?'badge-vente':'badge-location'}">${l.transaction === 'Vente' ? 'À vendre' : 'À louer'}</span>
        ${houseSVG(i, 88)}
      </div>
      <div class="card-body">
        <div class="card-city">${l.neighborhood}, ${l.city}</div>
        <div class="card-title">${l.title}</div>
        <div class="card-specs">${specs.join(' · ')}</div>
        <div class="card-price">${fmtPrice(l)}</div>
        <button class="card-cta" onclick="openModal(${l.id})">Voir les détails</button>
      </div>
    </div>`;
  }).join('');
}
 
function openModal(id){
  const l = listings.find(x => x.id === id);
  const i = listings.indexOf(l);
  const p = palette[i % palette.length];
  document.getElementById('modal-art').style.background = p.facade + '1A';
  document.getElementById('modal-art').innerHTML = `<button class="modal-close" onclick="closeModal()" aria-label="Fermer">✕</button>` + houseSVG(i, 110);
  document.getElementById('modal-city').textContent = `${l.neighborhood}, ${l.city}`;
  document.getElementById('modal-title').textContent = l.title;
  document.getElementById('modal-price').textContent = fmtPrice(l);
  const specs = [];
  if(l.beds !== null) specs.push(`<div><b>${l.beds}</b>Chambres</div>`);
  if(l.baths !== null) specs.push(`<div><b>${l.baths}</b>Salles de bain</div>`);
  specs.push(`<div><b>${l.area}</b>m²</div>`);
  document.getElementById('modal-specs').innerHTML = specs.join('');
  document.getElementById('modal-desc').textContent = l.desc;
  document.getElementById('modal-whatsapp').href = `https://wa.me/50900000000?text=${encodeURIComponent('Bonjour, je suis intéressé(e) par : ' + l.title + ' à ' + l.city)}`;
  document.getElementById('modal-overlay').classList.add('open');
}
function closeModal(){
  document.getElementById('modal-overlay').classList.remove('open');
}
function openPublishModal(){
  document.getElementById('publish-modal-overlay').classList.add('open');
}
function closePublishModal(){
  document.getElementById('publish-modal-overlay').classList.remove('open');
}
document.getElementById('modal-overlay').addEventListener('click', (e) => {
  if(e.target.id === 'modal-overlay') closeModal();
});
document.getElementById('publish-modal-overlay').addEventListener('click', (e) => {
  if(e.target.id === 'publish-modal-overlay') closePublishModal();
});
document.addEventListener('keydown', (e) => {
  if(e.key === 'Escape'){ closeModal(); closePublishModal(); }
});
 
document.getElementById('publish-form').addEventListener('submit', function(e){
  e.preventDefault();
  document.getElementById('pform-success').classList.add('show');
  this.reset();
});
 
populateCitySelect();
renderChips();
renderListings();