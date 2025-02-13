class ZCL_TMP_PARAL_TEST definition
  public
  inheriting from ZCL_CAUT_PARALLEL_PROCESSOR
  final
  create public .

public section.

  methods GET_INPUT_TYPE
    redefinition .
  methods WORK
    redefinition .
  methods GET_OUTPUT_TYPE
    redefinition .
protected section.
private section.
ENDCLASS.



CLASS ZCL_TMP_PARAL_TEST IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_TMP_PARAL_TEST->GET_INPUT_TYPE
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RO_DATA                        TYPE REF TO DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method GET_INPUT_TYPE.
     TYPES: BEGIN OF lty_s_input,
              matnr TYPE matnr_d,
            END OF lty_s_input.

     CREATE DATA ro_data TYPE STANDARD TABLE OF lty_s_input.


  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_TMP_PARAL_TEST->GET_OUTPUT_TYPE
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RO_DATA                        TYPE REF TO DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method GET_OUTPUT_TYPE.
     TYPES: BEGIN OF lty_s_output,
              matnr TYPE matnr_d,
              spras TYPE makt-spras,
              maktx TYPE makt-maktx,
            END OF lty_s_output.

     CREATE DATA ro_data TYPE STANDARD TABLE OF lty_s_output.
  endmethod.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_TMP_PARAL_TEST->WORK
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_INPUT                       TYPE        ANY TABLE
* | [--->] IT_PARAMETERS                  TYPE        GTY_T_PARAMETERS
* | [<-()] RO_OUTPUT                      TYPE REF TO DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  method WORK.


    DATA: lt_input  TYPE STANDARD TABLE OF mara,
          lt_r_spras TYPE zacpf_tt_lg_dv_generic_range,
          lv_select TYPE string.
    lt_input = CORRESPONDING #( it_input ).

    CHECK lt_input IS NOT INITIAL.


    "Selection fields depend on parameters (select MAKTX or MAKTG)
    lv_select = |a~matnr, t~spras|.
    READ TABLE it_parameters WITH KEY name = 'UPPER' ASSIGNING FIELD-SYMBOL(<ls_param>).
    IF sy-subrc = 0 AND abap_on IN <ls_param>-value .
        lv_select = |{ lv_select }, t~maktg as maktx|.
    ELSE.
       lv_select = |{ lv_select }, t~maktx|.
    ENDIF.

    READ TABLE it_parameters WITH KEY name = 'SPRAS' ASSIGNING <ls_param>.
    IF sy-subrc = 0.
      lt_r_spras = <ls_param>-value.
    ENDIF.

    FIELD-SYMBOLS: <lt_output> TYPE STANDARD TABLE.
    DATA(lo_output) =  me->get_output_type( ).
    ASSIGN lo_output->* TO <lt_output>.

    SELECT (lv_select)
      FROM mara as a LEFT OUTER JOIN makt AS t on  t~matnr = a~matnr
                                               AND t~spras = 'E'
      FOR ALL ENTRIES IN @lt_input
      WHERE a~matnr = @lt_input-matnr
        AND t~spras IN @lt_r_spras
      INTO CORRESPONDING FIELDS OF TABLE @<lt_output>.

    GET REFERENCE OF <lt_output> INTO ro_output.

  endmethod.
ENDCLASS.
