CREATE OR REPLACE PACKAGE APPS.QST_ZUORA_REPORTS_PKG IS
-- +============================================================================+
-- |                                                                            |
-- |                            Dell Software Group (formerly Quest Software Inc)                              |
-- |                                                                            |
-- +============================================================================+
-- | Name               : QST_ZUORA_REPORTS_PKG                          |
-- | Description        : This package is used to generate reports related to  Zuora fusion connectors. 
-- |                     
-- |Input  Parameters    : p_request_date: invoices which have createdDate greater than this date shall be extracted
-- |Output Parameters    : None                                                 |
-- |                                                                            |
-- |Change Record:                                                              |
-- |===============                                                             |
-- |Version          Date                      Author                      Remarks                           |
-- |=======     ===========   =============   ==================================|
-- |1                  24-Sep-2014           TV Gopal                 Initial Draft version            |
--===============================================================================

   PROCEDURE Invoice_Report ( errbuf            OUT VARCHAR2,
                              retcode           OUT VARCHAR2,
                              p_zuora_invoice_num IN VARCHAR2,
                              p_zuora_inv_date_from IN VARCHAR2,
                              p_zuora_inv_date_to IN VARCHAR2,
                              p_request_id IN NUMBER,
                              p_errors_only VARCHAR2
                             -- p_request_date_from   IN     VARCHAR2,
                            --  p_request_date_to   IN     VARCHAR2,
                             );

   PROCEDURE Payment_Errors ( errbuf            OUT VARCHAR2,
                              retcode           OUT VARCHAR2,
                              p_oracle_receipt_num IN VARCHAR2
                             );
 
   PROCEDURE output (p_msg IN VARCHAR2);

   PROCEDURE LOG (p_msg IN VARCHAR2);

END QST_ZUORA_REPORTS_PKG;
/

