// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DirectFundingConsumer} from "./DirectFundingConsumer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Coinflip is Ownable {
    // A map of the player and their corresponding requestId
    mapping(address => uint256) public playerRequestID;
    // A map that stores the player's 3 Coinflip guesses
    mapping(address => uint8[3]) public bets;
    // An instance of the random number requestor, client interface
    DirectFundingConsumer private vrfRequestor;

    // VRF instance setup
    constructor() Ownable(msg.sender) {
        vrfRequestor = new DirectFundingConsumer();
    }

    ///@notice Fund the VRF instance with 5 LINK tokens.
    ///@return boolean of whether funding the VRF instance with LINK tokens was successful or not
    ///@dev Ensure that the contract has enough LINK tokens before calling this function.
    function fundOracle() external returns(bool) {
        address LINK_ADDR = 0x779877A7B0D9E8603169DdbD7836e478b4624789;  // LINK token address
        uint256 LINK_AMOUNT = 5 * 10**18; // 5 LINK tokens (decimals)
        bool successful = IERC20(LINK_ADDR).transfer(address(vrfRequestor), LINK_AMOUNT);
        require(successful, "Transfer failed");
        return successful;
    }

    ///@notice User guesses THREE flips, either 1 or 0.
    ///@param Guesses - 3 guesses required to be 1 or 0
    ///@dev After validating the user input, store the user's input and request random numbers.
    function userInput(uint8[3] calldata Guesses) external {
        require(Guesses[0] == 0 || Guesses[0] == 1, "Guess must be 0 or 1");
        require(Guesses[1] == 0 || Guesses[1] == 1, "Guess must be 0 or 1");
        require(Guesses[2] == 0 || Guesses[2] == 1, "Guess must be 0 or 1");

        // Store user guesses
        bets[msg.sender] = Guesses;
        
        // Request random numbers (3 flips) from VRF
        uint256 requestId = vrfRequestor.requestRandomWords(true);
        
        // Store the request ID for the user
        playerRequestID[msg.sender] = requestId;
    }

    ///@notice User checks the status of their random number request.
    ///@return boolean of whether the request has been fulfilled or not
    function checkStatus() external view returns(bool) {
        uint256 requestId = playerRequestID[msg.sender];
        (, bool fulfilled, ) = vrfRequestor.getRequestStatus(requestId);
        return fulfilled;
    }

    ///@notice Determine if the player won based on their guesses and the random numbers.
    ///@return boolean of whether the user won or not based on their input
    function determineFlip() external view returns(bool){
        uint256 requestId = playerRequestID[msg.sender];
        (, bool fulfilled, uint256[] memory randomWords) = vrfRequestor.getRequestStatus(requestId);
        require(fulfilled, "Randomness not fulfilled yet");
        require(randomWords.length >= 3, "Not enough random words received");

        uint8[3] memory outcomes;
        for (uint i = 0; i < 3; i++) {
            outcomes[i] = uint8(randomWords[i] % 2);
        }
        uint8[3] memory userGuesses = bets[msg.sender];
        return (outcomes[0] == userGuesses[0] &&
                outcomes[1] == userGuesses[1] &&
                outcomes[2] == userGuesses[2]);
    }
}
