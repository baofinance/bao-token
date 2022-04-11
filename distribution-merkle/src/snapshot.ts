import fs from 'fs'
import { utils, BigNumber } from 'ethers'
import axios from 'axios'

const checkDupes = () => {
  const snapshot = JSON.parse(fs.readFileSync(`${__dirname}/../snapshot.json`).toString())

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
  console.log(`Total locked BAO: ${total.toString()} or ${utils.formatUnits(total.toString())}`)
  console.log(`Equivalent with new cap: ${newTotal.toString()}`)
}

const fetchLockedBalances = async () => {
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

  for (let i = 0;;i += 1000) {
    const query = getQuery(i)
    const { data: mainnet } = await axios.post('https://api.thegraph.com/subgraphs/name/n0xmare/locked-bao-mainnet', { query })
    if (mainnet.errors) break

    lockedBalances = lockedBalances.concat(
      mainnet.data.accounts.map((account: any) => ({
        address: account.id,
        amount: account.amountOwed
      }))
    )
  }

  const mainnetAddresses = lockedBalances.map((account: any) => account.address)

  for (let i = 1000;;i += 1000) {
    const query = getQuery(i)
    const { data: xdai } = await axios.post(
      'https://api.thegraph.com/subgraphs/name/n0xmare/locked-bao-xdai',
      { query }
    )
    if (xdai.errors) break

    for (let j = 0; j < xdai.data.accounts.length; j++) {
      const account = xdai.data.accounts[j];
      const index = mainnetAddresses.indexOf(account.id)

      if (index >= 0) {
        lockedBalances[index].amount = BigNumber
          .from(lockedBalances[index].amount)
          .add(account.amountOwed)
          .toString()
      } else {
        lockedBalances.push({
          address: account.id,
          amount: account.amountOwed.toString()
        })
      }
    }
  }

  lockedBalances = lockedBalances.sort((a: any, b: any): number => {
    return BigNumber.from(a.amount).gt(BigNumber.from(b.amount)) ? -1 : 1
  })

  fs.writeFileSync(`${__dirname}/../snapshot.json`, JSON.stringify(lockedBalances, null, 2))
}

const main = async () => {
  console.log('Fetching mainnet data from subgraph...')
  await fetchLockedBalances()
  console.log('Done!\n')

  console.log('Checking for duplicates and computing totals...')
  checkDupes()
}

main()