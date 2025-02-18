---
sidebar_position: 4
---

# Fee Channels 

In the Tagion ecosystem, users will initially have four channels through which they can contribute TGN to the treasury. Three of these channels—Execution Fees, Storage Fees, and Relay Fees—are tied to operations conducted on the Mainnet. The fourth, Subsystem Taxes, applies to operations within Subsystems and is designed to ensure that Subsystems fairly compensate Mainnet Nodes for the critical role they play in providing security to these Subsystems. 

### Execution Fees 

Execution Fees are charged when instructions are submitted for processing. Each execution consists of one or more instructions, and these instructions require computational power. The total cost depends on both the complexity of each instruction and the number of instructions included in the execution. Some instructions require very little processing power, while others are more demanding. Additionally, the number of instructions processed together can vary, which further impacts the total computational load. 

To account for this, Quarks [working title] are used as a unit to measure the computational resources consumed by each instruction, with a computational load counter keeping track of the total Quarks used across all instructions in an execution. The total execution fee is determined based on the number of Quarks recorded by the load counter, ensuring that users are charged according to the actual computational resources consumed. 

_The price will be administered but will initially be set at x TGN per unit of Quark._

### Storage Fees 

Storage Fees, which include fees for operations that allocate network storage resources, such as storing transaction histories, documents, or user data. To account for these ongoing and cumulative demands, a storage unit, referred to as Byte(s), will measure the volume of data being stored. Storage costs will also depend on the length of time the data remains on the network, reflecting the long-term burden it imposes. The storage unit ensures precise measurement of resource use, where smaller datasets incur lower initial costs, while larger files require greater fees. The length of storage adds an additional dimension, with periodic charges applied for data retention over time.  

Storage costs incentivize efficient use of storage space, such as compressing data or deleting unnecessary records, to avoid bloating the system. It ensures that those utilizing the network for persistent data storage contribute fairly to its maintenance and scalability. 

_The price will be administered but will initially be set at x TGN per Byte times x per month._

### Subsystem Tax 

As autonomous and self-governing entities, Federated Subsystems operate independently and are not subject to direct control by the mainnet. However, the mainnet will require them to provide fair compensation in exchange for the security services it offers. This fee, known as a Subsystem Tax, consists of two channels: 

+ **Ecosystem Tax** – A predetermined, fixed fee—paid weekly, monthly, or annually—for operating a Subsystem that is connected to and interacts with the Tagion Ecosystem, which includes both the Mainnet and other Subsystems. This tax is designed to account for the benefits and resources provided by the ecosystem, such as security, interoperability, software, and network infrastructure. 

_The Ecosystem Tax will be administered but will initially be set at x TGN per month.-

+ **Usage Tax** – A tax that is incurred for each execution. Notably, the tax rate should be a fraction of the execution fees on the mainnet. This reflects the reality that subsystems primarily depend on Mainnet nodes for security rather than full computational processing. In other words, while subsystems leverage the Mainnet’s security infrastructure, they do not place the same level of computational burden on it. As a result, the execution fees for subsystems are set lower to account for their reduced reliance on Mainnet resources. 

_The Execution Tax will be administered but will initially be set at x Ticket (link) per unit of Quark._

The community, as mentioned, is responsible for determining and administering the tax rates, ensuring they reflect the collective needs and preferences of its members. This includes both the ecosystem tax and the execution tax, which should be balanced to achieve two key objectives: 

1. **Fair Compensation of contributors** – The tax rates should be set high enough to adequately reward contributors for their efforts and resource contributions. 

2. **Encouraging Subsystem Adoption** – Tax rates must remain low enough to avoid discouraging individuals and businesses from creating or utilizing Subsystems. Excessively high rates could deter adoption and push more activity onto the Mainnet, leading to increased congestion, inefficiencies, and a heavier computational burden on the Mainnet.

### Tickets 

The Execution Tax is payable exclusively in what we call "Tickets". So, what is a Ticket? 

A Ticket is purchased through a smart contract managed by the Treasury. By paying 1 TGN into the smart contract, a Subsystem will receive 1 Ticket in return. So why use Tickets instead of TGN? 

Tickets are preferred for the simple reason that they enable execution taxes to be paid by subsystems without overburdening the Mainnet. If subsystems were required to settle execution taxes in TGN, each execution within a federated subsystem would need to be mirrored by a corresponding execution on the Mainnet. This duplication would increase the computational load on Mainnet nodes, driving up operational costs and reducing the overall efficiency of the network. 

With Tickets, we can implement a simple counter on each subsystem to measure the computational load of every execution, automatically burning the equivalent amount in Tickets stored within a smart contract. As such, users do not need to acquire Tickets themselves to transact within subsystems, as the process is fully automated. The subsystem, as a whole, however, would be required to store the necessary Tickets. 
