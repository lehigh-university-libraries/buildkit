#!/command/with-contenv bash
# shellcheck shell=bash

# shellcheck disable=SC1091
source /usr/local/share/isle/utilities.sh

# Check environment variables match expectations otherwise exit non-zero.
#
# For each level we specify an a value for that level and all levels that are
# lower precedence than it. We then check to see that precedence holds as
# expected:
#
#  1. Secrets kept in /run/secrets
#  2. Environment variables passed into the container
#  3. Environment variables defined in Dockerfile(s)
#  4. Environment variables defined in the /etc/defaults directory (lowest only used for multiline variables)

# For ease of reading overridden values follow the format:
# ENV_VAR_NAME="ENV_VAR_NAME SOURCE value"
expect "JWT_ADMIN_TOKEN" "JWT_ADMIN_TOKEN secret value"       # Secret should take precedence
expect "DB_PASSWORD" 'DB_PASSWORD secret "quote" \ value'     # Secret should take precedence and preserve special characters
expect "GOOGLE_APPLICATION_CREDENTIALS" "/run/secrets/GOOGLE_APPLICATION_CREDENTIALS" # Google credentials should remain file based
expect "DB_NAME" "DB_NAME passed in value"                    # Environment passed into the container should take precedence
expect "DB_USER" "default"                                    # Environment variables defined in Dockerfile should take precedence
expect "JWT_PUBLIC_KEY" "$(cat /etc/defaults/JWT_PUBLIC_KEY)" # Unspecified /etc/defaults value is used.

# Check templated output from environment-backed confd matches expectations.
diff /opt/keys/jwt/syn-settings.xml <(sed -e "s|{{ getenv \"JWT_ADMIN_TOKEN\" }}|${JWT_ADMIN_TOKEN}|" /etc/confd/templates/syn-settings.xml.tmpl)

# Check templated output from secrets matches expectations.
diff /opt/keys/jwt/private.key <(echo -n "${JWT_PRIVATE_KEY}")

# All tests were successful
exit 0
