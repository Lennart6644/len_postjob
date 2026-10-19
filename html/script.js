const $ = (id) => document.getElementById(id);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'len_postjob';

const state = {
    strings: {},
    numberLocale: 'de-DE',
    currency: '$',
    menuOpen: false,
    busy: false,
    xpEnabled: true,
    minigameKey: 'E',
    cancelLabel: 'Backspace',
};

let stampTimer = null;
let stampHide = null;

function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({}));
}

function t(key, vars = {}) {
    let text = state.strings[key] ?? key;
    for (const [name, value] of Object.entries(vars)) {
        text = text.split(`{${name}}`).join(String(value));
    }
    return text;
}

const num = (n) => Number(n || 0).toLocaleString(state.numberLocale);
const money = (n) => `${num(n)} ${state.currency}`;

function applyStatic() {
    document.querySelectorAll('[data-i18n]').forEach((el) => {
        el.textContent = t(el.dataset.i18n);
    });
    document.querySelectorAll('[data-i18n-aria]').forEach((el) => {
        el.setAttribute('aria-label', t(el.dataset.i18nAria));
    });
}

function init(data) {
    state.strings = data.strings || {};
    state.numberLocale = data.numberLocale || 'de-DE';
    state.currency = data.currency || '$';
    state.xpEnabled = data.xpEnabled !== false;
    state.minigameKey = data.minigameKey || 'E';
    state.cancelLabel = data.cancelLabel || 'Backspace';
    document.documentElement.lang = data.locale || 'de';
    $('promptKey').textContent = data.interactKey || 'E';
    applyStatic();
}

function setBusy(on) {
    state.busy = on;
    document.querySelectorAll('#menu .btn').forEach((btn) => { btn.disabled = on; });
}

function renderMenu(d) {
    $('lvl').textContent = d.level;
    $('worker').textContent = d.name || '–';
    const xpOn = !!state.xpEnabled;
    $('levelStamp').classList.toggle('hidden', !xpOn);
    $('xpBlock').classList.toggle('hidden', !xpOn);
    $('bonus').classList.toggle('hidden', !xpOn);
    $('rank').classList.toggle('hidden', !xpOn);
    $('rank').textContent = d.rank || '';
    $('bonus').textContent = t('ui.menu_bonus', { bonus: d.bonus });
    $('sDel').textContent = num(d.deliveries);
    $('sEarn').textContent = money(d.earned);

    const pct = d.maxLevel ? 100 : Math.min(100, Math.round((d.xp / d.xpNeeded) * 100));
    $('xpFill').style.width = `${pct}%`;
    $('xpTrack').setAttribute('aria-valuenow', pct);
    $('xpText').textContent = d.maxLevel
        ? t('ui.menu_xp_max')
        : t('ui.menu_xp', { xp: num(d.xp), needed: num(d.xpNeeded) });

    $('shiftBox').classList.toggle('hidden', !d.shift);
    if (d.shift) {
        $('shiftText').textContent = t('ui.menu_shift_text', {
            deliveries: num(d.shift.deliveries),
            earned: money(d.shift.earned),
        });
    }

    $('lead').textContent = t(d.shift ? 'ui.menu_lead_active' : 'ui.menu_lead');

    const shiftBtn = $('btnShift');
    shiftBtn.textContent = t(d.shift ? 'ui.btn_stop_shift' : 'ui.btn_start_shift');
    shiftBtn.classList.toggle('stop', !!d.shift);

    const uniformBtn = $('btnUniform');
    uniformBtn.classList.toggle('hidden', !d.uniformEnabled);
    uniformBtn.textContent = t(d.uniformOn ? 'ui.btn_uniform_off' : 'ui.btn_uniform_on');
}

function openMenu(d) {
    state.menuOpen = true;
    renderMenu(d);
    $('menu').classList.remove('hidden');
    setBusy(false);
    $('btnShift').focus();
}

function closeMenu() {
    state.menuOpen = false;
    $('menu').classList.add('hidden');
    setBusy(false);
}

function showMenu(show, d) {
    if (!show) return closeMenu();
    if (state.menuOpen) {
        renderMenu(d);
        setBusy(false);
    } else {
        openMenu(d);
    }
}

function trapFocus(e) {
    const items = [...document.querySelectorAll('#menu .btn:not(:disabled), #menu .close')]
        .filter((el) => el.offsetParent !== null);
    if (!items.length) return;
    const first = items[0];
    const last = items[items.length - 1];
    if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
    }
}

$('btnClose').addEventListener('click', () => post('close'));

$('menu').addEventListener('mousedown', (e) => {
    if (e.target === $('menu')) post('close');
});

document.addEventListener('keydown', (e) => {
    if (!state.menuOpen) return;
    if (e.key === 'Escape') post('close');
    if (e.key === 'Tab') trapFocus(e);
});

$('btnShift').addEventListener('click', () => {
    if (state.busy) return;
    setBusy(true);
    post('toggleShift');
});

$('btnUniform').addEventListener('click', () => {
    if (state.busy) return;
    setBusy(true);
    post('toggleUniform');
});

function fmtDistance(m) {
    return m < 1000
        ? t('ui.distance_m', { value: Math.round(m) })
        : t('ui.distance_km', { value: (m / 1000).toLocaleString(state.numberLocale, { maximumFractionDigits: 1 }) });
}

function fmtTime(sec) {
    const m = String(Math.floor(sec / 60)).padStart(2, '0');
    const s = String(sec % 60).padStart(2, '0');
    return `${m}:${s}`;
}

function updateHud(d) {
    $('hudTask').textContent = t(d.stage === 'pickup' ? 'ui.hud_task_pickup' : 'ui.hud_task_dropoff');
    $('hudDist').textContent = fmtDistance(d.distance);
    $('hudCargo').textContent = d.cargo || t('ui.hud_empty');
    $('hudDel').textContent = num(d.deliveries);
    $('hudEarn').textContent = money(d.earned);
    $('hudTime').textContent = fmtTime(d.elapsed || 0);
    $('hudWarn').classList.toggle('hidden', !d.vehicleFar);
}

function setPrompt(text) {
    $('prompt').classList.toggle('hidden', !text);
    $('promptText').textContent = text || '';
}

function showPayout(d) {
    clearTimeout(stampTimer);
    clearTimeout(stampHide);
    const el = $('stamp');

    $('pmAmount').textContent = `+ ${money(d.payout)}`;
    $('pmXp').classList.toggle('hidden', !state.xpEnabled);
    $('pmXp').textContent = t('ui.stamp_xp', { xp: num(d.xp) });

    const tip = $('pmTip');
    tip.classList.toggle('hidden', !d.tip);
    tip.textContent = d.tip ? t('ui.stamp_tip', { tip: money(d.tip) }) : '';

    const lv = $('pmLevel');
    lv.classList.toggle('hidden', !d.levelUp);
    lv.textContent = d.levelUp ? t('ui.stamp_levelup', { level: d.levelUp, rank: d.rank }) : '';

    el.classList.remove('hidden', 'leaving', 'show');
    void el.offsetWidth;
    el.classList.add('show');

    stampTimer = setTimeout(() => {
        el.classList.add('leaving');
        stampHide = setTimeout(() => el.classList.add('hidden'), 500);
    }, 3600);
}

function showSkill(d) {
    $('minigame').classList.toggle('hidden', !d.show);
    if (!d.show) return;
    $('mgLabel').textContent = t('ui.mg_skill');
    $('mgRound').textContent = t('ui.mg_round', { round: d.round, rounds: d.rounds });
    const zone = $('mgZone');
    zone.style.left = `${d.zoneStart * 100}%`;
    zone.style.width = `${(d.zoneEnd - d.zoneStart) * 100}%`;
    $('mgCursor').style.left = '0%';
    $('mgHint').textContent = t('ui.mg_hint', { key: state.minigameKey, cancel: state.cancelLabel });
}

function moveSkill(pos) {
    $('mgCursor').style.left = `${pos * 100}%`;
}

function showProgress(d) {
    const fill = $('progressFill');
    $('progress').classList.toggle('hidden', !d.show);
    fill.style.transition = 'none';
    fill.style.width = '0%';
    if (!d.show) return;
    $('progressLabel').textContent = d.label || '';
    void fill.offsetWidth;
    fill.style.transition = `width ${d.duration}ms linear`;
    fill.style.width = '100%';
}

window.addEventListener('message', (event) => {
    const m = event.data || {};
    switch (m.action) {
        case 'menu':
            showMenu(m.show, m.data);
            break;
        case 'hud':
            $('hud').classList.toggle('hidden', !m.show);
            if (m.show && m.data) updateHud(m.data);
            break;
        case 'prompt':
            setPrompt(m.text);
            break;
        case 'payout':
            showPayout(m.data);
            break;
        case 'skill':
            showSkill(m);
            break;
        case 'skillPos':
            moveSkill(m.pos);
            break;
        case 'progress':
            showProgress(m);
            break;
    }
});

post('ready').then(init);
