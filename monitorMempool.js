const Web3 = require('web3');
const web3 = new Web3('wss://mainnet.infura.io/ws/v3/YOUR_INFURA_PROJECT_ID');

web3.eth.subscribe('pendingTransactions', function(error, result) {
    if (!error) {
        web3.eth.getTransaction(result)
            .then(function(transaction) {
                if (transaction && transaction.input) {
                    console.log(transaction);
                    // Further logic to check and decode the transaction data
                }
            });
    }
});



const Web3 = require('web3');
// const web3 = new Web3('wss://mainnet.infura.io/ws/v3/YOUR_INFURA_PROJECT_ID');

const contractAddress = '0xYourContractAddress';
const solveFunctionSignature = web3.utils.sha3('solve(string)').substr(0, 10);

web3.eth.subscribe('pendingTransactions', function(error, result) {
    if (!error) {
        web3.eth.getTransaction(result)
            .then(function(transaction) {
                if (transaction && transaction.to === contractAddress && transaction.input.startsWith(solveFunctionSignature)) {
                    console.log("Detected solve function call:", transaction);
                    const solution = web3.utils.toAscii('0x' + transaction.input.substr(10));
                    console.log("Solution extracted:", solution);
                    // Eve can now front-run by sending her own transaction with the extracted solution
                }
            });
    }
});
