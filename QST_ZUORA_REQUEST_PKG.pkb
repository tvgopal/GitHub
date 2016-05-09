CREATE OR REPLACE PACKAGE BODY QST_ZUORA_REQUEST_PKG
IS
   -- +============================================================================+
   -- |                                                                            |
   -- |                            Dell Software Group (formerly Quest Software Inc)                              |
   -- |                                                                            |
   -- +============================================================================+
   -- | Name               : QST_ZUORA_REQUEST_PKG                          |
   -- | Description        : This package is used to invoke the fusion connector to imports Zuora Invoices
   -- |
   -- |Input  Parameters    : request_date: invoices which have createdDate greater than this date shall be extracted
   -- |Output Parameters    : None                                                 |
   -- |                                                                            |
   -- |Change Record:                                                              |
   -- |===============                                                             |
   -- |Version          Date                      Author                      Remarks                           |
   -- |=======     ===========   =============   ==================================|
   -- |1                  20-Jun-2014           TV Gopal                 Initial Draft version            |
   --                       20-Aug-2014          TV Gopal                 Add new columns unit_price_after_discount, invoice_line_amt
   --                       15-Sep-2014          TV Gopal                 Added v_Error_flag.  Error status shall now be X for Fusion connector. Oracle process shall use E
   --                                                                                  Modified error handling logic for Online Sales
   --                       02-Jan-2015           TV Gopal                 DoD Phase 3 changes. Added date range parameters
 --                       24-Mar-2015           TV Gopal                Partner Model Changes (Code merged on 15-APR-2015)
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
                              p_zuora_invoice_num IN VARCHAR2,
                              p_request_date_from   IN     VARCHAR2,
                              p_request_date_to   IN     VARCHAR2
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
   l_new_run_id number := -1;
   
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
      LOG (' zuora_invoice_num:'||p_zuora_invoice_num);
      LOG (' p_request_date_from:'||p_request_date_from);
      LOG (' p_request_date_to:'||p_request_date_to);

-----------------------------------------------------------------------
-- Get last succesful run date and request_id
-----------------------------------------------------------------------
FOR c_last_run IN (select max(request_id) request_id  from qst_zuora_request where status_flag = 'Y' and attribute2 is null) 
loop
   v_last_request_id := c_last_run.request_id;
end loop;

FOR c_last_run IN (select max(last_updated_date) run_date   from qst_zuora_request where request_id = v_last_request_id) 
loop
   v_last_run_date := c_last_run.run_date;
end loop;

LOG('last_run_date:'||to_char(v_last_run_date,'DD-MON-YY hh24:mi:ss')||' request_id:'||v_last_request_id);

-----------------------------------------------------------------------
     -- Insert into staging table
-----------------------------------------------------------------------
INSERT INTO qst_zuora_request (RUN_ID,
                               STATUS_FLAG,
                               ERROR_MESSAGE,
                               REQUEST_ID,
                               CREATION_DATE,
                               CREATED_BY,
                               LAST_UPDATED_DATE,
                               LAST_UPDATED_BY,
                               ATTRIBUTE1,
                               ATTRIBUTE2,
                               ATTRIBUTE4,
                               ATTRIBUTE5)
     VALUES (qst_zuora_request_s.NEXTVAL,
             'N',
             NULL,
             v_request_id,  
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.user_id,
            to_char(v_last_run_date, 'yyyy-mm-dd')||'T'||to_char(v_last_run_date, 'HH24:MI:SS')||'.000'|| sessiontimezone,   --2013-07-01T00:00:00.000-08:00
             p_zuora_invoice_num,
             decode(p_request_date_from, NULL,NULL,to_char(to_date(p_request_date_from ,'RRRR/MM/DD HH24:MI:SS'),'yyyy-mm-dd')||'T'||to_char(to_date(p_request_date_from ,'RRRR/MM/DD HH24:MI:SS'), 'HH24:MI:SS')||'.000'|| sessiontimezone),  --p_request_date_from,
              decode(p_request_date_from, NULL,NULL,to_char(to_date(p_request_date_to ,'RRRR/MM/DD HH24:MI:SS'),'yyyy-mm-dd')||'T'||to_char(to_date(p_request_date_to ,'RRRR/MM/DD HH24:MI:SS'), 'HH24:MI:SS')||'.000'|| sessiontimezone)  --p_request_date_to
             );

COMMIT;

-----------------------------------------------------------------------
-- Wait for SOA Composite to complete extraction of Zuora Invoices  
-----------------------------------------------------------------------
LOOP
v_counter := v_counter + 1;

SELECT status_flag, error_message
  INTO v_status_flag, v_error_message
  FROM qst_zuora_request
 WHERE request_id = v_request_id;

LOG(to_char(sysdate, 'HH24:mi:ss')||' v_status_flag:'||v_status_flag||' v_error_message:'||v_error_message );
exit when (v_status_flag = 'Y' OR v_status_flag = 'E');
DBMS_LOCK.sleep(10);
exit when v_counter = 360;                           -- exit after one hour
END loop;

if v_counter >= 360 then
   errbuf := errbuf ||' Terminating process after one hour... Investigate further'; 
   retcode := 1;
end if;

         log('--------------------------------------');

FOR c_count_rec IN ( SELECT sum(decode(status_flag,'H',1,0)) hold_count, count(1) total_count from qst_zuora_invoice qzi where request_id = v_request_id) 
loop
    v_hold_rec_count := c_count_rec.hold_count;
    v_total_rec_count :=  c_count_rec.total_count;
end loop;

IF v_total_rec_count = 0 THEN
    log('No records to process in this run');
    goto skip_process;
END IF;





--==========================
-- Begin Post processing of tables after fusion connector completion
--==========================

-----------------------------------------------------------------------
-- Derive Org_id 
--Sales Comp Commitment Amount should be NULL for Usage chargeType and zero if sales credit lines do not exist. Default value from Fusion Connector is zero
-- bill-to and ship-to customer name should be same as sold-to customer name
-----------------------------------------------------------------------

/*        UPDATE qst_zuora_invoice qzi SET qzi.org_id = (select min(org_id) from qst_country_org_mapping qcom where qcom.country_name = nvl(qzi.attribute10,'United States'))
        ,sales_comp_commitment_amt = decode(UPPER(charge_type),'USAGE',NULL,decode(UPPER(attribute6), 'PER INVOICE',NULL,sales_comp_commitment_amt)), bill_to_customer_name = sold_to_customer_name, ship_to_customer_name = sold_to_customer_name
        --,attribute11 = v_request_id
        , status_flag = decode(error_message, NULL,status_flag,v_error_flag), created_by = fnd_global.user_id, last_updated_by = fnd_global.user_id
        where request_id = v_request_id;*/
        
        -- TVGopal 12/08/2015 Fix for missing request_id
         UPDATE qst_zuora_invoice qzi SET request_id = v_request_id where request_id IS NULL and creation_date between sysdate - 1/2 and sysdate;
        IF SQL%ROWCOUNT > 0 THEN
            LOG(SQL%ROWCOUNT||'  of qst_zuora_invoice with null request_id updated ' );
    END IF;

        -- TVGopal 12/08/2015 Fix for missing request_id
        UPDATE qst_zuora_sales_credits qzi SET request_id = v_request_id where request_id IS NULL and creation_date between sysdate - 1/2 and sysdate;
     IF SQL%ROWCOUNT > 0 THEN
            LOG(SQL%ROWCOUNT||'  of qst_zuora_sales_credits with null request_id updated ' );
    END IF;
   
        --DoD Phase 3 changes
        UPDATE qst_zuora_invoice qzi SET qzi.org_id = (select min(org_id) from qst_country_org_mapping qcom where qcom.country_name = nvl(qzi.attribute10,'United States'))
        ,sales_comp_commitment_amt = decode(UPPER(charge_type),'USAGE',0,decode(UPPER(attribute6), 'PER INVOICE',invoice_line_amt,nvl(sales_comp_commitment_amt,0))), 
        bill_to_customer_name = sold_to_customer_name, ship_to_customer_name = sold_to_customer_name, term_name = decode(attribute14,'Amendment',decode(term_name,null,'Net 30',term_name),term_name)
        ,bill_to_acct_id = nvl(bill_to_acct_id,sold_to_acct_id),ship_to_acct_id = nvl(ship_to_acct_id,sold_to_acct_id)
        , status_flag = decode(error_message, NULL,status_flag,v_error_flag), created_by = fnd_global.user_id, last_updated_by = fnd_global.user_id
        ,term_end_date = decode(attribute14,'Quote',add_months(term_start_date,initial_term), term_end_date)
        ,actual_start_date = decode(attribute14,'Quote',greatest(term_start_date,nvl(attributed1,term_start_date-1)),'Amendment', nvl(actual_start_date,attributed2),actual_start_date)
        ,submitted_date = nvl(submitted_date,decode(attribute14,'Amendment',trunc(sysdate),'Quote',trunc(sysdate), submitted_date))
        where request_id = v_request_id;

-----------------------------------------------------------------------
--Do not import invoices if already imported earlier into Oracle.  
-----------------------------------------------------------------------
i := 0;
FOR c_inv_rec in (select distinct zuora_invoice_num from qst_zuora_invoice qzi where request_id = v_request_id and exists (select 1 from qst_zuora_invoice qzi1 where qzi1.request_id != qzi.request_id and qzi1.zuora_invoice_num = qzi.zuora_invoice_num and nvl(status_flag,'N') IN ( 'P','E')))
loop
      if i = 1 THEN
         log('--------------------------------------------');
         log('Invoices already imported into Oracle:');
         log('--------------------------------------------');
      END IF;
      i := i + 1;
      log(c_inv_rec.zuora_invoice_num);
end loop;

DELETE qst_zuora_sales_credits qzi where request_id = v_request_id and exists (select 1 from qst_zuora_invoice qzi1 where qzi1.request_id != qzi.request_id and qzi1.zuora_invoice_num = qzi.zuora_invoice_num and nvl(status_flag,'N') IN ( 'P','N', 'E'));
    IF SQL%ROWCOUNT > 0 THEN
            LOG(SQL%ROWCOUNT||'  sales credit records from qst_zuora_sales_credits were already extracted into Oracle staging tables' );
    END IF;

DELETE qst_zuora_invoice qzi where request_id = v_request_id and exists (select 1 from qst_zuora_invoice qzi1 where qzi1.request_id != qzi.request_id and qzi1.zuora_invoice_num = qzi.zuora_invoice_num  and nvl(status_flag,'N') IN ( 'P', 'N','E'));
    IF SQL%ROWCOUNT > 0 THEN
        LOG(SQL%ROWCOUNT||'  invoice (line) records from qst_zuora_invoice were already extracted into Oracle staging tables' );
    END IF;

-----------------------------------------------------------------------
-- If invoice exists in table but not imported into Oracle, purge the older records and retain the current records for that invoice
-----------------------------------------------------------------------

DELETE qst_zuora_sales_credits qzi where request_id != v_request_id and nvl(status_flag,'N') NOT IN ('P','E','N') and zuora_invoice_num in (select distinct zuora_invoice_num from qst_zuora_invoice qzi2 where request_id = v_request_id);

    IF SQL%ROWCOUNT > 0 THEN
            LOG(SQL%ROWCOUNT||'  sales credits from qst_zuora_sales_credits purged' );
    END IF;

DELETE qst_zuora_invoice qzi where  request_id != v_request_id and nvl(status_flag,'N') NOT IN ('P','E','N') and zuora_invoice_num in (select distinct zuora_invoice_num from qst_zuora_invoice qzi2 where request_id = v_request_id);
    IF SQL%ROWCOUNT > 0 THEN
        LOG(SQL%ROWCOUNT||'  invoices from qst_zuora_invoice purged' );
    END IF;
 
         log('--------------------------------------');

-----------------------------------------------------------------------
-- Create default 'No Sales Credit' records where applicable
-----------------------------------------------------------------------

qst_zuora_invoice_tbl.delete;
qst_zuora_sales_credits_tbl.delete;

SELECT * 
BULK COLLECT INTO qst_zuora_invoice_tbl
from qst_zuora_invoice qzi where request_id = v_request_id and nvl(status_flag,'N') NOT IN ( 'X')
and not exists (select 1 from qst_zuora_sales_credits qzsc  where qzsc.zuora_invoice_num = qzi.zuora_invoice_num and qzi.request_id = qzsc.request_id);

FOR i in 1..qst_zuora_invoice_tbl.count
loop

    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count+1).zuora_invoice_num :=   qst_zuora_invoice_tbl(i).zuora_invoice_num;
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count).request_id                  :=   v_request_id;
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count). zquote_record_id       :=    NVL(qst_zuora_invoice_tbl(i).attribute11, '-1') ; 
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count).zuora_invoice_num      :=   qst_zuora_invoice_tbl(i).zuora_invoice_num ; 
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count).zuora_subscription_id  :=     qst_zuora_invoice_tbl(i).zuora_subscription_id; 
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count).salesrep_id  :=     -3 ; 
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count).salesrep_number        :=     '-3';  --'No Sales Credit' ; 
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count).sales_credit_type        :=     'Financial' ; 
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count).sales_credit_type_id        :=     1001 ; 
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count).percent                      :=       100 ; 
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count).created_by                 :=       fnd_global.user_id ; 
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count).creation_date              :=    SYSDATE ; 
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count).last_updated_by          :=      fnd_global.user_id ; 
    qst_zuora_sales_credits_tbl(qst_zuora_sales_credits_tbl.count).last_updated_date         :=      SYSDATE;
    log('Inserted No Sales Credit record for invoice:'||qst_zuora_invoice_tbl(i).zuora_invoice_num);
end loop;

FORALL j in 1..qst_zuora_sales_credits_tbl.count
INSERT INTO qst_zuora_sales_credits values qst_zuora_sales_credits_tbl(j);

-----------------------------------------------------------------------
-- Unique rows should exist in sales credits for a given combination of zquote_record_id, zuora_invoice_num,zuora_subscription_id, salesrep_number
-----------------------------------------------------------------------
       begin
        DELETE qst_zuora_sales_credits  where request_id = v_request_id and rowid not in
         (select max(rowid) from qst_zuora_sales_credits zsc where request_id = v_request_id
        group by zquote_record_id, zuora_invoice_num,zuora_subscription_id, salesrep_number, attribute8);
        IF SQL%ROWCOUNT > 0 THEN
            LOG('Deleted '||SQL%ROWCOUNT||' rows from qst_zuora_sales_credits' );
        END IF;
        
        exception
        when others then
           log('error updating qst_zuora_sales_credits  :'||sqlerrm);
        end;

-----------------------------------------------------------------------
-- Error handling for missing data elements
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

--Invoice Level Loop
--FOR m in 1..qst_invoice_hdr_tbl.count
--loop

        SELECT * 
        BULK COLLECT INTO qst_zuora_invoice_tbl
        from qst_zuora_invoice where request_id = v_request_id;
        --qst_invoice_hdr_tbl(m).request_id           and zuora_invoice_num = qst_invoice_hdr_tbl(m).zuora_invoice_num;

        log('********************************************** ');
         
        -- Invoice Item Level loop
        FOR i in 1..qst_zuora_invoice_tbl.count
        loop

            log(' ##### Invoice:'|| qst_zuora_invoice_tbl(i).zuora_invoice_num||' Zuor_Invoice_Line_id:'||qst_zuora_invoice_tbl(i).zuora_invoice_line_id);
         v_inv_error_message := qst_zuora_invoice_tbl(i).error_message;

                          -- TVGopal 08/05/2015 Issue 
                          --  IF qst_zuora_invoice_tbl(i).ATTRIBUTE14 = 'Invoice' THEN
                            IF qst_zuora_invoice_tbl(i).ATTRIBUTE14 = 'Invoice'  and qst_zuora_invoice_tbl(i).ATTRIBUTE8 IS NULL THEN
                                  v_online_sales_flag := 'Y';
                                  qst_zuora_invoice_tbl(i).org_id := 84;
                                  
                            ELSE
                                  v_online_sales_flag := 'N';
                            END IF;

              --v_inv_error_message := qst_zuora_invoice_tbl(i).rowid;
/*
One or more of these elements missing on Zuora Account - PaymentTerm, Currency, CrmId, SiebelAccountId__c, S_ShipTo_Address_ID__c, S_BillTo_Address_ID__c, Currency, PurchaseOrderNumber, BillToId, SoldToId 
One or more of these elements missing - Siebel_Row_Id__c, Siebel_Address_Row_Id__c, BillingCountry 
One or more of these elements missing -  FirstName, LastName
One or more of these elements missing - Siebel_Row_Id__c, FirstName, LastName  
Query Invoice  Item-  ServiceStartDate, ChargeAmount, ServiceEndDate, ProductDescription, SKU, Quantity, UnitPrice, UOM, RatePlanChargeId  
Query Zuora Subscription -  Name,ZQuoteRecordId__c, ServiceActivationDate,TermStartDate, TermEndDate
Query Zuora ProductRatePlan -  Name, Description, SKUTL__c, SKUTS__c, PaymentMethods__c  
ProductRatePlanCharge -  ChargeType, Name, ProductRatePlanId , SKU__c 

SFDC SalesComp -  Compensation_Type__c, Percent__c, Quote__c,Sales_Credit_ID__c,Sales_Rep__c,Sales_Rep_Name__c,SalesRepType__c 
SFDC ZQuote -  Sales_Comp_Type__c, Sales_Comp_Commitment_Amount__c
*/
                            
                            IF qst_zuora_invoice_tbl(i).ZUORA_SUBSCRIPTION_ID IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'Zuora Subscription is missing';
                                
                            END IF;

                            IF v_online_sales_flag = 'N' THEN 
                            

                                IF qst_zuora_invoice_tbl(i).SOLD_TO_ACCT_ID IS NULL THEN
                                    v_inv_error_message := v_inv_error_message||v_err_delimiter||'Siebel_Row_Id__c is missing on SFDC Account';
                                END IF;
                                
                                -- Commented as part of Partner Model changes
                                --IF qst_zuora_invoice_tbl(i).BILL_TO_CONTACT_ID IS NULL THEN
                                --    v_inv_error_message := v_inv_error_message||v_err_delimiter||'Siebel_Row_Id__c is missing on SFDC Contact';
                                --END IF;
                                IF qst_zuora_invoice_tbl(i).SHIP_TO_ADDR_ID IS NULL THEN
                                    v_inv_error_message := v_inv_error_message||v_err_delimiter||'S_ShipTo_Address_ID__c on Zuora Account  is missing';
                                END IF;
                                IF qst_zuora_invoice_tbl(i).BILL_TO_ADDR_ID IS NULL THEN
                                    v_inv_error_message := v_inv_error_message||v_err_delimiter||'S_BillTo_Address_ID__c on Zuora Account  is missing';
                                END IF;
                                IF qst_zuora_invoice_tbl(i).attribute11 IS NULL THEN
                                    v_inv_error_message := v_inv_error_message||v_err_delimiter||'ZQuoteRecordId on Zuora Subscription  is missing';
                                END IF;
                            
                            END IF;
                            
                           /*
                            IF qst_zuora_invoice_tbl(i).BILL_TO_CONTACT_LAST_NAME IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'SFDC Contact Last  Name is missing';
                            END IF;
                            IF qst_zuora_invoice_tbl(i).SHIP_TO_CONTACT_FIRST_NAME IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'Zuora Contact Fist Name is missing';
                            END IF;
                            IF qst_zuora_invoice_tbl(i).SHIP_TO_CONTACT_LAST_NAME IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'Zuora Contact Last Name is missing';
                            END IF;
                            IF qst_zuora_invoice_tbl(i).UOM_CODE IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'UOM on Zuora Invoice Item is missing';
                            END IF;
                            */
                            --IF qst_zuora_invoice_tbl(i).PURCHASE_ORDER IS NULL THEN
                            --    v_inv_error_message := v_inv_error_message||v_err_delimiter||'Purchase Order on Zuora Account is missing';
                            --END IF;
                            IF qst_zuora_invoice_tbl(i).TERM_NAME IS NULL THEN
                                
                                IF qst_zuora_invoice_tbl(i).attribute15 = 'Invoice' THEN
                                   v_inv_error_message := v_inv_error_message||v_err_delimiter||'Payment Term on Zuora Account  is missing';
                                END IF;
                                
                            END IF;
                            IF qst_zuora_invoice_tbl(i).CURRENCY_CODE IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'Currency Code on Zuora Account  is missing';
                            END IF;
                            IF qst_zuora_invoice_tbl(i).INVOICE_DATE IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'Due Date on Zuora Invoice is missing';
                            END IF;
                            IF qst_zuora_invoice_tbl(i).SKU IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'SKU on Invoice Item is missing';
                            END IF;
                            IF qst_zuora_invoice_tbl(i).QUANTITY IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'Quantity on Zuora Invoice Item is  missing';
                            END IF;
                            IF qst_zuora_invoice_tbl(i).UNIT_PRICE_AFTER_DISCOUNT IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'Charge Amount on Zuora Invoice Item is missing';
                            END IF;
                            IF qst_zuora_invoice_tbl(i).INVOICE_LINE_AMT IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'Unit Price on Zuora Invoice Item  is missing';
                            END IF;
                            IF qst_zuora_invoice_tbl(i).TERM_START_DATE IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'Service Start Date on Zuora Invoice Item  is missing';
                            END IF;
                            IF qst_zuora_invoice_tbl(i).TERM_END_DATE IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'Service End Date on Zuora Invoice Item  is missing';
                            END IF;
                            IF qst_zuora_invoice_tbl(i).CHARGE_TYPE IS NULL THEN
                                v_inv_error_message := v_inv_error_message||v_err_delimiter||'Charge Type on Zuora ProductRatePlanCharge  is missing';
                            END IF;
                            
/*
                            qst_zuora_invoice_tbl(i).RATE_PLAN||v_delimiter||
                            qst_zuora_invoice_tbl(i).SKU_TL||v_delimiter||
                            qst_zuora_invoice_tbl(i).SKU_TS||v_delimiter||
                            qst_zuora_invoice_tbl(i).CHARGE_NAME||v_delimiter||
                            qst_zuora_invoice_tbl(i).CHARGE_TYPE||v_delimiter||
                            qst_zuora_invoice_tbl(i).SKU||v_delimiter||
                            qst_zuora_invoice_tbl(i).DELIVERY_METHOD||v_delimiter||
                            qst_zuora_invoice_tbl(i).SALES_COMP_COMMITMENT_AMT||v_delimiter||
*/


                        qst_zuora_invoice_tbl(i).ERROR_MESSAGE := SUBSTR(v_inv_error_message,1,4000);
                        
                        IF qst_zuora_invoice_tbl(i).ERROR_MESSAGE IS  NOT NULL THEN
                            retcode := 1;
                            qst_zuora_invoice_tbl(i).status_flag := v_error_flag;
                        END IF;
--=====================================DoD Phase 3.1  (not required for 3.0)

                             /*
                             FOR c_chron_check IN (select distinct zuora_invoice_num  from qst_zuora_invoice z
                             where request_id = v_request_id and  attribute14 in ('Amendment') and attribute15 = qst_zuora_invoice_tbl(i).attribute15    -- attribute15 has the SubscriptionName
                                and zuora_invoice_num != qst_zuora_invoice_tbl(i).zuora_invoice_num
                                and not exists (select 1 from apps.ra_customer_trx_all rct where  interface_header_context = 'Zuora' 
                                                         and interface_header_attribute1 = z.zuora_invoice_num))
                               LOOP
                               
                                     log('Chronological order creation check- Zuora Invoice Number :'||v_zuora_inv_num ||' does not exist in Oracle');     
                                                          
                                     qst_zuora_invoice_tbl(i).ERROR_MESSAGE := SUBSTR(qst_zuora_invoice_tbl(i).ERROR_MESSAGE||' Chronological order Check failed. Place on hold',1,4000);
                                     
                                     -- if due to an error above, status_flag is already marked as X, then leave it as X. Else mark as H for On Hold.
                                     
                                     if qst_zuora_invoice_tbl(i).status_flag  is null then
                                      qst_zuora_invoice_tbl(i).status_flag := 'H';
                                     end if;
                                     
                               END LOOP;
                                                       
                               */  


--==========================
                    
                    log('Invoice:'||qst_zuora_invoice_tbl(i).zuora_invoice_num||' Zuora_Invoice_Line_Id:'||qst_zuora_invoice_tbl(i).Zuora_Invoice_Line_Id||' Error Message:'||qst_zuora_invoice_tbl(i).ERROR_MESSAGE );
        end loop;

        FORALL p in 1..qst_zuora_invoice_tbl.count
        --UPDATE qst_zuora_invoice set error_message = qst_zuora_invoice_tbl(p).ERROR_MESSAGE, status_flag = decode(qst_zuora_invoice_tbl(p).ERROR_MESSAGE,NULL,status_flag,v_error_flag), org_id = qst_zuora_invoice_tbl(p).org_id 
        UPDATE qst_zuora_invoice set error_message = qst_zuora_invoice_tbl(p).ERROR_MESSAGE, status_flag = qst_zuora_invoice_tbl(p).status_flag, org_id = qst_zuora_invoice_tbl(p).org_id 
        WHERE request_id = qst_zuora_invoice_tbl(p).request_id and zuora_invoice_num = qst_zuora_invoice_tbl(p).zuora_invoice_num
        and zuora_invoice_line_id = qst_zuora_invoice_tbl(p).zuora_invoice_line_id;

             select * bulk collect into  qst_zuora_sales_credits_tbl
                from qst_zuora_sales_credits
               where request_id = v_request_id;
               --qst_invoice_hdr_tbl(m).request_id                   and zuora_invoice_num = qst_invoice_hdr_tbl(m).ZUORA_INVOICE_NUM;
                 
               IF v_online_sales_flag = 'N' THEN
               
                       IF qst_zuora_sales_credits_tbl.COUNT = 0 THEN
                           v_sc_error_message := v_sc_error_message||v_err_delimiter|| 'Could not derive SFDC Sales Comp. Verify ZQuoteRecordId is valid on Zuora subscription';
                       END IF;
                       
                       FOR k in 1..qst_zuora_sales_credits_tbl.COUNT   
                       LOOP 
                      v_sc_error_message := NULL;
                                    IF qst_zuora_sales_credits_tbl(k).PERCENT IS NULL THEN
                                        v_sc_error_message := v_sc_error_message||v_err_delimiter||'Percent on SFDC Sales Comp is missing';
                                    END IF;
                                    IF qst_zuora_sales_credits_tbl(k).SALESREP_NUMBER IS NULL THEN
                                        v_sc_error_message := v_sc_error_message||v_err_delimiter||'Salesrep number on SFDC Sales Comp is missing';
                                    END IF;
                                    IF qst_zuora_sales_credits_tbl(k).SALES_CREDIT_TYPE IS NULL THEN
                                        v_sc_error_message := v_sc_error_message||v_err_delimiter||'Salescredit type is missing on SFDC Sales Comp is missing';
                                    END IF;
                                    IF qst_zuora_sales_credits_tbl(k).SALESREP_NUMBER IS NULL THEN
                                        v_sc_error_message := v_sc_error_message||v_err_delimiter||'Salesrep number on SFDC Sales Comp is missing';
                                    END IF;
                                qst_zuora_sales_credits_tbl(k).ERROR_MESSAGE := SUBSTR(v_sc_error_message,1,4000);
                                
                                IF qst_zuora_sales_credits_tbl(k).ERROR_MESSAGE IS NOT NULL THEN
                                    retcode := 1;
                                END IF;
                            
                            log('Invoice:'||qst_zuora_sales_credits_tbl(k).zuora_invoice_num||' Salesrep_number:'||qst_zuora_sales_credits_tbl(k).SALESREP_NUMBER||' Error Message:'||qst_zuora_sales_credits_tbl(k).ERROR_MESSAGE );
                       END LOOP;   

                        FORALL q in 1..qst_zuora_sales_credits_tbl.count
                        UPDATE qst_zuora_sales_credits set error_message = qst_zuora_sales_credits_tbl(q).ERROR_MESSAGE, status_flag = decode(qst_zuora_sales_credits_tbl(q).ERROR_MESSAGE,NULL,status_flag,v_error_flag)
                        WHERE request_id = qst_zuora_sales_credits_tbl(q).request_id and zuora_invoice_num = qst_zuora_sales_credits_tbl(q).zuora_invoice_num
                        and attribute8 = qst_zuora_sales_credits_tbl(q).attribute8;
               END IF;
               
    -- Update invoice lines table status if sales comp has errors
    UPDATE qst_zuora_invoice set status_flag = v_error_flag, error_message = error_message|| ' Sales Comp errors' where request_id = v_request_id
    and zuora_invoice_num = (select max(zuora_invoice_num) from qst_zuora_sales_credits where request_id = v_request_id and status_flag = v_error_flag ); 


-- End Post processing of tables after fusion connector completion
--==========================

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
                'REVENUE_TYPE'||v_delimiter||
                'SUBSCRIPTION_TYPE'||v_delimiter||
                'BASE_SUBSCRIPTION_NAME'||v_delimiter||
                'SUBMITTED_DATE'||v_delimiter||
                'RPC_TCV'||v_delimiter||
                'RPC_MRR'||v_delimiter||
                'RPC_BILLING_PERIOD'||v_delimiter||
                'ACTUAL_START_DATE'||v_delimiter||
                'SOURCE'||v_delimiter||
                'INITIAL_TERM'||v_delimiter||
                'RENEWAL_TERM'||v_delimiter||
                'AUTO_RENEW'||v_delimiter||
                'ORDER_ORIGINATION'||v_delimiter||
                'CHARGE_DESCRIPTION'||v_delimiter||
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
                            qst_zuora_invoice_tbl(i).REVENUE_TYPE||v_delimiter||
                        qst_zuora_invoice_tbl(i).SUBSCRIPTION_TYPE||v_delimiter||
                        qst_zuora_invoice_tbl(i).BASE_SUBSCRIPTION_NAME||v_delimiter||
                        qst_zuora_invoice_tbl(i).SUBMITTED_DATE||v_delimiter||
                        qst_zuora_invoice_tbl(i).RPC_TCV||v_delimiter||
                        qst_zuora_invoice_tbl(i).RPC_MRR||v_delimiter||
                        qst_zuora_invoice_tbl(i).RPC_BILLING_PERIOD||v_delimiter||
                        qst_zuora_invoice_tbl(i).ACTUAL_START_DATE||v_delimiter||
                        qst_zuora_invoice_tbl(i).SOURCE||v_delimiter||
                        qst_zuora_invoice_tbl(i).INITIAL_TERM||v_delimiter||
                        qst_zuora_invoice_tbl(i).RENEWAL_TERM||v_delimiter||
                        qst_zuora_invoice_tbl(i).AUTO_RENEW||v_delimiter||
                        qst_zuora_invoice_tbl(i).ORDER_ORIGINATION||v_delimiter||
                        qst_zuora_invoice_tbl(i).CHARGE_DESCRIPTION||v_delimiter||
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

-- Added  by VGOPAL on 01/07/2016 for Fusion Connector Performance Improvement
-- Only for scheduled run, launch multi-threaded requests. If specific parameters such as Invoice Number or Request Date Range are passed, do not launch.
IF p_zuora_invoice_num IS NULL AND p_request_date_from   IS NULL AND  p_request_date_to   IS NULL then

            apps.qst_zuora_request_pkg.insert_request ( p_request_id => v_request_id, 
                                    p_run_id => NULL, 
                                    x_new_run_id => l_new_run_id
                                         ) ;

end if;

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
   -- Added by VGOPAL on 01/07/2016 for Fusion Connector Performance improvement
   PROCEDURE insert_request ( p_request_id NUMBER, p_run_id NUMBER, x_new_run_id OUT NUMBER
                             ) IS
                             
   v_total_invoice_count number;
   v_batch_size number;
   v_request_count number := 0;
  v_request_id  number := 0;
   BEGIN
        
        log('p_request_id:'||p_request_id||' p_run_id:'||p_run_id);

   if p_request_id is null and p_run_id is null then
        log('p_request_id and p_run_id are both null');
        goto skip_process;
   end if;
   
   for c_get_request_count in (select count(1) req_count from apps.qst_zuora_request where request_id = p_request_id  )
   loop
      v_request_count := c_get_request_count.req_count;
   end loop;
  
  if v_request_count = 10 then
        log(' Launched 10 requests for request_id:'||p_request_id);
        goto skip_process;
  end if;
   
for c_get_request_rec in (select nvl(attribute6,0) total_invoice_count, nvl(attribute7,0) batch_size from apps.qst_zuora_request where 1=1 and request_id = nvl(p_request_id,request_id) 
                                        and run_id = nvl(p_run_id, run_id))
loop

    v_total_invoice_count := nvl(to_number(c_get_request_rec.total_invoice_count),0);
    v_batch_size := nvl(to_number(c_get_request_rec.batch_size),0); 

   log('v_total_invoice_count:'||v_total_invoice_count||' v_batch_size:'||v_batch_size);
   
    if v_total_invoice_count > v_batch_size then
    -----------------------------------------------------------------------
         -- Insert into staging table
    -----------------------------------------------------------------------
    
    log('Insert new request...');
 
/*   
    INSERT INTO qst_zuora_request (RUN_ID,
                                   STATUS_FLAG,
                                   ERROR_MESSAGE,
                                   REQUEST_ID,
                                   CREATION_DATE,
                                   CREATED_BY,
                                   LAST_UPDATED_DATE,
                                   LAST_UPDATED_BY,
                                   ATTRIBUTE1,
                                   ATTRIBUTE2,
                                   ATTRIBUTE4,
                                   ATTRIBUTE5)
         VALUES (qst_zuora_request_s.NEXTVAL,
                 'N',
                 NULL,
                 p_request_id,  
                 SYSDATE,
                 fnd_global.user_id,
                 SYSDATE,
                 fnd_global.user_id,
                null,  --to_char(v_last_run_date, 'yyyy-mm-dd')||'T'||to_char(v_last_run_date, 'HH24:MI:SS')||'.000'|| sessiontimezone,   --2013-07-01T00:00:00.000-08:00
                 null,  --p_zuora_invoice_num,
                 null,  --decode(p_request_date_from, NULL,NULL,to_char(to_date(p_request_date_from ,'RRRR/MM/DD HH24:MI:SS'),'yyyy-mm-dd')||'T'||to_char(to_date(p_request_date_from ,'RRRR/MM/DD HH24:MI:SS'), 'HH24:MI:SS')||'.000'|| sessiontimezone),  --p_request_date_from,
                 null  -- decode(p_request_date_from, NULL,NULL,to_char(to_date(p_request_date_to ,'RRRR/MM/DD HH24:MI:SS'),'yyyy-mm-dd')||'T'||to_char(to_date(p_request_date_to ,'RRRR/MM/DD HH24:MI:SS'), 'HH24:MI:SS')||'.000'|| sessiontimezone)  --p_request_date_to
                  );

  
        mo_global.set_policy_context('S', fnd_global.Org_Id);
        -- initialize environment
        fnd_global.apps_initialize(user_id      => fnd_global.User_Id,
                                   resp_id      => fnd_global.Resp_Id,
                                   resp_appl_id => fnd_global.Resp_Appl_Id);
*/
  

 v_request_id := apps.FND_REQUEST.SUBMIT_REQUEST
                       (application => 'QSTAR',
            program => 'QST_ZUORA_FUSION_REQUEST',
            description => 'QSTAR - Zuora Invoice Import Fusion Request',
            start_time => TO_CHAR(SYSDATE, 'DD-MON-YY HH:MI:SS'),
            sub_request => FALSE,
            argument1 => NULL,
            argument2 => NULL,
            argument3 => NULL
            );

     COMMIT;
    
    log('request_id:'||v_request_id);  

    end if;

end loop;


--COMMIT;


<<skip_process>>
null;

   EXCEPTION
          
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Error in insert_request:'||SQLERRM);
   END insert_request;

END QST_ZUORA_REQUEST_PKG;
/