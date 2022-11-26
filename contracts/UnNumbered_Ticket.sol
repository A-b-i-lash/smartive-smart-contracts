// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.8.0;

contract UnNumberedTicket is ERC1155, Pausable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    struct EventCategory {
        uint256 categoryId;
        uint256 price;
        uint256 capacity;
        string name;
        uint256 minted;
    }

    struct EventDetails {
        uint256 startDate;
        string locationName;
        string websiteUrl;
        string eventName;
        uint256 duration;
    }

    EventDetails public eventDetails;
    mapping (uint256 => EventCategory) categories;
    uint256[] public supplies;
    uint256[] categoryList;

    constructor(uint256 startDate_, string memory locationName_, string memory websiteUrl_, string memory eventName_, uint256 duration_) ERC1155("") {
        require(startDate_ > block.timestamp, "You can not set start time of the event to a past date.");
        require(duration_ > 0, "The duration should be greater than 0.");
        eventDetails = EventDetails(
            startDate_,
            locationName_,
            websiteUrl_,
            eventName_,
            duration_
        );
    }

    function getAllCategories() public view returns(uint256[] memory items) {
        return categoryList;
    }

    function getCategoryById(uint256 cateId) private view returns(EventCategory memory item) {
        return categories[cateId];
    }

    function addCategory(uint256 price, uint256 capacity, string memory name) public onlyOwner {
        require(!checkEventPassed(), "Event has already occurred.");
        require(price >= 0, "Price should be greater than or equal to 0.");
        require(capacity > 0, "Capacity should be greater than 0.");
        for(uint256 i=0; i<supplies.length; i++) {
            require(!compareStrings(categories[i].name, name), "There is already a category with the same name.");
        }
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        categories[tokenId] = EventCategory(tokenId, price, capacity, name, 0);
        supplies.push(capacity);
        _mint(msg.sender, tokenId, capacity, "");
        categoryList.push(tokenId);
    }

    function buyTicket(uint256 id, uint256 amount) public payable {
        require(!checkEventPassed(), "Event has already occurred.");
        require(supplies.length > 0, "There is no category to buy ticket");
        require(id <= supplies.length-1 && id >= 0, "Category does not exist.");
        require(categories[id].minted + amount <= supplies[id], "The category has not enough place for the amount you entered.");
        require(msg.value >= (categories[id].price * amount), "You don't have enough price.");
        _safeTransferFrom(owner(), msg.sender, id, amount, "");
        categories[id].minted += amount;
    }

    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function checkEventPassed() private returns (bool) {
        if(block.timestamp >= eventDetails.startDate) {
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