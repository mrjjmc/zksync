// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.0;

pragma experimental ABIEncoderV2;

import "./ReentrancyGuard.sol";
import "./SafeMath.sol";
import "./SafeMathUInt128.sol";
import "./SafeCast.sol";
import "./Utils.sol";

import "./Storage.sol";
import "./Config.sol";
import "./Events.sol";

import "./Bytes.sol";
import "./Operations.sol";

import "./UpgradeableMaster.sol";

contract AdditionalZkSync is Storage, Config, Events, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMathUInt128 for uint128;

    function performExodus(
        StoredBlockInfo memory _storedBlockInfo,
        address _owner,
        uint32 _accountId,
        uint32 _tokenId,
        uint128 _amount,
        uint32 _nftCreatorAccountId,
        address _nftCreatorAddress,
        uint32 _nftSerialId,
        bytes32 _nftContentHash,
        uint256[] calldata _proof
    ) external {
        // Require statements combined
        require(
            _accountId <= MAX_ACCOUNT_ID && _accountId != SPECIAL_ACCOUNT_ID && _tokenId < SPECIAL_NFT_TOKEN_ID && exodusMode &&
            !performedExodus[_accountId][_tokenId] &&
            storedBlockHashes[totalBlocksExecuted] == hashStoredBlockInfo(_storedBlockInfo),
            "Invalid parameters or not in exodus mode"
        );

        bool proofCorrect = verifier.verifyExitProof(
            _storedBlockInfo.stateHash,
            _accountId,
            _owner,
            _tokenId,
            _amount,
            _nftCreatorAccountId,
            _nftCreatorAddress,
            _nftSerialId,
            _nftContentHash,
            _proof
        );
        require(proofCorrect, "Invalid proof");

        if (_tokenId <= MAX_FUNGIBLE_TOKEN_ID) {
            // Inline increaseBalanceToWithdraw
            bytes22 packedBalanceKey = packAddressAndTokenId(_owner, uint16(_tokenId));
            uint128 balance = pendingBalances[packedBalanceKey].balanceToWithdraw;
            pendingBalances[packedBalanceKey] = PendingBalance(balance.add(_amount), FILLED_GAS_RESERVE_VALUE);
            emit WithdrawalPending(uint16(_tokenId), _owner, _amount);
        } else {
            require(_amount != 0, "Unsupported nft amount");
            Operations.WithdrawNFT memory withdrawNftOp = Operations.WithdrawNFT(
                _nftCreatorAccountId,
                _nftCreatorAddress,
                _nftSerialId,
                _nftContentHash,
                _owner,
                _tokenId
            );
            pendingWithdrawnNFTs[_tokenId] = withdrawNftOp;
            emit WithdrawalNFTPending(_tokenId);
        }
        performedExodus[_accountId][_tokenId] = true;
    }

    function cancelOutstandingDepositsForExodusMode(uint64 _n, bytes[] calldata _depositsPubdata) external {
        require(exodusMode, "Exodus mode not active");
        uint64 toProcess = Utils.minU64(totalOpenPriorityRequests, _n);
        require(toProcess > 0, "No deposits to process");
        uint64 currentDepositIdx = 0;
        for (uint64 id = firstPriorityRequestId; id < firstPriorityRequestId + toProcess; ++id) {
            if (priorityRequests[id].opType == Operations.OpType.Deposit) {
                bytes memory depositPubdata = _depositsPubdata[currentDepositIdx];
                require(Utils.hashBytesToBytes20(depositPubdata) == priorityRequests[id].hashedPubData, "Incorrect deposit data");
                ++currentDepositIdx;

                Operations.Deposit memory op = Operations.readDepositPubdata(depositPubdata);
                bytes22 packedBalanceKey = packAddressAndTokenId(op.owner, uint16(op.tokenId));
                pendingBalances[packedBalanceKey].balanceToWithdraw += op.amount;
            }
            delete priorityRequests[id];
        }
        firstPriorityRequestId += toProcess;
        totalOpenPriorityRequests -= toProcess;
    }

    uint256 internal constant SECURITY_COUNCIL_THRESHOLD = $$(SECURITY_COUNCIL_THRESHOLD);

    function approveCutUpgradeNoticePeriod(address addr) internal {
        address payable[SECURITY_COUNCIL_MEMBERS_NUMBER] memory SECURITY_COUNCIL_MEMBERS = [$(SECURITY_COUNCIL_MEMBERS)];
        for (uint256 id = 0; id < SECURITY_COUNCIL_MEMBERS_NUMBER; ++id) {
            if (SECURITY_COUNCIL_MEMBERS[id] == addr) {
                if (!securityCouncilApproves[id]) {
                    securityCouncilApproves[id] = true;
                    numberOfApprovalsFromSecurityCouncil += 1;
                    emit ApproveCutUpgradeNoticePeriod(addr);
                    if (numberOfApprovalsFromSecurityCouncil >= SECURITY_COUNCIL_THRESHOLD && approvedUpgradeNoticePeriod > 0) {
                        approvedUpgradeNoticePeriod = 0;
                        emit NoticePeriodChange(approvedUpgradeNoticePeriod);
                    }
                }
                break;
            }
        }
    }

    // Other functions remain the same
}
