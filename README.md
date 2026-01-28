# Batch Distributor V2 – Dual Signature (EIP-712)

A **secure, production-ready dual-signature batch distribution system** for ERC-20 tokens and native assets.

This project enables:
- **Off-chain batch approval** by a Submitter
- **On-chain verification and execution** by a Verifier/Executor
- Strong replay protection using **EIP-712 typed data**
- Full auditability via `batchId` and emitted events

Designed for **ops-grade payout flows**, treasury automation, and enterprise-grade Web3 applications.

---

## 🚀 Key Features

- 🔐 **Dual-signature authorization**
  - Submitter signs batch off-chain (no gas)
  - Verifier executes batch on-chain
- 🧾 **EIP-712 typed signatures** (safe, deterministic, auditable)
- 🔁 **Replay protection**
  - Unique `batchId`
  - Expiring `deadline`
- 🪙 **ERC-20 token distribution**
  - Token whitelist (USDT, IGNET, extendable)
- ⛽ **Gas-efficient batching**
- 🛑 **Pausable + role-based access**
- 🧪 Production-safe (stack-safe, IR-ready)

---

## 🏗 Architecture Overview
Submitter (off-chain)
|
| EIP-712 Signature
v
Backend / Frontend
|
| Submitter Signature + Batch Payload
v
Verifier / Executor (on-chain)
|
| Dual-Sig Verification
v
BatchDistributorV2.sol
|
| ERC-20 Transfers
v
Recipients


---

## 🔑 Roles

| Role | Description |
|----|----|
| **Submitter** | Signs batch off-chain (never sends tx) |
| **Verifier / Executor** | Verifies + executes batch on-chain |
| **Admin** | Manages token whitelist, pause, rescue |

---

## 📄 Smart Contract

### Contract Name


BatchDistributorV2.sol


### Core Function
```solidity
batchDistributeTokenDualSig(
  bytes32 batchId,
  address token,
  address[] recipients,
  uint256[] amounts,
  uint256 deadline,
  address submitter,
  bytes submitterSig,
  bytes verifierSig
)
```
🔐 Signature Flow (EIP-712)

Both Submitter and Verifier sign the same typed payload:

BatchToken {
  batchId
  token
  recipientsHash
  amountsHash
  totalAmount
  deadline
}


The contract verifies:

submitter signature matches declared submitter

verifier signature matches msg.sender

batch is not expired or replayed

📦 Deployment (BSC Mainnet)
Component	Address
BatchDistributorV2	0x219144e08F6a91451332a324717562301de363ad
USDT	0x55E2BC7f5295293649967aB75e5dF7A5745E6205
IGNET	0x427245a96F7d33A29aD3B5011458C669c375A8Cf
🧪 Example Frontend Flow

1️⃣ Submitter connects wallet
2️⃣ Random batch generated (recipients + amounts)
3️⃣ Submitter signs batch (off-chain)
4️⃣ Verifier connects wallet
5️⃣ Verifier signs + executes batch (on-chain)

A complete demo frontend is included using ethers v6.

⚙️ Development Setup
Install
npm install

Compile (Hardhat)
viaIR: true
optimizer: { enabled: true, runs: 200 }

🧠 Security Considerations

Uses abi.encode (NOT encodePacked) for EIP-712 safety

Domain-separated signatures (chain-bound)

Deadline prevents signature reuse

Batch ID prevents replay

Executor role restricted via AccessControl

ReentrancyGuard + Pausable included

📜 Events
BatchExecutedWithDualSig(
  batchId,
  token,
  submitter,
  verifier,
  recipients,
  totalAmount,
  timestamp
)


Used by backend systems to track completion.

🧩 Use Cases

Treasury payouts

Payroll distributions

DAO rewards

Exchange withdrawals


