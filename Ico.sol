// SPDX-License-Identifier: MIT

// 10 CR Token Mint
// P1 1 token -> 0.001 MATIC/ETH & Sale Range 0-1CR (0-1CR)
// P1 2 token -> 0.003 MATIC/ETH & Sale Range 1-5CR (0-2CR)
// P1 3 token -> 0.005 MATIC/ETH & Sale Range 5-10CR (0-3CR)

// 1000000000000000

pragma solidity ^0.8.7;

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

error InvalidAmountICO();

contract ICO {
    IERC20 public immutable token;
    address payable public owner;
    uint256 public tokenSold; //Counter of total token sold
    uint256 public price;

    uint256 public constant PHASEONE_MAXLIMIT = 10;
    uint256 public constant PHASETWO_MAXLIMIT = 50;
    uint256 public constant PHASETHREE_MAXLIMIT = 100;

    enum Phases {
        ONE,
        TWO,
        THREE
    }

    Phases public currentPhase;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only Owner");
        _;
    }

    constructor(IERC20 _token, uint256 _price) {
        token = _token;
        owner = payable(msg.sender);
        currentPhase = Phases.ONE;
        price = _price;
    }

    function buyToken(uint256 _amount) external payable {
        require(msg.sender != address(0), "Zero Address");
        require(_amount > 0, "Invalid Amount");

        if (tokenSold <= PHASEONE_MAXLIMIT && currentPhase == Phases.ONE) {
            require(
                msg.value == (price * _amount),
                "MUST PAY 0.001 ETH PER TOKEN"
            );
        } else if (
            tokenSold > PHASEONE_MAXLIMIT &&
            tokenSold <= PHASETWO_MAXLIMIT &&
            currentPhase == Phases.TWO
        ) {
            price = 0.003 ether;
            require(
                msg.value == (price * _amount),
                "MUST PAY 0.003 ETH PER TOKEN"
            );
        } else if (
            tokenSold > PHASETWO_MAXLIMIT &&
            tokenSold <= PHASETHREE_MAXLIMIT &&
            currentPhase == Phases.THREE
        ) {
            price = 0.005 ether;
            require(
                msg.value == (price * _amount),
                "MUST PAY 0.005 ETH PER TOKEN"
            );
        } else {
            revert InvalidAmountICO();
        }

        tokenSold += _amount;
        token.transfer(msg.sender, _amount);
    }

    // function updatePhase() external onlyOwner {
    //     if(tokenSold )
    // }

    function withdraw() external onlyOwner {
        (bool ok, ) = owner.call{value: address(this).balance}("");
        require(ok, "Tx Failed");
    }

    function withdrawToken(IERC20 _token) external onlyOwner {
        uint256 amount = _token.balanceOf(address(this));
        _token.transfer(msg.sender, amount);
    }
}