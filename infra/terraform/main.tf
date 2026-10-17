# 建築AI経営研究会 会員サイト — Cloudflare Access の設定
#
# これで何が起きるか:
#   var.app_domain 宛てのリクエストは Cloudflare Access が先に受け、
#   許可リストに載っているメールアドレスでログインした人だけが中身を受け取る。
#   HTML も JSON も画像も、ログインしていない相手には一切渡らない。
#
# 前提: Cloudflare Pages へのデプロイと、独自ドメインを使う場合の
#       ドメイン追加が先に済んでいること（infra/README.md の手順1〜3）。

# ── ログイン方法: メール確認コード（One-time PIN）──────────────────
# 設定項目のない identity provider。会員側に事前準備が要らない。
# 出典: https://developers.cloudflare.com/cloudflare-one/integrations/identity-providers/one-time-pin/
resource "cloudflare_zero_trust_access_identity_provider" "otp" {
  account_id = var.account_id
  name       = "One-time PIN"
  type       = "onetimepin"
  config     = {}
}

# ── 保護するアプリケーション ────────────────────────────────────
# v5 ではポリシーをアプリケーションの policies 属性にインラインで書く
# （v4 の cloudflare_access_policy を別リソースにする書き方は廃止）。
resource "cloudflare_zero_trust_access_application" "members_site" {
  account_id       = var.account_id
  name             = "建築AI経営研究会 会員サイト"
  domain           = var.app_domain
  type             = "self_hosted"
  session_duration = var.session_duration

  # ログイン画面に出す方法を限定する。空にすると全部出る。
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.otp.id]
  auto_redirect_to_identity = false

  app_launcher_visible = false

  policies = [
    {
      name       = "事務局"
      decision   = "allow"
      precedence = 1
      include = [
        # ★要確認: include の書き方は provider のバージョンで変わる。
        #   terraform plan が通らない場合はレジストリの
        #   zero_trust_access_application の policies.include を参照して合わせること。
        for e in var.staff_emails : { email = { email = e } }
      ]
    },
    {
      name       = "会員"
      decision   = "allow"
      precedence = 2
      include = [
        for e in var.member_emails : { email = { email = e } }
      ]
    },
  ]
}

output "application_id" {
  value       = cloudflare_zero_trust_access_application.members_site.id
  description = "作成された Access アプリケーションのID"
}

output "login_url" {
  value       = "https://${var.app_domain}/"
  description = "会員にお渡しするURL"
}
