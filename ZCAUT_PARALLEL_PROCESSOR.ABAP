*&---------------------------------------------------------------------*
*& Report ZCAUT_PARALLEL_PROCESSOR
*&---------------------------------------------------------------------*
*& This is a component of the easy parallel processing tool
*& It is a fully dynamic implementation that will take care
*& of preparing, processing and post-processing work packets
*& no mater their data types or scopes.
*&---------------------------------------------------------------------*
REPORT zcaut_parallel_processor.


FORM f_before_rfc USING    is_before_rfc_imp     TYPE spta_t_before_rfc_imp
                  CHANGING cs_before_rfc_exp     TYPE spta_t_before_rfc_exp
                           ct_rfcdata            TYPE spta_t_indxtab
                           ct_failed_objects     TYPE spta_t_failed_objects
                           ct_objects_in_process TYPE spta_t_objects_in_process
                           cs_data               TYPE zcl_caut_parallel_processor=>gty_s_parallel_data  ##NEEDED. "#EC CALLED Called dynamically from the parallel processing framework


  FIELD-SYMBOLS: <lt_data>   TYPE STANDARD TABLE,
                 <lt_packet> TYPE STANDARD TABLE,
                 <lt_params> TYPE STANDARD TABLE.
  DATA: lo_packet    TYPE REF TO data,
        lo_data      TYPE REF TO data,
        lo_params    TYPE REF TO data,
        lo_processor TYPE REF TO object.

  cs_before_rfc_exp-start_rfc = abap_false.

  CHECK cs_data-input IS NOT INITIAL.
  DATA(lv_classname) = cs_data-input[ 1 ]-classname.
  CREATE OBJECT lo_processor TYPE (lv_classname).

  CALL METHOD lo_processor->('UNPACK_DATA')
    EXPORTING
      it_packed = cs_data-input
      iv_output = zcl_caut_parallel_processor=>gc_input
    RECEIVING
      ro_data   = lo_data.

  ASSIGN lo_data->* TO <lt_data>.
  CLEAR cs_data-input.
  CHECK <lt_data> IS NOT INITIAL.

  CALL METHOD lo_processor->('UNPACK_DATA')
    EXPORTING
      it_packed = cs_data-parameters
      iv_output = zcl_caut_parallel_processor=>gc_params
    RECEIVING
      ro_data   = lo_params.
  ASSIGN lo_params->* TO <lt_params>.

  "Create work packages
  CREATE DATA lo_packet LIKE <lt_data>.
  ASSIGN lo_packet->* TO  <lt_packet>.
  <lt_packet>[] = <lt_data>[].
  DELETE <lt_packet> FROM ( cs_data-pckg_size + 1 ).
  DELETE <lt_data>   FROM 1 TO ( cs_data-pckg_size  ).

  CHECK <lt_packet> IS NOT INITIAL.


  "Double packing to add the class name
  DATA: lt_packet_encoded TYPE zcl_caut_parallel_processor=>gty_t_data,
        lt_params_encoded TYPE zcl_caut_parallel_processor=>gty_t_data.

  CALL METHOD lo_processor->('PACK_DATA')
    EXPORTING
      it_data   = <lt_packet>
    RECEIVING
      rt_packed = lt_packet_encoded.

  "Always add the parameters
  CALL METHOD lo_processor->('PACK_DATA')
    EXPORTING
      it_data                = <lt_params>
      iv_data_are_parameters = abap_true
    RECEIVING
      rt_packed              = lt_params_encoded.

  APPEND LINES OF lt_params_encoded TO lt_packet_encoded.

  CALL FUNCTION 'SPTA_INDX_PACKAGE_ENCODE'
    EXPORTING
      data    = lt_packet_encoded
    IMPORTING
      indxtab = ct_rfcdata.

  "And leave the data still unprocessed
  "so that the next iteration creates further packages
  IF <lt_data> IS NOT INITIAL.
    CALL METHOD lo_processor->('PACK_DATA')
      EXPORTING
        it_data   = <lt_data>
      RECEIVING
        rt_packed = cs_data-input.
  ENDIF.

  "And start the thread right now
  cs_before_rfc_exp-start_rfc = abap_true.
ENDFORM.

FORM f_in_rfc   USING    is_in_rfc_imp     TYPE spta_t_in_rfc_imp
                CHANGING cs_in_rfc_exp     TYPE spta_t_in_rfc_exp
                         ct_rfcdata        TYPE spta_t_indxtab     ##NEEDED. "#EC CALLED Called dynamically from the parallel processing framework

  DATA: lo_data           TYPE REF TO data,
        lo_data_processed TYPE REF TO data,
        lo_params         TYPE REF TO data,
        lt_packet_encoded TYPE zcl_caut_parallel_processor=>gty_t_data,
        lo_processor      TYPE REF TO object.
  FIELD-SYMBOLS: <lt_data>      TYPE ANY TABLE,
                 <lt_processed> TYPE ANY TABLE,
                 <lt_params>    TYPE zcl_caut_parallel_processor=>gty_t_parameters.


  "First decode, get the clustered-data plus decoded class and cluster type
  CALL FUNCTION 'SPTA_INDX_PACKAGE_DECODE'
    EXPORTING
      indxtab = ct_rfcdata
    IMPORTING
      data    = lt_packet_encoded.

  "Now we have the processing class name, plus the clustered data package
  CHECK lt_packet_encoded IS NOT INITIAL.
  DATA(lv_classname) = lt_packet_encoded[ 1 ]-classname.
  CREATE OBJECT lo_processor TYPE (lv_classname).


  "Separate parameters from data
  DATA(lt_params_encoded) = lt_packet_encoded.
  DELETE lt_params_encoded WHERE block <> zcl_caut_parallel_processor=>gc_block_param.
  DELETE lt_packet_encoded WHERE block = zcl_caut_parallel_processor=>gc_block_param.

  "Now what we have the class we can further unpack the data as we can get the datatype
  CALL METHOD lo_processor->('UNPACK_DATA')
    EXPORTING
      it_packed = lt_packet_encoded
      iv_output = zcl_caut_parallel_processor=>gc_input
    RECEIVING
      ro_data   = lo_data.


  ASSIGN lo_data->* TO <lt_data>.
  CHECK <lt_data> IS NOT INITIAL.

  "Also unpack the parameters
  CALL METHOD lo_processor->('UNPACK_DATA')
    EXPORTING
      it_packed = lt_params_encoded
      iv_output = zcl_caut_parallel_processor=>gc_params
    RECEIVING
      ro_data   = lo_params.
  ASSIGN lo_params->* TO <lt_params>.


  "Perform work unit now!
  CALL METHOD lo_processor->('WORK')
    EXPORTING
      it_input      = <lt_data>
      it_parameters = <lt_params>
    RECEIVING
      ro_output     = lo_data_processed.

  "And set the results so that the after RFC process can
  "collect it
  ASSIGN lo_data_processed->* TO <lt_processed>.

  "Again we do a double packing to send the data to the post-process form
  CALL METHOD lo_processor->('PACK_DATA')
    EXPORTING
      it_data   = <lt_processed>
    RECEIVING
      rt_packed = lt_packet_encoded.

  CALL FUNCTION 'SPTA_INDX_PACKAGE_ENCODE'
    EXPORTING
      data    = lt_packet_encoded
    IMPORTING
      indxtab = ct_rfcdata.

ENDFORM.

FORM f_after_rfc      USING it_rfcdata            TYPE spta_t_indxtab
                            iv_rfcsubrc           TYPE sy-subrc
                            iv_rfcmsg             TYPE spta_t_rfcmsg
                            it_objects_in_process TYPE spta_t_objects_in_process
                            is_after_rfc_imp      TYPE spta_t_after_rfc_imp
                   CHANGING cs_after_rfc_exp      TYPE spta_t_after_rfc_exp
                            cs_data               TYPE zcl_caut_parallel_processor=>gty_s_parallel_data ##NEEDED. "#EC CALLED Called dynamically from the parallel processing framework

  DATA: lt_result_encoded TYPE zcl_caut_parallel_processor=>gty_t_data,
        lo_data           TYPE REF TO data,
        lo_processor      TYPE REF TO object.

  FIELD-SYMBOLS: <lt_packet> TYPE STANDARD TABLE,
                 <lt_total>  TYPE STANDARD TABLE.

  "This is called for each thread that finishes, a call will be made
  "for as many threads as we triggered
  CALL FUNCTION 'SPTA_INDX_PACKAGE_DECODE'
    EXPORTING
      indxtab = it_rfcdata
    IMPORTING
      data    = lt_result_encoded.

  "As always, we have double codding, the first one we allows us to retrieve the processor class
  CHECK lt_result_encoded IS NOT INITIAL.
  DATA(lv_classname) = lt_result_encoded[ 1 ]-classname.
  CREATE OBJECT lo_processor TYPE (lv_classname).

  "Now with the processor at hand we can unpack the actual
  "INDX cluster into the output data
  CALL METHOD lo_processor->('UNPACK_DATA')
    EXPORTING
      it_packed = lt_result_encoded
      iv_output = zcl_caut_parallel_processor=>gc_output
    RECEIVING
      ro_data   = lo_data.
  ASSIGN lo_data->* TO <lt_packet>.

  "To add it to the results we need to first unpack the existing data
  "to later appnd the new one
  CALL METHOD lo_processor->('UNPACK_DATA')
    EXPORTING
      it_packed = cs_data-output
      iv_output = zcl_caut_parallel_processor=>gc_output
    RECEIVING
      ro_data   = lo_data.
  ASSIGN lo_data->* TO <lt_total>.

  APPEND LINES OF <lt_packet> TO <lt_total>.

  CHECK <lt_total> IS NOT INITIAL.

  CALL METHOD lo_processor->('PACK_DATA')
    EXPORTING
      it_data   = <lt_total>
    RECEIVING
      rt_packed = cs_data-output.

ENDFORM.
