#!/command/with-contenv bash
# shellcheck shell=bash
set -e

# UID should only be set in the development environments.
if [[ "${DEVELOPMENT_ENVIRONMENT}" != "true" ]]; then
  exit 0
fi

if [[ -z "${UID}" ]]; then
  exit 0
fi

# ensure no new lines or other non-digits
UID=$(echo "${UID}" | tr -cd '0-9')

if [ "${UID}" = "0" ]; then
  exit 0
fi

# Get the current user for this UID (if any) - don't fail if not found
EXISTING_USER=$(getent passwd "${UID}" 2>/dev/null | cut -d: -f1 || true)

if [ -z "$EXISTING_USER" ]; then
  # UID doesn't exist, safe to change nginx user
  usermod -u "${UID}" nginx
elif [ "$EXISTING_USER" != "nginx" ]; then
  # UID exists but belongs to another user
  # Move existing user out of the way
  NEW_UID=$((UID + 10000))
  usermod -u "${NEW_UID}" "$EXISTING_USER" || true
  usermod -u "${UID}" nginx
fi

# Fix writable runtime directories if needed. The application tree is owned in
# the image build and should not be recursively rewritten on every boot.
for writable_dir in \
  /var/www/drupal/private \
  /var/www/drupal/web/sites/default/files; do
  if [ -d "${writable_dir}" ] && [[ "$(stat -c %u "${writable_dir}")" != "${UID}" ]]; then
    chown -R nginx:nginx "${writable_dir}"
  fi
done

# Always ensure nginx has access to the socket
for fpm_dir in /run/php-fpm*; do
  if [ -d "${fpm_dir}" ]; then
    chown -R nginx:nginx "${fpm_dir}"
  fi
done
