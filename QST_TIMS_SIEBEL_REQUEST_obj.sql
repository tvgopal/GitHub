Connect QSTADMIN/&&QSTADMIN_pwd@&&instance

DROP TABLE QSTADMIN.QST_TIMS_SIEBEL_REQUEST CASCADE CONSTRAINTS;

CREATE TABLE QSTADMIN.QST_TIMS_SIEBEL_REQUEST
(
  RUN_ID             NUMBER,
  STATUS_FLAG        VARCHAR2(1 BYTE),
  ERROR_MESSAGE      VARCHAR2(4000 BYTE),
  REQUEST_ID         NUMBER,
  QUOTE_DATE_FROM    VARCHAR2(500 BYTE),
  QUOTE_DATE_TO      VARCHAR2(500 BYTE),
  QUOTE_NUMBER       VARCHAR2(500 BYTE),
  SFDC_ACCOUNT       VARCHAR2(500 BYTE),
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATED_DATE  DATE,
  LAST_UPDATED_BY    NUMBER,
  INSTANCE_ID        NUMBER,
  QUOTE_COUNT        NUMBER,
  SFDC_FLAG          VARCHAR2(1 BYTE),
  SFDC_MESSAGE       VARCHAR2(4000 BYTE),
  SIEBEL_FLAG        VARCHAR2(1 BYTE),
  SIEBEL_MESSAGE     VARCHAR2(4000 BYTE),
  TIMS_FLAG          VARCHAR2(1 BYTE),
  TIMS_MESSAGE       VARCHAR2(4000 BYTE),
  ZUORA_FLAG         VARCHAR2(1 BYTE),
  ZUORA_MESSAGE      VARCHAR2(4000 BYTE),
  ATTRIBUTE1         VARCHAR2(500 BYTE),
  ATTRIBUTE2         VARCHAR2(500 BYTE),
  ATTRIBUTE3         VARCHAR2(500 BYTE),
  ATTRIBUTE4         VARCHAR2(500 BYTE),
  ATTRIBUTE5         VARCHAR2(500 BYTE),
  ATTRIBUTE6         VARCHAR2(500 BYTE),
  ATTRIBUTE7         VARCHAR2(500 BYTE),
  ATTRIBUTE8         VARCHAR2(500 BYTE),
  ATTRIBUTE9         VARCHAR2(500 BYTE),
  ATTRIBUTE10        VARCHAR2(500 BYTE),
  ATTRIBUTE11        VARCHAR2(500 BYTE),
  ATTRIBUTE12        VARCHAR2(500 BYTE),
  ATTRIBUTE13        VARCHAR2(500 BYTE),
  ATTRIBUTE14        VARCHAR2(500 BYTE),
  ATTRIBUTE15        VARCHAR2(500 BYTE),
  ATTRIBUTE16        VARCHAR2(500 BYTE),
  ATTRIBUTE17        VARCHAR2(500 BYTE),
  ATTRIBUTE18        VARCHAR2(500 BYTE),
  ATTRIBUTE19        VARCHAR2(500 BYTE),
  ATTRIBUTE20        VARCHAR2(500 BYTE)
);


GRANT ALL ON QST_TIMS_SIEBEL_REQUEST to APPS;

DROP SEQUENCE QSTADMIN.QST_TIMS_SIEBEL_REQUEST_S;

CREATE SEQUENCE QSTADMIN.QST_TIMS_SIEBEL_REQUEST_S
  START WITH 1
  MAXVALUE 9999999999999999999999999999
  MINVALUE 1
  NOCYCLE
  CACHE 20
  NOORDER;

GRANT ALL ON QST_TIMS_SIEBEL_REQUEST_S to APPS;
  
Connect apps/&&apps_pwd@&&instance

DROP SYNONYM APPS.QST_TIMS_SIEBEL_REQUEST;

CREATE SYNONYM APPS.QST_TIMS_SIEBEL_REQUEST FOR QSTADMIN.QST_TIMS_SIEBEL_REQUEST;

DROP SYNONYM APPS.QST_TIMS_SIEBEL_REQUEST_S;

CREATE SYNONYM APPS.QST_TIMS_SIEBEL_REQUEST_S FOR QSTADMIN.QST_TIMS_SIEBEL_REQUEST_S;