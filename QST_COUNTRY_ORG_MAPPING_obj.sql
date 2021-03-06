Connect QSTADMIN/&&QSTADMIN_pwd@&&instance

DROP TABLE QSTADMIN.QST_COUNTRY_ORG_MAPPING CASCADE CONSTRAINTS;

CREATE TABLE QSTADMIN.QST_COUNTRY_ORG_MAPPING
(
  COUNTRY_CODE       VARCHAR2(500 BYTE),
  COUNTRY_NAME       VARCHAR2(500 BYTE),
  ORG_ID             NUMBER,
  REGION             VARCHAR2(500 BYTE), 
  SUBREGION          VARCHAR2(500 BYTE),
  CURRENCY_CODE      VARCHAR2(500 BYTE),
  CREATION_DATE      DATE,
  CREATED_BY         NUMBER,
  LAST_UPDATED_DATE  DATE,
  LAST_UPDATED_BY    NUMBER,
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
  ATTRIBUTE15        VARCHAR2(500 BYTE)
);

GRANT ALL ON QSTADMIN.QST_COUNTRY_ORG_MAPPING TO APPS;

Connect apps/&&apps_pwd@&&instance

DROP SYNONYM APPS.QST_COUNTRY_ORG_MAPPING;

CREATE SYNONYM APPS.QST_COUNTRY_ORG_MAPPING FOR QSTADMIN.QST_COUNTRY_ORG_MAPPING;

