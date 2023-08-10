// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title OraclePrices
 * @notice A library that provides functionalities for processing and analyzing token rate and weight data provided by an oracle.
 *         The library is used when an oracle uses multiple pools to determine a token's price.
 *         It allows to filter out pools with low weight and significantly incorrect price, which could distort the weighted price.
 *         The level of low-weight pool filtering can be managed using the thresholdFilter parameter.
 */
library OraclePrices {
    using SafeMath for uint256;

    /**
    * @title Oracle Price Data Structure
    * @notice This structure encapsulates the rate and weight information for tokens as provided by an oracle
    * @dev An array of OraclePrice structures can be used to represent oracle data for multiple pools
    * @param rate The oracle-provided rate for a token
    * @param weight The oracle-provided derived weight for a token
    */
    struct OraclePrice {
        uint256 rate;
        uint256 weight;
    }

    /**
    * @title Oracle Prices Data Structure
    * @notice This structure encapsulates information about a list of oracles prices and weights
    * @dev The structure is initialized with a maximum possible length by the `init` function
    * @param oraclePrices An array of OraclePrice structures, each containing a rate and weight
    * @param maxOracleWeight The maximum weight among the OraclePrice elements in the oraclePrices array
    * @param size The number of meaningful OraclePrice elements added to the oraclePrices array
    */
    struct Data {
        uint256 maxOracleWeight;
        uint256 size;
        OraclePrice[] oraclePrices;
    }

    /**
    * @notice Initializes an array of OraclePrices with a given maximum length and returns it wrapped inside a Data struct
    * @dev Uses inline assembly for memory allocation to avoid array zeroing
    * @param maxArrLength The maximum length of the oraclePrices array
    * @return data Returns an instance of Data struct containing an OraclePrice array with a specified maximum length
    */
    function init(uint256 maxArrLength) internal pure returns (Data memory data) {
        OraclePrice[] memory oraclePrices;
        assembly ("memory-safe") { // solhint-disable-line no-inline-assembly
            oraclePrices := mload(0x40)
            mstore(0x40, add(oraclePrices, add(0x20, mul(maxArrLength, 0x40))))
            mstore(oraclePrices, maxArrLength)
        }
        data = Data(0, 0, oraclePrices);
    }

    /**
    * @notice Appends an OraclePrice to the oraclePrices array in the provided Data struct if the OraclePrice has a non-zero weight
    * @dev If the weight of the OraclePrice is greater than the current maxOracleWeight, the maxOracleWeight is updated. The size (number of meaningful elements) of the array is incremented after appending the OraclePrice.
    * @param data The Data struct that contains the oraclePrices array, maxOracleWeight, and the current size
    * @param oraclePrice The OraclePrice to be appended to the oraclePrices array
    * @return isAppended A flag indicating whether the oraclePrice was appended or not
    */
    function append(Data memory data, OraclePrice memory oraclePrice) internal pure returns (bool isAppended) {
        if (oraclePrice.weight > 0) {
            data.oraclePrices[data.size] = oraclePrice;
            data.size++;
            if (oraclePrice.weight > data.maxOracleWeight) {
                data.maxOracleWeight = oraclePrice.weight;
            }
            return true;
        }
        return false;
    }

    /**
    * @notice Calculates the weighted rate from the oracle prices data using a threshold filter
    * @param data The data structure containing oracle prices, the maximum oracle weight and the size of the used oracle prices array
    * @param thresholdFilter The threshold to filter oracle prices based on their weight
    * @return weightedRate The calculated weighted rate
    * @return totalWeight The total weight of the oracle prices that passed the threshold
    */
    function getRateAndWeight(Data memory data, uint256 thresholdFilter) internal pure returns (uint256 weightedRate, uint256 totalWeight) {
        for (uint256 i = 0; i < data.size; i++) {
            if (data.oraclePrices[i].weight * 100 < data.maxOracleWeight * thresholdFilter) {
                continue;
            }
            weightedRate += data.oraclePrices[i].rate * data.oraclePrices[i].weight;
            totalWeight += data.oraclePrices[i].weight;
        }
        if (totalWeight > 0) {
            unchecked { weightedRate /= totalWeight; }
        }
    }

    /**
    * @notice See `getRateAndWeight`. It uses SafeMath to prevent overflows.
    */
    function getRateAndWeightWithSafeMath(Data memory data, uint256 thresholdFilter) internal pure returns (uint256 weightedRate, uint256 totalWeight) {
        for (uint256 i = 0; i < data.size; i++) {
            if (data.oraclePrices[i].weight * 100 < data.maxOracleWeight * thresholdFilter) {
                continue;
            }
            (bool ok, uint256 weightedRateI) = data.oraclePrices[i].rate.tryMul(data.oraclePrices[i].weight);
            if (ok) {
                (ok, weightedRate) = _tryAdd(weightedRate, weightedRateI);
                if (ok) totalWeight += data.oraclePrices[i].weight;
            }
        }
        if (totalWeight > 0) {
            unchecked { weightedRate /= totalWeight; }
        }
    }

    function _tryAdd(uint256 value, uint256 addition) private pure returns (bool, uint256) {
        unchecked {
            uint256 result = value + addition;
            if (result < value) return (false, value);
            return (true, result);
        }
    }
}
