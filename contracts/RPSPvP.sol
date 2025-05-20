// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract RPSPvP {
    enum Move { None, Rock, Paper, Scissors }
    enum RoomState { WaitingForPlayer, ReadyToPlay, Completed }

    struct Room {
        address player1;
        address player2;
        Move move1;
        Move move2;
        uint256 stake;
        RoomState state;
        bool player1Paid;
        bool player2Paid;
    }

    address public owner;
    uint256 public roomCounter;
    uint256 public ownerFeePercent = 5;

    mapping(uint256 => Room) public rooms;

    event RoomCreated(uint256 indexed roomId, address indexed player1, uint256 stake);
    event PlayerJoined(uint256 indexed roomId, address indexed player2);
    event MoveSubmitted(uint256 indexed roomId, address indexed player, Move move);
    event MatchResolved(uint256 indexed roomId, address winner, uint256 reward);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyPlayers(uint256 roomId) {
        require(
            msg.sender == rooms[roomId].player1 || msg.sender == rooms[roomId].player2,
            "Not a player in this room"
        );
        _;
    }

    function createRoom(uint256 stake) external returns (uint256 roomId) {
        require(stake > 0, "Stake must be greater than 0");

        roomCounter++;
        rooms[roomCounter] = Room({
            player1: msg.sender,
            player2: address(0),
            move1: Move.None,
            move2: Move.None,
            stake: stake,
            state: RoomState.WaitingForPlayer,
            player1Paid: false,
            player2Paid: false
        });

        emit RoomCreated(roomCounter, msg.sender, stake);
        return roomCounter;
    }

    function joinRoom(uint256 roomId) external {
        Room storage room = rooms[roomId];
        require(room.state == RoomState.WaitingForPlayer, "Room not available");
        require(msg.sender != room.player1, "You cannot join your own room");

        room.player2 = msg.sender;
        room.state = RoomState.ReadyToPlay;

        emit PlayerJoined(roomId, msg.sender);
    }

    function submitMove(uint256 roomId, string calldata moveStr) external payable onlyPlayers(roomId) {
        Room storage room = rooms[roomId];
        require(room.state == RoomState.ReadyToPlay, "Room not ready");

        Move move = _parseMove(moveStr);
        require(move != Move.None, "Invalid move");
        require(msg.value == room.stake, "Incorrect stake amount");

        if (msg.sender == room.player1) {
            require(!room.player1Paid, "Move already submitted");
            room.move1 = move;
            room.player1Paid = true;
        } else {
            require(!room.player2Paid, "Move already submitted");
            room.move2 = move;
            room.player2Paid = true;
        }

        emit MoveSubmitted(roomId, msg.sender, move);

        if (room.player1Paid && room.player2Paid) {
            _resolveMatch(roomId);
        }
    }

    function _resolveMatch(uint256 roomId) internal {
        Room storage room = rooms[roomId];
        room.state = RoomState.Completed;

        address payable winner;
        uint256 totalPool = room.stake * 2;
        uint256 fee = (totalPool * ownerFeePercent) / 100;
        uint256 reward = totalPool - fee;

        if (room.move1 == room.move2) {
            // Draw: refund both
            payable(room.player1).transfer(room.stake);
            payable(room.player2).transfer(room.stake);
            emit MatchResolved(roomId, address(0), 0);
            return;
        }

        if (_beats(room.move1, room.move2)) {
            winner = payable(room.player1);
        } else {
            winner = payable(room.player2);
        }

        // Transfer reward to winner
        (bool sent, ) = winner.call{value: reward}("");
        require(sent, "Reward transfer failed");

        // Transfer fee to owner
        (bool feeSent, ) = payable(owner).call{value: fee}("");
        require(feeSent, "Owner fee transfer failed");

        emit MatchResolved(roomId, winner, reward);
    }

    function _parseMove(string memory moveStr) internal pure returns (Move) {
        bytes32 h = keccak256(abi.encodePacked(moveStr));
        if (h == keccak256(abi.encodePacked("rock"))) return Move.Rock;
        if (h == keccak256(abi.encodePacked("paper"))) return Move.Paper;
        if (h == keccak256(abi.encodePacked("scissors"))) return Move.Scissors;
        return Move.None;
    }

    function _beats(Move a, Move b) internal pure returns (bool) {
        return (a == Move.Rock && b == Move.Scissors) ||
               (a == Move.Paper && b == Move.Rock) ||
               (a == Move.Scissors && b == Move.Paper);
    }

    function getRoom(uint256 roomId) external view returns (
        address player1,
        address player2,
        Move move1,
        Move move2,
        uint256 stake,
        RoomState state
    ) {
        Room storage r = rooms[roomId];
        return (r.player1, r.player2, r.move1, r.move2, r.stake, r.state);
    }
}
