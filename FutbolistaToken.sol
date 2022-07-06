//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

/**
 * Standard SafeMath, stripped down to just add/sub/mul/div
 */
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;
    mapping(address => bool) internal _isOwner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        _isOwner[msgSender] = true;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

/**
 * BEP20 standard interface.
 */
interface IBEP20 {
    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address _owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IDEXRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function getAmountsOut(uint256 amountIn, address[] memory path)
        external
        view
        returns (uint256[] memory amounts);
}

contract SafeToken is Ownable {
    address payable safeManager;

    constructor() {
        safeManager = payable(msg.sender);
    }

    function getSafeManager() public view returns (address) {
        return safeManager;
    }

    function setSafeManager(address payable _safeManager) public onlyOwner {
        safeManager = _safeManager;
    }

    function withdrawBNB(uint256 _amount) external {
        require(msg.sender == safeManager);
        safeManager.transfer(_amount);
    }
}

contract BaseToken is Ownable, IBEP20 {
    using SafeMath for uint256;

    address BNB = 0xB8c77482e45F1F44dE1745F52C74426C631bDD52;
    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;

    string _name;
    string _symbol;
    uint8 _decimals;
    uint256 _totalSupply;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        uint8 decimals_
    ) {
        _name = name_;
        _symbol = symbol_;
        _totalSupply = totalSupply_;
        _decimals = decimals_;
    }

    receive() external payable {}

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveFrom(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "approve from the zero address");
        require(spender != address(0), "approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        if (_allowances[sender][msg.sender] != ~uint256(0)) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender]
                .sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual returns (bool) {
        return _basicTransfer(sender, recipient, amount);
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function burn(uint256 amount) internal virtual {
        _burn(_msgSender(), amount);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address holder, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[holder][spender];
    }
}

contract MainToken is
    BaseToken("Futbolista", "FBL", 1000000000 * 10**18, 18),
    SafeToken
{
    using SafeMath for uint256;

    // Special wallets
    address public lpAddress = 0x56796377bdada476ccd0cB0e046903Ff5B19C21c;
    address public marketingAddress =
        0xbe00Ecf53b680Bc972a7757a4399b2f6B073Ca95;
    address public rewardAddress = 0x9a2C7130687325B27d3bc10eb4D1Df095Aa56fe2;

    IDEXRouter pancakeRouter;

    uint256 public undistributedBuyTax = 0;
    uint256 public undistributedSellTax = 0;
    uint256 public firstAddliquid = 0;

    uint8 public BUY_IN_TAX_PERCENTAGE = 3;
    uint8 public SELL_OUT_TAX_PERCENTAGE = 3;

    uint8 constant TX_NORMAL = 0;
    uint8 constant TX_BUY = 1;
    uint8 constant TX_SELL = 2;

    bool inSwap;

    event BurnSupply(address indexed _user, uint256 _amount);

    constructor() {
        pancakeRouter = IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        approveFrom(address(this), address(pancakeRouter), ~uint256(0));

        address contractOwner = owner();
        _balances[contractOwner] = _totalSupply;
    }

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    /**
     *  Set address
     */
    function initSpecialAddresses(
        address _lpAddress,
        address _rewardAddress,
        address _marketingAddress
    ) public onlyOwner {
        // Set new address
        lpAddress = _lpAddress;
        marketingAddress = _marketingAddress;
        rewardAddress = _rewardAddress;
    }

    function setLPAddress(address newLPAddress) public onlyOwner {
        lpAddress = newLPAddress;
    }

    function setMarketingAddress(address newMarketingAddress) public onlyOwner {
        marketingAddress = newMarketingAddress;
    }

    function setRewardAddress(address newRewardAddress) public onlyOwner {
        rewardAddress = newRewardAddress;
    }

    /**
     *  Withdraw all bnb accidentally sent to this address
     */
    function withdrawAllBNB() external {
        require(msg.sender == safeManager);
        safeManager.transfer(address(this).balance);
    }

    /**
        Undistributed sell tax in project token
    */
    function getSellTaxBalance() public view returns (uint256) {
        return undistributedSellTax.div(10**_decimals);
    }

    /**
        Undistributed buy tax in project token
    */
    function getBuyTaxBalance() public view returns (uint256) {
        return undistributedBuyTax.div(10**_decimals);
    }

    /**
     *  Set Buy in tax percentage
     */
    function setBuyInTaxPercentage(uint8 percent) external onlyOwner {
        require(percent <= 15, "Tax percentage must be less than 15");
        BUY_IN_TAX_PERCENTAGE = percent;
    }

    /**
     *  Set  Sell out tax percentage
     */
    function setSellOutTaxPercentage(uint8 percent) external onlyOwner {
        require(percent <= 15, "Tax percentage must be less than 15");
        SELL_OUT_TAX_PERCENTAGE = percent;
    }

    /* Burn Total Supply Function */
    function burnDead(uint256 _value) external onlyOwner {
        transfer(DEAD, _value);
        emit Transfer(msg.sender, DEAD, _value);
    }

    function burnSupply(uint256 _value) external onlyOwner {
        burn(_value);
        emit BurnSupply(msg.sender, _value);
    }

    // Swap THIS token into bnb (eth).
    function swapTokenToBnb(uint256 amount) private {
        require(amount > 0);
        IBEP20 tokenContract = IBEP20(address(this));
        tokenContract.approve(address(pancakeRouter), amount);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeRouter.WETH();
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function distributeAutoBuyBack(uint256 amount, address receiverAddress) private {
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH();
        path[1] = address(this);

        pancakeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amount
        }(0, path, receiverAddress, block.timestamp.add(300));
    }

    /**
        Force swapping all undistributed buy tax
        and distribute
     */
    function swapBackAndDistributeBuyTax() private swapping {
        uint256 bnbBefore = address(this).balance;
        swapTokenToBnb(undistributedBuyTax);
        uint256 bnbAfter = address(this).balance;
        uint256 bnbToDistribute = bnbAfter.sub(bnbBefore);

        uint256 marketingBnb = bnbToDistribute.mul(33).div(100);
        distributeBnb(marketingAddress, marketingBnb);

        uint256 lpBnb = bnbToDistribute.mul(33).div(100);
        distributeAutoBuyBack(lpBnb, lpAddress);

        distributeAutoBuyBack(bnbToDistribute.sub(marketingBnb).sub(lpBnb), rewardAddress);

        undistributedBuyTax = 0;
    }

    /**
        Force swapping all undistributed sell tax
        and distribute
     */
    function swapBackAndDistributeSellTax() private swapping {
        uint256 bnbBefore = address(this).balance;

        swapTokenToBnb(undistributedSellTax);
        uint256 bnbAfter = address(this).balance;
        uint256 bnbToDistribute = bnbAfter.sub(bnbBefore);

        uint256 marketingBnb = bnbToDistribute.mul(33).div(100);
        distributeBnb(marketingAddress, marketingBnb);

        uint256 lpBnb = bnbToDistribute.mul(33).div(100);
        distributeAutoBuyBack(lpBnb, lpAddress);

        distributeAutoBuyBack(bnbToDistribute.sub(marketingBnb).sub(lpBnb), rewardAddress);

        undistributedSellTax = 0;
    }

    function canSwapBack() private view returns (bool) {
        return !inSwap;
    }

    /**
     * Returns the transfer type.
     * 1 if user is buying (swap main token for sc token)
     * 2 if user is selling (swap sc token for main token)
     * 0 if user do the simple transfer between two wallets.
     */
    function checkTransferType(address sender, address recipient)
        private
        view
        returns (uint8)
    {
        if (sender.code.length > 0) {
            // in case of the wallet, there's no code => length == 0.
            return TX_BUY; // buy
        } else if (recipient.code.length > 0) {
            return TX_SELL; // sell
        }

        return TX_NORMAL; // normal transfer
    }

    /**
     * Transfer the token from sender to recipient
     * The logic of tax applied here.
     */
    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal override returns (bool) {
        // For the whitelisted wallets, simply do basic transfer
        uint8 transferType = checkTransferType(sender, recipient);
        if (_isOwner[sender] || _isOwner[recipient] || inSwap || firstAddliquid == 0) {
            if (transferType == TX_BUY) {
                firstAddliquid++;
            }
            return _basicTransfer(sender, recipient, amount);
        }

        uint256 fee = 0;
        if (transferType == TX_BUY) {
            fee = amount.mul(BUY_IN_TAX_PERCENTAGE).div(100);
            undistributedBuyTax = undistributedBuyTax.add(fee);
        } else {
            if (transferType == TX_SELL) {
                fee = amount.mul(SELL_OUT_TAX_PERCENTAGE).div(100);
                undistributedSellTax = undistributedSellTax.add(fee);
            }
        }

        uint256 amountReceived = amount.sub(fee);
        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );
        _balances[address(this)] = _balances[address(this)].add(fee);

        // Swap back and distribute taxes
        if (canSwapBack() && transferType == TX_SELL) {
            if (undistributedBuyTax > 0) {
                swapBackAndDistributeBuyTax();
            }

            if (undistributedSellTax > 0) {
                swapBackAndDistributeSellTax();
            }
        }

        _balances[recipient] = _balances[recipient].add(amountReceived);
        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    function distributeBnb(address recipient, uint256 amount) private {
        (bool success, ) = payable(recipient).call{value: amount, gas: 30000}(
            ""
        );
        require(success, "Failed to distribute BNB");
    }
}
