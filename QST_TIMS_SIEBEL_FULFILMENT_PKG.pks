CREATE OR REPLACE PACKAGE APPS.QST_TIMS_SIEBEL_FULFILMENT_PKG IS
-- +============================================================================+
-- |                                                                            |
-- |                            Dell Software Group (formerly Quest Software Inc)                              |
-- |                                                                            |
-- +============================================================================+
-- | Name               : QST_TIMS_SIEBEL_FULFILMENT_PKG                          |
-- | Description        : This package is used to invoke the TIMS Siebel Fulfilment connector to manage TIMS Licenses and Siebel Assets
-- |
-- |Input  Parameters    : SFDC Quote, SFDC LastModified DateFrom and DateTo
-- |Output Parameters    : None                                                 |
-- |                                                                            |
-- |Change Record:                                                              |
-- |===============                                                             |
-- |Version          Date                      Author                      Remarks                           |
-- |=======     ===========   =============   ==================================|
-- |1                  25-Jun-2015           TV Gopal                 Initial Draft version            |
--===============================================================================

   PROCEDURE main ( errbuf            OUT VARCHAR2,
                              retcode           OUT VARCHAR2,
                              p_sfdc_quote IN VARCHAR2,
                              p_sfdc_date_from   IN     VARCHAR2,
                              p_sfdc_date_to   IN     VARCHAR2
                             );

    PROCEDURE add_months (input_date varchar2,
                                          months varchar2,
                                          output_date OUT varchar2);

   PROCEDURE convert_date_format (input_date varchar2,input_date_format varchar2, output_date_format varchar2, output_date OUT varchar2);
   
    
                                          
END QST_TIMS_SIEBEL_FULFILMENT_PKG;
/
