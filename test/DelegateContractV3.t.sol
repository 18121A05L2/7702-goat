// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DelegateContractV3} from "../src/DelegateContractV3.sol";
import {DelegateContractV3_1} from "../src/DelegateContractV3_1.sol";

contract DelegateContractV3Test is Test {
    address deployer = makeAddr("deployer");
    Vm.Wallet alice = vm.createWallet("alice");
    address guardian_1 = makeAddr("guardian_1");

    DelegateContractV3 delegateContract;
    
    // Signature params that can be replayed cross-chain
    uint8 v;
    bytes32 r;
    bytes32 s;

    function setUp() public {
        // Alice's account has no code
        require(alice.addr.code.length == 0);
        
        address[] memory guardians = new address[](1);
        guardians[0] = guardian_1;

        // Alice signs initialization data for the delegate contract. This doesn't include chain ID.
        bytes32 hash = keccak256(abi.encode(guardians, alice.addr));
        (v, r, s) = vm.sign(alice.privateKey, hash);
    }

    function test_initializeWithSignature() public {
        // Deploy delegate contract
        vm.prank(deployer);
        delegateContract = new DelegateContractV3();

        address[] memory guardians = new address[](1);
        guardians[0] = guardian_1;

        // It's possible to set the account's code and initialize it with a signature in the same tx
        // By design, the tx can be submitted by anyone, as long as they have both signatures (one for the 7702 data and the other for initialization)
        vm.signAndAttachDelegation(address(delegateContract), alice.privateKey);
        DelegateContractV3(payable(alice.addr)).initialize(guardians, v, r, s);

        // The same initialization signature can be replayed on another contract
        DelegateContractV3_1 anotherDelegateContract = new DelegateContractV3_1();
        vm.signAndAttachDelegation(address(anotherDelegateContract), alice.privateKey);
        DelegateContractV3_1(payable(alice.addr)).initialize(guardians, v, r, s);
        
        assertGt(alice.addr.code.length, 0);
    }

    function test_replayInitializeWithSignature() public {
        vm.createSelectFork("https://odyssey.ithaca.xyz");

        // Alice's account has no code
        require(alice.addr.code.length == 0);

        // Deploy delegate contract
        vm.prank(deployer);
        delegateContract = new DelegateContractV3();

        address[] memory guardians = new address[](1);
        guardians[0] = guardian_1;

        vm.signAndAttachDelegation(address(delegateContract), alice.privateKey);
        DelegateContractV3(payable(alice.addr)).initialize(guardians, v, r, s); // // The same initialization signature can be replayed on another chain
    }
}
