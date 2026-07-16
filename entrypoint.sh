#!/usr/bin/env bash

set -euo pipefail

: "${HOME:?HOME must be set}"
: "${USER_NAME:?USER_NAME must be set}"
: "${WORKSPACE_DIR:?WORKSPACE_DIR must be set}"
readonly HOME USER_NAME WORKSPACE_DIR

initialize_mounts() {
  local user_gid user_uid

  user_uid="$(id -u "${USER_NAME}")"
  user_gid="$(id -g "${USER_NAME}")"
  if [[ "$(stat -c '%u:%g' "${HOME}")" != "${user_uid}:${user_gid}" ]]; then
    chown "${USER_NAME}:${USER_NAME}" "${HOME}"
  fi
  if [[ -d /opt/home-skel && -z "$(ls -A "${HOME}" 2> /dev/null)" ]]; then
    cp -a /opt/home-skel/. "${HOME}/"
    chown -R "${USER_NAME}:${USER_NAME}" "${HOME}"
  fi
}

if (( "$(id -u)" == 0 )); then
  initialize_mounts
  exec setpriv --reuid="${USER_NAME}" --regid="${USER_NAME}" --init-groups \
    env USER="${USER_NAME}" LOGNAME="${USER_NAME}" \
    "${BASH_SOURCE[0]}" "$@"
fi

readonly VNC_CONFIG_DIR="${HOME}/.config/tigervnc"

if [[ -d "${WORKSPACE_DIR}" ]] && [[ ! -w "${WORKSPACE_DIR}" ]]; then
  printf 'WARNING: %s is not writable; the workspace may be read-only.\n' \
    "${WORKSPACE_DIR}" >&2
fi

if (( ${#} > 0 )); then
  exec "${@}"
fi

: "${VNC_PASSWORD:?VNC_PASSWORD must be set}"

mkdir -p "${VNC_CONFIG_DIR}"
printf '%s\n' "${VNC_PASSWORD}" | vncpasswd -f > "${VNC_CONFIG_DIR}/passwd"
chmod 600 "${VNC_CONFIG_DIR}/passwd"

cat > "${VNC_CONFIG_DIR}/xstartup" << EOF
#!/usr/bin/env bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x "${VNC_CONFIG_DIR}/xstartup"

vncserver "${DISPLAY}" \
  -geometry "${VNC_GEOMETRY}" \
  -depth "${VNC_DEPTH}" \
  -localhost no

exec websockify \
  --web=/usr/share/novnc \
  "0.0.0.0:${NOVNC_PORT}" \
  localhost:5901
