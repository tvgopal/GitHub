DROP VIEW APPS.QST_ZUORA_INVOICE_V;

/* Formatted on 12/18/2015 12:10:13 PM (QP5 v5.149.1003.31008) */
CREATE OR REPLACE FORCE VIEW APPS.QST_ZUORA_INVOICE_V
(
   SOURCE_NAME,
   ORGANIZATION_NAME,
   ORG_ID,
   ZUORA_SUBSCRIPTION_ID,
   SOLD_TO_ACCT_ID,
   SOLD_TO_CUSTOMER_NAME,
   BILL_TO_CUSTOMER_NAME,
   BILL_TO_ADDR_ID,
   BILL_TO_CONTACT_FIRST_NAME,
   BILL_TO_CONTACT_LAST_NAME,
   BILL_TO_CONTACT_ID,
   SHIP_TO_CUSTOMER_NAME,
   SHIP_TO_ADDR_ID,
   SHIP_TO_CONTACT_FIRST_NAME,
   SHIP_TO_CONTACT_LAST_NAME,
   SHIP_TO_CONTACT_ID,
   CURRENCY_CODE,
   CONVERSION_RATE,
   CONVERSION_TYPE,
   SALESREP_NAME,
   SALESREP_ID,
   SALESREP_NUMBER,
   PURCHASE_ORDER,
   TERM_NAME,
   ZUORA_INVOICE_NUM,
   INVOICE_DATE,
   INVOICE_TYPE,
   LINE_NUMBER,
   LINE_TYPE,
   PRODUCT_CODE,
   QUANTITY,
   UOM_CODE,
   UNIT_PRICE_AFTER_DISCOUNT,
   INVOICE_LINE_AMT,
   SIEBEL_LINE_TYPE,
   TERM_START_DATE,
   TERM_END_DATE,
   TAX_RATE,
   TAX_AMOUNT,
   COMMENTS,
   CREATION_DATE,
   CREATED_BY,
   LAST_UPDATED_DATE,
   LAST_UPDATED_BY,
   REQUEST_ID,
   AR_PROCESS_REQUEST_ID,
   ERROR_MESSAGE,
   STATUS_FLAG,
   ATTRIBUTE1,
   ORACLE_INVOICE_NUMBER,
   ZUORA_INVOICE_LINE_ID,
   UNIT_SELLING_PRICE,
   RATE_PLAN,
   SKU_TL,
   SKU_TS,
   CHARGE_NAME,
   CHARGE_TYPE,
   SKU,
   DELIVERY_METHOD,
   SALES_COMP_COMMITMENT_AMT,
   ATTRIBUTE2,
   ATTRIBUTE3,
   ATTRIBUTE4,
   ATTRIBUTE5,
   ATTRIBUTE6,
   ATTRIBUTE7,
   ATTRIBUTE8,
   ATTRIBUTE9,
   ATTRIBUTE10,
   ATTRIBUTE11,
   ATTRIBUTE12,
   ATTRIBUTE13,
   ATTRIBUTE14,
   ATTRIBUTE15,
   ATTRIBUTE16,
   ATTRIBUTE17,
   ATTRIBUTE18,
   ATTRIBUTE19,
   ATTRIBUTE20,
   ATTRIBUTEN1,
   ATTRIBUTEN2,
   ATTRIBUTEN3,
   ATTRIBUTEN4,
   ATTRIBUTEN5,
   ATTRIBUTEN6,
   ATTRIBUTEN7,
   ATTRIBUTEN8,
   ATTRIBUTEN9,
   ATTRIBUTEN10,
   ATTRIBUTED1,
   ATTRIBUTED2,
   ATTRIBUTED3,
   ATTRIBUTED4,
   ATTRIBUTED5,
   ATTRIBUTED6,
   ATTRIBUTED7,
   ATTRIBUTED8,
   ATTRIBUTED9,
   ATTRIBUTED10,
   BILL_TO_ACCT_ID,
   SHIP_TO_ACCT_ID,
   REVENUE_TYPE,
   SUBSCRIPTION_TYPE,
   BASE_SUBSCRIPTION_NAME,
   SUBMITTED_DATE,
   RPC_TCV,
   RPC_MRR,
   RPC_BILLING_PERIOD,
   ACTUAL_START_DATE,
   SOURCE,
   INITIAL_TERM,
   RENEWAL_TERM,
   AUTO_RENEW,
   ORDER_ORIGINATION,
   CHARGE_DESCRIPTION
)
AS
   SELECT "SOURCE_NAME",
          "ORGANIZATION_NAME",
          "ORG_ID",
          "ZUORA_SUBSCRIPTION_ID",
          "SOLD_TO_ACCT_ID",
          "SOLD_TO_CUSTOMER_NAME",
          "BILL_TO_CUSTOMER_NAME",
          "BILL_TO_ADDR_ID",
          "BILL_TO_CONTACT_FIRST_NAME",
          "BILL_TO_CONTACT_LAST_NAME",
          "BILL_TO_CONTACT_ID",
          "SHIP_TO_CUSTOMER_NAME",
          "SHIP_TO_ADDR_ID",
          "SHIP_TO_CONTACT_FIRST_NAME",
          "SHIP_TO_CONTACT_LAST_NAME",
          "SHIP_TO_CONTACT_ID",
          "CURRENCY_CODE",
          "CONVERSION_RATE",
          "CONVERSION_TYPE",
          "SALESREP_NAME",
          "SALESREP_ID",
          "SALESREP_NUMBER",
          "PURCHASE_ORDER",
          "TERM_NAME",
          "ZUORA_INVOICE_NUM",
          "INVOICE_DATE",
          "INVOICE_TYPE",
          "LINE_NUMBER",
          "LINE_TYPE",
          "PRODUCT_CODE",
          "QUANTITY",
          "UOM_CODE",
          "UNIT_PRICE_AFTER_DISCOUNT",
          "INVOICE_LINE_AMT",
          "SIEBEL_LINE_TYPE",
          "TERM_START_DATE",
          "TERM_END_DATE",
          "TAX_RATE",
          "TAX_AMOUNT",
          "COMMENTS",
          "CREATION_DATE",
          "CREATED_BY",
          "LAST_UPDATED_DATE",
          "LAST_UPDATED_BY",
          "REQUEST_ID",
          "AR_PROCESS_REQUEST_ID",
          "ERROR_MESSAGE",
          "STATUS_FLAG",
          "ATTRIBUTE1",
          "ORACLE_INVOICE_NUMBER",
          "ZUORA_INVOICE_LINE_ID",
          "UNIT_SELLING_PRICE",
          "RATE_PLAN",
          "SKU_TL",
          "SKU_TS",
          "CHARGE_NAME",
          "CHARGE_TYPE",
          "SKU",
          "DELIVERY_METHOD",
          "SALES_COMP_COMMITMENT_AMT",
          "ATTRIBUTE2",
          "ATTRIBUTE3",
          "ATTRIBUTE4",
          "ATTRIBUTE5",
          "ATTRIBUTE6",
          "ATTRIBUTE7",
          "ATTRIBUTE8",
          "ATTRIBUTE9",
          "ATTRIBUTE10",
          "ATTRIBUTE11",
          "ATTRIBUTE12",
          "ATTRIBUTE13",
          "ATTRIBUTE14",
          "ATTRIBUTE15",
          "ATTRIBUTE16",
          "ATTRIBUTE17",
          "ATTRIBUTE18",
          "ATTRIBUTE19",
          "ATTRIBUTE20",
          "ATTRIBUTEN1",
          "ATTRIBUTEN2",
          "ATTRIBUTEN3",
          "ATTRIBUTEN4",
          "ATTRIBUTEN5",
          "ATTRIBUTEN6",
          "ATTRIBUTEN7",
          "ATTRIBUTEN8",
          "ATTRIBUTEN9",
          "ATTRIBUTEN10",
          "ATTRIBUTED1",
          "ATTRIBUTED2",
          "ATTRIBUTED3",
          "ATTRIBUTED4",
          "ATTRIBUTED5",
          "ATTRIBUTED6",
          "ATTRIBUTED7",
          "ATTRIBUTED8",
          "ATTRIBUTED9",
          "ATTRIBUTED10",
          "BILL_TO_ACCT_ID",
          "SHIP_TO_ACCT_ID",
          "REVENUE_TYPE",
          "SUBSCRIPTION_TYPE",
          "BASE_SUBSCRIPTION_NAME",
          "SUBMITTED_DATE",
          "RPC_TCV",
          "RPC_MRR",
          "RPC_BILLING_PERIOD",
          "ACTUAL_START_DATE",
          "SOURCE",
          "INITIAL_TERM",
          "RENEWAL_TERM",
          "AUTO_RENEW",
          "ORDER_ORIGINATION",
          "CHARGE_DESCRIPTION"
     FROM qst_zuora_invoice where status_flag = 'P';
