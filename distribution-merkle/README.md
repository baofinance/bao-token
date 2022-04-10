# BAOv2 Distribution Merkle Tree

Accounts that can verify their inclusion in the merkle tree generated from `snapshot.json` will be eligible to start their BAOv2 distribution.

### Tree Leaves
The merkle tree's leaves consist of the address and the balance of locked BAO owed to them. 

In solidity:
```solidity
bytes32 leaf = keccak256(abi.encodePacked(address, amount));
```

In typescript (with `ethers.js`):
```typescript
const getLeaf = (address: string, amount: string): string =>
  ethers.utils.keccak256(
    ethers.utils.solidityPack(
      ['address', 'uint256'],
      [address, amount]
    )
  );
```