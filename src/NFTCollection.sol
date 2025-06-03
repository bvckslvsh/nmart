// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/// @title Simple ERC721 NFT Collection Contract
/// @notice Allows users to mint NFTs with a unique URI and tracks the original creator of each token
contract NFTCollection is ERC721URIStorage {
    /// @notice Token name is "NMARTC", symbol is "NMARTCOLLECTION"
    constructor() ERC721("NMARTC", "NMARTCOLLECTION") {}

    /// @notice Mapping from tokenId to the address of the original creator
    mapping(uint256 => address) public creatorOf;

    /// @notice Counter for new token IDs
    uint256 private tokenId = 0;

    /// @notice Emitted when a new token is minted
    /// @param creator The address who minted the token
    /// @param tokenId The token's unique ID
    /// @param uri The metadata URI associated with the token
    event Minted(address indexed creator, uint256 indexed tokenId, string uri);

    /// @notice Mint a new NFT with a specific metadata URI
    /// @param _uri The metadata URI for the token
    function mint(string calldata _uri) external {
        ++tokenId; // increment token counter
        _mint(msg.sender, tokenId); // mint token to caller
        _setTokenURI(tokenId, _uri); // set token metadata URI
        creatorOf[tokenId] = msg.sender; // store creator address
        emit Minted(msg.sender, tokenId, _uri); // emit event
    }
}
