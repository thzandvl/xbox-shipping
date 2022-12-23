import logging, os
from typing import final

import azure.functions as func
from azure.cosmos import exceptions, CosmosClient
from . import AzureNotificationHub as anh

# Notification Hub parameters
APP_HUB_NAME = os.environ["HUB_NAME"]
APP_NH_CONNECTION_STRING = os.environ["HUB_CONNECTION_STRING"]

# Cosmos DB parameters
ENDPOINT = os.environ["COSMOS_ENDPOINT"]
KEY = os.environ["COSMOS_KEY"]
DATABASE = os.environ["COSMOS_DB"]
CONTAINER = os.environ["COSMOS_CONTAINER"]

# Product ID
PRD_ID = "MZ-FG-R100"

# Retrieve the device tokens from the Cosmos DB
def retrieveDeviceTokens(category):
    try:
        client = CosmosClient(ENDPOINT, KEY)
        database = client.get_database_client(DATABASE)
        container = database.get_container_client(CONTAINER)
        items = list(container.query_items(query="SELECT * FROM c WHERE c.category = '" + category + "'"))

        return items
    except exceptions.CosmosHttpResponseError as e:
        print( '\nAn error occurred. {0}'.format(e.message))
        return list()


# Check if all the required list items exist in the LIKP message
def checkMessageValuesLIKP(sapmsg, product):
    notifybody = {}
    logging.info("Check if all data is available in sap message")
    notifybody['objkey'] = sapmsg.get('objkey', "")
    notifybody['event'] = sapmsg.get('event', "")
    notifybody['loadingdate'] = sapmsg.get('loadingdate', "")
    notifybody['deliverydate'] = sapmsg.get('deliverydate', "")
    notifybody['product'] = product
    notifybody['quantity'] = 0.0
    notifybody['uom'] = ""
    notifybody['salesorder'] = ""
    shipmentlines = sapmsg.get('shipmentlines',{})
        
    logging.info("Get shipmentlines")
    for shipmentline in shipmentlines:
        logging.info("Check if all data is available in shipmentline")
        shipmentline['product'] = shipmentline.get('product', "")
        logging.info("Check product")
        if shipmentline['product'] == product:
            notifybody['uom'] += shipmentline.get('uom', "") + " "
            notifybody['salesorder'] += shipmentline.get('salesorder', "") + " "
            logging.info("Add quantity: " + str(shipmentline['quantity']))
            notifybody['quantity'] += shipmentline['quantity']

    logging.info("Quantity: " + str(notifybody['quantity']))

    return notifybody


# Check if all the required list items exist in the BUS2017 message
def checkMessageValuesBUS2017(sapmsg, product):
    notifybody = {}
    logging.info("Check if all data is available in sap message")
    notifybody['event'] = sapmsg.get('event', "")
    notifybody['date'] = sapmsg.get('date', "")
    notifybody['time'] = sapmsg.get('time', "")
    notifybody['quantity'] = 0.0
    notifybody['availQty'] = 0.0
    goodsmovementlines = sapmsg.get('goodsmovementlines',{})
        
    logging.info("Get goodsmovementlines")
    for goodsmovementline in goodsmovementlines:
        logging.info("Check if all data is available in goodsmovementline")
        goodsmovementline['product'] = goodsmovementline.get('product', "")
        logging.info("Check product")
        if goodsmovementline['product'] == product:
            notifybody['product'] = goodsmovementline.get('product', "")
            notifybody['plant'] = goodsmovementline.get('plant', "")
            notifybody['storageloc'] = goodsmovementline.get('storageloc', "")
            logging.info("Add quantity: " + str(goodsmovementline['quantity']))
            notifybody['quantity'] += goodsmovementline.get('quantity', 0.00)
            notifybody['availQty'] = goodsmovementline.get('availQty', 0.00)
            notifybody['uom'] = goodsmovementline.get('uom', "")

    logging.info("Quantity: " + str(notifybody['quantity']))

    return notifybody


# Prepare the notification message for LIKP
def prepareMessageLIKP(notifybody):
    logging.info("Create message")
    notifymsg = {
        "notification": {
            "title":"Your order is on its way to the store", 
            "body":"We are happy to inform you that your order has been shipped to the store."
        }, 
            "data": {
                "objkey":notifybody['objkey'],
                "status":notifybody['event'],
                "product":notifybody['product'],
                "quantity":notifybody['quantity'],
                "uom":notifybody['uom'],
                "salesorder":notifybody['salesorder']
            }
        }
    
    logging.info(notifymsg)
    return notifymsg


# Prepare the notification message for BUS2017
def prepareMessageBUS2017(notifybody):
    logging.info("Create message")
    notifymsg = {
        "notification": {
            "title":"Material availability changed for product " + notifybody['product'], 
            "body":"The new availability quantity is: " + str(notifybody['availQty'])
        }, 
            "data": {
                "plant":notifybody['plant'],
                "product":notifybody['product'],
                "addedQuantity":notifybody['quantity'],
                "uom":notifybody['uom'],
                "storageloc":notifybody['storageloc']
            }
        }
    
    logging.info(notifymsg)
    return notifymsg


# Main function where the message is received
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    try:
        status = 400
        logging.info('Read JSON from HTTP body')
        sapmsg = req.get_json()
        logging.info(sapmsg)

        # check the values in the message
        if sapmsg.get('busobj', "") == "LIKP":
            notifybody = checkMessageValuesLIKP(sapmsg, PRD_ID)
        elif sapmsg.get('busobj', "") == "BUS2017":
            notifybody = checkMessageValuesBUS2017(sapmsg, PRD_ID)
        else:
            notifybody = {}
            notifybody['quantity'] = 0.0

        # if no relevant procucts for notification found, no need to continue
        if notifybody['quantity'] <= 0.0:
            return func.HttpResponse(
                '{ "msg": "No relevant products found!" }',
                status_code=status
            )

        # prepare the message
        logging.info("Prepare notification message")
        if sapmsg.get('busobj', "") == "LIKP":
            notifymsg = prepareMessageLIKP(notifybody)
        elif sapmsg.get('busobj', "") == "BUS2017":
            notifymsg = prepareMessageBUS2017(notifybody)
        else:
            notifymsg = {}

        # retrieve the device tokens to notify from the Cosmos DB
        logging.info("Retrieve device tokens")
        items = retrieveDeviceTokens("xbox-series-x")

        # create the notification hub
        logging.info("Prepare notification")
        hub = anh.AzureNotificationHub(APP_NH_CONNECTION_STRING, APP_HUB_NAME, False)

        # send the notifications to the relevant devices
        logging.info("Send notification to Android devices")
        for item in items:
            logging.info("Send to device:" + item.get('deviceToken'))
            status, headers = hub.send_google_notification(True, notifymsg, device_handle=item.get('deviceToken'))

            logging.info("Log the output values")
            if status is not None:
                logging.info("Status: " + str(status))
            else:
                logging.info("No status returned")

        # return the response
        logging.info('Send response')
        if(status == 400):
            return func.HttpResponse(
                '{ "msg": "No subscribed devices found!" }',
                status_code=status
            )
        else: 
            return func.HttpResponse(
                '{ "msg": "Notifications processed" }',
                status_code=status
            )
    except ValueError:
        pass
        return func.HttpResponse(
            '{ "msg": "No valid JSON input received!" }',
            status_code=400
        )