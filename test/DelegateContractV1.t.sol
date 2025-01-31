// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DelegateContractV1} from "../src/DelegateContractV1.sol";

contract DelegateContractV1Test is Test {
    address deployer = makeAddr("deployer");
    Vm.Wallet alice = vm.createWallet("alice");
    Vm.Wallet bob = vm.createWallet("bob");

    address guardian_1 = makeAddr("guardian_1");
    address guardian_2 = makeAddr("guardian_2");

    DelegateContractV1 delegateContract;

    // Show that guardians are set during deployment, executing the `constructor` like any regular smart contract.
    function setUp() public {
        // Alice's account has no code
        require(alice.addr.code.length == 0);

        address[] memory guardians = new address[](2);
        guardians[0] = guardian_1;
        guardians[1] = guardian_2;

        // Deploy delegate contract
        vm.prank(deployer);
        delegateContract = new DelegateContractV1(guardians);

        assertEq(delegateContract.guardians(guardian_1), true);
        assertEq(delegateContract.guardians(guardian_2), true);
    }

    // Show that guardians are for the delegate contract. Any account delegating to it won't have guardians.
    // And there's no way to set them given how `DelegateContactV1` works, because there's no notion of initcode during delegation.
    function test_noGuardiansInAccounts() public {
        vm.signAndAttachDelegation(address(delegateContract), alice.privateKey);
        vm.signAndAttachDelegation(address(delegateContract), bob.privateKey);
        address(0).call("");

        assertGt(alice.addr.code.length, 0);
        assertGt(bob.addr.code.length, 0);

        assertFalse(DelegateContractV1(payable(alice.addr)).guardians(guardian_1));
        assertFalse(DelegateContractV1(payable(alice.addr)).guardians(guardian_2));

        assertFalse(DelegateContractV1(payable(bob.addr)).guardians(guardian_1));
        assertFalse(DelegateContractV1(payable(bob.addr)).guardians(guardian_2));
    }
}
