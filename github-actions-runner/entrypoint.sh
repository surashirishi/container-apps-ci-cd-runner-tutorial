#!/bin/bash -l

# 以下の環境変数を利用して処理を行います。事前に container app ジョブ側の環境変数の設定が必要です。
# $PEM_KEY
# $GITHUB_APP_ID
# $GITHUB_OWNER
# $REPOS

# 以下にて、環境変数に指定している Github Apps の秘密鍵から jwt トークンの取得 -> インストール ID の取得 -> Github App トークンを取得します。
echo "$PEM_KEY" > github_app_private_key.pem

set -o pipefail
client_id=$GITHUB_APP_ID # Client ID as first argument

now=$(date +%s)
iat=$((${now} - 60)) # Issues 60 seconds in the past
exp=$((${now} + 600)) # Expires 10 minutes in the future

b64enc() { openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }

header_json='{
    "typ":"JWT",
    "alg":"RS256"
}'
# Header encode
header=$( echo -n "${header_json}" | b64enc )

payload_json='{
    "iat":'"${iat}"',
    "exp":'"${exp}"',
    "iss":'"${client_id}"'
}'
# Payload encode
payload=$( echo -n "${payload_json}" | b64enc )

# Signature
header_payload="${header}"."${payload}"
signature=$(
    openssl dgst -sha256 -sign ./github_app_private_key.pem \
    <(echo -n "${header_payload}") | b64enc
)

# Create JWT
jwt="${header_payload}"."${signature}"
printf '%s\n' "JWT: $jwt"

installation_id="$(curl --location --silent --request GET \
  --url "https://api.github.com/users/$GITHUB_OWNER/installation" \
  --header "Accept: application/vnd.github+json" \
  --header "X-GitHub-Api-Version: 2022-11-28" \
  --header "Authorization: Bearer $jwt" \
  | jq -r '.id'
)"

echo "installation_id is: $installation_id"

token="$(curl --location --silent --request POST \
  --url "https://api.github.com/app/installations/$installation_id/access_tokens" \
  --header "Accept: application/vnd.github+json" \
  --header "X-GitHub-Api-Version: 2022-11-28" \
  --header "Authorization: Bearer $jwt" \
  | jq -r '.token'
)"

echo "token is: $token"

registration_token="$(curl -X POST -fsSL \
  -H 'Accept: application/vnd.github.v3+json' \
  -H "Authorization: Bearer $token" \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runners/registration-token" \
  | jq -r '.token')"
echo "registration_token is: $registration_token"
echo "url is: https://github.com/$GITHUB_OWNER/$GITHUB_REPO"

# 取得したトークンでGithubリポジトリへアクセスします
./config.sh --url https://github.com/$GITHUB_OWNER/$GITHUB_REPO --token $registration_token --unattended --ephemeral && ./run.sh
