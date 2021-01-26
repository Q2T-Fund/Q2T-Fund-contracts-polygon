import React, { useState } from "react";
// ethers to interact with the Ethereum network and our contract
import { ethers } from "ethers";

// contract's artifacts and address here
import ConnectWallet from './ConnectWallet'
import NoWalletDetected from './NoWalletDetected'
import { SkillWallet } from "./skillWallet";


// Here's a list of network ids https://docs.metamask.io/guide/ethereum-provider.html#properties
// to use when deploying to other networks.
const HARDHAT_NETWORK_ID = '31337';

// This is an error code that indicates that the user canceled a transaction
const ERROR_CODE_TX_REJECTED_BY_USER = 4001;



const App = () => {
    const [address, setAddress] = useState(undefined)
    const [networkError, setNetworkError] = useState(undefined)



    const _connectWallet = async () => {
        const addresses = await window.ethereum.enable()
        await SkillWallet.init(addresses[0]);
        await SkillWallet.store({
            skillWallet: [{ skill: 'Teaching', level: 8 }, { skill: 'Gardening', level: 9 }]
        });
        const res = await SkillWallet.get();

        console.log(res);

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