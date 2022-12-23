# Azure Service Bus Setup
This setup consists of 2 steps :
1. Create an Azure Service Bus Namespace
2. Create an Azure Service Bus Topic within the Namespace

## Azure Service Bus NameSpace
Search for 'Service Bus' on the Marketplace and press 'Create'.
<img src="images/ServiceBus/servicebuscreate.png" height=100>

Provide a resource group, location and name.
The 'Basic' pricing tier is sufficient for our example.
<img src="images/ServiceBus/servicebuscreate2.png">

## Azure Service Bus Topic
Now you need to create a topic within your Azure Service Bus Namespace.

<img src="images/ServiceBus/createtopic1.png">

<img src="images/ServiceBus/createtopic2.png">

To connect the ABAP SDK or ASAPIO to this topic, you'll need the `Topic URL` and a `Shared Access Policy`.
The `Host name`can be found at the Topic Overview Tab.
<img src="images/ServiceBus/topic_overview.png">

Here you can also find the link to the `Shared Access Policies (SAS)`. Add a new `SAS Policy` with send permissions. Note the primary key.
<img src="images/ServiceBus/SASPolicy.png">
