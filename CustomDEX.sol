// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract CustomToken is ERC20 {
constructor (string memory name, string memory symbol) ERC20 (name, symbol ){
_mint (msg. sender, 10000000 * 10 ** 18);
}
}


contract CustomDex {

// Custom tokens to be initialiazed
string[] public tokens = ["Tether USD", "BNB", "USD Coin", "stETH", "TRON","Matic Token", "SHIBA INU", "Uniswap"];
// map to maintain the tokens and its instances
mapping (string => ERC20) public tokenInstanceMap;
uint256 ethValue = 100000000000000;

struct History {
uint256 historyId;
string tokenA;
string tokenB;
uint256 inputValue;
uint256 outputValue;
address userAddress;
}

uint256 public historyIndex;
mapping (uint256 => History) private historys;

constructor(){
for (uint i=0; i<tokens.length; i++) {
CustomToken token = new CustomToken(tokens[i], tokens[i]) ;
tokenInstanceMap[tokens[i]] = token;
         }
     }


function getBalance (string memory tokenName, address _address) public view returns(uint256) {
     // return tokenInstanceMap[tokenName].balance0f(_address);
        return tokenInstanceMap[tokenName].balanceOf(_address);
}


function getTotalSupply (string memory tokenName) public view returns (uint256) {
return tokenInstanceMap[tokenName].totalSupply();
}

  function getName(string memory tokenName) public view returns (string memory) {
return tokenInstanceMap[tokenName].name();
}
function getTokenAddress (string memory tokenName) public view returns (address) {
return address (tokenInstanceMap[tokenName]);
}

function getEthBalance () public view returns (uint256){
return address(this).balance;
}

function _transactionHistory (string memory tokenName, string memory etherToken,
uint256 inputValue, uint256 outputValue) internal {
historyIndex++;
uint256 _historyId = historyIndex ;
History storage history = historys[_historyId] ;
history.historyId = _historyId;
history.userAddress = msg.sender;
history.tokenA = tokenName;
history.tokenB = etherToken;
history.inputValue = inputValue;
history.outputValue = outputValue;
}

function swapEthToToken (string memory tokenName) public payable returns (uint256) {
uint256 inputValue = msg.value;
uint256 outputValue = (inputValue / ethValue) * 10 ** 18; // Convert to 18 decimal places
require(tokenInstanceMap[tokenName].transfer(msg.sender, outputValue));
string memory etherToken = "Ether";
_transactionHistory (tokenName, etherToken, inputValue, outputValue );
return outputValue;
}

function swapTokenToEth(string memory tokenName, uint256 _amount) public returns(uint256){
// Convert the token amount (ethValue) to exact amount (10)
uint256 exactAmount = _amount / 10 ** 18;
uint256 ethToBeTransferred = exactAmount * ethValue;
require(address(this).balance >= ethToBeTransferred, "Dex is running low on balance.");
payable(msg.sender).transfer(ethToBeTransferred) ;
require (tokenInstanceMap[tokenName].transferFrom(msg.sender, address(this), _amount));
string memory etherToken = "Ether";
_transactionHistory(tokenName, etherToken, exactAmount, ethToBeTransferred);
return ethToBeTransferred;
}

function swapTokenToToken(string memory srcTokenName, string memory destTokenName,
uint256 _amount) public {
require (tokenInstanceMap[srcTokenName].transferFrom(msg.sender, address(this),
_amount ));
require(tokenInstanceMap[destTokenName].transfer(msg. sender, _amount));
_transactionHistory(srcTokenName, destTokenName, _amount, _amount );
}

function getAllHistory() public view returns (History[] memory) {
uint256 itemCount = historyIndex;
uint256 currentIndex = 0;
History[] memory items = new History[](itemCount);
for(uint256 i = 0; i<itemCount; i++) {
uint256 currentId = i + 1;
History storage currentItem = historys[currentId];
items [currentIndex] = currentItem;
currentIndex += 1;
}
return items;
}

}




// Deploy file


// const hre = require ("hardhat" );
// async function ma in()
// const CustomDex = await
// const customDex = await CustomDex. deploy () ;
// hre.ethers. getCont ract Factory ("CustomDex");
// await customDex . deployed (0;
// console. log(' CustomDex: ${customDex. add ress)' );
// main(). catch( (error) => {
// console,error(error) ;
// process. exitCode = 1;

