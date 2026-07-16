#!/usr/bin/env bash

set -euo pipefail

: "${VNC_PASSWORD:?VNC_PASSWORD must be set}"

# The persistent home volume is empty on its first mount; seed it once from
# the image's default skeleton home. A later start finds it already
# populated and leaves it untouched.
if [[ -d /opt/home-skel && -z "$(ls -A "${HOME}" 2> /dev/null)" ]]; then
  cp -a /opt/home-skel/. "${HOME}/"
fi

# TigerVNC migrates the legacy ~/.vnc directory to ~/.config/tigervnc on
# first start.  Its migration cannot create ~/.config itself.
install -d -m 700 "${HOME}/.config"
install -d -m 700 "${HOME}/.vnc"

printf '%s\n' "${VNC_PASSWORD}" | vncpasswd -f > "${HOME}/.vnc/passwd"
chmod 600 "${HOME}/.vnc/passwd"

cat > "${HOME}/.vnc/xstartup" << EOF
#!/usr/bin/env bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x "${HOME}/.vnc/xstartup"

vncserver "${DISPLAY}" \
  -geometry "${VNC_GEOMETRY}" \
  -depth "${VNC_DEPTH}" \
  -localhost no

exec websockify \
  --web=/usr/share/novnc \
  "0.0.0.0:${NOVNC_PORT}" \
  localhost:5901
