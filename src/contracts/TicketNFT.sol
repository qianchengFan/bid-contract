// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
import "../interfaces/ITicketNFT.sol";
import "../interfaces/IPrimaryMarket.sol";

contract TicketNFT is ITicketNFT{
    uint256 nextTicketID = 0;
    mapping(uint256 => address) private ticketHolderAddress;
    mapping(uint256 => string) private ticketHolderName;
    // mapping(uint256 => string) private ticketName;
    mapping(uint256 => uint) private ticketExpiryTime;
    mapping(address => uint256[]) private ownedTicket;
    mapping(uint256 => address) private _approved;
    mapping(uint256 => bool) private _used;
    address private PMarket;
    address private Creator;
    string _eventName;
    uint256 _price;
    uint256 _totalNum;
    
    constructor(address Sender,string memory newEventName, uint256 price,uint256 totalNum){
        Creator = Sender;
        PMarket = msg.sender;
        _eventName = newEventName;
        _price = price;
        _totalNum = totalNum;
    }



        /**
     * @dev Returns the address of the user who created the NFT collection
     * This is the address of the user who called `createNewEvent` in the primary market
     */
    function creator() external view returns (address){
        return address(Creator);
    }

    /**
     * @dev Returns the maximum number of tickets that can be minted for this event.
     */
    function maxNumberOfTickets() external view returns (uint256){
        return _totalNum;
    }

	/**
     * @dev Returns the name of the event for this TicketNFT
     */
    function eventName() external view returns (string memory){
        return _eventName;
    }

     /**
     * Mints a new ticket for `holder` with `holderName`.
     * The ticket must be assigned the following metadata:
     * - A unique ticket ID. Once a ticket has been used or expired, its ID should not be reallocated
     * - An expiry time of 10 days from the time of minting
     * - A boolean `used` flag set to false
     * On minting, a `Transfer` event should be emitted with `from` set to the zero address.
     *
     * Requirements:
     *
     * - The caller must be the primary market
     */
    function mint(address holder, string memory holderName) external returns (uint256 id){
        require(msg.sender == address(PMarket));
        uint256 ticketID = nextTicketID;
        nextTicketID += 1;
        uint expiryTime = block.timestamp + 10 days;
        ticketHolderAddress[ticketID] = holder;
        ticketHolderName[ticketID] = holderName;
        // ticketName[ticketID] = "default";
        ticketExpiryTime[ticketID] = expiryTime;
        _used[ticketID] = false;
        ownedTicket[holder].push(ticketID);
        emit Transfer(address(0),holder,ticketID);
        return ticketID;
    }

    /**
     * @dev Returns the number of tickets a `holder` has.
     */
    function balanceOf(address holder) external view returns (uint256 balance){
        return ownedTicket[holder].length;
    }


    /**
     * @dev Returns the address of the holder of the `ticketID` ticket.
     *
     * Requirements:
     *
     * - `ticketID` must exist.
     */
    function holderOf(uint256 ticketID) external view returns (address holder){
        require(ticketHolderAddress[ticketID] != address(0));
        return ticketHolderAddress[ticketID];
    }

        /**
     * @dev Transfers `ticketID` ticket from `from` to `to`.
     * This should also set the approved address for this ticket to the zero address
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - the caller must either:
     *   - own `ticketID`
     *   - be approved to move this ticket using `approve`
     *
     * Emits a `Transfer` and an `Approval` event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 ticketID
    ) external{
        require(from != address(0) && to != address(0));
        require(ticketHolderAddress[ticketID] == from);
        require(_approved[ticketID]==msg.sender || ticketHolderAddress[ticketID] == msg.sender);
        _approved[ticketID] = address(0);
        ticketHolderAddress[ticketID] = to;
        removeTicket(from,ticketID);
        ownedTicket[to].push(ticketID);
        emit Transfer(from,to,ticketID);
        emit Approval(from,address(0),ticketID);
    }

    // function addressListContains(address[] memory list, address toCheck) internal returns(bool contains){
    //     for (uint256 i = 0;i<list.length-1;i++){
    //         if(list[i]==toCheck){
    //             return true;
    //         }
    //     }
    //     return false;
    // }

    function removeTicket(address from, uint256 ticketID) internal {
        for (uint256 i = 0; i<= ownedTicket[from].length-1;i++){
            if(ownedTicket[from][i] == ticketID){
                //swap this with last element
                ownedTicket[from][i] = ownedTicket[from][ownedTicket[from].length-1];
                ownedTicket[from].pop();
                return;
            }
        }
    }

        /**
     * @dev Gives permission to `to` to transfer `ticketID` ticket to another account.
     * The approval is cleared when the ticket is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the ticket
     * - `ticketID` must exist.
     *
     * Emits an `Approval` event.
     */
    function approve(address to, uint256 ticketID) external{

        require(ticketHolderAddress[ticketID] != address(0),"the ticket not exist");
        require(ticketHolderAddress[ticketID] == msg.sender,"only ticket holder can call approve");
        _approved[ticketID] = to;
        emit Approval(msg.sender,to,ticketID);
    }

    /**
     * @dev Returns the account approved for `ticketID` ticket.
     *
     * Requirements:
     *
     * - `ticketID` must exist.
     */
    function getApproved(uint256 ticketID)
        external
        view
        returns (address operator){
            require(ticketHolderAddress[ticketID]!=address(0));
            return _approved[ticketID];
        }
    
    /**
     * @dev Returns the current `holderName` associated with a `ticketID`.
     * Requirements:
     *
     * - `ticketID` must exist.
     */
    function holderNameOf(uint256 ticketID)
        external
        view
        returns (string memory holderName){
            require(ticketHolderAddress[ticketID]!=address(0));
            return ticketHolderName[ticketID];
        }

    
    /**
     * @dev Updates the `holderName` associated with a `ticketID`.
     * Note that this does not update the actual holder of the ticket.
     *
     * Requirements:
     *
     * - `ticketID` must exists
     * - Only the current holder can call this function
     */
    function updateHolderName(uint256 ticketID, string calldata newName)
        external{
            require(ticketHolderAddress[ticketID]!=address(0)
                && ticketHolderAddress[ticketID] == msg.sender);
            ticketHolderName[ticketID] = newName;
        }
    
    /**
     * @dev Sets the `used` flag associated with a `ticketID` to `true`
     *
     * Requirements:
     *
     * - `ticketID` must exist
     * - the ticket must not already be used
     * - the ticket must not be expired
     * - Only the creator of the collection can call this function
     */
    function setUsed(uint256 ticketID) external{
        require(ticketHolderAddress[ticketID]!=address(0));
        require(_used[ticketID] != true);
        require(ticketExpiryTime[ticketID] > block.timestamp);
        require(msg.sender == Creator);
        _used[ticketID] = true;
    }

    
    /**
     * @dev Returns `true` if the `used` flag associated with a `ticketID` if `true`
     * or if the ticket has expired, i.e., the current time is greater than the ticket's
     * `expiryDate`.
     * Requirements:
     *
     * - `ticketID` must exist
     */
    function isExpiredOrUsed(uint256 ticketID) external view returns (bool){
        require(ticketHolderAddress[ticketID]!=address(0));
        if (ticketExpiryTime[ticketID] < block.timestamp
            || _used[ticketID]){
                return true;
            }
        return false;
    }
}