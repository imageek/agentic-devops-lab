# shellcheck shell=bash
# Local TLS servers for the cert-expiry tests. No network: everything listens
# on 127.0.0.1, on a port the OS picks.
#
# `openssl ca` is used because it can set an exact expiry date on every
# OpenSSL we run on (OpenSSL 3.0 on CI can't do that with `req -x509`).

# start_tls_server NAME ENDDATE
#   Serves a self-signed cert for CN=localhost that expires at ENDDATE
#   (YYYYMMDDHHMMSSZ) and exports NAME=127.0.0.1:<port>.
start_tls_server() {
  local name=$1 enddate=$2
  local dir="$BATS_FILE_TMPDIR/$name"
  mkdir -p "$dir/newcerts"
  : >"$dir/index.txt"
  echo 01 >"$dir/serial"
  cat >"$dir/ca.cnf" <<CNF
[ca]
default_ca = lab
[lab]
dir = $dir
database = $dir/index.txt
new_certs_dir = $dir/newcerts
serial = $dir/serial
default_md = sha256
policy = anything
[anything]
commonName = supplied
CNF
  openssl req -new -newkey rsa:2048 -nodes -subj /CN=localhost \
    -keyout "$dir/key.pem" -out "$dir/req.pem" 2>/dev/null
  openssl ca -config "$dir/ca.cnf" -batch -notext -selfsign \
    -keyfile "$dir/key.pem" -in "$dir/req.pem" -out "$dir/cert.pem" \
    -startdate 20250101000000Z -enddate "$enddate" 2>/dev/null

  # Close fd 3 too, or bats waits for the server to exit before finishing.
  openssl s_server -accept 0 -www -cert "$dir/cert.pem" -key "$dir/key.pem" \
    </dev/null >"$dir/server.log" 2>&1 3>&- &
  echo "$!" >>"$BATS_FILE_TMPDIR/server.pids"

  local port="" _
  for _ in {1..50}; do
    port=$(sed -n 's/^ACCEPT .*:\([0-9]*\)$/\1/p' "$dir/server.log")
    [[ -n "$port" ]] && break
    sleep 0.1
  done
  [[ -n "$port" ]] || { cat "$dir/server.log" >&2; return 1; }
  export "$name=127.0.0.1:$port"
}

stop_tls_servers() {
  local pids="$BATS_FILE_TMPDIR/server.pids"
  [[ -f "$pids" ]] || return 0
  # shellcheck disable=SC2046  # one PID per word is what kill wants
  kill $(cat "$pids") 2>/dev/null || true
}

# start_silent_server NAME
#   Accepts TCP connections and never answers, like a hung TLS endpoint.
#   Exports NAME=127.0.0.1:<port>. python3 because nc's flags differ between
#   macOS and Linux, and neither reports an OS-picked port reliably.
start_silent_server() {
  local name=$1
  local dir="$BATS_FILE_TMPDIR/$name"
  mkdir -p "$dir"
  python3 -c '
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
s.listen()
print(s.getsockname()[1], flush=True)
held = []
while True:
    held.append(s.accept()[0])  # keep each connection open, say nothing
' >"$dir/port" 2>&1 3>&- &
  echo "$!" >>"$BATS_FILE_TMPDIR/server.pids"

  local port="" _
  for _ in {1..50}; do
    port=$(cat "$dir/port")
    [[ "$port" =~ ^[0-9]+$ ]] && break
    sleep 0.1
  done
  [[ "$port" =~ ^[0-9]+$ ]] || { cat "$dir/port" >&2; return 1; }
  export "$name=127.0.0.1:$port"
}
