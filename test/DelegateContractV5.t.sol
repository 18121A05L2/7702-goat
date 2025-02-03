// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DelegateContractV5} from "../src/DelegateContractV5.sol";
import "forge-std/console.sol";

contract DelegateContractV5Test is Test {
    address deployer = makeAddr("deployer");
    Vm.Wallet alice = vm.createWallet("alice");
    address guardian_1 = makeAddr("guardian_1");

    DelegateContractV5 delegateContractV5;

    function setUp() public {
        vm.prank(deployer);
        delegateContractV5 = new DelegateContractV5();

        // Alice's account has no code
        require(alice.addr.code.length == 0);
    }

    function test_oneTimeSendCanBeReplayed() public {
        vm.deal(alice.addr, 1 ether);

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

        address oneTimeSender = makeAddr("oneTimeSender");
        address receiver = makeAddr("receiver");
        uint256 amount = 0.1 ether;

        hash = keccak256(abi.encode(
            oneTimeSender,
            amount,
            validUntil,
            receiver,
            keccak256("oneTimeSend"),
            address(delegateContractV5),
            block.chainid
        ));
        (v, r, s) = vm.sign(alice.privateKey, hash);

        // Alice's signature is replayable as long as it's not expired on this contract, because there's no nonce mechanism
        vm.startPrank(oneTimeSender);
        for(uint256 i = 0; i < 10; i++) {
            DelegateContractV5(payable(alice.addr)).oneTimeSend(
                amount,
                validUntil,
                receiver,
                v, r, s
            );
        }
        vm.stopPrank();

        assertEq(alice.addr.balance, 0 ether);
        assertEq(receiver.balance, 1 ether);
    }
}
