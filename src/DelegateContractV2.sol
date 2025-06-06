// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/**
 * @notice VULNERABLE, UNAUDITED CODE. DO NOT USE IN PRODUCTION.
 * @author The Red Guild (@theredguild)
 */
contract DelegateContractV2 is ReentrancyGuard {
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
        init = true; // if this wasn't here, you'd be able to execute calls from the delegate contract itself
    }

    function initialize(address[] memory newGuardians) external { // can be called by anyone
        require(!init, AlreadyInitialized());
        for (uint256 i = 0; i < newGuardians.length; i++) {
            address newGuardian = newGuardians[i];
            guardians[newGuardian] = true;
            emit NewGuardian(newGuardian);
        }
        // not setting `init` to true
    }

    function execute(Call[] calldata calls) public payable nonReentrant {
        require(msg.sender == address(this), Unauthorized());
        _execute(calls);
    }

    function executeGuardian(Call[] calldata calls) external payable nonReentrant {
        require(guardians[msg.sender], Unauthorized());
        _execute(calls);
    }

    function _execute(Call[] calldata calls) private {
        for (uint256 i = 0; i < calls.length; i++) {
            Call memory call = calls[i];

            (bool success,) = call.to.call{value: call.value}(call.data);
            require(success, ExternalCallFailed());

            emit Executed(call.to, call.value, call.data);
        }
    }

    receive() external payable {}
}
