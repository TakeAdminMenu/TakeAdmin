const MAX_VISIBLE = 10;

const $menu = document.getElementById('menu');
const $sub = document.getElementById('sub-text');
const $counter = document.getElementById('counter');
const $items = document.getElementById('items');
const $desc = document.getElementById('description');
const $notifs = document.getElementById('notifications');
const $big = document.getElementById('big-message');
const $shot = document.getElementById('screenshot');

let offset = 0;
let lastMenuKey = '';
let bigTimer = null;

// Skalierung relativ zu 1080p
function updateScale() {
    document.documentElement.style.setProperty('--scale', Math.max(0.65, window.innerHeight / 1080));
}
updateScale();
window.addEventListener('resize', updateScale);

function setAccent(hex) {
    const m = /^#?([0-9a-f]{6})$/i.exec(hex || '');
    if (!m) return;
    const root = document.documentElement.style;
    root.setProperty('--accent', '#' + m[1]);
}

function setPosition(pos) {
    $menu.classList.toggle('right', pos === 'right');
    $notifs.classList.toggle('left', pos === 'right');
}

function esc(text) {
    return String(text ?? '')
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// GTA-Farbcodes (~r~, ~g~ ...) in HTML umwandeln
function colorize(text) {
    let html = esc(text).replace(/~n~/g, ' ');
    let open = 0;
    html = html.replace(/~([rgbyopcws])~/g, (_, c) => {
        let out = '</span>'.repeat(open);
        open = 0;
        if (c === 's' || c === 'w') return out;
        open = 1;
        return out + `<span class="c-${c}">`;
    });
    return html + '</span>'.repeat(open);
}

const CHECK_SVG = '<svg viewBox="0 0 24 24" width="18" height="18"><path d="M4 12.5l5 5L20 6.5" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>';

function renderItem(it, selected) {
    const el = document.createElement('div');
    el.className = 'item' + (selected ? ' selected' : '');

    if (it.type === 'separator') {
        el.className = 'item separator';
        el.innerHTML = colorize(it.label);
        return el;
    }

    let right = '';
    switch (it.type) {
        case 'checkbox':
            right = `<div class="check ${it.checked ? 'on' : ''}">${CHECK_SVG}</div>`;
            break;
        case 'list':
            right = `<span class="right list-val"><span class="chev">&#9664;</span>${colorize(it.list)}<span class="chev">&#9654;</span></span>`;
            break;
        case 'slider': {
            const pct = it.max > 0 ? (it.value / it.max) * 75 : 0;
            right = `<div class="slider"><div class="fill" style="left:${pct}%"></div><div class="mid"></div></div>`;
            break;
        }
        case 'submenu':
            right = (it.right ? `<span class="right">${colorize(it.right)}</span>` : '') + '<span class="arrow">&#8250;&#8250;</span>';
            break;
        default:
            if (it.right) right = `<span class="right">${colorize(it.right)}</span>`;
    }

    el.innerHTML = `<span class="label">${colorize(it.label)}</span>${right}`;
    return el;
}

function renderMenu(data) {
    const items = data.items || [];
    const index = (data.index || 1) - 1;

    const key = data.subtitle + '|' + items.length;
    if (key !== lastMenuKey) {
        lastMenuKey = key;
        offset = Math.max(0, Math.min(offset, items.length - MAX_VISIBLE));
    }
    if (index < offset) offset = index;
    if (index >= offset + MAX_VISIBLE) offset = index - MAX_VISIBLE + 1;
    if (items.length <= MAX_VISIBLE) offset = 0;

    $sub.innerHTML = colorize(data.subtitle || '');

    const selectable = items.filter(i => i.type !== 'separator');
    const selPos = items.slice(0, index + 1).filter(i => i.type !== 'separator').length;
    $counter.textContent = selectable.length ? `${selPos} / ${selectable.length}` : '0 / 0';

    $items.innerHTML = '';
    items.slice(offset, offset + MAX_VISIBLE).forEach((it, i) => {
        $items.appendChild(renderItem(it, offset + i === index));
    });

    document.getElementById('footer').style.display = items.length > MAX_VISIBLE ? 'flex' : 'none';

    if (data.description) {
        $desc.innerHTML = colorize(data.description);
        $desc.classList.remove('hidden');
    } else {
        $desc.classList.add('hidden');
    }
}

const HEADS = { success: 'Erfolg', error: 'Fehler', warning: 'Warnung', info: 'TakeAdmin', report: 'Neuer Report', staff: 'Team-Chat' };

function notify(text, type) {
    type = HEADS[type] ? type : 'info';
    const time = type === 'report' ? 12000 : 5500;
    const now = new Date();
    const clock = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
    const el = document.createElement('div');
    el.className = 'notify ' + type;
    el.innerHTML = `
        <div class="n-head"><span class="n-tag">${HEADS[type]}</span><span class="n-time">${clock}</span></div>
        <div class="n-text">${colorize(text)}</div>
        <div class="bar" style="animation-duration:${time}ms"></div>`;
    $notifs.appendChild(el);
    while ($notifs.children.length > 5) $notifs.firstChild.remove();

    setTimeout(() => {
        el.classList.add('out');
        setTimeout(() => el.remove(), 250);
    }, time);
}

function bigMessage(title, text, style) {
    $big.className = style || '';
    $big.querySelector('.bm-title').textContent = title;
    // Text kommt vom Server: nur <br> und <small> erlauben
    const safe = esc(text)
        .replace(/&lt;br&gt;/g, '<br>')
        .replace(/&lt;small&gt;/g, '<small>')
        .replace(/&lt;\/small&gt;/g, '</small>');
    $big.querySelector('.bm-text').innerHTML = safe;
    clearTimeout(bigTimer);
    bigTimer = setTimeout(() => $big.classList.add('hidden'), style === 'announce' ? 12000 : 9000);
}

function copy(text) {
    const ta = document.getElementById('clipboard');
    ta.value = text;
    ta.select();
    document.execCommand('copy');
}

window.addEventListener('message', (e) => {
    const d = e.data;
    switch (d.action) {
        case 'init':
            setPosition(d.position);
            setAccent(d.accent);
            break;
        case 'show':
            setPosition(d.position);
            setAccent(d.accent);
            $menu.classList.remove('hidden');
            offset = 0;
            lastMenuKey = '';
            break;
        case 'hide':
            $menu.classList.add('hidden');
            break;
        case 'menu':
            renderMenu(d);
            break;
        case 'notify':
            notify(d.text, d.type);
            break;
        case 'bigMessage':
            bigMessage(d.title, d.text, d.style);
            break;
        case 'screenshot':
            $shot.querySelector('img').src = d.image;
            $shot.querySelector('.ss-name').textContent = 'Screenshot: ' + (d.name || '');
            $shot.classList.remove('hidden');
            break;
        case 'hideScreenshot':
            $shot.classList.add('hidden');
            $shot.querySelector('img').src = '';
            break;
        case 'copy':
            copy(d.text);
            break;
    }
});
