// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPS {
    // Initial Imported Smart Contract
    CommitReveal private commit_reveal = new CommitReveal();
    TimeUnit private time_unit = new TimeUnit();

    //state variables เพื่อไล่ดูสถานะของเกม
    uint public numPlayer = 0;
    uint public reward = 0;     
    uint public numInput = 0;   // บอกจำนวนคนที่มาเล่นครบ 2 คน เเละออกอาวุธเเล้ว นั่นคือพร้อมตัดสินผลเเพ้-ชนะ
    uint public num_reveal = 0;
    uint256 constant TIMEOUT = 30;

    mapping (address => uint) public player_choice; // 0 - Rock, 1 - Paper , 2 - Scissors, 3 - Lizard, 4 - Spock  // can get from reveal
    mapping (address => bytes32) public player_reveal;

    address[] public players;
    mapping(address => bool) public player_not_played;  
    mapping(address => bool) public player_not_reveal;  

    mapping (address => bool) public allowedAddresses;
    constructor() {
        allowedAddresses[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
        allowedAddresses[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = true;
        allowedAddresses[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = true;
        allowedAddresses[0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB] = true;
    }

    function addPlayer() public payable {
        require(allowedAddresses[msg.sender]);
        require(numPlayer < 2); // ถ้า > 2 ก็เรียกใช้ได้นะ เเต่จะเป็นโมฆะ บางทีก็คืน gas ให้
        if (numPlayer > 0) {
            require(msg.sender != players[0]);  // msg.sender เเทน address ของคนที่เรียกฟังก์ชัน addPlayer() --> อาจเป็น 2 คนเดียวกันก็ได้
        }
        require(msg.value == 1 ether); // ตอนเรียก addPlayer() ใน smart contract RPS จะต้องส่งเงินมาด้วย 1 ether (ในกระเป๋าจริงๆมีตังเท่าไหร่ก็ได้)
        reward += msg.value;
        player_not_played[msg.sender] = true; // default = false  // true mean that player have right to play
        player_not_reveal[msg.sender] = true;
        players.push(msg.sender);   // update address[] space
        numPlayer++;
        time_unit.setStartTime(msg.sender);
    }

    function input(bytes32 choice) public  {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);     // คนเล่นต้องเคยเรียก addPlayer() มาแล้วเท่านั้น
        require(player_not_reveal[msg.sender]);
        commit_reveal.commit(choice, msg.sender);       // choice = output from getHash function (bytes32)
        player_not_played[msg.sender] = false;
        numInput++;
        time_unit.setStartTime(msg.sender);
    }

    function revealChoice(bytes32 reveal) public {
        require(numInput == 2);
        commit_reveal.reveal(reveal, msg.sender);

        player_reveal[msg.sender] = reveal;
        player_not_reveal[msg.sender] = false;

        num_reveal++;
        time_unit.setStartTime(msg.sender);

        if (num_reveal == 2) {
            _checkWinnerAndPay();   //  ผู้เล่นจะไม่สามารถเรียกใช้งาน Private function ได้
        }
    }

    function _checkWinnerAndPay() private {
        bytes32 p0Choice = player_reveal[players[0]];
        bytes32 p1Choice = player_reveal[players[1]];

        uint8 p0_final_choice = uint8(uint256(p0Choice) & 0xFF); // 0-2
        uint8 p1_final_choice = uint8(uint256(p1Choice) & 0xFF); // 0-2

        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if ((p0_final_choice + 1) % 3 == p1_final_choice) {
            // to pay player[1]
            account1.transfer(reward);
        }
        else if ((p1_final_choice + 1) % 3 == p0_final_choice) {
            // to pay player[0]
            account0.transfer(reward);    
        }
        else {
            // to split reward
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }

        emit playerChoice(players[0], p0Choice, p0_final_choice);
        emit playerChoice(players[1], p1Choice, p1_final_choice);

        _resetGame();
    }
    event playerChoice(address indexed _player, bytes32 Reveal, uint8 choice_num_);


//     function _checkWinnerAndPay() private {
//     bytes32 p0Choice = player_reveal[players[0]];
//     bytes32 p1Choice = player_reveal[players[1]];

//     uint8 p0_final_choice = uint8(uint256(p0Choice) & 0xFF); // 0-4
//     uint8 p1_final_choice = uint8(uint256(p1Choice) & 0xFF); // 0-4

//     address payable account0 = payable(players[0]);
//     address payable account1 = payable(players[1]);

//     // Both player choose the same choice => tie
//     if (p0_final_choice == p1_final_choice) {
//         account0.transfer(reward / 2);
//         account1.transfer(reward / 2);
//     } 
//     // Check if p0 beats p1
//     else if (_is_A_Winning(p0_final_choice, p1_final_choice)) {
//         account0.transfer(reward);
//     } 
//     // Otherwise p1 must be the winner
//     else {
//         account1.transfer(reward);
//     }

//     emit playerChoice(players[0], p0Choice, p0_final_choice);
//     emit playerChoice(players[1], p1Choice, p1_final_choice);

//     _resetGame();
// }
// event playerChoice(address player, bytes32 reveal, uint8 finalChoice);


// function _is_A_Winning(uint8 choiceA, uint8 choiceB) private pure returns (bool) {
//     // List all winning conditions for choiceA vs. choiceB
//     // 0 = Rock, 1 = Paper, 2 = Scissors, 3 = Lizard, 4 = Spock

//     // Scissors (2) cuts Paper (1)
//     if (choiceA == 2 && choiceB == 1) return true;
//     // Paper (1) covers Rock (0)
//     if (choiceA == 1 && choiceB == 0) return true;
//     // Rock (0) crushes Lizard (3)
//     if (choiceA == 0 && choiceB == 3) return true;
//     // Lizard (3) poisons Spock (4)
//     if (choiceA == 3 && choiceB == 4) return true;
//     // Spock (4) smashes Scissors (2)
//     if (choiceA == 4 && choiceB == 2) return true;
//     // Scissors (2) decapitates Lizard (3)
//     if (choiceA == 2 && choiceB == 3) return true;
//     // Lizard (3) eats Paper (1)
//     if (choiceA == 3 && choiceB == 1) return true;
//     // Paper (1) disproves Spock (4)
//     if (choiceA == 1 && choiceB == 4) return true;
//     // Spock (4) vaporizes Rock (0)
//     if (choiceA == 4 && choiceB == 0) return true;
//     // Rock (0) crushes Scissors (2)
//     if (choiceA == 0 && choiceB == 2) return true;

//     // If none match, choiceA does not win --> choiceB win
//     return false;
// }


    function getTime() public view returns (uint256) {
        // Checking time that pass for each step - addPlayer, input, revealChoice
        return time_unit.elapsedSeconds(msg.sender);
    }


    function stopGame() public {
        // check that time has pass more than TIMEOUT
        uint256 time = time_unit.elapsedSeconds(msg.sender);
        require(time >= TIMEOUT);

        // check that the msg.sender is really a player
        bool real_player = false;
        uint256 player_idx = 0;
        for (uint i=0; i<players.length; i++) {
            address player = players[i];
            if (player == msg.sender) {
                real_player = true;
                player_idx = i;
                break;
            }
        }
        require(real_player);

        address payable account = payable(players[player_idx]);

        uint256 player_idx_bad = 0;
        address payable account_bad = payable(players[0]);
        if (numPlayer == 2) {
            player_idx_bad = (player_idx + 1) % 2;
            account_bad = payable(players[player_idx_bad]);
        }

        if (numPlayer == 1) {
            account.transfer(reward);
            _resetGame();
        }
        else if (numPlayer == 2 && numInput == 1) {
            if (!player_not_played[account]) {
                account.transfer(reward / 2);
                account_bad.transfer(reward / 2);
                _resetGame();
            }
            else {
                revert("Please input");
            }
        }
        else if (numPlayer == 2 && numInput == 2 && num_reveal == 1) {
            if (!player_not_reveal[account]) {
                account.transfer(reward / 2);
                account_bad.transfer(reward / 2);
                _resetGame();
            }
            else {
                revert("Please revealChoice");
            }
        }
    }

    // Reset game state for a new round
    function _resetGame() private {
        for (uint i = 0; i < players.length; i++) {
            address player = players[i];
            delete player_choice[player];
            delete player_reveal[player];
            delete player_not_played[player];
            delete player_not_reveal[player];
        }
        delete players;
        numPlayer = 0;
        numInput = 0;
        reward = 0;
        num_reveal = 0;
    }
}