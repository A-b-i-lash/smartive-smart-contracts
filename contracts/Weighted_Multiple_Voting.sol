// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

contract WeightedMultipleVoting {
    struct Candidate {
        bytes32 name;
        uint256 voteCount;
    }

    struct Voter {
        uint256 weight;
        address voterAddress;
        uint256[] voteIndexes;
        bool hasVoted;
        address delegate;
    }

    address public owner;
    Candidate[] private candidates;
    mapping(address => Voter) public voters;
    uint256 private maxAllowedVotes;
    uint256 constant votePrice = 0.001 ether;
    uint256 private startTime;
    uint256 private endTime;

    constructor(bytes32[] memory candidateNames, uint256 maxVotes, uint256 ownerWeight, uint256 startTime_, uint256 endTime_) {
        owner = msg.sender;
        voters[owner].voterAddress = owner;
        voters[owner].weight = ownerWeight;
        for(uint i=0; i<candidateNames.length; i++) {
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

    function addVoter(address voterAddress, uint256 weight) public {
        require(endTime > block.timestamp, "You can not add a voter after the voting is finished.");
        require(msg.sender == owner, "Only the owner can add a voter.");
        require(voters[voterAddress].weight == 0, "The voter has already added and exist.");
        require(weight > 0, "The weight should be greater than 0.");
        voters[voterAddress].voterAddress = voterAddress;
        voters[voterAddress].weight = weight;
    }

    function vote(uint256[] memory candidateList) payable public {
        require(endTime > block.timestamp, "You can not vote after the voting is finished.");
        require(block.timestamp > startTime, "You can not vote since the voting has not started yet.");
        require(maxAllowedVotes >= candidateList.length, "You can not vote more than the maximum allowed vote number.");
        Voter storage voteSender = voters[msg.sender];
        require(!voteSender.hasVoted, "You have already voted.");
        require(voteSender.weight != 0, "You are not a voter.");
        require(voteSender.delegate == address(0), "You have delegated, you cannot vote.");
        uint256 totalRequiredPrice = (votePrice*candidateList.length);
        require(msg.value >= totalRequiredPrice, "You don't have enough price to vote.");
        voteSender.voteIndexes = candidateList;
        for(uint256 i=0; i<candidateList.length; i++) {
            require(!(checkDuplicate(candidateList, candidateList[i])), "You can not vote more than once to one candidate.");
            require(candidateList[i]<candidates.length, "One of the candidates you want to vote couldn't be found.");
            candidates[candidateList[i]].voteCount += voteSender.weight;
        }
        voteSender.hasVoted = true;
    }

    function totalCandidateVotes(uint256 candidate) view public returns(uint256) {
        return candidates[candidate].voteCount;
    }

    function checkDuplicate(uint256[] memory allList, uint256 element) internal pure returns (bool) {
        uint256 foundNum = 0;
        for (uint256 i = 0; i < allList.length; i++) {
            if (allList[i] == element) {
                foundNum++;
            }
        }
        return foundNum > 1;
    }

    function delegate(address toAddress) public {
        require(endTime > block.timestamp, "You can not delegate after the voting is finished.");
        Voter storage sender = voters[msg.sender];
        require(msg.sender != owner, "Owner can not delegate.");
        require(!sender.hasVoted, "You have already voted.");
        require(sender.weight != 0, "You don't have a vote right to delegate.");
        require(toAddress != msg.sender, "You can not delegate to yourself.");
        while (voters[toAddress].delegate != address(0)) {
            toAddress = voters[toAddress].delegate;
            require(toAddress != msg.sender, "Found loop in the delegation.");
        }
        Voter storage delegatedVoter = voters[toAddress];
        require(!delegatedVoter.hasVoted, "Delegate has already voted.");
        // It is not a voter.
        if(delegatedVoter.weight == 0) {
            voters[toAddress].voterAddress = toAddress;
            voters[toAddress].weight = sender.weight;
        } else {
            voters[toAddress].weight += sender.weight;
        }
        sender.hasVoted = true;
        sender.delegate = toAddress;
    }

    function withdraw() public {
        require(msg.sender == owner, "Only the owner can withdraw.");
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Withdraw couldn't be completed");
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

    function updateVotingStartTime(uint256 newStartTime) public {
        require(msg.sender == owner, "Only the owner can update start time.");
        require(newStartTime > block.timestamp, "You can not set the start time to past.");
        require(endTime > newStartTime, "You can not set start time after the end time.");
        require(startTime > block.timestamp, "You can not change the start time after the voting started.");
        startTime = newStartTime;
    }

    function updateEndTime(uint256 newEndTime) public {
        require(msg.sender == owner, "Only the owner can update start time.");
        require(newEndTime > block.timestamp, "You can not set the end time to past.");
        require(newEndTime > startTime, "You can not set start time after the end time.");
        require(endTime > block.timestamp, "You can not change the end time after the voting finished.");
        endTime = newEndTime;
    }

    function isVotingOpen() public view returns(bool) {
        return (block.timestamp > startTime && block.timestamp < endTime);
    }

    function getFinalResults() public view returns (Candidate[] memory) {
        require(endTime < block.timestamp, "Voting has not finished yet.");
        return candidates;
    }
}