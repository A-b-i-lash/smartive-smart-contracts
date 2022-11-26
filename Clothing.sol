// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >= 0.8.0;

contract Clothing is ERC1155, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    enum ClothingType {TSHIRT, SHIRT, PANTS, HOODIES, SWEATER, SHORTS, SKIRTS, RAINCOAT, UNDERWEAR, GYMCLOTHES, TANKTOP, PAJAMA, SWIMSUIT, BATHROBE, COAT, SCARF, SUIT, OTHER }
    enum ClothingSize {XXS, XS, S, SM, M, ML, MT, L, LT, XL, XLT, XXL, XXLT, XXXL, XXXLT, XXXXL, XXXXLT, OTHER }
    enum ClothingColor {RED, GREEN, BLACK, WHITE, BLUE, YELLOW, GREY, PURPLE, PINK, ORANGE, BROWN, OTHER }
    
    struct ClothingItem {
        uint256 tokenId;
        uint256 price;
        string name;
        string brand;
        ClothingType clothingType;
        ClothingSize size;
        ClothingColor color;
        uint256 numberOfSales;
    }

    struct Order {
        uint256 tokenId;
        address orderOwner;
        uint256 amount;
        bool received;
    }

    mapping (uint256 => ClothingItem) public clothingItems;
    mapping (address => Order) private orders;
    uint256[] public supplies;
    uint256 public lastUpdate;

    constructor() ERC1155("") {
        lastUpdate = block.timestamp;
    }

    function addNewClothingItem(uint256 price, string memory name, string memory brand, uint8 clothingType, uint8 size,
        uint8 color, uint256 amount) public onlyOwner {
        
        require(clothingType >= uint8(ClothingType.TSHIRT) && clothingType <= uint8(ClothingType.OTHER), "Clothing item type is out of range");
        require(size >= uint8(ClothingSize.XXS) && size <= uint8(ClothingSize.OTHER), "Clothing size is out of range");
        require(color >= uint8(ClothingColor.RED) && color <= uint8(ClothingColor.OTHER), "Clothing color is out of range");
        require(price >= 0, "Price must not be a negative number");
        require(!isEmpty(brand), "Brand name must be entered");
        require(!isEmpty(name), "Name must be entered");
        for(uint256 i = 0; i < supplies.length; i++) {
            require(!compareStrings(clothingItems[i].name, name), "There is already a clothing item with the same name.");
        }

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        clothingItems[tokenId] = ClothingItem(tokenId, price, name, brand, ClothingType(clothingType), ClothingSize(size),
            ClothingColor(color), 0);
        supplies.push(amount);
        _mint(owner(), tokenId, amount, "");
    }

    function getCatalog() public view returns(uint256[] memory availableClothingItemList) {
        availableClothingItemList = new uint256[](supplies.length);
        for(uint256 i = 0; i < supplies.length; i++) {
            availableClothingItemList[i] = (supplies[i] - clothingItems[i].numberOfSales);
        }
        return availableClothingItemList;
    }

    function getClothingItemForSaleAmount(uint256 _clothingItemId) public view returns(uint256 forSaleAmount){
        require(_clothingItemId <= supplies.length - 1, "The clothing item couldn't be found.");
        return supplies[_clothingItemId] - clothingItems[_clothingItemId].numberOfSales;
    }

    function getClothingItemNumberOfSales(uint256 _clothingItemId) public view returns(uint256 numberOfSales) {
        require(_clothingItemId <= supplies.length - 1, "The clothing item couldn't be found.");
        return clothingItems[_clothingItemId].numberOfSales;
    }

    function getClothingItemById(uint256 _clothingItemId) private view returns(ClothingItem memory clothingItem) {
        require(_clothingItemId <= supplies.length - 1, "The clothing item couldn't be found.");
        return clothingItems[_clothingItemId];
    }

    function getAddressOrder() private view returns(Order memory order) {
        require(orders[msg.sender].amount > 0, "You don't have any order.");
        return orders[msg.sender];
    }

    function updateClothingItem(uint256 clothingItemId, uint256 price, string memory name, string memory brand,
        uint8 clothingType, uint8 size, uint8 color) public onlyOwner {
        
        require(clothingType >= uint8(ClothingType.TSHIRT) && clothingType <= uint8(ClothingType.OTHER), "Clothing item type is out of range");
        require(size >= uint8(ClothingSize.XXS) && size <= uint8(ClothingSize.OTHER), "Clothing size is out of range");
        require(color >= uint8(ClothingColor.RED) && color <= uint8(ClothingColor.OTHER), "Clothing color is out of range");
        require(price >= 0, "Price must not be a negative number");
        require(isEmpty(brand), "Brand name must be entered");
        require(isEmpty(name), "Name must be entered");
        require(supplies.length > 0, "There is no clothing item to update.");
        require(clothingItemId <= supplies.length-1 && clothingItemId >= 0, "Clothing item does not exist.");
        for(uint256 i=0; i<supplies.length; i++) {
            require(!compareStrings(clothingItems[i].name, name), "There is already a clothing item with the same name.");
        }

        clothingItems[clothingItemId].price = price;
        clothingItems[clothingItemId].name = name;
        clothingItems[clothingItemId].brand = brand;
        clothingItems[clothingItemId].clothingType = ClothingType(clothingType);
        clothingItems[clothingItemId].size = ClothingSize(size);
        clothingItems[clothingItemId].color = ClothingColor(color);
    }

    function produceClothingItem(uint256 clothingItemId, uint256 amount) public onlyOwner {
        require(supplies.length > 0, "There is no clothing item to produce.");
        require(clothingItemId <= supplies.length-1 && clothingItemId >= 0, "Clothing item does not exist.");
        supplies[clothingItemId] = supplies[clothingItemId] + amount;
        _mint(owner(), clothingItemId, amount, "");
    }

    function buyClothingItem(uint256 clothingItemId, uint256 amount) public payable {
        require(supplies.length > 0, "There is no clothing item to buy.");
        require(clothingItemId <= supplies.length-1 && clothingItemId >= 0, "Clothing item does not exist.");
        require(amount > 0, "The amount should be greater than 0.");
        require(supplies[clothingItemId] - clothingItems[clothingItemId].numberOfSales >= amount, "There is no enough produced clothing items.");
        require(msg.value >= (clothingItems[clothingItemId].price * amount), "You don't have enough balance.");
        require(orders[msg.sender].amount == 0, "You already have an order to wait for receiving, first get it.");
        _safeTransferFrom(owner(), msg.sender, clothingItemId, amount, "");
        clothingItems[clothingItemId].numberOfSales += amount;
        orders[msg.sender] = Order(clothingItemId, msg.sender, amount, false);
    }

    function receiveClothingItem(uint256 clothingId, uint256 amount) public {
        require(supplies.length > 0, "There is no clothing item to receive.");
        require(clothingId <= supplies.length-1 && clothingId >= 0, "Clothing item does not exist.");
        require(amount > 0, "The amount should be greater than 0.");
        require(balanceOf(msg.sender, clothingId) >= amount, "You didn't have a clothing item with the amount you gave.");
        require(orders[msg.sender].amount > 0, "You don't have any order to receive.");
        orders[msg.sender].received = true;
        _burn(msg.sender, clothingId, amount);
    }

    function isEmpty(string memory str) private pure returns (bool) {
        //bytes memory tempStr = bytes(str);
        return (bytes(str).length == 0);
    }

    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "Balance is 0.");
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdraw couldn't be completed.");
    }
}
