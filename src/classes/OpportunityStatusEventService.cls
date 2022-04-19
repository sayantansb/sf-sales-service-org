/**
 * Created by sayantan.sb on 18.04.22.
 */

public with sharing class OpportunityStatusEventService {

    @future
    public static void publishPostStatusChangedNotificationAsync(List<Id> opportunityIds) {
        publishPostStatusChangedNotification(opportunityIds);
    }

    private static void publishPostStatusChangedNotification(List<Id> opportunityIds) {
        List<Database.SaveResult> results = publishPostOpportunityStatusChanged(opportunityIds);
        checkPublishingResults(results);
    }

    private static List<Database.SaveResult> publishPostOpportunityStatusChanged(List<Id> opportunityIds) {
        List<Database.SaveResult> results = null;
        System.debug('OpportunityStatusEventService.publishPostOpportunityStatusChanged, opportunityIds = ' + opportunityIds);
        LogUtil.insertDebugEvent('Platform Event Generation on Opportunity Stage Closed WON','Opportunity',String.valueOf(opportunityIds),'Generating Opportunity Status Event OpportunityStatusEvent__e for Opportunity Ids : ' + opportunityIds,'DEBUG');
        List<Opportunity> opportunities = [SELECT Id, AgreementForm__c,DealType__c,RequestorId__c,AccountId FROM Opportunity WHERE Id IN :opportunityIds];

        List<Id> accountIds = new List<Id>();
        for (Opportunity opportunity : opportunities) {
            accountIds.add(opportunity.AccountId);
        }
        List<Account> accounts = [SELECT Id, Name, OwnerId,ClearingHouse__c, LiableOffice__c, SalesTeam__c,BookingType__c,BillingTerms__c,SalesChannel__c,AccessType__c FROM Account WHERE Id IN :accountIds];
        Map<Id, Account> accountById = new Map<Id, Account>();
        for (Account account : accounts) {
            accountById.put(account.Id, account);
        }

        List<Contact> userContacts = [SELECT Id,FirstName,LastName,Gender__c,AccountId,Phone,Email,MailingCountry,MailingCity,MailingPostalCode,MailingStreet,HouseNumber__c FROM Contact WHERE AccountId IN :accountIds];
        Map<Id,Contact> contactsByAccountId = new Map<Id, Contact>();
        for(Contact contact: userContacts){
            contactsByAccountId.put(contact.AccountId,Contact);
        }

        List<FeatureProduct__c> featureProducts = [SELECT Id,Type__c,Price__c,PricePerMonth__c,description__c,Opportunity__c FROM FeatureProduct__c WHERE Opportunity__c IN :opportunityIds];
        Map<Id,List<FeatureProduct__c>> featureProductsByOppId = new Map<Id, List<FeatureProduct__c>>();
        for(FeatureProduct__c featureProduct : featureProducts){
            if(featureProductsByOppId.containsKey(featureProduct.Opportunity__c)){
                featureProductsByOppId.get(featureProduct.Opportunity__c).add(featureProduct);
            }else{
                List<FeatureProduct__c> featureProductList = new List<FeatureProduct__c>();
                featureProductList.add(featureProduct);
                featureProductsByOppId.put(featureProduct.Opportunity__c,featureProductList);
            }
        }

        List<RevenueShare__c> revenueShares = [SELECT Id,Opportunity__c,TotalShareValue__c,TotalShareInPercent__c,SalesManagerId__c,ProfitCenter__c FROM RevenueShare__c WHERE Opportunity__c IN :opportunityIds];
        Map<Id,List<RevenueShare__c>> revenueSharesByOppId = new Map<Id, List<RevenueShare__c>>();
        for(RevenueShare__c revenueShare:revenueShares ){
            if(revenueSharesByOppId.containsKey(revenueShare.Opportunity__c)){
                revenueSharesByOppId.get(revenueShare.Opportunity__c).add(revenueShare);
            }else{
                List<RevenueShare__c> revenueShareList = new List<RevenueShare__c>();
                revenueShareList.add(revenueShare);
                revenueSharesByOppId.put(revenueShare.Opportunity__c,revenueShareList);
            }
        }

        Map<Id, Contact> contactsByOpportunityId = new Map<Id, Contact>();
        Map<Id, Account> accountByOpportunityId = new Map<Id, Account>();
        for (Opportunity opportunity : opportunities) {
            accountByOpportunityId.put(opportunity.Id, accountById.get(opportunity.AccountId));
            contactsByOpportunityId.put(opportunity.Id, contactsByAccountId.get(opportunity.AccountId));
        }


        List<OpportunityStatusEvent__e> opportunitiesChanged = new List<OpportunityStatusEvent__e>();
        for (Opportunity opportunity : opportunities) {
            try {
                OpportunityStatusEvent__e opportunityStatusEvent = createOpportunityChanged(opportunity);
                Account account = accountByOpportunityId.get(opportunity.Id);
                Contact contact = contactsByOpportunityId.get(opportunity.Id);
                fillAccountContact(opportunityStatusEvent, account, contact,opportunity.Id);
                fillFeatureProductList(opportunityStatusEvent,featureProductsByOppId.get(opportunity.Id),opportunity.Id);
                fillRevenueShareList(opportunityStatusEvent,revenueSharesByOppId.get(opportunity.Id),opportunity.Id);

                opportunitiesChanged.add(opportunityStatusEvent);

            } catch(Exception e) {
                LogUtil.insertDebugEvent('Platform Event Generation on Opportunity Stage Closed WON','Opportunity',opportunity.id,e.getMessage(),'ERROR');
                System.debug('Couldn\'t create event for OpportunityStatusChanged, opportunityId=' + opportunity.id + '. StackTrace: ' + e.getStackTraceString());
            }
        }
        System.debug('Publishing PlatformEvent ');
        try{
            results = EventBus.publish(opportunitiesChanged);
            LogUtil.insertDebugEvent('Platform Event Submitted on Opportunity Stage Closed WON','OpportunityStatusEvent__e','','Submitted Platform Event List for OpportunityStatusEvent__e','DEBUG');
        } catch(Exception ex) {
            System.debug('Exception while publishing cancellation details to event bus OpportunityStatusEvent__e');
            LogUtil.insertDebugEvent('Platform Event Publish on Opportunity Stage Closed WON','OpportunityStatusEvent__e','',ex.getMessage(),'ERROR');
        }
        return results;
    }

    @TestVisible
    private static OpportunityStatusEvent__e createOpportunityChanged(Opportunity opportunity) {
        OpportunityStatusEvent__e  opportunityStatusEvent = new OpportunityStatusEvent__e ();
        System.debug('Before creating PlatformEvent for Opportunity Id : ' + opportunity.Id);
        try{
            opportunityStatusEvent.OpportunityId__c  = opportunity.Id;
            opportunityStatusEvent.AgreementForm__c = opportunity.AgreementForm__c;
            opportunityStatusEvent.DealType__c = opportunity.DealType__c;
            opportunityStatusEvent.RequestorId__c  = String.valueOf(opportunity.RequestorId__c);
            System.debug('After creating PlatformEvent for Opportunity Id : ' + opportunity.Id);
        } catch (Exception e) {
            LogUtil.insertDebugEvent('Platform Event Generation on Opportunity Stage Closed WON','Opportunity',opportunity.Id,'Error creating Event OpportunityStatusEvent__e for Opportunity Id : ' + e.getMessage(),'ERROR');
            System.debug('Error while creating OpportunityStatusEvent__e for Opportunity ID : ' + opportunity.Id);
            System.debug('Error is : '+e.getStackTraceString());
        }
        return opportunityStatusEvent;
    }

    private static void checkPublishingResults(List<Database.SaveResult> results) {
        for (Database.SaveResult result : results) {
            if (result.isSuccess()) {
                LogUtil.insertDebugEvent('Platform Event Published Successfully on Opportunity Stage Closed WON','OpportunityStatusEvent__e','','Successfully Published Platform Event List for OpportunityStatusEvent__e','DEBUG');
                System.debug('OpportunityStatusEvent__e successfully published event: ' + result.id);
            } else {
                for(Database.Error error : result.getErrors()) {
                    LogUtil.insertDebugEvent('Platform Event Publish on Opportunity Stage Closed WON','OpportunityStatusEvent__e','',error.getStatusCode().name()+'>>'+error.getMessage(),'ERROR');
                    System.debug('Error returned generating event: ' + error.getStatusCode() + ' - ' + error.getMessage());
                }
            }
        }
    }

    @TestVisible
    public static void fillAccountContact(OpportunityStatusEvent__e event, Account account, Contact mainContact,Id opportunityId) {
        System.debug('Before fillAccountContactAndLead AccountId: '+account.Id);
        try {
            event.UserId__c = account.OwnerId;
            event.UserContactFirstName__c = mainContact.FirstName;
            event.UserContactLastName__c = mainContact.LastName;
            event.UserGender__c  = mainContact.Gender__c;
            event.CompanyName__c = account.Name;
            event.UserPhoneNumber__c = mainContact.Phone;
            event.UserEmailAddress__c = mainContact.Email;
            event.UserCountry__c = mainContact.MailingCountry;
            event.UserCity__c = mainContact.MailingCity;
            event.UserZipCode__c = mainContact.MailingPostalCode;
            event.UserStreet__c = mainContact.MailingStreet;
            event.UserHouseNumber__c = mainContact.HouseNumber__c;

            event.ClearingHouse__c = account.ClearingHouse__c;
            event.SalesTeam__c = account.SalesTeam__c;
            event.AccountBookingType__c = account.BookingType__c;
            event.BillingTerms__c = account.BillingTerms__c;
            event.SalesChannels__c = account.SalesChannel__c;
            event.AccountAccessTypes__c = account.AccessType__c;

            System.debug('After populating Account and Contact info in OpportunityStatusEvent__e for opportunityId : '+opportunityId);
        } catch (Exception e) {
            LogUtil.insertDebugEvent('Platform Event Generation on Opportunity Stage Closed WON','OpportunityStatusEvent__e',opportunityId,e.getMessage(),'ERROR');
            System.debug('Invalid ShopId expected a number: ' + e.getMessage());
        }
    }

    @TestVisible
    public static void fillFeatureProductList(OpportunityStatusEvent__e event, List<FeatureProduct__c> featureProductList, Id opportunityId) {
        String strFeatureProdList = '';
        try{
            for(FeatureProduct__c featureProduct: featureProductList){
                String strFeatureProd = 'Type__c---'+featureProduct.Type__c+':'+'Price__c---'+featureProduct.Price__c+':'+'PricePerMonth__c---'+featureProduct.PricePerMonth__c+':'+'description__c---'+featureProduct.description__c+'||';
                strFeatureProdList+=strFeatureProd;
            }
            Integer lastIdx = strFeatureProdList.lastIndexOf('||');
            if(lastIdx>-1){
                strFeatureProdList = strFeatureProdList.substring(0,lastIdx);
            }
            event.Products__c = strFeatureProdList;
        }catch (Exception ex){
            LogUtil.insertDebugEvent('Platform Event Generation on Opportunity Stage Closed WON','OpportunityStatusEvent__e',opportunityId,ex.getMessage(),'ERROR');
            System.debug('Error in populating feature Product List for Opportunity: ' + ex.getMessage());
        }

    }

    @TestVisible
    public static void fillRevenueShareList(OpportunityStatusEvent__e event, List<RevenueShare__c> revenueShareList, Id opportunityId) {
        String strRevenueShareList = '';
        try{
            for(RevenueShare__c revenueShare: revenueShareList){
                String strRevenueShare = 'SalesManagerId__c---'+revenueShare.SalesManagerId__c+':'+'ProfitCenter__c---'+revenueShare.ProfitCenter__c+':'+'TotalShareInPercent__c---'+revenueShare.TotalShareInPercent__c+':'+'TotalShareValue__c---'+revenueShare.TotalShareValue__c+'||';
                strRevenueShareList+=strRevenueShare;
            }
            Integer lastIdx = strRevenueShareList.lastIndexOf('||');
            if(lastIdx>-1){
                strRevenueShareList = strRevenueShareList.substring(0,lastIdx);
            }
            event.SMRevenueShares__c = strRevenueShareList;
        }catch (Exception ex){
            LogUtil.insertDebugEvent('Platform Event Generation on Opportunity Stage Closed WON','OpportunityStatusEvent__e',opportunityId,ex.getMessage(),'ERROR');
            System.debug('Error in populating feature Product List for Opportunity: ' + ex.getMessage());
        }

    }

}