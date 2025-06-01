// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DelegateContractV3} from "../src/DelegateContractV3.sol";
import {DelegateContractV4} from "../src/DelegateContractV4.sol";
import "forge-std/console.sol";

contract DelegateContractV4Test is Test {
    address deployer = makeAddr("deployer");
    Vm.Wallet alice = vm.createWallet("alice");
    address guardian_1 = makeAddr("guardian_1");

    DelegateContractV3 delegateContractV3;
    DelegateContractV4 delegateContractV4;

    function setUp() public {
        // Deploy the two versions of the delegate contracts
        vm.startPrank(deployer);
        delegateContractV3 = new DelegateContractV3();
        delegateContractV4 = new DelegateContractV4();
        vm.stopPrank();

        // Alice's account has no code
        require(alice.addr.code.length == 0);
    }

    function test_upgradeV3ToV4() public {
        address[] memory guardians = new address[](1);
        guardians[0] = guardian_1;

        bytes32 hash = keccak256(abi.encode(guardians, alice.addr));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, hash);

        // Alice starts using V3
        vm.signAndAttachDelegation(address(delegateContractV3), alice.privateKey);
        DelegateContractV3(payable(alice.addr)).initialize(guardians, v, r, s);

        /**
         * The storage layout of DelegateContractV3 is as follows:
         *
         * forge inspect DelegateContractV3 storageLayout
         *         ╭-----------+--------------------------+------+--------+-------+-----------------------------------------------╮
         *         | Name      | Type                     | Slot | Offset | Bytes | Contract                                      |
         *         +==============================================================================================================+
         *         | _status   | uint256                  | 0    | 0      | 32    | src/DelegateContractV3.sol:DelegateContractV3 |
         *         |-----------+--------------------------+------+--------+-------+-----------------------------------------------|
         *         | init      | bool                     | 1    | 0      | 1     | src/DelegateContractV3.sol:DelegateContractV3 |
         *         |-----------+--------------------------+------+--------+-------+-----------------------------------------------|
         *         | guardians | mapping(address => bool) | 2    | 0      | 32    | src/DelegateContractV3.sol:DelegateContractV3 |
         *         ╰-----------+--------------------------+------+--------+-------+-----------------------------------------------╯
         */

        // Alice moves to V4
        vm.signAndAttachDelegation(address(delegateContractV4), alice.privateKey);

        /**
         * The storage layout of DelegateContractV4 is as follows:
         *
         * forge inspect DelegateContractV4 storageLayout
         *         ╭-----------+--------------------------+------+--------+-------+-----------------------------------------------╮
         *         | Name      | Type                     | Slot | Offset | Bytes | Contract                                      |
         *         +==============================================================================================================+
         *         | _status   | uint256                  | 0    | 0      | 32    | src/DelegateContractV4.sol:DelegateContractV4 |
         *         |-----------+--------------------------+------+--------+-------+-----------------------------------------------|
         *         | paused    | bool                     | 1    | 0      | 1     | src/DelegateContractV4.sol:DelegateContractV4 |
         *         |-----------+--------------------------+------+--------+-------+-----------------------------------------------|
         *         | guardians | mapping(address => bool) | 2    | 0      | 32    | src/DelegateContractV4.sol:DelegateContractV4 |
         *         ╰-----------+--------------------------+------+--------+-------+-----------------------------------------------╯
         */

        // Slot 0 continues to be ReentrancyGuard::_status
        assertEq(vm.load(alice.addr, 0), bytes32(0));

        // Now slot 1 is DelegateContractV4::paused instead of DelegateContractV3::init
        // but the value remains set to 1 from the previous version.
        assertEq(vm.load(alice.addr, bytes32(uint256(1))), bytes32(uint256(1)));

        // That means the account now is paused due to storage collision
        assertTrue(DelegateContractV4(payable(alice.addr)).paused());
    }
}
