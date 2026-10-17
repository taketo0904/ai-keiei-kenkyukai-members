terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      # v5 系。v4 からはリソース名とポリシーの書き方が変わっている。
      # 移行ガイド: https://github.com/cloudflare/terraform-provider-cloudflare/blob/main/docs/guides/version-5-migration.md
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  # 環境変数 CLOUDFLARE_API_TOKEN で渡すこと。tfvars に書かない。
  # 必要な権限: Account > Access: Apps and Policies > Edit
  #             Account > Access: Organizations, Identity Providers, and Groups > Edit
}
