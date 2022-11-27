// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.8.0;

contract CafeMenu is ERC1155, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    enum MenuItemType {BREAKFAST, ENTREE, SALAD, PIZZA, BURGER, PASTA, MEAT, COLDDRINK, HOTDRINK, SPECIAL, CAKE, COOKIE, BISKUIT, PASTRY, CANDY, PUDDING, DEEPFRIED, FROZEN, GELATIN, FRUIT}
    
    struct MenuItem {
        uint256 tokenId;
        uint256 price;
        string name;
        MenuItemType itemType;
        uint256 calories;
        uint256 preparationTime;
        string[] ingredients;
        uint256 soldNumber;
    }

    struct Order {
        uint256 tokenId;
        address orderOwner;
        uint256 amount;
        bool received;
    }

    mapping (uint256 => MenuItem) public menuItems;
    mapping (address => Order) private orders;
    uint256[] public supplies;
    uint256 public lastUpdate;

    constructor() ERC1155("") {
        lastUpdate = block.timestamp;
    }

    function addNewMenuItem(uint256 price, string memory name, uint8 itemType, uint256 calories, uint256 preparationTime,
        string[] memory ingredients, uint256 initialAmount) public onlyOwner {
        require(itemType <= uint8(MenuItemType.FRUIT), "Menu item type is out of range.");
        require(price >= 0, "Price should be greater than or equal to 0.");
        require(calories > 0, "Calories should be greater than 0.");
        require(preparationTime > 0, "Preparation time should be greater than 0.");
        require(ingredients.length > 0, "Ingredients can not be empty.");
        for(uint256 i=0; i<supplies.length; i++) {
            require(!compareStrings(menuItems[i].name, name), "There is already a menu item with the same name.");
        }
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        menuItems[tokenId] = MenuItem(tokenId, price, name, MenuItemType(itemType), calories, preparationTime, ingredients, 0);
        supplies.push(initialAmount);
        _mint(owner(), tokenId, initialAmount, "");
    }

    function getMenu() public view returns(uint256[] memory availableItemList) {
        availableItemList = new uint256[](supplies.length);
        for(uint256 i=0; i<supplies.length; i++) {
            availableItemList[i] = (supplies[i] - menuItems[i].soldNumber);
        }
        return availableItemList;
    }

    function getItemAvailability(uint256 _id) public view returns(uint256 availableNumber) {
        require(_id <= supplies.length - 1, "The item couldn't find.");
        return supplies[_id] - menuItems[_id].soldNumber;
    }

    function getItemSoldNumber(uint256 _id) public view returns(uint256 soldNumber) {
        require(_id <= supplies.length - 1, "The item couldn't find.");
        return menuItems[_id].soldNumber;
    }

    function getItemById(uint256 _id) private view returns(MenuItem memory item) {
        require(_id <= supplies.length - 1, "The item couldn't find.");
        return menuItems[_id];
    }

    function getAddressOrder() private view returns(Order memory order) {
        require(orders[msg.sender].amount > 0, "You don't have any order.");
        return orders[msg.sender];
    }

    function updateItemData(uint256 itemId, uint256 price, string memory name, uint8 itemType, uint256 calories, uint256 preparationTime, string[] memory ingredients) public onlyOwner {
        require(itemType <= uint8(MenuItemType.FRUIT), "Menu item type is out of range.");
        require(price >= 0, "Price should be greater than or equal to 0.");
        require(calories > 0, "Calories should be greater than 0.");
        require(preparationTime > 0, "Preparation time should be greater than 0.");
        require(ingredients.length > 0, "Ingredients can not be empty.");
        require(supplies.length > 0, "There is no item to update.");
        require(itemId <= supplies.length-1 && itemId >= 0, "Menu item does not exist.");
        for(uint256 i=0; i<supplies.length; i++) {
            require(!compareStrings(menuItems[i].name, name), "There is already a menu item with the same name.");
        }
        menuItems[itemId].price = price;
        menuItems[itemId].name = name;
        menuItems[itemId].itemType = MenuItemType(itemType);
        menuItems[itemId].calories = calories;
        menuItems[itemId].preparationTime = preparationTime;
        menuItems[itemId].ingredients = ingredients;
        lastUpdate = block.timestamp;
    }

    function produceItem(uint256 id, uint256 amount) public onlyOwner {
        require(supplies.length > 0, "There is no item to produce.");
        require(id <= supplies.length-1 && id >= 0, "Menu item does not exist.");
        supplies[id] = supplies[id] + amount;
        _mint(owner(), id, amount, "");
        lastUpdate = block.timestamp;
    }

    function buyItem(uint256 id, uint256 amount) public payable {
        require(supplies.length > 0, "There is no item to buy.");
        require(id <= supplies.length-1 && id >= 0, "Menu item does not exist.");
        require(amount > 0, "The amount should be greater than 0.");
        require(supplies[id] - menuItems[id].soldNumber >= amount, "There is no enough produced item.");
        require(msg.value >= (menuItems[id].price * amount), "You don't have enough price.");
        require(orders[msg.sender].amount == 0, "You already have an order to wait for receiving, first get it.");
        _safeTransferFrom(owner(), msg.sender, id, amount, "");
        menuItems[id].soldNumber += amount;
        orders[msg.sender] = Order(id, msg.sender, amount, false);
        lastUpdate = block.timestamp;
    }

    function receiveItem(uint256 id, uint256 amount) public {
        require(supplies.length > 0, "There is no item to receive.");
        require(id <= supplies.length-1 && id >= 0, "Menu item does not exist.");
        require(amount > 0, "The amount should be greater than 0.");
        require(balanceOf(msg.sender, id) >= amount, "You didn't have item with the amount you gave.");
        require(orders[msg.sender].amount > 0, "You don't have any order to receive.");
        orders[msg.sender].received = true;
        _burn(msg.sender, id, amount);
        lastUpdate = block.timestamp;
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