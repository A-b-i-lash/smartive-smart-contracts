// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >= 0.8.0;

contract GameObject is ERC1155, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    enum ItemType { CHARACTER, CLOTHING, COLLECTIBLE, SKIN, WEAPON, OTHER }
    enum Rareness { COMMON, RARE, SUPERRARE, LEGENDARY, UNIQUE, OTHER }

    struct GameItem {
        uint256 tokenId;
        uint256 price;
        uint256 gameId;
        string name;
        ItemType itemType;
        Rareness rareness;
        uint256 numberOfSales;
    }

    struct Game {
        uint256 tokenId;
        string gameName;
    }

    struct Order {
        uint256 tokenId;
        address orderOwner;
        uint256 amount;
        bool received;
    }

    mapping (uint256 => GameItem) public gameItems;
    mapping (uint256 => Game) public games;
    mapping (address => Order) private orders;
    uint256[] public supplies;
    uint256[] public gameList;
    uint256 public lastUpdate;

    constructor() ERC1155("") {
        lastUpdate = block.timestamp;
    }

    function addNewGameItem(uint256 price, uint256 gameId, string memory name, uint8 itemType, uint8 rareness,
        uint256 amount) public onlyOwner {
        
        require(itemType >= uint8(ItemType.CHARACTER) && itemType <= uint8(ItemType.OTHER), "Type of game item is out of range");
        require(rareness >= uint8(Rareness.COMMON) && rareness <= uint8(Rareness.OTHER), "Rareness of game item is out of range");
        require(price >= 0, "Price must not be a negative number");
        require(gameId >= 0 && gameId < gameList.length, "Game with the given gameId could not be found");
        require(!isEmpty(name), "Name of game item must be entered");
        for(uint256 i = 0; i < supplies.length; i++) {
            require(!compareStrings(gameItems[i].name, name), "There is already a game item with the same name.");
        }

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        gameItems[tokenId] = GameItem(tokenId, price, gameId, name, ItemType(itemType), Rareness(rareness), 0);
        supplies.push(amount);
        _mint(owner(), tokenId, amount, "");
    }

    function addNewGame(string memory name) public onlyOwner {
        require(!isEmpty(name), "Name of game must be entered");
        for(uint256 i = 0; i < gameList.length; i++) {
            require(!compareStrings(games[i].gameName, name), "There is already a game with the same name");
        }
        uint256 tempGameId = gameList.length;
        games[tempGameId] = Game(tempGameId, name);
        gameList.push(tempGameId);
    }

    function getCatalog() public view returns(uint256[] memory availableGameItemList) {
        availableGameItemList = new uint256[](supplies.length);
        for(uint256 i = 0; i < supplies.length; i++) {
            availableGameItemList[i] = (supplies[i] - gameItems[i].numberOfSales);
        }
        return availableGameItemList;
    }

    function getGameItemForSaleAmount(uint256 _gameItemId) public view returns(uint256 forSaleAmount){
        require(_gameItemId <= supplies.length - 1, "The game item couldn't be found.");
        return supplies[_gameItemId] - gameItems[_gameItemId].numberOfSales;
    }

    function getGameItemNumberOfSales(uint256 _gameItemId) public view returns(uint256 numberOfSales) {
        require(_gameItemId <= supplies.length - 1, "The game item couldn't be found.");
        return gameItems[_gameItemId].numberOfSales;
    }

    function getGameItemById(uint256 _gameItemId) private view returns(GameItem memory gameItem) {
        require(_gameItemId <= supplies.length - 1, "The game item couldn't be found.");
        return gameItems[_gameItemId];
    }

    function getGameById(uint256 _gameId) private view returns(Game memory game) {
        require(_gameId >= 0 && _gameId < gameList.length, "Game with the given gameId could not be found");
        return games[_gameId];
    }

    function getAddressOrder() private view returns(Order memory order) {
        require(orders[msg.sender].amount > 0, "You don't have any order.");
        return orders[msg.sender];
    }

    function updateGameItem(uint256 gameItemId, uint256 price, uint256 gameId, string memory name, uint8 itemType, 
        uint8 rareness) public onlyOwner {
        
        require(supplies.length > 0, "There is no game item to update.");
        require(gameItemId <= supplies.length-1 && gameItemId >= 0, "Game item does not exist.");
        require(itemType >= uint8(ItemType.CHARACTER) && itemType <= uint8(ItemType.OTHER), "Type of game item is out of range");
        require(rareness >= uint8(Rareness.COMMON) && rareness <= uint8(Rareness.OTHER), "Rareness of game item is out of range");
        require(price >= 0, "Price must not be a negative number");
       require(gameId >= 0 && gameId < gameList.length, "Game with the given gameId could not be found");
        require(!isEmpty(name), "Name of game item must be entered");
        for(uint256 i = 0; i < supplies.length; i++) {
            require(!compareStrings(gameItems[i].name, name), "There is already a game item with the same name.");
        }

        gameItems[gameItemId].price = price;
        gameItems[gameItemId].gameId = gameId;
        gameItems[gameItemId].name = name;
        gameItems[gameItemId].itemType = ItemType(itemType);
        gameItems[gameItemId].rareness = Rareness(rareness);
    }

    function produceGameItem(uint256 gameItemId, uint256 amount) public onlyOwner {
        require(supplies.length > 0, "There is no game item to produce.");
        require(gameItemId <= supplies.length-1 && gameItemId >= 0, "Game item does not exist.");
        supplies[gameItemId] = supplies[gameItemId] + amount;
        _mint(owner(), gameItemId, amount, "");
    }

    function buyGameItem(uint256 gameItemId, uint256 amount) public payable {
        require(supplies.length > 0, "There is no game item to buy.");
        require(gameItemId <= supplies.length-1 && gameItemId >= 0, "Game item does not exist.");
        require(amount > 0, "The amount should be greater than 0.");
        require(supplies[gameItemId] - gameItems[gameItemId].numberOfSales >= amount, "There is no enough produced game items.");
        require(msg.value >= (gameItems[gameItemId].price * amount), "You don't have enough balance.");
        require(orders[msg.sender].amount == 0, "You already have an order to wait for receiving, first get it.");
        _safeTransferFrom(owner(), msg.sender, gameItemId, amount, "");
        gameItems[gameItemId].numberOfSales += amount;
        orders[msg.sender] = Order(gameItemId, msg.sender, amount, false);
    }

    function receiveGameItem(uint256 gameItemId, uint256 amount) public {
        require(supplies.length > 0, "There is no game item to receive.");
        require(gameItemId <= supplies.length-1 && gameItemId >= 0, "Game item does not exist.");
        require(amount > 0, "The amount should be greater than 0.");
        require(balanceOf(msg.sender, gameItemId) >= amount, "You didn't have a game item with the amount you gave.");
        require(orders[msg.sender].amount > 0, "You don't have any order to receive.");
        orders[msg.sender].received = true;
        _burn(msg.sender, gameItemId, amount);
    }

    function isEmpty(string memory str) private pure returns (bool) {
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
