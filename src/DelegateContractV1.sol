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
     * Casual readers might think this code allows accounts delegating to this contract to set their own guardians.
     * It does not. The guardians would be set at the delegate contract deployment,
     * and any account delegating to this contract wouldn't be able to set guardians.
     * Because this constructor is never executed in the context of an account delegating to this contract.
     */
    constructor(address[] memory newGuardians) {
        for (uint256 i = 0; i < newGuardians.length; i++) {
            address newGuardian = newGuardians[i];
            guardians[newGuardian] = true;
            emit NewGuardian(newGuardian);
        }
    }

    function execute(Call[] memory calls) public payable nonReentrant {
        require(msg.sender == address(this), Unauthorized()); // access control

        for (uint256 i = 0; i < calls.length; i++) {
            Call memory call = calls[i];

            (bool success,) = call.to.call{value: call.value}(call.data);
            require(success, ExternalCallFailed());

            emit Executed(call.to, call.value, call.data);
        }
    }

    function executeGuardian(Call[] calldata calls) external payable nonReentrant {
        require(guardians[msg.sender], Unauthorized()); // access control
        execute(calls);
    }

    receive() external payable {} // allow receiving ETH
}
