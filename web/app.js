const ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ESCAPES[c]);
const $ = (sel) => document.querySelector(sel);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'arca_character';
const post = (name, data = {}) =>
    fetch(`https://${resource}/${name}`, { method: 'POST', body: JSON.stringify(data) })
        .then((r) => r.json())
        .catch(() => ({}));
const money = (n) => '$' + Number(n || 0).toLocaleString('en-US');

let state = { characters: [], maxSlots: 1, nationalities: [] };
let selected = null;
let createSlot = null;
let deleting = null;
let busy = false;

function render() {
    const slots = $('#slots');
    slots.innerHTML = '';
    for (let cid = 1; cid <= state.maxSlots; cid++) {
        const char = state.characters.find((c) => c.cid === cid);
        const el = document.createElement('div');

        if (!char) {
            el.className = 'slot empty';
            el.innerHTML = `<i class="fa-solid fa-plus"></i> Create character`;
            el.addEventListener('click', () => openCreate(cid));
        } else {
            el.className = 'slot' + (selected === char.citizenid ? ' selected' : '');
            el.innerHTML = `
                <div class="name">${esc(char.firstname)} ${esc(char.lastname)}</div>
                <div class="info">
                    <span><i class="fa-solid fa-briefcase"></i> ${esc(char.job)}${char.grade ? ' - ' + esc(char.grade) : ''}</span>
                    <span><i class="fa-solid fa-money-bill"></i> ${money(char.cash)}</span>
                    <span><i class="fa-solid fa-building-columns"></i> ${money(char.bank)}</span>
                </div>
                <div class="buttons">
                    <button class="btn primary play"><i class="fa-solid fa-play"></i> Play</button>
                    <button class="btn danger del"><i class="fa-solid fa-trash"></i></button>
                </div>`;
            el.addEventListener('click', () => { selected = char.citizenid; render(); });
            el.querySelector('.play').addEventListener('click', (e) => { e.stopPropagation(); play(char); });
            el.querySelector('.del').addEventListener('click', (e) => { e.stopPropagation(); openConfirm(char); });
        }
        slots.appendChild(el);
    }
}

async function play(char) {
    if (busy) return;
    busy = true;
    const res = await post('select', { citizenid: char.citizenid });
    busy = false;
    if (!res.ok) alertError('Could not load character');
}

function alertError(msg) {
    $('.sub').textContent = msg;
    setTimeout(() => ($('.sub').textContent = 'Select a character'), 3000);
}

/* ---------- create ---------- */
function openCreate(cid) {
    createSlot = cid;
    $('#create-form').reset();
    $('#create-error').textContent = '';
    $('#nationality').innerHTML = state.nationalities.map((n) => `<option>${esc(n)}</option>`).join('');
    $('#create').classList.remove('hidden');
}

$('#create-cancel').addEventListener('click', () => $('#create').classList.add('hidden'));

$('#create-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (busy) return;
    const form = new FormData(e.target);
    const data = Object.fromEntries(form.entries());
    data.gender = Number(data.gender);
    data.cid = createSlot;

    busy = true;
    const res = await post('create', data);
    busy = false;
    if (!res.ok) {
        $('#create-error').textContent = res.error || 'Could not create character';
        return;
    }
    $('#create').classList.add('hidden');
});

/* ---------- delete ---------- */
function openConfirm(char) {
    deleting = char;
    $('#confirm-text').textContent = `${char.firstname} ${char.lastname} will be permanently deleted.`;
    $('#confirm').classList.remove('hidden');
}

$('#confirm-cancel').addEventListener('click', () => $('#confirm').classList.add('hidden'));
$('#confirm-ok').addEventListener('click', async () => {
    if (!deleting || busy) return;
    busy = true;
    await post('delete', { citizenid: deleting.citizenid });
    busy = false;
    deleting = null;
    selected = null;
    $('#confirm').classList.add('hidden');
});

/* ---------- router ---------- */
window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'open':
            // Lua sends empty tables as {} rather than []
            state = data.data;
            if (!Array.isArray(state.characters)) state.characters = Object.values(state.characters || {});
            if (!Array.isArray(state.nationalities)) state.nationalities = Object.values(state.nationalities || {});
            $('#app').classList.remove('hidden');
            render();
            break;
        case 'close':
            $('#app').classList.add('hidden');
            $('#create').classList.add('hidden');
            $('#confirm').classList.add('hidden');
            selected = null;
            break;
    }
});
