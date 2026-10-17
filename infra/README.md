# 会員サイトの認証 — 引き継ぎ資料

建築AI経営研究会の会員サイトに、Cloudflare Access による認証を入れるための一式です。
インフラご担当者に、この `infra/` 配下と `feature/cloudflare-access` ブランチをお渡しします。

- リポジトリ: https://github.com/taketo0904/ai-keiei-kenkyukai-members
- 作業ブランチ: `feature/cloudflare-access`（**main には入れていません**）
- 現行サイト: https://taketo0904.github.io/ai-keiei-kenkyukai-members/
- 経緯と判断の資料: 中川が別途お渡しする「セキュリティ現状と対応案」

---

## 1. 何を直すのか

**いまのサイトには認証がありません。** ログイン画面はありますが、判定をブラウザ内のJavaScriptで行っているため、次のいずれでも素通りできます。

- データファイルを直接叩く（`.../members.json` をアドレス欄に入れるだけで会員20名の氏名・会社名・メールアドレス・各社の売上高が返ります）
- ログイン画面に表示されていたパスワードを読む（本ブランチで撤去済み）

静的サイトである以上、フロントエンドの改修では直りません。**サーバー side でリクエストを止める必要があり、そこをお願いしたい**というのが今回の依頼です。

### 守る対象

`https://<ドメイン>/` 配下すべて。HTML だけでなく **JSON ファイルも保護対象**です。これが今回いちばん重要な点で、`members.json` `videos.json` `interviews.json` が直接取得できることが現在の問題の本体です。

| ファイル | 中身 |
|---|---|
| `members.json` | 会員20名の氏名・会社名・役職・エリア・**メールアドレス**・各社の売上や従業員数 |
| `videos.json` | Vimeo 限定公開動画44本の再生URL（ハッシュ付き） |
| `interviews.json` | 会員インタビュー（現在は空） |
| `photos/*.webp` | 研究会の写真 |
| `index.html` | サイト本体 |

---

## 2. 想定している構成

```
会員のブラウザ
  │
  ├─ 未ログイン ──▶ Cloudflare Access のログイン画面
  │                    （メールに届く6桁コード、またはGoogleログイン）
  │
  └─ ログイン済み ─▶ Cloudflare Pages（静的ファイル配信）
                        index.html / *.json / photos/
```

- **ホスティング**: Cloudflare Pages（GitHub Pages から移設）
- **認証**: Cloudflare Access（Zero Trust）
- **ログイン方法**: メール確認コード（One-time PIN）を基本、Googleログインを併用
- **費用**: Cloudflare 無料プランの範囲。Zero Trust 無料プランの上限は50ユーザー、現在の会員は20名

> なぜ GitHub Pages のままにしないか: Pages サイトを限定公開にするには GitHub Enterprise Cloud が必要で、個人向けプランではリポジトリを private にしてもサイトは公開のままになります。

---

## 3. 作業手順

### 手順1 — GitHub 側を閉じる

1. リポジトリを **private** に変更
2. GitHub Pages を **停止**

> リポジトリは2026-08-23から公開状態で、会員データは2026-09-28から入っています。private 化で止められるのは以降の新規取得までで、**すでに複製された分（フォーク・各種キャッシュ）は取り消せません。**

### 手順2 — Cloudflare Pages へデプロイ

ビルド不要の静的サイトです。

| 設定項目 | 値 |
|---|---|
| Framework preset | None |
| Build command | （空欄） |
| Build output directory | `/` |
| Production branch | `main`（本ブランチをマージ後） |

`_headers` をリポジトリ直下に置いてあります。CSP や Referrer-Policy はこれが効きます。

### 手順3 — 独自ドメインを使う場合はここで追加

**Access を有効にする前に** Pages 側にカスタムドメインを追加してください。逆順だと追加できません（Cloudflare の既知の制約）。

独自ドメインを使わず `<project>.pages.dev` のままでも認証はかけられます。

### 手順4 — Access を設定

Terraform（`infra/terraform/`）か、ダッシュボードのどちらでも構いません。

**許可リストの作り方:**

```bash
bash infra/scripts/gen-allowlist.sh
```

`members.json` から会員20名のメールアドレスを抜き出し、`infra/allowlist.txt`（ダッシュボード貼り付け用）と `infra/allowlist.tfvars`（Terraform用）を作ります。**どちらも .gitignore 済みです。会員のメールアドレスを含むので、コミットやチャット転送はしないでください。**

**Terraform で行う場合:**

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # account_id と app_domain を埋める
export CLOUDFLARE_API_TOKEN=***                # tfvars には書かない
terraform init
terraform plan -var-file=terraform.tfvars -var-file=../allowlist.tfvars
terraform apply -var-file=terraform.tfvars -var-file=../allowlist.tfvars
```

必要なAPIトークン権限:
- Account > Access: Apps and Policies > Edit
- Account > Access: Organizations, Identity Providers, and Groups > Edit

> **`main.tf` に1箇所 `★要確認` を入れています。** ポリシーの `include` の書き方は provider のバージョンで変わるため、私の手元では `terraform plan` を通して確認できていません。plan が通らない場合はレジストリの `zero_trust_access_application` の `policies.include` を見て合わせてください。それ以外（v5ではポリシーをアプリケーションにインラインで書くこと、One-time PIN が `type = "onetimepin"` で config 空であること）は公式ドキュメントで確認済みです。

**ダッシュボードで行う場合** は、つまずきやすい点を手順6にまとめています。

### 手順5 — 管理者の設定

`admins.example.json` を `admins.json` にコピーし、事務局の担当者のメールアドレスを入れてデプロイしてください（`.gitignore` 済み）。

### 手順6 — 動作確認

1. ログアウト状態で `https://<ドメイン>/members.json` を直接開く → **Access のログイン画面にリダイレクトされること**（ここが今回の肝です）
2. 会員のアドレスでログイン → 名簿20名、事例動画が見えること
3. 事務局のアドレスでログイン → 「管理」メニューが出ること
4. 許可リストにないアドレスでログインを試す → 入れないこと
5. 動画が再生できること（Referrer-Policy の設定ミスで再生できなくなることがあります）

---

## 4. ダッシュボードで設定する場合の注意点

公式ドキュメントに記載のある、つまずきやすい点です。

- Pages の設定画面にある「Enable access policy」だけでは、**プレビュー用の一時URLしか保護されません**。`*.pages.dev` と独自ドメインには、それぞれ別に Access のアプリケーション設定が必要です
- 独自ドメインは **Access を有効にする前に** Pages へ追加する
- 独自ドメインに Access のポリシーを作り忘れると、ログイン画面は出るのに通過できない状態になります
- SSL証明書の検証のため、`/.well-known/acme-challenge/*` は Access で遮らない設定にしてください

---

## 5. 本ブランチでのコード側の変更

`index.html` のみ、4箇所です。

| 変更 | 内容 |
|---|---|
| ログイン画面 | メールアドレス／パスワードの入力欄と、**平文で表示していたデモ用パスワードを撤去**。認証状態の表示だけに |
| パスワード定数 | `PASS` / `PASS_ADMIN` を削除 |
| 認証処理 | `/cdn-cgi/access/get-identity` を呼び、Cloudflare Access が通したユーザーのメールアドレスを取得して画面を出す |
| ログアウト | `/cdn-cgi/access/logout` へ遷移 |

ローカル確認用に、`localhost` / `127.0.0.1` / `[::1]` のときだけ `?as=メールアドレス` で表示を切り替えられるようにしてあります。本番は Access が手前で止めるためこの分岐には到達しません。

```bash
python3 -m http.server 8080
# http://127.0.0.1:8080/index.html?as=member@example.co.jp
```

### 管理画面の扱い（ご判断ください）

管理画面（名簿・動画の編集）の出し分けは `admins.json` に載っているかどうかで行っています。**これは画面の出し分けであって、権限の境界ではありません。** Access を通った会員が開発者ツールで操作すれば管理UIを出せます。

ただし管理UIから変更できるのはブラウザ内のデータだけで、サーバー側への書き込み経路はありません（更新は事務局がJSONを出力してコミットする運用）。**実害は「本来見えない編集画面が見える」ことに留まります。**

厳密に分けるなら、管理UIを別パス（例 `/admin/`）に切り出し、そこに事務局だけを許可する Access アプリケーションをもう1つ作る形になります。必要かどうかのご判断をお願いします。

---

## 6. 認証とは別に残っている課題

- **Vimeo のドメイン制限**: 動画44本のURLが現在取得可能な状態にあります。Access を入れてもURL自体を知られれば再生できるため、Vimeo 側で「特定のドメイン」制限をかけてください。ご契約のStarterプランで使える見込みです（Vimeoヘルプ上、無料/Basic以外の全プランで利用可）。設定後は Referrer-Policy との兼ね合いで再生確認が必要です
- **会員への通知**: アンケートでは「会員限定ページのみの掲載」とご案内しており、公開状態だった件をどう扱うかはライフファンド様のご判断事項です
- **名簿の掲載項目**: 認証を入れても、会員全員が他社の売上高や従業員数を閲覧できる構造は変わりません。掲載項目を絞るかは別途ご議論ください

---

## 連絡先

中川（オールデリバード） t.nakagawa@alldelivered.jp
