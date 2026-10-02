#!/command/with-contenv bash
# shellcheck shell=bash
set -euo pipefail

vault_url="${VAULT_ADDR:-}"
if [[ -z "${vault_url}" ]]; then
    exit 0
fi
vault_url="${vault_url%/}"

app_uid="${APP_UID:-100}"
auth_method="${VAULT_AUTH_METHOD:-gcp}"
auth_path="${VAULT_AUTH_PATH:-gcp}"
auth_role="${VAULT_AUTH_ROLE:-site-workload}"
output_dir="${VAULT_SECRET_OUTPUT_DIR:-/run/secrets}"
overwrite="${VAULT_SECRET_OVERWRITE:-false}"

declare -A existing_secrets=()

log() {
    printf 'vault-secrets: %s\n' "$*" >&2
}

first_set() {
    local value
    for value in "$@"; do
        if [[ -n "${value}" ]]; then
            printf '%s' "${value}"
            return 0
        fi
    done
}

urlencode() {
    jq -nr --arg value "$1" '$value|@uri'
}

base64url() {
    openssl base64 -A | tr '+/' '-_' | tr -d '='
}

valid_vault_name() {
    [[ "$1" =~ ^[A-Za-z0-9._/-]+$ && "$1" != /* && "$1" != *..* && "$1" != *//* ]]
}

valid_secret_name() {
    [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

vault_request() {
    local method="$1"
    local path="$2"
    local token="${3:-}"
    local payload="${4:-}"
    local response_file
    local status
    response_file="$(mktemp)"

    local args=(
        -sS
        -o "${response_file}"
        -w "%{http_code}"
        --request "${method}"
    )

    if [[ -n "${token}" ]]; then
        args+=(--header "X-Vault-Token: ${token}")
    fi

    if [[ -n "${payload}" ]]; then
        args+=(--header "Content-Type: application/json" --data "${payload}")
    fi

    set +e
    status="$(curl "${args[@]}" "${vault_url}/v1/${path}")"
    local curl_status=$?
    set -e

    if [[ ${curl_status} -ne 0 ]]; then
        rm -f "${response_file}"
        return "${curl_status}"
    fi

    if [[ "${status}" =~ ^2 ]]; then
        cat "${response_file}"
        rm -f "${response_file}"
        return 0
    fi

    if [[ "${status}" = "404" ]]; then
        rm -f "${response_file}"
        return 2
    fi

    log "Vault ${method} /v1/${path} failed with HTTP ${status}: $(cat "${response_file}")"
    rm -f "${response_file}"
    return 1
}

metadata_request() {
    curl -fsS \
        --header "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/$1"
}

google_application_credentials_file() {
    if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" && -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
        printf '%s' "${GOOGLE_APPLICATION_CREDENTIALS}"
        return 0
    fi

    if [[ -f /run/secrets/GOOGLE_APPLICATION_CREDENTIALS ]]; then
        printf '%s' /run/secrets/GOOGLE_APPLICATION_CREDENTIALS
        return 0
    fi

    if [[ -f /secrets/GOOGLE_APPLICATION_CREDENTIALS ]]; then
        printf '%s' /secrets/GOOGLE_APPLICATION_CREDENTIALS
        return 0
    fi

    if [[ -f ./secrets/GOOGLE_APPLICATION_CREDENTIALS ]]; then
        printf '%s' ./secrets/GOOGLE_APPLICATION_CREDENTIALS
        return 0
    fi

    return 0
}

google_application_credentials_value() {
    local field="$1"
    local credentials_file="$2"
    jq -er ".${field}" "${credentials_file}"
}

google_application_credentials_project_id() {
    local credentials_file
    credentials_file="$(google_application_credentials_file)"
    if [[ -z "${credentials_file}" ]]; then
        return 0
    fi

    google_application_credentials_value project_id "${credentials_file}" || true
}

vault_gcp_json_key_jwt() {
    local credentials_file="$1"
    local service_account
    local key_id
    local expiration
    local header
    local claim
    local signing_input
    local signature
    local private_key_file

    service_account="$(google_application_credentials_value client_email "${credentials_file}")"
    key_id="$(google_application_credentials_value private_key_id "${credentials_file}")"
    expiration="$(($(date +%s) + ${VAULT_GCP_JWT_TTL:-600}))"
    header="$(jq -n --arg key_id "${key_id}" '{alg: "RS256", typ: "JWT", kid: $key_id}')"
    claim="$(jq -n \
        --arg audience "vault/${auth_role}" \
        --arg subject "${service_account}" \
        --argjson expiration "${expiration}" \
        '{aud: $audience, sub: $subject, exp: $expiration}')"
    signing_input="$(printf '%s' "${header}" | base64url).$(printf '%s' "${claim}" | base64url)"

    private_key_file="$(mktemp)"
    chmod 0400 "${private_key_file}"
    google_application_credentials_value private_key "${credentials_file}" > "${private_key_file}"

    set +e
    signature="$(printf '%s' "${signing_input}" | openssl dgst -sha256 -sign "${private_key_file}" -binary | base64url)"
    local sign_status=$?
    set -e
    rm -f "${private_key_file}"

    if [[ ${sign_status} -ne 0 ]]; then
        return "${sign_status}"
    fi

    printf '%s.%s' "${signing_input}" "${signature}"
}

vault_gcp_gce_jwt() {
    local audience
    local service_account
    audience="${VAULT_GCP_AUDIENCE:-vault/${auth_role}}"
    service_account="${VAULT_GCP_SERVICE_ACCOUNT:-default}"
    metadata_request "instance/service-accounts/${service_account}/identity?audience=$(urlencode "${audience}")&format=full"
}

vault_gcp_iam_jwt() {
    local credentials_file
    local service_account
    local access_token
    local expiration
    local claim
    local response

    credentials_file="$(google_application_credentials_file)"
    if [[ -n "${credentials_file}" ]]; then
        vault_gcp_json_key_jwt "${credentials_file}"
        return 0
    fi

    service_account="$(first_set "${VAULT_GCP_SERVICE_ACCOUNT_EMAIL:-}" "${GOOGLE_SERVICE_ACCOUNT_EMAIL:-}")"
    if [[ -z "${service_account}" ]]; then
        service_account="$(metadata_request "instance/service-accounts/${VAULT_GCP_SERVICE_ACCOUNT:-default}/email")"
    fi

    access_token="$(metadata_request "instance/service-accounts/${VAULT_GCP_SERVICE_ACCOUNT:-default}/token" | jq -er '.access_token')"
    expiration="$(($(date +%s) + ${VAULT_GCP_JWT_TTL:-600}))"
    claim="$(jq -n \
        --arg audience "vault/${auth_role}" \
        --arg subject "${service_account}" \
        --argjson expiration "${expiration}" \
        '{aud: $audience, sub: $subject, exp: $expiration}')"

    response="$(curl -fsS \
        --header "Authorization: Bearer ${access_token}" \
        --header "Content-Type: application/json" \
        --data "$(jq -n --arg payload "${claim}" '{payload: $payload}')" \
        "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/$(urlencode "${service_account}"):signJwt")"

    printf '%s' "${response}" | jq -er '.signedJwt'
}

vault_login_gcp() {
    local jwt
    local response

    case "${VAULT_GCP_AUTH_TYPE:-iam}" in
        gce)
            jwt="$(vault_gcp_gce_jwt)"
            ;;
        iam)
            jwt="$(vault_gcp_iam_jwt)"
            ;;
        *)
            log "unsupported VAULT_GCP_AUTH_TYPE=${VAULT_GCP_AUTH_TYPE}"
            return 1
            ;;
    esac

    response="$(vault_request "POST" "auth/${auth_path}/login" "" "$(jq -n --arg role "${auth_role}" --arg jwt "${jwt}" '{role: $role, jwt: $jwt}')")"
    printf '%s' "${response}" | jq -er '.auth.client_token'
}

vault_token() {
    if [[ -n "${VAULT_TOKEN_FILE:-}" && -f "${VAULT_TOKEN_FILE}" ]]; then
        cat "${VAULT_TOKEN_FILE}"
        return 0
    fi

    if [[ -f /run/secrets/VAULT_TOKEN ]]; then
        cat /run/secrets/VAULT_TOKEN
        return 0
    fi

    if [[ -n "${VAULT_TOKEN:-}" ]]; then
        printf '%s' "${VAULT_TOKEN}"
        return 0
    fi

    case "${auth_method}" in
        gcp)
            vault_login_gcp
            ;;
        token)
            log "VAULT_AUTH_METHOD=token requires VAULT_TOKEN, VAULT_TOKEN_FILE, or /run/secrets/VAULT_TOKEN"
            return 1
            ;;
        *)
            log "unsupported VAULT_AUTH_METHOD=${auth_method}"
            return 1
            ;;
    esac
}

scope_path() {
    case "$1" in
        organization)
            first_set
            ;;
        project)
            first_set \
                "${LIBOPS_PROJECT_ID:-}" \
                "$(google_application_credentials_project_id)"
            ;;
        site)
            first_set "${LIBOPS_SITE_ID:-}"
            ;;
    esac
}

path_join() {
    local parent="$1"
    local child="$2"
    if [[ -n "${parent}" ]]; then
        printf '%s/%s' "${parent%/}" "${child}"
    else
        printf '%s' "${child}"
    fi
}

metadata_path() {
    local mount="$1"
    local path="$2"
    if [[ -n "${path}" ]]; then
        printf '%s/metadata/%s?exclude_deleted=true' "${mount}" "${path}"
    else
        printf '%s/metadata?exclude_deleted=true' "${mount}"
    fi
}

data_path() {
    local mount="$1"
    local path="$2"
    local name="$3"
    printf '%s/data/%s' "${mount}" "$(path_join "${path}" "${name}")"
}

write_secret_file() {
    local name="$1"
    local response="$2"
    local target="${output_dir}/${name}"
    local tmp

    if [[ -n "${existing_secrets[${name}]:-}" && "${overwrite}" != "true" ]]; then
        log "leaving existing secret file ${target}"
        return 0
    fi

    tmp="$(mktemp "${output_dir}/.${name}.XXXXXX")"
    if ! printf '%s' "${response}" | jq -erj '.data.data.value' > "${tmp}"; then
        rm -f "${tmp}"
        log "skipping ${name}; Vault secret does not contain data.value"
        return 0
    fi

    chmod 0400 "${tmp}"
    if [[ "$(id -u)" = "0" ]]; then
        if [[ "${name}" = "DB_ROOT_PASSWORD" ]]; then
            chown 0:0 "${tmp}"
        else
            chown "${app_uid}:0" "${tmp}"
        fi
    fi
    mv -f "${tmp}" "${target}"
}

import_scope() {
    local scope="$1"
    local mount="$2"
    local path="$3"
    local token="$4"
    local list_response
    local list_status
    local name
    local secret_response

    if [[ -z "${mount}" ]]; then
        return 0
    fi

    if ! valid_vault_name "${mount}" || ! valid_vault_name "${path:-x}"; then
        log "invalid Vault ${scope} mount/path: ${mount}/${path}"
        return 1
    fi

    set +e
    list_response="$(vault_request "LIST" "$(metadata_path "${mount}" "${path}")" "${token}")"
    list_status=$?
    set -e

    if [[ ${list_status} -eq 2 ]]; then
        log "no ${scope} secrets found at ${mount}/${path}"
        return 0
    fi

    if [[ ${list_status} -ne 0 ]]; then
        return "${list_status}"
    fi

    while IFS= read -r name; do
        if [[ "${name}" = */ ]]; then
            log "skipping nested Vault secret folder ${mount}/${path}/${name}"
            continue
        fi

        if ! valid_secret_name "${name}"; then
            log "skipping Vault secret ${mount}/${path}/${name}; secret names must be environment-compatible"
            continue
        fi

        secret_response="$(vault_request "GET" "$(data_path "${mount}" "${path}" "${name}")" "${token}")"
        write_secret_file "${name}" "${secret_response}"
    done < <(printf '%s' "${list_response}" | jq -er '.data.keys[]?' || true)
}

mkdir -p "${output_dir}"
for file in "${output_dir}"/*; do
    if [[ -f "${file}" ]]; then
        existing_secrets["$(basename "${file}")"]=1
    fi
done

token="$(vault_token)"

organization_path="$(scope_path organization)"
project_path="$(scope_path project)"
site_path="$(scope_path site)"

import_scope organization "${VAULT_ORGANIZATION_SECRET_MOUNT:-secret-organization}" "${organization_path}" "${token}"

if [[ -n "${project_path}" ]]; then
    import_scope project "${VAULT_PROJECT_SECRET_MOUNT:-secret-project}" "${project_path}" "${token}"
else
    log "skipping project secrets; no project id configured"
fi

if [[ -n "${site_path}" ]]; then
    import_scope site "${VAULT_SITE_SECRET_MOUNT:-secret-site}" "${site_path}" "${token}"
else
    log "skipping site secrets; no site id configured"
fi
