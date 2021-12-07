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


# Check if all the required list items exist
def checkMessageValues(sapmsg, product):
    notifybody = {}
    logging.info("Check if all data is available in sap message")
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


# Prepare the notification message
def prepareMessage(notifybody):
    logging.info("Create message")
    if notifybody['quantity'] > 0:
        notifymsg = {
            "notification": {
                "title":"Your order is on its way to the store", 
                "body":"We are happy to inform you that your order has been shipped to the store."
            }, 
                "data": {
                    "status":notifybody['event'],
                    "product":notifybody['product'],
                    "quantity":notifybody['quantity'],
                    "uom":notifybody['uom'],
                    "salesorder":notifybody['salesorder']
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
        notifybody = checkMessageValues(sapmsg, "MZ-FG-R100")

        # prepare the message
        logging.info("Prepare notification message")
        notifymsg = prepareMessage(notifybody)

        # if no relevant procucts for notification found, no need to continue
        if notifybody['quantity'] == 0.0:
            return func.HttpResponse(
                '{ "msg": "No relevant products found!" }',
                status_code=status
            )

        # create the notification hub
        logging.info("Prepare notification")
        hub = anh.AzureNotificationHub(APP_NH_CONNECTION_STRING, APP_HUB_NAME, False)

        # retrieve the device tokens to notify from the Cosmos DB
        logging.info("Retrieve device tokens")
        items = retrieveDeviceTokens("xbox-series-x")

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