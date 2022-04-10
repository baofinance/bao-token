import { MerkleTree } from 'merkletreejs'
import { ethers } from 'ethers'
import fs from 'fs'

// -------------------------------
// TYPES
// -------------------------------

type Account = {
  address: string
  amount: string
}

// -------------------------------
// MERKLE ROOT GENERATION
// -------------------------------

const generateMerkleRoot = () => {
  const snapshot: Account[] =
    JSON.parse(fs.readFileSync(`${__dirname}/../snapshot.json`).toString())

  const leaves = snapshot.map(account => _keccakAbiEncode(account.address, account.amount))
  const tree = new MerkleTree(leaves, ethers.utils.keccak256, { sort: true })
  const root = tree.getRoot().toString('hex')
  console.log(`Merkle Root: 0x${root}`)

  console.log('-------------------------------------------------------------------------------')

  const leaf = _keccakAbiEncode(snapshot[0].address, snapshot[0].amount)
  const proof = tree.getHexProof(leaf)
  console.log(`Sample proof of inclusion for address "${snapshot[0].address}": ${JSON.stringify(proof)}`)
  console.log(`Is proof valid?: ${tree.verify(proof, leaf, root) ? 'Yes' : 'No'}`) // should always be yes!
}

const _keccakAbiEncode = (a: string, n: string): string =>
  ethers.utils.keccak256(ethers.utils.solidityPack(['address', 'uint256'], [a, n]))

generateMerkleRoot()