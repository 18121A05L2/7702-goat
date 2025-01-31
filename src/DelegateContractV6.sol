// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @notice VULNERABLE, UNAUDITED CODE. DO NOT USE IN PRODUCTION.
 * @author The Red Guild (@theredguild)
 */
contract DelegateContractV5 is Initializable, ReentrancyGuard {
    struct Call {
        bytes data;
        address to;
        uint256 value;
    }

    error Unauthorized();
    error ExternalCallFailed();
    error Paused();
    error SignatureExpired();
    error InvalidNonce();

    event Executed(address indexed to, uint256 value, bytes data);
    event NewGuardian(address indexed newGuardian);
    event Initialized();

    mapping(address account => bool isGuardian) guardians;
    bool public paused;
    uint256 public nonce;

    modifier whenNotPaused() {
        require(!paused, Paused());
        _;
    }

    function initialize(address[] memory newGuardians, uint256 validUntil, uint256 _nonce, bytes memory signature)
        external
        initializer
    {
        require(validUntil > block.timestamp, SignatureExpired());
        require(nonce == _nonce, InvalidNonce());

        address signer = ECDSA.recover(
            keccak256(
                abi.encode(newGuardians, validUntil, _nonce, keccak256("initialize"), address(this), block.chainid)
            ), // might as well be EIP712 structure data
            signature
        );
        require(signer == address(this), Unauthorized());

        for (uint256 i = 0; i < newGuardians.length; i++) {
            address newGuardian = newGuardians[i];
            guardians[newGuardian] = true;
            emit NewGuardian(newGuardian);
        }

        nonce++;
    }

    function setPause(bool _paused, uint256 validUntil, uint256 _nonce, bytes memory signature) external {
        require(validUntil > block.timestamp, SignatureExpired());
        require(nonce == _nonce, InvalidNonce());

        address signer = ECDSA.recover(
            keccak256(abi.encode(_paused, validUntil, _nonce, keccak256("setPause"), address(this), block.chainid)), // might as well be EIP712 structure data
            signature
        );
        require(signer == address(this), Unauthorized());

        paused = _paused;
        nonce++;
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

    function oneTimeSend(
        address executor,
        uint256 value,
        uint256 _nonce,
        uint256 validUntil,
        address target,
        bytes memory signature
    ) external {
        require(validUntil > block.timestamp, SignatureExpired());
        require(nonce == _nonce, InvalidNonce());

        address signer = ECDSA.recover(
            keccak256(
                abi.encode(executor, value, validUntil, _nonce, keccak256("oneTimeSend"), address(this), block.chainid)
            ), // might as well be EIP712 structure data
            signature
        );
        require(signer == address(this), Unauthorized());

        (bool success,) = target.call{value: value}("");
        require(success, ExternalCallFailed());
        nonce++;
    }

    receive() external payable {}
}
