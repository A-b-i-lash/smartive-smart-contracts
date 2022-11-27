// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >= 0.8.0;

contract ProductManagement is ERC1155, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _productTypeCounter;

    struct Product {
        uint256 tokenId;
        uint256 price;
        uint256 productType;
        string name;
        uint256 amountOfSales;
    }

    struct ProductType {
        uint256 productTypeId;
        string productTypeName;
    }

    struct Order {
        uint256 tokenId;
        address orderOwner;
        uint256 amount;
        bool received;
    }

    mapping (uint256 => Product) public products;
    mapping (uint256 => ProductType) public productTypes;
    mapping (address => Order) private orders;
    uint256[] public supplies;
    //uint256[] public productTypeList;
    uint256 public lastUpdate;

    constructor() ERC1155("") {
        lastUpdate = block.timestamp;
    }

    function addNewProduct(uint256 price, uint256 productTypeId, string memory name, uint256 amount) public onlyOwner {
        
        require(price >= 0, "Price must not be a negative number");
        require(productTypeId >= 0 && productTypeId < (_productTypeCounter.current()), "Product type with the given product type id could not be found");
        require(!isEmpty(name), "Name of product must be entered");
        for(uint256 i = 0; i < supplies.length; i++) {
            require(!compareStrings(products[i].name, name), "There is already a product with the same name.");
        }

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        products[tokenId] = Product(tokenId, price, productTypeId, name, 0);
        supplies.push(amount);
        _mint(owner(), tokenId, amount, "");
    }

    function addNewProductType(string memory name) public onlyOwner {
        require(!isEmpty(name), "Name of product type must be entered");
        uint256 tempNumOfProductTypes = _productTypeCounter.current();
        for(uint256 i = 0; i < tempNumOfProductTypes; i++) {
            require(!compareStrings(productTypes[i].productTypeName, name), "There is already a product type with the same name");
        }
        
        productTypes[tempNumOfProductTypes] = ProductType(tempNumOfProductTypes, name);
        _productTypeCounter.increment();
    }

    function getCatalog() public view returns(uint256[] memory availableProductList) {
        availableProductList = new uint256[](supplies.length);
        for(uint256 i = 0; i < supplies.length; i++) {
            availableProductList[i] = (supplies[i] - products[i].amountOfSales);
        }
        return availableProductList;
    }

    function getProductForSaleAmount(uint256 _productId) public view returns(uint256 forSaleAmount){
        require(_productId <= supplies.length - 1, "The product couldn't be found.");
        return supplies[_productId] - products[_productId].amountOfSales;
    }

    function getProductNumberOfSales(uint256 _productId) public view returns(uint256 amountOfSales) {
        require(_productId <= supplies.length - 1, "The product couldn't be found.");
        return products[_productId].amountOfSales;
    }

    function getProductById(uint256 _productId) private view returns(Product memory product) {
        require(_productId <= supplies.length - 1, "The product couldn't be found.");
        return products[_productId];
    }

    function getProductTypeById(uint256 _productTypeId) private view returns(ProductType memory productType) {
        require(_productTypeId >= 0 && _productTypeId < _productTypeCounter.current(), "Product type with the given product type id could not be found");
        return productTypes[_productTypeId];
    }

    function getAddressOrder() private view returns(Order memory order) {
        require(orders[msg.sender].amount > 0, "You don't have any order.");
        return orders[msg.sender];
    }

    function updateProduct(uint256 productId, uint256 price, uint256 productTypeId, string memory name) public onlyOwner {
        
        require(supplies.length > 0, "There is no product to update.");
        require(productId <= supplies.length-1 && productId >= 0, "Product does not exist.");
        require(price >= 0, "Price must not be a negative number");
        require(productTypeId >= 0 && productTypeId < _productTypeCounter.current(), "Product type with the given product type id could not be found");
        require(!isEmpty(name), "Name of product must be entered");
        for(uint256 i = 0; i < supplies.length; i++) {
            require(!compareStrings(products[i].name, name), "There is already a product with the same name.");
        }

        products[productId].price = price;
        products[productId].productType = productTypeId;
        products[productId].name = name;
    }

    function produceProducts(uint256 productId, uint256 amount) public onlyOwner {
        require(supplies.length > 0, "There is no product to produce.");
        require(productId <= supplies.length-1 && productId >= 0, "Product does not exist.");
        supplies[productId] = supplies[productId] + amount;
        _mint(owner(), productId, amount, "");
    }

    function buyProduct(uint256 productId, uint256 amount) public payable {
        require(supplies.length > 0, "There is no product to buy.");
        require(productId <= supplies.length-1 && productId >= 0, "Product does not exist.");
        require(amount > 0, "The amount should be greater than 0.");
        require(supplies[productId] - products[productId].amountOfSales >= amount, "There is no enough produced products.");
        require(msg.value >= (products[productId].price * amount), "You don't have enough balance.");
        require(orders[msg.sender].amount == 0, "You already have an order to wait for receiving, first get it.");
        _safeTransferFrom(owner(), msg.sender, productId, amount, "");
        products[productId].amountOfSales += amount;
        orders[msg.sender] = Order(productId, msg.sender, amount, false);
    }

    function receiveProduct(uint256 productId, uint256 amount) public {
        require(supplies.length > 0, "There is no product to receive.");
        require(productId <= supplies.length-1 && productId >= 0, "Product does not exist.");
        require(amount > 0, "The amount should be greater than 0.");
        require(balanceOf(msg.sender, productId) >= amount, "You didn't have a product with the amount you gave.");
        require(orders[msg.sender].amount > 0, "You don't have any order to receive.");
        orders[msg.sender].received = true;
        _burn(msg.sender, productId, amount);
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
