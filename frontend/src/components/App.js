import React, { useState } from "react";
import Web3 from 'web3';
import WalletConnectProvider from '@walletconnect/web3-provider'

// ethers to interact with the Ethereum network and our contract
import { ethers } from "ethers";

// contract's artifacts and address here

import ConnectWallet from './ConnectWallet'
import NoWalletDetected from './NoWalletDetected'

import { ThreeIdConnect, EthereumAuthProvider } from '3id-connect'
// import { getSkillWalletByID, storeSkillWallet } from './threaddb.config';
 import { createDefinition, publishSchema } from '@ceramicstudio/idx-tools'
import Ceramic from '@ceramicnetwork/http-client'
import { IDX } from '@ceramicstudio/idx'
import Web3Modal from 'web3modal';

// Here's a list of network ids https://docs.metamask.io/guide/ethereum-provider.html#properties
// to use when deploying to other networks.
const HARDHAT_NETWORK_ID = '31337';

// This is an error code that indicates that the user canceled a transaction
const ERROR_CODE_TX_REJECTED_BY_USER = 4001;



const App = () => {
    const [address, setAddress] = useState(undefined)
    const [networkError, setNetworkError] = useState(undefined)
    const threeIdConnect = new ThreeIdConnect()


    const DiToSkillWalletIDXSchema =
    {
        $schema: 'http://json-schema.org/draft-07/schema#',
        type: "object",
        properties: {
            "skillWalletID": {
                "type": "string"
            }
        },
        required: [
            "skillWalletID"
        ],
        title: "DiToSkillWallet",
    }

    // const getProvider = async () => {
    //     const addresses = await window.ethereum.enable()
    //     setAddress(addresses);
    //     const authProvider = new EthereumAuthProvider(window.ethereum, addresses[0])
    //     await threeIdConnect.connect(authProvider)
    //     const didProvider = await threeIdConnect.getDidProvider()
    //     return didProvider;
    // }

    
 const web3Modal = new Web3Modal({
    network: 'mainnet',
    cacheProvider: true,
    providerOptions: {
      walletconnect: {
        package: WalletConnectProvider,
        options: {
          infuraId: 'e87f83fb85bf4aa09bdf6605ebe144b7',
        },
      }
    },
  })
  
  const getProvider = async () => {
    const ethProvider = await web3Modal.connect()
    const addresses = await ethProvider.enable()
    await threeIdConnect.connect(new EthereumAuthProvider(ethProvider, addresses[0]))
    return threeIdConnect.getDidProvider()
  }



    const createCeramic = async () => {
        const ceramic = new Ceramic()
        window.ceramic = ceramic
        return Promise.resolve(ceramic)
    }

    const authenticate = async () => {
        const [ceramic, provider] = await Promise.all([ceramicPromise, getProvider()])
        await ceramic.setDIDProvider(provider)
        const idx = createIDX(ceramic)
        window.did = ceramic.did
        console.log(idx);
        const schema = await publishSchema(ceramic, { content: DiToSkillWalletIDXSchema, name: 'DiToSkillWallet' })
        console.log('schema created')
        console.log(schema);
        const definition = await createDefinition(ceramic, {
            name: 'SkillWallet',
            description: 'The Distributed Town Skill Wallet deffinition',
            schema: schema.commitId.toUrl(),
        })
        console.log(definition);
        console.log('definition created');

        return idx.id
    }

    const createIDX = (ceramic) => {
        const idx = new IDX({ ceramic })
        window.idx = idx
        return idx
    }
    const ceramicPromise = createCeramic()

    const _connectWallet = async () => {



        await authenticate();

        // console.log('storing in threaddb')
        // const ids = await storeSkillWallet({
        //     skillWallet: [{ skill: 'Teaching', level: 8 }, { skill: 'Gardening', level: 9 }]
        // })
        // console.log('stored in threaddb')

        // console.log(ids);
        // const skillWallet = {
        //     skillWalletID: ids[0]
        // }

        // console.log('setting skill wallet');
        // const skillWalletStored = await idx.set(definition.id.toString(), skillWallet);
        // console.log('skillWalletStored', skillWalletStored);

        // const getResult = await idx.get(definition.id.toString());
        // console.log('get result: ', getResult)

        // const fromDB = await getSkillWalletByID(ids[0])
        // console.log('result from threaddb');
        // console.log(fromDB)

        // right now hardhat, changeable
        if (window.ethereum.networkVersion !== HARDHAT_NETWORK_ID) {
            setNetworkError("Please connect Metamask to Localhost:8545")
        }

        // setAddress(addresses)
        _initializeEthers(address)


        // We reinitialize it whenever the user changes their account.
        window.ethereum.on("accountsChanged", ([newAddress]) => {

            if (newAddress === undefined) {
                setAddress(undefined)
            }

            _initializeEthers(newAddress)
        })

    }

    const _initializeEthers = async () => {
        const _provider = new ethers.providers.Web3Provider(window.ethereum);

        {/*
        this._dito = new ethers.Contract({
            contractAddress.DiTo, 
            DiToArtifact.abi,
            this._provider.getSigner(0)
        })
        */}
    }




    if (window.ethereum === undefined) {
        return (<NoWalletDetected />)
    }

    if (!address) {
        return (
            <ConnectWallet
                connectWallet={() => _connectWallet()}

            />
        )
    }

    // now actual functionality

    return (
        <>
            <h2>welcome {address}</h2>
            <p>lot's to be done here! :)</p>
        </>
    )



}

export default App;