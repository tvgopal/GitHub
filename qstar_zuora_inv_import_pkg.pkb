CREATE OR REPLACE PACKAGE BODY APPS."QSTAR_ZUORA_INV_IMPORT_PKG" IS 


    PROCEDURE write_output(p_msg IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.OUTPUT, p_msg);
    END write_output;

    PROCEDURE write_log(p_msg IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, p_msg);
    End Write_Log;

Function LAST_DAY_CURRENT_PERIOD (
                P_set_of_books_id IN NUMBER,
                P_DATE IN DATE)
   RETURN DATE
   IS
     x_last_day_current_period date :=NULL;
     x_last_day_next_period date :=NULL;

   BEGIN
    select trunc(end_date)
          into x_last_day_current_period
          from GL_PERIOD_STATUSES
        where application_id=222
       and set_of_books_id=P_set_of_books_id
       and adjustment_period_flag='N'
       and p_date between start_date and end_date
           and rownum=1;

      RETURN (x_last_day_current_period);
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         x_last_day_current_period:=p_date;
         RETURN (x_last_day_current_period);
   END;

Function LAST_DAY_NEXT_PERIOD (
                P_set_of_books_id IN NUMBER,
                P_DATE IN DATE)
   RETURN DATE
   IS
     x_last_day_current_period date :=NULL;
     x_last_day_next_period date :=NULL;

   BEGIN
    select trunc(end_date)
          into x_last_day_current_period
          from GL_PERIOD_STATUSES
        where application_id=222
       and set_of_books_id=P_set_of_books_id
       and adjustment_period_flag='N'
       and p_date between start_date and end_date
           and rownum=1;

    select trunc(end_date)
          into x_last_day_next_period
          from GL_PERIOD_STATUSES
        where application_id=222
       and set_of_books_id=P_set_of_books_id
       and adjustment_period_flag='N'
       and x_last_day_current_period +1 between start_date and end_date
           and rownum=1;

      RETURN (x_last_day_next_period);
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         x_last_day_next_period:=trunc(last_day(add_months(p_date,1)));
         RETURN (x_last_day_next_period);
   END;

    PROCEDURE import (     x_ret_code      OUT   NUMBER
                          ,x_ret_mesg      OUT   VARCHAR2
                     )
    IS

    g_commit_count                NUMBER:= 800;
    g_acct_rule_id                NUMBER;
    g_batchsource_id              NUMBER;
    g_custtrxtype_id              NUMBER;
    g_request_id                  NUMBER  := FND_GLOBAL.CONC_REQUEST_ID;
    g_user_id                     NUMBER  := FND_GLOBAL.USER_ID;
    g_location                    VARCHAR2(400);
    g_Tax_Regime_Code             VARCHAR2(30);
    g_TAX_CODE                    VARCHAR2(50);
    g_Tax_Jurisdiction_Code       VARCHAR2(30);
    G_Tax_Status_Code             VARCHAR2(30);
    g_Tax_Rate_Code               VARCHAR2(30);
    g_tax                         VARCHAR2(30);
    g_org_name                    VARCHAR2(250):= fnd_profile.value('ORG_NAME');
    g_org_id                      number := fnd_profile.value('ORG_ID');
    l_currency_precision number;   --JMA
    l_currency_code       varchar2(10);   --JMA
    l_conc_request_id   fnd_concurrent_requests.request_id%TYPE;
    l_batch_source_name VARCHAR2 (20);
    l_acc_rule_id       NUMBER;
    l_line_inv_rule_id  NUMBER;
    l_batch_source_id   NUMBER;
    l_salesrep_id       NUMBER;
    l_set_of_books_id   NUMBER;
    l_salesrep_tmp_id   NUMBER;
    l_salesrep_type_id  NUMBER;
    l_error_flag        VARCHAR(10);
    l_error_message     VARCHAR2(4000);
    l_ret_code          NUMBER;
    l_ret_mesg          VARCHAR2(4000);
    l_term_id           NUMBER;
    l_cust_trx_type_id  NUMBER;
    l_trx_name          VARCHAR2(30);
    l_reason_code_mean  VARCHAR2(30);
    l_uom_code          VARCHAR2(10);

    l_item_b            VARCHAR2(50);

    l_tax_regime_code             VARCHAR2(30);
    l_tax_code                    VARCHAR2(50);
    l_tax_jurisdiction_code       VARCHAR2(30);
    l_tax_status_code             VARCHAR2(30);
    l_tax_rate_code               VARCHAR2(30);
    l_tax                         VARCHAR2(30);
    l_count_total     NUMBER;
    l_error_count     NUMBER;
    l_proc_count      NUMBER;
    l_temp              VARCHAR2 (10);
    l_boolean boolean;

    l_cust_acc_site_bid  NUMBER;
    l_cust_acc_bid       NUMBER;
    l_cust_acc_site_sid  NUMBER;
    l_cust_acc_sid       NUMBER;
    l_cust_acc_soid      NUMBER;
    l_item_id        NUMBER;
    l_item_sku_id        NUMBER;
    l_item_sku_tl_id        NUMBER;
    l_item_sku_ts_id        NUMBER;
    l_create_rel    VARCHAR2(10);
    l_rel_status    VARCHAR2(10);
    l_bill_to_flag  VARCHAR2(10);
    l_lin_error_mesg  VARCHAR2(10000);
    l_ret_status      VARCHAR2(10);
    l_ret_mess        VARCHAR2(4000);
    l_tax_bundle      VARCHAR2(10);
    data_error EXCEPTION;
    setup_error EXCEPTION;
    fatal_error EXCEPTION;
    l_process varchar2(50);
    l_desc  varchar2(240);
    l_BILL_TO_CONTACT_ID NUMBER;
    l_SHIP_TO_CONTACT_ID NUMBER;
    l_quantity number;
    l_period_status varchar2(1);
    l_gl_date date;
    l_RULE_START_DATE date;
    l_duration number;
    l_ZUORA_INVOICE_NUM varchar2(20);
    l_line_number number;
    x_quota_balance                    number;
    x_error_point                      varchar2(15)  := null;
    x_warning_msg                      varchar2(2000) := null;
    x_employee_name                    varchar2(240) := null;
    x_salesrep_name                    varchar2(240) := null;
    x_salesrep_id                      number        := null;
    x_invalid_data                     varchar2(4000)  := null;
    x_warning_counter                  number        := 0;
    x_error_counter                  number        := 0;
    x_dummy_num  number :=0;
    x_line_status_flag                 varchar2(1)   := null;
    x_status_flag                      varchar2(1)   := null;
    x_header_error_msg                 varchar2(2000) := null;

    CURSOR c_inv_lines
    IS
    SELECT
       decode(round(months_between(trunc(nvl(TERM_END_DATE,sysdate),'MON'),     trunc(nvl(TERM_start_DATE,sysdate),'MON'))),
                            0,1,
                            round(months_between(trunc(nvl(TERM_END_DATE,sysdate),'MON'),     trunc(nvl(TERM_start_DATE,sysdate),'MON')))) duration,
       SOURCE_NAME,
       ORGANIZATION_NAME,
       ORG_ID,
       ZUORA_SUBSCRIPTION_ID ,
       SOLD_TO_ACCT_ID  ,
       SOLD_TO_CUSTOMER_NAME,
       BILL_TO_CUSTOMER_NAME ,
       BILL_TO_ACCT_ID  ,
       BILL_TO_ADDR_ID        ,
       BILL_TO_CONTACT_FIRST_NAME ,
       BILL_TO_CONTACT_LAST_NAME   ,
       BILL_TO_CONTACT_ID          ,
       SHIP_TO_CUSTOMER_NAME       ,
       SHIP_TO_ACCT_ID  ,
       SHIP_TO_ADDR_ID             ,
       SHIP_TO_CONTACT_FIRST_NAME  ,
       SHIP_TO_CONTACT_LAST_NAME   ,
       SHIP_TO_CONTACT_ID          ,
       CURRENCY_CODE               ,
       CONVERSION_RATE            ,
       CONVERSION_TYPE             ,
       SALESREP_NAME               ,
       SALESREP_ID                ,
       SALESREP_NUMBER             ,
       PURCHASE_ORDER              ,
       TERM_NAME                   ,
       ZUORA_INVOICE_NUM           ,
       INVOICE_DATE               ,
       INVOICE_TYPE                ,
       LINE_NUMBER                 ,
       LINE_TYPE                   ,
       PRODUCT_CODE                ,
       QUANTITY                    ,
       UOM_CODE                   ,
       sum(round(nvl(INVOICE_LINE_AMT,0)/nvl(quantity,1),5)) UNIT_SELLING_PRICE,
       --sum(nvl(UNIT_SELLING_PRICE,0)) UNIT_SELLING_PRICE,
       SIEBEL_LINE_TYPE,
       TERM_START_DATE  ,
       TERM_END_DATE     ,
       TAX_RATE           ,
       TAX_AMOUNT          ,
       COMMENTS             ,
       ATTRIBUTE1,
       --ZUORA_INVOICE_LINE_ID       VARCHAR2(50 BYTE) NOT NULL,
       RATE_PLAN,
       SKU_TL    ,
       SKU_TS    ,
       CHARGE_NAME,
       CHARGE_TYPE,
       SKU,DELIVERY_METHOD,
       nvl(SALES_COMP_COMMITMENT_AMT,sum(nvl(INVOICE_LINE_AMT,0))) SALES_COMP_COMMITMENT_AMT
      FROM qst_zuora_invoice qzis
     WHERE org_id      = g_org_id
       AND nvl(STATUS_FLAG,'N') in ('N','E')
       and upper(SOLD_TO_CUSTOMER_NAME) not like '%ZUORA%TEST%'
       and upper(SOLD_TO_CUSTOMER_NAME) not like '%TEST%ZUORA%'
       --and nvl(INVOICE_LINE_AMT ,0)<>0
       and (nvl(INVOICE_LINE_AMT ,0)<>0  
            or           
            (ZUORA_INVOICE_NUM like 'SFDC%' and nvl(SALES_COMP_COMMITMENT_AMT,0)<>0    )  --allow zero amount invoice non-zero sum lump invocie to be interface
           )       
--       and nvl(quantity,0)*nvl(unit_selling_price,0)<>0
       group by
         SOURCE_NAME,
         ORGANIZATION_NAME,
         ORG_ID,
         ZUORA_SUBSCRIPTION_ID ,
         SOLD_TO_ACCT_ID  ,
         SOLD_TO_CUSTOMER_NAME,
         BILL_TO_CUSTOMER_NAME ,
         BILL_TO_ACCT_ID  ,
         BILL_TO_ADDR_ID        ,
         BILL_TO_CONTACT_FIRST_NAME ,
         BILL_TO_CONTACT_LAST_NAME   ,
         BILL_TO_CONTACT_ID          ,
         SHIP_TO_CUSTOMER_NAME       ,
         SHIP_TO_ACCT_ID  ,
         SHIP_TO_ADDR_ID             ,
         SHIP_TO_CONTACT_FIRST_NAME  ,
         SHIP_TO_CONTACT_LAST_NAME   ,
         SHIP_TO_CONTACT_ID          ,
         CURRENCY_CODE               ,
         CONVERSION_RATE            ,
         CONVERSION_TYPE             ,
         SALESREP_NAME               ,
         SALESREP_ID                ,
         SALESREP_NUMBER             ,
         PURCHASE_ORDER              ,
         TERM_NAME                   ,
         ZUORA_INVOICE_NUM           ,
         INVOICE_DATE               ,
         INVOICE_TYPE                ,
         LINE_NUMBER                 ,
         LINE_TYPE                   ,
         PRODUCT_CODE                ,
         QUANTITY                    ,
         UOM_CODE                   ,
         --UNIT_SELLING_PRICE          ,
         SIEBEL_LINE_TYPE,
         TERM_START_DATE  ,
         TERM_END_DATE     ,
         TAX_RATE           ,
         TAX_AMOUNT          ,
         COMMENTS             ,
         ATTRIBUTE1,
         --ZUORA_INVOICE_LINE_ID       VARCHAR2(50 BYTE) NOT NULL,
         RATE_PLAN,
         SKU_TL    ,
         SKU_TS    ,
         CHARGE_NAME,
         CHARGE_TYPE,
         SKU,DELIVERY_METHOD, SALES_COMP_COMMITMENT_AMT
       order by ZUORA_INVOICE_NUM,line_number;
--     for update;

  cursor cur_get_salesreps (cp_org_id number,
                            cp_ZUORA_INVOICE_NUM varchar2,
                            cp_ZUORA_SUBSCRIPTION_ID varchar2
                           ) is
  select t.quota_flag           t_quota_flag,
       t.sales_credit_type_id t_sales_credit_type_id,
       t.enabled_flag         t_enabled_flag,
       round(s.percent,4)     round_percent,
       r.name                 r_name,
       r.salesrep_id          r_salesrep_id,
       r.end_date_active      r_end_date_active,
       r.start_date_active    r_start_date_active,
       s.*,
       s.rowid,
       r.status               r_status
  from jtf_rs_salesreps r,
       oe_sales_credit_types t,
       QST_ZUORA_SALES_CREDITS s
 where s.ZUORA_INVOICE_NUM=cp_ZUORA_INVOICE_NUM
   and s.ZUORA_SUBSCRIPTION_ID=cp_ZUORA_SUBSCRIPTION_ID
   and s.sales_credit_type = t.name(+)
   and to_char(s.salesrep_number) = r.salesrep_number(+)
   and r.org_id(+) = cp_org_id;

    BEGIN

        g_request_id         := FND_GLOBAL.CONC_REQUEST_ID;
        g_user_id            := FND_GLOBAL.USER_ID;
        l_batch_source_name  := NULL;
        l_set_of_books_id    := NULL;
        l_acc_rule_id        := NULL;
        l_line_inv_rule_id   := NULL;
        l_batch_source_id    := NULL;
        l_salesrep_id        := NULL;
        l_salesrep_tmp_id    := NULL;
        l_error_message      := NULL;
        l_error_flag         := NULL;
        l_tax_bundle         := NULL;
        --l_term_id            := NULL;
        l_count_total        := 0;
        l_proc_count         := 0;
        l_error_count        := 0;
        l_ZUORA_INVOICE_NUM :='XX';

        write_log(' Org_id  ' || g_org_id);

       fnd_profile.get('GL_SET_OF_BKS_ID',l_set_of_books_id);
       write_log(' Set of Books  ' || l_set_of_books_id);

      l_process := 'Valiate Zuora Batch source';

        BEGIN

            SELECT rbs.name,rbs.batch_source_id
              INTO l_batch_source_name,l_batch_source_id
              FROM ra_batch_sources_all rbs
             WHERE rbs.NAME              = 'Zuora'
               AND rbs.batch_source_type = 'FOREIGN'
               AND rbs.org_id            = g_org_id; --of the new OU mapping

        EXCEPTION
        WHEN OTHERS THEN
            l_error_message := 'Zuora is not defined as Transaction Source in '||g_org_name;
           write_log(l_error_message);
           raise setup_error;
        END;

      l_process := 'Valiate No Sales Credit';
        BEGIN
            SELECT salesrep_id
              INTO l_salesrep_tmp_id
              FROM ra_salesreps_all
             WHERE name='No Sales Credit'
                and org_id=g_org_id
               AND ROWNUM =1;

        EXCEPTION
        WHEN OTHERS THEN
            l_error_message := 'No Sales Credit is not defined as Salesrep in '||g_org_name;
           write_log(l_error_message);
          raise setup_error;
        END;

      l_process := 'Valiate Rule_id';
        SELECT rule_id
           INTO l_acc_rule_id
          FROM ra_rules
       WHERE  name = 'QUEST VARIABLE SCHEDULE'
           AND status = 'A';

      l_process := 'Valiate next rule ID';
        SELECT rule_id
           INTO l_line_inv_rule_id
          FROM ra_rules
        WHERE name = 'Advance Invoice'-- Need to check the invoicing rule
            AND type = 'I';

        l_count_total :=0;
        l_ZUORA_INVOICE_NUM := 'XXX';

        FOR r_inv_lines IN c_inv_lines
        LOOP

           l_count_total := l_count_total +1 ;
           l_error_message := null;

           --if l_ZUORA_INVOICE_NUM<>substr(r_inv_lines.ZUORA_INVOICE_NUM,4) then
           --   l_ZUORA_INVOICE_NUM := substr(r_inv_lines.ZUORA_INVOICE_NUM,4);
           fnd_file.put_line (fnd_file.LOG,'l_ZUORA_INVOICE_NUM='||l_ZUORA_INVOICE_NUM);
           fnd_file.put_line (fnd_file.LOG,'r_inv_lines.ZUORA_INVOICE_NUM='||r_inv_lines.ZUORA_INVOICE_NUM);
           
           if l_ZUORA_INVOICE_NUM<>r_inv_lines.ZUORA_INVOICE_NUM then
              l_ZUORA_INVOICE_NUM := r_inv_lines.ZUORA_INVOICE_NUM;
              l_line_number :=1;
           else
              l_line_number := l_line_number + 1;
           end if;

           fnd_file.put_line (fnd_file.LOG,'r_inv_lines.ZUORA_INVOICE_NUM='||r_inv_lines.ZUORA_INVOICE_NUM);
           fnd_file.put_line (fnd_file.LOG,'r_inv_lines.line_number='||r_inv_lines.line_number);
           fnd_file.put_line (fnd_file.LOG,'l_line_number='||l_line_number);

            --  write_log('jma40');

           BEGIN

           -- verify salesrep and credit
           -- Reset quota balance at each new order, or order line
             l_error_message        := null;
             x_quota_balance := 100;
             --write_log('jma20');

             BEGIN
             for salesrep_rec in cur_get_salesreps (r_inv_lines.org_id,r_inv_lines.ZUORA_INVOICE_NUM,r_inv_lines.ZUORA_SUBSCRIPTION_ID) loop
               declare -- salesrep loop
                 -- reset local pl/sql block variables at each sales credit line
                 s_salesrep_id number := null;
                 s_salesrep_name varchar2(240) := null;
                 s_salesrep_number number;
                 s_sales_credit_type_id number := null;
                 s_percent number := null;
               begin -- salesrep loop

                 x_error_point := 'ZUORA000';
                 -- Process Invalid Salesreps (not defined or inactive)
                 if (   (salesrep_rec.r_salesrep_id is NULL)
                     or (trunc(nvl(salesrep_rec.r_end_date_active,sysdate)) < trunc(sysdate))
                     or (trunc(nvl(salesrep_rec.r_start_date_active,sysdate)) > trunc(sysdate))
                     or (salesrep_rec.r_status = 'I')) then
                   x_error_point := 'ZUORA6105';

                   if (salesrep_rec.r_salesrep_id is NULL) then -- no salesrep in org (or oracle)
                     x_error_point := 'ZUORA6110'; -- do NOT change, used in Zoom program
                     x_warning_msg := 'Salesrep not in Org';

                     begin -- get employee_name (of inactive salesrep)
                       select substr(full_name,1,30)
                       into   x_employee_name
                       from   per_all_people_f
                       where  employee_number = to_char(salesrep_rec.salesrep_number)
                       and    rownum = 1;  -- regardless of active status
                     exception  -- get employee_name
                       when no_data_found then
                         x_employee_name := null;
                         x_warning_msg := 'Salesrep not in Oracle';
                     end; -- get employee_name

                     x_invalid_data := to_char(salesrep_rec.salesrep_number)||' ('||x_employee_name||' - '||to_char(salesrep_rec.round_percent)||'%'||salesrep_rec.ZUORA_INVOICE_NUM||')'||salesrep_rec.ZUORA_SUBSCRIPTION_ID;
                     x_warning_counter := x_warning_counter + 1;
                     fnd_file.put_line (fnd_file.LOG, 'Error Point: '||x_error_point||' Error Message: '||l_error_message  );
                   else -- salesrep is inactive
                     x_error_point := 'ZUORA6115'; -- do NOT change, used in Zoom program
                     x_warning_msg := 'Salesrep is Inactive';
                     x_invalid_data := to_char(salesrep_rec.salesrep_number)||' ('||salesrep_rec.r_name||' - '||to_char(salesrep_rec.round_percent)||'%'||salesrep_rec.ZUORA_INVOICE_NUM||')'||salesrep_rec.ZUORA_SUBSCRIPTION_ID;
                     x_warning_counter := x_warning_counter + 1;

             fnd_file.put_line (fnd_file.LOG,'Error Point: '||x_error_point||' Warning Message: '||x_warning_msg);
                   end if; -- salesrep_rec.r_salesrep_id is NULL
                 else -- valid salesrep
                   s_salesrep_id := salesrep_rec.r_salesrep_id;
                   s_salesrep_name := salesrep_rec.r_name;
                 end if; -- process invalid salesrep

                 -- Validate Sales Credit Type
                 if (salesrep_rec.t_enabled_flag = 'N') then -- sales credit type disabled
                   x_error_point := 'ZUORA6120';
                   l_error_message := 'Sales Credit Type is Disabled in Oracle';
                   x_invalid_data := salesrep_rec.sales_credit_type;
                   s_sales_credit_type_id := null;
                   x_error_counter := x_error_counter + 1;
                   fnd_file.put_line (fnd_file.LOG,'Error Point: '||x_error_point||' Error Message: '||l_error_message);
                 elsif (salesrep_rec.t_enabled_flag is NULL) then -- sales credit type invalid
                   x_error_point := 'ZUORA6125';
                   l_error_message := 'Invalid Sales Credit Type';
                   x_invalid_data := salesrep_rec.sales_credit_type;
                   x_error_counter := x_error_counter + 1;
                   fnd_file.put_line (fnd_file.LOG,'Error Point: '||x_error_point||' Error Message: '||l_error_message);
                 else -- sales credit type valid
                   s_sales_credit_type_id := salesrep_rec.t_sales_credit_type_id;
                 end if; -- sales credit type checks

                 -- Validate Sales Credit Percentages
                 -- Sales credit percentage must be between 0 and 100 and rounded to 4 digits past the decimal point
                 if (salesrep_rec.percent > 100) then
                   x_error_point := 'ZUORA6130'; -- do NOT change, used in Zoom program
                   x_warning_msg := 'Sales Credit Percent > 100 - Using 100';
                   x_invalid_data := to_char(salesrep_rec.percent)||'% ('||salesrep_rec.ZUORA_INVOICE_NUM||')'||salesrep_rec.ZUORA_SUBSCRIPTION_ID;
                   s_percent := 100; -- override value w/maximum percentage
                   x_warning_counter := x_warning_counter + 1;
                   fnd_file.put_line (fnd_file.LOG,
                               'Error Point: '||x_error_point||' Warning Message: '||x_warning_msg
                              );
                 elsif (salesrep_rec.percent < 0) then
                   x_error_point := 'ZUORA6135'; -- do NOT change, used in Zoom program
                   x_warning_msg := 'Sales Credit Percent < 0 - Using 0';
                   x_invalid_data := to_char(salesrep_rec.percent)||'% ('||s_salesrep_name||salesrep_rec.ZUORA_INVOICE_NUM||')'||salesrep_rec.ZUORA_SUBSCRIPTION_ID;
                   s_percent := 0; -- override value w/minimum percentage
                   x_warning_counter := x_warning_counter + 1;
                   fnd_file.put_line (fnd_file.LOG,'Error Point: '||x_error_point||' Warning Message: '||x_warning_msg);
                 else -- percentage w/in range
                   if (salesrep_rec.percent != salesrep_rec.round_percent) then -- round percent to 4 digits
                     x_error_point := 'ZUORA6140'; -- do NOT change, used in Zoom program
                     x_warning_msg := 'Sales Percent > 4 decimals -  Using '||to_char(salesrep_rec.round_percent);
                     x_invalid_data := to_char(salesrep_rec.percent)||'% ('||s_salesrep_name||salesrep_rec.ZUORA_INVOICE_NUM||')'||salesrep_rec.ZUORA_SUBSCRIPTION_ID;
                     s_percent := salesrep_rec.round_percent; -- override value w/rounded percentage
                     x_warning_counter := x_warning_counter + 1;
                     fnd_file.put_line (fnd_file.LOG, 'Error Point: '||x_error_point||' Warning Message: '||x_warning_msg);
                   else -- percent does not require rounding (to 4 digits)
                     s_percent := salesrep_rec.percent;
                   end if; -- round percent to 4 digits
                 end if; -- salesrep_rec.percent > 100


                 -- Sales credit Quota percentage must be 100% (verify <= 100%)
              --write_log(x_quota_balance);
              --write_log(s_percent);
                 if (salesrep_rec.t_quota_flag = 'Y') then -- valid sales credit type
                   if (s_percent > x_quota_balance) then -- quota > 100%
                     x_error_point := 'ZUORA6150'; -- do NOT change, used in Zoom program
                     x_warning_msg := 'Sales Quota Exceeds 100% - Using '||to_char(x_quota_balance);
                     l_error_message := 'Sales Quota Exceeds 100% - Using '||to_char(x_quota_balance);
                     x_invalid_data := to_char(s_percent)||'% ('||s_salesrep_name||salesrep_rec.ZUORA_INVOICE_NUM||')'||salesrep_rec.ZUORA_SUBSCRIPTION_ID;
                     --s_percent := x_quota_balance; -- override value w/remaining quota
                     x_warning_counter := x_warning_counter + 1;
                     write_log('Error Point: '||x_error_point||' Warning Message: '||x_warning_msg  );
                   end if; -- quota > 100%

                   x_quota_balance := x_quota_balance - s_percent;
                 end if; -- salesrep_rec.t_quota_flag = 'Y'

                 -- We can't have two salesreps with a sales credit type of Financial
                 x_error_point := 'ZUORA6190';

                 begin
                   select count(*)
                   into x_dummy_num
                   from QST_ZUORA_SALES_CREDITS s
                   where sales_credit_type = 'Financial'
                     and s.ZUORA_INVOICE_NUM=salesrep_rec.ZUORA_INVOICE_NUM
                     and s.ZUORA_SUBSCRIPTION_ID=salesrep_rec.ZUORA_SUBSCRIPTION_ID
                     and salesrep_number = s_salesrep_number;

                   if x_dummy_num > 1 then
                     l_error_message := 'Duplicate Salesrep in Financial credit type';
                     x_invalid_data := s_salesrep_name;
                     x_error_counter := x_error_counter + 1;
                     fnd_file.put_line (fnd_file.LOG, 'Error Point: '||x_error_point||' Error Message: '||l_error_message);
                   end if;
                 end;

                 -- Set the Error Status Flag
                 x_error_point := 'ZUORA6200';

                 if (l_error_message is null) then -- salesrep record passed w/no errors
                   x_line_status_flag := 'R'; -- Ready to be Interfaced
                 else -- salesrep record has errors
                   x_line_status_flag := 'E'; -- Error
                   if (nvl(x_status_flag,' ') != 'E') then -- order not marked w/error
                     x_header_error_msg := 'Error in Salesreps';
                   end if; -- order not marked w/error
                 end if; -- salesrep record passed w/no errors

                 -- Update the Salesreps Staging Table
                 x_error_point := 'ZUORA6210';

                 update QST_ZUORA_SALES_CREDITS
                 set    status_flag          = x_line_status_flag,
                        attribute11           = g_request_id,
                        last_updated_date     = SYSDATE,
                        last_updated_by      = FND_GLOBAL.User_Id, -- 1151,
                        salesrep_id          = s_salesrep_id,
                        sales_credit_type_id = s_sales_credit_type_id,
                        percent              = s_percent,
                        error_message        = l_error_message
                 where  rowid = salesrep_rec.rowid;
               end; -- salesrep loop
             end loop; -- salesrep_rec in cur_get_salesreps
             EXCEPTION
                 WHEN OTHERS THEN
                    write_log(x_error_point);
             END;

             if l_error_message is not null then
                write_log(l_error_message);
                 raise data_error;
             end if;
           -- End of verify salesrep and credit

                l_process := 'Valiate zuora_invoice_num';
                l_temp :=NULL;

                if r_inv_lines.ZUORA_INVOICE_NUM like 'INV%' THEN
                   l_ZUORA_INVOICE_NUM := substr(r_inv_lines.ZUORA_INVOICE_NUM,4);  --Truncate first 3 chars INV for Zuora invoice, for SFDC invoice, use the full invoice number
                end if;

                BEGIN
                     SELECT 'Y'
                         INTO l_temp
                        FROM ra_customer_trx_all
                      WHERE trx_number        = l_zuora_invoice_num
                           AND org_id                    = g_org_id
                           AND batch_source_id     = l_batch_source_id;
                EXCEPTION
                      WHEN OTHERS THEN
                             NULL;
                END;

                IF nvl(l_temp,'N')='Y' THEN
                    l_error_message := 'Zuora invoice number '||l_zuora_invoice_num||' alreay exists in Oracle';
                    write_log(l_error_message);
                    raise data_error;
                END IF;

               l_process := 'Valiate invoice type';
                BEGIN
                     SELECT cust_trx_type_id,name
                         INTO   l_cust_trx_type_id,l_trx_name
                        FROM   ra_cust_trx_types_all
                      WHERE  org_id=g_org_id
                           AND nvl(status,'A')='A'
                           AND upper(name)  = upper(r_inv_lines.INVOICE_TYPE)
                           and rownum=1;
                EXCEPTION
                      WHEN OTHERS THEN
                            l_error_message := 'INVOICE_TYPE '||r_inv_lines.INVOICE_TYPE||' is invalid'||' invoice='||l_zuora_invoice_num||' line_num='||r_inv_lines.line_number;
                            write_log(l_error_message);
                            raise data_error;
                END;

              --write_log('jma41');
                l_process := 'Valiate sold acct';
                BEGIN
                    SELECT hs.cust_account_id
                       INTO l_cust_acc_soid
                     FROM hz_cust_site_uses_all hsu,
                               hz_cust_acct_sites_all hs
                                --WHERE hsu.orig_system_reference like r_inv_lines.sold_to_acct_id||'%'        -- '1-4WS9M5$1-4WS9M1$101'
                   WHERE hsu.orig_system_reference like '%'||r_inv_lines.sold_to_acct_id||'%'        --1-61BMK   '1-4WS9M5$1-4WS9M1$101'
                       AND hs. cust_acct_site_id           = hsu. cust_acct_site_id
                       AND hsu.status = 'A'
                       AND hs.status = 'A'
                       AND hsu.org_id             = g_org_id
                       AND rownum = 1;
                EXCEPTION
                      WHEN OTHERS THEN
                            l_error_message := 'sold_to_acct_id '||r_inv_lines.sold_to_acct_id||' has no active customer account'||' invoice='||l_zuora_invoice_num||' line_num='||r_inv_lines.line_number;
                            write_log(l_error_message);
                            raise data_error;
                END;

                l_cust_acc_site_bid :=NULL;
                l_cust_acc_bid :=NULL;

                --write_log('jma1');
                --write_log(r_inv_lines.bill_to_addr_id);
                --write_log(r_inv_lines.sold_to_acct_id);
                --write_log(g_org_id);
                l_process := 'Valiate bill_to';
                BEGIN
                   SELECT hs.cust_acct_site_id,hs.cust_account_id
                      INTO l_cust_acc_site_bid, l_cust_acc_bid
                    FROM hz_cust_site_uses_all hsu,
                         hz_cust_acct_sites_all hs
                  --WHERE hsu.orig_system_reference = r_inv_lines.bill_to_addr_id||'$'||r_inv_lines.sold_to_acct_id||'$'||g_org_id         -- '1-4WS9M5$1-4WS9M1$101'
                  WHERE hsu.orig_system_reference = r_inv_lines.bill_to_addr_id||'$'||r_inv_lines.bill_to_acct_id||'$'||g_org_id         -- '1-4WS9M5$1-4WS9M1$101'
                       AND hs. cust_acct_site_id       = hsu. cust_acct_site_id
                       AND hsu.site_use_code           = 'BILL_TO'
                       AND hsu.status             = 'A'
                       AND hs.status             = 'A'
                       AND hsu.org_id             = g_org_id
                       AND rownum=1;

                EXCEPTION
                      WHEN OTHERS THEN
                            l_error_message := 'bill_to_addr_id '||r_inv_lines.bill_to_addr_id||'$'||r_inv_lines.bill_to_acct_id||'$'||g_org_id||' has no active customer account or site'||' invoice='||l_zuora_invoice_num||' line_num='||r_inv_lines.line_number;
                            write_log(l_error_message);
                            raise data_error;
                END;

                l_cust_acc_site_sid :=NULL;
                l_cust_acc_sid :=NULL;

                l_process := 'Valiate ship_to';
               IF r_inv_lines.ship_to_addr_id is not null THEN
                BEGIN
                   SELECT hs.cust_acct_site_id,hs.cust_account_id
                      INTO l_cust_acc_site_sid, l_cust_acc_sid
                    FROM hz_cust_site_uses_all hsu,
                              hz_cust_acct_sites_all hs
                  WHERE hsu.orig_system_reference = r_inv_lines.ship_to_addr_id||'$'||r_inv_lines.ship_to_acct_id||'$'||g_org_id         -- '1-4WS9M5$1-4WS9M1$101'
                       AND hs. cust_acct_site_id       = hsu. cust_acct_site_id
                       AND hsu.site_use_code           = 'SHIP_TO'
                       AND hsu.status             = 'A'
                       AND hs.status             = 'A'
                       AND hsu.org_id             = g_org_id;

                EXCEPTION
                      WHEN OTHERS THEN
                            l_error_message := 'ship_to_addr_id '||r_inv_lines.ship_to_addr_id||'$'||r_inv_lines.ship_to_acct_id||'$'||g_org_id||' has no active customer account or site'||' invoice='||l_zuora_invoice_num||' line_num='||r_inv_lines.line_number;
                            write_log(l_error_message);
                            raise data_error;
                END;
               END IF;

                l_process := 'Valiate relationship';
              IF l_cust_acc_sid is not null and l_cust_acc_site_sid is not null then
              --verify ship_to to bill_to relationship
               BEGIN
                   SELECT status,  bill_to_flag
                       INTO l_rel_status,  l_bill_to_flag
                      FROM hz_cust_acct_relate_all
                    WHERE org_id  = g_org_id
                        AND cust_account_id         = l_cust_acc_sid
                        AND related_cust_account_id = l_cust_acc_bid
                        AND rownum =1;

               EXCEPTION
                     WHEN no_data_found THEN
                          l_create_rel := 'Y';
                     WHEN OTHERS THEN
                          l_create_rel := 'N';
               END;

               IF l_create_rel = 'Y' AND l_cust_acc_sid is not null and (l_cust_acc_sid <> l_cust_acc_bid ) THEN
                  INSERT INTO hz_cust_acct_relate_all
                                    VALUES
                                      (
                                        l_cust_acc_sid,                  -- Customer ID
                                        l_cust_acc_bid,                  -- Related Customer ID
                                        sysdate,                         -- Last Update Date
                                        FND_GLOBAL.User_Id,              -- Last Updated By
                                        sysdate,                         -- Creation Date
                                        FND_GLOBAL.User_Id,              -- Created By
                                        NULL,                            -- Last Update Login
                                        'ALL',                           -- Relationship Type
                                        NULL,                            -- Comments
                                        NULL,                            -- Attribute Category
                                        NULL,                            -- Attribute1
                                        NULL,                            -- Attribute2
                                        NULL,                            -- Attribute3
                                        NULL,                            -- Attribute4
                                        NULL,                            -- Attribute5
                                        NULL,                            -- Attribute6
                                        NULL,                            -- Attribute7
                                        NULL,                            -- Attribute8
                                        NULL,                            -- Attribute9
                                        NULL,                            -- Attribute10
                                        g_request_id,                    -- Request ID
                                        NULL,                            -- Program Application ID
                                        NULL,                            -- Program ID
                                        NULL,                            -- Program Update Date
                                        'Y',                             -- Customer Reciprocal Flag
                                        'A',                             -- Status
                                        NULL,                            -- Attribute11
                                        NULL,                            -- Attribute12
                                        NULL,                            -- Attribute13
                                        NULL,                            -- Attribute14
                                        NULL,                            -- Attribute15
                                        g_org_id,                        -- org ID
                                        'Y',                             -- Bill To Flag
                                        NULL,                            -- Ship To Flag
                                        NULL,                            -- Object Version Number
                                        NULL,                            -- Created By Module
                                        NULL,                            -- Application ID
                                        HZ_CUST_ACCT_RELATE_S.NEXTVAL
                                      );

               END IF; ---end of ship_to/bill_to

              -- validate Customer Bill_to/Ship to relation
               BEGIN
                   SELECT status,               bill_to_flag
                       INTO l_rel_status,       l_bill_to_flag
                      FROM hz_cust_acct_relate_all
                     WHERE org_id                = g_org_id
                         AND cust_account_id         = l_cust_acc_bid
                         AND related_cust_account_id = l_cust_acc_sid
                         AND rownum =1;

               EXCEPTION
                     WHEN no_data_found THEN
                           l_create_rel := 'Y';
                     WHEN OTHERS THEN
                           l_create_rel := 'N';
               END;

               IF l_create_rel = 'Y' AND l_cust_acc_sid is not null and ( l_cust_acc_sid <> l_cust_acc_bid ) THEN
                    INSERT INTO hz_cust_acct_relate_all
                                    VALUES
                                      (
                                        l_cust_acc_bid,                  -- Customer ID
                                        l_cust_acc_sid,                  -- Related Customer ID
                                        sysdate,                         -- Last Update Date
                                        FND_GLOBAL.User_Id,              -- Last Updated By
                                        sysdate,                         -- Creation Date
                                        FND_GLOBAL.User_Id,              -- Created By
                                        NULL,                            -- Last Update Login
                                        'ALL',                           -- Relationship Type
                                        NULL,                            -- Comments
                                        NULL,                            -- Attribute Category
                                        NULL,                            -- Attribute1
                                        NULL,                            -- Attribute2
                                        NULL,                            -- Attribute3
                                        NULL,                            -- Attribute4
                                        NULL,                            -- Attribute5
                                        NULL,                            -- Attribute6
                                        NULL,                            -- Attribute7
                                        NULL,                            -- Attribute8
                                        NULL,                            -- Attribute9
                                        NULL,                            -- Attribute10
                                        g_request_id,                    -- Request ID
                                        NULL,                            -- Program Application ID
                                        NULL,                            -- Program ID
                                        NULL,                            -- Program Update Date
                                        'Y',                             -- Customer Reciprocal Flag
                                        'A',                             -- Status
                                        NULL,                            -- Attribute11
                                        NULL,                            -- Attribute12
                                        NULL,                            -- Attribute13
                                        NULL,                            -- Attribute14
                                        NULL,                            -- Attribute15
                                        g_org_id,                        -- org ID
                                        'Y',                             -- Bill To Flag
                                        NULL,                            -- Ship To Flag
                                        NULL,                            -- Object Version Number
                                        NULL,                            -- Created By Module
                                        NULL,                            -- Application ID
                                        HZ_CUST_ACCT_RELATE_S.NEXTVAL
                                      );
               END IF;---end of bill_to/ship_to
              END IF;  --end of relation

              --logic to get contact_id
                l_process := 'Valiate bill_to contact';
              l_BILL_TO_CONTACT_ID :=NULL;
              IF r_inv_lines.BILL_TO_CONTACT_ID is not null then
                         write_log('M'||r_inv_lines.BILL_TO_CONTACT_ID||r_inv_lines.bill_to_acct_id||'M');
                         write_log(l_cust_acc_bid);
               BEGIN
                   select cust_account_role_id --contact_id
                     into l_BILL_TO_CONTACT_ID
                    from hz_cust_account_roles  --ra_contacts
                  where orig_system_reference = r_inv_lines.BILL_TO_CONTACT_ID||'$'||r_inv_lines.bill_to_acct_id   --'1-4OCS5D$1-6WZN-492'
                     and cust_account_id = l_cust_acc_bid  --19709  --x_invoice_customer_id
                     and rownum = 1;
               EXCEPTION
                   WHEN OTHERS THEN
                         l_error_message := 'BILL_TO_CONTACT_ID '||r_inv_lines.BILL_TO_CONTACT_ID||'$'||r_inv_lines.bill_to_acct_id||' is invalid'||' invoice='||l_zuora_invoice_num||' line_num='||r_inv_lines.line_number;
                         write_log(l_error_message);
                         raise data_error;
               END;
              END IF;

                l_process := 'Valiate shipto contact';
                  l_SHIP_TO_CONTACT_ID :=NULL;
                  IF r_inv_lines.SHIP_TO_CONTACT_ID is not null then
                  BEGIN
                   select cust_account_role_id --contact_id
                     into l_SHIP_TO_CONTACT_ID
                    from hz_cust_account_roles  --ra_contacts
                  where orig_system_reference = r_inv_lines.SHIP_TO_CONTACT_ID||'$'||r_inv_lines.ship_to_acct_id   --'1-4OCS5D$1-6WZN-492'
                     and cust_account_id = l_cust_acc_sid  --19709  --x_invoice_customer_id
                     and rownum = 1;
                  EXCEPTION
                   WHEN OTHERS THEN
                         l_error_message := 'SHIP_TO_CONTACT_ID '||r_inv_lines.SHIP_TO_CONTACT_ID||'$'||r_inv_lines.ship_to_acct_id||' is invalid'||' invoice='||l_zuora_invoice_num||' line_num='||r_inv_lines.line_number;
                         write_log(l_error_message);
                         raise data_error;
                  END;
                  END IF;

               l_process := 'Valiate term';
               BEGIN
                  SELECT  term_id
                      INTO  l_term_id
                     FROM  ra_terms
                   WHERE  name = decode(r_inv_lines.term_name,'Due Upon Receipt','Credit Card','CreditCard','Credit Card',r_inv_lines.term_name)
                        AND  nvl(start_date_active,sysdate) <= SYSDATE
                        AND  nvl(end_date_active,sysdate)   >= SYSDATE;
               EXCEPTION
                   WHEN OTHERS THEN
                         l_error_message := 'term_name '||r_inv_lines.term_name||' is invalid'||' invoice='||l_zuora_invoice_num||' line_num='||r_inv_lines.line_number;
                         write_log(l_error_message);
                         raise data_error;
               END;

                l_process := 'Valiate salesrep';
               BEGIN
                    SELECT  salesrep_id
                       INTO  l_salesrep_id
                      FROM  ra_salesreps_all
                    WHERE  salesrep_number = r_inv_lines.salesrep_number
                        AND  org_id          = g_org_id
                        AND  status          = 'A';
               EXCEPTION
                   WHEN OTHERS THEN
                         l_error_message := 'salesrep_number '||r_inv_lines.salesrep_number ||' is invalid'||' invoice='||l_zuora_invoice_num||' line_num='||r_inv_lines.line_number;
                         write_log(l_error_message);
                         raise data_error;
               END;

               l_process := 'Valiate item';
/*
               l_item_sku_tl_id :=NULL;
               BEGIN
                   SELECT inventory_item_id,description
                       INTO l_item_sku_tl_id,l_desc
                      FROM mtl_system_items_b  MSI
                   WHERE  msi.segment1                 = nvl(r_inv_lines.sku_tl,'XX')
                        AND  msi.organization_id =(select organization_id  from mtl_parameters where organization_code='MST');
               EXCEPTION
                   WHEN OTHERS THEN
                         l_error_message := 'product_code '||r_inv_lines.sku_tl ||' is invalid'||' invoice='||l_zuora_invoice_num||' line_num='||r_inv_lines.line_number;
                         write_log(l_error_message);
                         raise data_error;
               END;

               l_item_sku_ts_id :=NULL;
               BEGIN
                   SELECT inventory_item_id,description
                       INTO l_item_sku_ts_id,l_desc
                      FROM mtl_system_items_b  MSI
                   WHERE  msi.segment1                 = nvl(r_inv_lines.sku_ts,'XX')
                        AND  msi.organization_id =(select organization_id  from mtl_parameters where organization_code='MST');
               EXCEPTION
                   WHEN OTHERS THEN
                         l_error_message := 'product_code '||r_inv_lines.sku_ts ||' is invalid'||' invoice='||l_zuora_invoice_num||' line_num='||r_inv_lines.line_number;
                         write_log(l_error_message);
                         raise data_error;
               END;
*/

               l_item_sku_id :=NULL;
               BEGIN
                   SELECT inventory_item_id,description
                       INTO l_item_sku_id,l_desc
                      FROM mtl_system_items_b  MSI
                   WHERE  msi.segment1                 = nvl(r_inv_lines.sku,'XX')
                        AND  msi.organization_id =(select organization_id  from mtl_parameters where organization_code='MST');
               EXCEPTION
                   WHEN OTHERS THEN
                         l_error_message := 'product_code '||r_inv_lines.sku ||' is invalid'||' invoice='||l_zuora_invoice_num||' line_num='||r_inv_lines.line_number;
                         write_log(l_error_message);
                         raise data_error;
               END;

               l_currency_precision :=2;

              BEGIN
                  select precision
                     into l_currency_precision
                   from FND_CURRENCIES_VL
                where  enabled_flag='Y'
                    and currency_flag='Y'
                    and currency_code=r_inv_lines.currency_code;
              exception
                 when others then
                     l_currency_precision :=2;
              end;

                l_process := 'Insert';

                l_quantity :=1;
                select  decode(nvl(r_inv_lines.quantity,0),0,1,r_inv_lines.quantity)
                   into   l_quantity
                   from dual ;

               l_gl_date :=nvl(r_inv_lines.invoice_date,sysdate);
               begin
                   select closing_status
                      into l_period_status
                    from gl_period_statuses
                  where application_id = 222  --Receivables
                      and set_of_books_id = l_set_of_books_id
                      and adjustment_period_flag='N'
                      and r_inv_lines.invoice_date between start_date and end_date
                      and nvl(closing_status,'O') <>'C'
                      and rownum=1;

               exception when no_data_found then
                     l_gl_date :=sysdate;
               end;

               l_duration :=  r_inv_lines.duration;

              --one-time charges/Recurring charges are always ADVANCE.
              --Usage based charges are always ARREARS.
              --Usage or Recurring or OneTime
              /*
              l_RULE_START_DATE := r_inv_lines.invoice_date;
              if r_inv_lines.CHARGE_TYPE ='Usage' then   --Usage based charges are always ARREARS.
                 l_RULE_START_DATE :=LAST_DAY_CURRENT_PERIOD(l_set_of_books_id,r_inv_lines.invoice_date);
                 l_duration :=1;   ---set duration to be 1
              else   --ADVANCE for one-time charges/Recurring charges
                 l_RULE_START_DATE :=LAST_DAY_NEXT_PERIOD(l_set_of_books_id,r_inv_lines.invoice_date);
              end if;
              */

              IF nvl(r_inv_lines.line_type,'XX')='LINE' THEN
                  INSERT INTO ra_interface_lines_all
                                                (
                                                trx_number,
                                                amount,
                                                batch_source_name,
                                                --conversion_rate,
                                                conversion_type,
                                                created_by,
                                                creation_date,
                                                currency_code,
                                                cust_trx_type_id,
                                                description,
                                                gl_date,
                                                interface_line_attribute1,
                                                interface_line_attribute2,
                                                interface_line_attribute3,
                                                interface_line_attribute4,
                                                interface_line_attribute5,
                                                interface_line_attribute6,
                                                interface_line_attribute7,
                                                interface_line_context,
                                                last_update_date,
                                                last_updated_by,
                                                line_type,
                                                org_id,
                                                orig_system_bill_customer_id,
                                                orig_system_bill_address_id,
                                                orig_system_ship_customer_id,
                                                orig_system_ship_address_id,
                                                orig_system_sold_customer_id,
                                                primary_salesrep_id,
                                                set_of_books_id,
                                                term_id,
                                                accounting_rule_id,
                                                --accounting_rule_duration,
                                                --rule_start_date,
                                                inventory_item_id,
                                                uom_code,
                                                invoicing_rule_id,
                                                unit_selling_price,
                                                quantity,
                                                --line_number,
                                                trx_date,
                                                purchase_order,
                                                comments,
                                                reason_code,
                                                attribute1,
                                                attribute2,
                                                attribute3,
                                                attribute4,
                                                attribute7,
                                                attribute8,
                                                attribute10,
                                                attribute6,
                                                attribute15,
                                                taxable_flag,
                                                amount_includes_tax_flag,
                                                TAX_CODE,
                                                TAX_EXEMPT_FLAG,
                                                tax_rate,
                                                taxable_amount,   --JMA TAX
                                                header_attribute2,
                                                header_attribute6, -- G,
                                                quantity_ordered,
                                                ORIG_SYSTEM_BILL_CONTACT_ID,
                                                ORIG_SYSTEM_SHIP_CONTACT_ID,
                                                ACCOUNTING_RULE_DURATION,
                                                RULE_START_DATE
                                                ,sales_order_line
                                                ,interface_line_attribute14
                                                )
                                                VALUES
                                                (
                                                NULL,  ---r_inv_lines.zuora_invoice_num,
                                                round(l_quantity*r_inv_lines.UNIT_SELLING_PRICE,l_currency_precision),         -- amount
                                                r_inv_lines.SOURCE_NAME, -- batch_source_name
                                                --0.89,         -- conversion_rate
                                                'Corporate',        -- conversion_type
                                                g_user_id,         -- created_by
                                                SYSDATE,      -- creation_date
                                                r_inv_lines.currency_code,         -- currency_code
                                                l_cust_trx_type_id,            -- cust_trx_type_id
                                                l_desc, --'APPLICATIONS - PROFESSIONAL SERVICES PREPAID DAILY RATE',
                                                l_gl_date, -- gl_date
                                                l_zuora_invoice_num,       -- interface_line_attribute1
                                                r_inv_lines.invoice_date,   -- interface_line_attribute2
                                                r_inv_lines.CHARGE_type,         -- interface_line_attribute3
                                                r_inv_lines.invoice_type,       -- interface_line_attribute4
                                                r_inv_lines.ZUORA_Subscription_ID,--round(r_inv_lines.quantity*r_inv_lines.UNIT_SELLING_PRICE,l_currency_precision),       -- interface_line_attribute5
                                                l_line_number,      -- interface_line_attribute6
                                                nvl(r_inv_lines.SALES_COMP_COMMITMENT_AMT,'0.0') ,    --attribute12
                                                r_inv_lines.SOURCE_NAME, -- interface_line_context
                                                SYSDATE,      -- last_update_date
                                                g_user_id,         -- last_updated_by
                                                'LINE',       -- line_type
                                                g_org_id,     -- org_id
                                                l_cust_acc_bid,        -- orig_system_bill_customer_id
                                                l_cust_acc_site_bid,        -- orig_system_bill_address_id
                                                l_cust_acc_sid,        -- orig_system_ship_customer_id
                                                l_cust_acc_site_sid,        -- orig_system_ship_address_id
                                                l_cust_acc_soid,
                                                l_salesrep_id,               --100001578,    -- primary_salesrep_id
                                                l_set_of_books_id,                                              -- set_of_books_id
                                                l_term_id,                                                      -- term_id                                accounting_rule_id,
                                                l_acc_rule_id,                                                  -- accouting rule id                      accounting_rule_duration,
                                                l_item_sku_id,                                                     --inventory_item_id,
                                                'Ea',   ----r_inv_lines.uom_code,                                                     --   uom_name,                                                 invoicing_rule_id,
                                                l_line_inv_rule_id,                                             --   invoicing_rule_id,                                 round(round(unit_selling_price,3),2),
                                                r_inv_lines.unit_selling_price,           --   unit_selling_price,                                 quantity_ordered
                                                l_quantity,                                                --   quantity_ordered
                                                --r_inv_lines.line_number,
                                                r_inv_lines.invoice_date,  --trx_date
                                                r_inv_lines.purchase_order,
                                                r_inv_lines.comments,
                                                NULL,
                                                NVL(r_inv_lines.attribute1,'Y'),   --attribute1
                                                NULL,  --r_inv_lines.pack_parent_line_number,  --attribute2
                                                to_char(r_inv_lines.term_start_date,'RRRR/MM/DD'),  --attribute3
                                                to_char(r_inv_lines.term_end_date,'RRRR/MM/DD'),   --attribute4
                                                to_char(r_inv_lines.term_start_date,'RRRR/MM/DD'),  --attribute7
                                                to_char(r_inv_lines.term_end_date,'RRRR/MM/DD'),   --attribute8
                                                r_inv_lines.DELIVERY_METHOD ,    --attribute10 delivery_method
                                                r_inv_lines.siebel_line_type,  --attribute6
                                                NULL, --attribute15 amount for PB before unbundle
                                                'Y',
                                                'N',
                                                'LOCRATECODE',--TAX_CODE
                                                'S',  --TAX_EXEMPT_FLAG
                                                NULL,  --r_inv_lines.tax_rate,
                                                NULL,---r_inv_lines.tax_amount,   --JMA TAX
                                                NULL,--r_inv_lines.siebel_quote_number,
                                                NULL,--r_inv_lines.govt_invoice_num,
                                                l_quantity,
                                                l_BILL_TO_CONTACT_ID,
                                                l_SHIP_TO_CONTACT_ID,
                                                l_duration,
                                                l_RULE_START_DATE
                                                ,l_line_number
                                                ,'0'
                                                );

              BEGIN
                  INSERT INTO ra_interface_salescredits_all
                                                              (
                                                                created_by,
                                                                creation_date,
                                                                interface_line_attribute1,
                                                                interface_line_attribute2,
                                                                interface_line_attribute3,
                                                                interface_line_attribute4,
                                                                interface_line_attribute5,
                                                                interface_line_attribute6,
                                                                INTERFACE_LINE_ATTRIBUTE7,
                                                                interface_line_context,
                                                                last_updated_by,
                                                                last_update_date,
                                                                sales_credit_percent_split,
                                                                sales_credit_type_id,
                                                                salesrep_id,
                                                                org_id
                                                                ,interface_line_attribute14
                                                              )
                                                              select
                                                                g_user_id,        -- created_by
                                                                SYSDATE,     -- creation_date
                                                                l_zuora_invoice_num,       -- interface_line_attribute1
                                                                r_inv_lines.invoice_date,   -- interface_line_attribute2
                                                                r_inv_lines.CHARGE_type,         -- interface_line_attribute3
                                                                r_inv_lines.invoice_type,       -- interface_line_attribute4
                                                                r_inv_lines.ZUORA_Subscription_ID,--round(r_inv_lines.quantity*r_inv_lines.UNIT_SELLING_PRICE,l_currency_precision),       -- interface_line_attribute5
                                                                l_line_number,      -- interface_line_attribute6
                                                                nvl(r_inv_lines.SALES_COMP_COMMITMENT_AMT,'0.0') ,    --attribute12
                                                                r_inv_lines.source_name, -- interface_line_context
                                                                g_user_id,         -- last_updated_by
                                                                sysdate,      -- last_update_date
                                                                s.PERCENT,           -- sales_credit_percent_split
                                                                s.SALES_CREDIT_TYPE_ID,         -- sales_credit_type_id
                                                                s.SALESREP_ID,    -- salesrep_id 100001284
                                                                g_org_id           -- org_id
                                                                ,'0'
                                                               from QST_ZUORA_SALES_CREDITS s
                                                              where 1=1
                                                                and s.ZUORA_INVOICE_NUM=r_inv_lines.ZUORA_INVOICE_NUM
                                                                and s.ZUORA_SUBSCRIPTION_ID=r_inv_lines.ZUORA_SUBSCRIPTION_ID;
              EXCEPTION
                  WHEN OTHERS THEN
                       l_error_message := 'Unable to Insert Sales Credit for SKU in '||g_org_name||' invoice='||l_zuora_invoice_num||' line_num='||r_inv_lines.line_number;
                       write_log(l_error_message);
                       raise setup_error;
              END;


              END IF;

             l_process := 'Update record statues_flag';
              update qst_zuora_invoice
                   set status_flag='P',
                        ERROR_MESSAGE=NULL,
                        LAST_UPDATED_DATE  =sysdate,
                        LAST_UPDATED_BY       =g_user_id,
                        AR_PROCESS_REQUEST_ID                =g_request_id
                   where ZUORA_INVOICE_NUM=r_inv_lines.ZUORA_INVOICE_NUM
                     and nvl(LINE_NUMBER,1)=nvl(r_inv_lines.LINE_NUMBER,1);
              l_proc_count := l_proc_count+1;

           EXCEPTION
               when data_error then
                   update qst_zuora_invoice
                        set status_flag='E',
                             ERROR_MESSAGE=l_error_message,
                             LAST_UPDATED_DATE     =sysdate,
                             LAST_UPDATED_BY       =g_user_id,
                             AR_PROCESS_REQUEST_ID =g_request_id
                   where ZUORA_INVOICE_NUM=r_inv_lines.ZUORA_INVOICE_NUM
                     and nvl(LINE_NUMBER,1)=nvl(r_inv_lines.LINE_NUMBER,1);
                   l_error_count := l_error_count+1;
               when setup_error then
                    raise fatal_error;
               when OTHERS then
                    fnd_file.put_line (fnd_file.OUTPUT,'SQLERRM : '||sqlerrm);
           END;

           l_ZUORA_INVOICE_NUM := r_inv_lines.ZUORA_INVOICE_NUM;
        
        END LOOP; -- r_inv_lines

commit;

        write_output('+-----------------------------------------------------------------------------------------+');
        write_output('  QSTAR Zuora Invoice Import '||g_org_name);
        write_output('+-----------------------------------------------------------------------------------------+');
        write_output('        Processing Request ID                              :'||g_request_id);
        write_output('        Total No of Invoice lines                           :'||l_count_total);
        write_output('        Total No of Invoice lines Processed            :'||l_proc_count);
        write_output('        Total No of Invoice lines Not processed      :'||l_error_count);
        write_output('+-----------------------------------------------------------------------------------------+');

    EXCEPTION
        when fatal_error then
        rollback;
        fnd_file.put_line (fnd_file.OUTPUT,'Program Error - Contact the MIS Helpdesk');
        fnd_file.put_line (fnd_file.OUTPUT,'SQLERRM : '||sqlerrm);
        fnd_file.put_line (fnd_file.OUTPUT,'l_process= '||l_process);
        l_boolean := FND_CONCURRENT.Set_Completion_Status('ERROR','Program Error - Contact the MIS Helpdesk');
        WHEN OTHERS THEN
            write_log('OTHERS EXCEPTION in PROCEDURE import @'||l_process);
            write_log('SQLERRM: '||substr(SQLERRM,1,255));
    END import;


END qstar_zuora_inv_import_pkg;
/
