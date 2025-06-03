// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./NFTCollection.sol";

/// @title NFT Marketplace with Royalty Support
/// @notice Allows users to list, buy, delist NFTs with a fixed royalty fee paid to creators
contract NFTMarketplace is ReentrancyGuard {
    /// @notice Reference to the NFT collection contract
    NFTCollection public nftCollection;

    /// @notice Constructor sets the NFT collection address
    /// @param _nftCollection Address of the deployed NFTCollection contract
    constructor(address _nftCollection) {
        nftCollection = NFTCollection(_nftCollection);
    }

    /// @notice Royalty percentage sent to original creators (5%)
    uint256 private constant royaltyPercent = 5;

    /// @notice Listing data structure
    struct Listing {
        address seller; // Owner who listed the NFT
        uint256 price; // Sale price
        bool active; // Is listing currently active
    }

    /// @notice Maps tokenId to its current listing info
    mapping(uint256 => Listing) tokenListings;

    /// @notice Amounts pending withdrawal per address (sellers and creators)
    mapping(address => uint256) public pendingWithdrawals;

    /// @notice Emitted when an NFT is listed for sale
    /// @param seller The address who listed the NFT
    /// @param tokenId The NFT token ID
    /// @param price The listing price
    /// @param timestamp When the event happened
    event Listed(address indexed seller, uint256 indexed tokenId, uint256 price, uint256 timestamp);

    /// @notice Emitted when an NFT is delisted (removed from sale)
    event Delisted(address indexed seller, uint256 indexed tokenId, uint256 price, uint256 timestamp);

    /// @notice Emitted when an NFT is sold
    event Sold(address indexed seller, uint256 indexed tokenId, uint256 price, uint256 timestamp);

    /// @notice List an owned NFT on the marketplace for sale at a fixed price
    /// @param _tokenId The ID of the NFT to list
    /// @param _price The sale price in wei (must be > 0)
    function listNFT(uint256 _tokenId, uint256 _price) external nonReentrant {
        // Only owner of the token can list it
        require(nftCollection.ownerOf(_tokenId) == msg.sender, "Caller is not the token owner!");
        require(_price > 0, "Price can't be 0!");
        // Token must not be already listed
        require(tokenListings[_tokenId].active == false, "Token is already listed!");

        // Transfer NFT to marketplace contract for escrow during sale
        nftCollection.safeTransferFrom(msg.sender, address(this), _tokenId);

        // Record the new listing
        tokenListings[_tokenId] = Listing({seller: msg.sender, price: _price, active: true});

        emit Listed(msg.sender, _tokenId, _price, block.timestamp);
    }

    /// @notice Remove an NFT listing, returning the NFT to the seller
    /// @param _tokenId The ID of the NFT to delist
    function delistNFT(uint256 _tokenId) external nonReentrant {
        // Only the seller who listed can delist
        require(tokenListings[_tokenId].seller == msg.sender, "Not the seller");
        require(tokenListings[_tokenId].active == true, "Token is not Listed!");

        // Mark listing inactive
        tokenListings[_tokenId].active = false;

        // Return NFT back to seller
        nftCollection.safeTransferFrom(address(this), tokenListings[_tokenId].seller, _tokenId);

        emit Delisted(tokenListings[_tokenId].seller, _tokenId, tokenListings[_tokenId].price, block.timestamp);

        // Remove listing from storage
        delete tokenListings[_tokenId];
    }

    /// @notice Buy a listed NFT by paying the listed price
    /// @param _tokenId The ID of the NFT to purchase
    function buyNFT(uint256 _tokenId) external payable nonReentrant {
        require(tokenListings[_tokenId].active == true, "Token is not Listed!");
        require(msg.value >= tokenListings[_tokenId].price, "Not enough money!");

        // Mark listing inactive (sold)
        tokenListings[_tokenId].active = false;

        // Calculate royalty amount (5%)
        uint256 royaltySum = (tokenListings[_tokenId].price / 100) * royaltyPercent;

        // Remaining amount goes to the seller
        uint256 sellerPrice = tokenListings[_tokenId].price - royaltySum;

        // Lookup creator address from NFT contract
        address creator = nftCollection.creatorOf(_tokenId);

        // Accumulate pending withdrawals for creator and seller
        pendingWithdrawals[creator] += royaltySum;
        pendingWithdrawals[tokenListings[_tokenId].seller] += sellerPrice;

        // Transfer NFT ownership to buyer
        nftCollection.safeTransferFrom(address(this), msg.sender, _tokenId);

        emit Sold(tokenListings[_tokenId].seller, _tokenId, tokenListings[_tokenId].price, block.timestamp);

        // Clean up listing mapping
        delete tokenListings[_tokenId];
    }

    /// @notice ERC721 receiver hook to accept safe transfers
    /// @dev Required for receiving ERC721 tokens safely
    function onERC721Received(address, /*operator*/ address, /*from*/ uint256, /*tokenId*/ bytes calldata /*data*/ )
        external
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    /// @notice Withdraw accumulated proceeds (sales or royalties)
    /// @dev Transfers the caller's pending withdrawal balance and resets it to zero
    function withdraw() external nonReentrant {
        require(pendingWithdrawals[msg.sender] > 0, "Nothing to withdraw!");
        uint256 amount = pendingWithdrawals[msg.sender];
        pendingWithdrawals[msg.sender] = 0;

        // Send ETH to the caller, revert if transfer fails
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed!");
    }
}
