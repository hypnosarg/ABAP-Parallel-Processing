class ZCX_CAUT_PARALLEL_PROCESSOR definition
  public
  inheriting from CX_STATIC_CHECK
  create protected .

public section.

  interfaces IF_T100_MESSAGE .
  interfaces IF_T100_DYN_MSG .

  methods CONSTRUCTOR
    importing
      !TEXTID like IF_T100_MESSAGE=>T100KEY optional
      !PREVIOUS like PREVIOUS optional .
  class-methods RAISE_NO_RESOURCES
    importing
      !IV_SERVERGROUP type CLIKE optional .
protected section.
private section.
ENDCLASS.



CLASS ZCX_CAUT_PARALLEL_PROCESSOR IMPLEMENTATION.


  method CONSTRUCTOR.
CALL METHOD SUPER->CONSTRUCTOR
EXPORTING
PREVIOUS = PREVIOUS
.
clear me->textid.
if textid is initial.
  IF_T100_MESSAGE~T100KEY = IF_T100_MESSAGE=>DEFAULT_TEXTID.
else.
  IF_T100_MESSAGE~T100KEY = TEXTID.
endif.
  endmethod.


  METHOD raise_no_resources.
    DATA(ls_nores) = VALUE SCX_T100KEY( msgid = 'SPTA'
                                        msgno = '004'
                                        attr1 = iv_servergroup ).
    RAISE EXCEPTION TYPE zcx_caut_parallel_processor
      EXPORTING
        textid = ls_nores.
  ENDMETHOD.
ENDCLASS.
