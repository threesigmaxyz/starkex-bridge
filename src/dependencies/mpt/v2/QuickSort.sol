// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// https://gist.github.com/subhodi/b3b86cc13ad2636420963e692a4d896f

library QuickSort {
    struct Items {
        uint256[] keys;
        uint256[] values;
    }

    function sort(bytes32[] memory data) internal pure returns (bytes32[] memory) {
        quickSort(data, int256(0), int256(data.length - 1));
        return data;
    }

    function quickSort(bytes32[] memory arr, int256 left, int256 right) internal pure {
        int256 i = left;
        int256 j = right;
        if (i == j) return;
        uint256 pivot = uint256(arr[uint256(left + (right - left) / 2)]);
        while (i <= j) {
            while (uint256(arr[uint256(i)]) < pivot) i++;
            while (pivot < uint256(arr[uint256(j)])) j--;
            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
                i++;
                j--;
            }
        }
        if (left < j) {
            quickSort(arr, left, j);
        }
        if (i < right) {
            quickSort(arr, i, right);
        }
    }
}
