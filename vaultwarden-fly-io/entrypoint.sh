#!/bin/sh

set -eu

. /lib.sh

#
# Business logic
#

VAULTWARDEN_CONFIG_PATH=/data/config.json

mount_s3() {
  # Mount data directories that should be stored in S3. Note that we do not need to use SSE-C because Vaultwarden
  # already encrypts these data files (except for the icon cache, but who cares).
  if [ "${GEESEFS_ENABLED:-true}" = "true" ]; then
    # NOTE: We configure Vaultwarden from the default data directory paths (e.g. /data/attachments, /data/icon_cache)
    #       to directories inside /data/files instead, for two reasons:
    #       (1) Vaultwarden's startup procedure uses std::fs::create_dir_all() which seems to error if the directory
    #           already exists; I can't explain how this does NOT error when Vaultwarden is run with a persistent
    #           disk that does not use mounts for these directories, but something behaves differently if the actual
    #           target directory is a mount.
    #       (2) This allows GeeseFS to share the same memory limit across all data files served and we only need to
    #           spawn a single GeeseFS process.
    #       Also, using --uid 100 causes that even root gets permission errors when accessing the directory, so instead
    #       we do not use this option, keep the file owner as root and run Vaultwarden as root (:sadface:).
    info "setting up S3 mountpoints"
    mkdir -p /mnt/s3
    GEESEFS_MEMORY_LIMIT=${GEESEFS_MEMORY_LIMIT:-64}
    info_run geesefs --memory-limit "$GEESEFS_MEMORY_LIMIT" --endpoint "$AWS_ENDPOINT_URL_S3" "$BUCKET_NAME:data/" /mnt/s3
  else
    warn "GeeseFS is disabled, certain data directories are not persisted."
  fi
}

write_rsa_key() {
  # Write the RSA key that is used to sign authentication tokens.
  info "writing /data/rsa_key.pem and /data/rsa_key.pub.pem"
  assert_is_set VAULTWARDEN_RSA_PRIVATE_KEY
  echo "$VAULTWARDEN_RSA_PRIVATE_KEY" >/data/rsa_key.pem
  openssl rsa -in /data/rsa_key.pem -pubout >/data/rsa_key.pub.pem
}

write_config() {
  # Generate admin configuration from environment variables. Only non-default settings are written;
  # everything else falls back to Vaultwarden's built-in defaults.
  VAULTWARDEN_DOMAIN="${VAULTWARDEN_DOMAIN:-https://${FLY_APP_NAME}.fly.dev}"
  assert_is_set VAULTWARDEN_ADMIN_TOKEN

  # shellcheck disable=SC2086
  entries="\"log_timestamp_format\": \"%Y-%m-%d %H:%M:%S.%3f\"
\"attachments_folder\": \"/mnt/s3/attachments\"
\"icon_cache_folder\": \"/mnt/s3/icon_cache\"
\"sends_folder\": \"/mnt/s3/sends\"
\"domain\": \"${VAULTWARDEN_DOMAIN}\"
\"hibp_api_key\": \"${VAULTWARDEN_HIBP_API_KEY:-}\"
\"incomplete_2fa_time_limit\": 3
\"show_password_hint\": ${VAULTWARDEN_SHOW_PASSWORD_HINT:-false}
\"admin_token\": \"${VAULTWARDEN_ADMIN_TOKEN}\"
\"ip_header\": \"${VAULTWARDEN_IP_HEADER:-X-Real-IP}\"
\"icon_redirect_code\": 302
\"icon_blacklist_non_global_ips\": true
\"use_sendmail\": ${VAULTWARDEN_USE_SENDMAIL:-false}"

  if [ "${VAULTWARDEN_ENABLE_SMTP:-false}" = "true" ]; then
    assert_is_set VAULTWARDEN_SMTP_HOST
    assert_is_set VAULTWARDEN_SMTP_FROM
    assert_is_set VAULTWARDEN_SMTP_USERNAME
    assert_is_set VAULTWARDEN_SMTP_PASSWORD
    entries="$entries
\"smtp_host\": \"${VAULTWARDEN_SMTP_HOST}\"
\"smtp_security\": \"${VAULTWARDEN_SMTP_SECURITY:-force_tls}\"
\"smtp_port\": ${VAULTWARDEN_SMTP_PORT:-465}
\"smtp_from\": \"${VAULTWARDEN_SMTP_FROM}\"
\"smtp_from_name\": \"${VAULTWARDEN_SMTP_FROM_NAME:-Vaultwarden}\"
\"smtp_username\": \"${VAULTWARDEN_SMTP_USERNAME}\"
\"smtp_password\": \"${VAULTWARDEN_SMTP_PASSWORD}\"
\"_enable_email_2fa\": ${VAULTWARDEN_ENABLE_EMAIL_2FA:-true}"
  fi

  if [ -n "${VAULTWARDEN_PUSH_INSTALLATION_ID:-}" ]; then
    assert_is_set VAULTWARDEN_PUSH_INSTALLATION_KEY
    entries="$entries
\"push_installation_id\": \"${VAULTWARDEN_PUSH_INSTALLATION_ID}\"
\"push_installation_key\": \"${VAULTWARDEN_PUSH_INSTALLATION_KEY}\""
  fi

  if [ "${VAULTWARDEN_ENABLE_YUBICO:-false}" = "true" ]; then
    assert_is_set VAULTWARDEN_YUBICO_CLIENT_ID
    assert_is_set VAULTWARDEN_YUBICO_SECRET_KEY
    entries="$entries
\"_enable_yubico\": true
\"yubico_client_id\": \"${VAULTWARDEN_YUBICO_CLIENT_ID}\"
\"yubico_secret_key\": \"${VAULTWARDEN_YUBICO_SECRET_KEY}\""
  fi

  info "writing $VAULTWARDEN_CONFIG_PATH"
  printf '{\n' >$VAULTWARDEN_CONFIG_PATH
  echo "$entries" | sed 's/^/  /; s/$/,/' >>$VAULTWARDEN_CONFIG_PATH
  printf '  "admin_session_lifetime": 20\n}\n' >>$VAULTWARDEN_CONFIG_PATH

  # Prevent writing to the config.json, the admin panel should only serve as point to view settings.
  chmod -w $VAULTWARDEN_CONFIG_PATH
}

validate_config() {
  # Validate the JSON file syntax. This is a sanity check that should prevent successful startup if we made a mistake
  # in the JSON syntax, as Vaultwarden will not complain and simply not load the file.
  info "validating $VAULTWARDEN_CONFIG_PATH syntax"
  if ! jq < $VAULTWARDEN_CONFIG_PATH >/dev/null; then
    error "we made a mistake in $VAULTWARDEN_CONFIG_PATH, please file a bug report"
    exit 1
  fi
}

maybe_idle() {
  if [ "${ENTRYPOINT_IDLE:-false}" = "true" ]; then
    info "ENTRYPOINT_IDLE=true, entering idle state"
    sleep infinity
  fi
}

on_error() {
  [ $? -eq 0 ] && exit
  error "an unexpected error occurred."
  maybe_idle
}

trap 'on_error' EXIT

main() {
  mount_s3
  write_rsa_key
  write_config
  validate_config
  maybe_idle
  export I_REALLY_WANT_VOLATILE_STORAGE=true
  export BUCKET_PATH="vaultwarden.db"
  export LITESTREAM_DATABASE_PATH=/data/db.sqlite3
  info_run exec /litestream-entrypoint.sh "/vaultwarden"
}

main "$@"
