// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @notice Auth contract with two levels of access - `owner` can access both `onlyOwner` and `onlyOperator` functions,
 *  while `operator` can only access `onlyOperator` functions.
 */
abstract contract Owned {
    address public owner;
    address public nominatedOwner;
    address public operator;

    event NewOwner(address indexed oldOwner, address indexed newOwner);
    event NominatedOwner(address indexed nominatedOwner);
    event NewOperator(address indexed oldOperator, address indexed newOperator);

    error Unauthorized();
    error ZeroAddress();

    constructor(address owner_, address operator_) {
        if (owner_ == address(0)) revert ZeroAddress();
        if (operator_ == address(0)) revert ZeroAddress();
        emit NewOwner(address(0), owner_);
        emit NewOperator(address(0), operator_);
        owner = owner_;
        operator = operator_;
    }

    function setOperator(address operator_) public virtual onlyOwner {
        if (operator_ == address(0)) revert ZeroAddress();
        emit NewOperator(operator, operator_);
        operator = operator_;
    }

    function nominateOwner(address nominatedOwner_) public virtual onlyOwner {
        emit NominatedOwner(nominatedOwner_);
        nominatedOwner = nominatedOwner_;
    }

    function acceptOwnership() public virtual onlyNominatedOwner {
        emit NewOwner(owner, nominatedOwner);
        owner = nominatedOwner;
        nominatedOwner = address(0);
    }

    modifier onlyOwner() virtual {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyNominatedOwner() virtual {
        if (msg.sender != nominatedOwner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() virtual {
        if (msg.sender != owner && msg.sender != operator) revert Unauthorized();
        _;
    }
}
