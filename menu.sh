#!/data/data/com.termux/files/usr/bin/bash
set -e

REPO_URL="https://github.com/Anonzeroes/intercom"
REPO_DIR="$HOME/intercom"
LOG="$HOME/intercom-suite/intercom.log"

CFG="$HOME/.config/intercom-suite"
GH_TOKEN_FILE="$CFG/github_token"
WALLETS_FILE="$CFG/wallets.json"
RPC_FILE="$CFG/rpc.json"

BIN_DIR="$HOME/intercom-suite/bin"
TRACKER="$BIN_DIR/wallet_tracker.js"
SWAP="$BIN_DIR/swap_link.js"

R='\033[31m'; G='\033[32m'; Y='\033[33m'; B='\033[34m'; C='\033[36m'; W='\033[0m'

hdr() {
  clear
  echo -e "${C}╔════════════════════════════════════════════════════════╗${W}"
  echo -e "${C}║${W}   ${G}INTERCOM SUITE MENU (Termux)${W}                    ${C}║${W}"
  echo -e "${C}║${W}   Repo: ${Y}${REPO_URL}${W}                 ${C}║${W}"
  echo -e "${C}╚════════════════════════════════════════════════════════╝${W}"
  echo
}

pause(){ echo; read -rp "Enter untuk lanjut... " _; }

init_cfg() {
  mkdir -p "$CFG"
  [ -f "$WALLETS_FILE" ] || printf '{\n  "wallets": []\n}\n' > "$WALLETS_FILE"
  [ -f "$RPC_FILE" ] || printf '{\n  "evm_rpc": "https://cloudflare-eth.com",\n  "sol_rpc": "https://api.mainnet-beta.solana.com"\n}\n' > "$RPC_FILE"
}

install_deps() {
  hdr
  echo -e "${B}[*] Install dependencies...${W}"
  pkg update -y && pkg upgrade -y
  pkg install -y git openssl curl nodejs termux-api
  cd "$HOME/intercom-suite" || exit 1
  npm init -y >/dev/null 2>&1 || true
  npm install axios inquirer@8 >/dev/null 2>&1
  chmod +x "$TRACKER" "$SWAP"
  echo -e "${G}[OK] deps lengkap.${W}"
  pause
}

clone_repo() {
  hdr
  if [ -d "$REPO_DIR/.git" ]; then
    echo -e "${Y}[i] Repo sudah ada:${W} $REPO_DIR"
    pause; return
  fi
  echo -e "${B}[*] Cloning...${W}"
  git clone --depth 1 "$REPO_URL" "$REPO_DIR"
  echo -e "${G}[OK] Cloned ke:${W} $REPO_DIR"
  pause
}

update_repo() {
  hdr
  if [ ! -d "$REPO_DIR/.git" ]; then
    echo -e "${R}Repo belum ada. Clone dulu.${W}"
    pause; return
  fi
  echo -e "${B}[*] Updating repo...${W}"
  git -C "$REPO_DIR" pull --ff-only
  echo -e "${G}[OK] Updated.${W}"
  pause
}

setup_repo() {
  hdr
  if [ ! -d "$REPO_DIR" ]; then
    echo -e "${R}Repo belum ada. Clone dulu.${W}"
    pause; return
  fi
  cd "$REPO_DIR"
  if [ -f package.json ]; then
    echo -e "${B}[*] npm install (kalau ada native deps error di Termux, itu normal).${W}"
    npm install 2>&1 | tee -a "$LOG" || true
    echo -e "${G}[OK] setup selesai (best-effort).${W}"
  else
    echo -e "${Y}[i] Tidak ada package.json. Setup manual mungkin diperlukan.${W}"
  fi
  pause
}

gen_token_local() {
  hdr
  mkdir -p "$CFG"
  token="$(openssl rand -hex 32)"
  echo "$token" > "$CFG/intercom_token"
  chmod 600 "$CFG/intercom_token"
  echo -e "${G}[OK] Token dibuat:${W} $CFG/intercom_token"
  echo -e "${Y}Token:${W} $token"
  pause
}

run_repo() {
  hdr
  if [ ! -d "$REPO_DIR" ]; then
    echo -e "${R}Repo belum ada. Clone dulu.${W}"
    pause; return
  fi
  cd "$REPO_DIR"

  echo -e "${B}[*] Run (auto-detect, tanpa asumsi npm start)...${W}"
  echo -e "${Y}Jika repo butuh runtime khusus (pear/intercom CLI), Termux bisa tidak support.${W}\n"

  if [ -f package.json ]; then
    echo -e "${B}Scripts tersedia:${W}"
    npm run || true
    echo
    if grep -q '"start"' package.json 2>/dev/null; then
      echo -e "${G}Menjalankan: npm start${W}"
      (npm start 2>&1 | tee -a "$LOG") || true
    elif grep -q '"dev"' package.json 2>/dev/null; then
      echo -e "${G}Menjalankan: npm run dev${W}"
      (npm run dev 2>&1 | tee -a "$LOG") || true
    else
      echo -e "${Y}Tidak ada start/dev. Cek scripts di atas untuk perintah yang benar.${W}"
    fi
  elif [ -f index.js ]; then
    echo -e "${G}Menjalankan: node index.js${W}"
    (node index.js 2>&1 | tee -a "$LOG") || true
  else
    echo -e "${R}Entrypoint tidak ditemukan.${W}"
    echo -e "${Y}Coba lihat isi repo: ls -la $REPO_DIR${W}"
  fi

  pause
}

stop_repo() {
  hdr
  echo -e "${B}[*] Stop proses (best-effort)...${W}"
  pkill -f "$REPO_DIR" >/dev/null 2>&1 || true
  pkill -f "node" >/dev/null 2>&1 || true
  echo -e "${G}[OK] stop done.${W}"
  pause
}

show_log() {
  hdr
  if [ -f "$LOG" ]; then
    echo -e "${B}=== LOG (tail 200): $LOG ===${W}"
    tail -n 200 "$LOG" || true
  else
    echo -e "${Y}Belum ada log.${W}"
  fi
  pause
}

# ---------- GitHub Token ----------
set_github_token() {
  hdr
  init_cfg
  echo -e "${B}Masukkan GitHub Token (PAT).${W}"
  echo -e "${Y}Disimpan aman di:${W} $GH_TOKEN_FILE (chmod 600)"
  read -rsp "Token: " tok; echo
  [ -z "$tok" ] && { echo -e "${R}Token kosong.${W}"; pause; return; }
  echo "$tok" > "$GH_TOKEN_FILE"
  chmod 600 "$GH_TOKEN_FILE"
  echo -e "${G}[OK] Token disimpan.${W}"
  pause
}

test_github_token() {
  hdr
  init_cfg
  if [ ! -f "$GH_TOKEN_FILE" ]; then
    echo -e "${R}Belum ada token.${W} pilih Set token dulu."
    pause; return
  fi
  tok="$(cat "$GH_TOKEN_FILE")"
  echo -e "${B}Test token via GitHub API (/user).${W}"
  curl -s -H "Authorization: Bearer $tok" -H "Accept: application/vnd.github+json" https://api.github.com/user | head -n 60
  echo
  echo -e "${Y}Kalau ada field 'login', token valid.${W}"
  pause
}

# ---------- Wallet manager ----------
wallet_add() {
  hdr
  init_cfg
  read -rp "Label (mis: MAIN/ALT/TRAC_MAIN): " label
  read -rp "Address (EVM 0x.. / Sol base58 / TRAC trac1..): " addr
  [ -z "$label" ] || [ -z "$addr" ] && true
  if [ -z "$label" ] || [ -z "$addr" ]; then
    echo -e "${R}Label/Address tidak boleh kosong.${W}"; pause; return
  fi

  export LBL="$label"
  export ADDR="$addr"

  node - <<'NODE'
const fs=require("fs");
const path=require("path");
const HOME=process.env.HOME||".";
const CFG=path.join(HOME,".config","intercom-suite");
const W=path.join(CFG,"wallets.json");
const label=process.env.LBL;
const addr=process.env.ADDR;
const data=JSON.parse(fs.readFileSync(W,"utf-8"));
data.wallets=data.wallets||[];
data.wallets.push({label, address: addr});
fs.writeFileSync(W, JSON.stringify(data,null,2));
console.log("OK: added", label, addr);
NODE

  pause
}

wallet_list() {
  hdr
  init_cfg
  echo -e "${B}Wallets:${W}"
  cat "$WALLETS_FILE"
  pause
}

wallet_reset() {
  hdr
  init_cfg
  read -rp "Reset wallet list? (y/n): " yn
  if [ "$yn" = "y" ] || [ "$yn" = "Y" ]; then
    printf '{\n  "wallets": []\n}\n' > "$WALLETS_FILE"
    echo -e "${G}[OK] Wallet list direset.${W}"
  else
    echo -e "${Y}Batal.${W}"
  fi
  pause
}

wallet_track() {
  hdr
  init_cfg
  if [ ! -f "$TRACKER" ]; then
    echo -e "${R}Tracker tidak ada.${W} Jalankan Install deps dulu."
    pause; return
  fi
  read -rp "Refresh interval detik (default 20): " sec
  sec="${sec:-20}"
  echo -e "${B}Mulai tracking... Stop dengan Ctrl+C${W}\n"
  node "$TRACKER" "$sec"
  pause
}

rpc_set() {
  hdr
  init_cfg
  echo -e "${B}Set RPC endpoint${W}"
  echo -e "${Y}RPC file:${W} $RPC_FILE"
  echo
  echo -e "${C}Saat ini:${W}"
  cat "$RPC_FILE"
  echo
  read -rp "EVM RPC baru (enter untuk skip): " evm
  read -rp "Solana RPC baru (enter untuk skip): " sol

  export EVM="$evm"
  export SOL="$sol"

  node - <<'NODE'
const fs=require("fs");
const path=require("path");
const HOME=process.env.HOME||".";
const RPC=path.join(HOME,".config","intercom-suite","rpc.json");
const data=JSON.parse(fs.readFileSync(RPC,"utf-8"));
if(process.env.EVM && process.env.EVM.trim()) data.evm_rpc=process.env.EVM.trim();
if(process.env.SOL && process.env.SOL.trim()) data.sol_rpc=process.env.SOL.trim();
fs.writeFileSync(RPC, JSON.stringify(data,null,2));
console.log("OK: rpc updated");
NODE

  pause
}

# ---------- TRAC Explorer ----------
trac_open_explorer() {
  hdr
  read -rp "Masukkan TRAC address (trac1...): " addr
  if [ -z "$addr" ]; then echo -e "${R}Alamat kosong.${W}"; pause; return; fi
  url="https://explorer.trac.network/address/$addr"
  echo -e "${B}Opening:${W} $url"
  termux-open-url "$url" >/dev/null 2>&1 || { echo -e "${Y}Buka manual:${W} $url"; }
  pause
}

# ---------- Swap menu ----------
swap_menu() {
  hdr
  if [ ! -f "$SWAP" ]; then
    echo -e "${R}Swap helper tidak ada.${W} Jalankan Install deps dulu."
    pause; return
  fi
  echo -e "${B}Swap helper (buat link swap)${W}"
  echo -e "${Y}Swap dieksekusi di DEX/wallet (lebih aman, tanpa private key di bot).${W}\n"
  node "$SWAP"
  pause
}

while true; do
  hdr
  echo -e "${C}1${W}) Install deps + npm modules (axios, inquirer)"
  echo -e "${C}2${W}) Clone repo Anonzeroes/intercom"
  echo -e "${C}3${W}) Update repo (git pull)"
  echo -e "${C}4${W}) Setup repo (npm install best-effort)"
  echo -e "${C}5${W}) Generate local token (openssl rand -hex 32)"
  echo -e "${C}6${W}) Run repo (auto-detect scripts)"
  echo -e "${C}7${W}) Stop repo (best-effort)"
  echo -e "${C}8${W}) View log (tail 200)"
  echo
  echo -e "${C}10${W}) GitHub Token: set/login"
  echo -e "${C}11${W}) GitHub Token: test"
  echo
  echo -e "${C}12${W}) Wallet: add (EVM/SOL/TRAC)"
  echo -e "${C}13${W}) Wallet: list"
  echo -e "${C}14${W}) Wallet: track (monitor)"
  echo -e "${C}15${W}) Wallet: reset"
  echo -e "${C}16${W}) RPC: set (EVM/SOL)"
  echo
  echo -e "${C}17${W}) Swap menu (buat link swap)"
  echo -e "${C}18${W}) TRAC Explorer: open address"
  echo
  echo -e "${C}0${W}) Exit"
  echo
  read -rp "Pilih menu: " ch

  case "$ch" in
    1) install_deps ;;
    2) clone_repo ;;
    3) update_repo ;;
    4) setup_repo ;;
    5) gen_token_local ;;
    6) run_repo ;;
    7) stop_repo ;;
    8) show_log ;;
    10) set_github_token ;;
    11) test_github_token ;;
    12) wallet_add ;;
    13) wallet_list ;;
    14) wallet_track ;;
    15) wallet_reset ;;
    16) rpc_set ;;
    17) swap_menu ;;
    18) trac_open_explorer ;;
    0) exit 0 ;;
    *) echo -e "${R}Pilihan tidak valid.${W}"; sleep 1 ;;
  esac
done
