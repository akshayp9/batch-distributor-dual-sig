// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract BatchDistributorV2 is AccessControl, Pausable, ReentrancyGuard, EIP712 {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    event TokenWhitelistUpdated(address indexed token, bool whitelisted);

    event BatchExecuted(
        bytes32 indexed batchId,
        address indexed token, // address(0) for native
        address indexed executedBy,
        uint256 recipients,
        uint256 totalAmount,
        uint256 timestamp
    );

    event TransferItem(
        bytes32 indexed batchId,
        address indexed token,
        address indexed to,
        uint256 amount
    );

    event BatchExecutedWithDualSig(
        bytes32 indexed batchId,
        address indexed token,
        address indexed submitter,
        address verifierExecutor,
        uint256 recipients,
        uint256 totalAmount,
        uint256 timestamp
    );

    mapping(address => bool) public whitelistedToken;
    mapping(bytes32 => bool) public isBatchExecuted;

    uint256 public maxBatchSize = 500;

    error ZeroAddress();
    error InvalidArrayLengths();
    error EmptyBatch();
    error BatchTooLarge(uint256 size, uint256 max);
    error TokenNotWhitelisted(address token);
    error BatchAlreadyExecuted(bytes32 batchId);
    error InvalidAmount();
    error InvalidSignature();
    error InvalidSigner();
    error SameSubmitterAndExecutorNotAllowed();

    // ============================
    // EIP-712 TYPEHASH
    // ============================
    /**
     * @dev This struct is what both parties sign.
     * Include chain-binding via EIP712 domain separator.
     * Include recipientsHash & amountsHash so payload size stays efficient.
     */
    bytes32 private constant BATCH_TOKEN_TYPEHASH =
        keccak256(
            "BatchToken(bytes32 batchId,address token,bytes32 recipientsHash,bytes32 amountsHash,uint256 totalAmount,uint256 deadline)"
        );

    constructor(address admin, address usdt, address igate)
        EIP712("BatchDistributorV2", "1")
    {
        if (admin == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        // Admin is also verifier by default (optional, you can separate)
        _grantRole(VERIFIER_ROLE, admin);

        if (usdt != address(0)) {
            whitelistedToken[usdt] = true;
            emit TokenWhitelistUpdated(usdt, true);
        }
        if (igate != address(0)) {
            whitelistedToken[igate] = true;
            emit TokenWhitelistUpdated(igate, true);
        }
    }

    // ============================
    // Admin Controls
    // ============================

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function setMaxBatchSize(uint256 newMax) external onlyRole(ADMIN_ROLE) {
        if (newMax == 0) revert InvalidAmount();
        maxBatchSize = newMax;
    }

    function setTokenWhitelisted(address token, bool allowed) external onlyRole(ADMIN_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        whitelistedToken[token] = allowed;
        emit TokenWhitelistUpdated(token, allowed);
    }

    // ============================
    // NEW: Signable Hash Helpers
    // ============================

    function getBatchTokenDigest(
    bytes32 batchId,
    address token,
    address[] calldata recipients,
    uint256[] calldata amounts,
    uint256 deadline
) public view returns (bytes32) {
    bytes32 recipientsHash = keccak256(abi.encode(recipients));
    bytes32 amountsHash = keccak256(abi.encode(amounts));
    uint256 totalAmount = _sum(amounts);

    bytes32 structHash = keccak256(
        abi.encode(
            BATCH_TOKEN_TYPEHASH,
            batchId,
            token,
            recipientsHash,
            amountsHash,
            totalAmount,
            deadline
        )
    );

    return _hashTypedDataV4(structHash);
}

    /**
     * @notice Helper for backend/frontend:
     * Recover the submitter address from a given signature (off-chain signature verification).
     */
    function recoverSubmitter(
        bytes32 batchId,
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts,
        uint256 deadline,
        bytes calldata submitterSig
    ) external view returns (address) {
        bytes32 digest = getBatchTokenDigest(batchId, token, recipients, amounts, deadline);
        return ECDSA.recover(digest, submitterSig);
    }

    // ============================
    // Dual Signature Execution (TOKEN)
    // ============================

    /**
     * @notice Token distribution requiring 2 signatures:
     * 1) submitter signature (sign-only party)
     * 2) verifier/executor signature (caller signs and executes)
     *
     * @dev submitter does NOT submit transaction; verifier/executor does.
     */
    function batchDistributeTokenDualSig(
        bytes32 batchId,
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts,
        uint256 deadline,
        address submitter,
        bytes calldata submitterSig
        // bytes calldata verifierSig
    ) external onlyRole(VERIFIER_ROLE) whenNotPaused nonReentrant {
        if (!whitelistedToken[token]) revert TokenNotWhitelisted(token);

        _precheckBatch(batchId, recipients.length, amounts.length);

        // Build digest
        bytes32 digest = getBatchTokenDigest(batchId, token, recipients, amounts, deadline);

        // Recover signer-1 (submitter)
        address recoveredSubmitter = ECDSA.recover(digest, submitterSig);
        if (recoveredSubmitter == address(0)) revert InvalidSignature();
        if (recoveredSubmitter != submitter) revert InvalidSigner();

        // Optional but recommended: enforce separation of duty
        if (submitter == msg.sender) revert SameSubmitterAndExecutorNotAllowed();

        // Mark executed FIRST to prevent replay/reentrancy patterns
        isBatchExecuted[batchId] = true;

        // Execute transfers
        IERC20 erc20 = IERC20(token);
        uint256 total = _sum(amounts);

        require(erc20.balanceOf(address(this)) >= total, "INSUFFICIENT_TOKEN_BALANCE");

        for (uint256 i = 0; i < recipients.length; i++) {
            address to = recipients[i];
            uint256 amt = amounts[i];

            if (to == address(0)) revert ZeroAddress();
            if (amt == 0) revert InvalidAmount();

            erc20.transfer(to, amt);
            emit TransferItem(batchId, token, to, amt);
        }

        emit BatchExecutedWithDualSig(
            batchId,
            token,
            submitter,
            msg.sender,
            recipients.length,
            total,
            block.timestamp
        );

        // keep the older event too if you want backwards compatibility:
        emit BatchExecuted(batchId, token, msg.sender, recipients.length, total, block.timestamp);
    }

    // ============================
    // Existing Native Distribution (unchanged)
    // ============================

    function batchDistributeNative(
        bytes32 batchId,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external payable onlyRole(ADMIN_ROLE) whenNotPaused nonReentrant {
        _precheckBatch(batchId, recipients.length, amounts.length);

        uint256 total = _sum(amounts);
        require(msg.value == total, "NATIVE_VALUE_MISMATCH");

        isBatchExecuted[batchId] = true;

        for (uint256 i = 0; i < recipients.length; i++) {
            address to = recipients[i];
            uint256 amt = amounts[i];

            if (to == address(0)) revert ZeroAddress();
            if (amt == 0) revert InvalidAmount();

            (bool ok, ) = to.call{value: amt}("");
            require(ok, "NATIVE_TRANSFER_FAILED");

            emit TransferItem(batchId, address(0), to, amt);
        }

        emit BatchExecuted(batchId, address(0), msg.sender, recipients.length, total, block.timestamp);
    }

    // ============================
    // Internal helpers
    // ============================

    function _precheckBatch(bytes32 batchId, uint256 recipientsLen, uint256 amountsLen) internal view {
        if (batchId == bytes32(0)) revert InvalidAmount();
        if (isBatchExecuted[batchId]) revert BatchAlreadyExecuted(batchId);

        if (recipientsLen == 0) revert EmptyBatch();
        if (recipientsLen != amountsLen) revert InvalidArrayLengths();
        if (recipientsLen > maxBatchSize) revert BatchTooLarge(recipientsLen, maxBatchSize);
    }

    function _sum(uint256[] calldata amounts) internal pure returns (uint256 total) {
        for (uint256 i = 0; i < amounts.length; i++) total += amounts[i];
    }

    receive() external payable {}
}
