#!/usr/bin/env bash

set -euo pipefail

trap 'exit 130' INT

: "${HOME:?HOME must be set}"
: "${USER_NAME:?USER_NAME must be set}"
: "${WORKSPACE_DIR:?WORKSPACE_DIR must be set}"
readonly HOME USER_NAME WORKSPACE_DIR

if (("$(id -u)" == 0)); then
  user_uid="$(id -u "${USER_NAME}")"
  user_gid="$(id -g "${USER_NAME}")"
  mkdir -p /run/dbus
  if [[ ! -S /run/dbus/system_bus_socket ]]; then
    dbus-daemon --system --fork
  fi
  if [[ "$(stat -c '%u:%g' "${HOME}")" != "${user_uid}:${user_gid}" ]]; then
    chown "${USER_NAME}:${USER_NAME}" "${HOME}"
  fi
  if [[ -d /opt/home-skel && -z "$(ls -A "${HOME}" 2> /dev/null)" ]]; then
    cp -a /opt/home-skel/. "${HOME}/"
    chown -R "${USER_NAME}:${USER_NAME}" "${HOME}"
  fi
  exec setpriv --reuid="${USER_NAME}" --regid="${USER_NAME}" --init-groups \
    env USER="${USER_NAME}" LOGNAME="${USER_NAME}" "${BASH_SOURCE[0]}" "${@}"
fi

readonly VNC_CONFIG_DIR="${HOME}/.config/tigervnc"

if [[ -d "${WORKSPACE_DIR}" ]] && [[ ! -w "${WORKSPACE_DIR}" ]]; then
  printf 'WARNING: %s is not writable; the workspace may be read-only.\n' \
    "${WORKSPACE_DIR}" >&2
fi

if ((${#} > 0)); then
  exec "${@}"
fi

: "${VNC_PASSWORD:?VNC_PASSWORD must be set}"

mkdir -p "${VNC_CONFIG_DIR}"
printf '%s\n' "${VNC_PASSWORD}" | vncpasswd -f > "${VNC_CONFIG_DIR}/passwd"
chmod 600 "${VNC_CONFIG_DIR}/passwd"

cat > "${VNC_CONFIG_DIR}/xstartup" << 'EOF'
#!/usr/bin/env bash

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-run-session -- startxfce4
EOF
chmod +x "${VNC_CONFIG_DIR}/xstartup"

vncserver "${DISPLAY}" \
  -geometry "${VNC_GEOMETRY}" \
  -depth "${VNC_DEPTH}" \
  -localhost no

readonly -a NOVNC_ARGS=(
  --web=/usr/share/novnc
  "0.0.0.0:${NOVNC_PORT}"
  localhost:5901
)

if [[ "${ACLD_ORACLE_SERVE:-0}" == 1 ]]; then
  : "${ORACLE_SERVE_PORT:?ORACLE_SERVE_PORT must be set}"
  oracle_service_pids=()
  oracle_service_signal_received=''

  # Invoked indirectly by the TERM and INT traps below.
  # shellcheck disable=SC2329
  oracle_service_signal() {
    oracle_service_signal_received="${1}"
    if [[ "${1}" == INT ]]; then
      oracle_service_kill_children TERM
    else
      oracle_service_kill_children "${1}"
    fi
  }

  oracle_service_kill_children() {
    local signal="${1}"
    local pid

    for pid in "${oracle_service_pids[@]}"; do
      kill "-${signal}" "${pid}" 2> /dev/null || true
    done
  }

  oracle_service_stop_children() {
    local signal="${1}"
    local pid

    oracle_service_kill_children "${signal}"
    for pid in "${oracle_service_pids[@]}"; do
      wait "${pid}" 2> /dev/null || true
    done
  }

  run_oracle_services() {
    local exit_status
    local stop_signal

    trap 'oracle_service_signal TERM' TERM
    trap 'oracle_service_signal INT' INT

    (
      trap - INT
      exec websockify "${NOVNC_ARGS[@]}"
    ) &
    oracle_service_pids+=("$!")
    (
      trap - INT
      exec oracle serve --host 0.0.0.0 --manual-login --port "${ORACLE_SERVE_PORT}"
    ) &
    oracle_service_pids+=("$!")

    if [[ -n "${oracle_service_signal_received}" ]]; then
      exit_status=0
    elif wait -n "${oracle_service_pids[@]}"; then
      exit_status=0
    else
      exit_status=$?
    fi

    if [[ "${oracle_service_signal_received}" == INT ]]; then
      stop_signal=TERM
    else
      stop_signal="${oracle_service_signal_received:-TERM}"
    fi
    oracle_service_stop_children "${stop_signal}"
    trap - TERM INT

    if [[ -n "${oracle_service_signal_received}" ]]; then
      if [[ "${oracle_service_signal_received}" == INT ]]; then
        exit_status=130
      else
        exit_status=143
      fi
    elif ((exit_status == 0)); then
      exit_status=1
    fi
    return "${exit_status}"
  }
  if run_oracle_services; then
    exit 0
  else
    exit $?
  fi
fi

exec websockify "${NOVNC_ARGS[@]}"
