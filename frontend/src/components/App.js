import React, { useState } from "react";

// contract's artifacts and address here
import NoWalletDetected from './NoWalletDetected'
import HomePage from "./HomePage"

const App = () => {

    // TO DO: use ConnectWallet.js to update the state of the app
    // in this fashion:
    // const { address } = state
    // instead of being sourced from a function
    const [address, setAddress] = useState(undefined)

    if (window.ethereum === undefined) {
        return (<NoWalletDetected />)
    }

    if (!address) {
        return (
            //<ConnectWallet connectWallet={() => _connectWallet()}/>
            <HomePage />
        )
    }

    // now actual functionality

    return (<>
        <h2>welcome {address}</h2>
        <p>lot's to be done here! :)</p>
    </>)



}

export default App;