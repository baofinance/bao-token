import fs from 'fs'
import { ethers, utils, BigNumber } from 'ethers'
import axios from 'axios'
import baoV1Abi from './abi/baov1.json'

// -------------------------------
// CONSTANTS
// -------------------------------

const SNAPSHOT_FILE = `${__dirname}/../snapshot.json`

// -------------------------------
// SNAPSHOT VERIFICATION
// -------------------------------

const verifySnapshot = async () => {
  console.log('Checking for duplicates and computing totals...')
  const snapshot = JSON.parse(fs.readFileSync(SNAPSHOT_FILE).toString())

  const mainnetProvider = new ethers.providers.AlchemyProvider()
  const bao = new ethers.Contract('0x374CB8C27130E2c9E04F44303f3c8351B9De61C1', baoV1Abi, mainnetProvider)
  const xdaiProvider = new ethers.providers.JsonRpcProvider('https://rpc.gnosischain.com/')
  const baoCx = new ethers.Contract('0xe0d0b1DBbCF3dd5CAc67edaf9243863Fd70745DA', baoV1Abi, xdaiProvider)

  const mainnetLocked = await bao.lockedSupply()
  const xdaiLocked = await baoCx.lockedSupply()

  const exists = []
  let total = BigNumber.from(0)
  let newTotal = BigNumber.from(0)
  snapshot.forEach((account: any) => {
    if (exists.includes(account.address)) console.log('DUPLICATE')
    total = total.add(BigNumber.from(account.amount))
    newTotal = newTotal.add(BigNumber.from(account.amount).div(1e4))
    exists.push(account.address)
  })

  console.log('Done!')
  console.log(`Accounts: ${exists.length}`)
  console.log(`Total locked BAO: ${total.toString()} or ${utils.formatUnits(total.toString())}`)
  console.log(`Equivalent with new cap: ${newTotal.toString()}`)
  console.log(
    `Actual Locked Balances: ${
      mainnetLocked.toString()
    } (ETH) | ${xdaiLocked.toString()} (XDAI) | ${mainnetLocked.add(xdaiLocked).toString()} (TOTAL)`
  )
  console.log(`Snapshot valid?: ${mainnetLocked.add(xdaiLocked).eq(total) ? 'Yes' : 'No'}`) // Should always be yes!
}

// -------------------------------
// SNAPSHOT GENERATION
// -------------------------------

const takeSnapshot = async () => {
  let lockedBalances = []

  const getQuery = (i: number) =>
    `
      query {
        accounts(skip:${i},first:1000) {
          id
          amountOwed
        }
      }
    `

  console.log('Fetching mainnet data from subgraph...')
  for (let i = 0;;i += 1000) {
    const query = getQuery(i)
    const { data: mainnet } = await axios.post(
      'https://api.thegraph.com/subgraphs/name/n0xmare/locked-bao-mainnet',
      { query }
    )
    if (mainnet.errors) break

    lockedBalances = lockedBalances.concat(
      mainnet.data.accounts.map((account: any) => ({
        address: account.id,
        amount: account.amountOwed
      }))
    )
  }

  const mainnetAddresses = lockedBalances.map((account: any) => account.address)
  console.log(`Done! Found ${mainnetAddresses.length} addresses.`)

  console.log('Fetching xdai data from subgraph and merging datasets...')
  let updated = 0
  let newAddresses = 0
  for (let i = 0;;i += 1000) {
    const query = getQuery(i)
    const { data: xdai } = await axios.post(
      'https://api.thegraph.com/subgraphs/name/n0xmare/locked-bao-xdai',
      { query }
    )
    if (xdai.errors) break

    for (let j = 0; j < xdai.data.accounts.length; j++) {
      const account = xdai.data.accounts[j]
      const index = mainnetAddresses.indexOf(account.id)

      if (index >= 0) {
        lockedBalances[index].amount = BigNumber
          .from(lockedBalances[index].amount)
          .add(account.amountOwed)
          .toString()
        updated++
      } else {
        lockedBalances.push({
          address: account.id,
          amount: account.amountOwed.toString()
        })
        newAddresses++
      }
    }
  }

  console.log(`Done! Updated balances for ${updated} addresses and found ${newAddresses} new addresses.`)

  lockedBalances = lockedBalances.sort((a: any, b: any): number => {
    return BigNumber.from(a.amount).gt(BigNumber.from(b.amount)) ? -1 : 1
  })

  fs.writeFileSync(SNAPSHOT_FILE, JSON.stringify(lockedBalances, null, 2))
  console.log('Done! Results written to snapshot.json')
}

const main = async () => {
  await takeSnapshot()
  console.log()
  await verifySnapshot()
}

main()