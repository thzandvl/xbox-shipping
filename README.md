# Xbox shipping scenario using an SAP Event Driven Architecture
## Introduction
This repo contains all the artifacts and descriptions to reproduce our prototype for an event-driven architecture with SAP S/4HANA. See our [blog post](https://blogs.sap.com/2021/12/09/hey-sap-where-is-my-xbox-an-insight-into-capitalizing-on-event-driven-architectures/) for the complete story.

The screenshots and remaining descriptions will be completed over the coming days.

## Setup

The architecture for the solution looks as follows:
<img src="images/xbox-overview.png" />

The scenario start with an event when a Delivery in SAP created. This event is used to send out a message to Azure Service Bus. Receivers, in our example a logic app listening to Azure Service Bus, will send out Notifications to the end-customer indicating their delivery is on its way.

### Azure Service Bus
Azure Service Bus is a fully managed enterprise message broker with message queues and publish-subscribe topics (in a namespace). For more information, please consult [What is Azure Service Bus](https://docs.microsoft.com/en-us/azure/service-bus-messaging/service-bus-messaging-overview).

The Delivery messages will be send to a queue within a Azure Service Bus Namespace. Instruction can be found at [Azure Service Bus setup](ServiceBusSetup.md)
After this step we can turn to the setup on the SAP side.

### SAP Setup
The setup on SAP side mainly consists of :
1. Raise & capture the event when a Delivery is created, changed (or deleted)
2. creating the corresponding message
3. send the message to the Azure receiver, in this case this is a Azure Service Bus 

To raise the event we will be using `SAP Event Type Linkage`. Since we will be sending out our own message (we're not adhering to standard), we will need custom code to create this json message. For sending the message we used 2 methods. We'll be using the [ABAP SDK for Azure](https://github.com/Microsoft/ABAP-SDK-for-Azure) and [ASAPIO](https://asapio.com/). Both methods will plug into SAP Event Linages on their own way. For ABAP SDK we'll need to create a custom ABAP Class. This class will create the custom message and link to Azure using a class delivered with the ABAP SDK. ASAPIO comes with a predefined function module to hook the ASAPIO framework into the SAP Event Linkage. Both ABAP SDK and ASAPIO depend on customizing tables and a RFC destionation for the connectivity towards Azure.

* ABAP SDK Specific setup can be found [here](ABAPSDKSetup.md)
* ASAPIO specific setup can be found [here](ASAPIOSetup.md)

### Azure Notification Hub
The steps to process the SAP message to a notification are described in the [functionApp](https://github.com/thzandvl/xbox-shipping/tree/main/functionApp) section.

### Azure LogicApp

An Azure Logic App is used to read the messages pushed by SAP into the Azure Service Bus from the queue. The messages are pushed in an Base64 format to prevent conflicts. Therefore the message needs to be decoded before it can be used. The format of the message is in JSON. This JSON message is send to the Azure Function App which is based on an HTTP trigger template.
The Azure Logic App look as follows: \
![Logic App](images/LogicApp/xbox-logicapp.png)

The first component is a Azure Service Bus component and is triggered once a message is received in the queue.\
![Service Bus Connector](images/LogicApp/servicebus-connector.png)

The Base64 decoding is done by using the `base64ToString()` function in a new *Compose* action which is part of *Data Operations*. The code used is:

```json
"actions": {
    "Base64Decode": {
        "inputs": "@base64ToString(triggerBody()['ContentData'])",
        "runAfter": {},
        "type": "Compose"
    },
```

After the Base64 decoding is done the JSON output can be send to the Azure Function App. The Azure Function App is called via the *Azure Functions* component.

![Azure Function App](images/LogicApp/azure-functions.png)

After selecting the *Azure Functions* action you can choose the Azure Function App which you created in the earlier step. As *Request Body* provide the outputs of the *Compose* function from the earlier step.

### Android app
The steps to use an Android App to receive notifications from the Azure Notification Hub are described in the [androidApp](https://github.com/thzandvl/xbox-shipping/tree/main/androidApp) section.
