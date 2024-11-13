// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__FaildToTransact(bytes);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IEntryPoint private immutable i_entryPoint;


    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyFromEntryPoint() {
        if (msg.sender != address(i_entryPoint))
            revert MinimalAccount__NotFromEntryPoint();
        _;
    }

    modifier onlyFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner())
            revert MinimalAccount__NotFromEntryPointOrOwner();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function execute(
        address dest,
        uint256 amount,
        bytes calldata functionData
    ) external onlyFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: amount}(
            functionData
        );
        if (!success) revert MinimalAccount__FaildToTransact(result);
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external onlyFromEntryPoint returns (uint256 validationData) {
        validationData = _validSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view returns (uint256) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            userOpHash
        );
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) return SIG_VALIDATION_FAILED;
        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFund) internal {
        if (missingAccountFund == 0) return;
        (bool success, ) = payable(msg.sender).call{
            value: missingAccountFund,
            gas: type(uint256).max
        }("");
        (success);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/
    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
