/**
 * Created by sayantan.sb on 18.04.22.
 */

public with sharing class OpportunityTriggerHandler {
    public OpportunityTriggerHandler() {
    }

    public void OnBeforeInsert(List<Opportunity> newOpportunities) {
        System.debug('OpportunityTriggerHandler.OnBeforeInsert :: begins');
        OpportunityActions.preInsertAction(newOpportunities);
        System.debug('OpportunityTriggerHandler.OnBeforeInsert :: ends');
    }

    public void OnAfterInsert(List<Opportunity> newOpportunities) {
        System.debug('OpportunityTriggerHandler.OnAfterInsert :: begins');
        OpportunityActions.postInsertAction(newOpportunities);
        System.debug('OpportunityTriggerHandler.OnAfterInsert :: ends');
    }

    public void OnAfterUpdate(List<Opportunity> newOpportunities, List<Opportunity> oldOpportunities,
            Map<ID, Opportunity> newOpportunitiesMap, Map<ID, Opportunity> oldOpportunitiesMap) {
        System.debug('OpportunityTriggerHandler.OnAfterUpdate :: begins');
        OpportunityActions.postUpdateAction (newOpportunities, oldOpportunities, newOpportunitiesMap, oldOpportunitiesMap);
        System.debug('OpportunityTriggerHandler.OnAfterUpdate :: ends');
    }

    public void OnBeforeUpdate(List<Opportunity> newOpportunities, List<Opportunity> oldOpportunities,
            Map<ID, Opportunity> newOpportunitiesMap, Map<ID, Opportunity> oldOpportunitiesMap) {
        System.debug('OpportunityTriggerHandler.OnBeforeUpdate :: begins');
        OpportunityActions.preUpdateAction (newOpportunities, oldOpportunities, newOpportunitiesMap, oldOpportunitiesMap);
        System.debug('OpportunityTriggerHandler.OnBeforeUpdate :: ends');
    }

}