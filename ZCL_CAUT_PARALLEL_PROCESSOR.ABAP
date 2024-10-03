class ZCL_CAUT_PARALLEL_PROCESSOR definition
  public
  abstract
  create public .

public section.

  types:
    BEGIN OF gty_s_data,
            classname  TYPE string,
            datarecord TYPE indx,
         END OF gty_s_data .
  types:
    gty_t_data TYPE STANDARD TABLE OF gty_s_data WITH DEFAULT KEY .
  types:
    gty_t_indx TYPE STANDARD TABLE OF indx WITH DEFAULT KEY .
  types:
    BEGIN OF gty_s_parallel_data,
             pckg_size        TYPE int4,
             input            TYPE gty_t_data  ,
             output           TYPE gty_t_data  ,
           END OF gty_s_parallel_data .

  methods PACK_DATA
    importing
      !IT_DATA type STANDARD TABLE
    returning
      value(RT_PACKED) type GTY_T_DATA .
  methods PROCESS
  final
    importing
      !IV_SERVERGROUP type CLIKE
      !IV_PCKG_SIZE type INT4 optional
      !IV_PCKG_COUNT type INT4 optional
    changing
      !CT_DATA type STANDARD TABLE
    returning
      value(RO_RESULT) type ref to DATA .
  methods WORK
  abstract
    importing
      !IT_INPUT type ANY TABLE
    returning
      value(RO_OUTPUT) type ref to DATA .
  methods GET_INPUT_TYPE
    returning
      value(RO_DATA) type ref to DATA .
  methods GET_PROCESSOR_SUBCLASS
    returning
      value(RV_CLASS) type STRING .
  methods UNPACK_DATA
    importing
      !IT_PACKED type GTY_T_DATA
      !IV_OUTPUT type BOOLEAN default ABAP_FALSE
    returning
      value(RO_DATA) type ref to DATA .
  methods GET_OUTPUT_TYPE
    returning
      value(RO_DATA) type ref to DATA .
protected section.
private section.
ENDCLASS.



CLASS ZCL_CAUT_PARALLEL_PROCESSOR IMPLEMENTATION.


  method GET_INPUT_TYPE.
  endmethod.


  method GET_OUTPUT_TYPE.
    ro_data = me->get_input_type( ).
  endmethod.


  method GET_PROCESSOR_SUBCLASS.
    rv_class =  cl_abap_typedescr=>describe_by_object_ref( me )->get_relative_name( ).
  endmethod.


  METHOD pack_data.

    DATA:  lt_indx TYPE gty_t_indx.

    CALL FUNCTION 'SPTA_INDX_PACKAGE_ENCODE'
      EXPORTING
        data    = it_data
      IMPORTING
        indxtab = lt_indx.

    DATA(lv_caller) = me->get_processor_subclass( ).
    LOOP AT lt_indx ASSIGNING FIELD-SYMBOL(<ls_indx>).
      APPEND INITIAL LINE TO rt_packed ASSIGNING FIELD-SYMBOL(<ls_input>).
      MOVE-CORRESPONDING <ls_indx> TO <ls_input>-datarecord.
      <ls_input>-classname = lv_caller.
    ENDLOOP.

  ENDMETHOD.


  METHOD process.


    DATA ls_param TYPE gty_s_parallel_data.

    CHECK ct_data IS NOT INITIAL.
    IF iv_pckg_size IS SUPPLIED.
      ls_param-pckg_size = iv_pckg_size.
    ELSEIF iv_pckg_count IS SUPPLIED AND  iv_pckg_count <> 0.
      ls_param-pckg_size = lines( ct_data ) /  iv_pckg_count.
    ELSE.
      "One of both must be provided
      RETURN.
    ENDIF.

    ls_param-input = pack_data( ct_data ).

    CALL FUNCTION 'SPTA_PARA_PROCESS_START_2'
      EXPORTING
        server_group             = CONV spta_rfcgr( iv_servergroup )
        before_rfc_callback_form = 'F_BEFORE_RFC'
        in_rfc_callback_form     = 'F_IN_RFC'
        after_rfc_callback_form  = 'F_AFTER_RFC'
        callback_prog            = 'ZCAUT_PARALLEL_PROCESSOR'
*       SHOW_STATUS              = ' '
*       RESOURCE_TIMEOUT         = 600
*       TASK_CALL_MODE           = 1
      CHANGING
        user_param               = ls_param
      EXCEPTIONS
        invalid_server_group     = 1
        no_resources_available   = 2
        OTHERS                   = 3.
    IF sy-subrc <> 0.
      MESSAGE TEXT-e11 TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

   ro_result =  me->unpack_data(
      EXPORTING
        it_packed = ls_param-output
        iv_output = abap_true
    ).

  ENDMETHOD.


  METHOD unpack_data.
    DATA: lt_indx_in TYPE gty_t_indx.
    FIELD-SYMBOLS: <lt_data> TYPE STANDARD TABLE.

    IF iv_output = abap_false.
      ro_data = me->get_input_type( ).
    ELSE.
      ro_data = me->get_output_type( ).
    ENDIF.


    LOOP AT it_packed ASSIGNING FIELD-SYMBOL(<ls_in>).
      APPEND <ls_in>-datarecord TO lt_indx_in.
    ENDLOOP.

    ASSIGN ro_data->* TO <lt_data>.

    CALL FUNCTION 'SPTA_INDX_PACKAGE_DECODE'
      EXPORTING
        indxtab = lt_indx_in
      IMPORTING
        data    = <lt_data>.


  ENDMETHOD.
ENDCLASS.
