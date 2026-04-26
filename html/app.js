const body = document.body;
const box = document.getElementById('radiation-box');
const fill = document.getElementById('radiation-fill');
const glow = document.getElementById('radiation-glow');
const value = document.getElementById('radiation-value');
const status = document.getElementById('radiation-status');
const environmentText = document.getElementById('radiation-environment');
const radiationText = document.getElementById('radiation-text');

const maskStatus = document.getElementById('mask-status');
const suitStatus = document.getElementById('suit-status');
const filterStatus = document.getElementById('filter-status');
const filterFill = document.getElementById('filter-fill');
const protectionValue = document.getElementById('protection-value');

function getState(current, data = {}) {
    const inZone = Boolean(data.inZone);
    const protection = Number(data.protection) || 0;
    const zoneLabel = data.zoneLabel || 'HOT ZONE';

    if (current >= 75) {
        return {
            className: 'state-danger',
            status: 'CRITICO',
            env: zoneLabel,
            text: 'Contaminazione estrema rilevata'
        };
    }

    if (inZone && protection >= 100) {
        return {
            className: 'state-protected',
            status: 'ISOLATO',
            env: zoneLabel,
            text: 'Protezione totale attiva'
        };
    }

    if (inZone && protection > 0) {
        return {
            className: 'state-protected',
            status: 'PROTETTO',
            env: zoneLabel,
            text: `Esposizione attenuata del ${protection}%`
        };
    }

    if (current >= 35 || inZone) {
        return {
            className: 'state-mid',
            status: inZone ? 'ESPOSTO' : 'CONTAMINATO',
            env: inZone ? zoneLabel : 'UNSAFE AREA',
            text: inZone ? 'Esposizione radioattiva in corso' : 'Esposizione radioattiva rilevata'
        };
    }

    return {
        className: 'state-safe',
        status: 'STABILE',
        env: 'SAFE ZONE',
        text: 'Livelli sotto controllo'
    };
}

function setStatusElement(element, active, activeText = 'SI', inactiveText = 'NO') {
    if (!element) return;

    element.textContent = active ? activeText : inactiveText;
    element.classList.toggle('off', !active);
}

const radiationSound = document.getElementById('radiation-sound');

let soundPlaying = false;
let fadeInterval = null;

function fadeAudio(targetVolume, fadeMs = 1000, stopAfter = false) {
    if (!radiationSound) return;

    if (fadeInterval) {
        clearInterval(fadeInterval);
        fadeInterval = null;
    }

    const startVolume = radiationSound.volume;
    const steps = 30;
    const stepTime = Math.max(10, fadeMs / steps);
    let currentStep = 0;

    fadeInterval = setInterval(() => {
        currentStep++;

        const progress = currentStep / steps;
        const newVolume = startVolume + ((targetVolume - startVolume) * progress);

        radiationSound.volume = Math.max(0, Math.min(1, newVolume));

        if (currentStep >= steps) {
            clearInterval(fadeInterval);
            fadeInterval = null;

            radiationSound.volume = targetVolume;

            if (stopAfter) {
                radiationSound.pause();
                radiationSound.currentTime = 0;
                soundPlaying = false;
            }
        }
    }, stepTime);
}

function playRadiationSound(volume = 0.35, fadeMs = 1000) {
    if (!radiationSound) return;

    radiationSound.loop = true;

    if (!soundPlaying) {
        radiationSound.volume = 0.0;
        radiationSound.currentTime = 0;

        radiationSound.play().catch((error) => {
            console.log('[bg_radiations] Errore avvio audio NUI:', error);
        });

        soundPlaying = true;
    }

    fadeAudio(volume, fadeMs, false);
}

function stopRadiationSound(fadeMs = 1000) {
    if (!radiationSound || !soundPlaying) return;

    fadeAudio(0.0, fadeMs, true);
}

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'sound') {
        if (data.state) {
            playRadiationSound(
                Number(data.volume) || 0.35,
                Number(data.fadeMs) || 1000
            );
        } else {
            stopRadiationSound(Number(data.fadeMs) || 1000);
        }

        return;
    }

    if (data.action === 'visible') {
        body.classList.toggle('hidden', !data.state);
        return;
    }

    if (data.action === 'update') {
        const current = Number(data.value) || 0;
        const max = Number(data.max) || 100;
        const percent = Math.max(0, Math.min(100, (current / max) * 100));
        const protection = Number(data.protection) || 0;
        const filterSeconds = Number(data.filterSeconds) || 0;
        const filterMaxSeconds = Number(data.filterMaxSeconds) || 300;
        const filterPercent = data.filterActive
            ? Math.max(0, Math.min(100, (filterSeconds / filterMaxSeconds) * 100))
            : 0;

        const state = getState(current, data);

        fill.style.width = `${percent}%`;
        glow.style.width = `${percent}%`;
        value.textContent = `${Math.round(current)}%`;
        status.textContent = state.status;
        environmentText.textContent = state.env;
        radiationText.textContent = state.text;

        box.classList.remove('state-safe', 'state-mid', 'state-danger', 'state-protected');
        box.classList.add(state.className);

        setStatusElement(maskStatus, Boolean(data.hasMask));
        setStatusElement(suitStatus, Boolean(data.hasSuit));

        if (filterStatus) {
            if (data.filterActive) {
                filterStatus.textContent = data.filterTime || '00:00';
                filterStatus.classList.remove('off');
                filterStatus.classList.toggle('warning', filterSeconds <= 60);
            } else {
                filterStatus.textContent = 'NO';
                filterStatus.classList.add('off');
                filterStatus.classList.remove('warning');
            }
        }

        if (filterFill) {
            filterFill.style.width = `${filterPercent}%`;
            filterFill.classList.toggle('warning', filterSeconds <= 60 && filterSeconds > 0);
        }

        if (protectionValue) {
            protectionValue.textContent = `${protection}%`;
            protectionValue.classList.toggle('off', protection <= 0);
        }
    }
});
