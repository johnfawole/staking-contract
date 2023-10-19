// SPDX-License-Identifier: MIT

 pragma solidity 0.8.21;

  import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

  contract StakingDAO {
    // this is the token they stake
    IERC20 public immutable stakingToken;
    // this is the token they get in return
    IERC20 public immutable rewardsToken;

    address public owner;

    uint public duration;
    uint public finishAt;
    uint public updatedAt;
    // this is reward-per-second
    uint public rewardRate;
    
    // we will have to define this user
    uint public rewardPerTokenStored;

    // we need this to track every user's "rewardPerTokenStored" 
    mapping(address => uint) public userRewardPerTokenPaid;
    // track address to the reward they earn
    mapping(address => uint) public rewards;


    uint public totalSupply;
    mapping(address => uint) public balanceOf;
 
    // pass in the addresses of reward and staking tokens
    // make the tokens to be in IERC20
    constructor(address _stakingToken, address _rewardToken) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "unauthorized");
        _;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalSupply;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(finishAt, block.timestamp);
    }

    // this function lets us know the minimum between x and y
    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    function setRewardsDuration(uint _duration) external onlyOwner{
        require(finishAt < block.timestamp, "wait for everything to finish");
        // on deployment, "_duration" is where we will specify the actual duration
        duration = _duration;
    }

    function notifyRewardAmount(uint _amount) external onlyOwner updateReward (address(0)) {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }
    }

     function setStopAndUpdate() external onlyOwner {
        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function stake(uint _amount) external {
      require(_amount > 0, "amount = 0");
      stakingToken.transferFrom(msg.sender, address(this), _amount);
      balanceOf[msg.sender] += _amount;
      totalSupply += _amount;
    }

    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0 , "_amount = 0");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function earned(address _account) public view returns (uint){
        return ((balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
         rewards[_account];
    }

    function getReward(uint _amount) external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }


  }
