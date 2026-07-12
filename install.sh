#!/usr/bin/env bash
#
# install.sh - dotfiles のセットアップ（symlink / gh extension）
#
# 使い方:
#   ./install.sh              # すべてのセットアップを実行
#   ./install.sh --dry-run    # 実際には変更せず、何が起きるかだけ確認
#   ./install.sh --links-only # symlink のみ
#   ./install.sh --gh-only    # gh extension のみ
#

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
RUN_LINKS=true
RUN_GH=true

for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=true ;;
    --links-only) RUN_GH=false ;;
    --gh-only)    RUN_LINKS=false ;;
  esac
done

# ===== リンク定義 =====
# link_file      "リポ内の相対パス" "リンク先"  … symlink（dotfiles 側が正）。既存は .bak.<ts> へ退避
# copy_if_absent "テンプレート"     "リンク先"  … 既存なら触らずコピー（各マシンで編集する前提）
setup_links() {
  # --- Claude 設定 ---
  link_file      "claude/CLAUDE.md"               "$HOME/.claude/CLAUDE.md"
  copy_if_absent "claude/CLAUDE.local.example.md" "$HOME/.claude/CLAUDE.local.md"
}

# ===== GitHub CLI Extensions =====
# gh-extensions に 1 行 1 エントリ（<owner>/<repo>）。# と空行は無視。
setup_gh_extensions() {
  local extfile="$DOTFILES_DIR/gh-extensions"
  if [[ ! -f "$extfile" ]]; then
    log_skip "gh-extensions が存在しないため gh extension install をスキップ"
    return
  fi
  if ! command -v gh &>/dev/null; then
    log_skip "gh が見つからないため gh extension install をスキップ"
    return
  fi
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$DRY_RUN" == true ]]; then
      log_dry "gh extension install $line"
    elif gh extension list | grep -q "${line##*/}"; then
      log_skip "gh extension $line (already installed)"
    else
      log_info "gh extension install $line"
      gh extension install "$line"
    fi
  done < "$extfile"
}

# ===== ユーティリティ =====
log_info()    { echo "[info]  $*"; }
log_skip()    { echo "[skip]  $*"; }
log_dry()     { echo "[dry]   $*"; }
log_success() { echo "[link]  $*"; }
log_backup()  { echo "[bkup]  $*"; }

# 単一ファイルの symlink を作成する（既存は .bak.<ts> へ退避）
link_file() {
  local src="$DOTFILES_DIR/$1"
  local dest="$2"

  if [[ "$DRY_RUN" == true ]]; then
    log_dry "$src → $dest"
    return
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    log_skip "$dest (already linked)"
    return
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    log_backup "$dest → $backup"
  fi

  ln -s "$src" "$dest"
  log_success "$src → $dest"
}

# テンプレートから実ファイルを作る（既存なら触らない）
copy_if_absent() {
  local src="$DOTFILES_DIR/$1"
  local dest="$2"

  if [[ ! -f "$src" ]]; then
    log_skip "$1 (テンプレートが存在しない)"
    return
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    log_skip "$dest (already exists)"
    return
  fi
  if [[ "$DRY_RUN" == true ]]; then
    log_dry "cp $src → $dest"
    return
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  log_success "$src → $dest (copy)"
}

# ===== メイン処理 =====
main() {
  [[ "$DRY_RUN" == true ]] && log_info "Dry-run モード: 実際にはリンクしません"
  log_info "dotfiles ディレクトリ: $DOTFILES_DIR"
  [[ "$RUN_LINKS" == true ]] && setup_links
  [[ "$RUN_GH"   == true ]] && setup_gh_extensions
  log_info "完了"
}

main
