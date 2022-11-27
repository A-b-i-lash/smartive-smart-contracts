// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TravelTicket is ERC721, Pausable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _blockIdCounter;
    Counters.Counter private _rowIdCounter;
    Counters.Counter private _columnIdCounter;

    enum VehicleType { PLANE, BUS, TRAIN, OTHER }

    struct SeatRow {
        uint256 rowId;
        uint256 totalCapacity;
        uint256 firstCellId;
        mapping(uint256 => bool) cells;
    }

    struct SeatColumn {
        uint256 columnId;
        uint256 totalCapacity;
        uint256 firstCellId;
        mapping(uint256 => bool) cells;
    }

    struct SeatBlock {
        uint256 blockId;
        uint256 price;
        string name;
        uint256 totalRowNumber;
        uint256 createdRowNumber;
        uint256 totalColumnNumber;
        uint256 createdColumnNumber;
        uint256 capacity;
        mapping(uint256 => SeatRow) seatRows;
        mapping(uint256 => SeatColumn) seatColumns;
    }

    struct EventDetails {
        uint256 startDate;
        uint256 duration;
        string locationFrom;
        string locationTo;
        string eventName;
        VehicleType vehicleType;
    }

    EventDetails public eventDetails;
    mapping (uint256 => SeatBlock) public seatBlocks;
    uint256[] public supplies;

    constructor(uint256 startDate_, uint256 duration_, string memory locationFrom_, string memory locationTo_,
        string memory eventName_, uint8 vehicleType_) ERC721("TravelTicketToken", "TraT") {
        
        require(startDate_ > block.timestamp, "You can not set start time of the match to a past date.");
        require(duration_ > 0, "The duration should be greater than 0.");
        require(vehicleType_ >= uint8(VehicleType.PLANE) && vehicleType_ <= uint8(VehicleType.OTHER), "The vehicle type is out of bounds.");
        require(!isEmpty(locationFrom_), "Departing location must be entered.");
        require(!isEmpty(locationTo_), "Arriving location must be entered.");
        require(!isEmpty(eventName_), "Event name must be entered.");
        eventDetails = EventDetails(
            startDate_,
            duration_,
            locationFrom_,
            locationTo_,
            eventName_,
            VehicleType(vehicleType_)
        );
    }

    function addBlock(uint256 price, string memory name, uint256 totalRowNumber_, uint256 totalColumnNumber_) public onlyOwner {
        require(!checkEventPassed(), "Event has already occurred.");
        require(price >= 0, "Price should be greater than or equal to 0.");
        require(totalRowNumber_ > 0, "The block has to have at least 1 row.");
        require(totalColumnNumber_ > 0, "The block has to have at least 1 column.");
        for(uint256 i=0; i<supplies.length; i++) {
            require(!compareStrings(seatBlocks[i].name, name), "There is already a block with the same name.");
        }
        uint256 blockId = _blockIdCounter.current();
        _blockIdCounter.increment();
        
        seatBlocks[blockId].blockId = blockId;
        seatBlocks[blockId].price = price;
        seatBlocks[blockId].name = name;
        seatBlocks[blockId].totalRowNumber = totalRowNumber_;
        seatBlocks[blockId].capacity = 0;
        supplies.push(0);
    }

    function addBlockRow(uint256 blockId, uint256 capacity_) public onlyOwner {
        require(blockId >= 0, "Block id should be grater than or equal to 0.");
        require(seatBlocks[blockId].totalRowNumber > 0, "There is no block with the given block id.");
        require(seatBlocks[blockId].createdRowNumber < seatBlocks[blockId].totalRowNumber, "This block has maximum rows entered.");
        require(capacity_ > 0, "A row should have more than 0 capacity.");
        uint256 rowId = _rowIdCounter.current();
        _rowIdCounter.increment();
        seatBlocks[blockId].seatRows[rowId].rowId = rowId;
        seatBlocks[blockId].seatRows[rowId].totalCapacity = capacity_;
        for(uint256 k=0; k<capacity_; k++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            if(k==0) {
                seatBlocks[blockId].seatRows[rowId].firstCellId = tokenId;
            }
            seatBlocks[blockId].seatRows[rowId].cells[tokenId] = false;
        }
        seatBlocks[blockId].capacity += capacity_;
        seatBlocks[blockId].createdRowNumber++;
        supplies[blockId] += capacity_;
    }

    function addBlockColumn(uint256 blockId, uint256 capacity_) public onlyOwner {
        require(blockId >= 0, "Block id should be grater than or equal to 0.");
        require(seatBlocks[blockId].totalColumnNumber > 0, "There is no block with the given block id.");
        require(seatBlocks[blockId].createdColumnNumber < seatBlocks[blockId].totalColumnNumber, "This block has maximum columns entered.");
        require(capacity_ > 0, "A column should have more than 0 capacity.");
        uint256 columnId = _columnIdCounter.current();
        _columnIdCounter.increment();
        seatBlocks[blockId].seatColumns[columnId].columnId = columnId;
        seatBlocks[blockId].seatColumns[columnId].totalCapacity = capacity_;
        for(uint256 k=0; k<capacity_; k++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            if(k==0) {
                seatBlocks[blockId].seatColumns[columnId].firstCellId = tokenId;
            }
            seatBlocks[blockId].seatColumns[columnId].cells[tokenId] = false;
        }
        seatBlocks[blockId].capacity += capacity_;
        seatBlocks[blockId].createdColumnNumber++;
        supplies[blockId] += capacity_;
    }

    function buyRowTicket(uint256 blockId, uint256 rowId, uint256 cellId) public payable {
        require(!checkEventPassed(), "Event has already occurred.");
        require(supplies.length > 0, "There is no block to buy ticket");
        require(seatBlocks[blockId].totalRowNumber > 0, "There is no block with the given block id.");
        require(seatBlocks[blockId].seatRows[rowId].totalCapacity > 0, "There is no row with the given row id.");
        require(cellId < seatBlocks[blockId].seatRows[rowId].totalCapacity, "Seat number is the greater than the last seat in this row.");
        require(cellId >= 0, "Seat number is the less than the first seat in this row.");
        uint256 tokenId = cellId + seatBlocks[blockId].seatRows[rowId].firstCellId;
        require(!seatBlocks[blockId].seatRows[rowId].cells[tokenId], "The seat has already sold.");
        require(msg.value >= seatBlocks[blockId].price, "You don't have enough amount.");
        _safeMint(msg.sender, tokenId);
        seatBlocks[blockId].seatRows[rowId].cells[tokenId] = true;
    }

    function buyColumnTicket(uint256 blockId, uint256 columnId, uint256 cellId) public payable {
        require(!checkEventPassed(), "Event has already occurred.");
        require(supplies.length > 0, "There is no block to buy ticket");
        require(seatBlocks[blockId].totalColumnNumber > 0, "There is no block with the given block id.");
        require(seatBlocks[blockId].seatColumns[columnId].totalCapacity > 0, "There is no column with the given column id.");
        require(cellId < seatBlocks[blockId].seatColumns[columnId].totalCapacity, "Seat number is the greater than the last seat in this column.");
        require(cellId >= 0, "Seat number is the less than the first seat in this column.");
        uint256 tokenId = cellId + seatBlocks[blockId].seatColumns[columnId].firstCellId;
        require(!seatBlocks[blockId].seatColumns[columnId].cells[tokenId], "The seat has already sold.");
        require(msg.value >= seatBlocks[blockId].price, "You don't have enough amount.");
        _safeMint(msg.sender, tokenId);
        seatBlocks[blockId].seatColumns[columnId].cells[tokenId] = true;
    }

    function isEmpty(string memory str) private pure returns (bool) {
        return (bytes(str).length == 0);
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
