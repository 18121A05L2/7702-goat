// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/console.sol";

/**
 * @notice VULNERABLE, UNAUDITED CODE. DO NOT USE IN PRODUCTION.
 * @dev A version of `DelegateContractV3` using `Initializable`
 * @author The Red Guild (@theredguild)
 */
contract DelegateContractV3_1 is Initializable, ReentrancyGuard {
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

    mapping(address account => bool isGuardian) guardians;

    constructor() {
        _disableInitializers();
    }

    function initialize(address[] memory newGuardians, uint8 v, bytes32 r, bytes32 s) external initializer {
        address signer = ECDSA.recover(
            keccak256(abi.encode(newGuardians, address(this))),
            v, r, s
        );
        require(signer == address(this), Unauthorized());

        for (uint256 i = 0; i < newGuardians.length; i++) {
            address newGuardian = newGuardians[i];
            guardians[newGuardian] = true;
            emit NewGuardian(newGuardian);
        }
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
