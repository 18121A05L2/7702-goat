// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DelegateContractV3} from "../src/DelegateContractV3.sol";
import {DelegateContractV4} from "../src/DelegateContractV4.sol";

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

        // Alice moves to V4
        vm.signAndAttachDelegation(address(delegateContractV4), alice.privateKey);
        address(0).call("");

        // The account now is paused due to storage collision in V4
        assertTrue(DelegateContractV4(payable(alice.addr)).paused());
    }
}
