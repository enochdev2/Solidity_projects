// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IEigenPod} from "src/eigenlayer/IEigenPod.sol";

/**
 * @dev
 * Holesky EigenLayerBeaconOracle proof for validatorIndex `1686451`, slot `1452883`, timestamp `1713336996`
 * Generated using: https://github.com/Layr-Labs/eigenpod-proofs-generation
 */
abstract contract WithdrawalCredentialsProof {
    uint256 internal validatorIndex = 1686451;
    uint256 internal slot = 1452883;
    uint64 internal oracleTimestamp = 1713336996;

    IEigenPod.StateRootProof internal stateRootProof;
    uint40[] internal validatorIndices;
    bytes[] internal validatorFieldsProofs;
    bytes32[][] internal validatorFields;

    constructor() {
        stateRootProof = IEigenPod.StateRootProof({
            beaconStateRoot: 0x210589cea4616593f79eb0dcc876b984ec95f7fa733dd1588aba79ec0955a806,
            proof: abi.encode(
                [
                    0x9a1135f9ad9c088ef345d8189945c8f2e1e4215e93e4356c3f95dedaa0bbb45c,
                    0x3936950afdc6c0364e4429dd9d87ba4ca23c21d25b7db1a6ddfd3ebbc9c65057,
                    0x6e5f3363181dfa27aa61b0c7b8666e43ff9acb0147abccf7cb38ea4b1127d669
                ]
                )
        });

        validatorIndices.push(1686451);

        validatorFieldsProofs.push(
            abi.encode(
                [
                    0x210e3ece86fd265e333f6f45baf0bb41c1bd51b85ae54d8287f6054a0856d806,
                    0xd457bc49d40e7ab0d684b52b5c06ca4a2134111f1c3b2c623b90fe0535b34df4,
                    0xfed9af31e20b80747b275aaea3ed43f4aecc583ed3fb54a9d4f4355b69db7e96,
                    0x312c25cd573b224739b89e286c3e2accf77e72699cec88ac68b5cf419b89b909,
                    0x871802aca59f57cbf1b2b39af76bc3470c4900f117d583f9608b265e7628f9bd,
                    0x98925bb686aece65904afc0538ec976f17159a4299ebf8aecb5a5e2cf52d6b0f,
                    0xcf13a9d0d595e55d12e99c2c9d131844bd201b755ee1e68247f1414e769bca45,
                    0x8cde05eb6a8d6a5d337aec26d44e2e5805c58d880ef0eb43484afd808d0ef296,
                    0x5d0641d765e557c09bc0e20b543ea6d480ac8e78fd75a65beb908db39749f2b8,
                    0xa8d9ef940e083054e4fa65f2eb8ad38655efcf7b45f2fa665f162277c6367fce,
                    0x4b7f33209be23e1324d4cb129b214a23cdfe75d02af3f8959e684820255e57c0,
                    0x1bf0a8982170e0f6182a6f1055e227c3045d39003d4066d78fec1abd06bd64d8,
                    0x9ecabcce82d99f7ba9573fd8d33cbcb71a4e4625502f6f2b7a714cc1010509c4,
                    0x6e4db7482cddb221333cd959b1264008b2f54937c3988882dd9705c0c329ad25,
                    0x0beba2636f9c6e384635c73669d2361517b3a30ca6f96b8ab5092521634289f7,
                    0x30245952eb5aea20b936d37cb9ae403c9fad9b4d493508d9238aba6513b96343,
                    0x1f31ce43f310ef4ff4b30dcaa4f37a53142dc342a408f5212281ec170fce6c40,
                    0x8d0d63c39ebade8509e0ae3c9c3876fb5fa112be18f905ecacfecb92057603ab,
                    0x95eec8b2e541cad4e91de38385f2e046619f54496c2382cb6cacd5b98c26f5a4,
                    0x6c33c137633f32d32a3a6c360bf640410b9ebdf96349c5d59689fca7bdd07f56,
                    0x9cc30fab754c5dd3c7bd7687df88952c7c7c5990f59a577719f4914ceb8f5db4,
                    0x8a8d7fe3af8caa085a7639a832001457dfb9128a8061142ad0335629ff23ff9c,
                    0xfeb3c337d7a51a6fbf00b9e34c52e1c9195c969bd4e7a0bfd51d5c5bed9c1167,
                    0xe71f0aa83cc32edfbefa9f4d3e0174ca85182eec9f3a09f6a6c0df6377a510d7,
                    0x31206fa80a50bb6abe29085058f16212212a60eec8f049fecb92d8c8e0a84bc0,
                    0x21352bfecbeddde993839f614c3dac0a3ee37543f9b412b16199dc158e23b544,
                    0x619e312724bb6d7c3153ed9de791d764a366b389af13c58bf8a8d90481a46765,
                    0x7cdd2986268250628d0c10e385c58c6191e6fbe05191bcc04f133f2cea72c1c4,
                    0x848930bd7ba8cac54661072113fb278869e07bb8587f91392933374d017bcbe1,
                    0x8869ff2c22b28cc10510d9853292803328be4fb0e80495e8bb8d271f5b889636,
                    0xb5fe28e79f1b850f8658246ce9b6a1e7b49fc06db7143e8fe0b4f2b0c5523a5c,
                    0x985e929f70af28d0bdd1a90a808f977f597c7c778c489e98d3bd8910d31ac0f7,
                    0xc6f67e02e6e4e1bdefb994c6098953f34636ba2b6ca20a4721d2b26a886722ff,
                    0x1c9a7e5ff1cf48b4ad1582d3f4e4a1004f3b20d8c5a2b71387a4254ad933ebc5,
                    0x2f075ae229646b6f6aed19a5e372cf295081401eb893ff599b3f9acc0c0d3e7d,
                    0x328921deb59612076801e8cd61592107b5c67c79b846595cc6320c395b46362c,
                    0xbfb909fdb236ad2411b4e4883810a074b840464689986c3f8a8091827e17c327,
                    0x55d8fb3687ba3ba49f342c77f5a1f89bec83d811446e1a467139213d640b6a74,
                    0xf7210d4f8e7e1039790e7bf4efa207555a10a6db1dd4b95da313aaa88b88fe76,
                    0xad21b516cbc645ffe34ab5de1c8aef8cd4e7f8d2b51e8e1456adc7563cda206f,
                    0x3ec5190000000000000000000000000000000000000000000000000000000000,
                    0x6ec8030000000000000000000000000000000000000000000000000000000000,
                    0x9748d351fa588799bb1e0df9d1bf0ff0f9087451bcc396637554edc4f83f97f7,
                    0x5f1e9e88e49cd62bf053184116eb538c61712156b4252aae5b4ba619649c60f2,
                    0x768e3479c1da76247c95c5143632bde86ec98a841b5f7fc6cd17cf4b0ca19a01,
                    0x6ede9fb7ee61deef2553a09e907f47532bfcd6d68792ff1c33fef768c88eab17
                ]
            )
        );

        bytes32[] memory validatorField = new bytes32[](8);
        validatorField[0] = 0x4e0ab4be0a464977de0b0bb9941e2999300c37d6ef21a0a2a96e706c643aebd0;
        validatorField[1] = 0x01000000000000000000000097865de5624fa6eed5972588394e1afe9236f33b;
        validatorField[2] = 0x0040597307000000000000000000000000000000000000000000000000000000;
        validatorField[3] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        validatorField[4] = 0xa5ac000000000000000000000000000000000000000000000000000000000000;
        validatorField[5] = 0xffffffffffffffff000000000000000000000000000000000000000000000000;
        validatorField[6] = 0xffffffffffffffff000000000000000000000000000000000000000000000000;
        validatorField[7] = 0xffffffffffffffff000000000000000000000000000000000000000000000000;

        validatorFields.push(validatorField);
    }
}

abstract contract MultiProof {
    uint256 internal slot = 1498256;
    uint64 internal oracleTimestamp = 1713881472;

    IEigenPod.StateRootProof internal stateRootProof;
    uint40[] internal validatorIndices;
    bytes[] internal validatorFieldsProofs;
    bytes32[][] internal validatorFields;

    constructor() {
        stateRootProof = IEigenPod.StateRootProof({
            beaconStateRoot: 0x46739023d1b2607369d05428c9ea0cd560b131418664ba24e1691f706d780725,
            proof: abi.encode(
                [
                    0x9b077426e0936c7f7d17f8621cceceebb45d445a85a9a313eb87788861faf59b,
                    0x4758103998471df701fb616864ebc19290e5d83f28cb35ab2f6e48d5501f1074,
                    0x4937371479e306f06ac330aa06786f798620e74f56ebdaf4708bfd47f10b10b6
                ]
                )
        });

        validatorIndices.push(1689033);
        validatorIndices.push(1689043);

        validatorFieldsProofs.push(
            abi.encode(
                [
                    0x9d3a97858e97b2faa066799f4b9556f209c3ba25ba7741ed15562f61932d2ead,
                    0x4e70078a1cdc8e56fa8cfbd8570a4c3c2bd95536f5a9a2c3e03be4054f5a014d,
                    0xd4713030e4258cc636aafb8093c78db5dbb66bc96c9e65d4309a75adea484489,
                    0x20a87b38c88017123888678cac9fd79d23b46abb1ce90404839105dcb96208eb,
                    0x2738651d75f1950b5ba5a3b339214ed5589f609a6077835b95ec54c561763bcb,
                    0x71ff8639ae4c908843063957b62f8442c797b9d5e5447689f7baa3c65d0039cd,
                    0xa8082d79e0f967affcff992b654d858748fc3716b2eb0700727ad095d2fd3060,
                    0xf4d54d0885a9f355a7e84f1bc701547dc9096da0570cef1b3b23e41ab818e427,
                    0xe49d12a5981e0a6b53a38f01d39d3f3364ca2bc5c2d70b7a304d53f17f3219a4,
                    0x716d8ce4684350f0e59f684f5a316d76379d0cc9183e2d933b9511bf9e473506,
                    0x05fc2771e5c5e6f592c8168a7b201a8009d81f631e8a399288666530a059bf22,
                    0x0d486915d17d54a482c5765df00dcec831d0a52c48bc9a8f537ce461e048cbc7,
                    0x5be072bda54c51ae8da2ad84a3754618abbb9d209eaa1bd024afb80857bd7026,
                    0xdf6af5f5bbdb6be9ef8aa618e4bf8073960867171e29676f8b284dea6a08a85e,
                    0xacc597c35b6eecea975ffd3c0758c0e376611ce705e9001e5a6fee8da3f0238b,
                    0x9289933c7fc16f99a0fe5d0fb82086aea9f6cade28b64a0171118bd21d084264,
                    0x71fefd8995369a729676a2f86ad6e928db47815010c26c035fc29827688dfa73,
                    0x8d0d63c39ebade8509e0ae3c9c3876fb5fa112be18f905ecacfecb92057603ab,
                    0x95eec8b2e541cad4e91de38385f2e046619f54496c2382cb6cacd5b98c26f5a4,
                    0xcf816460c2fbe68680f40f868f45b45ba45ca5fcdf4a9f85597a880bece97838,
                    0xaa2e6d6562ebd016f234ba0ea9b278e4b059deca8a5d698c96efbbfeb6f8d3c3,
                    0x8a8d7fe3af8caa085a7639a832001457dfb9128a8061142ad0335629ff23ff9c,
                    0xfeb3c337d7a51a6fbf00b9e34c52e1c9195c969bd4e7a0bfd51d5c5bed9c1167,
                    0xe71f0aa83cc32edfbefa9f4d3e0174ca85182eec9f3a09f6a6c0df6377a510d7,
                    0x31206fa80a50bb6abe29085058f16212212a60eec8f049fecb92d8c8e0a84bc0,
                    0x21352bfecbeddde993839f614c3dac0a3ee37543f9b412b16199dc158e23b544,
                    0x619e312724bb6d7c3153ed9de791d764a366b389af13c58bf8a8d90481a46765,
                    0x7cdd2986268250628d0c10e385c58c6191e6fbe05191bcc04f133f2cea72c1c4,
                    0x848930bd7ba8cac54661072113fb278869e07bb8587f91392933374d017bcbe1,
                    0x8869ff2c22b28cc10510d9853292803328be4fb0e80495e8bb8d271f5b889636,
                    0xb5fe28e79f1b850f8658246ce9b6a1e7b49fc06db7143e8fe0b4f2b0c5523a5c,
                    0x985e929f70af28d0bdd1a90a808f977f597c7c778c489e98d3bd8910d31ac0f7,
                    0xc6f67e02e6e4e1bdefb994c6098953f34636ba2b6ca20a4721d2b26a886722ff,
                    0x1c9a7e5ff1cf48b4ad1582d3f4e4a1004f3b20d8c5a2b71387a4254ad933ebc5,
                    0x2f075ae229646b6f6aed19a5e372cf295081401eb893ff599b3f9acc0c0d3e7d,
                    0x328921deb59612076801e8cd61592107b5c67c79b846595cc6320c395b46362c,
                    0xbfb909fdb236ad2411b4e4883810a074b840464689986c3f8a8091827e17c327,
                    0x55d8fb3687ba3ba49f342c77f5a1f89bec83d811446e1a467139213d640b6a74,
                    0xf7210d4f8e7e1039790e7bf4efa207555a10a6db1dd4b95da313aaa88b88fe76,
                    0xad21b516cbc645ffe34ab5de1c8aef8cd4e7f8d2b51e8e1456adc7563cda206f,
                    0x1dd5190000000000000000000000000000000000000000000000000000000000,
                    0xa4d8030000000000000000000000000000000000000000000000000000000000,
                    0x578656cb2c044b890f51d085f9fe66a686d4ce8337c7b91edbe9ae707f6e6fdc,
                    0x5c724655da30866e687671927c31c8e0a8ca89edf38215bd01e088758addb80c,
                    0xa9205869ffca820efa68a9699702578942730cf520d3aa81f2e77ab3c9fd1b2d,
                    0xd32ff2ab91da9b0bae1c23d3c7c6538be753751388bf0021bc6e774efde49493
                ]
            )
        );

        validatorFieldsProofs.push(
            abi.encode(
                [
                    0xf5c78dd83132c7bfa844090682e8fa1dfcddfdbb05077f35767d56d6d7a72550,
                    0x1213b7dac81e71f860c858d8cad2b69452322e0f38b7b741ff14b656ec868738,
                    0xc45004846f814e390fd83431896a3709a1f9bfc760c0d363ab8a4b044a24a08e,
                    0x766a0036c4769623ce6bbcfe85732b8f156c72d0723ff6cda8ec5b959b2085d0,
                    0xef25183f336909a708ee296ca399c50e2887db7fd86a1e03c457fb924b615575,
                    0x71ff8639ae4c908843063957b62f8442c797b9d5e5447689f7baa3c65d0039cd,
                    0xa8082d79e0f967affcff992b654d858748fc3716b2eb0700727ad095d2fd3060,
                    0xf4d54d0885a9f355a7e84f1bc701547dc9096da0570cef1b3b23e41ab818e427,
                    0xe49d12a5981e0a6b53a38f01d39d3f3364ca2bc5c2d70b7a304d53f17f3219a4,
                    0x716d8ce4684350f0e59f684f5a316d76379d0cc9183e2d933b9511bf9e473506,
                    0x05fc2771e5c5e6f592c8168a7b201a8009d81f631e8a399288666530a059bf22,
                    0x0d486915d17d54a482c5765df00dcec831d0a52c48bc9a8f537ce461e048cbc7,
                    0x5be072bda54c51ae8da2ad84a3754618abbb9d209eaa1bd024afb80857bd7026,
                    0xdf6af5f5bbdb6be9ef8aa618e4bf8073960867171e29676f8b284dea6a08a85e,
                    0xacc597c35b6eecea975ffd3c0758c0e376611ce705e9001e5a6fee8da3f0238b,
                    0x9289933c7fc16f99a0fe5d0fb82086aea9f6cade28b64a0171118bd21d084264,
                    0x71fefd8995369a729676a2f86ad6e928db47815010c26c035fc29827688dfa73,
                    0x8d0d63c39ebade8509e0ae3c9c3876fb5fa112be18f905ecacfecb92057603ab,
                    0x95eec8b2e541cad4e91de38385f2e046619f54496c2382cb6cacd5b98c26f5a4,
                    0xcf816460c2fbe68680f40f868f45b45ba45ca5fcdf4a9f85597a880bece97838,
                    0xaa2e6d6562ebd016f234ba0ea9b278e4b059deca8a5d698c96efbbfeb6f8d3c3,
                    0x8a8d7fe3af8caa085a7639a832001457dfb9128a8061142ad0335629ff23ff9c,
                    0xfeb3c337d7a51a6fbf00b9e34c52e1c9195c969bd4e7a0bfd51d5c5bed9c1167,
                    0xe71f0aa83cc32edfbefa9f4d3e0174ca85182eec9f3a09f6a6c0df6377a510d7,
                    0x31206fa80a50bb6abe29085058f16212212a60eec8f049fecb92d8c8e0a84bc0,
                    0x21352bfecbeddde993839f614c3dac0a3ee37543f9b412b16199dc158e23b544,
                    0x619e312724bb6d7c3153ed9de791d764a366b389af13c58bf8a8d90481a46765,
                    0x7cdd2986268250628d0c10e385c58c6191e6fbe05191bcc04f133f2cea72c1c4,
                    0x848930bd7ba8cac54661072113fb278869e07bb8587f91392933374d017bcbe1,
                    0x8869ff2c22b28cc10510d9853292803328be4fb0e80495e8bb8d271f5b889636,
                    0xb5fe28e79f1b850f8658246ce9b6a1e7b49fc06db7143e8fe0b4f2b0c5523a5c,
                    0x985e929f70af28d0bdd1a90a808f977f597c7c778c489e98d3bd8910d31ac0f7,
                    0xc6f67e02e6e4e1bdefb994c6098953f34636ba2b6ca20a4721d2b26a886722ff,
                    0x1c9a7e5ff1cf48b4ad1582d3f4e4a1004f3b20d8c5a2b71387a4254ad933ebc5,
                    0x2f075ae229646b6f6aed19a5e372cf295081401eb893ff599b3f9acc0c0d3e7d,
                    0x328921deb59612076801e8cd61592107b5c67c79b846595cc6320c395b46362c,
                    0xbfb909fdb236ad2411b4e4883810a074b840464689986c3f8a8091827e17c327,
                    0x55d8fb3687ba3ba49f342c77f5a1f89bec83d811446e1a467139213d640b6a74,
                    0xf7210d4f8e7e1039790e7bf4efa207555a10a6db1dd4b95da313aaa88b88fe76,
                    0xad21b516cbc645ffe34ab5de1c8aef8cd4e7f8d2b51e8e1456adc7563cda206f,
                    0x1dd5190000000000000000000000000000000000000000000000000000000000,
                    0xa4d8030000000000000000000000000000000000000000000000000000000000,
                    0x578656cb2c044b890f51d085f9fe66a686d4ce8337c7b91edbe9ae707f6e6fdc,
                    0x5c724655da30866e687671927c31c8e0a8ca89edf38215bd01e088758addb80c,
                    0xa9205869ffca820efa68a9699702578942730cf520d3aa81f2e77ab3c9fd1b2d,
                    0xd32ff2ab91da9b0bae1c23d3c7c6538be753751388bf0021bc6e774efde49493
                ]
            )
        );

        bytes32[] memory validatorField = new bytes32[](8);
        validatorField[0] = 0x95485600fdafc35d2250008755bf6490ee2082389fc1935ec2a2b587fbf683fd;
        validatorField[1] = 0x0100000000000000000000002fab5ed65b0aacc9534e5942ba357e9c17fd37a8;
        validatorField[2] = 0x0040597307000000000000000000000000000000000000000000000000000000;
        validatorField[3] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        validatorField[4] = 0xe7b1000000000000000000000000000000000000000000000000000000000000;
        validatorField[5] = 0xffffffffffffffff000000000000000000000000000000000000000000000000;
        validatorField[6] = 0xffffffffffffffff000000000000000000000000000000000000000000000000;
        validatorField[7] = 0xffffffffffffffff000000000000000000000000000000000000000000000000;

        validatorFields.push(validatorField);

        bytes32[] memory validatorFieldsTwo = new bytes32[](8);

        validatorFieldsTwo[0] = 0xb2727621f10810c77bdc6baad369f204853707de7e5aa0000bddfaa594ef82ad;
        validatorFieldsTwo[1] = 0x0100000000000000000000002fab5ed65b0aacc9534e5942ba357e9c17fd37a8;
        validatorFieldsTwo[2] = 0x0040597307000000000000000000000000000000000000000000000000000000;
        validatorFieldsTwo[3] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        validatorFieldsTwo[4] = 0xe7b1000000000000000000000000000000000000000000000000000000000000;
        validatorFieldsTwo[5] = 0xffffffffffffffff000000000000000000000000000000000000000000000000;
        validatorFieldsTwo[6] = 0xffffffffffffffff000000000000000000000000000000000000000000000000;
        validatorFieldsTwo[7] = 0xffffffffffffffff000000000000000000000000000000000000000000000000;

        validatorFields.push(validatorFieldsTwo);
    }
}
