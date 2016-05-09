CREATE OR REPLACE PACKAGE BODY APPS.QST_ZUORA_PAYMENTS_PKG
IS
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
--                       18-NOV-2014        TV Gopal                 Exclude Adjustments with reason code 'Exchange Rate'
--                       11-NOV-2015        TV Gopal                 Fix for partial payments issue. Added procedure update_payments_stg
--                       02-FEB-2016         TV Gopal                 Fix for W payments. Exclude Cybersource Payments created by SCHED_JOBS. 
--                                                                                 Also modified main query to include 'Zuora_Invoice' trx_type
--===============================================================================

   PROCEDURE output (p_msg IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.OUTPUT, p_msg);
--dbms_output.put_line(p_msg);
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, SQLERRM);
       --dbms_output.put_line(SQLERRM);
   END output;


   PROCEDURE LOG (p_msg IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.LOG, p_msg);
     --dbms_output.put_line(p_msg);
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, SQLERRM);
    -- dbms_output.put_line(SQLERRM);
   END LOG;

 PROCEDURE main  ( errbuf            OUT VARCHAR2,
                              retcode           OUT VARCHAR2,
                              p_receipt_number IN VARCHAR2,
                              p_receipt_date_from   IN VARCHAR2,
                              p_receipt_date_to   IN     VARCHAR2
                             )
  IS
   v_last_run_date date;
   v_request_id  number := fnd_global.conc_request_id;
   v_counter number := 0;
   v_inprocess_rec_count  number := 0;
   v_last_request_id number := 0;
   v_status_flag varchar2(1);
   v_error_message varchar2(4000);
   v_delimiter varchar2(1) := ',';
   v_payments_count number := 0;
   v_adjustments_count number := 0;
   c_payment_method_id varchar2(500) := NULL;
   v_db_name varchar2(100) := null;
   
   --v_success BOOLEAN;
   

 
   BEGIN
      LOG ('begin main....  p_receipt_number:'||p_receipt_number);
      
      select name into v_db_name from v$database;
      
      IF v_db_name = 'R12PER' THEN 
          c_payment_method_id := '2c92c0f9392c80790139448f9d73467d';
      ELSIF v_db_name = 'R12UAT' THEN
          c_payment_method_id := '2c92c0f83de30102013defee3b481c89';
      ELSIF v_db_name = 'R12F4B' THEN
          c_payment_method_id := '2c92c0f83de30102013defee3b481c89';
      ELSIF v_db_name = 'R12PRD' THEN
          c_payment_method_id := '2c92a0f939b8f0590139c5a2036e7dd8';
      END IF;          

-- Get last succesful run date and request_id
FOR c_last_run IN (select max(creation_date) run_date,max(request_id) request_id  from qst_zuora_request where status_flag = 'Y') 
loop
   v_last_run_date := c_last_run.run_date;
   v_last_request_id := c_last_run.request_id;
end loop;

LOG('last_run_date:'||to_char(v_last_run_date,'DD-MON-YY hh24:mi:ss')||' request_id:'||v_last_request_id);

   qst_payment_tbl.delete;

   -- Fetch eligible Receipt records
   -- Insert into staging table
   
   SELECT qst_zuora_payments_stg_s.NEXTVAL RECORD_ID,
       'N' STATUS_FLAG,
       NULL ERROR_MESSAGE,
       fnd_global.conc_request_id REQUEST_ID,
       rct.sold_to_customer_id CUST_ACCOUNT_ID,
       hp.party_name CUSTOMER_NAME,
       hca.account_number ACCOUNT_NUMBER,
       CASE WHEN acr.currency_code = rct.invoice_currency_code then ara.amount_applied else round(ara.amount_applied*nvl(acr.exchange_rate,1),2) end  AMOUNT,
       CASE WHEN acr.currency_code = rct.invoice_currency_code then ara.amount_applied else round(ara.amount_applied*nvl(acr.exchange_rate,1),2) end  APPLIED_INV_AMOUNT,
       acr.receipt_date+ 0.1 RECEIPT_DATE,
       rct.trx_number INVOICE_NUMBER,
       acr.receipt_number RECEIPT_NUMBER,
       SYSDATE CREATION_DATE,
       fnd_global.user_id CREATED_BY,
       SYSDATE LAST_UPDATED_DATE,
       fnd_global.user_id LAST_UPDATED_BY,
       'INV'||rct.interface_header_attribute1 Z_INVOICE_NUM,
       c_payment_method_id Z_PAYMENT_METHOD_ID,
     (select max(attribute13) from qst_zuora_invoice qzi where qzi.zuora_invoice_num = 'INV'||rct.interface_header_attribute1) z_account_id,  
     NULL STATUS,
       'Payment' TYPE,
       NULL REFERENCE_ID, 
       acr.cash_receipt_id,
       rct.customer_trx_id, 
       acr.org_id, 
       NULL Z_PAYMENT_NUM,
       NULL attribute1,acr.currency_code attribute2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
  BULK COLLECT INTO qst_payment_tbl
  FROM ar_cash_receipts_all acr,
       ra_customer_trx_all rct,
       ra_cust_trx_types_all rctt,
       AR_RECEIVABLE_APPLICATIONS_all ara,
       ra_batch_sources_all rbs,
       hz_parties hp,
       hz_cust_accounts hca
 WHERE     rbs.batch_source_id = rct.batch_source_id
       AND rbs.name = 'Zuora'
       AND acr.attribute6 IS NULL
       AND acr.cash_receipt_id = ara.cash_receipt_id
       AND ARA.applied_customer_trx_id = rct.customer_trx_id
       AND hp.party_id = hca.party_id
       AND hca.cust_account_id = rct.sold_to_customer_id
       and rctt.cust_trx_type_id = rct.cust_trx_type_id AND rctt.name in ('Invoice','Zuora_Invoice')  and rctt.org_id = rct.org_id  --AND rct.cust_trx_type_id = 1
       AND rct.interface_header_context = 'Zuora'
      -- AND acr.status = 'APP' 
      AND ara.status = 'APP'  and ara.display = 'Y' and ara.amount_applied  != 0 and acr.attribute4 IN ('C','W')
       --AND rct.trx_number = '1000147165'
       AND rct.trx_date > '01-JUN-2014'
       and not exists (select 1 from  apps.fnd_user fu    WHERE fu.user_id = acr.created_by AND fu.user_name = 'SCHED_JOBS')  -- VGOPAL 12/31/2015 fix for excluding Cybersource W payments
       and acr.receipt_number = nvl(p_receipt_number, acr.receipt_number)
       and acr.receipt_date between nvl(p_receipt_date_from,acr.receipt_date-1) and nvl(p_receipt_date_to,acr.receipt_date+1);
 
 v_payments_count := qst_payment_tbl.count;
 log('Payments Count:'||v_payments_count);
   
 IF     qst_payment_tbl.count = 0 THEN
       log('No eligible cash receipts found');
ELSE
   FORALL i in 1..qst_payment_tbl.count
   INSERT INTO qst_zuora_payments_stg values qst_payment_tbl(i);

 END IF;
 
  
 -- Fetch eligible Adjustment records
   -- Insert into staging table
   qst_payment_tbl.delete;
 
 SELECT qst_zuora_payments_stg_s.NEXTVAL RECORD_ID,
       'N' STATUS_FLAG,
       NULL ERROR_MESSAGE,
       fnd_global.conc_request_id REQUEST_ID,
       rac.CUST_ACCOUNT_ID,
       party.party_name CUSTOMER_NAME,
       rac.account_number ACCOUNT_NUMBER,
       ABS(adj.amount) AMOUNT,
       adj.amount APPLIED_INV_AMOUNT,
       adj.apply_date+ 0.1 RECEIPT_DATE,
       ct.trx_number INVOICE_NUMBER,
       adj.adjustment_number adjustment_NUMBER,
       SYSDATE CREATION_DATE,
       fnd_global.user_id CREATED_BY,
       SYSDATE LAST_UPDATED_DATE,
       fnd_global.user_id LAST_UPDATED_BY,
       'INV'||ct.interface_header_attribute1 Z_INVOICE_NUM,
       c_payment_method_id Z_PAYMENT_METHOD_ID,
     (select max(attribute13) from qst_zuora_invoice qzi where qzi.zuora_invoice_num = 'INV'||ct.interface_header_attribute1) z_account_id,  
       NULL STATUS,
       'Adjustment' TYPE,
       NULL REFERENCE_ID,
       adj.adjustment_id,
       ct.customer_trx_id, 
       adj.org_id ,
      NULL Z_PAYMENT_NUM,
        NULL attribute1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
  BULK COLLECT INTO qst_payment_tbl
  FROM AR_RECEIVABLES_TRX_all RT,
          AR_LOOKUPS LK_REASON,
         -- AR_LOOKUPS LK_STATUS,
         -- AR_LOOKUPS LK_TYPE,
          RA_CUSTOMER_TRX_LINES_all CTL_LINENUM,
          RA_CUSTOMER_TRX_all CT,
          RA_CUSTOMER_TRX_all CT_CHARGE,
          RA_CUST_TRX_TYPES_all CTT,
          HZ_CUST_ACCOUNTS RAC,
          HZ_PARTIES PARTY,
          AR_PAYMENT_SCHEDULES_all PS,
          RA_BATCH_SOURCES_all BS,
       --   FND_USER FU1,
     --     FND_USER FU2,
          AR_ADJUSTMENTS_ALL ADJ
    WHERE     ADJ.RECEIVABLES_TRX_ID = RT.RECEIVABLES_TRX_ID
          AND ADJ.ORG_ID = RT.ORG_ID
          AND RT.RECEIVABLES_TRX_ID <> -15
          AND      (ADJ.REASON_CODE = LK_REASON.LOOKUP_CODE(+)
               AND LK_REASON.LOOKUP_TYPE(+) = 'ADJUST_REASON')
         -- AND ADJ.STATUS = LK_STATUS.LOOKUP_CODE
         -- AND LK_STATUS.LOOKUP_TYPE = 'APPROVAL_TYPE'
         -- AND ADJ.TYPE = LK_TYPE.LOOKUP_CODE
         -- AND LK_TYPE.LOOKUP_TYPE = 'ADJUSTMENT_TYPE'
          AND ADJ.CUSTOMER_TRX_LINE_ID = CTL_LINENUM.CUSTOMER_TRX_LINE_ID(+)
          AND ADJ.CUSTOMER_TRX_ID = CT.CUSTOMER_TRX_ID(+)
          AND ADJ.ORG_ID = CT.ORG_ID(+)
          AND ADJ.CHARGEBACK_CUSTOMER_TRX_ID = CT_CHARGE.CUSTOMER_TRX_ID(+)
          AND ADJ.ORG_ID = CT_CHARGE.ORG_ID(+)
          AND CT.CUST_TRX_TYPE_ID = CTT.CUST_TRX_TYPE_ID(+)
          AND CT.ORG_ID = CTT.ORG_ID(+)
          AND PS.CUSTOMER_ID = RAC.CUST_ACCOUNT_ID
          AND RAC.PARTY_ID = PARTY.PARTY_ID
          AND ADJ.PAYMENT_SCHEDULE_ID = PS.PAYMENT_SCHEDULE_ID(+)
          AND ADJ.ORG_ID = PS.ORG_ID(+)
          AND CT.BATCH_SOURCE_ID = BS.BATCH_SOURCE_ID(+)
          AND CT.ORG_ID = BS.ORG_ID(+)
          and bs.name = 'Zuora' and adj.attribute1 IS NULL
       AND ctt.name in ('Invoice','Zuora_Invoice')  and ctt.org_id = ct.org_id   --AND ct.cust_trx_type_id = 1
       AND ct.interface_header_context = 'Zuora'
       --AND rct.trx_number = '1000147165'
       AND ct.trx_date > '01-JUN-2014'
       and adj.adjustment_number = nvl(p_receipt_number, adj.adjustment_number)
       and adj.reason_code != 'EXCHANGE RATE'   -- added by TVGOPAL on  11/18/2014
       and adj.apply_date between nvl(p_receipt_date_from,adj.apply_date-1) and nvl(p_receipt_date_to,adj.apply_date+1);

  v_adjustments_count := qst_payment_tbl.count;
 log('Adjustments Count:'||v_adjustments_count);
  
  IF     qst_payment_tbl.count = 0 THEN
       log('No eligible Adjustments found');
ELSE
   FORALL i in 1..qst_payment_tbl.count
   INSERT INTO qst_zuora_payments_stg values qst_payment_tbl(i);

 END IF;
    
   -- Insert record into polling table 
   
   IF v_adjustments_count + v_payments_count = 0 THEN
       goto skip_process;
   END IF;
   
   INSERT INTO qst_zuora_payments_request (RUN_ID,
                               STATUS_FLAG,
                               ERROR_MESSAGE,
                               REQUEST_ID,
                               CREATION_DATE,
                               CREATED_BY,
                               LAST_UPDATED_DATE,
                               LAST_UPDATED_BY,
                               ATTRIBUTE1,
                               ATTRIBUTE2,
                               Receipt_DATE_FROM,
                               Receipt_DATE_TO,
                               Receipt_number)
     VALUES (qst_zuora_payments_request_s.NEXTVAL,
             'N',
             NULL,
             v_request_id,  
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.user_id,
             v_adjustments_count + v_payments_count,  --'2014-07-01T00:00:00.000-08:00',  -- to_char(v_last_run_date, 'yyyy-mm-dd')||'T'||to_char(v_last_run_date, 'HH24:MI:SS')||'.000'|| sessiontimezone,   --2013-07-01T00:00:00.000-08:00
             null,
             p_receipt_date_from,  
             p_receipt_date_to,
             p_receipt_number  
             );

COMMIT;

   -- Wait for completion of Fusion connector. Update status
LOOP
v_counter := v_counter + 1;

SELECT status_flag, error_message
  INTO v_status_flag, v_error_message
  FROM qst_zuora_payments_request
 WHERE request_id = v_request_id;

LOG('v_status_flag:'||v_status_flag||' v_error_message:'||v_error_message );
exit when (v_status_flag = 'Y' OR v_status_flag = 'E');
DBMS_LOCK.sleep(30);
exit when v_counter = 20;                           -- remove after testing
END loop;


-- Update ar_cash_receipts_all attribute6

-- Update ar_adjustments_all attribute6
  
   -- Write to output file
   qst_payment_tbl.delete;
   SELECT * BULK COLLECT INTO qst_payment_tbl from qst_zuora_payments_stg where request_id = v_request_id;
   
              output( 'RECORD_ID'||v_delimiter||
            'STATUS_FLAG'||v_delimiter||
            'ERROR_MESSAGE'||v_delimiter||
            'REQUEST_ID'||v_delimiter||
            'CUST_ACCOUNT_ID'||v_delimiter||
            'CUSTOMER_NAME'||v_delimiter||
            'ACCOUNT_NUMBER'||v_delimiter||
            'AMOUNT'||v_delimiter||
            'APPLIED_INV_AMOUNT'||v_delimiter||
            'RECEIPT_DATE'||v_delimiter||
            'INVOICE_NUMBER'||v_delimiter||
            'RECEIPT_NUMBER'||v_delimiter||
            'CREATION_DATE'||v_delimiter||
            'CREATED_BY'||v_delimiter||
            'LAST_UPDATED_DATE'||v_delimiter||
            'LAST_UPDATED_BY'||v_delimiter||
            'Z_INVOICE_NUM'||v_delimiter||
            'Z_PAYMENT_METHOD_ID'||v_delimiter||
            'STATUS'||v_delimiter||
            'TYPE'||v_delimiter||
            'REFERENCE_ID'||v_delimiter||
            'ATTRIBUTE1'||v_delimiter||
            'ATTRIBUTE2'||v_delimiter||
            'ATTRIBUTE3'||v_delimiter||
            'ATTRIBUTE4'||v_delimiter||
            'ATTRIBUTE5'||v_delimiter||
            'ATTRIBUTE6'||v_delimiter||
            'ATTRIBUTE7'||v_delimiter||
            'ATTRIBUTE8'||v_delimiter||
            'ATTRIBUTE9'||v_delimiter||
            'ATTRIBUTE10'||v_delimiter||
            'ATTRIBUTE11'||v_delimiter||
            'ATTRIBUTE12'||v_delimiter||
            'ATTRIBUTE13'||v_delimiter||
            'ATTRIBUTE14'||v_delimiter||
            'ATTRIBUTE15'||v_delimiter||
            'ATTRIBUTE16'||v_delimiter||
            'ATTRIBUTE17'||v_delimiter||
            'ATTRIBUTE18'||v_delimiter||
            'ATTRIBUTE19'||v_delimiter||
            'ATTRIBUTE20'||v_delimiter||
            'ATTRIBUTE21'||v_delimiter||
            'ATTRIBUTE22'||v_delimiter||
            'ATTRIBUTE23'||v_delimiter||
            'ATTRIBUTE24'||v_delimiter||
            'ATTRIBUTE25'||v_delimiter||
            'ATTRIBUTE26'||v_delimiter||
            'ATTRIBUTE27'||v_delimiter||
            'ATTRIBUTE28'||v_delimiter||
            'ATTRIBUTE29'||v_delimiter||
            'ATTRIBUTE30');

           FOR i in 1..qst_payment_tbl.COUNT
           LOOP
                 output (qst_payment_tbl(i).RECORD_ID||v_delimiter||
                            qst_payment_tbl(i).STATUS_FLAG||v_delimiter||
                            qst_payment_tbl(i).ERROR_MESSAGE||v_delimiter||
                            qst_payment_tbl(i).REQUEST_ID||v_delimiter||
                            qst_payment_tbl(i).CUST_ACCOUNT_ID||v_delimiter||
                            qst_payment_tbl(i).CUSTOMER_NAME||v_delimiter||
                            qst_payment_tbl(i).ACCOUNT_NUMBER||v_delimiter||
                            qst_payment_tbl(i).AMOUNT||v_delimiter||
                            qst_payment_tbl(i).APPLIED_INV_AMOUNT||v_delimiter||
                            qst_payment_tbl(i).RECEIPT_DATE||v_delimiter||
                            qst_payment_tbl(i).INVOICE_NUMBER||v_delimiter||
                            qst_payment_tbl(i).RECEIPT_NUMBER||v_delimiter||
                            qst_payment_tbl(i).CREATION_DATE||v_delimiter||
                            qst_payment_tbl(i).CREATED_BY||v_delimiter||
                            qst_payment_tbl(i).LAST_UPDATED_DATE||v_delimiter||
                            qst_payment_tbl(i).LAST_UPDATED_BY||v_delimiter||
                            qst_payment_tbl(i).Z_INVOICE_NUM||v_delimiter||
                            qst_payment_tbl(i).Z_PAYMENT_METHOD_ID||v_delimiter||
                            qst_payment_tbl(i).STATUS||v_delimiter||
                            qst_payment_tbl(i).TYPE||v_delimiter||
                            qst_payment_tbl(i).REFERENCE_ID||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE1||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE2||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE3||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE4||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE5||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE6||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE7||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE8||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE9||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE10||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE11||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE12||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE13||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE14||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE15||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE16||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE17||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE18||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE19||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE20||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE21||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE22||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE23||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE24||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE25||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE26||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE27||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE28||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE29||v_delimiter||
                            qst_payment_tbl(i).ATTRIBUTE30);
           END LOOP;

 /*
-- Update AR Cash Receipt record attribute6
   qst_payment_tbl.delete;
   SELECT * BULK COLLECT INTO qst_payment_tbl from qst_zuora_payments_stg where request_id = v_request_id and type = 'Payment' and status_flag = 'Y';
   
   FORALL i in 1..qst_payment_tbl.COUNT
   UPDATE ar_cash_receipts_all set attribute6 = 'Y' WHERE receipt_number = qst_payment_tbl(i).receipt_number and org_id = qst_payment_tbl(i).org_id;
   log('Receipts to be updated:'||qst_payment_tbl.COUNT);
   
-- Update AR Adjustments record attribute1
   qst_payment_tbl.delete;
   SELECT * BULK COLLECT INTO qst_payment_tbl from qst_zuora_payments_stg where request_id = v_request_id and type = 'Adjustment' and status_flag = 'Y';
   
   FORALL i in 1..qst_payment_tbl.COUNT
   UPDATE ar_adjustments_all set attribute1 = 'Y' WHERE adjustment_number = qst_payment_tbl(i).receipt_number and org_id = qst_payment_tbl(i).org_id;
   log('Adjustments to be updated:'||qst_payment_tbl.COUNT);
   */ 
   <<skip_process>>
   NULL;
          
   EXCEPTION
      WHEN OTHERS
      THEN
         log(SQLERRM);
         retcode := '2';
   END main;
   --==================================================================================================
      PROCEDURE update_payment_stg (p_receipt_number IN VARCHAR2,
                              p_receipt_date_from   IN VARCHAR2,
                              p_receipt_date_to   IN     VARCHAR2,
                              p_request_id IN NUMBER
                             ) IS
   v_request_id NUMBER;
   BEGIN
   
   v_request_id := p_request_id;
            
   -- Update AR Cash Receipt record attribute6
   qst_payment_tbl.delete;
   SELECT * BULK COLLECT INTO qst_payment_tbl from qst_zuora_payments_stg where request_id = v_request_id and type = 'Payment' and status_flag = 'Y';
   
   FORALL i in 1..qst_payment_tbl.COUNT
   UPDATE ar_cash_receipts_all set attribute6 = 'Y' WHERE receipt_number = qst_payment_tbl(i).receipt_number and org_id = qst_payment_tbl(i).org_id and attribute4 IN ('C','W');
   log('Receipts to be updated:'||qst_payment_tbl.COUNT);
   
-- Update AR Adjustments record attribute1
   qst_payment_tbl.delete;
   SELECT * BULK COLLECT INTO qst_payment_tbl from qst_zuora_payments_stg where request_id = v_request_id and type = 'Adjustment' and status_flag = 'Y';
   
   FORALL i in 1..qst_payment_tbl.COUNT
   UPDATE ar_adjustments_all set attribute1 = 'Y' WHERE adjustment_number = qst_payment_tbl(i).receipt_number and org_id = qst_payment_tbl(i).org_id;
   log('Adjustments to be updated:'||qst_payment_tbl.COUNT);
                 
   EXCEPTION
      WHEN OTHERS
      THEN
         log('error in update_payment_stg: '||SQLERRM);
   END update_payment_stg;

END QST_ZUORA_PAYMENTS_PKG;
/
