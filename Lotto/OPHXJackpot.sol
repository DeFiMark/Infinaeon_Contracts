//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./IERC20.sol";
import "./ReentrantGuard.sol";
import "./Ownable.sol";
import "./TransferHelper.sol";

interface IClaimManager {
    function credit(address user) external payable;
}

interface IPointManager {
    function addPoints(address user, uint256 amount) external;
}

interface IRNG {
    function requestRandom(uint32 gas, uint32 numResults) external returns (uint256 requestId);
}

/**
    OPHX Jackpot Game!

    Inspired by pvp.money's Winner Takes All

    Learn more at https://pvp.money
 */
contract OPHXJackpot is Ownable, ReentrancyGuard {

    // chainlink fee receiver
    address public chainlinkFeeReceiver;

    // Claim Manager
    address public claimManager;

    // Platform Fee Recipient
    address public platformFeeRecipient;

    // Point Manager
    address public pointManager;

    // Addr0
    address private addr0;

    // RNG contract
    address public RNG;

    // Gas to call the RNG
    uint32 public gasToCallRandom;

    // Whether joining is paused or not
    bool public paused;

    // Table Structure
    struct Table {
        address token;
        uint256 buyIn;
        uint32 max_players;
        uint256 gameID;
        uint256 nPoints;
        uint256 platformFee;
        uint256 duration;
    }

    // Game Structure
    struct Game {
        bool hasEnded;
        uint256 tableId;
        address[] players;
        address[] playersForRNG;
        mapping ( address => uint ) entriesPerPlayer;
        uint256 endTime;
        address winner;
        uint256 pot;
    }

    // mapping from tableID => Table
    mapping ( uint256 => Table ) public tables;

    // mapping from GameID => Game
    mapping ( uint256 => Game ) public games;

    // request ID => GameID
    mapping ( uint256 => uint256 ) private requestToGame;

    // Table Nonce
    uint256 public tableNonce = 1;

    // Game Nonce
    uint256 public gameNonce = 1;

    // Min Buy In Gas
    uint256 public minBuyInGas;

    /** Fee Denominator */
    uint256 private constant FEE_DENOM = 1000;

    // Valid Table
    modifier isValidTable(uint256 tableId) {
        require(
            validTable(tableId),
            'Table Not Valid'
        );
        _;
    }

    // Events
    event TableCreated(
        address token,
        uint256 newTableId,
        uint256 buyIn,
        uint32 max_players
    );

    /// @notice emitted after a random request has been sent out
    event RandomnessRequested(uint256 gameId);

    /// @notice emitted after a game has been started at a specific table
    event GameStarted(uint256 tableId, uint256 gameId);

    /// @notice Emitted after the VRF comes back with the index of the winning player
    event GameEnded(uint256 tableId, uint256 gameId, address indexed winner);

    /// @notice Emitted if the fulfilRandomWords function needs to return out for any reason
    event FulfilRandomFailed(uint256 requestId, uint256 gameId, uint256[] randomWords);

    constructor(
        address _platformFeeRecipient, 
        address _claimManager, 
        address _chainlinkFeeReceiver,
        address _rng,
        address _pointManager,
        address _addr0
    ) {
        
        // set buy in gas for ETH
        minBuyInGas = 0.001 ether;

        // set gas to call random
        gasToCallRandom = 1_250_000;

        // set managers
        platformFeeRecipient = _platformFeeRecipient;
        claimManager = _claimManager;
        chainlinkFeeReceiver = _chainlinkFeeReceiver;
        RNG = _rng;
        pointManager = _pointManager;
        addr0 = _addr0;
    }

    //////////////////////////////////////
    ///////    OWNER FUNCTIONS    ////////
    //////////////////////////////////////

    function setChainlinkFeeReceiver(address newReceiver) external onlyOwner {
        chainlinkFeeReceiver = newReceiver;
    }

    function setClaimManager(address newManager) external onlyOwner {
        claimManager = newManager;
    }

    function setPlatformFeeRecipient(address newRecipient) external onlyOwner {
        platformFeeRecipient = newRecipient;
    }

    function setPointManager(address newManager) external onlyOwner {
        pointManager = newManager;
    }

    function setRNG(address newRNG) external onlyOwner {
        RNG = newRNG;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function setAddr0(address newAddr0) external {
        require(msg.sender == addr0, 'Not Addr0');
        addr0 = newAddr0;
    }

    function createTable(
        address token,
        uint256 buyIn,
        uint32 max_players,
        uint256 nPoints,
        uint256 duration,
        uint256 platformFee
    ) external onlyOwner {
        require(
            max_players >= 3,
            'Cannot Have Fewer Than Three'
        );
        require(
            buyIn > 0,
            'Cannot Have Zero Buy In'
        );
        require(
            duration > 1_800,
            'Must Be Longer Than 30 Minutes'
        );
        require(
            platformFee <= FEE_DENOM,
            'Platform Fee Too High'
        );
        
        // initialize table
        tables[tableNonce] = Table({
            token: token,
            buyIn: buyIn,
            max_players: max_players,
            gameID: 0,
            nPoints: nPoints,
            platformFee: platformFee,
            duration: duration
        });

        // emit event
        emit TableCreated(token, tableNonce, buyIn, max_players);

        // increment table nonce
        unchecked {
            ++tableNonce;
        }
    }

    function setNPoints(uint256 tableId, uint256 newNPoints) external onlyOwner isValidTable(tableId) {
        tables[tableId].nPoints = newNPoints;
    }

    function setBuyIn(uint256 tableId, uint256 newBuyIn) external onlyOwner isValidTable(tableId) {
        require(
            newBuyIn > 0,
            'Zero Buy In'
        );
        tables[tableId].buyIn = newBuyIn;
    }

    function setMaxPlayers(uint256 tableId, uint32 maxPlayers) external onlyOwner isValidTable(tableId) {
        require(
            maxPlayers >= 3,
            'Cannot Have Fewer Than Three'
        );
        tables[tableId].max_players = maxPlayers;
    }

    function setDuration(uint256 tableId, uint256 newDuration) external onlyOwner isValidTable(tableId) {
        require(
            newDuration >= 1_800,
            'Must Be Longer Than 30 Minutes'
        );
        tables[tableId].duration = newDuration;
    }

    function setGasToCallRandom(uint32 newGas) external onlyOwner {
        require(
            newGas >= 250_000,
            'Gas Too Few'
        );
        require(
            newGas <= 20_000_000,
            'Gas Too High'
        );
        gasToCallRandom = newGas;
    }

    function setPlatformFee(uint256 tableId, uint newFee) external onlyOwner {
        require(
            newFee <= FEE_DENOM,
            'Platform Fee Too High'
        );
        tables[tableId].platformFee = newFee;
    }

    function setToken(uint256 tableId, address newToken) external onlyOwner isValidTable(tableId) {
        tables[tableId].token = newToken;
    }

    function setMinBuyInGas(uint256 weiValue) external onlyOwner {
        minBuyInGas = weiValue;
    }

    function forcefullyEndGame(uint256 tableId) external onlyOwner isValidTable(tableId) {

        uint gameID = tables[tableId].gameID;
        require(gameID > 0, 'Zero Game');
        require(games[gameID].players.length > 0, 'Zero Players');

        // toggle has ended to true
        games[gameID].hasEnded = true;

        if (games[gameID].players.length == 1) {

            // clear storage
            delete tables[tableId].gameID; // allow new game to start

            // fetch the one user
            address user = games[gameID].players[0];

            // set user to be winner
            games[gameID].winner = user;

            // refund user full value
            _sendToClaimManager(
                tables[tableId].token, user, games[gameID].pot
            );
        } else {

            // request random words for game
            _requestRandom(gameID);
        }
    }

    //////////////////////////////////////
    ///////   Public FUNCTIONS    ////////
    //////////////////////////////////////

    
    function joinGame(uint256 tableId, uint256 numEntries) external payable nonReentrant isValidTable(tableId) {
        require(
            !paused,
            'Game Is Paused'
        );
        require(
            numEntries > 0,
            'Must Have At Least One Entry'
        );

        // if first join, start the game
        if (tables[tableId].gameID == 0) {
            _startGame(tableId);
        }

        // join game
        uint256 gameId = _joinGame(tableId, numEntries);

        // if max players is reached, end game early
        if (games[gameId].playersForRNG.length >= tables[tableId].max_players) {
            _endGame(tableId);
        }
    }

    function endGame(uint256 tableId) external nonReentrant isValidTable(tableId) {
        require(
            tables[tableId].gameID > 0,
            'No Game'
        );

        // end game
        _endGame(tableId);
    }

    function donateToGamePot(uint256 tableId, uint256 amount) external nonReentrant payable isValidTable(tableId) {
        
        uint256 gameID = tables[tableId].gameID;
        require(
            gameID > 0,
            'No Game'
        );
        if (tables[tableId].token == address(0)) {
            require(amount == 0, 'Invalid Amount');
        } else {
            require(msg.value == 0, 'Invalid Value');
        }

        // determine value we are adding based on table token
        uint256 valueToAdd = tables[tableId].token == address(0) ? msg.value : _transferIn(tables[tableId].token, amount);
        
        // increment pot by amount received
        unchecked {
            games[gameID].pot += valueToAdd;
        }
    }


    //////////////////////////////////////
    ///////   INTERNAL FUNCTIONS  ////////
    //////////////////////////////////////

    function _startGame(uint256 tableId) internal {

        // set table stats
        tables[tableId].gameID = gameNonce;

        // set game stats
        games[gameNonce].tableId = tableId;
        games[gameNonce].endTime = block.timestamp + tables[tableId].duration;
        
        // emit event
        emit GameStarted(tableId, gameNonce);

        // increment game nonce
        unchecked {
            ++gameNonce;
        }
    }

    function _endGame(uint256 tableId) internal {
        uint256 gameId = tables[tableId].gameID;
        require(
            games[gameId].hasEnded == false,
            'Game Already Ended'
        );
        if (games[gameId].playersForRNG.length < tables[tableId].max_players) {
            require(
                timeUntilGameEnds(gameId) == 0,
                'Not Time'
            );
        }

        // toggle has ended to true
        games[gameId].hasEnded = true;

        // check if there's more than one unique player in the game
        if (games[gameId].players.length == 1) {

            // clear storage
            delete tables[tableId].gameID; // allow new game to start

            // fetch the one user
            address user = games[gameId].players[0];

            // set user to be winner
            games[gameId].winner = user;

            // only one user, refund full value, don't take fee
            _sendToClaimManager(
                tables[tableId].token, user, games[gameId].pot
            );
            
        } else {
            
            // request random word
            _requestRandom(gameId);
        }
        
    }

    function _joinGame(uint256 tableId, uint256 numEntries) internal returns (uint256) {

        // current game ID
        uint256 tableId_ = tableId;
        uint256 gameId = tables[tableId_].gameID;
        address token = tables[tableId_].token;
        

        // ensure state allows for new game
        require(
            gameId > 0,
            'No Game'
        );
        require(
            games[tables[tableId_].gameID].hasEnded == false,
            'Game Already Ended'
        );

        // add player to RNG tracker
        for (uint i = 0; i < numEntries;) {
            games[gameId].playersForRNG.push(msg.sender); // cheaper to do this than add to mapping and increment total
            unchecked { ++i; }
        }

        // add player if unique
        if (games[gameId].entriesPerPlayer[msg.sender] == 0) {

            // add to unique list of players
            games[gameId].players.push(msg.sender);
        }

        // increment entry
        unchecked {
            games[gameId].entriesPerPlayer[msg.sender] += numEntries;
        }

        // ensure we did not overflow the number of players
        require(
            games[gameId].playersForRNG.length <= tables[tableId_].max_players,
            'Max Players Entered'
        );

        // ensure buy in requirement is met
        uint256 cost = tables[tableId_].buyIn * numEntries;

        if (token == address(0)) {
            require(
                msg.value >= cost,
                'Invalid Buy In'
            );
        } else {
            cost = _transferIn(token, cost);
        }

        // Calculate VRF Cost Fee
        uint256 vrfFee = token == address(0) ? msg.value - cost : msg.value;
        require(
            vrfFee >= ( minBuyInGas * numEntries ),
            'MIN BUY IN GAS AID REQUIRED'
        );

        // send fee to fee recipient
        _send(address(0), chainlinkFeeReceiver, vrfFee);

        // calculate cost for the pot
        uint256 costForPot = _takeFee(tableId, cost);

        // increase pot size
        unchecked {
            games[gameId].pot += costForPot;
        }

        // add points for user
        IPointManager(pointManager).addPoints(
            msg.sender, 
            tables[tableId_].nPoints * numEntries
        );

        // return the current gameId
        return gameId;
    }

    function _takeFee(uint256 tableId, uint256 amount) internal returns (uint256) {

        // divvy up fees
        uint256 platform = ( amount * tables[tableId].platformFee ) / FEE_DENOM;
        uint256 addr0_ = ( amount * 50 ) / FEE_DENOM;

        // send fees to sources
        _send(tables[tableId].token, platformFeeRecipient, platform);
        _send(tables[tableId].token, addr0, addr0_);
        
        // return amount less fees
        return amount - ( platform + addr0_ );
    }

    function _requestRandom(uint256 gameId) internal {

        // request random words from RNG contract
        uint256 requestId = IRNG(RNG).requestRandom(
            gasToCallRandom, // callback gas limit is dependent num of random values & gas used in callback
            1 // the number of random results to return
        );

        // require that the requestId is unused
        require(
            requestToGame[requestId] == 0,
            'RequestId In Use'
        );

        // map this request ID to the game it belongs to
        requestToGame[requestId] = gameId;

        // emit event
        emit RandomnessRequested(gameId);
    }

    /**
        Callback to provide us with randomness
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) external {
        require(
            msg.sender == RNG,
            'Only RNG'
        );

        // get game ID from requestId
        uint256 gameId = requestToGame[requestId];
        
        // if faulty ID, remove
        if (gameId == 0 || games[gameId].playersForRNG.length == 0) {
            emit FulfilRandomFailed(requestId, gameId, randomWords);
            return;
        }

        // clear storage
        delete requestToGame[requestId];
        delete tables[games[gameId].tableId].gameID; // allow new game to start

        // process random word for table
        uint nEntries = games[gameId].playersForRNG.length;
        if (nEntries > 0) {

            // select winner out of array
            address winner = games[gameId].playersForRNG[randomWords[0] % nEntries];
            games[gameId].winner = winner;

            // send pot to winner, allowing them to claim
            _sendToClaimManager(tables[games[gameId].tableId].token, winner, games[gameId].pot);
            
            // Emit Game Ended Event
            emit GameEnded(games[gameId].tableId, gameId, winner);
        } 
    }

    function _send(address token, address to, uint amount) internal {
        if (to == address(0) || amount == 0) {
            return;
        }

        if (token == address(0)) {
            TransferHelper.safeTransferETH(to, amount);
        } else {
            TransferHelper.safeTransfer(token, to, amount);
        }
    }

    function _sendToClaimManager(address token, address user, uint256 value) internal {
        if (user == address(0) || value == 0) {
            return;
        }
        if (token == address(0)) {
            if (value > address(this).balance) {
                value = address(this).balance;
            }
            if (value == 0) {
                return;
            }
            // enforce user claims rewards to preserve minOut when swapping
            IClaimManager(claimManager).credit{value: value}(user);
        } else {
            if (value > IERC20(token).balanceOf(address(this))) {
                value = IERC20(token).balanceOf(address(this));
            }
            if (value == 0) {
                return;
            }
            // send tokens to user
            TransferHelper.safeTransfer(token, user, value);
        }
    }

    function _transferIn(address token, uint256 amount) internal returns (uint256) {
        require(
            IERC20(token).balanceOf(msg.sender) >= amount,
            'Insufficient Balance'
        );
        require(
            IERC20(token).allowance(msg.sender, address(this)) >= amount,
            'Insufficient Allowance'
        );
        uint256 before = IERC20(token).balanceOf(address(this));
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);
        uint256 After = IERC20(token).balanceOf(address(this));
        require(
            After > before,
            'Transfer Failed'
        );
        return After - before;
    }

    //////////////////////////////////////
    ///////     READ FUNCTIONS    ////////
    //////////////////////////////////////

    function validTable(uint256 tableId) public view returns (bool) {
        return tableId > 0 && tables[tableId].max_players > 0;
    }

    function canEndGame(uint256 tableId) external view returns (bool) {
        uint256 gameId = tables[tableId].gameID;
        if (gameId == 0) {
            return false;
        }
        if (games[gameId].hasEnded) {
            return false;
        }
        if (games[gameId].playersForRNG.length < tables[tableId].max_players) {
            return timeUntilGameEnds(gameId) == 0;
        }
        return true;
    }

    function getMaxPot(uint256 tableId) public view returns (uint256) {
        uint trueMax = tables[tableId].buyIn * tables[tableId].max_players;
        uint platformFee = ( trueMax * tables[tableId].platformFee ) / FEE_DENOM;
        uint addr0_ = ( trueMax * 50 ) / FEE_DENOM;
        return trueMax - ( platformFee + addr0_ );
    }

    function getMaxPots() external view returns (uint256[] memory) {
        uint256[] memory maxPots = new uint256[](tableNonce - 1);
        for (uint i = 1; i < tableNonce;) {
            maxPots[i-1] = getMaxPot(i);
            unchecked { ++i; }
        }
        return maxPots;
    }

    function calculatePot(uint256 tableId, uint256 amount) external view returns (uint256) {
        uint256 platform = ( amount * tables[tableId].platformFee ) / FEE_DENOM;
        return amount - platform;
    }

    function getPlayersForTable(uint256 tableId) public view returns (address[] memory) {
        return getPlayersForGame(tables[tableId].gameID);
    }

    function getPlayersForGame(uint256 gameId) public view returns (address[] memory) {
        return games[gameId].players;
    }

    function getWinnerForGame(uint256 gameId) public view returns (address) {
        return games[gameId].winner;
    }

    function getWinnerAndPotForGame(uint256 gameId) public view returns (address, uint256) {
        return ( games[gameId].winner, games[gameId].pot );
    }

    function getWinnersAndPotsForAllGames() public view returns (address[] memory, uint256[] memory) {
        address[] memory winners = new address[](gameNonce - 1);
        uint256[] memory pots = new uint256[](gameNonce - 1);
        for (uint i = 1; i < gameNonce;) {
            (winners[i-1], pots[i-1]) = getWinnerAndPotForGame(i);
            unchecked { ++i; }
        }
        return (winners, pots);
    }

    function getTableInfo(uint256 tableId) public view returns (
        address token,
        uint256 buyIn,
        uint32 max_players,
        uint256 numberOfPlayers,
        uint256 gameID,
        uint256 duration,
        uint256 nPoints
    ) {
        token = tables[tableId].token;
        buyIn = tables[tableId].buyIn;
        max_players = tables[tableId].max_players;
        numberOfPlayers = games[tables[tableId].gameID].playersForRNG.length;
        gameID = tables[tableId].gameID;
        duration = tables[tableId].duration;
        nPoints = tables[tableId].nPoints;
    }

    function listTableInfo() external view returns (
        address[] memory tokens,
        uint256[] memory buyIns,
        uint32[] memory max_players,
        uint256[] memory numberOfPlayers,
        uint256[] memory gameIDs,
        uint256[] memory durations,
        uint256[] memory nPoints
    ) {
        tokens = new address[](tableNonce - 1);
        buyIns = new uint256[](tableNonce - 1);
        max_players = new uint32[](tableNonce - 1);
        numberOfPlayers = new uint256[](tableNonce - 1);
        gameIDs = new uint256[](tableNonce - 1);
        durations = new uint256[](tableNonce - 1);
        nPoints = new uint256[](tableNonce - 1);

        for (uint i = 1; i < tableNonce;) {
            (
                tokens[i-1],
                buyIns[i-1],
                max_players[i-1],
                numberOfPlayers[i-1],
                gameIDs[i-1],
                durations[i-1],
                nPoints[i-1]
            ) = getTableInfo(i);
            unchecked { ++i; }
        }
    }

    function listGameIDs() external view returns (
        uint256[] memory gameIDs
    ) {
        gameIDs = new uint256[](tableNonce - 1);
        for (uint i = 1; i < tableNonce;) {
            gameIDs[i-1] = tables[i].gameID;
            unchecked { ++i; }
        }
    }

    function listTableAndGamesInfo() external view returns (
        address[] memory tokens,
        uint256[] memory buyIns,
        uint32[] memory max_players,
        uint256[] memory numberOfPlayers,
        uint256[] memory pots,
        uint256[] memory gameIDs,
        uint256[] memory endTimes,
        uint256[] memory nPoints
    ) {
        tokens = new address[](tableNonce - 1);
        buyIns = new uint256[](tableNonce - 1);
        max_players = new uint32[](tableNonce - 1);
        numberOfPlayers = new uint256[](tableNonce - 1);
        pots = new uint256[](tableNonce - 1);
        gameIDs = new uint256[](tableNonce - 1);
        endTimes = new uint256[](tableNonce - 1);
        nPoints = new uint256[](tableNonce - 1);
        uint gameId;

        for (uint i = 1; i < tableNonce;) {
            (
                tokens[i - 1],
                buyIns[i - 1],
                max_players[i - 1],
                numberOfPlayers[i-1],
                gameId,
                ,
                nPoints[i - 1]
            ) = getTableInfo(i);
            endTimes[i - 1] = games[gameId].endTime;
            pots[i - 1] = games[gameId].pot;
            gameIDs[i - 1] = gameId;
            unchecked { ++i; }
        }
    }

    function listTableAndGameInfo(uint256 gameId) external view returns (
        uint256 buyIn,
        uint32 max_players,
        uint256 numberOfPlayers,
        uint256 pot,
        uint256 endTime,
        uint256 nPoints
    ) {
        // fetch table id
        uint256 tableId = games[gameId].tableId;

        // fetch table info
        buyIn = tables[tableId].buyIn;
        max_players = tables[tableId].max_players;
        nPoints = tables[tableId].nPoints;

        // fetch game info
        numberOfPlayers = games[gameId].playersForRNG.length;
        pot = games[gameId].pot;
        endTime = games[gameId].endTime;
    }

    function getGameInfo(uint256 gameId) external view returns(
        bool gameEnded,
        uint256 tableId,
        address[] memory players,
        uint256 endTime,
        address winner,
        uint256 pot
    ) {
        gameEnded = games[gameId].hasEnded;
        tableId = games[gameId].tableId;
        players = games[gameId].players;
        endTime = games[gameId].endTime;
        winner = games[gameId].winner;
        pot = games[gameId].pot;
    }

    function getGameInfoNoPlayers(uint256 gameId) external view returns(
        bool gameEnded,
        uint256 tableId,
        uint256 endTime,
        address winner,
        uint256 pot
    ) {
        gameEnded = games[gameId].hasEnded;
        tableId = games[gameId].tableId;
        endTime = games[gameId].endTime;
        winner = games[gameId].winner;
        pot = games[gameId].pot;
    }

    function entriesPerPlayer(address user, uint256 gameId) public view returns (uint256) {
        return games[gameId].entriesPerPlayer[user];
    }

    function entriesForAllPlayers(uint256 gameId) external view returns (uint256[] memory) {
        uint len = games[gameId].players.length;
        uint256[] memory playerEntries = new uint256[](len);
        for (uint i = 0; i < len;) {
            playerEntries[i] = games[gameId].entriesPerPlayer[games[gameId].players[i]];
            unchecked { ++i; }
        }
        return playerEntries;
    }

    function entriesForListOfPlayers(uint256 gameId, address[] calldata players) external view returns (uint256[] memory) {
        uint len = players.length;
        uint256[] memory playerEntries = new uint256[](len);
        for (uint i = 0; i < len;) {
            playerEntries[i] = games[gameId].entriesPerPlayer[players[i]];
            unchecked { ++i; }
        }
        return playerEntries;
    }

    function numPlayersInGame(uint256 gameId) external view returns (uint256) {
        return games[gameId].players.length;
    }

    function numEntriesInGame(uint256 gameId) external view returns (uint256) {
        return games[gameId].playersForRNG.length;
    }

    function entriesVersusMax(uint256 gameId) external view returns (uint256, uint256) {
        return ( games[gameId].playersForRNG.length, tables[games[gameId].tableId].max_players);
    }

    function timeUntilTableEnds(uint256 tableId) external view returns (uint256) {
        return timeUntilGameEnds(tables[tableId].gameID);
    }

    function timeUntilGameEnds(uint256 gameId) public view returns (uint256) {
        if (gameId == 0) {
            return 0;
        }
        return games[gameId].endTime > block.timestamp ? games[gameId].endTime - block.timestamp : 0;
    }

    function paginatePlayers(uint256 gameId, uint256 startIndex, uint256 endIndex) external view returns (address[] memory) {
        address[] memory players = new address[](endIndex - startIndex);
        uint count = 0;
        for (uint i = startIndex; i < endIndex;) {
            players[count] = games[gameId].players[i];
            unchecked { ++count; ++i; }
        }
        return players;
    }

}