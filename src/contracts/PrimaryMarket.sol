// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
import "../interfaces/IPrimaryMarket.sol";
import "../interfaces/ITicketNFT.sol";
import "../contracts/TicketNFT.sol";
import "../interfaces/IERC20.sol";

contract PrimaryMarket is IPrimaryMarket{
    IERC20 private _purchaseToken;
    mapping(address => Event) eventList;

    struct Event {
        address creator;
        address ticketNFT;
        string eventName;
        uint256 price;
        uint256 maxNumberOfTickets;
        uint256 currentNumberOfTickers;
    }
    constructor(IERC20 purchaseToken){
        _purchaseToken = purchaseToken;
    }
    /**
     *
     * @param eventName is the name of the event to create
     * @param price is the price of a single ticket for this event
     * @param maxNumberOfTickets is the maximum number of tickets that can be created for this event
     */
    function createNewEvent(
        string memory eventName,
        uint256 price,
        uint256 maxNumberOfTickets
    ) external returns (ITicketNFT ticketCollection){
        TicketNFT newTicketNFT = new TicketNFT(msg.sender,eventName,price,maxNumberOfTickets);
        Event memory newEvent = Event(msg.sender,address(newTicketNFT),eventName,price,maxNumberOfTickets,0); 
        eventList[address(newTicketNFT)] = newEvent;
        emit EventCreated(msg.sender,address(newTicketNFT),eventName,price,maxNumberOfTickets);
        return newTicketNFT;
    }


    /**
     * @notice Allows a user to purchase a ticket from `ticketCollectionNFT`
     * @dev Takes the initial NFT token holder's name as a string input
     * and transfers ERC20 tokens from the purchaser to the creator of the NFT collection
     * @param ticketCollection the collection from which to buy the ticket
     * @param holderName the name of the buyer
     * @return id of the purchased ticket
     */
    function purchase(
        address ticketCollection,
        string memory holderName
    ) external returns (uint256 id){
        Event memory  objectEvent= eventList[ticketCollection];

        require(objectEvent.creator != address(0),"the event shoud exist");
        require(_purchaseToken.balanceOf(msg.sender) >= objectEvent.price);
        require(objectEvent.currentNumberOfTickers < objectEvent.maxNumberOfTickets,"max number of tickets reached");

        _purchaseToken.transferFrom(msg.sender, objectEvent.creator, objectEvent.price);
        uint256 ticketId = ITicketNFT(ticketCollection).mint(msg.sender, holderName);
        eventList[ticketCollection].currentNumberOfTickers +=1;

        emit Purchase(msg.sender, ticketCollection, ticketId, holderName);
        return ticketId;
    }

    /**
     * @param ticketCollection the collection from which to get the price
     * @return price of a ticket for the event associated with `ticketCollection`
     */
    function getPrice(
        address ticketCollection
    ) external view returns (uint256 price){
        return eventList[ticketCollection].price;
    }
}