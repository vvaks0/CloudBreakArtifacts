package com.hortonworks;

import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.Random;

public class DataGen {
	
public static void main(String[] args) throws IOException, ParseException {
	 String outputPath = args[0];
	 int recordCount = args[1];
	 String csvFile = outputPath+"/aum.csv";
     //FileWriter w = new FileWriter(csvFile);
     PrintWriter writer = new PrintWriter(csvFile, "UTF-8");
     
     Random rt = new Random(recordCount);
     Random rd = new Random(recordCount);
     SimpleDateFormat df = new SimpleDateFormat("yyyy-MM-dd");
     
     List<String> effecDates =  Arrays.asList("2017-08-02", "2016-03-03", "2016-04-05");
     List<String> accountCode =  Arrays.asList("02", "04", "06");
     List<String> iveMgr =  Arrays.asList("Banker1", "Banker2", "Banker3");
     List<String> curr =  Arrays.asList("USD", "EUR", "RUP");
     
	for (int i=0; i< recordCount; i++) {
		
		 int id = i;
		 String account ="AccountName " +i;
		 String al2 ="al2";
		 String al3 ="al3";
		 String al4 ="al4 "+ i;
		 String currency = "USD";
		 double fxRate = 2.3345;
		 long netWorth = 100 * i;
		 String riskProfile = "4 medium";
	
		int TENANT_ID =  rt.nextInt(60);
		
		String EFFECTIVE_DATE = effecDates.get(rd.nextInt(3));
		String ACCOUNT_CODE = accountCode.get(rd.nextInt(3));
		  
		long   POSITION_DETAIL_ID =0l;
		String ACCOUNT_NAME = "Account_"+i;
		String ACCOUNT_SUBTYPE = accountCode.get(rd.nextInt(3));
		String ACCOUNT_TYPE =accountCode.get(rd.nextInt(3));
		 String   ASSET_CLASS_LEVEL_1 = "Future";
		 String    ASSET_CLASS_LEVEL_2 = "Option";
		 String    ASSET_CLASS_LEVEL_3 ="Security";
		 String   BASE_CURRENCY = curr.get(rt.nextInt(3));
		 String   CLIENT_SUB_TYPE = "CST";
		 String   CLIENT_TYPE = "CT";
		 String   CURRENCY_STRATEGY = "none";
		 String   INVESTMENT_TYPE ="IT";
		 String   LEAD_INVESTMENT_MGR =  iveMgr.get(rd.nextInt(3));
		 String  MANDATE_TYPE ="MT";
		 double   MARKET_VALUE  = 23.7;
		 String   PORTFOLIO_PM_NAME = "BlackRock_"+i;
		 String  PROCESS_SEC_TYPE = "PT";
		 String  PRODUCT_CODE = "PC";
		  int  SECURITY_ALIAS  = rt.nextInt(3);
		 String  SECURITY_CODE = "SC";
		 String  SECURITY_NAME = "SN";
		 int SRC_INTFC_INST =1;
		 
		 StringBuffer sb = new StringBuffer();
		 sb.append(ACCOUNT_NAME);
		 sb.append(",");
		 sb.append(EFFECTIVE_DATE);
		 sb.append(",");
		 sb.append(TENANT_ID);
		 sb.append(",");
		 sb.append(ACCOUNT_CODE);
		 sb.append(",");
		 sb.append(POSITION_DETAIL_ID);
		 sb.append(",");
		 sb.append(ACCOUNT_SUBTYPE);
		 sb.append(",");
		 sb.append(ACCOUNT_TYPE);
		 sb.append(",");
		 sb.append(ASSET_CLASS_LEVEL_1);
		 sb.append(",");
		 sb.append(ASSET_CLASS_LEVEL_2);
		 sb.append(",");
		 sb.append(ASSET_CLASS_LEVEL_3);
		 sb.append(",");
		 sb.append(BASE_CURRENCY);
		 sb.append(",");
		 sb.append(CLIENT_SUB_TYPE);
		 sb.append(",");
		 sb.append(CLIENT_TYPE);
		 sb.append(",");
		 sb.append(CURRENCY_STRATEGY);
		 sb.append(",");
		 sb.append(INVESTMENT_TYPE);
		 sb.append(",");
		 sb.append(LEAD_INVESTMENT_MGR);
		 sb.append(",");
		 sb.append(MANDATE_TYPE);
		 sb.append(",");
		 sb.append(MARKET_VALUE);
		 sb.append(",");
		 sb.append(PORTFOLIO_PM_NAME);
		 sb.append(",");
		 sb.append(PROCESS_SEC_TYPE);
		 sb.append(",");
		 sb.append(PRODUCT_CODE);
		 sb.append(",");
		 sb.append(SECURITY_ALIAS);
		 sb.append(",");
		 sb.append(SECURITY_CODE);
		 sb.append(",");
		 sb.append(SECURITY_NAME);
		 sb.append(",");
		 sb.append(SRC_INTFC_INST);
		// sb.append("\n");
		 //w.append(sb.toString());
		writer.println(sb.toString());
 
		 if (i %100000 ==0) {
			 System.out.println(sb.toString());
			 writer.flush();
		   
		 }
	}
	writer.close();
	
	}
}
