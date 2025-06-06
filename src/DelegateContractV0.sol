// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @notice VULNERABLE, UNAUDITED CODE. DO NOT USE IN PRODUCTION.
 * @author The Red Guild (@theredguild)
 */
contract DelegateContractV0 {
    struct Call {
        bytes data;
        address to;
        uint256 value;
    }

    error ExternalCallFailed();

    function execute(Call[] memory calls) external payable { // lack of access control
        for (uint256 i = 0; i < calls.length; i++) {
            Call memory call = calls[i];

            (bool success,) = call.to.call{value: call.value}(call.data);
            require(success, ExternalCallFailed());
        }
    }

    // no receive function nor payable fallback function
}
