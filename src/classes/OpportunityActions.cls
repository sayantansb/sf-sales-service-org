/**
 * Created by sayantan.sb on 18.04.22.
 */

public with sharing class OpportunityActions {

    public static void postUpdateAction(List<Opportunity> newOpportunities, List<Opportunity> oldOpportunities,
            Map<ID, Opportunity> newOpportunitiesMap, Map<ID, Opportunity> oldOpportunitiesMap) {
        System.debug('OpportunityActions.postUpdateAction :: begins');
        processStatusChanges(newOpportunitiesMap, oldOpportunitiesMap);
        System.debug('OpportunityActions.postUpdateAction :: ends');
    }


    public static void preUpdateAction (List<Opportunity> newOpportunities, List<Opportunity> oldOpportunities,
            Map<ID, Opportunity> newOpportunitiesMap , Map<ID, Opportunity> oldOpportunitiesMap) {
        System.debug('OpportunityActions.preUpdateAction :: begins');

        System.debug('OpportunityActions.preUpdateAction :: ends');
    }


    public static void postInsertAction(List<Opportunity> opportunities) {
        System.debug('OpportunityActions.postInsertAction :: begins');

        System.debug('OpportunityActions.postInsertAction :: ends');
    }

    public static void preInsertAction(List<Opportunity> opportunities) {

    }


    private static void processStatusChanges(Map<ID, Opportunity> newOpportunitiesMap , Map<ID, Opportunity> oldOpportunitiesMap) {
        List<Id> idListForPostStatusChanges = populateIdListForPostStatusChangesNotification(newOpportunitiesMap, oldOpportunitiesMap);
        System.debug('OpportunityActions.processStatusChanges :: size of idListForPostStatusChanges = ' + idListForPostStatusChanges.size());
        if(idListForPostStatusChanges.size() > 0) {
            System.debug('OpportunityActions.processStatusChanges :: before call to OpportunityStatusEventService.publishPostStatusChangedNotificationAsync');
            /**
             *  Approach 1 with PLatform Events
            */
            //OpportunityStatusEventService.publishPostStatusChangedNotificationAsync(idListForPostStatusChanges);

            /**
             *  Approach 2 with REST Call directly from salesforce future handler
            */
            BookingInvoker.invokeBookingAsync(idListForPostStatusChanges);
            System.debug('OpportunityActions.processStatusChanges :: after call to OpportunityStatusEventService.publishPostStatusChangedNotificationAsync');
        }
    }

    private static List<Id> populateIdListForPostStatusChangesNotification(Map<ID, Opportunity> newOpportunitiesMap,
            Map<ID, Opportunity> oldOpportunitiesMap){
        List<Id> idListForPostStatusChangesNotification = new List<Id>();
        for(Id id : newOpportunitiesMap.keySet()) {
            Opportunity newOpportunity = newOpportunitiesMap.get(id);
            if(newOpportunity != null) {
                Opportunity oldOpportunity = oldOpportunitiesMap.get(id);
                if(isStageNameChanged(newOpportunity, oldOpportunity)) {
                    idListForPostStatusChangesNotification.add(id);
                }
            }
        }
        return idListForPostStatusChangesNotification;
    }

    private static boolean isStageNameChanged(Opportunity newOpportunity, Opportunity oldOpportunity) {
        if (oldOpportunity!=null && newOpportunity.StageName == 'Closed Won' ) {
            return newOpportunity.StageName != oldOpportunity.StageName;
        }
        return false;
    }


}