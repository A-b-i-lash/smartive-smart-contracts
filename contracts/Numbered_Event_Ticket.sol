// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.8.0;

contract EventTicket is ERC721, Pausable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _blockIdCounter;
    Counters.Counter private _rowIdCounter;

    struct SeatRow {
        uint256 rowId;
        uint256 totalCapacity;
        uint256 firstCellId;
        mapping(uint256 => bool) cells;
    }

    struct SeatBlock {
        uint256 blockId;
        uint256 price;
        string name;
        uint256 totalRowNumber;
        uint256 capacity;
        mapping(uint256 => SeatRow) seatRows;
    }

    struct EventDetails {
        uint256 startDate;
        string locationName;
        string websiteUrl;
        string eventName;
        uint256 duration;
    }

    EventDetails public eventDetails;
    mapping (uint256 => SeatBlock) seatBlocks;
    uint256[] supplies;

    constructor(uint256 startDate_, string memory locationName_, string memory websiteUrl_, string memory eventName_, uint256 duration_) ERC721("EventTicketToken", "EveT") {
        require(startDate_ > block.timestamp, "You can not set start time of the match to a past date.");
        require(duration_ > 0, "The duration should be greater than 0.");
        eventDetails = EventDetails(
            startDate_,
            locationName_,
            websiteUrl_,
            eventName_,
            duration_
        );
    }

    function addBlock(uint256 price, string memory name, uint256[] memory rowCapacities_) public onlyOwner {
        require(!checkEventPassed(), "Event has already occurred.");
        require(price >= 0, "Price should be greater than or equal to 0.");
        require(rowCapacities_.length > 0, "The block has to have at least 1 row.");
        for(uint256 i=0; i<supplies.length; i++) {
            require(!compareStrings(seatBlocks[i].name, name), "There is already a block with the same name.");
        }
        uint256 blockId = _blockIdCounter.current();
        _blockIdCounter.increment();
        SeatBlock storage newSeatBlock = seatBlocks[blockId];
        newSeatBlock.blockId = blockId;
        newSeatBlock.price = price;
        newSeatBlock.name = name;
        newSeatBlock.totalRowNumber = rowCapacities_.length;

        uint256 blockCapacity = 0;
        for(uint256 i=0; i<rowCapacities_.length; i++) {
            blockCapacity += rowCapacities_[i];
            require(blockCapacity > 0, "A row should have more than 0 capacity.");
            uint256 rowId = _rowIdCounter.current();
            _rowIdCounter.increment();
            seatBlocks[blockId].seatRows[rowId].rowId = rowId;
            seatBlocks[blockId].seatRows[rowId].totalCapacity = rowCapacities_[i];
            for(uint256 k=0; k<rowCapacities_[i]; k++) {
                uint256 tokenId = _tokenIdCounter.current();
                _tokenIdCounter.increment();
                if(k==0) {
                    seatBlocks[blockId].seatRows[rowId].firstCellId = tokenId;
                }
                seatBlocks[blockId].seatRows[rowId].cells[tokenId] = false;
            }
        }

        seatBlocks[blockId].capacity = blockCapacity;
        supplies.push(blockCapacity);
    }

    function buyTicket(uint256 blockId, uint256 rowId, uint256 cellId) public payable {
        require(!checkEventPassed(), "Event has already occurred.");
        require(supplies.length > 0, "There is no block to buy ticket");
        require(seatBlocks[blockId].capacity > 0, "There is no block with the given block id.");
        require(seatBlocks[blockId].seatRows[rowId].totalCapacity > 0, "There is no row with the given row id.");
        require(cellId < seatBlocks[blockId].seatRows[rowId].totalCapacity, "Seat number is the greater than the last seat in this row.");
        require(cellId >= 0, "Seat number is the less than the first seat in this row.");
        uint256 tokenId = cellId + seatBlocks[blockId].seatRows[rowId].firstCellId;
        require(!seatBlocks[blockId].seatRows[rowId].cells[tokenId], "The seat has already sold.");
        require(msg.value >= seatBlocks[blockId].price, "You don't have enough price.");
        _safeMint(msg.sender, tokenId);
        seatBlocks[blockId].seatRows[rowId].cells[tokenId] = true;
    }

    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override {
        require(!checkEventPassed(), "Event has already occurred.");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function checkEventPassed() private returns (bool) {
        if(block.timestamp >= eventDetails.startDate) {
            _pause();
            return true;
        }
        return false;
    }

    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "Balance is 0.");
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdraw couldn't be completed.");
    }
}