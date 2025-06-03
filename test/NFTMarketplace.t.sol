// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {NFTCollection} from "../src/NFTCollection.sol";

contract MarketplaceTest is Test {
    NFTMarketplace public marketplace;
    NFTCollection public collection;

    address alice = vm.addr(1);
    address bob = vm.addr(2);
    address charlie = vm.addr(3);

    function setUp() public {
        collection = new NFTCollection();
        marketplace = new NFTMarketplace(address(collection));
    }

    function testListNFT() public {
        vm.prank(alice);
        collection.mint("ipfs://my-nft-uri");

        uint256 tokenId = 1;

        vm.prank(alice);
        collection.approve(address(marketplace), tokenId);

        vm.prank(alice);
        marketplace.listNFT(tokenId, 1 ether);

        assertEq(collection.ownerOf(tokenId), address(marketplace));
    }

    function testDelistNFTbySeller() public {
        vm.startPrank(alice);
        collection.mint("ipfs://test-uri");

        uint256 tokenId = 1;

        collection.approve(address(marketplace), tokenId);
        marketplace.listNFT(tokenId, 1 ether);
        marketplace.delistNFT(tokenId);
        vm.stopPrank();

        assertEq(collection.ownerOf(tokenId), alice);
    }

    function testBuyNFT() public {
        vm.startPrank(alice);
        collection.mint("ipfs://test-uri");
        uint256 tokenId = 1;
        collection.approve(address(marketplace), tokenId);
        marketplace.listNFT(tokenId, 1 ether);
        vm.stopPrank();

        vm.deal(bob, 1 ether);
        vm.startPrank(bob);
        marketplace.buyNFT{value: 1 ether}(tokenId);
        vm.stopPrank();

        assertEq(collection.ownerOf(tokenId), bob);
        assertEq(marketplace.pendingWithdrawals(alice), 1 ether);
    }

    function testBuyRoyaltyNFT() public {
        vm.startPrank(alice);
        collection.mint("ipfs://test-uri");
        uint256 tokenId = 1;
        collection.approve(address(bob), tokenId);
        assertEq(collection.ownerOf(tokenId), alice);
        collection.transferFrom(alice, bob, tokenId);
        vm.stopPrank();

        vm.startPrank(bob);
        collection.approve(address(marketplace), tokenId);
        marketplace.listNFT(tokenId, 1 ether);
        vm.stopPrank();

        vm.deal(charlie, 1 ether);
        vm.startPrank(charlie);
        marketplace.buyNFT{value: 1 ether}(tokenId);
        vm.stopPrank();

        assertEq(collection.ownerOf(tokenId), charlie);
        assertEq(marketplace.pendingWithdrawals(alice), 0.05 ether);
        assertEq(marketplace.pendingWithdrawals(bob), 0.95 ether);
    }

    function testWithdrawAfterSale() public {
        vm.startPrank(alice);
        collection.mint("ipfs://test-uri");
        uint256 tokenId = 1;
        collection.approve(address(marketplace), tokenId);
        marketplace.listNFT(tokenId, 1 ether);
        vm.stopPrank();

        vm.deal(bob, 1 ether);
        vm.startPrank(bob);
        marketplace.buyNFT{value: 1 ether}(tokenId);
        vm.stopPrank();

        assertEq(marketplace.pendingWithdrawals(alice), 1 ether);

        vm.deal(alice, 0);
        assertEq(alice.balance, 0);

        vm.startPrank(alice);
        marketplace.withdraw();
        vm.stopPrank();

        assertEq(alice.balance, 1 ether);
    }
}
