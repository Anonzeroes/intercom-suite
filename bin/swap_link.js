#!/usr/bin/env node
"use strict";

const inquirer = require("inquirer");
const { execSync } = require("child_process");

function openUrl(url) {
  try {
    execSync(`termux-open-url "${url}"`, { stdio: "ignore" });
    console.log("Opened:", url);
  } catch {
    console.log("Buka manual:", url);
  }
}

async function main() {
  const { chain } = await inquirer.prompt([
    { type: "list", name: "chain", message: "Pilih chain untuk swap link", choices: ["EVM (Uniswap)", "EVM (1inch)", "Solana (Jupiter)"] }
  ]);

  if (chain.startsWith("EVM")) {
    const { from, to, amount } = await inquirer.prompt([
      { type: "input", name: "from", message: "Token FROM (0x.. atau ETH)", default: "ETH" },
      { type: "input", name: "to", message: "Token TO (contract 0x..)" },
      { type: "input", name: "amount", message: "Amount (mis: 0.01)", default: "0.01" }
    ]);

    let url = "";
    const inCur = from.toUpperCase() === "ETH" ? "ETH" : from;

    if (chain.includes("Uniswap")) {
      url = `https://app.uniswap.org/swap?inputCurrency=${encodeURIComponent(inCur)}&outputCurrency=${encodeURIComponent(to)}&value=${encodeURIComponent(amount)}`;
    } else {
      url = `https://app.1inch.io/#/1/swap/${encodeURIComponent(inCur)}/${encodeURIComponent(to)}?amount=${encodeURIComponent(amount)}`;
    }

    console.log("\nLink swap (eksekusi di DEX/wallet):");
    openUrl(url);
    return;
  }

  const { inputMint, outputMint } = await inquirer.prompt([
    { type: "input", name: "inputMint", message: "Input mint (kosong untuk SOL)", default: "" },
    { type: "input", name: "outputMint", message: "Output mint (Solana)" }
  ]);

  const url = `https://jup.ag/swap/${encodeURIComponent(inputMint || "SOL")}-${encodeURIComponent(outputMint)}`;
  console.log("\nLink swap (eksekusi di DEX/wallet):");
  openUrl(url);
}

main().catch((e) => {
  console.error("Fatal:", e.message || e);
  process.exit(1);
});
