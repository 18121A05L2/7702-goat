// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DelegateContractV5} from "../src/DelegateContractV5.sol";
import {DelegateContractV6} from "../src/DelegateContractV6.sol";
import "forge-std/console.sol";

contract DelegateContractV6Test is Test {
    address deployer = makeAddr("deployer");
    Vm.Wallet alice = vm.createWallet("alice");
    address guardian_1 = makeAddr("guardian_1");
    address guardian_2 = makeAddr("guardian_2");

    DelegateContractV5 delegateContractV5;
    DelegateContractV6 delegateContractV6;

    function setUp() public {
        vm.startPrank(deployer);
        delegateContractV5 = new DelegateContractV5();
        delegateContractV6 = new DelegateContractV6();
        vm.stopPrank();

        // Alice's account has no code
        require(alice.addr.code.length == 0);

        address[] memory guardians = new address[](1);
        guardians[0] = guardian_1;

        uint256 validUntil = block.timestamp + 1 days;

        bytes32 hash = keccak256(abi.encode(
            guardians, validUntil, keccak256("initialize"), address(delegateContractV5), block.chainid)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, hash);

        vm.signAndAttachDelegation(address(delegateContractV5), alice.privateKey);
        DelegateContractV5(payable(alice.addr)).initialize(
            guardians,
            validUntil,
            v, r, s
        );

        require(alice.addr.code.length > 0);

        assertTrue(DelegateContractV5(payable(alice.addr)).guardians(guardian_1), "Unexpected guardians");

        hash = keccak256(abi.encode(
            true, validUntil, keccak256("setPause"), address(delegateContractV5), block.chainid)
        );
        (v, r, s) = vm.sign(alice.privateKey, hash);
        DelegateContractV5(payable(alice.addr)).setPause(true, validUntil, v, r, s);

        assertTrue(DelegateContractV5(payable(alice.addr)).paused(), "Not paused");
    }

    function test_upgradeV5ToV6AndReinitializeWithNewGuardian() public {
        /**
         * forge inspect DelegateContractV5 storageLayout
         *  ╭-----------+--------------------------+------+--------+-------+-----------------------------------------------╮
            | Name      | Type                     | Slot | Offset | Bytes | Contract                                      |
            +==============================================================================================================+
            | _status   | uint256                  | 0    | 0      | 32    | src/DelegateContractV5.sol:DelegateContractV5 |
            |-----------+--------------------------+------+--------+-------+-----------------------------------------------|
            | paused    | bool                     | 1    | 0      | 1     | src/DelegateContractV5.sol:DelegateContractV5 |
            |-----------+--------------------------+------+--------+-------+-----------------------------------------------|
            | guardians | mapping(address => bool) | 2    | 0      | 32    | src/DelegateContractV5.sol:DelegateContractV5 |
            ╰-----------+--------------------------+------+--------+-------+-----------------------------------------------╯
         *
         * forge inspect DelegateContractV6 storageLayout
         *  ╭-----------+--------------------------+------+--------+-------+-----------------------------------------------╮
            | Name      | Type                     | Slot | Offset | Bytes | Contract                                      |
            +==============================================================================================================+
            | _status   | uint256                  | 0    | 0      | 32    | src/DelegateContractV6.sol:DelegateContractV6 |
            |-----------+--------------------------+------+--------+-------+-----------------------------------------------|
            | _paused   | bool                     | 1    | 0      | 1     | src/DelegateContractV6.sol:DelegateContractV6 |
            |-----------+--------------------------+------+--------+-------+-----------------------------------------------|
            | guardians | mapping(address => bool) | 2    | 0      | 32    | src/DelegateContractV6.sol:DelegateContractV6 |
            |-----------+--------------------------+------+--------+-------+-----------------------------------------------|
            | nonce     | uint256                  | 3    | 0      | 32    | src/DelegateContractV6.sol:DelegateContractV6 |
            ╰-----------+--------------------------+------+--------+-------+-----------------------------------------------╯Ç
         * 
         */

        // New guardian
        address[] memory guardians = new address[](1);
        guardians[0] = guardian_2;

        uint256 validUntil = block.timestamp + 1 days;
        uint256 nonce = 0;

        // Clean up storage slots where `paused` and `guardians[guardian_1]` are stored
        // (see https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html#mappings-and-dynamic-arrays)
        // If we didn't do this, the storage would still have the old values from the previous version
        uint256[] memory slotsToClean = new uint256[](2);
        slotsToClean[0] = 1; // paused is at slot 1
        slotsToClean[1] = uint256(keccak256(abi.encodePacked(abi.encode(guardian_1), uint256(2)))); // guardians[guardian_1]

        bytes32 hash = keccak256(abi.encode(
            guardians, slotsToClean, validUntil, nonce, keccak256("initialize"), address(delegateContractV6), block.chainid)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, hash);

        vm.signAndAttachDelegation(address(delegateContractV6), alice.privateKey);
        DelegateContractV6(payable(alice.addr)).initialize(
            guardians,
            slotsToClean,
            validUntil,
            nonce,
            v, r, s
        );
        require(alice.addr.code.length > 0);

        assertFalse(DelegateContractV6(payable(alice.addr)).paused(), "Still paused");
        assertTrue(DelegateContractV6(payable(alice.addr)).guardians(guardian_2), "Guardian 2 not set");
        assertEq(DelegateContractV6(payable(alice.addr)).nonce(), 1, "Unexpected nonce");
        assertFalse(DelegateContractV6(payable(alice.addr)).guardians(guardian_1), "Guardian 1 still set");
    }
}
