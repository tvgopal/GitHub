CREATE OR REPLACE PACKAGE BODY APPS.QST_TIMS_SIEBEL_FULFILMENT_PKG
IS
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

PROCEDURE output (p_msg IN VARCHAR2)
IS
BEGIN
   fnd_file.put_line (fnd_file.OUTPUT, p_msg);
EXCEPTION
   WHEN OTHERS
   THEN
      fnd_file.put_line (fnd_file.LOG, SQLERRM);
END output;

PROCEDURE LOG (p_msg IN VARCHAR2)
IS
BEGIN
   fnd_file.put_line (fnd_file.LOG, p_msg);
EXCEPTION
   WHEN OTHERS
   THEN
      fnd_file.put_line (fnd_file.LOG, SQLERRM);
END LOG;
 PROCEDURE main ( errbuf            OUT VARCHAR2,
                              retcode           OUT VARCHAR2,
                              p_sfdc_quote IN VARCHAR2,
                              p_sfdc_date_from   IN     VARCHAR2,
                              p_sfdc_date_to   IN     VARCHAR2
                             )
  IS
   v_last_run_date date;
   v_request_id  number := fnd_global.conc_request_id;
   v_counter number := 0;
   v_inprocess_rec_count  number := 0;
   v_last_request_id number := 0;
   v_status_flag varchar2(1);
   v_error_flag varchar2(1) := 'X';
   v_error_message varchar2(4000);
   v_delimiter varchar2(1) := ',';
   v_err_delimiter varchar2(1) := '~';
   v_inv_error_message varchar2(4000) := NULL;
   v_sc_error_message varchar2(4000) := NULL;
   v_online_sales_flag varchar2(1) := 'N';
   v_zuora_inv_num varchar2(500);
   v_hold_rec_count NUMBER := 0;
   v_total_rec_count NUMBER := 0;

i number;

TYPE invoice_rec
   IS                RECORD
   (zuora_invoice_num varchar2(500),
    request_id number);

TYPE invoice_tbl IS TABLE OF invoice_rec
  INDEX by binary_integer;
   qst_invoice_hdr_tbl invoice_tbl;


TYPE qst_zuora_invoice_tab IS TABLE OF qst_zuora_invoice%ROWTYPE
 INDEX by binary_integer;
   qst_zuora_invoice_tbl qst_zuora_invoice_tab;

TYPE qst_zuora_sales_credits_tab IS TABLE OF qst_zuora_sales_credits%ROWTYPE
 INDEX by binary_integer;
   qst_zuora_sales_credits_tbl qst_zuora_sales_credits_tab;
   BEGIN
      LOG ('Parameters:');
      LOG (' p_sfdc_quote:'||p_sfdc_quote);
      LOG (' p_sfdc_date_from:'||p_sfdc_date_from);
      LOG (' p_sfdc_date_to:'||p_sfdc_date_to);

/*
-----------------------------------------------------------------------
-- Get last succesful run date and request_id
-----------------------------------------------------------------------
FOR c_last_run IN (select max(request_id) request_id  from QST_TIMS_SIEBEL_REQUEST where status_flag = 'Y' and attribute2 is null)
loop
   v_last_request_id := c_last_run.request_id;
end loop;

FOR c_last_run IN (select max(last_updated_date) run_date   from QST_TIMS_SIEBEL_REQUEST where request_id = v_last_request_id)
loop
   v_last_run_date := c_last_run.run_date;
end loop;

LOG('last_run_date:'||to_char(v_last_run_date,'DD-MON-YY hh24:mi:ss')||' request_id:'||v_last_request_id);
*/
-----------------------------------------------------------------------
     -- Insert into staging table
-----------------------------------------------------------------------
INSERT INTO QST_TIMS_SIEBEL_REQUEST (RUN_ID,
                               STATUS_FLAG,
                               ERROR_MESSAGE,
                               REQUEST_ID,
                               CREATION_DATE,
                               CREATED_BY,
                               LAST_UPDATED_DATE,
                               LAST_UPDATED_BY,
                               QUOTE_DATE_FROM,
                               QUOTE_DATE_TO,
                               QUOTE_NUMBER)
     VALUES (QST_TIMS_SIEBEL_REQUEST_s.NEXTVAL,
             'N',
             NULL,
             v_request_id,
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.user_id,
             decode(p_sfdc_date_from, NULL,NULL,to_char(to_date(p_sfdc_date_from ,'RRRR/MM/DD HH24:MI:SS'),'yyyy-mm-dd')||'T'||to_char(to_date(p_sfdc_date_from ,'RRRR/MM/DD HH24:MI:SS'), 'HH24:MI:SS')||'.000'|| sessiontimezone),  --p_sfdc_date_from,
              decode(p_sfdc_date_from, NULL,NULL,to_char(to_date(p_sfdc_date_to ,'RRRR/MM/DD HH24:MI:SS'),'yyyy-mm-dd')||'T'||to_char(to_date(p_sfdc_date_to ,'RRRR/MM/DD HH24:MI:SS'), 'HH24:MI:SS')||'.000'|| sessiontimezone),  --p_sfdc_date_to
             p_sfdc_quote);

COMMIT;

-----------------------------------------------------------------------
-- Wait for SOA Composite to complete TIMS Siebel Fulfilment process
-----------------------------------------------------------------------
LOOP
v_counter := v_counter + 1;

SELECT status_flag, error_message
  INTO v_status_flag, v_error_message
  FROM QST_TIMS_SIEBEL_REQUEST
 WHERE request_id = v_request_id;

LOG(to_char(sysdate, 'HH24:mi:ss')||' v_status_flag:'||v_status_flag||' v_error_message:'||v_error_message );
exit when (v_status_flag = 'Y' OR v_status_flag = 'E');
DBMS_LOCK.sleep(10);
exit when v_counter = 30;  --360;                           -- exit after one hour
END loop;

if v_counter >= 360 then
   errbuf := errbuf ||' Terminating process after one hour... Investigate further';
   retcode := 1;
end if;

         log('--------------------------------------');



/*
-----------------------------------------------------------------------
--write to output file
-----------------------------------------------------------------------
qst_invoice_hdr_tbl.delete;
qst_zuora_invoice_tbl.delete;
qst_zuora_sales_credits_tbl.delete;

SELECT distinct zuora_invoice_num, request_id
BULK COLLECT INTO qst_invoice_hdr_tbl
from qst_zuora_invoice where request_id = v_request_id;

if qst_invoice_hdr_tbl.count = 0 then
   log('no invoices to output');
   goto skip_process;
end if;

        -----------------------------------------------------------------------
        --write header labels to output file
        -----------------------------------------------------------------------
         output('SOURCE_NAME'||v_delimiter||
                    'ORGANIZATION_NAME'||v_delimiter||
                    'ORG_ID'||v_delimiter||
                    'ZUORA_SUBSCRIPTION_ID'||v_delimiter||
                    'SOLD_TO_ACCT_ID'||v_delimiter||
                   'SHIP_TO_ACCT_ID'||v_delimiter||
                   'BILL_TO_ACCT_ID'||v_delimiter||
                    'SOLD_TO_CUSTOMER_NAME'||v_delimiter||
                    'BILL_TO_CUSTOMER_NAME'||v_delimiter||
                    'BILL_TO_ADDR_ID'||v_delimiter||
                    'BILL_TO_CONTACT_FIRST_NAME'||v_delimiter||
                    'BILL_TO_CONTACT_LAST_NAME'||v_delimiter||
                    'BILL_TO_CONTACT_ID'||v_delimiter||
                    'SHIP_TO_CUSTOMER_NAME'||v_delimiter||
                    'SHIP_TO_ADDR_ID'||v_delimiter||
                    'SHIP_TO_CONTACT_FIRST_NAME'||v_delimiter||
                    'SHIP_TO_CONTACT_LAST_NAME'||v_delimiter||
                    'SHIP_TO_CONTACT_ID'||v_delimiter||
                    'CURRENCY_CODE'||v_delimiter||
                    'CONVERSION_RATE'||v_delimiter||
                    'CONVERSION_TYPE'||v_delimiter||
                    'SALESREP_NAME'||v_delimiter||
                    'SALESREP_ID'||v_delimiter||
                    'SALESREP_NUMBER'||v_delimiter||
                    'PURCHASE_ORDER'||v_delimiter||
                    'TERM_NAME'||v_delimiter||
                    'ZUORA_INVOICE_NUM'||v_delimiter||
                    'INVOICE_DATE'||v_delimiter||
                    'INVOICE_TYPE'||v_delimiter||
                    'LINE_NUMBER'||v_delimiter||
                    'LINE_TYPE'||v_delimiter||
                    'PRODUCT_CODE'||v_delimiter||
                    'QUANTITY'||v_delimiter||
                    'UOM_CODE'||v_delimiter||
                    'UNIT_PRICE_AFTER_DISCOUNT'||v_delimiter||
                    'INVOICE_LINE_AMT'||v_delimiter||
                    'SIEBEL_LINE_TYPE'||v_delimiter||
                    'TERM_START_DATE'||v_delimiter||
                    'TERM_END_DATE'||v_delimiter||
                    'TAX_RATE'||v_delimiter||
                    'TAX_AMOUNT'||v_delimiter||
                    'COMMENTS'||v_delimiter||
                    'CREATION_DATE'||v_delimiter||
                    'CREATED_BY'||v_delimiter||
                    'LAST_UPDATED_DATE'||v_delimiter||
                    'LAST_UPDATED_BY'||v_delimiter||
                    'REQUEST_ID'||v_delimiter||
                    'ERROR_MESSAGE'||v_delimiter||
                    'STATUS_FLAG'||v_delimiter||
                    'ATTRIBUTE1'||v_delimiter||
                    'ORACLE_INVOICE_NUMBER'||v_delimiter||
                    'ZUORA_INVOICE_LINE_ID'||v_delimiter||
                    'RATE_PLAN'||v_delimiter||
                    'SKU_TL'||v_delimiter||
                    'SKU_TS'||v_delimiter||
                    'CHARGE_NAME'||v_delimiter||
                    'CHARGE_TYPE'||v_delimiter||
                    'SKU '||v_delimiter||
                    'DELIVERY_METHOD '||v_delimiter||
                    'SALES_COMP_COMMITMENT_AMT'||v_delimiter||
                    'ATTRIBUTE2'||v_delimiter||
                    'ATTRIBUTE3'||v_delimiter||
                    'ATTRIBUTE4 '||v_delimiter||
                    'ATTRIBUTE5 '||v_delimiter||
                    'ATTRIBUTE6 '||v_delimiter||
                    'ATTRIBUTE7 '||v_delimiter||
                    'ATTRIBUTE8 '||v_delimiter||
                    'ATTRIBUTE9 '||v_delimiter||
                    'ATTRIBUTE10 '||v_delimiter||
                    'ATTRIBUTE11'||v_delimiter||
                    'ATTRIBUTE12'||v_delimiter||
                    'ATTRIBUTE13'
                     );
--Invoice Level Loop
FOR m in 1..qst_invoice_hdr_tbl.count
loop

        SELECT *
        BULK COLLECT INTO qst_zuora_invoice_tbl
        from qst_zuora_invoice where request_id = qst_invoice_hdr_tbl(m).request_id
          and zuora_invoice_num = qst_invoice_hdr_tbl(m).zuora_invoice_num;

        -- Invoice Item Level loop
        FOR i in 1..qst_zuora_invoice_tbl.count
        loop

                 output(qst_zuora_invoice_tbl(i).SOURCE_NAME||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).ORGANIZATION_NAME||'"'||v_delimiter||
                            qst_zuora_invoice_tbl(i).ORG_ID||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).ZUORA_SUBSCRIPTION_ID||'"'||v_delimiter||
                            qst_zuora_invoice_tbl(i).SOLD_TO_ACCT_ID||v_delimiter||
                           qst_zuora_invoice_tbl(i).SHIP_TO_ACCT_ID||v_delimiter||
                           qst_zuora_invoice_tbl(i).BILL_TO_ACCT_ID||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).SOLD_TO_CUSTOMER_NAME||'"'||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).BILL_TO_CUSTOMER_NAME||'"'||v_delimiter||
                            qst_zuora_invoice_tbl(i).BILL_TO_ADDR_ID||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).BILL_TO_CONTACT_FIRST_NAME||'"'||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).BILL_TO_CONTACT_LAST_NAME||'"'||v_delimiter||
                            qst_zuora_invoice_tbl(i).BILL_TO_CONTACT_ID||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).SHIP_TO_CUSTOMER_NAME||'"'||v_delimiter||
                            qst_zuora_invoice_tbl(i).SHIP_TO_ADDR_ID||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).SHIP_TO_CONTACT_FIRST_NAME||'"'||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).SHIP_TO_CONTACT_LAST_NAME||'"'||v_delimiter||
                            qst_zuora_invoice_tbl(i).SHIP_TO_CONTACT_ID||v_delimiter||
                            qst_zuora_invoice_tbl(i).CURRENCY_CODE||v_delimiter||
                            qst_zuora_invoice_tbl(i).CONVERSION_RATE||v_delimiter||
                            qst_zuora_invoice_tbl(i).CONVERSION_TYPE||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).SALESREP_NAME||'"'||v_delimiter||
                            qst_zuora_invoice_tbl(i).SALESREP_ID||v_delimiter||
                            qst_zuora_invoice_tbl(i).SALESREP_NUMBER||v_delimiter||
                            qst_zuora_invoice_tbl(i).PURCHASE_ORDER||v_delimiter||
                            qst_zuora_invoice_tbl(i).TERM_NAME||v_delimiter||
                            qst_zuora_invoice_tbl(i).ZUORA_INVOICE_NUM||v_delimiter||
                            to_char(qst_zuora_invoice_tbl(i).INVOICE_DATE, 'DD-MON-YY HH24:MI:SS')||v_delimiter||
                            qst_zuora_invoice_tbl(i).INVOICE_TYPE||v_delimiter||
                            qst_zuora_invoice_tbl(i).LINE_NUMBER||v_delimiter||
                            qst_zuora_invoice_tbl(i).LINE_TYPE||v_delimiter||
                            qst_zuora_invoice_tbl(i).PRODUCT_CODE||v_delimiter||
                            qst_zuora_invoice_tbl(i).QUANTITY||v_delimiter||
                            qst_zuora_invoice_tbl(i).UOM_CODE||v_delimiter||
                            qst_zuora_invoice_tbl(i).UNIT_PRICE_AFTER_DISCOUNT||v_delimiter||
                            qst_zuora_invoice_tbl(i).INVOICE_LINE_AMT||v_delimiter||
                            qst_zuora_invoice_tbl(i).SIEBEL_LINE_TYPE||v_delimiter||
                            to_char(qst_zuora_invoice_tbl(i).TERM_START_DATE, 'DD-MON-YY HH24:MI:SS')||v_delimiter||
                            to_char(qst_zuora_invoice_tbl(i).TERM_END_DATE, 'DD-MON-YY HH24:MI:SS')||v_delimiter||
                            qst_zuora_invoice_tbl(i).TAX_RATE||v_delimiter||
                            qst_zuora_invoice_tbl(i).TAX_AMOUNT||v_delimiter||
                            qst_zuora_invoice_tbl(i).COMMENTS||v_delimiter||
                            to_char(qst_zuora_invoice_tbl(i).CREATION_DATE, 'DD-MON-YY HH24:MI:SS')||v_delimiter||
                            qst_zuora_invoice_tbl(i).CREATED_BY||v_delimiter||
                            to_char(qst_zuora_invoice_tbl(i).LAST_UPDATED_DATE, 'DD-MON-YY HH24:MI:SS')||v_delimiter||
                            qst_zuora_invoice_tbl(i).LAST_UPDATED_BY||v_delimiter||
                            qst_zuora_invoice_tbl(i).REQUEST_ID||v_delimiter||
                            qst_zuora_invoice_tbl(i).ERROR_MESSAGE||v_delimiter||
                            qst_zuora_invoice_tbl(i).STATUS_FLAG||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE1||v_delimiter||
                            qst_zuora_invoice_tbl(i).ORACLE_INVOICE_NUMBER||v_delimiter||
                            qst_zuora_invoice_tbl(i).ZUORA_INVOICE_LINE_ID||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).RATE_PLAN||'"'||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).SKU_TL||'"'||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).SKU_TS||'"'||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).CHARGE_NAME||'"'||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).CHARGE_TYPE||'"'||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).SKU||'"'||v_delimiter||
                            '"'||qst_zuora_invoice_tbl(i).DELIVERY_METHOD||'"'||v_delimiter||
                            qst_zuora_invoice_tbl(i).SALES_COMP_COMMITMENT_AMT||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE2||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE3||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE4||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE5||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE6||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE7||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE8||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE9||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE10||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE11||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE12||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE13||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE14||v_delimiter||
                            qst_zuora_invoice_tbl(i).ATTRIBUTE15
                            );


        end loop;

             select * bulk collect into  qst_zuora_sales_credits_tbl
                from qst_zuora_sales_credits
               where request_id = qst_invoice_hdr_tbl(m).request_id
                  and zuora_invoice_num = qst_invoice_hdr_tbl(m).ZUORA_INVOICE_NUM;

            -----------------------------------------------------------------------
            --write sales credit header labels to output file
            -----------------------------------------------------------------------
               output(v_delimiter||'ZUORA_INVOICE_NUM'||v_delimiter||
                        'ZUORA_SUBSCRIPTION_ID '||v_delimiter||
                        'SALESREP_ID'||v_delimiter||
                        'SALESREP_NUMBER'||v_delimiter||
                        'SALES_CREDIT_TYPE'||v_delimiter||
                        'SALES_CREDIT_TYPE_ID'||v_delimiter||
                        'PERCENT'||v_delimiter||
                        'ZQUOTE_RECORD_ID'||v_delimiter||
                        'ATTRIBUTE1'||v_delimiter||
                        'ATTRIBUTE2'||v_delimiter||
                        'ATTRIBUTE3'||v_delimiter||
                        'ATTRIBUTE4'||v_delimiter||
                        'ATTRIBUTE5'||v_delimiter||
                        'ATTRIBUTE6'||v_delimiter||
                        'ATTRIBUTE7'
                        );

               FOR k in 1..qst_zuora_sales_credits_tbl.COUNT
               LOOP
                 output (v_delimiter||qst_zuora_sales_credits_tbl(k).ZUORA_INVOICE_NUM||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).ZUORA_SUBSCRIPTION_ID ||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).SALESREP_ID||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).SALESREP_NUMBER||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).SALES_CREDIT_TYPE||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).SALES_CREDIT_TYPE_ID||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).PERCENT||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).ZQUOTE_RECORD_ID||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).ATTRIBUTE1||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).ATTRIBUTE2||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).ATTRIBUTE3||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).ATTRIBUTE4||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).ATTRIBUTE5||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).ATTRIBUTE6||v_delimiter||
                            qst_zuora_sales_credits_tbl(k).ATTRIBUTE7
                            ) ;
               END LOOP;

end loop;
*/

<<skip_process>>
  null;

   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, SQLERRM);
         retcode := '2';
   END main;

   PROCEDURE delete_invoice ( errbuf            OUT VARCHAR2,
                              retcode           OUT VARCHAR2,
                              p_zuora_invoice_num IN VARCHAR2
                             ) IS

   v_status_flag VARCHAR2(1);

   BEGIN

        log('Zuora Invoice Number:'||p_zuora_invoice_num);

        begin

        select max(status_flag) into v_status_flag from qst_zuora_invoice where zuora_invoice_num = p_zuora_invoice_num;

              if v_status_flag = 'P' then
                 log('Invoice already interfaced to Oracle');
                      retcode := '1';
              else
                  DELETE qst_zuora_sales_credits where  zuora_invoice_num = p_zuora_invoice_num;
                 log('Deleted '||sql%rowcount||' rows from qst_zuora_sales_credits');
                  DELETE qst_zuora_invoice where  zuora_invoice_num = p_zuora_invoice_num;
                 log('Deleted '||sql%rowcount||' rows from qst_zuora_invoice');
              end if;

        exception
             when no_data_found then
                log('Invoice not found in staging tables');
                     retcode := '1';
        end;


   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         fnd_file.put_line (fnd_file.LOG, 'Invoice does not exist in staging tables');
         retcode := '1';

      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, SQLERRM);
         retcode := '2';
   END delete_invoice;

    PROCEDURE add_months (input_date varchar2,
                                          months varchar2,
                                          output_date OUT varchar2) IS
                                          
   BEGIN
         
   select to_char(add_months(to_date(input_date,'MM/DD/YYYY'),months ),'MM/DD/YYYY') into output_date  from dual;
   
                                       
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, SQLERRM);
         output_date := NULL;
         
   END add_months;

    PROCEDURE convert_date_format (input_date varchar2,input_date_format varchar2, output_date_format varchar2, output_date OUT varchar2) IS
                                          
   BEGIN
         
   select to_char(to_date(input_date,input_date_format),output_date_format) into output_date  from dual;
   
                                       
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, SQLERRM);
         output_date := NULL;
         
   END convert_date_format;

END QST_TIMS_SIEBEL_FULFILMENT_PKG;
/
