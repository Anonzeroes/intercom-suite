#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const axios = require("axios");

const HOME = process.env.HOME || ".";
const CFG_DIR = path.join(HOME, ".config", "intercom-suite");
const WALLETS = path.join(CFG_DIR, "wallets.json");
const RPC = path.join(CFG_DIR, "rpc.json");

function ensureCfg() {
  if (!fs.existsSync(CFG_DIR)) fs.mkdirSync(CFG_DIR, { recursive: true });
  if (!fs.existsSync(WALLETS)) fs.writeFileSync(WALLETS, JSON.stringify({ wallets: [] }, null, 2));
  if (!fs.existsSync(RPC)) {
    fs.writeFileSync(
      RPC,
      JSON.stringify(
        { evm_rpc: "https://cloudflare-eth.com", sol_rpc: "https://api.mainnet-beta.solana.com" },
        null,
        2
      )
    );
  }
}

function loadJson(p) {
  return JSON.parse(fs.readFileSync(p, "utf-8"));
}

function isEvm(addr) { return /^0x[a-fA-F0-9]{40}$/.test(addr); }
function isSol(addr) { return /^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(addr); }
function isTrac(addr){ return /^trac1[0-9a-z]{20,}$/.test(addr); }
function tracExplorerUrl(addr){ return `https://explorer.trac.network/address/${addr}`; }

async function rpcPost(url, method, params) {
  const res = await axios.post(
    url,
    { jsonrpc: "2.0", id: 1, method, params },
    { timeout: 20000, headers: { "Content-Type": "application/json" } }
  );
  if (res.data && res.data.error) throw new Error(JSON.stringify(res.data.error));
  return res.data.result;
}

function weiToEth(weiHex) {
  const wei = BigInt(weiHex);
  const ethInt = wei / 1000000000000000000n;
  const ethFrac = wei % 1000000000000000000n;
  const fracStr = ethFrac.toString().padStart(18, "0").replace(/0+$/, "");
  return fracStr ? `${ethInt}.${fracStr}` : `${ethInt}`;
}

async function checkEvm(addr, evmRpcUrl) {
  const balHex = await rpcPost(evmRpcUrl, "eth_getBalance", [addr, "latest"]);
  const nonceHex = await rpcPost(evmRpcUrl, "eth_getTransactionCount", [addr, "latest"]);
  return {
    chain: "EVM (Ethereum mainnet)",
    balance_native: `${weiToEth(balHex)} ETH`,
    tx_count: parseInt(nonceHex, 16)
  };
}

async function checkSol(addr, solRpcUrl) {
  const bal = await rpcPost(solRpcUrl, "getBalance", [addr, { commitment: "confirmed" }]);
  const lamports = BigInt(bal?.value ?? 0);
  const sol = Number(lamports) / 1e9;

  const sigs = await rpcPost(solRpcUrl, "getSignaturesForAddress", [addr, { limit: 5 }]);
  const last = Array.isArray(sigs) && sigs.length ? sigs[0] : null;

  return {
    chain: "Solana mainnet",
    balance_native: `${sol} SOL`,
    last_sig: last?.signature || "-",
    last_time: last?.blockTime ? new Date(last.blockTime * 1000).toISOString() : "-"
  };
}

async function main() {
  ensureCfg();
  const wallets = loadJson(WALLETS).wallets || [];
  const rpc = loadJson(RPC);

  const interval = Number(process.argv[2] || "20");
  if (!wallets.length) {
    console.log("Wallet list kosong. Tambah lewat menu (Wallet: add).");
    process.exit(0);
  }

  console.log(`Tracking ${wallets.length} wallet(s). Refresh tiap ${interval}s`);
  console.log("Stop: Ctrl+C\n");

  while (true) {
    const now = new Date().toISOString();
    console.log(`=== ${now} ===`);

    for (const w of wallets) {
      const addr = w.address;
      try {
        if (isEvm(addr)) {
          const r = await checkEvm(addr, rpc.evm_rpc);
          console.log(`- ${w.label} | ${addr}`);
          console.log(`  ${r.chain} | ${r.balance_native} | tx_count=${r.tx_count}`);
        } else if (isSol(addr)) {
          const r = await checkSol(addr, rpc.sol_rpc);
          console.log(`- ${w.label} | ${addr}`);
          console.log(`  ${r.chain} | ${r.balance_native} | last=${r.last_sig} @ ${r.last_time}`);
        } else if (isTrac(addr)) {
          console.log(`- ${w.label} | ${addr}`);
          console.log(`  TRAC network | explorer: ${tracExplorerUrl(addr)}`);
        } else {
          console.log(`- ${w.label} | ${addr}`);
          console.log("  Unknown format (EVM 0x.. / Solana base58 / TRAC trac1..).");
        }
      } catch (e) {
        console.log(`- ${w.label} | ${addr}`);
        console.log(`  ERROR: ${e.message || e}`);
      }
      console.log("");
    }

    await new Promise((r) => setTimeout(r, interval * 1000));
  }
}

main().catch((e) => {
  console.error("Fatal:", e.message || e);
  process.exit(1);
});
