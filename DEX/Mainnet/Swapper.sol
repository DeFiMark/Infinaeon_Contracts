//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title Owner
 * @dev Set & change owner
 */
contract Ownable {

    address private owner;
    
    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    
    // modifier to check if caller is owner
    modifier onlyOwner() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    
    /**
     * @dev Set contract deployer as owner
     */
    constructor() {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);
    }

    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public onlyOwner {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Return owner address 
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }
}

interface IERC20 {

    function totalSupply() external view returns (uint256);
    
    function symbol() external view returns(string memory);
    
    function name() external view returns(string memory);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
    
    /**
     * @dev Returns the number of decimal places
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
    event Approval(address indexed owner, address indexed spender, uint256 value);
}



interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}


interface IInfinitySwapRouter {
    function factory() external view returns (address);
    function WETH() external view returns (address);
    function getETHFeeForSwap(address[] memory path) external view returns (uint256 totalFee);
    function getETHFee(address pair) external view returns (uint256);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        uint ethFee
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        uint ethFee
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external view returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external view returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}


contract SellLessSwapper is Ownable {

    struct ListedToken {
        address router;
        uint256 buyFee;
        uint256 sellFee;
        address feeDestination;
    }
    mapping ( address => ListedToken ) public listedTokens;

    // Fee Denom For Fee Calculations
    uint256 public platformFee = 200; // 0.2%
    uint256 public constant FEE_DENOM = 100_000;

    // Infinity Swap Router
    address public infinitySwapRouter;

    // recipient to get gas upcharges
    address public platformFeeRecipient;

    constructor(
        address _infinitySwap,
        address _platformFeeRecipient
    ) {
        infinitySwapRouter = _infinitySwap;
        platformFeeRecipient = _platformFeeRecipient;
    }

    function listToken(
        address _token,
        address _router,
        uint256 _buyFee,
        uint256 _sellFee,
        address _feeDestination
    ) external onlyOwner {
        require(
            _token != address(0),
            'Token Cannot Be Zero'
        );
        require(
            _router != address(0),
            'Router Cannot Be Zero'
        );
        require(
            _feeDestination != address(0),
            'Fee Destination Cannot Be Zero'
        );

        listedTokens[_token] = ListedToken({
            router: _router,
            buyFee: _buyFee,
            sellFee: _sellFee,
            feeDestination: _feeDestination
        });
    }

    // view function to get estimated out from the router
    // maybe package it as a "view and revert" function, to pull the return data

    function setRouter(address _token, address _router) external onlyOwner {
        listedTokens[_token].router = _router;
    }

    function setBuyFee(address _token, uint256 _fee) external onlyOwner {
        listedTokens[_token].buyFee = _fee;
    }

    function setSellFee(address _token, uint256 _fee) external onlyOwner {
        listedTokens[_token].sellFee = _fee;
    }

    function setFeeDestination(address _token, address _destination) external onlyOwner {
        listedTokens[_token].feeDestination = _destination;
    }

    function setInfinitySwapRouter(address _router) external onlyOwner {
        infinitySwapRouter = _router;
    }

    function setPlatformFee(uint256 _fee) external onlyOwner {
        platformFee = _fee;
    }

    function setPlatformFeeRecipient(address _destination) external onlyOwner {
        platformFeeRecipient = _destination;
    }

    function withdrawTokens(address _token) external onlyOwner {
        IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this)));
    }

    function withdraw() external onlyOwner {
        (bool s,) = payable(msg.sender).call{value: address(this).balance}("");
        require(s);
    }

    function isListedToken(address _token) public view returns (bool) {
        return listedTokens[_token].feeDestination != address(0) && listedTokens[_token].router != address(0);
    }

    function quoteSwap(address token, address dex, uint256 amountBuy, uint256 amountSell) external view returns (uint256) {
        if (amountBuy > 0) {
            // we are buying token with bnb, apply buy fee
            uint256 feePercent = listedTokens[token].buyFee;

            // create swap path
            address[] memory path = new address[](2);
            path[0] = IUniswapV2Router02(dex).WETH();
            path[1] = token;

            // estimate out
            uint256[] memory outs = IUniswapV2Router02(dex).getAmountsOut(amountBuy, path);
            uint256 out = outs[1];
            
            // return out minus fee
            return out - ( (out * feePercent) / FEE_DENOM );
        } else if (amountSell > 0) {
            // we are selling token for bnb, apply sell fee
            uint256 feePercent = listedTokens[token].sellFee;

            // create swap path
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = IUniswapV2Router02(dex).WETH();

            // estimate out
            uint256[] memory outs = IUniswapV2Router02(dex).getAmountsOut(amountSell, path);
            uint256 out = outs[1];

            // return out minus fee
            return out - ( (out * feePercent) / FEE_DENOM );
        }
        return 0;
    }

    function buyToken(address token, uint minOut) external payable {
        require(
            isListedToken(token),
            'Token Not Listed'
        );

        // take fee
        uint _tokenfee = ( msg.value * listedTokens[token].buyFee ) / FEE_DENOM;
        uint _platformFee = ( msg.value * platformFee ) / FEE_DENOM;
        _send(platformFeeRecipient, _platformFee);
        _send(listedTokens[token].feeDestination, _tokenfee);

        // determine swap path
        address[] memory path = new address[](2);
        path[0] = IUniswapV2Router02(listedTokens[token].router).WETH();
        path[1] = token;

        IUniswapV2Router02(listedTokens[token].router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: address(this).balance}(
            minOut,
            path,
            address(this),
            block.timestamp + 300
        );
        IERC20(token).transfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }

    function sellToken(address token, uint256 amount, uint256 minOut) external payable {
        require(
            isListedToken(token),
            'Token Not Listed'
        );
        require(
            IERC20(token).balanceOf(msg.sender) >= amount,
            'Insufficient Balance'
        );
        require(
            IERC20(token).allowance(msg.sender, address(this)) >= amount,
            'Insufficient Allowance'
        );

        // fetch router
        address router = listedTokens[token].router;

        // determine swap path
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = IUniswapV2Router02(router).WETH();

        // transfer in, expecting the same amount to be received as was sent to ensure fee-exemption takes place for listed tokens
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // approve of the router, assuming that this contract has been fee exempted (and reverting if not)
        IERC20(token).approve(router, amount);

        // swap
        if (router == infinitySwapRouter) {
            IInfinitySwapRouter(router).swapExactTokensForETHSupportingFeeOnTransferTokens{value: msg.value}(
                amount,
                minOut,
                path,
                address(this),
                block.timestamp + 300
            );
        } else {
            IUniswapV2Router02(router).swapExactTokensForETHSupportingFeeOnTransferTokens(
                amount,
                minOut,
                path,
                address(this),
                block.timestamp + 300
            );
        }

        
        // take fee in bnb
        uint _tokenFee = ( address(this).balance * listedTokens[token].sellFee ) / FEE_DENOM;
        uint _platformFee = ( address(this).balance * platformFee ) / FEE_DENOM;
        _send(listedTokens[token].feeDestination, _tokenFee);
        _send(platformFeeRecipient, _platformFee);

        // send remaining bnb to caller
        (bool s,) = payable(msg.sender).call{value: address(this).balance}("");
        require(s);
    }

    receive() external payable {}

    function _send(address to, uint val) internal {
        if (to == address(0) || val == 0) {
            return;
        }
        (bool s,) = payable(to).call{value: val}("");
        require(s);
    }
}