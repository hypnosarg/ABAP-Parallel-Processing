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


  method GET_INPUT_TYPE.
    "Returns a data reference to a table of the type we desire as input for our data packages
     TYPES: BEGIN OF lty_s_input,
              matnr TYPE matnr_d,
            END OF lty_s_input.

     CREATE DATA ro_data TYPE STANDARD TABLE OF lty_s_input.


  endmethod.


  method GET_OUTPUT_TYPE.
     "Returns a data reference to a table of the type we desire to contain processed data
     TYPES: BEGIN OF lty_s_output,
              matnr TYPE matnr_d,
              maktx TYPE makt-maktx,
            END OF lty_s_output.

     CREATE DATA ro_data TYPE STANDARD TABLE OF lty_s_output.
  endmethod.


  method WORK.

    "Simple example retrieve description for all the articles received in a work
    "package
    DATA: lt_input TYPE STANDARD TABLE OF mara.
    lt_input = CORRESPONDING #( it_input ).

    CHECK lt_input IS NOT INITIAL.

    FIELD-SYMBOLS: <lt_output> TYPE STANDARD TABLE.
    DATA(lo_output) =  me->get_output_type( ).
    ASSIGN lo_output->* TO <lt_output>.

    SELECT a~matnr, t~maktx
      FROM mara as a LEFT OUTER JOIN makt AS t on  t~matnr = a~matnr
                                               AND t~spras = 'E'
      FOR ALL ENTRIES IN @lt_input
      WHERE a~matnr = @lt_input-matnr
      INTO CORRESPONDING FIELDS OF TABLE @<lt_output>.

    GET REFERENCE OF <lt_output> INTO ro_output.

  endmethod.
ENDCLASS.
