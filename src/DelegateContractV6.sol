// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @notice VULNERABLE, UNAUDITED CODE. DO NOT USE IN PRODUCTION.
 * @author The Red Guild (@theredguild)
 */
contract DelegateContractV6 is Initializable, ReentrancyGuard, Pausable {
    struct Call {
        bytes data;
        address to;
        uint256 value;
    }

    error Unauthorized();
    error ExternalCallFailed();
    error SignatureExpired();
    error InvalidNonce();

    event Executed(address indexed to, uint256 value, bytes data);
    event NewGuardian(address indexed newGuardian);
    event Cleaned(uint256 slot);

    address immutable _DELEGATE_CONTRACT_ADDRESS;

    mapping(address account => bool isGuardian) public guardians;
    uint256 public nonce;

    modifier notExpired(uint256 validUntil) {
        require(validUntil > block.timestamp, SignatureExpired());
        _;
    }

    modifier checkNonce(uint256 _nonce) {
        require(nonce == _nonce, InvalidNonce());
        _;
    }

    constructor() {
        _DELEGATE_CONTRACT_ADDRESS = address(this);
        _disableInitializers();
    }

    function _cleanStorage(uint256[] memory slots) private onlyInitializing {
        for (uint256 i = 0; i < slots.length; i++) {
            uint256 slot = slots[i];
            assembly {
                sstore(slot, 0)
            }
            emit Cleaned(slot);
        }
    }

    function initialize(address[] memory newGuardians, uint256[] memory slotsToClean, uint256 validUntil, uint256 _nonce, uint8 v, bytes32 r, bytes32 s)
        external
        reinitializer(6)
        notExpired(validUntil)
        checkNonce(_nonce)
    {
        _cleanStorage(slotsToClean);

        address signer = ECDSA.recover(
            keccak256(
                abi.encode(newGuardians, slotsToClean, validUntil, _nonce, keccak256("initialize"), _DELEGATE_CONTRACT_ADDRESS, block.chainid)
            ),
            v, r, s
        );
        require(signer == address(this), Unauthorized());

        for (uint256 i = 0; i < newGuardians.length; i++) {
            address newGuardian = newGuardians[i];
            guardians[newGuardian] = true;
            emit NewGuardian(newGuardian);
        }

        nonce++;
    }

    function setPause(bool pause, uint256 validUntil, uint256 _nonce, uint8 v, bytes32 r, bytes32 s)
        external
        notExpired(validUntil)
        checkNonce(_nonce)
    {
        address signer = ECDSA.recover(
            keccak256(abi.encode(pause, validUntil, _nonce, keccak256("setPause"), _DELEGATE_CONTRACT_ADDRESS, block.chainid)),
            v, r, s
        );
        require(signer == address(this), Unauthorized());

        nonce++;

        if(pause) {
            _pause();
        } else {
            _unpause();
        }
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
        uint256 value,
        uint256 _nonce,
        uint256 validUntil,
        address target,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        notExpired(validUntil)
        nonReentrant
        whenNotPaused
        checkNonce(_nonce)
    {
        address signer = ECDSA.recover(
            keccak256(
                abi.encode(msg.sender, value, validUntil, target, _nonce, keccak256("oneTimeSend"), _DELEGATE_CONTRACT_ADDRESS, block.chainid)
            ),
            v, r, s
        );
        require(signer == address(this), Unauthorized());

        nonce++;

        (bool success,) = target.call{value: value}("");
        require(success, ExternalCallFailed());
    }

    receive() external payable {}
}
