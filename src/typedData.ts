/* eslint-disable @typescript-eslint/no-explicit-any */
import { AbiCoder, keccak256 } from "ethers";
import { sum } from "./utils";

export function getTypedData({
  chainId,
  verifyingContract,
  batchId,
  token,
  recipients,
  amounts,
  deadline,
}: any) {

  const recipientsHash = keccak256(
  AbiCoder.defaultAbiCoder().encode(["address[]"], [recipients])
);

const amountsHash = keccak256(
  AbiCoder.defaultAbiCoder().encode(["uint256[]"], [amounts])
);

  const totalAmount = sum(amounts);

  return {
    domain: {
      name: "BatchDistributorV2",
      version: "1",
      chainId,
      verifyingContract,
    },
    types: {
      BatchToken: [
        { name: "batchId", type: "bytes32" },
        { name: "token", type: "address" },
        { name: "recipientsHash", type: "bytes32" },
        { name: "amountsHash", type: "bytes32" },
        { name: "totalAmount", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    },
    value: {
      batchId,
      token,
      recipientsHash,
      amountsHash,
      totalAmount,
      deadline,
    },
  };
}
