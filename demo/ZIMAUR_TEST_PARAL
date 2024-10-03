*&---------------------------------------------------------------------*
*& Report ZIMAUR_TEST_PARAL
*&---------------------------------------------------------------------*
*& Very simple example of the parallel processor tool. Just get
*& get article ids from MARA and  instantiate a processor to get
*& their description in many parallel processes
*&---------------------------------------------------------------------*
REPORT zimaur_test_paral.



INITIALIZATION.
  FIELD-SYMBOLS: <lt_input> TYPE STANDARD TABLE.
  DATA(lo_paral) = NEW zcl_tmp_paral_test( ).
  DATA(lo_input) = lo_paral->get_input_type( ).
  ASSIGN lo_input->* TO <lt_input>.


  SELECT matnr
    FROM mara
    INTO TABLE @<lt_input>
    UP TO 5000 ROWS.



  DATA(lo_result) = lo_paral->process(
    EXPORTING
      iv_servergroup = 'AB_PARALLEL_PROC'
      iv_pckg_size   = 100
    CHANGING
      ct_data        = <lt_input>

  ).



 FIELD-SYMBOLS: <lt_out> TYPE STANDARD TABLE.
 ASSIGN lo_result->* TO <lt_out>.

 BREAK-POINT.
