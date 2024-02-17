// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.0;

import "./ReentrancyGuard.sol";
import "./Governance.sol";
import "./ITrustedTransfarableERC20.sol";
import "./Utils.sol";

contract TokenGovernance is ReentrancyGuard {
    event TokenListerUpdate(address indexed tokenLister, bool isActive);
    event ListingFeeTokenUpdate(ITrustedTransfarableERC20 indexed newListingFeeToken, uint256 newListingFee);
    event ListingFeeUpdate(uint256 newListingFee);
    event ListingCapUpdate(uint16 newListingCap);
    event TreasuryUpdate(address newTreasury);

    Governance public governance;
    ITrustedTransfarableERC20 public listingFeeToken;
    uint256 public listingFee;
    uint16 public listingCap;
    address public treasury;
    mapping(address => bool) public tokenLister;

    constructor(
        Governance _governance,
        ITrustedTransfarableERC20 _listingFeeToken,
        uint256 _listingFee,
        uint16 _listingCap,
        address _treasury
    ) {
        initializeReentrancyGuard();
        governance = _governance;
        listingFeeToken = _listingFeeToken;
        listingFee = _listingFee;
        listingCap = _listingCap;
        treasury = _treasury;
        tokenLister[_governance.networkGovernor()] = true;
        emit TokenListerUpdate(_governance.networkGovernor(), true);
    }

    modifier onlyGovernor() {
        require(msg.sender == governance.networkGovernor(), "Only governor");
        _;
    }

    function addToken(address _token) external nonReentrant {
        require(_token != address(0), "Token address cannot be zero");
        require(_token != address(governance), "Token address cannot be governance address");
        require(governance.totalTokens() < listingCap, "Maximum tokens reached");

        if (!tokenLister[msg.sender] && listingFee > 0) {
            require(listingFeeToken.transferFrom(msg.sender, treasury, listingFee), "Fee transfer failed");
        }
        governance.addToken(_token);
    }

    function setListingFeeToken(ITrustedTransfarableERC20 _newListingFeeToken, uint256 _newListingFee) external onlyGovernor {
        listingFeeToken = _newListingFeeToken;
        listingFee = _newListingFee;
        emit ListingFeeTokenUpdate(_newListingFeeToken, _newListingFee);
    }

    function setListingFee(uint256 _newListingFee) external onlyGovernor {
        listingFee = _newListingFee;
        emit ListingFeeUpdate(_newListingFee);
    }

    function setLister(address _listerAddress, bool _active) external onlyGovernor {
        if (tokenLister[_listerAddress] != _active) {
            tokenLister[_listerAddress] = _active;
            emit TokenListerUpdate(_listerAddress, _active);
        }
    }

    function setListingCap(uint16 _newListingCap) external onlyGovernor {
        listingCap = _newListingCap;
        emit ListingCapUpdate(_newListingCap);
    }

    function setTreasury(address _newTreasury) external onlyGovernor {
        treasury = _newTreasury;
        emit TreasuryUpdate(_newTreasury);
    }
}
