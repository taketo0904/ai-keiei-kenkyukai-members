variable "account_id" {
  description = "Cloudflare のアカウントID（ダッシュボード右下、または URL の /accounts/<ここ>）"
  type        = string
}

variable "app_domain" {
  description = "保護するホスト名。例 members.example.jp または ai-keiei.pages.dev"
  type        = string
}

variable "member_emails" {
  description = "会員のメールアドレス。infra/scripts/gen-allowlist.sh が生成する allowlist.tfvars を使う"
  type        = list(string)
}

variable "staff_emails" {
  description = "事務局（管理者）のメールアドレス"
  type        = list(string)
  default     = []
}

variable "session_duration" {
  description = "ログインの有効期間。provider 5.24.0 以降は既定値がないため明示する"
  type        = string
  default     = "720h" # 30日
}
