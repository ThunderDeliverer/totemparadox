import { ethers, run, network } from "hardhat";
import { IERC7508, Minter, MintingUtils, Quest, Resources, Rewards, Totems } from "../typechain-types";
import * as IERC7508json from "../artifacts/@rmrk-team/evm-contracts/contracts/RMRK/extension/tokenProperties/IERC7508.sol/IERC7508.json";
import { BigNumber, Signer } from "ethers";

const IERC7508address = "0xA77b75D5fDEC6E6e8E00e05c707a7CA81a3F9f4a";

async function main() {
  const [owner] = await ethers.getSigners();
  const totems = await deployTotems();
  const attributes = await getAttributesRepository(owner);
  await offsetInitialAttributesSettingCost(attributes, totems, owner);
  const mintingUtils = await deployMintingUtils();
  const minter = await deployMinter(totems.address, mintingUtils.address);
  await assignMinterToTotems(minter, totems);
  const quest = await deployQuest(totems);
  const rewards = await deployRewards(totems);
  /*const resources =*/ await deployResources(rewards);
  await addRewardsToQuest(quest, rewards);
  await addQuestAsTransferabilityManagerOfTotems(quest, totems);
}

async function getAttributesRepository(signer: Signer): Promise<IERC7508> {
  const attributes = new ethers.Contract(IERC7508address, JSON.stringify(IERC7508json.abi), signer);
  console.log(`Connected to ERC-7508 attributes repository at ${IERC7508address}.`);
  return attributes as IERC7508;
}

async function deployTotems(): Promise<Totems> {
  console.log(`Deploying TotemParadox Totems to ${network.name} blockchain...`);

  const contractFactory = await ethers.getContractFactory("Totems");
  const args = [
    "TotemParadox Totems",
    "TOTEM",
    "ipfs://QmYG1p1dEVZb93S7TnVUQZQ4Wz1sU67yAnN32A5BWsvBec",
    ethers.constants.MaxUint256,
    (await ethers.getSigners())[0].address,
    500,
  ] as const;
  const totems: Totems = (await contractFactory.deploy(...args)) as Totems;
  await totems.deployed();
  console.log(`TotemParadox Totems deployed to ${totems.address}.`);

  console.log("Configuring general totems parameters...");
  await totems.updateMaxTierAndStage(3, 3);
  console.log("Configuring general totems parameters done.");

  const chainId = (await ethers.provider.getNetwork()).chainId;
  if (chainId === 31337) {
    console.log("Skipping verify on local chain");
    return totems;
  }

  await run("verify:verify", {
    address: totems.address,
    constructorArguments: args,
  });

  return totems;
}

async function offsetInitialAttributesSettingCost(ierc7508: IERC7508, totems: Totems, owner: Signer): Promise<void> {
  console.log(`Configuring attributes reposiotry access control`);
  await ierc7508.registerAccessControl(totems.address, await owner.getAddress(), true);
  console.log(`Offsetting initial attributes setting cost...`);
  await ierc7508.manageAccessControl(totems.address, "element", 2, ethers.constants.AddressZero);
  await ierc7508.manageAccessControl(totems.address, "stage", 2, ethers.constants.AddressZero);
  await ierc7508.manageAccessControl(totems.address, "tier", 2, ethers.constants.AddressZero);
  await ierc7508.setStringAttribute(totems.address, 0, "element", "infernum"); // These are set, so that the user doesn't
  await ierc7508.setStringAttribute(totems.address, 0, "element", "eternum"); // have to pay for the setting the string
  await ierc7508.setStringAttribute(totems.address, 0, "element", "metamorphium"); // value to the ID representing it.
  await ierc7508.setStringAttribute(totems.address, 0, "element", "genesisium");
  await ierc7508.setStringAttribute(totems.address, 0, "element", "emphatium");
  await ierc7508.setUintAttribute(totems.address, 0, "stage", 0);
  await ierc7508.setUintAttribute(totems.address, 0, "tier", 0);
  console.log(`Offsetting initial attributes setting cost done.`);
}

async function deployMintingUtils(): Promise<MintingUtils> {
  console.log("Deploying MintingUtils...");
  const contractFactory = await ethers.getContractFactory("MintingUtils");
  const mintingUtils = (await contractFactory.deploy()) as MintingUtils;
  await mintingUtils.deployed();
  console.log(`MintingUtils deployed to ${mintingUtils.address}.`);

  console.log("Setting equal distribuion of elements...");
  await mintingUtils.setElementDistribution(
    ["infernum", "eternum", "metamorphium", "genesisium", "emphatium"],
    [BigNumber.from(0), BigNumber.from(2000), BigNumber.from(4000), BigNumber.from(6000), BigNumber.from(8000)],
    [BigNumber.from(1999), BigNumber.from(3999), BigNumber.from(5999), BigNumber.from(7999), BigNumber.from(10000)],
  );
  console.log("Setting equal distribuion of elements done.");

  const chainId = (await ethers.provider.getNetwork()).chainId;
  if (chainId === 31337) {
    console.log("Skipping verify on local chain");
    return mintingUtils;
  }

  await run("verify:verify", {
    address: mintingUtils.address,
    constructorArguments: [],
  });

  return mintingUtils;
}

async function deployMinter(totems: string, mintingUtils: string): Promise<Minter> {
  console.log("Deploying Minter...");
  const contractFactory = await ethers.getContractFactory("Minter");

  const args = [totems, mintingUtils, ethers.utils.parseEther("0.001")] as const;

  const minter = (await contractFactory.deploy(...args)) as Minter;
  await minter.deployed();
  console.log(`Minter deployed to ${minter.address}.`);

  const chainId = (await ethers.provider.getNetwork()).chainId;
  if (chainId === 31337) {
    console.log("Skipping verify on local chain");
    return minter;
  }

  await run("verify:verify", {
    address: minter.address,
    constructorArguments: args,
  });

  return minter;
}

async function assignMinterToTotems(minter: Minter, totems: Totems): Promise<void> {
  console.log("Assigning Minter to Totems...");
  const crafterRole = await totems.CRAFTER_ROLE();
  await totems.grantRole(crafterRole, minter.address);
  console.log("Assigning Minter to Totems done.");
}

async function deployQuest(totems: Totems): Promise<Quest> {
  console.log("Deploying Quest...");
  const contractFactory = await ethers.getContractFactory("Quest");

  const args = [
    "TotemParadox Quests",
    "QUEST",
    "ipfs://QmabN5KdpzgABzk2y6RFoSg7urSyjUe1XdLrczp9mUngZc",
    ethers.constants.MaxUint256,
    totems.address,
    (await ethers.getSigners())[0].address,
  ];

  const quest = (await contractFactory.deploy(...args)) as Quest;
  await quest.deployed();
  console.log(`Quest deployed to ${quest.address}.`);

  console.log("Configuring general quest parameters...");
  await quest.updateQuestJoinTimeBpts(BigNumber.from("1000"));
  await quest.updateMaxTotemsPerInstance(4);
  // await quest.setRewardsAddress(rewards.address);
  console.log("Configuring general quest parameters done.");

  const chainId = (await ethers.provider.getNetwork()).chainId;
  if (chainId === 31337) {
    console.log("Skipping verify on local chain");
    return quest;
  }

  await run("verify:verify", {
    address: quest.address,
    constructorArguments: args,
  });

  return quest;
}

async function deployRewards(totems: Totems): Promise<Rewards> {
  console.log("Deploying Rewards...");
  const contractFactory = await ethers.getContractFactory("Rewards");

  const args = [3, totems.address, (await ethers.getSigners())[0].address];

  const rewards = (await contractFactory.deploy(...args)) as Rewards;
  await rewards.deployed();
  console.log(`Rewards deployed to ${rewards.address}.`);

  const chainId = (await ethers.provider.getNetwork()).chainId;
  if (chainId === 31337) {
    console.log("Skipping verify on local chain");
    return rewards;
  }

  await run("verify:verify", {
    address: rewards.address,
    constructorArguments: args,
  });

  return rewards;
}

async function deployResources(minter: Rewards): Promise<Resources> {
  console.log("Deploying Resources...");
  const contractFactory = await ethers.getContractFactory("Resources");

  const args = [minter.address];

  const resources = (await contractFactory.deploy(...args)) as Resources;
  await resources.deployed();
  console.log(`Resources deployed to ${resources.address}.`);

  const chainId = (await ethers.provider.getNetwork()).chainId;
  if (chainId === 31337) {
    console.log("Skipping verify on local chain");
    return resources;
  }

  await run("verify:verify", {
    address: resources.address,
    constructorArguments: args,
  });

  return resources;
}

async function addRewardsToQuest(quest: Quest, rewards: Rewards): Promise<void> {
  console.log("Adding Resources to Rewards...");
  await quest.setRewardsAddress(rewards.address);
  console.log("Adding Resources to Rewards done.");
}

async function addQuestAsTransferabilityManagerOfTotems(quest: Quest, totems: Totems): Promise<void> {
  console.log("Adding Quest as transferability manager of Totems...");
  const transferabilityManagerRole = await totems.TRANSFERABILITY_MANAGER_ROLE();
  await totems.grantRole(transferabilityManagerRole, quest.address);
  console.log("Adding Quest as transferability manager of Totems done.");
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
