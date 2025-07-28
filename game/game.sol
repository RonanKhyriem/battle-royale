// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract BattleRoyaleGame {
    
    // Game state variables
    address public owner;
    uint256 public gameId;
    uint256 public entryFee;
    uint256 public maxPlayers;
    uint256 public gameEndTime;
    bool public gameActive;
    
    // Player structure
    struct Player {
        address playerAddress;
        uint256 health;
        uint256 position;
        bool isAlive;
        uint256 joinTime;
    }
    
    // Game mappings
    mapping(uint256 => mapping(address => Player)) public games;
    mapping(uint256 => address[]) public gamePlayers;
    mapping(uint256 => address) public gameWinner;
    mapping(uint256 => uint256) public gamePrizePool;
    
    // Events
    event GameCreated(uint256 indexed gameId, uint256 entryFee, uint256 maxPlayers);
    event PlayerJoined(uint256 indexed gameId, address indexed player);
    event PlayerEliminated(uint256 indexed gameId, address indexed player, address indexed eliminator);
    event GameEnded(uint256 indexed gameId, address indexed winner, uint256 prizeAmount);
    event HealthUpdated(uint256 indexed gameId, address indexed player, uint256 newHealth);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier gameIsActive(uint256 _gameId) {
        require(_gameId <= gameId && _gameId > 0, "Invalid game ID");
        require(block.timestamp < gameEndTime, "Game has ended");
        _;
    }
    
    modifier playerIsAlive(uint256 _gameId) {
        require(games[_gameId][msg.sender].isAlive, "Player is not alive");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        gameId = 0;
    }
    
    // Core Function 1: Create and Join Game
    function createAndJoinGame(uint256 _entryFee, uint256 _maxPlayers, uint256 _gameDuration) external payable {
        require(_maxPlayers >= 2 && _maxPlayers <= 100, "Invalid max players");
        require(_gameDuration >= 300 && _gameDuration <= 3600, "Game duration must be 5-60 minutes");
        require(msg.value >= _entryFee, "Insufficient entry fee");
        
        gameId++;
        entryFee = _entryFee;
        maxPlayers = _maxPlayers;
        gameEndTime = block.timestamp + _gameDuration;
        gameActive = true;
        
        // Add creator as first player
        games[gameId][msg.sender] = Player({
            playerAddress: msg.sender,
            health: 100,
            position: uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 1000,
            isAlive: true,
            joinTime: block.timestamp
        });
        
        gamePlayers[gameId].push(msg.sender);
        gamePrizePool[gameId] = msg.value;
        
        emit GameCreated(gameId, _entryFee, _maxPlayers);
        emit PlayerJoined(gameId, msg.sender);
        
        // Refund excess payment
        if (msg.value > _entryFee) {
            payable(msg.sender).transfer(msg.value - _entryFee);
        }
    }
    
    function joinGame(uint256 _gameId) external payable gameIsActive(_gameId) {
        require(msg.value >= entryFee, "Insufficient entry fee");
        require(gamePlayers[_gameId].length < maxPlayers, "Game is full");
        require(!games[_gameId][msg.sender].isAlive && games[_gameId][msg.sender].playerAddress == address(0), "Player already in game");
        
        // Add player to game
        games[_gameId][msg.sender] = Player({
            playerAddress: msg.sender,
            health: 100,
            position: uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 1000,
            isAlive: true,
            joinTime: block.timestamp
        });
        
        gamePlayers[_gameId].push(msg.sender);
        gamePrizePool[_gameId] += entryFee;
        
        emit PlayerJoined(_gameId, msg.sender);
        
        // Refund excess payment
        if (msg.value > entryFee) {
            payable(msg.sender).transfer(msg.value - entryFee);
        }
    }
    
    // Core Function 2: Combat System
    function attackPlayer(uint256 _gameId, address _target) external gameIsActive(_gameId) playerIsAlive(_gameId) {
        require(games[_gameId][_target].isAlive, "Target player is not alive");
        require(_target != msg.sender, "Cannot attack yourself");
        require(games[_gameId][_target].playerAddress != address(0), "Target not in game");
        
        Player storage attacker = games[_gameId][msg.sender];
        Player storage target = games[_gameId][_target];
        
        // Calculate damage based on position proximity and randomness
        uint256 distance = attacker.position > target.position ? 
            attacker.position - target.position : target.position - attacker.position;
        
        require(distance <= 50, "Target too far to attack");
        
        // Random damage between 15-35 points
        uint256 damage = 15 + (uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _target))) % 21);
        
        if (target.health <= damage) {
            target.health = 0;
            target.isAlive = false;
            emit PlayerEliminated(_gameId, _target, msg.sender);
            
            // Check if game should end
            _checkGameEnd(_gameId);
        } else {
            target.health -= damage;
            emit HealthUpdated(_gameId, _target, target.health);
        }
    }
    
    // Core Function 3: End Game and Distribute Rewards
    function endGameAndDistribute(uint256 _gameId) external {
        require(_gameId <= gameId && _gameId > 0, "Invalid game ID");
        require(block.timestamp >= gameEndTime || _getAlivePlayers(_gameId) <= 1, "Game not ready to end");
        require(gameWinner[_gameId] == address(0), "Game already ended");
        
        address winner = _determineWinner(_gameId);
        
        if (winner != address(0)) {
            gameWinner[_gameId] = winner;
            uint256 prizeAmount = gamePrizePool[_gameId];
            
            // Winner gets 90% of prize pool
            uint256 winnerAmount = (prizeAmount * 90) / 100;
            // Owner gets 10% as platform fee
            uint256 platformFee = prizeAmount - winnerAmount;
            
            payable(winner).transfer(winnerAmount);
            payable(owner).transfer(platformFee);
            
            emit GameEnded(_gameId, winner, winnerAmount);
        } else {
            // No winner, refund players proportionally
            _refundPlayers(_gameId);
        }
        
        gameActive = false;
    }
    
    // Internal helper functions
    function _checkGameEnd(uint256 _gameId) internal {
        uint256 aliveCount = _getAlivePlayers(_gameId);
        if (aliveCount <= 1) {
            gameEndTime = block.timestamp; // Force game to end
        }
    }
    
    function _getAlivePlayers(uint256 _gameId) internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < gamePlayers[_gameId].length; i++) {
            if (games[_gameId][gamePlayers[_gameId][i]].isAlive) {
                count++;
            }
        }
        return count;
    }
    
    function _determineWinner(uint256 _gameId) internal view returns (address) {
        for (uint256 i = 0; i < gamePlayers[_gameId].length; i++) {
            if (games[_gameId][gamePlayers[_gameId][i]].isAlive) {
                return gamePlayers[_gameId][i];
            }
        }
        return address(0);
    }
    
    function _refundPlayers(uint256 _gameId) internal {
        uint256 refundAmount = gamePrizePool[_gameId] / gamePlayers[_gameId].length;
        for (uint256 i = 0; i < gamePlayers[_gameId].length; i++) {
            payable(gamePlayers[_gameId][i]).transfer(refundAmount);
        }
    }
    
    // View functions
    function getGameInfo(uint256 _gameId) external view returns (
        uint256 playerCount,
        uint256 prizePool,
        address winner,
        bool isActive
    ) {
        return (
            gamePlayers[_gameId].length,
            gamePrizePool[_gameId],
            gameWinner[_gameId],
            block.timestamp < gameEndTime && gameWinner[_gameId] == address(0)
        );
    }
    
    function getPlayerInfo(uint256 _gameId, address _player) external view returns (
        uint256 health,
        uint256 position,
        bool isAlive
    ) {
        Player memory player = games[_gameId][_player];
        return (player.health, player.position, player.isAlive);
    }
    
    function getCurrentGameId() external view returns (uint256) {
        return gameId;
    }
    
    // Emergency functions
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    function updateOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}
