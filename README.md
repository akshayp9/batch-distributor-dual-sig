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

