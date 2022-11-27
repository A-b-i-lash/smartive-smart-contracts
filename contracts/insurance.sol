// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Insurance is ERC20, Ownable{

    using SafeMath for uint256;
    address Owner;
    uint256 maxUsableAmount;
    address payable wallet;
     uint256 insuranceAmount;
     uint256 firstTokenSetPrice;
     uint256 extraTokenPrice;
     uint256  firstTokenSetAmount;
    

    struct  insuranceMember {
        bool validMember;
        address memberAddress;
        uint256  startTime;
        uint256  endTime;
    }
    
   
    mapping(address => insuranceMember) public members;

    constructor(uint256 _firstTokenSetPrice, uint256 _extraTokenPrice, address payable _wallet, uint256 _totalSupply, uint256 _firstTokenSetAmount )
    ERC20("InsuranceToken", "ISK")
    {
        Owner = msg.sender;
        firstTokenSetPrice = _firstTokenSetPrice;
        wallet = _wallet;
        extraTokenPrice = _extraTokenPrice;
        firstTokenSetAmount = _firstTokenSetAmount;
         _mint(msg.sender, _totalSupply);
       
    }
    
   
   

    
    function addInsuranceMember(address _memberAddress) public onlyOwner{
        require(!members[_memberAddress].validMember);
        members[_memberAddress].validMember = true;
        members[_memberAddress].memberAddress = _memberAddress;

       

    }



    function approve(address spender, uint256 amount) public virtual override onlyOwner returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function takeFirstTokenSet( ) payable public {
        require(members[msg.sender].validMember, "You are not member of this insurance");
        require(msg.value >= firstTokenSetPrice, "You should send price of that insurance");
        wallet.transfer(msg.value);
        super.transferFrom(Owner,msg.sender,firstTokenSetAmount);
        
    }
    
    function useInsurenceToken() public
    {
        require(members[msg.sender].validMember, "You are not member of this insurance");
        super.transfer(Owner,1 );
      
    }

    function buyExtraInsuranceToken() payable public {
        require(members[msg.sender].validMember, "You are not member of this insurance");
        require(msg.value >= extraTokenPrice, "You should send price of the extra insurance");
         super.transferFrom(Owner,msg.sender,1);
        wallet.transfer(msg.value);
    }


}

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      assert(b <= a);
      return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }
}



