#!/usr/bin/env bash
#
# install_dev_tools.sh
#
# Ідемпотентний скрипт перевірки та підготовки середовища для роботи з
# ML-моделями та Docker: Docker, Docker Compose V2, Python >= 3.13, pip,
# а також бібліотеки torch / torchvision / pillow.
#
# Усі результати перевірки/встановлення пишуться у install.log
# (як на екран, так і у файл).
#
# Використання:
#   bash scripts/install_dev_tools.sh
#
# Скрипт можна запускати повторно (ідемпотентно) — уже встановлені
# компоненти просто позначаються як "OK" і не перевстановлюються.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${PROJECT_ROOT}/install.log"
REQUIRED_PYTHON_MAJOR=3
REQUIRED_PYTHON_MINOR=13

# ---------------------------------------------------------------------------
# Допоміжні функції
# ---------------------------------------------------------------------------

log() {
    # Пише повідомлення одночасно у консоль та install.log з таймстемпом
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "${msg}" | tee -a "${LOG_FILE}"
}

section() {
    log ""
    log "==== $* ===="
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Ініціалізація логу
# ---------------------------------------------------------------------------

: > "${LOG_FILE}"   # очищаємо/створюємо лог-файл на кожен запуск
log "Старт перевірки середовища (install_dev_tools.sh)"
log "Операційна система: $(uname -a)"

STATUS_OK=true

# ---------------------------------------------------------------------------
# 1. Docker
# ---------------------------------------------------------------------------

section "Перевірка Docker"

if command_exists docker; then
    DOCKER_VERSION="$(docker --version 2>&1)"
    log "OK: Docker знайдено -> ${DOCKER_VERSION}"
else
    log "УВАГА: Docker не знайдено."
    if command_exists apt-get; then
        log "Спроба встановлення Docker через офіційний скрипт get-docker.sh..."
        if command_exists curl; then
            curl -fsSL https://get.docker.com -o /tmp/get-docker.sh 2>>"${LOG_FILE}" \
                && sh /tmp/get-docker.sh >>"${LOG_FILE}" 2>&1 \
                && log "Docker встановлено успішно." \
                || { log "ПОМИЛКА: не вдалося автоматично встановити Docker."; STATUS_OK=false; }
        else
            log "ІНСТРУКЦІЯ: встановіть Docker вручну: https://docs.docker.com/engine/install/"
            STATUS_OK=false
        fi
    else
        log "ІНСТРУКЦІЯ: встановіть Docker вручну для вашої ОС: https://docs.docker.com/engine/install/"
        STATUS_OK=false
    fi
fi

# ---------------------------------------------------------------------------
# 2. Docker Compose V2 (docker compose version, НЕ docker-compose)
# ---------------------------------------------------------------------------

section "Перевірка Docker Compose V2"

if command_exists docker && docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION="$(docker compose version 2>&1)"
    log "OK: Docker Compose V2 знайдено -> ${COMPOSE_VERSION}"
else
    log "УВАГА: Docker Compose V2 (плагін 'docker compose') не знайдено."
    log "ІНСТРУКЦІЯ: встановіть плагін docker-compose-plugin:"
    log "  sudo apt-get update && sudo apt-get install -y docker-compose-plugin"
    log "  або дивіться: https://docs.docker.com/compose/install/linux/"
    STATUS_OK=false
fi

# ---------------------------------------------------------------------------
# 3. Python >= 3.13
# ---------------------------------------------------------------------------

section "Перевірка Python >= ${REQUIRED_PYTHON_MAJOR}.${REQUIRED_PYTHON_MINOR}"

if command_exists python3; then
    PY_VERSION_STR="$(python3 --version 2>&1 | awk '{print $2}')"
    PY_MAJOR="$(echo "${PY_VERSION_STR}" | cut -d. -f1)"
    PY_MINOR="$(echo "${PY_VERSION_STR}" | cut -d. -f2)"

    if [ "${PY_MAJOR}" -gt "${REQUIRED_PYTHON_MAJOR}" ] || \
       { [ "${PY_MAJOR}" -eq "${REQUIRED_PYTHON_MAJOR}" ] && [ "${PY_MINOR}" -ge "${REQUIRED_PYTHON_MINOR}" ]; }; then
        log "OK: Python ${PY_VERSION_STR} відповідає вимозі (>= 3.13)."
    else
        log "УВАГА: Знайдено Python ${PY_VERSION_STR}, потрібна версія >= 3.13."
        log "ІНСТРУКЦІЯ: встановіть Python 3.13, наприклад:"
        log "  sudo add-apt-repository ppa:deadsnakes/ppa && sudo apt-get update"
        log "  sudo apt-get install -y python3.13 python3.13-venv python3.13-dev"
        STATUS_OK=false
    fi
else
    log "ПОМИЛКА: python3 не знайдено в системі."
    log "ІНСТРУКЦІЯ: встановіть Python 3.13: https://www.python.org/downloads/"
    STATUS_OK=false
fi

# ---------------------------------------------------------------------------
# 4. pip
# ---------------------------------------------------------------------------

section "Перевірка pip"

if command_exists pip3; then
    PIP_VERSION="$(pip3 --version 2>&1)"
    log "OK: pip знайдено -> ${PIP_VERSION}"
else
    log "УВАГА: pip3 не знайдено."
    if command_exists python3; then
        log "Спроба встановлення pip через ensurepip..."
        python3 -m ensurepip --upgrade >>"${LOG_FILE}" 2>&1 \
            && log "pip встановлено успішно." \
            || { log "ІНСТРУКЦІЯ: встановіть pip вручну: sudo apt-get install -y python3-pip"; STATUS_OK=false; }
    else
        STATUS_OK=false
    fi
fi

# ---------------------------------------------------------------------------
# 5. Python-бібліотеки: torch, torchvision, pillow
# ---------------------------------------------------------------------------

section "Перевірка ML-залежностей (torch, torchvision, pillow)"

check_or_install_python_pkg() {
    local pkg_name="$1"
    local import_name="$2"

    if python3 -c "import ${import_name}" >/dev/null 2>&1; then
        local ver
        ver="$(python3 -c "import ${import_name}; print(getattr(${import_name}, '__version__', 'unknown'))" 2>/dev/null)"
        log "OK: ${pkg_name} вже встановлено (версія ${ver})."
    else
        log "УВАГА: ${pkg_name} не знайдено. Спроба встановлення через pip..."
        if command_exists pip3; then
            pip3 install --break-system-packages --quiet "${pkg_name}" >>"${LOG_FILE}" 2>&1
            if python3 -c "import ${import_name}" >/dev/null 2>&1; then
                log "OK: ${pkg_name} успішно встановлено."
            else
                log "ПОМИЛКА: не вдалося встановити ${pkg_name} автоматично."
                log "ІНСТРУКЦІЯ: встановіть вручну -> pip3 install ${pkg_name}"
                STATUS_OK=false
            fi
        else
            log "ІНСТРУКЦІЯ: встановіть pip3, потім виконайте: pip3 install ${pkg_name}"
            STATUS_OK=false
        fi
    fi
}

if command_exists python3; then
    check_or_install_python_pkg "torch" "torch"
    check_or_install_python_pkg "torchvision" "torchvision"
    check_or_install_python_pkg "pillow" "PIL"
else
    log "ПРОПУСК: неможливо перевірити Python-бібліотеки без python3."
    STATUS_OK=false
fi

# ---------------------------------------------------------------------------
# Підсумок
# ---------------------------------------------------------------------------

section "Підсумок перевірки"

if [ "${STATUS_OK}" = true ]; then
    log "УСПІХ: усі компоненти середовища готові до роботи."
    log "Повний лог збережено у: ${LOG_FILE}"
    exit 0
else
    log "УВАГА: деякі компоненти потребують ручного втручання (див. інструкції вище)."
    log "Повний лог збережено у: ${LOG_FILE}"
    exit 1
fi
