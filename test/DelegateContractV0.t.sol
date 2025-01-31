// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DelegateContractV0} from "../src/DelegateContractV0.sol";

contract DelegateContractV0Test is Test {
    address deployer = makeAddr("deployer");

    Vm.Wallet alice = vm.createWallet("alice");
    Vm.Wallet bob = vm.createWallet("bob");
    DelegateContractV0 delegateContract;

    function setUp() public {
        // Alice's account has no code
        require(alice.addr.code.length == 0);

        // Deploy delegate contract
        vm.prank(deployer);
        delegateContract = new DelegateContractV0();
    }

    function test_anyoneCanCall() public {
        // Alice's account starts with 1 ETH
        vm.deal(alice.addr, 1 ether);

        DelegateContractV0.Call[] memory calls = new DelegateContractV0.Call[](1);
        calls[0] = DelegateContractV0.Call({data: "", to: bob.addr, value: alice.addr.balance});

        vm.signAndAttachDelegation(address(delegateContract), alice.privateKey);
        DelegateContractV0(alice.addr).execute(calls);

        // Alice has code now, and no balance
        assertGt(alice.addr.code.length, 0);
        assertEq(alice.addr.balance, 0);
    }

    function test_cannotReceiveETH() public {
        DelegateContractV0.Call[] memory calls = new DelegateContractV0.Call[](1);
        calls[0] = DelegateContractV0.Call({data: "", to: bob.addr, value: alice.addr.balance});

        vm.signAndAttachDelegation(address(delegateContract), alice.privateKey);
        (bool success,) = address(0).call(""); // execute a call to submit the delegation tx
        require(success);

        assertGt(alice.addr.code.length, 0);

        // Account doesn't implement `receive` nor payable `fallback` functions
        vm.expectRevert();
        payable(alice.addr).transfer(1 ether);
    }
}
