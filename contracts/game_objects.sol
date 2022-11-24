// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract GameObject {
    
    struct Item {
        uint256 id;
        string itemName;
        string gameName;
        uint256 price;
        ItemType itemType;
        ItemStatus itemStatus;
        address seller;
        address buyer;
    }

    enum ItemType {Clothing, Character, Collectible, Skin, Weapon}
    enum ItemStatus {ForSale, NotForSale}

    address public owner;
    mapping(address => uint256[]) private userItems; 
    mapping(uint256 => Item) items;
    uint256[] itemList;

    constructor() public {
        owner = msg.sender;
        itemCounter = 0;
    }

    uint256 itemCounter;
    function getItemId() private returns(uint) { return ++itemCounter; }

    function isEmpty(string memory _str) pure private returns(bool _isEmpty) {
        bytes memory tempStr = bytes(_str);
        return tempStr.length == 0;
    }

    function createItem(string memory _itemName, string memory _gameName, uint256 _price, string memory _itemType) public returns(bool success) {
        require(!isEmpty(_itemName), "Item name must not be empty");
        require(!isEmpty(_gameName), "Game name must not be empty");
        require(_price >= 0, "Price must not be a negative number");
        require(!isEmpty(_itemType), "Item type must not be empty");
        require(msg.sender == owner, "Only owner can add new items");
        uint256 itemId = getItemId();
        Item memory item = items[itemId];
        item.id = itemId;
        item.itemName = _itemName;
        item.gameName = _gameName;
        item.price = _price;
        if(keccak256(bytes(_itemType)) == keccak256(bytes("Clothing"))) {
            item.itemType = ItemType.Clothing;
        } else if(keccak256(bytes(_itemType)) == keccak256(bytes("Character"))) {
            item.itemType = ItemType.Character;
        } else if(keccak256(bytes(_itemType)) == keccak256(bytes("Collectible"))) {
            item.itemType = ItemType.Collectible;
        } else if(keccak256(bytes(_itemType)) == keccak256(bytes("Skin"))) {
            item.itemType = ItemType.Skin;
        } else if(keccak256(bytes(_itemType)) == keccak256(bytes("Weapon"))) {
            item.itemType = GameObject.ItemType.Weapon;
        }
        item.itemStatus = GameObject.ItemStatus.ForSale;
        item.seller = msg.sender;
        items[itemId] = item;
        itemList.push(itemId);
        return true;
    }

    function getAllItemList() public view returns(uint256[] memory _items) {
        return itemList;
    }

    function getItemById(uint256 _id) private view returns(Item memory item) {
        return items[_id];
    }

    function getItemStrById(uint256 _id) public view returns(uint256 id, string memory itemName, string memory gameName, uint256 price, string memory itemType, string memory itemStatus, address seller, address buyer) {
        Item memory item = items[_id];
        string memory tempItemType;
        if(item.itemType == ItemType.Clothing) {
            tempItemType = "Clothing";
        } else if(item.itemType == ItemType.Character) {
            tempItemType = "Character";
        } else if(item.itemType == ItemType.Collectible) {
            tempItemType = "Collectible";
        } else if(item.itemType == ItemType.Skin) {
            tempItemType = "Skin";
        } else if(item.itemType == ItemType.Weapon) {
            tempItemType = "Weapon";
        }

        string memory tempItemStatus;
        if(item.itemStatus == ItemStatus.ForSale) {
            tempItemStatus = "For Sale";
        } else if(item.itemStatus == ItemStatus.NotForSale) {
            tempItemStatus = "Not For Sale";
        }
        return (item.id, item.itemName, item.gameName, item.price, tempItemType, tempItemStatus, item.seller, item.buyer);
    }

    function getMyItem() public view returns(uint256[] memory item) {
        return userItems[msg.sender];
    }

    function buyItem(uint256 _itemId) public payable returns(bool success) {
        Item memory item = getItemById(_itemId);
        if(item.itemStatus == ItemStatus.NotForSale) {
            payable(msg.sender).transfer(msg.value);
            return false;
        }
        if(msg.value <= item.price) {
           payable(msg.sender).transfer(msg.value);
            return false;
        }
        item.buyer = msg.sender;
        item.itemStatus = ItemStatus.NotForSale;
        items[_itemId] = item;
        userItems[msg.sender].push(item.id);
        return true;
    }

}
