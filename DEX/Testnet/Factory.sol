//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IOPHDEXFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function numPairs() external view returns (uint);

    function createPair(address tokenA, address tokenB, uint256 ethFee) external returns (address pair);
    function getDenomFee() external view returns (uint256);
    function getSwapFee() external view returns (uint256);
    function ethFee(address pair) external view returns (uint256);

    function INIT_CODE_PAIR_HASH() external view returns (bytes32);
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

interface IOPHDEXPair is IERC20 {

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external payable;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)
library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}

// a library for performing various math operations
library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
// range: [0, 2**112 - 1]
// resolution: 1 / 2**112
library UQ112x112 {
    uint224 constant Q112 = 2**112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}

interface IOPHDEXCallee {
    function OPHDEXCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

interface IFeeTo {
    function takeFee(address sender, address pair) external payable;
}

contract OPHDEXPair is IOPHDEXPair {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    uint public constant override MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public override factory;
    address public override token0;
    address public override token1;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint private unlocked = 1;
    modifier lock() {
        require(
            unlocked == 1, 
            'OPHDEX: LOCKED'
        );
        unlocked = 0;
        _;
        unlocked = 1;
    }

    string public constant override name = 'OPHDEX LPs';
    string public constant override symbol = 'OPHDEX-LP';
    uint8 public constant override decimals = 18;
    uint  public override totalSupply;
    mapping(address => uint) public override balanceOf;
    mapping(address => mapping(address => uint)) public override allowance;

    constructor() {
        factory = msg.sender;
    }

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        require(
            balanceOf[from] >= value,
            'OPHDEX: INSUFFICIENT_BALANCE'
        );
        require(
            to != address(0),
            'OPHDEX: TRANSFER_TO_ZERO'
        );
        require(
            value > 0,
            'OPHDEX: TRANSFER_ZERO'
        );

        // set balances
        balanceOf[from] -= value;
        balanceOf[to] += value;

        // transfer event
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external override returns (bool) {
        if (allowance[from][msg.sender] != ~uint(0)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    function getReserves() public view override returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'OPHDEX: TRANSFER_FAILED');
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external override {
        require(msg.sender == factory, 'OPHDEX: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112, uint112) private {
        require(balance0 <= ~uint112(0) && balance1 <= ~uint112(0), 'OPHDEX: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external override lock returns (uint liquidity) {
        require(to != address(this), 'Cannot Mint LP to itself');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'OPHDEX: INSUFFICIENT_LIQUIDITY_MINTED');

        // mint tokens to user
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external override lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'OPHDEX: INSUFFICIENT_LIQUIDITY_BURNED');

        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external override payable lock {
        require(amount0Out > 0 || amount1Out > 0, 'OPHDEX: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'OPHDEX: INSUFFICIENT_LIQUIDITY');

        // handle gas fees associated with OPHDEX
        {
            uint fee = IOPHDEXFactory(factory).ethFee(address(this));
            require(msg.value >= fee, 'OPHDEX: INSUFFICIENT FEE');
            IFeeTo(IOPHDEXFactory(factory).feeTo()).takeFee{value: fee}(msg.sender, address(this));
        }

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'OPHDEX: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IOPHDEXCallee(to).OPHDEXCall(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'OPHDEX: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        uint balance0Adjusted = (balance0.mul(10000).sub(amount0In.mul(IOPHDEXFactory(factory).getSwapFee())));
        uint balance1Adjusted = (balance1.mul(10000).sub(amount1In.mul(IOPHDEXFactory(factory).getSwapFee())));
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(10000**2), 'OPHDEX: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external override lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    // force reserves to match balances
    function sync() external override lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}

contract OPHDEXFactory is IOPHDEXFactory {
    bytes32 public constant override INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(OPHDEXPair).creationCode));

    // Fee Recipient, Factory Owner
    address public override feeTo;
    address public feeToSetter;
    address public owner;

    // Min ETH Fee Applicable To Swaps
    uint256 public minEthFee = 0.006 ether;

    // Dex Swap Fee
    uint256 private constant swapFee = 1; // 0.01%
    uint256 private constant denomFee = 10000 - 1;

    // Mapping From Token To Token To LP Address
    mapping(address => mapping(address => address)) public override getPair;

    // List Of All LP Addresses Created By This Factory
    address[] public override allPairs;
    address[] public allTokens;
    mapping ( address => bool ) public isTokenListed;

    // Mapping From Token To All LPs Created With This Token
    mapping ( address => address[] ) public allPairsForToken;

    // Mapping from pair to whether or not its a pair
    mapping ( address => bool ) public isPair;

    // Maps a pair to its ETH Fee
    mapping ( address => uint256 ) public ethFee;

    // Maps a token to its URI to fetch images
    mapping ( address => string ) public tokenImage;

    constructor(address _feeTo, address _owner, address _feeToSetter) {
        require(
            _feeTo != address(0) &&
            _owner != address(0) &&
            _feeToSetter != address(0),
            'Invalid Params'
        );
        feeTo = _feeTo;
        owner = _owner;
        feeToSetter = _feeToSetter;
    }

    function createPair(address tokenA, address tokenB, uint256 _ethFee) external override returns (address pair) {
        require(tokenA != tokenB, 'OPHDEX: IDENTICAL_ADDRESSES');
        require(_ethFee >= minEthFee, 'OPHDEX: INSUFFICIENT FEE');

        // order tokens
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        // list tokens and add to array if not listed
        if (isTokenListed[token0] == false) {
            isTokenListed[token0] = true;
            allTokens.push(token0);
        }
        if (isTokenListed[token1] == false) {
            isTokenListed[token1] = true;
            allTokens.push(token1);
        }

        require(token0 != address(0), 'OPHDEX: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'OPHDEX: PAIR_EXISTS'); // single check is sufficient

        // create pair
        bytes memory bytecode = type(OPHDEXPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        // initialize pair, set data mappings
        IOPHDEXPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction

        // push to list of all pairs
        allPairs.push(pair);

        // set isPair to true
        isPair[pair] = true;

        // set eth fee for pair
        ethFee[pair] = _ethFee;

        // add to list of pairs which correspond to a given token
        allPairsForToken[token0].push(pair);
        allPairsForToken[token1].push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function changeOwner(address _owner) external {
        require(msg.sender == owner, 'OPHDEX: FORBIDDEN');
        owner = _owner;
    }

    function setMinETHFee(uint256 newFee) external {
        require(msg.sender == owner, 'OPHDEX: FORBIDDEN');
        require(newFee > 0, 'OPHDEX: FEE OUT OF BOUNDS');
        minEthFee = newFee;
    }

    function setTokenImage(address token, string memory uri) external {
        require(msg.sender == owner, 'OPHDEX: FORBIDDEN');
        tokenImage[token] = uri;
    }

    function setFeeTo(address newFeeTo) external {
        require(msg.sender == feeToSetter, 'OPHDEX: FORBIDDEN');
        feeTo = newFeeTo;
    }

    function setFeeToSetter(address newFeeToSetter) external {
        require(msg.sender == feeToSetter, 'OPHDEX: FORBIDDEN');
        feeToSetter = newFeeToSetter;
    }

    function setETHFee(address pair, uint256 newFee) external {
        require(msg.sender == owner, 'OPHDEX: FORBIDDEN');
        require(newFee >= minEthFee, 'OPHDEX: INSUFFICIENT FEE');
        ethFee[pair] = newFee;
    }

    function fetchAllPairsForToken(address _token) external view returns (address[] memory) {
        return allPairsForToken[_token];
    }

    function fetchAllPairs() external view returns (address[] memory) {
        return allPairs;
    }

    function fetchAllTokens() external view returns (address[] memory) {
        return allTokens;
    }

    function numPairs() external view returns (uint256) {
        return allPairs.length;
    }

    function numTokens() external view returns (uint) {
        return allTokens.length;
    }

    function numPairsForToken(address _token) external view returns (uint256) {
        return allPairsForToken[_token].length;
    }

    function getDenomFee() external pure override returns (uint256) {
        return denomFee;
    }
    function getSwapFee() external pure override returns (uint256) {
        return swapFee;
    }
}