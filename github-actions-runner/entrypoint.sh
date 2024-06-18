#!/bin/sh -l

# # 以下の環境変数を利用して処理を行います。事前に container app ジョブ側の環境変数の設定が必要です。
# # $PEM_KEY
# # $GITHUB_APP_ID
# # $GITHUB_OWNER
# # $REPOS

# # 以下にて、環境変数に指定している Github Apps の秘密鍵から jwt トークンの取得 -> インストール ID の取得 -> Github App トークンを取得します。
# echo "$PEM_KEY" > github_app_private_key.pem

# base64url() {
#   openssl enc -base64 -A | tr '+/' '-_' | tr -d '='
# }
# sign() {
#   openssl dgst -binary -sha256 -sign ./github_app_private_key.pem
# }

# # echo "PEM_KEY is: $PEM_KEY"
# header="$(printf '{"alg":"RS256","typ":"JWT"}' | base64url)"
# now="$(date '+%s')"
# iat="$((now - 60))"
# exp="$((now + (3 * 60)))"
# template='{"iss":"%s","iat":%s,"exp":%s}'
# payload="$(printf "$template" "$GITHUB_APP_ID" "$iat" "$exp" | base64url)"
# signature="$(printf '%s' "$header.$payload" | sign | base64url)"
# jwt="$header.$payload.$signature"

# echo "header is: $header"
# echo "payload is: $payload"
# echo "signature is: $signature"
# echo "jwt is: $jwt"
# echo "below is file github_app_private_key.pem content."
# cat ./github_app_private_key.pem

echo "start original sh"
# 設定する値
APP_ID="$GITHUB_APP_ID" # GitHub AppのID

# JWTの有効期限（10分）
CURRENT_TIME=$(date +%s)
EXPIRATION_TIME=$(($CURRENT_TIME + 600))

# JWTのヘッダーとペイロードを作成
HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | openssl base64 -A | tr -d '=' | tr '/+' '_-' | tr -d '\n')
PAYLOAD=$(printf '{"iat":%s,"exp":%s,"iss":"%s"}' "$CURRENT_TIME" "$EXPIRATION_TIME" "$APP_ID" | openssl base64 -A | tr -d '=' | tr '/+' '_-' | tr -d '\n')

# データを署名する
HEADER_PAYLOAD="$HEADER.$PAYLOAD"
SIGNATURE=$(printf '%s' "$HEADER_PAYLOAD" | openssl dgst -sha256 -sign ./github_app_private_key.pem | openssl base64 -A | tr -d '=' | tr '/+' '_-' | tr -d '\n')

# 完全なJWTトークンを構築する
$jwt="$HEADER_PAYLOAD.$SIGNATURE"

echo "Generated JWT: $jwt"

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

# registration_token2="$(curl -X POST -fsSL \
#   -H 'Accept: application/vnd.github.v3+json' \
#   -H "Authorization: Bearer $token" \
#   -H 'X-GitHub-Api-Version: 2022-11-28' \
#   "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO2/actions/runners/registration-token" \
#   | jq -r '.token')"
# echo "registration_token is: $registration_token2"
# echo "url is: https://github.com/$GITHUB_OWNER/$GITHUB_REPO2"

# 取得したトークンでGithubリポジトリへアクセスします
./config.sh --url https://github.com/$GITHUB_OWNER/$GITHUB_REPO --token $registration_token --unattended --ephemeral && ./run.sh
# ./config.sh --url https://github.com/$GITHUB_OWNER/$GITHUB_REPO2 --token $registration_token2 --unattended --ephemeral && ./run.sh

# ',' を区切り文字として、環境変数を配列に分割
# echo "REPOS is: $REPOS"
# IFS=',' read -r -a repos_array <<< "$REPOS"

# echo "repos_array is: $repos_array"

# # 配列の要素数分だけループ
# for repo in "${repos_array[@]}"
# do
#     echo "Current variable: $repo"
#     # ここに環境変数ごとに実行したい処理を記述
#     registration_token="$(curl -X POST -fsSL \
#       -H 'Accept: application/vnd.github.v3+json' \
#       -H "Authorization: Bearer $token" \
#       -H 'X-GitHub-Api-Version: 2022-11-28' \
#       "https://api.github.com/repos/$GITHUB_OWNER/$repo/actions/runners/registration-token" \
#       | jq -r '.token')"
    
#     echo "registration_token is: $registration_token"
#     echo "url is: https://github.com/$GITHUB_OWNER/$repo"
#     # 取得したトークンでGithubリポジトリへアクセスします
#     ./config.sh --url https://github.com/$GITHUB_OWNER/$repo --token $registration_token --unattended --ephemeral && ./run.sh
# done
