// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Lottery is OwnableUpgradeable {
    // 管理员地址
    address payable manager;

    // 开奖号码数量
    uint8 constant numQuantity = 4;
    // 开奖号码的最大取值范围（不包含max）
    uint8 constant max = 10;

    // 彩民投注号码
    struct PlayerBet {
        address payable player;
        uint8[numQuantity] bet;
    }

    // 奖项
    enum Awards {FIRST, SECOND, THIRD}

    // 中奖人中奖号码及奖项
    struct WinnerBetGrade {
        address payable winner;
        uint8[numQuantity] bet;
        uint8 awards;
    }

    // 抽奖数据
    struct LotteryData {
        // 所有彩民的投注号码
        PlayerBet[] playersBet;
        // 彩民的投注号码
        mapping(address => uint8[numQuantity]) playerBet;
        // 开奖号码
        uint8[numQuantity] lotteryNums;
        // 所有中奖人中奖号码及奖项
        WinnerBetGrade[] winnersBetGrade;
        // 每个奖项的中奖人数
        mapping(uint8 => uint) awardWinnerCount;
    }

    // 彩票期数
    uint round;
    // 每期开奖中奖数据
    mapping(uint => LotteryData) LotteryDatas;

    function initialize() public initializer {
        __Ownable_init();

        manager = payable(owner());
        round = 1;
    }

    /*
     * 投注
     * bet  投注号码
     */
    function play(uint8[numQuantity] memory _bet) payable public {
        // 每次投注1Eth
        require(msg.value == 1 ether);
        // 输入的投注号码必须小于max
        for (uint8 i = 0; i < _bet.length; i++) {
            require(_bet[i] < max);
        }
        PlayerBet memory playerBet = PlayerBet(payable(_msgSender()), _bet);
        LotteryDatas[round].playersBet.push(playerBet);
        LotteryDatas[round].playerBet[_msgSender()] = _bet;
    }

    /*
     * 开奖
     */
    function runLottery() public onlyOwner {
        LotteryData storage data = LotteryDatas[round];

        // 至少1个参与者才能开奖
        require(data.playersBet.length > 0);

        // 随机生成的开奖号码
        for (uint8 i = 0; i < numQuantity; i++) {
            uint v = uint(sha256(abi.encodePacked(block.timestamp, data.playersBet.length, i)));
            // 将随机获取的Hash值对max取余，保证号码在0~max之间（不包含max）
            data.lotteryNums[i] = uint8(v % uint(max));
        }

        for (uint i = 0; i < data.playersBet.length; i++) {
            uint8 count;
            // 记录彩民投注号码顺序符合开奖号码的个数
            uint8[numQuantity] memory bet = data.playersBet[i].bet;
            // 遍历开奖号码与彩民投注号码，顺序符合则count加1
            for (uint8 j = 0; j < numQuantity; j++) {
                if (data.lotteryNums[j] == bet[j]) {
                    count ++;
                }
            }
            // 如果numQuantity（4）个号码顺序相同，则中一等奖；3个号码相同则中二等奖；2个号码相同则中三等奖
            if (count == numQuantity) {
                WinnerBetGrade memory winnerBetGrade = WinnerBetGrade(data.playersBet[i].player, bet, uint8(Awards.FIRST));
                data.winnersBetGrade.push(winnerBetGrade);
                // 一等奖的中奖人数加1
                data.awardWinnerCount[uint8(Awards.FIRST)]++;
            } else if (count == numQuantity - 1) {
                WinnerBetGrade memory winnerBetGrade = WinnerBetGrade(data.playersBet[i].player, bet, uint8(Awards.SECOND));
                data.winnersBetGrade.push(winnerBetGrade);
                // 二等奖的中奖人数加1
                data.awardWinnerCount[uint8(Awards.SECOND)]++;
            } else if (count == numQuantity - 2) {
                WinnerBetGrade memory winnerBetGrade = WinnerBetGrade(data.playersBet[i].player, bet, uint8(Awards.THIRD));
                data.winnersBetGrade.push(winnerBetGrade);
                // 三等奖的中奖人数加1
                data.awardWinnerCount[uint8(Awards.THIRD)]++;
            }
        }

        dividePrizePool(data); // 瓜分奖池

        round++;
    }

    /*
     * 瓜分奖池
     */
    function dividePrizePool(LotteryData storage _data) private {
        // 瓜分的奖池总金额
        uint totalAmount = address(this).balance;
        // 每注一等奖瓜分的奖池金额
        uint firstDivide = 0;
        // 每注二等奖瓜分的奖池金额
        uint secondDivide = 0;
        // 每注三等奖瓜分的奖池金额
        uint thirdDivide = 0;

        // 管理员收取2%的奖池金额作为管理费
        uint managerDivide = totalAmount * 2 / 100;
        // 一等奖瓜分80%的奖池金额
        if (_data.awardWinnerCount[uint8(Awards.FIRST)] != 0) {
            firstDivide = totalAmount * 80 / (100 * _data.awardWinnerCount[uint8(Awards.FIRST)]);
        }
        // 二等奖瓜分15%的奖池金额
        if (_data.awardWinnerCount[uint8(Awards.SECOND)] != 0) {
            secondDivide = totalAmount * 15 / (100 * _data.awardWinnerCount[uint8(Awards.SECOND)]);
        }
        // 三等奖瓜分3%的奖池金额
        if (_data.awardWinnerCount[uint8(Awards.THIRD)] != 0) {
            thirdDivide = totalAmount * 3 / (100 * _data.awardWinnerCount[uint8(Awards.THIRD)]);
        }

        // 向管理员转账
        manager.transfer(managerDivide);
        for (uint i = 0; i < _data.winnersBetGrade.length; i++) {
            if (_data.winnersBetGrade[i].awards == uint8(Awards.FIRST)) {
                // 向一等奖中奖者转账
                _data.winnersBetGrade[i].winner.transfer(firstDivide);
            } else if (_data.winnersBetGrade[i].awards == uint8(Awards.SECOND)) {
                // 向二等奖中奖者转账
                _data.winnersBetGrade[i].winner.transfer(secondDivide);
            }  else if (_data.winnersBetGrade[i].awards == uint8(Awards.THIRD)) {
                // 向三等奖中奖者转账
                _data.winnersBetGrade[i].winner.transfer(thirdDivide);
            }
        }
    }

    /*
     * 获取合约余额
     */
    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    /*
     * 获取当期彩民投注号码数组长度
     */
    function getPlayersBetLength() public view returns (uint) {
        return LotteryDatas[round].playersBet.length;
    }

    /*
     * 获取彩民某期投注号码
     */
    function getPlayersBet(uint _round) public view returns (uint8[numQuantity] memory) {
        return LotteryDatas[_round].playerBet[_msgSender()];
    }

    /*
     * 获取开奖号码
     */
    function getLotteryNums(uint _round) public view returns (uint8[numQuantity] memory) {
        return LotteryDatas[_round].lotteryNums;
    }

    /*
     * 获取某期中奖人总个数
     */
    function getWinnersBetGradeLength(uint _round) public view returns (uint) {
        return LotteryDatas[_round].winnersBetGrade.length;
    }

    /*
     * 获取某期某奖项中奖人个数
     */
    function getWinnersBetGradeLength(uint _round, uint8 _award) public view returns (uint) {
        return LotteryDatas[_round].awardWinnerCount[_award];
    }

    /*
     * 获取某期中奖人中奖号码及奖项
     */
    function getWinnersBetGradeLength(uint _round, uint _index) public view returns (WinnerBetGrade memory) {
        return LotteryDatas[_round].winnersBetGrade[_index];
    }

    /*
     * 获取彩票期数
     */
    function getRound() public view returns (uint) {
        return round;
    }
}