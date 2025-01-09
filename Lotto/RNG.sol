//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Ownable.sol";
import "./IVRF.sol";

interface IChainlinkSubscriptionOwner {
    function getSubscriptionID() external view returns (uint64);
}

interface IGame {
    function fulfillRandomWords(uint256 requestId,uint256[] calldata randomWords) external;
}

/**
    Random Number Generator Tracking Contract

    Add in fetching from chainlinkOwner for data

    Pulled from pvp.money's RNG Tracker contract
    visit https://pvp.money
 */
contract RNGTracker is Ownable, VRFConsumerBaseV2 {

    // VRF Coordinator
    VRFCoordinatorV2Interface public immutable COORDINATOR;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    bytes32 public keyHash; // 0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04

    // Number of block confirmations
    uint16 public num_confirmations;

    // maps request ID to requester
    mapping ( uint256 => address ) private requestIdToRequester;

    // Chainlink subscription owner
    IChainlinkSubscriptionOwner public chainlinkSubscriptionOwner;

    // Maps an address to whether or not it is a game
    mapping ( address => bool ) public isGame;

    /**
        Builds The Necessary Components Of Any Game
     */
    constructor(
        address coordinator_,
        bytes32 keyHash_,
        address chainlinkSubscriptionOwner_
    ) VRFConsumerBaseV2(coordinator_) {

        // setup chainlink
        COORDINATOR = VRFCoordinatorV2Interface(coordinator_);
        chainlinkSubscriptionOwner = IChainlinkSubscriptionOwner(chainlinkSubscriptionOwner_);

        // set key hash
        keyHash = keyHash_;
        num_confirmations = 3;
    }

    function setKeyHash(bytes32 newHash) external onlyOwner {
        keyHash = newHash;
    }

    function setChainlinkSubscriptionOwner(address newOwner) external onlyOwner {
        chainlinkSubscriptionOwner = IChainlinkSubscriptionOwner(newOwner);
    }

    function setIsGame(address game, bool value) external onlyOwner {
        isGame[game] = value;
    }

    function setNumConfirmations(uint16 numConfirmations) external onlyOwner {
        require(
            num_confirmations >= 3,
            'Num Confirmations Too Low'
        );
        require(
            num_confirmations < 200,
            'Num Confirmations Too High'
        );
        num_confirmations = numConfirmations;
    }

    function requestRandom(uint32 gas, uint32 numResults) external returns (uint256 requestId) {
        require(
            isGame[msg.sender],
            'Not A Game'
        );
        require(
            gas >= 250_000 && gas <= 2_500_000,
            'Gas Out Of Range'
        );
        require(
            numResults >= 1 && numResults < 500,
            'Too Many Results'
        );

        // fetch the current chainlink subscription id
        uint64 subId = chainlinkSubscriptionOwner.getSubscriptionID();

        // get random number and send rewards when callback is executed
        // the callback is called "fulfillRandomWords"
        // this will revert if VRF subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subId,
            num_confirmations, // number of block confirmations before returning random value
            gas, // callback gas limit is dependent num of random values & gas used in callback
            numResults // the number of random results to return
        );

        // require that this ID is not in use by another game
        require(
            requestIdToRequester[requestId] == address(0),
            'Duplicate Request'
        );

        // save the requestId to the game that made the request
        requestIdToRequester[requestId] = msg.sender;
    }

    /**
        Chainlink's callback to provide us with randomness
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {

        // fetch game address 
        address game = requestIdToRequester[requestId];

        // ensure valid request Id
        if (game == address(0)) {
           return;
        }

        // remove request ID mapping to save gas
        delete requestIdToRequester[requestId];

        // perform call back on Game
        IGame(game).fulfillRandomWords(requestId, randomWords);
    }

    function subscriptionId() external view returns (uint64) {
        return chainlinkSubscriptionOwner.getSubscriptionID();
    }
}