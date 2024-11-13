// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp} from "script/SendPackedUserOp.s.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig helper;
    MinimalAccount minimalAccount;
    ERC20Mock usdcContract;
    address randomUser = makeAddr("randomUser");
    uint256 constant AMOUNT = 1e18;
    SendPackedUserOp sendPackedUserOp;

    function setUp() public {
        DeployMinimal deployer = new DeployMinimal();
        (helper, minimalAccount) = deployer.deployMinimalAccount();
        usdcContract = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testOwnerCanExecuteCommand() public {
        address dest = address(usdcContract);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            usdcContract.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        assertEq(usdcContract.balanceOf(address(minimalAccount)), 0);
        vm.startPrank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);
        vm.stopPrank();
        assertEq(usdcContract.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOWnerCanNotExecuteCommand() public {
        address dest = address(usdcContract);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            usdcContract.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        assertEq(usdcContract.balanceOf(address(minimalAccount)), 0);
        vm.prank(randomUser);
        vm.expectRevert(
            MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector
        );
        minimalAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() public {
        address dest = address(usdcContract);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            usdcContract.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        bytes memory executeFunctionData = abi.encodeWithSelector(
            minimalAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory packedUserOp = sendPackedUserOp
            .generateSignedUserOperation(
                executeFunctionData,
                helper.getConfig(),
                address(minimalAccount)
            );
        bytes32 packedUserOpHash = IEntryPoint(helper.getConfig().entryPoint)
            .getUserOpHash(packedUserOp);

        address actualSigner = ECDSA.recover(
            packedUserOpHash.toEthSignedMessageHash(),
            packedUserOp.signature
        );
        assertEq(actualSigner, minimalAccount.owner());
    }

    function testValidationOfUserOp() public {
        address dest = address(usdcContract);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            usdcContract.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        bytes memory executeFunctionData = abi.encodeWithSelector(
            minimalAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory packedUserOp = sendPackedUserOp
            .generateSignedUserOperation(
                executeFunctionData,
                helper.getConfig(),
                address(minimalAccount)
            );
        bytes32 packedUserOpHash = IEntryPoint(helper.getConfig().entryPoint)
            .getUserOpHash(packedUserOp);

        uint256 missingAccountFunds = 1e18;

        vm.prank(helper.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(
            packedUserOp,
            packedUserOpHash,
            missingAccountFunds
        );

        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommands() public {
        address dest = address(usdcContract);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            usdcContract.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        bytes memory executeFunctionData = abi.encodeWithSelector(
            minimalAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory packedUserOp = sendPackedUserOp
            .generateSignedUserOperation(
                executeFunctionData,
                helper.getConfig(),
                address(minimalAccount)
            );

        vm.deal(address(minimalAccount), AMOUNT);
        assertEq(usdcContract.balanceOf(address(minimalAccount)), 0);
        
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.prank(randomUser);
        IEntryPoint(helper.getConfig().entryPoint).handleOps(
            ops,
            payable(randomUser)
        );

        assertEq(usdcContract.balanceOf(address(minimalAccount)), AMOUNT);
    }
}
