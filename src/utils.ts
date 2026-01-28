import { keccak256, randomBytes } from "ethers";

export function randomBatchId(): `0x${string}` {
  return keccak256(randomBytes(32)) as `0x${string}`;
}

export function sum(arr: bigint[]) {
  return arr.reduce((a, b) => a + b, 0n);
}
