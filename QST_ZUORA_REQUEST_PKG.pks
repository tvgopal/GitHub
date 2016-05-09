CREATE OR REPLACE PACKAGE APPS.QST_ZUORA_REQUEST_PKG IS
-- +============================================================================+
-- |                                                                            |
-- |                            Dell Software Group (formerly Quest Software Inc)                              |
-- |                                                                            |
-- +============================================================================+
-- | Name               : QST_ZUORA_REQUEST_PKG                          |
-- | Description        : This package is used to invoke the fusion connector to imports Zuora Invoices
-- |                     
-- |Input  Parameters    : p_request_date: invoices which have createdDate greater than this date shall be extracted
-- |Output Parameters    : None                                                 |
-- |                                                                            |
-- |Change Record:                                                              |
-- |===============                                                             |
-- |Version          Date                      Author                      Remarks                           |
-- |=======     ===========   =============   ==================================|
-- |1                  20-Jun-2014           TV Gopal                 Initial Draft version            |
--===============================================================================

   PROCEDURE main ( errbuf            OUT VARCHAR2,
                              retcode           OUT VARCHAR2,
                              p_zuora_invoice_num IN VARCHAR2,
                              p_request_date_from   IN     VARCHAR2,
                              p_request_date_to   IN     VARCHAR2
                             ); 

   PROCEDURE delete_invoice ( errbuf            OUT VARCHAR2,
                              retcode           OUT VARCHAR2,
                              p_zuora_invoice_num IN VARCHAR2
                             );

   PROCEDURE insert_request ( p_request_id NUMBER, p_run_id NUMBER, x_new_run_id OUT NUMBER
                             );

END QST_ZUORA_REQUEST_PKG;
/

