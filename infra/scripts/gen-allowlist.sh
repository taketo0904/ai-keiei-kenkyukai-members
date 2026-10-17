#!/usr/bin/env bash
# members.json から、Cloudflare Access に登録する会員のメールアドレス一覧を作る。
#
#   使い方:  bash infra/scripts/gen-allowlist.sh
#   出力:    infra/allowlist.txt      （1行1アドレス。ダッシュボードに貼る用）
#            infra/allowlist.tfvars   （Terraform の member_emails 用）
#
# 出力ファイルは .gitignore 済み。会員のメールアドレスを含むので、
# リポジトリにコミットしたり、チャットに貼ったりしないこと。
set -euo pipefail
cd "$(dirname "$0")/../.."

python3 - <<'PY'
import json, pathlib
src = json.load(open('members.json', encoding='utf-8'))
mails = []
for m in src.get('members', []):
    a = (m.get('mail') or '').strip().lower()
    if a and a not in mails:
        mails.append(a)

pathlib.Path('infra/allowlist.txt').write_text('\n'.join(mails) + '\n', encoding='utf-8')

body = ',\n'.join('  "%s"' % a for a in mails)
pathlib.Path('infra/allowlist.tfvars').write_text(
    'member_emails = [\n%s\n]\n' % body, encoding='utf-8')

print('会員 %d 件を書き出しました:' % len(mails))
print('  infra/allowlist.txt')
print('  infra/allowlist.tfvars')
PY
