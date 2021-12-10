# Azure Service Bus Setup
This setup consists of 2 steps :
1. Create a Azure Service Bus Namespace
2. Create a Azure Service Bus Queue within the Namespace

## Azure Service Bus NameSpace
Search for 'Azure Service Bus' on the Marketplace and press 'Create'.
<img src="images/ServiceBus/servicebuscreate.png" height=100>

Provide a resource group, location and name.
The 'Basic' pricing tier is sufficient for our example.
<img src="images/ServiceBus/servicebuscreate2.png">

## Azure Service Bus Queue
Now you need to create a queue within your Azure Service Bus Namespace.

<img src="images/ServiceBus/createqueue1.png">

<img src="images/ServiceBus/createqueue2.png">

To connect the ABAP SDK or ASAPIO to this queue, you'll need the `Queue URL` and a `Shared Access Policy`.
The `Host name`can be found at the Queue Overview Tab.
<img src="images/ServiceBus/queue_overview.png">

Here you can also find the link to the `Shared Access Policies (SAS)`. Add a new `SAS Policy` with send permissions. Note the primary key.
<img src="images/ServiceBus/SASPolicy.png">
