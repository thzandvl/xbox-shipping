method BI_EVENT_HANDLER_STATIC~ON_EVENT.

  "InterfaceId to be used by ABAP SDK
  constants: gc_interface_id type zinterface_id value 'AZSB_SHIP'.  "ABAP SDK Interface Id

  "Constants for Application Log
  constants: gc_message_class type symsgid value 'ZAZSB',           "Message Class
             gc_appl_log_obj type balobj_d value 'ZBD_ABSDKEH',     "Application Log Object
             gc_appl_log_subobj type balsubobj value 'ZSHIP'.       "Application Log Subobject

  TYPES: BEGIN of lty_shipmentevent_line,
      product    type MATNR,
      quantity   type LFIMG,
      UOM        type MEINS,
      salesorder type VGBEL,
  END OF lty_shipmentevent_line.

  types : lty_shipmentlines type standard table of lty_shipmentevent_line with default key.

  TYPES: BEGIN OF lty_shipmentevent,
    busobj        TYPE sbo_bo_type,
    busobjname    TYPE SBEH_BOTYP_TEXT,
    objkey        TYPE SIBFBORIID,
    event         TYPE SIBFEVENT,
    date          TYPE dats,
    time          TYPE tims,
    shipto        TYPE KUNWE,
    loadingdate   type lddat,
    deliverydate  type LFDAT_V,
    shipmentlines type lty_shipmentlines,
  END OF lty_shipmentevent.

  "Data for Event Information
  data: lv_busobj_type        type sbo_bo_type,
        lv_busobj_type_name   type SBEH_BOTYP_TEXT.

  "Date for Shipment Information
  data: lv_shipmentevent      TYPE lty_shipmentevent,
        lv_shipmentline       TYPE lty_shipmentevent_line,
        lv_shipmentlines      TYPE table of lty_shipmentevent_line,
        delivery_item         TYPE LIPS,
        delivery_header       TYPE LIKP,
        delivery_id           TYPE VBELN_VL,
        shipto                TYPE KUNWE, "Field KUNNR
        product               TYPE MATNR, "Field MATNR
        quantity              TYPE LFIMG, "Field LFIMG
        UOM                   TYPE MEINS. "FIELD MEINS

  "Data for JSON Conversion
  Data : sQuantity      type string,
         gv_json_output type string.

  "Data for Azure Service Hub Connection
  constants: gc_interface type zinterface_id value 'AZSB_SHIP'.

  data: it_headers            TYPE tihttpnvp,
        wa_headers            TYPE LINE OF tihttpnvp,
        lv_error_string       TYPE string,
        lv_info_string        TYPE string,
        lv_response           TYPE string,
        cx_interface          TYPE REF TO zcx_interace_config_missing,
        cx_http               TYPE REF TO zcx_http_client_failed,
        cx_adf_service        TYPE REF TO zcx_adf_service,
        oref_servicebus       TYPE REF TO zcl_adf_service_servicebus,
        oref                  TYPE REF TO zcl_adf_service,
        filter                type zbusinessid,
        lv_http_status        TYPE i, "HTTP Status code
        lo_json               TYPE REF TO cl_trex_json_serializer,
        lv_json_string        TYPE string,
        lv_json_xstring       TYPE xstring.

  "Data for Log Messaging
  data: lt_msg                TYPE bal_tt_msg,
        ls_msg                TYPE bal_s_msg.

  "Select information about the event
  "select the business object type
  SELECT SINGLE bo_type INTO lv_busobj_type
    FROM sbo_i_bodef
    WHERE object_name = sender-typeid
    AND   object_type_category = sender-catid.
  IF sy-subrc = 0.
    SELECT SINGLE bo_text INTO lv_busobj_type_name
      FROM sbo_i_botypet
      WHERE bo_type  = lv_busobj_type
      AND   bo_textlan = sy-langu.
  ENDIF.

  "Create the Shipment Event message header
  lv_shipmentevent-busobj     = sender-typeid.
  lv_shipmentevent-busobjname = lv_busobj_type_name.
  lv_shipmentevent-event      = event.
  lv_shipmentevent-objkey     = sender-instid.
  lv_shipmentevent-date       = sy-datlo.
  lv_shipmentevent-time       = sy-timlo.

  "Select delivery related information
  delivery_id = sender-instid.
  select single * from LIKP into delivery_header where VBELN = delivery_id.
  if sy-subrc ne 0.
    "Something went wrong
    ls_msg-msgty  = 'E'.
    ls_msg-msgid  = gc_message_class.
    ls_msg-msgno  = '000'.
    ls_msg-msgv1  = delivery_id.
    APPEND ls_msg TO lt_msg.
    CALL METHOD cl_beh_application_log=>create
       EXPORTING
         i_msg       = lt_msg
         i_object    = gc_appl_log_obj
         i_subobject = gc_appl_log_subobj.
    exit.
  endif.
  lv_shipmentevent-shipto = delivery_header-KUNNR.
  lv_shipmentevent-deliverydate = delivery_header-LFDAT.
  lv_shipmentevent-loadingdate = delivery_header-LDDAT.

  "Select delivery item information
  select * from LIPS into delivery_item where VBELN = delivery_id.
    lv_shipmentline-product = delivery_item-MATNR.
    lv_shipmentline-quantity = delivery_item-LFIMG.
    lv_shipmentline-UOM = delivery_item-MEINS.
    lv_shipmentline-salesorder = delivery_item-VGBEL.
    append lv_shipmentline to lv_shipmentlines.
  endselect.

  move-corresponding lv_shipmentlines to lv_shipmentevent-shipmentlines.

  "Convert to JSON
  gv_json_output = /ui2/cl_json=>serialize( data     = lv_shipmentevent
                                            compress = abap_true
                                            pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

  "Send to json message to Azure Service Bus
  TRY.
    "Calling Factory method to instantiate service bus client

    oref = zcl_adf_service_factory=>create( iv_interface_id        = gc_interface_id
                                            iv_business_identifier = filter ).
    oref_servicebus ?= oref. "Type Cast to Service Object?

    "Setting Expiry time
    CALL METHOD oref_servicebus->add_expiry_time
      EXPORTING
        iv_expiry_hour = 0
        iv_expiry_min  = 15
        iv_expiry_sec  = 0.

    "Convert input string data to Xstring format required by ABAP SDK
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = gv_json_output
      IMPORTING
        buffer = lv_json_xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.
    IF sy-subrc <> 0.
       "Something went wrong
    ENDIF.

    "Add message label
    CLEAR it_headers.
    wa_headers-name = 'BrokerProperties'.
    wa_headers-value = '{"Label":"ShipmentData"}'.
    APPEND wa_headers TO it_headers.
    CLEAR  wa_headers.

    "Sending Converted SAP data to Azure Service Bus
    oref_servicebus->send( EXPORTING request        = lv_json_xstring   "Input XSTRING of SAP Business data
                                     it_headers     = it_headers        "Header attributes
                           IMPORTING response       = lv_response       "Response from Service Bus
                                     ev_http_status = lv_http_status ). "Status

  CATCH zcx_interace_config_missing INTO cx_interface.
    lv_error_string = cx_interface->get_text( ).
    ls_msg-msgty  = 'E'.
    ls_msg-msgid  = gc_message_class.
    ls_msg-msgno  = '001'.
    ls_msg-msgv1  = sender-typeid.
    ls_msg-msgv2  = delivery_id.
    ls_msg-msgv3  = lv_error_string.
    APPEND ls_msg TO lt_msg.
    CALL METHOD cl_beh_application_log=>create
       EXPORTING
         i_msg       = lt_msg
         i_object    = gc_appl_log_obj
         i_subobject = gc_appl_log_subobj.

  CATCH zcx_http_client_failed INTO cx_http .
    lv_error_string = cx_http->get_text( ).
    ls_msg-msgty  = 'E'.
    ls_msg-msgid  = gc_message_class.
    ls_msg-msgno  = '001'.
    ls_msg-msgv1  = sender-typeid.
    ls_msg-msgv2  = delivery_id.
    ls_msg-msgv3  = lv_error_string.
    APPEND ls_msg TO lt_msg.
    CALL METHOD cl_beh_application_log=>create
       EXPORTING
         i_msg       = lt_msg
         i_object    = gc_appl_log_obj
         i_subobject = gc_appl_log_subobj.

  CATCH zcx_adf_service INTO cx_adf_service.
    lv_error_string = cx_adf_service->get_text( ).
    ls_msg-msgty  = 'E'.
    ls_msg-msgid  = gc_message_class.
    ls_msg-msgno  = '001'.
    ls_msg-msgv1  = sender-typeid.
    ls_msg-msgv2  = delivery_id.
    ls_msg-msgv3  = lv_error_string.
    APPEND ls_msg TO lt_msg.
    CALL METHOD cl_beh_application_log=>create
       EXPORTING
         i_msg       = lt_msg
         i_object    = gc_appl_log_obj
         i_subobject = gc_appl_log_subobj.

  ENDTRY.

  "Check HTTP Status
  IF lv_http_status NE '201' AND
     lv_http_status NE '200'.
    lv_error_string = 'HTTP Error - SAP data not sent to Azure Service Bus'.
    ls_msg-msgty  = 'E'.
    ls_msg-msgid  = gc_message_class.
    ls_msg-msgno  = '002'.
    ls_msg-msgv1  = sender-typeid.
    ls_msg-msgv2  = delivery_id.
    ls_msg-msgv3  = lv_error_string.
    ls_msg-msgv4  = lv_http_status.
    APPEND ls_msg TO lt_msg.
    CALL METHOD cl_beh_application_log=>create
       EXPORTING
         i_msg       = lt_msg
         i_object    = gc_appl_log_obj
         i_subobject = gc_appl_log_subobj.
  ELSE.
    lv_info_string = 'SAP data sent to Azure Service Bus'.
    ls_msg-msgty  = 'I'.
    ls_msg-msgid  = gc_message_class.
    ls_msg-msgno  = '003'.
    ls_msg-msgv1  = sender-typeid.
    ls_msg-msgv2  = delivery_id.
    ls_msg-msgv3  = lv_info_string.
    APPEND ls_msg TO lt_msg.
    CALL METHOD cl_beh_application_log=>create
       EXPORTING
         i_msg       = lt_msg
         i_object    = gc_appl_log_obj
         i_subobject = gc_appl_log_subobj.
  ENDIF.

endmethod.