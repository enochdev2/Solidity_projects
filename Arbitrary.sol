pragma solidity ^0.6.6;

import './UniswapV2Library.sol';
import './interfaces/IUniswapV2Router02.sol';
import' ./interfaces/IUniswapV2Pair.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IERC20.sol';


contract Arbitrage {
address public factory;
uint constant deadline = 10 days;
IUniswapv2Router02 public sushiRouter;
constructor(address _factory, address _sushiRouter) public {
factory = _factory;
sushiRouter = IUniSwapV2Router02(_sushiRouter);
}

function startArbitrage (address token0,address token1,uint amount0,uint amount1) external {
address pairAddress = IUniswapV2Factory(factory).getPair(token0, token1);
require(pairAddress != address(0), 'This pool does not exist') ;
IUniswapV2Pair(pairAddress).swap(amount0, amount1,address(this),bytes('not empty'));
}


function uniswapv2Call(
address _sender,
uint _amount0,
uint _amount1,
bytes calldata_data
) external {
address memory path = new address[](2) ;
uint amountToken =_amount0 ? _amount1 : _amount0;
address token = IUniswapV2Pair(msg. sender).token0(0;
address token1 = IUniswapV2Pair(msg. sender).token1(0;
require(msg.sender == Uniswapv2Library. pairFor(factory, token0, token1),
"Unauthorized');
require(_amount || _amount1 = 0);
path [0] = _amount ? tokenl: token0;
path [1] = amount1 ? token0: token1;
IERC20 token = IERC20(_amounte? token1 : token0);
token. approve (add ress (sushiRouter), amountToken);
uint amount Required = UniswapV2Library.getAmountsIn
factory,
amountToken,
path
)[0];
uint amountReceived = sushiRouter. SwapExactTokens ForTokens (
amountToken,
amountRequired,
path,
msg. sender,
deadline
D[1];
token.transfer(tx.origin, amountReceived
amountRequired) ;
}