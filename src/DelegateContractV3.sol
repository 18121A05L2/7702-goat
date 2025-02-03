// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/console.sol";

/**
 * @notice VULNERABLE, UNAUDITED CODE. DO NOT USE IN PRODUCTION.
 * @author The Red Guild (@theredguild)
 */
contract DelegateContractV3 is ReentrancyGuard {
    struct Call {
        bytes data;
        address to;
        uint256 value;
    }

    error Unauthorized();
    error ExternalCallFailed();
    error AlreadyInitialized();

    event Executed(address indexed to, uint256 value, bytes data);
    event NewGuardian(address indexed newGuardian);

    bool public init;
    mapping(address account => bool isGuardian) public guardians;

    constructor() {
        init = true; 
    }

    /**
     * Note that address(this) will change depending on whether you're executing this code
     * at the delegate contract itself, or in the context of an account delegating to it.
     */
    function getHash(address[] memory newGuardians) public view returns (bytes32) {
        return keccak256(abi.encode(newGuardians, address(this)));
    }

    function initialize(address[] memory newGuardians, uint8 v, bytes32 r, bytes32 s) external {
        require(!init, AlreadyInitialized());

        address signer = ECDSA.recover(
            keccak256(abi.encode(newGuardians, address(this))), // weak signature (e.g., replayable)
            v, r, s
        );
        require(signer == address(this), Unauthorized());

        for (uint256 i = 0; i < newGuardians.length; i++) {
            address newGuardian = newGuardians[i];
            guardians[newGuardian] = true;
            emit NewGuardian(newGuardian);
        }

        init = true;
    }

    function execute(Call[] memory calls) public payable nonReentrant {
        require(msg.sender == address(this), Unauthorized());

        for (uint256 i = 0; i < calls.length; i++) {
            Call memory call = calls[i];

            (bool success,) = call.to.call{value: call.value}(call.data);
            require(success, ExternalCallFailed());

            emit Executed(call.to, call.value, call.data);
        }
    }

    function executeGuardian(Call[] calldata calls) external payable nonReentrant {
        require(guardians[msg.sender]);
        execute(calls);
    }

    receive() external payable {}
}
