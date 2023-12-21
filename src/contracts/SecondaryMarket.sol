// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
import "../interfaces/ISecondaryMarket.sol";
import "../interfaces/ITicketNFT.sol";
import "../interfaces/IPrimaryMarket.sol";
import "../interfaces/IERC20.sol";

contract SecondaryMarket is ISecondaryMarket{
    IERC20 private _purchaseToken;
    

    struct _ticket {
        address owner;
        uint256 price;
        bool active;
    }

    struct _bid{
        address sender;
        string name;
        uint256 price;
    }

    mapping(address => mapping(uint256 => _ticket)) public ticketList;
    mapping(address => mapping (uint256=> _bid)) public ticketBidList;

    constructor(IERC20 purchaseToken){
        _purchaseToken = purchaseToken;
    }

    

    /**
     * @dev This method lists a ticket with `ticketID` for sale by transferring the ticket
     * such that it is held by this contract. Only the current owner of a specific
     * ticket is able to list that ticket on the secondary market. The purchase
     * `price` is specified in an amount of `PurchaseToken`.
     * Note: Only non-expired and unused tickets can be listed
     */
    function listTicket(
        address ticketCollection,
        uint256 ticketID,
        uint256 price
    ) external{
        ITicketNFT ticket = ITicketNFT(ticketCollection);
        require(ticket.holderOf(ticketID) == msg.sender
            && !ticket.isExpiredOrUsed(ticketID));
        ticket.transferFrom(msg.sender, address(this), ticketID);
        ticketList[ticketCollection][ticketID] = _ticket(msg.sender, price, true);

        emit Listing(msg.sender, ticketCollection, ticketID, price);
    }


    /** @notice This method allows the msg.sender to submit a bid for the ticket from `ticketCollection` with `ticketID`
     * The `bidAmount` should be kept in escrow by the contract until the bid is accepted, a higher bid is made,
     * or the ticket is delisted.
     * If this is not the first bid for this ticket, `bidAmount` must be strictly higher that the previous bid.
     * `name` gives the new name that should be stated on the ticket when it is purchased.
     * Note: Bid can only be made on non-expired and unused tickets
     */
    function submitBid(
        address ticketCollection,
        uint256 ticketID,
        uint256 bidAmount,
        string calldata name
    ) external{
        _ticket memory ticket = ticketList[ticketCollection][ticketID];
        ITicketNFT ticketObj = ITicketNFT(ticketCollection);
        require(!ticketObj.isExpiredOrUsed(ticketID));
        require(ticket.active);
        require(bidAmount >= ticket.price);
        require(_purchaseToken.balanceOf(msg.sender) >= bidAmount);
        _bid memory lastBid = ticketBidList[ticketCollection][ticketID];
        if (lastBid.sender != address(0)){
            require(bidAmount > lastBid.price);
            //send back escrow to last bider when higher bid is made
            _purchaseToken.transfer(lastBid.sender, bidAmount);
        }
        //keep in escrow
        _purchaseToken.transferFrom(msg.sender, address(this), bidAmount);

        ticketBidList[ticketCollection][ticketID] = _bid(msg.sender,name,bidAmount);

        emit BidSubmitted(
            msg.sender,
            ticketCollection,
            ticketID,
            bidAmount,
            name
        );
    }

    /**
     * Returns the current highest bid for the ticket from `ticketCollection` with `ticketID`
     */
    function getHighestBid(
        address ticketCollection,
        uint256 ticketId
    ) external view returns (uint256){
        _bid memory bid = ticketBidList[ticketCollection][ticketId];
        _ticket memory ticket = ticketList[ticketCollection][ticketId];
        if (bid.price >= ticket.price){
            return ticketBidList[ticketCollection][ticketId].price;
        }
        return ticketList[ticketCollection][ticketId].price;
    }
    
    /**
     * Returns the current highest bidder for the ticket from `ticketCollection` with `ticketID`
     */
    function getHighestBidder(
        address ticketCollection,
        uint256 ticketId
    ) external view returns (address){
        return ticketBidList[ticketCollection][ticketId].sender;
    }

    /*
     * @notice Allow the lister of the ticket from `ticketCollection` with `ticketID` to accept the current highest bid.
     * This function reverts if there is currently no bid.
     * Otherwise, it should accept the highest bid, transfer the money to the lister of the ticket,
     * and transfer the ticket to the highest bidder after having set the ticket holder name appropriately.
     * A fee charged when the bid is accepted. The fee is charged on the bid amount.
     * The final amount that the lister of the ticket receives is the price
     * minus the fee. The fee should go to the creator of the `ticketCollection`.
     */
    function acceptBid(address ticketCollection, uint256 ticketID) external{
        require(ticketList[ticketCollection][ticketID].active
            && ticketBidList[ticketCollection][ticketID].sender != address(0)
            && msg.sender == ticketList[ticketCollection][ticketID].owner);

        _ticket memory ticket = ticketList[ticketCollection][ticketID];
        _bid memory bid = ticketBidList[ticketCollection][ticketID];
        ITicketNFT ticketObj = ITicketNFT(ticketCollection);
        
        require(!ticketObj.isExpiredOrUsed(ticketID));

        ticketObj.updateHolderName(ticketID,bid.name);
        ticketObj.transferFrom(address(this),bid.sender,ticketID);

        uint256 toLister = (bid.price * 95)/100;
        uint256 toCreator = bid.price - toLister;
        
        _purchaseToken.transfer(ticketObj.creator(), toCreator);
        _purchaseToken.transfer(ticket.owner, toLister);

        delete ticketList[ticketCollection][ticketID];
        delete ticketBidList[ticketCollection][ticketID];

        emit BidAccepted(
            bid.sender,
            ticketCollection,
            ticketID,
            bid.price,
            bid.name
        );
    }

    /** @notice This method delists a previously listed ticket of `ticketCollection` with `ticketID`. Only the account that
     * listed the ticket may delist the ticket. The ticket should be transferred back
     * to msg.sender, i.e., the lister, and escrowed bid funds should be return to the bidder, if any.
     */
    function delistTicket(address ticketCollection, uint256 ticketID) external{
        require(ticketList[ticketCollection][ticketID].active
            && msg.sender == ticketList[ticketCollection][ticketID].owner);

        ITicketNFT ticketObj = ITicketNFT(ticketCollection);
        ticketObj.transferFrom(address(this),msg.sender,ticketID);
        _bid memory bid = ticketBidList[ticketCollection][ticketID];
        if (bid.sender != address(0)){
            _purchaseToken.transfer(bid.sender, bid.price);
        }
        delete ticketList[ticketCollection][ticketID];
        delete ticketBidList[ticketCollection][ticketID];

        emit Delisting(ticketCollection, ticketID);
    }

}