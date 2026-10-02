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
let activeCid = null;   // slot number (1..maxSlots)
let gender = 0;
let busy = false;

const charAt = (cid) => state.characters.find((c) => c.cid === cid);

/* ---------- slots ---------- */
function renderSlots() {
    const list = $('#slots');
    list.innerHTML = '';
    for (let cid = 1; cid <= state.maxSlots; cid++) {
        const char = charAt(cid);
        const slot = document.createElement('div');
        slot.className = 'slot' + (cid === activeCid ? ' active' : '');
        slot.innerHTML = char
            ? `<span class="idx">${cid}</span>
               <button class="card">
                   <span class="tag">${char.gender === 1 ? 'Female' : 'Male'}</span>
                   <div class="cid">${esc(char.citizenid)}</div>
                   <div class="name">${esc(char.firstname)} ${esc(char.lastname)}</div>
                   <div class="sub"><i class="fa-solid fa-briefcase"></i> ${esc(char.job)}${char.grade ? ' · ' + esc(char.grade) : ''}</div>
                   <i class="fa-solid fa-angles-right chev"></i>
               </button>`
            : `<span class="idx">${cid}</span>
               <button class="card empty"><i class="fa-regular fa-square-plus"></i><strong>Create</strong></button>`;
        slot.querySelector('.card').addEventListener('click', () => selectSlot(cid));
        list.appendChild(slot);
    }
}

function selectSlot(cid) {
    if (activeCid === cid) return;
    activeCid = cid;
    renderSlots();

    const char = charAt(cid);
    $('#details').classList.toggle('hidden', !char);
    $('#create').classList.toggle('hidden', !!char);

    if (char) {
        $('#d-name').textContent = `${char.firstname} ${char.lastname}`;
        $('#d-id').textContent = `CITIZEN ID · ${char.citizenid}`;
        $('#d-dob').textContent = char.birthdate || '—';
        $('#d-gender').textContent = char.gender === 1 ? 'Female' : 'Male';
        $('#d-nat').textContent = char.nationality || '—';
        $('#d-job').textContent = char.grade ? `${char.job} · ${char.grade}` : char.job;
        $('#d-cash').textContent = money(char.cash);
        $('#d-bank').textContent = money(char.bank);
        post('preview', { citizenid: char.citizenid });
    } else {
        resetCreate();
        post('preview', { gender });
    }
}

/* ---------- details ---------- */
$('#play').addEventListener('click', async () => {
    const char = charAt(activeCid);
    if (!char || busy) return;
    busy = true;
    $('#play').disabled = true;
    const res = await post('select', { citizenid: char.citizenid });
    busy = false;
    $('#play').disabled = false;
    if (!res.ok) $('#d-id').textContent = 'Could not load character';
});

$('#delete').addEventListener('click', () => {
    const char = charAt(activeCid);
    if (!char) return;
    $('#confirm-text').textContent = `${char.firstname} ${char.lastname} will be permanently deleted.`;
    $('#confirm').classList.remove('hidden');
});
$('#confirm-cancel').addEventListener('click', () => $('#confirm').classList.add('hidden'));
$('#confirm-ok').addEventListener('click', async () => {
    const char = charAt(activeCid);
    if (!char || busy) return;
    busy = true;
    await post('delete', { citizenid: char.citizenid });
    busy = false;
    $('#confirm').classList.add('hidden');
    activeCid = null; // the refreshed list re-selects a slot
});

/* ---------- creation ---------- */
function resetCreate() {
    $('#create').reset();
    $('#create-error').textContent = '';
    $('#nationality').innerHTML = state.nationalities.map((n) => `<option>${esc(n)}</option>`).join('');
    setGender(0, false);
}

function setGender(g, preview = true) {
    gender = g;
    document.querySelectorAll('.g-btn').forEach((b) => b.classList.toggle('active', Number(b.dataset.gender) === g));
    if (preview) post('preview', { gender });
}

document.querySelectorAll('.g-btn').forEach((b) => b.addEventListener('click', () => setGender(Number(b.dataset.gender))));

$('#create').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (busy) return;
    const data = Object.fromEntries(new FormData(e.target).entries());
    data.gender = gender;
    data.cid = activeCid;

    busy = true;
    const btn = e.target.querySelector('.create');
    btn.disabled = true;
    const res = await post('create', data);
    busy = false;
    btn.disabled = false;
    if (!res.ok) $('#create-error').textContent = res.error || 'Could not create character';
});

/* ---------- router ---------- */
window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'open': {
            // Lua sends empty tables as {} rather than []
            state = data.data;
            if (!Array.isArray(state.characters)) state.characters = Object.values(state.characters || {});
            if (!Array.isArray(state.nationalities)) state.nationalities = Object.values(state.nationalities || {});
            $('#app').classList.remove('hidden');
            const first = state.characters.length ? Math.min(...state.characters.map((c) => c.cid)) : 1;
            const keep = activeCid && activeCid <= state.maxSlots ? activeCid : first;
            activeCid = null;
            selectSlot(keep);
            break;
        }
        case 'close':
            $('#app').classList.add('hidden');
            $('#confirm').classList.add('hidden');
            activeCid = null;
            break;
    }
});

// browser preview: open web/index.html?preview
if (location.search.includes('preview')) {
    document.body.style.background = 'linear-gradient(135deg,#2b2f33,#121416)';
    window.postMessage({
        action: 'open',
        data: {
            maxSlots: 3,
            nationalities: ['American', 'British'],
            characters: [{ cid: 1, citizenid: 'ABC12345', firstname: 'Jordan', lastname: 'Reyes', gender: 0, birthdate: '1994-05-12', nationality: 'American', job: 'Law Enforcement', grade: 'Sergeant', cash: 2450, bank: 18900 }],
        },
    });
}
if (location.search.includes('create')) setTimeout(() => selectSlot(2), 50);
