CREATE OR REPLACE PACKAGE APPS.QST_ZUORA_PAYMENTS_PKG IS
-- +============================================================================+
-- |                                                                            |
-- |                            Dell Software Group (formerly Quest Software Inc)                              |
-- |                                                                            |
-- +============================================================================+
-- | Name               : QST_ZUORA_PAYMENTS_PKG                          |
-- | Description        : This package is used to extract Oracle AR Receipts and create Zuora Payments using Fusion connector
-- |                     
-- |Input  Parameters    : p_receipt_number: Oracle Receipt Number (for testing). Invoices which have createdDate greater than this date shall be extracted
-- |Output Parameters    : None                                                 |
-- |                                                                            |
-- |Change Record:                                                              |
-- |===============                                                             |
-- |Version          Date                      Author                      Remarks                           |
-- |=======     ===========   =============   ==================================|
-- |1                  22-Jul-2014           TV Gopal                 Initial Draft version            |
--===============================================================================

      TYPE payment_tbl IS TABLE OF qst_zuora_payments_stg%rowtype  index by binary_integer;
      qst_payment_tbl payment_tbl;

   PROCEDURE main ( errbuf            OUT VARCHAR2,
                              retcode           OUT VARCHAR2,
                              p_receipt_number IN VARCHAR2,
                              p_receipt_date_from   IN VARCHAR2,
                              p_receipt_date_to   IN     VARCHAR2
                             );

   PROCEDURE update_payment_stg (p_receipt_number IN VARCHAR2,
                              p_receipt_date_from   IN VARCHAR2,
                              p_receipt_date_to   IN     VARCHAR2,
                              p_request_id IN NUMBER
                             );

END QST_ZUORA_PAYMENTS_PKG;
/

