FUNCTION ZBD_CHECKXBOXSHIPMENTEVENT.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(OBJTYPE) LIKE  SWETYPECOU-OBJTYPE
*"     VALUE(OBJKEY) LIKE  SWEINSTCOU-OBJKEY
*"     VALUE(EVENT) LIKE  SWEINSTCOU-EVENT
*"     VALUE(RECTYPE) LIKE  SWETYPECOU-RECTYPE
*"  TABLES
*"      EVENT_CONTAINER STRUCTURE  SWCONT
*"  EXCEPTIONS
*"      NO_APPROVAL_TO_START
*"----------------------------------------------------------------------
  "Define xbox material nr
  constants: c_xbox type MATNR value 'MZ-FG-R100'.

  "Constants for Application Log
  constants: gc_message_class type symsgid value 'ZAZSB',           "Message Class
             gc_appl_log_obj type balobj_d value 'ZBD_ABSDKEH',     "Application Log Object
             gc_appl_log_subobj type balsubobj value 'ZSHIP'.       "Application Log Subobject
  "Data for Log Messaging
  data: lt_msg                TYPE bal_tt_msg,
        ls_msg                TYPE bal_s_msg.

  " Data for XBOX logic
  data: delivery_id      type VBELN_VL,
        delivery_header  TYPE LIKP,
        delivery_item    TYPE LIPS,
        xbox_found       type abap_bool.

  "Extract Shipment Nr
  delivery_id = objkey.
  " Check if Delivery exists
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
    "Prevent Workflow from starting
    raise no_approval_to_start.
  endif.


  "Select delivery item information
  xbox_found = abap_false.
  select * from LIPS into delivery_item where VBELN = delivery_id.
    if c_xbox = delivery_item-MATNR.
      xbox_found = abap_true.
    endif.
  endselect.

  if xbox_found = abap_true.
    "No XBOX Found in Delivery
    ls_msg-msgty  = 'I'.
    ls_msg-msgid  = gc_message_class.
    ls_msg-msgno  = '004'. "Xbox found in delivery
    ls_msg-msgv1  = delivery_id.
    APPEND ls_msg TO lt_msg.
    CALL METHOD cl_beh_application_log=>create
       EXPORTING
         i_msg       = lt_msg
         i_object    = gc_appl_log_obj
         i_subobject = gc_appl_log_subobj.
  else.
    "No XBOX Found in Delivery
    ls_msg-msgty  = 'I'.
    ls_msg-msgid  = gc_message_class.
    ls_msg-msgno  = '005'. "XBOX not found in delivery
    ls_msg-msgv1  = delivery_id.
    APPEND ls_msg TO lt_msg.
    CALL METHOD cl_beh_application_log=>create
       EXPORTING
         i_msg       = lt_msg
         i_object    = gc_appl_log_obj
         i_subobject = gc_appl_log_subobj.
    "Prevent Workflow from starting
    raise no_approval_to_start.
  endif.
ENDFUNCTION.