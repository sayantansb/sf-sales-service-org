/**
 * Created by sayantan.sb on 18.04.22.
 */

public with sharing class LogUtil {

    public static void insertDebugEvent(String businessCase,String objectName,String objectId,String message,String level){

        try{
            Debug__c debug = new Debug__c();
            debug.BusinessCase__c = businessCase;
            debug.ObjectName__c = objectName;
            debug.ObjectId__c = objectId;
            debug.Message__c = message;
            debug.Level__c = level;

            Database.SaveResult result = Database.insert(debug);
            if(!result.success){
                System.debug('Error in saving Debug object');
            }
        }catch (Exception e){
            System.debug('Error in saving Debug object');
        }

    }

}