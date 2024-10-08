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
      !IV_RESOURCE_PERC type NUMC2 default 0
      !IV_MAX_TASKS_PARALLEL type NUMC2 default 0
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

  constants GC_CLASSFIELD type STRING value 'ZXY_CLASS' ##NO_TEXT.
private section.

  methods DETERMINE_TASK_COUNT
    importing
      !IV_SERVERGROUP type CLIKE
      !IV_RESOURCE_PERC type NUMC2
      !IV_MAX_TASKS type NUMC2
    returning
      value(RV_COUNT) type SY-INDEX .
ENDCLASS.



CLASS ZCL_CAUT_PARALLEL_PROCESSOR IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_CAUT_PARALLEL_PROCESSOR->DETERMINE_TASK_COUNT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_SERVERGROUP                 TYPE        CLIKE
* | [--->] IV_RESOURCE_PERC               TYPE        NUMC2
* | [--->] IV_MAX_TASKS                   TYPE        NUMC2
* | [<-()] RV_COUNT                       TYPE        SY-INDEX
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD determine_task_count.
    DATA:  lv_free TYPE i.


    rv_count = 0.

    CALL FUNCTION 'SPBT_INITIALIZE'
      EXPORTING
        group_name                     = CONV rzlli_apcl( iv_servergroup )
      IMPORTING
        free_pbt_wps                   = lv_free
      EXCEPTIONS
        invalid_group_name             = 1
        internal_error                 = 2
        pbt_env_already_initialized    = 3
        currently_no_resources_avail   = 4
        no_pbt_resources_found         = 5
        cant_init_different_pbt_groups = 6
        OTHERS                         = 7.

    IF sy-subrc  = 3.
      "Environment already initialized, use a different FM
      "to get available resources
      CALL FUNCTION 'SPBT_GET_CURR_RESOURCE_INFO'
        IMPORTING
          free_pbt_wps                = lv_free
        EXCEPTIONS
          internal_error              = 1
          pbt_env_not_initialized_yet = 2
          OTHERS                      = 3.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
    ELSEIF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF iv_resource_perc <> 0.
      rv_count = ( iv_resource_perc * lv_free ) / 100.
    ELSE.
      "Take them all!!
      rv_count = lv_free.
    ENDIF.

    "Did we receive a certain external limit con task count?
    "Then adjust the calculation by it at lower common denominator
    IF iv_max_tasks <> 0 AND iv_max_tasks < rv_count.
      rv_count = iv_max_tasks.
    ENDIF.




  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_CAUT_PARALLEL_PROCESSOR->GET_INPUT_TYPE
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RO_DATA                        TYPE REF TO DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method GET_INPUT_TYPE.
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_CAUT_PARALLEL_PROCESSOR->GET_OUTPUT_TYPE
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RO_DATA                        TYPE REF TO DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method GET_OUTPUT_TYPE.
    ro_data = me->get_input_type( ).
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_CAUT_PARALLEL_PROCESSOR->GET_PROCESSOR_SUBCLASS
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RV_CLASS                       TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method GET_PROCESSOR_SUBCLASS.
    rv_class =  cl_abap_typedescr=>describe_by_object_ref( me )->get_relative_name( ).
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_CAUT_PARALLEL_PROCESSOR->PACK_DATA
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_DATA                        TYPE        STANDARD TABLE
* | [<-()] RT_PACKED                      TYPE        GTY_T_DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
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


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_CAUT_PARALLEL_PROCESSOR->PROCESS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_SERVERGROUP                 TYPE        CLIKE
* | [--->] IV_PCKG_SIZE                   TYPE        INT4(optional)
* | [--->] IV_RESOURCE_PERC               TYPE        NUMC2 (default =0)
* | [--->] IV_MAX_TASKS_PARALLEL          TYPE        NUMC2 (default =0)
* | [<-->] CT_DATA                        TYPE        STANDARD TABLE
* | [<-()] RO_RESULT                      TYPE REF TO DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD process.

    DATA: ls_param    TYPE gty_s_parallel_data,
          lv_maxtasks TYPE sy-index.

    CHECK ct_data IS NOT INITIAL.

    "Determine maximum number of tasks if a certain % of
    "resource utilization is desiered
    lv_maxtasks = me->determine_task_count(  iv_servergroup    = iv_servergroup
                                             iv_resource_perc  = iv_resource_perc
                                             iv_max_tasks      = iv_max_tasks_parallel     ).


    IF iv_pckg_size IS SUPPLIED.
      ls_param-pckg_size = iv_pckg_size.
    ELSEIF lv_maxtasks <> 0.
      ls_param-pckg_size = lines( ct_data ) /  lv_maxtasks.
    ELSE.
      "No available resources? throw an error
      RETURN.
    ENDIF.




    ls_param-input = pack_data( ct_data ).

    CALL FUNCTION 'SPTA_PARA_PROCESS_START_2'
      EXPORTING
        server_group             = CONV spta_rfcgr( iv_servergroup )
        max_no_of_tasks          = lv_maxtasks
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


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_CAUT_PARALLEL_PROCESSOR->UNPACK_DATA
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_PACKED                      TYPE        GTY_T_DATA
* | [--->] IV_OUTPUT                      TYPE        BOOLEAN (default =ABAP_FALSE)
* | [<-()] RO_DATA                        TYPE REF TO DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
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
