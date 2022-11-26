// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.8.0;

contract StadiumTicket is ERC1155, Pausable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    enum BlockDirection {NORTH, EAST, SOUTH, WEST}

    struct StadiumCategory {
        uint256 categoryId;
        uint256 price;
        BlockDirection direction;
        uint256 capacity;
        string name;
        uint256 transferred;
    }

    struct MatchEvent {
        string homeTeam;
        string awayTeam;
        uint256 startDate;
    }

    MatchEvent public matchEvent;
    mapping (uint256 => StadiumCategory) private categories;
    uint256[] public supplies;
    uint256[] public categoryList;

    constructor(string memory homeTeam_, string memory awayTeam_, uint256 startDate_) ERC1155("") {
        require(!compareStrings(homeTeam_, awayTeam_), "The home and away team can not be the same team.");
        require(startDate_ > block.timestamp, "You can not set start time of the match to a past date.");
        matchEvent = MatchEvent({
            homeTeam: homeTeam_,
            awayTeam: awayTeam_,
            startDate: startDate_
        });
    }

    function getAllCategories() public view returns(uint256[] memory items) {
        return categoryList;
    }

    function getCategoryById(uint256 cateId) private view returns(StadiumCategory memory item) {
        return categories[cateId];
    }

    function addCategory(uint256 price, uint8 direction, uint256 capacity, string memory name) public onlyOwner {
        require(!checkEventPassed(), "Event has already occurred.");
        require(direction <= uint8(BlockDirection.WEST), "Direction is out of range.");
        require(price >= 0, "Price should be greater than or equal to 0.");
        require(capacity > 0, "Capacity should be greater than 0.");
        for(uint256 i=0; i<supplies.length; i++) {
            require(!compareStrings(categories[i].name, name), "There is already a category with the same name.");
        }
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        categories[tokenId] = StadiumCategory(tokenId, price, BlockDirection(direction), capacity, name, 0);
        supplies.push(capacity);
        _mint(msg.sender, tokenId, capacity, "");
        categoryList.push(tokenId);
    }

    function buyTicket(uint256 id, uint256 amount) public payable {
        require(!checkEventPassed(), "Event has already occurred.");
        require(supplies.length > 0, "There is no category to buy ticket");
        require(id <= supplies.length-1 && id >= 0, "Category does not exist.");
        require(categories[id].transferred + amount <= supplies[id], "The category has not enough place for the amount you entered.");
        require(msg.value >= (categories[id].price * amount), "You don't have enough price.");
        _safeTransferFrom(owner(), msg.sender, id, amount, "");
        categories[id].transferred += amount;
    }

    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function checkEventPassed() private returns (bool) {
        if(block.timestamp >= matchEvent.startDate) {
            _pause();
            return true;
        }
        return false;
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)        
        internal
        whenNotPaused
        override {
        require(!checkEventPassed(), "Event has already occurred.");
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "Balance is 0.");
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdraw couldn't be completed.");
    }
}