Connect QSTADMIN/&QSTADMIN_pwd@&&instance

DROP TABLE QSTADMIN.QST_ZUORA_INVOICE CASCADE CONSTRAINTS;

CREATE TABLE QSTADMIN.QST_ZUORA_INVOICE
(
  SOURCE_NAME                 VARCHAR2(50 BYTE),
  ORGANIZATION_NAME           VARCHAR2(50 BYTE),
  ORG_ID                      NUMBER,
  ZUORA_SUBSCRIPTION_ID       VARCHAR2(240 BYTE),
  SOLD_TO_ACCT_ID             VARCHAR2(240 BYTE),
  SOLD_TO_CUSTOMER_NAME       VARCHAR2(240 BYTE),
  BILL_TO_CUSTOMER_NAME       VARCHAR2(240 BYTE),
  BILL_TO_ADDR_ID             VARCHAR2(240 BYTE),
  BILL_TO_CONTACT_FIRST_NAME  VARCHAR2(60 BYTE),
  BILL_TO_CONTACT_LAST_NAME   VARCHAR2(60 BYTE),
  BILL_TO_CONTACT_ID          VARCHAR2(15 BYTE),
  SHIP_TO_CUSTOMER_NAME       VARCHAR2(240 BYTE),
  SHIP_TO_ADDR_ID             VARCHAR2(240 BYTE),
  SHIP_TO_CONTACT_FIRST_NAME  VARCHAR2(150 BYTE),
  SHIP_TO_CONTACT_LAST_NAME   VARCHAR2(150 BYTE),
  SHIP_TO_CONTACT_ID          VARCHAR2(50 BYTE),
  CURRENCY_CODE               VARCHAR2(15 BYTE) NOT NULL,
  CONVERSION_RATE             NUMBER,
  CONVERSION_TYPE             VARCHAR2(30 BYTE),
  SALESREP_NAME               VARCHAR2(240 BYTE),
  SALESREP_ID                 NUMBER,
  SALESREP_NUMBER             NUMBER,
  PURCHASE_ORDER              VARCHAR2(150 BYTE),
  TERM_NAME                   VARCHAR2(150 BYTE),
  ZUORA_INVOICE_NUM           VARCHAR2(20 BYTE) NOT NULL,
  INVOICE_DATE                DATE              NOT NULL,
  INVOICE_TYPE                VARCHAR2(30 BYTE),
  LINE_NUMBER                 NUMBER,
  LINE_TYPE                   VARCHAR2(30 BYTE),
  PRODUCT_CODE                VARCHAR2(250 BYTE),
  QUANTITY                    NUMBER,
  UOM_CODE                    VARCHAR2(20 BYTE),
  UNIT_PRICE_AFTER_DISCOUNT   NUMBER,
  INVOICE_LINE_AMT            NUMBER,
  SIEBEL_LINE_TYPE            VARCHAR2(50 BYTE),
  TERM_START_DATE             DATE,
  TERM_END_DATE               DATE,
  TAX_RATE                    NUMBER,
  TAX_AMOUNT                  NUMBER(15,5),
  COMMENTS                    VARCHAR2(240 BYTE),
  CREATION_DATE               DATE,
  CREATED_BY                  NUMBER,
  LAST_UPDATED_DATE           DATE,
  LAST_UPDATED_BY             NUMBER,
  REQUEST_ID                  NUMBER,
  AR_PROCESS_REQUEST_ID       NUMBER,
  ERROR_MESSAGE               VARCHAR2(4000 BYTE),
  STATUS_FLAG                 VARCHAR2(1 BYTE),
  ATTRIBUTE1                  VARCHAR2(240 BYTE),
  ORACLE_INVOICE_NUMBER       NUMBER,
  ZUORA_INVOICE_LINE_ID       VARCHAR2(50 BYTE) NOT NULL,
  UNIT_SELLING_PRICE          NUMBER(15,5),
  RATE_PLAN                   VARCHAR2(240 BYTE),
  SKU_TL                      VARCHAR2(240 BYTE),
  SKU_TS                      VARCHAR2(240 BYTE),
  CHARGE_NAME                 VARCHAR2(240 BYTE),
  CHARGE_TYPE                 VARCHAR2(240 BYTE),
  SKU                         VARCHAR2(240 BYTE),
  DELIVERY_METHOD             VARCHAR2(240 BYTE),
  SALES_COMP_COMMITMENT_AMT   NUMBER,
  --begin columns added for Partner Model
  BILL_TO_ACCT_ID VARCHAR2(240)
  SHIP_TO_ACCT_ID VARCHAR2(240));
  --end columns added for Partner Model
  --begin columns added for Northstar report
  REVENUE_TYPE                VARCHAR2(500),
  SUBSCRIPTION_TYPE           VARCHAR2(500),
  SUBSCRIPTION_NAME           VARCHAR2(500),
  SUBMITTED_DATE              DATE,
  RPC_TCV                     VARCHAR2(500),
  RPC_MRR                     VARCHAR2(500),
  RPC_BILLING_PERIOD          VARCHAR2(500),
  --end columns added for Northstar report
  ATTRIBUTE2                  VARCHAR2(500 BYTE),
  ATTRIBUTE3                  VARCHAR2(500 BYTE),
  ATTRIBUTE4                  VARCHAR2(500 BYTE),
  ATTRIBUTE5                  VARCHAR2(500 BYTE),
  ATTRIBUTE6                  VARCHAR2(500 BYTE),
  ATTRIBUTE7                  VARCHAR2(500 BYTE),
  ATTRIBUTE8                  VARCHAR2(500 BYTE),
  ATTRIBUTE9                  VARCHAR2(500 BYTE),
  ATTRIBUTE10                 VARCHAR2(500 BYTE),
  ATTRIBUTE11                 VARCHAR2(500 BYTE),
  ATTRIBUTE12                 VARCHAR2(500 BYTE),
  ATTRIBUTE13                 VARCHAR2(500 BYTE),
  ATTRIBUTE14                 VARCHAR2(500 BYTE),
  ATTRIBUTE15                 VARCHAR2(500 BYTE),
  ATTRIBUTE16                 VARCHAR2(500 BYTE),
  ATTRIBUTE17                 VARCHAR2(500 BYTE),
  ATTRIBUTE18                 VARCHAR2(500 BYTE),
  ATTRIBUTE19                 VARCHAR2(500 BYTE),
  ATTRIBUTE20                 VARCHAR2(500 BYTE),
  ATTRIBUTEN1                 NUMBER,
  ATTRIBUTEN2                 NUMBER,
  ATTRIBUTEN3                 NUMBER,
  ATTRIBUTEN4                 NUMBER,
  ATTRIBUTEN5                 NUMBER,
  ATTRIBUTEN6                 NUMBER,
  ATTRIBUTEN7                 NUMBER,
  ATTRIBUTEN8                 NUMBER,
  ATTRIBUTEN9                 NUMBER,
  ATTRIBUTEN10                NUMBER,
  ATTRIBUTED1                 DATE,
  ATTRIBUTED2                 DATE,
  ATTRIBUTED3                 DATE,
  ATTRIBUTED4                 DATE,
  ATTRIBUTED5                 DATE,
  ATTRIBUTED6                 DATE,
  ATTRIBUTED7                 DATE,
  ATTRIBUTED8                 DATE,
  ATTRIBUTED9                 DATE,
  ATTRIBUTED10                DATE,
)
TABLESPACE QSTD
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING;



GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON QSTADMIN.QST_ZUORA_INVOICE TO APPS;

Connect apps/&apps_pwd@&&instance

DROP SYNONYM APPS.QST_ZUORA_INVOICE;

CREATE SYNONYM APPS.QST_ZUORA_INVOICE FOR QSTADMIN.QST_ZUORA_INVOICE;
