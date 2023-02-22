//SPDX-License-Identifier: MIT

pragma solidity =0.8.17;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Context.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router01.sol";
import "https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Factory.sol";
import "https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol";
import "https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
import "https://github.com/aifeelit/pink-antibot-guide-binance-solidity/blob/main/IPinkAntiBot.sol";


contract DeeLance is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapV2Router;
    address public  uniswapV2Pair;

    bool private feeActive = true;
    bool public tradingEnabled;
    uint256 public launchTime;

    uint256 internal totaltokensupply =  1000000000 * (10**18);


    address public deadWallet = 0x000000000000000000000000000000000000dEaD;

    IPinkAntiBot public pinkAntiBot;

    uint256 public buyFee = 0;
    uint256 public sellFee = 0;
    uint256 public maxtranscation = 5000000000000000;
    
    bool public antiBotEnabled;
    bool public antiDumpEnabled = false;


    bool public verifierOne = false;
    bool public verifierOwner = false;

    address public feeWallet     = 0x91130ca7111A5333051dB4b4c8aC553Bf25041E8; 
    address public pinkAntiBot_  = 0xf4f071EB637b64fC78C9eA87DaCE4445D119CA35;
    address public firstVerifier = 0x3de72566bA2917D96a90500bd8B165863EE4c900; 

    modifier onlyfirstVerifier() {
        require(_msgSender() == firstVerifier, "Ownable: caller is not the first voter");
        _;
    }

     // exclude from fees and max transaction amount
    mapping (address => bool) private _isExcludedFromFees;

    mapping (address => uint256) public antiDump;
    mapping (address => uint256) public sellingTotal;
    mapping (address => uint256) public lastSellstamp;
    uint256 public antiDumpTime = 10 minutes;
    uint256 public antiDumpAmount = totaltokensupply.mul(5).div(10000);



    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;


    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event LiquidityWalletUpdated(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);


    constructor() ERC20("DeeLance", "$dlance") {

    	IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
         // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);
        pinkAntiBot = IPinkAntiBot(pinkAntiBot_);
        pinkAntiBot.setTokenOwner(msg.sender);
        antiBotEnabled = true;

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), totaltokensupply);
    }

    receive() external payable {

  	}

    function setEnableAntiBot(bool _enable) external onlyOwner {
        antiBotEnabled = _enable;
    }

    function setantiDumpEnabled(bool nodumpamount) external onlyOwner {
        antiDumpEnabled = nodumpamount;
    }

    function setantiDump(uint256 interval, uint256 amount) external onlyOwner {
        antiDumpTime = interval;
        antiDumpAmount = amount;
    }

    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(newAddress != address(uniswapV2Router), "DeeLance: The router already has that address");
        require(newAddress != address(0), "new address is zero address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
        address _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Pair = _uniswapV2Pair;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "Deelance: Account is already the value of 'excluded'");
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setbuyFee(uint256 value) external onlyOwner{
        require(value <= 15, "Max 15%");
        buyFee = value;
    }

    function setsellFee(uint256 value) external onlyOwner{
        require(value <= 15, "Max 15%");
        sellFee = value;
    }

    function setmaxtranscation(uint256 value) external onlyOwner{
        maxtranscation = value;
    }

    function setfeeWallet(address feaddress) public onlyOwner {
        feeWallet = feaddress;
    }

    function setFirstverifier(address faddress) public onlyOwner {
        require(faddress != address(0), "Ownable: new voter is the zero address");
        require(verifierOne == true && verifierOwner == true ,'not active');
        firstVerifier = faddress;
        verifierOne = false;
    }


    function setfeeActive(bool value) external onlyOwner {
        feeActive = value;
    }

    function voteVerifierOne(bool voteverifier) public onlyfirstVerifier() {
        verifierOne = voteverifier;
    }

    function voteVerifierOwner(bool voteverifier) public onlyOwner {
        verifierOwner = voteverifier;
    }


    function startTrading() external onlyOwner{
        require(launchTime == 0, "Already Listed!");
        launchTime = block.timestamp;
        tradingEnabled = true;
    }

    function pauseTrading() external onlyOwner{
        launchTime = 0 ;
        tradingEnabled = false;

    }


    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "DeeLance: The UniSwap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }


    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(automatedMarketMakerPairs[pair] != value, "DeeLance: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require( _isExcludedFromFees[from] || _isExcludedFromFees[to]  || amount <= maxtranscation,"Max transaction Limit Exceeds!");
        if (antiBotEnabled) {
      pinkAntiBot.onPreTransferCheck(from, to, amount);
    }

        if(!_isExcludedFromFees[from]) { require(tradingEnabled == true, "Trading not enabled yet"); }

        if(from == owner()) { require(verifierOne == true && verifierOwner == true ,"not active"); }



        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }


        if (
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to] &&
            launchTime + 3 minutes >= block.timestamp
        ) {
            // don't allow to buy more than 0.01% of total supply for 3 minutes after launch
            require(
                automatedMarketMakerPairs[from] ||
                    balanceOf(to).add(amount) <= totaltokensupply.div(10000),
                "AntiBot: Buy Banned!"
            );
            if (launchTime + 180 seconds >= block.timestamp)
                // don't allow sell for 180 seconds after launch
                require(
                    automatedMarketMakerPairs[to],
                    "AntiBot: Sell Banned!"
                );
        }


        if (
            antiDumpEnabled &&
            automatedMarketMakerPairs[to] &&
            !_isExcludedFromFees[from]
        ) {
            require(
                antiDump[from] < block.timestamp,
                "Err: antiDump active"
            );
            if (
                lastSellstamp[from] + antiDumpTime < block.timestamp
            ) {
                lastSellstamp[from] = block.timestamp;
                sellingTotal[from] = 0;
            }
            sellingTotal[from] = sellingTotal[from].add(amount);
            if (sellingTotal[from] >= antiDumpAmount) {
                antiDump[from] = block.timestamp + antiDumpTime;
            }
        }

        bool takeFee = feeActive;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if(takeFee) {

            uint256 fees = 0;
            if(automatedMarketMakerPairs[from])
            {
        	    fees += amount.mul(buyFee).div(100);
        	}
        	if(automatedMarketMakerPairs[to]){
        	    fees += amount.mul(sellFee).div(100);
        	}
        	amount = amount.sub(fees);



            super._transfer(from, feeWallet, fees);
        }

        super._transfer(from, to, amount);
    }

    function recoverothertokens(address tokenAddress, uint256 tokenAmount) public  onlyOwner {
        require(tokenAddress != address(this), "cannot be same contract address");
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }


    function recovertoken(address payable destination) public onlyOwner {
        require(destination != address(0), "destination is zero address");
        destination.transfer(address(this).balance);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0),
            block.timestamp
        );

    }
}