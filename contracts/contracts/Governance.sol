// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.0;

import "./Config.sol";
import "./Utils.sol";
import "./NFTFactory.sol";
import "./TokenGovernance.sol";

contract Governance is Config {
    address public networkGovernor;
    uint16 public totalTokens;
    TokenGovernance public tokenGovernance;
    NFTFactory public defaultFactory;

    mapping(uint16 => address) public tokenAddresses;
    mapping(address => uint16) public tokenIds;
    mapping(address => bool) public validators;
    mapping(uint16 => bool) public pausedTokens;
    mapping(uint32 => mapping(address => NFTFactory)) public nftFactories;

    modifier onlyGovernor() {
        require(msg.sender == networkGovernor, "Only governor");
        _;
    }

    modifier onlyTokenGovernance() {
        require(msg.sender == address(tokenGovernance), "Only token governance");
        _;
    }

    modifier onlyIfTokenExists(address _token) {
        require(tokenIds[_token] == 0, "Token exists");
        _;
    }

    event NewToken(address indexed token, uint16 indexed tokenId);
    event TokenPausedUpdate(address indexed token, bool paused);
    event ValidatorStatusUpdate(address indexed validatorAddress, bool isActive);
    event NewGovernor(address newGovernor);
    event NewTokenGovernance(TokenGovernance newTokenGovernance);
    event NFTFactoryRegisteredCreator(uint32 indexed creatorAccountId, address indexed creatorAddress, address factoryAddress);
    event SetDefaultNFTFactory(address indexed factory);

    function initialize(bytes calldata initializationParameters) external {
        networkGovernor = abi.decode(initializationParameters, (address));
    }

    function changeGovernor(address _newGovernor) external onlyGovernor {
        if (networkGovernor != _newGovernor) {
            networkGovernor = _newGovernor;
            emit NewGovernor(_newGovernor);
        }
    }

    function changeTokenGovernance(TokenGovernance _newTokenGovernance) external onlyGovernor {
        if (tokenGovernance != _newTokenGovernance) {
            tokenGovernance = _newTokenGovernance;
            emit NewTokenGovernance(_newTokenGovernance);
        }
    }

    function addToken(address _token) external onlyTokenGovernance onlyIfTokenExists(_token) {
        totalTokens++;
        uint16 newTokenId = totalTokens;
        tokenAddresses[newTokenId] = _token;
        tokenIds[_token] = newTokenId;
        emit NewToken(_token, newTokenId);
    }

    function setTokenPaused(address _tokenAddr, bool _tokenPaused) external onlyGovernor {
        uint16 tokenId = validateTokenAddress(_tokenAddr);
        if (pausedTokens[tokenId] != _tokenPaused) {
            pausedTokens[tokenId] = _tokenPaused;
            emit TokenPausedUpdate(_tokenAddr, _tokenPaused);
        }
    }

    function setValidator(address _validator, bool _active) external onlyGovernor {
        if (validators[_validator] != _active) {
            validators[_validator] = _active;
            emit ValidatorStatusUpdate(_validator, _active);
        }
    }

    function requireActiveValidator(address _address) external view {
        require(validators[_address], "Validator is not active");
    }

    function isValidTokenId(uint16 _tokenId) external view returns (bool) {
        return _tokenId <= totalTokens;
    }

    function validateTokenAddress(address _tokenAddr) public view returns (uint16) {
        uint16 tokenId = tokenIds[_tokenAddr];
        require(tokenId != 0, "Invalid token");
        return tokenId;
    }

    // Other functions remain unchanged
}
