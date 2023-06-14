// SPDX-License-Identifier: unlicensed
pragma solidity 0.8.4;

abstract contract ERC20Interface {
    function totalSupply() public view virtual returns (uint256);

    function balanceOf(address account) public view virtual returns (uint256);

    function transfer(address recipient, uint256 amount)
        public
        virtual
        returns (bool);

    function allowance(address owner, address spender)
        public
        view
        virtual
        returns (uint256);

    function approve(address spender, uint256 amount)
        public
        virtual
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Paused(bool isPaused);
    event OwnershipTransferred(address newOwner);
    event TokensPurchased(address account, uint256 amount);
}

contract SafeMath {
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a);
    }

    function safeSub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b <= a);
        c = a - b;
    }

    function safeMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }

    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b > 0);
        c = a / b;
    }
}

contract PAY2PAL is ERC20Interface, SafeMath {
    string public symbol;
    string public name;
    uint8 public decimals;
    uint256 public _totalSupply;
    address public owner;
    bool paused = false;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;
    mapping(address => uint256) stakedBalances;
    mapping(address => uint256) public stakeTimestamp;

    uint256 public constant stakeDuration = 100;

    constructor() {
        symbol = "P2P";
        name = "PAY2PAL";
        decimals = 18;
        _totalSupply = 100000000 * 10**18; // 100 million tokens
        balances[msg.sender] = _totalSupply;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner is allowed");
        _;
    }

    modifier isPaused() {
        require(!paused, "Contract is in paused state");
        _;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address tokenOwner)
        public
        view
        override
        returns (uint256 balance)
    {
        return balances[tokenOwner];
    }

    function transfer(address receiver, uint256 tokens)
        public
        override
        isPaused
        returns (bool success)
    {
        balances[msg.sender] = safeSub(balances[msg.sender], tokens);
        balances[receiver] = safeAdd(balances[receiver], tokens);
        emit Transfer(msg.sender, receiver, tokens);
        return true;
    }

    function approve(address spender, uint256 tokens)
        public
        override
        isPaused
        returns (bool success)
    {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    function transferFrom(
        address sender,
        address receiver,
        uint256 tokens
    ) public override isPaused returns (bool success) {
        balances[sender] = safeSub(balances[sender], tokens);
        allowed[sender][msg.sender] = safeSub(
            allowed[sender][msg.sender],
            tokens
        );
        balances[receiver] = safeAdd(balances[receiver], tokens);
        emit Transfer(sender, receiver, tokens);
        return true;
    }

    function allowance(address tokenOwner, address spender)
        public
        view
        override
        returns (uint256 remaining)
    {
        return allowed[tokenOwner][spender];
    }

    function increaseApproval(address _spender, uint256 _addedValue)
        public
        isPaused
        returns (bool)
    {
        return _increaseApproval(msg.sender, _spender, _addedValue);
    }

    function _increaseApproval(
        address _sender,
        address _spender,
        uint256 _addedValue
    ) internal returns (bool) {
        allowed[_sender][_spender] = allowed[_sender][_spender] + _addedValue;
        emit Approval(_sender, _spender, allowed[_sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint256 _subtractedValue)
        public
        isPaused
        returns (bool)
    {
        return _decreaseApproval(msg.sender, _spender, _subtractedValue);
    }

    function _decreaseApproval(
        address _sender,
        address _spender,
        uint256 _subtractedValue
    ) internal returns (bool) {
        uint256 oldValue = allowed[_sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[_sender][_spender] = 0;
        } else {
            allowed[_sender][_spender] = oldValue - _subtractedValue;
        }
        emit Approval(_sender, _spender, allowed[_sender][_spender]);
        return true;
    }

    function pause(bool _flag) external onlyOwner {
        paused = _flag;
        emit Paused(_flag);
    }

    function transferOwnership(address _newOwner) public virtual onlyOwner {
        owner = _newOwner;
        emit OwnershipTransferred(_newOwner);
    }

    function burn(uint256 _value, address _add) public onlyOwner {
        _totalSupply = safeSub(_totalSupply, _value);
        balances[_add] = safeSub(balances[_add], _value);
        emit Transfer(_add, address(0), _value);
    }

    function mint(uint256 _value, address _add) public onlyOwner {
        _totalSupply = safeAdd(_totalSupply, _value);
        balances[_add] = safeAdd(balances[_add], _value);
        emit Transfer(_add, address(0), _value);
    }

    function withdrawOwner(uint256 _amount) public onlyOwner returns (bool) {
        payable(msg.sender).transfer(_amount);
        return true;
    }

    function stake(uint256 _amount) public returns (bool) {
        require(_amount > 0, "Invalid amount");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        approve(owner, _amount);
        uint256 allowance1 = allowed[msg.sender][owner];
        require(allowance1 >= _amount, "Check the token allowance");
        // transferFrom(msg.sender, owner, _amount);
        balances[msg.sender] = safeSub(balances[msg.sender], _amount);
        allowed[msg.sender][owner] = safeSub(allowed[msg.sender][owner], _amount);
        balances[owner] = balances[owner] + _amount;
        emit Transfer(msg.sender, owner, _amount);
        stakedBalances[msg.sender] = _amount;
        stakeTimestamp[msg.sender] = block.timestamp + stakeDuration;
        return true;
    }

    function unstake() public {
        require(stakedBalances[msg.sender] > 0, "No staked balance");
        require(
            block.timestamp >= stakeTimestamp[msg.sender],
            "Stake duration not reached"
        );
        uint256 amount = stakedBalances[msg.sender];
        balances[msg.sender] = safeAdd(balances[msg.sender], amount);
        balances[owner] = safeSub(balances[owner], amount);
        stakedBalances[msg.sender] = 0;
        stakeTimestamp[msg.sender] = 0;
        emit Transfer(address(this), msg.sender, amount);
    }

    function getStakedBalance(address account) public view returns (uint256) {
        return stakedBalances[account];
    }
}
