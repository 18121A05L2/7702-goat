// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/**
 * @notice VULNERABLE, UNAUDITED CODE. DO NOT USE IN PRODUCTION.
 * @author The Red Guild (@theredguild)
 */
contract DelegateContractV1 is ReentrancyGuard {
    struct Call {
        bytes data;
        address to;
        uint256 value;
    }

    error Unauthorized();
    error ExternalCallFailed();

    event Executed(address indexed to, uint256 value, bytes data);
    event NewGuardian(address indexed newGuardian);

    mapping(address account => bool isGuardian) public guardians;

    /**
     * @notice Sets the initial guardians for your account
     * @param newGuardians The guardians you'd like to set
     */
    constructor(address[] memory newGuardians) {
        for (uint256 i = 0; i < newGuardians.length; i++) {
            address newGuardian = newGuardians[i];
            guardians[newGuardian] = true;
            emit NewGuardian(newGuardian);
        }
    }

    function execute(Call[] memory calls) public payable nonReentrant {
        // prevent reentrant calls
        require(msg.sender == address(this), Unauthorized()); // access control

        for (uint256 i = 0; i < calls.length; i++) {
            Call memory call = calls[i];

            (bool success,) = call.to.call{value: call.value}(call.data);
            require(success, ExternalCallFailed());

            emit Executed(call.to, call.value, call.data);
        }
    }

    function executeGuardian(Call[] calldata calls) external payable nonReentrant {
        // prevent reentrant calls
        require(guardians[msg.sender], Unauthorized()); // access control
        execute(calls);
    }

    receive() external payable {} // allow receiving ETH
}
