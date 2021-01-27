import { storeSkillWallet, getSkillWalletByID, initialize } from "./threaddb.config";
import { ThreeIdConnect, EthereumAuthProvider } from '3id-connect'
import Ceramic from '@ceramicnetwork/http-client'
import { IDX } from '@ceramicstudio/idx'
require('dotenv').config();


/**
 * SkillWallet class providing functionality for connecting to 
 * a user skill wallet with Metamask. 
 * Before using it, it should be initialized with a certain user address
 */
export class SkillWallet {

    static isInitialized = false;
    static async init(address) {
        const threeIdConnect = new ThreeIdConnect()

        this.ceramic = new Ceramic()
        this.idx = new IDX({ ceramic: this.ceramic })

        const authProvider = new EthereumAuthProvider(window.ethereum, address)
        await threeIdConnect.connect(authProvider)
        const didProvider = await threeIdConnect.getDidProvider()
        await this.ceramic.setDIDProvider(didProvider)

        SkillWallet.isInitialized = true;

    }

    static async store(obj) {
        if (!SkillWallet.isInitialized) {
            throw Error('Skill Wallet not initialized.');
        }
        const ids = await storeSkillWallet(obj)
        const skillWallet = {
            skillWalletID: ids[0]
        }
        await this.idx.set(process.env.REACT_APP_IDX_DEFINITION_ID, skillWallet);
    }

    static async get() {
        if (!SkillWallet.isInitialized) {
            throw Error('Skill Wallet not initialized.');
        }
        const idxRes = await this.idx.get(process.env.REACT_APP_IDX_DEFINITION_ID);
        const wallet = await getSkillWalletByID(idxRes.skillWalletID)
        return wallet;
    }


}