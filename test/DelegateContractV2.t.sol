// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DelegateContractV2} from "../src/DelegateContractV2.sol";

contract DelegateContractV2Test is Test {
    address deployer = makeAddr("deployer");
    Vm.Wallet alice = vm.createWallet("alice");
    Vm.Wallet bob = vm.createWallet("bob");

    DelegateContractV2 delegateContract;

    function setUp() public {
        // Alice's account has no code
        require(alice.addr.code.length == 0);

        // Deploy delegate contract
        vm.prank(deployer);
        delegateContract = new DelegateContractV2();

        assertTrue(delegateContract.init());
    }

    function test_anyoneCanInitialize() public {
        vm.deal(alice.addr, 1 ether);

        vm.signAndAttachDelegation(address(delegateContract), alice.privateKey);
        vm.prank(alice.addr); // not needed to be alice herself - by design, anyone with the signed authorization can attach and submit
        address(0).call("");

        assertGt(alice.addr.code.length, 0);

        address[] memory guardians = new address[](1);
        guardians[0] = bob.addr;

        // Bob (or anyone) initializes Alice's account
        vm.startPrank(bob.addr);
        DelegateContractV2(payable(alice.addr)).initialize(guardians);

        // Once a guardian, can do anything
        DelegateContractV2.Call[] memory calls = new DelegateContractV2.Call[](1);
        calls[0] = DelegateContractV2.Call({data: "", to: bob.addr, value: alice.addr.balance});
        DelegateContractV2(payable(alice.addr)).executeGuardian(calls);

        vm.stopPrank();

        assertEq(alice.addr.balance, 0);
    }
}
