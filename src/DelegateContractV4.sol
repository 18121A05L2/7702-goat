// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @notice VULNERABLE, UNAUDITED CODE. DO NOT USE IN PRODUCTION.
 * @author The Red Guild (@theredguild)
 */
contract DelegateContractV4 is Initializable, ReentrancyGuard { // Now this is Initializable
    struct Call {
        bytes data;
        address to;
        uint256 value;
    }

    error Unauthorized();
    error ExternalCallFailed();
    error AlreadyInitialized();
    error Paused();
    error SignatureExpired();

    event Executed(address indexed to, uint256 value, bytes data);
    event NewGuardian(address indexed newGuardian);

    address immutable _DELEGATE_CONTRACT_ADDRESS;

    bool public paused; // `paused` took the place of `DelegateContractV3::init`
    mapping(address account => bool isGuardian) public guardians;

    modifier whenNotPaused() {
        require(!paused, Paused());
        _;
    }

    modifier notExpired(uint256 validUntil) {
        require(validUntil > block.timestamp, SignatureExpired());
        _;
    }

    constructor() {
        _DELEGATE_CONTRACT_ADDRESS = address(this);
        _disableInitializers();
    }

    function initialize(address[] memory newGuardians, uint256 validUntil, uint8 v, bytes32 r, bytes32 s)
        external
        initializer
        whenNotPaused
        notExpired(validUntil)
    {
        address signer = ECDSA.recover(
            keccak256(abi.encode(newGuardians, validUntil, keccak256("initialize"), _DELEGATE_CONTRACT_ADDRESS, block.chainid)), // might as well be EIP712 structure data
            v, r, s
        );
        require(signer == address(this), Unauthorized());

        for (uint256 i = 0; i < newGuardians.length; i++) {
            address newGuardian = newGuardians[i];
            guardians[newGuardian] = true;
            emit NewGuardian(newGuardian);
        }
    }

    function setPause(bool _paused, uint256 validUntil, uint8 v, bytes32 r, bytes32 s) external notExpired(validUntil) {
        address signer = ECDSA.recover(
            keccak256(abi.encode(_paused, validUntil, keccak256("setPause"), _DELEGATE_CONTRACT_ADDRESS, block.chainid)), // might as well be EIP712 structure data
            v, r, s
        );
        require(guardians[signer], Unauthorized());

        paused = _paused;
    }

    function execute(Call[] memory calls) public payable nonReentrant whenNotPaused {
        require(msg.sender == address(this), Unauthorized());

        for (uint256 i = 0; i < calls.length; i++) {
            Call memory call = calls[i];

            (bool success,) = call.to.call{value: call.value}(call.data);
            require(success, ExternalCallFailed());

            emit Executed(call.to, call.value, call.data);
        }
    }

    function executeGuardian(Call[] calldata calls) external payable nonReentrant whenNotPaused {
        require(guardians[msg.sender], Unauthorized());
        execute(calls);
    }

    receive() external payable {}
}
