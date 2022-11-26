// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity >=0.8.0;

contract WeightedMultipleVoting is ERC20, Pausable, Ownable {
    struct Candidate {
        string name;
        uint256 voteCount;
    }

    struct Voter {
        uint256 weight;
        address voterAddress;
        uint256[] voteIndexes;
        address delegate;
    }

    Candidate[] public candidates;
    mapping(address => Voter) public voters;
    uint256 public maxAllowedVotes;
    uint256 constant public votePrice = 0.001 ether;
    uint256 public startTime;
    uint256 public endTime;

    constructor(string[] memory candidateNames, uint256 maxVotes, uint256 ownerWeight, uint256 startTime_, uint256 endTime_)
    ERC20("WeightedToken", "WeTo")    
    {
        voters[msg.sender].voterAddress = msg.sender;
        voters[msg.sender].weight = ownerWeight;
        _mint(msg.sender, maxVotes);
        for(uint i=0; i<candidateNames.length; i++) {
            require(!(checkDuplicate(candidateNames, candidateNames[i])), "You can not create more than one with the same name.");
            candidates.push(Candidate({
                name: candidateNames[i],
                voteCount: 0
            }));
        }
        maxAllowedVotes = maxVotes > 0 ? maxVotes : 1;
        require(startTime_ > block.timestamp, "You can not set start time to past.");
        require(endTime_ > startTime, "You can not set start time after the end time.");
        startTime = startTime_;
        endTime = endTime_;
    }

    function getAllCandidates() public view returns (Candidate[] memory) {
        return candidates;
    }

    function addVoter(address voterAddress, uint256 weight) public onlyOwner {
        require(endTime > block.timestamp, "You can not add a voter after the WeightedMultipleVoting is finished.");
        require(voters[voterAddress].weight == 0, "The voter has already added and exist.");
        require(weight > 0, "The weight should be greater than 0.");
        _mint(voterAddress, maxAllowedVotes);
        voters[voterAddress].voterAddress = voterAddress;
        voters[voterAddress].weight = weight;
    }

    function vote(uint256 candidate) payable public {
        require(endTime > block.timestamp, "You can not vote after the WeightedMultipleVoting is finished.");
        require(block.timestamp > startTime, "You can not vote since the WeightedMultipleVoting has not started yet.");
        Voter storage voteSender = voters[msg.sender];
        require(voteSender.weight != 0, "You are not a voter.");
        require(voteSender.delegate == address(0), "You have delegated, you cannot vote.");
        require(maxAllowedVotes >= voteSender.voteIndexes.length + 1, "You can not vote more than the maximum allowed vote number.");
        require(msg.value >= votePrice, "You don't have enough price to vote.");
        require(balanceOf(msg.sender) > 0, "You don't have enough price to vote.");
        require(!(existInList(voteSender.voteIndexes, candidate)), "You can not vote more than once to one candidate.");
        require(candidate<candidates.length, "Candidate couldn't be found.");
        candidates[candidate].voteCount += voteSender.weight;
        voteSender.voteIndexes.push(candidate);
        _burn(msg.sender, 1);
    }

    function totalCandidateVotes(uint256 candidate) view public returns(uint256) {
        return candidates[candidate].voteCount;
    }

    function existInList(uint256[] memory allList, uint256 element) internal pure returns (bool) {
        for (uint256 i = 0; i < allList.length; i++) {
            if (allList[i] == element) {
                return true;
            }
        }
        return false;
    }

    function delegate(address toAddress) public {
        require(endTime > block.timestamp, "You can not delegate after the WeightedMultipleVoting is finished.");
        Voter storage sender = voters[msg.sender];
        require(msg.sender != owner(), "Owner can not delegate.");
        require(balanceOf(msg.sender) > 0, "You don't have any vote right to delegate.");
        require(sender.weight != 0, "You don't have a vote right to delegate.");
        require(sender.delegate == address(0), "You have already delegated.");
        require(toAddress != msg.sender, "You can not delegate to yourself.");
        while (voters[toAddress].delegate != address(0)) {
            toAddress = voters[toAddress].delegate;
            require(toAddress != msg.sender, "Found loop in the delegation.");
        }
        Voter storage delegatedVoter = voters[toAddress];
        require(delegatedVoter.delegate == address(0), "The one you want to delegate is already delegate to another one.");
        // It is not a voter.
        if(delegatedVoter.weight == 0) {
            voters[toAddress].voterAddress = toAddress;
            voters[toAddress].weight = sender.weight;
        } else {
            voters[toAddress].weight += sender.weight;
        }
        sender.delegate = toAddress;
    }

    function winningCandidate() public view returns (Candidate memory winning){
        uint maxVoteCount = 0;
        for (uint c = 0; c < candidates.length; c++) {
            if (candidates[c].voteCount > maxVoteCount) {
                maxVoteCount = candidates[c].voteCount;
                winning = candidates[c];
            }
        }
        return winning;
    }

    function updateStartTime(uint256 newStartTime) public onlyOwner {
        require(newStartTime > block.timestamp, "You can not set the start time to past.");
        require(endTime > newStartTime, "You can not set start time after the end time.");
        require(startTime > block.timestamp, "You can not change the start time after the WeightedMultipleVoting started.");
        startTime = newStartTime;
    }

    function updateEndTime(uint256 newEndTime) public onlyOwner {
        require(newEndTime > block.timestamp, "You can not set the end time to past.");
        require(newEndTime > startTime, "You can not set start time after the end time.");
        require(endTime > block.timestamp, "You can not change the end time after the WeightedMultipleVoting finished.");
        endTime = newEndTime;
    }

    function isWeightedMultipleVotingOpen() public view returns(bool) {
        return (block.timestamp > startTime && block.timestamp < endTime);
    }

    function getFinalResults() public view returns (Candidate[] memory) {
        require(endTime < block.timestamp, "WeightedMultipleVoting has not finished yet.");
        return candidates;
    }

    function checkDuplicate(string[] memory allList, string memory element) internal pure returns (bool) {
        uint256 foundNum = 0;
        for (uint256 i = 0; i < allList.length; i++) {
            if (compareStrings(allList[i], element)) {
                foundNum++;
            }
        }
        return foundNum > 1;
    }

    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "Balance is 0.");
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdraw couldn't be completed");
    }
}