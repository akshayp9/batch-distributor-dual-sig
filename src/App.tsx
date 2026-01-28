/* eslint-disable @typescript-eslint/no-explicit-any */
import { useState } from "react";
import {
  BrowserProvider,
  Contract,
  parseUnits,
} from "ethers";

import {
  CONTRACTS,
  BSC_CHAIN_ID,
} from "./config.ts";

import { BatchDistributorABI } from "./abi.ts";
import { randomBatchId } from "./utils.ts";
import { getTypedData } from "./typedData.ts";

declare global {
  interface Window {
    ethereum?: any;
  }
}

export default function App() {
  const [submitterSig, setSubmitterSig] = useState<string>();
  const [batchData, setBatchData] = useState<any>();
  const [txHash, setTxHash] = useState<string>();

  // -----------------------------
  // STEP 1 — SUBMITTER SIGNS
  // -----------------------------
  async function submitterSign() {
    const provider = new BrowserProvider(window.ethereum as any);
    const signer = await provider.getSigner();

    const batchId = randomBatchId();
    const token = CONTRACTS.USDT;

    // random demo data
    const recipients = [
      "0x1111111111111111111111111111111111111111",
      "0x2222222222222222222222222222222222222222",
    ];

    // USDT = 6 decimals
    const amounts = [
      parseUnits("1", 6),
      parseUnits("2", 6),
    ];

    const deadline = Math.floor(Date.now() / 1000) + 3600;

    const typedData = getTypedData({
      chainId: BSC_CHAIN_ID,
      verifyingContract: CONTRACTS.BATCH_DISTRIBUTOR,
      batchId,
      token,
      recipients,
      amounts,
      deadline,
    });

    const sig = await signer.signTypedData(
      typedData.domain,
      typedData.types,
      typedData.value
    );

    setSubmitterSig(sig);
    setBatchData({
      batchId,
      token,
      recipients,
      amounts,
      deadline,
      submitter: await signer.getAddress(),
    });

    alert("Submitter signed batch (off-chain)");
  }

  // -----------------------------
  // STEP 2 — VERIFIER EXECUTES
  // -----------------------------
  async function verifierExecute() {
    if (!batchData || !submitterSig) return;

    const provider = new BrowserProvider(window.ethereum as any);
    const signer = await provider.getSigner();

    const typedData = getTypedData({
      chainId: BSC_CHAIN_ID,
      verifyingContract: CONTRACTS.BATCH_DISTRIBUTOR,
      batchId: batchData.batchId,
      token: batchData.token,
      recipients: batchData.recipients,
      amounts: batchData.amounts,
      deadline: batchData.deadline,
    });

    const verifierSig = await signer.signTypedData(
      typedData.domain,
      typedData.types,
      typedData.value
    );
    console.log("🚀 ~ verifierExecute ~ verifierSig:", verifierSig)

    const contract = new Contract(
      CONTRACTS.BATCH_DISTRIBUTOR,
      BatchDistributorABI,
      signer
    );

    const tx = await contract.batchDistributeTokenDualSig(
      batchData.batchId,
      batchData.token,
      batchData.recipients,
      batchData.amounts,
      batchData.deadline,
      batchData.submitter,
      submitterSig    
    );

    const receipt = await tx.wait();
    setTxHash(receipt.hash);

    alert("Batch executed on-chain");
  }

  return (
    <div style={{ padding: 40 }}>
      <h2>BatchDistributorV2 – Dual Signature Demo (BSC)</h2>

      <button onClick={submitterSign}>
        1️⃣ Connect Submitter & Sign Batch
      </button>

      <br /><br />

      <button onClick={verifierExecute} disabled={!submitterSig}>
        2️⃣ Connect Verifier & Execute Batch
      </button>

      {txHash && (
        <p>
          ✅ Tx Hash:{" "}
          <a
            href={`https://bscscan.com/tx/${txHash}`}
            target="_blank"
          >
            {txHash}
          </a>
        </p>
      )}
    </div>
  );
}
