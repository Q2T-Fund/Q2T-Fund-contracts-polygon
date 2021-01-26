import { publishSchema, createDefinition } from "@ceramicstudio/idx-tools";
import Ceramic from '@ceramicnetwork/http-client';

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

const init = async () => {

    const ceramic = new Ceramic();
    const ceramic = undefinded;
    const schema = await publishSchema(ceramic, { content: DiToSkillWalletIDXSchema, name: 'DiToSkillWallet' })
    const definition = await createDefinition(ceramic, {
        name: 'SkillWallet',
        description: 'The Distributed Town Skill Wallet deffinition',
        schema: schema.commitId.toUrl(),
    })
    console.log(definition.id.toString());

}


init()
    .then(r => console.log('Schema and definition created.'))
    .catch(err => console.log(err));