# Shared helpers for the entrypoint scripts. Sourced, not executed.

info() {
  >&2 echo "[$0 |  INFO]:" "$@"
}

warn() {
  >&2 echo "[$0 |  WARN]:" "$@"
}

error() {
  >&2 echo "[$0 | ERROR]:" "$@"
}

info_run() {
  info "$@"
  "$@"
}

assert_is_set() {
  eval "val=\${$1+x}"
  if [ -z "$val" ]; then
    error "missing expected environment variable \"$1\""
    exit 1
  fi
}
