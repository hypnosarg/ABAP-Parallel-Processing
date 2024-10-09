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

  TRY.
      "Greedy usage, use as many parallel sessions as possible
      "this means all records will be divided by the ammount of available
      "sessions and processed at once
      DATA(lo_result) = lo_paral->process(
        EXPORTING
          iv_servergroup   = 'AB_PARALLEL_PROC'
        CHANGING
          ct_data        = <lt_input>

      ).


      "LImit resource usage to a max, like 50%, no max threads
      "so this means the 5000 records will be divided by <AvAILABLE_RESOURCES> DIV 2
      "and all threads triggered at the same time
      DATA(lo_result2) = lo_paral->process(
        EXPORTING
          iv_servergroup   = 'AB_PARALLEL_PROC'
          iv_resource_perc = 50
        CHANGING
          ct_data        = <lt_input>

      ).

      "If we also set package size, it means we use up to max 50% of resources and packages are fixed at 2500 records
      "in this case as we know we have 5k records it means we will trigger no more than 2 threads in parallel
      DATA(lo_result3) = lo_paral->process(
        EXPORTING
          iv_servergroup   = 'AB_PARALLEL_PROC'
          iv_resource_perc = 50
          iv_pckg_size     = 2500
        CHANGING
          ct_data        = <lt_input>

      ).

      "We can also choose to indicate how many threads we want to dive the work by
      "note that the parameter is for max ammount of parallel tasks, not total
      "if we don't set a pacakge size it means we dive the whole dataset in the number of tasks indicated
      "(or less depending on availability).
      DATA(lo_result4) = lo_paral->process(
        EXPORTING
          iv_servergroup         = 'AB_PARALLEL_PROC'
          iv_max_tasks_parallel  = 3
        CHANGING
          ct_data        = <lt_input>

      ).

      "If we also set the package size, then it means we will open new threads to process
      "500 records  up to three in parallel, until all records are processsd
      DATA(lo_result5) = lo_paral->process(
        EXPORTING
          iv_servergroup         = 'AB_PARALLEL_PROC'
          iv_max_tasks_parallel  = 3
          iv_pckg_size           = 500
        CHANGING
          ct_data        = <lt_input>

      ).


      FIELD-SYMBOLS: <lt_out> TYPE STANDARD TABLE.
      ASSIGN lo_result->* TO <lt_out>.

      BREAK-POINT.

    CATCH zcx_caut_parallel_processor INTO DATA(lo_exc).
      "DO something on error
      MESSAGE lo_exc->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
